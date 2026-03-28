import 'package:flutter/material.dart';

class LoginHeader extends StatelessWidget {
  final VoidCallback onBackPressed;

  const LoginHeader({Key? key, required this.onBackPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40, bottom: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onBackPressed,
            icon: const Icon(
              Icons.arrow_back,
              size: 24,
              color: Color(0xFFDC2626),
            ),
          ),
          const Text(
            'Login',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class InputField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? errorText;
  final TextInputType keyboardType;
  final bool isLoading;
  final Function(String)? onChanged;

  const InputField({
    Key? key,
    required this.label,
    required this.icon,
    required this.controller,
    this.errorText,
    this.keyboardType = TextInputType.text,
    required this.isLoading,
    this.onChanged,
  }) : super(key: key);

  String _getHintText() {
    if (label.toLowerCase().contains('email')) {
      return 'Enter your registered email';
    } else if (label.toLowerCase().contains('password')) {
      return 'Enter your password';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText != null
                  ? const Color(0xFFDC2626)
                  : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                icon,
                size: 20,
                color: errorText != null
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  enabled: !isLoading,
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: _getHintText(),
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
          ),
        ],
      ],
    );
  }
}

class PasswordInputField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? errorText;
  final bool isLoading;
  final bool showPassword;
  final VoidCallback onTogglePassword;
  final Function(String)? onChanged;

  const PasswordInputField({
    Key? key,
    required this.label,
    required this.icon,
    required this.controller,
    this.errorText,
    required this.isLoading,
    required this.showPassword,
    required this.onTogglePassword,
    this.onChanged,
  }) : super(key: key);

  String _getHintText() {
    if (label.toLowerCase().contains('password')) {
      return 'Enter your password';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText != null
                  ? const Color(0xFFDC2626)
                  : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                icon,
                size: 20,
                color: errorText != null
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: !showPassword,
                  enabled: !isLoading,
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: _getHintText(),
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                  onChanged: onChanged,
                ),
              ),
              IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  showPassword ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
          ),
        ],
      ],
    );
  }
}

class LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const LoginButton({
    Key? key,
    required this.isLoading,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(
                'Sign In',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const GoogleSignInButton({
    Key? key,
    required this.isLoading,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/google_logo.png', width: 24, height: 24),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpPrompt extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSignUpPressed;

  const SignUpPrompt({
    Key? key,
    required this.isLoading,
    required this.onSignUpPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(fontSize: 14, color: Colors.black),
        ),
        GestureDetector(
          onTap: isLoading ? null : onSignUpPressed,
          child: const Text(
            'Sign Up',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFFDC2626),
            ),
          ),
        ),
      ],
    );
  }
}
