import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import '../models/admin_config.dart';

class FormatsConfigPage extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onBack;
  const FormatsConfigPage({
    super.key,
    this.isEmbedded = false,
    this.onBack,
  });

  @override
  State<FormatsConfigPage> createState() => _FormatsConfigPageState();
}

class _FormatsConfigPageState extends State<FormatsConfigPage> {
  SportConfig? _localConfig;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isCreating = false;

  String? _createSelectedSport;
  final TextEditingController _createNameController = TextEditingController();
  final TextEditingController _createDescController = TextEditingController();
  final Set<String> _createSelectedDisciplines = {};
  String _createDisciplineSearchQuery = '';
  final TextEditingController _createDisciplineSearchController = TextEditingController();

  @override
  void dispose() {
    _createNameController.dispose();
    _createDescController.dispose();
    _createDisciplineSearchController.dispose();
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
            content: Text('Formats configuration saved successfully.'),
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

  void _showAddFormatDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    if (_localConfig!.sports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please define at least one sport first.')),
      );
      return;
    }

    String selectedSport = _localConfig!.sports.first.name;
    final selectedDisciplines = <String>{};
    String disciplineSearchQuery = '';

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredDisciplines = _localConfig!.disciplines
                .where((d) => d.name.toLowerCase().contains(disciplineSearchQuery.toLowerCase()))
                .toList();

