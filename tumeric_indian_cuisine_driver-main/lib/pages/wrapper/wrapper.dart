import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tumeric_indian_cuisine_driver/pages/home_page.dart';
import 'package:tumeric_indian_cuisine_driver/pages/sign_in_page.dart';

import 'package:tumeric_indian_cuisine_driver/widgets/driver_state_manager.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String _personnelId = '';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final personnelId = prefs.getString('personnel_id') ?? '';
      final userEmail = prefs.getString('user_email');

      final hasValidSession =
          isLoggedIn && (personnelId.isNotEmpty || userEmail != null);

      // if (hasValidSession) {
      //   // Initialize driver state manager
      //   final driverStateManager = Provider.of<DriverStateManager>(
      //     context,
      //     listen: false,
      //   );
      //   await driverStateManager.initializeDriverState();
      // }

      setState(() {
        _isLoggedIn = hasValidSession;
        _personnelId = personnelId;
        _isLoading = false;
      });

      print(
        'Login check: isLoggedIn=$hasValidSession, personnelId=$personnelId, email=$userEmail',
      );
    } catch (e) {
      print('Error checking login status: $e');
      setState(() {
        _isLoggedIn = false;
        _personnelId = '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF667eea)),
              SizedBox(height: 16),
              Text('Loading Tumeric Driver...'),
            ],
          ),
        ),
      );
    }

    if (_isLoggedIn) {
      return HomePage(personellId: _personnelId);
    } else {
      return const LoginPage();
    }
  }
}
