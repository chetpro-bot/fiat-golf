import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/round_model.dart';
import '../services/auth_service.dart';

/// 명예의 전당 화면
/// - 베스트 스코어 / 최고 GIR / 최저 퍼팅수
/// - [신규] 니어왕 / 버디왕 / 파 킹 / 보기 킹
/// - Q-Point 최고 / Q-Point 최저
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
              // 1. 기본 실력 지표
              _sectionHeader('실력 지표'),
              if (records.bestScore != null)
                _RecordCard(
                  icon: '⛳',
                  category: '베스트 스코어',
                  entry: records.bestScore!,
                  color: const Color(0xFFE74C3C),
                ),
              const SizedBox(height: 12),
              if (records.bestGir != null)
                _RecordCard(
                  icon: '🎯',
                  category: '최고 GIR',
                  entry: records.bestGir!,
                  color: const Color(0xFF27AE60),
                ),
              const SizedBox(height: 12),
              if (records.bestPutt != null)
                _RecordCard(
                  icon: '🏌️',
                  category: '최저 퍼팅수',
                  entry: records.bestPutt!,
                  color: const Color(0xFF2980B9),
                ),
              
              const SizedBox(height: 24),
              
              // 2. 동반자 배틀 (킹 시리즈)
              _sectionHeader('타이틀 매치'),
              if (records.nearestKing != null)
                _RecordCard(
                  icon: '📍',
                  category: 'Nearest King',
                  entry: records.nearestKing!,
                  color: Colors.deepOrange,
                ),
              const SizedBox(height: 12),
              if (records.birdieKing != null)
                _RecordCard(
                  icon: '🐦',
                  category: 'Birdie King',
                  entry: records.birdieKing!,
                  color: Colors.purple,
                ),
              const SizedBox(height: 12),
              if (records.parKing != null)
                _RecordCard(
                  icon: '📋',
                  category: 'Par King',
                  entry: records.parKing!,
                  color: Colors.teal,
                ),
              const SizedBox(height: 12),
              if (records.bogeyKing != null)
                _RecordCard(
                  icon: '🤡',
                  category: 'Bogey King',
                  entry: records.bogeyKing!,
                  color: Colors.blueGrey,
                ),

              const SizedBox(height: 24),

              // 3. Q-Point 지표
              _sectionHeader('Q-Point 지표'),
              if (records.bestQPoint != null)
                _RecordCard(
                  icon: '⭐',
                  category: 'Q-Point 최고',
                  entry: records.bestQPoint!,
                  color: const Color(0xFFD4AF37),
                ),
              const SizedBox(height: 12),
              if (records.worstQPoint != null)
                _RecordCard(
                  icon: '😅',
                  category: 'Q-Point 최저',
                  entry: records.worstQPoint!,
                  color: const Color(0xFF7F8C8D),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
      ),
    );
  }

  _HallRecords _computeRecords(List<RoundData> rounds) {
    _HallEntry? bestScore;
    _HallEntry? bestGir;
    _HallEntry? bestPutt;
    _HallEntry? bestQPoint;
    _HallEntry? worstQPoint;
    
    // 신규 추가
    _HallEntry? nearestKing;
    _HallEntry? birdieKing;
    _HallEntry? parKing;
    _HallEntry? bogeyKing;

    for (final round in rounds) {
      final enteredHoles = round.holes.where((h) => h.score != -99).length;
      if (enteredHoles < 18) continue; // 18홀 미완성 제외

      final totalPar = round.holes.fold(0, (s, h) => s + h.par);
      final allNames = <String>[round.userName ?? '나', ...round.companions];

      for (int pi = 0; pi < allNames.length; pi++) {
        final name = allNames[pi];

        int scoreCount = 0;
        int puttsCount = 0;
        int girCount = 0;
        
        int roundBirdies = 0;
        int roundPars = 0;
        int roundBogeys = 0;
        int roundNearests = 0;
        
        bool allEntered = true;

        if (pi == 0) {
          final allScored = round.holes.every((h) => h.score != -99 && h.putt != -99);
          if (!allScored) allEntered = false;
          scoreCount = round.holes.fold(0, (s, h) => s + (h.score == -99 ? 0 : h.score));
          puttsCount = round.holes.fold(0, (s, h) => s + (h.putt == -99 ? 0 : h.putt));
          for (final h in round.holes) {
            if (h.score != -99 && h.putt != -99) {
              if (h.score - h.putt <= -2) girCount++;
              if (h.score < 0) roundBirdies++;
              if (h.score == 0) roundPars++;
              if (h.score == 1) roundBogeys++;
            }
            if (h.nearestPlayerIndex == 0) roundNearests++;
          }
        } else {
          final cIdx = pi - 1;
          final allScored = round.holes.every((h) =>
              h.companionScores.length > cIdx && h.companionScores[cIdx] != -99 &&
              h.companionPutts.length > cIdx && h.companionPutts[cIdx] != -99);
          if (!allScored) allEntered = false;
          scoreCount = round.holes.fold(0, (s, h) {
            final v = h.companionScores.length > cIdx ? h.companionScores[cIdx] : -99;
            return s + (v == -99 ? 0 : v);
          });
          puttsCount = round.holes.fold(0, (s, h) {
            final v = h.companionPutts.length > cIdx ? h.companionPutts[cIdx] : -99;
            return s + (v == -99 ? 0 : v);
          });
          for (final h in round.holes) {
            final cs = h.companionScores.length > cIdx ? h.companionScores[cIdx] : -99;
            final cp = h.companionPutts.length > cIdx ? h.companionPutts[cIdx] : -99;
            if (cs != -99 && cp != -99) {
              if (cs - cp <= -2) girCount++;
              if (cs < 0) roundBirdies++;
              if (cs == 0) roundPars++;
              if (cs == 1) roundBogeys++;
            }
            if (h.nearestPlayerIndex == pi) roundNearests++;
          }
        }

        if (!allEntered) continue;

        final grossScore = totalPar + scoreCount;
        final qp = round.getQPointBreakdown(pi).total;
        final overUnderStr = scoreCount >= 0 ? '+$scoreCount' : '$scoreCount';

        // 1. 기본 지표
        if (bestScore == null || grossScore < bestScore.value) {
          bestScore = _HallEntry(playerName: name, courseName: round.golfCourseName, date: round.date, value: grossScore, displayValue: '$grossScore($overUnderStr)');
        }
        if (bestGir == null || girCount > bestGir.value) {
          bestGir = _HallEntry(playerName: name, courseName: round.golfCourseName, date: round.date, value: girCount, displayValue: '$girCount/18');
        }
        if (bestPutt == null || puttsCount < bestPutt.value) {
          bestPutt = _HallEntry(playerName: name, courseName: round.golfCourseName, date: round.date, value: puttsCount, displayValue: '$puttsCount퍼트');
        }

        // 2. 킹 시리즈 (신규)
        if (roundNearests > 0 && (nearestKing == null || roundNearests > nearestKing.value)) {
          nearestKing = _HallEntry(playerName: name, courseName: round.golfCourseName, date: round.date, value: roundNearests, displayValue: '$roundNearests회');
        }
        if (roundBirdies > 0 && (birdieKing == null || roundBirdies > birdieKing.value)) {
          birdieKing = _HallEntry(playerName: name, courseName: round.golfCourseName, date: round.date, value: roundBirdies, displayValue: '$roundBirdies개');
        }
        if (roundPars > 0 && (parKing == null || roundPars > parKing.value)) {
          parKing = _HallEntry(playerName: name, courseName: round.golfCourseName, date: round.date, value: roundPars, displayValue: '$roundPars개');
        }
        if (roundBogeys > 0 && (bogeyKing == null || roundBogeys > bogeyKing.value)) {
          bogeyKing = _HallEntry(playerName: name, courseName: round.golfCourseName, date: round.date, value: roundBogeys, displayValue: '$roundBogeys개');
        }

        // 3. Q-Point
        if (bestQPoint == null || qp > bestQPoint.value) {
          bestQPoint = _HallEntry(playerName: name, courseName: round.golfCourseName, date: round.date, value: qp, displayValue: '${qp}pt');
        }
        if (worstQPoint == null || qp < worstQPoint.value) {
          worstQPoint = _HallEntry(playerName: name, courseName: round.golfCourseName, date: round.date, value: qp, displayValue: '${qp}pt');
        }
      }
    }

    return _HallRecords(
      bestScore: bestScore, bestGir: bestGir, bestPutt: bestPutt,
      bestQPoint: bestQPoint, worstQPoint: worstQPoint,
      nearestKing: nearestKing, birdieKing: birdieKing, parKing: parKing, bogeyKing: bogeyKing,
    );
  }
}

