import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tawheeed/features/home/services/widget_sync.dart';

part 'widget_sync_provider.g.dart';

@Riverpod(keepAlive: true)
WidgetSync widgetSync(Ref ref) => WidgetSync();
