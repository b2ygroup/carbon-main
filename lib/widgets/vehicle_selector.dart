// lib/widgets/vehicle_selector.dart (Placeholder)
import 'package:flutter/material.dart';
// TODO: Definir ou importar o modelo 'Vehicle' se for usar
// import '../models/vehicle.dart';

// Define um tipo para a função de callback
typedef VehicleSelectionCallback = void Function(dynamic vehicle); // Usa dynamic por enquanto

class VehicleSelector extends StatelessWidget {
  final VehicleSelectionCallback onVehicleSelected;
  const VehicleSelector({super.key, required this.onVehicleSelected});

  @override Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.directions_car),
      label: const Text('VehicleSelector (Placeholder)'),
      onPressed: () {
        print("VehicleSelector: Botão pressionado (Placeholder)");
        // TODO: Implementar lógica real de seleção, talvez chamando onVehicleSelected com um veículo mock
        // onVehicleSelected(Vehicle(id: '1', name: 'Mock Car', fuelType: FuelType.gasoline));
      },
    );
  }
}