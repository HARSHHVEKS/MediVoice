import 'db_constants.dart';

class DBTables {

  // ── 1. PATIENTS TABLE ─────────────────────────────────
  static String get createPatientsTable => '''
    CREATE TABLE ${DBConstants.tablePatients} (
      ${DBConstants.patientId}              INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DBConstants.patientFullName}        TEXT    NOT NULL,
      ${DBConstants.patientAge}             INTEGER,
      ${DBConstants.patientGender}          TEXT,
      ${DBConstants.patientPhoto}           TEXT,
      ${DBConstants.patientLanguage}        TEXT    NOT NULL DEFAULT 'lg',
      ${DBConstants.patientNotes}           TEXT,
      ${DBConstants.patientWard}            TEXT,
      ${DBConstants.patientAlertPhone}      TEXT,
      ${DBConstants.patientIsDevicePatient} INTEGER NOT NULL DEFAULT 0,
      ${DBConstants.patientIsActive}        INTEGER NOT NULL DEFAULT 1,
      ${DBConstants.patientCreatedAt}       TEXT    NOT NULL,
      ${DBConstants.patientUpdatedAt}       TEXT    NOT NULL
    )
  ''';

  // ── 2. MEDICATIONS TABLE ──────────────────────────────
  static String get createMedicationsTable => '''
    CREATE TABLE ${DBConstants.tableMedications} (
      ${DBConstants.medId}           INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DBConstants.medPatientId}    INTEGER NOT NULL,
      ${DBConstants.medName}         TEXT    NOT NULL,
      ${DBConstants.medDosage}       TEXT    NOT NULL,
      ${DBConstants.medDosageUnit}   TEXT    NOT NULL DEFAULT 'mg',
      ${DBConstants.medFrequency}    TEXT    NOT NULL,
      ${DBConstants.medInstructions} TEXT,
      ${DBConstants.medPillColor}    TEXT,
      ${DBConstants.medPillShape}    TEXT,
      ${DBConstants.medPillPhoto}    TEXT,
      ${DBConstants.medAudioPath}    TEXT,
      ${DBConstants.medStartDate}    TEXT    NOT NULL,
      ${DBConstants.medEndDate}      TEXT,
      ${DBConstants.medIsActive}     INTEGER NOT NULL DEFAULT 1,
      ${DBConstants.medCreatedAt}    TEXT    NOT NULL,
      ${DBConstants.medUpdatedAt}    TEXT    NOT NULL,
      FOREIGN KEY (${DBConstants.medPatientId})
        REFERENCES ${DBConstants.tablePatients}(${DBConstants.patientId})
    )
  ''';

  // ── 3. REMINDER SCHEDULES TABLE ───────────────────────
  static String get createReminderSchedulesTable => '''
    CREATE TABLE ${DBConstants.tableReminderSchedules} (
      ${DBConstants.schedId}        INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DBConstants.schedMedId}     INTEGER NOT NULL,
      ${DBConstants.schedPatientId} INTEGER NOT NULL,
      ${DBConstants.schedTime}      TEXT    NOT NULL,
      ${DBConstants.schedDays}      TEXT    NOT NULL DEFAULT '1,2,3,4,5,6,7',
      ${DBConstants.schedIsEnabled} INTEGER NOT NULL DEFAULT 1,
      ${DBConstants.schedAlarmId}   INTEGER,
      ${DBConstants.schedCreatedAt} TEXT    NOT NULL,
      FOREIGN KEY (${DBConstants.schedMedId})
        REFERENCES ${DBConstants.tableMedications}(${DBConstants.medId}),
      FOREIGN KEY (${DBConstants.schedPatientId})
        REFERENCES ${DBConstants.tablePatients}(${DBConstants.patientId})
    )
  ''';

  // ── 4. DOSE LOGS TABLE ────────────────────────────────
  static String get createDoseLogsTable => '''
    CREATE TABLE ${DBConstants.tableDoseLogs} (
      ${DBConstants.logId}            INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DBConstants.logMedId}         INTEGER NOT NULL,
      ${DBConstants.logPatientId}     INTEGER NOT NULL,
      ${DBConstants.logScheduleId}    INTEGER,
      ${DBConstants.logScheduledTime} TEXT    NOT NULL,
      ${DBConstants.logConfirmedTime} TEXT,
      ${DBConstants.logStatus}        TEXT    NOT NULL DEFAULT 'pending',
      ${DBConstants.logMethod}        TEXT,
      ${DBConstants.logNotes}         TEXT,
      ${DBConstants.logSmsAlert}      INTEGER NOT NULL DEFAULT 0,
      ${DBConstants.logCreatedAt}     TEXT    NOT NULL,
      ${DBConstants.logUpdatedAt}     TEXT    NOT NULL,
      FOREIGN KEY (${DBConstants.logMedId})
        REFERENCES ${DBConstants.tableMedications}(${DBConstants.medId}),
      FOREIGN KEY (${DBConstants.logPatientId})
        REFERENCES ${DBConstants.tablePatients}(${DBConstants.patientId})
    )
  ''';

  // ── 5. ALERT CONTACTS TABLE ───────────────────────────
  static String get createAlertContactsTable => '''
    CREATE TABLE ${DBConstants.tableAlertContacts} (
      ${DBConstants.contactId}           INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DBConstants.contactPatientId}    INTEGER NOT NULL,
      ${DBConstants.contactName}         TEXT    NOT NULL,
      ${DBConstants.contactPhone}        TEXT    NOT NULL,
      ${DBConstants.contactRelationship} TEXT,
      ${DBConstants.contactIsPrimary}    INTEGER NOT NULL DEFAULT 0,
      ${DBConstants.contactReceiveSms}   INTEGER NOT NULL DEFAULT 1,
      ${DBConstants.contactIsEmergency}  INTEGER NOT NULL DEFAULT 0,
      ${DBConstants.contactCreatedAt}    TEXT    NOT NULL,
      FOREIGN KEY (${DBConstants.contactPatientId})
        REFERENCES ${DBConstants.tablePatients}(${DBConstants.patientId})
    )
  ''';

  // ── 6. APP SETTINGS TABLE ─────────────────────────────
  static String get createAppSettingsTable => '''
    CREATE TABLE ${DBConstants.tableAppSettings} (
      ${DBConstants.settingKey}       TEXT PRIMARY KEY,
      ${DBConstants.settingValue}     TEXT NOT NULL,
      ${DBConstants.settingUpdatedAt} TEXT NOT NULL
    )
  ''';

  // ── Default settings on first launch ──────────────────
  static List<String> get defaultSettings {
    final now = DateTime.now().toIso8601String();
    return [
      "INSERT INTO ${DBConstants.tableAppSettings} VALUES ('${DBConstants.keyCurrentPatientId}', '', '$now')",
      "INSERT INTO ${DBConstants.tableAppSettings} VALUES ('${DBConstants.keyAdminPin}', '123456', '$now')",
      "INSERT INTO ${DBConstants.tableAppSettings} VALUES ('${DBConstants.keyDefaultLanguage}', 'lg', '$now')",
      "INSERT INTO ${DBConstants.tableAppSettings} VALUES ('${DBConstants.keyMissedDoseDelay}', '30', '$now')",
    ];
  }
}