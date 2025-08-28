// lib/providers/wallet_provider.dart (COM MÉTODO DE RESET)

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
    print("[WalletProvider] - Iniciando fetchWalletBalance para o usuário: $userId");

    if (!_isLoading) {
      _isLoading = true;
      notifyListeners();
    }

    _balanceSubscription?.cancel();
    
    _balanceSubscription = _walletService.getWalletBalanceStream(userId).listen(
      (newBalance) {
        print("[WalletProvider] - Novo saldo recebido do stream: $newBalance");
        _balance = newBalance;
        if (_isLoading) {
          _isLoading = false;
        }
        notifyListeners();
      }, 
      onError: (error) {
        print("[WalletProvider] - ERRO recebido do stream: $error");
        _isLoading = false;
        notifyListeners();
      }
    );
  }

  /// **NOVO MÉTODO ADICIONADO**
  /// Limpa o estado da carteira ao fazer logout.
  /// Isso evita que dados de um usuário anterior apareçam para o próximo.
  void resetWalletState() {
    print("[WalletProvider] - Resetando o estado da carteira para logout.");
    _balance = 0.0;
    _isLoading = false; // Define como false para não mostrar um loading infinito na tela de login.
    _balanceSubscription?.cancel(); // Cancela qualquer escuta ativa.
    // Não é necessário chamar notifyListeners() aqui, pois os widgets que escutam
    // provavelmente serão destruídos durante o processo de logout.
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    super.dispose();
  }
}