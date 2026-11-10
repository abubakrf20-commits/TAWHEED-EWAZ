# إعداد Release Signing للنشر على Google Play

## الخطوة 1: إنشاء Keystore

افتح Terminal أو Command Prompt وشغّل الأمر التالي:

```bash
keytool -genkey -v -keystore C:\Users\abubakr\Desktop\tawheeed\android\app\release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

ستُطلب منك إدخال:
- **Password**: اختر كلمة مرور قوية (مثلاً: `Tawheed2024!`)
- **First/Last Name**: `Abubakr Froghi`
- **Organizational Unit**: (اتركه فارغاً أو اكتب `Development`)
- **Organization**: `Tawheed`
- **City**: (اكتب مدينتك)
- **Province**: (اكتب مقاطعتك)
- **Country Code**: `AF` أو `IR`

## الخطوة 2: إنشاء key.properties

أنشئ ملف `android/key.properties` بالمحتوى التالي:

```properties
storePassword=your_password_here
keyPassword=your_password_here
keyAlias=upload
storeFile=release-key.jks
```

**مهم**: أضف `key.properties` إلى `.gitignore` لعدم رفعه إلى Git.

## الخطوة 3: تحديث build.gradle.kts

تأكد من أن `android/app/build.gradle.kts` يحتوي على الكود التالي:

```kotlin
android {
    signingConfigs {
        create("release") {
            val keystorePropertiesFile = rootProject.file("key.properties")
            val keystoreProperties = java.util.Properties()
            if (keystorePropertiesFile.exists()) {
                keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
            }
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"] as File?
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}
```

## الخطوة 4: بناء APK للإنتاج

```bash
cd android
./gradlew assembleRelease
```

أو عبر Flutter:

```bash
flutter build apk --release
```

الملف الناتج سيكون في:
```
android/app/build/outputs/apk/release/app-release.apk
```

## الخطوة 5: بناء App Bundle (مُوصى به)

```bash
flutter build appbundle --release
```

الملف الناتج سيكون في:
```
build/app/outputs/bundle/release/app-release.aab
```

**ملاحظة**: Google Play يُوصي باستخدام AAB بدلاً من APK.

## التحقق من التوقيع

```bash
jarsigner -verify -verbose -certs android/app/build/outputs/apk/release/app-release.apk
```

يجب أن ترى `jar verified`.

## ملاحظات أمنية

- **لا ترفع** `release-key.jks` أو `key.properties` إلى Git
- **احفظ** نسخة احتياطية من Keystore في مكان آمن
- **لا تفقد** Keystore — لن تتمكن من تحديث التطبيق بدونه
- **استخدم** كلمة مرور قوية للـ Keystore
