// lib/services/wallet_service.dart (CORRIGIDO)

import 'package:carbon/models/product_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  /// Inicializa a carteira para um novo usuário com saldo zerado.
  Future<void> initializeWallet(String userId) async {
    final walletRef = _db.collection('wallets').doc(userId);
    await walletRef.set({
      'balance': 0.0,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Retorna um Stream com o saldo da carteira do usuário em tempo real.
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

  /// Adiciona créditos (B2Y Coins) à carteira de um usuário.
  Future<void> addCreditsToWallet(String userId, double creditsToAdd) async {
    if (creditsToAdd <= 0) return;
    final walletRef = _db.collection('wallets').doc(userId);

    // MUDANÇA: Salva a transação na subcoleção correta, dentro do documento do usuário.
    final transactionPromise = _db.collection('users').doc(userId).collection('transactions').add({
      'userId': userId, // Redundante mas pode ajudar em queries futuras
      'amount': creditsToAdd,
      'type': 'credit_earned',
      'description': 'Créditos por viagem sustentável',
      'createdAt': FieldValue.serverTimestamp(), // <<< CORRIGIDO de 'timestamp' para 'createdAt'
    });

    // Atualiza o saldo do usuário
    await walletRef.set(
      {'balance': FieldValue.increment(creditsToAdd)},
      SetOptions(merge: true),
    );
    
    // Garante que a transação foi registrada
    await transactionPromise;
  }

  /// Tenta compensar uma quantidade de CO₂ usando o saldo de B2Y Coins do usuário.
  Future<bool> compensateWithCoins({
    required String userId,
    required double co2ToOffset,
    String? tripId,
  }) async {
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

        // MUDANÇA: Cria a referência da transação na subcoleção correta.
        final transactionRef = _db.collection('users').doc(userId).collection('transactions').doc();
        transaction.set(transactionRef, {
          'userId': userId, 'amount': -coinsNeeded, 'type': 'carbon_offset',
          'description': 'Compensação de ${co2ToOffset.toStringAsFixed(2)} kg de CO₂',
          'createdAt': FieldValue.serverTimestamp(),
        });
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

        // MUDANÇA: Cria a referência da transação na subcoleção correta.
        final transactionRef = _db.collection('users').doc(userId).collection('transactions').doc();
        transaction.set(transactionRef, {
          'userId': userId, 'amount': -coinsNeeded, 'type': 'marketplace_purchase',
          'description': 'Compra de "${product.name}"', 'createdAt': FieldValue.serverTimestamp(),
        });
      });
      return "success";
    } catch (e) {
      debugPrint("Erro ao executar compra com moedas: $e");
      return e.toString();
    }
  }

  /// Chama uma Cloud Function para criar uma sessão de checkout do Stripe.
  Future<String> purchaseProductWithStripe({required String priceId}) async {
    final callable = _functions.httpsCallable('createStripeProductCheckout');
    final result = await callable.call<Map<String, dynamic>>({'priceId': priceId});
    
    if (result.data['url'] != null) {
      return result.data['url'];
    } else {
      throw Exception(result.data['error'] ?? 'Não foi possível obter a URL de pagamento.');
    }
  }
}