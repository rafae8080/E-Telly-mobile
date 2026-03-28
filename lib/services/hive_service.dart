import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static Box get userSessionBox => Hive.box('user_session');
  
  static Future<void> saveUserSession({
    required String userId,
    required String email,
    required String name,
  }) async {
    final box = userSessionBox;
    await box.put('userId', userId);
    await box.put('email', email);
    await box.put('name', name);
    await box.put('isLoggedIn', true);
    await box.put('loginTime', DateTime.now().toIso8601String());
    print('User session saved: $name');
  }
  
  static Map<String, dynamic>? getUserSession() {
    final box = userSessionBox;
    if (!isLoggedIn()) return null;
    
    return {
      'userId': box.get('userId'),
      'email': box.get('email'),
      'name': box.get('name'),
      'loginTime': box.get('loginTime'),
    };
  }
  
  static bool isLoggedIn() {
    final box = userSessionBox;
    return box.get('isLoggedIn', defaultValue: false);
  }
  
  static String getUserName() {
    final box = userSessionBox;
    return box.get('name', defaultValue: 'User');
  }
  
  static String getUserEmail() {
    final box = userSessionBox;
    return box.get('email', defaultValue: '');
  }
  
  static Future<void> logout() async {
    final box = userSessionBox;
    await box.clear();
    print('User logged out');
  }
}