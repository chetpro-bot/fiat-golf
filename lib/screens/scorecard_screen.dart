import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/round_model.dart';
import '../services/download_service.dart';
import '../widgets/q_point_breakdown_dialog.dart';
import 'edit_round_screen.dart';

class ScorecardScreen extends StatefulWidget {
  final RoundData round;

  const ScorecardScreen({super.key, required this.round});

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {
  // 탭별로 각각 독립된 RepaintBoundary 키를 갖습니다.
  final List<GlobalKey> _repaintKeys = [];
  bool _isDownloading = false;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    List<String> players = [widget.round.userName ?? '나'];
    players.addAll(widget.round.companions);
    _repaintKeys.addAll(List.generate(players.length, (_) => GlobalKey()));
  }

  List<String> get _players {
    List<String> p = [widget.round.userName ?? '나'];
    p.addAll(widget.round.companions);
    return p;
  }

  Future<void> _downloadCurrentTab() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    final playerName = _players[_currentTabIndex];
    final dateStr = DateFormat('yyyyMMdd').format(widget.round.date);
    final filename = '스코어카드_${widget.round.golfCourseName}_${playerName}_$dateStr.png';

    await DownloadService.captureAndDownload(
      repaintKey: _repaintKeys[_currentTabIndex],
      filename: filename,
      pixelRatio: 2.5,
      context: context,
    );

    if (mounted) setState(() => _isDownloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _players.length,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('스코어카드'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: TabBar(
            isScrollable: _players.length > 3,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: _players.map((p) => Tab(text: p)).toList(),
            onTap: (index) {
              setState(() => _currentTabIndex = index);
            },
          ),
          actions: [
            IconButton(
              icon: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              tooltip: '스코어카드 이미지 저장',
              onPressed: _isDownloading ? null : _downloadCurrentTab,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: '수정하기',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditRoundScreen(round: widget.round),
                  ),
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: _players.asMap().entries.map((entry) {
            return _buildPlayerTab(context, entry.key, entry.value);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPlayerTab(BuildContext context, int playerIndex, String playerName) {
    int totalPar = widget.round.holes.fold(0, (sum, h) => sum + h.par);
    int totalPutt = 0;
    int overUnder = 0;
    int totalPenalty = 0;

    for (var h in widget.round.holes) {
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
    QPointBreakdown qPointBreakdown = widget.round.getQPointBreakdown(playerIndex);

    // 전체 콘텐츠를 RepaintBoundary로 감싸 다운로드 가능하게 함
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: RepaintBoundary(
        key: _repaintKeys[playerIndex],
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.round.golfCourseName,
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
                          color: overUnder < 0 ? Colors.red : (overUnder == 0 ? Colors.black87 : Colors.blue),
                        ),
                      ),
                      InkWell(
                        onTap: () => _showQPointBreakdown(context, widget.round, playerIndex, playerName),
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
                '${DateFormat('yyyy-MM-dd').format(widget.round.date)} ${widget.round.teeUpTime} | $playerName',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // 전반 스코어카드 제목
              _buildCourseLabel(widget.round.frontCourseName.isNotEmpty ? widget.round.frontCourseName : '전반 코스'),
              const SizedBox(height: 8),
              _buildScorecardGrid(widget.round.holes, 0, context, playerIndex),
              const SizedBox(height: 24),

              // 후반 스코어카드 제목
              _buildCourseLabel(widget.round.backCourseName.isNotEmpty ? widget.round.backCourseName : '후반 코스'),
              const SizedBox(height: 8),
              _buildScorecardGrid(widget.round.holes, 9, context, playerIndex),
              const SizedBox(height: 16),
              _buildScoreLegend(),
              const SizedBox(height: 16),

              // 18홀이 모두 입력된 경우에만 통계 제공
              widget.round.holes.where((h) => h.score != -99).length == 18
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

              // 하단 워터마크
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'FIAT GOLF  •  ${DateFormat('yyyy-MM-dd').format(widget.round.date)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, letterSpacing: 1.5),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey,
        letterSpacing: 0.5,
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
    showQPointBreakdownDialog(
      context,
      courseName: round.golfCourseName,
      playerName: playerName,
      breakdown: round.getQPointBreakdown(playerIndex),
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
            _buildScoreCell(null, playerIndex, customScore: totalScore, isBold: true, isTotal: true, totalPar: totalPar),
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

  Widget _buildScoreCell(HoleData? h, int playerIndex, {int? customScore, bool isBold = false, bool isTotal = false, int? totalPar}) {
    int score = customScore ?? (h != null ? _getPlayerScore(h, playerIndex) : 0);
    String text = score == 0 ? '0' : (score > 0 ? '+$score' : '$score');
    
    if (isTotal && totalPar != null) {
      text = '${totalPar + score}';
    }

    Color textColor = Colors.black87;
    Color bgColor = Colors.transparent;

    if (isTotal) {
      bgColor = Colors.transparent;
    } else {
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
    }

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
