import 'package:flutter/material.dart';

import '../../../noise_monitoring/presentation/pages/monitoring_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../events/presentation/pages/events_dashboard_page.dart';
import '../../../noise_diary/presentation/noise_diary_page.dart';
import '../../../noise_history/presentation/noise_history_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    NoiseMonitoringPage(),
    NoiseHistoryPage(),
    EventsDashboardPage(),
    NoiseDiaryPage(),
    SettingsPage(),
  ];

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.mic),
      activeIcon: Icon(Icons.mic_none),
      label: 'Monitor',
      tooltip: 'Real-time noise monitoring',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.timeline),
      activeIcon: Icon(Icons.timeline),
      label: 'Verlauf',
      tooltip: 'Geräuschverlauf',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
      tooltip: 'Events and statistics',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.book_outlined),
      activeIcon: Icon(Icons.book),
      label: 'Tagebuch',
      tooltip: 'Persönliches Lärmtagebuch',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings_outlined),
      activeIcon: Icon(Icons.settings),
      label: 'Settings',
      tooltip: 'App settings and preferences',
    ),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Preserve history filters and the monitor's initial-start state. A tab
      // change must not recreate the monitor and restart an explicitly stopped
      // microphone, or briefly show the wrong selected destination.
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        elevation: 8,
        destinations: _navItems.map((item) {
          return NavigationDestination(
            icon: item.icon,
            selectedIcon: item.activeIcon,
            label: item.label!,
            tooltip: item.tooltip,
          );
        }).toList(),
      ),
    );
  }
}
