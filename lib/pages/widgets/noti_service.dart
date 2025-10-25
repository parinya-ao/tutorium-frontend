import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  final String baseUrl = '${dotenv.env["API_URL"]}:${dotenv.env["PORT"]}';

  Future<Map<String, List<Map<String, dynamic>>>> fetchNotifications(
    int userId,
  ) async {
    try {
      final url = Uri.parse("$baseUrl/notifications");
      debugPrint("🔵 [DEBUG] Fetching notifications from: $url");
      debugPrint("🔵 [DEBUG] Current userId: $userId");

      final response = await http.get(url);
      debugPrint("🔵 [DEBUG] Response status: ${response.statusCode}");
      debugPrint(
        "🔵 [DEBUG] Response body length: ${response.body.length} chars",
      );

      if (response.statusCode != 200) {
        debugPrint(
          "❌ [ERROR] Failed to load notifications: ${response.statusCode}",
        );
        debugPrint("❌ [ERROR] Response body: ${response.body}");
        throw Exception("Failed to load notifications");
      }

      final List<dynamic> data = jsonDecode(response.body);
      debugPrint("🔵 [DEBUG] Total notifications received: ${data.length}");

      final Map<String, List<Map<String, dynamic>>> categorized = {
        "learner": [],
        "teacher": [],
        "system": [],
      };

      int matchedCount = 0;
      int skippedCount = 0;

      for (var n in data) {
        debugPrint("🔍 [DEBUG] Processing notification ID: ${n["ID"]}");
        debugPrint("   - user_id: ${n["user_id"]}");
        debugPrint("   - notification_type: ${n["notification_type"]}");
        debugPrint("   - read_flag: ${n["read_flag"]}");

        if (n["user_id"] == userId) {
          matchedCount++;
          final notificationType = (n["notification_type"] ?? "system")
              .toString()
              .toLowerCase();

          final mapped = {
            "id": n["ID"],
            "title": _getNotificationTitle(notificationType),
            "text": n["notification_description"] ?? "No description",
            "time": _formatDateTime(n["notification_date"]),
            "isRead": n["read_flag"] ?? false,
            "type": notificationType,
            "userId": n["user_id"],
          };

          // Categorize based on notification_type
          final category = _categorizeNotification(notificationType);
          debugPrint(
            "   ✅ Matched! Type: $notificationType -> Category: $category",
          );

          categorized[category]!.add(mapped);
        } else {
          skippedCount++;
          debugPrint(
            "   ⏭️  Skipped (user_id mismatch: ${n["user_id"]} != $userId)",
          );
        }
      }

      debugPrint("🎯 [SUMMARY] Matched: $matchedCount, Skipped: $skippedCount");
      debugPrint("🎯 [SUMMARY] Learner: ${categorized["learner"]!.length}");
      debugPrint("🎯 [SUMMARY] Teacher: ${categorized["teacher"]!.length}");
      debugPrint("🎯 [SUMMARY] System: ${categorized["system"]!.length}");

      return categorized;
    } catch (e, stackTrace) {
      debugPrint("❌ [ERROR] Exception in fetchNotifications: $e");
      debugPrint("❌ [STACK] $stackTrace");
      throw Exception("Error fetching notifications: $e");
    }
  }

  Future<void> deleteNotification(int id) async {
    debugPrint("🗑️  [DEBUG] Deleting notification ID: $id");
    final url = Uri.parse("$baseUrl/notifications/$id");
    debugPrint("🗑️  [DEBUG] DELETE URL: $url");

    final response = await http.delete(
      url,
      headers: {'accept': 'application/json'},
    );

    debugPrint("🗑️  [DEBUG] Delete response status: ${response.statusCode}");
    debugPrint("🗑️  [DEBUG] Delete response body: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 204) {
      debugPrint("❌ [ERROR] Failed to delete notification $id");
      throw Exception('Failed to delete notification $id');
    }

    debugPrint("✅ [SUCCESS] Notification $id deleted");
  }

  Future<bool> markAsRead(Map<String, dynamic> notification) async {
    final int id = notification["id"];
    final String url = "$baseUrl/notifications/$id";

    debugPrint("📖 [DEBUG] Marking notification as read: $id");
    debugPrint("📖 [DEBUG] URL: $url");

    final body = {
      "notification_date": notification["time"],
      "notification_description": notification["text"],
      "notification_type": notification["type"],
      "read_flag": true,
      "user_id": notification["userId"],
    };

    debugPrint("📖 [DEBUG] Request body: ${jsonEncode(body)}");

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {
          "accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      debugPrint("📖 [DEBUG] Response status: ${response.statusCode}");
      debugPrint("📖 [DEBUG] Response body: ${response.body}");

      if (response.statusCode == 200) {
        debugPrint("✅ [SUCCESS] Notification $id marked as read");
        return true;
      } else {
        debugPrint(
          "❌ [ERROR] Failed to mark as read (${response.statusCode}): ${response.body}",
        );
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [ERROR] Exception marking notification as read: $e");
      debugPrint("❌ [STACK] $stackTrace");
      return false;
    }
  }

  /// Helper: Categorize notification type into learner/teacher/system
  String _categorizeNotification(String notificationType) {
    switch (notificationType.toLowerCase()) {
      case "enrollment":
      case "class_completed":
      case "class_cancelled":
        return "learner";
      case "class":
      case "review":
      case "new_enrollment":
        return "teacher";
      case "system":
      case "balance":
      case "password":
      case "welcome":
      default:
        return "system";
    }
  }

  /// Helper: Get notification title based on type
  String _getNotificationTitle(String notificationType) {
    switch (notificationType.toLowerCase()) {
      case "enrollment":
        return "ENROLLMENT";
      case "class":
        return "CLASS UPDATE";
      case "system":
        return "Admin";
      case "balance":
        return "BALANCE";
      case "password":
        return "PASSWORD";
      case "review":
        return "REVIEW";
      case "welcome":
        return "WELCOME";
      default:
        return notificationType.toUpperCase();
    }
  }

  /// Helper: Format DateTime to readable format
  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return DateTime.now().toString();

    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return "Just now";
      } else if (difference.inMinutes < 60) {
        return "${difference.inMinutes}m ago";
      } else if (difference.inHours < 24) {
        return "${difference.inHours}h ago";
      } else if (difference.inDays < 7) {
        return "${difference.inDays}d ago";
      } else {
        return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
      }
    } catch (e) {
      debugPrint("⚠️  [WARN] Failed to parse datetime: $dateTimeStr");
      return dateTimeStr;
    }
  }
}

// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class NotiService{
//   final notificationsPlugin = FlutterLocalNotificationsPlugin();

//   bool _isInitialized = false;

//   bool get isInitialized => _isInitialized;

//   //initaillized
//   Future<void> initNotification() async{
//     if(_isInitialized) return; //Prevent re-initialization

//     //Prepare android init settings
//     const initSettingAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

//     // const initSettingIOS = DarwinInitializationSettings(
//     //   requestAlertPermission: true,
//     //   requestBadgePermission: true,
//     //   requestSoundPermission: true,
//     // );

//     const initSettings = InitializationSettings(
//       android: initSettingAndroid,
//       // iOS: initSettingIOS,
//     );

//     await notificationsPlugin.initialize(initSettings);
//   }
//   // Notification Detail
//   NotificationDetails notificationDetails(){
//     return const NotificationDetails(
//       android: AndroidNotificationDetails(
//         'daily_channel_id',
//         'Daily Notifications',
//         channelDescription: 'Daily Notifications Channel',
//         importance: Importance.max,
//         priority: Priority.high,
//       ),
//       // iOS: DarwinNotificationDetails(),
//     );
//   }
//   // Show Notification
//   Future<void> showNotification({
//     int id = 0,
//     String? title,
//     String? body,
//   }) async {
//     return notificationsPlugin.show(id, title, body, const NotificationDetails(),
//     );
//   }
//   //On noti tap
// }
