// lib/providers/trip_provider.dart

import 'dart:async';
import 'package:carbon/models/vehicle_type_enum.dart';
import 'package:carbon/services/carbon_service.dart';
import 'package:carbon/services/gamification_service.dart';
import 'package:carbon/services/wallet_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// Modelo de dados para informações de um veículo selecionado para uma viagem.
class SelectedVehicleInfo {
  final String vehicleId;
  final VehicleType? vehicleType;
  final String displayName;
  final String? licensePlate;

  SelectedVehicleInfo({
    required this.vehicleId,
    required this.vehicleType,
    required this.displayName,
    this.licensePlate,
  });
}

class TripProvider with ChangeNotifier {
  final CarbonService _carbonService = CarbonService();
  final WalletService _walletService = WalletService();
  final GamificationService _gamificationService = GamificationService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  // Estado da UI e Processamento
  bool _isLoadingGpsSave = false;
  bool _isProcessingStartImages = false;
  bool _isProcessingEndImage = false;
  String _loadingMessage = '';

  // Estado do rastreamento
  bool _isTracking = false;
  double _currentDistanceKm = 0.0;
  DateTime? _tripStartTime;
  
  // Dados do Veículo
  SelectedVehicleInfo? _selectedVehicle;
  
  // Dados de Imagens e OCR
  String? _plateImageURL;
  String? _odometerStartImageURL;
  String? _odometerEndImageURL;
  String? _recognizedPlateText;
  String? _recognizedOdometerStartText;
  String? _recognizedOdometerEndText;

  // Stream de Posição
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _lastPosition;
  double _accumulatedDistanceMeters = 0.0;
  
  // Getters Públicos para a UI
  bool get isLoadingGpsSave => _isLoadingGpsSave;
  bool get isProcessingStartImages => _isProcessingStartImages;
  bool get isProcessingEndImage => _isProcessingEndImage;
  bool get isTracking => _isTracking;
  double get currentDistanceKm => _currentDistanceKm;
  SelectedVehicleInfo? get selectedVehicle => _selectedVehicle;
  String get loadingMessage => _loadingMessage;

  /// Limpa e reseta completamente o estado da viagem.
  void resetTripState() {
    _isLoadingGpsSave = false;
    _isProcessingStartImages = false;
    _isProcessingEndImage = false;
    _loadingMessage = '';
    
    _isTracking = false;
    _currentDistanceKm = 0.0;
    _tripStartTime = null;
    
    _selectedVehicle = null;

    _plateImageURL = null;
    _odometerStartImageURL = null;
    _odometerEndImageURL = null;
    _recognizedPlateText = null;
    _recognizedOdometerStartText = null;
    _recognizedOdometerEndText = null;

    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _lastPosition = null;
    _accumulatedDistanceMeters = 0.0;

    notifyListeners();
  }

  /// Define o veículo a ser usado na próxima viagem.
  void selectVehicleForTrip(SelectedVehicleInfo? vehicleInfo) {
    if (_isTracking) return;

    if (_selectedVehicle?.vehicleId == vehicleInfo?.vehicleId) {
      _selectedVehicle = null;
    } else {
      _selectedVehicle = vehicleInfo;
    }
    notifyListeners();
  }

  /// Define os dados de imagens e OCR após a captura na UI.
  void setStartImagesData({
    required String? plateImageURL,
    required String? ocrPlateResult,
    required String? odometerStartImageURL,
    required String? ocrOdometerResult,
  }) {
    _plateImageURL = plateImageURL;
    _recognizedPlateText = ocrPlateResult;
    _odometerStartImageURL = odometerStartImageURL;
    _recognizedOdometerStartText = ocrOdometerResult;
    notifyListeners();
  }
  
