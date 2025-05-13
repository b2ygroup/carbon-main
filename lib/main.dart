// lib/main.dart (CORRIGIDO const AuthWrapper)
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carbon/firebase_options.dart'; // USA NOME 'carbon'
import 'package:carbon/screens/splash_screen.dart';
import 'package:carbon/screens/auth_screen.dart';
import 'package:carbon/screens/dashboard_screen.dart';
import 'package:carbon/providers/user_provider.dart';

void main() async { WidgetsFlutterBinding.ensureInitialized(); try { await Firebase.initializeApp( options: DefaultFirebaseOptions.currentPlatform ); runApp(const MyApp()); } catch (e) { runApp(ErrorApp(e.toString())); } }

class MyApp extends StatelessWidget { const MyApp({super.key});
  @override Widget build(BuildContext context) { return MultiProvider( providers: [ ChangeNotifierProvider(create: (_) => UserProvider()) ],
      child: MaterialApp( title: 'B2Y Carbon (Base)', theme: ThemeData( brightness: Brightness.dark, primarySwatch: Colors.cyan, useMaterial3: true, textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(bodyColor: Colors.white70), inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
        localizationsDelegates: const [ GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate ],
        supportedLocales: const [ Locale('pt', 'BR') ], locale: const Locale('pt', 'BR'),
        home: const SplashScreen(), debugShowCheckedModeBanner: false ) ); }
}

class AuthWrapper extends StatelessWidget { const AuthWrapper({super.key});
  @override Widget build(BuildContext context) { return StreamBuilder<User?>( stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snapshot.hasError) return Scaffold(body: Center(child: Text("Erro AuthWrapper: ${snapshot.error}")));
        if (snapshot.hasData) { WidgetsBinding.instance.addPostFrameCallback((_) { if (ctx.mounted) Provider.of<UserProvider>(ctx, listen: false).loadUserData(snapshot.data!.uid); });
          // ***** CORREÇÃO: Removido const *****
          return const DashboardScreen();
        } else { WidgetsBinding.instance.addPostFrameCallback((_) { if (ctx.mounted) Provider.of<UserProvider>(ctx, listen: false).clearUserDataOnLogout(); });
          // ***** CORREÇÃO: Removido const *****
          return const AuthScreen();
        }
      } ); }
}
class ErrorApp extends StatelessWidget { final String error; const ErrorApp(this.error, {super.key}); @override Widget build(BuildContext context) => MaterialApp(home: Scaffold(body: Center(child: Text("Erro:\n$error")))); }