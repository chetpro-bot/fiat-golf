import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/round_model.dart';
import '../services/betting_service.dart';
import '../services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class RoundResultScreen extends StatelessWidget {
  final RoundData round;

  const RoundResultScreen({super.key, required this.round});

  @override
  Widget build(BuildContext context) {
    final List<String> allPlayers = [round.userName ?? '나', ...round.companions];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('라운드 리포트', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.email_outlined),
            tooltip: '이메일로 보내기',
            onPressed: () => _sendEmail(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: 구현 예정 (스크린샷 저장 또는 텍스트 공유)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('공유 기능 준비 중입니다.')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            _buildRoundHeader(),
            const SizedBox(height: 24),
            _buildOverallScorecard(context, allPlayers),
            if (round.ojangConfig.enabled) ...[
              const SizedBox(height: 24),
              _buildOjangSettlement(allPlayers),
            ],
            const SizedBox(height: 32),
            const Divider(height: 1, thickness: 1, indent: 24, endIndent: 24),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.analytics, color: Color(0xFF27AE60)),
                  const SizedBox(width: 8),
                  Text('개인별 상세 통계', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(allPlayers.length, (index) {
              return _buildIndividualReport(context, allPlayers[index], index);
            }),
            const SizedBox(height: 40),
            Text(
              'App Version: 1.4.7+28',
              style: TextStyle(fontSize: 12, color: Colors.grey.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                round.golfCourseName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '18H 완료',
                  style: TextStyle(color: Color(0xFF27AE60), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${DateFormat('yyyy년 MM월 dd일').format(round.date)}  |  ${round.teeUpTime}',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.map_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${round.frontCourseName} - ${round.backCourseName}',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverallScorecard(BuildContext context, List<String> playerNames) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            '${round.frontCourseName} 코스',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF34495E)),
          ),
        ),
        _buildScoreTable(playerNames, 0, 9),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            '${round.backCourseName} 코스',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF34495E)),
          ),
        ),
        _buildScoreTable(playerNames, 9, 18),
        _buildLegend(),
      ],
    );
  }

  Widget _buildScoreTable(List<String> playerNames, int start, int end) {
    final subHoles = round.holes.sublist(start, end);
    final totalPar = subHoles.fold(0, (sum, h) => sum + h.par);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.0),
          10: FlexColumnWidth(1.5),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          // Header: Hole Numbers
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade50),
            children: [
              _buildCell('HOLE', isHeader: true),
              ...List.generate(9, (i) => _buildCell('${start + i + 1}', isHeader: true)),
              _buildCell('TOTAL', isHeader: true),
            ],
          ),
          // Par Row
          TableRow(
            children: [
              _buildCell('PAR', isBold: true),
              ...subHoles.map((h) => _buildCell('${h.par}')),
              _buildCell('$totalPar', isBold: true),
            ],
          ),
          // Player Rows
          ...List.generate(playerNames.length, (pIdx) {
            int subTotal = 0;
            for (var h in subHoles) {
              subTotal += _getPlayerScore(h, pIdx);
            }
            return TableRow(
              children: [
                _buildCell(playerNames[pIdx], isBold: true, textAlign: TextAlign.left),
                ...subHoles.map((h) => _buildScoreCell(_getPlayerScore(h, pIdx), h.par, h, pIdx)),
                _buildScoreCell(subTotal, 0, null, 0, isTotal: true),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCell(String text, {bool isHeader = false, bool isBold = false, TextAlign textAlign = TextAlign.center}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      alignment: textAlign == TextAlign.center ? Alignment.center : Alignment.centerLeft,
      child: Padding(
        padding: textAlign == TextAlign.left ? const EdgeInsets.only(left: 8) : EdgeInsets.zero,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
            color: isHeader ? Colors.grey.shade600 : const Color(0xFF2C3E50),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildScoreCell(int score, int par, HoleData? hole, int playerIndex, {bool isTotal = false}) {
    String text = score == 0 ? '0' : (score > 0 ? '+$score' : '$score');
    if (isTotal) {
      int gross = (hole == null) ? score + 36 : score; // TOTAL cell logic needs adjustment if not 9 holes
      // Simple display for total: just the over/under
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2C3E50)),
        ),
      );
    }

    Color bgColor = Colors.transparent;
    Color textColor = const Color(0xFF2C3E50);

    if (score <= -2) {
      bgColor = const Color(0xFFE74C3C); // Eagle+
      textColor = Colors.white;
    } else if (score == -1) {
      bgColor = const Color(0xFFFFADAD); // Birdie
    } else if (score == 1) {
      bgColor = const Color(0xFFA0E7E5); // Bogey
    } else if (score >= 2) {
      bgColor = const Color(0xFF3498DB); // Double+
      textColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: bgColor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            text,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
          ),
          if (hole != null && hole.par == 3 && hole.nearestPlayerIndex == playerIndex)
            Positioned(
              top: -2,
              right: 0,
              child: Text(
                score <= 0 ? '★' : 'X',
                style: TextStyle(
                  color: score <= 0 ? Colors.amber : Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildLegendItem('이글', const Color(0xFFE74C3C)),
          _buildLegendItem('버디', const Color(0xFFFFADAD)),
          _buildLegendItem('파', Colors.white, hasBorder: true),
          _buildLegendItem('보기', const Color(0xFFA0E7E5)),
          _buildLegendItem('더블+', const Color(0xFF3498DB)),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('★', style: TextStyle(color: Colors.amber, fontSize: 12)),
              Text(' 니어성공', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('X', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(' 니어실패', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {bool hasBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: hasBorder ? Border.all(color: Colors.grey.shade300) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildOjangSettlement(List<String> playerNames) {
    final totals = BettingService.calculateTotal(round);

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Color(0xFFD4AF37), size: 20),
              SizedBox(width: 8),
              Text(
                '오장마스터 정산 결과',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(playerNames.length, (i) {
              final isPositive = totals[i] >= 0;
              return Column(
                children: [
                  Text(
                    playerNames[i],
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isPositive ? '+' : ''}${NumberFormat('#,###').format(totals[i])}',
                    style: TextStyle(
                      color: isPositive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualReport(BuildContext context, String name, int playerIndex) {
    final stats = _calculateStats(playerIndex);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: playerIndex == 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF27AE60).withOpacity(0.1),
              radius: 16,
              child: Text(
                name[0],
                style: const TextStyle(color: Color(0xFF27AE60), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(
              '${stats.totalGross}(${stats.overUnderStr})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: stats.totalOverUnder < 0 ? Colors.red : (stats.totalOverUnder == 0 ? Colors.black87 : Colors.blue),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIndividualScoreGrid(playerIndex),
                const SizedBox(height: 24),
                _buildStatsSection(stats),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualScoreGrid(int playerIndex) {
    return Column(
      children: [
        _buildMiniGrid(0, 9, playerIndex),
        const SizedBox(height: 8),
        _buildMiniGrid(9, 18, playerIndex),
      ],
    );
  }

  Widget _buildMiniGrid(int start, int end, int playerIndex) {
    final subHoles = round.holes.sublist(start, end);
    return Table(
      border: TableBorder.all(color: Colors.grey.shade100),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade50),
          children: [
            _buildMiniCell('H', isHeader: true),
            ...subHoles.map((h) => _buildMiniCell('${h.holeNumber}', isHeader: true)),
          ],
        ),
        TableRow(
          children: [
            _buildMiniCell('S'),
            ...subHoles.map((h) => _buildMiniScoreCell(_getPlayerScore(h, playerIndex), h.par)),
          ],
        ),
        TableRow(
          children: [
            _buildMiniCell('P'),
            ...subHoles.map((h) => _buildMiniCell('${_getPlayerPutt(h, playerIndex)}')),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniCell(String text, {bool isHeader = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.grey : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMiniScoreCell(int score, int par) {
    Color bgColor = Colors.transparent;
    if (score <= -1) bgColor = const Color(0xFFFFADAD).withOpacity(0.3);
    else if (score >= 1) bgColor = const Color(0xFFA0E7E5).withOpacity(0.3);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: bgColor,
      alignment: Alignment.center,
      child: Text(
        score == 0 ? '0' : (score > 0 ? '+$score' : '$score'),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatsSection(_PlayerStats stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard('그린 적중률', '${stats.girPct.toStringAsFixed(1)}%', '${stats.girHits}/18')),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('스크램블링', '${stats.scramblingPct.toStringAsFixed(1)}%', '${stats.scramblingSuccesses}/${stats.scramblingChances}')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('평균 퍼트', stats.avgPutts.toStringAsFixed(1), '총 ${stats.totalPutts}회')),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('벌타 합계', '${stats.totalPenalty}', 'OB ${stats.obCount} / Haz ${stats.hazCount}')),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String subValue) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
          Text(subValue, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _sendEmail(BuildContext context) async {
    final userEmail = AuthService().currentUser?.email;
    if (userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인된 이메일 정보를 찾을 수 없습니다.')),
      );
      return;
    }

    final subject = Uri.encodeComponent('[Golf Score] ${round.golfCourseName} 라운드 리포트');
    
    // 이메일 본문 생성
    final buffer = StringBuffer();
    buffer.writeln('⛳ ${round.golfCourseName} 라운드 결과 리포트');
    buffer.writeln('일시: ${DateFormat('yyyy-MM-dd').format(round.date)} ${round.teeUpTime}');
    buffer.writeln('코스: ${round.frontCourseName} - ${round.backCourseName}');
    buffer.writeln('\n------------------------------');
    
    final playerNames = [round.userName ?? '나', ...round.companions];
    final totals = round.ojangConfig.enabled ? BettingService.calculateTotal(round) : null;

    for (int i = 0; i < playerNames.length; i++) {
      final stats = _calculateStats(i);
      buffer.writeln('\n👤 ${playerNames[i]}');
      buffer.writeln('스코어: ${stats.totalGross}타 (${stats.overUnderStr})');
      buffer.writeln('퍼트: 총 ${stats.totalPutts}회 (평균 ${stats.avgPutts.toStringAsFixed(1)})');
      buffer.writeln('그린적중률(GIR): ${stats.girPct.toStringAsFixed(1)}%');
      buffer.writeln('벌타: ${stats.totalPenalty}타 (OB ${stats.obCount}, Hazard ${stats.hazCount})');
      if (totals != null) {
        final amount = totals[i];
        buffer.writeln('정산: ${amount >= 0 ? '+' : ''}${NumberFormat('#,###').format(amount)}원');
      }
    }

    buffer.writeln('\n------------------------------');
    buffer.writeln('앱에서 상세 내용을 확인하세요.');
    
    final body = Uri.encodeComponent(buffer.toString());
    final url = Uri.parse('mailto:$userEmail?subject=$subject&body=$body');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메일 앱을 열 수 없습니다.')),
      );
    }
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

  _PlayerStats _calculateStats(int playerIndex) {
    int girHits = 0;
    int scramblingChances = 0;
    int scramblingSuccesses = 0;
    int totalPutts = 0;
    int totalPenalty = 0;
    int obCount = 0;
    int hazCount = 0;
    int totalOverUnder = 0;
    int totalPar = 0;

    for (var hole in round.holes) {
      int score = _getPlayerScore(hole, playerIndex);
      int putt = _getPlayerPutt(hole, playerIndex);
      
      totalOverUnder += score;
      totalPar += hole.par;
      totalPutts += putt;
      
      // Penalty
      if (playerIndex == 0) {
        obCount += hole.teeOb + hole.secondOb;
        hazCount += hole.teeHazard + hole.secondHazard;
      } else {
        int cIdx = playerIndex - 1;
        obCount += hole.companionTeeOb[cIdx] + hole.companionSecondOb[cIdx];
        hazCount += hole.companionTeeHazard[cIdx] + hole.companionSecondHazard[cIdx];
      }

      // GIR & Scrambling
      bool isGir = (score - putt) <= -2;
      if (isGir) {
        girHits++;
      } else {
        scramblingChances++;
        if (score <= 0) scramblingSuccesses++;
      }
    }
    
    totalPenalty = (obCount * 2) + hazCount;

    return _PlayerStats(
      totalGross: totalPar + totalOverUnder,
      totalOverUnder: totalOverUnder,
      girHits: girHits,
      girPct: (girHits / 18) * 100,
      scramblingChances: scramblingChances,
      scramblingSuccesses: scramblingSuccesses,
      scramblingPct: scramblingChances > 0 ? (scramblingSuccesses / scramblingChances) * 100 : 0,
      totalPutts: totalPutts,
      avgPutts: totalPutts / 18,
      totalPenalty: totalPenalty,
      obCount: obCount,
      hazCount: hazCount,
    );
  }
}

class _PlayerStats {
  final int totalGross;
  final int totalOverUnder;
  final int girHits;
  final double girPct;
  final int scramblingChances;
  final int scramblingSuccesses;
  final double scramblingPct;
  final int totalPutts;
  final double avgPutts;
  final int totalPenalty;
  final int obCount;
  final int hazCount;

  _PlayerStats({
    required this.totalGross,
    required this.totalOverUnder,
    required this.girHits,
    required this.girPct,
    required this.scramblingChances,
    required this.scramblingSuccesses,
    required this.scramblingPct,
    required this.totalPutts,
    required this.avgPutts,
    required this.totalPenalty,
    required this.obCount,
    required this.hazCount,
  });

  String get overUnderStr => totalOverUnder == 0 ? 'E' : (totalOverUnder > 0 ? '+$totalOverUnder' : '$totalOverUnder');
}
