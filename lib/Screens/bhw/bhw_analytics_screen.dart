import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../features/bhw/providers/bhw_patient_provider.dart';
import '../../../data/models/bhw_patient_model.dart';

class BHWAnalyticsScreen extends StatefulWidget {
  const BHWAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<BHWAnalyticsScreen> createState() => _BHWAnalyticsScreenState();
}

class _BHWAnalyticsScreenState extends State<BHWAnalyticsScreen> {
  String _selectedPeriod = 'This Week'; // This Week, This Month, All Time

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B6B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Analytics & Reports',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Today',
                child: Text('Today'),
              ),
              const PopupMenuItem(
                value: 'This Week',
                child: Text('This Week'),
              ),
              const PopupMenuItem(
                value: 'This Month',
                child: Text('This Month'),
              ),
              const PopupMenuItem(
                value: 'All Time',
                child: Text('All Time'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<BHWPatientProvider>(
        builder: (context, provider, child) {
          final patients = _getFilteredPatients(provider);
          final stats = _calculateStats(patients);

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadPatientsFromHive();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period selector
                    _buildPeriodCard(),
                    const SizedBox(height: 20),

                    // Summary cards
                    _buildSummaryCards(stats),
                    const SizedBox(height: 20),

                    // Risk distribution chart
                    _buildRiskDistributionChart(stats),
                    const SizedBox(height: 20),

                    // Daily activity chart
                    _buildDailyActivityChart(patients),
                    const SizedBox(height: 20),

                    // Demographics breakdown
                    _buildDemographicsSection(patients),
                    const SizedBox(height: 20),

                    // Barangay breakdown
                    _buildBarangayBreakdown(patients),
                    const SizedBox(height: 20),

                    // Top concerns
                    _buildTopSymptomsSection(patients),
                    const SizedBox(height: 20),

                    // Performance metrics
                    _buildPerformanceMetrics(stats),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ========== PERIOD CARD ==========
  Widget _buildPeriodCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Showing Data For',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedPeriod,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_today,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  // ========== SUMMARY CARDS ==========
  Widget _buildSummaryCards(Map<String, dynamic> stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Scans',
                '${stats['totalScans']}',
                Icons.camera_alt,
                const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'High Risk',
                '${stats['highRisk']}',
                Icons.warning,
                const Color(0xFFEF5350),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Avg/Day',
                '${stats['avgPerDay']}',
                Icons.trending_up,
                const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Referrals',
                '${stats['referrals']}',
                Icons.local_hospital,
                const Color(0xFF9C27B0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ========== RISK DISTRIBUTION CHART ==========
  Widget _buildRiskDistributionChart(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Risk Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: stats['low'].toDouble(),
                          color: Colors.green,
                          title: '${stats['low']}',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: stats['moderate'].toDouble(),
                          color: Colors.orange,
                          title: '${stats['moderate']}',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: stats['high'].toDouble(),
                          color: Colors.red,
                          title: '${stats['high']}',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: stats['critical'].toDouble(),
                          color: Colors.red[900],
                          title: '${stats['critical']}',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem('Low', Colors.green, stats['low']),
                      _buildLegendItem(
                          'Moderate', Colors.orange, stats['moderate']),
                      _buildLegendItem('High', Colors.red, stats['high']),
                      _buildLegendItem(
                          'Critical', Colors.red[900]!, stats['critical']),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label ($value)',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ========== DAILY ACTIVITY CHART ==========
  Widget _buildDailyActivityChart(List<BHWPatient> patients) {
    final dailyData = _getDailyActivity(patients);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scan Activity (Last 7 Days)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: dailyData.values.isEmpty
                    ? 10
                    : dailyData.values
                            .reduce((a, b) => a > b ? a : b)
                            .toDouble() +
                        2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final dates = dailyData.keys.toList();
                        if (value.toInt() < dates.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM\nd').format(dates[value.toInt()]),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200],
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups:
                    dailyData.entries.toList().asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value.toDouble(),
                        color: const Color(0xFFFF6B6B),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== DEMOGRAPHICS SECTION ==========
  Widget _buildDemographicsSection(List<BHWPatient> patients) {
    final ageGroups = _getAgeGroups(patients);
    final genderDist = _getGenderDistribution(patients);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demographics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Gender distribution
          Row(
            children: [
              Expanded(
                child: _buildDemographicCard(
                  'Male',
                  genderDist['Male'] ?? 0,
                  Icons.male,
                  const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDemographicCard(
                  'Female',
                  genderDist['Female'] ?? 0,
                  Icons.female,
                  const Color(0xFFE91E63),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Age groups
          const Text(
            'Age Distribution',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...ageGroups.entries.map((entry) {
            final total = patients.length;
            final percentage =
                total > 0 ? (entry.value / total * 100).toInt() : 0;
            return _buildAgeGroupBar(entry.key, entry.value, percentage);
          }),
        ],
      ),
    );
  }

  Widget _buildDemographicCard(
      String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeGroupBar(String label, int value, int percentage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
              Text(
                '$value ($percentage%)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
  }

  // ========== BARANGAY BREAKDOWN ==========
  Widget _buildBarangayBreakdown(List<BHWPatient> patients) {
    final barangayData = <String, int>{};
    for (var patient in patients) {
      barangayData[patient.barangay] =
          (barangayData[patient.barangay] ?? 0) + 1;
    }

    final sortedBarangays = barangayData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scans by Barangay',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (sortedBarangays.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No data available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...sortedBarangays.take(5).map((entry) {
              return _buildBarangayItem(
                entry.key,
                entry.value,
                patients.length,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBarangayItem(String barangay, int count, int total) {
    final percentage = total > 0 ? (count / total * 100).toInt() : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              barangay,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF6B6B)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B6B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== TOP SYMPTOMS SECTION ==========
  Widget _buildTopSymptomsSection(List<BHWPatient> patients) {
    final symptomCounts = <String, int>{};

    for (var patient in patients) {
      for (var symptom in patient.symptoms) {
        symptomCounts[symptom] = (symptomCounts[symptom] ?? 0) + 1;
      }
    }

    final sortedSymptoms = symptomCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Most Common Symptoms',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (sortedSymptoms.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No symptoms reported yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...sortedSymptoms.take(5).map((entry) {
              return _buildSymptomItem(entry.key, entry.value);
            }),
        ],
      ),
    );
  }

  Widget _buildSymptomItem(String symptom, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.warning,
              size: 16,
              color: Colors.orange[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              symptom,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== PERFORMANCE METRICS ==========
  Widget _buildPerformanceMetrics(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricRow('High Risk Detection Rate',
              '${stats['highRiskRate']}%', Icons.radar),
          _buildMetricRow('Referral Rate', '${stats['referralRate']}%',
              Icons.local_hospital),
          _buildMetricRow('Average Scans per Day', '${stats['avgPerDay']}',
              Icons.calendar_today),
          _buildMetricRow(
              'Total Patients Helped', '${stats['totalScans']}', Icons.people),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFFF6B6B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF6B6B),
            ),
          ),
        ],
      ),
    );
  }

  // ========== HELPER METHODS ==========
  List<BHWPatient> _getFilteredPatients(BHWPatientProvider provider) {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Today':
        return provider.todaysScans;
      case 'This Week':
        return provider.thisWeeksScans;
      case 'This Month':
        final monthStart = DateTime(now.year, now.month, 1);
        return provider.patients
            .where((p) => p.scanDate.isAfter(monthStart))
            .toList();
      case 'All Time':
      default:
        return provider.patients;
    }
  }

  Map<String, dynamic> _calculateStats(List<BHWPatient> patients) {
    final totalScans = patients.length;
    final lowRisk =
        patients.where((p) => p.riskLevel.toUpperCase() == 'LOW').length;
    final moderate =
        patients.where((p) => p.riskLevel.toUpperCase() == 'MODERATE').length;
    final high =
        patients.where((p) => p.riskLevel.toUpperCase() == 'HIGH').length;
    final critical =
        patients.where((p) => p.riskLevel.toUpperCase() == 'CRITICAL').length;
    final highRisk = high + critical;
    final referrals = patients.where((p) => p.referredToClinic).length;

    // Calculate date range
    int days = 1;
    if (patients.isNotEmpty) {
      final oldestScan = patients
          .map((p) => p.scanDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      days = DateTime.now().difference(oldestScan).inDays + 1;
    }

    final avgPerDay = days > 0 ? (totalScans / days).toStringAsFixed(1) : '0';
    final highRiskRate =
        totalScans > 0 ? ((highRisk / totalScans) * 100).toInt() : 0;
    final referralRate =
        totalScans > 0 ? ((referrals / totalScans) * 100).toInt() : 0;

    return {
      'totalScans': totalScans,
      'low': lowRisk,
      'moderate': moderate,
      'high': high,
      'critical': critical,
      'highRisk': highRisk,
      'referrals': referrals,
      'avgPerDay': avgPerDay,
      'highRiskRate': highRiskRate,
      'referralRate': referralRate,
    };
  }

  Map<DateTime, int> _getDailyActivity(List<BHWPatient> patients) {
    final Map<DateTime, int> dailyData = {};

    // Last 7 days
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      dailyData[dayStart] = 0;
    }

    for (var patient in patients) {
      final dayStart = DateTime(
        patient.scanDate.year,
        patient.scanDate.month,
        patient.scanDate.day,
      );
      if (dailyData.containsKey(dayStart)) {
        dailyData[dayStart] = dailyData[dayStart]! + 1;
      }
    }

    return dailyData;
  }

  Map<String, int> _getAgeGroups(List<BHWPatient> patients) {
    final Map<String, int> ageGroups = {
      '0-17': 0,
      '18-39': 0,
      '40-59': 0,
      '60+': 0,
    };

    for (var patient in patients) {
      if (patient.age < 18) {
        ageGroups['0-17'] = ageGroups['0-17']! + 1;
      } else if (patient.age < 40) {
        ageGroups['18-39'] = ageGroups['18-39']! + 1;
      } else if (patient.age < 60) {
        ageGroups['40-59'] = ageGroups['40-59']! + 1;
      } else {
        ageGroups['60+'] = ageGroups['60+']! + 1;
      }
    }

    return ageGroups;
  }

  Map<String, int> _getGenderDistribution(List<BHWPatient> patients) {
    final Map<String, int> genderDist = {};

    for (var patient in patients) {
      genderDist[patient.sex] = (genderDist[patient.sex] ?? 0) + 1;
    }

    return genderDist;
  }
}
