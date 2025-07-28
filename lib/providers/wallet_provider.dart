// lib/providers/wallet_provider.dart (COM MAIS LOGS PARA DIAGNÓSTICO)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:carbon/services/wallet_service.dart';

class WalletProvider with ChangeNotifier {
  final WalletService _walletService = WalletService();
  StreamSubscription? _balanceSubscription;

  double _balance = 0.0;
  bool _isLoading = true;

  double get balance => _balance;
  bool get isLoading => _isLoading;

  void fetchWalletBalance(String userId) {
    // [LOG] Adicionado para confirmar que a função foi chamada.
    print("[WalletProvider] - Iniciando fetchWalletBalance para o usuário: $userId");

    if (!_isLoading) {
      _isLoading = true;
      notifyListeners();
    }

    _balanceSubscription?.cancel();
    
    _balanceSubscription = _walletService.getWalletBalanceStream(userId).listen(
      (newBalance) {
        // [LOG] Adicionado para confirmar que o stream está a enviar dados.
        print("[WalletProvider] - Novo saldo recebido do stream: $newBalance");
        _balance = newBalance;
        if (_isLoading) {
          _isLoading = false;
        }
        notifyListeners();
      }, 
      onError: (error) {
        // [LOG] Adicionado para capturar qualquer erro no stream.
        print("[WalletProvider] - ERRO recebido do stream: $error");
        _isLoading = false;
        notifyListeners();
      }
    );
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    super.dispose();
  }
}