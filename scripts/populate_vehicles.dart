// scripts/populate_vehicles.dart (VERSÃO V4 - BASE DE DADOS MASSIVA)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

// MUDANÇA: O import foi corrigido para usar o 'package:' do seu projeto.
// Se o nome do seu projeto no pubspec.yaml não for 'carbon', altere aqui.
import 'package:carbon/firebase_options.dart';

/// Este script irá popular a coleção 'vehicle_models' com uma lista massiva de veículos
/// focando em Marca, Modelo e Tipo, sem o campo 'year'.
///
/// LÓGICA:
/// 1. O script verifica se um veículo com a mesma MARCA e MODELO já existe.
/// 2. Adiciona SOMENTE os veículos que ainda não estão no banco de dados.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('✅ Firebase inicializado. Iniciando o cadastro massivo de modelos de veículos...');

  final List<Map<String, dynamic>> vehicleData = [
    // === CARROS POPULARES (CLÁSSICOS E ATUAIS) ===
    { "make": "Volkswagen", "model": "Gol", "type": "carFlexSmall" },
    { "make": "Volkswagen", "model": "Fox", "type": "carFlexSmall" },
    { "make": "Volkswagen", "model": "Voyage", "type": "carFlexMedium" },
    { "make": "Fiat", "model": "Uno", "type": "carFlexSmall" },
    { "make": "Fiat", "model": "Palio", "type": "carFlexSmall" },
    { "make": "Fiat", "model": "Siena", "type": "carFlexMedium" },
    { "make": "Chevrolet", "model": "Celta", "type": "carFlexSmall" },
    { "make": "Chevrolet", "model": "Corsa", "type": "carFlexSmall" },
    { "make": "Chevrolet", "model": "Prisma", "type": "carFlexSmall" },
    { "make": "Ford", "model": "Ka", "type": "carFlexSmall" },
    { "make": "Ford", "model": "Fiesta", "type": "carFlexSmall" },
    { "make": "Ford", "model": "EcoSport", "type": "suvFlex" },

    // === LINHAS ATUAIS (JÁ EXISTENTES E EXPANDIDAS) ===
    // Fiat
    { "make": "Fiat", "model": "Mobi", "type": "carFlexSmall" },
    { "make": "Fiat", "model": "Argo", "type": "carFlexSmall" },
    { "make": "Fiat", "model": "Cronos", "type": "carFlexMedium" },
    { "make": "Fiat", "model": "Pulse", "type": "suvFlex" },
    { "make": "Fiat", "model": "Fastback", "type": "suvFlex" },
    { "make": "Fiat", "model": "Strada", "type": "pickupDiesel" },
    { "make": "Fiat", "model": "Toro", "type": "pickupDiesel" },
    { "make": "Fiat", "model": "500e", "type": "carElectricCompact" },
    // Volkswagen
    { "make": "Volkswagen", "model": "Polo", "type": "carFlexSmall" },
    { "make": "Volkswagen", "model": "Nivus", "type": "suvFlex" },
    { "make": "Volkswagen", "model": "T-Cross", "type": "suvFlex" },
    { "make": "Volkswagen", "model": "Virtus", "type": "carFlexMedium" },
    { "make": "Volkswagen", "model": "Taos", "type": "suvGasoline" },
    { "make": "Volkswagen", "model": "Amarok", "type": "pickupDiesel" },
    { "make": "Volkswagen", "model": "ID.4", "type": "suvElectric" },
    { "make": "Volkswagen", "model": "ID.Buzz", "type": "busElectric" },
    // Chevrolet
    { "make": "Chevrolet", "model": "Onix", "type": "carFlexSmall" },
    { "make": "Chevrolet", "model": "Onix Plus", "type": "carFlexSmall" },
    { "make": "Chevrolet", "model": "Tracker", "type": "suvFlex" },
    { "make": "Chevrolet", "model": "Montana", "type": "pickupDiesel" },
    { "make": "Chevrolet", "model": "S10", "type": "pickupDiesel" },
    { "make": "Chevrolet", "model": "Equinox", "type": "suvGasoline" },
    { "make": "Chevrolet", "model": "Bolt EUV", "type": "carElectricSedanSuv" },
    // Hyundai
    { "make": "Hyundai", "model": "HB20", "type": "carFlexSmall" },
    { "make": "Hyundai", "model": "HB20S", "type": "carFlexSmall" },
    { "make": "Hyundai", "model": "Creta", "type": "suvFlex" },
    // Toyota
    { "make": "Toyota", "model": "Yaris", "type": "carFlexSmall" },
    { "make": "Toyota", "model": "Yaris Sedan", "type": "carFlexMedium" },
    { "make": "Toyota", "model": "Corolla", "type": "carHybrid" },
    { "make": "Toyota", "model": "Corolla Cross", "type": "carHybrid" },
    { "make": "Toyota", "model": "Hilux", "type": "pickupDiesel" },
    { "make": "Toyota", "model": "RAV4", "type": "suvHybrid" },
    // Honda
    { "make": "Honda", "model": "City Hatch", "type": "carFlexSmall" },
    { "make": "Honda", "model": "City Sedan", "type": "carFlexMedium" },
    { "make": "Honda", "model": "HR-V", "type": "suvFlex" },
    { "make": "Honda", "model": "ZR-V", "type": "suvFlex" },
    // Renault
    { "make": "Renault", "model": "Kwid", "type": "carFlexSmall" },
    { "make": "Renault", "model": "Stepway", "type": "carFlexSmall" },
    { "make": "Renault", "model": "Duster", "type": "suvFlex" },
    { "make": "Renault", "model": "Oroch", "type": "pickupDiesel" },
    { "make": "Renault", "model": "Kwid E-Tech", "type": "carElectricCompact" },
    { "make": "Renault", "model": "Megane E-Tech", "type": "carElectricSedanSuv" },
    // Jeep
    { "make": "Jeep", "model": "Renegade", "type": "suvFlex" },
    { "make": "Jeep", "model": "Compass", "type": "suvFlex" },
    { "make": "Jeep", "model": "Compass 4xe", "type": "suvHybrid" },
    { "make": "Jeep", "model": "Commander", "type": "suvDiesel" },
    // Nissan
    { "make": "Nissan", "model": "Kicks", "type": "suvFlex" },
    { "make": "Nissan", "model": "Versa", "type": "carFlexMedium" },
    { "make": "Nissan", "model": "Frontier", "type": "pickupDiesel" },
    { "make": "Nissan", "model": "Leaf", "type": "carElectricCompact" },
    
    // === LINHAS COMPLETAS (FOCO BYD e BMW) ===
    // BYD
    { "make": "BYD", "model": "Dolphin", "type": "carElectricCompact" },
    { "make": "BYD", "model": "Dolphin Mini", "type": "carElectricCompact" },
    { "make": "BYD", "model": "Dolphin Plus", "type": "carElectricCompact" },
    { "make": "BYD", "model": "Seal", "type": "carElectricSedanSuv" },
    { "make": "BYD", "model": "Yuan Plus", "type": "suvElectric" },
    { "make": "BYD", "model": "Tan", "type": "suvElectric" },
    { "make": "BYD", "model": "Han", "type": "carElectricSedanSuv" },
    { "make": "BYD", "model": "Song Plus", "type": "suvHybrid" },
    // BMW
    { "make": "BMW", "model": "Série 1 (118i)", "type": "carGasolineMedium" },
    { "make": "BMW", "model": "Série 2 Gran Coupé", "type": "carGasolineMedium" },
    { "make": "BMW", "model": "Série 3 (320i)", "type": "carFlexMedium" },
    { "make": "BMW", "model": "Série 4 Coupé", "type": "carGasolineLarge" },
    { "make": "BMW", "model": "Série 5", "type": "carHybrid" },
    { "make": "BMW", "model": "X1", "type": "suvFlex" },
    { "make": "BMW", "model": "X3", "type": "suvHybrid" },
    { "make": "BMW", "model": "X4", "type": "suvGasoline" },
    { "make": "BMW", "model": "X5", "type": "suvHybrid" },
    { "make": "BMW", "model": "X6", "type": "suvGasoline" },
    { "make": "BMW", "model": "iX1", "type": "suvElectric" },
    { "make": "BMW", "model": "iX3", "type": "suvElectric" },
    { "make": "BMW", "model": "i4", "type": "carElectricSedanSuv" },
    { "make": "BMW", "model": "iX", "type": "suvElectric" },

    // === OUTRAS MARCAS PREMIUM ===
    // Mercedes-Benz
    { "make": "Mercedes-Benz", "model": "Classe A", "type": "carGasolineMedium" },
    { "make": "Mercedes-Benz", "model": "Classe C", "type": "carGasolineMedium" },
    { "make": "Mercedes-Benz", "model": "Classe E", "type": "carGasolineLarge" },
    { "make": "Mercedes-Benz", "model": "GLA", "type": "suvFlex" },
    { "make": "Mercedes-Benz", "model": "GLB", "type": "suvGasoline" },
    { "make": "Mercedes-Benz", "model": "GLC", "type": "suvDiesel" },
    // Audi
    { "make": "Audi", "model": "A3", "type": "carGasolineMedium" },
    { "make": "Audi", "model": "A4", "type": "carGasolineMedium" },
    { "make": "Audi", "model": "A5", "type": "carGasolineLarge" },
    { "make": "Audi", "model": "Q3", "type": "suvGasoline" },
    { "make": "Audi", "model": "Q5", "type": "suvHybrid" },
    { "make": "Audi", "model": "e-tron", "type": "suvElectric" },
    // Volvo
    { "make": "Volvo", "model": "XC40", "type": "suvElectric" },
    { "make": "Volvo", "model": "XC60", "type": "suvHybrid" },
    { "make": "Volvo", "model": "XC90", "type": "suvHybrid" },

    // === CAMINHÕES ===
    // Mercedes-Benz
    { "make": "Mercedes-Benz", "model": "Accelo", "type": "lightTruckDiesel" },
    { "make": "Mercedes-Benz", "model": "Atego", "type": "heavyTruckDiesel" },
    { "make": "Mercedes-Benz", "model": "Actros", "type": "heavyTruckDiesel" },
    // Volvo
    { "make": "Volvo", "model": "FH", "type": "heavyTruckDiesel" },
    { "make": "Volvo", "model": "FM", "type": "heavyTruckDiesel" },
    { "make": "Volvo", "model": "VM", "type": "lightTruckDiesel" },
    // Scania
    { "make": "Scania", "model": "Série R", "type": "heavyTruckDiesel" },
    { "make": "Scania", "model": "Série S", "type": "heavyTruckDiesel" },
    { "make": "Scania", "model": "Série P", "type": "lightTruckDiesel" },
    // Volkswagen Caminhões
    { "make": "Volkswagen", "model": "Delivery", "type": "lightTruckDiesel" },
    { "make": "Volkswagen", "model": "Constellation", "type": "heavyTruckDiesel" },
    { "make": "Volkswagen", "model": "Meteor", "type": "heavyTruckDiesel" },
    // Iveco
    { "make": "Iveco", "model": "Daily", "type": "lightTruckDiesel" },
    { "make": "Iveco", "model": "Tector", "type": "heavyTruckDiesel" },
    
    // === ÔNIBUS ===
    { "make": "Marcopolo", "model": "Torino", "type": "busDieselUrban" },
    { "make": "Marcopolo", "model": "Paradiso G8 1800 DD", "type": "busDieselRoad" },
    { "make": "Caio", "model": "Apache Vip V", "type": "busDieselUrban" },
    { "make": "BYD", "model": "D9W (Chassi Elétrico)", "type": "busElectric" },
    
    // === DEMAIS MARCAS ===
    { "make": "Peugeot", "model": "208", "type": "carFlexSmall" },
    { "make": "Peugeot", "model": "2008", "type": "suvFlex" },
    { "make": "Peugeot", "model": "e-2008", "type": "suvElectric" },
    { "make": "Citroën", "model": "C3", "type": "carFlexSmall" },
    { "make": "Citroën", "model": "C4 Cactus", "type": "suvFlex" },
    { "make": "GWM", "model": "Haval H6", "type": "suvHybrid" },
    { "make": "GWM", "model": "Ora 03", "type": "carElectricCompact" },
    { "make": "Mitsubishi", "model": "L200 Triton", "type": "pickupDiesel" },
    { "make": "Mitsubishi", "model": "Pajero Sport", "type": "suvDiesel" },
    { "make": "Mitsubishi", "model": "Eclipse Cross", "type": "suvGasoline" },
    { "make": "Ford", "model": "Ranger", "type": "pickupDiesel" },
    { "make": "Ford", "model": "Territory", "type": "suvGasoline" },
    { "make": "Ford", "model": "Bronco Sport", "type": "suvGasoline" },
    { "make": "Caoa Chery", "model": "Tiggo 5X", "type": "suvFlex" },
    { "make": "Caoa Chery", "model": "Tiggo 7 Pro", "type": "suvHybrid" },
    { "make": "Caoa Chery", "model": "Tiggo 8", "type": "suvHybrid" },
    
    // === MOTOS EXPANDIDO ===
    { "make": "Honda", "model": "CG 160 Titan", "type": "motoGasolineLowCc" },
    { "make": "Honda", "model": "CB 300F Twister", "type": "motoGasolineHighCc" },
    { "make": "Honda", "model": "PCX", "type": "motoGasolineLowCc" },
    { "make": "Honda", "model": "NXR 160 Bros", "type": "motoGasolineLowCc" },
    { "make": "Honda", "model": "XRE 300", "type": "motoGasolineHighCc" },
    { "make": "Yamaha", "model": "Factor 150", "type": "motoGasolineLowCc" },
    { "make": "Yamaha", "model": "Lander 250", "type": "motoGasolineHighCc" },
    { "make": "Yamaha", "model": "NMAX", "type": "motoGasolineLowCc" },
    { "make": "Yamaha", "model": "Fazer FZ25", "type": "motoGasolineHighCc" },
    { "make": "BMW", "model": "F 850 GS", "type": "motoGasolineHighCc" },
    { "make": "BMW", "model": "R 1250 GS", "type": "motoGasolineHighCc" },
    { "make": "Kawasaki", "model": "Ninja 400", "type": "motoGasolineHighCc" },
    { "make": "Triumph", "model": "Tiger 900", "type": "motoGasolineHighCc" },

    // Aviação e Náutico
    { "make": "Cessna", "model": "172 Skyhawk", "type": "airplaneSingleProp" },
    { "make": "Embraer", "model": "Phenom 300E", "type": "airplaneRegionalJet" },
    { "make": "Boeing", "model": "737 MAX", "type": "airplaneJumboJet" },
    { "make": "Airbus", "model": "A320neo", "type": "airplaneJumboJet" },
    { "make": "Fibrafort", "model": "Focker 242 GTO", "type": "boatRecreational" },
    { "make": "Schaefer Yachts", "model": "Schaefer 510", "type": "boatYachtDiesel" },
  ];

  print('${vehicleData.length} modelos de veículos na lista para processar.');
  print('--- Iniciando verificação e cadastro no Firestore ---');

  final db = FirebaseFirestore.instance;
  final collection = db.collection('vehicle_models');
  int newModelsCount = 0;
  int skippedModelsCount = 0;
  int errorCount = 0;

  for (final vehicle in vehicleData) {
    final make = vehicle['make'];
    final model = vehicle['model'];

    try {
      final existingVehicleQuery = await collection
          .where('make', isEqualTo: make)
          .where('model', isEqualTo: model)
          .limit(1)
          .get();

      if (existingVehicleQuery.docs.isEmpty) {
        await collection.add(vehicle);
        print('➕ Adicionado: $make $model');
        newModelsCount++;
      } else {
        print('⏭️ Ignorado (já existe): $make $model');
        skippedModelsCount++;
      }
    } catch (e) {
      print('❌ ERRO ao processar $make $model: $e');
      errorCount++;
    }
  }

  print('\n-----------------------------------------');
  print('✨ Processo de cadastro concluído! ✨');
  print('  - Novos modelos adicionados: $newModelsCount');
  print('  - Modelos ignorados (duplicados): $skippedModelsCount');
  if (errorCount > 0) {
    print('  - Erros encontrados: $errorCount');
  }
  print('-----------------------------------------');
}