import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recording_state.dart';
import '../providers/recording_provider.dart';

class ModeSwitcher extends StatelessWidget {
  const ModeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, provider, _) {
        final isRecording = provider.state.isRecording;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: SegmentedButton<RecordingMode>(
            segments: const [
              ButtonSegment(
                value: RecordingMode.audio,
                icon: Icon(Icons.mic),
                label: Text('Audio'),
              ),
              ButtonSegment(
                value: RecordingMode.photo,
                icon: Icon(Icons.photo_camera),
                label: Text('Photo'),
              ),
              ButtonSegment(
                value: RecordingMode.video,
                icon: Icon(Icons.videocam),
                label: Text('Video'),
              ),
              ButtonSegment(
                value: RecordingMode.text,
                icon: Icon(Icons.text_snippet),
                label: Text('Text'),
              ),
            ],
            selected: {provider.state.mode},
            onSelectionChanged: isRecording
                ? null
                : (modes) {
                    provider.setMode(modes.first);
                  },
          ),
        );
      },
    );
  }
}
