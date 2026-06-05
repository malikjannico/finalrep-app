import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/competition.dart';
import '../models/association.dart';
import '../models/profile.dart';
import '../models/admin_config.dart';
import '../utils/image_url_resolver.dart';
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
  int _registeredAthleteCount = 0;
  int _registeredVolunteerCount = 0;
  bool _isLoadingCounts = false;

  Profile? _creatorProfile;
  bool _isLoadingCreator = false;

  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.competition != null) {
      _competition = widget.competition;
      _loadSpotsCounts();
      _loadCreatorAndAssociation();
      if (_competition!.status == 'completed') {
        _loadMeetResults();
      }
    } else if (widget.competitionId != null) {
      _loadCompetition().then((_) {
        _loadSpotsCounts();
        _loadCreatorAndAssociation();
        if (_competition != null && _competition!.status == 'completed') {
          _loadMeetResults();
        }
      });
    }
  }

  void _onScroll() {
    if (!mounted) return;
    final showTitle = _scrollController.hasClients && _scrollController.offset >= 250;
    if (showTitle != _showAppBarTitle) {
      setState(() {
        _showAppBarTitle = showTitle;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCreatorAndAssociation() async {
    if (_competition == null) return;
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);

    if (_competition!.associationId != null) {
      try {
        if (compProvider.associations.isEmpty) {
          await compProvider.fetchAssociations();
        }
      } catch (e) {
        debugPrint('Error fetching associations: $e');
      }
    }

    if (_competition!.creatorId != null) {
      setState(() {
        _isLoadingCreator = true;
      });
      try {
        final profile = await compProvider.profileRepository.getProfile(_competition!.creatorId!);
        if (mounted) {
          setState(() {
            _creatorProfile = profile;
          });
        }
      } catch (e) {
        debugPrint('Error fetching creator profile: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingCreator = false;
          });
        }
      }
    }
  }

  Future<void> _loadSpotsCounts() async {
    if (_competition == null) return;
    setState(() {
      _isLoadingCounts = true;
    });
    try {
      final provider = Provider.of<CompetitionProvider>(context, listen: false);
      final athleteIds = await provider.competitionRepository.getRegisteredAthleteIds(_competition!.id);
      final volunteerCount = await provider.competitionRepository.getVolunteerCount(_competition!.id);

      if (mounted) {
        setState(() {
          _registeredAthleteCount = athleteIds.length;
          _registeredVolunteerCount = volunteerCount;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _registeredAthleteCount = 0;
          _registeredVolunteerCount = 0;
        });
      }
      debugPrint('Error loading spot counts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCounts = false;
        });
      }
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

  void _shareCompetition() {
    if (_competition == null) return;
    const String appDomain = String.fromEnvironment(
      'APP_DOMAIN',
      defaultValue: 'app.final-rep.com',
    );
    final String url = kIsWeb
        ? '${Uri.base.origin}/competitions/${_competition!.id}'
        : 'https://$appDomain/competitions/${_competition!.id}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied to clipboard: $url'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  String formatCompetitionLocation(String location, String? city, String? country) {
    final parts = location.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.length < 3) return location;

    final name = parts[0];
    final displayCountry = country ?? parts.last;
    final displayCity = city ?? (parts.length >= 3 ? parts[parts.length - 3] : '');

    String street = '';
    String houseNumber = '';

    for (int i = 1; i < parts.length; i++) {
      final part = parts[i];
      if (part == displayCity || part == displayCountry || RegExp(r'^\d{5}$').hasMatch(part)) {
        continue;
      }
      if (RegExp(r'^\d+[a-zA-Z]?$').hasMatch(part)) {
        houseNumber = part;
      } else if (street.isEmpty && i < 4) {
        street = part;
      }
    }

    if (houseNumber.isEmpty) {
      for (int i = 1; i < parts.length; i++) {
        final part = parts[i];
        if (part == displayCity || part == displayCountry || RegExp(r'^\d{5}$').hasMatch(part)) continue;
        if (RegExp(r'\d').hasMatch(part)) {
          houseNumber = part;
          break;
        }
      }
    }

    if (street.isEmpty && parts.length > 1) {
      for (int i = 1; i < parts.length; i++) {
        final part = parts[i];
        if (part != houseNumber && part != displayCity && part != displayCountry && !RegExp(r'^\d{5}$').hasMatch(part)) {
          street = part;
          break;
        }
      }
    }

    if (street.isNotEmpty && houseNumber.isNotEmpty) {
      return '$name, $street $houseNumber, $displayCity, $displayCountry';
    } else if (street.isNotEmpty) {
      return '$name, $street, $displayCity, $displayCountry';
    } else {
      return '$name, $displayCity, $displayCountry';
    }
  }

  Widget _buildStatusBadge(BuildContext context, ThemeData theme, String status) {
    String text = status.toUpperCase();
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color textCol = theme.colorScheme.onSurfaceVariant;
    final normalized = status.toLowerCase().replaceAll('_', ' ');

    if (normalized == 'draft') {
      text = 'DRAFT';
      bg = theme.colorScheme.surfaceContainerHighest;
      textCol = theme.colorScheme.onSurfaceVariant;
    } else if (normalized == 'published') {
      text = 'PUBLISHED';
      bg = theme.colorScheme.secondaryContainer.withValues(alpha: 0.5);
      textCol = theme.colorScheme.onSecondaryContainer;
    } else if (normalized == 'registration started' || normalized == 'registration open') {
      text = 'REGISTRATION OPEN';
      bg = theme.colorScheme.primaryContainer;
      textCol = theme.colorScheme.onPrimaryContainer;
    } else if (normalized == 'registration closed' || normalized == 'registration completed') {
      text = 'REGISTRATION CLOSED';
      bg = theme.colorScheme.surfaceContainerHighest;
      textCol = theme.colorScheme.onSurfaceVariant;
    } else if (normalized == 'payment started' || normalized == 'payment open') {
      text = 'PAYMENT OPEN';
      bg = theme.colorScheme.secondaryContainer;
      textCol = theme.colorScheme.onSecondaryContainer;
    } else if (normalized == 'payment completed') {
      text = 'PAYMENT COMPLETED';
      bg = theme.colorScheme.surfaceContainerHighest;
      textCol = theme.colorScheme.onSurfaceVariant;
    } else if (normalized == 'competition started' || normalized == 'ongoing') {
      text = 'ONGOING';
      bg = theme.colorScheme.tertiaryContainer;
      textCol = theme.colorScheme.onTertiaryContainer;
    } else if (normalized == 'competition completed' || normalized == 'completed') {
      text = 'COMPLETED';
      bg = theme.colorScheme.surfaceContainerHighest;
      textCol = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textCol,
          fontWeight: FontWeight.bold,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSpotsProgress(ThemeData theme, Competition competition) {
    if (_isLoadingCounts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final maxAthletes = competition.maxAthletes;
    final maxVolunteers = competition.maxVolunteers;
    final hasAthleteLimit = maxAthletes != null && maxAthletes > 0;
    final hasVolunteerLimit = maxVolunteers != null && maxVolunteers > 0;

    final athleteFraction = hasAthleteLimit
        ? (_registeredAthleteCount / maxAthletes).clamp(0.0, 1.0)
        : 0.0;
    final volunteerFraction = hasVolunteerLimit
        ? (_registeredVolunteerCount / maxVolunteers).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Participation & Spots',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(16),
          ),
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people_outline, color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Athlete Spots',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          hasAthleteLimit
                              ? '$_registeredAthleteCount / $maxAthletes'
                              : '$_registeredAthleteCount registered',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (hasAthleteLimit) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: athleteFraction,
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ],
                ),
                if (competition.volunteerNeeds) ...[
                  const Divider(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.handshake_outlined, color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Volunteer Spots',
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Text(
                            hasVolunteerLimit
                                ? '$_registeredVolunteerCount / $maxVolunteers'
                                : '$_registeredVolunteerCount applied',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (hasVolunteerLimit) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: volunteerFraction,
                            minHeight: 8,
                            backgroundColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('MMM dd, yyyy - HH:mm').format(dt);
  }

  Widget _buildPeriodRow(
    ThemeData theme, {
    required String title,
    required DateTime start,
    required DateTime end,
    required String status,
    required Color statusColor,
    required Color statusBg,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.surface,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDateTime(start)}   to   ${_formatDateTime(end)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelinePeriods(ThemeData theme, Competition competition) {
    final now = DateTime.now();

    String regStatus = 'UPCOMING';
    Color regColor = Colors.orange;
    Color regBg = Colors.orange.withValues(alpha: 0.1);
    if (now.isAfter(competition.registrationStart) && now.isBefore(competition.registrationEnd)) {
      regStatus = 'ONGOING';
      regColor = Colors.green;
      regBg = Colors.green.withValues(alpha: 0.1);
    } else if (now.isAfter(competition.registrationEnd)) {
      regStatus = 'CLOSED';
      regColor = Colors.red;
      regBg = Colors.red.withValues(alpha: 0.1);
    }

    String payStatus = 'UPCOMING';
    Color payColor = Colors.orange;
    Color payBg = Colors.orange.withValues(alpha: 0.1);
    final hasPayment = competition.requiresFees && competition.paymentStart != null && competition.paymentEnd != null;
    if (hasPayment) {
      if (now.isAfter(competition.paymentStart!) && now.isBefore(competition.paymentEnd!)) {
        payStatus = 'ONGOING';
        payColor = Colors.green;
        payBg = Colors.green.withValues(alpha: 0.1);
      } else if (now.isAfter(competition.paymentEnd!)) {
        payStatus = 'CLOSED';
        payColor = Colors.red;
        payBg = Colors.red.withValues(alpha: 0.1);
      }
    }

    String compStatus = 'UPCOMING';
    Color compColor = Colors.orange;
    Color compBg = Colors.orange.withValues(alpha: 0.1);
    if (now.isAfter(competition.startDate) && now.isBefore(competition.endDate)) {
      compStatus = 'ONGOING';
      compColor = Colors.green;
      compBg = Colors.green.withValues(alpha: 0.1);
    } else if (now.isAfter(competition.endDate)) {
      compStatus = 'COMPLETED';
      compColor = theme.colorScheme.onSurfaceVariant;
      compBg = theme.colorScheme.surfaceContainerHighest;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeline & Periods',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(16),
          ),
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              children: [
                Positioned(
                  left: 5,
                  top: 12,
                  bottom: 12,
                  width: 2,
                  child: Container(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                Column(
                  children: [
                    _buildPeriodRow(
                      theme,
                      title: 'Registration Period',
                      start: competition.registrationStart,
                      end: competition.registrationEnd,
                      status: regStatus,
                      statusColor: regColor,
                      statusBg: regBg,
                    ),
                    if (hasPayment) ...[
                      const SizedBox(height: 12),
                      _buildPeriodRow(
                        theme,
                        title: 'Payment Period',
                        start: competition.paymentStart!,
                        end: competition.paymentEnd!,
                        status: payStatus,
                        statusColor: payColor,
                        statusBg: payBg,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildPeriodRow(
                      theme,
                      title: 'Competition Period',
                      start: competition.startDate,
                      end: competition.endDate,
                      status: compStatus,
                      statusColor: compColor,
                      statusBg: compBg,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner(ThemeData theme, Competition competition) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isMobile = !isDesktop;
    final hideAppBar = isDesktop;
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
        margin: isMobile
            ? EdgeInsets.zero
            : EdgeInsets.only(
                left: 24,
                right: 24,
                top: hideAppBar
                    ? 16.0
                    : (16.0 + MediaQuery.of(context).padding.top + kToolbarHeight),
              ),
        child: AspectRatio(
          aspectRatio: 3.0,
          child: ClipRRect(
            borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(16),
            child: _buildHeroImage(context, theme),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetailSections(
    BuildContext context,
    Competition competition,
    ThemeData theme,
    Association? association,
  ) {
    final sport = competition.sportType;
    final formatName = competition.sportSubtype;
    final compProvider = Provider.of<CompetitionProvider>(context);
    List<String> abbrList = [];
    if (compProvider.sportConfig != null) {
      final links = compProvider.sportConfig!.links.where((l) =>
        l.sportName.toLowerCase() == sport.toLowerCase() &&
        l.formatName.toLowerCase() == formatName.toLowerCase()
      ).toList();
      final disciplines = compProvider.sportConfig!.disciplines;
      for (final link in links) {
        final d = disciplines.firstWhere(
          (dep) => dep.name.toLowerCase() == link.disciplineName.toLowerCase(),
          orElse: () => DisciplineDefinition(name: link.disciplineName),
        );
        if (d.abbreviation != null && d.abbreviation!.isNotEmpty) {
          abbrList.add(d.abbreviation!);
        }
      }
    }
    final fromDateStr = DateFormat('MMM dd, yyyy - HH:mm').format(competition.startDate);
    final toDateStr = DateFormat('MMM dd, yyyy - HH:mm').format(competition.endDate);

    return [
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildStatusBadge(context, theme, competition.status),
          if (competition.isPartOfGroup)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                competition.compGroupName!.toUpperCase(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),

      Text(
        competition.title,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 16),

      Row(
        children: [
          _buildQuickInfoCard(
            context,
            icon: Icons.fitness_center_outlined,
            title: 'Sport & Format',
            subtitle: '$sport, $formatName${abbrList.isNotEmpty ? ' (${abbrList.join(', ')})' : ''}',
          ),
        ],
      ),
      const SizedBox(height: 12),

      Row(
        children: [
          _buildQuickInfoCard(
            context,
            icon: Icons.calendar_month_outlined,
            title: 'Date & Time',
            subtitle: '$fromDateStr - $toDateStr',
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
            subtitle: formatCompetitionLocation(competition.location, competition.city, competition.country),
          ),
        ],
      ),
      const SizedBox(height: 24),

      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileInfoCard(
              context,
              title: 'Created By',
              name: _creatorProfile?.fullName ?? 'Loading Creator...',
              subtitle: _creatorProfile?.username != null ? '@${_creatorProfile!.username}' : null,
              avatar: CircleAvatar(
                radius: 12,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: (_creatorProfile?.profilePictureUrl != null &&
                        _creatorProfile!.profilePictureUrl!.isNotEmpty)
                    ? NetworkImage(ImageUrlResolver.resolve(context, _creatorProfile!.profilePictureUrl))
                    : null,
                child: (_creatorProfile?.profilePictureUrl == null ||
                        _creatorProfile!.profilePictureUrl!.isEmpty)
                    ? Text(
                        _creatorProfile?.fullName.isNotEmpty == true
                            ? _creatorProfile!.fullName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 8,
                        ),
                      )
                    : null,
              ),
            ),
            if (association != null) ...[
              const SizedBox(width: 12),
              _buildProfileInfoCard(
                context,
                title: 'Hosted By',
                name: association.name,
                subtitle: '${association.scope.substring(0, 1).toUpperCase()}${association.scope.substring(1).toLowerCase()} Association',
                avatar: CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: (association.profilePictureUrl != null &&
                          association.profilePictureUrl!.isNotEmpty)
                      ? NetworkImage(ImageUrlResolver.resolve(context, association.profilePictureUrl))
                      : null,
                  child: (association.profilePictureUrl == null ||
                          association.profilePictureUrl!.isEmpty)
                      ? Text(
                          association.name.isNotEmpty == true
                              ? association.name[0].toUpperCase()
                              : 'A',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 8,
                          ),
                        )
                      : null,
                ),
                onTap: () {
                  context.push('/associations/${association.id}');
                },
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 24),

      ElevatedButton.icon(
        key: const Key('share_competition_button'),
        onPressed: _shareCompetition,
        icon: const Icon(Icons.share, size: 18),
        label: const Text('SHARE COMPETITION'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(40),
          shape: const StadiumBorder(),
        ),
      ),
      const SizedBox(height: 24),

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

      _buildTimelinePeriods(theme, competition),
      const SizedBox(height: 24),

      _buildSpotsProgress(theme, competition),
      const SizedBox(height: 32),

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
    ];
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
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isMobile = !isDesktop;

    Association? association;
    if (competition.associationId != null) {
      for (final a in provider.associations) {
        if (a.id == competition.associationId) {
          association = a;
          break;
        }
      }
    }

    final hideAppBar = isDesktop;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBodyBehindAppBar: !hideAppBar,
      appBar: hideAppBar
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: _showAppBarTitle
                  ? theme.colorScheme.surface
                  : Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _showAppBarTitle
                        ? Colors.transparent
                        : Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: _showAppBarTitle
                        ? theme.colorScheme.onSurface
                        : Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: AnimatedOpacity(
                opacity: _showAppBarTitle ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  competition.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBanner(theme, competition),
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: EdgeInsets.only(
                  left: isMobile ? 16.0 : 24.0,
                  right: isMobile ? 16.0 : 24.0,
                  bottom: 24.0,
                  top: isMobile ? 16.0 : 0.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildDetailSections(
                    context,
                    competition,
                    theme,
                    association,
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildProfileInfoCard(
    BuildContext context, {
    required String title,
    required String name,
    String? subtitle,
    Widget? avatar,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final cardContent = Container(
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
          if (avatar != null) ...[
            avatar,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                  name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Expanded(
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: cardContent,
            )
          : cardContent,
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
