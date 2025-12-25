import 'package:flutter/material.dart';
import 'package:sprprj001/pages/musicplay_page.dart';
import 'camera_page.dart';
import 'gallery_page.dart';
import 'sticker_book_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            // 1. 갤러리
            IconButton(
              icon: const Icon(Icons.photo_library),
              color: Colors.deepPurple,
              tooltip: '갤러리',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GalleryPage(),
                  ),
                );
              },
            ),

            // 2. 카메라
            IconButton(
              icon: const Icon(Icons.camera_alt),
              color: Colors.deepPurple,
              tooltip: '카메라 촬영',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CameraPage(),
                  ),
                );
              },
            ),

            // 3. 음악
            IconButton(
              icon: const Icon(Icons.music_note),
              color: Colors.deepPurple,
              tooltip: '음악 재생',
              onPressed: () {
                Navigator.push(context,
                MaterialPageRoute(
                builder:(_) => const MusicPlay(
                  url: 'https://youtu.be/GPrspUrmZj8',
                )
                ),
                );
              },
            ),


            // 4. 설정
            IconButton(
              icon: const Icon(Icons.settings),
              color: Colors.deepPurple,
              tooltip: '설정',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('설정 페이지 이동 (미구현)')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.book),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StickerBookPage(),
                  ),
                );
              },
            ),

          ],
        ),
      ),
    );
  }
}
