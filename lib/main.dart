import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audio_streamer/audio_streamer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:isolate';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(const AbsolutePitchApp());

// isolate 側のエントリポイント
void pitchDetectIsolate(SendPort mainSendPort) {
  final port = ReceivePort();
  mainSendPort.send(port.sendPort);
  port.listen((message) async {
    final List<double> buffer = message[0];
    final SendPort replyPort = message[1];
    final detector = PitchDetector();
    final result = await detector.getPitchFromFloatBuffer(buffer);
    replyPort.send(result);
  });
}

Future<dynamic> detectPitchInIsolate(List<double> buffer) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(pitchDetectIsolate, receivePort.sendPort);
  final SendPort isolateSendPort = await receivePort.first;
  final responsePort = ReceivePort();
  isolateSendPort.send([buffer, responsePort.sendPort]);
  final result = await responsePort.first;
  return result;
}

class AbsolutePitchApp extends StatelessWidget {
  const AbsolutePitchApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<List<double>>? _audioSubscription;
  bool isRecording = false;
  String currentNote = '...';
  double frequency = 0.0;
  List<String> noteHistory = [];
  int? sampleRate;

  String? _lastPlayedNoteFile; // 直前に鳴らしたファイル名を保持して再生重複防止

  Future<bool> checkPermission() async => await Permission.microphone.isGranted;
  Future<void> requestPermission() async =>
      await Permission.microphone.request();

  void onAudio(List<double> buffer) async {
    if (sampleRate == null) {
      sampleRate = await _audioStreamer.actualSampleRate;
    }
    final result = await detectPitchInIsolate(buffer);

    if (result.pitched && result.pitch != null && result.pitch! > 0) {
      final freq = result.pitch!;
      final noteName = frequencyToNoteName(freq); // 例: "C4"
      final newNote = convertNoteToJapanese(noteName); // 例: "ド"

      // 再生用ファイル名は音名（半音つき）＋オクターブ＋拡張子
      final safeNoteName = noteName.replaceAll('#', 's');
      final audioFileName = '$safeNoteName.m4a';

      setState(() {
        frequency = freq;
        currentNote = newNote;

        if (noteHistory.isEmpty || noteHistory.last != newNote) {
          noteHistory.add(newNote);
          if (noteHistory.length > 10) noteHistory.removeAt(0);
        }
      });

      // 音が変わったときだけ音を鳴らす
      if (_lastPlayedNoteFile != audioFileName) {
        _lastPlayedNoteFile = audioFileName;
        // いったん停止してから再生（連続再生での重なり防止）
        await _audioPlayer.stop();
        try {
          await _audioPlayer.play(AssetSource('sounds/$audioFileName'));
        } catch (e) {
          // ファイルがない場合などの例外は無視
          debugPrint('Audio play error: $e');
        }
      }
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
    await _audioPlayer.stop();
    setState(() {
      isRecording = false;
      _lastPlayedNoteFile = null;
    });
  }

  void reset() {
    setState(() {
      noteHistory.clear();
      currentNote = '...';
      frequency = 0.0;
      _lastPlayedNoteFile = null;
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final orientation = MediaQuery.of(context).orientation;

    final currentNoteFontSize = (orientation == Orientation.portrait)
        ? screenHeight * 0.1
        : screenWidth * 0.08;
    final frequencyFontSize = (orientation == Orientation.portrait)
        ? screenHeight * 0.04
        : screenWidth * 0.03;

    final noteHistoryFontSize = (orientation == Orientation.portrait)
        ? 24.0
        : 20.0;

    return Scaffold(
      appBar: AppBar(title: const Text('絶対音感ビューア')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: (orientation == Orientation.portrait)
              ? SizedBox.expand(
                  child: Align(
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NoteHistoryWidget(
                            noteHistory: noteHistory,
                            fontSize: noteHistoryFontSize,
                          ),
                          const SizedBox(height: 24),
                          CurrentNoteWidget(
                            note: currentNote,
                            fontSize: currentNoteFontSize,
                          ),
                          const SizedBox(height: 16),
                          FrequencyWidget(
                            frequency: frequency,
                            fontSize: frequencyFontSize,
                          ),
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
                )
              : SingleChildScrollView(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            NoteHistoryWidget(
                              noteHistory: noteHistory,
                              fontSize: noteHistoryFontSize,
                            ),
                            const SizedBox(height: 16),
                            CurrentNoteWidget(
                              note: currentNote,
                              fontSize: currentNoteFontSize,
                            ),
                            const SizedBox(height: 8),
                            FrequencyWidget(
                              frequency: frequency,
                              fontSize: frequencyFontSize,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ControlButtonsWidget(
                              onStart: isRecording ? null : start,
                              onStop: isRecording ? stop : null,
                              onReset: reset,
                            ),
                          ],
                        ),
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
    _audioPlayer.dispose();
    super.dispose();
  }
}

class NoteHistoryWidget extends StatelessWidget {
  final List<String> noteHistory;
  final double fontSize;
  const NoteHistoryWidget({
    super.key,
    required this.noteHistory,
    this.fontSize = 24.0,
  });
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: noteHistory
            .map(
              (note) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(note, style: TextStyle(fontSize: fontSize)),
              ),
            )
            .toList(),
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
    return Wrap(
      spacing: 20.0,
      runSpacing: 10.0,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton(onPressed: onStart, child: const Text('録音開始')),
        ElevatedButton(onPressed: onStop, child: const Text('停止')),
        ElevatedButton(onPressed: onReset, child: const Text('リセット')),
      ],
    );
  }
}
