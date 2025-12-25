import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';
import 'musicplay_page.dart';
import '../models/sticker_model.dart';
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

  /// 🔗 스티커 → URL
  final Map<String, String> stickerUrlMap = {
    'model_shooky1': 'https://youtu.be/GPrspUrmZj8',
    'model_tata1': 'https://youtu.be/5zVFVevvXbQ?si=999mGrMSzgnu56FP/',
    'background' : 'https://youtu.be/4oMdAM5x3nM?si=6UzOHCkNL3CdWBHA',
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
    _labels = labelData
        .split('\n')
        .where((e) => e.trim().isNotEmpty)
        .toList();

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
  /// 🔥 핵심 추론 로직
  /// ===============================
  Future<InferenceResult> _runInference(File file) async {
    final bytes = await file.readAsBytes();
    final original = img.decodeImage(bytes)!;
    final resized = img.copyResize(original, width: 224, height: 224);

    final input = List.generate(
      1,
          (_) => List.generate(
        224,
            (y) => List.generate(
          224,
              (x) {
            final p = resized.getPixel(x, y);
            return [
              (p >> 16) & 0xFF,
              (p >> 8) & 0xFF,
              p & 0xFF,
            ];
          },
        ),
      ),
    );

    // 🔹 output tensor 정보 가져오기
    final outputTensor = _interpreter!.getOutputTensor(0);
    final scale = outputTensor.params.scale;
    final zeroPoint = outputTensor.params.zeroPoint;

    // 🔹 실제 모델 출력 클래스 수
    final outputSize = outputTensor.shape[1];

// 🔹 uint8 출력 버퍼
    final output = List.generate(
      1,
          (_) => List.filled(_labels.length, 0),
    );

// 🔹 추론 실행
    _interpreter!.run(input, output);

// 🔹 uint8 → float 복원
    final scores = output[0]
        .map<double>((v) => (v - zeroPoint) * scale)
        .toList();
    final sorted = List<double>.from(scores)..sort((b, a) => a.compareTo(b));

    final top1 = sorted[0];
    final top2 = sorted[1];
    final index = scores.indexOf(top1);

    final rawLabel = _labels[index];
    final label = rawLabel.contains(' ')
        ? rawLabel.split(' ').last
        : rawLabel;

    return InferenceResult(label, top1, top2);
  }

  /// ===============================
  /// URL 실행
  /// ===============================
  Future<void> _openUrl(String label) async {
    final url = stickerUrlMap[label];
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
      appBar: AppBar(
        title: const Text('스티커 촬영'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _capturedImage == null
          ? CameraPreview(_controller!)
          : _buildPreview(),
      floatingActionButton: _capturedImage == null
          ? FloatingActionButton(
        onPressed: _takePicture,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.camera_alt),
      )
          : null,
    );
  }

  /// ===============================
  /// 미리보기 + 확인 버튼
  /// ===============================
  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: Image.file(File(_capturedImage!.path)),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _retakePicture,
                  icon: const Icon(Icons.refresh),
                  label: const Text('재촬영'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('확인'),
                  onPressed: !_modelLoaded
                      ? null
                      : () async {
                    final result = await _runInference(
                      File(_capturedImage!.path),
                    );

                    if (result.label == 'background') {
                      _show('인식 대상이 아닙니다', Colors.orange);
                      return;
                    }

                    if (result.confidence < 0.7) {
                      _show(
                        '신뢰도 부족 (${(result.confidence * 100).toStringAsFixed(1)}%)',
                        Colors.red,
                      );
                      return;
                    }

                    if ((result.confidence - result.secondConfidence) < 0.25) {
                      _show('명확하지 않은 인식입니다', Colors.orange);
                      return;
                    }

                    if (!stickerUrlMap.containsKey(result.label)) {
                      _show('등록되지 않은 스티커', Colors.red);
                      return;
                    }
                    final sticker = StickerModel(
                      id: result.label,
                      label: result.label,
                      imagePath: _capturedImage!.path,
                      musicUrl: stickerUrlMap[result.label]!,
                      collectedAt: DateTime.now(),
                    );



// 🔥 수집
                    await StickerRepository.add(sticker);

// ▶ 음악 재생 페이지 이동


                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MusicPlay(
                          url: stickerUrlMap[result.label]!,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
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
