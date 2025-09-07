import 'package:flutter/material.dart';

import '../../../../widgets/shared_app_bar.dart';

class NoiseLevelsDetailPage extends StatelessWidget {
  const NoiseLevelsDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: SharedAppBar(
        pageTitle: 'Noise Levels',
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.volume_up_outlined,
                size: 80,
                color: Colors.blue,
              ),
              SizedBox(height: 16),
              Text(
                'Detailed Noise Levels',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This page will show comprehensive noise level analysis including hourly averages, peaks, and historical trends.',
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