class _HallEntry {
  final String playerName;
  final String courseName;
  final DateTime date;
  final int value;
  final String displayValue;

  const _HallEntry({
    required this.playerName, required this.courseName, required this.date,
    required this.value, required this.displayValue,
  });
}

class _HallRecords {
  final _HallEntry? bestScore;
  final _HallEntry? bestGir;
  final _HallEntry? bestPutt;
  final _HallEntry? bestQPoint;
  final _HallEntry? worstQPoint;
  
  // 신규
  final _HallEntry? nearestKing;
  final _HallEntry? birdieKing;
  final _HallEntry? parKing;
  final _HallEntry? bogeyKing;

  const _HallRecords({
    this.bestScore, this.bestGir, this.bestPutt, this.bestQPoint, this.worstQPoint,
    this.nearestKing, this.birdieKing, this.parKing, this.bogeyKing,
  });

  bool get isEmpty =>
      bestScore == null && bestGir == null && bestPutt == null &&
      bestQPoint == null && worstQPoint == null &&
      nearestKing == null && birdieKing == null && parKing == null && bogeyKing == null;
}

class _RecordCard extends StatelessWidget {
  final String icon;
  final String category;
  final _HallEntry entry;
  final Color color;

  const _RecordCard({
    required this.icon, required this.category, required this.entry, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  category,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.4),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  entry.displayValue,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color, height: 1.0),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.playerName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.golf_course, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.courseName,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormat('yyyy-MM-dd').format(entry.date),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
