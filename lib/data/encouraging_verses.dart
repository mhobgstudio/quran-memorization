/// Encouraging Quranic verses and hadith about memorizing / remembering the
/// Quran, shown in the daily reminder notification, its setup sheet, and the
/// planner screen as a rotating motivational quote.
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
    this.isHadith = false,
    this.narrator,
  });

  /// "surah:ayah", e.g. "54:17", or a hadith reference like "Sahih al-Bukhari 5027".
  final String reference;

  /// The verse in Arabic (Hafs 'an 'Asim spelling), or empty for hadith.
  final String arabic;

  /// English translation (Quran) or English text (hadith).
  final String translation;

  /// Whether this is a hadith rather than a Quran verse.
  final bool isHadith;

  /// Hadith narrator chain, e.g. "Narrated by Uthman ibn Affan".
  final String? narrator;
}

/// All available quotes — verses and hadith — for the planner rotation.
const List<EncouragingVerse> kEncouragingVerses = [
  // ── Quranic verses ──────────────────────────────────────────────────
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
  EncouragingVerse(
    reference: '73:4',
    arabic: 'وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا',
    translation: 'And recite the Qur\'an with measured recitation.',
  ),
  EncouragingVerse(
    reference: '50:17',
    arabic:
        'إِذِ الْمُوَكَّلُونَ مِن قَبْلِ وَمِن خَلْفِهِ يَحْفَظُونَهُ '
        'مِنْ أَمْرِ اللَّهِ',
    translation:
        '[That is] when the receivers [of the inspiration] receive [His '
        'message] before them and behind them by the command of Allah.',
  ),
  EncouragingVerse(
    reference: '2:185',
    arabic:
        'يُرِيدُ اللَّهُ بِكُمُ الْيُسْرَ وَلَا يُرِيدُ بِكُمُ الْعُسْرَ',
    translation:
        'Allah intends for you ease and does not intend for you hardship.',
  ),
  EncouragingVerse(
    reference: '94:5-6',
    arabic:
        'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا \u0600 إِنَّ مَعَ الْعُسْرِ يُسْرًا',
    translation:
        'For indeed, with hardship [will be] ease. Indeed, with hardship '
        '[will be] ease.',
  ),
  EncouragingVerse(
    reference: '93:4',
    arabic: 'وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ',
    translation: 'And your Lord is going to give you, and you will be satisfied.',
  ),

  // ── Hadith ──────────────────────────────────────────────────────────
  EncouragingVerse(
    reference: 'Sahih al-Bukhari 5027',
    arabic: '',
    translation:
        'The best among you (Muslims) are those who learn the Qur\'an and '
        'teach it.',
    isHadith: true,
    narrator: 'Narrated by Uthman ibn Affan (may Allah be pleased with him)',
  ),
  EncouragingVerse(
    reference: 'Sahih al-Bukhari 5032',
    arabic: '',
    translation:
        'The one who is proficient in the Qur\'an will be with the noble, '
        'honourable scribes (angels), and the one who recites it with '
        'difficulty, stammering through it, will have a double reward.',
    isHadith: true,
    narrator: 'Narrated by Aisha (may Allah be pleased with her)',
  ),
  EncouragingVerse(
    reference: 'Sahih Muslim 804',
    arabic: '',
    translation:
        'It will be said to the companion of the Qur\'an: "Recite and '
        'ascend (in status), and recite as you used to recite in the '
        'world, for your status will be at the last verse you recite."',
    isHadith: true,
    narrator: 'Narrated by Abu Umamah (may Allah be pleased with him)',
  ),
  EncouragingVerse(
    reference: 'Sahih al-Bukhari 5028',
    arabic: '',
    translation:
        'Such a person as recites the Qur\'an and masters it by heart will '
        'be with the noble righteous scribes (in Heaven). And such a person '
        'as recites the Qur\'an and finds it difficult for him, stammering '
        'through it, will have a double reward.',
    isHadith: true,
    narrator: 'Narrated by Ibn Mas\'ud (may Allah be pleased with him)',
  ),
  EncouragingVerse(
    reference: 'Jami\' at-Tirmidhi 2910',
    arabic: '',
    translation:
        'The one who reads the Qur\'an is like the owner of a high-priced '
        'stall in Paradise, and the one who memorizes it is like the owner '
        'of a high-priced and mounted stall in Paradise.',
    isHadith: true,
    narrator: 'Narrated by Abdullah ibn Amr (may Allah be pleased with him)',
  ),
  EncouragingVerse(
    reference: 'Sunan an-Nasa\'i 3058',
    arabic: '',
    translation:
        'The example of a believer who recites the Qur\'an is like that of '
        'a citron which has a pleasant fragrance and a sweet taste. And the '
        'example of a believer who does not recite the Qur\'an is like that '
        'of a date which has no fragrance but a sweet taste.',
    isHadith: true,
    narrator: 'Narrated by Abu Hurairah (may Allah be pleased with him)',
  ),
  EncouragingVerse(
    reference: 'Sahih al-Bukhari 5059',
    arabic: '',
    translation:
        'Whoever recites a letter from the Book of Allah will have a good '
        'deed, and each good deed is multiplied by ten. I do not say "Alif '
        'Lam Mim" is one letter, but "Alif" is a letter, "Lam" is a '
        'letter, and "Mim" is a letter.',
    isHadith: true,
    narrator: 'Narrated by Tamim ad-Dari (may Allah be pleased with him)',
  ),
  EncouragingVerse(
    reference: 'Sahih al-Bukhari 5052',
    arabic: '',
    translation:
        'Whoever recites a letter from the Book of Allah will be rewarded '
        'with one good deed, and each good deed is multiplied ten times. '
        'I do not say "Alif-Lam-Mim" is one letter. Rather, "Alif" is a '
        'letter, "Lam" is a letter, and "Mim" is a letter.',
    isHadith: true,
    narrator: 'Narrated by Abdullah ibn Mas\'ud (may Allah be pleased with him)',
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

/// Returns a rotating verse for the planner screen based on the current time
/// so the quote changes each time the app is opened (hourly rotation).
EncouragingVerse rotatingQuote() {
  final now = DateTime.now();
  final seed = now.year * 10000 + now.month * 100 + now.day + now.hour;
  return kEncouragingVerses[seed.abs() % kEncouragingVerses.length];
}
