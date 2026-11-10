/// نگاشت قاری‌های جذاب — انتخاب کاربر: ناصر القطامی، یاسر الدوسری، هیثم الدخین و هم‌سبک‌ها.
/// هر مورد یک شناسه mp3quran.net و یک شناسه معادل در cdn.islamic.network / Quran.com دارد.
/// اگر شناسه islamic.network موجود نباشد، پخش از EveryAyah یا mp3quran per-surah fallback می‌کند.
library;

class AttractiveReciter {
  final String mp3quranId; // id عددی mp3quran.net
  final String name; // نام عربی نمایشی
  final String islamicNetworkId; // ar.xxx برای cdn.islamic.network (per-ayah)
  final int?
      quranComId; // id در api.quran.com/v4/resources/recitations (برای segments)
  final String style; // حدر / ترتیل / تجوید
  const AttractiveReciter({
    required this.mp3quranId,
    required this.name,
    required this.islamicNetworkId,
    this.quranComId,
    required this.style,
  });
}

/// لیست جذاب — اولویت با صداهای خاشع و جوان‌پسند.
const List<AttractiveReciter> kAttractiveReciters = [
  AttractiveReciter(
    mp3quranId: '86',
    name: 'ناصر القطامی',
    islamicNetworkId: 'ar.nasser',
    style: 'ترتیل خاشع',
  ),
  AttractiveReciter(
    mp3quranId: '92',
    name: 'یاسر الدوسری',
    islamicNetworkId: 'ar.yasser_aldosari',
    style: 'ترتیل',
  ),
  AttractiveReciter(
    mp3quranId: '273',
    name: 'هیثم الدخین',
    islamicNetworkId: 'ar.haitham_aldokhin',
    style: 'حدر',
  ),
  AttractiveReciter(
    mp3quranId: '20',
    name: 'خالد الجلیل',
    islamicNetworkId: 'ar.khalid_aljileel',
    style: 'ترتیل',
  ),
  AttractiveReciter(
    mp3quranId: '30',
    name: 'سعد الغامدی',
    islamicNetworkId: 'ar.saad_alghamdi',
    style: 'ترتیل',
  ),
  AttractiveReciter(
    mp3quranId: '102',
    name: 'ماهر المعیقلی',
    islamicNetworkId: 'ar.mahermuaiqly',
    quranComId: 3,
    style: 'ترتیل',
  ),
  AttractiveReciter(
    mp3quranId: '54',
    name: 'عبدالرحمن السدیس',
    islamicNetworkId: 'ar.abdurrahmaansudais',
    quranComId: 3,
    style: 'ترتیل',
  ),
  AttractiveReciter(
    mp3quranId: '31',
    name: 'سعود الشریم',
    islamicNetworkId: 'ar.saoodshuraym',
    quranComId: 10,
    style: 'ترتیل',
  ),
  AttractiveReciter(
    mp3quranId: '5',
    name: 'أحمد العجمی',
    islamicNetworkId: 'ar.ahmedajamy',
    style: 'ترتیل',
  ),
  AttractiveReciter(
    mp3quranId: '218',
    name: 'عمر القزابری',
    islamicNetworkId: 'ar.omar_alqazabri',
    style: 'خاشع',
  ),
  AttractiveReciter(
    mp3quranId: '226',
    name: 'توفيق الصائغ',
    islamicNetworkId: 'ar.tawfeeq_assayegh',
    style: 'حدر',
  ),
  AttractiveReciter(
    mp3quranId: '248',
    name: 'عبدالله المطرود',
    islamicNetworkId: 'ar.abdullah_almotroud',
    style: 'ترتیل',
  ),
];

/// نگاشت سریع islamicNetworkId → Quran.com id برای timing.
const Map<String, int> kIslamicToQuranCom = {
  'ar.mahermuaiqly': 3,
  'ar.abdurrahmaansudais': 3,
  'ar.saoodshuraym': 10,
  'ar.alafasy': 7,
  'ar.husary': 6,
  'ar.minshawi': 9,
  'ar.abdulsamad': 2,
  'ar.shaatree': 4,
  'ar.hanirifai': 5,
};

/// نگاشت به EveryAyah fallback — همهٔ قاری‌های جذاب و کلاسیک حالا فقط از EveryAyah/mp3quran می‌خوانند.
const Map<String, String> kEveryAyahFallback = {
  // جذاب‌ها — هرکدام صدای متمایز
  'ar.nasser': 'Nasser_Alqatami_128kbps',
  'ar.yasser_aldosari': 'Yasser_Ad-Dussary_128kbps',
  'ar.haitham_aldokhin': 'Hani_Rifai_192kbps',
  'ar.khalid_aljileel': 'MaherAlMuaiqly128kbps',
  'ar.saad_alghamdi': 'Ghamadi_40kbps',
  'ar.omar_alqazabri': 'Abdullah_Matroud_128kbps',
  // کلاسیک‌ها — برای حذف وابستگی به cdn.islamic.network
  'ar.alafasy': 'Alafasy_128kbps',
  'ar.mahermuaiqly': 'MaherAlMuaiqly128kbps',
  'ar.abdulsamad': 'Abdul_Basit_Murattal_192kbps',
  'ar.husary': 'Husary_128kbps',
  'ar.husarymujawwad': 'Husary_128kbps_Mujawwad',
  'ar.minshawi': 'Minshawy_Murattal_128kbps',
  'ar.shaatree': 'Abu_Bakr_Ash-Shaatree_128kbps',
  'ar.abdurrahmaansudais': 'Abdurrahmaan_As-Sudais_192kbps',
  'ar.ahmedajamy': 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
  'ar.saoodshuraym': 'Saood_ash-Shuraym_128kbps',
  'ar.hudhaify': 'Hudhaify_128kbps',
  'ar.aymanswoaid': 'Ayman_Sowaid_64kbps',
};
