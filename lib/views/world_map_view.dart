import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<CompetitionProvider>(context);
    final competitions = provider.competitions.where((c) => c.latitude != 0.0 || c.longitude != 0.0).toList();

    return Column(
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
        
        // Map Container (Expanded so it fits the remaining vertical space without scrolling)
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;

                  // Calculate min zoom required to contain the world map (-180 to 180 lon, -85 to 85 lat) without showing borders.
                  // Width of map at zoom Z is 256 * 2^Z. We want 256 * 2^Z >= width => Z >= log2(width / 256).
                  // Height of map at zoom Z is 256 * 2^Z. We want 256 * 2^Z >= height => Z >= log2(height / 256).
                  // If constraints are not set or zero (e.g. initial layout pass), fallback to 1.8.
                  double calculatedMinZoom = 1.8;
                  if (width > 0 && height > 0) {
                    final minZoomX = math.log(width / 256) / math.log(2);
                    final minZoomY = math.log(height / 256) / math.log(2);
                    calculatedMinZoom = math.max(1.8, math.max(minZoomX, minZoomY));
                  }

                  return Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: const LatLng(30.0, 0.0),
                          initialZoom: calculatedMinZoom,
                          minZoom: calculatedMinZoom,
                          maxZoom: 18.0,
                          backgroundColor: isDark ? const Color(0xFF0F0B0A) : const Color(0xFFFAF6F4),
                          cameraConstraint: SafeContainCameraConstraint(
                            bounds: LatLngBounds(
                              const LatLng(-85.0, -180.0),
                              const LatLng(85.0, 180.0),
                            ),
                          ),
                          onTap: (tapPosition, point) {
                            setState(() {
                              _selectedCompetition = null;
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: isDark
                                ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                                : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.finalrep.app',
                          ),
                          MarkerLayer(
                            markers: competitions.map((comp) {
                              return Marker(
                                point: LatLng(comp.latitude, comp.longitude),
                                width: 60,
                                height: 60,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    setState(() {
                                      _selectedCompetition = comp;
                                    });
                                  },
                                  child: AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      final isSelected = _selectedCompetition?.id == comp.id;
                                      return Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Outer pulsing ring
                                          Container(
                                            width: 12 + _pulseController.value * 28,
                                            height: 12 + _pulseController.value * 28,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: theme.colorScheme.primary.withValues(
                                                  alpha: (1.0 - _pulseController.value) * 0.6,
                                                ),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            // Selected state extra ring
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                              ),
                                            ),
                                          // Inner pin dot
                                          Container(
                                            width: isSelected ? 12 : 8,
                                            height: isSelected ? 12 : 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: theme.colorScheme.primary,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.3),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      // Floating details card at the bottom of the map Stack
                      if (_selectedCompetition != null)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: Card(
                                margin: EdgeInsets.zero,
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
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
                                              });
                                            },
                                            child: const Icon(Icons.close, size: 16),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
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
                                                    height: 1.0,
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
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SafeContainCameraConstraint extends CameraConstraint {
  final LatLngBounds bounds;

  const SafeContainCameraConstraint({required this.bounds});

  @override
  MapCamera constrain(MapCamera camera) {
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize ||
        camera.nonRotatedSize.width <= 0 ||
        camera.nonRotatedSize.height <= 0) {
      return camera;
    }

    // Detect if we are called from MapController's option setter or during widget updates.
    // In these cases, return the camera unmodified to prevent the assertion failure:
    // "MapCamera is no longer within the cameraConstraint after an option change."
    final stack = StackTrace.current.toString();
    if (stack.contains('setOptions') ||
        stack.contains('didUpdateWidget')) {
      return camera;
    }

    final testZoom = camera.zoom;
    final testCenter = camera.center;

    final nePixel = camera.projectAtZoom(bounds.northEast, testZoom);
    final swPixel = camera.projectAtZoom(bounds.southWest, testZoom);

    final halfSize = camera.size / 2;

    final leftOkCenter = math.min(swPixel.dx, nePixel.dx) + halfSize.width;
    final rightOkCenter = math.max(swPixel.dx, nePixel.dx) - halfSize.width;
    final topOkCenter = math.min(swPixel.dy, nePixel.dy) + halfSize.height;
    final bottomOkCenter = math.max(swPixel.dy, nePixel.dy) - halfSize.height;

    final centerPix = camera.projectAtZoom(testCenter, testZoom);

    double targetX = centerPix.dx;
    if (leftOkCenter <= rightOkCenter) {
      targetX = centerPix.dx.clamp(leftOkCenter, rightOkCenter);
    } else {
      // Screen is wider than the map bounds at this zoom level. Center horizontally.
      targetX = (swPixel.dx + nePixel.dx) / 2;
    }

    double targetY = centerPix.dy;
    if (topOkCenter <= bottomOkCenter) {
      targetY = centerPix.dy.clamp(topOkCenter, bottomOkCenter);
    } else {
      // Screen is taller than the map bounds at this zoom level. Center vertically.
      targetY = (swPixel.dy + nePixel.dy) / 2;
    }

    final newCenterPix = Offset(targetX, targetY);

    if (newCenterPix == centerPix) return camera;

    // Use a small tolerance for floating point errors to avoid creating a new camera
    // when coordinates are visually identical.
    final dxDiff = (newCenterPix.dx - centerPix.dx).abs();
    final dyDiff = (newCenterPix.dy - centerPix.dy).abs();
    if (dxDiff < 1e-3 && dyDiff < 1e-3) {
      return camera;
    }

    return camera.withPosition(
      center: camera.unprojectAtZoom(newCenterPix, testZoom),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SafeContainCameraConstraint && other.bounds == bounds;
  }

  @override
  int get hashCode => bounds.hashCode;
}
