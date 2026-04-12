import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/round_model.dart';
import '../services/auth_service.dart';

/// 명예의 전당 화면
/// - 베스트 스코어 (최저 그로스)
/// - 최고 GIR (그린 적중률)
/// - 최저 퍼팅수
/// 유저 본인 + 모든 동반자 데이터를 포함해 집계
class HallOfFameScreen extends StatelessWidget {
  const HallOfFameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text('🏆 명예의 전당'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
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
            return Center(child: Text('데이터를 불러오지 못했습니다:\n${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                '기록이 없습니다.\n라운드를 입력하면 명예의 전당이 채워집니다!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          final rounds = snapshot.data!.docs
              .map((d) => RoundData.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList();

          final records = _computeRecords(rounds);

          if (records.isEmpty) {
            return const Center(
              child: Text(
                '18홀 완성 기록이 없습니다.\n18홀 기록을 입력하면 집계됩니다!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              if (records.bestScore != null)
                _RecordCard(
                  icon: '⛳',
                  category: '베스트 스코어',
                  value: '${records.bestScore!.value}타',
                  playerName: records.bestScore!.playerName,
                  courseName: records.bestScore!.courseName,
                  date: records.bestScore!.date,
                  color: const Color(0xFFE74C3C),
                ),
              const SizedBox(height: 16),
              if (records.bestGir != null)
                _RecordCard(
                  icon: '🎯',
                  category: '최고 GIR',
                  value: '${records.bestGir!.value}홀 (${((records.bestGir!.value / 18) * 100).toStringAsFixed(1)}%)',
                  playerName: records.bestGir!.playerName,
                  courseName: records.bestGir!.courseName,
                  date: records.bestGir!.date,
                  color: const Color(0xFF27AE60),
                ),
              const SizedBox(height: 16),
              if (records.bestPutt != null)
                _RecordCard(
                  icon: '🏌️',
                  category: '최저 퍼팅수',
                  value: '${records.bestPutt!.value}퍼트',
                  playerName: records.bestPutt!.playerName,
                  courseName: records.bestPutt!.courseName,
                  date: records.bestPutt!.date,
                  color: const Color(0xFF2980B9),
                ),
            ],
          );
        },
      ),
    );
  }

  _HallRecords _computeRecords(List<RoundData> rounds) {
    _HallEntry? bestScore;
    _HallEntry? bestGir;
    _HallEntry? bestPutt;

    for (final round in rounds) {
      final enteredHoles = round.holes.where((h) => h.score != -99).length;
      if (enteredHoles < 18) continue; // 18홀 미완성 제외

      final totalPar = round.holes.fold(0, (s, h) => s + h.par);
      final allNames = <String>[round.userName ?? '나', ...round.companions];

      // 유저(0) + 동반자(1~n) 순회
      for (int pi = 0; pi < allNames.length; pi++) {
        final name = allNames[pi];

        int score;
        int putts;
        int girCount = 0;
        bool allEntered = true;

        if (pi == 0) {
          // 유저 본인
          final allScored = round.holes.every((h) => h.score != -99 && h.putt != -99);
          if (!allScored) { allEntered = false; }
          score = round.holes.fold(0, (s, h) => s + (h.score == -99 ? 0 : h.score));
          putts = round.holes.fold(0, (s, h) => s + (h.putt == -99 ? 0 : h.putt));
          for (final h in round.holes) {
            if (h.score != -99 && h.putt != -99 && (h.score - h.putt) <= -2) girCount++;
          }
        } else {
          // 동반자
          final cIdx = pi - 1;
          final allScored = round.holes.every((h) =>
              h.companionScores.length > cIdx &&
              h.companionScores[cIdx] != -99 &&
              h.companionPutts.length > cIdx &&
              h.companionPutts[cIdx] != -99);
          if (!allScored) { allEntered = false; }
          score = round.holes.fold(0, (s, h) {
            final v = h.companionScores.length > cIdx ? h.companionScores[cIdx] : -99;
            return s + (v == -99 ? 0 : v);
          });
          putts = round.holes.fold(0, (s, h) {
            final v = h.companionPutts.length > cIdx ? h.companionPutts[cIdx] : -99;
            return s + (v == -99 ? 0 : v);
          });
          for (final h in round.holes) {
            final cs = h.companionScores.length > cIdx ? h.companionScores[cIdx] : -99;
            final cp = h.companionPutts.length > cIdx ? h.companionPutts[cIdx] : -99;
            if (cs != -99 && cp != -99 && (cs - cp) <= -2) girCount++;
          }
        }

        if (!allEntered) continue;

        final grossScore = totalPar + score;
        final entry = _HallEntry(
          playerName: name,
          courseName: round.golfCourseName,
          date: round.date,
          value: 0,
        );

        // 베스트 스코어 (낮을수록 좋음)
        if (bestScore == null || grossScore < bestScore.value) {
          bestScore = _HallEntry(
            playerName: name,
            courseName: round.golfCourseName,
            date: round.date,
            value: grossScore,
          );
        }

        // 최고 GIR (높을수록 좋음)
        if (bestGir == null || girCount > bestGir.value) {
          bestGir = _HallEntry(
            playerName: name,
            courseName: round.golfCourseName,
            date: round.date,
            value: girCount,
          );
        }

        // 최저 퍼팅수 (낮을수록 좋음)
        if (entry.playerName.isNotEmpty && (bestPutt == null || putts < bestPutt.value)) {
          bestPutt = _HallEntry(
            playerName: name,
            courseName: round.golfCourseName,
            date: round.date,
            value: putts,
          );
        }
      }
    }

    return _HallRecords(bestScore: bestScore, bestGir: bestGir, bestPutt: bestPutt);
  }
}

class _HallEntry {
  final String playerName;
  final String courseName;
  final DateTime date;
  final int value;

  const _HallEntry({
    required this.playerName,
    required this.courseName,
    required this.date,
    required this.value,
  });
}

class _HallRecords {
  final _HallEntry? bestScore;
  final _HallEntry? bestGir;
  final _HallEntry? bestPutt;

  const _HallRecords({this.bestScore, this.bestGir, this.bestPutt});

  bool get isEmpty => bestScore == null && bestGir == null && bestPutt == null;
}

class _RecordCard extends StatelessWidget {
  final String icon;
  final String category;
  final String value;
  final String playerName;
  final String courseName;
  final DateTime date;
  final Color color;

  const _RecordCard({
    required this.icon,
    required this.category,
    required this.value,
    required this.playerName,
    required this.courseName,
    required this.date,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 카테고리 헤더
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 기록값
            Text(
              value,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            // 달성자
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  playerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 코스명 + 날짜
            Row(
              children: [
                const Icon(Icons.golf_course, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    courseName,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormat('yyyy-MM-dd').format(date),
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
