// lib/screens/transaction_history_screen.dart

import 'package:carbon/models/transaction_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    // Inicializa os dados de localização para formatação de data em português
    initializeDateFormatting('pt_BR', null);
  }

  Stream<List<TransactionModel>> _getTransactionsStream() {
    if (userId == null) {
      return Stream.value([]);
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Extrato da Carteira', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.grey[900],
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _getTransactionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: SpinKitFadingCube(color: Colors.cyanAccent, size: 50.0));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar o histórico: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 60, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  const Text('Nenhuma transação encontrada.', style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            );
          }

          final transactions = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              final isCredit = transaction.amount > 0;
              final color = isCredit ? Colors.greenAccent[400] : Colors.redAccent[100];
              final icon = isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline;
              final formattedDate = DateFormat('dd/MM/yyyy \'às\' HH:mm', 'pt_BR').format(transaction.createdAt.toDate());

              return Card(
                color: Colors.grey[850]?.withOpacity(0.8),
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: Icon(icon, color: color, size: 30),
                  title: Text(
                    transaction.description,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    formattedDate,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                  ),
                  trailing: Text(
                    '${isCredit ? '+' : ''}${transaction.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.orbitron(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}