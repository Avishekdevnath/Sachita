import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/core/constants/route_paths.dart';

void main() {
  test('personal vault document import keeps only the simple add route', () {
    expect(RoutePaths.vaultDocAdd, '/vault/docs/add');

    final routePaths = File(
      'lib/core/constants/route_paths.dart',
    ).readAsStringSync();
    expect(routePaths, isNot(contains('vaultDocAddProcess')));
    expect(routePaths, isNot(contains('vaultDocAddFilter')));
    expect(routePaths, isNot(contains('vaultDocAddMetadata')));
    expect(routePaths, isNot(contains('vaultDocAddReview')));
    expect(routePaths, isNot(contains('vaultDocAddSource')));
  });

  test('personal vault document scanner pipeline files are removed', () {
    const removedPaths = <String>[
      'lib/features/vault/screens/vault_doc_import_source_screen.dart',
      'lib/features/vault/screens/vault_doc_import_process_screen.dart',
      'lib/features/vault/screens/vault_doc_import_filter_screen.dart',
      'lib/features/vault/screens/vault_doc_import_metadata_screen.dart',
      'lib/features/vault/screens/vault_doc_import_review_screen.dart',
      'lib/features/vault/providers/vault_doc_import_session_provider.dart',
      'lib/features/vault/models/vault_doc_import_session_state.dart',
      'lib/features/vault/services/document_import_image_service.dart',
      'lib/features/vault/models/document_page.dart',
      'lib/features/vault/widgets/vault_doc_import_step_bar.dart',
    ];

    for (final path in removedPaths) {
      expect(
        File(path).existsSync(),
        isFalse,
        reason: '$path should be deleted',
      );
    }
  });

  test('router no longer exposes import wizard child routes', () {
    final router = File(
      'lib/core/navigation/app_router.dart',
    ).readAsStringSync();

    expect(router, contains('VaultDocAddScreen'));
    expect(router, isNot(contains('VaultDocImport')));
    expect(router, isNot(contains('/vault/docs/add/process')));
    expect(router, isNot(contains('/vault/docs/add/filter')));
    expect(router, isNot(contains('/vault/docs/add/metadata')));
    expect(router, isNot(contains('/vault/docs/add/review')));
    expect(router, isNot(contains('vaultDocImportSessionProvider')));
  });
}
