import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audio_streamer/audio_streamer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

void main() => runApp(const AbsolutePitchApp());

class AbsolutePitchApp extends StatelessWidget {
  const AbsolutePitchApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '絶対音感ビューア',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const AbsolutePitchViewer(),
    );
  }
}

class AbsolutePitchViewer extends StatefulWidget {
  const AbsolutePitchViewer({super.key});
  @override
  State<AbsolutePitchViewer> createState() => _AbsolutePitchViewerState();
}

class _AbsolutePitchViewerState extends State<AbsolutePitchViewer> {
  final AudioStreamer _audioStreamer = AudioStreamer();
  final PitchDetector _pitchDetector = PitchDetector();

  StreamSubscription<List<double>>? _audioSubscription;
  bool isRecording = false;
  String currentNote = '...';
  double frequency = 0.0;
  List<String> noteHistory = [];
  int? sampleRate;

  Future<bool> checkPermission() async => await Permission.microphone.isGranted;
  Future<void> requestPermission() async =>
      await Permission.microphone.request();

  void onAudio(List<double> buffer) async {
    if (sampleRate == null) {
      sampleRate = await _audioStreamer.actualSampleRate;
    }
    final result = await _pitchDetector.getPitchFromFloatBuffer(buffer);
    if (result.pitched && result.pitch != null && result.pitch! > 0) {
      final freq = result.pitch!;
      final noteName = frequencyToNoteName(freq);
      setState(() {
        frequency = freq;
        currentNote = convertNoteToJapanese(noteName);
        noteHistory.add(currentNote);
        if (noteHistory.length > 10) noteHistory.removeAt(0);
      });
    }
  }

  void handleError(Object error) {
    debugPrint('Error: $error');
    setState(() => isRecording = false);
  }

  void start() async {
    if (!(await checkPermission())) {
      await requestPermission();
    }
    _audioStreamer.sampleRate = 44100;
    _audioSubscription = _audioStreamer.audioStream.listen(
      onAudio,
      onError: handleError,
    );
    setState(() => isRecording = true);
  }

  void stop() async {
    await _audioSubscription?.cancel();
    setState(() => isRecording = false);
  }

  void reset() {
    setState(() {
      noteHistory.clear();
      currentNote = '...';
      frequency = 0.0;
    });
  }

  String frequencyToNoteName(double freq) {
    const A4 = 440.0;
    const names = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final semis = (12 * (log(freq / A4) / log(2))).round();
    int idx = (semis + 9) % 12;
    if (idx < 0) idx += 12;
    final oct = 4 + ((semis + 9) ~/ 12);
    return '${names[idx]}$oct';
  }

  String convertNoteToJapanese(String note) {
    final base = note.replaceAll(RegExp(r'\d'), '');
    switch (base) {
      case 'C':
        return 'ド';
      case 'C#':
        return 'ド♯';
      case 'D':
        return 'レ';
      case 'D#':
        return 'レ♯';
      case 'E':
        return 'ミ';
      case 'F':
        return 'ファ';
      case 'F#':
        return 'ファ♯';
      case 'G':
        return 'ソ';
      case 'G#':
        return 'ソ♯';
      case 'A':
        return 'ラ';
      case 'A#':
        return 'ラ♯';
      case 'B':
        return 'シ';
      default:
        return note;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('絶対音感ビューア')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NoteHistoryWidget(noteHistory: noteHistory),
                const SizedBox(height: 24),
                CurrentNoteWidget(note: currentNote, fontSize: 80),
                const SizedBox(height: 16),
                FrequencyWidget(frequency: frequency, fontSize: 24),
                const SizedBox(height: 40),
                ControlButtonsWidget(
                  onStart: isRecording ? null : start,
                  onStop: isRecording ? stop : null,
                  onReset: reset,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    super.dispose();
  }
}

class NoteHistoryWidget extends StatelessWidget {
  final List<String> noteHistory;
  const NoteHistoryWidget({super.key, required this.noteHistory});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: noteHistory.map((note) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(note, style: const TextStyle(fontSize: 24)),
          );
        }).toList(),
      ),
    );
  }
}

class CurrentNoteWidget extends StatelessWidget {
  final String note;
  final double fontSize;
  const CurrentNoteWidget({
    super.key,
    required this.note,
    required this.fontSize,
  });
  @override
  Widget build(BuildContext context) {
    return Text(
      note,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
    );
  }
}

class FrequencyWidget extends StatelessWidget {
  final double frequency;
  final double fontSize;
  const FrequencyWidget({
    super.key,
    required this.frequency,
    required this.fontSize,
  });
  @override
  Widget build(BuildContext context) {
    return Text(
      '${frequency.toStringAsFixed(1)} Hz',
      style: TextStyle(fontSize: fontSize, color: Colors.grey[700]),
    );
  }
}

class ControlButtonsWidget extends StatelessWidget {
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final VoidCallback? onReset;

  const ControlButtonsWidget({
    super.key,
    this.onStart,
    this.onStop,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(onPressed: onStart, child: const Text('録音開始')),
        const SizedBox(width: 20),
        ElevatedButton(onPressed: onStop, child: const Text('停止')),
        const SizedBox(width: 20),
        ElevatedButton(onPressed: onReset, child: const Text('リセット')),
      ],
    );
  }
}
