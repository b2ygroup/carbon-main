// lib/widgets/trip_chart_placeholder.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Import fl_chart
import 'package:flutter_animate/flutter_animate.dart'; // Para .ms

class TripChartPlaceholder extends StatelessWidget {
  final Color primaryColor;
  const TripChartPlaceholder({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Card(
        // Usa elevação e shape do tema se disponíveis
        elevation: Theme.of(context).cardTheme.elevation ?? 4,
        shape: Theme.of(context).cardTheme.shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        clipBehavior: Clip.antiAlias, // Garante que o gradiente não vaze
        child: Container( // Container para aplicar gradiente ou cor sólida
          decoration: BoxDecoration(
             gradient: LinearGradient( // Gradiente sutil de fundo
               colors: [
                 Theme.of(context).cardTheme.color?.withOpacity(0.8) ?? Colors.grey[850]!.withOpacity(0.8),
                 Theme.of(context).cardTheme.color ?? Colors.grey[900]!,
               ],
               begin: Alignment.topLeft, end: Alignment.bottomRight,
             )
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    // Lista de pontos SEM const
                    spots: const [ FlSpot(0, 3), FlSpot(1, 1.5), FlSpot(2, 4), FlSpot(3, 2.5), FlSpot(4, 5), FlSpot(5, 3.5), FlSpot(6, 4.2) ],
                    isCurved: true,
                    color: primaryColor, // Usa a cor primária passada
                    barWidth: 3.5, // Linha um pouco mais grossa
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData( // Área preenchida abaixo da linha
                        show: true,
                        gradient: LinearGradient( // Gradiente na área
                           colors: [ primaryColor.withOpacity(0.3), primaryColor.withOpacity(0.0) ],
                           begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        )
                    ),
                  ),
                ],
                titlesData: const FlTitlesData(show: false), // Oculta eixos X e Y
                gridData: FlGridData( // Linhas de grade sutis
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 1,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine( color: Colors.white.withOpacity(0.05), strokeWidth: 1, ),
                  getDrawingVerticalLine: (value) => FlLine( color: Colors.white.withOpacity(0.05), strokeWidth: 1, ),
                ),
                borderData: FlBorderData(show: false), // Sem borda externa
                minY: 0, // Eixo Y começa em 0
              ),
              duration: 800.ms, // Animação suave
              curve: Curves.easeInOutCubic,
            ),
          ),
        ),
      ),
    );
  }
}