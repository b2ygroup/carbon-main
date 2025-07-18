// lib/screens/registration_screen.dart (VERSÃO CORRIGIDA E COMPLETA COM TIPO DE VEÍCULO)
import 'package:carbon/models/vehicle_type_enum.dart'; // <<< NOVO: Importação necessária
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controladores do formulário
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();

  // Variáveis de estado para os seletores
  VehicleType? _selectedVehicleType; // <<< NOVO
  String? _selectedMake;
  String? _selectedModelId;
  Map<String, dynamic>? _selectedModelData;
  
  List<String> _makes = [];
  List<Map<String, dynamic>> _models = [];

  bool _isFetchingMakes = false; // <<< ALTERADO: não inicia mais em true
  bool _isFetchingModels = false;
  

  // Paleta de cores da UI
  static const Color primaryColor = Color(0xFF00BFFF);
  static const Color secondaryColor = Color(0xFF00FFFF);
  static const Color errorColor = Color(0xFFFF8A80);
  static const Color inputFillColor = Color(0x0DFFFFFF);
  static const Color inputBorderColor = Color(0xFF616161);
  static const Color labelColor = Color(0xFFBDBDBD);
  static const Color textColor = Colors.white;
  static const Color iconColor = primaryColor;

  @override
  void initState() {
    super.initState();
    // Não busca mais as marcas aqui. A busca dependerá do tipo.
  }

  @override
  void dispose() {
    _yearController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  /// <<< NOVO: Busca as marcas correspondentes a um TIPO de veículo.
  Future<void> _fetchMakesForType(VehicleType type) async {
    setState(() {
      _isFetchingMakes = true;
      _makes = [];
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vehicle_models')
          .where('type', isEqualTo: type.name) // Filtra pelo tipo
          .get();
          
      final makes = snapshot.docs.map((doc) => doc.data()['make'] as String).toSet().toList();
      makes.sort();
      setState(() {
        _makes = makes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao buscar marcas: $e"), backgroundColor: errorColor));
      }
    } finally {
      if(mounted) setState(() => _isFetchingMakes = false);
    }
  }

  /// <<< ALTERADO: Busca os modelos filtrando também pelo tipo para segurança.
  Future<void> _fetchModelsForMake(String make) async {
    if (_selectedVehicleType == null) return;

    setState(() {
      _isFetchingModels = true;
      _models = [];
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vehicle_models')
          .where('type', isEqualTo: _selectedVehicleType!.name) // Garante o filtro de tipo
          .where('make', isEqualTo: make) // E o filtro de marca
          .get();

      final models = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _models = models;
      });
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao buscar modelos: $e"), backgroundColor: errorColor));
      }
    } finally {
      if(mounted) setState(() => _isFetchingModels = false);
    }
  }

  /// <<< NOVO: Exibe um diálogo para o usuário selecionar o TIPO do veículo.
  Future<void> _selectVehicleType() async {
    FocusScope.of(context).unfocus();
    final VehicleType? type = await showDialog<VehicleType>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Selecione o Tipo', style: GoogleFonts.orbitron(color: primaryColor)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: VehicleType.values.length,
              itemBuilder: (context, index) {
                final item = VehicleType.values[index];
                return RadioListTile<VehicleType>(
                  title: Text(item.displayName, style: GoogleFonts.poppins(color: textColor)),
                  value: item,
                  groupValue: _selectedVehicleType,
                  onChanged: (VehicleType? value) => Navigator.of(context).pop(value),
                  activeColor: secondaryColor,
                );
              },
            ),
          ),
           actions: <Widget>[
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: labelColor)),
              onPressed: () => Navigator.of(context).pop(null),
            ),
          ],
        );
      }
    );
    
    if (type != null && type != _selectedVehicleType) {
      setState(() {
        _selectedVehicleType = type;
        // Reseta as seleções subsequentes
        _selectedMake = null;
        _selectedModelId = null; 
        _selectedModelData = null;
      });
      _fetchMakesForType(type);
    }
  }


  /// Exibe um diálogo para o usuário selecionar a marca.
  Future<void> _selectMake() async {
    if (_selectedVehicleType == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um tipo de veículo primeiro.'), backgroundColor: Colors.orangeAccent));
      return;
    }
    FocusScope.of(context).unfocus();
    final String? make = await _showSelectionDialog(
      title: 'Selecione a Marca',
      items: _makes,
      currentSelection: _selectedMake,
      isLoading: _isFetchingMakes,
    );
    if (make != null && make != _selectedMake) {
      setState(() {
        _selectedMake = make;
        _selectedModelId = null; // Reseta a seleção do modelo
        _selectedModelData = null;
      });
      _fetchModelsForMake(make);
    }
  }

  /// Exibe um diálogo para o usuário selecionar o modelo.
  Future<void> _selectModel() async {
    if (_selectedMake == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma marca primeiro.'), backgroundColor: Colors.orangeAccent));
      return;
    }
    FocusScope.of(context).unfocus();
    
    final modelNames = _models.map((m) => "${m['model']} (${m['year']})").toList();
    
    final String? selectedModelName = await _showSelectionDialog(
      title: 'Selecione o Modelo',
      items: modelNames,
      currentSelection: _selectedModelData != null ? "${_selectedModelData?['model']} (${_selectedModelData?['year']})" : null,
      isLoading: _isFetchingModels
    );

    if (selectedModelName != null) {
      final selectedModel = _models.firstWhere((m) => "${m['model']} (${m['year']})" == selectedModelName);
      setState(() {
        _selectedModelId = selectedModel['id'];
        _selectedModelData = selectedModel;
        // Preenche o ano automaticamente com base no modelo, mas permite edição.
        _yearController.text = selectedModel['year']?.toString() ?? '';
      });
    }
  }
  
  /// Valida o formulário e salva os dados do veículo na coleção 'vehicles'.
  void _submitForm() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_selectedModelId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione Tipo, Marca e Modelo.'), backgroundColor: Colors.orangeAccent));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado.');

      final vehicleData = {
        'userId': user.uid,
        'modelId': _selectedModelId,
        'licensePlate': _plateController.text.trim().toUpperCase(),
        'year': int.parse(_yearController.text.trim()),
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance.collection('vehicles').add(vehicleData); 

      if (mounted) {
        final make = _selectedModelData?['make'] ?? '';
        final model = _selectedModelData?['model'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$make $model ${_yearController.text} registrado!'),
            backgroundColor: Colors.green));
        Navigator.of(context).pop(); 
      }
    } catch (error) { 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao salvar veículo: ${error.toString()}'),
            backgroundColor: errorColor));
      }
    } finally { 
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  /// Widget genérico para exibir um diálogo de seleção com uma lista de itens.
  Future<String?> _showSelectionDialog({
    required String title,
    required List<String> items,
    String? currentSelection,
    bool isLoading = false,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(title, style: GoogleFonts.orbitron(color: primaryColor)),
          content: isLoading
            ? const SizedBox(height: 100, child: Center(child: SpinKitFadingCircle(color: secondaryColor, size: 40.0)))
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int index) {
                    final item = items[index];
                    return RadioListTile<String>(
                      title: Text(item, style: GoogleFonts.poppins(color: textColor)),
                      value: item,
                      groupValue: currentSelection,
                      onChanged: (String? value) => Navigator.of(context).pop(value),
                      activeColor: secondaryColor,
                    );
                  },
                ),
              ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: labelColor)),
              onPressed: () => Navigator.of(context).pop(null),
            ),
          ],
        );
      },
    );
  }

  // --- Widgets de Construção da UI ---

  InputDecoration _inputDecoration({required String labelText, required IconData prefixIcon}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.poppins(textStyle: const TextStyle(color: labelColor, fontSize: 14)),
      prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Icon(prefixIcon, color: iconColor.withOpacity(0.8), size: 20)),
      filled: true,
      fillColor: inputFillColor,
      counterText: "",
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: inputBorderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: inputBorderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: secondaryColor, width: 1.5)),
    );
  }

  Widget _buildSelectionRow({
    required String label,
    required IconData icon, // <<< NOVO: ícone customizável
    String? value,
    VoidCallback? onPressed,
    String? placeholder,
  }) {
    return InputDecorator(
      decoration: _inputDecoration(labelText: label, prefixIcon: icon),
      child: GestureDetector(
        onTap: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value ?? placeholder ?? 'Não selecionado',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(textStyle: TextStyle(
                  color: value != null ? textColor : labelColor.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
                )),
              )
            ),
            const Icon(Icons.search, size: 20, color: primaryColor)
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('Registrar Novo Veículo', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Informe os dados do veículo', textAlign: TextAlign.center, style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 20)),
                  const SizedBox(height: 30),
                  
                  // <<< NOVO: Seletor de Tipo de Veículo
                  _buildSelectionRow(
                    label: 'Tipo de Veículo*',
                    icon: _selectedVehicleType?.icon ?? Icons.category_outlined,
                    value: _selectedVehicleType?.displayName,
                    onPressed: _isLoading ? null : _selectVehicleType,
                    placeholder: 'Selecione o tipo',
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 15),

                  // <<< ALTERADO: Seletor de Marca
                  _buildSelectionRow(
                    label: 'Marca*',
                    icon: Icons.factory_outlined,
                    value: _selectedMake,
                    onPressed: _isLoading || _selectedVehicleType == null ? null : _selectMake,
                    placeholder: _selectedVehicleType == null ? 'Selecione o tipo primeiro' : 'Selecione a marca',
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 15),

                  // <<< ALTERADO: Seletor de Modelo
                  _buildSelectionRow(
                    label: 'Modelo*',
                    icon: Icons.directions_car_filled_outlined,
                    value: _selectedModelData != null ? "${_selectedModelData?['model']} (${_selectedModelData?['year']})" : null,
                    onPressed: _isLoading || _selectedMake == null ? null : _selectModel,
                    placeholder: _selectedMake == null ? 'Selecione a marca primeiro' : 'Selecione o modelo',
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: _yearController,
                    enabled: !_isLoading,
                    style: const TextStyle(color: textColor),
                    decoration: _inputDecoration(labelText: 'Ano*', prefixIcon: Icons.calendar_today_outlined),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obrigatório';
                      if (v.length != 4) return 'Ano inválido';
                      final yr = int.tryParse(v);
                      if (yr == null || yr < 1950 || yr > DateTime.now().year + 1) return 'Ano inválido';
                      return null;
                    },
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 15),
                  
                  TextFormField(
                    controller: _plateController,
                    enabled: !_isLoading,
                    style: const TextStyle(color: textColor),
                    decoration: _inputDecoration(labelText: 'Placa*', prefixIcon: Icons.badge_outlined),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 7,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Placa é obrigatória';
                      if (v.trim().length < 7) return 'Placa deve ter 7 caracteres';
                      return null;
                    },
                  ).animate().fadeIn(delay: 500.ms),
                  const SizedBox(height: 40),

                  _isLoading
                      ? const Center(child: SpinKitWave(color: primaryColor, size: 30.0))
                      : ElevatedButton.icon(
                          onPressed: _submitForm,
                          icon: const Icon(Icons.save_alt_rounded),
                          label: const Text('Salvar Veículo'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold))
                        ).animate().fadeIn(delay: 600.ms).scale(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}