import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 인증 상태 변화 감시 스트림
  Stream<User?> get userState => _auth.authStateChanges();

  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 이메일/비밀번호 회원가입
  Future<UserCredential?> signUp(String email, String password, String name) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // 이메일/비밀번호 로그인
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // 이름 업데이트 (기존 가입자용)
  Future<void> updateName(String name) async {
    try {
      await _auth.currentUser?.updateDisplayName(name);
    } catch (e) {
      debugPrint('이름 업데이트 실패: $e');
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 에러 메시지 한글화 처리
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return '등록되지 않은 이메일입니다.';
      case 'wrong-password':
        return '비밀번호가 틀렸습니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일 주소입니다.';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'weak-password':
        return '비밀번호가 너무 취약합니다.';
      case 'network-request-failed':
        return '네트워크 연결이 원활하지 않습니다.';
      default:
        return '인증 오류가 발생했습니다. (${e.code})';
    }
  }
}
