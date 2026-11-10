plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    // The Compose compiler plugin (org.jetbrains.kotlin.plugin.compose) was
    // retired with Glance on 2026-11-04: both home-screen widgets are
    // hand-built RemoteViews now (PrayerNativeViews / TasbihNativeViews) and
    // no @Composable remains in this module — keeping the plugin without any
    // Compose runtime on the class path is a hard compile error.
    // Reads android/app/google-services.json and generates the resources the
    // Google/Firebase plugins look up at runtime — WITHOUT this line the file
    // is inert: `default_web_client_id` is absent, so google_sign_in cannot
    // resolve a serverClientId and the Google account picker never opens, and
    // no Firebase resource exists for the native SDK. Declared in
    // settings.gradle.kts with `apply false`; it must be APPLIED here.
    id("com.google.gms.google-services")
}

import java.util.Properties

// Load keystore credentials from key.properties (not committed to VCS)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

// The ONE versionCode that ever moves — and only at publish time: bump it by
// 1..10 right before a publish, then it stays frozen through the next
// development cycle. Frozen at the user-chosen cap 2_000_012_020 (2026-10-17):
// above every code real installs carry (1.7.1 published = 2_000_010_013,
// 1.7.0 direct = 2_000_004_000).
val FROZEN_VERSION_CODE = 2_000_012_020

// The code the ONE shipped APK carries: the frozen base plus a 3000 offset.
//
// Why an offset and not the bare base — this is a correction, not a bump.
// Earlier builds also produced ABI splits, and those carried base+1000
// (armeabi-v7a = 2_000_013_020) and base+2000 (arm64-v8a = 2_000_014_020).
// Any device that installed a split therefore holds a code ABOVE the base, and
// the universal APK (bare base) could never update it:
//
//   $ adb install -r build/.../app-release.apk
//   Failure [INSTALL_FAILED_VERSION_DOWNGRADE: Update version code 2000012020
//            is older than current 2000014020]
//
// `adb install -d` does not help: it only allows a downgrade for DEBUGGABLE
// packages. The result for a real user is «بسته نامعتبر» with no way out short
// of an uninstall, which loses their data.
//
// Splits are no longer built (see the `splits` block), so the shipped APK is
// the only artifact — and it must outrank every code already in the wild.
// 3020 clears the published 1.9.0 code (+3010 = 2_000_015_030) and stays
// 1..10-away from the next publish bump (bumped +10, 2026-11-07).
val SHIPPED_VERSION_CODE = FROZEN_VERSION_CODE + 3_020

android {
    testOptions {
        // Plain unit tests run on the JVM: unmocked android.* calls (Log, etc.)
        // return default values instead of throwing, matching common app-code
        // paths that log via android.util.Log.
        unitTests.isReturnDefaultValues = true
        // Robolectric needs the merged resources/manifest to build the app from
        // the real AndroidManifest.xml (receiver actions, activity flags).
        unitTests.isIncludeAndroidResources = true
    }

    namespace = "com.islamic.tawheeed"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.islamic.tawheeed"
        // 24 = Android 7.0: required by the committed flutter_local_notifications
        // 22.x. The AGP 9 block below re-enables v1 signing for minSdk >= 24 so
        // the APK still installs on older Android versions.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // See SHIPPED_VERSION_CODE above: the frozen base carries a fixed 3000
        // offset so the single shipped APK outranks every ABI-split code that
        // earlier builds handed out. `pubspec.yaml`'s `+code` and any
        // `--build-number` deliberately do NOT take part — they moved the code
        // on every build, which is exactly what the freeze forbids.
        // `versionName` still comes from pubspec so the UI can report 1.9.0.
        versionCode = SHIPPED_VERSION_CODE
        versionName = flutter.versionName

        // Ship only the two ABIs actually served (arm64 for modern devices,
        // armeabi-v7a for older 32-bit phones). This keeps the universal APK
        // from carrying x86/x86_64 native libs (emulator-only, ~20 MB).
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: ""
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: ""
            storeFile = file(keystoreProperties.getProperty("storeFile") ?: "release-key.jks")
            storePassword = keystoreProperties.getProperty("storePassword") ?: ""
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
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

    splits {
        abi {
            // OFF, deliberately — and this is a bug fix, not a preference.
            //
            // On AGP 9.1.1 the arm64-v8a split is packaged WITHOUT its
            // manifest or resources. The file is a valid zip (339 entries,
            // `unzip -t` clean) but holds only dex + libs + assets:
            //
            //   $ aapt2 dump badging app-arm64-v8a-release.apk
            //   error: could not identify format of APK.
            //   $ adb install -r app-arm64-v8a-release.apk
            //   Failure [INSTALL_PARSE_FAILED_UNEXPECTED_EXCEPTION: ... base.apk:
            //            AndroidManifest.xml]
            //
            // The armeabi-v7a split and the universal APK from the same run are
            // both fine (1803 / 1810 entries), so this is specific to the arm64
            // output — the ABI almost every real device needs. Shipping it means
            // handing arm64 users an APK that cannot be installed.
            //
            // The universal APK already contains only armeabi-v7a + arm64-v8a
            // (see `ndk.abiFilters`), so dropping splits costs size, not
            // support: 52 MB instead of 32 MB, still inside the CI budget.
            // One artifact also removes the versionCode deadlock documented at
            // SHIPPED_VERSION_CODE — with two artifact kinds there is always one
            // that a given install can never receive.
            isEnable = false
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            // Keep the ABI policy: only armeabi-v7a + arm64-v8a ship. Plugin
            // AARs can bring x86/x86_64 .so files that must not inflate the
            // universal APK.
            excludes += setOf("lib/x86/**", "lib/x86_64/**")
        }
    }

}

