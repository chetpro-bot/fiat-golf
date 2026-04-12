import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';

import '../models/round_model.dart';
import '../widgets/q_point_breakdown_dialog.dart';
import 'edit_round_screen.dart';
import 'course_list_screen.dart';
import 'statistics_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserName();
    });
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
        title: const Text('나의 골프 기록 (v1.3.2)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.logout, size: 20),
          tooltip: '로그아웃',
          onPressed: () => AuthService().signOut(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: '프로필 수정',
            onPressed: () => _showNameEditDialog(),
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
          
          return ListView.builder(
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
          );
        },
      ),
      bottomNavigationBar: Container(
        height: 30,
        alignment: Alignment.center,
        child: Text(
          'App Version v1.3.2',
          style: TextStyle(fontSize: 10, color: Colors.grey.withOpacity(0.5)),
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
      playerName: '나',
      breakdown: round.getQPointBreakdown(0),
    );
  }
}
