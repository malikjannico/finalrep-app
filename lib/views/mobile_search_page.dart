import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/competition.dart';
import '../providers/competition_provider.dart';
import 'competition_detail_page.dart';

class MobileSearchPage extends StatefulWidget {
  const MobileSearchPage({super.key});

  @override
  State<MobileSearchPage> createState() => _MobileSearchPageState();
}

class _MobileSearchPageState extends State<MobileSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Competition> _suggestions = [];

  @override
  void initState() {
    super.initState();
    // Initialize search text if provider already has query
    final provider = Provider.of<CompetitionProvider>(context, listen: false);
    _searchController.text = provider.query;
    _updateSuggestions(provider.query, provider.allCompetitions);
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
    final results = allCompetitions.where((c) =>
      c.title.toLowerCase().contains(q) ||
      c.location.toLowerCase().contains(q) ||
      (c.description != null && c.description!.toLowerCase().contains(q)) ||
      (c.city != null && c.city!.toLowerCase().contains(q)) ||
      (c.country != null && c.country!.toLowerCase().contains(q))
    ).toList();

    setState(() {
      _suggestions = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<CompetitionProvider>(context);

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
            hintText: 'Search competitions...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _updateSuggestions('', provider.allCompetitions);
                    },
                  )
                : null,
          ),
          onChanged: (val) {
            _updateSuggestions(val, provider.allCompetitions);
          },
          onSubmitted: (val) {
            provider.setQuery(val);
            Navigator.of(context).pop();
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(
            height: 1.0,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      body: _searchController.text.trim().isEmpty
          ? Center(
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
                    'Search FinalRep Meets',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Type a city, country, or keyword to begin.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            )
          : _suggestions.isEmpty
              ? Center(
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
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final comp = _suggestions[index];
                    return ListTile(
                      leading: Icon(
                        Icons.fitness_center,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        comp.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${comp.location} • ${DateFormat('MMM dd, yyyy').format(comp.startDate)}'),
                      trailing: const Icon(Icons.chevron_right, size: 16),
                      onTap: () {
                        // Close search page and open details view
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => CompetitionDetailPage(competition: comp),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
