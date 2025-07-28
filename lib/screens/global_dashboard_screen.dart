import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlobalDashboardScreen extends StatelessWidget {
  const GlobalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Impacto Global',
          style: GoogleFonts.orbitron(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1c1c1e),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placeholder para o Mapa
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 50, color: Colors.white70),
                    SizedBox(height: 10),
                    Text(
                      'Mapa de Atividade Global (Em Breve)',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Estatísticas da Comunidade',
              style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Divider(color: Colors.cyanAccent, thickness: 0.5, endIndent: 150),
            const SizedBox(height: 16),
            
            // Placeholder para os Indicadores Globais
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: [
                _buildGlobalStatCard(
                  title: 'CO₂ Total Economizado',
                  value: '--- kg',
                  icon: Icons.eco,
                  color: Colors.greenAccent,
                ),
                _buildGlobalStatCard(
                  title: 'KM Sustentáveis Totais',
                  value: '--- km',
                  icon: Icons.drive_eta,
                  color: Colors.blueAccent,
                ),
                _buildGlobalStatCard(
                  title: 'Membros Ativos',
                  value: '---',
                  icon: Icons.people,
                  color: Colors.purpleAccent,
                ),
                _buildGlobalStatCard(
                  title: 'B2Y Coins em Circulação',
                  value: '---',
                  icon: Icons.toll,
                  color: Colors.amberAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para os cartões de estatística
  Widget _buildGlobalStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: const Color(0xFF2D2F41),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.rajdhani(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}