class GroupFinanceTransactionModel {
  const GroupFinanceTransactionModel({
    required this.id,
    required this.groupId,
    required this.memberId,
    required this.memberName,
    required this.type,
    required this.amountPaisa,
    required this.categoryId,
    required this.categoryName,
    required this.note,
    required this.date,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String memberId;
  final String memberName;
  final String type;
  final int amountPaisa;
  final String categoryId;
  final String categoryName;
  final String note;
  final DateTime date;
  final DateTime createdAt;

  factory GroupFinanceTransactionModel.fromMap(Map<String, Object?> map) {
    final dateString = map['date'] as String? ?? '';
    final createdAtString = map['created_at'] as String? ?? '';
    return GroupFinanceTransactionModel(
      id: map['id'] as String? ?? '',
      groupId: map['group_id'] as String? ?? '',
      memberId: map['member_id'] as String? ?? '',
      memberName: map['member_name'] as String? ?? 'Unknown member',
      type: map['type'] as String? ?? 'expense',
      amountPaisa: (map['amount'] as num?)?.toInt() ?? 0,
      categoryId: map['category_id'] as String? ?? '',
      categoryName: map['category_name'] as String? ?? 'Unknown category',
      note: map['note'] as String? ?? '',
      date: DateTime.tryParse(dateString) ?? DateTime.now(),
      createdAt: DateTime.tryParse(createdAtString) ?? DateTime.now(),
    );
  }
}
