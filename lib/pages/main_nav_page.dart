import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/home/teacher_home.dart';
import 'package:flutter/foundation.dart';
import 'dev/api_console_page.dart';
import 'home/learner_home.dart';
// import 'home/teacher/teacher_home.dart';
import 'search/search_page.dart';
import 'notification/notification_page.dart';
import 'profile/profile_page.dart';

class MainNavPage extends StatefulWidget {
  const MainNavPage({super.key});

  @override
  State<MainNavPage> createState() => _MainNavPageState();
}

class _MainNavPageState extends State<MainNavPage> {
  int _currentIndex = 0;
  bool isLearner = true;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void toggleRole() {
    setState(() {
      isLearner = !isLearner;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      isLearner
          ? LearnerHomePage(onSwitch: toggleRole)
          : TeacherHomePage(onSwitch: toggleRole),
      const SearchPage(),
      const NotificationPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
            if (_currentIndex == 0) {
              isLearner = true;
            }
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Notification",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
      floatingActionButton: kReleaseMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ApiConsolePage()),
                );
              },
              icon: const Icon(Icons.terminal),
              label: const Text('API Console'),
            ),
    );
  }
}
