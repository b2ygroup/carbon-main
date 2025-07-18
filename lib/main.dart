// lib/main.dart (VERSÃO FINAL E CORRIGIDA)
import 'package:carbon/firebase_options.dart';
import 'package:carbon/providers/user_provider.dart';
import 'package:carbon/screens/auth_screen.dart';
import 'package:carbon/screens/dashboard_screen.dart';
import 'package:carbon/screens/splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

void main() async {
  // Garante que todos os bindings do Flutter e dos pacotes estejam prontos
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // A inicialização do Stripe só acontece se NÃO for a plataforma web.
  if (!kIsWeb) {
    Stripe.publishableKey = 'pk_test_51RlGaY4Ie0XV5ATGx5aA75CGqomoet2FJPvHRTmit9VjUW6TL7f30Wx1uriWfloIREMlf4LZFry5p5zVAKDEN3Ic00urqBvXdh';
    await Stripe.instance.applySettings();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
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
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// O AuthWrapper decide qual tela mostrar: Login ou Dashboard
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          if (snapshot.hasData) {
            final user = snapshot.data!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) {
                Provider.of<UserProvider>(ctx, listen: false).loadUserData(user.uid);
              }
            });
            return const DashboardScreen();
          }
          return const AuthScreen();
        });
  }
}