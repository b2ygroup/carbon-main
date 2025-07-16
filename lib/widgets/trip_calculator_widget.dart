// lib/widgets/trip_calculator_widget.dart (COMPLETO E CORRIGIDO)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:carbon/models/vehicle_type_enum.dart';
import 'package:carbon/services/carbon_service.dart';
import 'package:carbon/widgets/indicator_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class TripCalculatorWidget extends StatefulWidget {
  const TripCalculatorWidget({super.key});
  @override State<TripCalculatorWidget> createState() => _TripCalculatorWidgetState();
}

class _TripCalculatorWidgetState extends State<TripCalculatorWidget> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  String? _selectedVehicleDataString;
  bool _isLoading = false;
  bool _isCalculating = false;
  Map<String, dynamic>? _results;
  List<DropdownMenuItem<String>> _vehicleDropdownItems = [];
  bool _vehiclesLoading = true;
  final CarbonService _carbonService = CarbonService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  final String _googleApiKey = "AIzaSyDy_WBvHCk13hGIfqEP_VPEDu436PvMF0E";

  // Cores Consistentes
  static const Color primaryColor = Color(0xFF00BFFF);
  static const Color secondaryColor = Color(0xFF00FFFF);
  static final Color errorColor = Colors.redAccent[100]!;
  static final Color inputFillColor = Colors.white.withAlpha(13); // 0.05
  static final Color inputBorderColor = Colors.grey[700]!;
  static final Color labelColor = Colors.grey[400]!;
  static const Color textColor = Colors.white;
  static const Color iconColor = primaryColor;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _fetchUserVehicles(_currentUser.uid);
    } else {
      if (mounted) setState(() => _vehiclesLoading = false);
    }
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserVehicles(String userId) async {
    if (!mounted) return;
    setState(() => _vehiclesLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        final type = vehicleTypeFromString(data['type'] as String?);
        final label =
            '${data['make'] ?? '?'} ${data['model'] ?? '?'} (${type?.displayName ?? data['type'] ?? 'Tipo Desconhecido'})';
        final valueString = '${doc.id}|${type?.name ?? ''}';
        return DropdownMenuItem<String>(
            value: valueString,
            child: Text(label, overflow: TextOverflow.ellipsis));
      }).toList();
      if (mounted) {
        setState(() {
          _vehicleDropdownItems = items;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao carregar veículos.'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _vehiclesLoading = false);
    }
  }

  Future<void> _calculateTrip() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    FocusScope.of(context).unfocus();
    if (!isValid) return;

    if (_selectedVehicleDataString == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Selecione um veículo.'),
              backgroundColor: Colors.orange),
        );
      }
      return;
    }

    if (_googleApiKey.contains("SUA_CHAVE_API")) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuração da API de direções incompleta.'), backgroundColor: Colors.redAccent),
            );
        }
        return;
    }

    if (_isCalculating) return;
    
    setState(() {
      _isCalculating = true;
      _results = null;
    });

    final originText = _originController.text.trim();
    final destinationText = _destinationController.text.trim();
    final parts = _selectedVehicleDataString!.split('|');
    final vehicleId = parts[0];
    final vehicleType = vehicleTypeFromString(parts.length > 1 ? parts[1] : null);

    if (vehicleType == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro interno: tipo de veículo inválido.'),
              backgroundColor: Colors.red),
        );
        setState(() => _isCalculating = false);
      }
      return;
    }

    double? distanceKm;

    try {
      final Uri directionsUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?origin=${Uri.encodeComponent(originText)}&destination=${Uri.encodeComponent(destinationText)}&key=$_googleApiKey');
      
      final http.Response response = await http.get(directionsUrl).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          final int distanceMeters = data['routes'][0]['legs'][0]['distance']['value'];
          distanceKm = distanceMeters / 1000.0;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(data['error_message'] ?? 'Não foi possível encontrar a rota ou obter a distância.'),
                  backgroundColor: Colors.orange),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erro ao conectar com o serviço de direções.'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro de rede ou timeout ao buscar distância.'),
              backgroundColor: Colors.redAccent),
        );
      }
    }

    if (distanceKm == null) {
      if (mounted) setState(() => _isCalculating = false);
      return;
    }

    try {
      // ======================= CORREÇÃO PRINCIPAL AQUI =======================
      // 1. Recebe o objeto TripCalculationResult
      final TripCalculationResult impactResults = await _carbonService.getTripCalculationResults(
        distanceKm: distanceKm,
        vehicleType: vehicleType,
      );

      if (mounted) {
        setState(() {
          // 2. Popula o mapa _results usando as propriedades do objeto
          _results = {
            'distance': distanceKm,
            'co2SavedKg': impactResults.co2SavedKg,
            'creditsEarned': impactResults.creditsEarned,
            'co2EmittedKg': impactResults.co2EmittedKg,
            'compensationCostBRL': impactResults.compensationCostBRL,
            'isEmission': impactResults.isEmission,
            'origin': originText,
            'destination': destinationText,
            'vehicleId': vehicleId,
            'vehicleType': vehicleType,
          };
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao calcular impacto da rota.'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCalculating = false;
        });
      }
    }
  }

  Future<void> _saveManualTrip() async {
    if (_results == null || _currentUser == null) return;
    
    if (!mounted) return;
    setState(() { _isLoading = true; });
    await Future.delayed(200.ms);
    try {
      final Map<String, dynamic> tripData = {
        'userId': _currentUser.uid,
        'vehicleId': _results!['vehicleId'],
        'vehicleType': (_results!['vehicleType'] as VehicleType).name,
        'origin': _results!['origin'],
        'destination': _results!['destination'],
        'distanceKm': _results!['distance'],
        'startTime': Timestamp.now(),
        'endTime': Timestamp.now(),
        'durationMinutes': 0,
        'co2SavedKg': _results!['co2SavedKg'],
        'creditsEarned': _results!['creditsEarned'],
        'co2EmittedKg': _results!['co2EmittedKg'],
        'compensationCostBRL': _results!['compensationCostBRL'],
        'processedForWallet': false,
        'createdAt': FieldValue.serverTimestamp(),
        'calculationMethod': 'manual_route',
      };
      await FirebaseFirestore.instance.collection('trips').add(tripData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Viagem calculada registrada!'),
              backgroundColor: Colors.green),
        );
        _originController.clear();
        _destinationController.clear();
        setState(() {
          _results = null;
          _selectedVehicleDataString = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao salvar registro.'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color kmColor = Colors.blueAccent[100]!;
    final Color co2Color = Colors.greenAccent[400]!;
    final Color creditsColor = Colors.lightGreenAccent[400]!;
    final Color valueColorPositive = Colors.greenAccent[400]!;
    final Color valueColorNegative = Colors.redAccent[100]!;

    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.grey[900]?.withAlpha(128), // Correção de Opacidade
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Calcular Rota e Impacto',
                  style: GoogleFonts.orbitron(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 25),
              if (_vehiclesLoading)
                const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(strokeWidth: 2, color: secondaryColor)))
              else if (_vehicleDropdownItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _currentUser == null ? 'Faça login para carregar veículos.' : 'Nenhum veículo cadastrado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: labelColor),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedVehicleDataString,
                  items: _vehicleDropdownItems,
                  onChanged: _isCalculating ? null : (String? newValue) {
                    if (newValue != _selectedVehicleDataString && _results != null) {
                      setState(() => _results = null);
                    }
                    setState(() => _selectedVehicleDataString = newValue);
                  },
                  isExpanded: true,
                  decoration: _inputDecoration(
                    labelText: 'Selecione o Veículo *',
                    prefixIcon: Icons.directions_car_outlined,
                  ),
                  dropdownColor: Colors.grey[850],
                  style: GoogleFonts.poppins(color: textColor, fontSize: 15),
                  validator: (v) => v == null || v.isEmpty ? 'Selecione um veículo' : null,
                ).animate().fadeIn(),
              const SizedBox(height: 15),
              TextFormField(
                controller: _originController,
                enabled: !_isCalculating,
                style: const TextStyle(color: textColor, fontSize: 15),
                decoration: _inputDecoration(
                    labelText: 'Origem (Ex: São Paulo, SP) *',
                    prefixIcon: Icons.trip_origin),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 12),
              TextFormField(
                controller: _destinationController,
                enabled: !_isCalculating,
                style: const TextStyle(color: textColor, fontSize: 15),
                decoration: _inputDecoration(
                    labelText: 'Destino (Ex: Rio de Janeiro, RJ) *',
                    prefixIcon: Icons.flag_outlined),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 25),
              _isCalculating
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SpinKitPulse(color: primaryColor, size: 30.0)))
                  : ElevatedButton.icon(
                      onPressed: _calculateTrip,
                      icon: const Icon(Icons.route_outlined, size: 20),
                      label: const Text('Calcular Rota Real'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black87,
                          textStyle: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4),
                    ).animate().fadeIn(delay: 200.ms).scale(),
              AnimatedSize(
                duration: 300.ms,
                curve: Curves.easeInOut,
                child: _results != null
                    ? Column(
                        children: [
                          const Divider(height: 40, thickness: 0.5, indent: 20, endIndent: 20, color: Colors.grey),
                          Text('Resultados Estimados para a Rota:',
                              style: GoogleFonts.orbitron(fontSize: 15, color: textColor)),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              IndicatorCard(
                                isLoading: _isCalculating,
                                title: 'DISTÂNCIA REAL',
                                value: '${_results!['distance']?.toStringAsFixed(1) ?? 'N/A'} km',
                                icon: Icons.social_distance_outlined,
                                accentColor: kmColor,
                              ),
                              IndicatorCard(
                                isLoading: _isCalculating,
                                title: _results!['isEmission'] ? 'EMISSÃO CO₂' : 'CO₂ EVITADO',
                                value: '${(_results!['isEmission'] ? _results!['co2EmittedKg'] : _results!['co2SavedKg'])?.toStringAsFixed(2) ?? 'N/A'} kg',
                                icon: _results!['isEmission'] ? Icons.cloud_upload_outlined : Icons.shield_moon_outlined,
                                accentColor: _results!['isEmission'] ? valueColorNegative : co2Color,
                              ),
                              IndicatorCard(
                                isLoading: _isCalculating,
                                title: 'CRÉDITOS GERADOS',
                                value: '${_results!['creditsEarned']?.toStringAsFixed(4) ?? 'N/A'}',
                                icon: Icons.paid_outlined,
                                accentColor: creditsColor,
                              ),
                              IndicatorCard(
                                isLoading: _isCalculating,
                                title: 'CUSTO P/ COMPENSAR',
                                value: 'R\$ ${_results!['compensationCostBRL']?.toStringAsFixed(2) ?? 'N/A'}',
                                icon: Icons.attach_money_outlined,
                                accentColor: (_results!['compensationCostBRL'] ?? 0) > 0 ? valueColorNegative : valueColorPositive,
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          if (!_isLoading && !_isCalculating)
                            Center(
                              child: TextButton.icon(
                                onPressed: _saveManualTrip,
                                icon: const Icon(Icons.save_alt_rounded, size: 18),
                                label: const Text('Registrar Viagem Calculada'),
                                style: TextButton.styleFrom(
                                  foregroundColor: secondaryColor,
                                  textStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.w600)
                                ),
                              )
                            )
                          else if (_isLoading)
                            const Center(child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: secondaryColor)))),
                        ],
                      )
                    : const SizedBox.shrink(),
              ).animate().fadeIn(delay: 200.ms)
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({ required String labelText, required IconData prefixIcon }) {
    return InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(textStyle:TextStyle(color: labelColor, fontSize: 14)),
        prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Icon(prefixIcon, color: iconColor.withAlpha(204), size: 20)),
        prefixIconConstraints: const BoxConstraints(minWidth:20, minHeight:20),
        filled: true,
        fillColor: inputFillColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: inputBorderColor.withAlpha(128))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: inputBorderColor.withAlpha(128))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: secondaryColor, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: errorColor)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: errorColor, width: 1.5)),
        counterText: "",
        errorStyle: TextStyle(color: errorColor.withAlpha(242), fontSize: 12)
    );
  }
}