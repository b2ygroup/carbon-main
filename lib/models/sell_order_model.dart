// lib/models/sell_order_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class SellOrder {
  final String id;
  final String sellerId;
  final String? sellerName;
  final int coinsToSell;
  final double pricePerCoin;
  final String status;
  final Timestamp createdAt;

  SellOrder({
    required this.id,
    required this.sellerId,
    this.sellerName,
    required this.coinsToSell,
    required this.pricePerCoin,
    required this.status,
    required this.createdAt,
  });

  // Fábrica para criar uma instância a partir de um documento do Firestore
  factory SellOrder.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SellOrder(
      id: doc.id,
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'],
      coinsToSell: (data['coinsToSell'] as num?)?.toInt() ?? 0,
      pricePerCoin: (data['pricePerCoin'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'unknown',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}