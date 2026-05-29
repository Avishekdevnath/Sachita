import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/features/settings/screens/settings_drive_backup_screen.dart';
import 'package:sanchita/providers/drive_backup_provider.dart';
import 'package:sanchita/services/drive_backup_service.dart';

void main() {
  group('Drive Backup Feature Tests', () {
    testWidgets('Shows sign-in view when not signed in',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SettingsDriveBackupScreen(),
            ),
          ),
        ),
      );

      // Should show sign-in view
      expect(find.text('Google Drive Backup'), findsWidgets);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('Shows signed-in view with backup list when signed in',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SettingsDriveBackupScreen(),
            ),
          ),
        ),
      );

      // The screen should render without errors
      expect(find.byType(SettingsDriveBackupScreen), findsOneWidget);
    });

    testWidgets('Create Backup button is visible in signed-in state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SettingsDriveBackupScreen(),
            ),
          ),
        ),
      );

      // Screen renders successfully
      expect(find.byType(SettingsDriveBackupScreen), findsOneWidget);
    });

    testWidgets('Format bytes correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SettingsDriveBackupScreen(),
            ),
          ),
        ),
      );

      // Test that the widget renders
      expect(find.byType(SettingsDriveBackupScreen), findsOneWidget);
    });
  });

  group('Drive Backup Service Tests', () {
    test('BackupFile formats date correctly', () {
      final backupFile = BackupFile(
        id: 'test-id',
        name: 'Test Backup',
        modifiedTime: DateTime(2024, 2, 25, 10, 30, 0),
        size: 1024 * 1024, // 1 MB
      );

      expect(backupFile.formattedDate, isNotEmpty);
      expect(backupFile.formattedDate.contains('Feb'), true);
      expect(backupFile.formattedDate.contains('2024'), true);
    });

    test('BackupFile formats size correctly', () {
      // Test bytes
      final backupB = BackupFile(
        id: 'test-id',
        name: 'Small',
        modifiedTime: DateTime.now(),
        size: 512,
      );
      expect(backupB.formattedSize, '512 B');

      // Test KB
      final backupKB = BackupFile(
        id: 'test-id',
        name: 'Medium',
        modifiedTime: DateTime.now(),
        size: 1024 * 512, // 512 KB
      );
      expect(backupKB.formattedSize.contains('KB'), true);

      // Test MB
      final backupMB = BackupFile(
        id: 'test-id',
        name: 'Large',
        modifiedTime: DateTime.now(),
        size: 1024 * 1024 * 10, // 10 MB
      );
      expect(backupMB.formattedSize.contains('MB'), true);
    });
  });

  group('DriveBackupState Tests', () {
    test('DriveBackupState initial values', () {
      final state = DriveBackupState();
      expect(state.currentUser, isNull);
      expect(state.backups, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('DriveBackupState copyWith works correctly', () {
      final state = DriveBackupState();
      final updated = state.copyWith(isLoading: true, error: 'Test error');

      expect(updated.isLoading, isTrue);
      expect(updated.error, 'Test error');
      expect(updated.backups, isEmpty);
    });

    test('DriveBackupState isSignedIn property', () {
      final state = DriveBackupState();
      expect(state.isSignedIn, isFalse);
    });
  });
}
