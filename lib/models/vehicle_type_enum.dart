// lib/models/vehicle_type_enum.dart (CORRIGIDO Const Colors)
import 'package:flutter/material.dart';

enum VehicleType {
  electric('Elétrico', Icons.electric_bolt_outlined, Colors.lightBlueAccent),
  gasoline('Gasolina', Icons.local_gas_station_outlined, Colors.orangeAccent),
  alcohol('Álcool', Icons.local_drink_outlined, Color(0xFFE040FB)),
  diesel('Diesel', Icons.opacity_outlined, Color(0xFFA0A0A0)),
  flex('Flex (Álcool/Gasolina)', Icons.sync_alt_outlined, Color(0xFFEEFF41)),
  hybrid('Híbrido', Icons.settings_input_component_outlined, Color(0xFF64FFDA));

  const VehicleType(this.displayName, this.icon, this.displayColor);
  final String displayName;
  final IconData icon;
  final Color displayColor;
}

VehicleType? vehicleTypeFromString(String? typeString) {
  if (typeString == null) return null;
  for (VehicleType type in VehicleType.values) { if (type.name == typeString) return type; }
  return null;
}