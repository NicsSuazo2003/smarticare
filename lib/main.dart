import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/Screens/latest_scan_cache.dart';
import 'package:flutter_application_1/reminder_model.dart';
import 'package:flutter_application_1/services/offline_sync_service.dart';
import 'firebase_options.dart';
import 'screens/login.dart';
import 'screens/register_screen.dart';
import 'screens/personal_screen.dart';
import 'screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'screens/symptom_assessment_provider.dart';
import 'user_session_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'screens/complete_profile_screen.dart';

// ✅ ADD THIS IMPORT
import 'package:flutter_application_1/services/one_time_scan_migration.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling background message: ${message.messageId}');
}

Future<void> saveTokenToFirestore(String uid) async {
  try {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('⚠️ No internet, token save deferred');
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      print('FCM Token saved: $token');
    }
  } catch (e) {
    print('Error saving FCM token: $e');
  }
}

Future<void> requestNotificationPermission() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('⚠️ User granted provisional permission');
    } else {
      print('❌ User declined notification permission');
    }
  } catch (e) {
    print('Error requesting notification permission: $e');
  }
}

Future<void> initializeLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    ),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print('Notification clicked: ${response.payload}');
    },
  );
}

Future<void> enableFirestoreOfflineMode() async {
  try {
    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      print('✅ Firestore offline mode enabled');
    } else {
      await FirebaseFirestore.instance.enablePersistence(
        const PersistenceSettings(synchronizeTabs: true),
      );
      print('✅ Firestore web persistence enabled');
    }
  } catch (e) {
    print('⚠️ Firestore persistence error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');

    await enableFirestoreOfflineMode();

    tz.initializeTimeZones();
    print('✅ Timezone initialized');

    await initializeLocalNotifications();
    print('✅ Local notifications initialized');

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await Hive.initFlutter();
    Hive.registerAdapter(ReminderAdapter());

    // ✅ Open all Hive boxes
    await Hive.openBox<Reminder>('remindersBox');
    await Hive.openBox('clinicsBox');
    await Hive.openBox('scansBox');
    await Hive.openBox('userProfileBox');
    await Hive.openBox('syncQueueBox');
    await Hive.openBox<Map>('latestScansCache'); // ✅ ADD THIS LINE
    print('✅ Hive initialized with all boxes');

    // ✅ ADD THIS:  Initialize LatestScanCache
    await LatestScanCache.initialize();
    print('✅ LatestScanCache initialized');

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SymptomAssessmentProvider()),
          ChangeNotifierProvider(create: (_) => UserSessionProvider()),
          ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    print('❌ Error during initialization: $e');
    print(stackTrace);

    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to initialize app',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  ConnectivityProvider() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    notifyListeners();

    Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      if (!wasOnline && _isOnline) {
        print('🌐 Back online - syncing data...');
        _syncPendingData();
      } else if (wasOnline && !_isOnline) {
        print('📴 Gone offline');
      }

      notifyListeners();
    });
  }

  Future<void> _syncPendingData() async {
    try {
      await OfflineSyncService().syncAllPendingData();
      print('✅ All pending data synced via OfflineSyncService');
    } catch (e) {
      print('❌ Error syncing data: $e');
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _hasSeenWelcome = false;
  bool _isAuthenticated = false;
  bool _needsProfileCompletion = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeUserAndInitClinics();
    _setupForegroundNotifications();
  }

  void _setupForegroundNotifications() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Foreground message received: ${message.notification?.title}');

      if (message.notification != null) {
        flutterLocalNotificationsPlugin.show(
          message.hashCode,
          message.notification!.title,
          message.notification!.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'reminder_channel',
              'Reminders',
              channelDescription: 'Notifications for reminders and updates',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: message.data['payload'],
        );
      }
    });
  }

  Future<void> _checkFirstTimeUserAndInitClinics() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final user = FirebaseAuth.instance.currentUser;
      final isAuthenticated = user != null;

      print('🔍 hasSeenWelcome: ${prefs.getBool('hasSeenWelcome')}');
      print('🔍 Current User: ${user?.email ?? "No user"}');
      print('🔍 isAuthenticated: $isAuthenticated');

      final clinicBox = await Hive.openBox('clinicsBox');
      final clinics = clinicBox.get('clinics', defaultValue: []);

      if (clinics.isEmpty) {
        final List<Map<String, String>> defaultClinics = [
          {
            "name": "Arceas Eye Clinic",
            "address": "Poblacion, Sta. Maria, Davao Occidental",
            "contactEmail": "a.534587@umindanao.edu.ph",
            "contactPhone": "09104117984",
            "status": "Active",
            "createdAt": "2025-09-13T02:07:58.000Z",
            "distance": "0.5 km",
            "hours": "8:00 AM - 5:00 PM",
            "phone": "09104117984",
          },
        ];
        await clinicBox.put('clinics', defaultClinics);
        print('✅ Default clinics initialized');
      }

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        await requestNotificationPermission();

        if (user != null) {
          await saveTokenToFirestore(user.uid);
        }
      }

      bool needsProfile = false;
      if (isAuthenticated && user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (!userDoc.exists) {
            needsProfile = true;
            print('ℹ️ Authenticated user requires profile completion');
          } else {
            needsProfile = false;
          }
        } catch (e) {
          print('Error checking user profile existence: $e');
          needsProfile = false;
        }
      }

      setState(() {
        _hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;
        _isAuthenticated = isAuthenticated;
        _needsProfileCompletion = needsProfile;
        _isLoading = false;
      });
    } catch (e) {
      print('Error during initialization: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);
    setState(() {
      _hasSeenWelcome = true;
    });
  }

  Widget _determineHomeWidget() {
    if (_isAuthenticated) {
      if (_needsProfileCompletion) {
        final user = FirebaseAuth.instance.currentUser!;
        final displayName = user.displayName ?? '';
        String firstName = '';
        String lastName = '';
        if (displayName.isNotEmpty) {
          final parts = displayName.split(' ');
          firstName = parts.isNotEmpty ? parts.first : '';
          lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }
        return CompleteProfileScreen(
          uid: user.uid,
          email: user.email ?? '',
          firstName: firstName,
          lastName: lastName,
        );
      }

      print('✅ User authenticated - showing HomeScreen');
      return const HomeScreen();
    } else {
      if (!_hasSeenWelcome) {
        print('📖 Showing WelcomeScreen');
        return WelcomeScreen(
          onSkip: () async {
            await _markWelcomeSeen();
            setState(() {});
          },
        );
      } else {
        print('🔐 Showing LoginScreen');
        return const LoginScreen();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/icon.png',
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  color: Color(0xFFFF6B6B),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Loading SmartiCare...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartiCare',
      theme: ThemeData(
        primaryColor: const Color(0xFFFF6B6B),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B6B),
          primary: const Color(0xFFFF6B6B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            Consumer<ConnectivityProvider>(
              builder: (context, connectivity, _) {
                if (!connectivity.isOnline) {
                  return Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Offline Mode - Data will sync when online',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        );
      },
      home: _determineHomeWidget(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/personal': (context) => PersonalScreen(
              onSkip: (ctx) {
                final user = FirebaseAuth.instance.currentUser;
                Navigator.pushNamedAndRemoveUntil(
                  ctx,
                  user == null ? '/login' : '/home',
                  (route) => false,
                );
              },
              onNext: (ctx) {
                final user = FirebaseAuth.instance.currentUser;
                Navigator.pushNamedAndRemoveUntil(
                  ctx,
                  user == null ? '/login' : '/home',
                  (route) => false,
                );
              },
            ),
      },
    );
  }
}
