// lib/models/product_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final int priceCoins;
  final String imageUrl;
  final String category;
  final int stock;
  final bool isActive;
  final List<String> tags;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.priceCoins,
    required this.imageUrl,
    required this.category,
    required this.stock,
    required this.isActive,
    required this.tags,
  });

  // Factory constructor para criar uma instância de Product a partir de um documento do Firestore
  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? 'Nome Indisponível',
      description: data['description'] ?? 'Sem descrição.',
      priceCoins: (data['priceCoins'] as num?)?.toInt() ?? 0,
      imageUrl: data['imageUrl'] ?? '',
      category: data['category'] ?? 'Geral',
      stock: (data['stock'] as num?)?.toInt() ?? -1,
      isActive: data['isActive'] ?? false,
      // Garante que o campo 'tags' seja lido corretamente como uma lista de strings
      tags: List<String>.from(data['tags'] ?? []),
    );
  }
}