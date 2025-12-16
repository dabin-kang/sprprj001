import 'package:flutter/material.dart';
import 'package:sprprj001/pages/camera_page.dart';
import 'gallery_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp( // 최상위 MaterialApp
      home: Scaffold( // 앱의 기본 구조
        appBar: AppBar(
          title: const Text('음악플레이어 SPR'),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(
          child: Text(
            '메인 화면: 스티커 인식 대기 중',
            style: TextStyle(fontSize: 22, color: Colors.deepPurple),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          // const 키워드는 Navigator.push 때문에 사용할 수 없습니다.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              // 1. 갤러리 페이지 이동 버튼 (사진첩)
              IconButton(
                icon: const Icon(Icons.photo_library),
                color: Colors.deepPurple,
                tooltip: '갤러리',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GalleryPage(),
                    ),
                  );
                },
              ),

              // 2. 카메라 페이지 이동 버튼 (스티커 촬영)
              IconButton(
                icon: const Icon(Icons.camera_alt),
                color: Colors.deepPurple,
                tooltip: '카메라 촬영',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CameraPage(),
                    ),
                  );
                },
              ),

              // 3. 현재 음악/플레이리스트 버튼
              IconButton(
                icon: const Icon(Icons.music_note),
                color: Colors.deepPurple,
                tooltip: '음악 재생',
                onPressed: () {
                  // TODO: 현재 재생 중인 음악/플레이리스트 페이지로 이동
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('음악 재생 페이지 이동 (미구현)')),
                  );
                },
              ),

              // 4. 설정 버튼
              IconButton(
                icon: const Icon(Icons.settings),
                color: Colors.deepPurple,
                tooltip: '설정',
                onPressed: () {
                  // TODO: 설정 페이지로 이동
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('설정 페이지 이동 (미구현)')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}