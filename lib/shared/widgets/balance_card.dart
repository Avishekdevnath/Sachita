import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';

/// Improved balance display card with clear visibility toggle affordance.
///
/// Provides:
/// - Large, readable balance display
/// - Clear visual feedback on hide/show state
/// - Better contrast between label and amount
/// - Smooth animations
class BalanceCard extends StatefulWidget {
  const BalanceCard({
    required this.balance,
    required this.subtext,
    this.isHidden = false,
    this.onToggleHide,
    this.currencySymbol = 'BDT',
    super.key,
  });

  final String balance;
  final String subtext;
  final bool isHidden;
  final VoidCallback? onToggleHide;
  final String currencySymbol;

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTokens.durationNormal,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTokens.goldGradient,
        borderRadius: AppTokens.cardRadius,
        boxShadow: [
          BoxShadow(
            color: AppTokens.goldPrimary.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppTokens.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Net Balance',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: AppTokens.goldDeep.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                        ),
                        const SizedBox(height: AppTokens.space2),
                        Text(
                          widget.subtext,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppTokens.goldDeep.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: widget.isHidden ? 'Show balance' : 'Hide balance',
                    child: GestureDetector(
                      onTap: widget.onToggleHide,
                      child: Container(
                        padding: const EdgeInsets.all(AppTokens.space8),
                        decoration: BoxDecoration(
                          color: AppTokens.goldDeep.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        ),
                        child: Icon(
                          widget.isHidden
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTokens.goldDeep.withValues(alpha: 0.8),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space16),
              Text(
                widget.balance,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppTokens.goldDeep,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
