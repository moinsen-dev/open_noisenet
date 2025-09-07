import 'package:flutter/material.dart';

import '../../../../widgets/shared_app_bar.dart';

class AnalysisResultsPage extends StatelessWidget {
  const AnalysisResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: SharedAppBar(
        pageTitle: 'Analysis Results',
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 80,
                color: Colors.purple,
              ),
              SizedBox(height: 16),
              Text(
                'AI Analysis Results',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This page will show results from AI analysis of audio recordings, including sound classification and pattern recognition.',
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