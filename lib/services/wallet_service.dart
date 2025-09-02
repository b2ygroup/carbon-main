// lib/services/wallet_service.dart (VERSÃO FINAL COM LÓGICA DE TRADE)

import 'package:carbon/models/product_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  // NOVO: Adiciona um método privado para centralizar a criação de registros de transação
  Future<void> _createTransactionRecord(String userId, double amount, String type, String description) async {
    await _db.collection('users').doc(userId).collection('transactions').add({
      'userId': userId,
      'amount': amount,
      'type': type,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Inicializa a carteira para um novo usuário com saldos zerados.
  Future<void> initializeWallet(String userId) async {
    final walletRef = _db.collection('wallets').doc(userId);
    await walletRef.set({
      'balance': 0.0,
      'locked_balance': 0.0, // NOVO: Campo para saldo bloqueado em ordens de venda
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Retorna um Stream com o saldo total da carteira do usuário.
  Stream<double> getWalletBalanceStream(String userId) {
    return _db.collection('wallets').doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data()!.containsKey('balance')) {
        return (snapshot.data()!['balance'] as num).toDouble();
      }
      return 0.0;
    }).handleError((error) {
      debugPrint("Erro ao ouvir saldo da carteira: $error");
      return 0.0;
    });
  }

  // NOVO: Retorna um Stream com o saldo DISPONÍVEL (Total - Bloqueado).
  Stream<double> getAvailableWalletBalanceStream(String userId) {
    return _db.collection('wallets').doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final totalBalance = (data['balance'] as num?)?.toDouble() ?? 0.0;
        final lockedBalance = (data['locked_balance'] as num?)?.toDouble() ?? 0.0;
        return totalBalance - lockedBalance;
      }
      return 0.0;
    }).handleError((error) {
      debugPrint("Erro ao ouvir saldo disponível da carteira: $error");
      return 0.0;
    });
  }


  /// Adiciona créditos (B2Y Coins) à carteira de um usuário.
  Future<void> addCreditsToWallet(String userId, double creditsToAdd) async {
    if (creditsToAdd <= 0) return;
    final walletRef = _db.collection('wallets').doc(userId);
    
    await _createTransactionRecord(userId, creditsToAdd, 'credit_earned', 'Créditos por viagem sustentável');
    
    await walletRef.set(
      {'balance': FieldValue.increment(creditsToAdd)},
      SetOptions(merge: true),
    );
  }

  // NOVO MÉTODO: Bloqueia uma quantidade de moedas para uma ordem de venda.
  Future<bool> lockCoinsForSale(String userId, int coinsToLock) async {
    if (coinsToLock <= 0) return false;
    final walletRef = _db.collection('wallets').doc(userId);

    try {
      await _db.runTransaction((transaction) async {
        final walletSnapshot = await transaction.get(walletRef);
        if (!walletSnapshot.exists) throw Exception("Carteira não encontrada.");
        
        final data = walletSnapshot.data()!;
        final totalBalance = (data['balance'] as num?)?.toDouble() ?? 0.0;
        final lockedBalance = (data['locked_balance'] as num?)?.toDouble() ?? 0.0;
        final availableBalance = totalBalance - lockedBalance;

        if (availableBalance < coinsToLock) {
          throw Exception("Saldo disponível insuficiente para criar a ordem.");
        }

        // Incrementa o saldo bloqueado
        transaction.update(walletRef, {'locked_balance': FieldValue.increment(coinsToLock.toDouble())});
      });
      return true;
    } catch (e) {
      debugPrint("Erro ao bloquear moedas: $e");
      return false;
    }
  }

  /// Tenta compensar uma quantidade de CO₂ usando o saldo de B2Y Coins do usuário.
  Future<bool> compensateWithCoins({ required String userId, required double co2ToOffset, String? tripId }) async {
    // ... (código existente, sem alterações necessárias aqui)
    final double coinsNeeded = co2ToOffset;
    if (coinsNeeded <= 0) return false;
    final walletRef = _db.collection('wallets').doc(userId);

    try {
      await _db.runTransaction((transaction) async {
        final walletSnapshot = await transaction.get(walletRef);

        if (!walletSnapshot.exists) {
          throw Exception('Carteira do usuário não encontrada.');
        }
        final currentBalance = (walletSnapshot.data()!['balance'] as num?)?.toDouble() ?? 0.0;
        if (currentBalance < coinsNeeded) {
          throw Exception('Saldo de B2Y Coins insuficiente.');
        }

        final newBalance = currentBalance - coinsNeeded;
        transaction.update(walletRef, {'balance': newBalance});

        final offsetRef = _db.collection('carbon_offsets').doc();
        transaction.set(offsetRef, {
          'userId': userId, 'offsetAmountKg': co2ToOffset, 'coinsUsed': coinsNeeded,
          'method': 'b2y_coins', 'tripId': tripId, 'createdAt': FieldValue.serverTimestamp(),
        });
        
        final description = 'Compensação de ${co2ToOffset.toStringAsFixed(2)} kg de CO₂';
        _createTransactionRecord(userId, -coinsNeeded, 'carbon_offset', description);
      });
      debugPrint("Compensação com B2Y Coins bem-sucedida para o usuário $userId");
      return true;
    } catch (e) {
      debugPrint("Erro ao compensar com B2Y Coins: $e");
      return false;
    }
  }

  /// Executa la compra de um produto usando B2Y Coins.
  Future<String> executePurchase({required String userId, required Product product}) async {
    // ... (código existente, sem alterações necessárias aqui)
    final walletRef = _db.collection('wallets').doc(userId);
    final double coinsNeeded = product.priceCoins.toDouble();

    try {
      await _db.runTransaction((transaction) async {
        final walletSnapshot = await transaction.get(walletRef);
        if (!walletSnapshot.exists) throw Exception('Carteira não encontrada.');
        
        final currentBalance = (walletSnapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
        if (currentBalance < coinsNeeded) throw Exception('Saldo de B2Y Coins insuficiente.');
        
        transaction.update(walletRef, {'balance': currentBalance - coinsNeeded});

        final purchaseRef = _db.collection('purchases').doc();
        transaction.set(purchaseRef, {
          'userId': userId, 'productId': product.id, 'productName': product.name,
          'coinsSpent': coinsNeeded, 'createdAt': FieldValue.serverTimestamp(),
        });
        
        final description = 'Compra de "${product.name}"';
        _createTransactionRecord(userId, -coinsNeeded, 'marketplace_purchase', description);
      });
      return "success";
    } catch (e) {
      debugPrint("Erro ao executar compra com moedas: $e");
      return e.toString();
    }
  }

  /// Chama uma Cloud Function para criar uma sessão de checkout do Stripe.
  Future<String> purchaseProductWithStripe({required String priceId}) async {
    // ... (código existente, sem alterações)
    final callable = _functions.httpsCallable('createStripeProductCheckout');
    final result = await callable.call<Map<String, dynamic>>({'priceId': priceId});
    
    if (result.data['url'] != null) {
      return result.data['url'];
    } else {
      throw Exception(result.data['error'] ?? 'Não foi possível obter a URL de pagamento.');
    }
  }
}