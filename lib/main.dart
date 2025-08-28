// lib/main.dart (VERSÃO FINAL - VERIFIQUE SE O SEU ESTÁ ASSIM)

import 'package:carbon/firebase_options.dart';
import 'package:carbon/providers/trip_provider.dart';
import 'package:carbon/providers/user_provider.dart';
import 'package:carbon/providers/wallet_provider.dart';
import 'package:carbon/screens/auth_gate.dart'; // Agora esta importação vai funcionar
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          primaryColor: const Color(0xFF00BFFF),
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00BFFF),
            secondary: Color(0xFF00FFFF),
            background: Color(0xFF1A1A2E),
            surface: Color(0xFF1E1E3F),
            error: Colors.redAccent,
          ),
          textTheme: ThemeData.dark().textTheme.apply(
                fontFamily: 'Poppins',
              ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('pt', 'BR')],
        locale: const Locale('pt', 'BR'),
        home: const AuthGate(),
      ),
    );
  }
}