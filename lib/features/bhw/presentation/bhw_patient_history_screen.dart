import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/bhw_patient_model.dart';
import 'bhw_result_slip_screen.dart';

class BHWPatientHistoryScreen extends StatelessWidget {
  final String patientName;
  final List<BHWPatient> patientHistory;

  const BHWPatientHistoryScreen({
    super.key,
    required this.patientName,
    required this.patientHistory,
  });

  @override
  Widget build(BuildContext context) {
    // Sort by date (newest first)
    final sortedHistory = List<BHWPatient>.from(patientHistory)
      ..sort((a, b) => b.scanDate.compareTo(a.scanDate));

    final latestScan = sortedHistory.first;
    final firstScan = sortedHistory.last;
    final totalScans = sortedHistory.length;

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
          'Patient History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Patient summary card
            _buildPatientSummaryCard(latestScan, firstScan, totalScans),

            // Risk progression
            if (totalScans > 1) _buildRiskProgression(sortedHistory),

            // Timeline header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scan History ($totalScans)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Total: $totalScans',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B6B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Timeline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedHistory.length,
                itemBuilder: (context, index) {
                  final scan = sortedHistory[index];
                  final isLatest = index == 0;
                  final isOldest = index == sortedHistory.length - 1;

                  return _buildTimelineItem(
                    context,
                    scan,
                    isLatest,
                    isOldest,
                    index,
                    sortedHistory,
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ========== PATIENT SUMMARY CARD ==========
  Widget _buildPatientSummaryCard(
    BHWPatient latestScan,
    BHWPatient firstScan,
    int totalScans,
  ) {
    final daysSinceFirst = DateTime.now().difference(firstScan.scanDate).inDays;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient name and avatar
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latestScan.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${latestScan.age} years • ${latestScan.sex} • ${latestScan.barangay}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white30, thickness: 1),
          const SizedBox(height: 16),

          // Statistics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStatItem(
                'Total Scans',
                totalScans.toString(),
                Icons.camera_alt,
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              _buildSummaryStatItem(
                'Current Risk',
                latestScan.riskLevel,
                latestScan.getRiskIcon(),
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              _buildSummaryStatItem(
                'Tracking',
                '$daysSinceFirst days',
                Icons.calendar_today,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ========== RISK PROGRESSION ==========
  Widget _buildRiskProgression(List<BHWPatient> history) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          const Row(
            children: [
              Icon(Icons.trending_up, color: Color(0xFFFF6B6B), size: 20),
              SizedBox(width: 8),
              Text(
                'Risk Level Progression',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressionChart(history),
          const SizedBox(height: 12),
          _buildProgressionAnalysis(history),
        ],
      ),
    );
  }

  Widget _buildProgressionChart(List<BHWPatient> history) {
    final reversedHistory = history.reversed.toList(); // Oldest to newest

    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: reversedHistory.asMap().entries.map((entry) {
          final index = entry.key;
          final scan = entry.value;
          final isLatest = index == reversedHistory.length - 1;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Risk indicator
                Container(
                  height: _getRiskHeight(scan.riskLevel),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: scan.getRiskColor(),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    border: isLatest
                        ? Border.all(color: Colors.black, width: 2)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                // Date
                Text(
                  DateFormat('MMM\nd').format(scan.scanDate),
                  style: TextStyle(
                    fontSize: 9,
                    color: isLatest ? Colors.black87 : Colors.grey[600],
                    fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  double _getRiskHeight(String riskLevel) {
    switch (riskLevel.toUpperCase()) {
      case 'LOW':
        return 20;
      case 'MODERATE':
        return 35;
      case 'HIGH':
        return 50;
      case 'CRITICAL':
        return 65;
      default:
        return 10;
    }
  }

  Widget _buildProgressionAnalysis(List<BHWPatient> history) {
    if (history.length < 2) {
      return const SizedBox.shrink();
    }

    final latest = history.first;
    final previous = history[1];

    final latestRiskValue = _getRiskValue(latest.riskLevel);
    final previousRiskValue = _getRiskValue(previous.riskLevel);

    String trend;
    Color trendColor;
    IconData trendIcon;

    if (latestRiskValue > previousRiskValue) {
      trend = 'Risk level has INCREASED since last scan';
      trendColor = Colors.red;
      trendIcon = Icons.trending_up;
    } else if (latestRiskValue < previousRiskValue) {
      trend = 'Risk level has DECREASED since last scan';
      trendColor = Colors.green;
      trendIcon = Icons.trending_down;
    } else {
      trend = 'Risk level remains STABLE';
      trendColor = Colors.blue;
      trendIcon = Icons.trending_flat;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: trendColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(trendIcon, color: trendColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              trend,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: trendColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _getRiskValue(String riskLevel) {
    switch (riskLevel.toUpperCase()) {
      case 'LOW':
        return 1;
      case 'MODERATE':
        return 2;
      case 'HIGH':
        return 3;
      case 'CRITICAL':
        return 4;
      default:
        return 0;
    }
  }

  // ========== TIMELINE ITEM ==========
  Widget _buildTimelineItem(
    BuildContext context,
    BHWPatient scan,
    bool isLatest,
    bool isOldest,
    int index,
    List<BHWPatient> history,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              // Top line
              if (!isLatest)
                Container(
                  width: 2,
                  height: 20,
                  color: Colors.grey[300],
                ),
              // Circle
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isLatest ? scan.getRiskColor() : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scan.getRiskColor(),
                    width: isLatest ? 3 : 2,
                  ),
                ),
                child: isLatest
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
              // Bottom line
              if (!isOldest)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey[300],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // Card content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: isLatest
                    ? Border.all(color: scan.getRiskColor(), width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isLatest ? 0.1 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BHWResultSlipScreen(patient: scan),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('MMM d, yyyy').format(scan.scanDate),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        if (isLatest)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'LATEST',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Risk level badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scan.getRiskColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: scan.getRiskColor(),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            scan.getRiskIcon(),
                            size: 18,
                            color: scan.getRiskColor(),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Risk: ${scan.riskLevel}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: scan.getRiskColor(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Symptoms summary
                    if (scan.symptoms.isNotEmpty) ...[
                      const Text(
                        'Symptoms:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: scan.symptoms.take(3).map((symptom) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Text(
                              symptom.length > 25
                                  ? '${symptom.substring(0, 25)}...'
                                  : symptom,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[900],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (scan.symptoms.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '+${scan.symptoms.length - 3} more',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'No symptoms reported',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Scanned by
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Scanned by ${scan.scannedByBHWName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('h:mm a').format(scan.scanDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    // Change indicator
                    if (!isLatest && index < history.length - 1) ...[
                      const SizedBox(height: 12),
                      _buildChangeIndicator(scan, history[index + 1]),
                    ],

                    // View details button
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    BHWResultSlipScreen(patient: scan),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('View Details'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6B6B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeIndicator(BHWPatient current, BHWPatient previous) {
    final currentRisk = _getRiskValue(current.riskLevel);
    final previousRisk = _getRiskValue(previous.riskLevel);

    if (currentRisk == previousRisk) {
      return const SizedBox.shrink();
    }

    final improved = currentRisk < previousRisk;
    final color = improved ? Colors.green : Colors.red;
    final icon = improved ? Icons.arrow_downward : Icons.arrow_upward;
    final text = improved ? 'Improved from' : 'Worsened from';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$text ${previous.riskLevel}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
