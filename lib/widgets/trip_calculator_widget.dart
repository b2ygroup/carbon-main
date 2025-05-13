// lib/widgets/trip_calculator_widget.dart (COMPLETO FINAL - v2)
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:carbon/models/vehicle_type_enum.dart'; // CONFIRME NOME PACOTE
import 'package:carbon/services/carbon_service.dart'; // CONFIRME NOME PACOTE
import 'package:carbon/widgets/indicator_card.dart';   // CONFIRME NOME PACOTE
import 'package:google_fonts/google_fonts.dart';
// Precisa se usar formatters

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
  bool _isCalculating = false; // Para calcular
  Map<String, dynamic>? _results;
  List<DropdownMenuItem<String>> _vehicleDropdownItems = [];
  bool _vehiclesLoading = true;
  final CarbonService _carbonService = CarbonService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

   // Cores Consistentes
  static const Color primaryColor = Color(0xFF00BFFF);
  static const Color secondaryColor = Color(0xFF00FFFF);
  static final Color errorColor = Colors.redAccent[100]!;
  static final Color inputFillColor = Colors.white.withOpacity(0.05);
  static final Color inputBorderColor = Colors.grey[700]!;
  static final Color labelColor = Colors.grey[400]!;
  static const Color textColor = Colors.white;
  static const Color iconColor = primaryColor;

  @override
  void initState() { super.initState(); if (_currentUser != null) { _fetchUserVehicles(_currentUser.uid); } else { if (mounted) setState(() => _vehiclesLoading = false); debugPrint("[TripCalculator] Usuário não logado no initState."); } }
  @override
  void dispose() { _originController.dispose(); _destinationController.dispose(); super.dispose(); }

  // <<< FUNÇÃO COMPLETA >>>
  Future<void> _fetchUserVehicles(String userId) async {
     debugPrint("[TripCalculator] _fetchUserVehicles: Buscando veículos para $userId...");
     if (!mounted) return; setState(() => _vehiclesLoading = true); try { final snapshot = await FirebaseFirestore.instance.collection('vehicles').where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).get(); final items = snapshot.docs.map((doc) { final data = doc.data(); final type = vehicleTypeFromString(data['type'] as String?); final label = '${data['make'] ?? '?'} ${data['model'] ?? '?'} (${type?.displayName ?? data['type'] ?? 'Tipo Desconhecido'})'; final valueString = '${doc.id}|${type?.name ?? ''}'; return DropdownMenuItem<String>( value: valueString, child: Text(label, overflow: TextOverflow.ellipsis) ); }).toList(); if (mounted) setState(() { _vehicleDropdownItems = items; debugPrint("[TripCalculator] _fetchUserVehicles: ${items.length} veículos carregados."); }); } catch (e) { print("!!! ERRO fetch Calc vehicles: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Erro ao carregar veículos.'), backgroundColor: Colors.red), ); } } finally { if (mounted) setState(() => _vehiclesLoading = false); }
  }

  // <<< FUNÇÃO COMPLETA >>>
  Future<void> _calculateTrip() async {
    debugPrint("***** _calculateTrip FOI CHAMADO *****"); // DEBUG INICIAL

    final isValid = _formKey.currentState?.validate() ?? false;
    debugPrint("[TripCalculator] Formulário válido: $isValid");
    FocusScope.of(context).unfocus();
    if (!isValid) { debugPrint("[TripCalculator] Formulário inválido. Abortando."); return; }

    debugPrint("[TripCalculator] Veículo selecionado string: $_selectedVehicleDataString");
    if (_selectedVehicleDataString == null) { debugPrint("[TripCalculator] Nenhum veículo selecionado. Abortando."); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Selecione um veículo.'), backgroundColor: Colors.orange), ); } return; }

    if (_isCalculating) { debugPrint("[TripCalculator] Já estava calculando, abortando nova chamada."); return; }
    setState(() { debugPrint("[TripCalculator] Definindo _isCalculating = true"); _isCalculating = true; _results = null; });

    final originText = _originController.text.trim(); final destinationText = _destinationController.text.trim();
    final parts = _selectedVehicleDataString!.split('|'); final vehicleId = parts[0]; final vehicleType = vehicleTypeFromString(parts.length > 1 ? parts[1] : null);
    debugPrint("[TripCalculator] Dados extraídos: Origin='$originText', Dest='$destinationText', VehID='$vehicleId', VehType Enum=$vehicleType");

    if (vehicleType == null) { print("!!! ERRO: Tipo de veículo inválido ($parts[1]). Abortando. !!!"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Erro interno: tipo de veículo inválido.'), backgroundColor: Colors.red), ); setState(() => _isCalculating = false); } return; } // Resetar loading no erro

    try {
      debugPrint("[TripCalculator] Iniciando simulação de distância e cálculo de impacto...");
      await Future.delayed(1200.ms); // Simula API
      final randomDistance = 50.0 + Random().nextDouble() * 500.0; double distanceKm = double.parse(randomDistance.toStringAsFixed(1));
      debugPrint("[TripCalculator] Distância simulada: $distanceKm km");

      debugPrint("[TripCalculator] Chamando _carbonService.getTripCalculationResults...");
      final Map<String, double> impactResults = await _carbonService.getTripCalculationResults( distanceKm: distanceKm, vehicleType: vehicleType, );
      debugPrint("[TripCalculator] Resultados recebidos do serviço: $impactResults");

      final double carbonKg = impactResults['carbonKg'] ?? 0.0; final double co2SavedKg = impactResults['co2SavedKg'] ?? 0.0; final double creditsEarned = impactResults['creditsEarned'] ?? 0.0; final double carbonValue = impactResults['carbonValue'] ?? 0.0;

      if (mounted) {
        setState(() {
          debugPrint("[TripCalculator] Atualizando estado com resultados...");
          _results = { 'distance': distanceKm, 'carbonKg': carbonKg, 'co2SavedKg': co2SavedKg, 'creditsEarned': creditsEarned, 'carbonValue': carbonValue, 'isElectric': vehicleType == VehicleType.electric || vehicleType == VehicleType.hybrid, 'origin': originText, 'destination': destinationText, 'vehicleId': vehicleId, 'vehicleType': vehicleType, };
          debugPrint("[TripCalculator] Estado atualizado com: $_results");
        });
        debugPrint("[TripCalculator] Estado atualizado com sucesso.");
      }
    } catch (e, s) { print("!!! ERRO GERAL durante cálculo/simulação: $e\n$s"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Erro ao calcular rota.'), backgroundColor: Colors.redAccent), ); } }
    finally { debugPrint("--- [TripCalculator] Finalizando _calculateTrip (finally) ---"); if (mounted) { setState(() { _isCalculating = false; }); } }
  } // Fim _calculateTrip

  // <<< FUNÇÃO COMPLETA >>>
  Future<void> _saveManualTrip() async {
    debugPrint("--- [TripCalculator] Iniciando _saveManualTrip ---");
    if (_results == null) { debugPrint("[TripCalculator] _saveManualTrip: Nenhum resultado para salvar."); return; }
    if (_currentUser == null) { debugPrint("[TripCalculator] _saveManualTrip: Usuário nulo."); return; }
    if (!mounted) return;
    setState(() { _isLoading = true; }); // Usa _isLoading para salvar
    await Future.delayed(200.ms);
    try {
      final Map<String, dynamic> tripData = { 'userId': _currentUser.uid, 'vehicleId': _results!['vehicleId'], 'vehicleType': (_results!['vehicleType'] as VehicleType).name, 'origin': _results!['origin'], 'destination': _results!['destination'], 'distanceKm': _results!['distance'], 'startTime': Timestamp.now(), 'endTime': Timestamp.now(), 'durationMinutes': 0, 'co2SavedKg': _results!['co2SavedKg'], 'creditsEarned': _results!['creditsEarned'], 'calculatedCarbonKg': _results!['carbonKg'], 'calculatedValue': _results!['carbonValue'], 'processedForWallet': false, 'createdAt': FieldValue.serverTimestamp(), 'calculationMethod': 'manual_route', };
      debugPrint("[TripCalculator] Salvando viagem manual: $tripData");
      await FirebaseFirestore.instance.collection('trips').add(tripData);
      debugPrint("[TripCalculator] Viagem manual salva com sucesso!");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Viagem calculada registrada!'), backgroundColor: Colors.green), ); _originController.clear(); _destinationController.clear(); setState(() { _results = null; _selectedVehicleDataString = null; debugPrint("[TripCalculator] Formulário limpo após salvar."); }); }
    } catch (e, s) { print("!!! ERRO AO SALVAR VIAGEM MANUAL: $e\n$s"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Erro ao salvar registro.'), backgroundColor: Colors.redAccent), ); }
    } finally { debugPrint("--- [TripCalculator] Finalizando _saveManualTrip (finally) ---"); if (mounted) { setState(() { _isLoading = false; }); } }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); final colorScheme = theme.colorScheme;
    final Color kmColor = Colors.blueAccent[100]!; final Color co2Color = Colors.greenAccent[400]!; final Color creditsColor = Colors.lightGreenAccent[400]!; final Color valueColorPositive = Colors.greenAccent[400]!; final Color valueColorNegative = Colors.redAccent[100]!;

    return Card( elevation: 4, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), color: Colors.grey[900]?.withOpacity(0.5),
      child: Padding( padding: const EdgeInsets.all(20.0),
        child: Form( key: _formKey,
          child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text( 'Calcular Rota e Impacto', style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 25),
              // Dropdown Veículos
              if (_vehiclesLoading) const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: CircularProgressIndicator(strokeWidth: 2, color: secondaryColor)))
              else if (_vehicleDropdownItems.isEmpty) Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text( _currentUser == null ? 'Faça login...' : 'Nenhum veículo cadastrado.', textAlign: TextAlign.center, style: TextStyle(color: labelColor), ), )
              else DropdownButtonFormField<String>( value: _selectedVehicleDataString, items: _vehicleDropdownItems, onChanged: _isCalculating ? null : (String? newValue) { if (newValue != _selectedVehicleDataString && _results != null) { setState(() => _results = null); } setState(() => _selectedVehicleDataString = newValue); }, isExpanded: true, decoration: _inputDecoration( labelText: 'Selecione o Veículo *', prefixIcon: Icons.directions_car_outlined, ), dropdownColor: Colors.grey[850], style: GoogleFonts.poppins(color: textColor, fontSize: 16), validator: (v) => v == null || v.isEmpty ? 'Selecione um veículo' : null, ).animate().fadeIn(),
              const SizedBox(height: 15),
              // Origem/Destino
              TextFormField( controller: _originController, enabled: !_isCalculating, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Origem *', prefixIcon: Icons.trip_origin), validator: (v)=>(v==null||v.trim().isEmpty)?'Obrigatório':null, ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 12),
              TextFormField( controller: _destinationController, enabled: !_isCalculating, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Destino *', prefixIcon: Icons.flag_outlined), validator: (v)=>(v==null||v.trim().isEmpty)?'Obrigatório':null, ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 25),
              // Botão Calcular/Loading
              _isCalculating ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SpinKitPulse(color: primaryColor, size: 30.0)))
              : ElevatedButton.icon( onPressed: _calculateTrip, icon: const Icon(Icons.calculate_outlined, size: 20), label: const Text('Calcular Rota e Impacto'), style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: primaryColor, foregroundColor: Colors.black87, textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 4 ), ).animate().fadeIn(delay: 200.ms).scale(),
              // Área de Resultados
              AnimatedSize( duration: 300.ms, curve: Curves.easeInOut,
                child: _results != null ? Column( children: [ const Divider(height: 40, thickness: 0.5, indent: 20, endIndent: 20, color: Colors.grey), Text('Resultados Estimados:', style: GoogleFonts.orbitron(fontSize: 15, color: textColor)), const SizedBox(height: 15), Wrap( spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [ IndicatorCard( isLoading: _isCalculating, title: 'DISTÂNCIA', value: '${_results!['distance']?.toStringAsFixed(1) ?? 'N/A'} km', icon: Icons.route_outlined, accentColor: kmColor, ), IndicatorCard( isLoading: _isCalculating, title: _results!['isElectric'] ? 'CO₂ SALVO' : 'IMPACTO CO₂', value: '${(_results!['isElectric'] ? _results!['co2SavedKg'] : _results!['carbonKg'])?.toStringAsFixed(2) ?? 'N/A'} kg', icon: _results!['isElectric'] ? Icons.eco_outlined : Icons.co2, accentColor: (_results!['co2SavedKg'] ?? 0) > 0 ? co2Color : Colors.grey[400]!, ), IndicatorCard( isLoading: _isCalculating, title: 'CRÉDITOS GERADOS', value: '${_results!['creditsEarned']?.toStringAsFixed(4) ?? 'N/A'}', icon: Icons.toll_outlined, accentColor: creditsColor, ), IndicatorCard( isLoading: _isCalculating, title: 'VALOR MONETÁRIO', value: 'R\$ ${_results!['carbonValue']?.toStringAsFixed(2) ?? 'N/A'}', icon: Icons.paid_outlined, accentColor: (_results!['carbonValue'] ?? 0) >= 0 ? valueColorPositive : valueColorNegative, ), ], ), const SizedBox(height: 20), if (!_isLoading) Center( child: TextButton.icon( onPressed: _saveManualTrip, icon: const Icon(Icons.save_alt, size: 18), label: const Text('Registrar Viagem Calculada'), style: TextButton.styleFrom(foregroundColor: secondaryColor), ) ) else const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: secondaryColor)))), ], ) : const SizedBox.shrink(),
              ).animate().fadeIn(delay: 200.ms)
            ],
          ),
        ),
      ),
    );
  }

 // Helper InputDecoration (Consistente)
 InputDecoration _inputDecoration({ required String labelText, required IconData prefixIcon }) { return InputDecoration( labelText: labelText, labelStyle: GoogleFonts.poppins(textStyle:TextStyle(color: labelColor, fontSize: 14)), prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Icon(prefixIcon, color: iconColor.withOpacity(0.8), size: 20)), prefixIconConstraints: const BoxConstraints(minWidth:20, minHeight:20), filled: true, fillColor: inputFillColor, contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0), border: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: inputBorderColor.withOpacity(0.5))), enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: inputBorderColor.withOpacity(0.5))), focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: secondaryColor, width: 1.5)), errorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: errorColor)), focusedErrorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: errorColor, width: 1.5)), counterText: "", errorStyle: TextStyle(color: errorColor.withOpacity(0.95), fontSize: 12) ); }
}