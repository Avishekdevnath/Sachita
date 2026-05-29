import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/navigation/shell_scaffold.dart';
import 'package:sanchita/features/ai/screens/ai_insights_screen.dart';
import 'package:sanchita/features/auth/providers/session_provider.dart';
import 'package:sanchita/features/auth/screens/biometric_screen.dart';
import 'package:sanchita/features/auth/screens/forgot_pin_screen.dart';
import 'package:sanchita/features/auth/screens/pin_entry_screen.dart';
import 'package:sanchita/features/auth/screens/reset_confirm_screen.dart';
import 'package:sanchita/features/auth/screens/set_new_pin_screen.dart';
import 'package:sanchita/features/auth/screens/splash_screen.dart';
import 'package:sanchita/features/dashboard/screens/dashboard_screen.dart';
import 'package:sanchita/features/finance/screens/budget_management_screen.dart';
import 'package:sanchita/features/finance/screens/finance_screen.dart';
import 'package:sanchita/features/finance/screens/monthly_summary_screen.dart';
import 'package:sanchita/features/finance/screens/recurring_transactions_screen.dart';
import 'package:sanchita/features/finance/screens/transaction_edit_screen.dart';
import 'package:sanchita/features/finance/screens/transaction_filter_screen.dart';
import 'package:sanchita/features/groups/screens/group_budget_screen.dart';
import 'package:sanchita/features/groups/screens/group_detail_screen.dart';
import 'package:sanchita/features/groups/screens/group_edit_screen.dart';
import 'package:sanchita/features/groups/screens/group_finance_screen.dart';
import 'package:sanchita/features/groups/screens/group_member_breakdown_screen.dart';
import 'package:sanchita/features/groups/screens/group_members_screen.dart';
import 'package:sanchita/features/groups/screens/group_recurring_screen.dart';
import 'package:sanchita/features/groups/screens/group_vault_doc_add_screen.dart';
import 'package:sanchita/features/groups/screens/group_vault_doc_folder_screen.dart';
import 'package:sanchita/features/groups/screens/group_vault_doc_folders_screen.dart';
import 'package:sanchita/features/groups/screens/group_vault_doc_viewer_screen.dart';
import 'package:sanchita/features/groups/screens/group_vault_info_detail_screen.dart';
import 'package:sanchita/features/groups/screens/group_vault_info_edit_screen.dart';
import 'package:sanchita/features/groups/screens/group_vault_info_list_screen.dart';
import 'package:sanchita/features/groups/screens/groups_screen.dart';
import 'package:sanchita/features/onboarding/screens/onboarding_screen.dart';
import 'package:sanchita/features/search/screens/search_screen.dart';
import 'package:sanchita/features/settings/screens/settings_about_screen.dart';
import 'package:sanchita/features/settings/screens/settings_appearance_screen.dart';
import 'package:sanchita/features/settings/screens/settings_backup_create_screen.dart';
import 'package:sanchita/features/settings/screens/settings_backup_restore_screen.dart';
import 'package:sanchita/features/settings/screens/settings_backup_screen.dart';
import 'package:sanchita/features/settings/screens/settings_categories_screen.dart';
import 'package:sanchita/features/settings/screens/settings_change_pin_screen.dart';
import 'package:sanchita/features/settings/screens/settings_drive_backup_screen.dart';
import 'package:sanchita/features/settings/screens/settings_screen.dart';
import 'package:sanchita/features/settings/screens/settings_security_question_screen.dart';
import 'package:sanchita/features/vault/providers/vault_session_provider.dart';
import 'package:sanchita/features/vault/screens/vault_doc_add_screen.dart';
import 'package:sanchita/features/vault/screens/vault_doc_folder_screen.dart';
import 'package:sanchita/features/vault/screens/vault_doc_folders_screen.dart';
import 'package:sanchita/features/vault/screens/vault_doc_viewer_screen.dart';
import 'package:sanchita/features/vault/screens/vault_gate_screen.dart';
import 'package:sanchita/features/vault/screens/vault_home_screen.dart';
import 'package:sanchita/features/vault/screens/vault_info_detail_screen.dart';
import 'package:sanchita/features/vault/screens/vault_info_edit_screen.dart';
import 'package:sanchita/features/vault/screens/vault_info_list_screen.dart';

