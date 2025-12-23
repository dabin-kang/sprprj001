import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final idController = TextEditingController();
  final pwController = TextEditingController();

  /// 회원가입
  Future<void> register() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('id', idController.text);
    await prefs.setString('pw', pwController.text);

    _show('회원가입 완료');
  }

  /// 로그인
  Future<void> login() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('id');
    final savedPw = prefs.getString('pw');

    if (idController.text == savedId &&
        pwController.text == savedPw) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      _show('아이디 또는 비밀번호 오류');
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SPR 로그인')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: '아이디'),
            ),
            TextField(
              controller: pwController,
              decoration: const InputDecoration(labelText: '비밀번호'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: login, child: const Text('로그인')),
            TextButton(onPressed: register, child: const Text('회원가입')),
          ],
        ),
      ),
    );
  }
}
