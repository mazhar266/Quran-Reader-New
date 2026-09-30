import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reader/domain/models.dart';
import 'package:quran_reader/domain/quran_text.dart';
import 'package:quran_reader/features/reader/mushaf_page.dart';

void main() {
  test('Uthmani words keep the ayah mark and rub ornament attached', () {
    const line = '۞\u00A0إِنَّ ٱللَّهَ\u00A0\uFC00 وَمَا';
    expect(lineWords(line), ['۞\u00A0إِنَّ', 'ٱللَّهَ\u00A0\uFC00', 'وَمَا']);
    expect(ayahEnds('ٱللَّهَ\u00A0\uFC00'), 1);
  });

  test('IndoPak detached signs stay with the previous word', () {
    const line = 'الْعٰلَمِیْنَ ۟ۙ\uF500 الرَّحْمٰنِ';
    expect(lineWords(line), ['الْعٰلَمِیْنَ ۟ۙ\uF500', 'الرَّحْمٰنِ']);
    expect(ayahEnds('۟ۙ\uF500'), 1);
    // U+F68F is a pause annotation, not an ayah end.
    expect(ayahEnds('\uF68F'), 0);
  });

  test('words map to ayahs across marks', () {
    const line = PageLine(
      line: 3,
      kind: LineKind.ayah,
      centered: false,
      text: 'لِّلۡمُتَّقِينَ\u00A0\uFC01 ٱلَّذِينَ يُؤۡمِنُونَ',
      first: AyahKey(2, 2),
      last: AyahKey(2, 3),
    );
    expect(wordAyahs(line), const [AyahKey(2, 2), AyahKey(2, 3), AyahKey(2, 3)]);
    expect(line.ayahs, const [AyahKey(2, 2), AyahKey(2, 3)]);
  });

  test('Arabic-Indic page numbers', () {
    expect(arabicDigits(604), '٦٠٤');
  });
}
