import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../home/presentation/home_page.dart';
import '../../permissions/presentation/permission_page.dart';
import 'login_page.dart';

/// AuthGate determines whether to show the Login Screen or proceed to 
/// the Permissions/Profile/Home screens based on authentication and local profile state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirebaseAuthService.isAuthenticated) {
      return const LoginPage();
    }

    // If authenticated, check if emergency profile is already configured
    return ValueListenableBuilder(
      valueListenable: Hive.box('emergency_profile_box').listenable(),
      builder: (context, Box box, _) {
        final profileCompleted = box.get('profile_completed', defaultValue: false);
        if (profileCompleted) {
          return const HomePage();
        } else {
          return const PermissionPage();
        }
      },
    );
  }
}
