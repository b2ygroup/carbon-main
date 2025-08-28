// lib/screens/signup/company_vehicle_screen.dart (NOVO ARQUIVO)

import 'package:carbon/screens/signup/widgets/vehicle_form_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CompanyVehicleScreen extends StatelessWidget {
  final User user;
  const CompanyVehicleScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cadastre um Veículo', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.grey[900],
        automaticallyImplyLeading: false, // Impede o usuário de voltar
      ),
      // Usamos o widget reutilizável que vamos criar no próximo passo
      body: VehicleFormWidget(
        userId: user.uid,
        accountType: 'PJ', // Indica que é um fluxo de cadastro PJ
      ),
    );
  }
}