// lib/models/product_model.dart (VERSÃO ATUALIZADA)

import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int priceCoins;
  final bool isActive;
  final Timestamp createdAt;
  
  // ▼▼▼ NOVOS CAMPOS ADICIONADOS ▼▼▼
  // Preço em dinheiro real (ex: 29.90)
  final double? priceReal; 
  // ID do preço gerado no painel do Stripe (ex: price_1P8g8Y...)
  final String? stripePriceId; 

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.priceCoins,
    required this.isActive,
    required this.createdAt,
    this.priceReal, // Adicionado ao construtor
    this.stripePriceId, // Adicionado ao construtor
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? 'Nome Indisponível',
      description: data['description'] ?? 'Sem descrição.',
      imageUrl: data['imageUrl'] ?? '',
      priceCoins: (data['priceCoins'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      // ▼▼▼ Lendo os novos campos do Firestore ▼▼▼
      // Eles são lidos como opcionais, então não quebrarão seus produtos antigos.
      priceReal: (data['priceReal'] as num?)?.toDouble(),
      stripePriceId: data['stripePriceId'] as String?,
    );
  }
}