// lib/screens/dashboard_screen.dart (VERSÃO FINAL COM STRIPE E GPS NA WEB ATIVADO)
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:carbon/screens/buy_coins_screen.dart';
import 'package:carbon/screens/marketplace_screen.dart';
import 'package:carbon/screens/premium_screen.dart';
import 'package:carbon/services/wallet_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:carbon/providers/user_provider.dart';
import 'package:carbon/screens/registration_screen.dart';
import 'package:carbon/models/vehicle_type_enum.dart';
import 'package:carbon/services/carbon_service.dart';
import 'package:carbon/screens/fleet_management_screen.dart';
import 'package:carbon/screens/trip_history_screen.dart';
import 'package:carbon/widgets/indicator_card.dart';
import 'package:carbon/widgets/trip_chart_placeholder.dart';
import 'package:carbon/widgets/ad_banner_placeholder.dart';
import 'package:carbon/widgets/minimap_placeholder.dart';
import 'package:carbon/screens/transaction_history_screen.dart';
import 'package:carbon/screens/admin_screen.dart';

class _InfoRowSimulator extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _InfoRowSimulator({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14.5))),
          Text(value, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  // Todas as variáveis de estado...
  bool _isTracking = false;
  bool _isLoadingGpsSave = false;
  double _currentDistanceKm = 0.0;
  String? _selectedVehicleIdForTrip;
  VehicleType? _selectedVehicleTypeForTrip;
  String? _selectedVehicleDisplayNameForTrip;
  StreamSubscription<Position>? _positionStreamSubscriptionForTrip;
  Position? _lastPositionForTripStart;
  double _accumulatedDistanceMeters = 0.0;
  DateTime? _tripStartTime;
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final CarbonService _carbonService = CarbonService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  String? _plateImageURL;
  String? _odometerStartImageURL;
  String? _odometerEndImageURL;
  bool _isProcessingStartImages = false;
  bool _isProcessingEndImage = false;
  String? _recognizedPlateText;
  String? _recognizedOdometerStartText;
  String? _recognizedOdometerEndText;
  TabController? _tabController;
  bool _isFetchingGpsTabOrigin = false;
  final _simulatedDistanceKmController = TextEditingController();
  final _simulatedOriginController = TextEditingController();
  final _simulatedDestinationController = TextEditingController();
  String? _selectedVehicleIdForSimulator;
  VehicleType? _selectedVehicleTypeForSimulator;
  String? _simulatedVehicleDisplayName;
  TripCalculationResult? _simulationResult;
  bool _isCalculatingSimulation = false;
  bool _isFetchingDistance = false;
  bool _isFetchingCurrentLocationCity = false;
  Stream<double>? _totalCo2OffsetStream;
  bool _isInitiatingPayment = false;
  static const double _brlPerKgCo2 = 0.25;

  final FocusNode _simulatedOriginFocusNode = FocusNode();
  final FocusNode _simulatedDestinationFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchAndSetGpsTabOriginCity();
    _tabController = TabController(length: 2, vsync: this);
    if (_currentUser != null) {
      _initializeOffsetStream();
    }
    _simulatedDestinationFocusNode.addListener(_onDestinationFocusChange);
  }
  
  void _onDestinationFocusChange() {
    if (!_simulatedDestinationFocusNode.hasFocus &&
        _simulatedOriginController.text.trim().isNotEmpty &&
        _simulatedDestinationController.text.trim().isNotEmpty) {
      _fetchAndSetDistance();
    }
  }
  
  void _initializeOffsetStream() {
    if (_currentUser == null) return;
    _totalCo2OffsetStream = FirebaseFirestore.instance
      .collection('carbon_offsets')
      .where('userId', isEqualTo: _currentUser!.uid)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) {
          return 0.0;
        }
        double total = 0.0;
        for (var doc in snapshot.docs) {
          total += (doc.data()['offsetAmountKg'] as num?)?.toDouble() ?? 0.0;
        }
        return total;
      }).handleError((error) {
        return 0.0;
      });
  }

  /// Inicia o processo de pagamento para a compensação de carbono.
  /// Chama a Cloud Function que cria uma sessão de checkout no Stripe.
  Future<void> _initiateCompensationPayment({required double cost, required double co2ToOffset}) async {
    // ATENÇÃO: Substitua pelo seu ID de PREÇO real do Stripe (modo de teste/produção).
    const String carbonOffsetPriceId = "price_1P8g8Y4Ie0XV5ATGXRL1Vv8H"; 

    if (!mounted) return;
    setState(() => _isInitiatingPayment = true);
    
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final callable = functions.httpsCallable('createStripeCheckout');

      final HttpsCallableResult result = await callable.call<Map<String, dynamic>>({
        'priceId': carbonOffsetPriceId, 
        'userId': _currentUser?.uid,
        'co2ToOffset': co2ToOffset,
        'costBRL': cost,
      });

      final checkoutUrl = result.data?['url'];
      if (checkoutUrl != null) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Não foi possível abrir a página de pagamento.';
        }
      } else {
        throw 'Não foi possível obter a URL de pagamento do servidor.';
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar pagamento: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInitiatingPayment = false);
      }
    }
  }

  /// Exibe o diálogo de compensação com a lógica de pagamento real via Stripe.
  Future<void> _showCompensationDialog({required double co2ToOffset, required double cost}) async {
    if (!mounted) return;
    
    setState(() => _isInitiatingPayment = false);

    await showDialog(
      context: context,
      barrierDismissible: !_isInitiatingPayment,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2c2c2e),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Compensar Emissão de CO₂',
                style: GoogleFonts.orbitron(color: Colors.greenAccent[400], fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ajude o planeta compensando sua pegada de carbono. Você será redirecionado para um ambiente de pagamento seguro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'VALOR PARA COMPENSAR:',
                      style: GoogleFonts.rajdhani(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      'R\$ ${cost.toStringAsFixed(2)}',
                      style: GoogleFonts.orbitron(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '(${co2ToOffset.toStringAsFixed(2)} kg de CO₂)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              actions: [
                if (_isInitiatingPayment)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SpinKitFadingCircle(color: Colors.greenAccent, size: 30),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.payment),
                        label: const Text('Pagar com PIX, Cartão ou Boleto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          await _initiateCompensationPayment(cost: cost, co2ToOffset: co2ToOffset);
                          if(mounted) {
                             Navigator.of(dialogContext).pop();
                          }
                        },
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Agora não', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  )
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _positionStreamSubscriptionForTrip?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _tabController?.dispose();
    _simulatedDistanceKmController.dispose();
    _simulatedOriginController.dispose();
    _simulatedDestinationController.dispose();
    
    _simulatedOriginFocusNode.dispose();
    _simulatedDestinationFocusNode.removeListener(_onDestinationFocusChange);
    _simulatedDestinationFocusNode.dispose();

    super.dispose();
  }
  
  Future<String> _getCityFromCoordinates(Position position) async {
    try {
      const String cloudFunctionUrl = 'https://getcityfromcoordinates-ki3ven47oa-uc.a.run.app';
      final String requestUrl = '$cloudFunctionUrl?lat=${position.latitude}&lng=${position.longitude}';
      final response = await http.get(Uri.parse(requestUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final results = data['results'] as List;
          String? city;
          for (var result in results) {
            final addressComponents = result['address_components'] as List;
            for (var component in addressComponents) {
              final types = component['types'] as List;
              if (types.contains('locality')) { 
                  city = component['long_name']; 
                  break; 
              }
            }
            if (city != null) break;
          }
          if (city == null) {
            for (var result in results) {
              final addressComponents = result['address_components'] as List;
              for (var component in addressComponents) {
                final types = component['types'] as List;
                if (types.contains('administrative_area_level_2')) { 
                    city = component['long_name']; 
                    break; 
                }
              }
              if (city != null) break;
            }
          }
          return city ?? 'Local Desconhecido';
        }
      }
    } catch (e) {
      // Silently fail
    }
    return 'Local Desconhecido';
  }

  Future<void> _fetchAndSetGpsTabOriginCity() async {
    if (!mounted) return;
    setState(() => _isFetchingGpsTabOrigin = true);
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS desativado. Não foi possível detectar a origem.')));
        }
        _originController.text = '';
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de localização negada para detectar origem.')));
          _originController.text = '';
          return;
        }
      }
      if (permission == LocationPermission.deniedForever && mounted) {
        await _showPermissionDeniedPermanentlyDialog("localização para cidade origem");
        _originController.text = '';
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      final String city = await _getCityFromCoordinates(position);

      if (mounted) {
        if (city != 'Local Desconhecido') {
          setState(() => _originController.text = city);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível determinar a cidade de origem automaticamente.'), backgroundColor: Colors.orangeAccent));
          _originController.text = '';
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao obter localização/cidade para origem: $e'), backgroundColor: Colors.red));
      }
      _originController.text = '';
    } finally {
      if (mounted) setState(() => _isFetchingGpsTabOrigin = false);
    }
  }

  Future<void> _showPermissionDeniedPermanentlyDialog(String permissionType) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissão Necessária'),
        content: Text(
          kIsWeb
              ? 'A permissão para $permissionType foi negada. Por favor, habilite a permissão de localização para este site nas configurações do seu navegador (Safari, Chrome, etc.).'
              : 'A permissão para $permissionType foi negada permanentemente. Habilite nas configurações do aplicativo.',
        ),
        actions: <Widget>[
          TextButton(
            child: const Text(kIsWeb ? 'Fechar' : 'Cancelar'),
            onPressed: () {
              if (mounted) Navigator.of(ctx).pop();
            },
          ),
          if (!kIsWeb)
            TextButton(
              onPressed: () {
                if (mounted) {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                }
              },
              child: const Text('Abrir Configurações'),
            ),
        ],
      ),
    );
  }
  
  void _navigateToAddVehicle() { if (mounted) {Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const RegistrationScreen()));} }
  void _navigateToFleetManagement() { if (mounted) {Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const FleetManagementScreen()));} }
  void _navigateToTripHistory() { if (mounted) {Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const TripHistoryScreen()));} }
  Future<void> _logout() async {
    if (mounted) {Provider.of<UserProvider>(context, listen: false).clearUserDataOnLogout();}
    await FirebaseAuth.instance.signOut();
  }

  Future<XFile?> _pickImageWithCamera(String imagePurpose) async {
    if (!kIsWeb) {
      PermissionStatus cameraStatus = await Permission.camera.request();
      if (!mounted) return null;
      if (!cameraStatus.isGranted) {
        if (cameraStatus.isPermanentlyDenied) {
          if (mounted) await _showPermissionDeniedPermanentlyDialog("câmera");
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permissão para câmera não concedida para $imagePurpose.'), backgroundColor: Colors.orangeAccent));
        }
        return null;
      }
    }
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 60, maxWidth: 1280, maxHeight: 1280);
      return pickedFile;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao usar a câmera para $imagePurpose: $e'), backgroundColor: Colors.redAccent));
      return null;
    }
  }

  Future<String?> _uploadImageToFirebaseStorage(XFile imageFile, String imageTypeForPath) async {
    if (_currentUser == null) return null;
    final String fileName = '${_currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}_$imageTypeForPath.jpg';
    final Reference storageReference = FirebaseStorage.instance.ref().child('trip_verification_images').child(fileName);
    try {
      Uint8List imageBytes = await imageFile.readAsBytes();
      final SettableMetadata metadata = SettableMetadata(contentType: 'image/jpeg');
      UploadTask uploadTask = storageReference.putData(imageBytes, metadata);
      TaskSnapshot taskSnapshot = await uploadTask;
      return await taskSnapshot.ref.getDownloadURL();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha no upload ($imageTypeForPath). Detalhes: $e'), backgroundColor: Colors.redAccent));
      return null;
    }
  }

  Future<String?> _processImageWithOCR(XFile imageFile, String imageType) async {
    if (!mounted) return null;
    String? processedTextResult;
    try {
      const String apiKey = "AIzaSyDy_WBvHCk13hGIfqEP_VPEDu436PvMF0E"; 
      final Uri url = Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey');
      final Uint8List imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      final Map<String, dynamic> requestBody = {
        "requests": [{"image": {"content": base64Image},"features": [{"type": "TEXT_DETECTION"}]}]
      };
      if (!mounted) return null;
      final http.Response response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: json.encode(requestBody));
      if (!mounted) return null;
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['responses'] != null && responseData['responses'].isNotEmpty && responseData['responses'][0]['fullTextAnnotation'] != null) {
          String fullText = responseData['responses'][0]['fullTextAnnotation']['text'];
          List<String> lines = fullText.split('\n');
          List<String> plateCandidates = [];
          String? foundOdometerInLines;
          if (imageType == 'odometer_start' || imageType == 'odometer_end') {
            for (String lineContent in lines) { 
              String trimmedLine = lineContent.trim();
              if (trimmedLine.isEmpty) continue;
              String numbersFromLine = trimmedLine.replaceAll(RegExp(r'[^0-9]'), '');
              if (numbersFromLine.length == 6) {
                foundOdometerInLines = numbersFromLine;
                break; 
              }
            }
            if (foundOdometerInLines == null) { 
              for (String lineContent in lines) {
                String trimmedLine = lineContent.trim();
                if (trimmedLine.isEmpty) continue;
                String numbersFromLine = trimmedLine.replaceAll(RegExp(r'[^0-9]'), '');
                if (numbersFromLine.length == 5 || numbersFromLine.length == 7) {
                  foundOdometerInLines = numbersFromLine;
                  break;
                }
              }
            }
          }
          
          if (imageType == 'plate') {
             for (String lineContent in lines) {
               String trimmedLine = lineContent.trim();
               if (trimmedLine.isEmpty) continue;
                String cleanedLineAlphanumeric = trimmedLine.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
                if (cleanedLineAlphanumeric.length >= 6 && cleanedLineAlphanumeric.length <= 7) {
                  plateCandidates.add(cleanedLineAlphanumeric);
                }
             }
          }
          
          if (imageType == 'plate') {
            if (plateCandidates.isNotEmpty) {
              RegExp mercosulPattern = RegExp(r'^[A-Z]{3}[0-9][A-Z][0-9]{2}$');
              RegExp antigaPattern = RegExp(r'^[A-Z]{3}[0-9]{4}$');
              String? bestPlateCandidate;
              for (String candidate in plateCandidates.reversed) {
                if (mercosulPattern.hasMatch(candidate) || antigaPattern.hasMatch(candidate)) {
                  bestPlateCandidate = candidate;
                  break; 
                }
              }
              if (bestPlateCandidate == null && plateCandidates.isNotEmpty) {
                bestPlateCandidate = plateCandidates.lastWhere((p) => p.length == 7, 
                                    orElse: () => plateCandidates.lastWhere((p) => p.length == 6, 
                                    orElse: () => plateCandidates.last));
              }

              if (bestPlateCandidate != null) {
                setState(() => _recognizedPlateText = bestPlateCandidate);
                processedTextResult = bestPlateCandidate;
              } else {
                setState(() => _recognizedPlateText = null);
              }
            } else {
              setState(() => _recognizedPlateText = null);
            }
          } else if (imageType == 'odometer_start' || imageType == 'odometer_end') {
            if (foundOdometerInLines != null) {
              processedTextResult = foundOdometerInLines;
              if (imageType == 'odometer_start') {
                setState(() => _recognizedOdometerStartText = processedTextResult);
              } else {
                setState(() => _recognizedOdometerEndText = processedTextResult);
              }
            } else {
              if (imageType == 'odometer_start') {
                setState(() => _recognizedOdometerStartText = null);
              } else {
                setState(() => _recognizedOdometerEndText = null);
              }
            }
          }
        } else { 
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OCR (Nuvem): Nenhum texto detectado.'), backgroundColor: Colors.orangeAccent));
          if (imageType == 'plate') setState(() => _recognizedPlateText = null);
          if (imageType == 'odometer_start') setState(() => _recognizedOdometerStartText = null);
          if (imageType == 'odometer_end') setState(() => _recognizedOdometerEndText = null);
        }
      } else { 
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro no OCR (Nuvem): Cód ${response.statusCode}'), backgroundColor: Colors.redAccent));
      }
    } catch (e) { 
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao processar OCR (Nuvem): $e'), backgroundColor: Colors.orangeAccent));
    }
    return processedTextResult;
  }

  Future<bool> _captureAndUploadStartImages() async {
    if (!mounted) return false;
    setState(() => _isProcessingStartImages = true);
    bool allOk = false;
    try {
      bool? readyForPlatePhoto;
      if (mounted) {
        readyForPlatePhoto = await showDialog<bool>(
          context: context, 
          barrierDismissible: false, 
          builder: (ctx) => AlertDialog(
            title: const Text('Foto da Placa'), 
            content: const Text('Tire uma foto nítida da placa.'), 
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('OK'))]
          )
        );
      }
      if (!mounted || readyForPlatePhoto != true) { 
        if (readyForPlatePhoto == null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Captura da placa cancelada.'), backgroundColor: Colors.orangeAccent));
        return false;
      }

      XFile? plateImage = await _pickImageWithCamera('Placa');
      if (plateImage == null) { 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto da placa é obrigatória.'), backgroundColor: Colors.orangeAccent));
        return false; 
      }

      String? ocrPlateResult = await _processImageWithOCR(plateImage, 'plate');
      if (!mounted) return false;
      if (ocrPlateResult == null || ocrPlateResult.isEmpty) { 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível ler a placa. Tente uma foto melhor.'), backgroundColor: Colors.orangeAccent, duration: Duration(seconds: 3)));
        return false; 
      }

      _plateImageURL = await _uploadImageToFirebaseStorage(plateImage, 'plate');
      if (_plateImageURL == null) return false;
      if (!mounted) return false;

      bool? readyForOdoStart;
      if (mounted) {
        readyForOdoStart = await showDialog<bool>(
          context: context, 
          barrierDismissible: false, 
          builder: (ctx) => AlertDialog(
            title: const Text('Hodômetro Inicial'), 
            content: const Text('Tire uma foto do hodômetro inicial.'), 
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('OK'))]
          )
        );
      }
      if (!mounted || readyForOdoStart != true) { 
        if (readyForOdoStart == null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Captura do hodômetro inicial cancelada.'), backgroundColor: Colors.orangeAccent));
        return false; 
      }

      XFile? odoStartImage = await _pickImageWithCamera('Hodômetro Inicial');
      if (odoStartImage == null) { 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto do hodômetro inicial é obrigatória.'), backgroundColor: Colors.orangeAccent));
        return false; 
      }
      
      String? ocrOdometerResult = await _processImageWithOCR(odoStartImage, 'odometer_start');
      if (!mounted) return false;
      if (ocrOdometerResult == null || ocrOdometerResult.isEmpty) { 
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hodômetro inicial não lido ou inválido. Tente uma foto melhor ou prossiga com cautela.'), backgroundColor: Colors.orangeAccent, duration: Duration(seconds: 4)));
      }

      _odometerStartImageURL = await _uploadImageToFirebaseStorage(odoStartImage, 'odometer_start');
      allOk = _plateImageURL != null && _odometerStartImageURL != null; 
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao capturar imagens iniciais: $e'), backgroundColor: Colors.redAccent));
      allOk = false;
    } finally {
      if (mounted) setState(() => _isProcessingStartImages = false);
    }
    return allOk;
  }

  Future<bool> _captureAndUploadEndOdometerImage() async {
    if (!mounted) return false;
    setState(() => _isProcessingEndImage = true);
    bool success = false; 
    try {
      bool? readyForOdoEnd;
      if (mounted) {
        readyForOdoEnd = await showDialog<bool>(
          context: context, 
          barrierDismissible: false, 
          builder: (ctx) => AlertDialog(
            title: const Text('Hodômetro Final'), 
            content: const Text('Tire uma foto do hodômetro final.'), 
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('OK'))]
          )
        );
      }
      if (!mounted || readyForOdoEnd != true) { 
        if (readyForOdoEnd == null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Captura do hodômetro final cancelada.'), backgroundColor: Colors.orangeAccent));
        return false;
      }

      XFile? odoEndImage = await _pickImageWithCamera('Hodômetro Final');
      if (odoEndImage == null) return false; 

      String? ocrOdometerResult = await _processImageWithOCR(odoEndImage, 'odometer_end');
      if (!mounted) return false;
      if (ocrOdometerResult == null || ocrOdometerResult.isEmpty) { 
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hodômetro final não lido ou inválido. O registro seguirá, mas verifique os dados.'), backgroundColor: Colors.orangeAccent, duration: Duration(seconds: 4)));
      }
      
      _odometerEndImageURL = await _uploadImageToFirebaseStorage(odoEndImage, 'odometer_end');
      if (_odometerEndImageURL != null) {
          success = true;
      } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha no upload da foto do hodômetro final.'), backgroundColor: Colors.orangeAccent));
      }
    } catch (e) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao capturar imagem final: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isProcessingEndImage = false);
    }
    return success;
  }
  
  Future<Map<String, dynamic>?> _fetchAndShowVehicleSelectionDialog() async {
    if (_currentUser == null) return null;
    final vehiclesSnapshot = await FirebaseFirestore.instance.collection('vehicles').where('userId', isEqualTo: _currentUser!.uid).get();
    if (!mounted) return null;
    if (vehiclesSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum veículo cadastrado.')));
      return null;
    }
    final modelIds = vehiclesSnapshot.docs.map((doc) => doc.data()['modelId'] as String?).where((id) => id != null).toList();
    if (modelIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veículos com formato antigo. Cadastre novamente.'), backgroundColor: Colors.orange));
        return null;
    }
    final modelsSnapshot = await FirebaseFirestore.instance.collection('vehicle_models').where(FieldPath.documentId, whereIn: modelIds).get();
    final modelsDataMap = { for (var doc in modelsSnapshot.docs) doc.id: doc.data() };
    final userVehicles = vehiclesSnapshot.docs.map((vehicleDoc) {
      final vehicleInfo = vehicleDoc.data();
      final modelId = vehicleInfo['modelId'] as String?;
      final modelData = modelsDataMap[modelId];
      if (modelData == null) return null;
      final type = vehicleTypeFromString(modelData['type'] as String?);
      return {
        'userVehicleId': vehicleDoc.id,
        'modelId': modelId,
        'label': '${modelData['make'] ?? '?'} ${modelData['model'] ?? '?'} (${modelData['year']})',
        'type': type,
      };
    }).where((v) => v != null).cast<Map<String, dynamic>>().toList();

    if (!mounted) return null;
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Selecione um Veículo', style: GoogleFonts.orbitron(color: Colors.cyanAccent[400])),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: userVehicles.length,
              itemBuilder: (context, index) {
                final vehicle = userVehicles[index];
                return ListTile(
                  leading: Icon((vehicle['type'] as VehicleType?)?.icon ?? Icons.car_rental, color: (vehicle['type'] as VehicleType?)?.displayColor ?? Colors.white70),
                  title: Text(vehicle['label'], style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.of(dialogContext).pop(vehicle),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(null), child: const Text('Cancelar', style: TextStyle(color: Colors.grey)))
          ],
        );
      },
    );
  }

  void _handleVehicleSelection(String vehicleId, VehicleType? vehicleType, String displayName) {
    if (_isTracking || _isProcessingStartImages || _isProcessingEndImage || _isLoadingGpsSave ) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não é possível alterar o veículo durante uma operação.'), backgroundColor: Colors.orangeAccent));
        return;
    }
    setState(() {
      if (_selectedVehicleIdForTrip == vehicleId) {
        _selectedVehicleIdForTrip = null; 
        _selectedVehicleTypeForTrip = null;
        _selectedVehicleDisplayNameForTrip = null;
      } else {
        _selectedVehicleIdForTrip = vehicleId; 
        _selectedVehicleTypeForTrip = vehicleType;
        _selectedVehicleDisplayNameForTrip = displayName;
      }
    });
  }
  
  Future<void> _showVehicleSelectionDialogForTracking() async {
    if (_isTracking) return;
    
    final selectedVehicleInfo = await _fetchAndShowVehicleSelectionDialog();
    if (selectedVehicleInfo != null) {
      _handleVehicleSelection(
        selectedVehicleInfo['userVehicleId'],
        selectedVehicleInfo['type'] as VehicleType?,
        selectedVehicleInfo['label'],
      );
    }
  }
  
  Future<void> _showVehicleSelectionDialogForSimulator() async {
    final selectedVehicleInfo = await _fetchAndShowVehicleSelectionDialog();
    if (selectedVehicleInfo != null && mounted) {
      setState(() {
        _selectedVehicleIdForSimulator = selectedVehicleInfo['userVehicleId'];
        _selectedVehicleTypeForSimulator = selectedVehicleInfo['type'] as VehicleType?;
        _simulatedVehicleDisplayName = selectedVehicleInfo['label'];
        _simulationResult = null;
      });
    }
  }
  
  /// Inicia ou para o monitoramento da viagem via GPS.
  Future<void> _toggleTracking() async {
    // A restrição para web foi removida conforme solicitado.
    // Lembre-se das limitações de GPS em navegadores.
    
    if (_isProcessingStartImages || _isProcessingEndImage || _isLoadingGpsSave) return;

    if (_isTracking) {
      // Lógica para PARAR o tracking
      setState(() => _isLoadingGpsSave = true);
      await _positionStreamSubscriptionForTrip?.cancel();
      _positionStreamSubscriptionForTrip = null;

      String finalDestinationCity = 'Destino desconhecido';
      try {
        Position? endPosition = await Geolocator.getLastKnownPosition();
        endPosition ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
        finalDestinationCity = await _getCityFromCoordinates(endPosition);
      } catch (e) {
        debugPrint("Erro ao obter localização final: $e");
      }

      await _captureAndUploadEndOdometerImage();

      if (!mounted) {
        setState(() => _isLoadingGpsSave = false);
        return;
      }

      final DateTime tripEndTime = DateTime.now();
      final double finalDistanceKm = _accumulatedDistanceMeters / 1000.0;

      if (_currentUser != null && _selectedVehicleIdForTrip != null && _selectedVehicleTypeForTrip != null && _tripStartTime != null && finalDistanceKm > 0.01) {
        final TripCalculationResult results = await _carbonService.getTripCalculationResults(
          vehicleType: _selectedVehicleTypeForTrip!,
          distanceKm: finalDistanceKm,
        );

        final String effectiveDestination = finalDestinationCity != 'Destino desconhecido'
            ? finalDestinationCity
            : (_destinationController.text.trim().isNotEmpty ? _destinationController.text.trim() : 'Destino desconhecido');

        final Map<String, dynamic> tripData = {
          'userId': _currentUser!.uid,
          'vehicleId': _selectedVehicleIdForTrip!,
          'vehicleType': _selectedVehicleTypeForTrip!.name,
          'distanceKm': finalDistanceKm,
          'startTime': Timestamp.fromDate(_tripStartTime!),
          'endTime': Timestamp.fromDate(tripEndTime),
          'durationMinutes': tripEndTime.difference(_tripStartTime!).inMinutes,
          'origin': _originController.text.trim().isNotEmpty ? _originController.text.trim() : 'Origem desconhecida',
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

        try {
          await FirebaseFirestore.instance.collection('trips').add(tripData);
          if (mounted) {
            if (results.isEmission) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viagem com emissão registrada!'), backgroundColor: Colors.orange));
              _showCompensationDialog(co2ToOffset: results.co2EmittedKg, cost: results.compensationCostBRL);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viagem salva! Créditos calculados.'), backgroundColor: Colors.green));

              if (results.creditsEarned > 0) {
                await WalletService().addCreditsToWallet(_currentUser!.uid, results.creditsEarned);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('+ ${results.creditsEarned.toStringAsFixed(4)} B2Y Coins na sua carteira!'),
                        backgroundColor: Colors.amber[800],
                      ));
                }
              }
            }
          }
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar viagem: $e'), backgroundColor: Colors.redAccent));
        }

        _resetTripState();
      } else {
        String message = 'Não foi possível salvar. ';
        if (_currentUser == null) message += 'Erro de usuário. ';
        if (_selectedVehicleIdForTrip == null || _selectedVehicleTypeForTrip == null) message += 'Veículo inválido. ';
        if (_tripStartTime == null) message += 'Tempo inválido. ';
        if (finalDistanceKm <= 0.01) message += 'Distância curta. ';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.orangeAccent));
        
        setState(() => _isLoadingGpsSave = false);
      }
    } else {
      // Lógica para INICIAR o tracking
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
        if (mounted) {
          await _showPermissionDeniedPermanentlyDialog("localização");
        }
        return;
      }

      bool startImagesOk = await _captureAndUploadStartImages();
      if (!startImagesOk) {
        if (mounted) {
          setState(() {
            _plateImageURL = null;
            _odometerStartImageURL = null;
            _recognizedPlateText = null;
            _recognizedOdometerStartText = null;
          });
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _isTracking = true;
        _accumulatedDistanceMeters = 0.0;
        _currentDistanceKm = 0.0;
        _lastPositionForTripStart = null;
        _tripStartTime = DateTime.now();
      });
      const LocationSettings locSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
      _positionStreamSubscriptionForTrip = Geolocator.getPositionStream(locationSettings: locSettings).listen(
        (Position position) {
          if (mounted && _isTracking) {
            setState(() {
              if (_lastPositionForTripStart != null) {
                double delta = Geolocator.distanceBetween(
                  _lastPositionForTripStart!.latitude,
                  _lastPositionForTripStart!.longitude,
                  position.latitude,
                  position.longitude,
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
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro GPS: $error'), backgroundColor: Colors.redAccent));
        },
        cancelOnError: false,
      );
    }
  }

  void _resetTripState() {
    if (mounted) {
      _originController.clear();
      _destinationController.clear();
      _fetchAndSetGpsTabOriginCity();
      setState(() {
        _accumulatedDistanceMeters = 0.0;
        _currentDistanceKm = 0.0;
        _tripStartTime = null;
        _plateImageURL = null;
        _odometerStartImageURL = null;
        _odometerEndImageURL = null;
        _recognizedPlateText = null;
        _recognizedOdometerStartText = null;
        _recognizedOdometerEndText = null;
        _isLoadingGpsSave = false;
        _isTracking = false;
        _selectedVehicleIdForTrip = null;
        _selectedVehicleTypeForTrip = null;
        _selectedVehicleDisplayNameForTrip = null;
      });
    }
  }

  Future<void> _fetchAndSetDistance() async {
    final String origin = _simulatedOriginController.text.trim();
    final String destination = _simulatedDestinationController.text.trim();

    if (origin.isEmpty || destination.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha a cidade de origem e destino para buscar a distância.'), backgroundColor: Colors.orangeAccent),
        );
      }
      return;
    }

    setState(() => _isFetchingDistance = true);
    const String cloudFunctionUrl = 'https://getdirections-ki3ven47oa-uc.a.run.app';
    final String requestUrl = '$cloudFunctionUrl?origin=${Uri.encodeComponent(origin)}&destination=${Uri.encodeComponent(destination)}';
    try {
      final response = await http.get(Uri.parse(requestUrl));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final legs = routes[0]['legs'] as List;
            if (legs.isNotEmpty) {
              final distanceInMeters = legs[0]['distance']['value'];
              final double distanceInKm = distanceInMeters / 1000.0;
              setState(() => _simulatedDistanceKmController.text = distanceInKm.toStringAsFixed(1));
              if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Distância aproximada: ${distanceInKm.toStringAsFixed(1)} KM.'), backgroundColor: Colors.green));
            } else {
              if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rota não encontrada (sem "legs" na resposta).'), backgroundColor: Colors.orangeAccent));
            }
          } else {
            if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma rota encontrada entre as cidades.'), backgroundColor: Colors.orangeAccent));
          }
        } else if (data['error_message'] != null) {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro da API de Direções: ${data['error_message']}'), backgroundColor: Colors.orangeAccent));
        } else {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar distância: ${data['status']}'), backgroundColor: Colors.orangeAccent));
        }
      } else {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao buscar distância do servidor: Cód ${response.statusCode}'), backgroundColor: 
        Colors.red));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro de conexão ao buscar distância.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isFetchingDistance = false);
    }
  }

  Future<Iterable<String>> _fetchCityAutocompleteSuggestions(TextEditingValue textEditingValue) async {
    if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
    const String cloudFunctionUrl = 'https://getplaceautocomplete-ki3ven47oa-uc.a.run.app';
    final String requestUrl = '$cloudFunctionUrl?input=${Uri.encodeComponent(textEditingValue.text)}';
    try {
      final response = await http.get(Uri.parse(requestUrl));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['predictions'] != null && data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions.map((p) => p['description'] as String).toList();
        }
      }
    } catch (e) { /* Silently fail or log */ }
    return const Iterable<String>.empty();
  }

  Future<void> _getCurrentLocationForOrigin() async {
    setState(() => _isFetchingCurrentLocationCity = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Serviço de GPS desativado.')));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de localização negada.')));
          return;
        }
      }
      if (permission == LocationPermission.deniedForever && mounted) {
        await _showPermissionDeniedPermanentlyDialog("localização para cidade origem");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      final String city = await _getCityFromCoordinates(position);
      
      if (mounted) {
        if (city != 'Local Desconhecido') {
          setState(() => _simulatedOriginController.text = city);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cidade origem definida: $city'), backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível determinar a cidade da sua localização atual.'), backgroundColor: Colors.orangeAccent));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao obter localização/cidade.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isFetchingCurrentLocationCity = false);
    }
  }

  Future<void> _runTripSimulation() async {
    if (_selectedVehicleIdForSimulator == null || _selectedVehicleTypeForSimulator == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione um veículo para a simulação.'), backgroundColor: Colors.orangeAccent));
      return;
    }
    final distanceText = _simulatedDistanceKmController.text.trim().replaceAll(',', '.');
    if (distanceText.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, insira ou busque a distância em KM.'), backgroundColor: Colors.orangeAccent));
      return;
    }
    final double? distanceKm = double.tryParse(distanceText);
    if (distanceKm == null || distanceKm <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, insira uma distância válida em KM.'), backgroundColor: Colors.orangeAccent));
      return;
    }

    setState(() { 
      _isCalculatingSimulation = true; 
      _simulationResult = null;
    });

    final results = await _carbonService.getTripCalculationResults(
      vehicleType: _selectedVehicleTypeForSimulator!, 
      distanceKm: distanceKm
    );

    if (mounted) {
      setState(() {
        _simulationResult = results;
        _isCalculatingSimulation = false;
      });
    }
  }

  Widget _buildIndicatorsSection(String userId) {
    const Color kmColor = Colors.blueAccent;
    const Color co2SavedColor = Colors.greenAccent;
    const Color b2yCoinColor = Colors.amberAccent;
    const Color co2EmittedColor = Color(0xFFff4d4d);
    const Color walletColor = Colors.purpleAccent;
    final Color co2OffsetColor = Colors.tealAccent[400]!;

    return StreamBuilder<double>(
      stream: _totalCo2OffsetStream,
      initialData: 0.0,
      builder: (context, offsetSnapshot) {
        final totalCo2Offset = offsetSnapshot.data ?? 0.0;
        final offsetIsLoading = offsetSnapshot.connectionState == ConnectionState.waiting;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('trips').where('userId', isEqualTo: userId).snapshots(),
          builder: (context, tripSnapshot) {
            double totalKm = 0.0;
            double totalCO2Saved = 0.0;
            double totalCO2Emitido = 0.0;
            
            bool tripIndicatorsLoading = tripSnapshot.connectionState == ConnectionState.waiting;

            if (tripSnapshot.hasData && tripSnapshot.data!.docs.isNotEmpty) {
              for (var doc in tripSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                totalKm += (data['distanceKm'] as num?)?.toDouble() ?? 0.0;
                totalCO2Saved += (data['co2SavedKg'] as num?)?.toDouble() ?? 0.0;
                totalCO2Emitido += (data['co2EmittedKg'] as num?)?.toDouble() ?? 0.0;
              }
            }
            final double netCo2ToOffset = totalCO2Emitido - totalCo2Offset;

            return StreamBuilder<double>(
              stream: WalletService().getWalletBalanceStream(userId),
              builder: (context, walletSnapshot) {
                final b2yCoins = walletSnapshot.data ?? 0.0;
                bool walletIsLoading = walletSnapshot.connectionState == ConnectionState.waiting;
                
                final List<Map<String, dynamic>> indicatorsData = [
                  {'title': 'KM TOTAL', 'isLoading': tripIndicatorsLoading, 'value': '${totalKm.toStringAsFixed(1)} km', 'icon': Icons.drive_eta_outlined, 'color': kmColor, 'action': null},
                  {'title': 'CO₂ SEQUESTRADO', 'isLoading': tripIndicatorsLoading, 'value': '${totalCO2Saved.toStringAsFixed(2)} kg', 'icon': Icons.eco, 'color': co2SavedColor, 'action': null},
                  {'title': 'CO₂ A COMPENSAR', 'isLoading': tripIndicatorsLoading || offsetIsLoading, 'value': '${netCo2ToOffset > 0 ? netCo2ToOffset.toStringAsFixed(2) : "0.00"} kg', 'icon': Icons.smoke_free, 'color': co2EmittedColor, 
                    'action': (netCo2ToOffset > 0.01 && !tripIndicatorsLoading && !offsetIsLoading) ? TextButton(onPressed: () => _showCompensationDialog(co2ToOffset: netCo2ToOffset, cost: netCo2ToOffset * _brlPerKgCo2), style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: co2EmittedColor.withAlpha(204), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)), child: const Text('COMPENSAR')) : null
                  },
                  {'title': 'B2Y COINS', 'isLoading': walletIsLoading, 'value': b2yCoins.toStringAsFixed(4), 'icon': Icons.toll_outlined, 'color': b2yCoinColor, 'action': null},
                  {'title': 'CO₂ COMPENSADO', 'isLoading': offsetIsLoading, 'value': '${totalCo2Offset.toStringAsFixed(2)} kg', 'icon': Icons.shield_outlined, 'color': co2OffsetColor, 'action': null},
                  {'title': 'CARTEIRA (R\$)', 'isLoading': false, 'value': 'Comprar Moedas', 'icon': Icons.account_balance_wallet_outlined, 'color': walletColor, 'action': null},
                ];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12.0,
                      crossAxisSpacing: 12.0,
                      childAspectRatio: 1.8,
                    ),
                    itemCount: indicatorsData.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final data = indicatorsData[index];
                      final card = IndicatorCard(
                        title: data['title'],
                        isLoading: data['isLoading'],
                        value: data['value'],
                        icon: data['icon'],
                        accentColor: data['color'],
                        actionButton: data['action'],
                      );

                      if (data['title'] == 'CARTEIRA (R\$)') {
                        return GestureDetector(
                          onTap: () {
                            if (mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (ctx) => const BuyCoinsScreen()),
                              );
                            }
                          },
                          child: card,
                        );
                      }
                      return card;
                    },
                  ).animate().fadeIn(delay: 200.ms),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProgressBarSection() {
    double currentProgress = 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          CircularPercentIndicator(
             radius: 30.0,
             lineWidth: 7.0,
             percent: currentProgress,
             center: Text( "${(currentProgress * 100).toInt()}%", style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70), ),
             progressColor: Colors.cyanAccent[400],
             backgroundColor: Colors.grey[800]!,
             circularStrokeCap: CircularStrokeCap.round,
             animateFromLastPercent: true,
             animation: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Economizando CO₂ com transporte sustentável",
              style: GoogleFonts.poppins(
                fontSize: 13, 
                color: Colors.white.withAlpha(204),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildGpsTrackingTabContent(ThemeData theme, Color subtleTextColor, Color primaryColor){
      final errorColor = theme.colorScheme.error;
      final accentColor = primaryColor;
      bool isCurrentlyProcessingImages = _isProcessingStartImages || _isProcessingEndImage;
      bool canEditFields = !_isTracking && !isCurrentlyProcessingImages && !_isFetchingGpsTabOrigin && !_isLoadingGpsSave;
      return Card( elevation: 4, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), color: Colors.grey[900]!.withAlpha(128),
        child: Padding( padding: const EdgeInsets.all(16.0),
          child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Monitorar Viagem GPS', style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 16),
            GestureDetector(
              onTap: (_isTracking || isCurrentlyProcessingImages) ? null : _showVehicleSelectionDialogForTracking,
              child: ListTile( 
                contentPadding: EdgeInsets.zero, 
                dense: true, 
                leading: Icon(
                  _selectedVehicleTypeForTrip?.icon ?? Icons.directions_car, 
                  color: _selectedVehicleIdForTrip != null ? _selectedVehicleTypeForTrip!.displayColor : subtleTextColor,
                  size: 30, 
                ), 
                title: Text('Veículo Selecionado:', style: theme.textTheme.bodySmall?.copyWith(color: subtleTextColor)), 
                subtitle: Text(
                  _selectedVehicleDisplayNameForTrip ?? "Selecione um veículo",
                  style: theme.textTheme.bodyMedium?.copyWith( 
                    fontWeight: _selectedVehicleIdForTrip != null ? FontWeight.bold : FontWeight.normal, 
                    color: _selectedVehicleIdForTrip == null ? errorColor : Colors.white70 
                  )
                ),
                trailing: const Icon(Icons.arrow_drop_down, color: Colors.white70), 
              ),
            ),
            const SizedBox(height: 12),
             TextFormField(
                controller: _originController,
                enabled: canEditFields && !_isFetchingGpsTabOrigin,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Origem',
                  labelStyle: TextStyle(color: subtleTextColor),
                  hintText: _isFetchingGpsTabOrigin 
                      ? 'Detectando origem...' 
                      : (_originController.text.isEmpty ? 'Não detectada ou digite' : ''),
                  hintStyle: TextStyle(color: subtleTextColor.withAlpha(128)),
                  isDense: true,
                  prefixIcon: _isFetchingGpsTabOrigin 
                      ? const Padding(
                          padding: EdgeInsets.all(12.0), 
                          child: SpinKitFadingCircle(color: Colors.cyanAccent, size: 20.0)
                        )
                      : Icon(Icons.trip_origin, color: subtleTextColor),
                  filled: true,
                  fillColor: Colors.black.withAlpha(51),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor)),
                ),
              ),
            const SizedBox(height: 10),
            TextFormField( controller: _destinationController, enabled: canEditFields, style: const TextStyle(color: Colors.white), decoration: InputDecoration( labelText: 'Destino (Opcional)', labelStyle: TextStyle(color: subtleTextColor), hintText: 'Ex: Mercado, Academia...', hintStyle: TextStyle(color: subtleTextColor.withAlpha(128)), isDense: true, prefixIcon: Icon(Icons.flag_outlined, color: subtleTextColor), filled: true, fillColor: Colors.black.withAlpha(51), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor)), 
            ), ), const SizedBox(height: 16),
            if (_isTracking)
               Center( child: Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.route, color: accentColor, size: 24), const SizedBox(width: 8), Text( '${_currentDistanceKm.toStringAsFixed(2)} km', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accentColor) ), const SizedBox(width: 10), SpinKitPulse(color: accentColor, size: 15.0) ] ) ) ).animate(onPlay: (c)=>c.repeat()).shimmer(delay: 400.ms, duration: 1000.ms, color: Colors.white.withAlpha(26)),
            const SizedBox(height: 16),
            Center(
              child: (_isLoadingGpsSave || _isProcessingStartImages || _isProcessingEndImage)
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column( children: [
                      SpinKitWave(color: accentColor, size: 25.0), const SizedBox(height: 8),
                      Text(
                        _isProcessingStartImages ? "Processando fotos e OCR..." :
                        _isProcessingEndImage ? "Processando foto e OCR..." :
                        _isLoadingGpsSave ? "Salvando viagem..." : "Aguarde...",
                        style: TextStyle(color: subtleTextColor)
                      )
                    ],),)
                : ElevatedButton.icon(
                    onPressed: (_selectedVehicleIdForTrip != null || _isTracking) ? _toggleTracking : null,
                    icon: Icon( _isTracking ? Icons.stop_circle_outlined : Icons.play_circle_outline, size: 22),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Text(_isTracking ? 'Parar e Salvar Viagem' : 'Iniciar Viagem', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTracking ? errorColor.withAlpha(230) : accentColor,
                      foregroundColor: _isTracking ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 8, shadowColor: _isTracking ? errorColor : accentColor,
                      disabledBackgroundColor: Colors.grey[800],
                    ),
                  ).animate().scale(delay: 100.ms),
            ),
            if (!_isTracking && _selectedVehicleIdForTrip == null && !isCurrentlyProcessingImages)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Center(
                  child: Text( "Selecione um veículo para iniciar o monitoramento.", style: theme.textTheme.bodySmall?.copyWith(color: errorColor.withAlpha(204)), textAlign: TextAlign.center, )
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildTripSimulatorTabContent(ThemeData theme, Color subtleTextColor, Color primaryColor) {
    final errorColor = theme.colorScheme.error;
    final accentColor = primaryColor;
    
    return Card(
      elevation: 4, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.grey[900]!.withAlpha(128),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            Text('Simulador de Viagem', style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
             const SizedBox(height: 16),
            GestureDetector(
              onTap: _showVehicleSelectionDialogForSimulator,
              child: ListTile(
                contentPadding: EdgeInsets.zero, dense: true,
                leading: Icon(
                  _selectedVehicleTypeForSimulator?.icon ?? Icons.directions_car,
                  color: _selectedVehicleIdForSimulator != null ? (_selectedVehicleTypeForSimulator?.displayColor) : subtleTextColor,
                ),
                title: Text('Veículo para Simulação:', style: theme.textTheme.bodySmall?.copyWith(color: subtleTextColor)),
                subtitle: Text(
                  _simulatedVehicleDisplayName ?? "Selecione um veículo",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: _selectedVehicleIdForSimulator != null ? FontWeight.bold : FontWeight.normal,
                    color: _selectedVehicleIdForSimulator == null ? errorColor : Colors.white70,
                  ),
                ),
                trailing: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              optionsBuilder: _fetchCityAutocompleteSuggestions,
              onSelected: (String selection) {
                _simulatedOriginController.text = selection;
                FocusScope.of(context).requestFocus(_simulatedDestinationFocusNode); // Move focus
              },
              fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                if (_simulatedOriginController.text != fieldTextEditingController.text) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                            fieldTextEditingController.text = _simulatedOriginController.text;
                            fieldTextEditingController.selection = TextSelection.fromPosition(TextPosition(offset: fieldTextEditingController.text.length));
                        }
                    });
                }
                return TextFormField(
                  controller: fieldTextEditingController,
                  focusNode: _simulatedOriginFocusNode,
                  onChanged: (text) => _simulatedOriginController.text = text,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Cidade Origem', labelStyle: TextStyle(color: subtleTextColor),
                    hintText: 'Ex: São Paulo', hintStyle: TextStyle(color: subtleTextColor.withAlpha(128)),
                    isDense: true,
                    prefixIcon: _isFetchingCurrentLocationCity 
                        ? const Padding(padding: EdgeInsets.all(12.0), child: SpinKitFadingCircle(color: Colors.cyanAccent, size: 20.0)) 
                        : IconButton(icon: Icon(Icons.my_location, color: accentColor), tooltip: 'Usar localização atual', onPressed: _getCurrentLocationForOrigin),
                    filled: true, fillColor: Colors.black.withAlpha(51),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor)),
                  ),
                );
              },
              optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0, color: Colors.grey[800],
                    child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 40),
                        child: ListView.builder(
                          padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Padding(padding: const EdgeInsets.all(16.0), child: Text(option, style: const TextStyle(color: Colors.white))),
                            );
                          },
                        ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Autocomplete<String>(
              optionsBuilder: _fetchCityAutocompleteSuggestions,
              onSelected: (String selection) {
                _simulatedDestinationController.text = selection;
                 _simulatedDestinationFocusNode.unfocus(); // Dispara o _onDestinationFocusChange
              },
              fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                if (_simulatedDestinationController.text != fieldTextEditingController.text) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                        if(mounted) {
                            fieldTextEditingController.text = _simulatedDestinationController.text;
                            fieldTextEditingController.selection = TextSelection.fromPosition(TextPosition(offset: fieldTextEditingController.text.length));
                        }
                    });
                }
                return 
                TextFormField(
                  controller: fieldTextEditingController,
                  focusNode: _simulatedDestinationFocusNode,
                  onChanged: (text) => _simulatedDestinationController.text = text,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Cidade Destino', labelStyle: TextStyle(color: subtleTextColor),
                    hintText: 'Ex: Rio de Janeiro', hintStyle: TextStyle(color: subtleTextColor.withAlpha(128)),
                    isDense: true, prefixIcon: Icon(Icons.pin_drop_outlined, color: subtleTextColor),
                    filled: true, fillColor: Colors.black.withAlpha(51),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor)),
                  ),
                );
              },
              optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0, color: Colors.grey[800],
                    child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 40),
                        child: ListView.builder(
                          padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Padding(padding: const EdgeInsets.all(16.0), child: Text(option, style: const TextStyle(color: Colors.white))),
                            );
                          },
                        ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _simulatedDistanceKmController,
              style: const TextStyle(color: Colors.white),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Distância (KM)',
                labelStyle: TextStyle(color: subtleTextColor),
                hintText: 'Preencha origem/destino ou digite',
                hintStyle: TextStyle(color: subtleTextColor.withAlpha(128)),
                isDense: true,
                prefixIcon: Icon(Icons.social_distance_outlined, color: subtleTextColor),
                suffixIcon: _isFetchingDistance
                    ? const Padding(padding: EdgeInsets.all(12.0), child: SpinKitFadingCircle(color: Colors.cyanAccent, size: 20.0))
                    : null,
                filled: true,
                fillColor: Colors.black.withAlpha(51),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor)),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: _isCalculatingSimulation
                  ? SpinKitWave(color: accentColor, size: 25.0)
                  : ElevatedButton.icon(
                      onPressed: _runTripSimulation,
                      icon: const Icon(Icons.calculate_outlined, size: 20),
                      label: const Padding(padding: EdgeInsets.symmetric(vertical: 10.0), child: Text('Calcular Simulação', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor, foregroundColor: Colors.black87,
                        padding: 
                        const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 8, shadowColor: accentColor,
                      ),
                    ).animate().scale(delay: 100.ms),
            ),
            Builder(builder: (context) {
              final result = _simulationResult;

              if (result != null && !_isCalculatingSimulation) {
                return Column(
                  children: [
                    const SizedBox(height: 20),
                    Divider(color: subtleTextColor.withAlpha(100)),
                    const SizedBox(height: 12),
                    Text('Resultados da Simulação:', style: GoogleFonts.orbitron(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70)),
                    const SizedBox(height: 10),
                    _InfoRowSimulator(
                      icon: result.isEmission ? Icons.smoke_free : Icons.eco,
                      label: result.isEmission ? 'CO₂ Emitido:' : 'CO₂ Sequestrado/Evitado:',
                      value: '${result.isEmission ? result.co2EmittedKg.toStringAsFixed(2) : result.co2SavedKg.toStringAsFixed(2)} kg',
                      iconColor: result.isEmission ? Colors.redAccent : Colors.greenAccent[400]!,
                    ),
                    const SizedBox(height: 6),
                    if (result.isEmission)
                      _InfoRowSimulator(
                        icon: Icons.price_change_outlined,
                        label: 'Custo para Compensar:',
                        value: 'R\$ ${result.compensationCostBRL.toStringAsFixed(2)}',
                        iconColor: Colors.amberAccent[100]!,
                      ),
                    if (!result.isEmission)
                      _InfoRowSimulator(
                        icon: Icons.monetization_on_outlined,
                        label: 'Créditos Gerados (B2Y):',
                        value: result.creditsEarned.toStringAsFixed(4),
                        iconColor: Colors.amberAccent[100]!,
                      ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }),
            if (!_isCalculatingSimulation && _selectedVehicleIdForSimulator == null)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Center(
                  child: Text("Selecione um veículo para simular.", style: theme.textTheme.bodySmall?.copyWith(color: errorColor.withAlpha(204)), textAlign: TextAlign.center,)
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSectionHeader(ThemeData theme, Color primaryColor) {
      final titleColor = Colors.white.withAlpha(230);
      final buttonColor = primaryColor;
      return Padding( padding: const EdgeInsets.only(top: 16.0),
        child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text( 'Meus Veículos', style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor) ),
          Row( mainAxisSize: MainAxisSize.min, children: [ TextButton.icon( icon: Icon(Icons.add_circle_outline, size: 18, color: buttonColor), label: Text('Adicionar', style: TextStyle(color: buttonColor.withAlpha(204), fontSize: 13)), style: TextButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 8), ), onPressed: _navigateToAddVehicle ), const SizedBox(width: 0), TextButton.icon( icon: Icon(Icons.list_alt_rounded, size: 18, color: Colors.grey[500]), label: Text('Gerenciar', style: TextStyle(color: Colors.grey[500], 
          fontSize: 13)), style: TextButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 8), ), onPressed: _navigateToFleetManagement ), ], ) ], ), );
  }

  Widget _buildVehicleList(String userId, ThemeData theme, Color primaryColor, Color subtleTextColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('vehicles').where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, vehicleSnapshot) {
        if (vehicleSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 30.0), child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (!vehicleSnapshot.hasData || vehicleSnapshot.data!.docs.isEmpty) {
          return Card(
              elevation: 1, color: Colors.grey[850]!.withAlpha(153), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_car_outlined, color: Colors.white.withAlpha(153), size: 30),
                    const SizedBox(height: 10),
                    Text('Nenhum veículo cadastrado.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withAlpha(153))),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Adicionar Veículo"),
                      onPressed: _navigateToAddVehicle,
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    )
                  ],
                ),
              ),
            ).animate().fadeIn();
        }

        final vehicleDocs = vehicleSnapshot.data!.docs;
        final modelIds = vehicleDocs.map((doc) => (doc.data() as Map<String, dynamic>)['modelId'] as String?).where((id) => id != null).toList();

        if (modelIds.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Veículos com cadastro antigo. Por favor, cadastre novamente.', style: TextStyle(color: Colors.orangeAccent)),
          ));
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('vehicle_models').where(FieldPath.documentId, whereIn: modelIds).get(),
          builder: (context, modelSnapshot) {
            if (modelSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 30.0), child: CircularProgressIndicator(strokeWidth: 2)));
            }
            if (!modelSnapshot.hasData) {
              return const Center(child: Text('Não foi possível carregar os detalhes dos veículos.'));
            }

            final modelsDataMap = {for (var doc in modelSnapshot.data!.docs) doc.id: doc.data() as Map<String, dynamic>};

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vehicleDocs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final vehicleDoc = vehicleDocs[index];
                final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
                final userVehicleId = vehicleDoc.id;
                final modelId = vehicleData['modelId'] as String?;
                final modelData = modelsDataMap[modelId];

                if (modelData == null) {
                  return ListTile(title: Text('Erro: Modelo ID $modelId não encontrado.', style: const TextStyle(color: Colors.red)));
                }

                final vehicleType = vehicleTypeFromString(modelData['type']);
                final displayName = '${modelData['make'] ?? '?'} ${modelData['model'] ?? '?'} (${modelData['year']})';
                final isSelected = userVehicleId == _selectedVehicleIdForTrip;

                return Card(
                  margin: EdgeInsets.zero,
                  elevation: isSelected ? 6 : 2,
                  color: Colors.grey[850]!.withAlpha(153),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isSelected ? primaryColor : Colors.grey[700]!, width: isSelected ? 2.0 : 0.8),
                  ),
                  child: InkWell(
                    onTap: () => _handleVehicleSelection(userVehicleId, vehicleType, displayName),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(vehicleType?.icon ?? Icons.help_outline, color: isSelected ? primaryColor : (vehicleType?.displayColor ?? Colors.white70), size: 28),
                        title: Text(displayName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 15, color: Colors.white)),
                        subtitle: Text('${vehicleData['licensePlate'] ?? 'Sem placa'}\nTipo: ${vehicleType?.displayName ?? modelData['type'] ?? '?'}', style: TextStyle(color: subtleTextColor, fontSize: 12.5, height: 1.3)),
                        trailing: isSelected ? Icon(Icons.check_circle, color: primaryColor, size: 22) : Icon(Icons.radio_button_unchecked, color: subtleTextColor.withAlpha(128), size: 20),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNavigationButtons() {
      final buttonColor = Colors.grey[800];
      const iconColor = Colors.white70; const textColor = Colors.white70;
      return Padding( padding: const EdgeInsets.only(top: 16.0),
        child: Wrap( spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: textColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.receipt_long, size: 18, color: iconColor),
          label: const Text('Extrato', style: TextStyle(fontSize: 13)),
          onPressed: () {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
              );
            }
          },
        ),
          ElevatedButton.icon( style: ElevatedButton.styleFrom( backgroundColor: buttonColor, foregroundColor: textColor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) ), icon: const Icon(Icons.history, size: 18, color: iconColor), label: const Text('Histórico', style: TextStyle(fontSize: 13)), onPressed: _navigateToTripHistory),
          ElevatedButton.icon(
             style: ElevatedButton.styleFrom( backgroundColor: buttonColor, foregroundColor: textColor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) ),
             icon: const Icon(Icons.store, size: 18, color: iconColor),
             label: const Text('Loja B2Y', style: TextStyle(fontSize: 13)),
             onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MarketplaceScreen()))
          ),
          ElevatedButton.icon(
             style: ElevatedButton.styleFrom( backgroundColor: Colors.cyan.withOpacity(0.2), foregroundColor: Colors.cyanAccent, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) ),
             icon: const Icon(Icons.star, size: 18, color: Colors.cyanAccent),
             label: const Text('Seja PRO', style: TextStyle(fontSize: 13)),
             onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen()))
          ),
        ], ).animate().fadeIn(delay: 800.ms), );
  }

  Widget _buildLastThreeTripsSection(String userId, Color accentColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('userId', isEqualTo: userId)
          .orderBy('endTime', descending: true) 
          .limit(3)
          .snapshots(),
       builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Center(child: SpinKitFadingCircle(color: Colors.white70, size: 30.0)),
          );
        }
        if (snapshot.hasError) {
          return 
          Text('Erro ao carregar últimas viagens: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: Text('Nenhuma viagem registrada ainda.', style: TextStyle(color: Colors.white70))),
          );
        }

        final trips = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
              child: Text(
                'Últimas Viagens Registradas:',
                style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(217)),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trips.length,
               itemBuilder: (context, index) {
                final tripDoc = trips[index];
                final tripData = tripDoc.data() as Map<String, dynamic>;
                
                String origin = tripData['origin']?.toString() ?? 'Origem desconhecida';
                String destination = tripData['destination']?.toString() ?? 'Destino desconhecido';
                double distance = (tripData['distanceKm'] as num?)?.toDouble() ?? 0.0;
                Timestamp? endTimeStamp = tripData['endTime'] as Timestamp?;
                String formattedDate = 'Data indisponível';
                if (endTimeStamp != null) {
                  DateTime endDate = endTimeStamp.toDate();
                  formattedDate = 
                    "${endDate.day.toString().padLeft(2,'0')}/${endDate.month.toString().padLeft(2,'0')}/${endDate.year} às ${endDate.hour.toString().padLeft(2,'0')}:${endDate.minute.toString().padLeft(2,'0')}";
                }
                
                final double co2Saved = (tripData['co2SavedKg'] as num?)?.toDouble() ?? 0.0;
                final double co2Emitted = (tripData['co2EmittedKg'] as num?)?.toDouble() ?? 0.0;
                final bool wasEmissionTrip = co2Emitted > 0;

                return Card(
                  color: Colors.grey[850]?.withAlpha(200),
                  margin: const EdgeInsets.symmetric(vertical: 5.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$origin → $destination', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text(formattedDate, style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 12.5)),
                        const SizedBox(height: 4),
                         Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Distância: ${distance.toStringAsFixed(1)} km', style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 12.5)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                 Text(
                                  wasEmissionTrip 
                                    ? 'CO₂ Emitido: ${co2Emitted.toStringAsFixed(2)} kg' 
                                    : 'CO₂ Salvo: ${co2Saved.toStringAsFixed(2)} kg',
                                  style: TextStyle(color: wasEmissionTrip ? Colors.orangeAccent : Colors.greenAccent, fontSize: 12)
                                 ),
                                 Text(
                                   'Créditos: ${(tripData['creditsEarned'] as num?)?.toDouble().toStringAsFixed(4) ?? '0.0000'}', 
                                   style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 12)
                                  ),
                              ],
                            )
                          ],
                        ),
                      ],
                   ),
                  ),
                ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: -0.1);
               },
            ),
          ],
        );
      },
    );
  }

  Widget _buildGpsTrackingTabContentWrapper(ThemeData theme, Color subtleTextColor, Color primaryColor) {
    final user = _currentUser;
    if (user == null) {
      return const Center(child: Text("Erro: Usuário não encontrado."));
    }
    final String userId = user.uid;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 80.0),
      children: [
        const AdBannerPlaceholder(), 
        const SizedBox(height: 12), 
        _buildIndicatorsSection(userId),
        const SizedBox(height: 12), 
        _buildProgressBarSection(),
        Divider(height: 20, thickness: 0.5, color: Colors.grey[800]), 
        _buildGpsTrackingTabContent(theme, subtleTextColor, primaryColor),
        _buildLastThreeTripsSection(userId, primaryColor), 
        const SizedBox(height: 20), 
        _buildVehicleSectionHeader(theme, primaryColor),
        const SizedBox(height: 10), 
        _buildVehicleList(userId, theme, primaryColor, subtleTextColor),
        const SizedBox(height: 20), 
        Text('Desempenho Recente', style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white.withAlpha(230))),
        const SizedBox(height: 10), 
        TripChartPlaceholder(primaryColor: primaryColor).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
        const SizedBox(height: 20), 
        Text('Mapa de Eletropostos (Simulado)', style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white.withAlpha(230))),
        const SizedBox(height: 10), 
        const MinimapPlaceholder(showUserMarker: true),
        const SizedBox(height: 20), 
        _buildNavigationButtons(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTripSimulatorTabContentWrapper(ThemeData theme, Color subtleTextColor, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
      child: _buildTripSimulatorTabContent(theme, subtleTextColor, primaryColor),
    );
  }
  
  Future<void> _showAboutDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2c2c2e),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.cyanAccent),
              const SizedBox(width: 10),
              Text('Sobre', style: GoogleFonts.orbitron(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Desenvolvido por:', style: TextStyle(color: Colors.white70)),
                Text('B2Y Group', style: GoogleFonts.orbitron(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24, height: 24),
                const Text('Contato para parcerias e projetos:', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => launchUrl(Uri.parse('mailto:b2ylion@gmail.com')),
                  child: const Text('b2ylion@gmail.com', style: TextStyle(color: Colors.cyanAccent, decoration: TextDecoration.underline, decorationColor: Colors.cyanAccent)),
                ),
                const SizedBox(height: 8),
                InkWell(
                   onTap: () => launchUrl(Uri.parse('https://wa.me/5511965520979')),
                  child: const Text('+55 11 96552-0979', style: TextStyle(color: Colors.cyanAccent, decoration: TextDecoration.underline, decorationColor: Colors.cyanAccent)),
                ),
                 const SizedBox(height: 8),
                InkWell(
                   onTap: () => launchUrl(Uri.parse('https://group-tau.vercel.app/')),
                  child: const Text('group-tau.vercel.app', style: TextStyle(color: Colors.cyanAccent, decoration: TextDecoration.underline, decorationColor: Colors.cyanAccent)),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    final theme = Theme.of(context);
    
    final userProvider = Provider.of<UserProvider>(context);
    
    final displayName = userProvider.userName?.isNotEmpty == true
        ? userProvider.userName!
        : user?.displayName ?? user?.email?.split('@')[0] ?? 'Usuário';

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }
    final Color accentColor = Colors.cyanAccent[400]!;
    final Color subtleTextColor = Colors.grey[500] ?? Colors.grey;
    const double appBarExpandedHeight = 150.0; 

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              elevation: 1.0,
              backgroundColor: theme.scaffoldBackgroundColor, 
              pinned: true, 
              floating: true, 
              forceElevated: innerBoxIsScrolled, 
              expandedHeight: appBarExpandedHeight, 
              primary: true, 
              flexibleSpace: FlexibleSpaceBar(
                background: SafeArea( 
                  bottom: false,   
                  child: Padding( 
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 0), 
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start, 
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: MediaQuery.of(context).padding.top > 0 ? 10 : 20), 
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'B2Y Carbon Cockpit',
                              style: GoogleFonts.orbitron(
                                fontWeight: FontWeight.bold,
                                fontSize: 20, 
                                color: Colors.white.withAlpha(242),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (userProvider.canAccessAdminPanel)
                                  IconButton(
                                    icon: const Icon(Icons.admin_panel_settings, color: Colors.amberAccent),
                                    tooltip: 'Painel Administrativo',
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (ctx) => const AdminScreen()),
                                      );
                                    },
                                  ),
                                
                                IconButton(
                                  icon: Icon(Icons.info_outline_rounded, color: accentColor.withAlpha(180)),
                                  tooltip: 'Sobre',
                                  onPressed: _showAboutDialog,
                                ),
                                IconButton(
                                  icon: Icon(Icons.power_settings_new_rounded, color: accentColor),
                                  tooltip: 'Sair',
                                  onPressed: _logout,
                                ),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 8), 
                        Text(
                          'Olá, $displayName!',
                          style: GoogleFonts.poppins(
                            textStyle: theme.textTheme.headlineSmall?.copyWith( 
                               fontWeight: FontWeight.w500,
                              color: Colors.white.withAlpha(204),
                              fontSize: (theme.textTheme.headlineSmall?.fontSize ?? 24) * 0.85, 
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                   ),
                )
              ),
              bottom: TabBar( 
                controller: _tabController,
                indicatorColor: accentColor,
                labelColor: accentColor,
                unselectedLabelColor: Colors.grey[400],
                labelStyle: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.orbitron(fontSize: 13),
                tabs: const [
                  Tab(text: 'MONITORAR GPS'),
                  Tab(text: 'SIMULAR VIAGEM'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildGpsTrackingTabContentWrapper(theme, subtleTextColor, accentColor),
            _buildTripSimulatorTabContentWrapper(theme, subtleTextColor, accentColor),
          ],
        ),
      ),
    );
  }
}