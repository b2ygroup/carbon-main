// lib/screens/premium_screen.dart (CÓDIGO COMPLETO)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('B2Y Carbon Pro', style: GoogleFonts.orbitron()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Desbloqueie todo o potencial da plataforma.',
              style: GoogleFonts.poppins(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Com o plano Pro, você tem acesso a ferramentas exclusivas para maximizar seu impacto e seus ganhos.',
              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
            ),
            const Divider(height: 40, color: Colors.white24),

            _buildFeatureTile(Icons.analytics, 'Relatórios Avançados', 'Acesse dashboards detalhados do seu histórico de emissões e economia.'),
            _buildFeatureTile(Icons.speed, 'Precisão Aumentada', 'Use fatores de emissão específicos para o modelo do seu veículo.'),
            _buildFeatureTile(Icons.groups, 'Modo Competição', 'Compare seu desempenho com amigos e suba no ranking de sustentabilidade.'),
            _buildFeatureTile(Icons.no_accounts, 'Experiência Sem Anúncios', 'Navegue pelo aplicativo sem interrupções.'),
            
            const SizedBox(height: 40),

            _buildSubscriptionCard(
              context,
              title: 'Plano Anual',
              price: 'R\$ 99,90',
              period: '/ano',
              highlightText: 'Melhor Custo-Benefício',
              isHighlighted: true,
            ),
            const SizedBox(height: 16),
            _buildSubscriptionCard(
              context,
              title: 'Plano Mensal',
              price: 'R\$ 9,90',
              period: '/mês',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Icon(icon, color: Colors.cyanAccent, size: 30),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.7))),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, {required String title, required String price, required String period, String? highlightText, bool isHighlighted = false}) {
    return Card(
      elevation: isHighlighted ? 8 : 2,
      color: isHighlighted ? Colors.cyan.withOpacity(0.15) : Colors.grey[850]?.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isHighlighted ? Colors.cyanAccent : Colors.transparent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (highlightText != null)
              Chip(label: Text(highlightText), backgroundColor: Colors.cyanAccent, labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.poppins(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(price, style: GoogleFonts.orbitron(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold)),
                Text(period, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7))),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Funcionalidade de pagamento em desenvolvimento.'))
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isHighlighted ? Colors.cyanAccent : Colors.grey[700],
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Assinar Agora', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}