// main.dart
// SPR (Sticker Playlist Recorder) - TFLite Model Applied Version
// 모델: model.tflite + labels.txt
// 기능: 카메라 촬영 → 이미지 분류(스티커 인식) → 자동 플레이리스트 매칭 → 수집

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const SPRApp());
}

class SPRApp extends StatelessWidget {
  const SPRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SPR',
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

// ----------------------
// 데이터 모델
// ----------------------
class StickerItem {
  final File image;
  final String label;
  final String playlistUrl;

  StickerItem({required this.image, required this.label, required this.playlistUrl});
}

// ----------------------
// 홈
// ----------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<StickerItem> stickers = [];

  void addSticker(StickerItem item) {
    setState(() => stickers.add(item));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SPR · Sticker Playlist')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.camera_alt),
        onPressed: () async {
          final result = await Navigator.push<StickerItem>(
            context,
            MaterialPageRoute(builder: (_) => const CameraPage()),
          );
          if (result != null) addSticker(result);
        },
      ),
      body: stickers.isEmpty
          ? const Center(child: Text('스티커를 촬영해 수집하세요'))
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
        itemCount: stickers.length,
        itemBuilder: (context, i) {
          final item = stickers[i];
          return Card(
            child: Column(children: [
              Expanded(child: Image.file(item.image, fit: BoxFit.cover)),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ----------------------
// 카메라 + 모델 추론
// ----------------------
class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  // label → 실제 플레이리스트 매핑
  final Map<String, String> playlistMap = {
    'model_tata1': 'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M',
    'model_tata2': 'https://music.youtube.com/playlist?list=PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI',
  };

  Interpreter? interpreter;
  List<String> labels = ['model_tata1', 'model_tata2'];
  File? image;
  String? resultLabel;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    interpreter = await Interpreter.fromAsset('model.tflite');
  }

  Future<void> pickAndPredict() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    final imgFile = File(picked.path);
    final input = preprocessImage(imgFile);
    final output = List.filled(labels.length, 0.0).reshape([1, labels.length]);

    interpreter!.run(input, output);

    int maxIndex = output[0].indexOf(output[0].reduce((a, b) => a > b ? a : b));

    setState(() {
      image = imgFile;
      resultLabel = labels[maxIndex];
    });
  }

  Uint8List preprocessImage(File file) {
    final bytes = file.readAsBytesSync();
    img.Image image = img.decodeImage(bytes)!;
    image = img.copyResize(image, width: 224, height: 224);

    final buffer = Float32List(224 * 224 * 3);
    int index = 0;
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = image.getPixel(x, y);
        buffer[index++] = img.getRed(pixel) / 255.0;
        buffer[index++] = img.getGreen(pixel) / 255.0;
        buffer[index++] = img.getBlue(pixel) / 255.0;
      }
    }
    return buffer.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스티커 인식')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          ElevatedButton.icon(
            onPressed: pickAndPredict,
            icon: const Icon(Icons.camera_alt),
            label: const Text('촬영 & 인식'),
          ),
          const SizedBox(height: 16),
          if (image != null) Image.file(image!, height: 200),
          if (resultLabel != null) ...[
            const SizedBox(height: 12),
            Text('인식 결과: $resultLabel', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  StickerItem(
                      image: image!,
                      label: resultLabel!,
                      playlistUrl: playlistMap[resultLabel] ?? ''
                  ),
                );
              },
              child: const Text('수집하기'),
            ),
          ]
        ]),
      ),
    );
  }
}
