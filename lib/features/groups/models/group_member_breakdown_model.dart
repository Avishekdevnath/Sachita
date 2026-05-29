class GroupMemberBreakdownModel {
  const GroupMemberBreakdownModel({
    required this.memberId,
    required this.memberName,
    required this.incomePaisa,
    required this.expensePaisa,
  });

  final String memberId;
  final String memberName;
  final int incomePaisa;
  final int expensePaisa;

  int get netPaisa => incomePaisa - expensePaisa;

  factory GroupMemberBreakdownModel.fromMap(Map<String, Object?> map) {
    return GroupMemberBreakdownModel(
      memberId: map['member_id'] as String? ?? '',
      memberName: map['member_name'] as String? ?? 'Member',
      incomePaisa: (map['income_total'] as num?)?.toInt() ?? 0,
      expensePaisa: (map['expense_total'] as num?)?.toInt() ?? 0,
    );
  }
}
