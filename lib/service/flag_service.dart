import 'package:flutter/foundation.dart';
import 'package:tutorium_frontend/service/api_client.dart';

/// Service for flagging teachers and learners
/// Production-ready with comprehensive logging
class FlagService {
  static final ApiClient _client = ApiClient();

  /// Flag a teacher (called by learner)
  /// POST /admins/flags/teacher
  static Future<Map<String, dynamic>> flagTeacher({
    required int teacherId,
    required int flagsToAdd,
    required String reason,
  }) async {
    debugPrint('🚩 [FLAG] Flagging teacher $teacherId');
    debugPrint('  ├─ Flags to add: $flagsToAdd');
    debugPrint('  └─ Reason: $reason');

    try {
      final response = await _client.postJsonMap(
        '/admins/flags/teacher',
        body: {'id': teacherId, 'flags_to_add': flagsToAdd, 'reason': reason},
      );

      debugPrint('✅ [FLAG] Teacher flagged successfully');
      debugPrint('  └─ Response: $response');
      return response;
    } catch (e) {
      debugPrint('❌ [FLAG] Failed to flag teacher: $e');
      rethrow;
    }
  }

  /// Flag a learner (called by teacher)
  /// POST /admins/flags/learner
  static Future<Map<String, dynamic>> flagLearner({
    required int learnerId,
    required int flagsToAdd,
    required String reason,
  }) async {
    debugPrint('🚩 [FLAG] Flagging learner $learnerId');
    debugPrint('  ├─ Flags to add: $flagsToAdd');
    debugPrint('  └─ Reason: $reason');

    try {
      final response = await _client.postJsonMap(
        '/admins/flags/learner',
        body: {'id': learnerId, 'flags_to_add': flagsToAdd, 'reason': reason},
      );

      debugPrint('✅ [FLAG] Learner flagged successfully');
      debugPrint('  └─ Response: $response');
      return response;
    } catch (e) {
      debugPrint('❌ [FLAG] Failed to flag learner: $e');
      rethrow;
    }
  }

  /// Flag multiple learners (batch operation for teachers)
  /// Returns a list of results with success/failure status
  static Future<List<FlagBatchResult>> flagMultipleLearners({
    required List<int> learnerIds,
    required int flagsToAdd,
    required String reason,
  }) async {
    debugPrint('🚩 [FLAG] Batch flagging ${learnerIds.length} learners');
    debugPrint('  ├─ Learner IDs: $learnerIds');
    debugPrint('  ├─ Flags to add: $flagsToAdd');
    debugPrint('  └─ Reason: $reason');

    final results = <FlagBatchResult>[];

    for (var i = 0; i < learnerIds.length; i++) {
      final learnerId = learnerIds[i];
      debugPrint('  [$i/${learnerIds.length}] Flagging learner $learnerId...');

      try {
        final response = await flagLearner(
          learnerId: learnerId,
          flagsToAdd: flagsToAdd,
          reason: reason,
        );

        results.add(
          FlagBatchResult(id: learnerId, success: true, response: response),
        );
        debugPrint('    ✅ Success');
      } catch (e) {
        results.add(
          FlagBatchResult(id: learnerId, success: false, error: e.toString()),
        );
        debugPrint('    ❌ Failed: $e');
      }
    }

    final successCount = results.where((r) => r.success).length;
    final failCount = results.where((r) => !r.success).length;

    debugPrint(
      '✅ [FLAG] Batch complete: $successCount success, $failCount failed',
    );

    return results;
  }
}

/// Result of a batch flag operation
class FlagBatchResult {
  final int id;
  final bool success;
  final Map<String, dynamic>? response;
  final String? error;

  FlagBatchResult({
    required this.id,
    required this.success,
    this.response,
    this.error,
  });

  @override
  String toString() {
    if (success) {
      return 'FlagBatchResult(id: $id, success: true)';
    } else {
      return 'FlagBatchResult(id: $id, success: false, error: $error)';
    }
  }
}
