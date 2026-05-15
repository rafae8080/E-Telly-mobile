import 'package:google_sign_in/google_sign_in.dart';
import 'auth_service.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: '927012189317-ljjmpf3d0c4ssatebm8sv3ht0rt9eml3.apps.googleusercontent.com',
  );
  
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>?> signIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final userData = {
        'userId': googleUser.id,
        'email': googleUser.email,
        'displayName': googleUser.displayName ?? googleUser.email,
        'photoUrl': googleUser.photoUrl,
        'authProvider': 'google',
      };

      await _authService.saveAuthData(
        token: googleAuth.idToken ?? 'temp_token',
        userData: userData,
      );

      return userData;
    } catch (e) {
      print('Google Sign-in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _authService.logout();
  }
}