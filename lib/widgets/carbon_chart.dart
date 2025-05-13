// lib/widgets/carbon_chart.dart (Placeholder)
import 'package:flutter/material.dart';
class CarbonChart extends StatelessWidget {
  final double carbonValue; // Recebe valor de carbono (exemplo)
  const CarbonChart({super.key, required this.carbonValue});
  @override Widget build(BuildContext context) {
    return Card( child: ListTile( title: const Text('CarbonChart (Placeholder)'), subtitle: Text('Valor Carbono: ${carbonValue.toStringAsFixed(2)}'), ));
  }
}