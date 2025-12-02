// functions/index.js

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// ✅ SEND PUSH NOTIFICATION WHEN ALERT IS CREATED
exports.sendAlertNotification = functions.database
  .ref('/devices/{deviceId}/alerts/{alertId}')
  .onCreate(async (snapshot, context) => {
    const deviceId = context.params.deviceId;
    const alertId = context.params.alertId;
    const alert = snapshot.val();

    console.log('🚨 NEW ALERT DETECTED');
    console.log('   Device:', deviceId);
    console.log('   Alert ID:', alertId);
    console.log('   Title:', alert.title);
    console.log('   Priority:', alert.priority);

    try {
      // Get all FCM tokens for this device
      const tokensSnapshot = await admin.database()
        .ref(`/devices/${deviceId}/fcm_tokens`)
        .once('value');

      const tokensData = tokensSnapshot.val();

      if (!tokensData) {
        console.log('⚠️ No FCM tokens found for device:', deviceId);
        return null;
      }

      // Extract active tokens
      const tokens = Object.values(tokensData)
        .filter(t => t.active === true)
        .map(t => t.token);

      if (tokens.length === 0) {
        console.log('⚠️ No active tokens to send to');
        return null;
      }

      console.log(`📱 Sending to ${tokens.length} device(s)`);

      // Prepare notification payload
      const message = {
        notification: {
          title: alert.title || '🌱 Agri-Leafy Alert',
          body: alert.message || 'Check your plant system',
        },
        data: {
          alertId: alertId,
          priority: alert.priority || 'medium',
          timestamp: alert.timestamp || new Date().toISOString(),
          type: 'sensor_alert',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'agri_leafy_alerts',
            sound: 'default',
            priority: 'max',
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
        tokens: tokens,
      };

      // Send multicast message
      const response = await admin.messaging().sendMulticast(message);

      console.log('✅ Success:', response.successCount);
      console.log('❌ Failed:', response.failureCount);

      // Clean up failed tokens
      if (response.failureCount > 0) {
        const failedTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(tokens[idx]);
            console.log('   Error:', resp.error);
          }
        });

        console.log('🗑️ Removing', failedTokens.length, 'failed tokens');

        // Remove failed tokens
        for (const token of failedTokens) {
          const tokenKey = token.substring(0, 20).replace(/[^a-zA-Z0-9]/g, '');
          await admin.database()
            .ref(`/devices/${deviceId}/fcm_tokens/${tokenKey}`)
            .remove();
        }
      }

      // Mark alert as sent
      await snapshot.ref.update({
        sent: true,
        sentAt: admin.database.ServerValue.TIMESTAMP,
        recipientCount: response.successCount,
      });

      return response;

    } catch (error) {
      console.error('❌ ERROR sending notification:', error);
      return null;
    }
  });

// ✅ CLEANUP OLD ALERTS (runs daily)
exports.cleanupOldAlerts = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('Asia/Manila')
  .onRun(async (context) => {
    console.log('🧹 Starting cleanup of old alerts...');

    const sevenDaysAgo = Date.now() - (7 * 24 * 60 * 60 * 1000);
    let deletedCount = 0;

    try {
      const devicesSnapshot = await admin.database().ref('/devices').once('value');
      const devices = devicesSnapshot.val() || {};

      for (const deviceId of Object.keys(devices)) {
        const alertsRef = admin.database().ref(`/devices/${deviceId}/alerts`);
        const alertsSnapshot = await alertsRef.once('value');
        const alerts = alertsSnapshot.val() || {};

        for (const [alertId, alert] of Object.entries(alerts)) {
          if (alert.timestamp) {
            const alertTime = new Date(alert.timestamp).getTime();

            if (alertTime < sevenDaysAgo) {
              await alertsRef.child(alertId).remove();
              deletedCount++;
            }
          }
        }
      }

      console.log(`✅ Cleanup complete: Deleted ${deletedCount} old alerts`);
      return null;

    } catch (error) {
      console.error('❌ Cleanup error:', error);
      return null;
    }
  });