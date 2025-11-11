import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/map_screen.dart';
import 'screens/rewards_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const SpottoApp());
}

const Color spottoBlue = Color(0xFF0D6EFD); // This is a clean, standard blue
const Color spottoLightGrey = Color(0xFFF8F9FA); // Off-white for backgrounds
const Color spottoGrey = Color(0xFF6C757D); // For text

class SpottoApp extends StatelessWidget {
  const SpottoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: spottoBlue,
        background: Colors.white,
        primary: spottoBlue,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white, // White background
      textTheme: GoogleFonts.interTextTheme(), // Use "Inter" font everywhere
    );

    return MaterialApp(
      title: 'Spotto',
      theme: base.copyWith(
        // Clean, flat AppBars
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        
        // This is for ALL rounded boxes
        cardTheme: base.cardTheme.copyWith(
          elevation: 0, // No shadows
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            // Add a subtle border like the mockups
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),

        // This is for ALL buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: spottoBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            textStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),

        // Clean up the Bottom Nav Bar
        navigationBarTheme: base.navigationBarTheme.copyWith(
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: spottoBlue.withOpacity(0.1), // The pill shape
          labelTextStyle: WidgetStateProperty.all(
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,


      home: const SplashScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    Builder(
      builder: (context) {
        try {
          return const MapScreen();
        } catch (e) {
          return Scaffold(
            body: Center(
              child: Text('Map Error: $e'),
            ),
          );
        }
      },
    ),
    const RewardsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard_outlined),
            selectedIcon: Icon(Icons.card_giftcard),
            label: 'Rewards',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
