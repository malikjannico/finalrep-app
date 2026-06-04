import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'views/home_navigation_shell.dart';
import 'views/login_page.dart';
import 'views/register_page.dart';
import 'views/association_detail_page.dart';
import 'views/profile_page.dart';
import 'views/competition_detail_page.dart';
import 'views/association_creation_page.dart';
import 'views/competition_creation_page.dart';
import 'views/settings_page.dart';
import 'views/appearance_settings_page.dart';
import 'views/change_password_page.dart';
import 'views/user_permissions_editor_page.dart';
import 'views/sports_config_page.dart';
import 'views/formats_config_page.dart';
import 'views/disciplines_config_page.dart';
import 'views/association_management_page.dart';
import 'views/competition_management_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter goRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: authRedirectNotifier,
  redirect: (context, state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoading) {
      return null;
    }
    final isAuthenticated = authProvider.isAuthenticated;
    final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

    final protectedRoutes = [
      '/profile',
      '/associations/create',
      '/competitions/create',
      '/settings',
      '/management',
      '/admin',
    ];
    final isProtected = protectedRoutes.any((route) => state.matchedLocation.startsWith(route));

    if (!isAuthenticated && isProtected) {
      return '/login';
    }
    if (isAuthenticated && isLoggingIn) {
      return '/';
    }
    return null;
  },
  routes: [
    // Auth Routes
    GoRoute(
      path: '/login',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => const NoTransitionPage(
        child: LoginPage(),
      ),
    ),
    GoRoute(
      path: '/register',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => const NoTransitionPage(
        child: RegisterPage(),
      ),
    ),

    // Full-Screen Creation/Settings Routes
    GoRoute(
      path: '/associations/create',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AssociationCreationPage(),
    ),
    GoRoute(
      path: '/competitions/create',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const CompetitionCreationPage(),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/settings/appearance',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AppearanceSettingsPage(),
    ),
    GoRoute(
      path: '/settings/updatesecurity',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ChangePasswordPage(),
    ),

    // Detail Routes that dynamically switch full-screen (mobile) or inline (desktop)
    GoRoute(
      path: '/associations/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final isDesktop = MediaQuery.of(context).size.width >= 900;
        if (isDesktop) {
          return NoTransitionPage(
            child: HomeNavigationShell(
              initialPath: '/associations/$id',
            ),
          );
        } else {
          return MaterialPage(
            child: AssociationDetailPage(associationId: id),
          );
        }
      },
    ),
    GoRoute(
      path: '/users/:username',
      pageBuilder: (context, state) {
        final username = state.pathParameters['username']!;
        final isDesktop = MediaQuery.of(context).size.width >= 900;
        if (isDesktop) {
          return NoTransitionPage(
            child: HomeNavigationShell(
              initialPath: '/users/$username',
            ),
          );
        } else {
          return MaterialPage(
            child: ProfilePage(username: username),
          );
        }
      },
    ),
    GoRoute(
      path: '/competitions/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final isDesktop = MediaQuery.of(context).size.width >= 900;
        if (isDesktop) {
          return NoTransitionPage(
            child: HomeNavigationShell(
              initialPath: '/competitions/$id',
            ),
          );
        } else {
          return MaterialPage(
            child: CompetitionDetailPage(competitionId: id),
          );
        }
      },
    ),

    // Core Shell Tab Routes
    GoRoute(
      path: '/',
      pageBuilder: (context, state) {
        final q = state.uri.queryParameters['q'];
        final scope = state.uri.queryParameters['scope'];
        return NoTransitionPage(
          child: HomeNavigationShell(
            initialPath: '/',
            initialQuery: q,
            initialScope: scope,
          ),
        );
      },
    ),
    GoRoute(
      path: '/competitions',
      pageBuilder: (context, state) {
        final q = state.uri.queryParameters['q'];
        return NoTransitionPage(
          child: HomeNavigationShell(
            initialPath: '/',
            initialQuery: q,
            initialScope: 'competitions',
          ),
        );
      },
    ),
    GoRoute(
      path: '/associations',
      pageBuilder: (context, state) {
        final q = state.uri.queryParameters['q'];
        return NoTransitionPage(
          child: HomeNavigationShell(
            initialPath: '/associations',
            initialQuery: q,
            initialScope: 'associations',
          ),
        );
      },
    ),
    GoRoute(
      path: '/users',
      pageBuilder: (context, state) {
        final q = state.uri.queryParameters['q'];
        return NoTransitionPage(
          child: HomeNavigationShell(
            initialPath: '/users',
            initialQuery: q,
            initialScope: 'users',
          ),
        );
      },
    ),
    GoRoute(
      path: '/rankings',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: HomeNavigationShell(
          initialPath: '/rankings',
        ),
      ),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: HomeNavigationShell(
          initialPath: '/profile',
        ),
      ),
    ),
    
    // Core Management Shell Routes
    GoRoute(
      path: '/management/competitions',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: HomeNavigationShell(
          initialPath: '/management/competitions',
        ),
      ),
    ),
    GoRoute(
      path: '/management/competitions/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id']!;
        return '/management/competitions/$id/metadata';
      },
    ),
    GoRoute(
      path: '/management/competitions/:id/:tab',
      pageBuilder: (context, state) {
        final tab = state.pathParameters['tab'] ?? 'metadata';
        return _buildCompetitionManagementTab(context, state, tab);
      },
    ),
    GoRoute(
      path: '/management/associations',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: HomeNavigationShell(
          initialPath: '/management/associations',
        ),
      ),
    ),
    GoRoute(
      path: '/management/associations/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id']!;
        return '/management/associations/$id/metadata';
      },
    ),
    GoRoute(
      path: '/management/associations/:id/:tab',
      pageBuilder: (context, state) {
        final tab = state.pathParameters['tab'] ?? 'metadata';
        return _buildAssociationManagementTab(context, state, tab);
      },
    ),


    // Core Administration Shell Routes
    GoRoute(
      path: '/admin/requests',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: HomeNavigationShell(
          initialPath: '/admin/requests',
        ),
      ),
    ),
    GoRoute(
      path: '/admin/configuration',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: HomeNavigationShell(
          initialPath: '/admin/configuration',
        ),
      ),
    ),
    GoRoute(
      path: '/admin/configuration/sports',
      pageBuilder: (context, state) {
        final isDesktop = MediaQuery.of(context).size.width >= 900;
        if (isDesktop) {
          return const NoTransitionPage(
            child: HomeNavigationShell(
              initialPath: '/admin/configuration/sports',
            ),
          );
        } else {
          return const MaterialPage(
            child: SportsConfigPage(),
          );
        }
      },
    ),
    GoRoute(
      path: '/admin/configuration/formats',
      pageBuilder: (context, state) {
        final isDesktop = MediaQuery.of(context).size.width >= 900;
        if (isDesktop) {
          return const NoTransitionPage(
            child: HomeNavigationShell(
              initialPath: '/admin/configuration/formats',
            ),
          );
        } else {
          return const MaterialPage(
            child: FormatsConfigPage(),
          );
        }
      },
    ),
    GoRoute(
      path: '/admin/configuration/disciplines',
      pageBuilder: (context, state) {
        final isDesktop = MediaQuery.of(context).size.width >= 900;
        if (isDesktop) {
          return const NoTransitionPage(
            child: HomeNavigationShell(
              initialPath: '/admin/configuration/disciplines',
            ),
          );
        } else {
          return const MaterialPage(
            child: DisciplinesConfigPage(),
          );
        }
      },
    ),
    GoRoute(
      path: '/admin/users',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: HomeNavigationShell(
          initialPath: '/admin/users',
        ),
      ),
    ),
    GoRoute(
      path: '/admin/users/:username',
      pageBuilder: (context, state) {
        final username = state.pathParameters['username']!;
        final isDesktop = MediaQuery.of(context).size.width >= 900;
        if (isDesktop) {
          return NoTransitionPage(
            child: HomeNavigationShell(
              initialPath: '/admin/users/$username',
            ),
          );
        } else {
          return MaterialPage(
            child: UserPermissionsEditorPage(
              username: username,
            ),
          );
        }
      },
    ),
  ],
);

Page<dynamic> _buildAssociationManagementTab(BuildContext context, GoRouterState state, String tab) {
  final id = state.pathParameters['id']!;
  final isDesktop = MediaQuery.of(context).size.width >= 900;
  if (isDesktop) {
    return NoTransitionPage(
      child: HomeNavigationShell(
        initialPath: '/management/associations/$id/$tab',
      ),
    );
  } else {
    return MaterialPage(
      child: AssociationManagementPage(associationId: id, initialTab: tab),
    );
  }
}

Page<dynamic> _buildCompetitionManagementTab(BuildContext context, GoRouterState state, String tab) {
  final id = state.pathParameters['id']!;
  final isDesktop = MediaQuery.of(context).size.width >= 900;
  if (isDesktop) {
    return NoTransitionPage(
      child: HomeNavigationShell(
        initialPath: '/management/competitions/$id/$tab',
      ),
    );
  } else {
    return MaterialPage(
      child: CompetitionManagementPage(competitionId: id, initialTab: tab),
    );
  }
}

