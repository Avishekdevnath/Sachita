import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/core/constants/route_paths.dart';

void main() {
  test(
    'document vault implementation remains routable but hidden from main UI',
    () {
      expect(RoutePaths.vaultDocs, '/vault/docs');
      expect(
        File(
          'lib/features/vault/screens/vault_doc_folders_screen.dart',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          'lib/features/vault/screens/vault_doc_add_screen.dart',
        ).existsSync(),
        isTrue,
      );

      final vaultHome = File(
        'lib/features/vault/screens/vault_home_screen.dart',
      ).readAsStringSync();
      final groupDetail = File(
        'lib/features/groups/screens/group_detail_screen.dart',
      ).readAsStringSync();
      final searchScreen = File(
        'lib/features/search/screens/search_screen.dart',
      ).readAsStringSync();
      final searchProvider = File(
        'lib/features/search/providers/search_provider.dart',
      ).readAsStringSync();
      final dashboardRepository = File(
        'lib/features/dashboard/data/dashboard_repository.dart',
      ).readAsStringSync();

      expect(vaultHome, isNot(contains('Document Vault')));
      expect(vaultHome, isNot(contains('RoutePaths.vaultDocs')));
      expect(groupDetail, isNot(contains('Group Document Vault')));
      expect(groupDetail, isNot(contains('RoutePaths.groupsVaultDocs')));
      expect(searchScreen, isNot(contains("'docs'")));
      expect(searchProvider, isNot(contains("'docs'")));
      expect(dashboardRepository, isNot(contains('vault_doc_item_index')));
    },
  );
}
