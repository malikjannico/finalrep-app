import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import '../models/admin_config.dart';

class DisciplinesConfigPage extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onBack;
  const DisciplinesConfigPage({
    super.key,
    this.isEmbedded = false,
    this.onBack,
  });

  @override
  State<DisciplinesConfigPage> createState() => _DisciplinesConfigPageState();
}

class _DisciplinesConfigPageState extends State<DisciplinesConfigPage> {
  SportConfig? _localConfig;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isCreating = false;

  final TextEditingController _createNameController = TextEditingController();
  final TextEditingController _createAbbreviationController = TextEditingController();
  final TextEditingController _createDescController = TextEditingController();

  @override
  void dispose() {
    _createNameController.dispose();
    _createAbbreviationController.dispose();
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
      if (!mounted) return;
      setState(() {
        _localConfig = SportConfig(
          sports: List.from(config.sports),
          formats: List.from(config.formats),
          disciplines: List.from(config.disciplines),
          links: List.from(config.links),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disciplines configuration saved successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        Provider.of<CompetitionProvider>(context, listen: false).loadSportsConfig();
        setState(() {
          _isEditing = false;
        });
      } else {
        throw Exception('Failed to save configuration.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAddDisciplineDialog() {
    final nameController = TextEditingController();
    final abbreviationController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Discipline'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Discipline Name',
                    hintText: 'e.g. Muscle Up',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: abbreviationController,
                  decoration: const InputDecoration(
                    labelText: 'Abbreviation',
                    hintText: 'e.g. MU',
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
                final abbreviation = abbreviationController.text.trim();
                final desc = descController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Discipline name cannot be empty.')),
                  );
                  return;
                }

                if (_localConfig!.disciplines.any(
                  (d) => d.name.toLowerCase() == name.toLowerCase(),
                )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Discipline already exists.')),
                  );
                  return;
                }

                final updatedConfig = SportConfig(
                  sports: _localConfig!.sports,
                  formats: _localConfig!.formats,
                  disciplines: List<DisciplineDefinition>.from(_localConfig!.disciplines)
                    ..add(DisciplineDefinition(
                      name: name,
                      description: desc.isEmpty ? null : desc,
                      abbreviation: abbreviation.isEmpty ? null : abbreviation,
                    )),
                  links: _localConfig!.links,
                );

                Navigator.of(context).pop();

                setState(() {
                  _isLoading = true;
                });

                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final success = await authProvider.saveSportsConfig(updatedConfig);
                  if (!mounted) return;
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Discipline created successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Provider.of<CompetitionProvider>(context, listen: false).loadSportsConfig();
                    setState(() {
                      _localConfig = updatedConfig;
                    });
                  } else {
                    throw Exception('Failed to save disciplines configuration.');
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error creating discipline: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
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

  void _showEditDisciplineDialog(DisciplineDefinition discipline) {
    final nameController = TextEditingController(text: discipline.name);
    final abbreviationController = TextEditingController(text: discipline.abbreviation ?? '');
    final descController = TextEditingController(text: discipline.description ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Discipline'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Discipline Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: abbreviationController,
                  decoration: const InputDecoration(
                    labelText: 'Abbreviation',
                    hintText: 'e.g. MU',
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
                final abbreviation = abbreviationController.text.trim();
                final desc = descController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Discipline name cannot be empty.')),
                  );
                  return;
                }

                if (name.toLowerCase() != discipline.name.toLowerCase() &&
                    _localConfig!.disciplines.any(
                      (d) => d.name.toLowerCase() == name.toLowerCase(),
                    )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Discipline name already exists.')),
                  );
                  return;
                }

                setState(() {
                  // Update disciplines list
                  final updatedDisciplines = _localConfig!.disciplines.map((d) {
                    if (d.name == discipline.name) {
                      return DisciplineDefinition(
                        name: name,
                        description: desc.isEmpty ? null : desc,
                        abbreviation: abbreviation.isEmpty ? null : abbreviation,
                      );
                    }
                    return d;
                  }).toList();

                  // Cascade rename in links
                  final updatedLinks = _localConfig!.links.map((l) {
                    if (l.disciplineName == discipline.name) {
                      return FormatDisciplineLink(
                        sportName: l.sportName,
                        formatName: l.formatName,
                        disciplineName: name,
                      );
                    }
                    return l;
                  }).toList();

                  _localConfig = SportConfig(
                    sports: _localConfig!.sports,
                    formats: _localConfig!.formats,
                    disciplines: updatedDisciplines,
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

  void _removeDiscipline(String disciplineName) {
    setState(() {
      final updatedDisciplines = List<DisciplineDefinition>.from(_localConfig!.disciplines)
        ..removeWhere((d) => d.name == disciplineName);
      final updatedLinks = List<FormatDisciplineLink>.from(_localConfig!.links)
        ..removeWhere((l) => l.disciplineName == disciplineName);

      _localConfig = SportConfig(
        sports: _localConfig!.sports,
        formats: _localConfig!.formats,
        disciplines: updatedDisciplines,
        links: updatedLinks,
      );
    });
  }

  Future<void> _confirmRemoveDiscipline(String disciplineName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Discipline?'),
        content: Text('Are you sure you want to delete the discipline "$disciplineName"? This will also remove it from any mapped formats.'),
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
      _removeDiscipline(disciplineName);
    }
  }

  Future<void> _handleCreateDiscipline({required bool saveAndCreateAnother}) async {
    final name = _createNameController.text.trim();
    final abbreviation = _createAbbreviationController.text.trim();
    final desc = _createDescController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discipline name cannot be empty.')),
      );
      return;
    }

    if (_localConfig!.disciplines.any(
      (d) => d.name.toLowerCase() == name.toLowerCase(),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discipline already exists.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedConfig = SportConfig(
        sports: _localConfig!.sports,
        formats: _localConfig!.formats,
        disciplines: List<DisciplineDefinition>.from(_localConfig!.disciplines)
          ..add(DisciplineDefinition(
            name: name,
            description: desc.isEmpty ? null : desc,
            abbreviation: abbreviation.isEmpty ? null : abbreviation,
          )),
        links: _localConfig!.links,
      );

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.saveSportsConfig(updatedConfig);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Discipline created successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        Provider.of<CompetitionProvider>(context, listen: false).loadSportsConfig();
        setState(() {
          _localConfig = updatedConfig;
          _createNameController.clear();
          _createAbbreviationController.clear();
          _createDescController.clear();
          if (!saveAndCreateAnother) {
            _isCreating = false;
          }
        });
      } else {
        throw Exception('Failed to save configuration.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildDisciplinesCreationForm(ThemeData theme) {
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
                    'Create New Discipline',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _createNameController,
                    decoration: const InputDecoration(
                      labelText: 'Discipline Name',
                      hintText: 'e.g. Muscle Up',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _createAbbreviationController,
                    decoration: const InputDecoration(
                      labelText: 'Abbreviation',
                      hintText: 'e.g. MU',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _createDescController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Short description of the discipline',
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
                              child: const Text('Disciplines'),
                            ),
                            Text(
                              ' / Create Discipline',
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
                              ' / Disciplines',
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
                                onPressed: () => _handleCreateDiscipline(saveAndCreateAnother: true),
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
                                onPressed: () => _handleCreateDiscipline(saveAndCreateAnother: false),
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
                                label: const Text('Create Discipline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                    ? _buildDisciplinesCreationForm(theme)
                    : (_localConfig == null || _localConfig!.disciplines.isEmpty
                        ? const Center(child: Text('No disciplines defined.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _localConfig!.disciplines.length,
                            itemBuilder: (context, index) {
                              final discipline = _localConfig!.disciplines[index];
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
                                  title: Row(
                                    children: [
                                      Text(
                                        discipline.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      if (discipline.abbreviation != null && discipline.abbreviation!.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            discipline.abbreviation!,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: discipline.description != null && discipline.description!.isNotEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text(discipline.description!),
                                        )
                                      : null,
                                  trailing: _isEditing
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                                              onPressed: () => _showEditDisciplineDialog(discipline),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                              onPressed: () => _confirmRemoveDiscipline(discipline.name),
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
                _isEditing ? 'Disciplines Config (Editing)' : 'Disciplines Configuration',
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
              onPressed: _showAddDisciplineDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
