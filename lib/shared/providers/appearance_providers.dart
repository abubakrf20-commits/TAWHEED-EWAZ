import 'package:flutter_riverpod/flutter_riverpod.dart';

const defaultCornerRadius = 24;

class _CornerRadiusNotifier extends Notifier<int> {
  @override
  int build() => defaultCornerRadius;

  void set(int value) => state = value;
}

final cornerRadiusProvider =
    NotifierProvider<_CornerRadiusNotifier, int>(_CornerRadiusNotifier.new);
