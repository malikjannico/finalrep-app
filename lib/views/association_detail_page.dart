import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/association.dart';
import '../models/association_member.dart';
import '../models/competition_group.dart';
import '../models/athlete_group.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import 'association_management_page.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'competition_detail_page.dart';
import 'competition_library_page.dart';
import 'profile_page.dart';
import '../models/competition.dart';
import '../models/profile.dart';
import '../utils/image_url_resolver.dart';
import '../widgets/competition_card.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AssociationDetailPage extends StatefulWidget {
  final String associationId;
  final bool isInline;

  const AssociationDetailPage({
    super.key,
    required this.associationId,
    this.isInline = false,
  });

  @override
  State<AssociationDetailPage> createState() => _AssociationDetailPageState();
}



class _AssociationDetailPageState extends State<AssociationDetailPage> {
  Association? _association;
  List<AssociationMember> _members = [];
  List<CompetitionGroup> _compGroups = [];
  List<AthleteGroup> _athleteGroups = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;

  List<Competition> _upcomingCompetitions = [];
  List<Competition> _completedCompetitions = [];
  List<Association> _subAssociations = [];
  Association? _parentAssociation;
  int _selectedTabIndex = 0;
  Map<String, Profile> _memberProfiles = {};
  final Set<String> _collapsedSections = {};

  String _memberCountText(int count) {
    return '$count ${count == 1 ? "Member" : "Members"}';
  }

  String _assocCountText(int count) {
    return '$count ${count == 1 ? "Association" : "Associations"}';
  }

