// lib/screens/dashboard_screen.dart (COMPLETO E FINAL - v5 - RETURNS CORRIGIDOS)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';

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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  // --- Estados ---
  bool _isTracking = false; bool _isLoadingGpsSave = false; double _currentDistanceKm = 0.0; String? _selectedVehicleIdForTrip; VehicleType? _selectedVehicleTypeForTrip; StreamSubscription<Position>? _positionStreamSubscription; Position? _lastPosition; double _accumulatedDistanceMeters = 0.0; DateTime? _tripStartTime; final _originController = TextEditingController(); final _destinationController = TextEditingController(); String _currentOrigin = ''; String _currentDestination = ''; String _currentVehicleId = ''; VehicleType? _currentVehicleType;
  final CarbonService _carbonService = CarbonService(); final User? _currentUser = FirebaseAuth.instance.currentUser; late TabController _tabController;

  @override
  void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); _tabController.addListener(() { if(mounted) setState(() {}); }); }
  @override
  void dispose() { _positionStreamSubscription?.cancel(); _originController.dispose(); _destinationController.dispose(); _tabController.removeListener(() {}); _tabController.dispose(); super.dispose(); }

  // --- Navegação ---
  void _navigateToAddVehicle() { Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const RegistrationScreen())); }
  void _navigateToFleetManagement() { Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const FleetManagementScreen())); }
  void _navigateToCalculatorScreen() { Navigator.push(context, MaterialPageRoute(builder: (_) => const TripCalculatorScreen())); }
  void _navigateToTripHistory() { Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const TripHistoryScreen())); }
  Future<void> _logout() async { Provider.of<UserProvider>(context, listen: false).clearUserDataOnLogout(); await FirebaseAuth.instance.signOut(); }


  // --- Lógica Principal (toggleTracking, handleVehicleSelection) ---
  Future<void> _toggleTracking() async {
      if (_isTracking) {
        setState(() { _isLoadingGpsSave = true; });
        try {
          await _positionStreamSubscription?.cancel(); _positionStreamSubscription = null; _lastPosition = null;
          final DateTime tripEndTime = DateTime.now(); final double finalDistanceKm = _accumulatedDistanceMeters / 1000.0;
          if (_currentUser != null && _currentVehicleId.isNotEmpty && _currentVehicleType != null && _tripStartTime != null && finalDistanceKm > 0.01) {
            final String userId = _currentUser.uid;
            final double co2SavedKg = await _carbonService.calculateCO2Saved(_currentVehicleType!, finalDistanceKm);
            final double creditsEarned = await _carbonService.calculateCreditsEarned(_currentVehicleType!, finalDistanceKm);
            final tripData = { 'userId': userId, 'vehicleId': _currentVehicleId, 'vehicleType': _currentVehicleType!.name, 'distanceKm': finalDistanceKm, 'startTime': Timestamp.fromDate(_tripStartTime!), 'endTime': Timestamp.fromDate(tripEndTime), 'durationMinutes': tripEndTime.difference(_tripStartTime!).inMinutes, 'origin': _currentOrigin.isNotEmpty ? _currentOrigin : null, 'destination': _currentDestination.isNotEmpty ? _currentDestination : null, 'co2SavedKg': co2SavedKg, 'creditsEarned': creditsEarned, 'createdAt': FieldValue.serverTimestamp(), 'calculationMethod': 'gps', };
            await FirebaseFirestore.instance.collection('trips').add(tripData);
            if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viagem salva!'), backgroundColor: Colors.green));
            _originController.clear(); _destinationController.clear(); _accumulatedDistanceMeters = 0.0; _currentDistanceKm = 0.0; _tripStartTime = null; _currentOrigin = ''; _currentDestination = '';
          } else { String message = 'Não foi possível salvar. '; if (_currentUser == null) message += 'Erro de usuário. '; if (_currentVehicleId.isEmpty || _currentVehicleType == null) message += 'Veículo inválido. '; if (_tripStartTime == null) message += 'Tempo inválido. '; if (finalDistanceKm <= 0.01) message += 'Distância curta. '; if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.orange)); _accumulatedDistanceMeters = 0.0; _currentDistanceKm = 0.0; _tripStartTime = null; }
        } catch (e) { print("Erro save trip: $e"); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: ${e.toString()}'), backgroundColor: Colors.red)); _accumulatedDistanceMeters = 0.0; _currentDistanceKm = 0.0; _tripStartTime = null;
        } finally { if (mounted) { setState(() { _isLoadingGpsSave = false; _isTracking = false; }); } }
      } else {
         if (_selectedVehicleIdForTrip == null || _selectedVehicleTypeForTrip == null) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um veículo abaixo.'), backgroundColor: Colors.orange)); return; }
        bool serviceEnabled; LocationPermission permission;
        serviceEnabled = await Geolocator.isLocationServiceEnabled(); if (!serviceEnabled) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS desativado.'))); return; }
        permission = await Geolocator.checkPermission(); if (permission == LocationPermission.denied) { permission = await Geolocator.requestPermission(); if (permission == LocationPermission.denied) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão negada.'))); return; } }
        if (permission == LocationPermission.deniedForever) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão negada permanentemente.'))); return; }
        setState(() { _isTracking = true; _accumulatedDistanceMeters = 0.0; _currentDistanceKm = 0.0; _lastPosition = null; _tripStartTime = DateTime.now(); _currentOrigin = _originController.text.trim(); _currentDestination = _destinationController.text.trim(); _currentVehicleId = _selectedVehicleIdForTrip!; _currentVehicleType = _selectedVehicleTypeForTrip; });
        const LocationSettings locationSettings = LocationSettings( accuracy: LocationAccuracy.high, distanceFilter: 10, );
        _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen( (Position position) { if (mounted) { setState(() { if (_lastPosition != null) { double distanceDeltaMeters = Geolocator.distanceBetween( _lastPosition!.latitude, _lastPosition!.longitude, position.latitude, position.longitude, ); if (distanceDeltaMeters > 1.0) { _accumulatedDistanceMeters += distanceDeltaMeters; _currentDistanceKm = _accumulatedDistanceMeters / 1000.0; } } _lastPosition = position; }); } }, onError: (error) { print("Erro GPS stream: $error"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro GPS: ${error.toString()}'), backgroundColor: Colors.red)); } }, cancelOnError: false, );
      }
  }
  void _handleVehicleSelection(String vehicleId, VehicleType? vehicleType) { if (!_isTracking) { setState(() { if (_selectedVehicleIdForTrip == vehicleId) { _selectedVehicleIdForTrip = null; _selectedVehicleTypeForTrip = null; } else { _selectedVehicleIdForTrip = vehicleId; _selectedVehicleTypeForTrip = vehicleType; } }); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não pode mudar veículo durante viagem.'), backgroundColor: Colors.orange)); } }

  // =====================================================================
  // ***** WIDGETS BUILDERS (Helpers) - TODOS COMPLETOS E CORRIGIDOS *****
  // =====================================================================

  // --- Indicadores ---
  Widget _buildIndicatorsSection(String userId) {
      final Color kmColor = Colors.blueAccent[100]!; final Color co2Color = Colors.greenAccent[400]!; final Color creditsColor = Colors.lightGreenAccent[400]!; final Color walletColor = Colors.amberAccent[100]!; final Color errorColor = Colors.redAccent[100]!;
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('trips').where('userId', isEqualTo: userId).snapshots(),
        builder: (context, tripSnapshot) {
          double totalKm = 0.0; double totalCO2 = 0.0; double totalCredits = 0.0; bool tripsHaveError = tripSnapshot.hasError; bool tripIndicatorsLoading = tripSnapshot.connectionState == ConnectionState.waiting;
          if (!tripsHaveError && tripSnapshot.hasData) { debugPrint("[Indicators] Lendo ${tripSnapshot.data!.docs.length} viagens..."); for (var doc in tripSnapshot.data!.docs) { final data = doc.data() as Map<String, dynamic>? ?? {}; final dist = (data['distanceKm'] as num?)?.toDouble() ?? 0.0; final co2 = (data['co2SavedKg'] as num?)?.toDouble() ?? 0.0; final cred = (data['creditsEarned'] as num?)?.toDouble() ?? 0.0; totalKm += dist; totalCO2 += co2; totalCredits += cred; } debugPrint("[Indicators] Totais Calculados: KM=$totalKm, CO2=$totalCO2, Credits=$totalCredits"); } else if(tripsHaveError) { print("Erro trip stream: ${tripSnapshot.error}"); } else if(!tripIndicatorsLoading) { debugPrint("[Indicators] Trip Stream ativo, mas sem dados (hasData=false).");}
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('wallets').doc(userId).snapshots(),
            builder: (context, walletSnapshot) {
              double walletBalance = 0.0; bool walletHasError = walletSnapshot.hasError; bool walletIsLoading = walletSnapshot.connectionState == ConnectionState.waiting; String walletValueForDisplay = "...";
              if (!walletIsLoading && !walletHasError && walletSnapshot.hasData) { if (walletSnapshot.data!.exists) { final d = walletSnapshot.data!.data() as Map<String, dynamic>?; if (d != null && d.containsKey('balance')) { walletBalance = (d['balance'] as num?)?.toDouble() ?? 0.0; walletValueForDisplay = "R\$ ${walletBalance.toStringAsFixed(2)}"; debugPrint("[Wallet Indicator] Saldo Lido: $walletValueForDisplay"); } else { walletHasError = true; walletValueForDisplay = "Inválido"; debugPrint("[Wallet Indicator] Doc existe, mas campo 'balance' inválido/ausente.");} } else { walletValueForDisplay = "R\$ 0.00"; debugPrint("[Wallet Indicator] Doc não existe, mostrando 0.00."); } } else if (walletHasError) { walletValueForDisplay = "Erro"; print("Erro wallet stream: ${walletSnapshot.error}"); }
              // <<< CORRIGIDO: Adicionado RETURN >>>
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 70.0),
                child: GridView.count(
                  crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10.0, crossAxisSpacing: 10.0,
                  childAspectRatio: 2.2, // Ajuste a proporção aqui
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

  // --- Barra de Progresso Circular ---
  // <<< CORRIGIDO: Adicionado RETURN >>>
  Widget _buildProgressBarSection() {
    double currentProgress = 0.0; // Exemplo (calcular valor real)
    // <<< CORRIGIDO: Retorna Padding >>>
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        children: [
          CircularPercentIndicator( radius: 35.0, lineWidth: 8.0, percent: currentProgress, center: Text( "${(currentProgress * 100).toInt()}%", style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70), ), progressColor: Colors.cyanAccent[400], backgroundColor: Colors.grey[800]!, circularStrokeCap: CircularStrokeCap.round, animateFromLastPercent: true, animation: true, ),
          const SizedBox(width: 16),
          Expanded( child: Text( "Economizando CO₂ com transporte sustentável", style: GoogleFonts.poppins( fontSize: 14, color: Colors.white.withOpacity(0.8), ), ), ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2);
  }

  // --- Botões de Ação Principais ---
  // <<< CORRIGIDO: Adicionado RETURN >>>
  Widget _buildActionButtons() {
    final Color accentColor = Colors.cyanAccent[400]!; final Color selectedColor = accentColor; final Color unselectedColor = Colors.grey[850]!; const Color selectedTextColor = Colors.black87; const Color unselectedTextColor = Colors.white70;
    // <<< CORRIGIDO: Retorna Padding >>>
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

  // --- Conteúdo da Aba de Rastreio GPS ---
  // <<< CORRIGIDO: Adicionado RETURN >>>
  Widget _buildGpsTrackingTabContent(ThemeData theme, Color subtleTextColor, Color primaryColor){
     final errorColor = theme.colorScheme.error; final accentColor = primaryColor;
     // <<< CORRIGIDO: Retorna Card >>>
     return Card( elevation: 4, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), color: Colors.grey[900]?.withOpacity(0.5),
       child: Padding( padding: const EdgeInsets.all(20.0),
          child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Monitorar Viagem GPS', style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 20),
              GestureDetector(
                onTap: _showVehicleSelectionDialogForTracking, // Chama diálogo
                child: ListTile( contentPadding: EdgeInsets.zero, dense: true, leading: Icon( _selectedVehicleTypeForTrip?.icon ?? Icons.directions_car, color: _selectedVehicleIdForTrip != null ? (_selectedVehicleTypeForTrip?.displayColor ?? accentColor) : subtleTextColor, size: 32, ), title: Text('Veículo Selecionado:', style: theme.textTheme.bodySmall?.copyWith(color: subtleTextColor)), subtitle: Text( _selectedVehicleIdForTrip != null ? '${_selectedVehicleTypeForTrip?.displayName ?? 'Tipo Desconhecido'} (Toque aqui para alterar)' : "Selecione um veículo na lista abaixo", style: theme.textTheme.bodyMedium?.copyWith( fontWeight: _selectedVehicleIdForTrip != null ? FontWeight.bold : FontWeight.normal, color: _selectedVehicleIdForTrip == null ? errorColor : Colors.white70 ) ), ),
              ), const SizedBox(height: 15),
              TextFormField( controller: _originController, enabled: !_isTracking, style: const TextStyle(color: Colors.white), decoration: InputDecoration( labelText: 'Origem (Opcional)', labelStyle: TextStyle(color: subtleTextColor), hintText: 'Ex: Casa, Trabalho...', hintStyle: TextStyle(color: subtleTextColor.withOpacity(0.5)), isDense: true, prefixIcon: Icon(Icons.trip_origin, color: subtleTextColor), filled: true, fillColor: Colors.black.withOpacity(0.2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor)), ), ), const SizedBox(height: 12),
              TextFormField( controller: _destinationController, enabled: !_isTracking, style: const TextStyle(color: Colors.white), decoration: InputDecoration( labelText: 'Destino (Opcional)', labelStyle: TextStyle(color: subtleTextColor), hintText: 'Ex: Mercado, Academia...', hintStyle: TextStyle(color: subtleTextColor.withOpacity(0.5)), isDense: true, prefixIcon: Icon(Icons.flag_outlined, color: subtleTextColor), filled: true, fillColor: Colors.black.withOpacity(0.2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor)), ), ), const SizedBox(height: 20),
              if (_isTracking) Center( child: Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.route, color: accentColor, size: 26), const SizedBox(width: 8), Text( '${_currentDistanceKm.toStringAsFixed(2)} km', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accentColor) ), const SizedBox(width: 10), SpinKitPulse(color: accentColor, size: 15.0) ] ) ) ).animate(onPlay: (c)=>c.repeat()).shimmer(delay: 400.ms, duration: 1000.ms, color: Colors.white.withOpacity(0.1)).scaleY(), const SizedBox(height: 20),
              Center( child: _isLoadingGpsSave ? Padding( padding: const EdgeInsets.symmetric(vertical: 10), child: Column( children: [ SpinKitWave(color: accentColor, size: 25.0), const SizedBox(height: 8), Text("Salvando viagem...", style: TextStyle(color: subtleTextColor)) ], ) ) : ElevatedButton.icon( onPressed: (_selectedVehicleIdForTrip != null || _isTracking) ? _toggleTracking : null, icon: Icon( _isTracking ? Icons.stop_circle_outlined : Icons.play_circle_outline, size: 24), label: Padding( padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(_isTracking ? 'Parar e Salvar Viagem' : 'Iniciar Viagem', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), ), style: ElevatedButton.styleFrom( backgroundColor: _isTracking ? errorColor.withOpacity(0.9) : accentColor, foregroundColor: _isTracking ? Colors.white : Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 8, shadowColor: _isTracking ? errorColor : accentColor, ), ).animate().scale(delay: 100.ms), ),
              if (!_isTracking && _selectedVehicleIdForTrip == null) Padding( padding: const EdgeInsets.only(top: 12.0), child: Center( child: Text( "Selecione um veículo na lista abaixo\npara iniciar o monitoramento.", style: theme.textTheme.bodySmall?.copyWith(color: errorColor.withOpacity(0.8)), textAlign: TextAlign.center, ) ), )
            ],
          ),
        ),
     );
   }

   // --- Diálogo de Seleção de Veículo para GPS ---
  void _showVehicleSelectionDialogForTracking() async {
      if (_isTracking) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não é possível mudar o veículo durante uma viagem ativa.'), backgroundColor: Colors.orange)); return; }
      if (_currentUser == null) return;
      List<Map<String, dynamic>> vehicles = [];
      try {
         final snapshot = await FirebaseFirestore.instance.collection('vehicles').where('userId', isEqualTo: _currentUser.uid).orderBy('createdAt', descending: true).get();
         vehicles = snapshot.docs.map((doc) { final data = doc.data(); final type = vehicleTypeFromString(data['type']); return {'id': doc.id, 'label': '${data['make'] ?? '?'} ${data['model'] ?? '?'} (${type?.displayName ?? data['type'] ?? '?'})', 'type': type}; }).toList();
      } catch (e) { print("Erro ao buscar veículos para seleção: $e"); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao carregar lista de veículos.'), backgroundColor: Colors.red)); return; }
      if (vehicles.isEmpty) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum veículo cadastrado para selecionar.'))); return; }
      final selectedVehicleInfo = await showDialog<Map<String, dynamic>>( context: context, builder: (BuildContext context) {
            return AlertDialog( backgroundColor: Colors.grey[900], title: Text('Selecione um Veículo', style: GoogleFonts.orbitron(color: Colors.cyanAccent[400])),
               content: SizedBox( width: double.maxFinite, child: ListView.builder( shrinkWrap: true, itemCount: vehicles.length, itemBuilder: (context, index) { final vehicle = vehicles[index]; return ListTile( leading: Icon( (vehicle['type'] as VehicleType?)?.icon ?? Icons.car_rental, color: (vehicle['type'] as VehicleType?)?.displayColor ?? Colors.white70), title: Text(vehicle['label'], style: const TextStyle(color: Colors.white)), onTap: () { Navigator.of(context).pop(vehicle); }, ); }, ), ),
               actions: [ TextButton( onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancelar', style: TextStyle(color: Colors.grey)))], ); } );
      if (selectedVehicleInfo != null) { _handleVehicleSelection(selectedVehicleInfo['id'], selectedVehicleInfo['type'] as VehicleType?); }
   }

  // --- Cabeçalho da Seção de Veículos ---
  // <<< CORRIGIDO: Adicionado RETURN >>>
  Widget _buildVehicleSectionHeader(ThemeData theme, Color primaryColor) {
     final titleColor = Colors.white.withOpacity(0.9); final buttonColor = primaryColor;
     // <<< CORRIGIDO: Retorna Padding >>>
     return Padding( padding: const EdgeInsets.only(top: 16.0),
       child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text( 'Meus Veículos', style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor) ),
            Row( mainAxisSize: MainAxisSize.min, children: [ TextButton.icon( icon: Icon(Icons.add_circle_outline, size: 18, color: buttonColor), label: Text('Adicionar', style: TextStyle(color: buttonColor.withOpacity(0.8), fontSize: 13)), style: TextButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 8), ), onPressed: _navigateToAddVehicle ), const SizedBox(width: 0), TextButton.icon( icon: Icon(Icons.list_alt_rounded, size: 18, color: Colors.grey[500]), label: Text('Gerenciar', style: TextStyle(color: Colors.grey[500], fontSize: 13)), style: TextButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 8), ), onPressed: _navigateToFleetManagement ), ], ) ], ), );
   }

  // --- Lista de Veículos ---
  // <<< CORRIGIDO: Adicionado RETURN >>>
  Widget _buildVehicleList(String userId, ThemeData theme, Color primaryColor, Color subtleTextColor) {
     final cardColor = Colors.grey[850]!.withOpacity(0.6); final selectedBorderColor = primaryColor; final normalBorderColor = Colors.grey[700]!; final titleColor = Colors.white.withOpacity(0.9); final subtitleColor = Colors.white.withOpacity(0.6); const iconColor = Colors.white70; final accentColor = primaryColor;
     // <<< CORRIGIDO: Retorna StreamBuilder >>>
     return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehicles').where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) { return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 30.0), child: CircularProgressIndicator(strokeWidth: 2, color: accentColor))); }
          if (snapshot.hasError) { return Center(child: Text('Erro ao carregar veículos.', style: TextStyle(color: theme.colorScheme.error))); }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { return Card( elevation: 1, color: cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding( padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0), child: Column( mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.directions_car_outlined, color: subtitleColor, size: 30), const SizedBox(height: 10), Text( 'Nenhum veículo cadastrado.', textAlign: TextAlign.center, style: TextStyle(color: subtitleColor) ), const SizedBox(height: 15), ElevatedButton.icon( icon: const Icon(Icons.add, size: 18), onPressed: _navigateToAddVehicle, label: const Text("Adicionar Veículo"), style: ElevatedButton.styleFrom( backgroundColor: accentColor, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), ), ) ], ) ), ).animate().fadeIn(); }
          final vehicleDocs = snapshot.data!.docs;
          // <<< CORRIGIDO: Retorna ListView >>>
          return ListView.separated(
             shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: vehicleDocs.length,
             separatorBuilder: (context, index) => const SizedBox(height: 8),
             itemBuilder: (ctx, index) {
                final vehicleData = vehicleDocs[index].data() as Map<String, dynamic>; final vehicleId = vehicleDocs[index].id; final vehicleType = vehicleTypeFromString(vehicleData['type']); final isSelected = vehicleId == _selectedVehicleIdForTrip;
                // <<< CORRIGIDO: Retorna Card >>>
                return Card( margin: EdgeInsets.zero, elevation: isSelected ? 6 : 2, color: cardColor, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12), side: BorderSide( color: isSelected ? selectedBorderColor : normalBorderColor, width: isSelected ? 2.0 : 0.8, ) ), child: InkWell( onTap: () => _handleVehicleSelection(vehicleId, vehicleType), borderRadius: BorderRadius.circular(12), splashColor: accentColor.withOpacity(0.2), highlightColor: accentColor.withOpacity(0.1), child: Padding( padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0), child: ListTile( dense: true, contentPadding: EdgeInsets.zero, leading: Icon( vehicleType?.icon ?? Icons.help_outline, color: isSelected ? accentColor : (vehicleType?.displayColor ?? iconColor), size: 28, ), title: Text( '${vehicleData['make'] ?? '?'} ${vehicleData['model'] ?? '?'}', style: TextStyle( fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 15, color: titleColor ) ), subtitle: Text( '${vehicleData['year'] ?? '?'} - ${vehicleData['licensePlate'] ?? 'Sem placa'}\nTipo: ${vehicleType?.displayName ?? vehicleData['type'] ?? '?'}', style: TextStyle(color: subtitleColor, fontSize: 12.5, height: 1.3) ), trailing: isSelected ? Icon(Icons.check_circle, color: selectedBorderColor, size: 22) : Icon(Icons.radio_button_unchecked, color: subtitleColor.withOpacity(0.5), size: 20), ), ), ), ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1); }, ); }, );
  }

  // --- Botões de Navegação Rápida ---
  // <<< CORRIGIDO: Adicionado RETURN >>>
  Widget _buildNavigationButtons() {
     final buttonColor = Colors.grey[800]; const iconColor = Colors.white70; const textColor = Colors.white70;
     // <<< CORRIGIDO: Retorna Padding >>>
     return Padding( padding: const EdgeInsets.only(top: 16.0),
       child: Wrap( spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            ElevatedButton.icon( style: ElevatedButton.styleFrom( backgroundColor: buttonColor, foregroundColor: textColor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) ), icon: const Icon(Icons.history, size: 18, color: iconColor), label: const Text('Histórico', style: TextStyle(fontSize: 13)), onPressed: _navigateToTripHistory),
            ElevatedButton.icon( style: ElevatedButton.styleFrom( backgroundColor: buttonColor, foregroundColor: textColor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) ), icon: const Icon(Icons.account_balance_wallet, size: 18, color: iconColor), label: const Text('Carteira', style: TextStyle(fontSize: 13)), onPressed: () {/*TODO: Navegar Carteira*/}),
            ElevatedButton.icon( style: ElevatedButton.styleFrom( backgroundColor: buttonColor, foregroundColor: textColor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) ), icon: const Icon(Icons.store, size: 18, color: iconColor), label: const Text('Mercado', style: TextStyle(fontSize: 13)), onPressed: () {/*TODO: Navegar Mercado*/}),
          ], ).animate().fadeIn(delay: 800.ms), );
  }


  // --- Helper para Conteúdo Rolável DENTRO de CADA Aba ---
  // <<< CORRIGIDO: Adicionado RETURN >>>
  Widget _buildScrollableTabContent(Widget tabSpecificContent) {
     final theme = Theme.of(context); final primaryColor = Colors.cyanAccent[400]!; final subtleTextColor = Colors.white.withOpacity(0.6); final user = _currentUser; if (user == null) return const Center(child: Text("Erro: Usuário não encontrado.")); final String userId = user.uid;
     // <<< CORRIGIDO: Retorna ListView >>>
     return ListView( primary: false, padding: const EdgeInsets.fromLTRB(16.0, 20, 16.0, 80.0), children: [
           const AdBannerPlaceholder(), const SizedBox(height: 20),
           _buildIndicatorsSection(userId), const SizedBox(height: 10),
           _buildProgressBarSection(),
           Divider(height: 30, thickness: 0.5, color: Colors.grey[800]),
           tabSpecificContent, const SizedBox(height: 30),
           _buildVehicleSectionHeader(theme, primaryColor), const SizedBox(height: 16),
           _buildVehicleList(userId, theme, primaryColor, subtleTextColor), const SizedBox(height: 30),
           Text('Desempenho Recente', style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.9))), const SizedBox(height: 16),
           TripChartPlaceholder(primaryColor: primaryColor).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2), const SizedBox(height: 30),
           _buildNavigationButtons(), const SizedBox(height: 20), ], );
  }

  // =====================================================================
  // ***** BUILD PRINCIPAL DO SCAFFOLD (Usando NestedScrollView) *****
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    final user = _currentUser; final theme = Theme.of(context); final userProvider = Provider.of<UserProvider>(context, listen: false); final displayName = userProvider.userName?.isNotEmpty == true ? userProvider.userName! : user?.email?.split('@')[0] ?? 'Usuário'; if (user == null) { return const Scaffold( body: Center( child: CircularProgressIndicator(color: Colors.cyanAccent))); } final Color accentColor = Colors.cyanAccent[400]!;
    // <<< CORRIGIDO: Retorna DefaultTabController >>>
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            // <<< CORRIGIDO: Retorna Lista de Slivers >>>
            return <Widget>[
              SliverAppBar( elevation: 1.0, backgroundColor: theme.scaffoldBackgroundColor, pinned: true, floating: true, expandedHeight: 150.0, collapsedHeight: kToolbarHeight + 48, // Altura Toolbar + TabBar
                flexibleSpace: FlexibleSpaceBar( collapseMode: CollapseMode.pin, background: SafeArea( child: Padding( padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 10.0, bottom: 50), child: Column( mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [ Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text('B2Y Carbon Cockpit', style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white.withOpacity(0.95))), IconButton(icon: Icon(Icons.power_settings_new_rounded, color: accentColor), tooltip: 'Sair', onPressed: _logout) ], ), const SizedBox(height: 4), Text( 'Olá, $displayName!', style: GoogleFonts.poppins(textStyle: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.8))) ), ], ), ), ), ),
                bottom: TabBar( controller: _tabController, indicatorColor: accentColor, indicatorWeight: 3.0, labelColor: accentColor, unselectedLabelColor: Colors.grey[600], labelStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13), unselectedLabelStyle: GoogleFonts.rajdhani(fontSize: 13), tabs: const [ Tab(text: 'MONITORAR'), Tab(text: 'CALCULAR'), ], ), ),
              SliverToBoxAdapter(child: _buildActionButtons()),
              SliverToBoxAdapter(child: Divider(height: 1, thickness: 0.5, color: Colors.grey[800], indent: 16, endIndent: 16)),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildScrollableTabContent( _buildGpsTrackingTabContent(theme, Colors.grey[500]!, accentColor) ),
              _buildScrollableTabContent( const TripCalculatorWidget() ),
            ],
          ),
        ),
      ),
    );
  }
} // Fim State