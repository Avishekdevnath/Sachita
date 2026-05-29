import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/vault/widgets/vault_info_modal.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';
import 'package:sanchita/shared/widgets/gradient_card.dart';

class VaultHomeScreen extends StatelessWidget {
  const VaultHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppNavigationBar(
        title: 'Vault',
        showBackButton: false,
        actions: <Widget>[
          IconButton(
            tooltip: 'Vault statistics',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const VaultInfoModal(),
              );
            },
            icon: const Icon(Icons.info_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space16,
          AppTokens.space20,
          AppTokens.space16,
          AppTokens.space24,
        ),
        children: <Widget>[
          Text(
            'Your vault is unlocked',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            'All stored data is encrypted on your device.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTokens.space24),
          GestureDetector(
            onTap: () {
              context.push(RoutePaths.vaultInfo);
            },
            child: GradientCard(
              gradient: AppTokens.goldGradient,
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppTokens.space12),
                    decoration: BoxDecoration(
                      color: AppTokens.goldDeep.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppTokens.goldDeep,
                      size: AppTokens.iconLg,
                    ),
                  ),
                  const SizedBox(width: AppTokens.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Info Vault',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppTokens.goldDeep,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: AppTokens.space4),
                        Text(
                          'Passwords, IDs, finance, medical, and more',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTokens.goldDeep.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppTokens.goldDeep.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
