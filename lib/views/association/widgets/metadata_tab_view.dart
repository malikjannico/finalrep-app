import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/utils/image_url_resolver.dart';
import 'package:finalrep_app/views/association_management_page.dart';
import 'package:finalrep_app/widgets/verified_location_badge.dart';

class MetadataTabView extends StatelessWidget {
  final AssociationManagementPageState state;

  const MetadataTabView({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: state.metadataFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Title & Action Buttons (Edit, Save, Cancel)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Association Metadata',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (MediaQuery.of(context).size.width >= 900) ...[
                  if (!state.isEditingMetadata)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.hasManagePermission)
                          ElevatedButton.icon(
                            onPressed: () => state.setState(() => state.isEditingMetadata = true),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('EDIT'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE94E1B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                      ],
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: state.resetMetadataFields,
                          child: const Text('CANCEL'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: state.saveMetadata,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE94E1B),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('SAVE'),
                        ),
                      ],
                    ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Card 1: General Information
            Card(
              margin: const EdgeInsets.only(bottom: 24),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'General Information',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: state.nameController,
                              enabled: state.isEditingMetadata,
                              decoration: const InputDecoration(
                                labelText: 'Association Name *',
                                prefixIcon: Icon(Icons.business_outlined),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Enter name' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: state.descController,
                              enabled: state.isEditingMetadata,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Description / Bio *',
                                prefixIcon: Icon(Icons.description_outlined),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Enter description' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Card 2: Scope & Location
            Card(
              margin: const EdgeInsets.only(bottom: 24),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scope & Location',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCustomDropdownField<String>(
                              context: context,
                              labelText: 'Scope',
                              value: state.scope,
                              enabled: state.isEditingMetadata,
                              prefixIcon: Icon(Icons.map_outlined, color: state.isEditingMetadata ? theme.colorScheme.primary : null, size: 20),
                              displayValue: (val) {
                                if (val == 'global') return 'Global';
                                if (val == 'continental') return 'Continental';
                                if (val == 'national') return 'National';
                                if (val == 'local') return 'Local';
                                return val;
                              },
                              items: const [
                                PopupMenuItem(value: 'global', child: Text('Global')),
                                PopupMenuItem(value: 'continental', child: Text('Continental')),
                                PopupMenuItem(value: 'national', child: Text('National')),
                                PopupMenuItem(value: 'local', child: Text('Local')),
                              ],
                              onChanged: state.isEditingMetadata
                                  ? (val) {
                                      state.setState(() {
                                        state.scope = val;
                                        state.isLocationVerified = false;
                                      });
                                    }
                                  : (val) {},
                            ),
                            const SizedBox(height: 16),
                            if (state.scope == 'continental') ...[
                              TextFormField(
                                controller: state.areaNameController,
                                enabled: state.isEditingMetadata,
                                decoration: const InputDecoration(
                                  labelText: 'Continent / Regional Area *',
                                  hintText: 'e.g. Europe, Asia',
                                  prefixIcon: Icon(Icons.language),
                                ),
                                onChanged: (val) => state.updateLocationSuggestions('area', val),
                                validator: (val) => state.scope == 'continental' && (val == null || val.trim().isEmpty) ? 'Area name is required' : null,
                              ),
                              if (state.isEditingMetadata && state.activeLocationField == 'area' && state.locationSuggestions.isNotEmpty)
                                state.buildSuggestionsList(state.areaNameController),
                            ],
                            if (state.scope == 'national') ...[
                              TextFormField(
                                controller: state.countryController,
                                enabled: state.isEditingMetadata,
                                decoration: const InputDecoration(
                                  labelText: 'Country *',
                                  hintText: 'e.g. Germany',
                                  prefixIcon: Icon(Icons.public),
                                ),
                                onChanged: (val) => state.updateLocationSuggestions('country', val),
                                validator: (val) => state.scope == 'national' && (val == null || val.trim().isEmpty) ? 'Country is required' : null,
                              ),
                              if (state.isEditingMetadata && state.activeLocationField == 'country' && state.locationSuggestions.isNotEmpty)
                                state.buildSuggestionsList(state.countryController),
                            ],
                            if (state.scope == 'local') ...[
                              TextFormField(
                                controller: state.countryController,
                                enabled: state.isEditingMetadata,
                                decoration: const InputDecoration(
                                  labelText: 'Country *',
                                  hintText: 'e.g. Germany',
                                  prefixIcon: Icon(Icons.public),
                                ),
                                onChanged: (val) => state.updateLocationSuggestions('country', val),
                                validator: (val) => state.scope == 'local' && (val == null || val.trim().isEmpty) ? 'Country is required' : null,
                              ),
                              if (state.isEditingMetadata && state.activeLocationField == 'country' && state.locationSuggestions.isNotEmpty)
                                state.buildSuggestionsList(state.countryController),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextFormField(
                                          controller: state.zipController,
                                          enabled: state.isEditingMetadata,
                                          decoration: const InputDecoration(
                                            labelText: 'ZIP Code *',
                                            hintText: 'e.g. 22529',
                                            prefixIcon: Icon(Icons.pin_drop_outlined),
                                          ),
                                          onChanged: (val) => state.updateLocationSuggestions('zip', val),
                                          validator: (val) => state.scope == 'local' && (val == null || val.trim().isEmpty) ? 'ZIP Code is required' : null,
                                        ),
                                        if (state.isEditingMetadata && state.activeLocationField == 'zip' && state.locationSuggestions.isNotEmpty)
                                          state.buildSuggestionsList(state.zipController),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextFormField(
                                          controller: state.cityController,
                                          enabled: state.isEditingMetadata,
                                          decoration: const InputDecoration(
                                            labelText: 'City *',
                                            hintText: 'e.g. Hamburg',
                                            prefixIcon: Icon(Icons.location_city),
                                          ),
                                          onChanged: (val) => state.updateLocationSuggestions('city', val),
                                          validator: (val) => state.scope == 'local' && (val == null || val.trim().isEmpty) ? 'City is required' : null,
                                        ),
                                        if (state.isEditingMetadata && state.activeLocationField == 'city' && state.locationSuggestions.isNotEmpty)
                                          state.buildSuggestionsList(state.cityController),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Card 3: Media Assets
            Card(
              margin: const EdgeInsets.only(bottom: 24),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Media Assets',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Logo / Profile Image', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.info_outline, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Recommended Size: 500 x 500 px (1:1 Aspect Ratio)',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: state.isEditingMetadata ? (state.isUploadingLogo ? null : state.pickLogoImage) : null,
                                        icon: state.isUploadingLogo
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Icon(Icons.cloud_upload_outlined, size: 18),
                                        label: const Text(
                                          'Upload Logo',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE94E1B),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          state.logoFileName ?? (state.profilePictureUrlController.text.isNotEmpty ? 'Custom logo set' : 'No image selected'),
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (state.profilePictureUrlController.text.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        ImageUrlResolver.resolve(context, state.profilePictureUrlController.text),
                                        height: 80,
                                        width: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 80),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text('Banner Image', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.info_outline, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Recommended Size: 1200 x 400 px (3:1 Aspect Ratio)',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: state.isEditingMetadata ? (state.isUploadingBanner ? null : state.pickBannerImage) : null,
                                        icon: state.isUploadingBanner
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Icon(Icons.cloud_upload_outlined, size: 18),
                                        label: const Text(
                                          'Upload Banner',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE94E1B),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          state.bannerFileName ?? (state.bannerUrlController.text.isNotEmpty ? 'Custom banner set' : 'No image selected'),
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (state.bannerUrlController.text.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        ImageUrlResolver.resolve(context, state.bannerUrlController.text),
                                        height: 100,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Card 4: Social & Channels
            Card(
              margin: const EdgeInsets.only(bottom: 24),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Social & Channels',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: state.websiteController,
                              enabled: state.isEditingMetadata,
                              decoration: const InputDecoration(
                                labelText: 'Official Website URL',
                                hintText: 'https://www.example.com',
                                prefixIcon: Icon(Icons.language),
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
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            Text('Social Media Handles / URLs', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: state.socialControllers.length,
                              itemBuilder: (context, idx) {
                                final platform = state.socialControllers.keys.elementAt(idx);
                                final controller = state.socialControllers[platform]!;
                                Widget prefixIcon = const Icon(Icons.link);
                                if (platform == 'Instagram') prefixIcon = const FaIcon(FontAwesomeIcons.instagram, size: 18);
                                if (platform == 'YouTube') prefixIcon = const FaIcon(FontAwesomeIcons.youtube, size: 18);
                                if (platform == 'Facebook') prefixIcon = const FaIcon(FontAwesomeIcons.facebook, size: 18);
                                if (platform == 'Twitch') prefixIcon = const FaIcon(FontAwesomeIcons.twitch, size: 18);
                                if (platform == 'Twitter/X') prefixIcon = const FaIcon(FontAwesomeIcons.xTwitter, size: 18);
                                if (platform == 'TikTok') prefixIcon = const FaIcon(FontAwesomeIcons.tiktok, size: 18);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: TextFormField(
                                    controller: controller,
                                    enabled: state.isEditingMetadata,
                                    decoration: InputDecoration(
                                      labelText: '$platform Username / URL',
                                      hintText: 'e.g. handle or link',
                                      prefixIcon: Container(
                                        width: 48,
                                        height: 48,
                                        alignment: Alignment.center,
                                        child: prefixIcon,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (state.isOwner && !state.isEditingMetadata) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  key: const Key('delete_association_button'),
                  onPressed: state.showDeleteAssociationConfirmation,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('DELETE ASSOCIATION'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomDropdownField<T>({
    required BuildContext context,
    required String labelText,
    required T value,
    required List<PopupMenuEntry<T>> items,
    required Function(T) onChanged,
    bool enabled = true,
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
        tooltip: enabled ? labelText : null,
        offset: const Offset(0, 48),
        onSelected: onChanged,
        itemBuilder: (BuildContext context) => items,
        enabled: enabled,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: labelText,
            prefixIcon: prefixIcon,
            enabled: enabled,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayStr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: enabled ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
