// lib/services/firestore_service.dart (CORRIGIDO E ORGANIZADO)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

class FirestoreService {
  /// Cria o documento inicial da carteira para um novo usuário se ele não existir.
  /// Agora é um método estático da classe.
  static Future<void> initializeWallet(String userId) async {
    if (userId.isEmpty) {
      debugPrint("[FirestoreService] Erro: Tentativa de inicializar carteira com userId vazio.");
      return;
    }
    
    // Referência para o documento da carteira do usuário específico
    final walletRef = FirebaseFirestore.instance.collection('wallets').doc(userId);
    
    try {
      debugPrint("[FirestoreService] Verificando/inicializando carteira para $userId...");
      
      // Usa .set com merge:true para criar o documento apenas se ele não existir,
      // sem sobrescrever dados existentes.
      await walletRef.set(
        {'balance': 0.0}, // Saldo inicial
        SetOptions(merge: true)
      );
      
      debugPrint("[FirestoreService] Carteira para $userId está pronta.");
    } catch (e) {
       debugPrint("!!! ERRO ao inicializar carteira para $userId: $e");
       // Considerar relançar o erro se a criação da carteira for uma operação crítica
       // throw Exception("Falha ao inicializar a carteira do usuário: $e");
    }
  }

  // Você pode adicionar outros métodos de serviço do Firestore aqui no futuro.
  // Ex: static Future<void> saveVehicle(String userId, Map<String, dynamic> vehicleData) async { ... }
}