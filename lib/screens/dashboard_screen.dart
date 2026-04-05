import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';

import '../models/round_model.dart';
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
      final nameCtrl = TextEditingController();
      final bool? success = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // 작성할 때까지 닫기 불가
        builder: (ctx) => AlertDialog(
          title: const Text('이름 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('기존에 가입하신 회원님이시네요!\n코스별 기록 저장을 위해 닉네임을 설정해주세요.'),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '이름 (닉네임)', border: OutlineInputBorder()),
              )
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty) {
                  await AuthService().updateName(nameCtrl.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx, true);
                }
              },
              child: const Text('저장'),
            )
          ],
        ),
      );
      if (success == true) {
        setState(() {}); // 프로필 갱신
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 골프 기록'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.logout, size: 20),
          tooltip: '로그아웃',
          onPressed: () => AuthService().signOut(),
        ),
        actions: [
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

              int totalPar = round.holes.fold(0, (total, h) => total + h.par);
              int totalPutt = round.holes.fold(0, (total, h) => total + h.putt);
              int overUnder = round.totalScore; // totalScore는 이제 오버/언더 누적값을 저장함
              int grossScore = totalPar + overUnder; 
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
                        Text(
                          '${DateFormat('yyyy-MM-dd').format(round.date)}  ${round.teeUpTime}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF667C7A)),
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
                      color: const Color(0xFF27AE60).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$grossScore($overUnderStr), $totalPutt putt',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _showQPointBreakdown(context, round),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Q-Point: ${round.qPoint}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF997D21),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditRoundScreen(), // 새 기록 추가
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
    int totalPar = round.holes.fold(0, (total, h) => total + h.par);
    int grossScore = totalPar + round.totalScore;
    bool sub80 = grossScore <= 79;
    
    int scramblingChances = 0;
    int scramblingSuccesses = 0;
    int totalPenalty = 0;
    bool hasThreePutt = false;
    bool isDigital = true;
    
    for (var hole in round.holes) {
      totalPenalty += hole.penaltyStrokes;
      if (hole.putt >= 3) hasThreePutt = true;
      if (hole.score > 1) isDigital = false;
      
      bool isGir = (hole.score - hole.putt) <= -2;
      if (!isGir) {
        scramblingChances++;
        if (hole.score <= 0) { scramblingSuccesses++; }
      }
    }
    
    bool scrambling50 = scramblingChances > 0 && (scramblingSuccesses / scramblingChances) >= 0.5;
    bool oneBall = totalPenalty == 0;
    bool digitalRound = isDigital;
    bool noThreePutt = !hasThreePutt;

    int points = 0;
    if (sub80) { points += 2; }
    if (scrambling50) { points += 2; }
    if (oneBall) { points += 2; }
    if (digitalRound) { points += 2; }
    if (noThreePutt) { points += 2; }

    Widget buildBonusRow(String title, bool achieved) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 14)),
            Text(achieved ? 'SUCCESS' : 'FAIL', style: TextStyle(color: achieved ? const Color(0xFF27AE60) : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      );
    }
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('${round.golfCourseName} Q-Point 상세내역', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                buildBonusRow('Sub-80 Round (+2)', sub80),
                buildBonusRow('Scrambling 50%+ (+2)', scrambling50),
                buildBonusRow('One Ball Play (+2)', oneBall),
                buildBonusRow('Digital Round (+2)', digitalRound),
                buildBonusRow('No Three Putt (+2)', noThreePutt),
                const Divider(),
                ...round.holes.map((h) {
                  int pts = h.qPoint;
                  
                  int actualStrokes = h.score + h.par;
                  int onStrokes = actualStrokes - h.putt;
                  
                  String scoreStr = '';
                  Color scoreColor = Colors.black87;
                  if (h.score <= -2) { scoreStr = 'Eagle'; scoreColor = Colors.red; }
                  else if (h.score == -1) { scoreStr = 'Birdie'; scoreColor = Colors.red; }
                  else if (h.score == 0) { scoreStr = 'Par'; }
                  else if (h.score == 1) { scoreStr = 'Bogey'; }
                  else if (h.score == 2) { scoreStr = 'Double'; }
                  else if (h.score == 3) { scoreStr = 'Triple'; }
                  else { scoreStr = '+${h.score}'; }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.black87),
                              children: [
                                TextSpan(text: '${h.holeNumber}번홀 (파${h.par}) $onStrokes온 ${h.putt}펏, '),
                                TextSpan(text: scoreStr, style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        Text('$pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF27AE60)),
              child: const Text('닫기')
            )
          ],
        );
      }
    );
  }
}
