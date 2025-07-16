// lib/services/wallet_service.dart (VERSÃO MELHORADA COM executePurchase)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:carbon/models/product_model.dart'; // Importa o modelo de produto

class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Garante que um usuário tenha uma carteira no Firestore.
  /// Se não existir, cria uma com saldo inicial 0.
  Future<void> initializeWallet(String userId) async {
    if (userId.isEmpty) {
      debugPrint("[WalletService] Erro: User ID vazio.");
      return;
    }
    final walletRef = _db.collection('wallets').doc(userId);
    // SetOptions(merge: true) cria o documento se não existir, sem sobrescrever se já existir.
    await walletRef.set({'balance': 0.0}, SetOptions(merge: true));
    debugPrint("[WalletService] Carteira inicializada para $userId.");
  }

  /// Adiciona um valor (créditos/B2Y Coins) ao saldo da carteira do usuário.
  /// Usa uma transação para garantir que a operação seja atômica e segura.
  Future<void> addCreditsToWallet(String userId, double amountToAdd) async {
    if (userId.isEmpty || amountToAdd <= 0) return;
    
    final walletRef = _db.collection('wallets').doc(userId);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(walletRef);

      if (!snapshot.exists) {
        transaction.set(walletRef, {'balance': amountToAdd});
      } else {
        final currentBalance = (snapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
        final newBalance = currentBalance + amountToAdd;
        transaction.update(walletRef, {'balance': newBalance});
      }
    }).catchError((error) {
       debugPrint("!!! ERRO ao adicionar créditos na carteira: $error");
       throw Exception("Falha ao atualizar o saldo da carteira.");
    });
  }

  /// Gasta um valor da carteira (para resgatar recompensas, por exemplo).
  /// Retorna `true` se a operação for bem-sucedida, `false` se não houver saldo.
  Future<bool> spendCreditsFromWallet(String userId, double amountToSpend) async {
    if (userId.isEmpty || amountToSpend <= 0) return false;

    final walletRef = _db.collection('wallets').doc(userId);

    try {
      return await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(walletRef);

        if (!snapshot.exists) {
          debugPrint("[WalletService] Tentativa de gastar de carteira inexistente.");
          return false;
        }

        final currentBalance = (snapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
        
        if (currentBalance < amountToSpend) {
          debugPrint("[WalletService] Saldo insuficiente para gastar.");
          return false; // Retorna false para indicar falha por saldo insuficiente
        }
        
        final newBalance = currentBalance - amountToSpend;
        transaction.update(walletRef, {'balance': newBalance});
        return true; // Retorna true para indicar sucesso
      });
    } catch (e) {
      debugPrint("!!! ERRO ao gastar créditos da carteira: $e");
      return false;
    }
  }

  /// Retorna um Stream com o saldo atual da carteira para atualizações em tempo real no UI.
  Stream<double> getWalletBalanceStream(String userId) {
    if (userId.isEmpty) return Stream.value(0.0);
    return _db.collection('wallets').doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return (snapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      }
      return 0.0;
    });
  }

  // ▼▼▼ NOVA FUNÇÃO DE COMPRA COM TRANSAÇÃO E HISTÓRICO ▼▼▼
  /// Executa uma compra completa: debita o saldo e registra a transação.
  /// Retorna "success" ou uma mensagem de erro.
  Future<String> executePurchase({required String userId, required Product product}) async {
    final walletRef = _db.collection('wallets').doc(userId);
    // O histórico de transações será salvo dentro do documento do usuário
    final userTransactionsRef = _db.collection('users').doc(userId).collection('transactions');

    try {
      // Usamos uma transação para garantir que todas as operações ocorram ou nenhuma ocorra.
      await _db.runTransaction((transaction) async {
        final walletSnapshot = await transaction.get(walletRef);

        if (!walletSnapshot.exists) {
          throw Exception("Carteira não encontrada.");
        }

        final currentBalance = (walletSnapshot.data()?['balance'] as num).toDouble();
        
        if (currentBalance < product.priceCoins) {
          throw Exception("Saldo insuficiente.");
        }

        final newBalance = currentBalance - product.priceCoins;
        
        // Ação 1: Atualiza o saldo da carteira
        transaction.update(walletRef, {'balance': newBalance});

        // Ação 2: Cria um registro no histórico de transações do usuário
        final transactionDoc = userTransactionsRef.doc(); // Cria um novo documento com ID automático
        transaction.set(transactionDoc, {
          'amount': -product.priceCoins,
          'type': 'purchase', // Tipo da transação
          'description': 'Compra de ${product.name}',
          'productId': product.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      return "success"; // Retorna sucesso se a transação for concluída
    } on FirebaseException catch (e) {
      debugPrint("!!! ERRO de Firestore na compra: ${e.message}");
      return "Erro do servidor, tente novamente.";
    } catch (e) {
      debugPrint("!!! ERRO na compra: $e");
      return e.toString(); // Retorna a mensagem de erro (ex: "Exception: Saldo insuficiente.")
    }
  }
}