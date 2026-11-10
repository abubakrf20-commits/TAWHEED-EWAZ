part of 'qibla_screen.dart';

extension _QiblaCompassCard on _QiblaScreenState {
  /// Fixed gold for the needle — NOT the accent-preset tertiary. The compass
  /// needle must stay golden in every theme (user request); only light/dark
  /// switches the shade for contrast.
  Color get _needleGold => Theme.of(context).brightness == Brightness.dark
      ? AppTheme.goldSoft
      : AppTheme.goldRich;

  Widget _buildCompass() {
    if (_qiblaDirection == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          // HERO — solid dark card: chips, dial, diff line. The
          // RepaintBoundary lives inside the hero (share raster target),
          // NOT around the scroll — rasters only the compass region.
          if (_userLat != null && _userLng != null) _buildHeroCard(),
          const SizedBox(height: DsSpacing.rowGap),
          if (_declinationError) _buildDeclinationChip(),
          ValueListenableBuilder<CompassReading>(
            // Only this subtree listens to the ~31 Hz sensor feed; the map,
            // sun-shadow and moon cards below rebuild on location/time only.
            valueListenable: _compass,
            builder: (context, reading, _) => Column(
              children: [
                if (reading.sensorAbsent)
                  _buildNoSensorBanner()
                else if (reading.hasFirstReading && reading.needsCalibration)
                  _buildLowAccuracyBanner(),
                if (reading.sensorAbsent ||
                    (reading.hasFirstReading && reading.needsCalibration))
                  const SizedBox(height: 4),
              ],
            ),
          ),
          if (_userLat != null && _userLng != null) ...[
            const SizedBox(height: DsSpacing.gap),
            _buildMapCard(),
          ],
          if (_shadowTimes != null && _shadowTimes!.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.gap),
            _buildSunShadowCard(),
          ],
          if (_solarEvents != null) ...[
            const SizedBox(height: DsSpacing.gap),
            _buildSolarInfoCard(),
          ],
          if (_userLat != null && _userLng != null) ...[
            const SizedBox(height: DsSpacing.gap),
            _buildMoonPositionCard(),
          ],
          // Night-only guide: the flat redesign dropped the `_isNight` gate
          // and the «راهنمای شب» card showed at noon — restored.
          if (_isNight && _userLat != null && _userLat! > 0) ...[
            const SizedBox(height: DsSpacing.gap),
            _buildPolarisGuideCard(),
          ],
          const SizedBox(height: DsSpacing.gap),
          // The «جهت فعلی» card reads the live heading, so it must sit inside
          // the sensor listener. Built from a bare `_compass.value` it froze on
          // the first frame — «—» for the whole session, while the diff line
          // right above it updated on every event.
          ValueListenableBuilder<CompassReading>(
            valueListenable: _compass,
            builder: (context, reading, _) => _buildInfoRow(reading),
          ),
          const SizedBox(height: DsSpacing.gap),
          _buildAccuracyThresholdSelector(),
          const SizedBox(height: 8),
          _buildShareButtons(),
          if (_showManualInput) ...[
            const SizedBox(height: DsSpacing.gap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
              child: _buildManualInputForm(),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// The declination chip (only when WMM lookup failed — the ONLY time the
  /// page says the heading is approximate).
  Widget _buildDeclinationChip() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: DsSpacing.page),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _StatusChip(
          text: 'انحراف مغناطیسی در دسترس نیست · جهت تقریبی',
          icon: Icons.error_outline,
          color: AppTheme.warning,
          bgColor: AppTheme.warningBg,
        ),
      ),
    );
  }

  /// HERO — one solid dark card: chips row, dial, diff line, status chip.
  /// No gradient, no glow, no stars decoration; the share RepaintBoundary
  /// covers this card only.
  Widget _buildHeroCard() {
    final p = _palette;
    final source = _locationSource ?? '';
    final isManual = source.contains('دستی');
    return RepaintBoundary(
      key: _cardKey,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        decoration: BoxDecoration(
          color: p.heroMid,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          children: [
            Row(
              children: [
                GlassChip(
                    icon: Icons.location_on,
                    text: _coordChipText(_userLat!, _userLng!)),
                const SizedBox(width: 6),
                OutlineChip(
                  text: isManual ? 'موقعیت دستی' : 'GPS',
                  icon: isManual ? Icons.edit_location_alt : Icons.gps_fixed,
                ),
                const Spacer(),
                if (_gpsRefreshing)
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<CompassReading>(
              valueListenable: _compass,
              builder: (context, reading, _) => Column(
                children: [
                  _buildDial(reading),
                  const SizedBox(height: 10),
                  _buildDiffLine(reading),
                  const SizedBox(height: 8),
                  _buildTargetChip(reading),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// LTR-isolated chip text: «27.755°N · 54.012°E».
  String _coordChipText(double lat, double lng) => NumberFormat.ltrIsolated(
      '${lat.abs().toStringAsFixed(3)}\u00b0${lat >= 0 ? 'N' : 'S'} \u00b7 '
      '${lng.abs().toStringAsFixed(3)}\u00b0${lng >= 0 ? 'E' : 'W'}');

  /// «اختلاف تا قبله: 149°» — B3: LTR-isolated number, never «°149 :».
  Widget _buildDiffLine(CompassReading reading) {
    final gold = _needleGold;
    // No sensor: the no-sensor banner right below the hero already speaks —
    // «در حال روشن شدن است…» would promise a start that never happens.
    if (reading.sensorAbsent) return const SizedBox.shrink();
    if (reading.heading == null) {
      return Text('قطب‌نما در حال روشن شدن است…',
          style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 11.5),
              color: Colors.white.withValues(alpha: 0.7)));
    }
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'اختلاف تا قبله: '),
          TextSpan(text: GeoFormat.degrees(reading.angle.abs(), decimals: 0)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: AppTheme.scaledFontSize(context, 12),
        fontWeight: FontWeight.w500,
        color: gold,
      ),
    );
  }

  /// INFO ROW — each fact once (B4): qibla angle / distance / heading.
  /// Takes the reading from its listener; never read `_compass.value` here.
  Widget _buildInfoRow(CompassReading reading) {
    final heading = reading.heading;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
      child: Row(
        children: [
          Expanded(
            child: _MiniInfoCard(
              icon: Icons.explore,
              accent: TopicHues.qibla,
              caption: 'زاویه قبله',
              value: GeoFormat.degrees(_qiblaDirection!),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _MiniInfoCard(
              icon: Icons.straighten,
              accent: AppPalette.goldDark,
              caption: 'فاصله تا کعبه',
              value: _distance ?? '—',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _MiniInfoCard(
              icon: Icons.north,
              accent: TopicHues.sciences,
              caption: 'جهت فعلی',
              value: heading == null
                  ? '—'
                  : GeoFormat.degrees(heading, decimals: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSensorBanner() {
    final err = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkError
        : AppTheme.lightError;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: err.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: err.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.sensors_off, size: 17, color: err),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'دستگاه شما حسگر قطب‌نما ندارد — از روش سایهٔ خورشید یا نقشه استفاده کنید',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    height: 1.6,
                    color: err),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowAccuracyBanner() {
    final warn = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkWarning
        : AppTheme.lightWarning;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: warn.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: warn.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, size: 17, color: warn),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'دقت قطب‌نما پایین است — گوشی را چند بار به شکل 8 انگلیسی بچرخانید. تا حد امکان در فضای باز باشید و دور از اشیای فلزی و مغناطیسی (کیف مغناطیسی، اسپیکر، خودرو) نگه دارید',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    height: 1.6,
                    color: warn),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// THE DIAL — the flat rose with its labelled degree ring (the labels the
  /// redesign had dropped: user request, 2026-10-15). The dial lives in its
  /// own widget (`widgets/qibla_dial.dart`) so it is widget-testable — the
  /// page itself cannot be pumped (map tiles over HttpClient).
  Widget _buildDial(CompassReading reading) {
    return QiblaDial(
      heading: reading.heading,
      angle: reading.angle,
      isOnTarget: reading.isOnTarget,
      hasFirstReading: reading.hasFirstReading,
      gold: _needleGold,
      palette: _palette,
      onTap: () async {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (!mounted) return;
        if (!enabled) {
          _showEnableGpsDialog();
        } else {
          _refreshGps();
        }
      },
    );
  }

  Widget _buildTargetChip(CompassReading reading) {
    final gold = _needleGold;
    final isOnTarget = reading.isOnTarget && reading.hasFirstReading;
    // Same reason as the diff line: never tell a phone without a compass to
    // «rotate» — the no-sensor banner owns that state.
    if (reading.sensorAbsent) return const SizedBox.shrink();
    if (!reading.hasFirstReading) {
      return Text('گوشی را بچرخانید',
          style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 12.5),
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.7)));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: isOnTarget
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: isOnTarget
            ? Border.all(color: gold.withValues(alpha: 0.4), width: 0.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOnTarget) ...[
            Icon(Icons.check_circle, size: 16, color: gold),
            const SizedBox(width: 6),
          ],
          Text(
            isOnTarget ? 'روبرو قبله هستید' : _turnInstruction(reading),
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 12.5),
              fontWeight: FontWeight.w500,
              color: isOnTarget ? gold : Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  /// Turn instruction with an isolated number.
  String _turnInstruction(CompassReading reading) {
    final a = reading.angle;
    return a >= 0
        ? 'به راست ${GeoFormat.degrees(a.abs(), decimals: 0)}'
        : 'به چپ ${GeoFormat.degrees(a.abs(), decimals: 0)}';
  }
}

class _MiniInfoCard extends StatelessWidget {
  const _MiniInfoCard({
    required this.icon,
    required this.accent,
    required this.caption,
    required this.value,
  });

  final IconData icon;
  final Color accent;
  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    return AppCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DuotoneIconTile(accent: accent, icon: icon, size: 32),
          const SizedBox(height: 6),
          Text(caption,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 10),
                  color: p.textMuted)),
          const SizedBox(height: 1),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12.5),
                  fontWeight: FontWeight.w500,
                  color: dsContentColor(context, accent))),
        ],
      ),
    );
  }
}
