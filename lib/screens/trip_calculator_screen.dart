// lib/screens/trip_calculator_screen.dart (Placeholder Inicial)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carbon/widgets/trip_calculator_widget.dart'; // Importa o widget real

class TripCalculatorScreen extends StatelessWidget {
  const TripCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calcular Rota Manual', style: GoogleFonts.rajdhani()),
      ),
      // Usa o widget que já tínhamos, agora dentro de uma tela dedicada
      // Envolve com SingleChildScrollView para garantir que cabe em telas menores
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: TripCalculatorWidget(), // Reutiliza o widget existente
      ),
    );
  }
}