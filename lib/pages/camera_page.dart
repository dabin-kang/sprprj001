// 필요한 패키지들을 불러옵니다
import 'dart:io'; // 파일 시스템 작업을 위한 패키지 (File 클래스 사용)
import 'package:flutter/material.dart'; // Flutter UI 구성 요소
import 'package:camera/camera.dart'; // 카메라 기능 사용
import 'package:flutter/services.dart'; // 앱 리소스(assets) 접근
import 'package:tflite_flutter/tflite_flutter.dart'; // TensorFlow Lite 모델 실행
import 'package:image/image.dart' as img; // 이미지 처리 (리사이즈 등)
import 'package:url_launcher/url_launcher.dart'; // URL/앱 실행

// CameraPage: 사용자가 보는 화면 위젯 (StatefulWidget = 상태가 변하는 위젯)
class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

// _CameraPageState: CameraPage의 실제 동작과 상태를 관리하는 클래스
class _CameraPageState extends State<CameraPage> {

  // ========================================
  // 📌 상태 변수들 (이 앱이 기억해야 할 정보들)
  // ========================================

  CameraController? _controller; // 카메라를 제어하는 객체 (null일 수 있음)
  bool _cameraReady = false; // 카메라가 준비되었는지 여부
  XFile? _capturedImage; // 촬영한 사진 파일 (null = 아직 촬영 안함)
  Interpreter? _interpreter; // AI 모델을 실행하는 객체
  List<String> _labels = []; // AI 모델이 인식할 수 있는 라벨 목록 (예: "model_tata1")
  bool _modelLoaded = false; // AI 모델이 로드되었는지 여부

  // 스티커 라벨과 연결된 URL 맵 (딕셔너리)
  // 주의: 'background'는 스티커가 아니므로 URL 없음
  final Map<String, String> stickerUrlMap = {
    'model_tata1': 'https://youtu.be/GPrspUrmZj8',
    'model_tata2': 'https://music.youtube.com/',
  };

  // ========================================
  // 🚀 initState: 화면이 처음 생성될 때 자동으로 실행
  // ========================================
  @override
  void initState() {
    super.initState();
    debugPrint('🚀 CameraPage initState 시작'); // 콘솔에 로그 출력
    _initCamera(); // 카메라 초기화 시작
    _loadModel(); // AI 모델 로드 시작
  }

  // ========================================
  // 📷 _initCamera: 카메라를 초기화하는 함수
  // ========================================
  Future<void> _initCamera() async {
    try {
      debugPrint('📷 카메라 초기화 시작');

      // 1단계: 사용 가능한 카메라 목록 가져오기
      final cameras = await availableCameras();

      // 2단계: 첫 번째 카메라(보통 후면 카메라)로 컨트롤러 생성
      _controller = CameraController(
        cameras.first, // 첫 번째 카메라 사용
        ResolutionPreset.high, // 고화질 설정
        enableAudio: false, // 오디오 녹음 끄기
      );

      // 3단계: 카메라 초기화 실행 (비동기 작업이므로 await)
      await _controller!.initialize();

      // 4단계: 화면이 아직 살아있으면 상태 업데이트
      if (mounted) {
        setState(() {
          _cameraReady = true; // 카메라 준비 완료 표시
        });
      }

      debugPrint('✅ 카메라 초기화 성공');
    } catch (e) {
      // 오류 발생 시 콘솔에 출력
      debugPrint('❌ 카메라 초기화 실패: $e');
    }
  }

