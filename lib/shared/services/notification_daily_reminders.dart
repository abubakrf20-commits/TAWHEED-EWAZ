part of 'notification_service.dart';

mixin _NotificationDailyReminders {
  NotificationService get service;

  /// قنات یادآوری روزانه با متن غنی (BigText) — متن عربی درشت/ضخیم، ترجمه در
  /// خط بعد و منبع کوچک در پایین، همگی از طریق HTML.
  AndroidNotificationDetails _dailyStyledChannel(String bigText) =>
      AndroidNotificationDetails(
        'daily_reminders_v3',
        'یادآوری روزانه',
        channelDescription: 'یادآوری‌های روزانه شامل آیه و حدیث',
        importance: Importance.high,
        icon: '@drawable/ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification_logo'),
        sound: const RawResourceAndroidNotificationSound('notif'),
        color: NotificationService._brandColor,
        visibility: NotificationService._visible,
        styleInformation: BigTextStyleInformation(
          bigText,
          htmlFormatBigText: true,
          contentTitle: 'یادآوری روزانه',
        ),
      );

  /// متن اعلان جمعه از همان منبع واحدِ کارت صفحهٔ خانه ([FridayContent]) ساخته
  /// می‌شود؛ یک متن ثابت اینجا باعث می‌شد اعلان با آداب و احادیث اصلاح‌شده
  /// difference پیدا کند.
  String get _fridayBody => FridayContent.notificationBody;

  AndroidNotificationDetails get _fridayChannel =>
      AndroidNotificationDetails(
        'friday_reminder_v3',
        'یادآوری روز جمعه',
        channelDescription: 'یادآوری هفتگی آداب و اذکار روز جمعه',
        importance: Importance.high,
        icon: '@drawable/ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification_logo'),
        sound: const RawResourceAndroidNotificationSound('notif'),
        color: NotificationService._brandColor,
        visibility: NotificationService._visible,
        styleInformation: BigTextStyleInformation(
          _fridayBody,
          contentTitle: 'یادآوری روز جمعه',
          summaryText: 'فضیلت و آداب روز جمعه، صلوات و دعا',
        ),
      );

  AndroidNotificationDetails get _fridayKahfChannel =>
      AndroidNotificationDetails(
        'friday_kahf_v1',
        'یادآوری سوره کهف',
        channelDescription: 'یادآوری هفتگی تلاوت سوره کهف در روز جمعه',
        importance: Importance.high,
        icon: '@drawable/ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification_logo'),
        sound: const RawResourceAndroidNotificationSound('notif'),
        color: NotificationService._brandColor,
        visibility: NotificationService._visible,
        styleInformation: BigTextStyleInformation(
          _kahfBody,
          contentTitle: 'سوره کهف — جمعه',
          summaryText:
              '«مَنْ قَرَأَ سُورَةَ الْكَهْفِ فِي يَوْمِ الْجُمُعَةِ أَضَاءَ لَهُ مِنَ النُّورِ»',
        ),
      );

  /// متن اعلان کهف؛ حدیثش از [FridayContent.kahfHadith] می‌آید تا با کارت
  /// صفحهٔ خانه یکی بماند.
  String get _kahfBody => '''
سوره کهف را امروز بخوانید؛ روز جمعه روز خیرین روزهاست.

پیامبر ﷺ فرمود: «${FridayContent.kahfHadith.arabic}»
${FridayContent.kahfHadith.translation}
(${FridayContent.kahfHadith.source})

📖 سوره کهف: هفت آیهٔ نخست را به نیت حفظ و تدبر بخوانید.
🕋 پس از هر نماز، 6 آیهٔ پایانی سورهٔ «حج» را میان نماز و جماعت بخوانید.''';

  /// یادآوری مستقل هفتگی «سوره کهف» — جمعه ساعت 6 صبح به‌صورت پیش‌فرض.
  /// عمداً از یادآوری جمعه جداست تا ساعت 7 صبح آن دست‌نخورده بماند.
  Future<void> scheduleFridayKahfReminder({required TimeOfDay time}) async {
    try {
      await service._scheduleNotification(
        NotificationIds.fridayKahf,
        'سوره کهف — جمعه',
        'فرا رسید وقت تلاوت سوره کهف در روز جمعه',
        _nextFridayAt(time),
        _fridayKahfChannel,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'friday_kahf',
      );
    } catch (e, st) {
      AppLogger.error('NotificationService',
          'Failed to schedule Surah Kahf reminder: $e', st);
    }
  }

  Future<void> cancelFridayKahfReminder() async {
    await service.cancel(NotificationIds.fridayKahf);
  }

  /// اعمال ترجیح ذخیره‌شدهٔ یادآوری سوره کهف (روشن/خاموش + ساعت) به‌شکل idempotent.
  Future<void> syncFridayKahfReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool(NotificationService.fridayKahfEnabledKey) ?? true;
      final hour = prefs.getInt(NotificationService.fridayKahfHourKey) ??
          NotificationService.defaultFridayKahfHour;
      final minute = prefs.getInt(NotificationService.fridayKahfMinuteKey) ??
          NotificationService.defaultFridayKahfMinute;
      if (enabled) {
        await scheduleFridayKahfReminder(
            time: TimeOfDay(hour: hour, minute: minute));
      } else {
        await cancelFridayKahfReminder();
      }
    } catch (e, st) {
      AppLogger.error(
          'NotificationService', 'Failed to sync Surah Kahf reminder: $e', st);
    }
  }

  AndroidNotificationDetails get _quranChannel =>
      const AndroidNotificationDetails(
        'quran_reminder_v3',
        'یادآوری قرآن',
        channelDescription: 'یادآوری تلاوت قرآن',
        importance: Importance.high,
        icon: '@drawable/ic_notification',
        largeIcon: DrawableResourceAndroidBitmap('ic_notification_logo'),
        sound: RawResourceAndroidNotificationSound('notif'),
        color: NotificationService._brandColor,
        visibility: NotificationService._visible,
      );
  Future<void> scheduleQuranReminder({required TimeOfDay time}) async {
    try {
      await service._scheduleNotification(
        NotificationIds.quranReminder,
        'یادآوری تلاوت قرآن',
        'وقت تلاوت روزانه قرآن است',
        _nextInstanceOfTime(time),
        _quranChannel,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'quran_reminder',
      );
    } catch (e, st) {
      AppLogger.error(
          'NotificationService', 'Failed to schedule Quran reminder: $e', st);
    }
  }

  Future<void> cancelQuranReminder() async {
    await service.cancel(NotificationIds.quranReminder);
  }

  Future<void> scheduleDailyVerse({required TimeOfDay time}) async {
    try {
      await _scheduleDailyContentWindow(
        idBase: NotificationIds.dailyVerseDayBase,
        legacyId: NotificationIds.dailyVerse,
        title: 'آیه روز',
        contentFor: (fireDate) {
          // Content is computed for the FIRE date (not schedule time), so the
          // displayed verse matches the day and rotates daily.
          final verse = DailyVerseSource.verseForDate(fireDate);
          return _DailyContent(
            text: verse['verse'] ?? '',
            trans: verse['trans'] ?? '',
            ref: verse['ref'] ?? '',
          );
        },
        time: time,
        payload: 'daily_verse',
      );
    } catch (e, st) {
      AppLogger.error(
          'NotificationService', 'Failed to schedule daily verse: $e', st);
    }
  }

  Future<void> cancelDailyVerse() => _cancelDailyContentWindow(
        title: 'آیه روز',
        legacyId: NotificationIds.dailyVerse,
        idBase: NotificationIds.dailyVerseDayBase,
      );
  Future<void> scheduleDailyHadith({required TimeOfDay time}) async {
    try {
      await _scheduleDailyContentWindow(
        idBase: NotificationIds.dailyHadithDayBase,
        legacyId: NotificationIds.dailyHadith,
        title: 'حدیث روز',
        contentFor: (fireDate) {
          final hadith = DailyHadithSource.hadithForDate(fireDate);
          return _DailyContent(
            text: hadith['text'] ?? '',
            trans: hadith['trans'] ?? '',
            ref: hadith['ref'] ?? '',
          );
        },
        time: time,
        payload: 'daily_hadith',
      );
    } catch (e, st) {
      AppLogger.error(
          'NotificationService', 'Failed to schedule daily hadith: $e', st);
    }
  }

  Future<void> cancelDailyHadith() => _cancelDailyContentWindow(
        title: 'حدیث روز',
        legacyId: NotificationIds.dailyHadith,
        idBase: NotificationIds.dailyHadithDayBase,
      );
  static const List<Map<String, String>> _dailyDuas = [
    {
      'ar': 'اللَّهُمَّ بَارِكْ لَنَا فِيمَا رَزَقْتَنَا',
      'fa': 'خدایا به آنچه روزی ما کرده‌ای برکت ده',
      'ref': 'دعای نبوی'
    },
    {
      'ar': 'اللَّهُمَّ اهْدِنَا فِيمَنْ هَدَيْتَ',
      'fa': 'خدایا ما را در زمره کسانی که هدایت کرده‌ای قرار ده',
      'ref': 'دعای قنوت'
    },
    {
      'ar': 'رَبَّنَا تَقَبَّلْ مِنَّا إِنَّكَ أَنتَ السَّمِيعُ الْعَلِيمُ',
      'fa': 'پروردگارا از ما بپذیر که تو شنوای دانایی',
      'ref': 'قرآن کریم — بقره:127'
    },
    {
      'ar':
          'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ',
      'fa': 'خدایا از تو عافیت در دنیا و آخرت را می‌خواهم',
      'ref': 'دعای نبوی'
    },
    {
      'ar':
          'رَبَّنَا آتِنَا مِن لَّدُنكَ رَحْمَةً وَهَيِّئْ لَنَا مِنْ أَمْرِنَا رَشَدًا',
      'fa': 'پروردگارا از نزد خود رحمتی به ما عطا کن و راه رستگاری به ما بنما',
      'ref': 'قرآن کریم — کهف:10'
    },
    {
      'ar':
          'اللَّهُمَّ أَصْلِحْ لَنَا دِينَنَا الَّذِي هُوَ عِصْمَةُ أَمْرِنَا',
      'fa': 'خدایا دین ما را اصلاح کن که نگهدارنده کار ماست',
      'ref': 'دعای نبوی'
    },
    {
      'ar':
          'اللَّهُمَّ أَعِنَّا عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ',
      'fa': 'خدایا ما را بر یاد خود و شکر خود و نیکویی عبادتت یاری ده',
      'ref': 'دعای نبوی'
    },
    {
      'ar': 'رَبَّنَا أَفْرِغْ عَلَيْنَا صَبْرًا وَثَبِّتْ أَقْدَامَنَا',
      'fa': 'پروردگارا بر ما صبر فرو ریز و گام‌هایمان را استوار کن',
      'ref': 'قرآن کریم — بقره:250'
    },
    {
      'ar': 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ',
      'fa': 'خدایا از غم و اندوه به تو پناه می‌برم',
      'ref': 'دعای نبوی'
    },
    {
      'ar': 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
      'fa': 'خدا برای ما بس است و بهترین کارگزار است',
      'ref': 'قرآن کریم — آل‌عمران:173'
    },
  ];
  Future<void> scheduleDailyDua({required TimeOfDay time}) async {
    try {
      await _scheduleDailyContentWindow(
        idBase: NotificationIds.dailyDuaDayBase,
        legacyId: NotificationIds.dailyDua,
        title: 'دعای روز',
        contentFor: (fireDate) {
          final index = _dayOfYear(fireDate) % _dailyDuas.length;
          final dua = _dailyDuas[index];
          return _DailyContent(
            text: dua['ar'] ?? '',
            trans: dua['fa'] ?? '',
            ref: dua['ref'] ?? '',
          );
        },
        time: time,
        payload: 'daily_dua',
      );
    } catch (e, st) {
      AppLogger.error(
          'NotificationService', 'Failed to schedule daily dua: $e', st);
    }
  }

  Future<void> cancelDailyDua() => _cancelDailyContentWindow(
        title: 'دعای روز',
        legacyId: NotificationIds.dailyDua,
        idBase: NotificationIds.dailyDuaDayBase,
      );

  /// Schedules the weekly Friday reminder (اذکار و آداب جمعه، صلوات و دعا).
  /// Repeats every Friday at [time] using a weekly (day-of-week + time) match.
  Future<void> scheduleFridayReminder({required TimeOfDay time}) async {
    try {
      await service._scheduleNotification(
        NotificationIds.fridayReminder,
        'یادآوری روز جمعه',
        'فضیلت و آداب روز جمعه، صلوات و دعا',
        _nextFridayAt(time),
        _fridayChannel,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'friday_reminder',
      );
    } catch (e, st) {
      AppLogger.error(
          'NotificationService', 'Failed to schedule friday reminder: $e', st);
    }
  }

  Future<void> cancelFridayReminder() async {
    await service.cancel(NotificationIds.fridayReminder);
  }

  /// Applies the stored Friday-reminder preference (toggle + time) idempotently.
  /// Safe to call on every boot and after any settings change.
  Future<void> syncFridayReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool(NotificationService.fridayEnabledKey) ?? true;
      final hour = prefs.getInt(NotificationService.fridayHourKey) ??
          NotificationService.defaultFridayHour;
      final minute = prefs.getInt(NotificationService.fridayMinuteKey) ??
          NotificationService.defaultFridayMinute;
      if (enabled) {
        await scheduleFridayReminder(
            time: TimeOfDay(hour: hour, minute: minute));
      } else {
        await cancelFridayReminder();
      }
    } catch (e, st) {
      AppLogger.error(
          'NotificationService', 'Failed to sync friday reminder: $e', st);
    }
  }

  AndroidNotificationDetails get _khatmChannel =>
      const AndroidNotificationDetails(
        'khatm_reminder_v3',
        'یادآوری ختم قرآن',
        channelDescription: 'یادآوری روزانه خواندن صفحات ختم قرآن',
        importance: Importance.high,
        icon: '@drawable/ic_notification',
        largeIcon: DrawableResourceAndroidBitmap('ic_notification_logo'),
        sound: RawResourceAndroidNotificationSound('notif'),
        color: NotificationService._brandColor,
        visibility: NotificationService._visible,
      );

  /// Schedules the daily khatm reminder (خواندن صفحات ختم قرآن) at [time].
  /// Repeats every day using a time-of-day match. [dailyTarget] (صفحات
  /// پیشنهادی امروز) is included in the body when positive.
  Future<void> scheduleKhatmReminder({
    required TimeOfDay time,
    int dailyTarget = 0,
  }) async {
    try {
      final body = dailyTarget > 0
          ? 'امروز $dailyTarget صفحه از ختم قرآن بخوانید'
          : 'وقت خواندن صفحات ختم قرآن فرا رسید؛ حتی چند صفحه هم ادامه راه است';
      await service._scheduleNotification(
        NotificationIds.khatmReminder,
        'یادآوری ختم قرآن',
        body,
        _nextInstanceOfTime(time),
        _khatmChannel,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'khatm_reminder',
      );
    } catch (e, st) {
      AppLogger.error(
          'NotificationService', 'Failed to schedule khatm reminder: $e', st);
    }
  }

  Future<void> cancelKhatmReminder() async {
    await service.cancel(NotificationIds.khatmReminder);
  }

  /// Applies the stored khatm-reminder preference (toggle + time) idempotently.
  /// Safe to call on every boot and after any change from the khatm screen.
  Future<void> syncKhatmReminder({int dailyTarget = 0}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool(NotificationService.khatmEnabledKey) ?? false;
      final hour = prefs.getInt(NotificationService.khatmHourKey) ??
          NotificationService.defaultKhatmHour;
      final minute = prefs.getInt(NotificationService.khatmMinuteKey) ??
          NotificationService.defaultKhatmMinute;
      if (enabled) {
        await scheduleKhatmReminder(
          time: TimeOfDay(hour: hour, minute: minute),
          dailyTarget: dailyTarget,
        );
      } else {
        await cancelKhatmReminder();
      }
    } catch (e, st) {
      AppLogger.error(
          'NotificationService', 'Failed to sync khatm reminder: $e', st);
    }
  }

  // --- یادآوری روزه مستحب ---

  /// One channel for both fasting reminders: they are the same user-facing
  /// topic, so a user silencing «روزه مستحب» silences both in system settings.
  AndroidNotificationDetails _fastingChannel({
    required String title,
    required String bigText,
  }) =>
      AndroidNotificationDetails(
        'fasting_reminder_v1',
        'یادآوری روزه مستحب',
        channelDescription: 'یادآوری روزه‌های مستحب دوشنبه و پنجشنبه و ایام بیض',
        importance: Importance.high,
        icon: '@drawable/ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification_logo'),
        sound: const RawResourceAndroidNotificationSound('notif'),
        color: NotificationService._brandColor,
        visibility: NotificationService._visible,
        styleInformation: BigTextStyleInformation(
          bigText,
          contentTitle: title,
        ),
      );

  /// The next device-local occurrence of [weekday] at [time] — today when it
  /// has not passed yet. Mirrors [_nextInstanceOfTime], one weekday over.
  DateTime _nextWeekdayAt(int weekday, TimeOfDay time) {
    final now = DateTime.now();
    var scheduled =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  /// Arms the Monday and Thursday reminders — the two days the Prophet ﷺ
  /// used to fast. Two ids, not one: `dayOfWeekAndTime` matches exactly one
  /// weekday per notification, so a single id can never fire twice a week.
  Future<void> scheduleMondayThursdayFasting({
    required TimeOfDay time,
  }) async {
    try {
      await service._scheduleNotification(
        NotificationIds.fastingMonday,
        'روزهٔ دوشنبه',
        'امروز دوشنبه است؛ روزهٔ مستحب را از دست ندهید.',
        _nextWeekdayAt(DateTime.monday, time),
        _fastingChannel(
          title: 'روزهٔ دوشنبه',
          bigText:
              'امروز دوشنبه است؛ روزهٔ مستحب را از دست ندهید.\nدوشنبه و پنجشنبه از روزهای روزهٔ مستحب در هفته است.',
        ),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'fasting_monday',
      );
      await service._scheduleNotification(
        NotificationIds.fastingThursday,
        'روزهٔ پنجشنبه',
        'امروز پنجشنبه است؛ روزهٔ مستحب را از دست ندهید.',
        _nextWeekdayAt(DateTime.thursday, time),
        _fastingChannel(
          title: 'روزهٔ پنجشنبه',
          bigText:
              'امروز پنجشنبه است؛ روزهٔ مستحب را از دست ندهید.\nدوشنبه و پنجشنبه از روزهای روزهٔ مستحب در هفته است.',
        ),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'fasting_thursday',
      );
    } catch (e, st) {
      AppLogger.error('NotificationService',
          'Failed to schedule Monday/Thursday fasting: $e', st);
    }
  }

  Future<void> cancelMondayThursdayFasting() async {
    await service.cancel(NotificationIds.fastingMonday);
    await service.cancel(NotificationIds.fastingThursday);
  }

  /// Arms a per-day window for ایام بیض (Hijri 13-15). A weekly match cannot
  /// follow these days — they move ~11 days earlier each Gregorian month — so
  /// each qualifying day gets its own one-shot, id = base + day-of-year. The
  /// window is [NotificationService.ayamAlBidhWindowDays] long, which always
  /// contains at least one complete 13-15 block; the 6-hourly/24-hourly
  /// background reschedule keeps it rolling when the app is never opened.
  Future<void> scheduleAyamAlBidhFasting({
    required int hijriOffset,
    required TimeOfDay time,
  }) async {
    try {
      await cancelAyamAlBidhFasting();
      final first = _nextInstanceOfTime(time);
      for (var i = 0; i < NotificationService.ayamAlBidhWindowDays; i++) {
        final fire = first.add(Duration(days: i));
        final date = DateTime(fire.year, fire.month, fire.day);
        if (!HijriUtils.isAyamAlBidh(date, offset: hijriOffset)) continue;
        final hijri = HijriUtils.hijriFromGreg(date.year, date.month, date.day,
            offset: hijriOffset);
        final monthName = DateConstants.hijriMonths[hijri.month - 1];
        final title = 'روزهٔ ایام بیض — ${hijri.day} $monthName';
        await service._scheduleNotification(
          NotificationIds.ayamAlBidhDayBase + _dayOfYear(date),
          title,
          'امروز ${hijri.day} $monthName است؛ روزهٔ مستحب ایام بیض را از دست ندهید.',
          fire,
          _fastingChannel(
            title: title,
            bigText:
                'امروز ${hijri.day} $monthName است؛ روزهٔ مستحب ایام بیض را از دست ندهید.\nایام بیض، روزهای ۱۳، ۱۴ و ۱۵ هر ماه قمری است.',
          ),
          payload: 'ayam_al_bidh',
        );
      }
    } catch (e, st) {
      AppLogger.error('NotificationService',
          'Failed to schedule Ayam al-Bidh fasting: $e', st);
    }
  }

  /// Clears the whole ایام بیض window. The native per-day ids are invisible
  /// to the plugin's pending list, so both must be swept: the armed native
  /// range and any plugin-pending one-shot in the same range.
  Future<void> cancelAyamAlBidhFasting() async {
    const base = NotificationIds.ayamAlBidhDayBase;
    await service.cancelNativeReminderRange(base, base + 366);
    try {
      final pending = await service._notifications.pendingNotificationRequests();
      for (final req in pending) {
        if (req.id >= base && req.id <= base + 366) {
          await service.cancel(req.id);
        }
      }
    } catch (e, st) {
      AppLogger.warning(
          'NotificationService', 'Cancel Ayam al-Bidh window failed: $e');
      AppLogger.error(
          'NotificationService', 'Cancel Ayam al-Bidh stack', st);
    }
  }

  /// Applies the stored fasting-reminder preferences (two toggles + times)
  /// idempotently. Both default to enabled at 07:00, matching the pref-backed
  /// Friday reminders. [hijriOffset] comes from [AppSettings] because ایام
  /// بیض must agree with the date the calendar section prints.
  Future<void> syncFastingReminders({int hijriOffset = 2}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final monThuEnabled =
          prefs.getBool(NotificationService.fastingMonThuEnabledKey) ?? true;
      final monThuHour = prefs.getInt(NotificationService.fastingMonThuHourKey) ??
          NotificationService.defaultFastingHour;
      final monThuMinute =
          prefs.getInt(NotificationService.fastingMonThuMinuteKey) ??
              NotificationService.defaultFastingMinute;
      if (monThuEnabled) {
        await scheduleMondayThursdayFasting(
            time: TimeOfDay(hour: monThuHour, minute: monThuMinute));
      } else {
        await cancelMondayThursdayFasting();
      }
      final bidhEnabled =
          prefs.getBool(NotificationService.fastingBidhEnabledKey) ?? true;
      final bidhHour = prefs.getInt(NotificationService.fastingBidhHourKey) ??
          NotificationService.defaultFastingHour;
      final bidhMinute =
          prefs.getInt(NotificationService.fastingBidhMinuteKey) ??
              NotificationService.defaultFastingMinute;
      if (bidhEnabled) {
        await scheduleAyamAlBidhFasting(
          hijriOffset: hijriOffset,
          time: TimeOfDay(hour: bidhHour, minute: bidhMinute),
        );
      } else {
        await cancelAyamAlBidhFasting();
      }
    } catch (e, st) {
      AppLogger.error(
          'NotificationService', 'Failed to sync fasting reminders: $e', st);
    }
  }

  Future<void> scheduleAllDailyReminders({
    required TimeOfDay morningVerse,
    required TimeOfDay eveningHadith,
    required TimeOfDay duaTime,
  }) async {
    await scheduleDailyVerse(time: morningVerse);
    await scheduleDailyHadith(time: eveningHadith);
    await scheduleDailyDua(time: duaTime);
  }

  /// Idempotently syncs every daily reminder (آیه/حدیث/دعای روز و یادآوری قرآن)
  /// with the user's [settings]. Safe to call on every boot and after any
  /// settings change — each entry only (re)schedules its own fixed ID.
  Future<void> scheduleDailyRemindersFromSettings(AppSettings settings) async {
    if (settings.dailyVerse) {
      await scheduleDailyVerse(
        time: TimeOfDay(
            hour: settings.dailyVerseTime.hour,
            minute: settings.dailyVerseTime.minute),
      );
    } else {
      await cancelDailyVerse();
    }
    if (settings.dailyHadith) {
      await scheduleDailyHadith(
        time: TimeOfDay(
            hour: settings.dailyHadithTime.hour,
            minute: settings.dailyHadithTime.minute),
      );
    } else {
      await cancelDailyHadith();
    }
    if (settings.dailyDua) {
      await scheduleDailyDua(
        time: TimeOfDay(
            hour: settings.dailyDuaTime.hour,
            minute: settings.dailyDuaTime.minute),
      );
    } else {
      await cancelDailyDua();
    }
    if (settings.quranReminder) {
      await scheduleQuranReminder(
        time: TimeOfDay(
            hour: settings.quranReminderTime.hour,
            minute: settings.quranReminderTime.minute),
      );
    } else {
      await cancelQuranReminder();
    }
    await syncFridayReminder();
    await syncFridayKahfReminder();
    await syncFastingReminders(hijriOffset: settings.hijriOffset);
    await catchUpMissedReminders(settings: settings);
  }

  Future<void> cancelAllDailyReminders() async {
    await cancelDailyVerse();
    await cancelDailyHadith();
    await cancelDailyDua();
    await cancelQuranReminder();
    await cancelFridayReminder();
    await cancelFridayKahfReminder();
    await cancelMondayThursdayFasting();
    await cancelAyamAlBidhFasting();
  }

  /// The next device-local wall-clock [DateTime] matching [time]. Computed from
  /// [DateTime.now] (not tz.local) so repeat scheduling can never drift when
  /// the timezone database is misaligned in a background isolate.
  DateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = DateTime.now();
    var scheduled =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// The next [count] device-local wall-clock occurrences of [time], starting
  /// today (if not yet passed) or tomorrow. Used by the daily-content window so
  /// each day's notification carries that day's content.
  List<DateTime> _nextInstancesOfTime(TimeOfDay time, int count) {
    final first = _nextInstanceOfTime(time);
    return List.generate(
      count,
      (i) => first.add(Duration(days: i)),
    );
  }

  /// Schedules [NotificationService.dailyContentWindowDays] one-shot notifications (آیه/حدیث/دعا)
  /// whose content is computed from each fire date, so the reminder rotates
  /// daily even when background re-scheduling is deferred. Each day maps to a
  /// stable id (base + day-of-year), so re-running this both refreshes the
  /// window and keeps coverage contiguous for a week.
  Future<void> _scheduleDailyContentWindow({
    required int idBase,
    required String title,
    required int legacyId,
    required _DailyContent Function(DateTime fireDate) contentFor,
    required TimeOfDay time,
    required String payload,
  }) async {
    // First clear the legacy repeating notification (id 400/401/402, left over
    // from pre-window versions), every stale pending entry with this title, and
    // every armed native per-day id in this window. Without this, an old
    // frozen-body notification keeps firing every day next to the freshly
    // rotated window — two «آیه روز» with different texts.
    await _cancelDailyContentWindow(
        title: title, legacyId: legacyId, idBase: idBase);
    for (final fire in _nextInstancesOfTime(
        time, NotificationService.dailyContentWindowDays)) {
      final fireDate = DateTime(fire.year, fire.month, fire.day);
      final content = contentFor(fireDate);
      await service._scheduleNotification(
        idBase + _dayOfYear(fireDate),
        title,
        content.plainBody,
        fire,
        _dailyStyledChannel(content.htmlBody),
        payload: payload,
      );
    }
  }

  /// Cancels the whole daily-content window for [title]: the legacy single
  /// repeating notification ([legacyId]), every armed native per-day id in
  /// [idBase..idBase+366] (native-armed ids are not visible in the plugin's
  /// pending list), plus any stale plugin-pending per-day id from older app
  /// versions.
  Future<void> _cancelDailyContentWindow({
    required String title,
    required int legacyId,
    required int idBase,
  }) async {
    await service.cancel(legacyId);
    await service.cancelNativeReminderRange(idBase, idBase + 366);
    try {
      final pending =
          await service._notifications.pendingNotificationRequests();
      for (final req in pending) {
        if (req.title == title) {
          await service.cancel(req.id);
        }
      }
    } catch (e, st) {
      AppLogger.warning(
          'NotificationService', 'Cancel daily content ($title) failed: $e');
      AppLogger.error('NotificationService', 'Cancel daily content stack', st);
    }
  }

  DateTime _nextFridayAt(TimeOfDay time) {
    final now = DateTime.now();
    var scheduled =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    while (scheduled.weekday != DateTime.friday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  /// Calculate day-of-year for deterministic daily content rotation
  static int _dayOfYear(DateTime date) {
    return date.difference(DateTime(date.year)).inDays;
  }

  /// Shows ONE silent digest listing today's fixed-time reminders whose
  /// moment passed while the app was closed.
  ///
  /// A fixed-time reminder is armed only by a run inside the 24 h before its
  /// fire time ([NotificationService._scheduleNotification] drops a past time),
  /// so the previous run's stamp is the only evidence that separates "armed,
  /// nothing to report" from "the app never ran in that window". The stamp is
  /// written before the digest so two syncs in one boot cannot both report.
  Future<void> catchUpMissedReminders({
    required AppSettings settings,
    DateTime? now,
  }) async {
    try {
      final at = now ?? DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final lastRunMs = prefs.getInt(NotificationService.catchUpLastRunKey);
      await prefs.setInt(
          NotificationService.catchUpLastRunKey, at.millisecondsSinceEpoch);
      if (lastRunMs == null) return;
      final lastRun = DateTime.fromMillisecondsSinceEpoch(lastRunMs);

      final missed = <String>[];
      void check(bool enabled, int hour, int minute, String title) {
        if (!enabled) return;
        if (reminderWasMissed(
            now: at, lastRun: lastRun, hour: hour, minute: minute)) {
          missed.add(title);
        }
      }

      check(settings.dailyVerse, settings.dailyVerseTime.hour,
          settings.dailyVerseTime.minute, 'آیه روز');
      check(settings.dailyHadith, settings.dailyHadithTime.hour,
          settings.dailyHadithTime.minute, 'حدیث روز');
      check(settings.dailyDua, settings.dailyDuaTime.hour,
          settings.dailyDuaTime.minute, 'دعای روز');
      check(settings.quranReminder, settings.quranReminderTime.hour,
          settings.quranReminderTime.minute, 'یادآوری تلاوت قرآن');

      final friday = at.weekday == DateTime.friday;
      check(
          friday &&
              (prefs.getBool(NotificationService.fridayEnabledKey) ?? true),
          prefs.getInt(NotificationService.fridayHourKey) ??
              NotificationService.defaultFridayHour,
          prefs.getInt(NotificationService.fridayMinuteKey) ??
              NotificationService.defaultFridayMinute,
          'یادآوری روز جمعه');
      check(
          friday &&
              (prefs.getBool(NotificationService.fridayKahfEnabledKey) ?? true),
          prefs.getInt(NotificationService.fridayKahfHourKey) ??
              NotificationService.defaultFridayKahfHour,
          prefs.getInt(NotificationService.fridayKahfMinuteKey) ??
              NotificationService.defaultFridayKahfMinute,
          'سوره کهف — جمعه');
      check(
          prefs.getBool(NotificationService.khatmEnabledKey) ?? false,
          prefs.getInt(NotificationService.khatmHourKey) ??
              NotificationService.defaultKhatmHour,
          prefs.getInt(NotificationService.khatmMinuteKey) ??
              NotificationService.defaultKhatmMinute,
          'یادآوری ختم قرآن');

      final monThuEnabled =
          prefs.getBool(NotificationService.fastingMonThuEnabledKey) ?? true;
      final monThuHour =
          prefs.getInt(NotificationService.fastingMonThuHourKey) ??
              NotificationService.defaultFastingHour;
      final monThuMinute =
          prefs.getInt(NotificationService.fastingMonThuMinuteKey) ??
              NotificationService.defaultFastingMinute;
      check(monThuEnabled && at.weekday == DateTime.monday, monThuHour,
          monThuMinute, 'روزهٔ دوشنبه');
      check(monThuEnabled && at.weekday == DateTime.thursday, monThuHour,
          monThuMinute, 'روزهٔ پنجشنبه');

      final bidhEnabled =
          prefs.getBool(NotificationService.fastingBidhEnabledKey) ?? true;
      final today = DateTime(at.year, at.month, at.day);
      if (bidhEnabled &&
          HijriUtils.isAyamAlBidh(today, offset: settings.hijriOffset)) {
        final hijri = HijriUtils.hijriFromGreg(at.year, at.month, at.day,
            offset: settings.hijriOffset);
        final monthName = DateConstants.hijriMonths[hijri.month - 1];
        final bidhHour = prefs.getInt(NotificationService.fastingBidhHourKey) ??
            NotificationService.defaultFastingHour;
        final bidhMinute =
            prefs.getInt(NotificationService.fastingBidhMinuteKey) ??
                NotificationService.defaultFastingMinute;
        if (reminderWasMissed(
            now: at, lastRun: lastRun, hour: bidhHour, minute: bidhMinute)) {
          missed.add('روزهٔ ایام بیض — ${hijri.day} $monthName');
        }
      }

      if (missed.isEmpty) return;
      const intro = 'زمان این یادآوری‌ها امروز گذشته است';
      await service.showLocalNotification(
        id: NotificationIds.missedRemindersDigest,
        title: 'یادآوری‌های امروز',
        body: intro,
        soundName: 'silent',
        bigText: '$intro:<br><br>${missed.join('<br>')}',
      );
    } catch (e, st) {
      AppLogger.error(
          'NotificationService', 'Failed to catch up missed reminders: $e', st);
    }
  }
}

/// Whether a fixed-time reminder that would fire at [hour]:[minute] (today,
/// device wall clock) could have been armed by the app's previous run.
///
/// Arming happens only inside the 24 h before the fire time, so a reminder is
/// missed exactly when its moment has passed and the last run predates that
/// window. Public so the guard test can drive it without constructing a
/// [NotificationService] (which would open native channels).
bool reminderWasMissed({
  required DateTime now,
  required DateTime lastRun,
  required int hour,
  required int minute,
}) {
  final fire = DateTime(now.year, now.month, now.day, hour, minute);
  if (now.isBefore(fire)) return false;
  return lastRun.isBefore(fire.subtract(const Duration(days: 1)));
}
