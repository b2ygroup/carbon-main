// lib/screens/splash_screen.dart (VERSÃO SIMPLIFICADA, SEM LÓGICA)
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';

// MUDANÇA: Convertido para um StatelessWidget.
// A sua única responsabilidade é exibir a UI.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
                    .animate(onPlay: (c) => c.repeat())
                    .moveY(
                      duration: duration.ms,
                      delay: delay.ms,
                      begin: 0,
                      end: -(screenSize.height + 50),
                      curve: Curves.linear,
                    )
                    .fadeOut(duration: duration.ms),
              );
            }),

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  
                  const SizedBox(height: 40),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [primaryColor, greenAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      'A Fintech Verde',
                      style: GoogleFonts.audiowide(
                        fontSize: 22,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 1.5,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: greenAccent.withOpacity(0.4), blurRadius: 10),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 2000.ms, duration: 1000.ms)
                    .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOut)
                    .then(delay: 100.ms)
                    .shimmer(
                      duration: 1800.ms,
                      color: Colors.white,
                      angle: 0.6,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // MUDANÇA: O SpinKitPulse agora não precisa de um controller.
                  SpinKitPulse(
                    color: primaryColor.withOpacity(0.9),
                    size: 40.0,
                  ).animate(onPlay: (c) => c.repeat()).fadeIn(delay: 2600.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}