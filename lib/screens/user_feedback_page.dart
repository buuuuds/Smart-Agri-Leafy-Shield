// screens/user_feedback_page.dart - COMPLETE USER FEEDBACK SYSTEM

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserFeedbackPage extends StatefulWidget {
  const UserFeedbackPage({super.key});

  @override
  State<UserFeedbackPage> createState() => _UserFeedbackPageState();
}

class _UserFeedbackPageState extends State<UserFeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _commentsController = TextEditingController();

  // Rating categories
  int _overallRating = 0;
  int _shadingEffectivenessRating = 0;
  int _wateringEffectivenessRating = 0;
  int _mistingEffectivenessRating = 0;
  int _easeOfUseRating = 0;
  int _appInterfaceRating = 0;
  int _reliabilityRating = 0;

  // User type
  String _userType = 'Small-scale Farmer';

  // Checkbox questions
  bool _wouldRecommend = false;
  bool _improvedCropHealth = false;
  bool _savedWater = false;
  bool _reducedLaborTime = false;

  bool _isSubmitting = false;
  bool _showSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    _loadPreviousFeedback();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _loadPreviousFeedback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('feedback_name');
      final savedLocation = prefs.getString('feedback_location');

      if (savedName != null) _nameController.text = savedName;
      if (savedLocation != null) _locationController.text = savedLocation;
    } catch (e) {
      debugPrint('Error loading previous feedback: $e');
    }
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    if (_overallRating == 0) {
      _showSnackBar('Please provide an overall rating', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Save to Firestore
      final feedbackData = {
        'timestamp': FieldValue.serverTimestamp(),
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'userType': _userType,
        'ratings': {
          'overall': _overallRating,
          'shadingEffectiveness': _shadingEffectivenessRating,
          'wateringEffectiveness': _wateringEffectivenessRating,
          'mistingEffectiveness': _mistingEffectivenessRating,
          'easeOfUse': _easeOfUseRating,
          'appInterface': _appInterfaceRating,
          'reliability': _reliabilityRating,
        },
        'benefits': {
          'wouldRecommend': _wouldRecommend,
          'improvedCropHealth': _improvedCropHealth,
          'savedWater': _savedWater,
          'reducedLaborTime': _reducedLaborTime,
        },
        'comments': _commentsController.text.trim(),
        'deviceInfo': {
          'platform': Theme.of(context).platform.toString(),
          'appVersion': '2.4',
        },
      };

      await FirebaseFirestore.instance
          .collection('user_feedback')
          .add(feedbackData);

      // Save user info locally for next time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('feedback_name', _nameController.text.trim());
      await prefs.setString(
        'feedback_location',
        _locationController.text.trim(),
      );

      setState(() {
        _isSubmitting = false;
        _showSuccessMessage = true;
      });

      _showSnackBar('Thank you for your feedback! 🌱', Colors.green);

      // Reset form after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnackBar('Failed to submit feedback: $e', Colors.red);
      debugPrint('Feedback submission error: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Feedback'),
        backgroundColor: isDarkMode
            ? const Color(0xFF1F1F1F)
            : const Color(0xFF2E7D32),
        elevation: 0,
      ),
      body: _showSuccessMessage
          ? _buildSuccessScreen()
          : _buildFeedbackForm(isDarkMode),
    );
  }

  Widget _buildSuccessScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Feedback Submitted!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Thank you for helping us improve the Smart Agri-Leafy Shield system!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackForm(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'We Value Your Feedback',
              'Help us improve the system by sharing your experience',
              Icons.feedback,
              isDarkMode,
            ),
            const SizedBox(height: 24),

            _buildUserInfoSection(isDarkMode),
            const SizedBox(height: 20),

            _buildOverallRatingSection(isDarkMode),
            const SizedBox(height: 20),

            _buildSystemPerformanceSection(isDarkMode),
            const SizedBox(height: 20),

            _buildAppUsabilitySection(isDarkMode),
            const SizedBox(height: 20),

            _buildBenefitsSection(isDarkMode),
            const SizedBox(height: 20),

            _buildCommentsSection(isDarkMode),
            const SizedBox(height: 24),

            _buildSubmitButton(),
            const SizedBox(height: 16),

            _buildPrivacyNote(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String subtitle,
    IconData icon,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection(bool isDarkMode) {
    return _buildCard(
      isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubheader('User Information', Icons.person, isDarkMode),
          const SizedBox(height: 16),

          TextFormField(
            controller: _nameController,
            decoration: _inputDecoration('Name', Icons.person_outline),
            validator: (value) =>
                value?.trim().isEmpty ?? true ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _locationController,
            decoration: _inputDecoration(
              'Location/Barangay',
              Icons.location_on,
            ),
            validator: (value) => value?.trim().isEmpty ?? true
                ? 'Please enter your location'
                : null,
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _userType,
            decoration: _inputDecoration('User Type', Icons.category),
            items: const [
              DropdownMenuItem(
                value: 'Small-scale Farmer',
                child: Text('Small-scale Farmer'),
              ),
              DropdownMenuItem(
                value: 'Student/Researcher',
                child: Text('Student/Researcher'),
              ),
              DropdownMenuItem(
                value: 'Agricultural Extension Worker',
                child: Text('Agricultural Extension Worker'),
              ),
              DropdownMenuItem(
                value: 'Tech Developer',
                child: Text('Tech Developer'),
              ),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => _userType = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallRatingSection(bool isDarkMode) {
    return _buildCard(
      isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubheader('Overall Satisfaction', Icons.star, isDarkMode),
          const SizedBox(height: 8),
          const Text(
            'How satisfied are you with the Smart Agri-Leafy Shield system?',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _buildStarRating(
            _overallRating,
            (rating) => setState(() => _overallRating = rating),
            large: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemPerformanceSection(bool isDarkMode) {
    return _buildCard(
      isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubheader('System Performance', Icons.assessment, isDarkMode),
          const SizedBox(height: 16),
          _buildRatingRow(
            'Shading System Effectiveness',
            Icons.wb_cloudy,
            _shadingEffectivenessRating,
            (rating) => setState(() => _shadingEffectivenessRating = rating),
          ),
          const SizedBox(height: 16),
          _buildRatingRow(
            'Watering/Irrigation System',
            Icons.water_drop,
            _wateringEffectivenessRating,
            (rating) => setState(() => _wateringEffectivenessRating = rating),
          ),
          const SizedBox(height: 16),
          _buildRatingRow(
            'Misting System',
            Icons.cloud,
            _mistingEffectivenessRating,
            (rating) => setState(() => _mistingEffectivenessRating = rating),
          ),
          const SizedBox(height: 16),
          _buildRatingRow(
            'System Reliability',
            Icons.verified,
            _reliabilityRating,
            (rating) => setState(() => _reliabilityRating = rating),
          ),
        ],
      ),
    );
  }

  Widget _buildAppUsabilitySection(bool isDarkMode) {
    return _buildCard(
      isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubheader(
            'Mobile App Usability',
            Icons.phone_android,
            isDarkMode,
          ),
          const SizedBox(height: 16),
          _buildRatingRow(
            'Ease of Use',
            Icons.touch_app,
            _easeOfUseRating,
            (rating) => setState(() => _easeOfUseRating = rating),
          ),
          const SizedBox(height: 16),
          _buildRatingRow(
            'App Interface Design',
            Icons.palette,
            _appInterfaceRating,
            (rating) => setState(() => _appInterfaceRating = rating),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection(bool isDarkMode) {
    return _buildCard(
      isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubheader('Benefits Realized', Icons.trending_up, isDarkMode),
          const SizedBox(height: 8),
          const Text(
            'Check all that apply:',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _buildCheckbox(
            'Improved crop health and yield',
            _improvedCropHealth,
            (value) => setState(() => _improvedCropHealth = value!),
            Icons.spa,
            Colors.green,
          ),
          _buildCheckbox(
            'Saved water consumption',
            _savedWater,
            (value) => setState(() => _savedWater = value!),
            Icons.water_drop,
            Colors.blue,
          ),
          _buildCheckbox(
            'Reduced manual labor and time',
            _reducedLaborTime,
            (value) => setState(() => _reducedLaborTime = value!),
            Icons.access_time,
            Colors.orange,
          ),
          _buildCheckbox(
            'Would recommend to other farmers',
            _wouldRecommend,
            (value) => setState(() => _wouldRecommend = value!),
            Icons.thumb_up,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(bool isDarkMode) {
    return _buildCard(
      isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubheader('Additional Comments', Icons.comment, isDarkMode),
          const SizedBox(height: 8),
          const Text(
            'Share your suggestions, concerns, or success stories',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _commentsController,
            decoration: _inputDecoration('Your comments here...', Icons.edit),
            maxLines: 5,
            maxLength: 500,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitFeedback,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Submit Feedback',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your feedback helps us improve the system. All responses are confidential and used for research purposes only.',
              style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(bool isDarkMode, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSubheader(String title, IconData icon, bool isDarkMode) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingRow(
    String label,
    IconData icon,
    int rating,
    Function(int) onRatingChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildStarRating(rating, onRatingChanged),
      ],
    );
  }

  Widget _buildStarRating(
    int rating,
    Function(int) onRatingChanged, {
    bool large = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () => onRatingChanged(index + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: index < rating ? Colors.amber : Colors.grey[400],
              size: large ? 40 : 32,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCheckbox(
    String label,
    bool value,
    Function(bool?) onChanged,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: value ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? color : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: CheckboxListTile(
          value: value,
          onChanged: onChanged,
          title: Row(
            children: [
              Icon(icon, size: 18, color: value ? color : Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: value ? color : Colors.grey[800],
                    fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          activeColor: color,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
      ),
    );
  }
}
