import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class CourseService {
  static final CourseService _instance = CourseService._internal();
  factory CourseService() => _instance;
  CourseService._internal();

  /// 특정 골프장 이름/docId로 등록된 라운드 개수 조회
  Future<int> getRoundCountForCourse(String courseName, {String? docId}) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return 0;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('rounds')
          .where('userId', isEqualTo: uid)
          .get();

      int count = 0;
      for (var doc in snap.docs) {
        final data = doc.data();
        final gName = data['golfCourseName'] as String?;
        if (gName != null &&
            (gName == courseName || (docId != null && gName == docId))) {
          count++;
        }
      }
      return count;
    } catch (e) {
      debugPrint('Error counting rounds for course: $e');
      return 0;
    }
  }

  /// 특정 골프장의 세부 코스(전반/후반 등)로 등록된 라운드 개수 조회
  Future<int> getRoundCountForSubCourse(
    String courseName,
    String subCourseName, {
    String? docId,
  }) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return 0;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('rounds')
          .where('userId', isEqualTo: uid)
          .get();

      int count = 0;
      for (var doc in snap.docs) {
        final data = doc.data();
        final gName = data['golfCourseName'] as String?;
        if (gName != null &&
            (gName == courseName || (docId != null && gName == docId))) {
          final front = data['frontCourseName'] as String?;
          final back = data['backCourseName'] as String?;
          if (front == subCourseName || back == subCourseName) {
            count++;
          }
        }
      }
      return count;
    } catch (e) {
      debugPrint('Error counting rounds for sub course: $e');
      return 0;
    }
  }

  /// 골프장 삭제 플로우: 라운드 개수 확인 후 0건이면 1단계, 1건 이상이면 2단계 재확인
  Future<bool> confirmAndDeleteCourse(
    BuildContext context, {
    required String docId,
    required String courseName,
  }) async {
    // 1. 라운드 개수 조회 (로딩 다이얼로그 표시)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('라운드 기록 확인 중...', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );

    int roundCount = 0;
    try {
      roundCount = await getRoundCountForCourse(courseName, docId: docId);
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // 로딩 닫기
      }
    }

    if (!context.mounted) return false;

    // 2. 라운드 기록 유무에 따른 삭제 확인 플로우
    if (roundCount == 0) {
      // 입력된 라운드가 없는 경우 -> 1회 확인 후 바로 삭제
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('골프장 삭제'),
          content: Text('‘$courseName’ 골프장을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('삭제'),
            ),
          ],
        ),
      );

      if (confirmed != true) return false;
    } else {
      // 입력된 라운드가 있는 경우 -> 2단계에 걸쳐 "한 번 더 물어보기"
      // 1단계 확인
      final firstConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('라운드 기록 발견'),
            ],
          ),
          content: Text(
            '‘$courseName’ 코스로 등록된 라운드가 총 $roundCount건 있습니다.\n\n해당 골프장 코스를 삭제하시겠습니까?',
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              child: const Text('계속 진행'),
            ),
          ],
        ),
      );

      if (firstConfirm != true) return false;
      if (!context.mounted) return false;

      // 2단계 (한 번 더 물어보기 - 최종 확인)
      final secondConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('최종 삭제 확인', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Text(
            '⚠️ 주의: ‘$courseName’ 코스로 입력된 라운드가 $roundCount건 존재합니다.\n\n'
            '코스를 삭제하더라도 기존 라운드 기록 자체는 유지되지만, 코스 목록에서 영구 제거되며 새 라운드 등록 시 코스 정보가 자동으로 불러와지지 않습니다.\n\n'
            '정말로 이 코스를 최종 삭제하시겠습니까?',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('최종 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (secondConfirm != true) return false;
    }

    // 3. 실제 삭제 수행
    try {
      await FirebaseFirestore.instance.collection('courses').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('‘$courseName’ 골프장이 삭제되었습니다.')),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
      return false;
    }
  }

  /// 세부 코스 섹션 삭제 시 확인 플로우
  Future<bool> confirmDeleteSubCourse(
    BuildContext context, {
    required String courseName,
    required String subCourseName,
    String? docId,
  }) async {
    if (subCourseName.trim().isEmpty) {
      return true;
    }

    // 라운드 개수 확인
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('라운드 기록 확인 중...', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );

    int roundCount = 0;
    try {
      roundCount = await getRoundCountForSubCourse(
        courseName,
        subCourseName,
        docId: docId,
      );
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!context.mounted) return false;

    if (roundCount == 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('세부 코스 삭제'),
          content: Text('‘$subCourseName’ 코스를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      return confirmed == true;
    } else {
      // 1단계
      final firstConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('라운드 기록 발견'),
            ],
          ),
          content: Text(
            '‘$subCourseName’ 코스로 등록된 라운드가 총 $roundCount건 있습니다.\n\n해당 세부 코스를 삭제하시겠습니까?',
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              child: const Text('계속 진행'),
            ),
          ],
        ),
      );

      if (firstConfirm != true) return false;
      if (!context.mounted) return false;

      // 2단계 (한 번 더 확인)
      final secondConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('최종 코스 삭제 확인', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Text(
            '⚠️ 주의: ‘$subCourseName’ 코스로 등록된 라운드가 $roundCount건 존재합니다.\n\n'
            '삭제하더라도 기존 라운드 기록에는 유지되지만, 해당 골프장의 세부 코스 설정에서 제거됩니다.\n\n'
            '정말로 ‘$subCourseName’ 코스를 최종 삭제하시겠습니까?',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('최종 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      return secondConfirm == true;
    }
  }
}
