import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards build portability (audit M-1). An absolute `org.gradle.java.home` is
/// machine-specific: committed, it points at one developer's Android Studio
/// JBR and fails on every other machine and on CI, where Gradle must resolve
/// its own configured JDK. The override belongs in the untracked user-level
/// `~/.gradle/gradle.properties`, so the tracked project file must stay free of
/// it. Commented guidance lines are fine — only a live assignment is rejected.
void main() {
  final props = File('android/gradle.properties');

  test('tracked gradle.properties pins no machine-specific java.home', () {
    expect(props.existsSync(), isTrue,
        reason: 'run from the project root so the file resolves');

    final live = props
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => !l.startsWith('#'))
        .where((l) => l.startsWith('org.gradle.java.home'))
        .toList();

    expect(live, isEmpty,
        reason: 'org.gradle.java.home breaks builds on other machines/CI — '
            'move it to the untracked ~/.gradle/gradle.properties');
  });
}
