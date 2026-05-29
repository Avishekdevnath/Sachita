class RecurringRuleModel {
  const RecurringRuleModel({
    required this.id,
    required this.type,
    required this.amountPaisa,
    required this.categoryId,
    required this.categoryName,
    required this.note,
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.nextDueDate,
    required this.isPaused,
  });

  final String id;
  final String type;
  final int amountPaisa;
  final String categoryId;
  final String categoryName;
  final String note;
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextDueDate;
  final bool isPaused;

  factory RecurringRuleModel.fromMap(Map<String, Object?> map) {
    final start = DateTime.tryParse(map['start_date'] as String? ?? '');
    final end = DateTime.tryParse(map['end_date'] as String? ?? '');
    final nextDue = DateTime.tryParse(map['next_due_date'] as String? ?? '');

    return RecurringRuleModel(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? 'expense',
      amountPaisa: (map['amount'] as num?)?.toInt() ?? 0,
      categoryId: map['category_id'] as String? ?? '',
      categoryName: map['category_name'] as String? ?? 'Unknown',
      note: map['note'] as String? ?? '',
      frequency: map['frequency'] as String? ?? 'monthly',
      startDate: start ?? DateTime.now(),
      endDate: end,
      nextDueDate: nextDue ?? DateTime.now(),
      isPaused: (map['is_paused'] as int? ?? 0) == 1,
    );
  }
}
