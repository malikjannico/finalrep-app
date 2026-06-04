import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/profile.dart';
import '../models/competition.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import '../repositories/profile_repository.dart';
import '../utils/mock_safety.dart';
import '../utils/image_url_resolver.dart';
import 'settings_page.dart';
import 'competition_detail_page.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  final String? username;
  final bool isInline;
  final ProfileRepository? profileRepository;

  const ProfilePage({
    super.key,
    this.userId,
    this.username,
    this.isInline = false,
    this.profileRepository,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Profile? _profile;
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;
  bool _isCurrentUser = false;
  bool _isLoadingProfile = false;
  bool _isEditing = false;
  String? _errorMsg;
  int _bannerTimestamp = DateTime.now().millisecondsSinceEpoch;

  List<Competition> _upcomingMeets = [];
  List<Competition> _completedMeets = [];
  List<Map<String, dynamic>> _highestRankings = [];
  List<Map<String, dynamic>> _personalRecords = [];
  bool _isLoadingAthleteData = false;
  final Map<String, Competition> _competitionCache = {};


  // Edit fields controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  String? _selectedSex;
  String? _selectedCountry;

  Uint8List? _customAvatarBytes;
  String? _customAvatarFileName;

  final List<String> _sexes = [
    'male',
    'female',
    'other',
    'prefer not to say',
  ];
  final List<String> _countries = [
    'Germany',
    'Austria',
    'Switzerland',
    'France',
    'United States',
    'Japan',
    'United Kingdom',
    'Spain',
    'Italy',
    'Canada',
  ];

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);
    _loadProfile();
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

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _customAvatarBytes = file.bytes;
          _customAvatarFileName = file.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _errorMsg = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (widget.userId == null && widget.username == null) {
        // Default to current user
        if (authProvider.isAuthenticated &&
            authProvider.currentUserProfile != null) {
          _profile = authProvider.currentUserProfile;
          _isCurrentUser = true;
        } else {
          _errorMsg = 'Please log in to view your profile.';
        }
      } else {
        final profileRepository =
            widget.profileRepository ?? authProvider.profileRepository;
        if (widget.userId != null) {
          // Fetch by ID
          _isCurrentUser =
              authProvider.isAuthenticated &&
              authProvider.currentUserProfile?.id == widget.userId;
          if (_isCurrentUser) {
            _profile = authProvider.currentUserProfile;
          } else {
            _profile = await profileRepository.getProfile(widget.userId!);
          }
        } else if (widget.username != null) {
          // Fetch by Username
          _isCurrentUser =
              authProvider.isAuthenticated &&
              authProvider.currentUserProfile?.username.toLowerCase() ==
                  widget.username!.toLowerCase();
          if (_isCurrentUser) {
            _profile = authProvider.currentUserProfile;
          } else {
            _profile = await profileRepository.getProfileByUsername(
              widget.username!,
            );
          }
        }
      }

      if (_profile == null && _errorMsg == null) {
        _errorMsg = 'User profile not found.';
      } else if (_profile != null) {
        _syncControllers();
        _loadAthleteData();
      }
    } catch (e) {
      _errorMsg = 'Error loading profile: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  void _syncControllers() {
    if (_profile == null) return;
    _fullNameController.text = _profile!.fullName;
    _emailController.text = _profile!.email;
    _bioController.text = _profile!.description ?? '';
    _selectedSex = _profile!.sex;
    _selectedCountry = _profile!.country;
  }

  String _capitalizeSex(String s) {
    if (s == 'prefer not to say') return 'Prefer not to say';
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }

  void _shareProfile() {
    if (_profile == null) return;
    final username = _profile!.username;
    final baseUrl = Uri.base.origin;
    final shareUrl = '$baseUrl/users/$username';

    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile link copied to clipboard: $shareUrl'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _saveProfileChanges() async {
    if (_formKey.currentState == null) {
      return;
    }
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      String? uploadedUrl;
      if (_customAvatarBytes != null) {
        final profileRepository =
            widget.profileRepository ?? authProvider.profileRepository;
        final fileName =
            'profiles-${_profile!.id}-${_customAvatarFileName ?? "avatar.png"}';
        uploadedUrl = await profileRepository.uploadFile(
          _customAvatarBytes!,
          fileName,
        );
      }

      await authProvider.updateProfile(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        sex: _selectedSex,
        country: _selectedCountry,
        description: _bioController.text.trim(),
        colorMode: _profile?.colorMode ?? 'system',
        profilePictureUrl: uploadedUrl,
      );
      setState(() {
        _profile = authProvider.currentUserProfile;
        _customAvatarBytes = null;
        _customAvatarFileName = null;
        _isEditing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  String _getBannerUrl() {
    if (_profile == null) return '';
    final userId = _profile!.id;
    try {
      final competitionProvider = Provider.of<CompetitionProvider>(
        context,
        listen: false,
      );
      final apiBaseUrl = competitionProvider.competitionRepository.baseUrl;
      if (MockSafety.isMockAllowed) {
        return '$apiBaseUrl/uploads/profiles-$userId-banner.jpg';
      }
      final bucket = 'finalrep-app-media-${MockSafety.env}';
      return 'https://storage.googleapis.com/$bucket/avatars/profiles-$userId-banner.jpg?t=$_bannerTimestamp';
    } catch (_) {
      return '';
    }
  }

  Future<void> _uploadBanner() async {
    final userId = _profile?.id;
    if (userId == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;

        if (bytes != null) {
          setState(() {
            _isLoadingProfile = true;
          });

          final fileName = 'profiles-$userId-banner.jpg';
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final profileRepository =
              widget.profileRepository ?? authProvider.profileRepository;

          await profileRepository.uploadFile(bytes, fileName);

          setState(() {
            _bannerTimestamp = DateTime.now().millisecondsSinceEpoch;
            _isLoadingProfile = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Banner updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload banner: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _loadAthleteData() async {
    if (_profile == null) return;
    setState(() {
      _isLoadingAthleteData = true;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final repo = widget.profileRepository ?? authProvider.profileRepository;
      final competitionRepository = Provider.of<CompetitionProvider>(
        context,
        listen: false,
      ).competitionRepository;

      final results = await Future.wait([
        repo.getUserUpcomingMeets(_profile!.id),
        repo.getUserCompletedMeets(_profile!.id),
        repo.getUserHighestRankings(_profile!.id),
        repo.getUserPersonalRecords(_profile!.id),
      ]);
      if (mounted) {
        final upcoming = results[0] as List<Competition>;
        final completed = results[1] as List<Competition>;
        final rankings = results[2] as List<Map<String, dynamic>>;
        final prs = results[3] as List<Map<String, dynamic>>;

        // Populate cache from loaded meets
        for (final c in completed) {
          _competitionCache[c.title] = c;
        }
        for (final c in upcoming) {
          _competitionCache[c.title] = c;
        }

        // Fallbacks for mock data
        _competitionCache.putIfAbsent(
          'FinalRep Qualifier Munich 2025',
          () => Competition(
            id: 'mock-meet-munich',
            title: 'FinalRep Qualifier Munich 2025',
            description: 'Munich streetlifting meet',
            startDate: DateTime(2025, 6, 15),
            endDate: DateTime(2025, 6, 16),
            location: 'Munich, Germany',
            sportSubtype: 'Modern',
            status: 'completed',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        _competitionCache.putIfAbsent(
          'FinalRep Underground Berlin 2025',
          () => Competition(
            id: 'mock-meet-berlin',
            title: 'FinalRep Underground Berlin 2025',
            description: 'Berlin streetlifting meet',
            startDate: DateTime(2025, 10, 12),
            endDate: DateTime(2025, 10, 12),
            location: 'Berlin, Germany',
            sportSubtype: 'Modern',
            status: 'completed',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        _competitionCache.putIfAbsent(
          'FinalRep Underground Frankfurt 2025',
          () => Competition(
            id: 'mock-meet-frankfurt',
            title: 'FinalRep Underground Frankfurt 2025',
            description: 'Frankfurt streetlifting meet',
            startDate: DateTime(2025, 11, 5),
            endDate: DateTime(2025, 11, 5),
            location: 'Frankfurt, Germany',
            sportSubtype: 'Modern',
            status: 'completed',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Fetch any missing competitions from database
        final titlesToFetch = <String>{};
        for (final r in rankings) {
          final title = r['competition']?.toString();
          if (title != null && title.isNotEmpty) titlesToFetch.add(title);
        }
        for (final pr in prs) {
          final title = pr['competition']?.toString();
          if (title != null && title.isNotEmpty) titlesToFetch.add(title);
        }
        titlesToFetch.removeWhere(
          (title) => _competitionCache.containsKey(title),
        );

        if (titlesToFetch.isNotEmpty) {
          try {
            final completedComps = await competitionRepository
                .getUpcomingCompetitions(status: 'completed');
            for (final c in completedComps) {
              if (titlesToFetch.contains(c.title)) {
                _competitionCache[c.title] = c;
              }
            }
            final upcomingComps = await competitionRepository
                .getUpcomingCompetitions(status: 'upcoming');
            for (final c in upcomingComps) {
              if (titlesToFetch.contains(c.title)) {
                _competitionCache[c.title] = c;
              }
            }
          } catch (e) {
            debugPrint('Error caching competitions: $e');
          }
        }

        setState(() {
          _upcomingMeets = upcoming;
          _completedMeets = completed;
          _highestRankings = rankings;
          _personalRecords = prs;
        });
      }
    } catch (e) {
      debugPrint('Error loading athlete data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAthleteData = false;
        });
      }
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

  Future<void> _launchURL(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildSocialLinks(ThemeData theme) {
    if (_profile == null ||
        _profile!.socialLinks == null ||
        _profile!.socialLinks!.isEmpty) {
      return const SizedBox.shrink();
    }

    final validLinks = _profile!.socialLinks!.entries
        .where((e) => e.value.trim().isNotEmpty)
        .toList();

    if (validLinks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Row(
          children: [
            Icon(
              Icons.language_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Website & Social Channels',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: validLinks.map((entry) {
            final name = entry.key;
            final handle = entry.value;
            IconData iconData;
            switch (name.toLowerCase()) {
              case 'instagram':
                iconData = Icons.camera_alt_outlined;
                break;
              case 'twitter':
              case 'x':
                iconData = Icons.alternate_email;
                break;
              case 'youtube':
                iconData = Icons.play_circle_outline;
                break;
              case 'tiktok':
                iconData = Icons.music_note_outlined;
                break;
              case 'facebook':
                iconData = Icons.facebook_outlined;
                break;
              case 'twitch':
                iconData = Icons.live_tv_outlined;
                break;
              default:
                iconData = Icons.link;
            }
            final displayText = _cleanSocialDisplay(name, handle);
            final url = _getSocialUrl(name, handle);

            return ActionChip(
              avatar: Icon(iconData, size: 16),
              label: Text(displayText),
              onPressed: () => _launchURL(url),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAthleteDashboard(ThemeData theme) {
    if (_isLoadingAthleteData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    String cleanLiftName(String name) {
      final lower = name.toLowerCase();
      if (lower.contains('muscle') && lower.contains('up')) return 'Muscle Up';
      if (lower.contains('pull') && lower.contains('up')) return 'Pull Up';
      if (lower.contains('dip')) return 'Dip';
      if (lower.contains('squat')) return 'Squat';
      return name
          .replaceAll(RegExp(r'\bWeighted\b', caseSensitive: false), '')
          .trim();
    }

    int getDisciplineOrder(String name) {
      final clean = cleanLiftName(name);
      switch (clean) {
        case 'Muscle Up':
          return 1;
        case 'Pull Up':
          return 2;
        case 'Dip':
          return 3;
        case 'Squat':
          return 4;
        default:
          return 5;
      }
    }

    String formatDate(DateTime date) {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day.$month.$year';
    }

    final processedPRs = _personalRecords.map((pr) {
      final lift = pr['lift']?.toString() ?? pr['discipline']?.toString() ?? '';
      final cleanName = cleanLiftName(lift);
      final newMap = Map<String, dynamic>.from(pr);
      newMap['lift'] = cleanName;
      return newMap;
    }).toList();

    processedPRs.sort((a, b) {
      final orderA = getDisciplineOrder(a['lift']?.toString() ?? '');
      final orderB = getDisciplineOrder(b['lift']?.toString() ?? '');
      return orderA.compareTo(orderB);
    });

    final overallRankings = _highestRankings.where((r) {
      final disc = r['discipline']?.toString().toLowerCase() ?? '';
      final isOverall = disc.contains('overall');
      if (!isOverall) return false;
      final compName =
          r['competition']?.toString() ??
          r['competition_name']?.toString() ??
          '';

      // Filter out rankings from upcoming competitions
      final isUpcoming = _upcomingMeets.any((c) => c.title == compName);
      if (isUpcoming) return false;

      final compObj = _competitionCache[compName];
      if (compObj != null && compObj.status == 'upcoming') {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(
          'Athlete Dashboard',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Personal Records
        Row(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Personal Records',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (processedPRs.isEmpty)
          Text(
            'No personal records recorded.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: processedPRs.length,
            itemBuilder: (context, index) {
              final pr = processedPRs[index];
              final compName =
                  pr['competition']?.toString() ??
                  pr['competition_name']?.toString() ??
                  '';
              final compObj = _competitionCache[compName];
              final location =
                  compObj?.location ?? pr['location']?.toString() ?? '';

              final dateRaw =
                  compObj?.startDate ??
                  pr['date'] ??
                  pr['achieved_at'] ??
                  pr['date_achieved'];
              String dateStr = '';
              if (dateRaw != null) {
                if (dateRaw is DateTime) {
                  dateStr =
                      '${dateRaw.day.toString().padLeft(2, '0')}.${dateRaw.month.toString().padLeft(2, '0')}.${dateRaw.year}';
                } else {
                  try {
                    final parsed = DateTime.parse(dateRaw.toString());
                    dateStr =
                        '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
                  } catch (_) {
                    dateStr = dateRaw.toString();
                  }
                }
              }

              String subtitleText = '';
              if (compName.isNotEmpty && dateStr.isNotEmpty) {
                subtitleText = '$compName • $dateStr';
              } else if (compName.isNotEmpty) {
                subtitleText = compName;
              } else if (dateStr.isNotEmpty) {
                subtitleText = dateStr;
              }

              final content = Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        pr['lift'] ?? '',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pr['weight'] ?? '',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (subtitleText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitleText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              );

              final fallbackComp =
                  compObj ??
                  Competition(
                    id: 'unknown-${compName.hashCode}',
                    title: compName,
                    description: '',
                    startDate: dateRaw is DateTime ? dateRaw : DateTime.now(),
                    endDate: dateRaw is DateTime ? dateRaw : DateTime.now(),
                    location: location.isNotEmpty
                        ? location
                        : 'Unknown Location',
                    sportSubtype: 'Modern',
                    status: 'completed',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CompetitionDetailPage(competition: fallbackComp),
                    ),
                  );
                },
                child: content,
              );
            },
          ),
        const SizedBox(height: 24),

        // Rankings
        Row(
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Highest Rankings',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (overallRankings.isEmpty)
          Text(
            'No overall ranking recorded.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...overallRankings.map((r) {
            final compName =
                r['competition']?.toString() ??
                r['competition_name']?.toString() ??
                r['source_meet_title']?.toString() ??
                'Unknown Competition';
            final compObj = _competitionCache[compName];

            final location =
                compObj?.location ??
                r['location']?.toString() ??
                r['source_meet_location']?.toString() ??
                r['competition_location']?.toString() ??
                '';
            final dateRaw =
                compObj?.startDate ??
                r['date'] ??
                r['achieved_at'] ??
                r['date_achieved'];
            String dateStr = '';
            if (dateRaw != null) {
              if (dateRaw is DateTime) {
                dateStr =
                    '${dateRaw.day.toString().padLeft(2, '0')}.${dateRaw.month.toString().padLeft(2, '0')}.${dateRaw.year}';
              } else {
                try {
                  final parsed = DateTime.parse(dateRaw.toString());
                  dateStr =
                      '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
                } catch (_) {
                  dateStr = dateRaw.toString();
                }
              }
            }

            String locationAndDate = '';
            if (location.isNotEmpty && dateStr.isNotEmpty) {
              locationAndDate = '$location • $dateStr';
            } else if (location.isNotEmpty) {
              locationAndDate = location;
            } else if (dateStr.isNotEmpty) {
              locationAndDate = dateStr;
            }

            return Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () {
                  final fallbackComp =
                      compObj ??
                      Competition(
                        id: 'unknown-${compName.hashCode}',
                        title: compName,
                        description: '',
                        startDate: dateRaw is DateTime
                            ? dateRaw
                            : DateTime.now(),
                        endDate: dateRaw is DateTime ? dateRaw : DateTime.now(),
                        location: location.isNotEmpty
                            ? location
                            : 'Unknown Location',
                        sportSubtype: 'Modern',
                        status: 'completed',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CompetitionDetailPage(competition: fallbackComp),
                    ),
                  );
                },
                leading: Icon(
                  Icons.stars_outlined,
                  color: theme.colorScheme.onSurface,
                ),
                title: Text(
                  r['discipline'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(compName),
                    if (locationAndDate.isNotEmpty)
                      Text(
                        locationAndDate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    r['rank'] ?? '',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 24),

        // Upcoming Competitions
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Upcoming Competitions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_upcomingMeets.isEmpty)
          Text(
            'No upcoming competitions registered.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _upcomingMeets.length,
            itemBuilder: (context, index) {
              final comp = _upcomingMeets[index];
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CompetitionDetailPage(competition: comp),
                      ),
                    );
                  },
                  title: Text(
                    comp.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${comp.location} • ${formatDate(comp.startDate)}',
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 24),

        // Completed Competitions
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Completed Competitions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_completedMeets.isEmpty)
          Text(
            'No completed competitions.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _completedMeets.length,
            itemBuilder: (context, index) {
              final comp = _completedMeets[index];
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CompetitionDetailPage(competition: comp),
                      ),
                    );
                  },
                  title: Text(
                    comp.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${comp.location} • ${formatDate(comp.startDate)}',
                  ),
                  trailing: Icon(
                    Icons.check_circle_outline,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final hideAppBar = widget.isInline && isDesktop;

    // If viewing current user and auth state changed, update local profile
    if (_isCurrentUser && authProvider.currentUserProfile != null) {
      _profile = authProvider.currentUserProfile;
    }

    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: hideAppBar
            ? null
            : AppBar(
                automaticallyImplyLeading: !widget.isInline,
                title: Text(widget.username ?? 'Profile'),
              ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMsg != null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: hideAppBar
            ? null
            : AppBar(
                automaticallyImplyLeading: !widget.isInline,
                title: const Text('Error'),
              ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMsg!,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadProfile,
                  child: const Text('RETRY'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: hideAppBar
            ? null
            : AppBar(
                automaticallyImplyLeading: !widget.isInline,
                title: const Text('Profile'),
              ),
        body: const Center(child: Text('No profile loaded.')),
      );
    }

    final isMobile = !isDesktop;
    final showAppBar = !hideAppBar && !(isMobile && _isEditing);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBodyBehindAppBar: showAppBar,
      appBar: showAppBar
          ? AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: _showAppBarTitle || _isEditing
                  ? theme.colorScheme.surface
                  : Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: _isEditing
                  ? IconButton(
                      key: const Key('edit_mode_back_button'),
                      icon: const Icon(Icons.arrow_back),
                      color: theme.colorScheme.onSurface,
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                        });
                      },
                    )
                  : (!widget.isInline
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
                      : null),
              title: AnimatedOpacity(
                opacity: _showAppBarTitle ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _profile?.username != null && _profile!.username.isNotEmpty
                      ? '@${_profile!.username}'
                      : 'Profile',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )
          : null,
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              _buildBanner(theme),
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SizedBox(
                            height: isMobile ? 45 : 40,
                            width: isMobile ? 90 : 80,
                          ),
                          Positioned(
                            top: isMobile ? -45 : -40,
                            left: 0,
                            child: _buildAvatar(theme),
                          ),
                        ],
                      ),
                      SizedBox(height: isMobile ? 8 : 12),
                      if (_customAvatarFileName != null) ...[
                        Text(
                          _customAvatarFileName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _buildProfileHeader(theme),
                      _buildSocialLinks(theme),
                      const SizedBox(height: 8),
                      _isEditing
                          ? _buildEditForm(theme, authProvider)
                          : _buildProfileInfoCard(theme),
                      if (_isCurrentUser && !_isEditing) ...[
                        const SizedBox(height: 24),
                        isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ElevatedButton.icon(
                                    key: const Key('edit_profile_button'),
                                    onPressed: () {
                                      setState(() {
                                        _isEditing = true;
                                      });
                                    },
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('EDIT PROFILE'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.secondary,
                                      foregroundColor: theme.colorScheme.onSecondary,
                                      minimumSize: const Size.fromHeight(40),
                                      shape: const StadiumBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    key: const Key('share_profile_button'),
                                    onPressed: _shareProfile,
                                    icon: const Icon(Icons.share, size: 18),
                                    label: const Text('SHARE PROFILE'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      foregroundColor: theme.colorScheme.onPrimary,
                                      minimumSize: const Size.fromHeight(40),
                                      shape: const StadiumBorder(),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      key: const Key('edit_profile_button'),
                                      onPressed: () {
                                        setState(() {
                                          _isEditing = true;
                                        });
                                      },
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('EDIT PROFILE'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.secondary,
                                        foregroundColor: theme.colorScheme.onSecondary,
                                        minimumSize: const Size.fromHeight(40),
                                        shape: const StadiumBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      key: const Key('share_profile_button'),
                                      onPressed: _shareProfile,
                                      icon: const Icon(Icons.share, size: 18),
                                      label: const Text('SHARE PROFILE'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.primary,
                                        foregroundColor: theme.colorScheme.onPrimary,
                                        minimumSize: const Size.fromHeight(40),
                                        shape: const StadiumBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                      if (!_isCurrentUser && !_isEditing) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            key: const Key('share_profile_button'),
                            onPressed: _shareProfile,
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('SHARE PROFILE'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              minimumSize: const Size.fromHeight(40),
                              shape: const StadiumBorder(),
                            ),
                          ),
                        ),
                      ],
                      if (!_isEditing) _buildAthleteDashboard(theme),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }



  Widget _buildBanner(ThemeData theme) {
    final bannerUrl = _getBannerUrl();
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
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                        theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: bannerUrl.isEmpty
                      ? const SizedBox.shrink()
                      : Image.network(
                          bannerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink(); // Fallback to gradient background
                          },
                        ),
                ),
                if (_isEditing && _isCurrentUser)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black38,
                      child: InkWell(
                        onTap: _uploadBanner,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, color: Colors.white, size: 32),
                            SizedBox(height: 8),
                            Text(
                              'Change Banner',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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



  Widget _buildAvatar(ThemeData theme) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isMobile = !isDesktop;
    final initials = _profile!.fullName.isNotEmpty
        ? _profile!.fullName
              .trim()
              .split(' ')
              .map((e) => e.isEmpty ? '' : e[0])
              .take(2)
              .join()
              .toUpperCase()
        : _profile!.username.isNotEmpty
        ? _profile!.username[0].toUpperCase()
        : '?';

    final resolvedUrl = ImageUrlResolver.resolve(context, _profile!.profilePictureUrl);
    final double avatarRadius = isMobile ? 45 : 40;
    final double avatarSize = isMobile ? 90 : 80;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.surface,
          width: 4,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: ClipOval(
              child: _customAvatarBytes != null
                  ? Image.memory(
                      _customAvatarBytes!,
                      width: avatarSize,
                      height: avatarSize,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: isMobile ? 32 : 28,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        );
                      },
                    )
                  : (resolvedUrl != null &&
                            resolvedUrl.isNotEmpty
                        ? Image.network(
                            resolvedUrl,
                            width: avatarSize,
                            height: avatarSize,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    fontSize: isMobile ? 32 : 28,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              );
                            },
                          )
                        : Text(
                            initials,
                            style: TextStyle(
                              fontSize: isMobile ? 32 : 28,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          )),
            ),
          ),
          if (_isEditing && _isCurrentUser)
            Positioned.fill(
              child: Material(
                type: MaterialType.circle,
                color: Colors.black45,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _pickAvatar,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: Colors.white, size: isMobile ? 24 : 20),
                      const SizedBox(height: 2),
                      Text(
                        'CHANGE PHOTO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 9 : 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                _profile!.fullName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isCurrentUser) ...[
              const SizedBox(width: 8),
              IconButton(
                key: const Key('profile_settings_icon'),
                icon: const Icon(Icons.settings_outlined),
                iconSize: 20,
                color: theme.colorScheme.onSurfaceVariant,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  try {
                    GoRouter.of(context);
                    goRouter.push('/settings');
                  } catch (_) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/settings'),
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                  }
                },
              ),
            ],
          ],
        ),
        Text(
          '@${_profile!.username}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_profile!.sex != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _capitalizeSex(_profile!.sex!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                  ),
                ),
              ),
            if (_profile!.sex != null && _profile!.country != null)
              const SizedBox(width: 8),
            if (_profile!.country != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 10,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _profile!.country!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileInfoCard(ThemeData theme) {
    final hasDescription =
        _profile!.description != null && _profile!.description!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        hasDescription ? _profile!.description! : 'No description provided.',
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.4,
          color: hasDescription
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildEditForm(ThemeData theme, AuthProvider authProvider) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Profile Info',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Full Name
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (val) =>
                val == null || val.isEmpty ? 'Full name is required' : null,
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Email is required';
              if (!val.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Bio Description
          TextFormField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Description / Bio',
              prefixIcon: Icon(Icons.description_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // Sex Picker
          Theme(
            data: theme.copyWith(
              cardColor: theme.colorScheme.surface,
            ),
            child: PopupMenuButton<String>(
              tooltip: 'Sex',
              offset: const Offset(0, 48),
              borderRadius: BorderRadius.circular(12),
              onSelected: (val) {
                setState(() {
                  _selectedSex = val;
                });
              },
              itemBuilder: (BuildContext context) {
                return _sexes.map((s) {
                  return PopupMenuItem<String>(
                    value: s,
                    child: Text(_capitalizeSex(s)),
                  );
                }).toList();
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Sex',
                  prefixIcon: Icon(Icons.people_outline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedSex != null ? _capitalizeSex(_selectedSex!) : '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Country Picker
          InkWell(
            onTap: () => _showCountrySelectorDialog(theme),
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Country',
                prefixIcon: Icon(Icons.public),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedCountry ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _syncControllers();
                  });
                },
                child: const Text('CANCEL'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _saveProfileChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: const Text('SAVE'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCountrySelectorDialog(ThemeData theme) {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _countries.where((c) {
              return c.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              title: const Text('Select Country'),
              content: SizedBox(
                width: 400,
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Country',
                        hintText: 'e.g. Germany, France...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final c = filtered[idx];
                          return ListTile(
                            title: Text(c),
                            trailing: _selectedCountry == c
                                ? Icon(Icons.check, color: theme.colorScheme.primary)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedCountry = c;
                              });
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
