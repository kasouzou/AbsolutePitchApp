import 'package:flutter/material.dart';

void main() {
  runApp(const AbsolutePitchApp());
}

class AbsolutePitchApp extends StatelessWidget {

  const AbsolutePitchApp({super.key})

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: '絶対音感ビューア',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const AbsolutePitchViewer(),// 最初に表示する画面
    );
  }
}
// class AbsolutePitchApp extends StatelessWidget
// FlutterのUIは全部Widgetでできていて、
// その中でもStatelessWidgetは「内部状態（変数）を持たない」固定的なWidget静的なものというイメージで理解してる。
// 「AbsolutePitchApp」はクラス名 → 自由につけていい（ただしわかりやすい名前にしよう）
// このクラスの役割：
// → 「アプリ全体を構成するWidgetをまとめる」
// （テーマ設定、最初の画面などをここで定義）

// const AbsolutePitchApp({super.key})
// FlutterではWidgetを再利用・最適化するためにconstコンストラクタをつけるのが一般的
// super.keyは親クラス（StatelessWidget）のkeyパラメータをそのまま渡しているだけ
// → 画面更新やアニメーションの管理に使う内部的な仕組み

// @override Widget build(BuildContext context)
// UIを返す関数のことで、
// StatelessWidgetは必ずbuildメソッドを実装する必要がある
// contextは「今どの場所でこのWidgetをビルドしているか」という情報を持つ変数
// → テーマやメディアクエリなどを取るときに使う

// MaterialApp
// Flutterの「マテリアルデザイン」アプリ全体を包む最上位Widget
// ここでテーマ、タイトル、初期画面、ルーティングなどをまとめて設定する

// home: const AbsolutePitchViewer()
// アプリを起動したときに最初に表示する画面を設定
// AbsolutePitchViewerは自作のWidget（つまりメイン画面）

// theme: ThemeData(primarySwatch: Colors.indigo)
// アプリ全体のテーマカラーを設定
// ボタンやAppBarなどでこの色が自動的に使われるようになる

// title: '絶対音感ビューア'
// Androidのタスクスイッチャーに表示されるアプリ名などで使われる

class AbsolutePitchViewer extends StatefulWidget {
  const AbsolutePitchViewer({super.key});// 識別ID

  @override
  State<AbsolutePitchViewer> createState() => _AbsolutePitchViewerState();
}
// _AbsolutePitchViewerState↓はアプリを開いたときに最初に表示される画面であるAbsolutePitchViewerの中身の実装。
// 接頭にアンダースコア＿が付くのは、Javaでいう、プライベート（private）と同じ意味。このクラスファイルmain.dartないからだったら参照できるが、ほかのクラスファイルからは参照できないようにする。
class _AbsolutePitchViewerState extends State<AbsolutePitchViewer> {
  String currentNote = '...';// 現在の音階
  double frequency = 0.0; // frequencyは訳すと周波数
  List<String> noteHistory = []; // これまでに鳴った音階の履歴

  void addNoteToHistory(String note) {
    setState(() {
      currentNote = note;
      frequency = 440.0; // 仮の周波数
      noteHistory.add(note);
      if (noteHistory.length > 10) {
        noteHistory.removeAt(0);
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('絶対音感ビューア')),
      body:LayoutBuilder(
        builder: (context, constraints) { // constraintsを訳すと「制約」
          final isLargeScreen = constraints.maxWidth > 600;
          final noteFontSize = isLargeScreen ? 100.0 : 80.0;
          final freqFontSize = isLargeScreen ? 32.0 : 24.0;

          return Padding(
            padding: const EdgeInsets.all(24.0),
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
                  onStart: () {
                    addNoteToHistory('ド'); // 仮：ボタンで履歴追加
                  },
                  onStop: () {
                    // 停止処理（後で作る）
                  }
                ),
              ]
            ),
          );
        }
      ),
    );
  }
}

// 音階履歴UIの詳細UIを設計
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

// 現在の音階UIの詳細UIを設計
class CurrentNoteWidget extends StatelessWidget {
  final String note;
  final double fontSize;

  const CurrentNoteWidget({super.key, required this.note, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Text(
      note,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
    );
  }
}

// 周波数表示UIの詳細UIを設計
class FrequencyWidget extends StatelessWidget {
  final double frequency;
  final double fontSize;

  const FrequencyWidget({super.key, required this.frequency, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${frequency.toStringAsFixed(1)} Hz',
      style: TextStyle(fontSize: fontSize, color: Colors.grey[700]),
    );
  }
}