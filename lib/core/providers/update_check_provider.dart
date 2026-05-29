import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/models/update_check_result.dart';
import 'package:sanchita/core/services/update_service.dart';

final updateCheckProvider = FutureProvider<UpdateCheckResult>((ref) async {
  return const UpdateService().checkForUpdate();
});
