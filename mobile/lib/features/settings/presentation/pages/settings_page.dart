import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.dark_mode),
            title: Text('Dark Mode'),
            subtitle: Text('Toggle dark theme'),
            trailing: Switch(value: false, onChanged: null), // TODO: Implement
          ),
          const ListTile(
            leading: Icon(Icons.volume_up),
            title: Text('Audio Settings'),
            subtitle: Text('Configure audio capture'),
          ),
          const ListTile(
            leading: Icon(Icons.location_on),
            title: Text('Location Settings'),
            subtitle: Text('Manage location permissions'),
          ),
          const ListTile(
            leading: Icon(Icons.cloud_sync),
            title: Text('Sync Settings'),
            subtitle: Text('Configure data synchronization'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.privacy_tip),
            title: Text('Privacy Policy'),
          ),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('About'),
          ),
        ],
      ),
    );
  }
}