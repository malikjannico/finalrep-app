import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/competition_provider.dart';
import '../widgets/competition_card.dart';

class SearchFeedPage extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const SearchFeedPage({
    Key? key,
    required this.onToggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<CompetitionProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final isTablet = size.width >= 600 && size.width < 900;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Nav Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/finalrep_icon.svg',
                        height: 32,
                      ),
                      const SizedBox(width: 12),
                      SvgPicture.asset(
                        'assets/finalrep_logo.svg',
                        height: 24,
                      ),
                    ],
                  ),
                  
                  // Theme Toggle & Org Details
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isDarkMode ? Icons.light_mode : Icons.dark_mode,
                          color: theme.colorScheme.onSurface,
                        ),
                        onPressed: onToggleTheme,
                        tooltip: 'Toggle Theme',
                      ),
                      if (isDesktop) ...[
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showAboutDialog(context, theme),
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: const Text('ABOUT STREETLIFTING'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor: theme.colorScheme.onPrimaryContainer,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ],
              ),
            ),

            // Main Feed Area
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Hero Section
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.only(left: 24, right: 24, top: 40, bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FinalRep Sport Platform',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.primary,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Find and search upcoming Streetlifting competitions globally.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Search Bar & Filter Controls
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search Box
                          TextField(
                            onChanged: provider.setQuery,
                            decoration: InputDecoration(
                              hintText: 'Search by title, location or city...',
                              prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                              suffixIcon: provider.query.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => provider.setQuery(''),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Subtypes selector
                          Text(
                            'STREETLIFTING SUBTYPE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: ['All', 'Modern', 'Classic'].map((subtype) {
                              final isSelected = provider.selectedSubtype == subtype;
                              return ChoiceChip(
                                label: Text(subtype),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) provider.setSelectedSubtype(subtype);
                                },
                                selectedColor: theme.colorScheme.primaryContainer,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurface,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // Competition groups selector
                          Text(
                            'COMPETITION GROUP',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              'All',
                              'FinalRep Underground',
                              'FinalRep Qualifier',
                              'FinalRep Final',
                              'Individual'
                            ].map((group) {
                              final isSelected = provider.selectedGroup == group;
                              return ChoiceChip(
                                label: Text(group),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) provider.setSelectedGroup(group);
                                },
                                selectedColor: theme.colorScheme.tertiaryContainer,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? theme.colorScheme.onTertiaryContainer
                                      : theme.colorScheme.onSurface,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Results Grid/List
                  if (provider.isLoading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (provider.errorMessage != null)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          provider.errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    )
                  else if (provider.competitions.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_outlined,
                                  size: 64, color: theme.colorScheme.outline),
                              const SizedBox(height: 16),
                              Text(
                                'No upcoming competitions found',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try refining your search query or reset filters.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: CenterInLineText().align,
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: provider.clearFilters,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reset All Filters'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 40),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          mainAxisExtent: 280,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final comp = provider.competitions[index];
                            return CompetitionCard(competition: comp);
                          },
                          childCount: provider.competitions.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              SvgPicture.asset('assets/finalrep_icon.svg', height: 28),
              const SizedBox(width: 12),
              const Text('Streetlifting Rules'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Format: One-Rep-Max (1RM)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Athletes perform 3 attempts per discipline with maximum weight. Highest valid attempt weights are summed to compute the final total.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Streetlifting Modern (4 disciplines):',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Text('• Muscle Up\n• Pull Up\n• Dip\n• Squat'),
                const SizedBox(height: 12),
                Text(
                  'Streetlifting Classic (2 disciplines):',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Text('• Pull Up\n• Dip'),
                const SizedBox(height: 16),
                Text(
                  'Official Weight Classes:',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Men: -66 kg, -73 kg, -80 kg, -87 kg, -101 kg, +101 kg\n'
                  'Women: -52 kg, -57 kg, -63 kg, -70 kg, +70 kg',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }
}

// Inline helper for text alignment to avoid nested layout calls
class CenterInLineText {
  TextAlign get align => TextAlign.center;
}
