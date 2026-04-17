// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_constants.dart';

class DoseHistoryScreen extends StatefulWidget {
  const DoseHistoryScreen({
    required this.patientId,
    required this.patientName,
    required this.medicationName,
    required this.medicationId,
    super.key,
  });

  final int patientId;
  final String patientName;
  final String medicationName;
  final int medicationId;

  @override
  State<DoseHistoryScreen> createState() => _DoseHistoryScreenState();
}

class _DoseHistoryScreenState extends State<DoseHistoryScreen> {
  // ── State ─────────────────────────────────────────────
  List<Map<String, dynamic>> _allLogs = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, taken, missed, skipped

  // ── Stats ─────────────────────────────────────────────
  int _takenCount = 0;
  int _missedCount = 0;
  int _skippedCount = 0;
  int _totalCount = 0;

  final _db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ── Load dose logs ────────────────────────────────────
  Future<void> _loadHistory() async {
    try {
      setState(() => _isLoading = true);

      // Get all logs for this patient
      final logs = await _db.getDoseLogsByPatient(
        widget.patientId,
        limit: 100,
      );

      // Filter to only this medication
      final medLogs = logs
          .where(
            (log) => log[DBConstants.logMedId] == widget.medicationId,
          )
          .toList();

      // Calculate stats
      _takenCount = medLogs
          .where((l) => l[DBConstants.logStatus] == DBConstants.statusTaken)
          .length;
      _missedCount = medLogs
          .where((l) => l[DBConstants.logStatus] == DBConstants.statusMissed)
          .length;
      _skippedCount = medLogs
          .where((l) => l[DBConstants.logStatus] == DBConstants.statusSkipped)
          .length;
      _totalCount = medLogs.length;

      if (!mounted) return;
      setState(() {
        _allLogs = medLogs;
        _isLoading = false;
      });

      _applyFilter(_selectedFilter);

      debugPrint(
        '✅ HISTORY: Loaded ${medLogs.length} logs '
        'for ${widget.medicationName}',
      );
    } catch (e) {
      debugPrint('❌ HISTORY LOAD ERROR: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Apply filter ──────────────────────────────────────
  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == 'all') {
        _filtered = List.from(_allLogs);
      } else {
        _filtered =
            _allLogs.where((l) => l[DBConstants.logStatus] == filter).toList();
      }
    });
  }

  // ── Format date ───────────────────────────────────────
  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '—';
    try {
      final dt = DateTime.parse(isoString);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$min';
    } catch (_) {
      return isoString;
    }
  }

  // ── Format scheduled time ─────────────────────────────
  String _formatScheduled(String? time) {
    if (time == null || time.isEmpty) return '—';
    try {
      final dt = DateTime.parse(time);
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$h:$min';
    } catch (_) {
      return time;
    }
  }

  // ── Status config ─────────────────────────────────────
  Map<String, dynamic> _statusConfig(String? status) {
    switch (status) {
      case DBConstants.statusTaken:
        return {
          'label': 'Taken',
          'color': AppColors.successGreen,
          'bg': AppColors.successGreen.withOpacity(0.1),
          'icon': Icons.check_circle_rounded,
        };
      case DBConstants.statusMissed:
        return {
          'label': 'Missed',
          'color': AppColors.dangerRed,
          'bg': AppColors.dangerRed.withOpacity(0.1),
          'icon': Icons.cancel_rounded,
        };
      case DBConstants.statusSkipped:
        return {
          'label': 'Skipped',
          'color': AppColors.textSecondary,
          'bg': Colors.grey.shade100,
          'icon': Icons.skip_next_rounded,
        };
      case DBConstants.statusPending:
      default:
        return {
          'label': 'Pending',
          'color': AppColors.warningOrange,
          'bg': AppColors.warningOrange.withOpacity(0.1),
          'icon': Icons.hourglass_empty_rounded,
        };
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryBlue,
                AppColors.primaryDark,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── Top Bar ────────────────────────────
                _buildTopBar(),

                // ── Stats Row ─────────────────────────
                _buildStatsRow(),

                // ── Content ────────────────────────────
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Filter tabs
                        _buildFilterTabs(),
                        // List
                        Expanded(
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryBlue,
                                  ),
                                )
                              : _filtered.isEmpty
                                  ? _buildEmptyState()
                                  : _buildLogList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  // ── Top Bar ───────────────────────────────────────────
  Widget _buildTopBar() => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.sm,
          AppDimensions.sm,
          AppDimensions.md,
          AppDimensions.sm,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.medicationName,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Dose history • ${widget.patientName}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
            // Refresh
            IconButton(
              icon: const Icon(
                Icons.refresh,
                color: Colors.white,
              ),
              onPressed: _loadHistory,
            ),
          ],
        ),
      );

  // ── Stats Row ─────────────────────────────────────────
  Widget _buildStatsRow() => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.md,
          0,
          AppDimensions.md,
          AppDimensions.md,
        ),
        child: Row(
          children: [
            _buildStatChip(
              label: 'Total',
              count: _totalCount,
              color: Colors.white,
              textColor: AppColors.primaryBlue,
            ),
            const SizedBox(width: AppDimensions.sm),
            _buildStatChip(
              label: 'Taken',
              count: _takenCount,
              color: AppColors.successGreen,
              textColor: Colors.white,
            ),
            const SizedBox(width: AppDimensions.sm),
            _buildStatChip(
              label: 'Missed',
              count: _missedCount,
              color: AppColors.dangerRed,
              textColor: Colors.white,
            ),
            const SizedBox(width: AppDimensions.sm),
            _buildStatChip(
              label: 'Skipped',
              count: _skippedCount,
              color: Colors.white.withOpacity(0.7),
              textColor: AppColors.textPrimary,
            ),
          ],
        ),
      );

  Widget _buildStatChip({
    required String label,
    required int count,
    required Color color,
    required Color textColor,
  }) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(
              AppDimensions.radiusMd,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: textColor.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ),
      );

  // ── Filter Tabs ───────────────────────────────────────
  Widget _buildFilterTabs() => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.md,
          AppDimensions.md,
          AppDimensions.md,
          AppDimensions.sm,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterTab('all', 'All'),
              _filterTab(DBConstants.statusTaken, 'Taken'),
              _filterTab(DBConstants.statusMissed, 'Missed'),
              _filterTab(DBConstants.statusSkipped, 'Skipped'),
              _filterTab(DBConstants.statusPending, 'Pending'),
            ],
          ),
        ),
      );

  Widget _filterTab(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => _applyFilter(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: AppDimensions.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────
  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              _selectedFilter == 'all'
                  ? 'No dose history yet'
                  : 'No $_selectedFilter doses found',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Doses will appear here once\nthe patient starts confirming.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.grey.shade400,
                height: 1.5,
              ),
            ),
          ],
        ),
      );

  // ── Log List ──────────────────────────────────────────
  Widget _buildLogList() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.md,
          0,
          AppDimensions.md,
          AppDimensions.xl,
        ),
        itemCount: _filtered.length,
        itemBuilder: (context, index) => _buildLogCard(_filtered[index]),
      );

  // ── Log Card ──────────────────────────────────────────
  Widget _buildLogCard(Map<String, dynamic> log) {
    final status = log[DBConstants.logStatus] as String?;
    final scheduledTime = log[DBConstants.logScheduledTime] as String?;
    final confirmedTime = log[DBConstants.logConfirmedTime] as String?;
    final method = log[DBConstants.logMethod] as String?;
    final createdAt = log[DBConstants.logCreatedAt] as String?;

    final config = _statusConfig(status);
    final color = config['color'] as Color;
    final bgColor = config['bg'] as Color;
    final icon = config['icon'] as IconData;
    final label = config['label'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Row(
          children: [
            // Status icon circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),

            const SizedBox(width: AppDimensions.md),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Scheduled time
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Scheduled: ${_formatScheduled(scheduledTime)}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  // Confirmed time (if taken)
                  if (confirmedTime != null && confirmedTime.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 13,
                          color: AppColors.successGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Taken: ${_formatDate(confirmedTime)}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Method
                  if (method != null && method.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Via: $method',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Date on right
            Text(
              _formatDate(createdAt).split('  ').first, // just the date part
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.grey.shade400,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}