  // ========================================
  // 📦 _loadModel: AI 모델과 라벨 파일을 로드하는 함수
  // ========================================
  Future<void> _loadModel() async {
    debugPrint('📦 모델 로드 시작');

    try {
      // ============================================
      // 1️⃣ AI 모델 파일 로드 (assets/model.tflite)
      // ============================================
      debugPrint('  1️⃣ 모델 파일 로드 시도...');
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      debugPrint('  ✅ 모델 파일 로드 성공');

      // 🔎 [디버깅용] 입력/출력 텐서 구조 확인
      // 입력: 이미지 크기 확인 (보통 [1, 224, 224, 3])
      debugPrint('📐 입력 텐서: ${_interpreter!.getInputTensor(0).shape}');
      // 출력: 클래스 개수 확인 (보통 [1, 3] = 3개 클래스)
      debugPrint('📐 출력 텐서: ${_interpreter!.getOutputTensor(0).shape}');

      // ============================================
      // 2️⃣ 라벨 파일 로드 (assets/labels.txt)
      // ============================================
      debugPrint('  2️⃣ 라벨 파일 로드 시도...');

      // labels.txt 파일을 문자열로 읽기
      final labelsData = await rootBundle.loadString('assets/labels.txt');

      // 줄바꿈으로 분리하고, 빈 줄 제거
      _labels = labelsData
          .split('\n') // 줄바꿈으로 분리
          .where((e) => e.trim().isNotEmpty) // 빈 줄 제거
          .toList();

      debugPrint('  ✅ 라벨 파일 로드 성공');
      debugPrint('  📋 라벨 목록: $_labels');

      // ============================================
      // 🔎 [테스트] 가짜 이미지로 모델 테스트
      // ============================================

      // 검은색 이미지 생성 (1장, 224x224, RGB 3채널)
      final testInput = List.generate(
        1, // 배치 크기 = 1장
            (_) => List.generate(
          224, // 세로 224픽셀
              (_) => List.generate(
            224, // 가로 224픽셀
                (_) => [0.0, 0.0, 0.0], // RGB 값 (검은색 = 0, 0, 0)
          ),
        ),
      );

      // 출력 결과를 받을 배열 생성 (클래스 개수만큼)
      final testOutput = List.generate(1, (_) => List.filled(_labels.length, 0.0));

      // 실제 추론 실행 (모델이 제대로 작동하는지 확인)
      _interpreter!.run(testInput, testOutput);
      debugPrint('🧪 테스트 추론 결과: ${testOutput[0]}');

      // ============================================
      // 3️⃣ 상태 업데이트 및 사용자에게 알림
      // ============================================
      if (mounted) {
        setState(() {
          _modelLoaded = true; // 모델 로드 완료 표시
        });
        debugPrint('  ✅ _modelLoaded = $_modelLoaded');

        // 화면 하단에 초록색 성공 메시지 표시
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
      // 오류 발생 시 처리
      debugPrint('❌ 모델 로드 실패: $e');

      if (mounted) {
        // 화면 하단에 빨간색 오류 메시지 표시
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

  // ========================================
  // 📸 _takePicture: 사진을 촬영하는 함수
  // ========================================
  Future<void> _takePicture() async {
    // 카메라가 준비되지 않았으면 함수 종료
    if (!_cameraReady) {
      debugPrint('⚠️ 카메라가 준비되지 않음');
      return;
    }

    try {
      // 카메라로 사진 촬영
      final image = await _controller!.takePicture();

      // 촬영한 사진을 상태에 저장 (화면 업데이트)
      setState(() {
        _capturedImage = image;
      });

      debugPrint('✅ 사진 촬영 완료: ${image.path}');
    } catch (e) {
      debugPrint('❌ 사진 촬영 실패: $e');
    }
  }

  // ========================================
  // 🔄 _retakePicture: 재촬영 버튼 (사진 삭제)
  // ========================================
  void _retakePicture() {
    setState(() {
      _capturedImage = null; // 촬영한 사진을 null로 만듦 → 카메라 프리뷰로 돌아감
    });
    debugPrint('🔄 재촬영 모드');
  }

  // ========================================
  // 🧠 _runInference: AI 모델로 이미지 인식하는 함수
  // ========================================
  Future<String> _runInference(File imageFile) async {
    debugPrint('🔥 추론 시작');
    debugPrint('  이미지: ${imageFile.path}');

    // 모델이나 라벨이 없으면 오류 발생
    if (_interpreter == null || _labels.isEmpty) {
      throw Exception('모델이 아직 준비되지 않았습니다');
    }

    try {
      // ============================================
      // 1단계: 이미지 파일을 바이트로 읽기
      // ============================================
      final bytes = await imageFile.readAsBytes();
      debugPrint('  이미지 크기: ${bytes.length} bytes');

      // ============================================
      // 2단계: 이미지 디코딩 (바이트 → 이미지 객체)
      // ============================================
      final original = img.decodeImage(bytes);
      if (original == null) {
        throw Exception('이미지 디코딩 실패');
      }
      debugPrint('  원본: ${original.width}x${original.height}');

      // ============================================
      // 3단계: 이미지 크기를 224x224로 조정
      // (AI 모델은 정해진 크기의 입력만 받음)
      // ============================================
      final resized = img.copyResize(original, width: 224, height: 224);
      debugPrint('  리사이즈: 224x224');

      // ============================================
      // 4단계: 이미지를 모델 입력 형식으로 변환
      // [1, 224, 224, 3] 형태의 4차원 배열
      // ============================================
      final input = List.generate(
        1, // 배치 크기 = 1장
            (_) => List.generate(
          224, // 세로 224픽셀
              (y) => List.generate(
            224, // 가로 224픽셀
                (x) {
              // (x, y) 위치의 픽셀 색상 가져오기
              final p = resized.getPixel(x, y);

              // 픽셀에서 RGB 값 추출 (비트 연산)
              final r = (p >> 16) & 0xFF; // 빨강 (0~255)
              final g = (p >> 8) & 0xFF;  // 초록 (0~255)
              final b = p & 0xFF;         // 파랑 (0~255)

              // RGB 값을 0.0~1.0 사이로 정규화 (AI 모델은 이 범위를 선호)
              return [r / 255.0, g / 255.0, b / 255.0];
            },
          ),
        ),
      );

      // ============================================
      // 5단계: 출력 결과를 받을 배열 생성
      // [1, 라벨개수] 형태 (예: [1, 3])
      // ============================================
      final output = List.generate(1, (_) => List.filled(_labels.length, 0.0));

      // ============================================
      // 6단계: 실제 AI 추론 실행
      // ============================================
      debugPrint('  추론 실행...');
      _interpreter!.run(input, output);

      // output[0]에 각 클래스의 확률이 담김
      // 예: [0.15, 0.82, 0.03] → background 15%, tata1 82%, tata2 3%
      final scores = output[0];
      debugPrint('  결과: $scores');

      // 🔎 [디버깅] 모든 클래스의 확률을 자세히 출력
      debugPrint('  📊 각 클래스별 확률:');
      for (int i = 0; i < scores.length; i++) {
        debugPrint('    ${_labels[i]}: ${(scores[i] * 100).toStringAsFixed(2)}%');
      }

      // ============================================
      // 7단계: 가장 높은 점수를 가진 클래스 찾기
      // ============================================
      final maxIndex = scores.indexOf(scores.reduce((a, b) => a > b ? a : b));
      final maxScore = scores[maxIndex]; // 가장 높은 확률값
      final rawLabel = _labels[maxIndex]; // 예: "0 model_tata1"

      // ============================================
      // 8단계: 라벨 정제 (앞의 숫자 제거)
      // "0 model_tata1" → "model_tata1"
      // ============================================
      final label = rawLabel.contains(' ')
          ? rawLabel.split(' ').last // 공백으로 분리 후 마지막 부분만
          : rawLabel; // 공백이 없으면 그대로

      debugPrint('  🏷️ 인식된 라벨: $label');
      debugPrint('  📈 신뢰도: ${(maxScore * 100).toStringAsFixed(2)}%');

      // ============================================
      // 🔒 [검증 1] background가 가장 높은 확률이면 거부
      // ============================================
      if (label == 'background') {
        debugPrint('❌ 배경으로 인식됨 (스티커가 아님)');
        throw Exception(
            '스티커가 인식되지 않았습니다\n'
                '스티커를 명확하게 촬영해주세요.'
        );
      }

      // ============================================
      // 🔒 [검증 2] 신뢰도 검증 (70% 이상일 때만 인식 성공)
      // ============================================
      const double confidenceThreshold = 0.7; // 70% 이상일 때만 인식

      if (maxScore < confidenceThreshold) {
        debugPrint('❌ 신뢰도 부족: ${(maxScore * 100).toStringAsFixed(2)}% < ${(confidenceThreshold * 100).toStringAsFixed(0)}%');
        throw Exception(
            '스티커 인식 실패\n'
                '신뢰도: ${(maxScore * 100).toStringAsFixed(1)}% (필요: ${(confidenceThreshold * 100).toStringAsFixed(0)}% 이상)\n'
                '스티커를 더 가까이서 명확하게 촬영해주세요.'
        );
      }

      debugPrint('✅ 추론 완료');
      debugPrint('  원본 라벨: $rawLabel');
      debugPrint('  정제 라벨: $label');
      debugPrint('  최종 신뢰도: ${(maxScore * 100).toStringAsFixed(2)}%');

      return label; // 인식된 라벨 반환

    } catch (e) {
      debugPrint('❌ 추론 오류: $e');
      rethrow; // 오류를 호출한 곳으로 다시 던짐
    }
  }

  // ========================================
  // 🔗 _openUrl: 인식된 스티커에 해당하는 URL 실행
  // ========================================
  Future<void> _openUrl(String label) async {
    debugPrint('🔗 URL 실행 시도');
    debugPrint('  라벨: $label');

    // ============================================
    // 1단계: 라벨에 해당하는 URL 찾기
    // ============================================
    final url = stickerUrlMap[label];

    // 등록되지 않은 스티커면 알림 표시 후 종료
    if (url == null || url.isEmpty) {
      debugPrint('❌ URL 없음: $label');
      debugPrint('  등록된 스티커: ${stickerUrlMap.keys.toList()}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                label == 'background'
                    ? '배경이 인식되었습니다\n스티커를 촬영해주세요'
                    : '등록되지 않은 스티커: $label'
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    debugPrint('  URL: $url');
    final uri = Uri.parse(url); // 문자열을 URI 객체로 변환

    try {
      // ============================================
      // 2단계: URL을 열 수 있는지 확인
      // ============================================
      final canLaunch = await canLaunchUrl(uri);
      debugPrint('  canLaunchUrl: $canLaunch');

      if (!canLaunch) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('URL을 열 수 없습니다')),
          );
        }
        return;
      }

      // ============================================
      // 3단계: URL 실행 (외부 앱으로 열기)
      // ============================================
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // 외부 브라우저/앱에서 열기
      );

      debugPrint('  launchUrl: $success');

      // ============================================
      // 4단계: 결과에 따라 사용자에게 알림
      // ============================================
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

  // ========================================
  // 🗑️ dispose: 화면이 사라질 때 리소스 정리
  // ========================================
  @override
  void dispose() {
    _controller?.dispose(); // 카메라 컨트롤러 해제
    _interpreter?.close(); // AI 모델 해제
    debugPrint('🗑️ 리소스 정리');
    super.dispose();
  }

  // ========================================
  // 🎨 build: 화면을 그리는 함수
  // ========================================
  @override
  Widget build(BuildContext context) {
    // 카메라가 준비되지 않았으면 로딩 화면 표시
    if (!_cameraReady) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(), // 로딩 스피너
              SizedBox(height: 16),
              Text('카메라 초기화 중...'),
            ],
          ),
        ),
      );
    }

    // ============================================
    // 카메라 준비 완료 시 메인 화면 구성
    // ============================================
    return Scaffold(
      // 상단 앱바
      appBar: AppBar(
        title: const Text('스티커 촬영'),
        backgroundColor: Colors.deepPurple,
        actions: [
          // 📍 모델 로딩 상태 표시 배지
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                // 모델 상태에 따라 배경색 변경
                color: _modelLoaded
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 아이콘 (체크 또는 모래시계)
                  Icon(
                    _modelLoaded ? Icons.check_circle : Icons.hourglass_empty,
                    color: _modelLoaded ? Colors.greenAccent : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  // 텍스트 (Ready 또는 Loading)
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

      // 메인 화면 본문
      body: _capturedImage == null
          ? CameraPreview(_controller!) // 사진 촬영 전: 카메라 프리뷰
          : _buildPreview(), // 사진 촬영 후: 미리보기 화면

      // 플로팅 버튼 (촬영 전에만 표시)
      floatingActionButton: _capturedImage == null
          ? FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: _takePicture, // 버튼 클릭 시 사진 촬영
        child: const Icon(Icons.camera_alt),
      )
          : null, // 사진 촬영 후에는 버튼 숨김
    );
  }

  // ========================================
  // 🖼 _buildPreview: 촬영한 사진 미리보기 화면
  // ========================================
  Widget _buildPreview() {
    return Column(
      children: [
        // ============================================
        // 상단: 촬영한 이미지 표시
        // ============================================
        Expanded(
          child: Image.file(
            File(_capturedImage!.path), // 파일 경로로 이미지 표시
            fit: BoxFit.contain, // 화면에 맞게 표시
          ),
        ),

        // ============================================
        // 하단: 버튼 영역 (검은 배경)
        // ============================================
        Container(
          color: Colors.black87,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 📍 모델 로딩 중일 때 안내 메시지
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

              // ============================================
              // 버튼 2개 (재촬영, 확인)
              // ============================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 🔄 재촬영 버튼
                  ElevatedButton.icon(
                    onPressed: _retakePicture, // 사진 삭제 후 카메라로 복귀
                    icon: const Icon(Icons.refresh),
                    label: const Text('재촬영'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),

                  // ✅ 확인 버튼 (AI 인식 실행)
                  ElevatedButton.icon(
                    // 모델이 로드된 경우에만 활성화
                    onPressed: _modelLoaded
                        ? () async {
                      debugPrint('🟢 확인 버튼 클릭');
                      debugPrint('  _modelLoaded = $_modelLoaded');

                      // 사용자에게 처리 중임을 알림
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
                        // AI 모델로 이미지 인식
                        final label = await _runInference(
                          File(_capturedImage!.path),
                        );

                        // 인식된 라벨에 해당하는 URL 실행
                        await _openUrl(label);

                      } catch (e) {
                        // 오류 발생 시 사용자에게 알림
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
                        : null, // 모델 로딩 전에는 버튼 비활성화
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