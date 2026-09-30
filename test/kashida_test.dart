import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reader/domain/kashida.dart';

void main() {
  List<int> offsets(String w) => [for (final p in kashidaPoints(w)) p.offset];

  test('elongates between joining letters, after the marks of the first', () {
    // كَفَرُواْ: kaf-feh and feh-reh join; reh, waw and alef do not join forward.
    const word = 'كَفَرُواْ';
    expect(offsets(word), [4, 2]);
    expect(elongate(word, 1), 'كَفَـرُواْ');
  });

  test('prefers the place after seen', () {
    const word = 'سَوَآءٌ';
    expect(kashidaPoints(word).first, const KashidaPoint(2, 1));
    expect(elongate(word, 2), 'سَــوَآءٌ');
  });

  test('prefers the join before a final heh or ta marbuta', () {
    const word = 'رَحۡمَةٗ';
    expect(kashidaPoints(word).first.priority, 2);
    expect(elongate(word, 1), 'رَحۡمَـةٗ');
  });

  test('never breaks lam-alef or the name of Allah', () {
    expect(kashidaPoints('لَا'), isEmpty);
    expect(kashidaPoints('ٱللَّهُ'), isEmpty);
    expect(kashidaPoints('بِٱللَّهِ'), isEmpty);
    expect(kashidaPoints('لِلَّهِ'), isEmpty);
  });

  test('stays inside the word, before an ayah mark', () {
    const word = 'ٱلۡعَٰلَمِينَ ﰁ';
    final points = offsets(word);
    expect(points, isNotEmpty);
    expect(points.every((o) => o < word.indexOf(' ')), isTrue);
  });

  test('non-joining words and ornaments get nothing', () {
    expect(kashidaPoints('وَرَدَ'), isEmpty);
    expect(kashidaPoints('۞'), isEmpty);
    expect(elongate('وَرَدَ', 3), 'وَرَدَ');
  });

  test('long elongations are split over the two best places', () {
    const word = 'يَكۡسِبُونَ';
    final out = elongate(word, 4);
    expect('ـ'.allMatches(out), hasLength(4));
    expect(RegExp('ـ+').allMatches(out), hasLength(2));
  });
}
