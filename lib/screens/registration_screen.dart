// lib/screens/registration_screen.dart (VERSÃO MODERNIZADA)
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

  // Novos controladores e variáveis de estado
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();

  List<String> _makes = [];
  List<Map<String, dynamic>> _models = [];

  bool _isFetchingMakes = true;
  bool _isFetchingModels = false;
  
  String? _selectedMake;
  String? _selectedModelId;
  Map<String, dynamic>? _selectedModelData;

  // Estilos (mantidos do seu código original)
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
    _fetchMakes();
  }

  @override
  void dispose() {
    _yearController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  // NOVA FUNÇÃO: Busca todas as marcas únicas do Firestore
  Future<void> _fetchMakes() async {
    setState(() => _isFetchingMakes = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('vehicle_models').get();
      final makes = snapshot.docs.map((doc) => doc.data()['make'] as String).toSet().toList();
      makes.sort(); // Opcional: ordenar alfabeticamente
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

  // NOVA FUNÇÃO: Busca modelos para uma marca específica
  Future<void> _fetchModelsForMake(String make) async {
    setState(() {
      _isFetchingModels = true;
      _models = []; // Limpa a lista de modelos anterior
    });
    try {
      final snapshot = await FirebaseFirestore.instance.collection('vehicle_models').where('make', isEqualTo: make).get();
      final models = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Adiciona o ID do documento ao mapa
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

  // FUNÇÃO ATUALIZADA: Lida com a seleção de marca
  Future<void> _selectMake() async {
    FocusScope.of(context).unfocus();
    final String? make = await _showSelectionDialog(
      title: 'Selecione a Marca',
      items: _makes,
      currentSelection: _selectedMake,
    );
    if (make != null && make != _selectedMake) {
      setState(() {
        _selectedMake = make;
        _selectedModelId = null; // Reseta a seleção do modelo
        _selectedModelData = null;
      });
      // Busca os novos modelos para a marca selecionada
      _fetchModelsForMake(make);
    }
  }

  // FUNÇÃO ATUALIZADA: Lida com a seleção de modelo
  Future<void> _selectModel() async {
    if (_selectedMake == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma marca primeiro.'), backgroundColor: Colors.orangeAccent));
      return;
    }
    FocusScope.of(context).unfocus();
    
    // Constrói a lista de nomes de modelo a partir dos dados já buscados
    final modelNames = _models.map((m) => m['model'] as String).toList();
    
    final String? selectedModelName = await _showSelectionDialog(
      title: 'Selecione o Modelo',
      items: modelNames,
      currentSelection: _selectedModelData?['model'],
    );

    if (selectedModelName != null) {
      // Encontra o documento completo do modelo selecionado
      final selectedModel = _models.firstWhere((m) => m['model'] == selectedModelName);
      setState(() {
        _selectedModelId = selectedModel['id'];
        _selectedModelData = selectedModel;
      });
    }
  }
  
  // FUNÇÃO ATUALIZADA: Salva o veículo no formato correto
  void _submitForm() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_selectedModelId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione Marca e Modelo.'), backgroundColor: Colors.orangeAccent));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado.');

      final vehicleData = {
        'userId': user.uid,
        'modelId': _selectedModelId, // SALVANDO O ID DO MODELO
        'year': int.tryParse(_yearController.text) ?? 0,
        'licensePlate': _plateController.text.trim().toUpperCase(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance.collection('vehicles').add(vehicleData); 

      if (mounted) {
        final make = _selectedModelData?['make'] ?? '';
        final model = _selectedModelData?['model'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$make $model registrado!'),
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

  // FUNÇÃO DE DIÁLOGO ATUALIZADA para mostrar um spinner de loading
  Future<String?> _showSelectionDialog({
    required String title,
    required List<String> items,
    String? currentSelection,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(title, style: GoogleFonts.orbitron(color: primaryColor)),
          content: _isFetchingMakes || _isFetchingModels
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

  // Funções de build de UI (mantidas e adaptadas)
  InputDecoration _inputDecoration({required String labelText, required IconData prefixIcon}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.poppins(textStyle: const TextStyle(color: labelColor, fontSize: 14)),
      prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Icon(prefixIcon, color: iconColor.withOpacity(0.8), size: 20)),
      filled: true,
      fillColor: inputFillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: inputBorderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: inputBorderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: secondaryColor, width: 1.5)),
    );
  }

  Widget _buildSelectionRow({
    required String label,
    String? value,
    VoidCallback? onPressed,
    required String selectText,
    String? placeholder,
  }) {
    return InputDecorator(
      decoration: _inputDecoration(labelText: label, prefixIcon: Icons.category_outlined),
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
            Icon(Icons.search, size: 20, color: primaryColor)
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registrar Novo Veículo', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[900],
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
                  Text('Informe os dados do veículo', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 30),
                  
                  _buildSelectionRow(
                    label: 'Marca*',
                    value: _selectedMake,
                    onPressed: _isLoading ? null : _selectMake,
                    selectText: 'Selecionar',
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 15),

                  _buildSelectionRow(
                    label: 'Modelo*',
                    value: _selectedModelData?['model'],
                    onPressed: _isLoading || _selectedMake == null ? null : _selectModel,
                    selectText: 'Selecionar',
                    placeholder: _selectedMake == null ? 'Selecione a marca primeiro' : 'Selecione o modelo',
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: _yearController,
                    enabled: !_isLoading,
                    decoration: _inputDecoration(labelText: 'Ano*', prefixIcon: Icons.calendar_month_outlined),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obrigatório';
                      if (v.length != 4) return 'Ano inválido';
                      final yr = int.tryParse(v);
                      if (yr == null || yr < 1950 || yr > DateTime.now().year + 1) return 'Ano inválido';
                      return null;
                    },
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 15),
                  
                  TextFormField(
                    controller: _plateController,
                    enabled: !_isLoading,
                    decoration: _inputDecoration(labelText: 'Placa*', prefixIcon: Icons.badge_outlined),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 7,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Placa é obrigatória';
                      if (v.trim().length < 7) return 'Placa deve ter 7 caracteres';
                      return null;
                    },
                  ).animate().fadeIn(delay: 400.ms),
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