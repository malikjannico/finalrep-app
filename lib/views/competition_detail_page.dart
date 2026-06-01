import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/competition.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';

class CompetitionDetailPage extends StatefulWidget {
  final Competition? competition;
  final String? competitionId;

  const CompetitionDetailPage({
    super.key,
    this.competition,
    this.competitionId,
  });

  @override
  State<CompetitionDetailPage> createState() => _CompetitionDetailPageState();
}

class _CompetitionDetailPageState extends State<CompetitionDetailPage> {
  Competition? _competition;
  bool _isLoading = false;
  List<Map<String, dynamic>> _allResults = [];
  bool _isLoadingResults = false;
  String _selectedRankingsFilter = 'All';

  @override
  void initState() {
    super.initState();
    if (widget.competition != null) {
      _competition = widget.competition;
      if (_competition!.status == 'completed') {
        _loadMeetResults();
      }
    } else if (widget.competitionId != null) {
      _loadCompetition().then((_) {
        if (_competition != null && _competition!.status == 'completed') {
          _loadMeetResults();
        }
      });
    }
  }

  Future<void> _loadMeetResults() async {
    if (_competition == null) return;
    setState(() {
      _isLoadingResults = true;
    });
    try {
      final provider = Provider.of<CompetitionProvider>(context, listen: false);
      final list = await provider.competitionRepository.getMeetResults();
      final filtered = list.where((item) {
        final compMap = item['competition'] as Map? ?? {};
        final cId = compMap['id'] as String? ?? item['competition_id'] as String? ?? '';
        return cId == _competition!.id;
      }).toList();

      if (mounted) {
        setState(() {
          _allResults = filtered;
          _isLoadingResults = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading meet results: $e');
      if (mounted) {
        setState(() {
          _isLoadingResults = false;
        });
      }
    }
  }

  Future<void> _loadCompetition() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final provider = Provider.of<CompetitionProvider>(context, listen: false);
      final comp = await provider.getCompetitionById(widget.competitionId!);
      if (mounted) {
        setState(() {
          _competition = comp;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading competition details: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE94E1B)),
          ),
        ),
      );
    }

    final provider = Provider.of<CompetitionProvider>(context);
    final compId = _competition?.id ?? widget.competitionId;
    final competition = provider.competitions.firstWhere(
      (c) => c.id == compId,
      orElse: () => _competition ?? widget.competition!,
    );

    final theme = Theme.of(context);

