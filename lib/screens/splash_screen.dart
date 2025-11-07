import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spotto/main.dart'; // Import main.dart to navigate to MainScreen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Wait for 3 seconds
    await Future.delayed(const Duration(milliseconds: 3000), () {});
    
    // Navigate to MainScreen and replace this screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color spottoBlue = Color(0xFF0D6EFD); // Our theme blue

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Our "Logo"
            Text(
              'SPOTTO',
              style: GoogleFonts.inter(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: spottoBlue,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            
            // Our "Tagline"
            Text(
              'Find a spotto',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),
            
            // Loading spinner
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(spottoBlue),
            ),
          ],
        ),
      ),
    );
  }
}