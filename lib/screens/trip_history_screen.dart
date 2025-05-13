// lib/screens/trip_history_screen.dart (Revisado com Import e Correções)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:carbon/models/vehicle_type_enum.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart'; // <<< IMPORT ADICIONADO

class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({super.key});

  // Função auxiliar para construir cada linha de detalhe
  Widget _buildDetailRow(IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor.withOpacity(0.8)),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.end,),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final Color accentColor = Colors.cyanAccent[400]!;
    final Color cardBgColor = Colors.grey[850]!.withOpacity(0.5);
    final Color primaryTextColor = Colors.white.withOpacity(0.9);
    final Color secondaryTextColor = Colors.white.withOpacity(0.7);
    final Color co2Color = Colors.greenAccent[400]!;
    final Color creditsColor = Colors.lightGreenAccent[400]!;

    if (user == null) {
      return Scaffold( appBar: AppBar(title: const Text('Histórico de Viagens')), body: const Center(child: Text('Erro: Usuário não autenticado.')), );
    }
    final String userId = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico de Viagens', style: GoogleFonts.orbitron()),
        backgroundColor: Colors.transparent, elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar histórico: ${snapshot.error}', style: TextStyle(color: theme.colorScheme.error)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
             return Center(child: Text('Nenhuma viagem encontrada.', style: TextStyle(color: secondaryTextColor)));
          }

          final tripDocs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: tripDocs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tripData = tripDocs[index].data() as Map<String, dynamic>;

              final DateTime? startTime = (tripData['startTime'] as Timestamp?)?.toDate();
              final double distanceKm = (tripData['distanceKm'] as num?)?.toDouble() ?? 0.0;
              final double co2SavedKg = (tripData['co2SavedKg'] as num?)?.toDouble() ?? 0.0;
              final double creditsEarned = (tripData['creditsEarned'] as num?)?.toDouble() ?? 0.0;
              final int durationMinutes = (tripData['durationMinutes'] as num?)?.toInt() ?? 0;
              final String origin = tripData['origin'] ?? '-'; // Usar '-' se nulo
              final String destination = tripData['destination'] ?? '-'; // Usar '-' se nulo
              final String vehicleTypeStr = tripData['vehicleType'] ?? '';
              final VehicleType? vehicleType = vehicleTypeFromString(vehicleTypeStr);
              final String calculationMethod = tripData['calculationMethod'] ?? 'gps';

              final String formattedDate = startTime != null ? DateFormat('dd/MM/yy').format(startTime) : '?';
              final String formattedTime = startTime != null ? DateFormat('HH:mm').format(startTime) : '?';
              final String durationStr = durationMinutes > 0 ? '$durationMinutes min' : (calculationMethod == 'manual_route' ? 'Calc.' : '?');

              return Card(
                elevation: 3, color: cardBgColor,
                shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[700]!, width: 0.5) ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Linha 1: Data, Hora, Duração e Tipo Veículo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [ Icon(Icons.calendar_today, size: 14, color: secondaryTextColor), const SizedBox(width: 4), Text('$formattedDate às $formattedTime', style: TextStyle(fontSize: 13, color: primaryTextColor)), ],),
                          Row(children: [ Icon(vehicleType?.icon ?? Icons.directions_car, size: 16, color: vehicleType?.displayColor ?? secondaryTextColor), const SizedBox(width: 4), Text(durationStr, style: TextStyle(fontSize: 12, color: secondaryTextColor)), ],)
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Linha 2: Origem -> Destino (se houver)
                      if(origin != '-' || destination != '-')
                       Text( '$origin ➔ $destination', style: TextStyle(color: secondaryTextColor, fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1,),
                      Divider(height: 16, color: Colors.grey[700]),

                      // Detalhes em linhas separadas
                      _buildDetailRow(Icons.route_outlined, "Distância", '${distanceKm.toStringAsFixed(1)} km', accentColor),
                      _buildDetailRow(Icons.eco, "CO₂ Salvo", '${co2SavedKg.toStringAsFixed(2)} kg', co2Color),
                      _buildDetailRow(Icons.toll, "Créditos", creditsEarned.toStringAsFixed(4), creditsColor),

                    ],
                  ),
                ),
              ).animate().fadeIn(delay: (50 * index).ms); // <<< Animação deve funcionar agora
            },
          );
        },
      ),
    );
  }
}