    final dateFormat = DateFormat('EEEE, MMMM dd, yyyy');
    final dateStr = dateFormat.format(competition.startDate);
    final timeStr =
        "${DateFormat('HH:mm').format(competition.startDate)} - ${DateFormat('HH:mm').format(competition.endDate)}";

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Hero Top App Bar
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 20),
                ),
                onPressed: () {
                  const String appDomain = String.fromEnvironment(
                    'APP_DOMAIN',
                    defaultValue: 'app.final-rep.com',
                  );
                  final String url = kIsWeb
                      ? '${Uri.base.origin}/competitions/${competition.id}'
                      : 'https://$appDomain/competitions/${competition.id}';
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Link copied to clipboard: $url'),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildHeroImage(context, theme),
                  // Bottom gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                  // Floating badges on bottom of image
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: competition.isModern
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            competition.sportSubtype.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: competition.isModern
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onTertiaryContainer,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer
                                .withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            competition.isPartOfGroup
                                ? competition.compGroupName!.toUpperCase()
                                : 'INDIVIDUAL MEET',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main body content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    competition.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick info cards
                  Row(
                    children: [
                      _buildQuickInfoCard(
                        context,
                        icon: Icons.calendar_month_outlined,
                        title: 'Date',
                        subtitle: dateStr,
                      ),
                      const SizedBox(width: 12),
                      _buildQuickInfoCard(
                        context,
                        icon: Icons.access_time,
                        title: 'Time',
                        subtitle: timeStr,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildQuickInfoCard(
                        context,
                        icon: Icons.location_on_outlined,
                        title: 'Location',
                        subtitle: competition.location,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'About this Competition',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    competition.description ??
                        'No detailed description available for this meet yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Disciplines & Format Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.fitness_center,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Streetlifting ${competition.sportSubtype} Format',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Streetlifting is a young urban strength sport where athletes get 3 attempts to score a One-Rep-Max (1RM) on the lifts. The highest weights are summed for the final total.',
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Included Lifts:',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...competition.disciplines.map(
                          (d) => _buildDisciplineRow(theme, d),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // CTA Buttons (Actions placeholder)
                  (() {
                    final authProvider = Provider.of<AuthProvider>(context);
                    final compProvider = Provider.of<CompetitionProvider>(context);
                    final currentUser = authProvider.currentUserProfile;
                    final bool ownsAssociation = competition.associationId != null &&
                        compProvider.associations.any(
                          (assoc) =>
                              assoc.id == competition.associationId &&
                              assoc.ownerId == currentUser?.id,
                        );
                    final bool canManageIndividual =
                        competition.associationId == null && currentUser?.isCompetitionCreator == true;
                    final bool isOrganizer = currentUser != null && (currentUser.isAdmin || ownsAssociation || canManageIndividual);
                    final bool registrationEnded = DateTime.now().isAfter(competition.registrationEnd);

                    if (competition.registrationMode == 'random' && isOrganizer) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  key: const Key('run_random_draw_btn'),
                                  icon: const Icon(Icons.shuffle),
                                  label: const Text('Run Random Draw'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.tertiary,
                                    foregroundColor: theme.colorScheme.onTertiary,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: registrationEnded
                                      ? () async {
                                          final success = await compProvider.runRandomDraw(competition.id);
                                          if (context.mounted) {
                                            if (success) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Random draw completed successfully!'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(compProvider.errorMessage ?? 'Random draw failed'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          if (!registrationEnded) ...[
                            const SizedBox(height: 4),
                            Center(
                              child: Text(
                                'Draw can only be run after registration ends.',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  })(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                            final currentUser = authProvider.currentUserProfile;
                            if (currentUser == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please log in to register.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            final success = await compProvider.registerAthlete(
                              competitionId: competition.id,
                              userId: currentUser.id,
                            );
                            if (context.mounted) {
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Successfully registered as athlete!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(compProvider.errorMessage ?? 'Registration failed'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Register as Athlete',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Tickets will be available soon!',
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.colorScheme.outline),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Buy Spectator Ticket',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            if (competition.volunteerNeeds) {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) =>
                                    VolunteerApplicationBottomSheet(
                                      competition: competition,
                                    ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Thank you for your interest! Volunteer applications for ${competition.title} will open soon.',
                                  ),
                                  backgroundColor: theme.colorScheme.primary,
                                ),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.colorScheme.outline),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Apply as Volunteer',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (competition.status == 'completed') ...[
                    const SizedBox(height: 32),
                    _buildRankingsSection(theme, competition),
                  ],
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(List<String> tabs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tabs.map((tab) {
        final isSelected = _selectedRankingsFilter == tab;
        return ChoiceChip(
          label: Text(tab),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedRankingsFilter = tab;
              });
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildRankingsSection(ThemeData theme, Competition competition) {
    final List<String> tabs = ['All'];
    if (competition.rankingType == 'gender') {
      tabs.addAll(['Men', 'Women']);
    } else if (competition.rankingType == 'athlete_group') {
      final classes = _allResults
          .map((e) => e['competition_class'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      classes.sort();
      tabs.addAll(classes);
    }

    final filtered = _allResults.where((item) {
      final profile = item['profile'] as Map? ?? {};
      final sexVal = (profile['sex'] ?? profile['gender'] as String? ?? 'male').toString().toLowerCase();
      final compClass = item['competition_class'] as String? ?? '';

      if (_selectedRankingsFilter == 'All') return true;
      if (_selectedRankingsFilter == 'Men') return sexVal == 'male';
      if (_selectedRankingsFilter == 'Women') return sexVal == 'female';
      return compClass == _selectedRankingsFilter;
    }).toList();

    filtered.sort((a, b) {
      final scoreA = (a['total_score'] as num?)?.toDouble() ?? 0.0;
      final scoreB = (b['total_score'] as num?)?.toDouble() ?? 0.0;
      return scoreB.compareTo(scoreA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rankings & Results',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (competition.rankingType != 'open' && tabs.length > 1) ...[
          _buildFilterChips(tabs),
          const SizedBox(height: 16),
        ],
        if (_isLoadingResults)
          const Center(child: CircularProgressIndicator())
        else if (filtered.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Text('No results recorded matching this filter.'),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.symmetric(
                inside: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('Athlete', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('Division / Class', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                ...List.generate(filtered.length, (index) {
                  final item = filtered[index];
                  final profile = item['profile'] as Map? ?? {};
                  final athleteName = profile['full_name'] as String? ?? 'Unknown Athlete';
                  final username = profile['username'] as String? ?? '';
                  final compClass = item['competition_class'] as String? ?? '';
                  final totalScore = (item['total_score'] as num?)?.toDouble() ?? 0.0;

                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(athleteName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (username.isNotEmpty)
                              Text('@$username', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(compClass.isNotEmpty ? compClass : 'Open'),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text('${totalScore.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE94E1B))),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeroImage(BuildContext context, ThemeData theme) {
    final path = _competition?.titleImageUrl;
    if (path == null || path.trim().isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.fitness_center_outlined,
            size: 64,
            color: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    if (path.startsWith('http') || path.startsWith('https')) {
      return Image.network(path, fit: BoxFit.cover);
    } else if (path.startsWith('/')) {
      final apiBaseUrl = Provider.of<CompetitionProvider>(context, listen: false).competitionRepository.baseUrl;
      return Image.network(
        '$apiBaseUrl$path',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.fitness_center_outlined,
              size: 64,
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
            ),
          ),
        ),
      );
    } else {
      return Image.asset(path, fit: BoxFit.cover);
    }
  }

  Widget _buildQuickInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisciplineRow(ThemeData theme, String discipline) {
    String desc = '';
    switch (discipline.toLowerCase()) {
      case 'muscle up':
        desc = 'The athlete pulls their body up over the bar to full arm lock.';
        break;
      case 'pull up':
        desc = 'The athlete pulls their chin above the bar from a dead hang.';
        break;
      case 'dip':
        desc = 'The athlete lowers and presses their body on parallel bars.';
        break;
      case 'squat':
        desc =
            'The athlete squats below parallel with load on their shoulders.';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: theme.colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  discipline,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  desc,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VolunteerApplicationBottomSheet extends StatefulWidget {
  final Competition competition;

  const VolunteerApplicationBottomSheet({super.key, required this.competition});

  @override
  State<VolunteerApplicationBottomSheet> createState() =>
      _VolunteerApplicationBottomSheetState();
}

class _VolunteerApplicationBottomSheetState
    extends State<VolunteerApplicationBottomSheet> {
  final List<String> _selectedRoles = [];
  final Map<String, List<String>> _shiftAvailability =
      {}; // role -> list of shifts
  final Map<String, dynamic> _customFieldAnswers = {};
  bool _disclaimerAccepted = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final positions = widget.competition.volunteerPositions ?? [];
    for (var pos in positions) {
      _shiftAvailability[pos] = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    final positions = widget.competition.volunteerPositions ?? [];
    final hasDisclaimer =
        widget.competition.disclaimerType != null &&
        widget.competition.disclaimerType != 'none';

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Apply as Volunteer',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 1. Roles selection
            Text('Select Preferred Roles', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (positions.isEmpty)
              const Text('No volunteer roles defined for this competition.')
            else
              Wrap(
                spacing: 8,
                children: positions.map((pos) {
                  final isSelected = _selectedRoles.contains(pos);
                  return FilterChip(
                    label: Text(pos),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedRoles.add(pos);
                          if (!_shiftAvailability.containsKey(pos)) {
                            _shiftAvailability[pos] = [];
                          }
                        } else {
                          _selectedRoles.remove(pos);
                          _shiftAvailability.remove(pos);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            if (_selectedRoles.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Please select at least one role',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 16),

            // 2. Reorderable preference list
            if (_selectedRoles.isNotEmpty) ...[
              Text(
                'Rank Preference (Drag to Reorder)',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                height: 150,
                child: ReorderableListView(
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = _selectedRoles.removeAt(oldIndex);
                      _selectedRoles.insert(newIndex, item);
                    });
                  },
                  children: _selectedRoles.map((role) {
                    return ListTile(
                      key: ValueKey(role),
                      title: Text(role),
                      trailing: const Icon(Icons.drag_handle),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Shift Availability per selected role
              Text(
                'Select Shift Availability',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._selectedRoles.map((role) {
                final shifts =
                    (widget.competition.volunteerShifts != null &&
                        widget.competition.volunteerShifts![role] != null &&
                        widget.competition.volunteerShifts![role]!.isNotEmpty)
                    ? widget.competition.volunteerShifts![role]!
                    : ['Morning', 'Afternoon'];
                final selectedShifts = _shiftAvailability[role] ?? [];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: shifts.map((shift) {
                            final isSel = selectedShifts.contains(shift);
                            return FilterChip(
                              label: Text(shift),
                              selected: isSel,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _shiftAvailability[role] = [
                                      ...selectedShifts,
                                      shift,
                                    ];
                                  } else {
                                    _shiftAvailability[role] = selectedShifts
                                        .where((s) => s != shift)
                                        .toList();
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // 4. Custom fields
            if (widget.competition.customVolunteerFields != null &&
                widget.competition.customVolunteerFields!.isNotEmpty) ...[
              Text('Additional Questions', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...widget.competition.customVolunteerFields!.map((f) {
                final String name = f['name'] ?? '';
                final String type = f['type'] ?? 'text';

                if (type == 'boolean') {
                  final currentVal =
                      _customFieldAnswers[name] as bool? ?? false;
                  return CheckboxListTile(
                    title: Text(name),
                    value: currentVal,
                    onChanged: (val) {
                      setState(() {
                        _customFieldAnswers[name] = val ?? false;
                      });
                    },
                  );
                } else if (type == 'dropdown') {
                  final List<String> options = List<String>.from(
                    f['options'] ?? [],
                  ).toSet().toList();
                  final currentVal = _customFieldAnswers[name] as String?;
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: name),
                    initialValue: currentVal,
                    items: options
                        .map(
                          (opt) =>
                              DropdownMenuItem(value: opt, child: Text(opt)),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _customFieldAnswers[name] = val;
                      });
                    },
                  );
                } else {
                  return TextFormField(
                    decoration: InputDecoration(labelText: name),
                    keyboardType: type == 'number'
                        ? TextInputType.number
                        : TextInputType.text,
                    onChanged: (val) {
                      setState(() {
                        _customFieldAnswers[name] = val;
                      });
                    },
                  );
                }
              }),
              const SizedBox(height: 16),
            ],

            // 5. Disclaimer / Terms Checkbox
            if (hasDisclaimer) ...[
              Text('Disclaimer / Terms', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              (() {
                final text = widget.competition.disclaimerText;
                if (text == null) return const SizedBox();
                try {
                  final decoded = jsonDecode(text);
                  if (decoded is List) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: decoded.map<Widget>((item) {
                        final dText = (item['text'] ?? '').toString();
                        final dUrl = (item['url'] ?? '').toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (dText.isNotEmpty) Text(dText),
                              if (dUrl.isNotEmpty)
                                Text(
                                  'Link: $dUrl',
                                  style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }
                } catch (_) {}
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text),
                    if (widget.competition.disclaimerUrl != null)
                      Text('Link: ${widget.competition.disclaimerUrl}'),
                  ],
                );
              }()),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const Key('comp_disclaimer'),
                title: const Text(
                  'I accept the disclaimer and terms conditions',
                ),
                value: _disclaimerAccepted,
                onChanged: (val) {
                  setState(() {
                    _disclaimerAccepted = val ?? false;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_isSubmitting ||
                        _selectedRoles.isEmpty ||
                        (hasDisclaimer && !_disclaimerAccepted))
                    ? null
                    : () async {
                        setState(() {
                          _isSubmitting = true;
                        });
                        final userId =
                            authProvider.currentUserProfile?.id ?? 'user-123';
                        final success = await compProvider
                            .submitVolunteerApplication(
                              competitionId: widget.competition.id,
                              userId: userId,
                              preferredRoles: _selectedRoles,
                              shiftAvailability: _shiftAvailability,
                              customFieldAnswers: _customFieldAnswers,
                              disclaimerAccepted: _disclaimerAccepted,
                            );
                        if (!context.mounted) return;
                        setState(() {
                          _isSubmitting = false;
                        });
                        if (success) {
                          Navigator.of(context).pop(true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                compProvider.errorMessage ??
                                    'Submission failed',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Application'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
