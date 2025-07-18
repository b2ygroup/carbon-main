// lib/services/wallet_service.dart (VERSÃO COMPLETA COM DEPURACÃO AVANÇADA)
import 'package:carbon/models/product_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> initializeWallet(String userId) async {
    if (userId.isEmpty) {
      debugPrint("[WalletService] Erro: User ID vazio.");
      return;
    }
    final walletRef = _db.collection('wallets').doc(userId);
    await walletRef.set({'balance': 0.0, 'userId': userId}, SetOptions(merge: true));
  }

  Future<void> addCreditsToWallet(String userId, double amountToAdd) async {
    if (userId.isEmpty || amountToAdd <= 0) return;
    
    final walletRef = _db.collection('wallets').doc(userId);
    await walletRef.update({'balance': FieldValue.increment(amountToAdd)});
  }

  Stream<double> getWalletBalanceStream(String userId) {
    if (userId.isEmpty) return Stream.value(0.0);
    return _db.collection('wallets').doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return (snapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      }
      return 0.0;
    });
  }

  // ▼▼▼ MÉTODO ATUALIZADO COM LOGS INTERNOS NA TRANSAÇÃO ▼▼▼
  Future<String> executePurchase({required String userId, required Product product}) async {
    final walletRef = _db.collection('wallets').doc(userId);
    final userTransactionsRef = _db.collection('users').doc(userId).collection('transactions');

    try {
      debugPrint("[executePurchase] Iniciando transação para o usuário: $userId");
      await _db.runTransaction((transaction) async {
        debugPrint("[executePurchase] Passo 1: Lendo o documento da carteira...");
        final walletSnapshot = await transaction.get(walletRef);
        debugPrint("[executePurchase] Passo 2: Documento da carteira lido. Existe? ${walletSnapshot.exists}");

        if (!walletSnapshot.exists) {
          throw Exception("Sua carteira digital não foi encontrada.");
        }

        debugPrint("[executePurchase] Passo 3: Lendo os dados da carteira... Dados: ${walletSnapshot.data()}");
        final walletData = walletSnapshot.data();
        if (walletData == null || walletData['balance'] == null) {
            throw Exception("O campo 'balance' não foi encontrado na carteira.");
        }
        
        final currentBalance = (walletData['balance'] as num).toDouble();
        debugPrint("[executePurchase] Passo 4: Saldo atual lido com sucesso: $currentBalance");
        
        if (currentBalance < product.priceCoins) {
          throw Exception("Saldo de moedas insuficiente.");
        }

        final newBalance = currentBalance - product.priceCoins;
        debugPrint("[executePurchase] Passo 5: Novo saldo calculado: $newBalance. Atualizando documento...");
        transaction.update(walletRef, {'balance': newBalance});
        debugPrint("[executePurchase] Passo 6: Documento da carteira atualizado. Criando registro de transação...");

        final transactionDoc = userTransactionsRef.doc();
        transaction.set(transactionDoc, {
          'id': transactionDoc.id,
          'amount': -product.priceCoins.toDouble(),
          'type': 'purchase',
          'description': 'Compra de ${product.name}',
          'relatedId': product.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint("[executePurchase] Passo 7: Registro de transação criado. Finalizando.");
      });
      debugPrint("[executePurchase] Transação concluída com sucesso.");
      return "success";
    } on FirebaseException catch (e) {
      debugPrint("ERRO DETALHADO DA TRANSAÇÃO NO FIREBASE: CÓDIGO: [${e.code}] MENSAGEM: ${e.message}");
      return "Erro do servidor: ${e.message}";
    } catch (e) {
      debugPrint("ERRO DETALHADO DA TRANSAÇÃO (GENÉRICO): $e");
      return e.toString();
    }
  }

  /// Inicia uma sessão de checkout do Stripe para um determinado produto.
  Future<String> purchaseProductWithStripe({required String priceId}) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final callable = functions.httpsCallable('createStripeCheckout');

      final HttpsCallableResult result = await callable.call<Map<String, dynamic>>({
        'priceId': priceId,
      });

      final url = result.data?['url'];
      if (url != null) {
        return url;
      } else {
        throw Exception("A URL de checkout não foi retornada pelo servidor.");
      }

    } on FirebaseFunctionsException catch (e) {
      debugPrint("Erro do Firebase Functions ao comprar com Stripe: [${e.code}] ${e.message}");
      throw Exception("Falha ao iniciar o pagamento. Por favor, tente novamente.");
    } catch (e) {
      debugPrint("Erro genérico ao chamar o Stripe: $e");
      throw Exception("Ocorreu um erro inesperado ao processar seu pagamento.");
    }
  }
}