// lib/screens/sell_coins_screen.dart (VERSÃO FINAL COM VALIDAÇÃO DE SALDO)

import 'package:carbon/services/wallet_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class SellCoinsScreen extends StatefulWidget {
  const SellCoinsScreen({super.key});

  @override
  State<SellCoinsScreen> createState() => _SellCoinsScreenState();
}

class _SellCoinsScreenState extends State<SellCoinsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _walletService = WalletService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  final _coinsToSellController = TextEditingController();
  final _pricePerCoinController = TextEditingController();

  final _coinFormatter = NumberFormat("#,##0", "pt_BR");
  bool _isLoading = false;
  double _currentAvailableBalance = 0.0;

  Future<void> _submitSellOrder() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro: Usuário não autenticado."), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final coinsToSell = int.parse(_coinsToSellController.text);
      final pricePerCoin = double.parse(_pricePerCoinController.text.replaceAll(',', '.'));
      final totalValue = coinsToSell * pricePerCoin;
      
      // VALIDAÇÃO CRÍTICA: Verifica se o saldo disponível é suficiente.
      if (coinsToSell > _currentAvailableBalance) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saldo disponível insuficiente para criar esta ordem."), backgroundColor: Colors.redAccent));
        setState(() => _isLoading = false);
        return;
      }

      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Confirmar Ordem de Venda"),
          content: Text("Você está prestes a colocar à venda:\n\nQuantidade: ${_coinFormatter.format(coinsToSell)} B2Y Coins\nPreço por Moeda: R\$ ${pricePerCoin.toStringAsFixed(2)}\nValor Total: R\$ ${totalValue.toStringAsFixed(2)}\n\nEsta ação irá reservar as moedas do seu saldo até que a ordem seja vendida ou cancelada."),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancelar")),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text("Confirmar")),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _isLoading = false);
        return;
      }
      
      // 1. Bloqueia as moedas no saldo do usuário ANTES de criar a ordem.
      final lockSuccess = await _walletService.lockCoinsForSale(_currentUser.uid, coinsToSell);
      if (!lockSuccess) {
          throw Exception("Não foi possível reservar seu saldo. Tente novamente.");
      }

      // 2. Se o bloqueio foi bem-sucedido, cria a ordem de venda.
      await FirebaseFirestore.instance.collection('sell_orders').add({
        'sellerId': _currentUser.uid,
        'sellerName': _currentUser.displayName ?? _currentUser.email,
        'coinsToSell': coinsToSell,
        'pricePerCoin': pricePerCoin,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ordem de venda criada com sucesso!"), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao criar ordem: ${e.toString()}"), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Vender B2Y Coins", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.grey[850],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text("Seu Saldo Disponível para Venda", style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_currentUser != null)
                        StreamBuilder<double>(
                          // MUDANÇA: Ouve o saldo DISPONÍVEL, não o total.
                          stream: _walletService.getAvailableWalletBalanceStream(_currentUser.uid),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SpinKitFadingCircle(color: Colors.amber, size: 24);
                            }
                            _currentAvailableBalance = snapshot.data ?? 0.0;
                            return Text(
                              _coinFormatter.format(_currentAvailableBalance),
                              style: GoogleFonts.orbitron(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amber),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text("Crie sua Ordem de Venda", style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              TextFormField(
                controller: _coinsToSellController,
                decoration: const InputDecoration(labelText: "Quantidade de Moedas para Vender", prefixIcon: Icon(Icons.toll_outlined)),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) return "Por favor, insira a quantidade.";
                  final amount = int.tryParse(value);
                  if (amount == null || amount <= 0) return "Insira uma quantidade válida.";
                  // A validação final contra o saldo é feita no _submitSellOrder
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pricePerCoinController,
                decoration: const InputDecoration(labelText: "Preço por Moeda (Ex: 0,25)", prefixText: "R\$ "),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Por favor, insira o preço.";
                  if (double.tryParse(value.replaceAll(',', '.')) == null) return "Por favor, insira um preço válido.";
                  return null;
                },
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _submitSellOrder,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text("Criar Ordem de Venda"),
                ),
            ],
          ),
        ),
      ),
    );
  }
}