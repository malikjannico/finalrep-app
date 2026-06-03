import 'package:flutter/material.dart';
import 'package:finalrep_app/models/association_member.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/utils/image_url_resolver.dart';
import 'package:finalrep_app/views/association_management_page.dart';
import 'package:finalrep_app/views/association/widgets/flat_list_item.dart';

class MembersTabView extends StatelessWidget {
  final AssociationManagementPageState state;

  const MembersTabView({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flatItems = state.buildMembersFlatList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${state.members.length} Members',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (state.hasManagePermission && MediaQuery.of(context).size.width >= 900)
                ElevatedButton.icon(
                  onPressed: state.showAddMemberModal,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Member'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94E1B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
            ],
          ),
        ),
        if (state.members.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No members added yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              itemCount: flatItems.length,
              itemBuilder: (context, idx) {
                final item = flatItems[idx];
                if (item is FlatHeaderItem) {
                  final isExpanded = !state.userCollapsedKeys.contains(item.key);
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () {
                        state.setState(() {
                          if (state.userCollapsedKeys.contains(item.key)) {
                            state.userCollapsedKeys.remove(item.key);
                          } else {
                            state.userCollapsedKeys.add(item.key);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
                        child: Row(
                          children: [
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            if (item.countText != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  item.countText!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSecondaryContainer,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                } else if (item is FlatMemberCardItem) {
                  final member = item.member;
                  final profile = state.memberProfiles[member.userId];
                  final isOwner = member.role == 'owner' || (state.association != null && member.userId == state.association!.ownerId);
                  
                  final displayName = profile?.fullName ?? member.userId;
                  final displayUsername = profile != null ? '@${profile.username}' : '';
                  final avatarUrl = profile?.profilePictureUrl;

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                            ? NetworkImage(ImageUrlResolver.resolve(context, avatarUrl))
                            : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? Text(
                                (profile?.username.isNotEmpty == true 
                                    ? profile!.username[0] 
                                    : (profile?.fullName.isNotEmpty == true 
                                        ? profile!.fullName[0] 
                                        : 'U')).toUpperCase(),
                                style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      title: Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (displayUsername.isNotEmpty) ...[
                            Text(
                              displayUsername,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (member.customTitle != null && member.customTitle!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(
                                member.customTitle!.toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: theme.colorScheme.outlineVariant.withOpacity(0.3),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: state.hasManagePermission
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: isOwner
                                  ? [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Update Member Title',
                                        color: theme.colorScheme.primary,
                                        onPressed: () => state.showUpdateMemberModal(member, profile),
                                      ),
                                    ]
                                  : [
                                      IconButton(
                                        icon: const Icon(Icons.swap_horiz_outlined),
                                        tooltip: 'Transfer Ownership',
                                        color: const Color(0xFFE94E1B),
                                        onPressed: () => state.transferOwnership(member.userId),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Update Member',
                                        color: theme.colorScheme.primary,
                                        onPressed: () => state.showUpdateMemberModal(member, profile),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                        tooltip: 'Remove Member',
                                        onPressed: () => state.showRemoveMemberConfirmation(member, profile),
                                      ),
                                    ],
                            )
                          : null,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
      ],
    );
  }
}
