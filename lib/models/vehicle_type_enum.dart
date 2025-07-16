// lib/models/vehicle_type_enum.dart (ATUALIZADO COM BARCOS E AVIÕES)
import 'package:flutter/material.dart';

enum VehicleType {
  // Carros de Passeio
  carGasolineSmall,
  carGasolineMedium,
  carGasolineLarge,
  carFlexSmall,
  carFlexMedium,
  carFlexLarge,
  carElectricCompact,
  carElectricSedanSuv,
  carHybrid,

  // SUVs e Pick-ups
  suvGasoline,
  suvDiesel,
  suvFlex,
  suvHybrid,
  suvElectric,
  pickupDiesel,

  // Motocicletas
  motoGasolineLowCc,
  motoGasolineHighCc,
  motoElectric,

  // Transporte Pesado
  busDieselUrban,
  busDieselRoad,
  busElectric,
  lightTruckDiesel,
  heavyTruckDiesel,
  
  // NOVOS TIPOS ADICIONADOS
  airplaneSingleProp, // Monomotor
  airplaneRegionalJet, // Jato Regional
  airplaneJumboJet,    // Jato Comercial Grande
  boatRecreational,    // Barco de Recreio (Gasolina)
  boatYachtDiesel,     // Iate/Balsa (Diesel)
  
  // Combustíveis legados (mantidos para compatibilidade)
  gasoline,
  alcohol,
  diesel,
  flex,
  electric,
  gnv,
}

extension VehicleTypeExtension on VehicleType {
  
  bool get isCombustion {
    // Retorna 'true' para todos os tipos que não são puramente elétricos ou híbridos.
    return ![
      VehicleType.electric, 
      VehicleType.carElectricCompact, 
      VehicleType.carElectricSedanSuv, 
      VehicleType.suvElectric,
      VehicleType.motoElectric, 
      VehicleType.busElectric,
      VehicleType.carHybrid,
      VehicleType.suvHybrid,
    ].contains(this);
  }

  String get displayName {
    switch (this) {
      // Carros de Passeio
      case VehicleType.carGasolineSmall: return 'Carro Pequeno (Gasolina)';
      case VehicleType.carGasolineMedium: return 'Carro Médio (Gasolina)';
      case VehicleType.carGasolineLarge: return 'Carro Grande (Gasolina)';
      case VehicleType.carFlexSmall: return 'Carro Pequeno (Flex)';
      case VehicleType.carFlexMedium: return 'Carro Médio (Flex)';
      case VehicleType.carFlexLarge: return 'Carro Grande (Flex)';
      case VehicleType.carElectricCompact: return 'Carro Elétrico (Compacto)';
      case VehicleType.carElectricSedanSuv: return 'Carro Elétrico (Sedan/SUV)';
      case VehicleType.carHybrid: return 'Carro Híbrido';
      
      // SUVs e Pick-ups
      case VehicleType.suvGasoline: return 'SUV (Gasolina)';
      case VehicleType.suvDiesel: return 'SUV (Diesel)';
      case VehicleType.suvFlex: return 'SUV (Flex)';
      case VehicleType.suvHybrid: return 'SUV (Híbrido)';
      case VehicleType.suvElectric: return 'SUV (Elétrico)';
      case VehicleType.pickupDiesel: return 'Pick-up (Diesel)';
      
      // Motocicletas
      case VehicleType.motoGasolineLowCc: return 'Moto até 160cc (Gasolina/Flex)';
      case VehicleType.motoGasolineHighCc: return 'Moto acima de 160cc (Gasolina)';
      case VehicleType.motoElectric: return 'Moto (Elétrica)';
      
      // Transporte Pesado
      case VehicleType.busDieselUrban: return 'Ônibus Urbano (Diesel)';
      case VehicleType.busDieselRoad: return 'Ônibus Rodoviário (Diesel)';
      case VehicleType.busElectric: return 'Ônibus (Elétrico)';
      case VehicleType.lightTruckDiesel: return 'Caminhão Leve (VUC)';
      case VehicleType.heavyTruckDiesel: return 'Caminhão Pesado';

      // Novos Tipos
      case VehicleType.airplaneSingleProp: return 'Avião Monomotor';
      case VehicleType.airplaneRegionalJet: return 'Jato Regional';
      case VehicleType.airplaneJumboJet: return 'Jato Comercial';
      case VehicleType.boatRecreational: return 'Barco de Recreio';
      case VehicleType.boatYachtDiesel: return 'Iate / Balsa (Diesel)';

      // Legados
      case VehicleType.gasoline: return 'Gasolina (Genérico)';
      case VehicleType.alcohol: return 'Etanol (Genérico)';
      case VehicleType.diesel: return 'Diesel (Genérico)';
      case VehicleType.flex: return 'Flex (Genérico)';
      case VehicleType.electric: return 'Elétrico (Genérico)';
      case VehicleType.gnv: return 'Gás Natural (GNV)';
    }
  }

