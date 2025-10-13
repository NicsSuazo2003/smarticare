import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/bhw_patient_provider.dart';
import '../../models/bhw_patient_model.dart';
import 'bhw_result_slip_screen.dart';
import 'bhw_patient_history_screen.dart';

class BHWPatientListScreen extends StatefulWidget {
  const BHWPatientListScreen({Key? key}) : super(key: key);

  @override
  State<BHWPatientListScreen> createState() => _BHWPatientListScreenState();
}

class _BHWPatientListScreenState extends State<BHWPatientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, Low, Moderate, High, Critical
  String _selectedSort = 'Newest'; // Newest, Oldest, Name A-Z, Name Z-A

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
          'Patient Records',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Filter button
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterDialog,
          ),
          // Sort button
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.white),
            onPressed: _showSortDialog,
          ),
        ],
      ),
      body: Consumer<BHWPatientProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Apply search, filter, and sort
          List<BHWPatient> patients = _getFilteredAndSortedPatients(provider);

          if (patients.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Search bar
              _buildSearchBar(),

              // Filter chips
              _buildFilterChips(provider),

              // Patient count
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${patients.length} ${patients.length == 1 ? 'patient' : 'patients'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (provider.unsyncedCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 14,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${provider.unsyncedCount} pending sync',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Patient list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await provider.loadPatientsFromHive();
                    await provider.syncAllPatients();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      return _buildPatientCard(patients[index]);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ========== SEARCH BAR ==========
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name, barangay, or ID...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFFFF6B6B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ========== FILTER CHIPS ==========
  Widget _buildFilterChips(BHWPatientProvider provider) {
    final stats = provider.getStatistics();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', '${stats['total']}', null),
          const SizedBox(width: 8),
          _buildFilterChip('Low', '${stats['low']}', Colors.green),
          const SizedBox(width: 8),
          _buildFilterChip('Moderate', '${stats['moderate']}', Colors.orange),
          const SizedBox(width: 8),
          _buildFilterChip('High', '${stats['high']}', Colors.red),
          const SizedBox(width: 8),
          _buildFilterChip(
              'Critical', '${stats['critical']}', Colors.red[900]!),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String count, Color? color) {
    final isSelected = _selectedFilter == label;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : color ?? Colors.black87,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.3)
                  : (color?.withOpacity(0.2) ?? Colors.grey[200]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: color ?? const Color(0xFFFF6B6B),
      checkmarkColor: Colors.white,
      elevation: isSelected ? 2 : 0,
      pressElevation: 4,
    );
  }

  // ========== PATIENT CARD ==========
  Widget _buildPatientCard(BHWPatient patient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        onTap: () {
          // Check if patient has multiple scans
          final provider =
              Provider.of<BHWPatientProvider>(context, listen: false);
          final patientHistory = provider.getPatientHistory(patient.name);

          if (patientHistory.length > 1) {
            // Show history screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BHWPatientHistoryScreen(
                  patientName: patient.name,
                  patientHistory: patientHistory,
                ),
              ),
            );
          } else {
            // Show single result slip
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BHWResultSlipScreen(patient: patient),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Risk indicator
                  Container(
                    width: 4,
                    height: 60,
                    decoration: BoxDecoration(
                      color: patient.getRiskColor(),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Patient info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${patient.age} years • ${patient.sex}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              patient.barangay,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Risk badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: patient.getRiskColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: patient.getRiskColor(),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          patient.getRiskIcon(),
                          size: 14,
                          color: patient.getRiskColor(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          patient.riskLevel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: patient.getRiskColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Footer row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Date and time
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM d, yyyy').format(patient.scanDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('h:mm a').format(patient.scanDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  // Sync status
                  Row(
                    children: [
                      if (!patient.isSyncedToFirestore)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_off,
                                size: 12,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Offline',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Icon(
                          Icons.cloud_done,
                          size: 16,
                          color: Colors.green[600],
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== EMPTY STATE ==========
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No patients found' : 'No patients yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Start by scanning your first patient',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/bhw-scan-patient');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.camera_alt),
                label: const Text(
                  'Scan First Patient',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ========== FILTER & SORT DIALOGS ==========
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Risk Level'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('All', null),
            _buildFilterOption('Low', Colors.green),
            _buildFilterOption('Moderate', Colors.orange),
            _buildFilterOption('High', Colors.red),
            _buildFilterOption('Critical', Colors.red[900]!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(String label, Color? color) {
    return RadioListTile<String>(
      title: Row(
        children: [
          if (color != null)
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          if (color != null) const SizedBox(width: 8),
          Text(label),
        ],
      ),
      value: label,
      groupValue: _selectedFilter,
      activeColor: const Color(0xFFFF6B6B),
      onChanged: (value) {
        setState(() {
          _selectedFilter = value!;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort By'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption('Newest First', Icons.arrow_downward),
            _buildSortOption('Oldest First', Icons.arrow_upward),
            _buildSortOption('Name A-Z', Icons.sort_by_alpha),
            _buildSortOption('Name Z-A', Icons.sort_by_alpha),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSortOption(String label, IconData icon) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      value: label,
      groupValue: _selectedSort,
      activeColor: const Color(0xFFFF6B6B),
      onChanged: (value) {
        setState(() {
          _selectedSort = value!;
        });
        Navigator.pop(context);
      },
    );
  }

  // ========== FILTERING & SORTING LOGIC ==========
  List<BHWPatient> _getFilteredAndSortedPatients(BHWPatientProvider provider) {
    List<BHWPatient> patients = provider.patients;

    // Apply search
    if (_searchQuery.isNotEmpty) {
      patients = provider.searchPatients(_searchQuery);
    }

    // Apply filter
    if (_selectedFilter != 'All') {
      patients = patients
          .where(
              (p) => p.riskLevel.toUpperCase() == _selectedFilter.toUpperCase())
          .toList();
    }

    // Apply sort
    switch (_selectedSort) {
      case 'Newest First':
        patients.sort((a, b) => b.scanDate.compareTo(a.scanDate));
        break;
      case 'Oldest First':
        patients.sort((a, b) => a.scanDate.compareTo(b.scanDate));
        break;
      case 'Name A-Z':
        patients.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Name Z-A':
        patients.sort((a, b) => b.name.compareTo(a.name));
        break;
    }

    return patients;
  }
}
