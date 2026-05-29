class RoutePaths {
  const RoutePaths._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String biometric = '/auth/biometric';
  static const String pin = '/auth/pin';
  static const String forgotPin = '/auth/forgot-pin';
  static const String setNewPin = '/auth/set-new-pin';
  static const String resetConfirm = '/auth/reset-confirm';
  static const String vaultGate = '/vault';
  static const String vaultHome = '/vault/home';
  static const String vaultInfo = '/vault/info';
  static const String vaultInfoNew = '/vault/info/new';
  static const String vaultInfoItemPattern = '/vault/info/:id';
  static const String vaultInfoEditPattern = '/vault/info/:id/edit';
  static const String vaultDocs = '/vault/docs';
  static const String vaultDocAdd = '/vault/docs/add';
  static const String vaultDocFolderPattern = '/vault/docs/folder/:folderId';
  static const String vaultDocItemPattern =
      '/vault/docs/folder/:folderId/item/:itemId';

  static const String dashboard = '/dashboard';
  static const String finance = '/finance';
  static const String financeFilter = '/finance/filter';
  static const String financeTransactionPattern = '/finance/transaction/:id';
  static const String financeSummaryPattern = '/finance/summary/:month';
  static const String financeBudget = '/finance/budget';
  static const String financeRecurring = '/finance/recurring';
  static const String groups = '/groups';
  static const String groupsNew = '/groups/new';
  static const String groupsDetailPattern = '/groups/:id';
  static const String groupsEditPattern = '/groups/:id/edit';
  static const String groupsMembersPattern = '/groups/:id/members';
  static const String groupsFinancePattern = '/groups/:id/finance';
  static const String groupsVaultInfoPattern = '/groups/:id/vault/info';
  static const String groupsVaultInfoNewPattern = '/groups/:id/vault/info/new';
  static const String groupsVaultInfoItemPattern =
      '/groups/:id/vault/info/:itemId';
  static const String groupsVaultInfoEditPattern =
      '/groups/:id/vault/info/:itemId/edit';
  static const String groupsVaultDocsPattern = '/groups/:id/vault/docs';
  static const String groupsVaultDocsAddPattern = '/groups/:id/vault/docs/add';
  static const String groupsVaultDocsFolderPattern =
      '/groups/:id/vault/docs/folder/:folderId';
  static const String groupsVaultDocsItemPattern =
      '/groups/:id/vault/docs/folder/:folderId/item/:itemId';
  static const String groupsFinanceBudgetsPattern =
      '/groups/:id/finance/budgets';
  static const String groupsFinanceRecurringPattern =
      '/groups/:id/finance/recurring';
  static const String groupsFinanceBreakdownPattern =
      '/groups/:id/finance/breakdown';
  static const String insights = '/insights';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String settingsCategories = '/settings/categories';
  static const String settingsBackup = '/settings/backup';
  static const String settingsBackupCreate = '/settings/backup/create';
  static const String settingsBackupRestore = '/settings/backup/restore';
  static const String settingsDriveBackup = '/settings/backup/drive';
  static const String settingsAppearance = '/settings/appearance';
  static const String settingsAbout = '/settings/about';
  static const String settingsDanger = '/settings/danger';
  static const String settingsChangePin = '/settings/change-pin';
  static const String settingsSecurityQuestion = '/settings/security-question';

  static String financeTransaction(String id) => '/finance/transaction/$id';
  static String vaultInfoItem(String id) => '/vault/info/$id';
  static String vaultInfoEdit(String id) => '/vault/info/$id/edit';
  static String vaultDocFolder(String folderId) =>
      '/vault/docs/folder/$folderId';

  static String vaultDocItem({
    required String folderId,
    required String itemId,
  }) {
    return '/vault/docs/folder/$folderId/item/$itemId';
  }

  static String groupsDetail(String groupId) => '/groups/$groupId';
  static String groupsEdit(String groupId) => '/groups/$groupId/edit';
  static String groupsMembers(String groupId) => '/groups/$groupId/members';
  static String groupsFinance(String groupId) => '/groups/$groupId/finance';
  static String groupsVaultInfo(String groupId) =>
      '/groups/$groupId/vault/info';
  static String groupsVaultInfoNew(String groupId) {
    return '/groups/$groupId/vault/info/new';
  }

  static String groupsVaultInfoItem({
    required String groupId,
    required String itemId,
  }) {
    return '/groups/$groupId/vault/info/$itemId';
  }

  static String groupsVaultInfoEdit({
    required String groupId,
    required String itemId,
  }) {
    return '/groups/$groupId/vault/info/$itemId/edit';
  }

  static String groupsVaultDocs(String groupId) {
    return '/groups/$groupId/vault/docs';
  }

  static String groupsVaultDocsAdd({
    required String groupId,
    String? folderId,
  }) {
    final base = '/groups/$groupId/vault/docs/add';
    if (folderId == null || folderId.trim().isEmpty) {
      return base;
    }
    return '$base?folderId=${Uri.encodeComponent(folderId)}';
  }

  static String groupsVaultDocsFolder({
    required String groupId,
    required String folderId,
  }) {
    return '/groups/$groupId/vault/docs/folder/$folderId';
  }

  static String groupsVaultDocsItem({
    required String groupId,
    required String folderId,
    required String itemId,
  }) {
    return '/groups/$groupId/vault/docs/folder/$folderId/item/$itemId';
  }

  static String groupsFinanceBudgets(String groupId) {
    return '/groups/$groupId/finance/budgets';
  }

  static String groupsFinanceRecurring(String groupId) {
    return '/groups/$groupId/finance/recurring';
  }

  static String groupsFinanceBreakdown(String groupId) {
    return '/groups/$groupId/finance/breakdown';
  }

  static String financeSummary(DateTime month) {
    final year = month.year.toString().padLeft(4, '0');
    final monthValue = month.month.toString().padLeft(2, '0');
    return '/finance/summary/$year-$monthValue';
  }
}
