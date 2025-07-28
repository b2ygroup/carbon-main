// lib/models/badge.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Badge {
  final String id;
  final String name;
  final String description;
  final String iconUrl; // URL para a imagem (SVG ou PNG) do emblema
  bool isUnlocked; // Usado na UI para saber se o usuário já o possui

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    this.isUnlocked = false,
  });

  factory Badge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Badge(
      id: doc.id,
      name: data['name'] ?? 'Emblema sem nome',
      description: data['description'] ?? 'Sem descrição',
      iconUrl: data['iconUrl'] ?? '',
    );
  }
}