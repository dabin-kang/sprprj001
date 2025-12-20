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

  // ✅ 수정: 키에서 "0 ", "1 " 제거
  final Map<String, String> stickerUrlMap = {
    'model_tata1': 'https://youtu.be/GPrspUrmZj8',
    'model_tata2': 'https://music.youtube.com/',
  };

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 CameraPage initState 시작');
    _initCamera();
    _loadModel();
  }

  /// 📷 카메라 초기화
  Future<void> _initCamera() async {
    try {
      debugPrint('📷 카메라 초기화 시작');
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
      debugPrint('✅ 카메라 초기화 성공');
    } catch (e) {
      debugPrint('❌ 카메라 초기화 실패: $e');
    }
  }
  Future<void> _loadModel() async {
    debugPrint('📦 모델 로드 시작');

    try {
      // 1️⃣ 모델 파일 로드
      debugPrint('   1️⃣ 모델 파일 로드 시도...');
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      debugPrint('   ✅ 모델 파일 로드 성공');

      // 🔎 [TEST 1] 입력 / 출력 텐서 구조 확인
      debugPrint('📐 입력 텐서: ${_interpreter!.getInputTensor(0).shape}');
      debugPrint('📐 출력 텐서: ${_interpreter!.getOutputTensor(0).shape}');

      // 2️⃣ 라벨 파일 로드
      debugPrint('   2️⃣ 라벨 파일 로드 시도...');
      final labelsData = await rootBundle.loadString('assets/labels.txt');

      _labels = labelsData
          .split('\n')
          .where((e) => e.trim().isNotEmpty)
          .toList();

      debugPrint('   ✅ 라벨 파일 로드 성공');
      debugPrint('   📋 라벨 목록: $_labels');

      // 🔎 [TEST 2] 가짜 입력으로 추론 테스트
      final testInput = List.generate(
        1,
            (_) => List.generate(
          224,
              (_) => List.generate(
            224,
                (_) => [0.0, 0.0, 0.0], // 검은 이미지
          ),
        ),
      );

      final testOutput =
      List.generate(1, (_) => List.filled(_labels.length, 0.0));

      _interpreter!.run(testInput, testOutput);

      debugPrint('🧪 테스트 추론 결과: ${testOutput[0]}');

      // 3️⃣ 상태 업데이트
      if (mounted) {
        setState(() {
          _modelLoaded = true;
        });

        debugPrint('   ✅ _modelLoaded = $_modelLoaded');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 모델 로드 및 테스트 완료'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      debugPrint('✅ 모델 로드 + 테스트 완료');

    } catch (e) {
      debugPrint('❌ 모델 로드 실패: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 모델 오류\n$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }



  /// 📸 사진 촬영
  Future<void> _takePicture() async {
    if (!_cameraReady) {
      debugPrint('⚠️  카메라가 준비되지 않음');
      return;
    }

    try {
      final image = await _controller!.takePicture();
      setState(() {
        _capturedImage = image;
      });
      debugPrint('✅ 사진 촬영 완료: ${image.path}');
    } catch (e) {
      debugPrint('❌ 사진 촬영 실패: $e');
    }
  }

  /// 🔄 재촬영
  void _retakePicture() {
    setState(() {
      _capturedImage = null;
    });
    debugPrint('🔄 재촬영 모드');
  }

  /// 🧠 추론
  Future<String> _runInference(File imageFile) async {
    debugPrint('🔥 추론 시작');
    debugPrint('   이미지: ${imageFile.path}');

    if (_interpreter == null || _labels.isEmpty) {
      throw Exception('모델이 아직 준비되지 않았습니다');
    }

    try {
      final bytes = await imageFile.readAsBytes();
      debugPrint('   이미지 크기: ${bytes.length} bytes');

      final original = img.decodeImage(bytes);
      if (original == null) {
        throw Exception('이미지 디코딩 실패');
      }
      debugPrint('   원본: ${original.width}x${original.height}');

      final resized = img.copyResize(original, width: 224, height: 224);
      debugPrint('   리사이즈: 224x224');

      final input = List.generate(
        1,
            (_) => List.generate(
          224,
              (y) => List.generate(
            224,
                (x) {
              final p = resized.getPixel(x, y);
              final r = (p >> 16) & 0xFF;
              final g = (p >> 8) & 0xFF;
              final b = p & 0xFF;

              return [r / 255.0, g / 255.0, b / 255.0];
            },
          ),
        ),
      );

      final output = List.generate(1, (_) => List.filled(_labels.length, 0.0));

      debugPrint('   추론 실행...');
      _interpreter!.run(input, output);

      final scores = output[0];
      debugPrint('   결과: $scores');

      final maxIndex = scores.indexOf(scores.reduce((a, b) => a > b ? a : b));
      final rawLabel = _labels[maxIndex];

      // ✅ 수정: 라벨에서 숫자 부분 제거
      final label = rawLabel.contains(' ')
          ? rawLabel.split(' ').last  // "0 model_tata1" → "model_tata1"
          : rawLabel;                 // "model_tata1" → "model_tata1"

      debugPrint('✅ 추론 완료');
      debugPrint('   원본 라벨: $rawLabel');
      debugPrint('   정제 라벨: $label');
      debugPrint('   신뢰도: ${(scores[maxIndex] * 100).toStringAsFixed(2)}%');

      return label;
    } catch (e) {
      debugPrint('❌ 추론 오류: $e');
      rethrow;
    }
  }

  /// 🔗 URL 실행
  Future<void> _openUrl(String label) async {
    debugPrint('🔗 URL 실행 시도');
    debugPrint('   라벨: $label');

    final url = stickerUrlMap[label];

    if (url == null) {
      debugPrint('❌ 등록되지 않은 스티커: $label');
      debugPrint('   등록된 스티커: ${stickerUrlMap.keys.toList()}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록되지 않은 스티커: $label')),
        );
      }
      return;
    }

    debugPrint('   URL: $url');

    final uri = Uri.parse(url);

    try {
      final canLaunch = await canLaunchUrl(uri);
      debugPrint('   canLaunchUrl: $canLaunch');

      if (!canLaunch) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('URL을 열 수 없습니다')),
          );
        }
        return;
      }

      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      debugPrint('   launchUrl: $success');

      if (success) {
        debugPrint('✅ URL 실행 성공!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('인식 완료: $label'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('앱 실행에 실패했습니다')),
        );
      }
    } catch (e) {
      debugPrint('❌ URL 실행 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _interpreter?.close();
    debugPrint('🗑️  리소스 정리');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraReady) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('카메라 초기화 중...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('스티커 촬영'),
        backgroundColor: Colors.deepPurple,
        actions: [
          // 모델 상태 표시
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _modelLoaded
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _modelLoaded ? Icons.check_circle : Icons.hourglass_empty,
                    color: _modelLoaded ? Colors.greenAccent : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _modelLoaded ? 'Ready' : 'Loading',
                    style: TextStyle(
                      fontSize: 11,
                      color: _modelLoaded ? Colors.greenAccent : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
        Container(
          color: Colors.black87,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 모델 로딩 중 표시
              if (!_modelLoaded)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '모델 로딩 중... 잠시 기다려주세요',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  ),
                ),

              // 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _retakePicture,
                    icon: const Icon(Icons.refresh),
                    label: const Text('재촬영'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _modelLoaded
                        ? () async {
                      debugPrint('🟢 확인 버튼 클릭');
                      debugPrint('   _modelLoaded = $_modelLoaded');

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('스티커 인식 중...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }

                      debugPrint('🟣 추론 시작');
                      try {
                        final label = await _runInference(
                          File(_capturedImage!.path),
                        );
                        await _openUrl(label);
                      } catch (e) {
                        debugPrint('❌ 오류: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('인식 실패: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                        : null,
                    icon: const Icon(Icons.check),
                    label: const Text('확인'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}