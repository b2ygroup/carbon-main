// lib/widgets/animated_credit_card.dart (Placeholder)
import 'package:flutter/material.dart';
class AnimatedCreditCard extends StatelessWidget {
  final double balance;
  const AnimatedCreditCard({super.key, required this.balance});
  @override Widget build(BuildContext context) {
    return Card( child: ListTile( title: const Text('AnimatedCreditCard (Placeholder)'), subtitle: Text('Saldo: ${balance.toStringAsFixed(2)}'),));
  }
}