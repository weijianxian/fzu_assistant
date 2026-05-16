import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/screen/home/schedule.dart';
import 'package:fzu_assistant/screen/my/my.dart';

const _pages = [
  SchedulePage(),
  MyPage(),
];

class HomeScreen extends HookWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPage = useState(0);

    return Scaffold(
      body: IndexedStack(
        index: currentPage.value,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentPage.value,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '课程表'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
        onTap: (i) => currentPage.value = i,
      ),
    );
  }
}
