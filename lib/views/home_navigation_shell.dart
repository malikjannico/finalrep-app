import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';
import '../router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/competition.dart';
import '../providers/competition_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/image_url_resolver.dart';
import 'competition_detail_page.dart';
import 'mobile_search_page.dart';
import 'world_map_view.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'admin_dashboard_page.dart';
import 'association_management_page.dart';
import 'association_library_page.dart';
import 'competition_library_page.dart';
import 'competition_management_page.dart';
import 'rankings_page.dart';
import 'association_detail_page.dart';
import 'competition_creation_page.dart';
import 'association_creation_page.dart';
import 'user_library_page.dart';
import '../widgets/filter_widgets.dart';

class NavigationItem {
  final String label;
  final IconData icon;
  NavigationItem({required this.label, required this.icon});
}

class HomeNavigationShell extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool? isDarkMode;
  final String? initialPath;
  final String? initialQuery;
  final String? initialScope;

  const HomeNavigationShell({
    super.key,
    this.onToggleTheme,
    this.isDarkMode,
    this.initialPath,
    this.initialQuery,
    this.initialScope,
  });

  @override
  State<HomeNavigationShell> createState() => _HomeNavigationShellState();
}

class _HomeNavigationShellState extends State<HomeNavigationShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<AdminDashboardPageState>? _adminDashboardKey = GlobalKey<AdminDashboardPageState>();
  late CompetitionProvider _provider;
  int _currentTabIndex = 0;
  String _currentTabCollection = 'All';

  bool get _hasGoRouter {
    try {
      GoRouter.of(context);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _safeMutateProvider(VoidCallback mutation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        mutation();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<CompetitionProvider>(context, listen: false);
    _provider.addListener(_onProviderChanged);

    _parseRoute(widget.initialPath ?? '/');

    if (widget.initialQuery != null) {
      final scope = widget.initialScope == 'associations'
          ? SearchScope.associations
          : (widget.initialScope == 'users' ? SearchScope.users : SearchScope.competitions);
      _safeMutateProvider(() => _provider.setSearchScopeAndQuery(scope, widget.initialQuery!));
    }
  }

  @override
  void didUpdateWidget(HomeNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPath != oldWidget.initialPath && widget.initialPath != null) {
      _parseRoute(widget.initialPath!);
    }
  }

  void _parseRoute(String path) {
    final uri = Uri.parse(path);
    final segments = uri.pathSegments;

    if (path.startsWith('/admin')) {
      _currentTabCollection = 'Administration';
      _safeMutateProvider(() => _provider.clearSelections());
      if (path.startsWith('/admin/configuration')) {
        _currentTabIndex = 1;
      } else if (path.startsWith('/admin/users')) {
        _currentTabIndex = 2;
      } else {
        _currentTabIndex = 0;
      }
    } else if (path.startsWith('/management')) {
      _currentTabCollection = 'Management';
      _safeMutateProvider(() => _provider.clearSelections());
      _currentTabIndex = path.contains('associations') ? 1 : 0;
    } else {
      _currentTabCollection = 'All';
      if (path == '/associations') {
        _currentTabIndex = 1;
        _safeMutateProvider(() {
          _provider.setSearchScope(SearchScope.associations);
          _provider.clearSelections();
        });
      } else if (path == '/users') {
        _currentTabIndex = -1;
        _safeMutateProvider(() {
          _provider.setSearchScope(SearchScope.users);
          _provider.clearSelections();
        });
      } else if (path == '/rankings') {
        _currentTabIndex = 2;
        _safeMutateProvider(() => _provider.clearSelections());
      } else if (path == '/profile') {
        _currentTabIndex = 3;
        _safeMutateProvider(() => _provider.clearSelections());
      } else if (path.startsWith('/associations/')) {
        _currentTabIndex = 1;
        final id = segments.length >= 2 ? segments[1] : null;
        if (id != null) {
          _safeMutateProvider(() {
            _provider.setSearchScope(SearchScope.associations);
            _provider.selectAssociation(id);
          });
        }
      } else if (path.startsWith('/users/')) {
        _currentTabIndex = -1;
        final username = segments.length >= 2 ? segments[1] : null;
        if (username != null) {
          _safeMutateProvider(() {
            _provider.setSearchScope(SearchScope.users);
            _provider.selectProfile(username: username);
          });
        }
      } else {
        _currentTabIndex = 0;
        _safeMutateProvider(() {
          _provider.setSearchScope(SearchScope.competitions);
          _provider.clearSelections();
        });
      }
    }
  }

  bool get _isDark {
    if (widget.isDarkMode != null) {
      return widget.isDarkMode!;
    }
    return Provider.of<ThemeProvider>(context).isDarkMode;
  }

  void _toggleTheme() {
    if (widget.onToggleTheme != null) {
      widget.onToggleTheme!();
    } else {
      Provider.of<ThemeProvider>(context, listen: false).toggleTheme(context);
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  String? _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return ImageUrlResolver.resolve(context, path);
  }

  void _onProviderChanged() {
    if (!mounted) return;

    if (_currentTabCollection == 'All') {
      if (_provider.searchScope == SearchScope.competitions) {
        if (_currentTabIndex == 0 || _currentTabIndex == 1 || _currentTabIndex == -1 || _provider.query.isNotEmpty) {
          _currentTabIndex = 0;
        }
      } else if (_provider.searchScope == SearchScope.associations) {
        if (_currentTabIndex == 0 || _currentTabIndex == 1 || _currentTabIndex == -1 || _provider.query.isNotEmpty) {
          _currentTabIndex = 1;
        }
      } else if (_provider.searchScope == SearchScope.users) {
        if (_currentTabIndex == 0 || _currentTabIndex == 1 || _currentTabIndex == -1 || _provider.query.isNotEmpty) {
          _currentTabIndex = -1;
        }
      }
    }

    if (!_hasGoRouter) return;

    try {
      final state = GoRouterState.of(context);
      final isDesktop = MediaQuery.of(context).size.width >= 900;
      if (_currentTabCollection == 'All' && isDesktop && _provider.selectedAssociationId != null) {
        final target = '/associations/${_provider.selectedAssociationId}';
        if (state.matchedLocation != target) {
          context.go(target);
        }
      } else if (_currentTabCollection == 'All' && isDesktop && _provider.selectedProfileUsername != null) {
        final target = '/users/${_provider.selectedProfileUsername}';
        if (state.matchedLocation != target) {
          context.go(target);
        }
      } else if (kIsWeb) {
        final currentUri = state.uri;
        final currentPath = currentUri.path;
        if (currentPath.startsWith('/settings') ||
            currentPath.startsWith('/admin') ||
            currentPath.startsWith('/management')) {
          return;
        }
        final matchedLoc = state.matchedLocation;
        if (matchedLoc == '/' ||
            matchedLoc == '/competitions' ||
            matchedLoc == '/associations' ||
            matchedLoc == '/users') {
          final currentLoc = currentUri.toString();
          
          String path = matchedLoc;
          if (_provider.query.isNotEmpty) {
            if (_provider.searchScope == SearchScope.competitions) {
              path = '/competitions';
            } else if (_provider.searchScope == SearchScope.associations) {
              path = '/associations';
            } else if (_provider.searchScope == SearchScope.users) {
              path = '/users';
            }
          } else {
            if (matchedLoc == '/competitions') {
              path = '/';
            }
          }

          final targetLoc = Uri(
            path: path,
            queryParameters: _provider.query.isNotEmpty
                ? {'q': _provider.query}
                : null,
          ).toString();
          if (currentLoc != targetLoc) {
            context.go(targetLoc);
          }
        }
      }
    } catch (_) {
      // Safely ignore if GoRouterState is not available in the current context
    }
  }

  void _handleTabNavigation(int index, String label) {
    _provider.clearSelections();
    _provider.setQuery('');

    if (_currentTabCollection == 'Management') {
      if (_hasGoRouter) {
        if (index == 0) {
          context.go('/management/competitions');
        } else if (index == 1) {
          context.go('/management/associations');
        }
      }
      setState(() {
        _currentTabIndex = index;
      });
      return;
    }

    if (_currentTabCollection == 'Administration') {
      if (_hasGoRouter) {
        if (index == 0) {
          context.go('/admin/requests');
        } else if (index == 1) {
          _adminDashboardKey?.currentState?.closeConfigSubpage();
          context.go('/admin/configuration');
        } else if (index == 2) {
          _adminDashboardKey?.currentState?.closeUserManagementSubpage();
          context.go('/admin/users');
        }
      }
      setState(() {
        _currentTabIndex = index;
      });
      return;
    }

    // 'All' collection
    if (_hasGoRouter) {
      if (label == 'Competitions' || label == 'My Competitions') {
        _provider.setSearchScopeAndQuery(SearchScope.competitions, '');
        context.go('/');
      } else if (label == 'Associations' || label == 'My Associations') {
        _provider.setSearchScopeAndQuery(SearchScope.associations, '');
        context.go('/associations');
      } else if (label == 'Users') {
        _provider.setSearchScopeAndQuery(SearchScope.users, '');
        context.go('/users');
      } else if (label == 'Rankings') {
        context.go('/rankings');
      } else if (label == 'Profile' || label == 'My Profile') {
        context.go('/profile');
      }
    } else {
      if (label == 'Competitions' || label == 'My Competitions') {
        _provider.setSearchScopeAndQuery(SearchScope.competitions, '');
      } else if (label == 'Associations' || label == 'My Associations') {
        _provider.setSearchScopeAndQuery(SearchScope.associations, '');
      } else if (label == 'Users') {
        _provider.setSearchScopeAndQuery(SearchScope.users, '');
      }
    }

    setState(() {
      _currentTabIndex = index;
    });
  }

  void _syncUrlToCurrentTab() {
    if (!_hasGoRouter) return;
    if (!kIsWeb) return;
    String path = '/';
    if (_currentTabCollection == 'Management') {
      if (_currentTabIndex == 0) {
        path = '/management/competitions';
      } else if (_currentTabIndex == 1) {
        final uri = Uri.parse(widget.initialPath ?? '');
        final segments = uri.pathSegments;
        final managementAssocId = (widget.initialPath?.startsWith('/management/associations/') == true && segments.length >= 3)
            ? segments[2]
            : null;
        final initialTab = (widget.initialPath?.startsWith('/management/associations/') == true && segments.length >= 4)
            ? segments[3]
            : null;
        path = managementAssocId != null
            ? (initialTab != null ? '/management/associations/$managementAssocId/$initialTab' : '/management/associations/$managementAssocId')
            : '/management/associations';
      }
    } else if (_currentTabCollection == 'Administration') {
      if (_currentTabIndex == 0) {
        path = '/admin/requests';
      } else if (_currentTabIndex == 1) {
        path = '/admin/configuration';
      } else if (_currentTabIndex == 2) {
        path = '/admin/users';
      }
    } else {
      if (_currentTabIndex == 0) {
        path = '/';
      } else if (_currentTabIndex == 1) {
        path = '/associations';
      } else if (_currentTabIndex == -1) {
        path = '/users';
      } else if (_currentTabIndex == 2) {
        path = '/rankings';
      } else if (_currentTabIndex == 3) {
        path = '/profile';
      }
    }
    context.go(path);
  }

  void _showResetPasswordDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    final theme = Theme.of(context);
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool obscureNew = true;
    bool obscureConfirm = true;
    bool dialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final pass = newPasswordController.text;
            final hasMinLength = pass.length >= 8;
            final hasUppercase = pass.contains(RegExp(r'[A-Z]'));
            final hasLowercase = pass.contains(RegExp(r'[a-z]'));
            final hasDigits = pass.contains(RegExp(r'[0-9]'));
            final hasSpecialChar = pass.contains(
              RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:\x27",./<>?]'),
            );

            final isPasswordValid =
                hasMinLength &&
                hasUppercase &&
                hasLowercase &&
                hasDigits &&
                hasSpecialChar;

            int rulesMet = 0;
            if (hasMinLength) rulesMet++;
            if (hasUppercase) rulesMet++;
            if (hasLowercase) rulesMet++;
            if (hasDigits) rulesMet++;
            if (hasSpecialChar) rulesMet++;

            Color barColor;
            String strengthText;
            int segmentsFilled;

            if (rulesMet == 0) {
              barColor = theme.colorScheme.outlineVariant.withAlpha(76);
              strengthText = 'None';
              segmentsFilled = 0;
            } else if (rulesMet <= 2) {
              barColor = const Color(0xFFEF5350);
              strengthText = 'Weak';
              segmentsFilled = 1;
            } else if (rulesMet <= 4) {
              barColor = const Color(0xFFFFB300);
              strengthText = 'Medium';
              segmentsFilled = 2;
            } else {
              barColor = const Color(0xFF4CAF50);
              strengthText = 'Strong';
              segmentsFilled = 3;
            }

            Widget buildRuleRow(String text, bool met) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(
                      met ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: met
                          ? const Color(0xFF4CAF50)
                          : theme.colorScheme.onSurfaceVariant.withAlpha(128),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: met
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant.withAlpha(
                                  178,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: const Text('Reset Your Password'),
              content: dialogLoading
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Please enter a new secure password for your account.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('reset_password_new_field'),
                              controller: newPasswordController,
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                prefixIcon: const Icon(
                                  Icons.lock_reset_outlined,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureNew
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      obscureNew = !obscureNew;
                                    });
                                  },
                                ),
                              ),
                              obscureText: obscureNew,
                              onChanged: (_) {
                                setDialogState(() {});
                              },
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Please enter a new password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('reset_password_confirm_field'),
                              controller: confirmPasswordController,
                              decoration: InputDecoration(
                                labelText: 'Confirm New Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureConfirm
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      obscureConfirm = !obscureConfirm;
                                    });
                                  },
                                ),
                              ),
                              obscureText: obscureConfirm,
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (val != newPasswordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Security Requirements:',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            buildRuleRow('At least 8 characters', hasMinLength),
                            buildRuleRow(
                              'At least 1 uppercase letter (A-Z)',
                              hasUppercase,
                            ),
                            buildRuleRow(
                              'At least 1 lowercase letter (a-z)',
                              hasLowercase,
                            ),
                            buildRuleRow('At least 1 number (0-9)', hasDigits),
                            buildRuleRow(
                              'At least 1 special character (e.g. !@#\$%^&*)',
                              hasSpecialChar,
                            ),
                            const SizedBox(height: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Password Strength:',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    Text(
                                      strengthText,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: barColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: List.generate(3, (index) {
                                    final isFilled = index < segmentsFilled;
                                    return Expanded(
                                      child: Container(
                                        height: 6,
                                        margin: EdgeInsets.only(
                                          right: index < 2 ? 6.0 : 0.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isFilled
                                              ? barColor
                                              : theme.colorScheme.outlineVariant
                                                    .withAlpha(50),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: dialogLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: dialogLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          if (!isPasswordValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Password does not meet all security rules.',
                                ),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                            return;
                          }
                          setDialogState(() {
                            dialogLoading = true;
                          });
                          try {
                            await authProvider.changePassword(
                              newPasswordController.text,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Password updated successfully!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to update password: $e',
                                  ),
                                  backgroundColor: theme.colorScheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setDialogState(() {
                                dialogLoading = false;
                              });
                            }
                          }
                        },
                  child: const Text('UPDATE PASSWORD'),
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
    final provider = Provider.of<CompetitionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Automatically switch back to competitions tab if user logs out
    if (!authProvider.isAuthenticated && !authProvider.isLoading) {
      _currentTabCollection = 'All';
      if (_currentTabIndex >= 3) {
        _currentTabIndex = 0;
      }
    }

    if (authProvider.isPasswordRecoveryActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          authProvider.clearPasswordRecovery();
          _showResetPasswordDialog(context, authProvider);
        }
      });
    }

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final isTablet = size.width >= 600 && size.width < 900;
    final navItems = _getNavigationItems(authProvider);
    final showProfileTab = !isDesktop && _currentTabCollection == 'All' && _currentTabIndex == 3;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.colorScheme.surface,
      drawer: showProfileTab
          ? null
          : _buildNavigationDrawer(context, provider, theme),
      endDrawer: _currentTabIndex == 0
          ? _buildFiltersDrawer(context, provider, theme)
          : null,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Responsive Top Header
            if (!showProfileTab)
              _buildTopHeader(context, provider, theme, isDesktop, isTablet),

            // Sub-navigation bar for desktop view
            if (isDesktop) _buildDesktopSubNavBar(provider, theme),

            // Main View Content
            Expanded(
              child: _buildActiveTabContent(
                context,
                provider,
                authProvider,
                theme,
                isDesktop,
                isTablet,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: !isDesktop
          ? NavigationBar(
              selectedIndex: _currentTabIndex.clamp(
                0,
                navItems.isEmpty ? 0 : navItems.length - 1,
              ),
              onDestinationSelected: (index) {
                final item = navItems[index];
                _handleTabNavigation(index, item.label);
              },
              destinations: navItems.map((item) {
                return NavigationDestination(
                  icon: Icon(item.icon),
                  label: item.label,
                );
              }).toList(),
            )
          : null,
      floatingActionButton: !isDesktop && _currentTabCollection == 'Management'
          ? (_currentTabIndex == 0
              ? (authProvider.isAdmin || authProvider.currentUserProfile?.isCompetitionCreator == true
                  ? FloatingActionButton.extended(
                      key: const Key('create_competition_fab'),
                      backgroundColor: const Color(0xFFE94E1B),
                      foregroundColor: Colors.white,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CompetitionCreationPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Competition'),
                    )
                  : null)
              : (_currentTabIndex == 1
                  ? (authProvider.isAdmin || authProvider.currentUserProfile?.isAssociationCreator == true
                      ? FloatingActionButton.extended(
                          key: const Key('create_association_fab'),
                          backgroundColor: const Color(0xFFE94E1B),
                          foregroundColor: Colors.white,
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AssociationCreationPage(),
                              ),
                            );
                            provider.fetchAssociations();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Association'),
                        )
                      : null)
                  : null))
          : null,
    );
  }

  Widget _buildActiveTabContent(
    BuildContext context,
    CompetitionProvider provider,
    AuthProvider authProvider,
    ThemeData theme,
    bool isDesktop,
    bool isTablet,
  ) {
    if (isDesktop && _currentTabCollection == 'All') {
      if (provider.selectedAssociationId != null) {
        return AssociationDetailPage(
          associationId: provider.selectedAssociationId!,
          isInline: true,
        );
      }
      if (provider.selectedProfileId != null || provider.selectedProfileUsername != null) {
        return ProfilePage(
          userId: provider.selectedProfileId,
          username: provider.selectedProfileUsername,
          isInline: true,
          profileRepository: provider.profileRepository,
        );
      }
    }

    if (_currentTabCollection == 'Management') {
      final uri = Uri.parse(widget.initialPath ?? '');
      final segments = uri.pathSegments;
      final managementAssocId = (widget.initialPath?.startsWith('/management/associations/') == true && segments.length >= 3)
          ? segments[2]
          : null;
      final initialTab = (widget.initialPath?.startsWith('/management/associations/') == true && segments.length >= 4)
          ? segments[3]
          : null;
      return IndexedStack(
        index: _currentTabIndex.clamp(0, 1),
        children: [
          const CompetitionManagementPage(isInline: true),
          AssociationManagementPage(
            key: ValueKey('assoc-manage-$managementAssocId'),
            isInline: true,
            associationId: managementAssocId,
            initialTab: initialTab,
          ),
        ],
      );
    } else if (_currentTabCollection == 'Administration') {
      final uri = Uri.parse(widget.initialPath ?? '');
      final segments = uri.pathSegments;
      final selectedUsername = (widget.initialPath?.startsWith('/admin/users/') == true && segments.length >= 3)
          ? segments[2]
          : null;
      final selectedConfigSubpage = (widget.initialPath?.startsWith('/admin/configuration/') == true && segments.length >= 3)
          ? segments[2]
          : null;

      return AdminDashboardPage(
        key: _adminDashboardKey,
        isInline: true,
        initialTabIndex: _currentTabIndex.clamp(0, 2),
        selectedUsername: selectedUsername,
        selectedConfigSubpage: selectedConfigSubpage,
        onTabIndexChanged: (index) {
          setState(() {
            _currentTabIndex = index;
          });
          _syncUrlToCurrentTab();
        },
      );
    } else {
      // 'All' tab collection
      return IndexedStack(
        index: _currentTabIndex == -1 ? 4 : _currentTabIndex.clamp(0, 3),
        children: [
          const CompetitionLibraryPage(),
          const AssociationLibraryPage(isInline: true),
          const RankingsPage(showAppBar: false),
          authProvider.isAuthenticated
              ? const ProfilePage(isInline: true)
              : const LoginPage(isInline: true),
          const UserLibraryPage(isInline: true),
        ],
      );
    }
  }



  Widget _buildTopHeader(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
    bool isTablet,
  ) {
    final authProvider = Provider.of<AuthProvider>(context);
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(
        left: isDesktop ? 24.0 : 8.0,
        right: isDesktop ? 24.0 : 8.0,
        top: 12.0 + topPadding,
        bottom: 12.0,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: isDesktop
          ? Stack(
              alignment: Alignment.center,
              children: [
                // Brand Icon
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      provider.setSearchScopeAndQuery(
                        SearchScope.competitions,
                        '',
                      );
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: SvgPicture.asset(
                        'assets/finalrep_icon.svg',
                        height: 28,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFE94E1B),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
                // Centered Search bar
                const SizedBox(width: 440, child: DesktopSearchBar()),
                // Theme toggle and profile on desktop right
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!authProvider.isAuthenticated) ...[
                        IconButton(
                          icon: Icon(
                            _isDark
                                ? Icons.light_mode
                                : Icons.dark_mode,
                            color: theme.colorScheme.onSurface,
                          ),
                          onPressed: _toggleTheme,
                          tooltip: 'Toggle Theme',
                        ),
                        const SizedBox(width: 12),
                      ],
                      _buildProfileHeaderButton(context, theme),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                // Hamburger menu on mobile left, replaced by back arrow when search query is active
                IconButton(
                  icon: Icon(provider.query.isNotEmpty ? Icons.arrow_back : Icons.menu),
                  onPressed: () {
                    if (provider.query.isNotEmpty) {
                      provider.setSearchScopeAndQuery(provider.searchScope, '');
                    } else {
                      _scaffoldKey.currentState?.openDrawer();
                    }
                  },
                ),
                const Spacer(),
                // Brand Icon
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    provider.setSearchScopeAndQuery(
                      SearchScope.competitions,
                      '',
                    );
                    try {
                      context.go('/');
                    } catch (_) {}
                  },
                  child: SvgPicture.asset(
                    'assets/finalrep_icon.svg',
                    height: 28,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFFE94E1B),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const Spacer(),
                // Mobile search icon on right
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MobileSearchPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildProfileHeaderButton(BuildContext context, ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.isAuthenticated) {
      final user = authProvider.currentUserProfile;
      final initials = user != null && user.fullName.isNotEmpty
          ? user.fullName
                .trim()
                .split(' ')
                .map((e) => e.isEmpty ? '' : e[0])
                .take(2)
                .join()
                .toUpperCase()
          : user?.username.isNotEmpty == true
          ? user!.username[0].toUpperCase()
          : '?';
      return PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'profile') {
            setState(() {
              _currentTabCollection = 'All';
              _currentTabIndex = 3;
            });
            _syncUrlToCurrentTab();
          } else if (value == 'settings') {
            _provider.setQuery('');
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
          } else if (value == 'logout') {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Log Out?'),
                content: const Text(
                  'Are you sure you want to log out of your session?',
                ),
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
              if (context.mounted) {
                _provider.setQuery('');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully.')),
                );
              }
            }
          }
        },
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'profile',
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 20,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                const Text('My Profile'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'settings',
            child: Row(
              children: [
                Icon(
                  Icons.settings_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                const Text('Settings'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                const Icon(Icons.logout, size: 20, color: Colors.redAccent),
                const SizedBox(width: 12),
                const Text(
                  'Log Out',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ],
            ),
          ),
        ],
        child: CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: _resolveImageUrl(user?.profilePictureUrl) != null
              ? NetworkImage(_resolveImageUrl(user!.profilePictureUrl)!)
              : null,
          child: user?.profilePictureUrl == null ||
                  user!.profilePictureUrl!.isEmpty
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                )
              : null,
        ),
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            key: const Key('desktop_signin_button'),
            onPressed: () {
              try {
                GoRouter.of(context);
                goRouter.push('/login');
              } catch (_) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/login'),
                    builder: (_) => const LoginPage(),
                  ),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Sign In', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            key: const Key('desktop_register_button'),
            onPressed: () {
              try {
                GoRouter.of(context);
                goRouter.push('/register');
              } catch (_) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/register'),
                    builder: (_) => const RegisterPage(),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE94E1B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Register',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildDesktopSubNavBar(CompetitionProvider provider, ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAuthenticated = authProvider.isAuthenticated;
    final user = authProvider.currentUserProfile;
    final bool hasManagement =
        user != null &&
        (user.isCompetitionCreator ||
            user.isAssociationCreator ||
            user.isAdmin);

    final navItems = _getNavigationItems(authProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (isAuthenticated && hasManagement) ...[
            _buildTabCollectionDropdown(context, authProvider, theme),
            const SizedBox(width: 16),
          ],
          ...navItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final bool isActive = _currentTabIndex == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildSubNavButton(
                label: item.label,
                isActive: isActive,
                onPressed: () => _handleTabNavigation(index, item.label),
                theme: theme,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubNavButton({
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive
              ? const Color(0xFFE94E1B)
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
  ) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserProfile;
    final bool hasManagement =
        user != null &&
        (user.isCompetitionCreator ||
            user.isAssociationCreator ||
            user.isAdmin);
    final navItems = _getNavigationItems(authProvider);
    final initials = user != null && user.fullName.isNotEmpty
        ? user.fullName
              .trim()
              .split(' ')
              .map((e) => e.isEmpty ? '' : e[0])
              .take(2)
              .join()
              .toUpperCase()
        : user?.username.isNotEmpty == true
        ? user!.username[0].toUpperCase()
        : '?';

    return Drawer(
      width: MediaQuery.of(context).size.width - 56.0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -200) {
            if (_scaffoldKey.currentState?.isDrawerOpen == true) {
              _scaffoldKey.currentState?.closeDrawer();
            }
          }
        },
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (authProvider.isAuthenticated && user != null) ...[
                GestureDetector(
                  onTap: () {
                    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                      _scaffoldKey.currentState?.closeDrawer();
                    }
                    try {
                      context.go('/profile');
                    } catch (_) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/profile'),
                          builder: (_) => const ProfilePage(),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          backgroundImage: _resolveImageUrl(user.profilePictureUrl) != null
                              ? NetworkImage(_resolveImageUrl(user.profilePictureUrl)!)
                              : null,
                          child: user.profilePictureUrl == null ||
                                  user.profilePictureUrl!.isEmpty
                              ? Text(
                                  initials,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.fullName,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${user.username}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 32.0,
                  ),
                  child: SvgPicture.asset(
                    'assets/finalrep_icon.svg',
                    height: 36,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFFE94E1B),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const Divider(height: 1),
              ],

              if (authProvider.isAuthenticated && hasManagement) ...[
                _buildTabCollectionDropdown(
                  context,
                  authProvider,
                  theme,
                  isDrawer: true,
                ),
              ],

              ...navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final bool isActive = _currentTabIndex == index;
                return _buildDrawerItem(
                  context: context,
                  icon: item.icon,
                  label: item.label,
                  isActive: isActive,
                  onTap: () {
                    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                      _scaffoldKey.currentState?.closeDrawer();
                    }
                    _handleTabNavigation(index, item.label);
                  },
                );
              }),
              if (_currentTabCollection == 'All' &&
                  authProvider.isAuthenticated) ...[
                _buildDrawerItem(
                  context: context,
                  icon: Icons.settings,
                  label: 'Settings',
                  isActive: false,
                  onTap: () {
                    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                      _scaffoldKey.currentState?.closeDrawer();
                    }
                    _provider.setQuery('');
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
              const Spacer(),
              if (authProvider.isAuthenticated) ...[
                const Divider(),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.logout,
                  label: 'Log Out',
                  isActive: false,
                  color: Colors.redAccent,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Log Out?'),
                        content: const Text(
                          'Are you sure you want to log out of your session?',
                        ),
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
                      if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                        _scaffoldKey.currentState?.closeDrawer();
                      }
                      await authProvider.logout();
                      if (context.mounted) {
                        _provider.setQuery('');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Logged out successfully.'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
              if (!authProvider.isAuthenticated) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('drawer_signin_button'),
                          onPressed: () {
                            if (_scaffoldKey.currentState?.isDrawerOpen ==
                                true) {
                              _scaffoldKey.currentState?.closeDrawer();
                            }
                            try {
                              GoRouter.of(context);
                              goRouter.push('/login');
                            } catch (_) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  settings: const RouteSettings(name: '/login'),
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.login, size: 16),
                          label: const Text('Sign In'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          key: const Key('drawer_register_button'),
                          onPressed: () {
                            if (_scaffoldKey.currentState?.isDrawerOpen ==
                                true) {
                              _scaffoldKey.currentState?.closeDrawer();
                            }
                            try {
                              GoRouter.of(context);
                              goRouter.push('/register');
                            } catch (_) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  settings: const RouteSettings(
                                    name: '/register',
                                  ),
                                  builder: (_) => const RegisterPage(),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.person_add, size: 16),
                          label: const Text('Register'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE94E1B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
              if (!authProvider.isAuthenticated)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Color Mode'),
                      IconButton(
                        icon: Icon(
                          _isDark
                              ? Icons.light_mode
                              : Icons.dark_mode,
                        ),
                        onPressed: () {
                          _toggleTheme();
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final defaultColor = isActive
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;
    final itemColor = color ?? defaultColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: itemColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: isActive || color != null ? FontWeight.bold : FontWeight.normal,
                        color: itemColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersDrawer(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
  ) {
    return Drawer(
      width: MediaQuery.of(context).size.width - 56.0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 200) {
            Navigator.of(context).pop();
          }
        },
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        if (_scaffoldKey.currentState?.isEndDrawerOpen ==
                            true) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  child: CompetitionFilterContent(
                    provider: provider,
                    isDesktop: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabCollectionDropdown(
    BuildContext context,
    AuthProvider authProvider,
    ThemeData theme, {
    bool isDrawer = false,
  }) {
    final user = authProvider.currentUserProfile;
    if (user == null) return const SizedBox.shrink();

    final bool isSystemAdmin = user.isAdmin;
    final bool isCreator =
        user.isCompetitionCreator || user.isAssociationCreator;

    final Widget dropdown = PopupMenuButton<String>(
      initialValue: _currentTabCollection,
      tooltip: 'Select tab collection',
      offset: const Offset(0, 40),
      onSelected: (String? newValue) {
        if (newValue != null && newValue != _currentTabCollection) {
          _provider.clearSelections();
          setState(() {
            _currentTabCollection = newValue;
            _currentTabIndex = 0; // Reset index to prevent bounds errors
          });
          // If competitions is selected, query it
          if (newValue == 'All') {
            _provider.setSearchScopeAndQuery(SearchScope.competitions, '');
          }
          _syncUrlToCurrentTab();
          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
            _scaffoldKey.currentState?.closeDrawer();
          }
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'All',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text('All'),
            ],
          ),
        ),
        if (isSystemAdmin || isCreator)
          PopupMenuItem<String>(
            value: 'Management',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.business_center,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text('Management'),
              ],
            ),
          ),
        if (isSystemAdmin)
          PopupMenuItem<String>(
            value: 'Administration',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text('Administration'),
              ],
            ),
          ),
      ],
      child: isDrawer
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Icon(
                            _currentTabCollection == 'All'
                                ? Icons.public
                                : _currentTabCollection == 'Management'
                                    ? Icons.business_center
                                    : Icons.admin_panel_settings,
                            size: 24,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _currentTabCollection,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.normal,
                                color: theme.colorScheme.onSurface,
                              ),
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
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentTabCollection == 'All'
                        ? Icons.public
                        : _currentTabCollection == 'Management'
                            ? Icons.business_center
                            : Icons.admin_panel_settings,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentTabCollection,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
    );

    if (isDrawer) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: dropdown,
      );
    }
    return dropdown;
  }

  List<NavigationItem> _getNavigationItems(AuthProvider authProvider) {
    if (_currentTabCollection == 'Management') {
      return [
        NavigationItem(label: 'My Competitions', icon: Icons.explore),
        NavigationItem(label: 'My Associations', icon: Icons.business),
      ];
    } else if (_currentTabCollection == 'Administration') {
      return [
        NavigationItem(label: 'Permission Requests', icon: Icons.security),
        NavigationItem(label: 'Configuration', icon: Icons.settings),
        NavigationItem(label: 'Users', icon: Icons.people),
      ];
    } else {
      return [
        NavigationItem(label: 'Competitions', icon: Icons.explore),
        NavigationItem(label: 'Associations', icon: Icons.business),
        NavigationItem(label: 'Rankings', icon: Icons.emoji_events),
        if (authProvider.isAuthenticated)
          NavigationItem(label: 'My Profile', icon: Icons.person),
      ];
    }
  }
}

  class DesktopSearchBar extends StatefulWidget {
  const DesktopSearchBar({super.key});

  @override
  State<DesktopSearchBar> createState() => _DesktopSearchBarState();
}

