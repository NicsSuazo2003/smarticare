import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/reminder_model.dart';
import 'firebase_options.dart';
import 'screens/login.dart';
import 'screens/register_screen.dart';
import 'screens/personal_screen.dart';
import 'screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'screens/symptom_assessment_provider.dart';
import 'user_session_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Import SharedPreferences and your WelcomeScreen
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart'; // Make sure path matches your project

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter(); // <-- Add this line!
  Hive.registerAdapter(ReminderAdapter());
  await Hive.openBox<Reminder>('remindersBox');
  await FirebaseFirestore.instance.enablePersistence();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SymptomAssessmentProvider()),
        ChangeNotifierProvider(create: (_) => UserSessionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _hasSeenWelcome = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeUserAndInitClinics();
  }

  Future<void> _checkFirstTimeUserAndInitClinics() async {
    final prefs = await SharedPreferences.getInstance();

    // --- HIVE CLINIC DATA INITIALIZATION ---
    final clinicBox = await Hive.openBox('clinicsBox');
    final clinics = clinicBox.get('clinics', defaultValue: []);
    if (clinics.isEmpty) {
      // Use your Firestore fields format here!
      final List<Map<String, String>> defaultClinics = [
        {
          "name": "Arceas Eye Clinic",
          "address": "Poblacion, Sta. Maria, Davao Occidental",
          "contactEmail": "a.534587@umindanao.edu.ph",
          "contactPhone": "09104117984",
          "status": "Active",
          "createdAt": "September 13, 2025 at 2:07:58 AM UTC+8",
          "distance": "0.5 km",
          "hours": "8:00 AM - 5:00 PM",
          "phone": "09104117984",
        },
        // Add more default clinics as needed
      ];
      await clinicBox.put('clinics', defaultClinics);
    }
    // --- END HIVE CLINIC DATA INIT ---

    setState(() {
      _hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);
    setState(() {
      _hasSeenWelcome = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: 'SmartiCare',
      theme: ThemeData(
        primaryColor: const Color(0xFFFF6B6B),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B6B),
          primary: const Color(0xFFFF6B6B),
        ),
      ),
      home: _hasSeenWelcome
          ? const AuthWrapper()
          : WelcomeScreen(
              onSkip: () async {
                await _markWelcomeSeen();
                setState(() {}); // Rebuild to show AuthWrapper
              },
            ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => HomeScreen(),
        '/personal': (context) => PersonalScreen(
              onSkip: () => Navigator.pushReplacementNamed(context, '/home'),
              onNext: () => Navigator.pushReplacementNamed(context, '/home'),
            ),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      return HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}