  final Map<String, List<String>> sportToFormatsMapping = {
    'Streetlifting': ['Modern', 'Classic', 'Multilift'],
    'Powerlifting': ['3 Lift', 'Bench Only', 'Deadlift Only', 'Push Pull'],
    'Weightlifting': ['Snatch', 'Clean & Jerk', 'Biathlon'],
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
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

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    try {
      final assoc = await compProvider.getAssociationDetails(widget.associationId);
      if (assoc != null) {
        final membersList = await compProvider.getAssociationMembers(widget.associationId);
        final compGroupsList = await compProvider.getCompetitionGroups(widget.associationId);
        final athleteGroupsList = await compProvider.getAthleteGroups(widget.associationId);

        // Fetch competitions linked to this association
        final upcomingList = await compProvider.competitionRepository.getUpcomingCompetitions(status: 'upcoming');
        final completedList = await compProvider.competitionRepository.getUpcomingCompetitions(status: 'completed');

        // Fetch all associations to resolve sub-associations and parent association
        if (compProvider.associations.isEmpty) {
          await compProvider.fetchAssociations();
        }

        final allAssocs = compProvider.associations;
        final subList = allAssocs.where((a) => a.parentAssociationId == widget.associationId).toList();
        
        Association? parentAssoc;
        if (assoc.parentAssociationId != null) {
          try {
            parentAssoc = allAssocs.firstWhere((a) => a.id == assoc.parentAssociationId);
          } catch (_) {
            parentAssoc = null;
          }
        }

        // Fetch sports config if needed
        if (compProvider.sportConfig == null) {
          await compProvider.loadSportsConfig();
        }

        // Fetch profiles for each member
        final Map<String, Profile> profilesMap = {};
        final profileRepo = compProvider.profileRepository;
        await Future.wait(
          membersList.map((member) async {
            try {
              final p = await profileRepo.getProfile(member.userId);
              if (p != null) {
                profilesMap[member.userId] = p;
              }
            } catch (e) {
              debugPrint('Error loading profile for member ${member.userId}: $e');
            }
          }),
        );

        setState(() {
          _association = assoc;
          _members = membersList;
          _compGroups = compGroupsList;
          _athleteGroups = athleteGroupsList;
          _upcomingCompetitions = upcomingList.where((c) => c.associationId == widget.associationId).toList();
          _completedCompetitions = completedList.where((c) => c.associationId == widget.associationId).toList();
          _subAssociations = subList;
          _parentAssociation = parentAssoc;
          _memberProfiles = profilesMap;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load details: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _canManage(String? currentUserId, bool isAdmin) {
    if (isAdmin) return true;
    if (currentUserId == null || _association == null) return false;
    if (_association!.ownerId == currentUserId) return true;

    return _members.any(
      (member) =>
          member.userId == currentUserId &&
          (member.role == 'owner' || member.role == 'editor'),
    );
  }

  Future<void> _launchURL(String urlString) async {
    try {
      String cleanUrl = urlString.trim();
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      final Uri uri = Uri.parse(cleanUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $cleanUrl');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  String _cleanSocialDisplay(String key, String value) {
    if (value.trim().isEmpty) return '';
    try {
      if (value.startsWith('http://') || value.startsWith('https://')) {
        final uri = Uri.parse(value.trim());
        if (key.toLowerCase() == 'website') {
          return uri.host.replaceFirst('www.', '');
        } else {
          if (uri.pathSegments.isNotEmpty) {
            final lastSegment = uri.pathSegments.lastWhere((seg) => seg.isNotEmpty, orElse: () => '');
            if (lastSegment.isNotEmpty) {
              if (lastSegment.startsWith('@')) {
                return lastSegment;
              }
              return '@$lastSegment';
            }
          }
        }
      }
    } catch (_) {}
    if (key.toLowerCase() == 'website') {
      return value.replaceFirst('www.', '');
    } else {
      if (!value.startsWith('@')) {
        return '@$value';
      }
      return value;
    }
  }

  String _getSocialUrl(String key, String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final handle = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    switch (key.toLowerCase()) {
      case 'instagram':
        return 'https://instagram.com/$handle';
      case 'youtube':
        return 'https://youtube.com/$handle';
      case 'facebook':
        return 'https://facebook.com/$handle';
      case 'twitch':
        return 'https://twitch.tv/$handle';
      case 'tiktok':
        return 'https://tiktok.com/@$handle';
      case 'twitter':
      case 'x':
        return 'https://x.com/$handle';
      default:
        return 'https://$trimmed';
    }
  }

  void _shareAssociation() {
    if (_association == null) return;
    const String appDomain = String.fromEnvironment(
      'APP_DOMAIN',
      defaultValue: 'app.final-rep.com',
    );
    final String url = kIsWeb
        ? '${Uri.base.origin}/associations/${_association!.id}'
        : 'https://$appDomain/associations/${_association!.id}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied to clipboard: $url'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUserProfile;
    final isAdmin = authProvider.isAdmin;
    final hasAssocCreatorPrivilege = currentUser != null && (currentUser.isAssociationCreator || isAdmin);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isMobile = !isDesktop;
    final hideAppBar = widget.isInline && isDesktop;

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE94E1B)),
          ),
        ),
      );
    }

    if (_association == null) {
      return const Scaffold(
        body: Center(
          child: Text('Could not find the requested association.'),
        ),
      );
    }

    final assoc = _association!;
    final isAuthorizedToManage = _canManage(currentUser?.id, isAdmin);
    final bannerUrl = ImageUrlResolver.resolve(context, assoc.bannerUrl);
    final logoUrl = ImageUrlResolver.resolve(context, assoc.profilePictureUrl);
    final initials = assoc.name.isNotEmpty ? assoc.name[0].toUpperCase() : 'A';

    // Group formats by sport
    final groupedFormats = <String, List<String>>{};
    final assignedFormats = <String>{};

    for (final sport in assoc.supportedSports) {
      final formatsForSport = sportToFormatsMapping[sport] ?? [];
      final matches = assoc.supportedFormats.where((f) => formatsForSport.contains(f)).toList();
      if (matches.isNotEmpty) {
        groupedFormats[sport] = matches;
        assignedFormats.addAll(matches);
      }
    }

    final otherFormats = assoc.supportedFormats.where((f) => !assignedFormats.contains(f)).toList();
    if (otherFormats.isNotEmpty) {
      groupedFormats['Other'] = otherFormats;
    }

    // Determine scope badge colors
    Color scopeBg;
    Color scopeText;
    switch (assoc.scope.toLowerCase()) {
      case 'global':
        scopeBg = const Color(0xFFFFB300).withValues(alpha: 0.15);
        scopeText = const Color(0xFFFF8F00);
        break;
      case 'continental':
      case 'area':
        scopeBg = Colors.blue.withValues(alpha: 0.15);
        scopeText = Colors.blue.shade700;
        break;
      case 'national':
        scopeBg = Colors.green.withValues(alpha: 0.15);
        scopeText = Colors.green.shade700;
        break;
      case 'local':
      default:
        scopeBg = Colors.purple.withValues(alpha: 0.15);
        scopeText = Colors.purple.shade700;
        break;
    }

    // Unify website and social links
    final List<MapEntry<String, String>> socialLinks = [];
    if (assoc.website != null && assoc.website!.isNotEmpty) {
      socialLinks.add(MapEntry('website', assoc.website!));
    }
    socialLinks.addAll(assoc.socialChannels.entries.where((e) => e.value.trim().isNotEmpty));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
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
              leading: !widget.isInline
                  ? IconButton(
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
                    )
                  : null,
              title: AnimatedOpacity(
                opacity: _showAppBarTitle ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  assoc.name,
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
            _buildBanner(theme, bannerUrl),
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: EdgeInsets.only(
                  left: isMobile ? 16.0 : 24.0,
                  right: isMobile ? 16.0 : 24.0,
                  bottom: 24.0,
                  top: 0.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overlapping Avatar Logo
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          height: isMobile ? 45 : 40,
                          width: isMobile ? 95 : 90,
                        ),
                        Positioned(
                          top: isMobile ? -45 : -40,
                          left: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 4,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: isMobile ? 45 : 40,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              backgroundImage: logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                              child: logoUrl.isEmpty
                                  ? Text(
                                      initials,
                                      style: TextStyle(
                                        color: theme.colorScheme.onPrimaryContainer,
                                        fontSize: isMobile ? 32 : 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 8 : 12),

                    // Name of Association
                    Text(
                      assoc.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Scope & Territory Details
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: scopeBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            assoc.scope.toUpperCase(),
                            style: TextStyle(
                              color: scopeText,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (assoc.scope.toLowerCase() != 'global')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              (assoc.areaName ?? assoc.country ?? 'Unknown').toUpperCase(),
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Description text directly
                    Text(
                      assoc.description.isEmpty
                          ? 'No detailed description available for this association.'
                          : assoc.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),

                    // Website & Social Channels Section
                    if (socialLinks.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: socialLinks.map((entry) {
                          final name = entry.key;
                          final handle = entry.value;
                          dynamic iconData;
                          switch (name.toLowerCase()) {
                            case 'instagram':
                              iconData = FontAwesomeIcons.instagram;
                              break;
                            case 'twitter':
                            case 'x':
                              iconData = FontAwesomeIcons.xTwitter;
                              break;
                            case 'youtube':
                              iconData = FontAwesomeIcons.youtube;
                              break;
                            case 'tiktok':
                              iconData = FontAwesomeIcons.tiktok;
                              break;
                            case 'facebook':
                              iconData = FontAwesomeIcons.facebook;
                              break;
                            case 'twitch':
                              iconData = FontAwesomeIcons.twitch;
                              break;
                            case 'website':
                            default:
                              iconData = FontAwesomeIcons.globe;
                          }
                          final displayText = _cleanSocialDisplay(name, handle);
                          final url = _getSocialUrl(name, handle);

                          return ActionChip(
                            avatar: FaIcon(iconData as FaIconData?, size: 16, color: theme.colorScheme.primary),
                            label: Text(displayText),
                            onPressed: () => _launchURL(url),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // SHARE / MANAGE Buttons Row / Column
                    const SizedBox(height: 20),
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (isAuthorizedToManage) ...[
                                ElevatedButton.icon(
                                  key: const Key('manage_association_button'),
                                  onPressed: () async {
                                    context.go('/management/associations/${assoc.id}');
                                  },
                                  icon: const Icon(Icons.settings, size: 18),
                                  label: const Text('MANAGE ASSOCIATION'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.secondary,
                                    foregroundColor: theme.colorScheme.onSecondary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              ElevatedButton.icon(
                                key: const Key('share_association_button'),
                                onPressed: _shareAssociation,
                                icon: const Icon(Icons.share, size: 18),
                                label: const Text('SHARE ASSOCIATION'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              if (isAuthorizedToManage) ...[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    key: const Key('manage_association_button'),
                                    onPressed: () async {
                                      context.go('/management/associations/${assoc.id}');
                                    },
                                    icon: const Icon(Icons.settings, size: 18),
                                    label: const Text('MANAGE ASSOCIATION'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.secondary,
                                      foregroundColor: theme.colorScheme.onSecondary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: ElevatedButton.icon(
                                  key: const Key('share_association_button'),
                                  onPressed: _shareAssociation,
                                  icon: const Icon(Icons.share, size: 18),
                                  label: const Text('SHARE ASSOCIATION'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: theme.colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                    const Divider(height: 32),
                    _buildTabBar(theme),
                    const SizedBox(height: 16),
                    _buildActiveTabContent(theme),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),);
  }

  Widget _buildTabBar(ThemeData theme) {
    return TabBar(
      onTap: (index) {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      indicatorColor: theme.colorScheme.primary,
      labelColor: theme.colorScheme.primary,
      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
      tabs: const [
        Tab(text: 'Competitions'),
        Tab(text: 'Sports'),
        Tab(text: 'Network'),
        Tab(text: 'Team'),
      ],
    );
  }

  Widget _buildActiveTabContent(ThemeData theme) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildCompetitionsTabContent(theme);
      case 1:
        return _buildSportsTabContent(theme);
      case 2:
        return _buildNetworkTabContent(theme);
      case 3:
        return _buildTeamTabContent(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCompetitionsTabContent(ThemeData theme) {
    final Map<String, List<Competition>> upcomingGroups = {};
    for (final c in _upcomingCompetitions) {
      final groupName = c.compGroupName ?? 'Independent Competitions';
      upcomingGroups.putIfAbsent(groupName, () => []).add(c);
    }

    final Map<String, List<Competition>> completedGroups = {};
    for (final c in _completedCompetitions) {
      final groupName = c.compGroupName ?? 'Independent Competitions';
      completedGroups.putIfAbsent(groupName, () => []).add(c);
    }

    if (_upcomingCompetitions.isEmpty && _completedCompetitions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            'No competitions available for this association.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_upcomingCompetitions.isNotEmpty) ...[
          Text(
            'UPCOMING COMPETITIONS',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...upcomingGroups.entries.map((entry) => _buildCompetitionGroupGrid(entry.key, entry.value, theme)),
        ],
        if (_completedCompetitions.isNotEmpty) ...[
          if (_upcomingCompetitions.isNotEmpty) const SizedBox(height: 24),
          Text(
            'COMPLETED COMPETITIONS',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...completedGroups.entries.map((entry) => _buildCompetitionGroupGrid(entry.key, entry.value, theme)),
        ],
      ],
    );
  }

  Widget _buildCompetitionGroupGrid(String groupName, List<Competition> list, ThemeData theme) {
    final displayList = list.take(5).toList();
    final hasMore = list.length > 5;
    int crossAxisCount = 1;
    final width = MediaQuery.of(context).size.width;
    if (width >= 900) {
      crossAxisCount = 3;
    } else if (width >= 600) {
      crossAxisCount = 2;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            groupName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 310,
          ),
          itemCount: displayList.length,
          itemBuilder: (context, index) {
            return CompetitionCard(competition: displayList[index]);
          },
        ),
        if (hasMore) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/competitions'),
                    builder: (_) => const CompetitionLibraryPage(),
                  ),
                );
              },
              child: const Text('Show More'),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  List<String> getDisciplinesForFormat(String sport, String format) {
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final links = compProvider.sportConfig?.links;
    if (links != null && links.isNotEmpty) {
      final matches = links
          .where((link) =>
              link.sportName.toLowerCase() == sport.toLowerCase() &&
              link.formatName.toLowerCase() == format.toLowerCase())
          .map((link) => link.disciplineName)
          .toList();
      if (matches.isNotEmpty) return matches;
    }

    // Fallbacks
    if (sport.toLowerCase() == 'streetlifting') {
      if (format.toLowerCase() == 'modern') {
        return ['Muscle Up', 'Pull Up', 'Dip', 'Squat'];
      } else if (format.toLowerCase() == 'classic') {
        return ['Pull Up', 'Dip'];
      } else if (format.toLowerCase() == 'multilift') {
        return ['Pull Up', 'Dip'];
      }
    } else if (sport.toLowerCase() == 'powerlifting') {
      if (format.toLowerCase() == '3 lift') {
        return ['Squat', 'Bench Press', 'Deadlift'];
      } else if (format.toLowerCase() == 'bench only') {
        return ['Bench Press'];
      } else if (format.toLowerCase() == 'deadlift only') {
        return ['Deadlift'];
      } else if (format.toLowerCase() == 'push pull') {
        return ['Bench Press', 'Deadlift'];
      }
    } else if (sport.toLowerCase() == 'weightlifting') {
      if (format.toLowerCase() == 'snatch') {
        return ['Snatch'];
      } else if (format.toLowerCase() == 'clean & jerk') {
        return ['Clean & Jerk'];
      } else if (format.toLowerCase() == 'biathlon') {
        return ['Snatch', 'Clean & Jerk'];
      }
    }
    return [];
  }


  Widget _buildSectionHeader({
    required String title,
    required String? countText,
    required bool isExpanded,
    required VoidCallback onToggle,
    double paddingLeft = 0.0,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      margin: EdgeInsets.only(left: paddingLeft, bottom: 8.0),
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
          child: Row(
            children: [
              Icon(
                isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (countText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    countText,
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRulebookCard(String sport, String url, ThemeData theme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Icon(
          Icons.book,
          color: theme.colorScheme.primary,
        ),
        title: const Text('Rulebook'),
        subtitle: Text(
          url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => _launchURL(url),
      ),
    );
  }

  Widget _buildSportsTabContent(ThemeData theme) {
    final assoc = _association!;
    if (assoc.supportedSports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            'No sports configured for this association.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Group formats by sport
    final groupedFormats = <String, List<String>>{};
    final assignedFormats = <String>{};

    for (final sport in assoc.supportedSports) {
      final formatsForSport = sportToFormatsMapping[sport] ?? [];
      final matches = assoc.supportedFormats.where((f) => formatsForSport.contains(f)).toList();
      if (matches.isNotEmpty) {
        groupedFormats[sport] = matches;
        assignedFormats.addAll(matches);
      }
    }

    final otherFormats = assoc.supportedFormats.where((f) => !assignedFormats.contains(f)).toList();
    if (otherFormats.isNotEmpty) {
      groupedFormats['Other'] = otherFormats;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: assoc.supportedSports.map((sport) {
        final rulebookUrl = assoc.rulebooks[sport];
        final formats = groupedFormats[sport] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sport.toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (rulebookUrl != null && rulebookUrl.isNotEmpty)
              _buildRulebookCard(sport, rulebookUrl, theme),
            if (formats.isNotEmpty) ...[
              Text(
                'Formats & Disciplines',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ...formats.map((format) {
                final disciplines = getDisciplinesForFormat(sport, format);
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          format,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (disciplines.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: disciplines.map((discipline) {
                              return Chip(
                                label: Text(discipline),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                                backgroundColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                side: BorderSide.none,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildNetworkAssociationRow(Association assoc, ThemeData theme, {double leftMargin = 0.0}) {
    Color scopeBg;
    Color scopeText;
    switch (assoc.scope.toLowerCase()) {
      case 'global':
        scopeBg = const Color(0xFFFFB300).withValues(alpha: 0.15);
        scopeText = const Color(0xFFFF8F00);
        break;
      case 'continental':
      case 'area':
        scopeBg = Colors.blue.withValues(alpha: 0.15);
        scopeText = Colors.blue.shade700;
        break;
      case 'national':
        scopeBg = Colors.green.withValues(alpha: 0.15);
        scopeText = Colors.green.shade700;
        break;
      case 'local':
      default:
        scopeBg = Colors.purple.withValues(alpha: 0.15);
        scopeText = Colors.purple.shade700;
        break;
    }

    final territory = assoc.scope.toLowerCase() != 'global'
        ? (assoc.areaName ?? assoc.country)
        : null;
    final showTerritory = territory != null && territory.isNotEmpty;
    final logoUrl = ImageUrlResolver.resolve(context, assoc.profilePictureUrl);

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(left: leftMargin, bottom: 8),
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          try {
            context.push('/associations/${assoc.id}');
          } catch (_) {
            Navigator.of(context).push(
              MaterialPageRoute(
                settings: RouteSettings(name: '/associations/${assoc.id}'),
                builder: (_) => AssociationDetailPage(associationId: assoc.id),
              ),
            );
          }
        },
        child: Container(
          height: 72,
          alignment: Alignment.center,
          child: ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
            child: logoUrl.isEmpty
                ? Text(
                    assoc.name.isNotEmpty ? assoc.name[0].toUpperCase() : 'A',
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                  )
                : null,
          ),
          title: Text(assoc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showTerritory) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    territory.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scopeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  assoc.scope.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scopeText,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildNetworkTabContent(ThemeData theme) {
    if (_parentAssociation == null && _subAssociations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            'No sub-associations or parent associations linked.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final Map<String, List<Association>> groupedSubs = {};
    for (final sub in _subAssociations) {
      final sc = sub.scope.toLowerCase();
      groupedSubs.putIfAbsent(sc, () => []).add(sub);
    }

    final parentExpanded = !_collapsedSections.contains('network/parent');
    final subsExpanded = !_collapsedSections.contains('network/subs');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_parentAssociation != null) ...[
          _buildSectionHeader(
            title: 'Parent Association',
            countText: _assocCountText(1),
            isExpanded: parentExpanded,
            onToggle: () => setState(() {
              if (parentExpanded) {
                _collapsedSections.add('network/parent');
              } else {
                _collapsedSections.remove('network/parent');
              }
            }),
          ),
          const SizedBox(height: 8),
          if (parentExpanded) ...[
            _buildNetworkAssociationRow(_parentAssociation!, theme),
            const SizedBox(height: 16),
          ],
        ],
        if (_subAssociations.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Sub-Associations',
            countText: _assocCountText(_subAssociations.length),
            isExpanded: subsExpanded,
            onToggle: () => setState(() {
              if (subsExpanded) {
                _collapsedSections.add('network/subs');
              } else {
                _collapsedSections.remove('network/subs');
              }
            }),
          ),
          const SizedBox(height: 8),
          if (subsExpanded)
            ...groupedSubs.entries.map((entry) {
              final scopeName = entry.key;
              final list = entry.value;
              final subSectionKey = 'network/subs/$scopeName';
              final subSectionExpanded = !_collapsedSections.contains(subSectionKey);
              final capitalizedScope = scopeName.isEmpty
                  ? ''
                  : '${scopeName[0].toUpperCase()}${scopeName.substring(1).toLowerCase()}';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    title: capitalizedScope,
                    countText: _assocCountText(list.length),
                    isExpanded: subSectionExpanded,
                    onToggle: () => setState(() {
                      if (subSectionExpanded) {
                        _collapsedSections.add(subSectionKey);
                      } else {
                        _collapsedSections.remove(subSectionKey);
                      }
                    }),
                    paddingLeft: 16.0,
                  ),
                  const SizedBox(height: 8),
                  if (subSectionExpanded) ...[
                    ...list.map((sub) => _buildNetworkAssociationRow(sub, theme, leftMargin: 16.0)),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            }),
        ],
      ],
    );
  }

  Widget _buildTeamTabContent(ThemeData theme) {
    if (_members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            'No members found for this association.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final Map<String, List<AssociationMember>> groupedMembers = {};
    for (final member in _members) {
      final role = member.role.toLowerCase();
      groupedMembers.putIfAbsent(role, () => []).add(member);
    }

    final rolesOrder = ['owner', 'editor'];
    final sortedRoles = groupedMembers.keys.toList()
      ..sort((a, b) {
        final idxA = rolesOrder.indexOf(a);
        final idxB = rolesOrder.indexOf(b);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(sortedRoles.length, (index) {
        final role = sortedRoles[index];
        final list = groupedMembers[role]!;
        final sectionKey = 'team/$role';
        final isExpanded = !_collapsedSections.contains(sectionKey);
        final roleDisplay = (role == 'owner' ? 'Owner' : (role == 'editor' ? 'Editors' : '${role[0].toUpperCase()}${role.substring(1)}s'));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 16),
            _buildSectionHeader(
              title: roleDisplay,
              countText: _memberCountText(list.length),
              isExpanded: isExpanded,
              onToggle: () => setState(() {
                if (isExpanded) {
                  _collapsedSections.add(sectionKey);
                } else {
                  _collapsedSections.remove(sectionKey);
                }
              }),
            ),
            const SizedBox(height: 8),
            if (isExpanded)
              ...list.map((member) {
                final profile = _memberProfiles[member.userId];
                final fullName = profile?.fullName ?? member.userId;
                final username = profile?.username != null && profile!.username.isNotEmpty
                    ? '@${profile.username}'
                    : '';
                final avatarUrl = profile?.profilePictureUrl != null
                    ? ImageUrlResolver.resolve(context, profile!.profilePictureUrl)
                    : '';
                final initials = fullName.isNotEmpty
                    ? fullName
                          .trim()
                          .split(' ')
                          .map((e) => e.isEmpty ? '' : e[0])
                          .take(2)
                          .join()
                          .toUpperCase()
                    : 'M';

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: theme.colorScheme.surfaceContainerLow,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: profile != null
                        ? () {
                            try {
                              context.push('/users/${profile.username}');
                            } catch (_) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  settings: RouteSettings(name: '/users/${profile.username}'),
                                  builder: (_) => ProfilePage(username: profile.username),
                                ),
                              );
                            }
                          }
                        : null,
                    child: Container(
                      height: 72,
                      alignment: Alignment.center,
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl.isEmpty
                              ? Text(
                                  initials,
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: username.isNotEmpty
                            ? Text(
                                username,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              )
                            : null,
                        trailing: (member.customTitle != null && member.customTitle!.isNotEmpty)
                            ? Chip(
                                label: Text(member.customTitle!.toUpperCase()),
                                labelStyle: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              )
                            : null,
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      }),
    );
  }

  Widget _buildBanner(ThemeData theme, String bannerUrl) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isMobile = !isDesktop;
    final hideAppBar = widget.isInline && isDesktop;
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
          aspectRatio: isMobile ? 2.2 : 278.6 / 80,
          child: ClipRRect(
            borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bannerUrl.isNotEmpty)
                  Image.network(
                    bannerUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => _buildDefaultBanner(theme),
                  )
                else
                  _buildDefaultBanner(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultBanner(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
      ),
    );
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }
}
