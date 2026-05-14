import 'package:flutter/material.dart';

class LogoSection extends StatelessWidget {
  final String appTitle;
  final String tagline;
  final Color textColor;

  const LogoSection({
    super.key,
    required this.appTitle,
    required this.tagline,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Transform.translate(
          offset: const Offset(0, -30),
          child: Image.asset(
            'assets/images/logo3.png',
            width: 240,
            height: 240,
            fit: BoxFit.contain,
          ),
        ),
        Text(
          appTitle,
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: textColor,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          tagline,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class FeatureItem extends StatelessWidget {
  final Animation<double> animation;
  final IconData icon;
  final String title;
  final String description;
  final Color surfaceColor;
  final Color primaryColor;
  final Color textColor;

  const FeatureItem({
    super.key,
    required this.animation,
    required this.icon,
    required this.title,
    required this.description,
    required this.surfaceColor,
    required this.primaryColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 32,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF333333),
                    height: 1.375,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GetStartedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color primaryColor;

  const GetStartedButton({
    super.key,
    required this.onPressed,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          elevation: 8,
          shadowColor: primaryColor.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
        child: const Text(
          'Get Started',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}