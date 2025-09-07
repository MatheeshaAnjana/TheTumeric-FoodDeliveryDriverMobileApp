import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tumeric_indian_cuisine_driver/pages/home_page.dart';
import 'package:tumeric_indian_cuisine_driver/pages/sign_in_page.dart';
import 'package:tumeric_indian_cuisine_driver/pages/wrapper/wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Turmeric Indian Cuisine Driver",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE65100),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: Wrapper(),
    );
  }
}
