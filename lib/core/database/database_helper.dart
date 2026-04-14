import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'db_constants.dart';
import 'db_tables.dart';

class DatabaseHelper {
  // ── Singleton ─────────────────────────────────────────
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance =
      DatabaseHelper._privateConstructor();

  static Database? _database;

  // ── Get database ──────────────────────────────────────
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // ── Initialize ────────────────────────────────────────
  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, DBConstants.dbName);
      debugPrint('🔌 DB: Path = $path');

      return await openDatabase(
        path,
        version: DBConstants.dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          debugPrint('✅ DB: Opened successfully!');
        },
      );
    } catch (e) {
      debugPrint('❌ DB INIT ERROR: $e');
      rethrow;
    }
  }

  // ── Create all tables on fresh install ────────────────
  Future<void> _onCreate(Database db, int version) async {
    try {
      await db.execute(DBTables.createPatientsTable);
      debugPrint('🏗️ DB: patients ✅');

      await db.execute(DBTables.createMedicationsTable);
      debugPrint('🏗️ DB: medications ✅');

      await db.execute(DBTables.createReminderSchedulesTable);
      debugPrint('🏗️ DB: reminder_schedules ✅');

      await db.execute(DBTables.createDoseLogsTable);
      debugPrint('🏗️ DB: dose_logs ✅');

      await db.execute(DBTables.createAlertContactsTable);
      debugPrint('🏗️ DB: alert_contacts ✅');

      await db.execute(DBTables.createAppSettingsTable);
      debugPrint('🏗️ DB: app_settings ✅');

      for (final sql in DBTables.defaultSettings) {
        await db.execute(sql);
      }
      debugPrint('✅ DB: All tables created!');
    } catch (e) {
      debugPrint('❌ DB CREATE ERROR: $e');
      rethrow;
    }
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Future migrations go here
  }

  // ══════════════════════════════════════════════════════
  // PATIENTS
  // ══════════════════════════════════════════════════════

  Future<int> insertPatient(Map<String, dynamic> patient) async {
    final db = await database;
    return db.insert(
      DBConstants.tablePatients,
      patient,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Map<String, dynamic>>> getAllPatients() async {
    final db = await database;
    return db.query(
      DBConstants.tablePatients,
      where: '${DBConstants.patientIsActive} = 1',
      orderBy: DBConstants.patientFullName,
    );
  }

  Future<List<Map<String, dynamic>>> getCaregiverPatients() async {
    final db = await database;
    return db.query(
      DBConstants.tablePatients,
      where:
          '${DBConstants.patientIsDevicePatient} = 0 AND '
          '${DBConstants.patientIsActive} = 1',
      orderBy: DBConstants.patientFullName,
    );
  }


  Future<List<Map<String, dynamic>>> getDevicePatients() async {
    final db = await database;
    return db.query(
      DBConstants.tablePatients,
      where:
          '${DBConstants.patientIsDevicePatient} = 1 AND '
          '${DBConstants.patientIsActive} = 1',
      orderBy: DBConstants.patientFullName,
    );
  }

  Future<Map<String, dynamic>?> getPatientById(int id) async {
    final db = await database;
    final results = await db.query(
      DBConstants.tablePatients,
      where: '${DBConstants.patientId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updatePatient(
    int id,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    data[DBConstants.patientUpdatedAt] =
        DateTime.now().toIso8601String();
    return db.update(
      DBConstants.tablePatients,
      data,
      where: '${DBConstants.patientId} = ?',
      whereArgs: [id],
    );
  }

  Future<int> deactivatePatient(int id) async {
    final db = await database;
    return db.update(
      DBConstants.tablePatients,
      {
        DBConstants.patientIsActive: 0,
        DBConstants.patientUpdatedAt:
            DateTime.now().toIso8601String(),
      },
      where: '${DBConstants.patientId} = ?',
      whereArgs: [id],
    );
  }

  // ══════════════════════════════════════════════════════
  // MEDICATIONS
  // ══════════════════════════════════════════════════════

  Future<int> insertMedication(Map<String, dynamic> med) async {
    final db = await database;
    return db.insert(
      DBConstants.tableMedications,
      med,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Map<String, dynamic>>> getMedicationsByPatient(
    int patientId,
  ) async {
    final db = await database;
    return db.query(
      DBConstants.tableMedications,
      where:
          '${DBConstants.medPatientId} = ? AND '
          '${DBConstants.medIsActive} = 1',
      whereArgs: [patientId],
      orderBy: DBConstants.medName,
    );
  }

  Future<Map<String, dynamic>?> getMedicationById(int id) async {
    final db = await database;
    final results = await db.query(
      DBConstants.tableMedications,
      where: '${DBConstants.medId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateMedication(
    int id,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    data[DBConstants.medUpdatedAt] =
        DateTime.now().toIso8601String();
    return db.update(
      DBConstants.tableMedications,
      data,
      where: '${DBConstants.medId} = ?',
      whereArgs: [id],
    );
  }

  Future<int> deactivateMedication(int id) async {
    final db = await database;
    return db.update(
      DBConstants.tableMedications,
      {
        DBConstants.medIsActive: 0,
        DBConstants.medUpdatedAt:
            DateTime.now().toIso8601String(),
      },
      where: '${DBConstants.medId} = ?',
      whereArgs: [id],
    );
  }

  // ══════════════════════════════════════════════════════
  // REMINDER SCHEDULES
  // ══════════════════════════════════════════════════════

  Future<int> insertSchedule(
    Map<String, dynamic> schedule,
  ) async {
    final db = await database;
    return db.insert(
      DBConstants.tableReminderSchedules,
      schedule,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Map<String, dynamic>>> getSchedulesByMedication(
    int medicationId,
  ) async {
    final db = await database;
    return db.query(
      DBConstants.tableReminderSchedules,
      where: '${DBConstants.schedMedId} = ?',
      whereArgs: [medicationId],
      orderBy: DBConstants.schedTime,
    );
  }

  Future<void> deleteSchedulesByMedication(
    int medicationId,
  ) async {
    final db = await database;
    await db.delete(
      DBConstants.tableReminderSchedules,
      where: '${DBConstants.schedMedId} = ?',
      whereArgs: [medicationId],
    );
  }

  // ══════════════════════════════════════════════════════
  // DOSE LOGS
  // ══════════════════════════════════════════════════════

  Future<int> insertDoseLog(Map<String, dynamic> log) async {
    final db = await database;
    return db.insert(
      DBConstants.tableDoseLogs,
      log,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateDoseStatus(
    int logId,
    String status,
    String? confirmedTime,
  ) async {
    final db = await database;
    return db.update(
      DBConstants.tableDoseLogs,
      {
        DBConstants.logStatus: status,
        DBConstants.logConfirmedTime: confirmedTime,
        DBConstants.logUpdatedAt:
            DateTime.now().toIso8601String(),
      },
      where: '${DBConstants.logId} = ?',
      whereArgs: [logId],
    );
  }

  Future<List<Map<String, dynamic>>> getDoseLogsByPatient(
    int patientId, {
    int limit = 30,
  }) async {
    final db = await database;
    return db.query(
      DBConstants.tableDoseLogs,
      where: '${DBConstants.logPatientId} = ?',
      whereArgs: [patientId],
      orderBy: '${DBConstants.logScheduledTime} DESC',
      limit: limit,
    );
  }

  // ══════════════════════════════════════════════════════
  // APP SETTINGS
  // ══════════════════════════════════════════════════════

  Future<String?> getSetting(String key) async {
    final db = await database;
    final results = await db.query(
      DBConstants.tableAppSettings,
      where: '${DBConstants.settingKey} = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first[DBConstants.settingValue] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      DBConstants.tableAppSettings,
      {
        DBConstants.settingKey: key,
        DBConstants.settingValue: value,
        DBConstants.settingUpdatedAt:
            DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ══════════════════════════════════════════════════════
  // CURRENT PATIENT SESSION
  // ══════════════════════════════════════════════════════

  Future<void> setCurrentPatient(int patientId) async {
    await setSetting(
      DBConstants.keyCurrentPatientId,
      patientId.toString(),
    );
    debugPrint('✅ SESSION: Current patient → $patientId');
  }

  Future<int?> getCurrentPatientId() async {
    final value =
        await getSetting(DBConstants.keyCurrentPatientId);
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value);
  }

  Future<void> clearCurrentPatient() async {
    await setSetting(DBConstants.keyCurrentPatientId, '');
    debugPrint('✅ SESSION: Cleared');
  }

  // ══════════════════════════════════════════════════════
  // UTILITY
  // ══════════════════════════════════════════════════════

  Future<bool> isDatabaseWorking() async {
    try {
      final db = await database;
      await db.query(DBConstants.tableAppSettings);
      return true;
    } catch (e) {
      debugPrint('❌ DATABASE ERROR: $e');
      return false;
    }
  }
}