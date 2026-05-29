import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/finance/widgets/finance_filter_sheet_content.dart';

class TransactionFilterScreen extends StatelessWidget {
  const TransactionFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Filters')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space12,
            AppTokens.space16,
            AppTokens.space24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const FinanceFilterSheetContent(showIntro: true),
        ),
      ),
    );
  }
}
