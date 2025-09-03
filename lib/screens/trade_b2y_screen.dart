// lib/screens/trade_b2y_screen.dart (VERSÃO COM GRÁFICO E MELHORIAS VISUAIS)

import 'package:carbon/models/sell_order_model.dart';
import 'package:carbon/screens/sell_coins_screen.dart';
import 'package:carbon/widgets/dashboard/buy_order_bottom_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:syncfusion_flutter_charts/charts.dart'; // <<< NOVO IMPORT

// <<< NOVO: Modelo de dados para o gráfico >>>
class ChartData {
  ChartData(this.x, this.open, this.high, this.low, this.close);
  final DateTime x;
  final double open, high, low, close;
}

class MarketIndicator extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final Color valueColor;
  final IconData? trendIcon;

  const MarketIndicator({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.valueColor,
    this.trendIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              if (trendIcon != null) Icon(trendIcon, color: valueColor, size: 18),
              if (trendIcon != null) const SizedBox(width: 4),
              Text(value, style: GoogleFonts.orbitron(color: valueColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          if (subtitle != null) const SizedBox(height: 2),
          if (subtitle != null) Text(subtitle!, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ],
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
  final _coinFormatter = NumberFormat("#,##0.00", "pt_BR");
  final _currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  final Stream<QuerySnapshot> _sellOrdersStream = FirebaseFirestore.instance
      .collection('sell_orders')
      .where('status', isEqualTo: 'active')
      .orderBy('pricePerCoin', descending: false)
      .snapshots();

  void _showPurchaseConfirmation(SellOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => BuyOrderBottomSheet(sellOrder: order),
    ).then((success) {
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Text("B2Y Carbon Trade", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          children: [
            _buildMarketIndicators(),
            const SizedBox(height: 12),
            // <<< MUDANÇA: Chamando o novo widget de gráfico >>>
            _buildCandleStickChart(),
            const SizedBox(height: 16),
            _buildOrderBookSection(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketIndicators() {
    return Card(
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: _sellOrdersStream,
          builder: (context, snapshot) {
            String currentPrice = "---";
            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              final firstOrder = SellOrder.fromFirestore(snapshot.data!.docs.first);
              currentPrice = _currencyFormatter.format(firstOrder.pricePerCoin);
            }

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MarketIndicator(
                      title: "Preço B2Y",
                      value: currentPrice,
                      valueColor: Colors.cyanAccent,
                    ),
                    const MarketIndicator(
                      title: "Variação 24h",
                      value: "+1.75%",
                      valueColor: Colors.greenAccent,
                      trendIcon: Icons.arrow_upward,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MarketIndicator(
                      title: "Crédito Carbono (Ton)",
                      value: "R\$ 85,40",
                      subtitle: "Ref: B3/Mercado Global",
                      valueColor: Colors.white,
                    ),
                    MarketIndicator(
                      title: "Volume 24h (B2Y)",
                      value: "15,280",
                      valueColor: Colors.white,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ).animate().fadeIn());
  }

  // <<< NOVO WIDGET: Gráfico de Velas (Candlestick) >>>
  Widget _buildCandleStickChart() {
    // Dados de exemplo para popular o gráfico
    final List<ChartData> chartData = [
      ChartData(DateTime.now().subtract(const Duration(days: 4)), 0.22, 0.28, 0.20, 0.25),
      ChartData(DateTime.now().subtract(const Duration(days: 3)), 0.25, 0.35, 0.24, 0.32),
      ChartData(DateTime.now().subtract(const Duration(days: 2)), 0.32, 0.33, 0.28, 0.30),
      ChartData(DateTime.now().subtract(const Duration(days: 1)), 0.30, 0.40, 0.29, 0.38),
      ChartData(DateTime.now(), 0.38, 0.39, 0.25, 0.25),
    ];

    return SizedBox(
      height: 200,
      child: SfCartesianChart(
        trackballBehavior: TrackballBehavior(enable: true, activationMode: ActivationMode.singleTap),
        plotAreaBorderWidth: 0,
        primaryXAxis: DateTimeAxis(
          majorGridLines: const MajorGridLines(width: 0),
          axisLine: const AxisLine(width: 0),
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 10)
        ),
        primaryYAxis: NumericAxis(
          opposedPosition: true, // Eixo Y à direita
          majorGridLines: const MajorGridLines(width: 0.2, color: Colors.white10),
          axisLine: const AxisLine(width: 0),
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 10),
          numberFormat: NumberFormat.simpleCurrency(locale: "pt_BR", decimalDigits: 2)
        ),
        series: <CandleSeries<ChartData, DateTime>>[
          CandleSeries<ChartData, DateTime>(
            dataSource: chartData,
            xValueMapper: (ChartData data, _) => data.x,
            lowValueMapper: (ChartData data, _) => data.low,
            highValueMapper: (ChartData data, _) => data.high,
            openValueMapper: (ChartData data, _) => data.open,
            closeValueMapper: (ChartData data, _) => data.close,
            bearColor: const Color(0xFFF44336), // Cor para dias de queda
            bullColor: const Color(0xFF4CAF50), // Cor para dias de alta
          )
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildOrderBookSection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("  Livro de Ofertas", style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(child: Text("Preço (R\$)", style: TextStyle(color: Colors.white70, fontSize: 12))),
                Expanded(child: Text("Quantidade (B2Y)", style: TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center)),
                Expanded(child: Text("Total (R\$)", style: TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.end)),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _sellOrdersStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Erro ao carregar ofertas.', style: TextStyle(color: Colors.red)));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: SpinKitFadingCube(color: Colors.cyanAccent, size: 30));
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhuma oferta de venda no mercado.", style: TextStyle(color: Colors.white54)));
                
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final order = SellOrder.fromFirestore(snapshot.data!.docs[index]);
                    return _buildOrderItem(order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // <<< MUDANÇA: Widget de item da lista com barra de profundidade >>>
  Widget _buildOrderItem(SellOrder order) {
    final totalValue = order.coinsToSell * order.pricePerCoin;
    // Lógica para a barra de profundidade (simples)
    // Ajuste o 'maxValueForDepth' para o valor máximo real das ordens visíveis para um efeito melhor
    const double maxValueForDepth = 500.0; 
    final double depthPercentage = (order.coinsToSell / maxValueForDepth).clamp(0.0, 1.0);

    return InkWell(
      onTap: () => _showPurchaseConfirmation(order),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // Barra de profundidade no fundo
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: depthPercentage,
              child: Container(
                height: 42, // Altura da linha
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                ),
              ),
            ),
          ),
          // Conteúdo da linha (seu Row original)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
            child: Row(
              children: [
                Expanded(child: Text(_currencyFormatter.format(order.pricePerCoin), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600))),
                Expanded(child: Text(_coinFormatter.format(order.coinsToSell), style: const TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                Expanded(child: Text(_currencyFormatter.format(totalValue), style: const TextStyle(color: Colors.white70), textAlign: TextAlign.end)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione uma ordem da lista para comprar.")));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text("Comprar"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const SellCoinsScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text("Vender"),
            ),
          ),
        ],
      ),
    );
  }
}