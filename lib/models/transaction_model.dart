// lib/models/transaction_model.dart (VERSÃO FINAL E CORRIGIDA)

import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final double amount;
  final String type;
  final String description;
  final String? relatedId; // Pode ser nulo para transações que não são de produto
  final Timestamp createdAt;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    this.relatedId, // Tornando opcional
    required this.createdAt,
  });

  // ▼▼▼ MÉTODO .toMap() ADICIONADO AQUI ▼▼▼
  // Converte o objeto TransactionModel em um mapa para salvar no Firestore.
  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'type': type,
      'description': description,
      'relatedId': relatedId,
      'createdAt': createdAt,
    };
  }
  // ▲▲▲ FIM DA ADIÇÃO ▲▲▲

  // Constrói um objeto TransactionModel a partir de um documento do Firestore.
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: data['type'] ?? 'unknown',
      description: data['description'] ?? 'Transação sem descrição',
      relatedId: data['relatedId'], // Carrega o campo
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}