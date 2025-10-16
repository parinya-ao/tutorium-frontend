import 'package:flutter/material.dart';
import '../widgets/schedule_card.dart';
import '../../services/local_notification_service.dart';

class LearnerHomePage extends StatefulWidget {
  final VoidCallback onSwitch;
  const LearnerHomePage({super.key, required this.onSwitch});

  @override
  State<LearnerHomePage> createState() => _LearnerHomePageState();
}

class _LearnerHomePageState extends State<LearnerHomePage> {
  final _notificationService = LocalNotificationService();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    _scheduleNotificationsForClasses();
  }

  void _scheduleNotificationsForClasses() {
    final scheduleData = _getScheduleData();

    for (int i = 0; i < scheduleData.length; i++) {
      final item = scheduleData[i];
      final classStartTime = _parseDateTime(
        item['date'] as String,
        item['startTime'] as String,
      );

      // Schedule notifications only if class is in the future
      if (classStartTime.isAfter(DateTime.now())) {
        _notificationService.scheduleClassReminders(
          classStartTime: classStartTime,
          className: item['className'] as String,
          classSessionId: i + 1, // Use index as ID for demo
        );
      }
    }
  }

  DateTime _parseDateTime(String dateStr, String timeStr) {
    final date = DateTime.parse(dateStr);
    final timeParts = timeStr.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );
  }

  List<Map<String, dynamic>> _getScheduleData() {
    return [
      {
        'className': 'Guitar class by Jane',
        'enrolledLearner': 10,
        'teacherName': 'Jane Frost',
        'date': '2025-07-25',
        'startTime': '13:00',
        'endTime': '16:00',
        'imagePath': 'assets/images/guitar.jpg',
      },
      {
        'className': 'Piano class by Jane',
        'enrolledLearner': 10,
        'teacherName': 'Jane Frost',
        'date': '2025-07-26',
        'startTime': '13:00',
        'endTime': '16:00',
        'imagePath': 'assets/images/piano.jpg',
      },
      {
        'className': 'violin class by Jane',
        'enrolledLearner': 10,
        'teacherName': 'Jane Frost',
        'date': '2025-07-26',
        'startTime': '13:00',
        'endTime': '16:00',
        'imagePath': 'assets/images/violin.jpg',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheduleData = _getScheduleData();

    DateTime parseDate(String dateStr) => DateTime.parse(dateStr);
    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: const Text(
                "Learner Home",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 36.0,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Row(
                children: [
                  const Icon(
                    Icons.school_rounded,
                    color: Colors.amber,
                    size: 50,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.change_circle,
                      color: Colors.amber,
                      size: 50,
                    ),
                    onPressed: widget.onSwitch,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Upcoming Schedule",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24.0,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 3),
              Container(height: 2, width: 200, color: Colors.black),
              SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: scheduleData.length,
                  itemBuilder: (context, index) {
                    final item = scheduleData[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: ScheduleCard(
                        className: item['className'],
                        enrolledLearner: item['enrolledLearner'],
                        teacherName: item['teacherName'],
                        date: parseDate(item['date']),
                        startTime: parseTime(item['startTime']),
                        endTime: parseTime(item['endTime']),
                        imagePath: item['imagePath'],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
