import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'dart:async';
import 'package:web/web.dart' as web;
import '../constants/app_version.dart';
import 'package:intl/intl.dart';

import '../models/round_model.dart';
import '../services/download_service.dart';
import '../widgets/q_point_breakdown_dialog.dart';
import 'edit_round_screen.dart';
import 'course_list_screen.dart';
import 'hall_of_fame_screen.dart';
import 'statistics_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription? _updateSubscription;
  bool _updateDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserName();
      _listenForAppUpdate();
    });
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }

  void _listenForAppUpdate() {
    _updateSubscription = FirebaseFirestore.instance
        .collection('app_meta')
        .doc('version')
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;
      final serverVersion = data['version'] as String? ?? '';
      final serverBuild = (data['buildNumber'] as num?)?.toInt() ?? 0;
      final notes = data['releaseNotes'] as String? ?? '';

      if ((serverBuild > appBuildNumber || (serverVersion.isNotEmpty && serverVersion != appVersion)) &&
          !_updateDialogShown &&
          mounted) {
        _updateDialogShown = true;
        _showUpdatePromptDialog(serverVersion, notes);
      }
    }, onError: (e) {
      debugPrint('버전 업데이트 리슨 에러: $e');
    });
  }

  void _showUpdatePromptDialog(String serverVersion, String notes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Color(0xFF27AE60), size: 28),
            SizedBox(width: 8),
            Text('앱 업데이트 알림'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '새로운 버전(v$serverVersion)이 출시되었습니다.',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notes,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              '최신 기능(코스 삭제 및 오장마스터 선핸디 룰 등)을 사용하려면 지금 업데이트해주세요.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateDialogShown = false;
            },
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () {
              if (kIsWeb) {
                web.window.location.reload();
              } else {
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27AE60),
              foregroundColor: Colors.white,
            ),
            child: const Text('지금 업데이트'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUserName() async {
    final user = AuthService().currentUser;
    if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
      _showNameEditDialog(isInitial: true);
    }
  }

  Future<void> _showNameEditDialog({bool isInitial = false}) async {
    final user = AuthService().currentUser;
    final nameCtrl = TextEditingController(text: user?.displayName);
    
    final bool? success = await showDialog<bool>(
      context: context,
      barrierDismissible: !isInitial,
      builder: (ctx) => AlertDialog(
        title: Text(isInitial ? '이름 설정' : '프로필 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isInitial 
              ? '기존에 가입하신 회원님이시네요!\n코스별 기록 저장을 위해 닉네임을 설정해주세요.' 
              : '사용하실 이름을 입력해 주세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '이름 (닉네임)', 
                border: OutlineInputBorder(),
                hintText: '예: 홍길동',
              ),
            )
          ],
        ),
        actions: [
          if (!isInitial)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                await AuthService().updateName(newName);
                if (ctx.mounted) Navigator.pop(ctx, true);
              }
            },
            child: const Text('저장'),
          )
        ],
      ),
    );

    if (success == true) {
      if (mounted) setState(() {}); // 프로필 갱신
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 이름이 업데이트되었습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기록실', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.logout, size: 20),
          tooltip: '로그아웃',
          onPressed: () => AuthService().signOut(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.yellowAccent),
            tooltip: '강제 동기화 (PWA 캐시 삭제)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('캐시를 비우고 최신 버전으로 동기화합니다...')),
              );
              DownloadService.forceWebUpdate();
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: '프로필 수정',
            onPressed: () => _showNameEditDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: '명예의 전당',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HallOfFameScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: '통계 대시보드',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatisticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.golf_course),
            tooltip: '골프장 관리',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CourseListScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // createdAt 기준으로 내림차순(최신순) 정렬하여 데이터 실시간 수신
        stream: FirebaseFirestore.instance
            .collection('rounds')
            .where('userId', isEqualTo: AuthService().currentUser?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('데이터를 불러오지 못했습니다:\n${snapshot.error}', textAlign: TextAlign.center));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('첫 라운딩 기록을 추가해보세요.'));
          }

          final docs = snapshot.data!.docs;
          
          return RefreshIndicator(
            onRefresh: () async {
              DownloadService.forceWebUpdate();
              await Future.delayed(const Duration(seconds: 1)); // UI feedback before reload
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final round = RoundData.fromMap(
                  docs[index].id,
                  docs[index].data() as Map<String, dynamic>,
                );

                final enteredHoles = round.holes.where((h) => h.score != -99).toList();
                int totalPar = enteredHoles.fold(0, (total, h) => total + h.par);
                int totalPutt = enteredHoles.fold(0, (total, h) => total + h.putt);
                int overUnder = round.totalScore; 
                int grossScore = totalPar + overUnder; 
                bool isIncomplete = enteredHoles.length < 18;

                String overUnderStr;
                if (overUnder > 0) {
                  overUnderStr = '+$overUnder';
                } else if (overUnder < 0) {
                  overUnderStr = '$overUnder';
                } else {
                  overUnderStr = 'E';
                }

                String courseNames = '';
                if (round.frontCourseName.isNotEmpty && round.backCourseName.isNotEmpty) {
                  courseNames = '${round.frontCourseName} / ${round.backCourseName}';
                } else if (round.frontCourseName.isNotEmpty) {
                  courseNames = round.frontCourseName;
                } else if (round.backCourseName.isNotEmpty) {
                  courseNames = round.backCourseName;
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          round.golfCourseName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        if (courseNames.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              courseNames,
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${DateFormat('yyyy-MM-dd').format(round.date)}  ${round.teeUpTime}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF667C7A)),
                              ),
                              if (isIncomplete) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Text(
                                    '${enteredHoles.length}홀 기록됨',
                                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (round.companions.isNotEmpty)
                            Text(
                              'With: ${round.companions.join(', ')}',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    titleAlignment: ListTileTitleAlignment.titleHeight,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isIncomplete ? Colors.grey.shade50 : const Color(0xFF27AE60).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$grossScore($overUnderStr), $totalPutt putt',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isIncomplete ? Colors.grey : (overUnder < 0 ? Colors.red : (overUnder == 0 ? Colors.black87 : Colors.blue)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _showQPointBreakdown(context, round),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isIncomplete ? Colors.grey.shade200 : const Color(0xFFD4AF37).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Q-Point: ${round.qPoint}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isIncomplete ? Colors.grey : const Color(0xFF997D21),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditRoundScreen(round: round),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'App Version v$appVersion',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditRoundScreen(),
            ),
          );
        },
        tooltip: '새 기록 추가',
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showQPointBreakdown(BuildContext context, RoundData round) {
    showQPointBreakdownDialog(
      context,
      courseName: round.golfCourseName,
      playerName: AuthService().currentUser?.displayName ?? round.userName ?? '나',
      breakdown: round.getQPointBreakdown(0),
    );
  }
}
