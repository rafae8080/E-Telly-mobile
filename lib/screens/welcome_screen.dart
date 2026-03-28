import 'package:flutter/material.dart';
import '../widgets/welcome.dart';

class Config {
  final String background_color;
  final String surface_color;
  final String text_color;
  final String primary_action_color;
  final String secondary_action_color;
  final String font_family;
  final double font_size;
  final String app_title;
  final String tagline;
  final String feature_1_title;
  final String feature_1_description;
  final String feature_2_title;
  final String feature_2_description;
  final String feature_3_title;
  final String feature_3_description;
  final String primary_button_text;
  final String secondary_button_text;

  Config({
    required this.background_color,
    required this.surface_color,
    required this.text_color,
    required this.primary_action_color,
    required this.secondary_action_color,
    required this.font_family,
    required this.font_size,
    required this.app_title,
    required this.tagline,
    required this.feature_1_title,
    required this.feature_1_description,
    required this.feature_2_title,
    required this.feature_2_description,
    required this.feature_3_title,
    required this.feature_3_description,
    required this.primary_button_text,
    required this.secondary_button_text,
  });
}

class WelcomeScreen extends StatefulWidget {
  final Config? config;
  final Function(Config)? onConfigChange;

  const WelcomeScreen({super.key, this.config, this.onConfigChange});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final defaultConfig = Config(
    background_color: "#FFFFFF",
    surface_color: "#F8FAFC",
    text_color: "#DC2626",
    primary_action_color: "#DC2626",
    secondary_action_color: "#EF4444",
    font_family: "Roboto",
    font_size: 16,
    app_title: "E-Telly",
    tagline: "Stay Safe, Stay Informed",
    feature_1_title: "Real-Time Alerts",
    feature_1_description:
        "Receive instant notifications about disasters in your area",
    feature_2_title: "Emergency Resources",
    feature_2_description:
        "Quick access to shelters, hospitals, and emergency contacts",
    feature_3_title: "Safety Tips",
    feature_3_description:
        "Expert guidance on how to prepare and respond to emergencies",
    primary_button_text: "Get Started",
    secondary_button_text: "Learn More",
  );

  late Config config;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _feature1Anim;
  late Animation<double> _feature2Anim;
  late Animation<double> _feature3Anim;
  late Animation<double> _buttonAnim;

  @override
  void initState() {
    super.initState();
    config = widget.config ?? defaultConfig;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _feature1Anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _feature2Anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _feature3Anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _buttonAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _parseColor(String color) {
    return Color(int.parse(color.replaceAll('#', '0xFF')));
  }

  void _handlePrimaryButtonPress() {
    Navigator.pushNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _parseColor(config.background_color),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _fadeAnim,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - _fadeAnim.value)),
                      child: Opacity(opacity: _fadeAnim.value, child: child),
                    );
                  },
                  child: LogoSection(
                    appTitle: config.app_title,
                    tagline: config.tagline,
                    textColor: _parseColor(config.text_color),
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    FeatureItem(
                      animation: _feature1Anim,
                      icon: Icons.notifications,
                      title: config.feature_1_title,
                      description: config.feature_1_description,
                      surfaceColor: _parseColor(config.surface_color),
                      primaryColor: _parseColor(config.primary_action_color),
                      textColor: _parseColor(config.text_color),
                    ),
                    const SizedBox(height: 18),
                    FeatureItem(
                      animation: _feature2Anim,
                      icon: Icons.local_hospital,
                      title: config.feature_2_title,
                      description: config.feature_2_description,
                      surfaceColor: _parseColor(config.surface_color),
                      primaryColor: _parseColor(config.primary_action_color),
                      textColor: _parseColor(config.text_color),
                    ),
                    const SizedBox(height: 18),
                    FeatureItem(
                      animation: _feature3Anim,
                      icon: Icons.security,
                      title: config.feature_3_title,
                      description: config.feature_3_description,
                      surfaceColor: _parseColor(config.surface_color),
                      primaryColor: _parseColor(config.primary_action_color),
                      textColor: _parseColor(config.text_color),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _buttonAnim,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - _buttonAnim.value)),
                      child: Opacity(opacity: _buttonAnim.value, child: child),
                    );
                  },
                  child: GetStartedButton(
                    onPressed: _handlePrimaryButtonPress,
                    primaryColor: _parseColor(config.primary_action_color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
