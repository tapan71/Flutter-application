import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import '../home_screen.dart';
import '../worker/worker_dashboard_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (authService.isInitializingSession) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking session...'),
            ],
          ),
        ),
      );
    }

    final user = authService.currentUser;
    if (user == null) {
      return const LoginScreen();
    }

    switch (user.role) {
      case UserRole.worker:
        return const WorkerDashboardScreen();
      case UserRole.customer:
        return const HomeScreen();
    }
  }
}
