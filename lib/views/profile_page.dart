import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../models/profile.dart';
import '../models/competition.dart';
import '../providers/auth_provider.dart';
import '../repositories/profile_repository.dart';
import 'settings_page.dart';

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

  // Edit fields controllers
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  String? _selectedGender;
  String? _selectedCountry;

  Uint8List? _customAvatarBytes;
  String? _customAvatarFileName;

  final List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
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
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _bioController = TextEditingController();
    _loadProfile();
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
    super.dispose();
  }

  SupabaseClient? _getSupabaseClient() {
    try {
      if (widget.profileRepository != null) {
        return widget.profileRepository!.client;
      }
    } catch (_) {}
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      return authProvider.profileRepository.client;
    } catch (_) {}
    try {
      return Supabase.instance.client;
    } catch (_) {}
    return null;
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
        if (authProvider.isAuthenticated && authProvider.currentUserProfile != null) {
          _profile = authProvider.currentUserProfile;
          _isCurrentUser = true;
        } else {
          _errorMsg = 'Please log in to view your profile.';
        }
      } else {
        final client = _getSupabaseClient();
        final profileRepository = widget.profileRepository ?? (client != null ? ProfileRepository(client) : null);
        if (profileRepository == null) {
          _errorMsg = 'Supabase client not available.';
        } else {
          if (widget.userId != null) {
            // Fetch by ID
            _isCurrentUser = authProvider.isAuthenticated &&
                authProvider.currentUserProfile?.id == widget.userId;
            if (_isCurrentUser) {
              _profile = authProvider.currentUserProfile;
            } else {
              _profile = await profileRepository.getProfile(widget.userId!);
            }
          } else if (widget.username != null) {
            // Fetch by Username
            _isCurrentUser = authProvider.isAuthenticated &&
                authProvider.currentUserProfile?.username.toLowerCase() ==
                    widget.username!.toLowerCase();
            if (_isCurrentUser) {
              _profile = authProvider.currentUserProfile;
            } else {
              _profile =
                  await profileRepository.getProfileByUsername(widget.username!);
            }
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
    _selectedGender = _profile!.gender;
    _selectedCountry = _profile!.country;
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
        final client = _getSupabaseClient();
        if (client == null) {
          throw Exception('Supabase client not available.');
        }
        final ext = _customAvatarFileName?.split('.').last ?? 'png';
        final filePath = 'profiles/${_profile!.id}/${_customAvatarFileName ?? "avatar.png"}';

        await client.storage.from('avatars').uploadBinary(
          filePath,
          _customAvatarBytes!,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            cacheControl: '3600',
            upsert: true,
          ),
        );

        uploadedUrl = client.storage.from('avatars').getPublicUrl(filePath);
      }

      await authProvider.updateProfile(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        gender: _selectedGender,
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
      final client = _getSupabaseClient();
      if (client == null) return '';
      final url = client.storage.from('avatars').getPublicUrl('profiles/$userId/banner.jpg');
      return '$url?t=$_bannerTimestamp';
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

          final filePath = 'profiles/$userId/banner.jpg';
          final client = _getSupabaseClient();
          if (client == null) {
            throw Exception('Supabase client not available.');
          }

          await client.storage.from('avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '0',
              upsert: true,
            ),
          );

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
      final client = _getSupabaseClient();
      final repo = widget.profileRepository ?? (client != null ? ProfileRepository(client) : null);
      if (repo != null) {
        final results = await Future.wait([
          repo.getUserUpcomingMeets(_profile!.id),
          repo.getUserCompletedMeets(_profile!.id),
          repo.getUserHighestRankings(_profile!.id),
          repo.getUserPersonalRecords(_profile!.id),
        ]);
        if (mounted) {
          setState(() {
            _upcomingMeets = results[0] as List<Competition>;
            _completedMeets = results[1] as List<Competition>;
            _highestRankings = results[2] as List<Map<String, dynamic>>;
            _personalRecords = results[3] as List<Map<String, dynamic>>;
          });
        }
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

  Widget _buildSocialLinks(ThemeData theme) {
    if (_profile == null || _profile!.socialLinks == null || _profile!.socialLinks!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: _profile!.socialLinks!.entries.map((entry) {
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
              iconData = Icons.music_note;
              break;
            default:
              iconData = Icons.link;
          }
          return ActionChip(
            avatar: Icon(iconData, size: 16),
            label: Text('$name: $handle'),
            onPressed: () {
              // URL helper or web browser launcher link mapping
            },
          );
        }).toList(),
      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(
          'Athlete Dashboard',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Personal Records
        Text(
          '🏆 Personal Records',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_personalRecords.isEmpty)
          Text('No personal records recorded.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemCount: _personalRecords.length,
            itemBuilder: (context, index) {
              final pr = _personalRecords[index];
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        pr['lift'] ?? '',
                        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pr['weight'] ?? '',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 24),

        // Rankings
        Text(
          '🥇 Highest Rankings',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_highestRankings.isEmpty)
          Text('No rankings available.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _highestRankings.length,
            itemBuilder: (context, index) {
              final r = _highestRankings[index];
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.stars, color: Colors.amber),
                  title: Text(r['discipline'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(r['competition'] ?? ''),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            },
          ),
        const SizedBox(height: 24),

        // Upcoming Meets
        Text(
          '📅 Upcoming Meets',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_upcomingMeets.isEmpty)
          Text('No upcoming meets registered.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
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
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(comp.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${comp.location} • ${comp.startDate.day}.${comp.startDate.month}.${comp.startDate.year}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              );
            },
          ),
        const SizedBox(height: 24),

        // Completed Meets
        Text(
          '🏁 Completed Meets',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_completedMeets.isEmpty)
          Text('No completed meets.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
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
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(comp.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${comp.location} • ${comp.startDate.day}.${comp.startDate.month}.${comp.startDate.year}'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            if (!hideAppBar)
              SliverAppBar(
                floating: true,
                snap: true,
                pinned: false,
                automaticallyImplyLeading: !widget.isInline,
                backgroundColor: theme.colorScheme.surface,
                title: Text(
                  _profile?.username != null && _profile!.username.isNotEmpty
                      ? '@${_profile!.username}'
                      : 'Profile',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ];
        },
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBanner(theme),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 36), // Reserve space for the shifted avatar (which has bottom: -40, so 40px overlap)
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
                          Row(
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
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: theme.colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        _buildAthleteDashboard(theme),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildBanner(ThemeData theme) {
    print('DEBUG PROFILE_PAGE _buildBanner: _isEditing=$_isEditing, _isCurrentUser=$_isCurrentUser, profileId=${_profile?.id}');
    final bannerUrl = _getBannerUrl();
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

    return SizedBox(
      height: 190,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 150,
            width: double.infinity,
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
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 150,
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
          Positioned(
            left: 24,
            bottom: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: ClipOval(
                    child: _customAvatarBytes != null
                        ? Image.memory(
                            _customAvatarBytes!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              );
                            },
                          )
                        : (_profile!.profilePictureUrl != null
                            ? Image.network(
                                _profile!.profilePictureUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 28,
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
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              )),
                  ),
                ),
                if (_isEditing && _isCurrentUser)
                  Positioned.fill(
                    child: ClipOval(
                      child: Container(
                        color: Colors.black45,
                        child: InkWell(
                          onTap: _pickAvatar,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              SizedBox(height: 2),
                              Text(
                                'CHANGE PHOTO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
          mainAxisSize: MainAxisSize.min,
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
              GestureDetector(
                key: const Key('profile_settings_icon'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/settings'),
                      builder: (_) => const SettingsPage(),
                    ),
                  );
                },
                child: Icon(
                  Icons.settings,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
            if (_profile!.gender != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _profile!.gender!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (_profile!.gender != null && _profile!.country != null)
              const SizedBox(width: 8),
            if (_profile!.country != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _profile!.country!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
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
    final hasDescription = _profile!.description != null && _profile!.description!.isNotEmpty;
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

          // Gender Picker
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              prefixIcon: Icon(Icons.people_outline),
            ),
            items: _genders.map((g) {
              return DropdownMenuItem(value: g, child: Text(g));
            }).toList(),
            onChanged: (val) => setState(() => _selectedGender = val),
          ),
          const SizedBox(height: 16),

          // Country Picker
          DropdownButtonFormField<String>(
            value: _selectedCountry,
            decoration: const InputDecoration(
              labelText: 'Country',
              prefixIcon: Icon(Icons.public),
            ),
            items: _countries.map((c) {
              return DropdownMenuItem(value: c, child: Text(c));
            }).toList(),
            onChanged: (val) => setState(() => _selectedCountry = val),
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


}
