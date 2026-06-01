import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const List<Map<String, String>> antipoloBarangays = [
  {'id': 'bagong_nayon',  'name': 'Bagong Nayon',  'value': 'Bagong Nayon'},
  {'id': 'beverly_hills', 'name': 'Beverly Hills', 'value': 'Beverly Hills'},
  {'id': 'calawis',       'name': 'Calawis',       'value': 'Calawis'},
  {'id': 'cupang',        'name': 'Cupang',         'value': 'Cupang'},
  {'id': 'dalig',         'name': 'Dalig',          'value': 'Dalig'},
  {'id': 'dela_paz',      'name': 'Dela Paz',       'value': 'Dela Paz'},
  {'id': 'inarawan',      'name': 'Inarawan',       'value': 'Inarawan'},
  {'id': 'mambugan',      'name': 'Mambugan',       'value': 'Mambugan'},
  {'id': 'mayamot',       'name': 'Mayamot',        'value': 'Mayamot'},
  {'id': 'munting_dilaw', 'name': 'Munting Dilaw',  'value': 'Munting Dilaw'},
  {'id': 'san_isidro',    'name': 'San Isidro',     'value': 'San Isidro'},
  {'id': 'san_jose',      'name': 'San Jose',       'value': 'San Jose'},
  {'id': 'san_juan',      'name': 'San Juan',       'value': 'San Juan'},
  {'id': 'san_luis',      'name': 'San Luis',       'value': 'San Luis'},
  {'id': 'san_roque',     'name': 'San Roque',      'value': 'San Roque'},
  {'id': 'santa_cruz',    'name': 'Santa Cruz',     'value': 'Santa Cruz'},
];

class SignUpHeader extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onBackPressed;

  const SignUpHeader({
    super.key,
    required this.isLoading,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: isLoading ? null : onBackPressed,
            icon: const Icon(
              Icons.arrow_back,
              size: 24,
              color: Color(0xFFDC2626),
            ),
          ),
          const Text(
            'Create Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 48), // For balance
        ],
      ),
    );
  }
}

class InputField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String fieldName;
  final bool isPassword;
  final bool showPassword;
  final VoidCallback? onTogglePassword;
  final bool isRequired;
  final String? errorText;
  final TextInputType keyboardType;
  final bool enabled;
  final bool isLoading;
  final Function(String, String) onChanged;
  final String? hintText;

  const InputField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    required this.fieldName,
    this.isPassword = false,
    this.showPassword = false,
    this.onTogglePassword,
    this.isRequired = true,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    required this.isLoading,
    required this.onChanged,
    this.hintText,
  });

  String _getHintText(String fieldName) {
    switch (fieldName) {
      case 'name':
        return 'Enter your full name';
      case 'email':
        return 'Enter your email';
      case 'streetDetails':
        return 'House number, street, building, etc.';
      case 'password':
        return '8+ chars, uppercase, number & special char';
      case 'confirmPassword':
        return 'Confirm password';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${isRequired ? '*' : ''}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: EdgeInsets.zero,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText != null ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                icon,
                size: 20,
                color: const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: isPassword && !showPassword,
                  keyboardType: keyboardType,
                  enabled: enabled && !isLoading,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hintText ?? _getHintText(fieldName),
                    hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  onChanged: (value) => onChanged(fieldName, value),
                ),
              ),
              if (isPassword && onTogglePassword != null)
                IconButton(
                  onPressed: enabled && !isLoading ? onTogglePassword : null,
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
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFDC2626),
            ),
          ),
        ],
        if (fieldName == 'password') ...[
          const SizedBox(height: 6),
          const Text(
            'Must be 8+ characters with uppercase, lowercase, number & special character.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
          ),
        ],
      ],
    );
  }
}

class BarangaySelector extends StatelessWidget {
  final String? selectedBarangay;
  final String? barangayError;
  final bool isLoading;
  final VoidCallback onTap;

  const BarangaySelector({
    super.key,
    required this.selectedBarangay,
    required this.barangayError,
    required this.isLoading,
    required this.onTap,
  });

  String _getBarangayDisplayText() {
    return selectedBarangay ?? 'Select barangay';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Barangay*',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isLoading ? null : onTap,
          child: Container(
            margin: EdgeInsets.zero,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: barangayError != null ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getBarangayDisplayText(),
                    style: TextStyle(
                      fontSize: 16,
                      color: selectedBarangay == null
                          ? const Color(0xFF9CA3AF)
                          : Colors.black,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 24,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
        if (barangayError != null) ...[
          const SizedBox(height: 6),
          Text(
            barangayError!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFDC2626),
            ),
          ),
        ],
      ],
    );
  }
}

class BarangayModal extends StatelessWidget {
  final List<Map<String, String>> barangays;
  final String? selectedBarangay;
  final Function(String) onSelect;

  const BarangayModal({
    super.key,
    required this.barangays,
    required this.selectedBarangay,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Barangay',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDC2626),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Color(0xFF666666)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Available for:',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
          ),
          const SizedBox(height: 15),
          ...barangays.map((barangay) {
            final isSelected = selectedBarangay == barangay['value'];
            return GestureDetector(
              onTap: () => onSelect(barangay['value']!),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFDC2626).withOpacity(0.1)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 20,
                      color: isSelected
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF666666),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        barangay['name']!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFFDC2626)
                              : Colors.black,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        size: 20,
                        color: Color(0xFFDC2626),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class SignUpButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const SignUpButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
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
                'Create Account',
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

class TermsAgreement extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTapTerms;
  final String? errorText;
  final bool isLoading;

  const TermsAgreement({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onTapTerms,
    required this.isLoading,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = !isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: enabled ? (v) => onChanged(v ?? false) : null,
                activeColor: const Color(0xFFDC2626),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: BorderSide(
                  color: errorText != null
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF9CA3AF),
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: Colors.black, height: 1.4),
                    children: [
                      const TextSpan(text: 'I have read and agree to the '),
                      TextSpan(
                        text: 'Terms & Conditions and Privacy Policy',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFFDC2626),
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = enabled ? onTapTerms : null,
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFDC2626),
            ),
          ),
        ],
      ],
    );
  }
}

class LoginLink extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const LoginLink({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Already have an account? ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: isLoading ? null : onPressed,
            child: const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
    );
  }
}