import 'package:flutter/material.dart';

import '../../../../widgets/shared_app_bar.dart';

class StorageManagementPage extends StatelessWidget {
  const StorageManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: SharedAppBar(
        pageTitle: 'Storage Management',
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.storage_outlined,
                size: 80,
                color: Colors.brown,
              ),
              SizedBox(height: 16),
              Text(
                'Storage Management',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This page will provide detailed storage information and management options for your audio files and database.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                '🚧 Under Construction',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}