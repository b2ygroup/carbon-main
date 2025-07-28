// lib/main.dart (VERSÃO FINAL E COMPLETA)
import 'package:carbon/firebase_options.dart';
import 'package:carbon/providers/trip_provider.dart';
import 'package:carbon/providers/user_provider.dart';
import 'package:carbon/providers/wallet_provider.dart';
import 'package:carbon/screens/auth_screen.dart';
import 'package:carbon/screens/dashboard_screen.dart';
import 'package:carbon/screens/splash_screen.dart';
import 'package:carbon/services/wallet_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Desativa a persistência para forçar a busca de dados do servidor
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );

    if (kIsWeb) {
      try {
        final userCredential = await FirebaseAuth.instance.getRedirectResult();
        if (userCredential.user != null && userCredential.additionalUserInfo?.isNewUser == true) {
          final user = userCredential.user!;
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'fullName': user.displayName, 'email': user.email,
            'createdAt': FieldValue.serverTimestamp(), 'accountType': 'PF', 'isAdmin': false,
          });
          await WalletService().initializeWallet(user.uid);
        }
      } catch (e) {
        // Erro ignorado intencionalmente
      }
    }

    if (!kIsWeb) {
      Stripe.publishableKey = 'pk_test_51RlGaY4Ie0XV5ATGx5aA75CGqomoet2FJPvHRTmit9VjUW6TL7f30Wx1uriWfloIREMlf4LZFry5p5zVAKDEN3Ic00urqBvXdh';
      await Stripe.instance.applySettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
      ],
      child: MaterialApp(
        title: 'B2Y Carbon',
        theme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.cyan,
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF1c1c1e),
            textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
                .apply(bodyColor: Colors.white70),
            inputDecorationTheme:
                const InputDecorationTheme(border: OutlineInputBorder())),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('pt', 'BR')],
        locale: const Locale('pt', 'BR'),
        home: FutureBuilder(
          future: _initialization,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }
            if (snapshot.hasError) {
              return Scaffold(body: Center(child: Text("Erro ao inicializar: ${snapshot.error}")));
            }
            return const AuthWrapper();
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF1c1c1e),
              body: Center(child: CircularProgressIndicator())
            );
          }
          if (snapshot.hasData) {
            final user = snapshot.data!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) {
                // Carrega todos os dados necessários após o login
                Provider.of<UserProvider>(ctx, listen: false).loadUserData(user.uid);
                Provider.of<WalletProvider>(ctx, listen: false).fetchWalletBalance(user.uid);
              }
            });
            return const DashboardScreen();
          }
          return const AuthScreen();
        });
  }
}