// AGP 9 forces V1 signing off whenever minSdk >= 24, even if
// enableV1Signing = true above. Re-enable it through the new variant API so
// the APK also installs on older Android versions and via installers that
// only accept v1-signed packages.
androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        println("Codebuff: variant=${variant.name} signingConfig=${variant.signingConfig}")
        variant.signingConfig?.enableV1Signing?.set(true)
        variant.signingConfig?.enableV2Signing?.set(true)
        variant.signingConfig?.enableV3Signing?.set(true)
    }
    // Per-output version codes are gone with the ABI splits: there is exactly
    // one output now, and it takes SHIPPED_VERSION_CODE from defaultConfig.
}
// Legacy KGP path (built-in Kotlin disabled): align Kotlin JVM target with
// compileOptions above.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Native AndroidX WorkManager runs background notification maintenance.
    implementation("androidx.work:work-runtime:2.10.2")
    implementation("androidx.concurrent:concurrent-futures:1.2.0")
    // Glance was retired on 2026-11-04: both home-screen widgets are
    // hand-built RemoteViews now (PrayerNativeViews / TasbihNativeViews); a
    // Glance session composes once per process on the test launcher and
    // cannot take partial updates — see the two builders' headers. The
    // dependency, the Compose compiler plugin and `compose = true` all went
    // with it.
    testImplementation("junit:junit:4.13.2")
    // Real org.json for local unit tests — the android.jar stubs throw
    // "not mocked" for JSONObject.put(), which the widget's per-zikr counter
    // persistence needs.
    testImplementation("org.json:json:20240303")
    // Robolectric: JVM harness for the widget's onReceive/applyTap paths (the
    // WIDGETS_PLAN option 5 gap — three shipped tap bugs were invisible to
    // both plain JVM tests and flutter test). testImplementation-only, so the
    // release APK is untouched. 4.17 = current stable, supports SDK 36-era
    // code; tests pin @Config(sdk=[34]) for determinism.
    testImplementation("org.robolectric:robolectric:4.17")
}

// Gradle 9's strict task-graph validation: with unitTests.isIncludeAndroidResources,
// the JVM-test packaging task (PackageForHostTest) consumes the merged assets, but
// the Flutter plugin's asset copy writes into that same output without a declared
// edge. Test-only path — release builds do not run these tasks.
tasks.matching { it.name == "packageDebugUnitTestForUnitTest" }.configureEach {
    dependsOn("copyFlutterAssetsDebug")
}
tasks.matching { it.name == "packageReleaseUnitTestForUnitTest" }.configureEach {
    dependsOn("copyFlutterAssetsRelease")
}
