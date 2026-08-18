import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class DailyReflectionCard extends StatefulWidget {
  const DailyReflectionCard({super.key});

  @override
  State<DailyReflectionCard> createState() => _DailyReflectionCardState();
}

class _DailyReflectionCardState extends State<DailyReflectionCard> {
  int _currentIndex = 0;

  final List<Map<String, String>> _reflections = const [
    {
      'type': 'QURANIC AYAH',
      'arabic': 'إِنَّ مَعَ الْعُسْرِ يُسْرًا',
      'text': '"Verily, with every hardship comes ease."',
      'ref': 'Surah Ash-Sharh 94:6',
    },
    {
      'type': 'QURANIC AYAH',
      'arabic': 'فَاذْكُرُونِي أَذْكُرْكُمْ',
      'text': '"So remember Me; I will remember you."',
      'ref': 'Surah Al-Baqarah 2:152',
    },
    {
      'type': 'QURANIC AYAH',
      'arabic': 'وَقَالَ رَبُّكُمُ ادْعُونِي أَسْتَجِبْ لَكُمْ',
      'text': '"Call upon Me; I will respond to you."',
      'ref': 'Surah Ghafir 40:60',
    },
    {
      'type': 'HADITH OF THE PROPHET ﷺ',
      'arabic': 'خَيْرُ النَّاسِ أَنْفَعُهُمْ لِلنَّاسِ',
      'text': '"The best of people are those that bring the most benefit to the rest of mankind."',
      'ref': 'Al-Mu\'jam Al-Awsat (Tabarani)',
    },
    {
      'type': 'QURANIC AYAH',
      'arabic': 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      'text': '"Unquestionably, by the remembrance of Allah hearts find rest."',
      'ref': 'Surah Ar-Ra\'d 13:28',
    },
    {
      'type': 'HADITH OF THE PROPHET ﷺ',
      'arabic': 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
      'text': '"Actions are judged by intentions, and every person will get what they intended."',
      'ref': 'Sahih al-Bukhari 1',
    },
    {
      'type': 'QURANIC AYAH',
      'arabic': 'وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ',
      'text': '"And seek help through patience and prayer."',
      'ref': 'Surah Al-Baqarah 2:45',
    },
  ];

  void _nextReflection() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = (_currentIndex + 1) % _reflections.length;
    });
  }

  void _copy() {
    final item = _reflections[_currentIndex];
    Clipboard.setData(ClipboardData(text: '${item['text']}\n— ${item['ref']}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reflection copied to clipboard'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF546356),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _reflections[_currentIndex];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF31332E).withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7E7D6).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  item['type']!,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: const Color(0xFF546356),
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy_outlined, size: 18, color: Color(0xFF5E6059)),
                    tooltip: 'Copy',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F4ED),
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: _nextReflection,
                    icon: const Icon(Icons.arrow_forward, size: 18, color: Color(0xFF5E6059)),
                    tooltip: 'Next Reflection',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F4ED),
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Arabic quote if available
          if (item['arabic'] != null && item['arabic']!.isNotEmpty) ...[
            Text(
              item['arabic']!,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.amiri(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF31332E),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // English translation
          Text(
            item['text']!,
            style: GoogleFonts.playfairDisplay(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF31332E),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Reference
          Row(
            children: [
              Container(
                width: 18,
                height: 1.5,
                color: const Color(0xFF546356),
              ),
              const SizedBox(width: 8),
              Text(
                item['ref']!,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5E6059),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
