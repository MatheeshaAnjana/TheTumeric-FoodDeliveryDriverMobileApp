import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tumeric_indian_cuisine_driver/pages/home_page.dart';
import 'package:tumeric_indian_cuisine_driver/pages/models/driver.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isEmailLogin = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      DeliveryPersonnelModel? personnel;

      if (_isEmailLogin) {
        personnel = await _firestoreService.loginWithEmail(
          _usernameController.text.trim(),
          _passwordController.text,
        );
      } else {
        personnel = await _firestoreService.loginWithPersonnelId(
          _usernameController.text.trim(),
          _passwordController.text,
        );
      }

      if (personnel != null) {
        if (personnel.isActive) {
          // FIXED: Create Firebase Auth session and save session data
          await _createAuthSession(personnel);

          // Navigate to home page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) => HomePage(personellId: personnel!.personnelId),
            ),
          );
        } else {
          _showErrorDialog(
            'Account Inactive',
            'Your account is inactive. Please contact support.',
          );
        }
      } else {
        _showErrorDialog(
          'Login Failed',
          'Invalid credentials. Please try again.',
        );
      }
    } catch (e) {
      print('Login error: $e');
      _showErrorDialog('Error', 'Login failed: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // FIXED: Create proper authentication session
  Future<void> _createAuthSession(DeliveryPersonnelModel personnel) async {
    try {
      // Option 1: Use Firebase Auth Anonymous + Custom Claims (Recommended)
      UserCredential userCredential = await _auth.signInAnonymously();

      // Save session data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('personnel_id', personnel.personnelId);
      await prefs.setString('user_email', personnel.email);
      await prefs.setString('full_name', personnel.fullName);
      await prefs.setString('firebase_uid', userCredential.user?.uid ?? '');

      // IMPORTANT: Map Firebase UID to Personnel ID for order service
      await prefs.setString(
        'driver_id',
        personnel.id,
      ); // Use Firestore document ID

      print('Session created for ${personnel.fullName}');
      print('Firebase UID: ${userCredential.user?.uid}');
      print('Personnel ID: ${personnel.personnelId}');
      print('Document ID: ${personnel.id}');
    } catch (e) {
      print('Error creating auth session: $e');
      // Fallback to SharedPreferences only
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('personnel_id', personnel.personnelId);
      await prefs.setString('user_email', personnel.email);
      await prefs.setString('full_name', personnel.fullName);
      await prefs.setString('driver_id', personnel.id);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4A300), Color(0xFFFFD166)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Title Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Delivery Driver Login',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Welcome back! Please sign in to continue.',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Login Type Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isEmailLogin = true;
                                });
                                _usernameController.clear();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _isEmailLogin
                                          ? Colors.white
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Email Login',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color:
                                        _isEmailLogin
                                            ? Color(0xFFF4A300)
                                            : Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isEmailLogin = false;
                                });
                                _usernameController.clear();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      !_isEmailLogin
                                          ? Colors.white
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'ID Login',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color:
                                        !_isEmailLogin
                                            ? Color(0xFFF4A300)
                                            : Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Login Form
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Username/Email Field
                          TextFormField(
                            controller: _usernameController,
                            keyboardType:
                                _isEmailLogin
                                    ? TextInputType.emailAddress
                                    : TextInputType.text,
                            decoration: InputDecoration(
                              labelText:
                                  _isEmailLogin
                                      ? 'Email Address'
                                      : 'Personnel ID',
                              hintText:
                                  _isEmailLogin
                                      ? 'Enter your email'
                                      : 'Enter your personnel ID',
                              prefixIcon: Icon(
                                _isEmailLogin ? Icons.email : Icons.badge,
                                color: Color(0xFFF4A300),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFF4A300),
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return _isEmailLogin
                                    ? 'Please enter your email'
                                    : 'Please enter your personnel ID';
                              }
                              if (_isEmailLogin && !value.contains('@')) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: Color(0xFFF4A300),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Color(0xFFF4A300),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFF4A300),
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 30),

                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFF4A300),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                              ),
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Text(
                                        'Login',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Support Contact
                    TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Need Help?'),
                                content: const Text(
                                  'Contact support:\nsupport@tumericindian.com\nPhone: +1-800-TUMERIC',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                        );
                      },
                      child: Text(
                        'Need Help? Contact Support',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
