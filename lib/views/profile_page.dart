import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../providers/auth_provider.dart';
import '../repositories/profile_repository.dart';

class ProfilePage extends StatefulWidget {
  final String? userId; // If null, loads current user's profile
  final String? username; // Can also look up by username for deep links
  final bool isInline; // If true, disables Scaffold's appBar back button, and doesn't pop on logout

  const ProfilePage({
    super.key,
    this.userId,
    this.username,
    this.isInline = false,
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

  // Edit fields controllers
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  String? _selectedGender;
  String? _selectedCountry;

  // Password change controller
  final _passwordFormKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

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

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _errorMsg = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileRepository = ProfileRepository(Supabase.instance.client);

    try {
      if (widget.userId == null && widget.username == null) {
        // Default to current user
        if (authProvider.isAuthenticated && authProvider.currentUserProfile != null) {
          _profile = authProvider.currentUserProfile;
          _isCurrentUser = true;
        } else {
          _errorMsg = 'Please log in to view your profile.';
        }
      } else if (widget.userId != null) {
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

      if (_profile == null && _errorMsg == null) {
        _errorMsg = 'User profile not found.';
      } else if (_profile != null) {
        _syncControllers();
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
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      await authProvider.updateProfile(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        gender: _selectedGender,
        country: _selectedCountry,
        description: _bioController.text.trim(),
        colorMode: _profile?.colorMode ?? 'system',
      );
      setState(() {
        _profile = authProvider.currentUserProfile;
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

  void _showChangePasswordDialog() {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Change Password'),
          content: Form(
            key: _passwordFormKey,
            child: TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Please enter a new password';
                }
                if (val.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!_passwordFormKey.currentState!.validate()) return;
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                try {
                  await authProvider.changePassword(_passwordController.text);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('UPDATE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // If viewing current user and auth state changed, update local profile
    if (_isCurrentUser && authProvider.currentUserProfile != null) {
      _profile = authProvider.currentUserProfile;
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isInline,
        title: Text(
          _isCurrentUser ? 'My Profile' : (_profile?.username ?? 'Profile'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_profile != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareProfile,
              tooltip: 'Share Profile Link',
            ),
        ],
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
              ? Center(
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
                          textAlign: CenterTextAlignment,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadProfile,
                          child: const Text('RETRY'),
                        ),
                      ],
                    ),
                  ),
                )
              : _profile == null
                  ? const Center(child: Text('No profile loaded.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildProfileHeader(theme),
                              const SizedBox(height: 24),
                              _isEditing
                                  ? _buildEditForm(theme, authProvider)
                                  : _buildProfileInfoCard(theme),
                              if (_isCurrentUser && !_isEditing) ...[
                                const SizedBox(height: 24),
                                _buildSettingsCard(theme, authProvider),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  static const TextAlign CenterTextAlignment = TextAlign.center;

  Widget _buildProfileHeader(ThemeData theme) {
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

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            // Profile Picture or Monogram
            CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: _profile!.profilePictureUrl != null
                  ? NetworkImage(_profile!.profilePictureUrl!)
                  : null,
              child: _profile!.profilePictureUrl == null
                  ? Text(
                      initials,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 20),

            // Profile metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _profile!.fullName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'About Me',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isCurrentUser)
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('EDIT'),
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _profile!.description != null && _profile!.description!.isNotEmpty
                  ? _profile!.description!
                  : 'No description provided.',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: _profile!.description == null ||
                        _profile!.description!.isEmpty
                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm(ThemeData theme, AuthProvider authProvider) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
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
        ),
      ),
    );
  }

  Widget _buildSettingsCard(ThemeData theme, AuthProvider authProvider) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings & Security',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Color Mode preference selector
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Default Color Mode'),
              subtitle: Text(
                'Current: ${_profile!.colorMode[0].toUpperCase()}${_profile!.colorMode.substring(1)}',
              ),
              trailing: DropdownButton<String>(
                value: _profile!.colorMode,
                underline: Container(),
                items: const [
                  DropdownMenuItem(value: 'system', child: Text('System')),
                  DropdownMenuItem(value: 'light', child: Text('Light')),
                  DropdownMenuItem(value: 'dark', child: Text('Dark')),
                ],
                onChanged: (val) async {
                  if (val == null) return;
                  try {
                    await authProvider.updateProfile(
                      fullName: _profile!.fullName,
                      email: _profile!.email,
                      gender: _profile!.gender,
                      country: _profile!.country,
                      description: _profile!.description,
                      colorMode: val,
                    );
                    setState(() {
                      _profile = authProvider.currentUserProfile;
                    });
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update color mode: $e')),
                      );
                    }
                  }
                },
              ),
            ),
            const Divider(),

            // Change Password button
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_reset_outlined),
              title: const Text('Update Login Credentials'),
              subtitle: const Text('Change your password'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: _showChangePasswordDialog,
            ),
            const Divider(),

            // Logout Option
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Log Out',
                style: TextStyle(color: Colors.redAccent),
              ),
              subtitle: const Text('Sign out of your account'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Log Out?'),
                    content: const Text('Are you sure you want to log out of your session?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('CANCEL'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('LOG OUT'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await authProvider.logout();
                  if (mounted) {
                    if (!widget.isInline) {
                      Navigator.of(context).pop(); // Back to main screen
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out successfully.')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
