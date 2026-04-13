class Medicine {

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.remindTimes,
    this.notes = '',
    this.isTaken = false,
  });
  final String id;
  final String name;
  final String dosage;
  final List<String> remindTimes; // e.g., ["08:00", "14:00", "20:00"]
  final String notes;
  bool isTaken;
}
