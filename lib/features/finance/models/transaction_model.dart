class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.type,
    required this.amountPaisa,
    required this.categoryId,
    required this.note,
    required this.date,
    required this.createdAt,
  });

  final String id;
  final String type;
  final int amountPaisa;
  final String categoryId;
  final String note;
  final DateTime date;
  final DateTime createdAt;

  factory TransactionModel.fromMap(Map<String, Object?> map) {
    return TransactionModel(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? 'expense',
      amountPaisa: map['amount'] as int? ?? 0,
      categoryId: map['category_id'] as String? ?? '',
      note: map['note'] as String? ?? '',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
