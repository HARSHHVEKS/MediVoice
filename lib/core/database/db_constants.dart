class DBConstants {
  // ── Database info ─────────────────────────────────────
  static const String dbName = 'medivoice.db';
  static const int dbVersion = 1;

  // ── Table Names ───────────────────────────────────────
  static const String tablePatients = 'patients';
  static const String tableMedications = 'medications';
  static const String tableReminderSchedules = 'reminder_schedules';
  static const String tableDoseLogs = 'dose_logs';
  static const String tableAlertContacts = 'alert_contacts';
  static const String tableAppSettings = 'app_settings';

  // ── Roles ─────────────────────────────────────────────
  static const String rolePatient = 'patient';
  static const String roleCaregiver = 'caregiver';
  static const String roleAdmin = 'admin';

  // ── PATIENTS TABLE ────────────────────────────────────
  static const String patientId = 'id';
  static const String patientFullName = 'full_name';
  static const String patientAge = 'age';
  static const String patientGender = 'gender';
  static const String patientPhoto = 'profile_photo_path';
  static const String patientLanguage = 'primary_language';
  static const String patientNotes = 'medical_notes';
  static const String patientWard = 'ward';
  static const String patientAlertPhone = 'alert_phone_number';
  static const String patientIsDevicePatient = 'is_device_patient';
  static const String patientIsActive = 'is_active';
  static const String patientCreatedAt = 'created_at';
  static const String patientUpdatedAt = 'updated_at';

  // ── MEDICATIONS TABLE ─────────────────────────────────
  static const String medId = 'id';
  static const String medPatientId = 'patient_id';
  static const String medName = 'medication_name';
  static const String medDosage = 'dosage';
  static const String medDosageUnit = 'dosage_unit';
  static const String medFrequency = 'frequency';
  static const String medInstructions = 'instructions';
  static const String medPillColor = 'pill_color';
  static const String medPillShape = 'pill_shape';
  static const String medPillPhoto = 'pill_photo_path';
  static const String medAudioPath = 'audio_instruction_path';
  static const String medStartDate = 'start_date';
  static const String medEndDate = 'end_date';
  static const String medIsActive = 'is_active';
  static const String medCreatedAt = 'created_at';
  static const String medUpdatedAt = 'updated_at';

  // ── REMINDER SCHEDULES TABLE ──────────────────────────
  static const String schedId = 'id';
  static const String schedMedId = 'medication_id';
  static const String schedPatientId = 'patient_id';
  static const String schedTime = 'scheduled_time';
  static const String schedDays = 'days_of_week';
  static const String schedIsEnabled = 'is_enabled';
  static const String schedAlarmId = 'alarm_id';
  static const String schedCreatedAt = 'created_at';

  // ── DOSE LOGS TABLE ───────────────────────────────────
  static const String logId = 'id';
  static const String logMedId = 'medication_id';
  static const String logPatientId = 'patient_id';
  static const String logScheduleId = 'reminder_schedule_id';
  static const String logScheduledTime = 'scheduled_time';
  static const String logConfirmedTime = 'confirmed_time';
  static const String logStatus = 'status';
  static const String logMethod = 'confirmation_method';
  static const String logNotes = 'notes';
  static const String logSmsAlert = 'sms_alert_sent';
  static const String logCreatedAt = 'created_at';
  static const String logUpdatedAt = 'updated_at';

  // Dose status values
  static const String statusPending = 'pending';
  static const String statusTaken = 'taken';
  static const String statusMissed = 'missed';
  static const String statusSkipped = 'skipped';

  // ── ALERT CONTACTS TABLE ──────────────────────────────
  static const String contactId = 'id';
  static const String contactPatientId = 'patient_id';
  static const String contactName = 'contact_name';
  static const String contactPhone = 'phone_number';
  static const String contactRelationship = 'relationship';
  static const String contactIsPrimary = 'is_primary';
  static const String contactReceiveSms = 'receive_missed_dose_sms';
  static const String contactIsEmergency = 'is_emergency_contact';
  static const String contactCreatedAt = 'created_at';

  // ── APP SETTINGS TABLE ────────────────────────────────
  static const String settingKey = 'setting_key';
  static const String settingValue = 'setting_value';
  static const String settingUpdatedAt = 'updated_at';

  // Setting keys
  static const String keyCurrentPatientId = 'current_patient_id';
  static const String keyAdminPin = 'admin_pin';
  static const String keyDefaultLanguage = 'default_language';
  static const String keyMissedDoseDelay = 'missed_dose_delay_minutes';
  static const String keyThemeMode = 'theme_mode';
}