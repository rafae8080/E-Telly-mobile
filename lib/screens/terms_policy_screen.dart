import 'package:flutter/material.dart';
import '../constants.dart';

/// Read-only Terms & Conditions / Privacy Policy screen.
///
/// Linked from the sign-up and profile-completion flows. The content here is the
/// source of truth for what residents agree to; if it changes, bump [termsVersion]
/// in lib/constants.dart so recorded consent stays accurate.
class TermsPolicyScreen extends StatelessWidget {
  const TermsPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0.5,
        shadowColor: Colors.grey,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Terms & Privacy Policy'),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'E-Telly Terms & Conditions and Privacy Policy',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ET_RED,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Version $termsVersion',
                style: TextStyle(fontSize: 13, color: ET_GRAY),
              ),
              SizedBox(height: 20),

              _Section(
                title: '1. Introduction',
                body:
                    'E-Telly is a community disaster-response application for residents of '
                    'Antipolo City. It helps you receive alerts, find evacuation routes, '
                    'report emergencies, and request or pledge resources during emergencies. '
                    'By creating an account and using E-Telly, you confirm that you have read, '
                    'understood, and agree to these Terms & Conditions and this Privacy Policy. '
                    'If you do not agree, please do not register or use the app.',
              ),

              _Section(
                title: '2. Personal Information We Collect',
                body:
                    'When you register, we collect and store your personal information, '
                    'including your full name, email address, and home address (barangay, '
                    'street/building details, and any landmark you provide). This information '
                    'is stored on our servers and is readable by authorized administrators and '
                    'barangay officials so they can coordinate emergency response, verify '
                    'residents, and deliver assistance. Please provide accurate information.',
              ),

              _Section(
                title: '3. Location Data',
                body:
                    'E-Telly accesses and uses your device location to provide core features '
                    'such as evacuation routing, hazard and flood alerts relevant to your area, '
                    'and emergency reporting. Your location may be shared with responders and '
                    'administrators when you submit a report or request help so they can reach '
                    'you. You can control location permissions through your device settings, but '
                    'some features may not work correctly without them.',
              ),

              _Section(
                title: '4. Resources Chat Is Monitored',
                body:
                    'In the Resources feature, requesters and pledgers can chat to coordinate '
                    'help. Please be aware that these conversations are visible to '
                    'administrators for safety, moderation, and to prevent abuse or fraud. Do '
                    'not share sensitive personal information (such as financial details or '
                    'passwords) in these chats. Treat all messages as monitored.',
              ),

              _Section(
                title: '5. Emergency Reports',
                body:
                    'When you submit an emergency report, the report details, your location, '
                    'and any photos you attach are shared with administrators, barangay '
                    'officials, and responders so they can assess and act on the situation. '
                    'Submit reports truthfully; false or malicious reports may result in '
                    'account suspension.',
              ),

              _Section(
                title: '6. How We Use, Retain, and Protect Your Data',
                body:
                    'We use your information solely to deliver E-Telly\'s disaster-response '
                    'services — alerting, routing, reporting, and resource coordination. We do '
                    'not sell your personal information. Your data is retained while your '
                    'account remains active and as needed for legitimate response and '
                    'record-keeping purposes. We apply reasonable technical and organizational '
                    'safeguards to protect it, though no system can be guaranteed completely '
                    'secure.',
              ),

              _Section(
                title: '7. Your Responsibilities',
                body:
                    'You agree to provide accurate and up-to-date information, to keep your '
                    'login credentials confidential, and to use E-Telly only for lawful, '
                    'legitimate community and emergency purposes. You are responsible for '
                    'activity that occurs under your account.',
              ),

              _Section(
                title: '8. Changes to These Terms',
                body:
                    'We may update these Terms & Conditions and Privacy Policy from time to '
                    'time. When we do, we will update the version shown above. Continued use of '
                    'E-Telly after an update means you accept the revised terms.',
              ),

              _Section(
                title: '9. Contact Us',
                body:
                    'If you have questions about these terms or how your data is handled, '
                    'please contact the E-Telly support team or your local barangay office.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ET_RED,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
