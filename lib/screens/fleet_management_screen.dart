// CRIE ESTE NOVO ARQUIVO: lib/screens/fleet_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carbon/models/vehicle_type_enum.dart';
// Para a funcionalidade de "Editar", você precisará importar sua tela de registro:
// import 'package:carbon/screens/registration_screen.dart'; 

class FleetManagementScreen extends StatefulWidget {
  const FleetManagementScreen({super.key});

  @override
  State<FleetManagementScreen> createState() => _FleetManagementScreenState();
}

class _FleetManagementScreenState extends State<FleetManagementScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _deleteVehicle(String vehicleId) async {
    if (_currentUser == null) return;

    // Diálogo de confirmação para evitar exclusão acidental
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2c2c2e),
          title: const Text('Confirmar Exclusão', style: TextStyle(color: Colors.white)),
          content: const Text('Tem certeza de que deseja excluir este veículo? Esta ação não pode ser desfeita.', style: TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('EXCLUIR'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('vehicles').doc(vehicleId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veículo excluído com sucesso.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir veículo: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // void _editVehicle(String vehicleId, Map<String, dynamic> vehicleData) {
  //   // AQUI VOCÊ NAVEGARIA PARA A TELA DE REGISTRO EM MODO DE EDIÇÃO
  //   // Exemplo:
  //   // Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => RegistrationScreen(vehicleId: vehicleId, initialData: vehicleData)));
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('Funcionalidade de edição a ser implementada.')),
  //   );
  // }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = Colors.cyanAccent[400]!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Gestão de Frota', style: GoogleFonts.orbitron()),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
      ),
      body: _currentUser == null
          ? const Center(child: Text('Usuário não logado.', style: TextStyle(color: Colors.white70)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('vehicles')
                  .where('userId', isEqualTo: _currentUser.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: accentColor));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar veículos: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum veículo cadastrado.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  );
                }

                final vehicleDocs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12.0),
                  itemCount: vehicleDocs.length,
                  itemBuilder: (context, index) {
                    final vehicleDoc = vehicleDocs[index];
                    final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
                    final vehicleType = vehicleTypeFromString(vehicleData['type']);
                    
                    return Card(
                      color: Colors.grey[850]?.withAlpha(200),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[700]!, width: 0.8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(vehicleType?.icon ?? Icons.directions_car, color: vehicleType?.displayColor ?? Colors.white70, size: 36),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${vehicleData['make'] ?? 'Marca'} ${vehicleData['model'] ?? 'Modelo'}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Placa: ${vehicleData['licensePlate'] ?? 'N/A'} - Ano: ${vehicleData['year'] ?? 'N/A'}',
                                        style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: Colors.grey[700]),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // TextButton.icon(
                                //   icon: const Icon(Icons.edit, size: 18),
                                //   label: const Text('Editar'),
                                //   style: TextButton.styleFrom(foregroundColor: accentColor),
                                //   onPressed: () => _editVehicle(vehicleDoc.id, vehicleData),
                                // ),
                                // const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  label: const Text('Excluir'),
                                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent[100]),
                                  onPressed: () => _deleteVehicle(vehicleDoc.id),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}