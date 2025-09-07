import 'package:flutter/material.dart';
import '../../../../core/database/models/audio_recording.dart';
import '../../../../widgets/audio_player_widget.dart';

class AudioPlayerPage extends StatelessWidget {
  final AudioRecording recording;

  const AudioPlayerPage({
    super.key,
    required this.recording,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noise Event Recording'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: AudioPlayerWidget(recording: recording),
      ),
    );
  }
}