  /// Inicia o processo de monitoramento da viagem.
  Future<void> startTracking({required Future<Map<String, dynamic>?> captureStartImages}) async {
    if (_currentUser == null) throw Exception('Usuário não autenticado.');
    if (_selectedVehicle == null) throw Exception('Nenhum veículo selecionado.');
    
    setProcessingStartImages(true);
    final imageResults = await captureStartImages;
    setProcessingStartImages(false);
    
    if (imageResults == null) {
      throw Exception('Captura de imagens iniciais falhou ou foi cancelada.');
    }
    
    if (_plateImageURL == null || _odometerStartImageURL == null) {
      throw Exception('URLs das imagens iniciais não foram definidas corretamente.');
    }

    final String registeredPlate = _selectedVehicle?.licensePlate?.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase() ?? '';
    final String ocrPlate = _recognizedPlateText?.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase() ?? '';

    if (registeredPlate.isEmpty) {
      throw Exception('Erro: Veículo selecionado não possui placa cadastrada.');
    }
    if (ocrPlate != registeredPlate) {
      throw Exception('Atenção: A placa fotografada ($ocrPlate) não corresponde à do veículo selecionado ($registeredPlate).');
    }

    _isTracking = true;
    _accumulatedDistanceMeters = 0.0;
    _currentDistanceKm = 0.0;
    _lastPosition = null;
    _tripStartTime = DateTime.now();
    notifyListeners();

    const LocationSettings locSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locSettings).listen(
      (Position position) {
        if (_isTracking) {
          if (_lastPosition != null) {
            double delta = Geolocator.distanceBetween(
              _lastPosition!.latitude, _lastPosition!.longitude,
              position.latitude, position.longitude,
            );
            if (delta > 1.0) { 
              _accumulatedDistanceMeters += delta;
              _currentDistanceKm = _accumulatedDistanceMeters / 1000.0;
              notifyListeners();
            }
          }
          _lastPosition = position;
        }
      },
      onError: (error) {
        debugPrint("Erro no stream de GPS do Provider: $error");
      },
    );
  }

  /// <<< MÉTODO stopAndSaveTracking ATUALIZADO >>>
  /// Para o monitoramento e salva os dados da viagem no Firestore.
  /// Retorna um Mapa contendo o resultado do cálculo e o ID da viagem.
  Future<Map<String, dynamic>?> stopAndSaveTracking({
    required BuildContext context,
    required String origin,
    required String destination,
    required String endCity,
    required Future<Map<String, String?>?> captureEndImage,
  }) async {
    if (!_isTracking || _currentUser == null || _selectedVehicle == null || _tripStartTime == null) {
      throw Exception('Condições inválidas para parar a viagem.');
    }
    
    _setLoading(true, "Processando foto final...");
    
    final endImageResults = await captureEndImage;
    if (endImageResults != null) {
      _odometerEndImageURL = endImageResults['odometerEndImageURL'];
      _recognizedOdometerEndText = endImageResults['odometerEndText'];
    }

    _setLoading(true, "Salvando viagem...");

    try {
      await _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;

      final DateTime tripEndTime = DateTime.now();
      final double finalDistanceKm = _accumulatedDistanceMeters / 1000.0;

      if (finalDistanceKm <= 0.01) {
        throw Exception('Distância muito curta para ser registrada.');
      }

      final TripCalculationResult results = await _carbonService.getTripCalculationResults(
        vehicleType: _selectedVehicle!.vehicleType!,
        distanceKm: finalDistanceKm,
      );

      final String effectiveDestination = endCity != 'Local Desconhecido' 
          ? endCity 
          : (destination.trim().isNotEmpty ? destination.trim() : 'Destino desconhecido');

      // Cria a referência do documento ANTES para pegar o ID
      final tripDocRef = FirebaseFirestore.instance.collection('trips').doc();

      final Map<String, dynamic> tripData = {
        'userId': _currentUser.uid,
        'vehicleId': _selectedVehicle!.vehicleId,
        'vehicleType': _selectedVehicle!.vehicleType!.name,
        'distanceKm': finalDistanceKm,
        'startTime': Timestamp.fromDate(_tripStartTime!),
        'endTime': Timestamp.fromDate(tripEndTime),
        'durationMinutes': tripEndTime.difference(_tripStartTime!).inMinutes,
        'origin': origin.trim().isNotEmpty ? origin.trim() : 'Origem desconhecida',
        'destination': effectiveDestination,
        'co2EmittedKg': results.co2EmittedKg,
        'co2SavedKg': results.co2SavedKg,
        'creditsEarned': results.creditsEarned,
        'createdAt': FieldValue.serverTimestamp(),
        'calculationMethod': 'gps',
        'plateImageURL': _plateImageURL,
        'odometerStartImageURL': _odometerStartImageURL,
        'odometerEndImageURL': _odometerEndImageURL,
        'recognizedPlate': _recognizedPlateText,
        'recognizedOdometerStart': _recognizedOdometerStartText,
        'recognizedOdometerEnd': _recognizedOdometerEndText,
      };
      
      await tripDocRef.set(tripData);
      
      if (results.creditsEarned > 0) {
        await _walletService.addCreditsToWallet(_currentUser.uid, results.creditsEarned);
      }
      
      final newBadges = await _gamificationService.checkAndAwardBadges(_currentUser.uid);
      if (newBadges.isNotEmpty && context.mounted) {
        for (var badgeName in newBadges) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🏆 Emblema Desbloqueado: $badgeName!'),
              backgroundColor: Colors.amber[800],
            ),
          );
           await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      // Retorna tanto o resultado do cálculo QUANTO o ID da viagem
      return {
        'tripResult': results,
        'tripId': tripDocRef.id,
      };

    } catch(e) {
      _setLoading(false, '');
      rethrow;
    } finally {
      _setLoading(false, '');
    }
  }
  
  /// Define o estado de processamento das imagens iniciais.
  void setProcessingStartImages(bool value) {
    _isProcessingStartImages = value;
    _loadingMessage = value ? "Processando fotos e OCR..." : "";
    notifyListeners();
  }

  /// Define o estado de processamento da imagem final.
  void setProcessingEndImage(bool value) {
_isProcessingEndImage = value;
    _loadingMessage = value ? "Processando foto e OCR..." : "";
    notifyListeners();
  }

  /// Define o estado de carregamento principal (salvando viagem).
  void _setLoading(bool value, String message) {
    _isLoadingGpsSave = value;
    _loadingMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
}