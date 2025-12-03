import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:k_verse/firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'models/user.dart';
import 'repositories/announcement_repository.dart';
import 'screens/adminstrators/adminstrator.dart';
import 'screens/login.dart';
import 'screens/register.dart';
import 'screens/home.dart';
import 'screens/splash_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'viewmodels/announcement_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/user_viewmodel.dart';
import 'services/notification_service.dart';
import 'screens/select_widget_wallpaper.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  print("🔵 Background message received: ${message.messageId}");
  print("🔵 Notification data: ${message.data}");
  print("🔵 Notification title: ${message.notification?.title}");
  print("🔵 Notification body: ${message.notification?.body}");

  await _showNotificationFromMessage(message);
}

Future<void> _showNotificationFromMessage(RemoteMessage message) async {
  final notification = message.notification;
  final data = message.data;

  if (notification != null) {
    await NotificationService.showNotification(
      title: notification.title ?? 'New Message',
      body: notification.body ?? 'You have a new message',
      payload: data.toString(),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.initialize();

  await _setupFCM();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('ko'),
        Locale('ja'),
        Locale('zh'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const ProviderScope(child: MyApp()),
    ),
  );
}

Future<void> _setupFCM() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    print('📱 Notification permission: ${settings.authorizationStatus}');

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print("🟢 FOREGROUND MESSAGE RECEIVED");
      print("🟢 Message ID: ${message.messageId}");
      print("🟢 Data: ${message.data}");
      print(
        "🟢 Notification: ${message.notification?.title} - ${message.notification?.body}",
      );

      await _showNotificationFromMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("🟠 APP OPENED FROM NOTIFICATION");
      print("🟠 Data: ${message.data}");
      _handleNotificationNavigation(message);
    });

    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      print("🔴 INITIAL MESSAGE FOUND");
      print("🔴 Data: ${initialMessage.data}");
      _handleNotificationNavigation(initialMessage);
    }

    String? token = await messaging.getToken();
    print("🎫 FCM TOKEN: $token");

    messaging.onTokenRefresh.listen((newToken) {
      print("🔄 TOKEN REFRESHED: $newToken");

      _sendTokenToServer(newToken);
    });

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    print("✅ FCM setup completed");
  } catch (e) {
    print("❌ FCM setup error: $e");
  }
}

void _handleNotificationNavigation(RemoteMessage message) {
  final data = message.data;

  if (data['type'] == 'chat') {
    print('Navigate to chat: ${data['chatId']}');
  } else if (data['type'] == 'news') {
    print('Navigate to news: ${data['newsId']}');
  } else if (data['type'] == 'profile') {
    print('Navigate to profile: ${data['userId']}');
  }
}

void _sendTokenToServer(String token) {
  print("📤 Send token to server: $token");
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);

    return provider.MultiProvider(
      providers: [
        provider.Provider(create: (_) => AnnouncementRepository()),
        provider.ChangeNotifierProvider(create: (_) => AuthViewModel()),
        provider.ChangeNotifierProvider(create: (_) => UserViewModel()),
        provider.ChangeNotifierProvider(
          create: (context) =>
              AnnouncementViewModel(context.read<AnnouncementRepository>()),
        ),
        provider.ChangeNotifierProvider(
          create: (context) => ManageAnnouncementViewModel(
            context.read<AnnouncementRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'K-Verse',
        theme: _buildTheme(themeState),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name!);

          if (uri.pathSegments.length == 2 &&
              uri.pathSegments.first == "selectWidgetWallpaper") {
            final id = int.parse(uri.pathSegments[1]);
            return MaterialPageRoute(
              builder: (_) => SelectWidgetWallpaperScreen(widgetId: id),
            );
          }

          return null;
        },
        home: provider.Consumer(
          builder: (context, ref, child) {
            final authViewModel = provider.Provider.of<AuthViewModel>(context);

            return StreamBuilder<Users?>(
              stream: authViewModel.userStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return LoginScreen();
                }

                final userData = snapshot.data!;

                switch (userData.role.toLowerCase()) {
                  case 'admin':
                    return AdminstratorScreen();
                  default:
                    return HomeScreen();
                }
              },
            );
          },
        ),
      ),
    );
  }

  ThemeData _buildTheme(ThemeState themeState) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: themeState.scaffoldBackgroundColor,
      primaryColor: themeState.primaryColor,
      appBarTheme: AppBarTheme(
        backgroundColor: themeState.appBarColor,
        foregroundColor: _getContrastColor(themeState.appBarColor),
        elevation: 0,
        iconTheme: IconThemeData(
          color: _getContrastColor(themeState.appBarColor),
        ),
      ),
      colorScheme: ColorScheme.light(
        primary: themeState.primaryColor,
        onPrimary: _getContrastColor(themeState.primaryColor),
        secondary: themeState.secondaryColor,
        onSecondary: _getContrastColor(themeState.secondaryColor),
        background: themeState.scaffoldBackgroundColor,
        surface: themeState.scaffoldBackgroundColor,
        onBackground: _getContrastColor(themeState.scaffoldBackgroundColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: themeState.primaryColor,
          foregroundColor: _getContrastColor(themeState.primaryColor),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: themeState.primaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: themeState.scaffoldBackgroundColor,
        unselectedLabelColor: _getContrastColor(
          themeState.scaffoldBackgroundColor,
        ),
        indicator: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: themeState.primaryColor, width: 2.0),
          ),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: themeState.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _getContrastColor(themeState.scaffoldBackgroundColor),
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: _getContrastColor(
            themeState.scaffoldBackgroundColor,
          ).withOpacity(0.8),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: themeState.primaryColor,
        foregroundColor: _getContrastColor(themeState.primaryColor),
      ),
      cardTheme: CardThemeData(
        color: _getCardColor(themeState.scaffoldBackgroundColor),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: themeState.scaffoldBackgroundColor,
        selectedItemColor: themeState.primaryColor,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  Color _getContrastColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
  }

  Color _getCardColor(Color backgroundColor) {
    double luminance = backgroundColor.computeLuminance();
    if (luminance > 0.8) return Colors.white;
    if (luminance < 0.2) return Colors.grey;
    return backgroundColor.withOpacity(0.9);
  }
}
