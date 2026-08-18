import '../models/playlist_item.dart';

class FilterService {
  // مفردات الفلترة العائلية؛ تستخدم فقط في أسماء القنوات والفئات وبيانات M3U.
  static const List<String> adultKeywords = [
    '+18',
    '18+',
    'ADULT',
    'ADULTS',
    'XXX',
    'PORN',
    'PORNSTAR',
    'SEX',
    'EROTIC',
    'X-RATED',
    'MATURE',
    'HARDCORE',
    'ONLYFANS',
    'REDLIGHT',
    'للكبار',
    'للبالغين',
    'محتوى بالغين',
    'اباحي',
    'إباحي',
    'جنسي',
  ];

  static String _normalizeSafetyText(String text) {
    return text
        .toUpperCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp(r'[^A-Z0-9\u0600-\u06FF]+'), '');
  }

  static bool _matchesAdultContent(String text) {
    final normalized = _normalizeSafetyText(text);
    return adultKeywords.any((keyword) => normalized.contains(_normalizeSafetyText(keyword)));
  }

  // الكلمات المفتاحية الرياضية
  static const List<String> sportsKeywords = [
    "SPORT",
    "KASS",
    "AD SPORT",
    "SSC",
    "SPORTS",
    "FOOTBALL",
    "KORA",
    "MATCH",
    "أون تايم",
    "ON TIME",
    "SSC SPORTS",
    "أبوظبي الرياضية",
    "الكأس",
    "رياضة",
    "رياضية",
    "بي إن",
    "BEIN"
  ];

  // الكلمات المفتاحية الإخبارية
  static const List<String> newsKeywords = [
    "NEWS",
    "إخبارية",
    "أخبار",
    "AL JAZEERA",
    "AL ARABIYA",
    "حدث",
    "HADATH",
    "BBC",
    "CNN",
    "SKY",
    "فرانس 24",
    "FRANCE 24",
    "الجزيرة",
    "العربية",
    "TRT",
    "العربية الحدث",
    "أخبار مصر",
    "RT ARABIC",
    "العربية",
    "الحدث"
  ];

  // الكلمات المفتاحية الخاصة بقنوات Alwan
  static const List<String> alwanKeywords = [
    "ALWAN",
    "ألوان",
    "AL WAN",
    "AL-WAN"
  ];

  /// التحقق من أن القناة تحتوي على محتوى غير عائلي/للكبار
  static bool isAdultStream(String name, String categoryName) {
    return _matchesAdultContent('$name $categoryName');
  }

  /// التحقق من أن القناة عربية
  static bool isArabicStream(String name, String categoryName) {
    // 1. فحص وجود أحرف عربية
    final arabicRegExp = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');
    if (arabicRegExp.hasMatch(name) || arabicRegExp.hasMatch(categoryName)) {
      return true;
    }

    // 2. فحص وجود كلمات مفتاحية شهيرة للقنوات العربية بالإنجليزية
    final String nameUpper = name.toUpperCase();
    final String catUpper = categoryName.toUpperCase();
    
    final List<String> arabicKeywords = [
      "ARAB", "ARABIC", "AR ", "OSN", "MBC", "BEIN", "ROTANA", "AL JAZEERA", "ALJAZEERA", "ART ", "MYCO", "NIL", "NILE", "AL KASS", "ALKASS", "AD SPORT"
    ];

    for (final kw in arabicKeywords) {
      if (nameUpper.contains(kw) || catUpper.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  /// التحقق من أن القناة رياضية
  static bool isSportsStream(String name, String categoryName) {
    final String nameUpper = name.toUpperCase();
    final String catUpper = categoryName.toUpperCase();
    
    for (final kw in sportsKeywords) {
      if (nameUpper.contains(kw) || catUpper.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  /// التحقق من أن القناة إخبارية
  static bool isNewsStream(String name, String categoryName) {
    final String nameUpper = name.toUpperCase();
    final String catUpper = categoryName.toUpperCase();
    
    for (final kw in newsKeywords) {
      if (nameUpper.contains(kw) || catUpper.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  /// التحقق من قنوات Alwan
  static bool isAlwanStream(String name, String categoryName) {
    final String nameUpper = name.toUpperCase();
    final String catUpper = categoryName.toUpperCase();
    
    for (final kw in alwanKeywords) {
      if (nameUpper.contains(kw) || catUpper.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  /// اعتراض وتصفية استجابة M3U الخام (M3U Content Interception)
  /// يقوم بقراءة النص الخام وحذف أي قنوات للكبار تماماً قبل حتى أن تدخل في عملية الـ Parsing
  static String interceptAndCleanRawM3U(String rawContent, {bool blockAdult = true}) {
    if (!blockAdult) return rawContent;

    final List<String> lines = rawContent.split('\n');
    final List<String> cleanLines = [];
    
    bool skipNextUrlLine = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        // فحص اسم القناة والفئة والمجموعة بعد تطبيع النص لتفادي صيغ الالتفاف الشائعة.
        final containsAdult = _matchesAdultContent(line);

        if (containsAdult) {
          skipNextUrlLine = true; // تخطي سطر الـ URL القادم التابع لهذه القناة
        } else {
          skipNextUrlLine = false;
          cleanLines.add(line);
        }
      } else if (line.startsWith('#')) {
        cleanLines.add(line);
      } else {
        // هذا سطر URL
        if (skipNextUrlLine) {
          skipNextUrlLine = false; // تم تخطي رابط القناة الإباحية بنجاح
        } else {
          cleanLines.add(line);
        }
      }
    }

    return cleanLines.join('\n');
  }

  /// اعتراض وتصفية قائمة الفئات (Category Interceptor)
  /// إزالة أقسام البالغين تماماً من أي استجابة Xtream أو Stalker أو M3U
  static List<Map<String, String>> interceptAndFilterCategories(
    List<Map<String, String>> rawCategories, {
    required bool blockAdult,
  }) {
    if (!blockAdult) return rawCategories;

    return rawCategories.where((cat) {
      final name = cat['category_name'] ?? cat['name'] ?? '';
      return !_matchesAdultContent(name); // استبعاد الفئة بالكامل قبل عرضها
    }).toList();
  }

  /// اعتراض وتصفية التدفقات والقنوات (Stream Interceptor)
  /// حظر كامل ومؤكد للقنوات بناءً على الإعدادات الحالية من المصدر
  static List<PlaylistItem> interceptAndFilterStreams(
    List<PlaylistItem> streams, {
    required bool blockAdult,
    required String channelFilter,
  }) {
    return streams.where((stream) {
      // 1. حظر المحتوى الإباحي
      if (blockAdult && isAdultStream(stream.name, stream.categoryName)) {
        return false;
      }

      // 2. تطبيق تصفية القنوات (الإقليمية والموضوعية)
      if (channelFilter != "الكل") {
        final isArab = isArabicStream(stream.name, stream.categoryName);
        
        if (channelFilter == "القنوات العربية فقط") {
          if (!isArab) return false;
        } else if (channelFilter == "القنوات الأجنبية فقط") {
          if (isArab) return false;
        } else if (channelFilter == "قنوات الرياضة فقط") {
          if (!isSportsStream(stream.name, stream.categoryName)) return false;
        } else if (channelFilter == "القنوات الرياضية العربية فقط") {
          if (!isSportsStream(stream.name, stream.categoryName) || !isArab) return false;
        } else if (channelFilter == "القنوات الإخبارية فقط") {
          if (!isNewsStream(stream.name, stream.categoryName)) return false;
        } else if (channelFilter == "قنوات Alwan فقط") {
          if (!isAlwanStream(stream.name, stream.categoryName)) return false;
        }
      }

      return true;
    }).toList();
  }
}
