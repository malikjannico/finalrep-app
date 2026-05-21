import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/auth_provider.dart';

class AuthPage extends StatefulWidget {
  final bool isInline;
  const AuthPage({super.key, this.isInline = false});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Login Controllers
  final _loginIdController = TextEditingController(); // email or username
  final _loginPasswordController = TextEditingController();
  bool _isUsernameLogin = false; // toggles email vs username login
  bool _obscureLoginPassword = true;

  // Register Controllers
  final _regUsernameController = TextEditingController();
  final _regFullNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  bool _obscureRegPassword = true;

  // Optional registration fields
  String? _selectedGender = 'Male';
  String? _selectedCountry = 'Germany';
  String? _selectedProfilePicUrl;

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

  // Preset avatars for profile pictures
  final List<String> _presetAvatars = [
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
    'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=150&q=80',
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=150&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdController.dispose();
    _loginPasswordController.dispose();
    _regUsernameController.dispose();
    _regFullNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final id = _loginIdController.text.trim();
    final password = _loginPasswordController.text;

    try {
      if (_isUsernameLogin) {
        await authProvider.loginWithUsernameAndPassword(
          username: id,
          password: password,
        );
      } else {
        await authProvider.loginWithEmailAndPassword(
          email: id,
          password: password,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(); // Return to previous screen upon success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully logged in!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.registerWithEmailAndPassword(
        email: _regEmailController.text.trim(),
        password: _regPasswordController.text,
        username: _regUsernameController.text.trim(),
        fullName: _regFullNameController.text.trim(),
        gender: _selectedGender,
        country: _selectedCountry,
        profilePictureUrl: _selectedProfilePicUrl,
      );
      if (mounted) {
        Navigator.of(context).pop(); // Return to previous screen upon success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Welcome to FinalRep.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: SvgPicture.asset(
          'assets/finalrep_icon.svg',
          height: 28,
          colorFilter: const ColorFilter.mode(
            Color(0xFFE94E1B),
            BlendMode.srcIn,
          ),
        ),
        centerTitle: true,
        leading: widget.isInline
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tabs Header
                    TabBar(
                      controller: _tabController,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      indicatorColor: theme.colorScheme.primary,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'LOGIN'),
                        Tab(text: 'REGISTER'),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Forms Content
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: SizedBox(
                        height: _tabController.index == 0 ? 460 : 700,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildLoginForm(theme, authProvider),
                            _buildRegisterForm(theme, authProvider),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme, AuthProvider authProvider) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Login Sub-toggle (Email vs Username)
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Email'),
                icon: Icon(Icons.email_outlined, size: 16),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Username'),
                icon: Icon(Icons.person_outline, size: 16),
              ),
            ],
            selected: {_isUsernameLogin},
            onSelectionChanged: (val) {
              setState(() {
                _isUsernameLogin = val.first;
                _loginIdController.clear();
              });
            },
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: theme.colorScheme.primaryContainer,
              selectedForegroundColor: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),

          // ID Field
          TextFormField(
            controller: _loginIdController,
            decoration: InputDecoration(
              labelText: _isUsernameLogin ? 'Username' : 'Email Address',
              prefixIcon: Icon(
                _isUsernameLogin ? Icons.person_outline : Icons.email_outlined,
              ),
            ),
            keyboardType: _isUsernameLogin
                ? TextInputType.text
                : TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return _isUsernameLogin
                    ? 'Please enter your username'
                    : 'Please enter your email';
              }
              if (!_isUsernameLogin && !value.contains('@')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _obscureLoginPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLoginPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscureLoginPassword = !_obscureLoginPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Action Button
          ElevatedButton(
            onPressed: authProvider.isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: authProvider.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'SIGN IN',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
          ),
          const SizedBox(height: 24),

          // SSO Divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: theme.colorScheme.outlineVariant,
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR CONTINUE WITH',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: theme.colorScheme.outlineVariant,
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // SSO and Passkey Buttons (Deferred/Disabled with Roadmap marker)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRoadmapSSOButton(
                icon: Icons.fingerprint,
                label: 'Passkey',
                theme: theme,
              ),
              _buildRoadmapSSOButton(
                icon: Icons.g_mobiledata,
                label: 'Google',
                theme: theme,
              ),
              _buildRoadmapSSOButton(
                icon: Icons.facebook,
                label: 'Meta',
                theme: theme,
              ),
              _buildRoadmapSSOButton(
                icon: Icons.apple,
                label: 'Apple',
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(ThemeData theme, AuthProvider authProvider) {
    return Form(
      key: _registerFormKey,
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Username
          TextFormField(
            controller: _regUsernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please choose a username';
              }
              if (value.trim().length < 3) {
                return 'Username must be at least 3 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Full Name
          TextFormField(
            controller: _regFullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Email
          TextFormField(
            controller: _regEmailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Password
          TextFormField(
            controller: _regPasswordController,
            obscureText: _obscureRegPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureRegPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscureRegPassword = !_obscureRegPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please choose a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Gender
          Text(
            'Gender',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.people_outline),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _genders.map((g) {
              return DropdownMenuItem(value: g, child: Text(g));
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedGender = val;
              });
            },
          ),
          const SizedBox(height: 16),

          // Country
          Text(
            'Country',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedCountry,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.public),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _countries.map((c) {
              return DropdownMenuItem(value: c, child: Text(c));
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedCountry = val;
              });
            },
          ),
          const SizedBox(height: 16),

          // Preset Avatars picker
          Text(
            'Profile Avatar (Optional)',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _presetAvatars.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                final url = _presetAvatars[idx];
                final isSelected = _selectedProfilePicUrl == url;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedProfilePicUrl = isSelected ? null : url;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(url),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          ElevatedButton(
            onPressed: authProvider.isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: authProvider.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'CREATE ACCOUNT',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapSSOButton({
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    return Tooltip(
      message: '$label (Future Roadmap - Coming Soon)',
      triggerMode: TooltipTriggerMode.tap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: Icon(icon, size: 28),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label integration is on our roadmap for a future release!'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule,
                size: 8,
                color: Colors.black87,
              ),
            ),
          )
        ],
      ),
    );
  }
}
