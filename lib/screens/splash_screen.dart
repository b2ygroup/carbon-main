import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carbon/main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _navigateToNextScreen();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() {
    Timer(const Duration(milliseconds: 4500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final random = Random();
    const primaryColor = Color(0xFF00FFFF);
    const greenAccent = Color(0xFF00FFAA);
    const backgroundGradient = LinearGradient(
      colors: [Color(0xFF001018), Color(0xFF003843)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: backgroundGradient),
        child: Stack(
          children: [
            // 💨 EFEITO DE PARTÍCULAS SUBINDO
            ...List.generate(35, (index) {
              final delay = random.nextInt(3000);
              final duration = random.nextInt(4000) + 2000;
              final size = random.nextDouble() * 2 + 1;
              return Positioned(
                left: random.nextDouble() * screenSize.width,
                bottom: -50,
                child: CircleAvatar(
                  radius: size,
                  backgroundColor:
                      greenAccent.withOpacity(random.nextDouble() * 0.6 + 0.3),
                )
                    .animate()
                    .moveY(
                      duration: duration.ms,
                      delay: delay.ms,
                      begin: 0,
                      end: -(screenSize.height + 50),
                      curve: Curves.easeInOut,
                    )
                    .fadeOut(duration: duration.ms),
              );
            }),

            // 🔥 ÍCONE CENTRAL FUTURISTA (LEAF + CO2 + CARRO)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glow Icon Stack
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.eco, size: 90, color: greenAccent.withOpacity(0.3))
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(end: 1.1, duration: 1500.ms),
                      const Icon(Icons.co2, size: 50, color: primaryColor),
                      Positioned(
                        bottom: -12,
                        child: Icon(Icons.electric_car,
                            size: 38, color: Colors.white.withOpacity(0.8))
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .slideX(begin: -0.1, end: 0.1, duration: 1800.ms),
                      )
                    ],
                  ).animate().fadeIn(duration: 1000.ms).scale(),

                  const SizedBox(height: 30),

                  // 🔷 NOME DO APP
                  Text(
                    'B2Y Carbon',
                    style: GoogleFonts.orbitron(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: primaryColor.withOpacity(0.6), blurRadius: 20),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 1000.ms)
                      .slideY(begin: 0.5)
                      .shimmer(duration: 1500.ms, color: greenAccent.withOpacity(0.4)),

                  const SizedBox(height: 14),

                  // 💬 SLOGAN
                  Text(
                    'Dirija, ganhe dinheiro e contribua com o meio ambiente',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.85),
                    ),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: 1400.ms, delay: 800.ms)
                      .slideY(begin: 0.4),

                  const SizedBox(height: 60),

                  // 🔄 Loading Spinner
                  SpinKitPulse(
                    controller: _controller,
                    color: primaryColor.withOpacity(0.9),
                    size: 40.0,
                  ).animate().fadeIn(delay: 2600.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
