// lib/constants.dart
import 'package:flutter/material.dart';

// Emergency Response Colors
const Color ET_RED = Color(0xFFDC2626);
const Color ET_ORANGE = Color(0xFFEA580C);
const Color ET_BLUE = Color(0xFF2563EB);
const Color ET_PURPLE = Color(0xFF7C3AED);
const Color ET_GREEN = Color(0xFF10B981);
const Color ET_YELLOW = Color(0xFFF59E0B);
const Color ET_GRAY = Color(0xFF6B7280);
const Color ET_CYAN = Color(0xFF06B6D4);  
const Color ET_PINK = Color(0xFFEC4899);   

const String API_BASE_URL = 'http://10.0.2.2:5000';
const String API_ALERTS_ENDPOINT = '/api/alerts';

// Current version of the Terms & Conditions / Privacy Policy presented to users.
// Bump this whenever the policy content in terms_policy_screen.dart changes so that
// recorded consent reflects which version each user agreed to.
const String termsVersion = '1.0';