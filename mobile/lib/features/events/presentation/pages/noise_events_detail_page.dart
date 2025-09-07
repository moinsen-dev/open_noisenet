import 'package:flutter/material.dart';

import '../../../../widgets/shared_app_bar.dart';

class NoiseEventsDetailPage extends StatelessWidget {
  const NoiseEventsDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: SharedAppBar(
        pageTitle: 'Noise Events',
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_outlined,
                size: 80,
                color: Colors.orange,
              ),
              SizedBox(height: 16),
              Text(
                'Noise Events Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This page will show detailed information about noise events that exceeded your threshold settings.',
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