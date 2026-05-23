import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/auth_provider.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final bool isInline;
  const LoginPage({super.key, this.isInline = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginFormKey = GlobalKey<FormState>();

  // Login Controllers
  final _loginIdController = TextEditingController(); // email or username
  final _loginPasswordController = TextEditingController();
  bool _isUsernameLogin = false; // toggles email vs username login
  bool _obscureLoginPassword = true;

  @override
  void dispose() {
    _loginIdController.dispose();
    _loginPasswordController.dispose();
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
        if (!widget.isInline) {
          Navigator.of(context).pop(); // Return to previous screen upon success
        }
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

  void _showForgotPasswordDialog() {
    final theme = Theme.of(context);
    final isEmail = !_isUsernameLogin;
    final initialEmail = isEmail ? _loginIdController.text.trim() : '';
    final dialogInputController = TextEditingController(text: initialEmail);
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        bool localLoading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reset Password'),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Enter your username or email address and we will send you a password reset link.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('forgot_password_email_field'),
                      controller: dialogInputController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: 'Username or Email Address',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your username or email';
                        }
                        final trimmed = value.trim();
                        if (!trimmed.contains('@') && trimmed.length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: localLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: localLoading
                      ? null
                      : () async {
                          if (!dialogFormKey.currentState!.validate()) return;
                          setDialogState(() {
                            localLoading = true;
                          });
                          try {
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            final input = dialogInputController.text.trim();
                            final String email;
                            if (input.contains('@')) {
                              email = input;
                            } else {
                              email = await authProvider.resolveEmailFromUsername(input);
                            }
                            if (email.trim().isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
                              throw Exception('Invalid email address format: $email');
                            }
                            await authProvider.sendPasswordResetEmail(email);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password reset link sent to your email!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceAll('Exception: ', '')),
                                  backgroundColor: theme.colorScheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setDialogState(() {
                                localLoading = false;
                              });
                            }
                          }
                        },
                  child: localLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('SEND RESET LINK'),
                ),
              ],
            );
          },
        );
      },
    );
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
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _loginFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Welcome Back',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to access your profile',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

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
                        key: const Key('login_id_field'),
                        controller: _loginIdController,
                        inputFormatters: [
                          if (_isUsernameLogin)
                            TextInputFormatter.withFunction((oldValue, newValue) {
                              return newValue.copyWith(text: newValue.text.toLowerCase());
                            }),
                        ],
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
                        key: const Key('login_password_field'),
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
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

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

                      // Navigation to Register Page
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (widget.isInline) {
                                // If inline, push full screen RegisterPage
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    settings: const RouteSettings(name: '/register'),
                                    builder: (_) => const RegisterPage(),
                                  ),
                                );
                              } else {
                                // If already pushing pages, push replacement or push new page
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    settings: const RouteSettings(name: '/register'),
                                    builder: (_) => const RegisterPage(),
                                  ),
                                );
                              }
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Text(
                                'Create one',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFFE94E1B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
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

                      // SSO and Passkey Buttons
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
                ),
              ),
            ),
          ),
        ),
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
