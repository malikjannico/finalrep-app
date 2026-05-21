import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/competition.dart';
import '../providers/competition_provider.dart';
import 'competition_detail_page.dart';

class WorldMapView extends StatefulWidget {
  const WorldMapView({super.key});

  @override
  State<WorldMapView> createState() => _WorldMapViewState();
}

class _WorldMapViewState extends State<WorldMapView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Competition? _selectedCompetition;
  Offset? _selectedOffset;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Offset _getOffset(double lat, double lon, Size size) {
    // Equirectangular projection mapping to canvas
    // Longitude: -180 to 180
    final double x = (lon + 180) * (size.width) / 360;

    // Latitude: zoom on populated regions (-50 to 72 latitude)
    const double minLat = -50.0;
    const double maxLat = 72.0;
    final double y = (maxLat - lat) * (size.height) / (maxLat - minLat);
    return Offset(x, y);
  }

  void _onTapUp(TapUpDetails details, Size size, List<Competition> competitions) {
    const double tapRadius = 24.0;
    Competition? closestComp;
    double closestDist = double.infinity;
    Offset? closestOffset;

    for (final comp in competitions) {
      final offset = _getOffset(comp.latitude, comp.longitude, size);
      final dist = (details.localPosition - offset).distance;
      if (dist < tapRadius && dist < closestDist) {
        closestDist = dist;
        closestComp = comp;
        closestOffset = offset;
      }
    }

    setState(() {
      _selectedCompetition = closestComp;
      _selectedOffset = closestOffset;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<CompetitionProvider>(context);
    final competitions = provider.competitions.where((c) => c.latitude != 0.0 || c.longitude != 0.0).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, max(320.0, constraints.maxHeight - 80));

        return Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Map Title & Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        'COMPETITIONS MAP',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Interactive view of upcoming Streetlifting meets globally.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Map Container
                Container(
                  width: size.width,
                  height: size.height,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F0B0A) : const Color(0xFFFAF6F4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Map Painter
                        GestureDetector(
                          onTapUp: (details) => _onTapUp(details, size, competitions),
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return CustomPaint(
                                size: size,
                                painter: WorldMapPainter(
                                  competitions: competitions,
                                  isDark: isDark,
                                  theme: theme,
                                  pulseValue: _pulseController.value,
                                  selectedCompetition: _selectedCompetition,
                                ),
                              );
                            },
                          ),
                        ),

                        // Popover Details Card
                        if (_selectedCompetition != null && _selectedOffset != null)
                          Positioned(
                            left: max(16.0, min(_selectedOffset!.dx - 140.0, size.width - 296.0)),
                            top: _selectedOffset!.dy < size.height / 2 
                                ? _selectedOffset!.dy + 24.0 
                                : _selectedOffset!.dy - 170.0,
                            child: Container(
                              width: 280,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  )
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedCompetition!.title,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedCompetition = null;
                                            _selectedOffset = null;
                                          });
                                        },
                                        child: const Icon(Icons.close, size: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _selectedCompetition!.location,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_month_outlined, size: 14, color: theme.colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('MMM dd, yyyy').format(_selectedCompetition!.startDate),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _selectedCompetition!.isModern
                                              ? theme.colorScheme.primaryContainer
                                              : theme.colorScheme.tertiaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _selectedCompetition!.sportSubtype.toUpperCase(),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: _selectedCompetition!.isModern
                                                ? theme.colorScheme.onPrimaryContainer
                                                : theme.colorScheme.onTertiaryContainer,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => CompetitionDetailPage(
                                                competition: _selectedCompetition!,
                                              ),
                                            ),
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Details',
                                              style: TextStyle(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Icon(Icons.chevron_right, size: 14, color: theme.colorScheme.primary),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

class WorldMapPainter extends CustomPainter {
  final List<Competition> competitions;
  final bool isDark;
  final ThemeData theme;
  final double pulseValue;
  final Competition? selectedCompetition;

  WorldMapPainter({
    required this.competitions,
    required this.isDark,
    required this.theme,
    required this.pulseValue,
    this.selectedCompetition,
  });

  Offset _getOffset(double lat, double lon, Size size) {
    final double x = (lon + 180) * (size.width) / 360;
    const double minLat = -50.0;
    const double maxLat = 72.0;
    final double y = (maxLat - lat) * (size.height) / (maxLat - minLat);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Grid Lines
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;

    // Draw Longitudes (vertical)
    for (double lon = -150; lon <= 150; lon += 30) {
      final p1 = _getOffset(72, lon, size);
      final p2 = _getOffset(-50, lon, size);
      canvas.drawLine(p1, p2, gridPaint);
    }
    // Draw Latitudes (horizontal)
    for (double lat = -40; lat <= 60; lat += 20) {
      final p1 = _getOffset(lat, -180, size);
      final p2 = _getOffset(lat, 180, size);
      canvas.drawLine(p1, p2, gridPaint);
    }

    // 2. Continent Polygons
    final Map<String, List<Offset>> continentPoints = {
      'NorthAmerica': [
        const Offset(-168, 65),
        const Offset(-120, 70),
        const Offset(-60, 80),
        const Offset(-55, 60),
        const Offset(-85, 45),
        const Offset(-50, 48),
        const Offset(-80, 25),
        const Offset(-100, 15),
        const Offset(-105, 20),
        const Offset(-125, 32),
        const Offset(-125, 48),
      ],
      'SouthAmerica': [
        const Offset(-80, 10),
        const Offset(-40, -5),
        const Offset(-35, -5),
        const Offset(-45, -22),
        const Offset(-70, -55),
        const Offset(-75, -50),
        const Offset(-70, -20),
        const Offset(-80, -5),
      ],
      'Greenland': [
        const Offset(-73, 78),
        const Offset(-60, 83),
        const Offset(-10, 81),
        const Offset(-40, 60),
      ],
      'Africa': [
        const Offset(-17, 32),
        const Offset(10, 37),
        const Offset(32, 31),
        const Offset(51, 11),
        const Offset(40, -34),
        const Offset(20, -34),
        const Offset(9, 4),
      ],
      'Eurasia': [
        const Offset(-9, 38), // Spain
        const Offset(12, 65), // Scandinavia
        const Offset(25, 71),
        const Offset(60, 73), // Siberia
        const Offset(100, 77),
        const Offset(170, 66), // Bering strait
        const Offset(140, 50),
        const Offset(130, 35), // China
        const Offset(120, 20),
        const Offset(110, 10), // Indochina
        const Offset(95, 10),
        const Offset(90, 22), // India
        const Offset(70, 8),
        const Offset(60, 25), // Middle East
        const Offset(48, 12),
        const Offset(34, 30),
        const Offset(26, 40), // Greece/Italy
      ],
      'Australia': [
        const Offset(113, -22),
        const Offset(136, -12),
        const Offset(143, -10),
        const Offset(153, -28),
        const Offset(140, -38),
        const Offset(115, -35),
      ],
      'Japan': [
        const Offset(130, 32),
        const Offset(133, 35),
        const Offset(138, 35),
        const Offset(142, 43),
        const Offset(140, 38),
      ],
      'UnitedKingdom': [
        const Offset(-8, 50),
        const Offset(-2, 58),
        const Offset(2, 51),
      ]
    };

    final continentPaint = Paint()
      ..color = isDark ? const Color(0xFF221815) : const Color(0xFFEFE8E5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isDark ? const Color(0xFF382A25) : const Color(0xFFDFD4D0)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    continentPoints.forEach((name, points) {
      final path = Path();
      final start = _getOffset(points[0].dy, points[0].dx, size);
      path.moveTo(start.dx, start.dy);

      for (int i = 1; i < points.length; i++) {
        final p = _getOffset(points[i].dy, points[i].dx, size);
        path.lineTo(p.dx, p.dy);
      }
      path.close();

      canvas.drawPath(path, continentPaint);
      canvas.drawPath(path, borderPaint);
    });

    // 3. Draw Pins & Pulsing Rings for Competitions
    final markerPaint = Paint()
      ..color = theme.colorScheme.primary
      ..style = PaintingStyle.fill;

    final markerBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final comp in competitions) {
      final offset = _getOffset(comp.latitude, comp.longitude, size);
      final isSelected = selectedCompetition?.id == comp.id;

      // Draw pulsing ring (multiple ripples)
      final pulsePaint = Paint()
        ..color = theme.colorScheme.primary.withValues(alpha: (1 - pulseValue) * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      canvas.drawCircle(offset, 4.0 + pulseValue * 16.0, pulsePaint);
      
      if (isSelected) {
        // Draw larger ring for selected marker
        final selectedPaint = Paint()
          ..color = theme.colorScheme.primary.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(offset, 14.0, selectedPaint);
      }

      // Draw the core pin dot
      canvas.drawCircle(offset, isSelected ? 7.0 : 5.0, markerPaint);
      canvas.drawCircle(offset, isSelected ? 7.0 : 5.0, markerBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WorldMapPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue || 
           oldDelegate.selectedCompetition != selectedCompetition ||
           oldDelegate.competitions.length != competitions.length;
  }
}
