// lib/screens/reports_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Uma classe simples para facilitar o manuseio dos dados da viagem
class TripReportData {
  final DateTime date;
  final double co2SavedKg;

  TripReportData({required this.date, required this.co2SavedKg});

  factory TripReportData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TripReportData(
      date: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      co2SavedKg: (data['co2SavedKg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  Map<String, double> _monthlyCo2Saved = {};

  @override
  void initState() {
    super.initState();
    _fetchTripData();
  }

  Future<void> _fetchTripData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('userId', isEqualTo: user.uid)
          .where('co2SavedKg', isGreaterThan: 0)
          .orderBy('co2SavedKg')
          .orderBy('endTime', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      final trips = snapshot.docs.map((doc) => TripReportData.fromFirestore(doc)).toList();
      _processDataForChart(trips);

    } catch (e) {
      debugPrint("Erro ao buscar dados para relatório: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _processDataForChart(List<TripReportData> trips) {
    final Map<String, double> data = {};
    
    for (final trip in trips) {
      final monthKey = DateFormat('MM/yy', 'pt_BR').format(trip.date);
      data.update(monthKey, (value) => value + trip.co2SavedKg, ifAbsent: () => trip.co2SavedKg);
    }
    
    var sortedEntries = data.entries.toList()
      ..sort((a, b) {
        try {
          final aParts = a.key.split('/');
          final bParts = b.key.split('/');
          final aDate = DateTime(int.parse('20${aParts[1]}'), int.parse(aParts[0]));
          final bDate = DateTime(int.parse('20${bParts[1]}'), int.parse(bParts[0]));
          return aDate.compareTo(bDate);
        } catch (e) {
          return 0;
        }
      });

    if (mounted) {
      setState(() {
        _monthlyCo2Saved = Map.fromEntries(sortedEntries);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Meus Relatórios',
          style: GoogleFonts.orbitron(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Visão Geral do seu Impacto',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Acompanhe sua evolução em sustentabilidade e ganhos ao longo do tempo.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),

          Text(
            'CO₂ Sequestrado por Mês (kg)',
            style: GoogleFonts.orbitron(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(200),
            ),
          ),
          const SizedBox(height: 16),
          
          _buildChartContainer(),
        ],
      ),
    );
  }

  Widget _buildChartContainer() {
    if (_isLoading) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_monthlyCo2Saved.isEmpty) {
      return Card(
        color: Colors.grey[850],
        child: const SizedBox(
          height: 250,
          child: Center(
            child: Text(
              'Nenhuma viagem sustentável encontrada para gerar o relatório.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      );
    }

    return Card(
      color: const Color(0xFF2c2c2e),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.blueGrey, // <<< PARÂMETRO CORRIGIDO
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final value = rod.toY;
                    return BarTooltipItem(
                      '${value.toStringAsFixed(2)} kg',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < _monthlyCo2Saved.keys.length) {
                        final monthKey = _monthlyCo2Saved.keys.elementAt(index);
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4.0,
                          child: Text(monthKey, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value == meta.max) return const Text('');
                      return Text('${value.toInt()}kg', style: const TextStyle(color: Colors.white70, fontSize: 10));
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return const FlLine(color: Colors.white12, strokeWidth: 1);
                },
              ),
              barGroups: _monthlyCo2Saved.entries.toList().asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: data.value,
                      color: Colors.greenAccent[400],
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}