import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/data/place_index.dart';
import 'package:tawheeed/features/prayer/services/location_resolver.dart';

/// Offline-first city picker, shown as a bottom sheet.
///
/// Before this existed the only ways to set a location by hand were tapping a
/// map or typing two raw numbers — and the bundled name table was Iranian, so
/// anyone outside Iran had no way to simply type «لندن» or «لاگوس». This sheet
/// searches both bundled tables ([PlaceIndex]) with no network, and only falls
/// back to online geocoding when the offline tables have nothing.
///
/// Returns the chosen [PlaceMatch]; applying it to settings is the caller's
/// job, so the sheet stays side-effect free and testable.
class CityPickerSheet extends StatefulWidget {
  const CityPickerSheet({super.key, this.initialQuery = ''});

  final String initialQuery;

  /// Opens the sheet and returns the picked place, or null if dismissed.
  static Future<PlaceMatch?> show(BuildContext context,
      {String initialQuery = ''}) {
    return showModalBottomSheet<PlaceMatch>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CityPickerSheet(initialQuery: initialQuery),
    );
  }

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  List<PlaceMatch> _results = const [];
  bool _searchingOnline = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _apply(widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply(String query) {
    setState(() {
      _results = PlaceIndex.search(query);
    });
  }

  /// Asks the platform geocoder for a name the offline tables do not know.
  Future<void> _searchOnline() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() => _searchingOnline = true);
    final coords = await LocationResolver.resolveCoordinates(query);
    if (!mounted) return;
    setState(() => _searchingOnline = false);
    if (coords == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('این نام پیدا نشد')),
      );
      return;
    }
    // A geocoded point has no bundled country label; show it as its own hit so
    // the user still confirms the coordinates before they are stored.
    Navigator.of(context).pop(
        PlaceMatch(name: query, country: '', lat: coords.lat, lng: coords.lng));
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textDirection: TextDirection.rtl,
                onChanged: _apply,
                onSubmitted: (_) => _searchOnline(),
                decoration: InputDecoration(
                  hintText: 'نام شهر را بنویسید',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: _buildList(query),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(String query) {
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                query.isEmpty
                    ? 'شهری را جست‌وجو کنید'
                    : 'در فهرست همراه این شهر نیست',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: TimeThemeKit.of(context).palette.textMuted),
              ),
              if (query.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _searchingOnline ? null : _searchOnline,
                  icon: _searchingOnline
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi, size: 18),
                  label: const Text('جست‌وجو در اینترنت'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final place = _results[index];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.place_outlined, size: 20),
          title: Text(place.name,
              style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 14))),
          subtitle: Text(
            '${place.country} · ${place.lat.toStringAsFixed(3)}, '
            '${place.lng.toStringAsFixed(3)}',
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: TimeThemeKit.of(context).palette.textMuted),
          ),
          onTap: () => Navigator.of(context).pop(place),
        );
      },
    );
  }
}
