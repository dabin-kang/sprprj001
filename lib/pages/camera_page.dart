import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  bool _cameraReady = false;

  XFile? _capturedImage;

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _modelLoaded = false;

  final Map<String, String> stickerUrlMap = {
    'model_tata1': 'https://youtu.be/GPrspUrmZj8',
    'model_tata2': 'https://music.youtube.com/',
  };

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadModel();
  }

  /// 📷 카메라 초기화
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();

    if (mounted) {
      setState(() {
        _cameraReady = true;
      });
    }
  }

  /// 🧠 모델 + 라벨 로드
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('model.tflite');

      final labelTxt =
      await rootBundle.loadString('assets/labels.txt');

      _labels = labelTxt
          .split('\n')
          .where((e) => e.trim().isNotEmpty)
          .toList();

      setState(() {
        _modelLoaded = true;
      });

      debugPrint('✅ 모델 로드 완료: $_labels');
    } catch (e) {
      debugPrint('❌ 모델 로드 실패: $e');
    }
  }

  /// 📸 사진 촬영
  Future<void> _takePicture() async {
    if (!_cameraReady) return;

    final image = await _controller!.takePicture();
    setState(() {
      _capturedImage = image;
    });
  }

  /// 🔄 재촬영
  void _retakePicture() {
    setState(() {
      _capturedImage = null;
    });
  }

  /// 🧠 추론
  Future<String> _runInference(File imageFile) async {
    if (_interpreter == null || _labels.isEmpty) {
      throw Exception('모델이 아직 준비되지 않았습니다');
    }

    final bytes = await imageFile.readAsBytes();
    final original = img.decodeImage(bytes);

    if (original == null) {
      throw Exception('이미지 디코딩 실패');
    }

    final resized = img.copyResize(original, width: 224, height: 224);

    final input = List.generate(
      1,
          (_) => List.generate(
        224,
            (y) => List.generate(
          224,
              (x) {
            final p = resized.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          },
        ),
      ),
    );

    final output =
    List.generate(1, (_) => List.filled(_labels.length, 0.0));

    _interpreter!.run(input, output);

    final scores = output[0];
    final maxIndex =
    scores.indexOf(scores.reduce((a, b) => a > b ? a : b));

    debugPrint('✅ 추론 완료: ${_labels[maxIndex]}');
    return _labels[maxIndex];

  }

  /// 🔗 URL 실행
  Future<void> _openUrl(String label) async {
    final url = stickerUrlMap[label];

    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록되지 않은 스티커: $label')),
      );
      return;
    }

    final uri = Uri.parse(url);

    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('URL을 열 수 없습니다')),
      );
      return;
    }

    final success = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('앱 실행에 실패했습니다')),
      );
    }
  }


  @override
  void dispose() {
    _controller?.dispose();
    _interpreter?.close();
    super.dispose();
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
        backgroundColor: Colors.deepPurple,
        onPressed: _takePicture,
        child: const Icon(Icons.camera_alt),
      )
          : null,
    );
  }

  /// 🖼 미리보기 + 인식 버튼
  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: Image.file(
            File(_capturedImage!.path),
            fit: BoxFit.contain,
          ),
        ),
        Padding(
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
                onPressed: () async {
                  if (!_modelLoaded) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('모델 로딩 중입니다'),
                      ),
                    );
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('스티커 인식 중...')),
                  );

                  try {
                    final label = await _runInference(
                      File(_capturedImage!.path),
                    );
                    await _openUrl(label);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('인식 실패: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('확인'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
