import 'package:flutter/material.dart';
import 'package:flutter_fft/flutter_fft.dart';

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
  late FlutterFft flutterFft; // FFT解析用のインスタンス lateは初期化をあとで行う宣言（initStateで初期化）
  bool isRecording = false; // 録音中かどうか

  @override
  // initState()はAbsolutePitchViewer（StatefulWidget）という画面用のWidgetsが生成されるときに1回だけ呼ばれるメソッド
  void initState() {
    super.initState(); // super.initState()は必ず先頭で呼ぶ（Flutterのルール）
    flutterFft = FlutterFft(); // flutterFftをここで初期化
  }

  // // テスト用にボタンを押したら履歴に「ド」とか追加する仕組みなので実際に音をとるコードを書いたら消してOK！！
  // void addNoteToHistory(String note) {
  //   setState(() {
  //     currentNote = note;
  //     frequency = 440.0; // 仮の周波数
  //     noteHistory.add(note);
  //     if (noteHistory.length > 10) {
  //       noteHistory.removeAt(0);
  //     }
  //   });
  // }
  void startListening() async {
    await flutterFft.startRecorder();
    setState(() {
      isRecording = true;
    });

    flutterFft.onRecorderStateChanged.listen((dynamic data) {
      if (data != null && data["note"] != null && data["note"] != "") {
        String note = data["note"]; // "C", "D", etc...
        double freq = data["frequency"] ?? 0.0;

        // 日本語に変換（例: C → ド）
        String japaneseNote = convertNoteToJapanese(note);

        setState(() {
          currentNote = japaneseNote;
          frequency = freq;
          noteHistory.add(japaneseNote);
          if (noteHistory.length > 10) {
            noteHistory.removeAt(0);
          }
        });
      }
    });
  }

  void stopListening() async {
    await flutterFft.stopRecorder();
    setState(() {
      isRecording = false;
    });
  }

  String convertNoteToJapanese(String note) {
    switch (note) {
      case 'C':
        return 'ド';
      case 'D':
        return 'レ';
      case 'E':
        return 'ミ';
      case 'F':
        return 'ファ';
      case 'G':
        return 'ソ';
      case 'A':
        return 'ラ';
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
