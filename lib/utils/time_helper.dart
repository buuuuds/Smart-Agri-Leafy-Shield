// lib/utils/time_helper.dart - NEW FILE

class TimeHelper {
  /// Converts DateTime to relative time string
  /// Examples: "just now", "5m ago", "2h ago", "3d ago"
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30)
      return '${(difference.inDays / 7).floor()}w ago';
    if (difference.inDays < 365)
      return '${(difference.inDays / 30).floor()}mo ago';
    return '${(difference.inDays / 365).floor()}y ago';
  }

  /// Get full relative time with text
  /// Examples: "2 minutes ago", "3 hours ago", "5 days ago"
  static String getFullRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) {
      final m = difference.inMinutes;
      return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
    }
    if (difference.inHours < 24) {
      final h = difference.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    }
    if (difference.inDays < 7) {
      final d = difference.inDays;
      return '$d ${d == 1 ? 'day' : 'days'} ago';
    }
    if (difference.inDays < 30) {
      final w = (difference.inDays / 7).floor();
      return '$w ${w == 1 ? 'week' : 'weeks'} ago';
    }
    if (difference.inDays < 365) {
      final m = (difference.inDays / 30).floor();
      return '$m ${m == 1 ? 'month' : 'months'} ago';
    }
    final y = (difference.inDays / 365).floor();
    return '$y ${y == 1 ? 'year' : 'years'} ago';
  }

  /// Format timestamp to readable date
  /// Example: "Jan 15, 2025 at 10:30 AM"
  static String formatTimestamp(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year at $hour:$minute $period';
  }
}
