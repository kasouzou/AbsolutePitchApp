import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

void main() {
  runApp(const AbsolutePitchApp());
}

class AbsolutePitchApp extends StatelessWidget {
  const AbsolutePitchApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '音階ビューア',
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
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();
  late PitchDetector pitchDetector;

  bool isRecording = false;
  String currentNote = '...';
  double frequency = 0.0;
  List<String> noteHistory = [];

  final int bufferSize = 2048;
  final int sampleRate = 44100;

  @override
  void initState() {
    super.initState();
    pitchDetector = PitchDetector();
  }

  Float64List float32ToFloat64(Float32List inBuf) {
    final out = Float64List(inBuf.length);
    for (int i = 0; i < inBuf.length; i++) out[i] = inBuf[i].toDouble();
    return out;
  }

  void listener(dynamic obj) async {
    final float32 = obj as Float32List;
    final buffer = float32ToFloat64(float32);

    final result = await pitchDetector.getPitchFromFloatBuffer(buffer);
    if (result.pitched && result.pitch != null && result.pitch! > 0) {
      final freq = result.pitch!;
      final noteName = frequencyToNoteName(freq);
      setState(() {
        void listener(dynamic obj) async {
          final float32 = obj as Float32List;
          final buffer = float32ToFloat64(float32);

          final result = await pitchDetector.getPitchFromFloatBuffer(buffer);
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

        frequency = freq;
        currentNote = convertNoteToJapanese(noteName);
        noteHistory.add(currentNote);
        if (noteHistory.length > 10) noteHistory.removeAt(0);
      });
    }
  }

  void onError(Object e) {
    debugPrint('Audio capture error: $e');
  }

  Future<void> startListening() async {
    await _audioCapture.start(listener, onError, bufferSize: bufferSize);
    setState(() => isRecording = true);
  }

  Future<void> stopListening() async {
    await _audioCapture.stop();
    setState(() => isRecording = false);
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
      body: Padding(
        padding: const EdgeInsets.all(24),
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
              onStart: isRecording ? null : startListening,
              onStop: isRecording ? stopListening : null,
            ),
          ],
        ),
      ),
    );
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
  const ControlButtonsWidget({
    super.key,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(onPressed: onStart, child: const Text('録音開始')),
        const SizedBox(width: 20),
        ElevatedButton(onPressed: onStop, child: const Text('停止')),
      ],
    );
  }
}
