import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/round_model.dart';
import 'edit_round_screen.dart';

class ScorecardScreen extends StatelessWidget {
  final RoundData round;

  const ScorecardScreen({super.key, required this.round});

  @override
  Widget build(BuildContext context) {
    int totalPar = round.holes.fold(0, (sum, h) => sum + h.par);
    int totalPutt = round.holes.fold(0, (sum, h) => sum + h.putt);
    int overUnder = round.totalScore;
    int totalGross = totalPar + overUnder;
    String overUnderStr = overUnder > 0 ? '+$overUnder' : (overUnder < 0 ? '$overUnder' : 'E');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('스코어카드'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '수정하기',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditRoundScreen(round: round),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 요약 정보
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    round.golfCourseName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$totalGross($overUnderStr)',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${DateFormat('yyyy-MM-dd').format(round.date)} ${round.teeUpTime}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            if (round.companions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  round.companions.join(', '),
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            const SizedBox(height: 24),
            
            // 전반 코스 그리드
            _buildScorecardGrid(round.holes, 0, context),
            const SizedBox(height: 32),
            
            // 후반 코스 그리드
            _buildScorecardGrid(round.holes, 9, context),
            
            const SizedBox(height: 24),
            // 전체 통계 요약
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Total Putts: $totalPutt',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildScorecardGrid(List<HoleData> holes, int startIndex, BuildContext context) {
    if (holes.length < startIndex + 9) return const SizedBox(); 

    final subHoles = holes.sublist(startIndex, startIndex + 9);
    final totalPar = subHoles.fold(0, (sum, h) => sum + h.par);
    final totalScore = subHoles.fold(0, (sum, h) => sum + h.score); // 오버/언더 누적
    final totalPutt = subHoles.fold(0, (sum, h) => sum + h.putt);

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 1),
      columnWidths: const {
        0: FlexColumnWidth(1.6),   // HOLE 라벨 등 첫번째 칼럼 조금 더 넓게
        10: FlexColumnWidth(1.6),  // TOTAL 칼럼 
      },
      defaultColumnWidth: const FlexColumnWidth(1.0),
      children: [
        // HOLE 행
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            _buildCell('HOLE', isHeader: true),
            for (int i = 1; i <= 9; i++) _buildCell('${startIndex + i}', isHeader: true),
            _buildCell('TOTAL', isHeader: true),
          ],
        ),
        // PAR 행
        TableRow(
          children: [
            _buildCell('PAR', isHeader: true),
            for (var h in subHoles) _buildCell('${h.par}'),
            _buildCell('$totalPar', isBold: true),
          ],
        ),
        // SCORE 행
        TableRow(
          children: [
            _buildCell('SCORE', isHeader: true),
            for (var h in subHoles) _buildScoreCell(h.score),
            _buildScoreCell(totalScore, isBold: true), // 9홀 합산 오버/언더
          ],
        ),
        // PUTT 행
        TableRow(
          children: [
            _buildCell('PUTT', isHeader: true),
            for (var h in subHoles) _buildCell('${h.putt}'),
            _buildCell('$totalPutt', isBold: true),
          ],
        ),
      ],
    );
  }

  Widget _buildCell(String text, {bool isHeader = false, bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.grey.shade600 : Colors.black87,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildScoreCell(int score, {bool isBold = false}) {
    Color bgColor = Colors.transparent;
    String text = score == 0 ? '0' : (score > 0 ? '+$score' : '$score');
    
    if (score < 0) {
      bgColor = Colors.red.shade200; // 언더파 (버디, 이글 등) -> 붉은색
    } else if (score > 0) {
      bgColor = Colors.cyan.shade200; // 오버파 (보기, 더블 등) -> 푸른색
    } else {
      bgColor = Colors.grey.shade100; // 파 (이븐) -> 밝은 회색
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.bold, // 스코어는 모두 굵게 표기 시인성 강화
          fontSize: 13,
          color: Colors.black87,
        ),
      ),
    );
  }
}
