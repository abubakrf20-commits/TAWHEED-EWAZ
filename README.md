# توحید — Tawheed

<div dir="rtl">

## همراه دیجیتال مسلمانان

اپلیکیشن اندرویدی توحید یک برنامه جامع اسلامی است که اوقات نماز، قرآن کریم، اذکار و اوراد، تسبیح دیجیتال، قبله‌نما، زکاة، حج و عمره، تقویم، و ارزیابی عملکرد دینی را در یک برنامه یکپارچه ارائه می‌دهد.

</div>

---

## Features / ویژگی‌ها

### Prayer Times / اوقات شرعی
- Automatic prayer time calculation based on GPS location
- 12+ calculation methods (Muslim World League, Karachi, Tehran, etc.)
- Automatic Azan playback with custom sound support
- Sunnah prayers tracking (Rawatib)
- Menstrual period tracker

### Quran / قرآن کریم
- Text-based reader with multiple translations
- Madina Mushaf (image-based) reader
- Audio playback with verse highlighting
- Offline download support
- Verse bookmarking and tafsir

### Azkar & Tasbih / اذکار و تسبیح
- Daily azkar tracker with prayer-time periods
- Digital tasbih counter with haptic feedback
- Custom azkar support
- Home screen widget sync

### More / سایر امکانات
- Qibla compass with distance to Kaaba
- Zakat calculator (gold, silver, livestock, crops)
- Hajj and Umrah step-by-step guide
- Ramadan guide with duas
- Triple calendar (Shamsi, Hijri, Gregorian)
- Worship evaluation and scoring system
- Islamic book library (38 books)
- Home screen widgets (4 types)
- Notes and custom reminders
- Light/Dark mode with 6 accent colors

---

## Tech Stack / فناوری‌ها

| Category | Technology |
|----------|-----------|
| Framework | Flutter 3.x |
| State Management | Riverpod 3.x + riverpod_annotation (code generation) |
| Routing | go_router 17.x |
| Local Database | Drift 2.x (SQLite) |
| Notifications | flutter_local_notifications + native AndroidX WorkManager |
| Prayer Calculation | adhan + islamic_utils |
| Location | geolocator + geocoding |
| Qibla Compass | flutter_compass |
| Audio | audioplayers |
| Quran | qcf_quran_lite (local assets) |
| Fonts | Vazirmatn, Amiri, Calibri |

---

## Project Structure / ساختار پروژه

```
lib/
├── app/
│   ├── router/               # go_router configuration
│   └── state/                # Shell navigation state
├── core/
│   ├── constants/            # App constants
│   ├── database/             # Drift AppDatabase متمرکز (۱۲ جدول)
│   ├── design_system/        # glass_surface و composables
│   ├── error/                # exceptions + failures
│   ├── services/             # Schedulerهای پس‌زمینه
│   ├── theme/                # AppTheme، AppColors، AppTextStyles، DesignTokens
│   └── utils/                # ابزارهای مشترک
├── features/                 # معماری feature-first
│   ├── adhkar/               # اذکار + تسبیح + دعاها
│   ├── books/                # کتابخانه اسلامی
│   ├── education/            # علوم اسلامی
│   ├── fasting/              # فقه صوم
│   ├── hadith/               # کتابخانه احادیث
│   ├── hajj_umrah/           # راهنمای حج و عمره
│   ├── home/                 # صفحه اصلی + ویجت‌های home
│   ├── prayer/               # اوقات شرعی + تنظیمات نماز
│   ├── quran/                # قرآن کریم
│   ├── settings/             # تنظیمات
│   ├── tools/                # تقویم، تبدیل تاریخ، purify، زکات
│   └── worship/              # یادداشت‌ها، ختم، یادآوری‌ها، ارزیابی
├── presentation/
│   └── screens/              # صفحات قدیمی (legacy)
├── shared/
│   ├── models/               # DayTime، Achievement، ...
│   ├── services/             # notification_service، daily_notification_scheduler
│   ├── utils/
│   └── widgets/              # ویجت‌های مشترک (bottom_nav، snackbar، ...)
├── admin_web/                # داشبورد وب مدیر (پنل جداگانه)
├── main_admin.dart           # نقطهٔ ورود جداگانهٔ پنل مدیر وب
│                             #   flutter run -d chrome -t lib/main_admin.dart
│                             #   عمداً از main.dart جداست تا dart:io وارد build وب نشود
└── main.dart                 # نقطه ورود
```

---

## Getting Started / شروع کار

### Prerequisites
- Flutter SDK >= 3.0.0
- Android Studio or VS Code
- Android SDK 36+

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/tawheed.git

# Navigate to project directory
cd tawheed

# Install dependencies
flutter pub get

# Generate code (providers, drift, etc.)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Build Release APK

```bash
flutter build apk --release
```

---

## Screenshots

> Coming soon

---

## License

This project is proprietary software. All rights reserved.

---

## Contact / تماس

**Abubakr Froghi**
- Phone: +989170265333
