import 'package:flutter/material.dart';

import '../../../noise_monitoring/presentation/pages/monitoring_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../events/presentation/pages/events_dashboard_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  static const List<Widget> _pages = [
    NoiseMonitoringPage(),
    EventsDashboardPage(),
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
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
      tooltip: 'Events and statistics',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings_outlined),
      activeIcon: Icon(Icons.settings),
      label: 'Settings',
      tooltip: 'App settings and preferences',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
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