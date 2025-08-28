// lib/screens/signup/widgets/vehicle_form_widget.dart (NOVO ARQUIVO)

import 'package:carbon/screens/dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';

class VehicleFormWidget extends StatefulWidget {
  final String userId;
  final String accountType; // 'PF' ou 'PJ'
  final VoidCallback? onPreviousPage; // Para o fluxo PF

  const VehicleFormWidget({
    super.key,
    required this.userId,
    required this.accountType,
    this.onPreviousPage,
  });

  @override
  State<VehicleFormWidget> createState() => _VehicleFormWidgetState();
}

class _VehicleFormWidgetState extends State<VehicleFormWidget> {
  final _vehicleDataFormKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String? _selectedCategory;
  String? _selectedFuel;
  String? _selectedMake;
  String? _selectedModelId;
  Map<String, dynamic>? _selectedModelData;
  final _plateController = TextEditingController();
  final _nicknameController = TextEditingController();
  List<String> _makes = [];
  List<Map<String, dynamic>> _models = [];
  bool _isFetchingMakes = false;
  bool _isFetchingModels = false;
  
  final List<String> _vehicleCategories = ['Carro', 'Moto', 'Onibus', 'Caminhao'];
  final Map<String, String> _fuelTypes = {
    'gasoline': 'Gasolina', 'alcohol': 'Etanol (Álcool)', 'diesel': 'Diesel',
    'flex': 'Flex', 'electric': 'Elétrico', 'gnv': 'GNV',
  };

  static const Color primaryColor = Color(0xFF00BFFF);
  static const Color secondaryColor = Color(0xFF00FFFF);
  static final Color errorColor = Colors.redAccent[100]!;
  static final Color labelColor = Colors.grey[400]!;
  static const Color textColor = Colors.white;

