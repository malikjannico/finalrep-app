import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/competition.dart';
import '../providers/competition_provider.dart';
import '../widgets/profile_card.dart';
import '../widgets/user_compact_row.dart';
import '../widgets/competition_card.dart';
import '../widgets/competition_compact_row.dart';
import 'competition_detail_page.dart';

class MobileSearchPage extends StatefulWidget {
  const MobileSearchPage({super.key});

  @override
  State<MobileSearchPage> createState() => _MobileSearchPageState();
}

class _MobileSearchPageState extends State<MobileSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Competition> _suggestions = [];
  SearchScope _selectedScope = SearchScope.competitions;
  bool _userIsCompactLayout = false;
  bool _compIsCompactLayout = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<CompetitionProvider>(context, listen: false);
    _selectedScope = provider.searchScope;
    _searchController.text = provider.query;
    if (_selectedScope == SearchScope.competitions) {
      _updateSuggestions(provider.query, provider.allCompetitions);
    } else {
      provider.searchUsers(provider.query);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateSuggestions(String query, List<Competition> allCompetitions) {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    final q = query.trim().toLowerCase();
    final results = allCompetitions
        .where(
          (c) =>
              c.title.toLowerCase().contains(q) ||
              c.location.toLowerCase().contains(q) ||
              (c.description != null &&
                  c.description!.toLowerCase().contains(q)) ||
              (c.city != null && c.city!.toLowerCase().contains(q)) ||
              (c.country != null && c.country!.toLowerCase().contains(q)),
        )
        .toList();

    setState(() {
      _suggestions = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<CompetitionProvider>(context);
    final isCompetitions = _selectedScope == SearchScope.competitions;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
          decoration: InputDecoration(
            hintText: isCompetitions ? 'Search competitions' : 'Search users...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      if (isCompetitions) {
                        _updateSuggestions('', provider.allCompetitions);
                      } else {
                        provider.searchUsers('');
                      }
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (val) {
            if (isCompetitions) {
              _updateSuggestions(val, provider.allCompetitions);
            } else {
              provider.searchUsers(val);
            }
          },
          onSubmitted: (val) {
            provider.setSearchScopeAndQuery(_selectedScope, val);
            Navigator.of(context).pop();
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 16.0, right: 16.0),
                child: Center(
                  child: SizedBox(
                    width: 320,
                    child: SlidingSearchScopeSelector(
                      selectedScope: _selectedScope,
                      onScopeChanged: (scope) {
                        setState(() {
                          _selectedScope = scope;
                        });
                        if (scope == SearchScope.competitions) {
                          _updateSuggestions(_searchController.text, provider.allCompetitions);
                        } else {
                          provider.searchUsers(_searchController.text);
                        }
                      },
                    ),
                  ),
                ),
              ),
              Stack(
                children: [
                  Divider(
                    height: 1.0,
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  if (provider.isLoadingUsers && !isCompetitions)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: isCompetitions
          ? _buildCompetitionsBody(theme, provider)
          : _buildUsersBody(theme, provider),
    );
  }

  Widget _buildCompetitionsBody(ThemeData theme, CompetitionProvider provider) {
    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search Competitions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Type a city, country, or keyword to begin.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_outlined,
                size: 64,
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No suggestions found',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Double check your spelling or search another keyword.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Result Indicator and Layout Switcher
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_suggestions.length} Competitions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              PopupMenuButton<bool>(
                tooltip: 'Select layout',
                onSelected: (bool isCompact) {
                  setState(() {
                    _compIsCompactLayout = isCompact;
                  });
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<bool>(
                    value: false,
                    child: Row(
                      children: [
                        Icon(
                          Icons.grid_view,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Grid Layout',
                          style: TextStyle(
                            fontWeight: !_compIsCompactLayout
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<bool>(
                    value: true,
                    child: Row(
                      children: [
                        Icon(
                          Icons.view_list,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Compact Layout',
                          style: TextStyle(
                            fontWeight: _compIsCompactLayout
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    !_compIsCompactLayout ? Icons.grid_view : Icons.view_list,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _compIsCompactLayout
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final comp = _suggestions[index];
                    return CompetitionCompactRow(
                      competition: comp,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            settings: RouteSettings(name: '/competitions/${comp.id}'),
                            builder: (_) => CompetitionDetailPage(competition: comp),
                          ),
                        );
                      },
                    );
                  },
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1, // On mobile, grid crossAxisCount is 1
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 380, // Standard mainAxisExtent for CompetitionCard
                  ),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final comp = _suggestions[index];
                    return CompetitionCard(
                      key: Key('comp_card_${comp.id}'),
                      competition: comp,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUsersBody(ThemeData theme, CompetitionProvider provider) {
    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search Users',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Type a name or username to begin.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (provider.searchedUsers.isEmpty && !provider.isLoadingUsers) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 64,
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No users found',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Double check your spelling or search another keyword.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Result Indicator and Layout Switcher
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${provider.searchedUsers.length} Users',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              PopupMenuButton<bool>(
                tooltip: 'Select layout',
                onSelected: (bool isCompact) {
                  setState(() {
                    _userIsCompactLayout = isCompact;
                  });
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<bool>(
                    value: false,
                    child: Row(
                      children: [
                        Icon(
                          Icons.grid_view,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Grid Layout',
                          style: TextStyle(
                            fontWeight: !_userIsCompactLayout
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<bool>(
                    value: true,
                    child: Row(
                      children: [
                        Icon(
                          Icons.view_list,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Compact Layout',
                          style: TextStyle(
                            fontWeight: _userIsCompactLayout
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    !_userIsCompactLayout ? Icons.grid_view : Icons.view_list,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _userIsCompactLayout
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: provider.searchedUsers.length,
                  itemBuilder: (context, index) {
                    final user = provider.searchedUsers[index];
                    return UserCompactRow(profile: user);
                  },
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1, // On mobile, grid crossAxisCount is 1
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 150,
                  ),
                  itemCount: provider.searchedUsers.length,
                  itemBuilder: (context, index) {
                    final user = provider.searchedUsers[index];
                    return ProfileCard(profile: user);
                  },
                ),
        ),
      ],
    );
  }
}

class SlidingSearchScopeSelector extends StatelessWidget {
  final SearchScope selectedScope;
  final ValueChanged<SearchScope> onScopeChanged;

  const SlidingSearchScopeSelector({
    super.key,
    required this.selectedScope,
    required this.onScopeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surfaceContainerHighest;
    const activeColor = Color(0xFFE94E1B);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final tabWidth = width / 2;
          final isCompetitions = selectedScope == SearchScope.competitions;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                left: isCompetitions ? 2 : tabWidth,
                top: 2,
                bottom: 2,
                width: tabWidth - 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onScopeChanged(SearchScope.competitions),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.titleSmall!.copyWith(
                            color: isCompetitions
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isCompetitions
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          child: const Text('Competitions'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onScopeChanged(SearchScope.users),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.titleSmall!.copyWith(
                            color: !isCompetitions
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: !isCompetitions
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          child: const Text('Users'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
