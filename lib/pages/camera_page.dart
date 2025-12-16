import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import 'package:image/image.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // 카메라 초기화
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![0], // 후면 카메라 사용
          ResolutionPreset.high,
        );

        await _controller!.initialize();

        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      print('카메라 초기화 오류: $e');
    }
  }

  // 사진 촬영
  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      final XFile image = await _controller!.takePicture();
      setState(() {
        _capturedImage = image;
      });

      // 촬영 완료 메시지
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사진이 촬영되었습니다!')));
      }
    } catch (e) {
      print('사진 촬영 오류: $e');
    }
  }

  // 촬영한 사진 재촬영
  void _retakePicture() {
    setState(() {
      _capturedImage = null;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스티커 촬영'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isInitialized
          ? _capturedImage == null
                ? _buildCameraPreview()
                : _buildImagePreview()
          : const Center(child: CircularProgressIndicator()),
    );
  }

  // 카메라 프리뷰 화면
  Widget _buildCameraPreview() {
    return Stack(
      children: [
        // 카메라 프리뷰
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: CameraPreview(_controller!),
        ),

        // 촬영 버튼
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _takePicture,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.deepPurple, width: 4),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 35,
                  color: Colors.deepPurple,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 촬영한 이미지 미리보기 화면
  Widget _buildImagePreview() {
    return Column(
      children: [
        Expanded(
          child: Image.file(File(_capturedImage!.path), fit: BoxFit.contain),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.black87,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 재촬영 버튼
              ElevatedButton.icon(
                onPressed: _retakePicture,
                icon: const Icon(Icons.refresh),
                label: const Text('재촬영'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                ),
              ),

              // 저장 버튼
              ElevatedButton.icon(
                onPressed: () {
                  // 여기에 이미지 저장 및 인식 로직 추가
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('스티커 인식 중...')));
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check),
                label: const Text('확인'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
