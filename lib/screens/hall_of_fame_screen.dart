import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/round_model.dart';
import '../services/auth_service.dart';

/// 명예의 전당 화면
/// - 베스트 스코어 / 최고 GIR / 최저 퍼팅수
/// - [신규] 니어왕 / 버디왕 / 파 킹 / 보기 킹
/// - Q-Point 최고 / Q-Point 최저
class HallOfFameScreen extends StatefulWidget {
  const HallOfFameScreen({super.key});

  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen> {
  bool _myOnly = false;

  Widget _buildTabSelector(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 5),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _myOnly = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: _myOnly ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _myOnly
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    '내 기록',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _myOnly ? FontWeight.bold : FontWeight.normal,
                      color: _myOnly ? activeColor : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _myOnly = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: !_myOnly ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: !_myOnly
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    '동반자 포함',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: !_myOnly ? FontWeight.bold : FontWeight.normal,
                      color: !_myOnly ? activeColor : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text('🏆 명예의 전당'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          _buildTabSelector(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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

                final records = _computeRecords(rounds, myOnly: _myOnly);

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
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                  children: [
                    // 1. 기본 실력 지표
                    _sectionHeader('실력 지표'),
                    if (records.bestScore != null) ...[
                      _RecordCard(
                        icon: '⛳',
                        category: '베스트 스코어',
                        entry: records.bestScore!,
                        color: const Color(0xFFE74C3C),
                      ),
                      const SizedBox(height: 7),
                    ],
                    if (records.bestGir != null) ...[
                      _RecordCard(
                        icon: '🎯',
                        category: '최고 GIR',
                        entry: records.bestGir!,
                        color: const Color(0xFF27AE60),
                      ),
                      const SizedBox(height: 7),
                    ],
                    if (records.bestPutt != null) ...[
                      _RecordCard(
                        icon: '🏌️',
                        category: '최저 퍼팅수',
                        entry: records.bestPutt!,
                        color: const Color(0xFF2980B9),
                      ),
                    ],
                    
                    const SizedBox(height: 14),
                    
                    // 2. 동반자 배틀 (킹 시리즈)
                    _sectionHeader('타이틀 매치'),
                    if (records.birdieKing != null) ...[
                      _RecordCard(
                        icon: '🐦',
                        category: 'Birdie King',
                        entry: records.birdieKing!,
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 7),
                    ],
                    if (records.parKing != null) ...[
                      _RecordCard(
                        icon: '📋',
                        category: 'Par King',
                        entry: records.parKing!,
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 7),
                    ],
                    if (records.bogeyKing != null) ...[
                      _RecordCard(
                        icon: '🤡',
                        category: 'Bogey King',
                        entry: records.bogeyKing!,
                        color: Colors.blueGrey,
                      ),
                    ],

                    const SizedBox(height: 14),

                    // 3. Q-Point 지표
                    _sectionHeader('Q-Point 지표'),
                    if (records.bestQPoint != null) ...[
                      _RecordCard(
                        icon: '⭐',
                        category: 'Q-Point 최고',
                        entry: records.bestQPoint!,
                        color: const Color(0xFFD4AF37),
                      ),
                      const SizedBox(height: 7),
                    ],
                    if (records.worstQPoint != null) ...[
                      _RecordCard(
                        icon: '😅',
                        category: 'Q-Point 최저',
                        entry: records.worstQPoint!,
                        color: const Color(0xFF7F8C8D),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black54),
      ),
    );
  }

  _HallRecords _computeRecords(List<RoundData> rounds, {required bool myOnly}) {
    _HallEntry? bestScore;
    _HallEntry? bestGir;
    _HallEntry? bestPutt;
    _HallEntry? bestQPoint;
    _HallEntry? worstQPoint;
    
    // 신규 추가
    _HallEntry? birdieKing;
    _HallEntry? parKing;
    _HallEntry? bogeyKing;

    for (final round in rounds) {
      final enteredHoles = round.holes.where((h) => h.score != -99).length;
      if (enteredHoles < 18) continue; // 18홀 미완성 제외

      final totalPar = round.holes.fold(0, (s, h) => s + h.par);
      final allNames = <String>[round.userName ?? '나', ...round.companions];

      final limit = myOnly ? 1 : allNames.length;
      for (int pi = 0; pi < limit; pi++) {
        final name = allNames[pi];

        int scoreCount = 0;
        int puttsCount = 0;
        int girCount = 0;
        
        int roundBirdies = 0;
        int roundPars = 0;
        int roundBogeys = 0;
        
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
      birdieKing: birdieKing, parKing: parKing, bogeyKing: bogeyKing,
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
  final _HallEntry? birdieKing;
  final _HallEntry? parKing;
  final _HallEntry? bogeyKing;

  const _HallRecords({
    this.bestScore, this.bestGir, this.bestPutt, this.bestQPoint, this.worstQPoint,
    this.birdieKing, this.parKing, this.bogeyKing,
  });

  bool get isEmpty =>
      bestScore == null && bestGir == null && bestPutt == null &&
      bestQPoint == null && worstQPoint == null &&
      birdieKing == null && parKing == null && bogeyKing == null;
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
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 5,
            offset: const Offset(0, 1.2),
          ),
        ],
        border: Border(left: BorderSide(color: color, width: 3.0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left Column: Category
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(icon, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 4.5),
                        Expanded(
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: color,
                              letterSpacing: 0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Vertical Divider 1
              Container(
                width: 1,
                color: Colors.grey[200],
              ),
              const SizedBox(width: 8),
              // Middle Column: Record & Course Name
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      entry.displayValue,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.golf_course, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            entry.courseName,
                            style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Vertical Divider 2
              Container(
                width: 1,
                color: Colors.grey[200],
              ),
              const SizedBox(width: 8),
              // Right Column: Player Name & Date
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(5.5),
                        ),
                        child: Text(
                          entry.playerName,
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event, size: 11, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(entry.date),
                            style: TextStyle(fontSize: 11.0, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
