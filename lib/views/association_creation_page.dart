import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import '../models/association.dart';

class AssociationCreationPage extends StatefulWidget {
  const AssociationCreationPage({super.key});

  @override
  State<AssociationCreationPage> createState() => _AssociationCreationPageState();
}

class _AssociationCreationPageState extends State<AssociationCreationPage> {
  int _currentStep = 0;
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // Form Fields - Step 1: Metadata
  final TextEditingController _nameController = TextEditingController();
  String _scope = 'local'; // 'global', 'area', 'local'
  final TextEditingController _areaNameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // Form Fields - Step 2: Rules
  final Map<String, TextEditingController> _rulebookControllers = {
    'Streetlifting': TextEditingController(text: 'https://example.com/streetlifting-rules.pdf'),
  };

  // Form Fields - Step 3: Social & Admin
  final List<String> _supportedSports = ['Streetlifting'];
  final List<String> _supportedFormats = ['Modern', 'Classic'];
  final Map<String, TextEditingController> _socialControllers = {
    'Instagram': TextEditingController(),
    'Facebook': TextEditingController(),
  };

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _areaNameController.dispose();
    _descController.dispose();
    for (var controller in _rulebookControllers.values) {
      controller.dispose();
    }
    for (var controller in _socialControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitAssociation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);

    if (authProvider.currentUserProfile == null) return;

    setState(() {
      _isSaving = true;
    });

    final name = _nameController.text.trim();
    final areaName = _scope == 'global' ? null : _areaNameController.text.trim();
    final description = _descController.text.trim();

    // Collect rulebooks
    final Map<String, String> rulebooks = {};
    _rulebookControllers.forEach((key, controller) {
      final val = controller.text.trim();
      if (val.isNotEmpty) {
        rulebooks[key] = val;
      }
    });

    // Collect social channels
    final Map<String, String> social = {};
    _socialControllers.forEach((key, controller) {
      final val = controller.text.trim();
      if (val.isNotEmpty) {
        social[key] = val;
      }
    });

    final newAssoc = Association(
      id: 'assoc-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      scope: _scope,
      areaName: areaName,
      description: description,
      rulebooks: rulebooks,
      socialChannels: social,
      status: 'approved', // Auto-approved in this flow
      ownerId: authProvider.currentUserProfile!.id,
      supportedSports: _supportedSports,
      supportedFormats: _supportedFormats,
    );

    try {
      final result = await compProvider.createAssociation(newAssoc);
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Association created successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to create association');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating association: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isAssociationCreator && !authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('Only authorized Association Creators can access this wizard.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Association'),
      ),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Saving association...'),
                ],
              ),
            )
          : Column(
              children: [
                _buildStepperProgress(theme),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildCurrentStepContent(theme),
                  ),
                ),
                _buildStepperActions(theme),
              ],
            ),
    );
  }

  Widget _buildStepperProgress(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepIndicator(0, 'Metadata', theme),
          _buildStepDivider(theme),
          _buildStepIndicator(1, 'Rules & Config', theme),
          _buildStepDivider(theme),
          _buildStepIndicator(2, 'Social & Sports', theme),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String title, ThemeData theme) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isDone
              ? Colors.green
              : isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
          child: isDone
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '${stepIndex + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isActive || isDone ? Colors.white : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(ThemeData theme) {
    return Container(
      width: 30,
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.colorScheme.outlineVariant,
    );
  }

  Widget _buildCurrentStepContent(ThemeData theme) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Metadata(theme);
      case 1:
        return _buildStep2Rules(theme);
      case 2:
        return _buildStep3SocialSports(theme);
      default:
        return Container();
    }
  }

  Widget _buildStep1Metadata(ThemeData theme) {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 1: Association Metadata', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Association Name',
              hintText: 'e.g. Deutsche Streetlifting Association (DSA)',
              prefixIcon: Icon(Icons.business_outlined),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter the association name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _scope,
            decoration: const InputDecoration(
              labelText: 'Scope / Territory',
              prefixIcon: Icon(Icons.map_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'global', child: Text('Global (Governing Body)')),
              DropdownMenuItem(value: 'area', child: Text('Regional / Continental')),
              DropdownMenuItem(value: 'local', child: Text('Local / National')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _scope = val;
                });
              }
            },
          ),
          if (_scope != 'global') ...[
            const SizedBox(height: 20),
            TextFormField(
              controller: _areaNameController,
              decoration: const InputDecoration(
                labelText: 'Area Name',
                hintText: 'e.g. Europe, Germany, Hamburg',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (val) {
                if (_scope != 'global' && (val == null || val.trim().isEmpty)) {
                  return 'Please specify the area/territory name';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 20),
          TextFormField(
            controller: _descController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description / Bio',
              hintText: 'Tell athletes and organizations about this association...',
              prefixIcon: Icon(Icons.description_outlined),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Rules(ThemeData theme) {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 2: Rulebooks & Guidelines', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Associate rulebook PDFs or document URLs for each sport category that this association supports.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rulebookControllers.length,
            itemBuilder: (context, idx) {
              final sportKey = _rulebookControllers.keys.elementAt(idx);
              final controller = _rulebookControllers[sportKey]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: '$sportKey Rulebook URL',
                    hintText: 'https://example.com/rules.pdf',
                    prefixIcon: const Icon(Icons.link_outlined),
                  ),
                  validator: (val) {
                    if (val != null && val.isNotEmpty) {
                      final uri = Uri.tryParse(val);
                      if (uri == null || !uri.hasAbsolutePath) {
                        return 'Please enter a valid URL';
                      }
                    }
                    return null;
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep3SocialSports(ThemeData theme) {
    return Form(
      key: _formKey3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 3: Social Links & Supported Formats', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          Text('Supported Sports & Formats', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Streetlifting'),
                selected: _supportedSports.contains('Streetlifting'),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _supportedSports.add('Streetlifting');
                    } else {
                      _supportedSports.remove('Streetlifting');
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Modern (4 lift)'),
                selected: _supportedFormats.contains('Modern'),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _supportedFormats.add('Modern');
                    } else {
                      _supportedFormats.remove('Modern');
                    }
                  });
                },
              ),
              FilterChip(
                label: const Text('Classic (Pull/Dip)'),
                selected: _supportedFormats.contains('Classic'),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _supportedFormats.add('Classic');
                    } else {
                      _supportedFormats.remove('Classic');
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Social Channels', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _socialControllers.length,
            itemBuilder: (context, idx) {
              final platform = _socialControllers.keys.elementAt(idx);
              final controller = _socialControllers[platform]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: '$platform Handle / Username',
                    hintText: 'e.g. dsa_lifting',
                    prefixIcon: Icon(platform == 'Instagram' ? Icons.camera_alt_outlined : Icons.link),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepperActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentStep--;
                });
              },
              child: const Text('BACK'),
            )
          else
            const SizedBox(),
          ElevatedButton(
            onPressed: () {
              if (_currentStep == 0) {
                if (_formKey1.currentState!.validate()) {
                  setState(() {
                    _currentStep++;
                  });
                }
              } else if (_currentStep == 1) {
                if (_formKey2.currentState!.validate()) {
                  setState(() {
                    _currentStep++;
                  });
                }
              } else {
                if (_formKey3.currentState!.validate()) {
                  _submitAssociation();
                }
              }
            },
            child: Text(_currentStep == 2 ? 'SUBMIT' : 'NEXT'),
          ),
        ],
      ),
    );
  }
}
