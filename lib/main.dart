import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';



late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await FirebaseAuth.instance.signInAnonymously();
    print('✅ Firebase 익명 로그인 성공');
  } catch (e) {
    print('❌ Firebase 익명 로그인 실패: $e');
  }

  cameras = await availableCameras(); // ⭐ 필수
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'spr app Demo',
      home: LoginPage(),
    );
  }
}
