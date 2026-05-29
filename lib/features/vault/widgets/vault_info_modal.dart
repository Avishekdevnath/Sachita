import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/vault/providers/vault_doc_provider.dart';
import 'package:sanchita/features/vault/providers/vault_info_provider.dart';

/// Shows an informational modal with vault statistics and usage data
class VaultInfoModal extends ConsumerWidget {
  const VaultInfoModal({super.key});

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[index]}';
  }

  Widget _buildStatItem({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    Color? iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppTokens.space12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          child: Icon(
            icon,
            color: iconColor ?? colorScheme.onPrimaryContainer,
            size: AppTokens.iconMd,
          ),
        ),
        const SizedBox(height: AppTokens.space8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTokens.space4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final vaultDocAsync = ref.watch(vaultDocProvider);
    final vaultInfoAsync = ref.watch(vaultInfoProvider);

    final vaultDocState = vaultDocAsync.asData?.value;
    final vaultInfoState = vaultInfoAsync.asData?.value;

    final totalFolders = vaultDocState?.folders.length ?? 0;
    final totalDocs = vaultDocState?.storageUsage.itemCount ?? 0;
    final storageBytesUsed =
        vaultDocState?.storageUsage.totalBytes ?? 0;
    final infoCount = vaultInfoState?.items.length ?? 0;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppTokens.space16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header
            Container(
              padding: const EdgeInsets.all(AppTokens.space16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTokens.radiusLg),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppTokens.space8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(200),
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusMd),
                    ),
                    child: Icon(
                      Icons.info_outlined,
                      color:
                          colorScheme.onPrimaryContainer,
                      size: AppTokens.iconLg,
                    ),
                  ),
                  const SizedBox(width: AppTokens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Vault Statistics',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onPrimaryContainer,
                              ),
                        ),
                        const SizedBox(height: AppTokens.space2),
                        Text(
                          'Storage and usage information',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: colorScheme.onPrimaryContainer
                                    .withAlpha(200),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(AppTokens.space20),
              child: Column(
                children: <Widget>[
                  // Stats Grid
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppTokens.space16,
                      crossAxisSpacing: AppTokens.space16,
                      childAspectRatio: 1.1,
                    ),
                    children: <Widget>[
                      _buildStatItem(
                        context: context,
                        label: 'Folders',
                        value: totalFolders.toString(),
                        icon: Icons.folder_outlined,
                        iconColor: colorScheme.primary,
                      ),
                      _buildStatItem(
                        context: context,
                        label: 'Documents',
                        value: totalDocs.toString(),
                        icon: Icons.description_outlined,
                        iconColor: colorScheme.secondary,
                      ),
                      _buildStatItem(
                        context: context,
                        label: 'Secure Info',
                        value: infoCount.toString(),
                        icon: Icons.lock_outline,
                        iconColor: colorScheme.tertiary,
                      ),
                      _buildStatItem(
                        context: context,
                        label: 'Storage Used',
                        value: _formatBytes(storageBytesUsed),
                        icon: Icons.storage_outlined,
                        iconColor: colorScheme.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space20),
                  // Storage Details Card
                  Container(
                    padding: const EdgeInsets.all(AppTokens.space16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusMd),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.storage_outlined,
                              color: colorScheme.primary,
                              size: AppTokens.iconSm,
                            ),
                            const SizedBox(width: AppTokens.space8),
                            Text(
                              'Storage Details',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.space12),
                        _buildDetailRow(
                          context,
                          label: 'Metadata Storage',
                          value: _formatBytes(
                            vaultDocState?.storageUsage.metadataBytes ?? 0,
                          ),
                        ),
                        const SizedBox(height: AppTokens.space8),
                        _buildDetailRow(
                          context,
                          label: 'Images Storage',
                          value: _formatBytes(
                            vaultDocState?.storageUsage.imagePayloadBytes ?? 0,
                          ),
                        ),
                        const SizedBox(height: AppTokens.space8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTokens.space8,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                          child: _buildDetailRow(
                            context,
                            label: 'Total Used',
                            value: _formatBytes(storageBytesUsed),
                            isTotal: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(AppTokens.space12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(25),
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusMd),
                      border: Border.all(
                        color: colorScheme.primary.withAlpha(100),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.shield_outlined,
                          color: colorScheme.primary,
                          size: AppTokens.iconSm,
                        ),
                        const SizedBox(width: AppTokens.space12),
                        Expanded(
                          child: Text(
                            'All data is encrypted and stored locally on your device',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                0,
                AppTokens.space16,
                AppTokens.space16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            color: isTotal
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isTotal
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
