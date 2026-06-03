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
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    final allSelected = _searchResults.isNotEmpty && _searchResults.every((u) => _selectedUserIds.contains(u.id));
    final anySelected = _searchResults.any((u) => _selectedUserIds.contains(u.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          minWidth: isMobile ? 0 : 800,
          maxWidth: isMobile ? 600 : 1000,
          minHeight: isMobile ? 300 : 500,
          maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.9 : 700,
        ),
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Add Association Member',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildRoleDropdown(theme),
                      const SizedBox(height: 16),
                      _buildCustomTitleField(theme),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _buildRoleDropdown(theme)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildCustomTitleField(theme)),
                    ],
                  ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _performSearch,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by username or name...',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedUserIds.length} selected',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_role != 'owner' && _searchResults.isNotEmpty)
                  Row(
                    children: [
                      const Text('Select All shown'),
                      Checkbox(
                        value: allSelected ? true : (anySelected ? null : false),
                        tristate: true,
                        activeColor: const Color(0xFFE94E1B),
                        onChanged: (bool? checked) {
                          setState(() {
                            if (checked == true) {
                              for (var user in _searchResults) {
                                _selectedUserIds.add(user.id);
                              }
                            } else {
                              for (var user in _searchResults) {
                                _selectedUserIds.remove(user.id);
                              }
                            }
                          });
                        },
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'Search by username or name to find users.'
                                : 'No users found.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, idx) {
                            final user = _searchResults[idx];
                            final isSelected = _selectedUserIds.contains(user.id);
                            final avatarUrl = user.profilePictureUrl;
                            return Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: CheckboxListTile(
                                activeColor: const Color(0xFFE94E1B),
                                secondary: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                      ? NetworkImage(ImageUrlResolver.resolve(context, avatarUrl))
                                      : null,
                                  child: avatarUrl == null || avatarUrl.isEmpty
                                      ? Text(
                                          (user.username.isNotEmpty ? user.username[0] : 'U').toUpperCase(),
                                          style: TextStyle(
                                            color: theme.colorScheme.onPrimaryContainer,
                                            fontSize: 12,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: _selectedUserIds.isEmpty
                            ? null
                            : () {
                                Navigator.of(context).pop(AddMemberResult(
                                  userIds: _selectedUserIds.toList(),
                                  role: _role,
                                  customTitle: _titleController.text.trim().isEmpty
                                      ? null
                                      : _titleController.text.trim(),
                                ));
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE94E1B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('ADD'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('CANCEL'),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('CANCEL'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _selectedUserIds.isEmpty
                            ? null
                            : () {
                                Navigator.of(context).pop(AddMemberResult(
                                  userIds: _selectedUserIds.toList(),
                                  role: _role,
                                  customTitle: _titleController.text.trim().isEmpty
                                      ? null
                                      : _titleController.text.trim(),
                                ));
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE94E1B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('ADD'),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleDropdown(ThemeData theme) {
    return _buildCustomDropdownFieldModal<String>(
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
    );
  }

  Widget _buildCustomTitleField(ThemeData theme) {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Custom Title',
        hintText: 'e.g. Chief Administrator',
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      ),
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
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
