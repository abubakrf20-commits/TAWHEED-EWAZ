$ErrorActionPreference = 'Stop'

$map = @{
  'SettingsProvider'      = 'settingsBridgeProvider',      'settings_bridge.dart'
  'PrayerTimeService'     = 'prayerTimeBridgeProvider',     'prayer_time_bridge.dart'
  'TasbihProvider'        = 'tasbihBridgeProvider',         'tasbih_bridge.dart'
  'AzkarProvider'         = 'azkarBridgeProvider',          'azkar_bridge.dart'
  'PrayerTrackerProvider' = 'prayerTrackerBridgeProvider',  'prayer_tracker_bridge.dart'
  'EvaluationService'     = 'evaluationBridgeProvider',     'evaluation_bridge.dart'
  'ReminderService'       = 'reminderBridgeProvider',       'reminder_bridge.dart'
}

function Transform-File($path) {
  $content = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  $orig = $content

  # 1) Remove the provider package import line
  $content = [regex]::Replace($content, "(?m)^\s*import 'package:provider/provider\.dart';\s*`r?`n", '')

  # 2) Ensure flutter_riverpod import is present (needed for ProviderScope)
  if ($content -notmatch "package:flutter_riverpod/flutter_riverpod\.dart") {
    $content = [regex]::Replace($content, "(?m)^(import 'package:flutter/material\.dart';)", "`$1`nimport 'package:flutter_riverpod/flutter_riverpod.dart';", 1)
  }

  foreach ($kv in $map.GetEnumerator()) {
    $cls = $kv.Key
    $bridge = $kv.Value[0]
    $bridgeFile = $kv.Value[1]

    # 3) Consumer<Cls>( builder: (context, var, _) {  ->  Builder( builder: (context) { final var = ProviderScope.containerOf(context).watch(bridge);
    $content = [regex]::Replace($content, "Consumer<$cls>\(\s*builder:\s*\(context,\s*(\w+),\s*_\)\s*\{", {
      param($m)
      $var = $m.Groups[1].Value
      "Builder(`n  builder: (context) {`n    final $var = ProviderScope.containerOf(context).watch($bridge);"
    })

    # 4) context.watch<Cls>()  ->  ProviderScope.containerOf(context).watch(bridge)
    $content = [regex]::Replace($content, "context\.watch<$cls>\(\)", "ProviderScope.containerOf(context).watch($bridge)")

    # 5) context.read<Cls>()  ->  ProviderScope.containerOf(context).read(bridge)
    $content = [regex]::Replace($content, "context\.read<$cls>\(\)", "ProviderScope.containerOf(context).read($bridge)")

    # 6) Add bridge import if the bridge provider is referenced and not already imported
    if ($content -match [regex]::Escape($bridge) -and $content -notmatch [regex]::Escape("providers/bridges/$bridgeFile")) {
      $imp = "import 'package:tawheeed/presentation/providers/bridges/$bridgeFile';"
      if ($content -notmatch [regex]::Escape($imp)) {
        $content = [regex]::Replace($content, "(?m)^(import 'package:flutter_riverpod/flutter_riverpod\.dart';)", "`$1`n$imp", 1)
      }
    }
  }

  if ($content -ne $orig) {
    [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "TRANSFORMED: $path"
  }
}

# Process every dart file under lib (idempotent)
Get-ChildItem -Path lib -Recurse -Filter *.dart | ForEach-Object {
  Transform-File $_.FullName
}
