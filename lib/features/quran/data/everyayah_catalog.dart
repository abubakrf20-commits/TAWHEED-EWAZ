import 'package:tawheeed/features/quran/services/mp3quran_service.dart';

/// EveryAyah — لیست واحد بدون دستکاری (ترتیب الفبایی سایت) — اسامی عربی صحیح.
const List<Mp3QuranReciter> kEveryAyahCatalog = [
  Mp3QuranReciter(
      identifier: 'everyayah:Abdul_Basit_Mujawwad_128kbps',
      name: 'عبد الباسط مجود'),
  Mp3QuranReciter(
      identifier: 'everyayah:Abdul_Basit_Murattal_192kbps',
      name: 'عبد الباسط مرتل'),
  Mp3QuranReciter(
      identifier: 'everyayah:Abdullaah_3awwaad_Al-Juhaynee_128kbps',
      name: 'عبدالله عواد الجهنی'),
  Mp3QuranReciter(
      identifier: 'everyayah:Abdullah_Basfar_192kbps', name: 'عبدالله بصفر'),
  Mp3QuranReciter(
      identifier: 'everyayah:Abdullah_Matroud_128kbps',
      name: 'عبدالله المطرود'),
  Mp3QuranReciter(
      identifier: 'everyayah:Abdurrahmaan_As-Sudais_192kbps',
      name: 'عبدالرحمن السدیس'),
  Mp3QuranReciter(
      identifier: 'everyayah:Abu_Bakr_Ash-Shaatree_128kbps',
      name: 'أبو بكر الشاطري'),
  Mp3QuranReciter(
      identifier: 'everyayah:Ahmed_Neana_128kbps', name: 'أحمد نعینع'),
  Mp3QuranReciter(
      identifier: 'everyayah:Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
      name: 'أحمد العجمی'),
  Mp3QuranReciter(
      identifier: 'everyayah:Akram_AlAlaqimy_128kbps', name: 'أکرم العلاقمی'),
  Mp3QuranReciter(
      identifier: 'everyayah:Alafasy_128kbps', name: 'مشاری العفاسی'),
  Mp3QuranReciter(
      identifier: 'everyayah:Ali_Hajjaj_AlSuesy_128kbps',
      name: 'علی حجاج السويسي'),
  Mp3QuranReciter(identifier: 'everyayah:Ali_Jaber_64kbps', name: 'علی جابر'),
  Mp3QuranReciter(
      identifier: 'everyayah:Ayman_Sowaid_64kbps', name: 'أیمن سوید'),
  Mp3QuranReciter(
      identifier: 'everyayah:Fares_Abbad_64kbps', name: 'فارس عباد'),
  Mp3QuranReciter(identifier: 'everyayah:Ghamadi_40kbps', name: 'سعد الغامدی'),
  Mp3QuranReciter(
      identifier: 'everyayah:Hani_Rifai_192kbps', name: 'هانی الرفاعی'),
  Mp3QuranReciter(
      identifier: 'everyayah:Hudhaify_128kbps', name: 'علی الحذیفی'),
  Mp3QuranReciter(
      identifier: 'everyayah:Husary_128kbps', name: 'محمود خلیل الحصری'),
  Mp3QuranReciter(
      identifier: 'everyayah:Husary_Muallim_128kbps',
      name: 'محمود خلیل الحصری (معلم)'),
  Mp3QuranReciter(
      identifier: 'everyayah:Husary_Mujawwad_64kbps',
      name: 'محمود خلیل الحصری (مجود)'),
  Mp3QuranReciter(
      identifier: 'everyayah:Ibrahim_Akhdar_32kbps', name: 'إبراهیم الأخضر'),
  Mp3QuranReciter(
      identifier: 'everyayah:Karim_Mansoori_40kbps', name: 'کریم منصوری'),
  Mp3QuranReciter(
      identifier: 'everyayah:Khaalid_Abdullaah_al-Qahtaanee_192kbps',
      name: 'خالد القحطانی'),
  Mp3QuranReciter(
      identifier: 'everyayah:MaherAlMuaiqly128kbps', name: 'ماهر المعیقلی'),
  Mp3QuranReciter(
      identifier: 'everyayah:Menshawi_16kbps', name: 'محمد صدیق المنشاوی'),
  Mp3QuranReciter(
      identifier: 'everyayah:Minshawy_Mujawwad_192kbps', name: 'المنشاوی مجود'),
  Mp3QuranReciter(
      identifier: 'everyayah:Minshawy_Murattal_128kbps', name: 'المنشاوی مرتل'),
  Mp3QuranReciter(
      identifier: 'everyayah:Minshawy_Teacher_128kbps', name: 'المنشاوی معلم'),
  Mp3QuranReciter(
      identifier: 'everyayah:Mohammad_al_Tablaway_128kbps',
      name: 'محمد الطبلاوی'),
  Mp3QuranReciter(
      identifier: 'everyayah:Muhammad_AbdulKareem_128kbps',
      name: 'محمد عبدالکریم'),
  Mp3QuranReciter(
      identifier: 'everyayah:Muhammad_Ayyoub_128kbps', name: 'محمد أیوب'),
  Mp3QuranReciter(
      identifier: 'everyayah:Muhammad_Jibreel_128kbps', name: 'محمد جبریل'),
  Mp3QuranReciter(
      identifier: 'everyayah:Muhsin_Al_Qasim_192kbps', name: 'محسن القاسم'),
  Mp3QuranReciter(
      identifier: 'everyayah:Mustafa_Ismail_48kbps', name: 'مصطفی إسماعیل'),
  Mp3QuranReciter(
      identifier: 'everyayah:Nabil_Rifa3i_48kbps', name: 'نبیل الرفاعی'),
  Mp3QuranReciter(
      identifier: 'everyayah:Nasser_Alqatami_128kbps', name: 'ناصر القطامی'),
  Mp3QuranReciter(
      identifier: 'everyayah:Parhizgar_48kbps', name: 'شهریار پرهیزگار'),
  Mp3QuranReciter(
      identifier: 'everyayah:Sahl_Yassin_128kbps', name: 'سهل یاسین'),
  Mp3QuranReciter(
      identifier: 'everyayah:Salaah_AbdulRahman_Bukhatir_128kbps',
      name: 'صلاح بوخاطر'),
  Mp3QuranReciter(
      identifier: 'everyayah:Salah_Al_Budair_128kbps', name: 'صلاح البدیر'),
  Mp3QuranReciter(
      identifier: 'everyayah:Saood_ash-Shuraym_128kbps', name: 'سعود الشریم'),
  Mp3QuranReciter(
      identifier: 'everyayah:Yaser_Salamah_128kbps', name: 'یاسر سلامة'),
  Mp3QuranReciter(
      identifier: 'everyayah:Yasser_Ad-Dussary_128kbps', name: 'یاسر الدوسری'),
  Mp3QuranReciter(
      identifier: 'everyayah:aziz_alili_128kbps', name: 'عزیز علیلی'),
  Mp3QuranReciter(
      identifier: 'everyayah:khalefa_al_tunaiji_64kbps', name: 'خلیفة الطنیجی'),
  Mp3QuranReciter(
      identifier: 'everyayah:mahmoud_ali_al_banna_32kbps',
      name: 'محمود علی البنا'),
];
