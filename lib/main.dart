import 'package:flutter/material.dart';
import 'package:waveform_fft/waveform_fft.dart';

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
  String currentNote = '...'; // 今の音階（最初は...で初期化）
  double frequency = 0.0; // 今の周波数
  List<String> noteHistory = []; // 音階の履歴（直近10件とか）
  late final WaveformFft
  waveformFft; // FFT解析用のインスタンス lateは初期化をあとで行う宣言（initStateで初期化）
  bool isRecording = false; // 録音中かどうか

  @override
  // initState()はAbsolutePitchViewer（StatefulWidget）という画面用のWidgetsが生成されるときに1回だけ呼ばれるメソッド
  void initState() {
    super.initState(); // super.initState()は必ず先頭で呼ぶ（Flutterのルール）
    waveformFft = WaveformFft(); // WaveformFftをここで初期化

    // noteを受取るストリームにリスナーをセット
    waveformFft.onNoteDetected.listen((note) {
      if (note != null && note != '') {
        String jpNote = convertNoteToJapanese(note);
        setState(() {
          currentNote = jpNote;
          noteHistory.add(jpNote);
          if (noteHistory.length > 10) {
            noteHistory.removeAt(0);
          }
        });
      }
    });

    // frequencyも受け取る
    waveformFft.onFrequencyDetected.listen((freq) {
      setState(() {
        frequency = freq ?? 0.0;
      });
    });
  }

  void startListening() async {
    await waveformFft.start();
    setState(() {
      isRecording = true;
    });
  }

  void stopListening() async {
    await waveformFft.stop();
    setState(() {
      isRecording = false;
    });
  }

  String convertNoteToJapanese(String note) {
    switch (note) {
      case 'C':
        return 'ド';
      case 'C#':
        return 'ド#';
      case 'D':
        return 'レ';
      case 'D#':
        return 'レ#';
      case 'E':
        return 'ミ';
      case 'F':
        return 'ファ';
      case 'F#':
        return 'ファ#';
      case 'G':
        return 'ソ';
      case 'G#':
        return 'ソ#';
      case 'A':
        return 'ラ';
      case 'A#':
        return 'ラ#';
      case 'B':
        return 'シ';
      default:
        return note;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('音階ビューア')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 600;
          final noteFontSize = isLargeScreen ? 100.0 : 80.0;
          final freqFontSize = isLargeScreen ? 32.0 : 24.0;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 音階履歴
                  NoteHistoryWidget(noteHistory: noteHistory),
                  const SizedBox(height: 24),

                  // 現在の音階
                  CurrentNoteWidget(note: currentNote, fontSize: noteFontSize),

                  const SizedBox(height: 16),

                  // 周波数表示
                  FrequencyWidget(frequency: frequency, fontSize: freqFontSize),

                  const SizedBox(height: 40),

                  // 操作ボタン
                  ControlButtonsWidget(
                    isRecording: isRecording,
                    onStart: startListening,
                    onStop: stopListening,
                  ),
                ],
              ),
            ),
          );
        },
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
  final VoidCallback onStart;
  final VoidCallback onStop;

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
