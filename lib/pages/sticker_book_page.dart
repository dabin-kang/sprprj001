import 'dart:io';
import 'package:flutter/material.dart';
import '../repositories/sticker_repository.dart';
import '../models/sticker_model.dart';

class StickerBookPage extends StatelessWidget {
  const StickerBookPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 스티커북'),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<List<StickerModel>>(
        future: StickerRepository.getAll(),
        builder: (context, snapshot) {
          // 🔄 로딩 중
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ❌ 에러
          if (snapshot.hasError) {
            return const Center(child: Text('스티커를 불러오지 못했습니다'));
          }

          final stickers = snapshot.data ?? [];

          // 📭 스티커 없음
          if (stickers.isEmpty) {
            return const Center(
              child: Text('아직 수집한 스티커가 없습니다'),
            );
          }

          // 📘 스티커 리스트
          return ListView.builder(
            itemCount: stickers.length,
            itemBuilder: (context, index) {
              final sticker = stickers[index];
              return ListTile(
                leading: Image.file(
                  File(sticker.imagePath),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
                title: Text(sticker.label),
                subtitle: Text(
                  sticker.collectedAt.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
