import 'package:flutter/material.dart';
import '../models/round_model.dart';

/// Q-Point 상세 다이얼로그를 표시하는 공유 함수.
///
/// [courseName]  골프장 이름 (제목에 표시)
/// [playerName]  플레이어 이름 (하단 합계에 표시)
/// [breakdown]   QPointBreakdown 데이터
void showQPointBreakdownDialog(
  BuildContext context, {
  required String courseName,
  required String playerName,
  required QPointBreakdown breakdown,
}) {
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
              // 제목
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$courseName Q-Point 상세',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.grey, height: 10),
              const SizedBox(height: 5),

              // 보너스 항목
              _bonusRow('Sub-80 Round',      breakdown.under80       ? 4 : 0),
              _bonusRow('GIR 50%+',          breakdown.gir50         ? 4 : 0),
              _bonusRow('Scrambling 50%+',   breakdown.scrambling    ? 4 : 0),
              _bonusRow('Putts 29 or less',  breakdown.puttsUnder30  ? 4 : 0),
              _bonusRow('No Three Putt',      breakdown.noThreePutt   ? 4 : 0),
              _bonusRow('One Ball Play',      breakdown.noPenalty     ? 4 : 0),
              _bonusRow('Digital Round',      breakdown.digital       ? 4 : 0),
              _bonusRow('Bounce Back',        breakdown.bounceBackCount * 2),
              const Divider(color: Colors.grey, height: 10),

              // 홀별 상세: 1-9번(왼쪽) / 10-18번(오른쪽)
              if (breakdown.holeDetails.length >= 18)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 0.5),
                  ),
                  child: Table(
                    border: TableBorder(
                      verticalInside: BorderSide(color: Colors.grey.shade300, width: 0.5),
                      horizontalInside: BorderSide(color: Colors.grey.shade200, width: 0.5),
                    ),
                    columnWidths: const {
                      0: FlexColumnWidth(1),
                      1: FlexColumnWidth(1),
                    },
                    children: List.generate(9, (i) {
                      final left  = breakdown.holeDetails[i];
                      final right = breakdown.holeDetails[i + 9];
                      return TableRow(
                        children: [
                          _holeCell(left),
                          _holeCell(right),
                        ],
                      );
                    }),
                  ),
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

              // 총합
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$playerName님의 총 Q-Point',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${breakdown.total}pt',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 닫기 버튼
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '닫기',
                    style: TextStyle(color: Color(0xFF27AE60), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _bonusRow(String title, int points) {
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

Widget _holeCell(HoleQPointInfo d) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            '${d.holeNumber}번 ${d.on}온 ${d.putt}펏, ${d.scoreLabel}',
            style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${d.points}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
      ],
    ),
  );
}