class _DesktopSearchBarState extends State<DesktopSearchBar> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _controller = TextEditingController();
  OverlayEntry? _overlayEntry;
  late SearchScope _tempSearchScope;
  SearchScope? _lastProviderScope;
  String? _lastProviderQuery;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChanged);

    final provider = Provider.of<CompetitionProvider>(context, listen: false);
    _tempSearchScope = provider.searchScope;
    _lastProviderScope = provider.searchScope;
    _lastProviderQuery = provider.query;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _controller.text.isNotEmpty) {
      _showOverlay();
    } else {
      // Delay slightly to let a tap on the suggestion list tiles process first
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _hideOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    if (_controller.text.isNotEmpty && _focusNode.hasFocus) {
      _showOverlay();
      final provider = Provider.of<CompetitionProvider>(context, listen: false);
      if (_tempSearchScope == SearchScope.users) {
        provider.searchUsers(_controller.text);
      } else if (_tempSearchScope == SearchScope.associations) {
        provider.searchAssociations(_controller.text);
      }
    } else {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 6.0),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Consumer<CompetitionProvider>(
              builder: (context, provider, child) {
                final theme = Theme.of(context);
                final query = _controller.text.trim().toLowerCase();

                if (_tempSearchScope == SearchScope.users) {
                  final suggestions = provider.searchedUsers;

                  if (suggestions.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: const Text('No users found'),
                    );
                  }

                  return Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final user = suggestions[index];
                        final resolvedUrl = ImageUrlResolver.resolve(context, user.profilePictureUrl);
                        final initials = user.fullName.isNotEmpty
                            ? user.fullName
                                  .trim()
                                  .split(' ')
                                  .map((e) => e.isEmpty ? '' : e[0])
                                  .take(2)
                                  .join()
                                  .toUpperCase()
                            : user.username.isNotEmpty
                            ? user.username[0].toUpperCase()
                            : '?';
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: resolvedUrl != null &&
                                    resolvedUrl.isNotEmpty
                                ? NetworkImage(resolvedUrl)
                                : null,
                            child: user.profilePictureUrl == null ||
                                    user.profilePictureUrl!.isEmpty
                                ? Text(
                                    initials,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            user.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('@${user.username}'),
                          onTap: () {
                            _hideOverlay();
                            _focusNode.unfocus();
                            final isDesktop = MediaQuery.of(context).size.width >= 900;
                            if (isDesktop) {
                              provider.selectProfile(id: user.id, username: user.username);
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  settings: RouteSettings(
                                    name: '/users/${user.username}',
                                  ),
                                  builder: (_) => ProfilePage(
                                    userId: user.id,
                                    profileRepository: provider.profileRepository,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  );
                } else if (_tempSearchScope == SearchScope.associations) {
                  final suggestions = provider.searchedAssociations;

                  if (suggestions.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: const Text('No associations found'),
                    );
                  }

                  return Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final assoc = suggestions[index];
                        final resolvedUrl = ImageUrlResolver.resolve(context, assoc.profilePictureUrl);
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                theme.colorScheme.secondaryContainer,
                            backgroundImage: resolvedUrl != null &&
                                    resolvedUrl.isNotEmpty
                                ? NetworkImage(resolvedUrl)
                                : null,
                            child: assoc.profilePictureUrl == null ||
                                    assoc.profilePictureUrl!.isEmpty
                                ? Text(
                                    assoc.name.isNotEmpty
                                        ? assoc.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme
                                          .colorScheme.onSecondaryContainer,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            assoc.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(_toTitleCase(assoc.scope)),
                          onTap: () {
                            _hideOverlay();
                            _focusNode.unfocus();
                            final isDesktop = MediaQuery.of(context).size.width >= 900;
                            if (isDesktop) {
                              provider.selectAssociation(assoc.id);
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  settings: RouteSettings(name: '/associations/${assoc.id}'),
                                  builder: (_) => AssociationDetailPage(
                                    associationId: assoc.id,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  );
                } else {
                  final suggestions = provider.allCompetitions.where((c) {
                    return c.title.toLowerCase().contains(query) ||
                        c.location.toLowerCase().contains(query) ||
                        (c.city != null &&
                            c.city!.toLowerCase().contains(query)) ||
                        (c.country != null &&
                            c.country!.toLowerCase().contains(query));
                  }).toList();

                  if (suggestions.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: const Text('No competitions found'),
                    );
                  }

                  return Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final comp = suggestions[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            comp.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(comp.location),
                          onTap: () {
                            _hideOverlay();
                            _focusNode.unfocus();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                settings: RouteSettings(
                                  name: '/competitions/${comp.id}',
                                ),
                                builder: (_) =>
                                    CompetitionDetailPage(competition: comp),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<CompetitionProvider>(context);

    // Sync state if provider's values changed from outside
    if (provider.searchScope != _lastProviderScope) {
      _tempSearchScope = provider.searchScope;
      _lastProviderScope = provider.searchScope;
    }
    if (provider.query != _lastProviderQuery) {
      _lastProviderQuery = provider.query;
      if (!_focusNode.hasFocus) {
        _controller.text = provider.query;
      }
    }
    if (provider.query.isEmpty &&
        _controller.text.isNotEmpty &&
        !_focusNode.hasFocus) {
      _controller.clear();
    }

    final isUsers = _tempSearchScope == SearchScope.users;
    final isAssociations = _tempSearchScope == SearchScope.associations;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          hintText: isUsers
              ? 'Search users...'
              : isAssociations
              ? 'Search associations...'
              : 'Search competitions',
          prefixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 12),
              PopupMenuButton<SearchScope>(
                initialValue: _tempSearchScope,
                tooltip: 'Search scope',
                offset: const Offset(-12, 32),
                onSelected: (val) {
                  setState(() {
                    _tempSearchScope = val;
                  });
                  _onTextChanged();
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: SearchScope.competitions,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text('Competitions'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SearchScope.users,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text('Users'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SearchScope.associations,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text('Associations'),
                      ],
                    ),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _tempSearchScope == SearchScope.competitions
                            ? Icons.emoji_events
                            : _tempSearchScope == SearchScope.users
                                ? Icons.person
                                : Icons.business,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                height: 20,
                width: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(width: 8),
            ],
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_controller.text.isNotEmpty) ...[
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    provider.setQuery('');
                    _hideOverlay();
                  },
                  child: const Icon(Icons.clear, size: 18),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () {
                  provider.setSearchScopeAndQuery(_tempSearchScope, _controller.text);
                  provider.setLayout(CompetitionsLayout.grid);
                  _hideOverlay();
                  _focusNode.unfocus();
                },
                child: Icon(Icons.search, size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 16),
            ],
          ),
          filled: true,
          fillColor: theme.brightness == Brightness.dark
              ? const Color(0xFF1E1715)
              : const Color(0xFFF3EDEB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (val) {
          provider.setSearchScopeAndQuery(_tempSearchScope, val);
          provider.setLayout(CompetitionsLayout.grid); // Show grid view
          _hideOverlay();
          _focusNode.unfocus();
        },
      ),
    );
  }
}

String _toTitleCase(String text) {
  if (text.isEmpty) return '';
  return text.split(' ').map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}
