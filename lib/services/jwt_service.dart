import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class JwtService {
  // Secret key for JWT signing
  // ⚠️ WARNING: In production, move token generation to your backend server!
  static const String _secretKey = 'e_telly_app_secret_key_2024';

  /// Generates a valid JWT token (HS256) for a user
  static String generateToken(Map<String, dynamic> userData) {
    final header = {
      'alg': 'HS256',
      'typ': 'JWT',
    };

    final payload = {
      'userId': userData['id'],
      'email': userData['email'],
      'name': userData['fullName'] ?? userData['name'],
      'role': userData['role'] ?? 'resident',
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now()
              .add(const Duration(days: 7))
              .millisecondsSinceEpoch ~/
          1000,
    };

    final encodedHeader = _base64UrlEncode(utf8.encode(jsonEncode(header)));
    final encodedPayload = _base64UrlEncode(utf8.encode(jsonEncode(payload)));
    final signature = _createHmacSignature('$encodedHeader.$encodedPayload');

    final token = '$encodedHeader.$encodedPayload.$signature';
    print('>>> JWT Token generated successfully, length: ${token.length}');
    return token;
  }

  /// Verifies a JWT token — checks signature and expiry
  static bool verifyToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        print('>>> JWT: Invalid token structure');
        return false;
      }

      // 1. Verify signature
      final expectedSignature = _createHmacSignature('${parts[0]}.${parts[1]}');
      if (expectedSignature != parts[2]) {
        print('>>> JWT: Signature mismatch');
        return false;
      }

      // 2. Check expiry
      if (JwtDecoder.isExpired(token)) {
        print('>>> JWT: Token is expired');
        return false;
      }

      print('>>> JWT: Token is valid');
      return true;
    } catch (e) {
      print('>>> JWT verifyToken error: $e');
      return false;
    }
  }

  /// Decodes JWT token payload without verification
  static Map<String, dynamic> decodeToken(String token) {
    return JwtDecoder.decode(token);
  }

  /// Returns the token expiration date
  static DateTime getExpirationDate(String token) {
    return JwtDecoder.getExpirationDate(token);
  }

  /// Checks if a token is expired
  static bool isTokenExpired(String token) {
    return JwtDecoder.isExpired(token);
  }

  // ✅ Proper Base64URL encoding without padding
  static String _base64UrlEncode(List<int> input) {
    return base64Url.encode(input).replaceAll('=', '');
  }

  // ✅ Real HMAC-SHA256 signature using the crypto package
  static String _createHmacSignature(String data) {
    final key = utf8.encode(_secretKey);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return _base64UrlEncode(digest.bytes);
  }
}