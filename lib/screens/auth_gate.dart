// lib/screens/auth_gate.dart (Com Duração Ajustada)

import 'package:carbon/providers/user_provider.dart';
import 'package:carbon/providers/wallet_provider.dart';
import 'package:carbon/screens/auth_screen.dart';
import 'package:carbon/screens/dashboard_screen.dart';
import 'package:carbon/screens/splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showSplashScreen = true;

  @override
  void initState() {
    super.initState();
    // MUDANÇA: Aumentei a duração de 3 para 6 segundos.
    // Isso dará tempo para todas as suas animações, incluindo a última, serem executadas.
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _showSplashScreen = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplashScreen) {
      return const SplashScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final user = snapshot.data!;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Provider.of<UserProvider>(context, listen: false).loadUserData(user.uid);
              Provider.of<WalletProvider>(context, listen: false).fetchWalletBalance(user.uid);
            }
          });

          return const DashboardScreen();
        }

        return const AuthScreen();
      },
    );
  }
}