// lib/screens/dashboard_screen.dart
// CÓDIGO COMPLETO E FINAL (vFinal) - CORRIGIDO CONFORME DIAGNÓSTICOS

import 'dart:async';
import 'dart:io'; // Para a classe File
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';

// Imports do seu projeto
import 'package:carbon/providers/user_provider.dart';
import 'package:carbon/screens/registration_screen.dart';
import 'package:carbon/models/vehicle_type_enum.dart';
import 'package:carbon/services/carbon_service.dart';
import 'package:carbon/screens/fleet_management_screen.dart';
import 'package:carbon/screens/trip_calculator_screen.dart';
import 'package:carbon/screens/trip_history_screen.dart';

// Imports dos Widgets Auxiliares
import 'package:carbon/widgets/indicator_card.dart';
import 'package:carbon/widgets/trip_chart_placeholder.dart';
import 'package:carbon/widgets/trip_calculator_widget.dart';
import 'package:carbon/widgets/ad_banner_placeholder.dart';
import 'package:carbon/widgets/minimap_placeholder.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  // --- Estados da Dashboard ---
  bool _isTracking = false;
  bool _isLoadingGpsSave = false;
  double _currentDistanceKm = 0.0;
  String? _selectedVehicleIdForTrip;
  VehicleType? _selectedVehicleTypeForTrip;
  StreamSubscription<Position>? _positionStreamSubscriptionForTrip;
  Position? _lastPositionForTripStart;
  double _accumulatedDistanceMeters = 0.0;
  DateTime? _tripStartTime;
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  String _currentOrigin = '';
  String _currentDestination = '';
  String _currentVehicleId = '';
  VehicleType? _currentVehicleType;

  final CarbonService _carbonService = CarbonService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late TabController _tabController;
  StreamSubscription<Position>? _generalPositionStream;

  // --- Estados para Captura de Imagem ---
  final ImagePicker _picker = ImagePicker();
  String? _plateImageURL;
  String? _odometerStartImageURL;
  String? _odometerEndImageURL;

  bool _isProcessingStartImages = false;
  bool _isProcessingEndImage = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _initializeGeneralLocationStream();
  }

  void _initializeGeneralLocationStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[DashboardScreen] Serviço de localização desativado (geral).');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Serviço de GPS está desativado.')));
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[DashboardScreen] Permissão de localização negada (geral).');
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Permissão de localização negada.')));
         }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      debugPrint('[DashboardScreen] Permissão de localização negada permanentemente (geral).');
      await _showPermissionDeniedPermanentlyDialog("localização");
      return;
    }
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        const LocationSettings locationSettings = LocationSettings(
          accuracy: LocationAccuracy.medium, distanceFilter: 100,
        );
        _generalPositionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) {
            debugPrint("[DashboardScreen] Posição geral atualizada: ${position.latitude}, ${position.longitude}");
        },
        onError: (error) {
            debugPrint("[DashboardScreen] Erro no stream de localização geral: $error");
        });
    }
  }

  Future<void> _showPermissionDeniedPermanentlyDialog(String permissionType) async {
    if (!mounted) return;
    await showDialog(
      context: context, // Usando o context do State
      builder: (ctx) => AlertDialog(
        title: const Text('Permissão Necessária'),
        content: Text('A permissão para $permissionType foi negada permanentemente. Por favor, habilite nas configurações do seu dispositivo.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Abrir Configurações'),
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
          ),
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscriptionForTrip?.cancel();
    _generalPositionStream?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _tabController.removeListener(() {});
    _tabController.dispose();
    super.dispose();
  }

  // --- Navegação ---
  void _navigateToAddVehicle() { if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const RegistrationScreen())); }
  void _navigateToFleetManagement() { if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const FleetManagementScreen())); }
  void _navigateToTripHistory() { if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const TripHistoryScreen())); }
  Future<void> _logout() async {
    if (mounted) Provider.of<UserProvider>(context, listen: false).clearUserDataOnLogout();
    await FirebaseAuth.instance.signOut();
  }

  // --- Lógica de Captura e Upload de Imagem ---
  Future<XFile?> _pickImageFromSource(ImageSource source, String imagePurpose) async {
    PermissionStatus status;
    String permissionTypeForDialog = "";

    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
      permissionTypeForDialog = "câmera";
    } else {
      status = await Permission.photos.request();
      permissionTypeForDialog = "galeria de fotos";
    }

    if (!mounted) return null; 

    if (status.isGranted) {
      try {
        final XFile? pickedFile = await _picker.pickImage(
          source: source, imageQuality: 60, maxWidth: 1280, maxHeight: 1280,
        );
        return pickedFile;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao capturar imagem para $imagePurpose: $e'), backgroundColor: Colors.redAccent),
          );
        }
        return null;
      }
    } else if (status.isPermanentlyDenied) {
      await _showPermissionDeniedPermanentlyDialog(permissionTypeForDialog);
      return null;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permissão para $permissionTypeForDialog não concedida para $imagePurpose.'), backgroundColor: Colors.orangeAccent),
        );
      }
      return null;
    }
  }
  
  Future<XFile?> _showImageSourceDialog(String imagePurpose) async {
    if (!mounted) return null;
    return await showDialog<XFile?>(
      context: context,
      builder: (BuildContext dialogCtx) => AlertDialog(
        title: Text('Foto para $imagePurpose'),
        content: const Text('Escolha a origem da imagem:'),
        actions: <Widget>[
          TextButton.icon(
            icon: const Icon(Icons.camera_alt), label: const Text('Câmera'),
            onPressed: () async {
              Navigator.of(dialogCtx).pop(await _pickImageFromSource(ImageSource.camera, imagePurpose));
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.photo_library), label: const Text('Galeria'),
            onPressed: () async {
              Navigator.of(dialogCtx).pop(await _pickImageFromSource(ImageSource.gallery, imagePurpose));
            },
          ),
        ],
      ),
    );
  }

  Future<String?> _uploadImageToFirebaseStorage(XFile imageFile, String imageTypeForPath) async {
    if (_currentUser == null) return null;
    final String fileName = '${_currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}_$imageTypeForPath.jpg';
    final Reference storageReference = FirebaseStorage.instance.ref().child('trip_verification_images').child(fileName);

    try {
      UploadTask uploadTask = storageReference.putFile(File(imageFile.path));
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadURL = await taskSnapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      debugPrint("[DashboardScreen] Erro upload ($imageTypeForPath): $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha no upload ($imageTypeForPath).'), backgroundColor: Colors.redAccent),
        );
      }
      return null;
    }
  }

  Future<bool> _captureAndUploadStartImages() async {
    if (!mounted) return false;
    setState(() => _isProcessingStartImages = true);

    XFile? plateImage = await _showImageSourceDialog('Placa do Veículo');
    if (plateImage == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto da placa é obrigatória.'), backgroundColor: Colors.orangeAccent));
      setState(() => _isProcessingStartImages = false);
      return false;
    }
    _plateImageURL = await _uploadImageToFirebaseStorage(plateImage, 'plate');
    if (_plateImageURL == null) {
      setState(() => _isProcessingStartImages = false);
      return false;
    }
    if (!mounted) return false;

    XFile? odometerStartImage = await _showImageSourceDialog('Hodômetro Inicial');
    if (odometerStartImage == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto do hodômetro inicial é obrigatória.'), backgroundColor: Colors.orangeAccent));
      setState(() => _isProcessingStartImages = false);
      return false;
    }
    _odometerStartImageURL = await _uploadImageToFirebaseStorage(odometerStartImage, 'odometer_start');
    if (_odometerStartImageURL == null) {
      setState(() => _isProcessingStartImages = false);
      return false;
    }

    setState(() => _isProcessingStartImages = false);
    return true;
  }

  Future<bool> _captureAndUploadEndOdometerImage() async {
    if (!mounted) return false;
    setState(() => _isProcessingEndImage = true);

    XFile? odometerEndImage = await _showImageSourceDialog('Hodômetro Final');
    if (odometerEndImage == null) {
      setState(() => _isProcessingEndImage = false);
      return false; 
    }
    _odometerEndImageURL = await _uploadImageToFirebaseStorage(odometerEndImage, 'odometer_end');
    
    setState(() => _isProcessingEndImage = false);
    return _odometerEndImageURL != null;
  }
  
  // Readicionado e corrigido
  void _handleVehicleSelection(String vehicleId, VehicleType? vehicleType) {
    if (!_isTracking && !_isProcessingStartImages && !_isProcessingEndImage && !_isLoadingGpsSave ) {
      setState(() {
        if (_selectedVehicleIdForTrip == vehicleId) {
          _selectedVehicleIdForTrip = null;
          _selectedVehicleTypeForTrip = null;
        } else {
          _selectedVehicleIdForTrip = vehicleId;
          _selectedVehicleTypeForTrip = vehicleType;
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não é possível alterar o veículo durante uma operação.'), backgroundColor: Colors.orangeAccent)
        );
      }
    }
  }

  // Readicionado e corrigido
  Future<void> _showVehicleSelectionDialogForTracking() async {
    if (_isTracking || _isProcessingStartImages || _isProcessingEndImage || _isLoadingGpsSave) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Aguarde a operação atual antes de selecionar um veículo.'),
            backgroundColor: Colors.orangeAccent));
      }
      return;
    }
    if (_currentUser == null) return;

    List<Map<String, dynamic>> vehicles = [];
    // TODO: Adicionar um indicador de loading no UI se esta busca for demorada
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('userId', isEqualTo: _currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();
      vehicles = snapshot.docs.map((doc) {
        final data = doc.data();
        final type = vehicleTypeFromString(data['type'] as String?);
        return {
          'id': doc.id,
          'label': '${data['make'] ?? '?'} ${data['model'] ?? '?'} (${type?.displayName ?? data['type'] ?? '?'})',
          'type': type
        };
      }).toList();
    } catch (e) {
      debugPrint("Erro ao buscar veículos para seleção: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Erro ao carregar lista de veículos.'),
            backgroundColor: Colors.redAccent));
      }
      return;
    }

    if (vehicles.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhum veículo cadastrado para selecionar.')));
      return;
    }
    if (!mounted) return;

    final selectedVehicleInfo = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Selecione um Veículo', style: GoogleFonts.orbitron(color: Colors.cyanAccent[400])),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return ListTile(
                  leading: Icon(
                      (vehicle['type'] as VehicleType?)?.icon ?? Icons.car_rental,
                      color: (vehicle['type'] as VehicleType?)?.displayColor ?? Colors.white70),
                  title: Text(vehicle['label'], style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(dialogContext).pop(vehicle);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)))
          ],
        );
      },
    );

    if (selectedVehicleInfo != null) {
      _handleVehicleSelection(selectedVehicleInfo['id'], selectedVehicleInfo['type'] as VehicleType?);
    }
  }

  // --- Lógica Principal de Rastreio (_toggleTracking) ---
  Future<void> _toggleTracking() async {
    if (_isProcessingStartImages || _isProcessingEndImage || _isLoadingGpsSave) return;

    if (_isTracking) { // PARANDO A VIAGEM
      setState(() => _isLoadingGpsSave = true); 
      await _positionStreamSubscriptionForTrip?.cancel();
      _positionStreamSubscriptionForTrip = null;

      bool endOdometerPhotoUploaded = await _captureAndUploadEndOdometerImage();
      if (!endOdometerPhotoUploaded && mounted) { 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto do hodômetro final não capturada. O registro seguirá sem ela.'), backgroundColor: Colors.orangeAccent));
      }

      final DateTime tripEndTime = DateTime.now();
      final double finalDistanceKm = _accumulatedDistanceMeters / 1000.0;

      if (_currentUser != null && _currentVehicleId.isNotEmpty && _currentVehicleType != null && _tripStartTime != null && finalDistanceKm > 0.01) {
        final String userId = _currentUser.uid; 
        final double co2SavedKg = await _carbonService.calculateCO2Saved(_currentVehicleType!, finalDistanceKm);
        final double creditsEarned = await _carbonService.calculateCreditsEarned(_currentVehicleType!, finalDistanceKm);
        
        final Map<String, dynamic> tripData = {
          'userId': userId, 'vehicleId': _currentVehicleId, 'vehicleType': _currentVehicleType!.name,
          'distanceKm': finalDistanceKm, 'startTime': Timestamp.fromDate(_tripStartTime!),
          'endTime': Timestamp.fromDate(tripEndTime), 'durationMinutes': tripEndTime.difference(_tripStartTime!).inMinutes,
          'origin': _currentOrigin.isNotEmpty ? _currentOrigin : null,
          'destination': _currentDestination.isNotEmpty ? _currentDestination : null,
          'co2SavedKg': co2SavedKg, 'creditsEarned': creditsEarned,
          'createdAt': FieldValue.serverTimestamp(), 'calculationMethod': 'gps',
          'plateImageURL': _plateImageURL, 'odometerStartImageURL': _odometerStartImageURL,
          'odometerEndImageURL': _odometerEndImageURL,
        };

        try {
          await FirebaseFirestore.instance.collection('trips').add(tripData);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viagem salva!'), backgroundColor: Colors.green));
          _originController.clear(); _destinationController.clear();
          _accumulatedDistanceMeters = 0.0; _currentDistanceKm = 0.0;
          _tripStartTime = null; _currentOrigin = ''; _currentDestination = '';
          _plateImageURL = null; _odometerStartImageURL = null; _odometerEndImageURL = null;
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: ${e.toString()}'), backgroundColor: Colors.redAccent));
        }
      } else {
        String message = 'Não foi possível salvar. ';
        if (_currentUser == null) message += 'Erro de usuário. ';
        if (_currentVehicleId.isEmpty || _currentVehicleType == null) message += 'Veículo inválido. ';
        if (_tripStartTime == null) message += 'Tempo inválido. ';
        if (finalDistanceKm <= 0.01) message += 'Distância curta. ';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.orangeAccent));
      }
      if (mounted) setState(() { _isLoadingGpsSave = false; _isTracking = false; });

    } else { // INICIANDO UMA VIAGEM
      if (_selectedVehicleIdForTrip == null || _selectedVehicleTypeForTrip == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um veículo.'), backgroundColor: Colors.orangeAccent));
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS desativado.')));
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão negada.')));
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão negada permanentemente.')));
        await _showPermissionDeniedPermanentlyDialog("localização");
        return;
      }

      bool startImagesOk = await _captureAndUploadStartImages();
      if (!startImagesOk) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotos iniciais obrigatórias. Viagem não iniciada.'), backgroundColor: Colors.redAccent));
        setState(() { _plateImageURL = null; _odometerStartImageURL = null; _isProcessingStartImages = false;});
        return; 
      }
      if (!mounted) return;

      setState(() {
        _isTracking = true; _accumulatedDistanceMeters = 0.0; _currentDistanceKm = 0.0;
        _lastPositionForTripStart = null; _tripStartTime = DateTime.now();
        _currentOrigin = _originController.text.trim(); _currentDestination = _destinationController.text.trim();
        _currentVehicleId = _selectedVehicleIdForTrip!; _currentVehicleType = _selectedVehicleTypeForTrip;
      });

      const LocationSettings locSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
      _positionStreamSubscriptionForTrip = Geolocator.getPositionStream(locationSettings: locSettings).listen(
        (Position position) {
          if (mounted && _isTracking) {
            setState(() {
              if (_lastPositionForTripStart != null) {
                double delta = Geolocator.distanceBetween(
                  _lastPositionForTripStart!.latitude, _lastPositionForTripStart!.longitude,
                  position.latitude, position.longitude,
                );
                if (delta > 1.0) {
                  _accumulatedDistanceMeters += delta;
                  _currentDistanceKm = _accumulatedDistanceMeters / 1000.0;
                }
              }
              _lastPositionForTripStart = position;
            });
          }
        },
        onError: (error) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro GPS: ${error.toString()}'), backgroundColor: Colors.redAccent));
        },
        cancelOnError: false,
      );
    }
  }

  // --- Widgets Builders ---
  Widget _buildIndicatorsSection(String userId) {
      final Color kmColor = Colors.blueAccent[100]!; final Color co2Color = Colors.greenAccent[400]!; final Color creditsColor = Colors.lightGreenAccent[400]!; final Color walletColor = Colors.amberAccent[100]!; final Color errorColor = Colors.redAccent[100]!;
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('trips').where('userId', isEqualTo: userId).snapshots(),
        builder: (context, tripSnapshot) {
          double totalKm = 0.0; double totalCO2 = 0.0; double totalCredits = 0.0; bool tripsHaveError = tripSnapshot.hasError; bool tripIndicatorsLoading = tripSnapshot.connectionState == ConnectionState.waiting;
          if (!tripsHaveError && tripSnapshot.hasData) { for (var doc in tripSnapshot.data!.docs) { final data = doc.data() as Map<String, dynamic>? ?? {}; final dist = (data['distanceKm'] as num?)?.toDouble() ?? 0.0; final co2 = (data['co2SavedKg'] as num?)?.toDouble() ?? 0.0; final cred = (data['creditsEarned'] as num?)?.toDouble() ?? 0.0; totalKm += dist; totalCO2 += co2; totalCredits += cred; } } else if(tripsHaveError) { debugPrint("[Indicators] Erro trip stream: ${tripSnapshot.error}"); }
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('wallets').doc(userId).snapshots(),
            builder: (context, walletSnapshot) {
              double walletBalance = 0.0; bool walletHasError = walletSnapshot.hasError; bool walletIsLoading = walletSnapshot.connectionState == ConnectionState.waiting; String walletValueForDisplay = "...";
              if (!walletIsLoading && !walletHasError && walletSnapshot.hasData) { if (walletSnapshot.data!.exists) { final d = walletSnapshot.data!.data() as Map<String, dynamic>?; if (d != null && d.containsKey('balance')) { walletBalance = (d['balance'] as num?)?.toDouble() ?? 0.0; walletValueForDisplay = "R\$ ${walletBalance.toStringAsFixed(2)}"; } else { walletHasError = true; walletValueForDisplay = "Inválido";} } else { walletValueForDisplay = "R\$ 0.00"; } } else if (walletHasError) { walletValueForDisplay = "Erro"; debugPrint("[Wallet Indicator] Erro wallet stream: ${walletSnapshot.error}"); }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 70.0),
                child: GridView.count(
                  crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10.0, crossAxisSpacing: 10.0,
                  childAspectRatio: 2.2,
                  children: [
                    IndicatorCard( title: 'KM TOTAL', isLoading: tripIndicatorsLoading, hasError: tripsHaveError, value: (tripIndicatorsLoading || tripsHaveError) ? (tripsHaveError ? 'Erro' : '') : '${totalKm.toStringAsFixed(1)} km', icon: Icons.drive_eta_outlined, accentColor: kmColor, ),
                    IndicatorCard( title: 'CO₂ SEQUESTRADO', isLoading: tripIndicatorsLoading, hasError: tripsHaveError, value: (tripIndicatorsLoading || tripsHaveError) ? (tripsHaveError ? 'Erro' : '') : '${totalCO2.abs().toStringAsFixed(2)} kg', icon: Icons.co2, accentColor: co2Color, ),
                    IndicatorCard( title: 'CRÉDITOS CARBONO', isLoading: tripIndicatorsLoading, hasError: tripsHaveError, value: (tripIndicatorsLoading || tripsHaveError) ? (tripsHaveError ? 'Erro' : '') : totalCredits.toStringAsFixed(4), icon: Icons.toll_outlined, accentColor: creditsColor, ),
                    IndicatorCard( title: 'CARTEIRA B2Y', isLoading: walletIsLoading, hasError: walletHasError, value: (walletIsLoading || walletHasError) ? (walletHasError ? 'Erro' : '') : walletValueForDisplay, icon: Icons.account_balance_wallet_outlined, accentColor: walletHasError ? errorColor : walletColor, ),
                  ],
                ).animate().fadeIn(delay: 200.ms),
              );
            },
          );
        },
      );
    }

  Widget _buildProgressBarSection() {
    double currentProgress = 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        children: [
          CircularPercentIndicator( radius: 35.0, lineWidth: 8.0, percent: currentProgress, center: Text( "${(currentProgress * 100).toInt()}%", style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70), ), progressColor: Colors.cyanAccent[400], backgroundColor: Colors.grey[800]!, circularStrokeCap: CircularStrokeCap.round, animateFromLastPercent: true, animation: true, ),
          const SizedBox(width: 16),
          Expanded( child: Text( "Economizando CO₂ com transporte sustentável", style: GoogleFonts.poppins( fontSize: 14, color: Colors.white.withAlpha((255 * 0.8).round()), ), ), ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildActionButtons() {
    final Color accentColor = Colors.cyanAccent[400]!; final Color selectedColor = accentColor; final Color unselectedColor = Colors.grey[850]!; const Color selectedTextColor = Colors.black87; const Color unselectedTextColor = Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
            Expanded( child: ElevatedButton.icon( icon: const Icon(Icons.gps_fixed_rounded, size: 18), label: const Text("Monitorar GPS"), onPressed: () { if(_tabController.index != 0) _tabController.animateTo(0); }, style: ElevatedButton.styleFrom( backgroundColor: _tabController.index == 0 ? selectedColor : unselectedColor, foregroundColor: _tabController.index == 0 ? selectedTextColor : unselectedTextColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12), side: _tabController.index != 0 ? BorderSide(color: Colors.grey[700]!) : null ), ), ),
            const SizedBox(width: 12),
            Expanded( child: ElevatedButton.icon( icon: const Icon(Icons.calculate_rounded, size: 18), label: const Text("Calcular Rota"), onPressed: () { if(_tabController.index != 1) _tabController.animateTo(1); }, style: ElevatedButton.styleFrom( backgroundColor: _tabController.index == 1 ? selectedColor : unselectedColor, foregroundColor: _tabController.index == 1 ? selectedTextColor : unselectedTextColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12), side: _tabController.index != 1 ? BorderSide(color: Colors.grey[700]!) : null ), ), ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildGpsTrackingTabContent(ThemeData theme, Color subtleTextColor, Color primaryColor){
      final errorColor = theme.colorScheme.error; final accentColor = primaryColor;
      bool isCurrentlyProcessingImages = _isProcessingStartImages || _isProcessingEndImage;

      return Card( elevation: 4, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), color: Colors.grey[900]?.withAlpha((255 * 0.5).round()),
        child: Padding( padding: const EdgeInsets.all(20.0),
          child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Monitorar Viagem GPS', style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 20),
            GestureDetector(
              onTap: (_isTracking || isCurrentlyProcessingImages) ? null : _showVehicleSelectionDialogForTracking,
              child: ListTile( contentPadding: EdgeInsets.zero, dense: true, leading: Icon( _selectedVehicleTypeForTrip?.icon ?? Icons.directions_car, color: _selectedVehicleIdForTrip != null ? (_selectedVehicleTypeForTrip?.displayColor ?? accentColor) : subtleTextColor, size: 32, ), title: Text('Veículo Selecionado:', style: theme.textTheme.bodySmall?.copyWith(color: subtleTextColor)), subtitle: Text( _selectedVehicleIdForTrip != null ? '${_selectedVehicleTypeForTrip?.displayName ?? 'Tipo Desconhecido'} (Toque para alterar)' : "Selecione um veículo", style: theme.textTheme.bodyMedium?.copyWith( fontWeight: _selectedVehicleIdForTrip != null ? FontWeight.bold : FontWeight.normal, color: _selectedVehicleIdForTrip == null ? errorColor : Colors.white70 ) ), ),
            ), const SizedBox(height: 15),
            TextFormField( controller: _originController, enabled: !_isTracking && !isCurrentlyProcessingImages, style: const TextStyle(color: Colors.white), decoration: InputDecoration( labelText: 'Origem (Opcional)', labelStyle: TextStyle(color: subtleTextColor), hintText: 'Ex: Casa, Trabalho...', hintStyle: TextStyle(color: subtleTextColor.withAlpha((255 * 0.5).round())), isDense: true, prefixIcon: Icon(Icons.trip_origin, color: subtleTextColor), filled: true, fillColor: Colors.black.withAlpha((255 * 0.2).round()), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor)), ), ), const SizedBox(height: 12),
            TextFormField( controller: _destinationController, enabled: !_isTracking && !isCurrentlyProcessingImages, style: const TextStyle(color: Colors.white), decoration: InputDecoration( labelText: 'Destino (Opcional)', labelStyle: TextStyle(color: subtleTextColor), hintText: 'Ex: Mercado, Academia...', hintStyle: TextStyle(color: subtleTextColor.withAlpha((255 * 0.5).round())), isDense: true, prefixIcon: Icon(Icons.flag_outlined, color: subtleTextColor), filled: true, fillColor: Colors.black.withAlpha((255 * 0.2).round()), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor)), ), ), const SizedBox(height: 20),
            
            if (_isTracking) 
              Center( child: Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.route, color: accentColor, size: 26), const SizedBox(width: 8), Text( '${_currentDistanceKm.toStringAsFixed(2)} km', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accentColor) ), const SizedBox(width: 10), SpinKitPulse(color: accentColor, size: 15.0) ] ) ) ).animate(onPlay: (c)=>c.repeat()).shimmer(delay: 400.ms, duration: 1000.ms, color: Colors.white.withAlpha((255 * 0.1).round())),
            
            const SizedBox(height: 20),

            Center(
              child: (_isLoadingGpsSave || _isProcessingStartImages || _isProcessingEndImage)
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        SpinKitWave(color: accentColor, size: 25.0),
                        const SizedBox(height: 8),
                        Text(
                          _isProcessingStartImages ? "Processando fotos iniciais..." : 
                          _isProcessingEndImage ? "Processando foto final..." :
                          _isLoadingGpsSave ? "Salvando viagem..." : "Aguarde...",
                          style: TextStyle(color: subtleTextColor)
                        )
                      ],
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: (_selectedVehicleIdForTrip != null || _isTracking) ? _toggleTracking : null,
                    icon: Icon( _isTracking ? Icons.stop_circle_outlined : Icons.play_circle_outline, size: 24),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(_isTracking ? 'Parar e Salvar Viagem' : 'Iniciar Viagem', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTracking ? errorColor.withAlpha((255 * 0.9).round()) : accentColor,
                      foregroundColor: _isTracking ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 8,
                      shadowColor: _isTracking ? errorColor : accentColor,
                    ),
                  ).animate().scale(delay: 100.ms),
            ),
            if (!_isTracking && _selectedVehicleIdForTrip == null && !isCurrentlyProcessingImages)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Center(
                  child: Text( "Selecione um veículo na lista abaixo\npara iniciar o monitoramento.", style: theme.textTheme.bodySmall?.copyWith(color: errorColor.withAlpha((255 * 0.8).round())), textAlign: TextAlign.center, )
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSectionHeader(ThemeData theme, Color primaryColor) {
      final titleColor = Colors.white.withAlpha((255 * 0.9).round());
      final buttonColor = primaryColor;
      return Padding( padding: const EdgeInsets.only(top: 16.0),
        child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text( 'Meus Veículos', style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor) ),
            Row( mainAxisSize: MainAxisSize.min, children: [ TextButton.icon( icon: Icon(Icons.add_circle_outline, size: 18, color: buttonColor), label: Text('Adicionar', style: TextStyle(color: buttonColor.withAlpha((255 * 0.8).round()), fontSize: 13)), style: TextButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 8), ), onPressed: _navigateToAddVehicle ), const SizedBox(width: 0), TextButton.icon( icon: Icon(Icons.list_alt_rounded, size: 18, color: Colors.grey[500]), label: Text('Gerenciar', style: TextStyle(color: Colors.grey[500], fontSize: 13)), style: TextButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 8), ), onPressed: _navigateToFleetManagement ), ], ) ], ), );
    }

  Widget _buildVehicleList(String userId, ThemeData theme, Color primaryColor, Color subtleTextColor) {
      final cardColor = Colors.grey[850]!.withAlpha((255 * 0.6).round()); 
      final selectedBorderColor = primaryColor; final normalBorderColor = Colors.grey[700]!; 
      final titleColor = Colors.white.withAlpha((255 * 0.9).round()); 
      final subtitleColorUsed = Colors.white.withAlpha((255 * 0.6).round()); 
      const iconColor = Colors.white70; final accentColor = primaryColor;
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehicles').where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) { return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 30.0), child: CircularProgressIndicator(strokeWidth: 2, color: accentColor))); }
          if (snapshot.hasError) { return Center(child: Text('Erro ao carregar veículos.', style: TextStyle(color: theme.colorScheme.error))); }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { return Card( elevation: 1, color: cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding( padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0), child: Column( mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.directions_car_outlined, color: subtitleColorUsed, size: 30), const SizedBox(height: 10), Text( 'Nenhum veículo cadastrado.', textAlign: TextAlign.center, style: TextStyle(color: subtitleColorUsed) ), const SizedBox(height: 15), ElevatedButton.icon( icon: const Icon(Icons.add, size: 18), onPressed: _navigateToAddVehicle, label: const Text("Adicionar Veículo"), style: ElevatedButton.styleFrom( backgroundColor: accentColor, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), ), ) ], ) ), ).animate().fadeIn(); }
          final vehicleDocs = snapshot.data!.docs;
          return ListView.separated(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: vehicleDocs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                final vehicleData = vehicleDocs[index].data() as Map<String, dynamic>; final vehicleId = vehicleDocs[index].id; final vehicleType = vehicleTypeFromString(vehicleData['type']); final isSelected = vehicleId == _selectedVehicleIdForTrip;
                return Card( margin: EdgeInsets.zero, elevation: isSelected ? 6 : 2, color: cardColor, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12), side: BorderSide( color: isSelected ? selectedBorderColor : normalBorderColor, width: isSelected ? 2.0 : 0.8, ) ), child: InkWell( onTap: () => _handleVehicleSelection(vehicleId, vehicleType), borderRadius: BorderRadius.circular(12), splashColor: accentColor.withAlpha((255 * 0.2).round()), highlightColor: accentColor.withAlpha((255 * 0.1).round()), child: Padding( padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0), child: ListTile( dense: true, contentPadding: EdgeInsets.zero, leading: Icon( vehicleType?.icon ?? Icons.help_outline, color: isSelected ? accentColor : (vehicleType?.displayColor ?? iconColor), size: 28, ), title: Text( '${vehicleData['make'] ?? '?'} ${vehicleData['model'] ?? '?'}', style: TextStyle( fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 15, color: titleColor ) ), subtitle: Text( '${vehicleData['year'] ?? '?'} - ${vehicleData['licensePlate'] ?? 'Sem placa'}\nTipo: ${vehicleType?.displayName ?? vehicleData['type'] ?? '?'}', style: TextStyle(color: subtitleColorUsed, fontSize: 12.5, height: 1.3) ), trailing: isSelected ? Icon(Icons.check_circle, color: selectedBorderColor, size: 22) : Icon(Icons.radio_button_unchecked, color: subtitleColorUsed.withAlpha((255 * 0.5).round()), size: 20), ), ), ), ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1); }, ); }, );
    }

  Widget _buildNavigationButtons() {
      final buttonColor = Colors.grey[800]; const iconColor = Colors.white70; const textColor = Colors.white70;
      return Padding( padding: const EdgeInsets.only(top: 16.0),
        child: Wrap( spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            ElevatedButton.icon( style: ElevatedButton.styleFrom( backgroundColor: buttonColor, foregroundColor: textColor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) ), icon: const Icon(Icons.history, size: 18, color: iconColor), label: const Text('Histórico', style: TextStyle(fontSize: 13)), onPressed: _navigateToTripHistory),
            ElevatedButton.icon( style: ElevatedButton.styleFrom( backgroundColor: buttonColor, foregroundColor: textColor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) ), icon: const Icon(Icons.account_balance_wallet, size: 18, color: iconColor), label: const Text('Carteira', style: TextStyle(fontSize: 13)), onPressed: () {}),
            ElevatedButton.icon( style: ElevatedButton.styleFrom( backgroundColor: buttonColor, foregroundColor: textColor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) ), icon: const Icon(Icons.store, size: 18, color: iconColor), label: const Text('Mercado', style: TextStyle(fontSize: 13)), onPressed: () {}),
          ], ).animate().fadeIn(delay: 800.ms), );
    }

  Widget _buildScrollableTabContent(Widget tabSpecificContent) {
    final theme = Theme.of(context);
    final primaryColor = Colors.cyanAccent[400]!;
    final subtleTextColor = Colors.white.withAlpha((255 * 0.6).round());
    final user = _currentUser;
    if (user == null) return const Center(child: Text("Erro: Usuário não encontrado."));
    final String userId = user.uid;

    return ListView(
      primary: false, 
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 80.0),
      children: [
        const AdBannerPlaceholder(), const SizedBox(height: 20),
        _buildIndicatorsSection(userId), const SizedBox(height: 10),
        _buildProgressBarSection(),
        Divider(height: 30, thickness: 0.5, color: Colors.grey[800]),
        tabSpecificContent, const SizedBox(height: 30),
        _buildVehicleSectionHeader(theme, primaryColor), const SizedBox(height: 16),
        _buildVehicleList(userId, theme, primaryColor, subtleTextColor), const SizedBox(height: 30),
        Text('Desempenho Recente', style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white.withAlpha((255 * 0.9).round()))), const SizedBox(height: 16),
        TripChartPlaceholder(primaryColor: primaryColor).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2), const SizedBox(height: 30),
        Text('Mapa de Eletropostos (Simulado)', style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white.withAlpha((255 * 0.9).round()))), const SizedBox(height: 16),
        const MinimapPlaceholder(showUserMarker: true), const SizedBox(height: 30),
        _buildNavigationButtons(), const SizedBox(height: 20),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    final theme = Theme.of(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final displayName = userProvider.userName?.isNotEmpty == true ? userProvider.userName! : user?.email?.split('@')[0] ?? 'Usuário';
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }
    final Color accentColor = Colors.cyanAccent[400]!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                elevation: 1.0, backgroundColor: theme.scaffoldBackgroundColor,
                pinned: true, floating: true, expandedHeight: 150.0,
                collapsedHeight: kToolbarHeight + 48,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 10.0, bottom: 50),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('B2Y Carbon Cockpit', style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white.withAlpha((255 * 0.95).round()))),
                              IconButton(icon: Icon(Icons.power_settings_new_rounded, color: accentColor), tooltip: 'Sair', onPressed: _logout)
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Olá, $displayName!',
                            style: GoogleFonts.poppins(textStyle: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500, color: Colors.white.withAlpha((255 * 0.8).round())))
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController, indicatorColor: accentColor, indicatorWeight: 3.0,
                  labelColor: accentColor, unselectedLabelColor: Colors.grey[600],
                  labelStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: GoogleFonts.rajdhani(fontSize: 13),
                  tabs: const [ Tab(text: 'MONITORAR'), Tab(text: 'CALCULAR'), ],
                ),
              ),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildActionButtons()
              )),
              SliverToBoxAdapter(child: Divider(height: 1, thickness: 0.5, color: Colors.grey[800], indent: 16, endIndent: 16)),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildScrollableTabContent(
                _buildGpsTrackingTabContent(theme, Colors.grey[500]!, accentColor)
              ),
              _buildScrollableTabContent(
                const TripCalculatorWidget()
              ),
            ],
          ),
        ),
      ),
    );
  }
}