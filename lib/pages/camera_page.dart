import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

import 'musicplay_page.dart';
import '../repositories/sticker_repository.dart';

/// ===============================
/// 추론 결과 모델
/// ===============================
class InferenceResult {
  final String label;
  final double confidence;
  final double secondConfidence;

  InferenceResult(this.label, this.confidence, this.secondConfidence);
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  Interpreter? _interpreter;

  bool _cameraReady = false;
  bool _modelLoaded = false;

  XFile? _capturedImage;
  List<String> _labels = [];

  /// 🔗 인식 가능한 스티커만 등록
  final Map<String, String> stickerUrlMap = {
    'model_shooky1': 'https://youtu.be/GPrspUrmZj8',
    'model_tata1': 'https://youtu.be/5zVFVevvXbQ',
  };

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadModel();
  }

  /// ===============================
  /// 카메라 초기화
  /// ===============================
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    setState(() => _cameraReady = true);
  }

  /// ===============================
  /// 모델 로드
  /// ===============================
  Future<void> _loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/model.tflite');

    final labelData = await rootBundle.loadString('assets/labels.txt');
    _labels = labelData.split('\n').where((e) => e.isNotEmpty).toList();

    setState(() => _modelLoaded = true);
  }

  /// ===============================
  /// 사진 촬영
  /// ===============================
  Future<void> _takePicture() async {
    final image = await _controller!.takePicture();
    setState(() => _capturedImage = image);
  }

  void _retakePicture() {
    setState(() => _capturedImage = null);
  }

  /// ===============================
  /// 🔥 추론 (FLOAT32 입력)
  /// ===============================
  Future<InferenceResult> _runInference(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes)!;
    final resized = img.copyResize(image, width: 224, height: 224);

    /// ✅ UINT8 입력 버퍼 (정답)
    final Uint8List input = Uint8List(1 * 224 * 224 * 3);

    int index = 0;

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resized.getPixel(x, y);

        input[index++] = (pixel >> 16) & 0xFF; // R
        input[index++] = (pixel >> 8) & 0xFF;  // G
        input[index++] = pixel & 0xFF;         // B
      }
    }

    final output = List.generate(
      1,
          (_) => List.filled(_labels.length, 0),
    );

    _interpreter!.run(
      input.reshape([1, 224, 224, 3]),
      output,
    );

    final scores = output[0];

    /// UINT8 → 확률화 (0~255 → 0.0~1.0)
    final normalized =
    scores.map((e) => e / 255.0).toList();

    final sorted = List<double>.from(normalized)
      ..sort((b, a) => a.compareTo(b));

    final top1 = sorted[0];
    final top2 = sorted.length > 1 ? sorted[1] : 0.0;

    final indexLabel = normalized.indexOf(top1);
    final label = _labels[indexLabel].split(' ').last;

    return InferenceResult(label, top1, top2);
  }


  void _show(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('스티커 촬영')),
      body: _capturedImage == null
          ? CameraPreview(_controller!)
          : _buildPreview(),
      floatingActionButton: _capturedImage == null
          ? FloatingActionButton(
        onPressed: _takePicture,
        child: const Icon(Icons.camera_alt),
      )
          : null,
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(child: Image.file(File(_capturedImage!.path))),
        SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _retakePicture,
                child: const Text('재촬영'),
              ),
              ElevatedButton(
                onPressed: !_modelLoaded
                    ? null
                    : () async {
                  final result =
                  await _runInference(File(_capturedImage!.path));

                  if (result.confidence < 0.7) {
                    _show('신뢰도 부족', Colors.red);
                    return;
                  }

                  if (!stickerUrlMap.containsKey(result.label)) {
                    _show('등록되지 않은 스티커', Colors.red);
                    return;
                  }

                  await StickerRepository.add(
                    id: result.label,
                    label: result.label,
                    imageFile: File(_capturedImage!.path),
                    musicUrl: stickerUrlMap[result.label]!,
                  );

                  if (!mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MusicPlay(
                        url: stickerUrlMap[result.label]!,
                      ),
                    ),
                  );
                },
                child: const Text('확인'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _interpreter?.close();
    super.dispose();
  }
}
