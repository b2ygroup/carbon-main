// lib/services/carbon_service.dart (ATUALIZADO COM BARCOS E AVIÕES)
import 'package:carbon/models/vehicle_type_enum.dart';

class TripCalculationResult {
  final double co2ImpactKg;
  final double co2EmittedKg;
  final double co2SavedKg;
  final double creditsEarned;
  final double compensationCostBRL;
  final bool isEmission;

  TripCalculationResult({
    this.co2ImpactKg = 0.0,
    this.co2EmittedKg = 0.0,
    this.co2SavedKg = 0.0,
    this.creditsEarned = 0.0,
    this.compensationCostBRL = 0.0,
    this.isEmission = false,
  });
}

class CarbonService {
  // Fatores de Emissão (kg CO2e por unidade)
  static const double _kgCO2ePerLiterGasoline = 2.3;
  static const double _kgCO2ePerLiterEthanol = 1.5;
  static const double _kgCO2ePerLiterDiesel = 2.7;
  static const double _kgCO2ePerCubicMeterGnv = 1.9;

  // Consumo Médio (km por unidade)
  static const double _kmplGasSmall = 14.0;
  static const double _kmplGasMedium = 11.5;
  static const double _kmplGasLarge = 8.5;
  static const double _kmplEthSmall = 9.8;
  static const double _kmplEthMedium = 8.0;
  static const double _kmplEthLarge = 6.0;
  static const double _kmplSuvGas = 9.5;
  static const double _kmplSuvDiesel = 11.0;
  static const double _kmplSuvFlex = 8.5;
  static const double _kmplPickupDiesel = 9.0;
  static const double _kmplMotoLowCc = 40.0;
  static const double _kmplMotoHighCc = 22.0;
  static const double _kmplBusUrban = 2.8;
  static const double _kmplBusRoad = 3.5;
  static const double _kmplLightTruck = 6.0;
  static const double _kmplHeavyTruck = 2.5;
  static const double _kmpm3Gnv = 13.0;

  // Fatores Elétricos
  static const double _gridEmissionFactorBr = 0.075; // kg/kWh
  static const double _kwhpkmCarCompact = 0.13;
  static const double _kwhpkmCarSedanSuv = 0.18;
  static const double _kwhpkmMoto = 0.04;
  static const double _kwhpkmBus = 1.2;

  // NOVOS FATORES DE EMISSÃO (kg CO2 / km)
  static const double _kgCO2ePerKmAirplaneSingleProp = 0.39;
  static const double _kgCO2ePerKmAirplaneRegionalJet = 1.80;
  static const double _kgCO2ePerKmAirplaneJumboJet = 11.0;
  static const double _kgCO2ePerKmBoatRecreational = 1.7;
  static const double _kgCO2ePerKmBoatYachtDiesel = 20.0;

  // Parâmetros Financeiros
  static const double _brlPerKgCo2ForCompensation = 0.25;
  static const double _creditsPerKgCo2Saved = 0.1;

