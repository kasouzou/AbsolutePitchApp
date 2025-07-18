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
        if (noteHistory.length > 10) noteHistory.removeAt(0); // 最新10件を保持
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
    _audioStreamer.sampleRate = 44100; // サンプルレートを設定
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
    // 音の周波数から半音数を計算
    final semis = (12 * (log(freq / A4) / log(2))).round();
    // 半音数から音名インデックスを計算
    int idx = (semis + 9) % 12; // Cを0とするインデックス
    if (idx < 0) idx += 12; // 負の値にならないように調整
    // オクターブを計算
    final oct = 4 + ((semis + 9) ~/ 12);
    return '${names[idx]}$oct';
  }

  String convertNoteToJapanese(String note) {
    final base = note.replaceAll(RegExp(r'\d'), ''); // オクターブ部分を削除
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
        return note; // マッチしない場合はそのまま返す
    }
  }

  @override
  Widget build(BuildContext context) {
    // 画面の高さと幅、向きを取得
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final orientation = MediaQuery.of(context).orientation;

    // 画面の向きによってフォントサイズを動的に計算
    final currentNoteFontSize = (orientation == Orientation.portrait)
        ? screenHeight *
              0.1 // 縦向きの場合
        : screenWidth * 0.08; // 横向きの場合（画面幅に対して小さめに調整）
    final frequencyFontSize = (orientation == Orientation.portrait)
        ? screenHeight *
              0.04 // 縦向きの場合
        : screenWidth * 0.03; // 横向きの場合（画面幅に対して小さめに調整）

    // 横向きの場合は、NoteHistoryWidgetのフォントサイズも少し小さくして、他の情報とのバランスをとる
    final noteHistoryFontSize = (orientation == Orientation.portrait)
        ? 24.0
        : 20.0;

    return Scaffold(
      appBar: AppBar(title: const Text('絶対音感ビューア')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          // 画面の向きによってレイアウトを切り替える
          child: (orientation == Orientation.portrait)
              ? SizedBox.expand(
                  // 縦画面の場合、利用可能なスペース全体に広がる
                  child: Align(
                    // その中でコンテンツを中央に配置
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      // コンテンツが多すぎたらスクロール
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, // 縦方向に中央寄せ
                        mainAxisSize: MainAxisSize.min, // コンテンツサイズに合わせる
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
                  // 横向きのレイアウトは変わらず
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly, // 要素を均等に配置
                    crossAxisAlignment: CrossAxisAlignment.center, // 垂直方向の中央寄せ
                    children: [
                      // 左側の情報（履歴と現在の音）
                      Expanded(
                        // 使えるスペースを最大限に使う
                        flex: 2, // 左右の比率を調整できる（例: 左が右の2倍の幅）
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center, // 縦方向に中央寄せ
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
                      const SizedBox(width: 24), // 左右のセクションの間にスペース
                      // 右側のコントロールボタン
                      Expanded(
                        flex: 1, // ボタンセクションは左側より小さくする
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center, // ボタンを縦方向に中央寄せ
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
    _audioSubscription?.cancel(); // ウィジェットが破棄されるときに購読をキャンセル
    super.dispose();
  }
}

class NoteHistoryWidget extends StatelessWidget {
  final List<String> noteHistory;
  final double fontSize; // フォントサイズを受け取るように変更
  const NoteHistoryWidget({
    super.key,
    required this.noteHistory,
    this.fontSize = 24.0,
  }); // デフォルト値を設定
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, // 横方向にスクロール可能
      child: Row(
        children: noteHistory.map((note) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              note,
              style: TextStyle(fontSize: fontSize),
            ), // 受け取ったフォントサイズを使用
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
      '${frequency.toStringAsFixed(1)} Hz', // 周波数を小数点以下1桁で表示
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
    // Wrap を使うことで、画面幅が足りないときに自動で折り返してくれる
    return Wrap(
      spacing: 20.0, // ボタン間の水平方向のスペース
      runSpacing: 10.0, // 折り返した際の垂直方向のスペース
      alignment: WrapAlignment.center, // ボタンを中央に寄せる
      children: [
        ElevatedButton(onPressed: onStart, child: const Text('録音開始')),
        ElevatedButton(onPressed: onStop, child: const Text('停止')),
        ElevatedButton(onPressed: onReset, child: const Text('リセット')),
      ],
    );
  }
}
