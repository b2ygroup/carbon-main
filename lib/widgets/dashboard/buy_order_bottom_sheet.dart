// lib/widgets/dashboard/buy_order_bottom_sheet.dart

import 'package:carbon/models/sell_order_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BuyOrderBottomSheet extends StatefulWidget {
  final SellOrder sellOrder;
  const BuyOrderBottomSheet({super.key, required this.sellOrder});

  @override
  State<BuyOrderBottomSheet> createState() => _BuyOrderBottomSheetState();
}

class _BuyOrderBottomSheetState extends State<BuyOrderBottomSheet> {
  final _currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  bool _isProcessing = false;

  // Função placeholder para a lógica de compra
  void _executePurchase() {
    setState(() => _isProcessing = true);
    // Simula uma chamada de backend
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.of(context).pop(true); // Retorna 'true' para indicar sucesso
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final order = widget.sellOrder;
    final subtotal = order.coinsToSell * order.pricePerCoin;
    const platformFee = 0.05; // 5% de taxa da plataforma
    final feeAmount = subtotal * platformFee;
    final totalAmount = subtotal + feeAmount;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Confirmar Compra",
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          _buildSummaryRow("Quantidade:", "${NumberFormat("#,##0", "pt_BR").format(order.coinsToSell)} B2Y Coins"),
          const Divider(color: Colors.white12),
          _buildSummaryRow("Preço por Moeda:", _currencyFormatter.format(order.pricePerCoin)),
          const Divider(color: Colors.white12),
          _buildSummaryRow("Subtotal:", _currencyFormatter.format(subtotal)),
          const SizedBox(height: 8),

          // A MONETIZAÇÃO DA PLATAFORMA!
          _buildSummaryRow(
            "Taxa de Serviço (5%):",
            _currencyFormatter.format(feeAmount),
            isFee: true,
          ),
          const Divider(color: Colors.white24, thickness: 1.5),
          const SizedBox(height: 8),

          _buildSummaryRow(
            "TOTAL A PAGAR:",
            _currencyFormatter.format(totalAmount),
            isTotal: true,
          ),
          const SizedBox(height: 32),
          
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            ElevatedButton(
              onPressed: _executePurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                "Confirmar e Pagar",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value, {bool isTotal = false, bool isFee = false}) {
    final valueStyle = GoogleFonts.orbitron(
      fontSize: isTotal ? 20 : 16,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      color: isFee ? Colors.cyanAccent : Colors.white,
    );
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}