            return AlertDialog(
              title: const Text('Add New Format'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedSport,
                        decoration: const InputDecoration(
                          labelText: 'Sport Name',
                          border: OutlineInputBorder(),
                        ),
                        items: _localConfig!.sports.map((s) {
                          return DropdownMenuItem<String>(
                            value: s.name,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedSport = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Format Name',
                          hintText: 'e.g. Modern, Classic',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'e.g. Exercises involved',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Map Disciplines',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search disciplines...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            disciplineSearchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      if (_localConfig!.disciplines.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('No disciplines defined in system.', style: TextStyle(color: Colors.redAccent)),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: filteredDisciplines.map((d) {
                              final isChecked = selectedDisciplines.contains(d.name);
                              return CheckboxListTile(
                                title: Text(d.name),
                                value: isChecked,
                                visualDensity: VisualDensity.compact,
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedDisciplines.add(d.name);
                                    } else {
                                      selectedDisciplines.remove(d.name);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94E1B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final desc = descController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Format name cannot be empty.')),
                      );
                      return;
                    }

                    if (_localConfig!.formats.any(
                      (f) => f.sportName == selectedSport && f.name.toLowerCase() == name.toLowerCase(),
                    )) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Format already exists for this sport.')),
                      );
                      return;
                    }

                    final updatedFormats = List<FormatDefinition>.from(_localConfig!.formats)
                      ..add(FormatDefinition(
                        sportName: selectedSport,
                        name: name,
                        description: desc.isEmpty ? null : desc,
                      ));

                    final updatedLinks = List<FormatDisciplineLink>.from(_localConfig!.links);
                    for (final discName in selectedDisciplines) {
                      updatedLinks.add(FormatDisciplineLink(
                        sportName: selectedSport,
                        formatName: name,
                        disciplineName: discName,
                      ));
                    }

                    final updatedConfig = SportConfig(
                      sports: _localConfig!.sports,
                      formats: updatedFormats,
                      disciplines: _localConfig!.disciplines,
                      links: updatedLinks,
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
                            content: Text('Format created successfully.'),
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
                        throw Exception('Failed to save formats configuration.');
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating format: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                  child: const Text('CREATE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditFormatDialog(FormatDefinition format) {
    final nameController = TextEditingController(text: format.name);
    final descController = TextEditingController(text: format.description ?? '');

    String selectedSport = format.sportName;
    final selectedDisciplines = _localConfig!.links
        .where((l) => l.sportName == format.sportName && l.formatName == format.name)
        .map((l) => l.disciplineName)
        .toSet();
    String disciplineSearchQuery = '';

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredDisciplines = _localConfig!.disciplines
                .where((d) => d.name.toLowerCase().contains(disciplineSearchQuery.toLowerCase()))
                .toList();

            return AlertDialog(
              title: const Text('Update Format'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedSport,
                        decoration: const InputDecoration(
                          labelText: 'Sport Name',
                          border: OutlineInputBorder(),
                        ),
                        items: _localConfig!.sports.map((s) {
                          return DropdownMenuItem<String>(
                            value: s.name,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedSport = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Format Name',
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
                      const SizedBox(height: 20),
                      Text(
                        'Map Disciplines',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search disciplines...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            disciplineSearchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      if (_localConfig!.disciplines.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('No disciplines defined in system.', style: TextStyle(color: Colors.redAccent)),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: filteredDisciplines.map((d) {
                              final isChecked = selectedDisciplines.contains(d.name);
                              return CheckboxListTile(
                                title: Text(d.name),
                                value: isChecked,
                                visualDensity: VisualDensity.compact,
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedDisciplines.add(d.name);
                                    } else {
                                      selectedDisciplines.remove(d.name);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94E1B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final desc = descController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Format name cannot be empty.')),
                      );
                      return;
                    }

                    final nameOrSportChanged = (selectedSport != format.sportName || name.toLowerCase() != format.name.toLowerCase());
                    if (nameOrSportChanged &&
                        _localConfig!.formats.any(
                          (f) => f.sportName == selectedSport && f.name.toLowerCase() == name.toLowerCase(),
                        )) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Format name already exists for this sport.')),
                      );
                      return;
                    }

                    setState(() {
                      // 1. Update formats list
                      final updatedFormats = _localConfig!.formats.map((f) {
                        if (f.sportName == format.sportName && f.name == format.name) {
                          return FormatDefinition(
                            sportName: selectedSport,
                            name: name,
                            description: desc.isEmpty ? null : desc,
                          );
                        }
                        return f;
                      }).toList();

                      // 2. Clear old links for this format, then insert new ones
                      final updatedLinks = List<FormatDisciplineLink>.from(_localConfig!.links)
                        ..removeWhere((l) => l.sportName == format.sportName && l.formatName == format.name);

                      for (final discName in selectedDisciplines) {
                        updatedLinks.add(FormatDisciplineLink(
                          sportName: selectedSport,
                          formatName: name,
                          disciplineName: discName,
                        ));
                      }

                      _localConfig = SportConfig(
                        sports: _localConfig!.sports,
                        formats: updatedFormats,
                        disciplines: _localConfig!.disciplines,
                        links: updatedLinks,
                      );
                    });

                    Navigator.of(context).pop();
                  },
                  child: const Text('UPDATE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removeFormat(String sportName, String formatName) {
    setState(() {
      final updatedFormats = List<FormatDefinition>.from(_localConfig!.formats)
        ..removeWhere((f) => f.sportName == sportName && f.name == formatName);
      final updatedLinks = List<FormatDisciplineLink>.from(_localConfig!.links)
        ..removeWhere((l) => l.sportName == sportName && l.formatName == formatName);

      _localConfig = SportConfig(
        sports: _localConfig!.sports,
        formats: updatedFormats,
        disciplines: _localConfig!.disciplines,
        links: updatedLinks,
      );
    });
  }

  Future<void> _confirmRemoveFormat(String sportName, String formatName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Format?'),
        content: Text('Are you sure you want to delete the format "$formatName" from "$sportName"?'),
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
      _removeFormat(sportName, formatName);
    }
  }

  Future<void> _handleCreateFormat({required bool saveAndCreateAnother}) async {
    final name = _createNameController.text.trim();
    final desc = _createDescController.text.trim();
    final sport = _createSelectedSport;
    if (name.isEmpty || sport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format name and sport cannot be empty.')),
      );
      return;
    }

    if (_localConfig!.formats.any(
      (f) => f.sportName == sport && f.name.toLowerCase() == name.toLowerCase(),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format already exists for this sport.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Add format
      final updatedFormats = List<FormatDefinition>.from(_localConfig!.formats)
        ..add(FormatDefinition(
          sportName: sport,
          name: name,
          description: desc.isEmpty ? null : desc,
        ));

      // 2. Add links
      final updatedLinks = List<FormatDisciplineLink>.from(_localConfig!.links);
      for (final dName in _createSelectedDisciplines) {
        updatedLinks.add(FormatDisciplineLink(
          sportName: sport,
          formatName: name,
          disciplineName: dName,
        ));
      }

      final updatedConfig = SportConfig(
        sports: _localConfig!.sports,
        formats: updatedFormats,
        disciplines: _localConfig!.disciplines,
        links: updatedLinks,
      );

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.saveSportsConfig(updatedConfig);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Format created successfully.'),
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
          _createSelectedDisciplines.clear();
          _createDisciplineSearchQuery = '';
          _createDisciplineSearchController.clear();
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

  Widget _buildFormatsCreationForm(ThemeData theme) {
    if (_localConfig == null) return const SizedBox.shrink();

    final sportsList = _localConfig!.sports.map((s) => s.name).toList();
    if (sportsList.isNotEmpty && (_createSelectedSport == null || !sportsList.contains(_createSelectedSport))) {
      _createSelectedSport = sportsList.first;
    }

    final filteredDisciplines = _localConfig!.disciplines
        .where((d) => d.name.toLowerCase().contains(_createDisciplineSearchQuery.toLowerCase()))
        .toList();

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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Create New Format',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    if (sportsList.isEmpty)
                      const Text(
                        'Please define at least one sport first.',
                        style: TextStyle(color: Colors.redAccent),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        value: _createSelectedSport,
                        decoration: const InputDecoration(
                          labelText: 'Sport Name',
                          border: OutlineInputBorder(),
                        ),
                        items: _localConfig!.sports.map((s) {
                          return DropdownMenuItem<String>(
                            value: s.name,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _createSelectedSport = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _createNameController,
                        decoration: const InputDecoration(
                          labelText: 'Format Name',
                          hintText: 'e.g. Modern, Classic',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _createDescController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'e.g. Exercises involved',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Map Disciplines',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _createDisciplineSearchController,
                        decoration: const InputDecoration(
                          hintText: 'Search disciplines...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _createDisciplineSearchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      if (_localConfig!.disciplines.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No disciplines defined in system.',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: filteredDisciplines.map((d) {
                              final isChecked = _createSelectedDisciplines.contains(d.name);
                              return CheckboxListTile(
                                title: Text(d.name),
                                value: isChecked,
                                visualDensity: VisualDensity.compact,
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _createSelectedDisciplines.add(d.name);
                                    } else {
                                      _createSelectedDisciplines.remove(d.name);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ],
                ),
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
                              child: const Text('Formats'),
                            ),
                            Text(
                              ' / Create Format',
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
                              ' / Formats',
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
                                onPressed: () => _handleCreateFormat(saveAndCreateAnother: true),
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
                                onPressed: () => _handleCreateFormat(saveAndCreateAnother: false),
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
                                label: const Text('Create Format', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                    ? _buildFormatsCreationForm(theme)
                    : (_localConfig == null || _localConfig!.formats.isEmpty
                        ? const Center(child: Text('No formats defined.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _localConfig!.formats.length,
                            itemBuilder: (context, index) {
                              final format = _localConfig!.formats[index];
                              final sportLinks = _localConfig!.links
                                  .where((l) => l.sportName == format.sportName && l.formatName == format.name)
                                  .map((l) => l.disciplineName)
                                  .join(', ');

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
                                    '${format.sportName} — ${format.name}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (format.description != null && format.description!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text(format.description!),
                                        ),
                                      if (sportLinks.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6.0),
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: sportLinks.split(', ').map((d) {
                                              return Chip(
                                                label: Text(d, style: const TextStyle(fontSize: 11)),
                                                padding: EdgeInsets.zero,
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                visualDensity: VisualDensity.compact,
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: _isEditing
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                                              onPressed: () => _showEditFormatDialog(format),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                              onPressed: () => _confirmRemoveFormat(format.sportName, format.name),
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
                _isEditing ? 'Formats Config (Editing)' : 'Formats Configuration',
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
              onPressed: _showAddFormatDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
