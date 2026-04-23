import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/round_model.dart';
import '../services/betting_service.dart';
import '../services/auth_service.dart';

class RoundResultScreen extends StatefulWidget {
  final RoundData round;

  const RoundResultScreen({super.key, required this.round});

  @override
  State<RoundResultScreen> createState() => _RoundResultScreenState();
}

class _RoundResultScreenState extends State<RoundResultScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  int _selectedPlayerIndex = 0;
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final List<String> allPlayers = [widget.round.userName ?? '나', ...widget.round.companions];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('라운드 리포트', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '이미지로 공유하기',
            onPressed: _isSharing ? null : _shareImage,
          ),
        ],
      ),
      body: _isSharing 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Screenshot(
              controller: _screenshotController,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    _buildRoundHeader(),
                    const SizedBox(height: 32),
                    _buildOverallScorecard(allPlayers),
                    if (widget.round.ojangConfig.enabled) ...[
                      const SizedBox(height: 32),
                      _buildOjangSettlement(allPlayers),
                    ],
                    const SizedBox(height: 40),
                    const Divider(height: 1, thickness: 1, indent: 24, endIndent: 24),
                    const SizedBox(height: 32),
          _buildDetailedStatsSection(allPlayers),
                    const SizedBox(height: 40),
                    Text(
                      'App Version: 1.4.9+30',
                      style: TextStyle(fontSize: 12, color: Colors.grey.withOpacity(0.5)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildRoundHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.round.golfCourseName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  DateFormat('yyyy.MM.dd').format(widget.round.date),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.round.frontCourseName} - ${widget.round.backCourseName}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallScorecard(List<String> playerNames) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCourseScoreSection(playerNames, widget.round.frontCourseName, 0, 9),
        const SizedBox(height: 32),
        _buildCourseScoreSection(playerNames, widget.round.backCourseName, 9, 18),
        _buildLegend(),
      ],
    );
  }

  Widget _buildCourseScoreSection(List<String> playerNames, String courseName, int start, int end) {
    final subHoles = widget.round.holes.sublist(start, end);
    final totalPar = subHoles.fold(0, (sum, h) => sum + h.par);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            courseName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(3.0), // 너비 소폭 확장
              10: FlexColumnWidth(2.2), // 너비 소폭 확장
            },
            border: TableBorder.all(color: Colors.grey.shade200),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Header
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade50),
                children: [
                  _buildCell('HOLE', isHeader: true),
                  ...List.generate(9, (i) => _buildCell('${start + i + 1}', isHeader: true)),
                  _buildCell('TOTAL', isHeader: true),
                ],
              ),
              // Par
              TableRow(
                children: [
                  _buildCell('PAR', isBold: true),
                  ...subHoles.map((h) => _buildCell('${h.par}')),
                  _buildCell('$totalPar', isBold: true),
                ],
              ),
              // Players
              ...List.generate(playerNames.length, (pIdx) {
                int totalScore = 0;
                for (var h in subHoles) {
                  totalScore += _getPlayerScore(h, pIdx);
                }
                final overUnderStr = totalScore == 0 ? 'E' : (totalScore > 0 ? '+$totalScore' : '$totalScore');
                
                return TableRow(
                  children: [
                    _buildCell(playerNames[pIdx], isBold: true, textAlign: TextAlign.left),
                    ...subHoles.map((h) => _buildScoreCell(_getPlayerScore(h, pIdx), h.par, h, pIdx)),
                    _buildCell(overUnderStr, isBold: true),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCell(String text, {bool isHeader = false, bool isBold = false, TextAlign textAlign = TextAlign.center}) {
    return Container(
      height: 36,
      alignment: textAlign == TextAlign.center ? Alignment.center : Alignment.centerLeft,
      padding: textAlign == TextAlign.left ? const EdgeInsets.only(left: 4) : EdgeInsets.zero,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10, // 폰트 크기 축소
          fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.grey : Colors.black,
        ),
      ),
    );
  }

  Widget _buildScoreCell(int score, int par, HoleData hole, int playerIndex) {
    String text = score == 0 ? '0' : (score > 0 ? '+$score' : '$score');
    Color? bgColor;
    Color textColor = Colors.black;

    if (score <= -2) {
      bgColor = const Color(0xFFE74C3C);
      textColor = Colors.white;
    } else if (score == -1) {
      bgColor = const Color(0xFFFFADAD);
    } else if (score == 1) {
      bgColor = const Color(0xFFA0E7E5);
    } else if (score >= 2) {
      bgColor = const Color(0xFF3498DB);
      textColor = Colors.white;
    }

    return Container(
      height: 36,
      color: bgColor,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
          ),
          if (hole.par == 3 && hole.nearestPlayerIndex == playerIndex)
            Positioned(
              top: 0,
              right: 1, // 우측으로 더 이동
              child: Text(
                score <= 0 ? '★' : 'X',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 8, // 크기 축소
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildLegendItem('이글', const Color(0xFFE74C3C)),
          const SizedBox(width: 8),
          _buildLegendItem('버디', const Color(0xFFFFADAD)),
          const SizedBox(width: 8),
          _buildLegendItem('파', Colors.white, hasBorder: true),
          const SizedBox(width: 8),
          _buildLegendItem('보기', const Color(0xFFA0E7E5)),
          const SizedBox(width: 8),
          _buildLegendItem('더블보기 이상', const Color(0xFF3498DB)),
          const SizedBox(width: 12),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('★', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(' 니어성공', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(width: 8),
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
          width: 10,
          height: 10,
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
    final totals = BettingService.calculateTotal(widget.round);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💰 정산 결과',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(playerNames.length, (i) {
              final isPositive = totals[i] >= 0;
              return Column(
                children: [
                  Text(
                    playerNames[i],
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isPositive ? '+' : ''}${NumberFormat('#,###').format(totals[i])}',
                    style: TextStyle(
                      color: isPositive ? Colors.blue : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

  Widget _buildDetailedStatsSection(List<String> playerNames) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Icon(Icons.analytics, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                '개인 라운드 통계',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF3F51B5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Player Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(playerNames.length, (index) {
              final isSelected = _selectedPlayerIndex == index;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(playerNames[index]),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedPlayerIndex = index;
                      });
                    }
                  },
                  selectedColor: Colors.blue.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.blue : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade300),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 24),
        _buildPlayerStatsCard(playerNames[_selectedPlayerIndex], _selectedPlayerIndex),
      ],
    );
  }

  Widget _buildPlayerStatsCard(String name, int playerIndex) {
    final stats = _calculateDetailedStats(playerIndex);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Individual Scorecards for the selected player
          _buildIndividualCourseCard(widget.round.frontCourseName, 0, 9, playerIndex),
          const SizedBox(height: 24),
          _buildIndividualCourseCard(widget.round.backCourseName, 9, 18, playerIndex),
          const SizedBox(height: 16),
          _buildLegend(),
          const SizedBox(height: 32),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 24),
          // Row 1: GIR & Scrambling
          Row(
            children: [
              Expanded(child: _buildStatItem('그린 적중률', '${stats.girPct.toStringAsFixed(1)}% (${stats.girHits}/18)')),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(child: _buildStatItem('스크램블링', '${stats.scramblingPct.toStringAsFixed(1)}% (${stats.scramblingSuccesses}/${stats.scramblingChances})')),
            ],
          ),
          const SizedBox(height: 24),
          const Text('퍼트 통계', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF34495E))),
          const SizedBox(height: 12),
          // Row 2: Putts (Avg), Putts on GIR, Putts on Miss
          Row(
            children: [
              Expanded(child: _buildStatItem('총 퍼트 (평균)', '${stats.totalPutts} (${stats.avgPutts.toStringAsFixed(1)})')),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(child: _buildStatItem('파온 성공시', stats.puttsOnGir.toStringAsFixed(1))),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(child: _buildStatItem('파온 실패시', stats.puttsMissGir.toStringAsFixed(1))),
            ],
          ),
          const SizedBox(height: 12),
          // Row 3: 1-putt, 2-putt, 3-putt
          Row(
            children: [
              Expanded(child: _buildStatItem('1퍼트', '${stats.putt1Count}')),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(child: _buildStatItem('2퍼트', '${stats.putt2Count}')),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(child: _buildStatItem('3퍼트 이상', '${stats.putt3PlusCount}')),
            ],
          ),
          const SizedBox(height: 24),
          const Text('패널티 통계', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF34495E))),
          const SizedBox(height: 12),
          // Row 4: Total Penalty, Tee Penalty, Second Penalty
          Row(
            children: [
              Expanded(child: _buildStatItem('합계 (벌타)', '${stats.totalPenalty}')),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(child: _buildStatItem('티샷 벌타', 'OB ${stats.teeOb} / Haz ${stats.teeHaz}')),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(child: _buildStatItem('세컨샷 벌타', 'OB ${stats.secondOb} / Haz ${stats.secondHaz}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualCourseCard(String courseName, int start, int end, int playerIndex) {
    final subHoles = widget.round.holes.sublist(start, end);
    int subTotalScore = 0;
    int subTotalPutt = 0;
    int subTotalPar = 0;
    int subQPoints = 0;

    for (var h in subHoles) {
      subTotalScore += _getPlayerScore(h, playerIndex);
      subTotalPutt += _getPlayerPutt(h, playerIndex);
      subTotalPar += h.par;
      // Calculate Q-points for these holes
      final hScore = _getPlayerScore(h, playerIndex) + h.par;
      final diff = hScore - h.par;
      if (diff <= -2) subQPoints += 5; // Eagle+
      else if (diff == -1) subQPoints += 3; // Birdie
      else if (diff == 0) subQPoints += 2; // Par
      else if (diff == 1) subQPoints += 1; // Bogey
    }

    final totalGross = subTotalPar + subTotalScore;
    final overUnderStr = subTotalScore == 0 ? 'E' : (subTotalScore > 0 ? '+$subTotalScore' : '$subTotalScore');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(courseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              '$totalGross($overUnderStr), $subTotalPutt putt, Q ${subQPoints}pt',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade200),
            columnWidths: const {
              0: FlexColumnWidth(3.0),
              10: FlexColumnWidth(2.2),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade50),
                children: [
                  _buildCell('HOLE', isHeader: true),
                  ...List.generate(9, (i) => _buildCell('${start + i + 1}', isHeader: true)),
                  _buildCell('TOTAL', isHeader: true),
                ],
              ),
              TableRow(
                children: [
                  _buildCell('PAR', isBold: true),
                  ...subHoles.map((h) => _buildCell('${h.par}')),
                  _buildCell('$subTotalPar', isBold: true),
                ],
              ),
              TableRow(
                children: [
                  _buildCell('SCORE', isBold: true),
                  ...subHoles.map((h) => _buildScoreCell(_getPlayerScore(h, playerIndex), h.par, h, playerIndex)),
                  _buildCell(overUnderStr, isBold: true),
                ],
              ),
              TableRow(
                children: [
                  _buildCell('PUTT', isBold: true),
                  ...subHoles.map((h) => _buildCell('${_getPlayerPutt(h, playerIndex)}')),
                  _buildCell('$subTotalPutt', isBold: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  _DetailedStats _calculateDetailedStats(int playerIndex) {
    int girHits = 0;
    int scramblingChances = 0;
    int scramblingSuccesses = 0;
    int totalPutts = 0;
    int girPuttSum = 0;
    int missGirPuttSum = 0;
    int putt1Count = 0;
    int putt2Count = 0;
    int putt3PlusCount = 0;
    int teeOb = 0;
    int teeHaz = 0;
    int secondOb = 0;
    int secondHaz = 0;

    for (var hole in widget.round.holes) {
      int score = _getPlayerScore(hole, playerIndex);
      int putt = _getPlayerPutt(hole, playerIndex);
      totalPutts += putt;

      // Putt counts
      if (putt == 1) putt1Count++;
      else if (putt == 2) putt2Count++;
      else if (putt >= 3) putt3PlusCount++;

      // Penalty
      if (playerIndex == 0) {
        teeOb += hole.teeOb;
        teeHaz += hole.teeHazard;
        secondOb += hole.secondOb;
        secondHaz += hole.secondHazard;
      } else {
        int cIdx = playerIndex - 1;
        teeOb += hole.companionTeeOb[cIdx];
        teeHaz += hole.companionTeeHazard[cIdx];
        secondOb += hole.companionSecondOb[cIdx];
        secondHaz += hole.companionSecondHazard[cIdx];
      }

      // GIR & Scrambling
      bool isGir = (score - putt) <= -2;
      if (isGir) {
        girHits++;
        girPuttSum += putt;
      } else {
        scramblingChances++;
        if (score <= 0) scramblingSuccesses++;
        missGirPuttSum += putt;
      }
    }

    return _DetailedStats(
      girHits: girHits,
      girPct: (girHits / 18) * 100,
      scramblingChances: scramblingChances,
      scramblingSuccesses: scramblingSuccesses,
      scramblingPct: scramblingChances > 0 ? (scramblingSuccesses / scramblingChances) * 100 : 0,
      totalPutts: totalPutts,
      avgPutts: totalPutts / 18,
      puttsOnGir: girHits > 0 ? girPuttSum / girHits : 0,
      puttsMissGir: (18 - girHits) > 0 ? missGirPuttSum / (18 - girHits) : 0,
      putt1Count: putt1Count,
      putt2Count: putt2Count,
      putt3PlusCount: putt3PlusCount,
      totalPenalty: (teeOb + secondOb) * 2 + (teeHaz + secondHaz),
      teeOb: teeOb,
      teeHaz: teeHaz,
      secondOb: secondOb,
      secondHaz: secondHaz,
    );
  }

  Future<void> _shareImage() async {
    setState(() => _isSharing = true);
    try {
      final image = await _screenshotController.capture();
      if (image != null) {
        // Web 환경 대응: 브라우저에서는 파일 공유가 제한적일 수 있으므로 다운로드 기능을 우선 고려
        // 모바일 앱 환경에서는 Share.shareXFiles가 정상 작동함
        final directory = await getTemporaryDirectory();
        final fileName = 'round_report_${DateTime.now().millisecondsSinceEpoch}.png';
        final imagePath = '${directory.path}/$fileName';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(image);

        // Web인 경우 다운로드 링크 생성 시도
        // (참고: 웹 전용 share_plus는 Navigator.share를 사용하지만 이미지 공유는 브라우저 지원 여부에 따라 다름)
        await Share.shareXFiles(
          [XFile(imagePath, name: fileName, mimeType: 'image/png')],
          text: '${widget.round.golfCourseName} 라운드 리포트입니다.⛳',
        );
      }
    } catch (e) {
      debugPrint('Share Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공유 중 오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}

class _DetailedStats {
  final int girHits;
  final double girPct;
  final int scramblingChances;
  final int scramblingSuccesses;
  final double scramblingPct;
  final int totalPutts;
  final double avgPutts;
  final double puttsOnGir;
  final double puttsMissGir;
  final int putt1Count;
  final int putt2Count;
  final int putt3PlusCount;
  final int totalPenalty;
  final int teeOb;
  final int teeHaz;
  final int secondOb;
  final int secondHaz;

  _DetailedStats({
    required this.girHits,
    required this.girPct,
    required this.scramblingChances,
    required this.scramblingSuccesses,
    required this.scramblingPct,
    required this.totalPutts,
    required this.avgPutts,
    required this.puttsOnGir,
    required this.puttsMissGir,
    required this.putt1Count,
    required this.putt2Count,
    required this.putt3PlusCount,
    required this.totalPenalty,
    required this.teeOb,
    required this.teeHaz,
    required this.secondOb,
    required this.secondHaz,
  });
}
