package com.islamic.tawheeed.widget

/**
 * The vertical prayer card's OWN provider.
 *
 * It is a zero-override subclass of [PrayerWidget]: every behaviour — the data
 * recompute, the alarm chain, the tap repaint, the boundary / minute / watchdog
 * / midnight arms — is inherited. The one thing that makes it a different
 * widget is its class name, which the launcher registers as a second,
 * independently placeable provider.
 *
 * Because [PrayerWidget] now builds every alarm Intent against `javaClass`
 * rather than a hardcoded `PrayerWidget`, this subclass' alarms are tagged with
 * `PrayerWidgetVertical` and are delivered to its own `onReceive` — so arming or
 * cancelling one provider never touches the other's alarms.
 *
 * Orientation is decided per render by the widget instance's actual provider
 * component (see [PrayerNativeViews.useVertical]): a card whose provider IS this
 * class is always drawn as the vertical card, regardless of the legacy
 * `widget_prayer_layout` pref. That pref only controls the horizontal
 * provider's instances, for backward compatibility with installs that chose
 * "vertical" before this second provider existed.
 *
 * The result is exactly what the user asked for: the horizontal and vertical
 * prayer widgets can now live on the home screen at the same time, each
 * independent of the other.
 */
class PrayerWidgetVertical : PrayerWidget()