  @override
  void dispose() {
    _plateController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _fetchMakes() async {
    if (_selectedCategory == null || _selectedFuel == null) return;
    setState(() { _isFetchingMakes = true; _makes = []; _selectedMake = null; _models = []; _selectedModelId = null; });
    try {
      final snapshot = await FirebaseFirestore.instance.collection('vehicle_models')
        .where('category', isEqualTo: _selectedCategory)
        .where('fuel', isEqualTo: _selectedFuel)
        .get();
      
      final makes = snapshot.docs.map((doc) => doc.data()['make'] as String).toSet().toList();
      makes.sort();
      
      if (mounted) {
        setState(() => _makes = makes);
        if (makes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhuma marca encontrada para esta combinação.'), backgroundColor: Colors.orangeAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao buscar marcas: $e"), backgroundColor: errorColor));
    } finally {
      if (mounted) setState(() => _isFetchingMakes = false);
    }
  }

  Future<void> _fetchModels() async {
    if (_selectedCategory == null || _selectedFuel == null || _selectedMake == null) return;
    setState(() { _isFetchingModels = true; _models = []; _selectedModelId = null; });
    try {
      final snapshot = await FirebaseFirestore.instance.collection('vehicle_models')
          .where('category', isEqualTo: _selectedCategory)
          .where('fuel', isEqualTo: _selectedFuel)
          .where('make', isEqualTo: _selectedMake).orderBy('model').get();
      final models = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      if (mounted) setState(() => _models = models);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao buscar modelos: $e"), backgroundColor: errorColor));
    } finally {
      if (mounted) setState(() => _isFetchingModels = false);
    }
  }

  Future<void> _submitVehicleForm() async {
    final isVehicleDataValid = _vehicleDataFormKey.currentState?.validate() ?? false;
    if (!isVehicleDataValid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Verifique os dados do veículo.'), backgroundColor: errorColor));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final vehicleData = {
        'userId': widget.userId, 'modelId': _selectedModelId,
        'licensePlate': _plateController.text.trim().toUpperCase(),
        'nickname': _nicknameController.text.trim().isNotEmpty ? _nicknameController.text.trim() : null,
        'year': _selectedModelData!['year'], 'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('vehicles').add(vehicleData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veículo cadastrado com sucesso! Bem-vindo(a)!'), backgroundColor: Colors.green));
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const DashboardScreen()), (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar veículo: ${e.toString()}'), backgroundColor: errorColor));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration({ required String labelText, required IconData prefixIcon, Widget? suffixIconWidget}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.poppins(textStyle: TextStyle(color: labelColor, fontSize: 14)),
      prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Icon(prefixIcon, color: primaryColor.withAlpha(204), size: 20)),
      suffixIcon: suffixIconWidget,
      filled: true,
      fillColor: Colors.white.withAlpha(13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey[800]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey[800]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: secondaryColor, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: errorColor)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: errorColor, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _vehicleDataFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.accountType == 'PJ' 
                ? 'Agora, cadastre o primeiro veículo da frota' 
                : 'Informe os dados do seu veículo principal', 
              textAlign: TextAlign.center, 
              style: const TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.w600)
            ),
            const SizedBox(height: 30),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text('Selecione a Categoria *'),
              style: const TextStyle(color: textColor),
              dropdownColor: Colors.grey[850],
              decoration: _inputDecoration(labelText: 'Categoria*', prefixIcon: Icons.category),
              items: _vehicleCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                  _selectedFuel = null; _selectedMake = null; _selectedModelId = null;
                  _makes = []; _models = [];
                });
              },
              validator: (v) => v == null ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedFuel,
              hint: const Text('Selecione o Combustível *'),
              style: const TextStyle(color: textColor),
              dropdownColor: Colors.grey[850],
              decoration: _inputDecoration(labelText: 'Combustível*', prefixIcon: Icons.local_gas_station),
              items: _fuelTypes.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
              onChanged: _selectedCategory == null ? null : (value) {
                setState(() => _selectedFuel = value);
                if (value != null) _fetchMakes();
              },
              validator: (v) => v == null ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedMake,
              hint: Text(_isFetchingMakes 
                ? 'A carregar...' 
                : (_selectedFuel == null 
                    ? 'Selecione o combustível' 
                    : (_makes.isEmpty ? 'Nenhuma marca encontrada' : 'Selecione a Marca *'))
              ),
              style: const TextStyle(color: textColor),
              dropdownColor: Colors.grey[850],
              decoration: _inputDecoration(labelText: 'Marca*', prefixIcon: Icons.factory),
              items: _makes.map((make) => DropdownMenuItem(value: make, child: Text(make))).toList(),
              onChanged: _makes.isEmpty ? null : (value) {
                setState(() {
                  _selectedMake = value;
                  _selectedModelId = null;
                  _models = [];
                });
                if(value != null) _fetchModels();
              },
              validator: (v) => v == null ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedModelId,
              hint: _isFetchingModels 
                ? const Text('A carregar...') 
                : (_selectedMake == null 
                    ? const Text('Selecione a marca primeiro') 
                    : const Text('Selecione o Modelo *')),
              style: const TextStyle(color: textColor),
              dropdownColor: Colors.grey[850],
              isExpanded: true,
              decoration: _inputDecoration(labelText: 'Modelo*', prefixIcon: Icons.directions_car),
              items: _models.map<DropdownMenuItem<String>>((model) {
                return DropdownMenuItem<String>(
                  value: model['id'],
                  child: Text("${model['model']} (${model['year']})", overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: _models.isEmpty ? null : (value) {
                final selectedModel = _models.firstWhere((m) => m['id'] == value, orElse: () => {});
                if (selectedModel.isNotEmpty) {
                    setState(() {
                    _selectedModelId = value;
                    _selectedModelData = selectedModel;
                  });
                }
              },
              validator: (v) => v == null ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 15),
            TextFormField(controller: _plateController, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Placa*', prefixIcon: Icons.badge_outlined), textCapitalization: TextCapitalization.characters, maxLength: 7, validator: (v) { if (v == null || v.trim().isEmpty) return 'Placa é obrigatória'; return null; }),
            const SizedBox(height: 15),
            TextFormField(controller: _nicknameController, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Apelido do Veículo (Opcional)', prefixIcon: Icons.label_important_outline)),
            const SizedBox(height: 40),
            _isLoading
                ? const Center(child: SpinKitWave(color: primaryColor, size: 30.0))
                : ElevatedButton.icon(
                    onPressed: _submitVehicleForm,
                    icon: const Icon(Icons.app_registration),
                    label: const Text('Concluir Cadastro'),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
          ],
        ),
      ),
    );
  }
}