  IconData get icon {
    switch (this) {
      case VehicleType.carElectricCompact:
      case VehicleType.carElectricSedanSuv:
      case VehicleType.suvElectric:
      case VehicleType.electric:
        return Icons.electric_car;

      case VehicleType.carHybrid:
      case VehicleType.suvHybrid:
        return Icons.eco;

      case VehicleType.motoGasolineLowCc:
      case VehicleType.motoGasolineHighCc:
      case VehicleType.motoElectric:
        return Icons.two_wheeler;
      
      case VehicleType.busDieselUrban:
      case VehicleType.busDieselRoad:
        return Icons.directions_bus;
      
      case VehicleType.busElectric:
        return Icons.directions_bus_filled;

      case VehicleType.pickupDiesel:
      case VehicleType.lightTruckDiesel:
      case VehicleType.heavyTruckDiesel:
        return Icons.local_shipping;
      
      case VehicleType.suvGasoline:
      case VehicleType.suvDiesel:
      case VehicleType.suvFlex:
        return Icons.rv_hookup;

      case VehicleType.airplaneSingleProp:
      case VehicleType.airplaneRegionalJet:
      case VehicleType.airplaneJumboJet:
        return Icons.flight_takeoff;
      
      case VehicleType.boatRecreational:
      case VehicleType.boatYachtDiesel:
        return Icons.directions_boat;

      default:
        return Icons.directions_car_filled;
    }
  }

  Color get displayColor {
    switch (this) {
      case VehicleType.carElectricCompact:
      case VehicleType.carElectricSedanSuv:
      case VehicleType.suvElectric:
      case VehicleType.motoElectric:
      case VehicleType.busElectric:
      case VehicleType.electric:
        return Colors.greenAccent[400]!;

      case VehicleType.carHybrid:
      case VehicleType.suvHybrid:
        return Colors.tealAccent[400]!;
      
      case VehicleType.airplaneSingleProp:
      case VehicleType.airplaneRegionalJet:
      case VehicleType.airplaneJumboJet:
      case VehicleType.boatRecreational:
      case VehicleType.boatYachtDiesel:
      case VehicleType.diesel:
      case VehicleType.suvDiesel:
      case VehicleType.pickupDiesel:
      case VehicleType.busDieselUrban:
      case VehicleType.busDieselRoad:
      case VehicleType.lightTruckDiesel:
      case VehicleType.heavyTruckDiesel:
        return Colors.deepOrangeAccent[200]!;
      
      case VehicleType.alcohol:
        return Colors.amberAccent[400]!;

      default: return Colors.lightBlueAccent[200]!;
    }
  }
}

VehicleType? vehicleTypeFromString(String? typeStr) {
  if (typeStr == null) return null;
  for (VehicleType type in VehicleType.values) {
    if (type.name == typeStr) {
      return type;
    }
  }
  return null;
}