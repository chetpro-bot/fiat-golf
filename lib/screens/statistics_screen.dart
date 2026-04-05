import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/round_model.dart';
import '../services/auth_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedFilter = '누적';

  List<RoundData> _applyFilter(List<RoundData> rounds) {
    if (_selectedFilter == '올해') {
      int currentYear = DateTime.now().year;
      return rounds.where((r) => r.date.year == currentYear).toList();
    } else if (_selectedFilter == '최근 10게임') {
      return rounds.take(10).toList();
    }
    return rounds;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('통계 대시보드'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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

        if (hole.score < 0) scoreDist['Birdie'] = scoreDist['Birdie']! + 1;
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('총 $totalRounds 라운드 분석', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF27AE60))),
          ],
        ),
        const SizedBox(height: 16),
        _buildSummaryCard('평균 Q-Point', '${avgQPoint.toStringAsFixed(1)}pt', Icons.stars, const Color(0xFFD4AF37)),
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
        const SizedBox(height: 40),
      ],
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('홀 유형별 평균 타수', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildParStat('Par 3', p3h > 0 ? p3s / p3h : 0, 3.0),
                _buildParStat('Par 4', p4h > 0 ? p4s / p4h : 0, 4.0),
                _buildParStat('Par 5', p5h > 0 ? p5s / p5h : 0, 5.0),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildParStat(String title, double avg, double parTarget) {
    Color col = avg > parTarget ? Colors.redAccent : const Color(0xFF27AE60);
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(avg > 0 ? avg.toStringAsFixed(1) : '-', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: col)),
      ],
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
            _buildDistBar('Birdie', dist['Birdie']!, total, rounds, const Color(0xFFD4AF37)),
            _buildDistBar('Par', dist['Par']!, total, rounds, const Color(0xFF3B6661)),
            _buildDistBar('Bogey', dist['Bogey']!, total, rounds, const Color(0xFF8BA3A0)),
            _buildDistBar('Double', dist['Double']!, total, rounds, Colors.deepOrangeAccent),
            _buildDistBar('Triple+', dist['Triple+']!, total, rounds, Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildDistBar(String label, int count, int total, int rounds, Color color) {
    double pct = total > 0 ? count / total : 0;
    double avgCount = rounds > 0 ? count / rounds : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          SizedBox(width: 85, child: Text('${_formatAvg(avgCount)} (${(pct*100).toStringAsFixed(0)}%)', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
        ],
      ),
    );
  }
}
