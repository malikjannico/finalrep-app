import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/competition_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/profile_card.dart';
import '../widgets/user_compact_row.dart';
import 'profile_page.dart';

class UserLibraryPage extends StatefulWidget {
  final bool isInline;

  const UserLibraryPage({super.key, this.isInline = false});

  @override
  State<UserLibraryPage> createState() => _UserLibraryPageState();
}

class _UserLibraryPageState extends State<UserLibraryPage> {
  bool _isLoading = false;
  bool _userIsCompactLayout = false;
  late CompetitionProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<CompetitionProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    if (_provider.query.isNotEmpty &&
        _provider.searchScope == SearchScope.users &&
        _provider.selectedProfileUsername == null &&
        _provider.selectedProfileId == null &&
        _provider.selectedAssociationId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _provider.setQuery('');
      });
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    final provider = Provider.of<CompetitionProvider>(context, listen: false);
    await provider.searchUsers(provider.query);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<CompetitionProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;

    final headerRow = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
      ),
      child: Row(
        children: [
          Text(
            '${provider.searchedUsers.length} Users',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          // Layout Selector Dropdown matching Association Library
          PopupMenuButton<bool>(
            tooltip: 'Select layout ',
            offset: const Offset(0, 40),
            onSelected: (val) {
              setState(() {
                _userIsCompactLayout = val;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: true,
                child: Row(
                  children: [
                    Icon(Icons.view_list, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    const Text('Compact View'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: false,
                child: Row(
                  children: [
                    Icon(Icons.grid_view, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    const Text('Grid View'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                _userIsCompactLayout ? Icons.view_list : Icons.grid_view,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );

    Widget mainContent;

    if (_isLoading) {
      mainContent = const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE94E1B)),
        ),
      );
    } else if (provider.errorMessage != null) {
      mainContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                provider.errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else if (provider.searchedUsers.isEmpty) {
      mainContent = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 64,
                color: theme.colorScheme.outline.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No users found',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try refining your search query.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      mainContent = RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFFE94E1B),
        child: CustomScrollView(
          slivers: [
            if (_userIsCompactLayout)
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 16,
                  vertical: 12,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final user = provider.searchedUsers[index];
                      return UserCompactRow(
                        profile: user,
                        onTap: isDesktop
                            ? () {
                                provider.selectProfile(id: user.id, username: user.username);
                              }
                            : null,
                      );
                    },
                    childCount: provider.searchedUsers.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.only(
                  left: isDesktop ? 24 : 16,
                  right: isDesktop ? 24 : 16,
                  bottom: 40,
                  top: 12,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    mainAxisExtent: 250, // Increased to fit the banner height
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final user = provider.searchedUsers[index];
                      return ProfileCard(
                        profile: user,
                        onTap: isDesktop
                            ? () {
                                provider.selectProfile(id: user.id, username: user.username);
                              }
                            : null,
                      );
                    },
                    childCount: provider.searchedUsers.length,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: widget.isInline
          ? null
          : AppBar(
              title: const Text('Users'),
            ),
      body: Column(
        children: [
          headerRow,
          Expanded(child: mainContent),
        ],
      ),
    );
  }
}
