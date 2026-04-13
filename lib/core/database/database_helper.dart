import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'db_constants.dart';
import 'db_tables.dart';

// ══════════════════════════════════════════════════════════
// DatabaseHelper — Singleton database manager
// Only ONE instance exists at a time
//
// Usage from anywhere:
//   final db = DatabaseHelper.instance;
//   await db.insertPatient(data);
// ══════════════════════════════════════════════════════════

class DatabaseHelper {
  // ── Singleton ────────────────────────────────────────────
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance =
      DatabaseHelper._privateConstructor();

  static Database? _database;

  // ── Get database ─────────────────────────────────────────
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // ── Initialize ───────────────────────────────────────────
  Future<Database> _initDatabase() async {
    try {
      debugPrint('🔌 DB: Getting database path...');
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

  // ── Create tables on fresh install ───────────────────────
  Future<void> _onCreate(Database db, int version) async {
    try {
      debugPrint('🏗️ DB: Creating patients table...');
      await db.execute(DBTables.createPatientsTable);

      debugPrint('🏗️ DB: Creating medications table...');
      await db.execute(DBTables.createMedicationsTable);

      debugPrint('🏗️ DB: Creating schedules table...');
      await db.execute(DBTables.createReminderSchedulesTable);

      debugPrint('🏗️ DB: Creating dose logs table...');
      await db.execute(DBTables.createDoseLogsTable);

      debugPrint('🏗️ DB: Creating alert contacts table...');
      await db.execute(DBTables.createAlertContactsTable);

      debugPrint('🏗️ DB: Creating app settings table...');
      await db.execute(DBTables.createAppSettingsTable);

      debugPrint('🏗️ DB: Inserting default settings...');
      final settings = DBTables.defaultSettings;
      for (var i = 0; i < settings.length; i++) {
        await db.execute(settings[i]);
      }

      debugPrint('✅ DB: All tables created successfully!');
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
  // PATIENTS — Create, Read, Update
  // ══════════════════════════════════════════════════════

  // Insert new patient profile
  Future<int> insertPatient(Map<String, dynamic> patient) async {
    final db = await database;
    return db.insert(
      DBConstants.tablePatients,
      patient,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // Get ALL active patients
  Future<List<Map<String, dynamic>>> getAllPatients() async {
    final db = await database;
    return db.query(
      DBConstants.tablePatients,
      where: '${DBConstants.patientIsActive} = 1',
      orderBy: DBConstants.patientFullName,
    );
  }

  // Get single patient by ID
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

  // Update patient info
  Future<int> updatePatient(int id, Map<String, dynamic> data) async {
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

  // Soft delete patient
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
  // MEDICATIONS — Create, Read, Update, Deactivate
  // ══════════════════════════════════════════════════════

  // Insert new medication
  Future<int> insertMedication(Map<String, dynamic> med) async {
    final db = await database;
    return db.insert(
      DBConstants.tableMedications,
      med,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // Get all active medications for a patient
  Future<List<Map<String, dynamic>>> getMedicationsByPatient(
    int patientId,
  ) async {
    final db = await database;
    return db.query(
      DBConstants.tableMedications,
      where:
          '${DBConstants.medPatientId} = ? AND ${DBConstants.medIsActive} = 1',
      whereArgs: [patientId],
      orderBy: DBConstants.medName,
    );
  }

  // Get single medication by ID
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

  // Update medication
  Future<int> updateMedication(
    int id,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    data[DBConstants.medUpdatedAt] = DateTime.now().toIso8601String();
    return db.update(
      DBConstants.tableMedications,
      data,
      where: '${DBConstants.medId} = ?',
      whereArgs: [id],
    );
  }

  // Soft delete medication — keep history
  Future<int> deactivateMedication(int id) async {
    final db = await database;
    return db.update(
      DBConstants.tableMedications,
      {
        DBConstants.medIsActive: 0,
        DBConstants.medUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DBConstants.medId} = ?',
      whereArgs: [id],
    );
  }

  // ══════════════════════════════════════════════════════
  // REMINDER SCHEDULES — Create, Read, Delete
  // ══════════════════════════════════════════════════════

  // Insert schedule
  Future<int> insertSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    return db.insert(
      DBConstants.tableReminderSchedules,
      schedule,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // Get schedules for a patient
  Future<List<Map<String, dynamic>>> getSchedulesByPatient(
    int patientId,
  ) async {
    final db = await database;
    return db.query(
      DBConstants.tableReminderSchedules,
      where:
          '${DBConstants.schedPatientId} = ? AND ${DBConstants.schedIsEnabled} = 1',
      whereArgs: [patientId],
      orderBy: DBConstants.schedTime,
    );
  }

  // Get schedules for a medication
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

  // Delete schedules for a medication
  Future<void> deleteSchedulesByMedication(int medicationId) async {
    final db = await database;
    await db.delete(
      DBConstants.tableReminderSchedules,
      where: '${DBConstants.schedMedId} = ?',
      whereArgs: [medicationId],
    );
  }

  // ══════════════════════════════════════════════════════
  // DOSE LOGS — Create, Read, Update
  // ══════════════════════════════════════════════════════

  // Insert dose log
  Future<int> insertDoseLog(Map<String, dynamic> log) async {
    final db = await database;
    return db.insert(
      DBConstants.tableDoseLogs,
      log,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // Update dose status
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
        DBConstants.logUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DBConstants.logId} = ?',
      whereArgs: [logId],
    );
  }

  // Get dose logs for a patient
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

  // Get today pending doses
  Future<List<Map<String, dynamic>>> getTodayPendingDoses(
    int patientId,
  ) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.query(
      DBConstants.tableDoseLogs,
      where:
          '${DBConstants.logPatientId} = ? AND ${DBConstants.logStatus} = ? AND ${DBConstants.logScheduledTime} LIKE ?',
      whereArgs: [patientId, DBConstants.statusPending, '$today%'],
    );
  }

  // ══════════════════════════════════════════════════════
  // ALERT CONTACTS — Create, Read, Delete
  // ══════════════════════════════════════════════════════

  // Insert alert contact
  Future<int> insertAlertContact(
    Map<String, dynamic> contact,
  ) async {
    final db = await database;
    return db.insert(
      DBConstants.tableAlertContacts,
      contact,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // Get contacts for patient
  Future<List<Map<String, dynamic>>> getAlertContacts(
    int patientId,
  ) async {
    final db = await database;
    return db.query(
      DBConstants.tableAlertContacts,
      where: '${DBConstants.contactPatientId} = ?',
      whereArgs: [patientId],
    );
  }

  // ══════════════════════════════════════════════════════
  // APP SETTINGS — Read, Write
  // ══════════════════════════════════════════════════════

  // Get a setting value
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

  // Save a setting value
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
  // Which patient is currently active on this device
  // ══════════════════════════════════════════════════════

  // Save current patient ID
  Future<void> setCurrentPatient(int patientId) async {
    await setSetting(
      DBConstants.keyCurrentPatientId,
      patientId.toString(),
    );
    debugPrint('✅ SESSION: Current patient set to $patientId');
  }

  // Get current patient ID
  Future<int?> getCurrentPatientId() async {
    final value = await getSetting(DBConstants.keyCurrentPatientId);
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value);
  }

  // Clear current patient (when switching profiles)
  Future<void> clearCurrentPatient() async {
    await setSetting(DBConstants.keyCurrentPatientId, '');
    debugPrint('✅ SESSION: Patient session cleared');
  }

  // ══════════════════════════════════════════════════════
  // UTILITY
  // ══════════════════════════════════════════════════════

  // Check database is working
  Future<bool> isDatabaseWorking() async {
    try {
      final db = await database;
      await db.query(DBConstants.tableAppSettings);
      return true;
    } catch (e, stack) {
      debugPrint('❌ DATABASE ERROR: $e');
      debugPrint('❌ STACK: $stack');
      return false;
    }
  }
}