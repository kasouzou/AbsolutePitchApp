#  Absolute Pitch Viewer

リアルタイムで音を検出して、視覚的に音階を表示する Flutter 製のアプリです。

##  主な機能
- 周囲の音（声・楽器など）をリアルタイムに検出
- 音階（ドレミなど）を画面に大きく表示
- 音の履歴ログ表示（※予定）
- シンプルで見やすいUI
- オフラインでも動作
- Google Mobile Ads による広告表示

##  使用技術
- Flutter
- Dart
- Kotlin（Androidネイティブ部分）
- Gradle
- google_mobile_ads（広告プラグイン）

##  ビルドと実行

```bash
# パッケージを取得
flutter pub get

# エミュレータまたは接続した実機でデバッグ実行
flutter run

# リリース用ビルド（Android App Bundle）
flutter build appbundle --release
