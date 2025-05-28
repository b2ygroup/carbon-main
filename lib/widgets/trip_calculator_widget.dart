// lib/widgets/trip_calculator_widget.dart
import 'dart:async';
import 'dart:math';
import 'dart:convert'; // Para json.decode
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:carbon/models/vehicle_type_enum.dart';
import 'package:carbon/services/carbon_service.dart';
import 'package:carbon/widgets/indicator_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // Import do pacote HTTP

class TripCalculatorWidget extends StatefulWidget {
  const TripCalculatorWidget({super.key});
  @override State<TripCalculatorWidget> createState() => _TripCalculatorWidgetState();
}

class _TripCalculatorWidgetState extends State<TripCalculatorWidget> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  String? _selectedVehicleDataString;
  bool _isLoading = false; // Para salvar
  bool _isCalculating = false; // Para calcular (API Directions + CarbonService)
  Map<String, dynamic>? _results;
  List<DropdownMenuItem<String>> _vehicleDropdownItems = [];
  bool _vehiclesLoading = true;
  final CarbonService _carbonService = CarbonService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // INSIRA SUA CHAVE DA API DO GOOGLE DIRECTIONS AQUI
  // ATENÇÃO: Em produção, NÃO coloque a chave diretamente no código.
  // Use variáveis de ambiente (flutter_dotenv) ou um serviço seguro.
  final String _googleApiKey = "AIzaSyB7h2B1aDBSln6f4GAnUdV9H4XoQ2w1_-0";

  // Cores Consistentes
  static const Color primaryColor = Color(0xFF00BFFF); // DeepSkyBlue
  static const Color secondaryColor = Color(0xFF00FFFF); // Cyan/Aqua
  static final Color errorColor = Colors.redAccent[100]!;
  static final Color inputFillColor = Colors.white.withOpacity(0.05);
  static final Color inputBorderColor = Colors.grey[700]!;
  static final Color labelColor = Colors.grey[400]!;
  static const Color textColor = Colors.white;
  static const Color iconColor = primaryColor;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _fetchUserVehicles(_currentUser!.uid);
    } else {
      if (mounted) setState(() => _vehiclesLoading = false);
      debugPrint("[TripCalculator] Usuário não logado no initState.");
    }
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserVehicles(String userId) async {
    debugPrint("[TripCalculator] _fetchUserVehicles: Buscando veículos para $userId...");
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
          debugPrint("[TripCalculator] _fetchUserVehicles: ${items.length} veículos carregados.");
        });
      }
    } catch (e) {
      print("!!! ERRO fetch Calc vehicles: $e");
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
    debugPrint("***** _calculateTrip FOI CHAMADO *****");

    final isValid = _formKey.currentState?.validate() ?? false;
    debugPrint("[TripCalculator] Formulário válido: $isValid");
    FocusScope.of(context).unfocus();
    if (!isValid) {
      debugPrint("[TripCalculator] Formulário inválido. Abortando.");
      return;
    }

    debugPrint("[TripCalculator] Veículo selecionado string: $_selectedVehicleDataString");
    if (_selectedVehicleDataString == null) {
      debugPrint("[TripCalculator] Nenhum veículo selecionado. Abortando.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Selecione um veículo.'),
              backgroundColor: Colors.orange),
        );
      }
      return;
    }

    if (_googleApiKey == "SUA_CHAVE_API_GOOGLE_DIRECTIONS_AQUI") {
        debugPrint("[TripCalculator] Chave da API Google Directions não configurada.");
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuração da API de direções incompleta.'), backgroundColor: Colors.redAccent),
            );
        }
        return;
    }

    if (_isCalculating) {
      debugPrint("[TripCalculator] Já estava calculando, abortando nova chamada.");
      return;
    }
    setState(() {
      debugPrint("[TripCalculator] Definindo _isCalculating = true");
      _isCalculating = true;
      _results = null;
    });

    final originText = _originController.text.trim();
    final destinationText = _destinationController.text.trim();
    final parts = _selectedVehicleDataString!.split('|');
    final vehicleId = parts[0];
    final vehicleType = vehicleTypeFromString(parts.length > 1 ? parts[1] : null);
    debugPrint("[TripCalculator] Dados extraídos: Origin='$originText', Dest='$destinationText', VehID='$vehicleId', VehType Enum=$vehicleType");

    if (vehicleType == null) {
      print("!!! ERRO: Tipo de veículo inválido (${parts.length > 1 ? parts[1] : 'N/A'}). Abortando. !!!");
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
      debugPrint("[TripCalculator] Buscando distância real da API Google Directions...");
      final Uri directionsUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?origin=${Uri.encodeComponent(originText)}&destination=${Uri.encodeComponent(destinationText)}&key=$_googleApiKey');
      
      final http.Response response = await http.get(directionsUrl).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          // Pega a distância em metros da primeira rota/leg
          final int distanceMeters = data['routes'][0]['legs'][0]['distance']['value'];
          distanceKm = distanceMeters / 1000.0;
          debugPrint("[TripCalculator] Distância real obtida: $distanceKm km");
        } else {
          debugPrint("[TripCalculator] Erro da API Directions: ${data['status']} - ${data['error_message'] ?? 'Sem rota encontrada.'}");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(data['error_message'] ?? 'Não foi possível encontrar a rota ou obter a distância.'),
                  backgroundColor: Colors.orange),
            );
          }
        }
      } else {
        debugPrint("[TripCalculator] Erro na requisição HTTP para Directions: ${response.statusCode}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erro ao conectar com o serviço de direções.'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e, s) {
      print("!!! ERRO ao buscar distância da API: $e\n$s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro de rede ou timeout ao buscar distância.'),
              backgroundColor: Colors.redAccent),
        );
      }
    }

    if (distanceKm == null) { // Se não conseguiu obter a distância
      if (mounted) setState(() => _isCalculating = false);
      return;
    }

    // Se a distância foi obtida, prossegue com o cálculo do CarbonService
    try {
      debugPrint("[TripCalculator] Chamando _carbonService.getTripCalculationResults com distância $distanceKm km...");
      final Map<String, double> impactResults = await _carbonService.getTripCalculationResults(
        distanceKm: distanceKm,
        vehicleType: vehicleType,
      );
      debugPrint("[TripCalculator] Resultados recebidos do serviço: $impactResults");

      final double carbonKg = impactResults['carbonKg'] ?? 0.0;
      final double co2SavedKg = impactResults['co2SavedKg'] ?? 0.0;
      final double creditsEarned = impactResults['creditsEarned'] ?? 0.0;
      final double carbonValue = impactResults['carbonValue'] ?? 0.0;

      if (mounted) {
        setState(() {
          debugPrint("[TripCalculator] Atualizando estado com resultados...");
          _results = {
            'distance': distanceKm,
            'carbonKg': carbonKg,
            'co2SavedKg': co2SavedKg,
            'creditsEarned': creditsEarned,
            'carbonValue': carbonValue,
            'isElectric': vehicleType == VehicleType.electric || vehicleType == VehicleType.hybrid,
            'origin': originText,
            'destination': destinationText,
            'vehicleId': vehicleId,
            'vehicleType': vehicleType,
          };
          debugPrint("[TripCalculator] Estado atualizado com: $_results");
        });
        debugPrint("[TripCalculator] Estado atualizado com sucesso.");
      }
    } catch (e, s) {
      print("!!! ERRO GERAL durante cálculo de impacto (CarbonService): $e\n$s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao calcular impacto da rota.'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      debugPrint("--- [TripCalculator] Finalizando _calculateTrip (finally) ---");
      if (mounted) {
        setState(() {
          _isCalculating = false;
        });
      }
    }
  } // Fim _calculateTrip

  Future<void> _saveManualTrip() async {
    debugPrint("--- [TripCalculator] Iniciando _saveManualTrip ---");
    if (_results == null) {
      debugPrint("[TripCalculator] _saveManualTrip: Nenhum resultado para salvar.");
      return;
    }
    if (_currentUser == null) {
      debugPrint("[TripCalculator] _saveManualTrip: Usuário nulo.");
      return;
    }
    if (!mounted) return;
    setState(() { _isLoading = true; });
    await Future.delayed(200.ms); // Pequeno delay para feedback visual
    try {
      final Map<String, dynamic> tripData = {
        'userId': _currentUser!.uid,
        'vehicleId': _results!['vehicleId'],
        'vehicleType': (_results!['vehicleType'] as VehicleType).name,
        'origin': _results!['origin'],
        'destination': _results!['destination'],
        'distanceKm': _results!['distance'],
        'startTime': Timestamp.now(), // Para viagens manuais, start/end podem ser iguais
        'endTime': Timestamp.now(),
        'durationMinutes': 0, // Duração não aplicável da mesma forma
        'co2SavedKg': _results!['co2SavedKg'],
        'creditsEarned': _results!['creditsEarned'],
        'calculatedCarbonKg': _results!['carbonKg'], // CO2 emitido se não fosse sustentável
        'calculatedValue': _results!['carbonValue'], // Valor monetário do CO2
        'processedForWallet': false, // Controle para processamento de créditos
        'createdAt': FieldValue.serverTimestamp(),
        'calculationMethod': 'manual_route',
      };
      debugPrint("[TripCalculator] Salvando viagem manual: $tripData");
      await FirebaseFirestore.instance.collection('trips').add(tripData);
      debugPrint("[TripCalculator] Viagem manual salva com sucesso!");
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
          _selectedVehicleDataString = null; // Opcional: resetar veículo também
          debugPrint("[TripCalculator] Formulário limpo após salvar.");
        });
      }
    } catch (e, s) {
      print("!!! ERRO AO SALVAR VIAGEM MANUAL: $e\n$s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao salvar registro.'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      debugPrint("--- [TripCalculator] Finalizando _saveManualTrip (finally) ---");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color kmColor = Colors.blueAccent[100]!;
    final Color co2Color = Colors.greenAccent[400]!;
    final Color creditsColor = Colors.lightGreenAccent[400]!;
    final Color valueColorPositive = Colors.greenAccent[400]!;
    final Color valueColorNegative = Colors.redAccent[100]!;

    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.grey[900]?.withOpacity(0.5),
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
                      // Limpa resultados anteriores se o veículo mudar
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
                  style: GoogleFonts.poppins(color: textColor, fontSize: 15), // Ajuste de fonte
                  validator: (v) => v == null || v.isEmpty ? 'Selecione um veículo' : null,
                ).animate().fadeIn(),
              const SizedBox(height: 15),
              TextFormField(
                controller: _originController,
                enabled: !_isCalculating,
                style: const TextStyle(color: textColor, fontSize: 15), // Ajuste de fonte
                decoration: _inputDecoration(
                    labelText: 'Origem (Ex: São Paulo, SP) *', // Exemplo de formato
                    prefixIcon: Icons.trip_origin),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 12),
              TextFormField(
                controller: _destinationController,
                enabled: !_isCalculating,
                style: const TextStyle(color: textColor, fontSize: 15), // Ajuste de fonte
                decoration: _inputDecoration(
                    labelText: 'Destino (Ex: Rio de Janeiro, RJ) *', // Exemplo de formato
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
                      icon: const Icon(Icons.route_outlined, size: 20), // Ícone de rota
                      label: const Text('Calcular Rota Real'), // Texto atualizado
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14), // Mais padding
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black87,
                          textStyle: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.bold), // Fonte
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
                          Text('Resultados Estimados para a Rota:', // Texto atualizado
                              style: GoogleFonts.orbitron(fontSize: 15, color: textColor)),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              IndicatorCard(
                                isLoading: _isCalculating, // Este não deveria ser _isCalculating aqui, mas ok
                                title: 'DISTÂNCIA REAL',
                                value: '${_results!['distance']?.toStringAsFixed(1) ?? 'N/A'} km',
                                icon: Icons.social_distance_outlined, // Ícone atualizado
                                accentColor: kmColor,
                              ),
                              IndicatorCard(
                                isLoading: _isCalculating,
                                title: _results!['isElectric'] ? 'CO₂ EVITADO' : 'EMISSÃO CO₂', // Título mais claro
                                value: '${(_results!['isElectric'] ? _results!['co2SavedKg'] : _results!['carbonKg'])?.toStringAsFixed(2) ?? 'N/A'} kg',
                                icon: _results!['isElectric'] ? Icons.shield_moon_outlined : Icons.cloud_upload_outlined, // Ícones atualizados
                                accentColor: (_results!['co2SavedKg'] ?? 0) > 0 || _results!['isElectric'] ? co2Color : valueColorNegative, // Cor baseada no tipo/valor
                              ),
                              IndicatorCard(
                                isLoading: _isCalculating,
                                title: 'CRÉDITOS GERADOS',
                                value: '${_results!['creditsEarned']?.toStringAsFixed(4) ?? 'N/A'}',
                                icon: Icons.paid_outlined, // Ícone atualizado
                                accentColor: creditsColor,
                              ),
                              IndicatorCard(
                                isLoading: _isCalculating,
                                title: 'VALOR (SEQUESTRO)', // Título mais claro
                                value: 'R\$ ${_results!['carbonValue']?.toStringAsFixed(2) ?? 'N/A'}',
                                icon: Icons.attach_money_outlined, // Ícone atualizado
                                accentColor: (_results!['carbonValue'] ?? 0) >= 0 ? valueColorPositive : valueColorNegative,
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          if (!_isLoading && !_isCalculating) // Só mostra salvar se não estiver carregando ou calculando
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
                          else if (_isLoading) // Loading específico para salvar
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
        prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Icon(prefixIcon, color: iconColor.withOpacity(0.8), size: 20)),
        prefixIconConstraints: const BoxConstraints(minWidth:20, minHeight:20),
        filled: true,
        fillColor: inputFillColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: inputBorderColor.withOpacity(0.5))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: inputBorderColor.withOpacity(0.5))),
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
        errorStyle: TextStyle(color: errorColor.withOpacity(0.95), fontSize: 12)
    );
  }
}