/// Notifies GoRouter to re-evaluate its redirect whenever auth or vault
/// session state changes, WITHOUT recreating the GoRouter instance.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
    ref.listen(vaultSessionProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      // Use ref.read() — this callback is invoked by refreshListenable,
      // not called during build, so watch() must not be used here.
      final session = ref.read(sessionProvider);
      final vaultSession = ref.read(vaultSessionProvider);
      final location = state.matchedLocation;
      final isSplash = location == RoutePaths.splash;
      final isOnboarding = location == RoutePaths.onboarding;
      final isVaultRoute = location.startsWith('/vault');
      final isGroupVaultRoute =
          location.startsWith('/groups/') && location.contains('/vault/');
      final isPinRoute = location == RoutePaths.pin;
      final isBiometricRoute = location == RoutePaths.biometric;
      final isForgotPinRoute = location == RoutePaths.forgotPin;
      final isSetNewPinRoute = location == RoutePaths.setNewPin;
      final isResetConfirmRoute = location == RoutePaths.resetConfirm;
      final isRecoveryRoute =
          isForgotPinRoute || isSetNewPinRoute || isResetConfirmRoute;

      if (session.isLoading) {
        return isSplash ? null : RoutePaths.splash;
      }

      final data = session.asData?.value;
      if (data == null) {
        return isSplash ? null : RoutePaths.splash;
      }

      if (!data.onboardingDone) {
        return isOnboarding ? null : RoutePaths.onboarding;
      }

      if (location == RoutePaths.setNewPin && !data.securityAnswerVerified) {
        return RoutePaths.forgotPin;
      }

      if (!data.authenticated) {
        if (isRecoveryRoute || isPinRoute || isBiometricRoute) {
          return null;
        }
        // Always show PIN screen first; biometric button is offered on it
        return RoutePaths.pin;
      }

      if (isPinRoute ||
          isBiometricRoute ||
          isForgotPinRoute ||
          isSetNewPinRoute) {
        return RoutePaths.dashboard;
      }

      if ((isVaultRoute || isGroupVaultRoute) &&
          location != RoutePaths.vaultGate &&
          !vaultSession.unlocked) {
        final encoded = Uri.encodeComponent(state.uri.toString());
        return '${RoutePaths.vaultGate}?next=$encoded';
      }

      if (location == RoutePaths.vaultGate && vaultSession.unlocked) {
        final nextPath = state.uri.queryParameters['next'];
        if (nextPath != null &&
            nextPath.isNotEmpty &&
            nextPath.startsWith('/') &&
            nextPath != RoutePaths.vaultGate) {
          return nextPath;
        }
        return RoutePaths.vaultHome;
      }

      if (isSplash || isOnboarding) {
        return RoutePaths.dashboard;
      }

      // Defensive null return - validation failed
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.pin,
        builder: (context, state) => const PinEntryScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPin,
        builder: (context, state) => const ForgotPinScreen(),
      ),
      GoRoute(
        path: RoutePaths.setNewPin,
        builder: (context, state) => const SetNewPinScreen(),
      ),
      GoRoute(
        path: RoutePaths.resetConfirm,
        builder: (context, state) => const ResetConfirmScreen(),
      ),
      GoRoute(
        path: RoutePaths.biometric,
        builder: (context, state) => const BiometricScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsCategories,
        builder: (context, state) => const SettingsCategoriesScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsBackup,
        builder: (context, state) => const SettingsBackupScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsBackupCreate,
        builder: (context, state) => const SettingsBackupCreateScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsBackupRestore,
        builder: (context, state) => const SettingsBackupRestoreScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsDriveBackup,
        builder: (context, state) => const SettingsDriveBackupScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsAppearance,
        builder: (context, state) => const SettingsAppearanceScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsAbout,
        builder: (context, state) => const SettingsAboutScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsDanger,
        builder: (context, state) => const ResetConfirmScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsChangePin,
        builder: (context, state) => const SettingsChangePinScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsSecurityQuestion,
        builder: (context, state) => const SettingsSecurityQuestionScreen(),
      ),
      GoRoute(
        path: RoutePaths.vaultGate,
        builder: (context, state) => const VaultGateScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.vaultInfo,
        builder: (context, state) => const VaultInfoListScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'new',
            builder: (context, state) => const VaultInfoEditScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return VaultInfoDetailScreen(itemId: id);
            },
            routes: <RouteBase>[
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return VaultInfoEditScreen(itemId: id);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.vaultDocs,
        builder: (context, state) => const VaultDocFoldersScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'add',
            builder: (context, state) {
              final folderId = state.uri.queryParameters['folderId'];
              return VaultDocAddScreen(initialFolderId: folderId);
            },
          ),
          GoRoute(
            path: 'folder/:folderId',
            builder: (context, state) {
              final folderId = state.pathParameters['folderId'] ?? '';
              return VaultDocFolderScreen(folderId: folderId);
            },
            routes: <RouteBase>[
              GoRoute(
                path: 'item/:itemId',
                builder: (context, state) {
                  final folderId = state.pathParameters['folderId'] ?? '';
                  final itemId = state.pathParameters['itemId'] ?? '';
                  return VaultDocViewerScreen(
                    folderId: folderId,
                    itemId: itemId,
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.insights,
        builder: (context, state) => const AiInsightsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScaffold(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RoutePaths.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RoutePaths.finance,
                builder: (context, state) => const FinanceScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'budget',
                    builder: (context, state) {
                      return const BudgetManagementScreen();
                    },
                  ),
                  GoRoute(
                    path: 'summary/:month',
                    builder: (context, state) {
                      final monthKey = state.pathParameters['month'] ?? '';
                      return MonthlySummaryScreen(
                        initialMonth: _parseSummaryMonth(monthKey),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'filter',
                    builder: (context, state) {
                      return const TransactionFilterScreen();
                    },
                  ),
                  GoRoute(
                    path: 'transaction/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return TransactionEditScreen(transactionId: id);
                    },
                  ),
                  GoRoute(
                    path: 'recurring',
                    builder: (context, state) {
                      return const RecurringTransactionsScreen();
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RoutePaths.groups,
                builder: (context, state) => const GroupsScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const GroupEditScreen(),
                  ),
                  GoRoute(
                    path: ':id/edit',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return GroupEditScreen(groupId: id);
                    },
                  ),
                  GoRoute(
                    path: ':id/members',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return GroupMembersScreen(groupId: id);
                    },
                  ),
                  GoRoute(
                    path: ':id/vault/info',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return GroupVaultInfoListScreen(groupId: id);
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'new',
                        builder: (context, state) {
                          final id = state.pathParameters['id'] ?? '';
                          return GroupVaultInfoEditScreen(groupId: id);
                        },
                      ),
                      GoRoute(
                        path: ':itemId',
                        builder: (context, state) {
                          final id = state.pathParameters['id'] ?? '';
                          final itemId = state.pathParameters['itemId'] ?? '';
                          return GroupVaultInfoDetailScreen(
                            groupId: id,
                            itemId: itemId,
                          );
                        },
                        routes: <RouteBase>[
                          GoRoute(
                            path: 'edit',
                            builder: (context, state) {
                              final id = state.pathParameters['id'] ?? '';
                              final itemId =
                                  state.pathParameters['itemId'] ?? '';
                              return GroupVaultInfoEditScreen(
                                groupId: id,
                                itemId: itemId,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: ':id/vault/docs',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return GroupVaultDocFoldersScreen(groupId: id);
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'add',
                        builder: (context, state) {
                          final id = state.pathParameters['id'] ?? '';
                          final folderId =
                              state.uri.queryParameters['folderId'];
                          return GroupVaultDocAddScreen(
                            groupId: id,
                            initialFolderId: folderId,
                          );
                        },
                      ),
                      GoRoute(
                        path: 'folder/:folderId',
                        builder: (context, state) {
                          final id = state.pathParameters['id'] ?? '';
                          final folderId =
                              state.pathParameters['folderId'] ?? '';
                          return GroupVaultDocFolderScreen(
                            groupId: id,
                            folderId: folderId,
                          );
                        },
                        routes: <RouteBase>[
                          GoRoute(
                            path: 'item/:itemId',
                            builder: (context, state) {
                              final id = state.pathParameters['id'] ?? '';
                              final folderId =
                                  state.pathParameters['folderId'] ?? '';
                              final itemId =
                                  state.pathParameters['itemId'] ?? '';
                              return GroupVaultDocViewerScreen(
                                groupId: id,
                                folderId: folderId,
                                itemId: itemId,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: ':id/finance',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return GroupFinanceScreen(groupId: id);
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'budgets',
                        builder: (context, state) {
                          final id = state.pathParameters['id'] ?? '';
                          return GroupBudgetScreen(groupId: id);
                        },
                      ),
                      GoRoute(
                        path: 'recurring',
                        builder: (context, state) {
                          final id = state.pathParameters['id'] ?? '';
                          return GroupRecurringScreen(groupId: id);
                        },
                      ),
                      GoRoute(
                        path: 'breakdown',
                        builder: (context, state) {
                          final id = state.pathParameters['id'] ?? '';
                          return GroupMemberBreakdownScreen(groupId: id);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return GroupDetailScreen(groupId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RoutePaths.search,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RoutePaths.vaultHome,
                builder: (context, state) => const VaultHomeScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const _RouteErrorScreen(),
  );
});

DateTime _parseSummaryMonth(String monthKey) {
  final pieces = monthKey.split('-');
  if (pieces.length != 2) {
    return DateTime(DateTime.now().year, DateTime.now().month);
  }

  final year = int.tryParse(pieces[0]);
  final month = int.tryParse(pieces[1]);
  if (year == null || month == null || month < 1 || month > 12) {
    return DateTime(DateTime.now().year, DateTime.now().month);
  }

  return DateTime(year, month);
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('404', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 16),
            const Text('Invalid route or page not found'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(RoutePaths.splash),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
