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
              Text(
                '$totalGross($overUnderStr)',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue),
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
          
          const SizedBox(height: 24),
          Card(
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
                      _statItem('To Par', overUnderStr),
                      _statItem('Putts', '$totalPutt'),
                      _statItem('Penalties', '$totalPenalty'),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _statItem(String title, String val) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
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
            for (var h in subHoles) _buildScoreCell(_getPlayerScore(h, playerIndex)),
            _buildScoreCell(totalScore, isBold: true),
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

  Widget _buildScoreCell(int score, {bool isBold = false}) {
    Color bgColor = Colors.transparent;
    String text = score == 0 ? '0' : (score > 0 ? '+$score' : '$score');
    
    if (score < 0) {
      bgColor = Colors.red.shade200;
    } else if (score > 0) {
      bgColor = Colors.cyan.shade200;
    } else {
      bgColor = Colors.grey.shade100;
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.black87,
        ),
      ),
    );
  }
}
