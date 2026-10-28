import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/round_model.dart';
import '../services/auth_service.dart';
import '../services/download_service.dart';
import 'dart:ui' as ui;

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedFilter = '누적';
  String _selectedTrendTab = '스코어';
  final GlobalKey _repaintKey = GlobalKey();
  bool _isDownloading = false;

  List<RoundData> _applyFilter(List<RoundData> rounds) {
    List<RoundData> completeRounds = rounds.where((r) => r.holes.where((h) => h.score != -99).length == 18).toList();

    if (_selectedFilter == '올해') {
      int currentYear = DateTime.now().year;
      return completeRounds.where((r) => r.date.year == currentYear).toList();
    } else if (_selectedFilter == '최근 10게임') {
      return completeRounds.take(10).toList();
    }
    return completeRounds;
  }

  Future<void> _downloadStats() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final filename = '골프통계_${_selectedFilter}_$dateStr.png';

    await DownloadService.captureAndDownload(
      repaintKey: _repaintKey,
      filename: filename,
      pixelRatio: 2.5,
      context: context,
    );

    if (mounted) setState(() => _isDownloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('통계 대시보드'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            tooltip: '통계 이미지 저장',
            onPressed: _isDownloading ? null : _downloadStats,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '누적', label: Text('누적')),
                ButtonSegment(value: '최근 10게임', label: Text('최근 10게임')),
                ButtonSegment(value: '올해', label: Text('올해')),
              ],
              selected: {_selectedFilter},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedFilter = newSelection.first;
                });
              },
            ),
          ),
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
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('통계를 분석할 구체적인 기록이 없습니다.'));
                }

                final allRounds = snapshot.data!.docs
                    .map((doc) => RoundData.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                    .toList();

                final filteredRounds = _applyFilter(allRounds);

                if (filteredRounds.isEmpty) {
                  return const Center(child: Text('선택한 조건에 해당하는 라운드 기록이 없습니다.'));
                }

                return _buildStatisticsDashboard(context, filteredRounds);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsDashboard(BuildContext context, List<RoundData> rounds) {
    int totalRounds = rounds.length;
    int totalQPoints = rounds.fold(0, (total, r) => total + r.qPoint);

    int totalHoles = 0;
    int girHits = 0;
    int scramblingChances = 0;
    int scramblingSuccesses = 0;
    int totalPutts = 0;

    int girPutts = 0;
    int nonGirPutts = 0;
    int onePuttCount = 0;
    int twoPuttCount = 0;
    int threePlusPuttCount = 0;

    int totalPenaltyStrokes = 0;
    int teeObCount = 0;
    int secondObCount = 0;
    int teeHazardCount = 0;
    int secondHazardCount = 0;

    int par3Strokes = 0, par3Holes = 0;
    int par4Strokes = 0, par4Holes = 0;
    int par5Strokes = 0, par5Holes = 0;

    Map<String, int> scoreDist = {
      'Eagle+': 0,
      'Birdie': 0,
      'Par': 0,
      'Bogey': 0,
      'Double': 0,
      'Triple+': 0
    };

    for (var r in rounds) {
      for (var hole in r.holes) {
        totalHoles++;
        totalPutts += hole.putt;

        totalPenaltyStrokes += hole.penaltyStrokes;
        teeObCount += hole.teeOb;
        secondObCount += hole.secondOb;
        teeHazardCount += hole.teeHazard;
        secondHazardCount += hole.secondHazard;

        if (hole.putt == 1) onePuttCount++;
        else if (hole.putt == 2) twoPuttCount++;
        else if (hole.putt >= 3) threePlusPuttCount++;

        bool isGir = (hole.score - hole.putt) <= -2;
        if (isGir) {
          girHits++;
          girPutts += hole.putt;
        } else {
          scramblingChances++;
          nonGirPutts += hole.putt;
          if (hole.score <= 0) scramblingSuccesses++;
        }

        int actualStrokes = hole.par + hole.score;
        if (hole.par == 3) {
          par3Holes++;
          par3Strokes += actualStrokes;
        } else if (hole.par == 4) {
          par4Holes++;
          par4Strokes += actualStrokes;
        } else if (hole.par == 5) {
          par5Holes++;
          par5Strokes += actualStrokes;
        }

        if (hole.score <= -2) scoreDist['Eagle+'] = scoreDist['Eagle+']! + 1;
        else if (hole.score == -1) scoreDist['Birdie'] = scoreDist['Birdie']! + 1;
        else if (hole.score == 0) scoreDist['Par'] = scoreDist['Par']! + 1;
        else if (hole.score == 1) scoreDist['Bogey'] = scoreDist['Bogey']! + 1;
        else if (hole.score == 2) scoreDist['Double'] = scoreDist['Double']! + 1;
        else if (hole.score >= 3) scoreDist['Triple+'] = scoreDist['Triple+']! + 1;
      }
    }

    double avgQPoint = totalQPoints / totalRounds;
    double girPct = totalHoles > 0 ? (girHits / totalHoles) * 100 : 0;
    double scramblingPct = scramblingChances > 0 ? (scramblingSuccesses / scramblingChances) * 100 : 0;
    double avgPutts = totalHoles > 0 ? totalPutts / totalHoles : 0;
    double avgPenaltyStrokes = totalRounds > 0 ? totalPenaltyStrokes / totalRounds : 0;

    double avgGirPutts = girHits > 0 ? girPutts / girHits : 0.0;
    double avgNonGirPutts = scramblingChances > 0 ? nonGirPutts / scramblingChances : 0.0;

    double avgTeeOb = totalRounds > 0 ? teeObCount / totalRounds : 0;
    double avgTeeHazard = totalRounds > 0 ? teeHazardCount / totalRounds : 0;
    double avgSecondOb = totalRounds > 0 ? secondObCount / totalRounds : 0;
    double avgSecondHazard = totalRounds > 0 ? secondHazardCount / totalRounds : 0;

    int totalGrossScore = 0;
    int totalCoursePar = 0;
    for (var r in rounds) {
      int roundPar = r.holes.fold(0, (acc, h) => acc + h.par);
      totalCoursePar += roundPar;
      totalGrossScore += (roundPar + r.totalScore);
    }
    double avgGrossScore = totalRounds > 0 ? totalGrossScore / totalRounds : 0.0;
    double avgHandicap = totalRounds > 0 ? (totalGrossScore - totalCoursePar) / totalRounds : 0.0;

    String avgHandicapStr;
    if (avgHandicap > 0) {
      avgHandicapStr = '+${avgHandicap.toStringAsFixed(1)}';
    } else if (avgHandicap < 0) {
      avgHandicapStr = avgHandicap.toStringAsFixed(1);
    } else {
      avgHandicapStr = 'E';
    }

    // 추이 분석용 데이터 추출 (과거 -> 최신 순이므로 rounds 리스트를 뒤집음)
    List<RoundData> chronoRounds = rounds.reversed.toList();
    List<double> trendValues = [];
    List<String> trendDates = [];
    
    for (var r in chronoRounds) {
      trendDates.add(DateFormat('MM/dd').format(r.date));
      if (_selectedTrendTab == '스코어') {
        int roundPar = r.holes.fold(0, (acc, h) => acc + h.par);
        trendValues.add((roundPar + r.totalScore).toDouble());
      } else if (_selectedTrendTab == 'Q-Point') {
        trendValues.add(r.qPoint.toDouble());
      } else if (_selectedTrendTab == '그린 적중률') {
        int girCount = r.holes.where((h) => h.score != -99 && (h.score - h.putt) <= -2).length;
        trendValues.add((girCount / 18.0) * 100.0);
      } else if (_selectedTrendTab == '퍼트 수') {
        int putts = r.holes.where((h) => h.putt != -99).fold(0, (acc, h) => acc + h.putt);
        trendValues.add(putts.toDouble());
      }
    }

    Color activeColor;
    if (_selectedTrendTab == '스코어') {
      activeColor = const Color(0xFF27AE60);
    } else if (_selectedTrendTab == 'Q-Point') {
      activeColor = const Color(0xFFD4AF37);
    } else if (_selectedTrendTab == '그린 적중률') {
      activeColor = const Color(0xFF2980B9);
    } else {
      activeColor = const Color(0xFFE67E22);
    }

    // 전체 콘텐츠를 RepaintBoundary로 감싸 다운로드 가능하게 함
    return SingleChildScrollView(
      child: RepaintBoundary(
        key: _repaintKey,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타이틀 헤더 (다운로드 이미지에서 식별용)
              Row(
                children: [
                  const Icon(Icons.bar_chart, color: Color(0xFF27AE60), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '골프 통계 (${'$_selectedFilter'})',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
                  ),
                  const Spacer(),
                  Text(
                    '총 $totalRounds 라운드 분석',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      '평균 핸디캡',
                      avgHandicapStr,
                      Icons.sports_golf,
                      const Color(0xFF27AE60),
                      subtitle: '평균 ${avgGrossScore.toStringAsFixed(1)}타',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      '평균 Q-Point',
                      '${avgQPoint.toStringAsFixed(1)}pt',
                      Icons.stars,
                      const Color(0xFFD4AF37),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTrendAnalysisCard(trendValues, trendDates, activeColor),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📊 기본 통계', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF27AE60))),
                      const Divider(height: 24),
                      Table(
                        border: TableBorder.all(color: Colors.grey.shade300),
                        defaultVerticalAlignment: TableCellVerticalAlignment.top,
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade50),
                            children: [
                              _buildStatCell('그린 적중률', '${girPct.toStringAsFixed(1)}% (${_formatAvg(girHits / totalRounds)}/${_formatAvg(totalHoles / totalRounds)})', valueColor: Colors.black87),
                              _buildStatCell('스크램블링', '${scramblingPct.toStringAsFixed(1)}% (${_formatAvg(scramblingSuccesses / totalRounds)}/${_formatAvg(scramblingChances / totalRounds)})', valueColor: Colors.black87),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('퍼트 통계', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF667C7A))),
                      const SizedBox(height: 8),
                      Table(
                        border: TableBorder.all(color: Colors.grey.shade300),
                        defaultVerticalAlignment: TableCellVerticalAlignment.top,
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade50),
                            children: [
                              _buildStatCell('총 퍼트 (평균)', '${_formatAvg(totalPutts / totalRounds)} (${avgPutts.toStringAsFixed(1)})', valueColor: Colors.black87),
                              _buildStatCell('파온 성공시', avgGirPutts > 0 ? avgGirPutts.toStringAsFixed(1) : "0", valueColor: Colors.black87),
                              _buildStatCell('파온 실패시', avgNonGirPutts > 0 ? avgNonGirPutts.toStringAsFixed(1) : "0", valueColor: Colors.black87),
                            ],
                          ),
                          TableRow(
                            decoration: BoxDecoration(color: Colors.white),
                            children: [
                              _buildStatCell('1퍼트', _formatAvg(onePuttCount / totalRounds), valueColor: Colors.black87),
                              _buildStatCell('2퍼트', _formatAvg(twoPuttCount / totalRounds), valueColor: Colors.black87),
                              _buildStatCell('3퍼트 이상', _formatAvg(threePlusPuttCount / totalRounds), valueColor: Colors.black87),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('패널티 통계', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF667C7A))),
                      const SizedBox(height: 8),
                      Table(
                        border: TableBorder.all(color: Colors.grey.shade300),
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade50),
                            children: [
                              _buildStatCell('합계 (벌타)', _formatAvg(avgPenaltyStrokes)),
                              _buildStatCell('티샷 벌타', _buildPenaltyValue(avgTeeOb, avgTeeHazard)),
                              _buildStatCell('세컨샷 벌타', _buildPenaltyValue(avgSecondOb, avgSecondHazard)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildParStatsCard(par3Strokes, par3Holes, par4Strokes, par4Holes, par5Strokes, par5Holes),
              const SizedBox(height: 24),
              _buildScoreDistributionCard(scoreDist, totalHoles, totalRounds),

              // 워터마크
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'FIAT GOLF  •  ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
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

  String _formatAvg(double v) {
    if (v == v.toInt()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  Widget _buildStatCell(String title, dynamic value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF667C7A), fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          if (value is Widget)
            value
          else
            Text(value.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor ?? Colors.black87), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPenaltyValue(double ob, double hazard) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            children: [
              const TextSpan(text: 'O.B ', style: TextStyle(color: Colors.red)),
              TextSpan(text: _formatAvg(ob), style: const TextStyle(color: Colors.black87)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            children: [
              const TextSpan(text: 'Hazard ', style: TextStyle(color: Colors.red)),
              TextSpan(text: _formatAvg(hazard), style: const TextStyle(color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              radius: 20,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParStatsCard(int p3s, int p3h, int p4s, int p4h, int p5s, int p5h) {
    double avg3 = p3h > 0 ? p3s / p3h : 0.0;
    double avg4 = p4h > 0 ? p4s / p4h : 0.0;
    double avg5 = p5h > 0 ? p5s / p5h : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('홀 유형별 평균 타수', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: [
                    _buildStatCell('Par 3', avg3 > 0 ? avg3.toStringAsFixed(1) : '-', valueColor: avg3 > 3.0 ? Colors.redAccent : const Color(0xFF27AE60)),
                    _buildStatCell('Par 4', avg4 > 0 ? avg4.toStringAsFixed(1) : '-', valueColor: avg4 > 4.0 ? Colors.redAccent : const Color(0xFF27AE60)),
                    _buildStatCell('Par 5', avg5 > 0 ? avg5.toStringAsFixed(1) : '-', valueColor: avg5 > 5.0 ? Colors.redAccent : const Color(0xFF27AE60)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreDistributionCard(Map<String, int> dist, int total, int rounds) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('스코어 분포도 (라운드당 평균)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDistBar('Eagle+', dist['Eagle+']!, total, rounds, Colors.red),
            _buildDistBar('Birdie', dist['Birdie']!, total, rounds, Colors.red.shade200),
            _buildDistBar('Par', dist['Par']!, total, rounds, Colors.grey.shade400),
            _buildDistBar('Bogey', dist['Bogey']!, total, rounds, Colors.cyan.shade200),
            _buildDistBar('Double', dist['Double']!, total, rounds, Colors.blue.shade400),
            _buildDistBar('Triple+', dist['Triple+']!, total, rounds, Colors.blue.shade900),
          ],
        ),
      ),
    );
  }

  Widget _buildDistBar(String label, int count, int total, int rounds, Color color) {
    double pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    double avgCount = rounds > 0 ? count / rounds : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 55, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double totalWidth = constraints.maxWidth;
                final double barWidth = totalWidth * pct;
                final double displayBarWidth = count > 0 ? (barWidth < 6.0 ? 6.0 : barWidth) : 0.0;
                final String countText = '$count';
                final double approxTextWidth = countText.length * 7.5 + 4;
                final bool fitsAfterBar = (displayBarWidth + approxTextWidth + 6) <= totalWidth;

                return ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    height: 14,
                    width: totalWidth,
                    color: Colors.grey.shade200,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        if (displayBarWidth > 0)
                          Container(
                            width: displayBarWidth,
                            height: 14,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        Positioned(
                          left: fitsAfterBar ? (displayBarWidth + 4) : null,
                          right: fitsAfterBar ? null : 6,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Text(
                              countText,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: fitsAfterBar ? Colors.grey.shade800 : Colors.white,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 85,
            child: Text(
              '${_formatAvg(avgCount)} (${(pct * 100).toStringAsFixed(0)}%)',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendTabButton(String label) {
    bool isSelected = _selectedTrendTab == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTrendTab = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF27AE60) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF27AE60) : Colors.grey.shade300,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendAnalysisCard(List<double> values, List<String> dates, Color activeColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Color(0xFF27AE60), size: 20),
                const SizedBox(width: 8),
                const Text(
                  '📈 추이 분석',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
                ),
                const Spacer(),
                if (values.isNotEmpty)
                  Text(
                    '최근 ${values.length}경기',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildTrendTabButton('스코어'),
                const SizedBox(width: 6),
                _buildTrendTabButton('Q-Point'),
                const SizedBox(width: 6),
                _buildTrendTabButton('그린 적중률'),
                const SizedBox(width: 6),
                _buildTrendTabButton('퍼트 수'),
              ],
            ),
            const SizedBox(height: 12),
            TrendChart(
              values: values,
              labels: dates,
              color: activeColor,
            ),
          ],
        ),
      ),
    );
  }
}

class TrendChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;

  const TrendChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('데이터가 없습니다.')),
      );
    }
    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: CustomPaint(
        painter: TrendChartPainter(values: values, labels: labels, color: color),
      ),
    );
  }
}

class TrendChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;

  TrendChartPainter({
    required this.values,
    required this.labels,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    double leftPadding = 24.0;
    double rightPadding = 12.0;
    double topPadding = 16.0;
    double bottomPadding = 24.0;
    
    double chartWidth = size.width - leftPadding - rightPadding;
    double chartHeight = size.height - topPadding - bottomPadding;

    // Y-axis scaling
    double minY = values.reduce((a, b) => a < b ? a : b);
    double maxY = values.reduce((a, b) => a > b ? a : b);
    
    if (minY == maxY) {
      minY -= 5;
      maxY += 5;
    } else {
      double range = maxY - minY;
      minY -= range * 0.15;
      maxY += range * 0.15;
    }

    // Grid lines
    const int gridLines = 4;
    final gridPaint = Paint()
      ..color = Colors.grey.shade100
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    // Draw horizontal grid lines and Y-axis labels
    for (int i = 0; i < gridLines; i++) {
      double yVal = maxY - (i * (maxY - minY) / (gridLines - 1));
      double yPos = topPadding + (i * chartHeight / (gridLines - 1));

      // Draw grid line
      canvas.drawLine(Offset(leftPadding, yPos), Offset(size.width - rightPadding, yPos), gridPaint);

      // Draw Y label
      textPainter.text = TextSpan(
        text: _formatYLabel(yVal),
        style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding - textPainter.width - 6, yPos - 6));
    }

    // Coordinates calculation
    int n = values.length;
    double stepX = n > 1 ? chartWidth / (n - 1) : chartWidth;
    List<Offset> points = [];

    for (int i = 0; i < n; i++) {
      double x = leftPadding + (i * stepX);
      double ratio = (values[i] - minY) / (maxY - minY);
      double y = topPadding + chartHeight - (ratio * chartHeight);
      points.add(Offset(x, y));
    }

    // Paint line path
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    if (n > 0) {
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < n; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    canvas.drawPath(path, linePaint);

    // Paint gradient area below path
    if (n > 0) {
      final fillPath = Path()
        ..moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < n; i++) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      }
      fillPath.lineTo(points[n - 1].dx, topPadding + chartHeight);
      fillPath.lineTo(points[0].dx, topPadding + chartHeight);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTRB(leftPadding, topPadding, size.width - rightPadding, topPadding + chartHeight))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    // Paint average line
    final double avgValue = values.reduce((a, b) => a + b) / n;
    final double avgRatio = (avgValue - minY) / (maxY - minY);
    final double avgY = topPadding + chartHeight - (avgRatio * chartHeight);

    final avgLinePaint = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw dashed average line
    const double dashWidth = 6.0;
    const double dashSpace = 4.0;
    double currentX = leftPadding;
    final double endX = size.width - rightPadding;
    while (currentX < endX) {
      canvas.drawLine(
        Offset(currentX, avgY),
        Offset((currentX + dashWidth).clamp(0.0, endX), avgY),
        avgLinePaint,
      );
      currentX += dashWidth + dashSpace;
    }

    // Draw average label — fixed at top-right corner of chart
    final String avgLabel = '평균 ${_formatValue(avgValue)}';
    textPainter.text = TextSpan(
      text: avgLabel,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade600,
      ),
    );
    textPainter.layout();
    const double labelPadding = 4.0;
    final double labelW = textPainter.width + labelPadding * 2;
    final double labelH = textPainter.height + labelPadding;
    final double labelX = size.width - rightPadding - labelW;
    const double labelY = 0.0; // top of the canvas (above topPadding)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(labelX, labelY, labelW, labelH),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.grey.shade200..style = PaintingStyle.fill,
    );
    textPainter.paint(canvas, Offset(labelX + labelPadding, labelY + labelPadding / 2));

    // Paint dots and values
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final darkColor = HSLColor.fromColor(color).withLightness((HSLColor.fromColor(color).lightness - 0.2).clamp(0.0, 1.0)).toColor();

    for (int i = 0; i < n; i++) {
      final pt = points[i];
      
      canvas.drawCircle(pt, 5, pointPaint);
      canvas.drawCircle(pt, 5, pointBorderPaint);

      // Value label above point
      bool shouldDrawValue = n <= 10 || (n <= 20 && i % 2 == 0) || i == 0 || i == n - 1;
      if (shouldDrawValue) {
        textPainter.text = TextSpan(
          text: _formatValue(values[i]),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: darkColor,
          ),
        );
        textPainter.layout();
        
        // Draw small background for text readability
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(pt.dx - textPainter.width / 2 - 3, pt.dy - 17, textPainter.width + 6, textPainter.height + 2),
            const Radius.circular(4),
          ),
          Paint()..color = Colors.white.withOpacity(0.9)..style = PaintingStyle.fill,
        );
        textPainter.paint(canvas, Offset(pt.dx - textPainter.width / 2, pt.dy - 16));
      }

      // X label (date)
      bool shouldDrawLabel = n <= 6 || (n <= 12 && i % 2 == 0) || (n <= 20 && i % 3 == 0) || i == 0 || i == n - 1;
      if (shouldDrawLabel && i < labels.length) {
        textPainter.text = TextSpan(
          text: labels[i],
          style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(pt.dx - textPainter.width / 2, topPadding + chartHeight + 6));
      }
    }
  }

  String _formatYLabel(double v) {
    return v.toStringAsFixed(0);
  }

  String _formatValue(double v) {
    if (v == v.toInt()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.labels != labels ||
        oldDelegate.color != color;
  }
}
