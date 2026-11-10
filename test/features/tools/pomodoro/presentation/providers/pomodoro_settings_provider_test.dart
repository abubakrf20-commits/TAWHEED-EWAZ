import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/providers/pomodoro_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('loads the saved durations', () async {
    SharedPreferences.setMockInitialValues({
      'pomodoro_focus': 30,
      'pomodoro_short': 8,
      'pomodoro_long': 20,
      'pomodoro_sessions': 3,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(pomodoroSettingsProvider);
    await settle();

    final s = container.read(pomodoroSettingsProvider);
    expect(s.focusMinutes, 30);
    expect(s.shortBreakMinutes, 8);
    expect(s.longBreakMinutes, 20);
    expect(s.sessionsBeforeLong, 3);
  });

  test('an update made before the prefs load lands is not reverted by it',
      () async {
    // build() kicks off the async read and returns the defaults. An edit made
    // in that window used to reach the prefs but be reverted on screen when
    // the load assigned the older values wholesale.
    SharedPreferences.setMockInitialValues({'pomodoro_focus': 30});
    // Warm the prefs singleton first: in the app it is loaded at boot, long
    // before this screen, so the load's continuation resolves in the same
    // turn as the edit. A cold singleton would let the edit's own read finish
    // the cache population and mask the revert.
    await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(pomodoroSettingsProvider);
    final pending = container
        .read(pomodoroSettingsProvider.notifier)
        .update(const PomodoroSettings(focusMinutes: 10));
    await settle();
    await pending;

    expect(container.read(pomodoroSettingsProvider).focusMinutes, 10);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('pomodoro_focus'), 10);
  });
}
