// lib/screens/fleet_management_screen.dart (Placeholder)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carbon/screens/registration_screen.dart'; // CONFIRME NOME PACOTE

class FleetManagementScreen extends StatelessWidget {
  const FleetManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Implementar busca e exibição da frota
    return Scaffold(
      appBar: AppBar( title: Text('Gerenciar Frota', style: GoogleFonts.rajdhani()), actions: [ IconButton( icon: const Icon(Icons.add_circle_outline), tooltip: 'Adicionar Veículo', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const RegistrationScreen())) ) ] ),
      body: Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.construction_rounded, size: 60, color: Colors.amber[300]), const SizedBox(height: 20),
            const Text( 'Gerenciamento de Frota (Em Construção)', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)), const SizedBox(height: 15),
            Text( 'Visualize, edite ou remova veículos da sua conta.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
            // TODO: Adicionar StreamBuilder/ListView aqui
          ], ), ), ), );
  }
}