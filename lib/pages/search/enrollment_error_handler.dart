import 'package:flutter/foundation.dart';

/// Production-grade error tracking for enrollment pipeline
class EnrollmentError {
  final EnrollmentErrorType type;
  final String message;
  final String userMessage;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final Map<String, dynamic> context;

  EnrollmentError({
    required this.type,
    required this.message,
    required this.userMessage,
    this.originalError,
    this.stackTrace,
    Map<String, dynamic>? context,
  }) : context = context ?? {};

  @override
  String toString() {
    return 'EnrollmentError(type: $type, message: $message, context: $context)';
  }
}

enum EnrollmentErrorType {
  // Pre-validation errors
  noLearnerInfo,
  noSelectedSession,
  insufficientBalance,
  teacherCannotEnroll,

  // API errors
  duplicateEnrollment,
  classFull,
  balanceDeductionFailed,
  enrollmentCreationFailed,
  balanceRestoreFailed,

  // Network errors
  networkTimeout,
  networkUnavailable,

  // Unknown
  unknown,
}

/// Logs enrollment pipeline events with structured context
class EnrollmentLogger {
  static const String _prefix = '🎓 [ENROLLMENT]';

  static void step(String step, Map<String, dynamic>? context) {
    if (kDebugMode) {
      final contextStr = context != null ? ' | ${_formatContext(context)}' : '';
      debugPrint('$_prefix ✅ $step$contextStr');
    }
  }

  static void warning(String message, Map<String, dynamic>? context) {
    if (kDebugMode) {
      final contextStr = context != null ? ' | ${_formatContext(context)}' : '';
      debugPrint('$_prefix ⚠️  $message$contextStr');
    }
  }

  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    if (kDebugMode) {
      final contextStr = context != null ? ' | ${_formatContext(context)}' : '';
      debugPrint('$_prefix ❌ $message$contextStr');
      if (error != null) {
        debugPrint('$_prefix    Error: $error');
      }
      if (stackTrace != null) {
        debugPrint(
          '$_prefix    Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}',
        );
      }
    }
  }

  static void rollback(String action, Map<String, dynamic>? context) {
    if (kDebugMode) {
      final contextStr = context != null ? ' | ${_formatContext(context)}' : '';
      debugPrint('$_prefix 🔄 ROLLBACK: $action$contextStr');
    }
  }

  static String _formatContext(Map<String, dynamic> context) {
    return context.entries.map((e) => '${e.key}=${e.value}').join(', ');
  }
}

/// User-friendly error message generator
class EnrollmentErrorMessages {
  static const Map<EnrollmentErrorType, String> _thaiMessages = {
    EnrollmentErrorType.noLearnerInfo:
        'ไม่พบข้อมูลผู้เรียน กรุณาเข้าสู่ระบบใหม่',
    EnrollmentErrorType.noSelectedSession:
        'กรุณาเลือก session ที่ต้องการลงทะเบียน',
    EnrollmentErrorType.insufficientBalance:
        'เงินในบัญชีไม่เพียงพอ กรุณาเติมเงินก่อนลงทะเบียน',
    EnrollmentErrorType.teacherCannotEnroll:
        'ครูไม่สามารถลงทะเบียนคลาสของตัวเองได้',
    EnrollmentErrorType.duplicateEnrollment: 'คุณลงทะเบียน session นี้แล้ว',
    EnrollmentErrorType.classFull: 'ขอโทษค่ะ คลาสนี้เต็มแล้ว',
    EnrollmentErrorType.balanceDeductionFailed:
        'ไม่สามารถหักเงินได้ กรุณาลองใหม่อีกครั้ง',
    EnrollmentErrorType.enrollmentCreationFailed:
        'ไม่สามารถลงทะเบียนได้ เราได้คืนเงินให้คุณแล้ว',
    EnrollmentErrorType.balanceRestoreFailed:
        'เกิดข้อผิดพลาด กรุณาติดต่อแอดมิน',
    EnrollmentErrorType.networkTimeout: 'เชื่อมต่อช้าเกินไป กรุณาลองใหม่',
    EnrollmentErrorType.networkUnavailable:
        'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบอินเทอร์เน็ต',
    EnrollmentErrorType.unknown: 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ กรุณาลองใหม่',
  };

  static String getMessage(EnrollmentErrorType type) {
    return _thaiMessages[type] ?? _thaiMessages[EnrollmentErrorType.unknown]!;
  }

  static String getDetailedMessage(EnrollmentError error) {
    final baseMessage = getMessage(error.type);

    // Add context-specific details
    if (error.type == EnrollmentErrorType.insufficientBalance) {
      final balance = error.context['currentBalance'];
      final needed = error.context['neededAmount'];
      if (balance != null && needed != null) {
        return '$baseMessage\nยอดคงเหลือ: \$${balance.toStringAsFixed(2)} | ต้องการ: \$${needed.toStringAsFixed(2)}';
      }
    }

    if (error.type == EnrollmentErrorType.classFull) {
      final current = error.context['currentEnrollment'];
      final limit = error.context['limit'];
      if (current != null && limit != null) {
        return '$baseMessage\nจำนวนผู้เรียนปัจจุบัน: $current/$limit';
      }
    }

    return baseMessage;
  }
}
