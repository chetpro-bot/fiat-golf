import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/round_model.dart';
import 'edit_round_screen.dart';

class ScorecardScreen extends StatelessWidget {
  final RoundData round;

  const ScorecardScreen({super.key, required this.round});

  @override
  Widget build(BuildContext context) {
    List<String> players = [round.userName ?? '나'];
    players.addAll(round.companions);

    return DefaultTabController(
      length: players.length,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('스코어카드'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: TabBar(
            isScrollable: players.length > 3,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: players.map((p) => Tab(text: p)).toList(),
          ),
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
        body: TabBarView(
          children: players.asMap().entries.map((entry) {
            return _buildPlayerTab(context, entry.key, entry.value);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPlayerTab(BuildContext context, int playerIndex, String playerName) {
    int totalPar = round.holes.fold(0, (sum, h) => sum + h.par);
    int totalPutt = 0;
    int overUnder = 0;
    int totalPenalty = 0;

    for (var h in round.holes) {
      if (playerIndex == 0) {
        totalPutt += (h.putt == -99 ? 0 : h.putt);
        overUnder += (h.score == -99 ? 0 : h.score);
        totalPenalty += h.penaltyStrokes;
      } else {
        int compIdx = playerIndex - 1;
        totalPutt += (h.companionPutts.length > compIdx && h.companionPutts[compIdx] != -99 ? h.companionPutts[compIdx] : 0);
        overUnder += (h.companionScores.length > compIdx && h.companionScores[compIdx] != -99 ? h.companionScores[compIdx] : 0);
        totalPenalty += (h.companionPenalties.length > compIdx ? h.companionPenalties[compIdx] : 0);
      }
    }

    int totalGross = totalPar + overUnder;
    String overUnderStr = overUnder > 0 ? '+$overUnder' : (overUnder < 0 ? '$overUnder' : 'E');
    QPointBreakdown qPointBreakdown = round.getQPointBreakdown(playerIndex);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$totalGross($overUnderStr)',
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold, 
                      color: overUnder < 0 ? Colors.red : (overUnder == 0 ? Colors.black87 : Colors.blue)
                    ),
                  ),
                  InkWell(
                    onTap: () => _showQPointBreakdown(context, round, playerIndex, playerName),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$totalPutt putt, ',
                          style: const TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Q ${qPointBreakdown.total}pt',
                          style: const TextStyle(fontSize: 16, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.info_outline, size: 14, color: Color(0xFFD4AF37)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('yyyy-MM-dd').format(round.date)} ${round.teeUpTime} | $playerName',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          _buildScorecardGrid(round.holes, 0, context, playerIndex),
          const SizedBox(height: 32),
          _buildScorecardGrid(round.holes, 9, context, playerIndex),
          const SizedBox(height: 16),
          _buildScoreLegend(),
          const SizedBox(height: 16),
          
          // 18홀이 모두 입력된 경우에만 통계 제공
          round.holes.where((h) => h.score != -99).length == 18
            ? Card(
                elevation: 1,
                color: Colors.grey.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('라운드 통계', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem('Gross', '$totalGross'),
                          _statItem('To Par', overUnderStr, color: overUnder < 0 ? Colors.red : (overUnder == 0 ? Colors.black87 : Colors.blue)),
                          _statItem('Putts', '$totalPutt'),
                          _statItem('Q-Point', '${qPointBreakdown.total}', color: const Color(0xFFD4AF37)),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade300, size: 32),
                      const SizedBox(height: 8),
                      const Text(
                        '18홀 기록이 모두 입력되어야 통계가 제공됩니다.',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _statItem(String title, String val, {Color? color}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
      ],
    );
  }

  void _showQPointBreakdown(BuildContext context, RoundData round, int playerIndex, String playerName) {
    final breakdown = round.getQPointBreakdown(playerIndex);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFFF1F4F1),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${round.golfCourseName} Q-Point 상세', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(color: Colors.grey, height: 10),
                const SizedBox(height: 5),
                _buildQPointBonusRow('Sub-80 Round', breakdown.under80 ? 4 : 0),
                _buildQPointBonusRow('Scrambling 50%+', breakdown.scrambling ? 4 : 0),
                _buildQPointBonusRow('One Ball Play', breakdown.noPenalty ? 4 : 0),
                _buildQPointBonusRow('Digital Round', breakdown.digital ? 4 : 0),
                _buildQPointBonusRow('No Three Putt', breakdown.noThreePutt ? 4 : 0),
                _buildQPointBonusRow('GIR 50%+', breakdown.gir50 ? 4 : 0),
                _buildQPointBonusRow('Putts 29 or less', breakdown.puttsUnder30 ? 4 : 0),
                _buildQPointBonusRow('Bounce Back', breakdown.bounceBackCount * 2),
                const Divider(color: Colors.grey, height: 10),
                // 홀 상세: 1-9번(왼쪽) / 10-18번(오른쪽) 나란히 표시
                if (breakdown.holeDetails.length >= 18)
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1),
                      1: FlexColumnWidth(1),
                    },
                    children: List.generate(9, (i) {
                      final left = breakdown.holeDetails[i];
                      final right = breakdown.holeDetails[i + 9];
                      return TableRow(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${left.holeNumber}번 ${left.on}온 ${left.putt}펏, ${left.scoreLabel}',
                                    style: const TextStyle(fontSize: 10.5, color: Colors.blueGrey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${left.points}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${right.holeNumber}번 ${right.on}온 ${right.putt}펏, ${right.scoreLabel}',
                                    style: const TextStyle(fontSize: 10.5, color: Colors.blueGrey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${right.points}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  )
                else
                  Column(
                    children: breakdown.holeDetails.map((d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${d.holeNumber}번홀 ${d.on}온 ${d.putt}펏, ${d.scoreLabel}',
                              style: const TextStyle(fontSize: 10.5, color: Colors.blueGrey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${d.points}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                const Divider(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$playerName님의 총 Q-Point', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${breakdown.total}pt', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기', style: TextStyle(color: Color(0xFF27AE60), fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQPointBonusRow(String title, int points) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.black87, fontSize: 14)),
          Text(
            '$points',
            style: TextStyle(
              color: points > 0 ? Colors.blue : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScorecardGrid(List<HoleData> holes, int startIndex, BuildContext context, int playerIndex) {
    if (holes.length < startIndex + 9) return const SizedBox(); 

    final subHoles = holes.sublist(startIndex, startIndex + 9);
    final totalPar = subHoles.fold(0, (sum, h) => sum + h.par);
    
    int totalScore = 0;
    int totalPutt = 0;
    
    for (var h in subHoles) {
      if (playerIndex == 0) {
        totalScore += (h.score == -99 ? 0 : h.score);
        totalPutt += (h.putt == -99 ? 0 : h.putt);
      } else {
        int compIdx = playerIndex - 1;
        totalScore += (h.companionScores.length > compIdx && h.companionScores[compIdx] != -99 ? h.companionScores[compIdx] : 0);
        totalPutt += (h.companionPutts.length > compIdx && h.companionPutts[compIdx] != -99 ? h.companionPutts[compIdx] : 0);
      }
    }

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 1),
      columnWidths: const {
        0: FlexColumnWidth(1.6),
        10: FlexColumnWidth(1.6),
      },
      defaultColumnWidth: const FlexColumnWidth(1.0),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            _buildCell('HOLE', isHeader: true),
            for (int i = 1; i <= 9; i++) _buildCell('${startIndex + i}', isHeader: true),
            _buildCell('TOTAL', isHeader: true),
          ],
        ),
        TableRow(
          children: [
            _buildCell('PAR', isHeader: true),
            for (var h in subHoles) _buildCell('${h.par}'),
            _buildCell('$totalPar', isBold: true),
          ],
        ),
        TableRow(
          children: [
            _buildCell('SCORE', isHeader: true),
            for (var h in subHoles) _buildScoreCell(h, playerIndex),
            _buildScoreCell(null, playerIndex, customScore: totalScore, isBold: true),
          ],
        ),
        TableRow(
          children: [
            _buildCell('PUTT', isHeader: true),
            for (var h in subHoles) _buildCell('${_getPlayerPutt(h, playerIndex)}'),
            _buildCell('$totalPutt', isBold: true),
          ],
        ),
      ],
    );
  }

  int _getPlayerScore(HoleData h, int playerIndex) {
    if (playerIndex == 0) return h.score == -99 ? 0 : h.score;
    int cIdx = playerIndex - 1;
    return (h.companionScores.length > cIdx && h.companionScores[cIdx] != -99) ? h.companionScores[cIdx] : 0;
  }

  int _getPlayerPutt(HoleData h, int playerIndex) {
    if (playerIndex == 0) return h.putt == -99 ? 0 : h.putt;
    int cIdx = playerIndex - 1;
    return (h.companionPutts.length > cIdx && h.companionPutts[cIdx] != -99) ? h.companionPutts[cIdx] : 0;
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

  Widget _buildScoreCell(HoleData? h, int playerIndex, {int? customScore, bool isBold = false}) {
    int score = customScore ?? (h != null ? _getPlayerScore(h, playerIndex) : 0);
    String text = score == 0 ? '0' : (score > 0 ? '+$score' : '$score');
    
    Color textColor = Colors.black87;
    Color bgColor = Colors.transparent;
    
    if (score <= -2) {
      bgColor = Colors.red;
      textColor = Colors.white;
    } else if (score == -1) {
      bgColor = Colors.red.shade200;
      textColor = Colors.black87;
    } else if (score == 1) {
      bgColor = Colors.cyan.shade200;
      textColor = Colors.black87;
    } else if (score >= 2) {
      bgColor = Colors.blue;
      textColor = Colors.white;
    }

    // 니어리스트 표시 (파3에서만)
    Widget? nearestMarker;
    if (h != null && h.par == 3 && h.nearestPlayerIndex == playerIndex) {
      if (score <= 0) {
        nearestMarker = const Positioned(
          top: 1,
          right: 2,
          child: Text('★', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
        );
      } else {
        nearestMarker = const Positioned(
          top: 1,
          right: 2,
          child: Text('X', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
        );
      }
    }

    return Container(
      color: bgColor,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textColor,
              ),
            ),
          ),
          if (nearestMarker != null) nearestMarker,
        ],
      ),
    );
  }

  Widget _buildScoreLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('이글', Colors.red),
          _buildLegendItem('버디', Colors.red.shade200),
          _buildLegendItem('파', Colors.transparent, hasBorder: true),
          _buildLegendItem('보기', Colors.cyan.shade200),
          _buildLegendItem('더블보기 이상', Colors.blue),
          const SizedBox(width: 8),
          const Text('★', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
          const Text(' 니어 성공', style: TextStyle(fontSize: 11, color: Colors.black87)),
          const SizedBox(width: 8),
          const Text('X', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
          const Text(' 니어 실패', style: TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {bool hasBorder = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color, 
              shape: BoxShape.circle,
              border: hasBorder ? Border.all(color: Colors.grey.shade400) : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }
}

