// lib/services/firestore_service.dart (Com a função initializeWallet)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

// <<< FUNÇÃO initializeWallet DEFINIDA AQUI (Fora da classe) >>>
/// Cria o documento inicial da carteira para um novo usuário se ele não existir.
Future<void> initializeWallet(String userId) async {
  if (userId.isEmpty) {
     debugPrint("[initializeWallet] Erro: Tentativa de inicializar carteira com userId vazio.");
     // Considerar lançar um erro dependendo da sua lógica
     // throw ArgumentError("User ID não pode ser vazio para inicializar carteira.");
     return;
  }
  // Referência para o documento da carteira do usuário específico
  final walletRef = FirebaseFirestore.instance.collection('wallets').doc(userId);
  try {
    debugPrint("[initializeWallet] Tentando inicializar/verificar carteira para $userId...");
    // Usa .set com merge:true.
    // Cria o doc com balance 0.0 se não existir.
    // NÃO sobrescreve se já existir (importante se houver outros campos ou saldo).
    await walletRef.set(
      {'balance': 0.0}, // Saldo inicial como número
      SetOptions(merge: true)
    );
    debugPrint("[initializeWallet] Carteira inicializada (ou já existia) para $userId.");
  } catch (e) {
     debugPrint("!!! ERRO ao inicializar carteira para $userId: $e");
     // Re-lançar erro se a falha na criação da carteira for crítica
     // throw Exception("Falha ao inicializar a carteira do usuário: $e");
  }
}
// <<< FIM DA FUNÇÃO >>>


// Classe de serviço (pode adicionar mais métodos aqui depois)
class FirestoreService {
  // Construtor (pode estar vazio)
  FirestoreService() {
    debugPrint("FirestoreService Instanciado");
  }

  // Exemplo de outros métodos que você poderia adicionar:
  // Future<void> saveVehicle(String userId, Map<String, dynamic> vehicleData) async { ... }
  // Future<Map<String, dynamic>?> getUserProfile(String userId) async { ... }
}