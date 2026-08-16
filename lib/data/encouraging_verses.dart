/// Encouraging Quranic verses about memorizing / remembering the Quran,
/// shown in the daily reminder notification and its setup sheet.
///
/// A scheduled reminder carries the verse chosen for the day it was set
/// (one repeating notification keeps a single body until rescheduled), so
/// setting or editing the reminder on a later day picks the next verse.
/// Translations use the widely-published Sahih International wording.
class EncouragingVerse {
  const EncouragingVerse({
    required this.reference,
    required this.arabic,
    required this.translation,
  });

  /// "surah:ayah", e.g. "54:17".
  final String reference;

  /// The verse in Arabic (Hafs 'an 'Asim spelling).
  final String arabic;

  /// English translation.
  final String translation;
}

const List<EncouragingVerse> kEncouragingVerses = [
  EncouragingVerse(
    reference: '54:17',
    arabic: 'وَلَقَدْ يَسَّرْنَا الْقُرْآنَ لِلذِّكْرِ فَهَلْ مِن مُّدَّكِرٍ',
    translation:
        'And We have certainly made the Qur\'an easy to remember. So is there '
        'any who will remember?',
  ),
  EncouragingVerse(
    reference: '2:152',
    arabic: 'فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ',
    translation:
        'So remember Me; I will remember you. And be grateful to Me and do '
        'not deny Me.',
  ),
  EncouragingVerse(
    reference: '29:49',
    arabic:
        'بَلْ هُوَ آيَاتٌ بَيِّنَاتٌ فِي صُدُورِ الَّذِينَ أُوتُوا الْعِلْمَ '
        'وَمَا يَجْحَدُ بِآيَاتِنَا إِلَّا الظَّالِمُونَ',
    translation:
        'Rather, the Qur\'an is distinct verses [preserved] within the '
        'breasts of those who have been given knowledge. And none reject Our '
        'verses except the wrongdoers.',
  ),
  EncouragingVerse(
    reference: '73:20',
    arabic: 'فَاقْرَءُوا مَا تَيَسَّرَ مِنَ الْقُرْآنِ',
    translation: 'So recite what is easy from the Qur\'an.',
  ),
  EncouragingVerse(
    reference: '87:6',
    arabic: 'سَنُقْرِئُكَ فَلَا تَنسَىٰ',
    translation:
        'We will make you recite, [O Muhammad], and you will not forget.',
  ),
  EncouragingVerse(
    reference: '17:106',
    arabic:
        'وَقُرْآنًا فَرَقْنَاهُ لِتَقْرَأَهُ عَلَى النَّاسِ عَلَى مُكْثٍ '
        'وَنَزَّلْنَاهُ تَنزِيلًا',
    translation:
        'And [it is] a Qur\'an which We have separated [by intervals] that '
        'you might recite it to the people over a prolonged period. And We '
        'have sent it down progressively.',
  ),
  EncouragingVerse(
    reference: '25:32',
    arabic:
        'وَقَالَ الَّذِينَ كَفَرُوا لَوْلَا نُزِّلَ عَلَيْهِ الْقُرْآنُ '
        'جُمْلَةً وَاحِدَةً كَذَٰلِكَ لِنُثَبِّتَ بِهِ فُؤَادَكَ '
        'وَرَتَّلْنَاهُ تَرْتِيلًا',
    translation:
        'And those who disbelieve say, "Why was the Qur\'an not revealed to '
        'him all at once?" Thus [it is] that We may strengthen thereby your '
        'heart. And We have spaced it distinctly.',
  ),
  EncouragingVerse(
    reference: '35:29',
    arabic:
        'إِنَّ الَّذِينَ يَتْلُونَ كِتَابَ اللَّهِ وَأَقَامُوا الصَّلَاةَ '
        'وَأَنفَقُوا مِمَّا رَزَقْنَاهُمْ سِرًّا وَعَلَانِيَةً يَرْجُونَ '
        'تِجَارَةً لَّن تَبُورَ',
    translation:
        'Indeed, those who recite the Book of Allah and establish prayer and '
        'spend [in His cause] out of what We have provided them, secretly and '
        'publicly, expect a transaction that will never fail.',
  ),
];

/// The verse for a reminder set on [date], rotating with the calendar so a
/// reminder set or edited on a different day shows a different verse.
/// Negative offsets (clock skew) are still safe: Dart's `%` returns a
/// non-negative result for a positive divisor.
EncouragingVerse encouragingVerseFor(DateTime date) {
  final days = date.difference(DateTime(2026, 1, 1)).inDays;
  return kEncouragingVerses[days % kEncouragingVerses.length];
}
