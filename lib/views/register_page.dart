import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  final bool isInline;
  const RegisterPage({super.key, this.isInline = false});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int _currentStep = 0; // 0 = Account, 1 = Details, 2 = Avatar
  final int _totalSteps = 3;
  bool _isCheckingAvailability = false;

  // Form Keys for individual step validation
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  // Controllers
  final _regUsernameController = TextEditingController();
  final _regFullNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  bool _obscureRegPassword = true;

  // Selected values
  String? _selectedGender = 'Male';
  String? _selectedCountry = 'Germany';

  // Custom avatar upload variables
  Uint8List? _customAvatarBytes;
  String? _customAvatarExtension;
  String? _customAvatarName;

  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
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
    _regPasswordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _regPasswordController.removeListener(_onPasswordChanged);
    _regUsernameController.dispose();
    _regFullNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      // Rebuild to update password strength/rules
    });
  }

  bool get _hasMinLength => _regPasswordController.text.length >= 8;
  bool get _hasUppercase =>
      _regPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase =>
      _regPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigits => _regPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar => _regPasswordController.text.contains(
    RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:\x27",./<>?]'),
  );

  bool get _isPasswordValid =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasDigits &&
      _hasSpecialChar;

  int get _rulesMetCount {
    int count = 0;
    if (_hasMinLength) count++;
    if (_hasUppercase) count++;
    if (_hasLowercase) count++;
    if (_hasDigits) count++;
    if (_hasSpecialChar) count++;
    return count;
  }

  Future<void> _pickCustomAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        final extension = file.extension;

        if (bytes != null) {
          setState(() {
            _customAvatarBytes = bytes;
            _customAvatarExtension = extension;
            _customAvatarName = file.name;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  void _nextStep() async {
    if (_currentStep == 0) {
      if (!_step1FormKey.currentState!.validate()) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final username = _regUsernameController.text.trim().toLowerCase();
      final email = _regEmailController.text.trim();

      setState(() {
        _isCheckingAvailability = true;
      });

      try {
        final uTaken = await authProvider.isUsernameTaken(username);
        if (uTaken) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Username is already taken'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }

        final eTaken = await authProvider.isEmailTaken(email);
        if (eTaken) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email is already taken'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error checking availability: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      } finally {
        if (mounted) {
          setState(() {
            _isCheckingAvailability = false;
          });
        }
      }
    } else if (_currentStep == 1) {
      if (!_step2FormKey.currentState!.validate()) return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _handleRegister() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.registerWithEmailAndPassword(
        email: _regEmailController.text.trim(),
        password: _regPasswordController.text,
        username: _regUsernameController.text.trim(),
        fullName: _regFullNameController.text.trim(),
        gender: _selectedGender,
        country: _selectedCountry,
        profilePictureUrl: null,
        customAvatarBytes: _customAvatarBytes,
        customAvatarExtension: _customAvatarExtension,
      );
      if (mounted) {
        if (!widget.isInline) {
          // If we pushed RegisterPage, we pop it (or pop twice to return to source if needed).
          // Since registration automatically logs in, popping once returns to search feed.
          Navigator.of(context).pop();
        }
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
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create Account',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Custom Premium Stepper
                    _buildStepper(theme),
                    const SizedBox(height: 32),

                    // Form Steps
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _buildCurrentStepForm(theme),
                    ),
                    const SizedBox(height: 32),

                    // Navigation Buttons (Next, Back, Submit)
                    _buildNavigationButtons(theme, authProvider),
                    const SizedBox(height: 24),

                    // Link back to Login
                    if (_currentStep == 0)
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (widget.isInline) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    settings: const RouteSettings(
                                      name: '/login',
                                    ),
                                    builder: (_) => const LoginPage(),
                                  ),
                                );
                              } else {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    settings: const RouteSettings(
                                      name: '/login',
                                    ),
                                    builder: (_) => const LoginPage(),
                                  ),
                                );
                              }
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Text(
                                'Sign In',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFFE94E1B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
    );
  }

  Widget _buildStepper(ThemeData theme) {
    return Row(
      children: [
        _buildStepIndicator(0, 'Account', theme),
        _buildStepConnector(0, theme),
        _buildStepIndicator(1, 'Details', theme),
        _buildStepConnector(1, theme),
        _buildStepIndicator(2, 'Avatar', theme),
      ],
    );
  }

  Widget _buildStepIndicator(int stepIndex, String label, ThemeData theme) {
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;

    Color circleColor;
    Color textColor;
    Widget child;

    if (isCompleted) {
      circleColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
      child = const Icon(Icons.check, size: 16, color: Colors.white);
    } else if (isActive) {
      circleColor = const Color(0xFFE94E1B); // Brand color
      textColor = Colors.white;
      child = Text(
        '${stepIndex + 1}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      );
    } else {
      circleColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurfaceVariant;
      child = Text(
        '${stepIndex + 1}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: textColor,
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          CircleAvatar(radius: 16, backgroundColor: circleColor, child: child),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isActive || isCompleted
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontWeight: isActive || isCompleted
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int afterStepIndex, ThemeData theme) {
    final isCompleted = _currentStep > afterStepIndex;
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isCompleted
          ? theme.colorScheme.primary
          : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }

  Widget _buildCurrentStepForm(ThemeData theme) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Form(theme);
      case 1:
        return _buildStep2Form(theme);
      case 2:
        return _buildStep3Form(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Form(ThemeData theme) {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Username
          TextFormField(
            key: const Key('register_username_field'),
            controller: _regUsernameController,
            maxLength: 15,
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                return newValue.copyWith(text: newValue.text.toLowerCase());
              }),
            ],
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
          const SizedBox(height: 16),

          // Email
          TextFormField(
            key: const Key('register_email_field'),
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
          const SizedBox(height: 16),

          // Password
          TextFormField(
            key: const Key('register_password_field'),
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
              if (!_isPasswordValid) {
                return 'Password does not meet all safety rules';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildPasswordStrengthBar(theme),
          const SizedBox(height: 16),
          _buildPasswordRulesChecklist(theme),
        ],
      ),
    );
  }

  Widget _buildStep2Form(ThemeData theme) {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Full Name
          TextFormField(
            key: const Key('register_fullname_field'),
            controller: _regFullNameController,
            maxLength: 30,
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
        ],
      ),
    );
  }

  Widget _buildStep3Form(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Profile Picture',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (_customAvatarBytes != null) ...[
          // Custom image preview
          Center(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE94E1B),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 56,
                    backgroundImage: MemoryImage(_customAvatarBytes!),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _customAvatarBytes = null;
                          _customAvatarExtension = null;
                          _customAvatarName = null;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _customAvatarName ?? 'Custom photo selected',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _pickCustomAvatar,
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('Change Photo'),
            ),
          ),
        ] else ...[
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.add_a_photo_outlined,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Upload a profile picture to customize your profile (optional)',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: _pickCustomAvatar,
              icon: const Icon(Icons.upload_file),
              label: const Text('UPLOAD CUSTOM PHOTO'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordStrengthBar(ThemeData theme) {
    final count = _rulesMetCount;
    Color barColor;
    String strengthText;
    int segmentsFilled;

    if (count == 0) {
      barColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.3);
      strengthText = 'None';
      segmentsFilled = 0;
    } else if (count <= 2) {
      barColor = const Color(0xFFEF5350); // Red
      strengthText = 'Weak';
      segmentsFilled = 1;
    } else if (count <= 4) {
      barColor = const Color(0xFFFFB300); // Yellow
      strengthText = 'Medium';
      segmentsFilled = 2;
    } else {
      barColor = const Color(0xFF4CAF50); // Green
      strengthText = 'Strong';
      segmentsFilled = 3;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password Strength:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              strengthText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: barColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(3, (index) {
            final isFilled = index < segmentsFilled;
            return Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: index < 2 ? 4.0 : 0.0),
                decoration: BoxDecoration(
                  color: isFilled
                      ? barColor
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPasswordRulesChecklist(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPasswordRule('Minimum 8 characters', _hasMinLength, theme),
        _buildPasswordRule(
          'At least one uppercase letter (A-Z)',
          _hasUppercase,
          theme,
        ),
        _buildPasswordRule(
          'At least one lowercase letter (a-z)',
          _hasLowercase,
          theme,
        ),
        _buildPasswordRule(
          'At least one numeric digit (0-9)',
          _hasDigits,
          theme,
        ),
        _buildPasswordRule(
          'At least one special character (!@#\$%^&*)',
          _hasSpecialChar,
          theme,
        ),
      ],
    );
  }

  Widget _buildPasswordRule(String label, bool isMet, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          isMet
              ? const Icon(Icons.check, color: Color(0xFF4CAF50), size: 16)
              : Icon(
                  Icons.fiber_manual_record,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  size: 8,
                ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isMet
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme, AuthProvider authProvider) {
    final isLastStep = _currentStep == _totalSteps - 1;
    final isFirstStep = _currentStep == 0;

    return Row(
      children: [
        if (!isFirstStep) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: authProvider.isLoading || _isCheckingAvailability
                  ? null
                  : _prevStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('BACK'),
            ),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed:
                authProvider.isLoading ||
                    _isCheckingAvailability ||
                    (isFirstStep && !_isPasswordValid)
                ? null
                : (isLastStep ? _handleRegister : _nextStep),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: authProvider.isLoading || _isCheckingAvailability
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    isLastStep ? 'CREATE ACCOUNT' : 'NEXT',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
