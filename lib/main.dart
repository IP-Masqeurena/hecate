
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hecate/pages/home_page.dart';
import 'package:hecate/pages/login_page.dart';
import 'package:hecate/pages/settings_page.dart';
import 'package:hecate/services/auth_service.dart';
import 'package:hecate/services/firebase_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDark') ?? false;
  runApp(MyApp(isDark: isDark));
}

class ThemeModel extends ChangeNotifier {
  ThemeMode _mode;
  ThemeModel(this._mode);

  ThemeMode get mode => _mode;

  void toggle() async {
    _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDark', _mode == ThemeMode.dark);
  }

  void setMode(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDark', _mode == ThemeMode.dark);
  }
}

class MyApp extends StatelessWidget {
  final bool isDark;
  const MyApp({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final lightBlue = Colors.lightBlue.shade400;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => ThemeModel(isDark ? ThemeMode.dark : ThemeMode.light)),
      ],
      child: Consumer<ThemeModel>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'Period Predictor',
            themeMode: theme.mode,
            theme: ThemeData(
              brightness: Brightness.light,
              primaryColor: lightBlue,
              colorScheme: ColorScheme.fromSeed(seedColor: lightBlue),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: lightBlue,
              colorScheme: ColorScheme.fromSeed(seedColor: lightBlue, brightness: Brightness.dark),
              useMaterial3: true,
            ),
            home: AuthWrapper(),
            routes: {
              SettingsPage.routeName: (_) => SettingsPage(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return StreamBuilder(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          // user signed in
          final uid = snapshot.data!.uid;
          // initialize FirestoreService with uid
          Provider.of<FirestoreService>(context, listen: false).setUser(uid);
          return HomePage();
        } else {
          return LoginPage();
        }
      },
    );
  }
}
