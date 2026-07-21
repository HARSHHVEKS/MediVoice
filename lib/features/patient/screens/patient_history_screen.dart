import 'package:flutter/material.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_constants.dart';
import '../../../core/widgets/pill_visual.dart';
import '../../caregiver/screens/dose_history_screen.dart';

/// Lists every medicine for the patient so any one can be opened in the
/// per-medicine dose history. Replaces the old header button that always
/// opened only the first medicine's history.
class PatientHistoryScreen extends StatefulWidget {
  const PatientHistoryScreen({
    required this.patientId,
    required this.patientName,
    super.key,
  });

  final int patientId;
  final String patientName;

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final meds = await _db.getMedicationsByPatient(widget.patientId);
      if (!mounted) return;
      setState(() {
        _medications = meds;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ PATIENT HISTORY ERROR: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Dose History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _medications.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  itemCount: _medications.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimensions.sm),
                  itemBuilder: (context, i) => _buildTile(_medications[i]),
                ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.xl),
          child: Text(
            'No medicines to show history for yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );

  Widget _buildTile(Map<String, dynamic> med) {
    final name = med[DBConstants.medName] as String;
    final dosage = med[DBConstants.medDosage] as String? ?? '';
    final unit = med[DBConstants.medDosageUnit] as String? ?? '';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.sm,
        ),
        leading: PillVisual(
          shape: med[DBConstants.medPillShape] as String?,
          colorName: med[DBConstants.medPillColor] as String?,
          photoPath: med[DBConstants.medPillPhoto] as String?,
          size: 52,
          animate: false,
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '$dosage $unit'.trim(),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DoseHistoryScreen(
              patientId: widget.patientId,
              patientName: widget.patientName,
              medicationName: name,
              medicationId: med[DBConstants.medId] as int,
            ),
          ),
        ),
      ),
    );
  }
}
