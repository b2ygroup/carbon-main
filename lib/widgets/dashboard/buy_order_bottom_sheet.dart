// lib/widgets/dashboard/buy_order_bottom_sheet.dart (VERSÃO FINAL E CORRIGIDA)

import 'package:carbon/models/sell_order_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart'; // <<< CORREÇÃO: Import adicionado
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
  
  // <<< CORREÇÃO: Instância do Firestore definida na classe
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // LÓGICA DE COMPRA REAL E ATÔMICA
  Future<void> _executePurchase() async {
    setState(() => _isProcessing = true);

    final buyerId = FirebaseAuth.instance.currentUser?.uid;
    if (buyerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sua sessão expirou. Faça login novamente."), backgroundColor: Colors.redAccent));
      setState(() => _isProcessing = false);
      return;
    }

    // <<< CORREÇÃO: Variável 'order' definida no escopo da função
    final order = widget.sellOrder;
    final sellerId = order.sellerId;
    final orderId = order.id;
    final coinsAmount = order.coinsToSell;
    
    try {
      // INÍCIO DA TRANSAÇÃO ATÔMICA
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Obter referências de todos os documentos que serão modificados.
        final orderRef = _db.collection('sell_orders').doc(orderId);
        final buyerWalletRef = _db.collection('wallets').doc(buyerId);
        final sellerWalletRef = _db.collection('wallets').doc(sellerId);
        
        // 2. Ler os documentos DENTRO da transação para garantir dados atualizados.
        final orderDoc = await transaction.get(orderRef);
        final buyerWalletDoc = await transaction.get(buyerWalletRef);
        final sellerWalletDoc = await transaction.get(sellerWalletRef);

        // 3. Validar todas as condições necessárias para a compra.
        // <<< CORREÇÃO: Cast para Map<String, dynamic> para evitar erro de tipo 'Object'
        if (!orderDoc.exists || (orderDoc.data() as Map<String, dynamic>?)?['status'] != 'active') {
          throw Exception("Esta ordem não está mais disponível para compra.");
        }
        if (!buyerWalletDoc.exists || !sellerWalletDoc.exists) {
            throw Exception("Carteira do comprador ou vendedor não encontrada.");
        }
        
        // 4. Se todas as validações passaram, executar as modificações.

        // a) Atualiza a ordem para 'completed'
        transaction.update(orderRef, {'status': 'completed', 'buyerId': buyerId});

        // b) Transfere as moedas: Debita do vendedor e credita no comprador
        transaction.update(sellerWalletRef, {
          'balance': FieldValue.increment(-coinsAmount.toDouble()),
          'locked_balance': FieldValue.increment(-coinsAmount.toDouble()),
        });
        transaction.update(buyerWalletRef, {
          'balance': FieldValue.increment(coinsAmount.toDouble()),
        });
        
        // c) Cria registros de transação para ambos (para o extrato)
        final buyerTransactionRef = _db.collection('users').doc(buyerId).collection('transactions').doc();
        final sellerTransactionRef = _db.collection('users').doc(sellerId).collection('transactions').doc();

        transaction.set(buyerTransactionRef, {
            'amount': coinsAmount.toDouble(),
            'type': 'p2p_buy',
            // <<< CORREÇÃO: Usando a variável 'order' que foi definida
            'description': 'Compra de ${order.coinsToSell} B2Y de ${order.sellerName ?? 'vendedor'}',
            'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(sellerTransactionRef, {
            'amount': -coinsAmount.toDouble(),
            'type': 'p2p_sell',
            // <<< CORREÇÃO: Usando a variável 'order' que foi definida
            'description': 'Venda de ${order.coinsToSell} B2Y para um usuário',
            'createdAt': FieldValue.serverTimestamp(),
        });
      });
      // FIM DA TRANSAÇÃO ATÔMICA

      if (mounted) Navigator.of(context).pop(true);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Falha na compra: ${e.toString()}"), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.sellOrder;
    final subtotal = order.coinsToSell * order.pricePerCoin;
    const platformFee = 0.05;
    final feeAmount = subtotal * platformFee;
    final totalAmount = subtotal + feeAmount;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Confirmar Compra", textAlign: TextAlign.center, style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 24),
            _buildSummaryRow("Quantidade:", "${NumberFormat("#,##0", "pt_BR").format(order.coinsToSell)} B2Y Coins"),
            const Divider(color: Colors.white12),
            _buildSummaryRow("Preço por Moeda:", _currencyFormatter.format(order.pricePerCoin)),
            const Divider(color: Colors.white12),
            _buildSummaryRow("Subtotal:", _currencyFormatter.format(subtotal)),
            const SizedBox(height: 8),
            _buildSummaryRow("Taxa de Serviço (5%):", _currencyFormatter.format(feeAmount), isFee: true),
            const Divider(color: Colors.white24, thickness: 1.5),
            const SizedBox(height: 8),
            _buildSummaryRow("TOTAL A PAGAR:", _currencyFormatter.format(totalAmount), isTotal: true),
            const SizedBox(height: 32),
            
            if (_isProcessing)
              // <<< CORREÇÃO: Adicionado 'const' e corrigida a chamada do Widget
              const Center(child: SpinKitFadingCube(color: Colors.greenAccent, size: 40))
            else
              ElevatedButton(
                onPressed: _executePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Confirmar e Pagar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancelar", style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
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