  double _calculateCombustionEmissionKg(double distanceKm, VehicleType type) {
    switch (type) {
      // Carros
      case VehicleType.carGasolineSmall: return (distanceKm / _kmplGasSmall) * _kgCO2ePerLiterGasoline;
      case VehicleType.carGasolineMedium: return (distanceKm / _kmplGasMedium) * _kgCO2ePerLiterGasoline;
      case VehicleType.carGasolineLarge: return (distanceKm / _kmplGasLarge) * _kgCO2ePerLiterGasoline;
      case VehicleType.carFlexSmall: return (distanceKm / _kmplEthSmall) * _kgCO2ePerLiterEthanol;
      case VehicleType.carFlexMedium: return (distanceKm / _kmplEthMedium) * _kgCO2ePerLiterEthanol;
      case VehicleType.carFlexLarge: return (distanceKm / _kmplEthLarge) * _kgCO2ePerLiterEthanol;
      // SUVs e Pick-ups
      case VehicleType.suvGasoline: return (distanceKm / _kmplSuvGas) * _kgCO2ePerLiterGasoline;
      case VehicleType.suvDiesel: return (distanceKm / _kmplSuvDiesel) * _kgCO2ePerLiterDiesel;
      case VehicleType.suvFlex: return (distanceKm / _kmplSuvFlex) * _kgCO2ePerLiterEthanol;
      case VehicleType.pickupDiesel: return (distanceKm / _kmplPickupDiesel) * _kgCO2ePerLiterDiesel;
      // Motos
      case VehicleType.motoGasolineLowCc: return (distanceKm / _kmplMotoLowCc) * _kgCO2ePerLiterGasoline;
      case VehicleType.motoGasolineHighCc: return (distanceKm / _kmplMotoHighCc) * _kgCO2ePerLiterGasoline;
      // Pesados
      case VehicleType.busDieselUrban: return (distanceKm / _kmplBusUrban) * _kgCO2ePerLiterDiesel;
      case VehicleType.busDieselRoad: return (distanceKm / _kmplBusRoad) * _kgCO2ePerLiterDiesel;
      case VehicleType.lightTruckDiesel: return (distanceKm / _kmplLightTruck) * _kgCO2ePerLiterDiesel;
      case VehicleType.heavyTruckDiesel: return (distanceKm / _kmplHeavyTruck) * _kgCO2ePerLiterDiesel;
      // Outros
      case VehicleType.gnv: return (distanceKm / _kmpm3Gnv) * _kgCO2ePerCubicMeterGnv;
      // Legados
      case VehicleType.gasoline: return (distanceKm / _kmplGasMedium) * _kgCO2ePerLiterGasoline;
      case VehicleType.alcohol: return (distanceKm / _kmplEthMedium) * _kgCO2ePerLiterEthanol;
      case VehicleType.diesel: return (distanceKm / 10.0) * _kgCO2ePerLiterDiesel;
      case VehicleType.flex: return (distanceKm / 10.0) * _kgCO2ePerLiterEthanol;
      
      // NOVOS CÁLCULOS
      case VehicleType.airplaneSingleProp: return distanceKm * _kgCO2ePerKmAirplaneSingleProp;
      case VehicleType.airplaneRegionalJet: return distanceKm * _kgCO2ePerKmAirplaneRegionalJet;
      case VehicleType.airplaneJumboJet: return distanceKm * _kgCO2ePerKmAirplaneJumboJet;
      case VehicleType.boatRecreational: return distanceKm * _kgCO2ePerKmBoatRecreational;
      case VehicleType.boatYachtDiesel: return distanceKm * _kgCO2ePerKmBoatYachtDiesel;
      
      default: return 0.0;
    }
  }
  
  double _calculateElectricEmissionKg(double distanceKm, VehicleType type) {
     switch (type) {
        case VehicleType.carElectricCompact:
        case VehicleType.electric:
          return distanceKm * _kwhpkmCarCompact * _gridEmissionFactorBr;
        
        case VehicleType.carElectricSedanSuv:
        case VehicleType.suvElectric:
          return distanceKm * _kwhpkmCarSedanSuv * _gridEmissionFactorBr;
        
        case VehicleType.motoElectric:
          return distanceKm * _kwhpkmMoto * _gridEmissionFactorBr;

        case VehicleType.busElectric:
          return distanceKm * _kwhpkmBus * _gridEmissionFactorBr;

        case VehicleType.carHybrid:
        case VehicleType.suvHybrid:
          return _calculateCombustionEmissionKg(distanceKm, VehicleType.carGasolineSmall) * 0.5;

        default: return 0.0;
     }
  }

  Future<TripCalculationResult> getTripCalculationResults({
    required VehicleType vehicleType,
    required double distanceKm,
  }) async {
    
    if (vehicleType.isCombustion) {
      final double emission = _calculateCombustionEmissionKg(distanceKm, vehicleType);
      final double cost = emission * _brlPerKgCo2ForCompensation;
      return TripCalculationResult(
        isEmission: true,
        co2EmittedKg: emission,
        compensationCostBRL: cost,
        co2ImpactKg: emission,
      );
    } 
    else {
      double baselineEmissionKg;
      switch(vehicleType) {
        case VehicleType.motoElectric:
          baselineEmissionKg = _calculateCombustionEmissionKg(distanceKm, VehicleType.motoGasolineLowCc);
          break;
        case VehicleType.busElectric:
          baselineEmissionKg = _calculateCombustionEmissionKg(distanceKm, VehicleType.busDieselUrban);
          break;
        default: // Carros, SUVs elétricos e híbridos
          baselineEmissionKg = _calculateCombustionEmissionKg(distanceKm, VehicleType.carFlexMedium);
      }
      
      final double actualEmissionKg = _calculateElectricEmissionKg(distanceKm, vehicleType);
      final double saved = baselineEmissionKg - actualEmissionKg;
      final double credits = saved * _creditsPerKgCo2Saved;

      return TripCalculationResult(
        isEmission: false,
        co2SavedKg: saved > 0 ? saved : 0,
        creditsEarned: credits > 0 ? credits : 0,
        co2ImpactKg: -saved,
      );
    }
  }
}