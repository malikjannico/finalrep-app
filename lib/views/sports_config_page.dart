import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import '../models/admin_config.dart';

class SportsConfigPage extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onBack;
  const SportsConfigPage({
    super.key,
    this.isEmbedded = false,
    this.onBack,
  });

  @override
  State<SportsConfigPage> createState() => _SportsConfigPageState();
}

class _SportsConfigPageState extends State<SportsConfigPage> {
  SportConfig? _localConfig;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isCreating = false;

  final TextEditingController _createNameController = TextEditingController();
  final TextEditingController _createDescController = TextEditingController();

  @override
  void dispose() {
    _createNameController.dispose();
    _createDescController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadConfig();
      }
    });
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final config = await authProvider.loadSportsConfig();
      setState(() {
        _localConfig = SportConfig(
          sports: List.from(config.sports),
          formats: List.from(config.formats),
          disciplines: List.from(config.disciplines),
          links: List.from(config.links),
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading configuration: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _cancelEdit() {
    _loadConfig();
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _saveConfig() async {
    if (_localConfig == null) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.saveSportsConfig(_localConfig!);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sports configuration saved successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        if (mounted) {
          Provider.of<CompetitionProvider>(context, listen: false).loadSportsConfig();
        }
        setState(() {
          _isEditing = false;
        });
      } else {
        throw Exception('Failed to save sports configuration.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving configuration: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddSportDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Sport'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Sport Name',
                    hintText: 'e.g. Streetlifting',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Short description',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sport name cannot be empty.')),
                  );
                  return;
                }

                if (_localConfig!.sports.any(
                  (s) => s.name.toLowerCase() == name.toLowerCase(),
                )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sport already exists.')),
                  );
                  return;
                }

                final updatedConfig = SportConfig(
                  sports: List<SportDefinition>.from(_localConfig!.sports)
                    ..add(SportDefinition(name: name, description: desc.isEmpty ? null : desc)),
                  formats: _localConfig!.formats,
                  disciplines: _localConfig!.disciplines,
                  links: _localConfig!.links,
                );

                Navigator.of(context).pop();

                setState(() {
                  _isLoading = true;
                });

                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final success = await authProvider.saveSportsConfig(updatedConfig);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sport created successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    if (mounted) {
                      Provider.of<CompetitionProvider>(context, listen: false).loadSportsConfig();
                    }
                    setState(() {
                      _localConfig = updatedConfig;
                    });
                  } else {
                    throw Exception('Failed to save sports configuration.');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating sport: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94E1B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('CREATE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showEditSportDialog(SportDefinition sport) {
    final nameController = TextEditingController(text: sport.name);
    final descController = TextEditingController(text: sport.description ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Sport'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Sport Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sport name cannot be empty.')),
                  );
                  return;
                }

                if (name.toLowerCase() != sport.name.toLowerCase() &&
                    _localConfig!.sports.any(
                      (s) => s.name.toLowerCase() == name.toLowerCase(),
                    )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sport name already exists.')),
                  );
                  return;
                }

                setState(() {
                  // Update sport in sports list
                  final updatedSports = _localConfig!.sports.map((s) {
                    if (s.name == sport.name) {
                      return SportDefinition(name: name, description: desc.isEmpty ? null : desc);
                    }
                    return s;
                  }).toList();

                  // Cascade update sportName in formats and links
                  final updatedFormats = _localConfig!.formats.map((f) {
                    if (f.sportName == sport.name) {
                      return FormatDefinition(
                        sportName: name,
                        name: f.name,
                        description: f.description,
                      );
                    }
                    return f;
                  }).toList();

                  final updatedLinks = _localConfig!.links.map((l) {
                    if (l.sportName == sport.name) {
                      return FormatDisciplineLink(
                        sportName: name,
                        formatName: l.formatName,
                        disciplineName: l.disciplineName,
                      );
                    }
                    return l;
                  }).toList();

                  _localConfig = SportConfig(
                    sports: updatedSports,
                    formats: updatedFormats,
                    disciplines: _localConfig!.disciplines,
                    links: updatedLinks,
                  );
                });

                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94E1B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('UPDATE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _removeSport(String sportName) {
    setState(() {
      final updatedSports = List<SportDefinition>.from(_localConfig!.sports)
        ..removeWhere((s) => s.name == sportName);
      final updatedFormats = List<FormatDefinition>.from(_localConfig!.formats)
        ..removeWhere((f) => f.sportName == sportName);
      final updatedLinks = List<FormatDisciplineLink>.from(_localConfig!.links)
        ..removeWhere((l) => l.sportName == sportName);

      _localConfig = SportConfig(
        sports: updatedSports,
        formats: updatedFormats,
        disciplines: _localConfig!.disciplines,
        links: updatedLinks,
      );
    });
  }

  Future<void> _confirmRemoveSport(String sportName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sport?'),
        content: Text('Are you sure you want to delete the sport "$sportName"? This will also delete all associated formats and mappings.'),
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
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _removeSport(sportName);
    }
  }

  Future<void> _handleCreateSport({required bool saveAndCreateAnother}) async {
    final name = _createNameController.text.trim();
    final desc = _createDescController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sport name cannot be empty.')),
      );
      return;
    }

    if (_localConfig!.sports.any(
      (s) => s.name.toLowerCase() == name.toLowerCase(),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sport already exists.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedConfig = SportConfig(
        sports: List<SportDefinition>.from(_localConfig!.sports)
          ..add(SportDefinition(name: name, description: desc.isEmpty ? null : desc)),
        formats: _localConfig!.formats,
        disciplines: _localConfig!.disciplines,
        links: _localConfig!.links,
      );

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.saveSportsConfig(updatedConfig);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sport created successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        if (mounted) {
          Provider.of<CompetitionProvider>(context, listen: false).loadSportsConfig();
        }
        setState(() {
          _localConfig = updatedConfig;
          _createNameController.clear();
          _createDescController.clear();
          if (!saveAndCreateAnother) {
            _isCreating = false;
          }
        });
      } else {
        throw Exception('Failed to save configuration.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving configuration: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildSportsCreationForm(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Create New Sport',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _createNameController,
                    decoration: const InputDecoration(
                      labelText: 'Sport Name',
                      hintText: 'e.g. Streetlifting',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _createDescController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Short description of the sport',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Widget bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isEmbedded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Breadcrumb
                      if (_isCreating)
                        Row(
                          children: [
                            TextButton(
                              onPressed: widget.onBack,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                overlayColor: Colors.transparent,
                              ).copyWith(
                                textStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
                                  return TextStyle(
                                    decoration: states.contains(WidgetState.hovered)
                                        ? TextDecoration.underline
                                        : TextDecoration.none,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  );
                                }),
                                foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                  return states.contains(WidgetState.hovered)
                                      ? theme.colorScheme.primary.withOpacity(0.8)
                                      : theme.colorScheme.primary;
                                }),
                              ),
                              child: const Text('Configuration'),
                            ),
                            Text(
                              ' / ',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isCreating = false;
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                overlayColor: Colors.transparent,
                              ).copyWith(
                                textStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
                                  return TextStyle(
                                    decoration: states.contains(WidgetState.hovered)
                                        ? TextDecoration.underline
                                        : TextDecoration.none,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  );
                                }),
                                foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                  return states.contains(WidgetState.hovered)
                                      ? theme.colorScheme.primary.withOpacity(0.8)
                                      : theme.colorScheme.primary;
                                }),
                              ),
                              child: const Text('Sports'),
                            ),
                            Text(
                              ' / Create Sport',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            TextButton(
                              onPressed: widget.onBack,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                overlayColor: Colors.transparent,
                              ).copyWith(
                                textStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
                                  return TextStyle(
                                    decoration: states.contains(WidgetState.hovered)
                                        ? TextDecoration.underline
                                        : TextDecoration.none,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  );
                                }),
                                foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                  return states.contains(WidgetState.hovered)
                                      ? theme.colorScheme.primary.withOpacity(0.8)
                                      : theme.colorScheme.primary;
                                }),
                              ),
                              child: const Text('Configuration'),
                            ),
                            Text(
                              ' / Sports',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      // Actions
                      if (!_isLoading)
                        Row(
                          children: [
                            if (_isCreating) ...[
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isCreating = false;
                                  });
                                },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _handleCreateSport(saveAndCreateAnother: true),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFE94E1B),
                                  side: const BorderSide(color: Color(0xFFE94E1B)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Save + Create', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _handleCreateSport(saveAndCreateAnother: false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE94E1B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Create', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ] else if (!_isEditing) ...[
                              OutlinedButton.icon(
                                onPressed: _toggleEdit,
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isCreating = true;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE94E1B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Create Sport', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ] else ...[
                              TextButton(
                                onPressed: _cancelEdit,
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _saveConfig,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE94E1B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: _isCreating
                    ? _buildSportsCreationForm(theme)
                    : (_localConfig == null || _localConfig!.sports.isEmpty
                        ? const Center(child: Text('No sports defined.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _localConfig!.sports.length,
                            itemBuilder: (context, index) {
                              final sport = _localConfig!.sports[index];
                              return Card(
                                elevation: 0,
                                color: isDark
                                    ? theme.colorScheme.surfaceContainerLow
                                    : theme.colorScheme.surfaceContainerLowest,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                                  ),
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Text(
                                    sport.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: sport.description != null && sport.description!.isNotEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text(sport.description!),
                                        )
                                      : null,
                                  trailing: _isEditing
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                                              onPressed: () => _showEditSportDialog(sport),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                              onPressed: () => _confirmRemoveSport(sport.name),
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                              );
                            },
                          )),
              ),
            ],
          );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: Text(
                _isEditing ? 'Sports Config (Editing)' : 'Sports Configuration',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: _isLoading
                  ? null
                  : [
                      if (!_isEditing)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit Configuration',
                          onPressed: _toggleEdit,
                        )
                      else ...[
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Cancel',
                          onPressed: _cancelEdit,
                        ),
                        IconButton(
                          icon: const Icon(Icons.check),
                          tooltip: 'Save Configuration',
                          onPressed: _saveConfig,
                        ),
                      ],
                    ],
            ),
      body: bodyContent,
      floatingActionButton: !_isEditing && !_isLoading && !widget.isEmbedded
          ? FloatingActionButton(
              onPressed: _showAddSportDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
