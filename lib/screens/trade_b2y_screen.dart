// lib/screens/trade_b2y_screen.dart (VERSÃO COMPLETA, ESTILO TRADING)

import 'package:carbon/models/sell_order_model.dart';
import 'package:carbon/screens/sell_coins_screen.dart';
import 'package:carbon/widgets/dashboard/buy_order_bottom_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Widget para os cards de indicadores no topo da tela
class TradeIndicatorCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const TradeIndicatorCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: Colors.grey[850],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.rajdhani(color: Colors.white70, fontSize: 14),
                  ),
                  Icon(icon, color: color, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TradeB2YScreen extends StatefulWidget {
  const TradeB2YScreen({super.key});

  @override
  State<TradeB2YScreen> createState() => _TradeB2YScreenState();
}

class _TradeB2YScreenState extends State<TradeB2YScreen> {
  final _coinFormatter = NumberFormat("#,##0", "pt_BR");
  final _currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  final Stream<QuerySnapshot> _sellOrdersStream = FirebaseFirestore.instance
      .collection('sell_orders')
      .where('status', isEqualTo: 'active')
      .orderBy('pricePerCoin', descending: false)
      .snapshots();

  // Método para mostrar a tela de confirmação de compra
  void _showPurchaseConfirmation(SellOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return BuyOrderBottomSheet(sellOrder: order);
      },
    ).then((success) {
      // Exibe uma mensagem de sucesso se a compra for confirmada
      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Compra realizada com sucesso!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            "B2Y Trade",
            style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 22),
          ).animate().fadeIn(delay: 200.ms).shimmer(duration: 2000.ms),
          elevation: 0,
        ),
        body: Column(
          children: [
            // Seção de Indicadores
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  TradeIndicatorCard(title: "Preço Médio", value: "R\$ 0,25", icon: Icons.show_chart, color: Colors.cyanAccent),
                  SizedBox(width: 8),
                  TradeIndicatorCard(title: "Volume 24h", value: "10.5K", icon: Icons.bar_chart, color: Colors.greenAccent),
                ],
              ),
            ),
            
            // Seção do Gráfico (Placeholder)
            Container(
              height: 200,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  "Gráfico de Preços (em breve)",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),

            // Abas para Comprar e Vender
            const TabBar(
              tabs: [
                Tab(text: "LIVRO DE OFERTAS"),
                Tab(text: "CRIAR ORDEM"),
              ],
              indicatorColor: Colors.cyanAccent,
              indicatorWeight: 3,
            ),
            
            // Conteúdo das Abas
            Expanded(
              child: TabBarView(
                children: [
                  // Aba 1: "Comprar" - O livro de ordens de venda
                  _buildOrderBook(),

                  // Aba 2: "Vender" - Botão para criar ordem
                  _buildCreateOrderTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget que constrói o livro de ofertas de venda
  Widget _buildOrderBook() {
    return StreamBuilder<QuerySnapshot>(
      stream: _sellOrdersStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Algo deu erro ao carregar as ordens.', style: TextStyle(color: Colors.red)));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: SpinKitFadingCube(color: Colors.cyanAccent));
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("Nenhuma ordem de venda no mercado.", style: TextStyle(color: Colors.white54)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: snapshot.data!.docs.length + 1, // +1 para o cabeçalho
          itemBuilder: (context, index) {
            if (index == 0) {
              // Cabeçalho da tabela
              return const ListTile(
                dense: true,
                title: Row(
                  children: [
                    Expanded(flex: 3, child: Text("Preço (R\$)", style: TextStyle(color: Colors.white70, fontSize: 12))),
                    Expanded(flex: 3, child: Text("Quantidade (B2Y)", style: TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.end)),
                    Expanded(flex: 4, child: Text("Valor Total (R\$)", style: TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.end)),
                  ],
                ),
              );
            }
            final order = SellOrder.fromFirestore(snapshot.data!.docs[index - 1]);
            return _buildOrderItem(order);
          },
        );
      },
    );
  }

  // Widget que constrói um item da lista de ofertas
  Widget _buildOrderItem(SellOrder order) {
    final totalValue = order.coinsToSell * order.pricePerCoin;
    return InkWell(
      onTap: () => _showPurchaseConfirmation(order),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(_currencyFormatter.format(order.pricePerCoin), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
            Expanded(flex: 3, child: Text(_coinFormatter.format(order.coinsToSell), style: const TextStyle(color: Colors.white), textAlign: TextAlign.end)),
            Expanded(flex: 4, child: Text(_currencyFormatter.format(totalValue), style: const TextStyle(color: Colors.white70), textAlign: TextAlign.end)),
          ],
        ),
      ),
    );
  }

  // Widget que constrói a aba de criar ordens
  Widget _buildCreateOrderTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sell_outlined, size: 80, color: Colors.white24),
          const SizedBox(height: 24),
          const Text(
            "Quer vender suas B2Y Coins?",
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            "Crie uma ordem de venda e ganhe com suas viagens sustentáveis.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white54),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const SellCoinsScreen()));
            },
            icon: const Icon(Icons.add),
            label: const Text("Criar Nova Ordem de Venda"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}