import 'package:flutter/material.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/association_member.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/utils/image_url_resolver.dart';

class AddMemberResult {
  final List<String> userIds;
  final String role;
  final String? customTitle;
  AddMemberResult({required this.userIds, required this.role, this.customTitle});
}

class AddMemberDialog extends StatefulWidget {
  final ProfileRepository profileRepository;
  const AddMemberDialog({Key? key, required this.profileRepository}) : super(key: key);

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  String _role = 'editor';
  List<Profile> _searchResults = [];
  final Set<String> _selectedUserIds = {};
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    try {
      final results = await widget.profileRepository.searchProfiles(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      debugPrint('Error searching profiles: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add Association Member'),
      content: Container(
        constraints: const BoxConstraints(minWidth: 800, minHeight: 400, maxWidth: 1200),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomDropdownFieldModal<String>(
                context: context,
                labelText: 'Permission Role',
                value: _role,
                displayValue: (val) => val[0].toUpperCase() + val.substring(1),
                items: const [
                  PopupMenuItem(value: 'owner', child: Text('Owner')),
                  PopupMenuItem(value: 'editor', child: Text('Editor')),
                  PopupMenuItem(value: 'manager', child: Text('Manager')),
                  PopupMenuItem(value: 'partner', child: Text('Partner')),
                ],
                onChanged: (val) {
                  setState(() {
                    _role = val;
                    if (_role == 'owner' && _selectedUserIds.length > 1) {
                      final first = _selectedUserIds.first;
                      _selectedUserIds.clear();
                      _selectedUserIds.add(first);
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: _performSearch,
                decoration: InputDecoration(
                  labelText: 'Search by username or name',
                  hintText: 'e.g. johndoe',
                  suffixIcon: IconButton(
                     icon: const Icon(Icons.search),
                     onPressed: () => _performSearch(_searchController.text),
                  ),
                ),
                onSubmitted: _performSearch,
              ),
              const SizedBox(height: 12),
              Text(
                'Search Results',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                        ? const Center(child: Text('Search and select users.'))
                        : SingleChildScrollView(
                            child: Column(
                              children: _searchResults.map((user) {
                                final isSelected = _selectedUserIds.contains(user.id);
                                final avatarUrl = user.profilePictureUrl;
                                return CheckboxListTile(
                                  secondary: CircleAvatar(
                                    radius: 16,
                                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                        ? NetworkImage(ImageUrlResolver.resolve(context, avatarUrl))
                                        : null,
                                    child: avatarUrl == null || avatarUrl.isEmpty
                                        ? Text(
                                            (user.username.isNotEmpty ? user.username[0] : 'U').toUpperCase(),
                                            style: const TextStyle(fontSize: 12),
                                          )
                                        : null,
                                  ),
                                  title: Text(user.fullName),
                                  subtitle: Text(
                                    user.username.isNotEmpty ? '@${user.username}' : '',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  value: isSelected,
                                  onChanged: (bool? val) {
                                    setState(() {
                                      if (_role == 'owner') {
                                        _selectedUserIds.clear();
                                        if (val == true) {
                                          _selectedUserIds.add(user.id);
                                        }
                                      } else {
                                        if (val == true) {
                                          _selectedUserIds.add(user.id);
                                        } else {
                                          _selectedUserIds.remove(user.id);
                                        }
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Custom Title',
                  hintText: 'e.g. Chief Administrator',
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
          onPressed: _selectedUserIds.isEmpty
              ? null
              : () {
                  Navigator.of(context).pop(AddMemberResult(
                    userIds: _selectedUserIds.toList(),
                    role: _role,
                    customTitle: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
                  ));
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE94E1B),
            foregroundColor: Colors.white,
          ),
          child: const Text('ADD'),
        ),
      ],
    );
  }

  Widget _buildCustomDropdownFieldModal<T>({
    required BuildContext context,
    required String labelText,
    required T value,
    required List<PopupMenuEntry<T>> items,
    required Function(T) onChanged,
    Widget? prefixIcon,
    String Function(T)? displayValue,
  }) {
    final theme = Theme.of(context);
    final displayStr = displayValue != null ? displayValue(value) : value.toString();
    return Theme(
      data: theme.copyWith(
        cardColor: theme.colorScheme.surface,
      ),
      child: PopupMenuButton<T>(
        tooltip: labelText,
        offset: const Offset(0, 48),
        onSelected: onChanged,
        itemBuilder: (BuildContext context) => items,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: labelText,
            prefixIcon: prefixIcon,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayStr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
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
    );
  }
}

class UpdateMemberResult {
  final String role;
  final String? customTitle;
  UpdateMemberResult({required this.role, this.customTitle});
}

class UpdateMemberDialog extends StatefulWidget {
  final AssociationMember member;
  final Profile? profile;
  const UpdateMemberDialog({Key? key, required this.member, this.profile}) : super(key: key);

  @override
  State<UpdateMemberDialog> createState() => _UpdateMemberDialogState();
}

class _UpdateMemberDialogState extends State<UpdateMemberDialog> {
  late TextEditingController _titleController;
  late String _role;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.member.customTitle ?? '');
    _role = widget.member.role;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = widget.profile?.fullName ?? widget.member.userId;
    return AlertDialog(
      title: Text('Update Member: $displayName'),
      content: Container(
        constraints: const BoxConstraints(minWidth: 800, minHeight: 400, maxWidth: 1200),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Custom Title',
                  hintText: 'e.g. Technical Director',
                ),
              ),
              if (widget.member.role != 'owner') ...[
                const SizedBox(height: 16),
                _buildCustomDropdownFieldModal<String>(
                  context: context,
                  labelText: 'Permission Role',
                  value: _role,
                  displayValue: (val) => val[0].toUpperCase() + val.substring(1),
                  items: const [
                    PopupMenuItem(value: 'owner', child: Text('Owner')),
                    PopupMenuItem(value: 'editor', child: Text('Editor')),
                    PopupMenuItem(value: 'manager', child: Text('Manager')),
                    PopupMenuItem(value: 'partner', child: Text('Partner')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _role = val;
                    });
                  },
                ),
              ],
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
          onPressed: () {
            Navigator.of(context).pop(UpdateMemberResult(
              role: _role,
              customTitle: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
            ));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE94E1B),
            foregroundColor: Colors.white,
          ),
          child: const Text('SAVE'),
        ),
      ],
    );
  }

  Widget _buildCustomDropdownFieldModal<T>({
    required BuildContext context,
    required String labelText,
    required T value,
    required List<PopupMenuEntry<T>> items,
    required Function(T) onChanged,
    Widget? prefixIcon,
    String Function(T)? displayValue,
  }) {
    final theme = Theme.of(context);
    final displayStr = displayValue != null ? displayValue(value) : value.toString();
    return Theme(
      data: theme.copyWith(
        cardColor: theme.colorScheme.surface,
      ),
      child: PopupMenuButton<T>(
        tooltip: labelText,
        offset: const Offset(0, 48),
        onSelected: onChanged,
        itemBuilder: (BuildContext context) => items,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: labelText,
            prefixIcon: prefixIcon,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayStr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
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
    );
  }
}
