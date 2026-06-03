import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/association.dart';
import '../models/association_member.dart';
import '../models/competition_group.dart';
import '../models/athlete_group.dart';
import '../models/profile.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import '../repositories/profile_repository.dart';
import '../utils/mock_safety.dart';
import '../widgets/filter_widgets.dart';
import 'login_page.dart';
import 'association_detail_page.dart';
import 'settings_page.dart';
import 'association_creation_page.dart';
import '../models/admin_config.dart';
import '../utils/image_url_resolver.dart';
import '../widgets/association_card.dart';

import 'association/dialogs/association_member_dialogs.dart';
import 'association/dialogs/competition_group_dialog.dart';
import 'association/dialogs/athlete_group_dialog.dart';
import 'association/dialogs/sport_config_dialog.dart';
import 'association/dialogs/add_sub_association_dialog.dart';
import 'association/dialogs/athlete_groups_reorder_dialog.dart';
import 'association/dialogs/share_resource_dialog.dart';
import 'association/dialogs/share_resource_multi_dialog.dart';
import 'association/dialogs/explore_shared_resources_dialog.dart';
import 'association/dialogs/share_athlete_groups_selection_dialog.dart';
import 'association/widgets/metadata_tab_view.dart';
import 'association/widgets/members_tab_view.dart';
import 'association/widgets/competition_groups_tab_view.dart';
import 'association/widgets/athlete_groups_tab_view.dart';
import 'association/widgets/hoverable_breadcrumb.dart';
import 'association/widgets/collapsible_section.dart';
import 'association/widgets/flat_list_item.dart';
import 'association/widgets/hierarchy_helpers.dart';
import '../widgets/verified_location_badge.dart';
import '../widgets/unified_empty_state.dart';
import '../widgets/dashboard_header.dart';

class AssociationManagementPage extends StatefulWidget {
  final String? associationId; // If null, acts as Management Dashboard for all owned/edited associations
  final bool isInline;
  final bool isPublic; // Deprecated but kept for backward compatibility
  final String? initialTab;

  const AssociationManagementPage({
    super.key,
    this.associationId,
    this.isInline = false,
    this.isPublic = false,
    this.initialTab,
  });

  @override
  State<AssociationManagementPage> createState() =>
      AssociationManagementPageState();
}

class AssociationManagementPageState extends State<AssociationManagementPage>
    with SingleTickerProviderStateMixin {
  // Static cache to prevent reloading data and flashing when GoRouter rebuilds the page on mobile tab changes
  static String? _cachedAssociationId;
  static Association? _cachedAssociation;
  static List<AssociationMember> _cachedMembers = [];
  static Map<String, Profile> _cachedMemberProfiles = {};
  static List<CompetitionGroup> _cachedCompGroups = [];
  static List<AthleteGroup> _cachedAthleteGroups = [];
  static List<CompetitionGroup> _cachedAppliedCompGroups = [];
  static List<AthleteGroup> _cachedAppliedAthleteGroups = [];

  static int? _lastActiveTabIndex;
  static String? _lastActiveTabAssociationId;
  static DateTime? _lastActiveTabTime;

  late TabController _tabController;
  TabController get tabController => _tabController;
  int _currentIndex = 0;
  int _activeIndexedStackIndex = 0;
  final Set<int> _activatedIndices = {};
  Association? _association;
  List<AssociationMember> _members = [];
  final Map<String, Profile> _memberProfiles = {};
  List<CompetitionGroup> _compGroups = [];
  List<AthleteGroup> _athleteGroups = [];
  bool _isLoading = false;
  bool _isEditingMetadata = false;
  final Set<String> _userCollapsedKeys = {};
  bool _isReorderingAthleteGroups = false;
  List<AthleteGroup> _tempAthleteGroups = [];
  final Set<String> _selectedAthleteGroupIds = {};

  // Local filter states for Dashboard View (when associationId is null)
  final Set<String> _selectedAssocScopes = {};
  final Set<String> _selectedAssocCountries = {};
  final Set<String> _selectedAssocAreas = {};
  final Set<String> _selectedAssocSports = {};
  final Set<String> _selectedAssocFormats = {};
  String _assocSortOrder = 'name_asc';
  bool _assocIsCompactLayout = true;

  // Global Key for Scaffold
  final GlobalKey<ScaffoldState> _assocScaffoldKey = GlobalKey<ScaffoldState>();

  // Form keys and Controllers for Editing Metadata
  final _metadataFormKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  String _scope = 'local';
  late TextEditingController _areaNameController;

  // New controllers for complete editing
  late TextEditingController _profilePictureUrlController;
  late TextEditingController _bannerUrlController;
  late TextEditingController _countryController;
  late TextEditingController _cityController;
  late TextEditingController _zipController;
  late TextEditingController _websiteController;
  final Map<String, TextEditingController> _socialControllers = {
    'Instagram': TextEditingController(),
    'YouTube': TextEditingController(),
    'Facebook': TextEditingController(),
    'Twitch': TextEditingController(),
    'Twitter/X': TextEditingController(),
    'TikTok': TextEditingController(),
  };

  // Sports config state
  final Map<String, List<String>> _selectedSportsFormats = {};
  final Map<String, TextEditingController> _rulebookControllers = {};
  String _activeSportType = 'Streetlifting';
  List<String> _activeFormats = [];
  final TextEditingController _activeRulebookController = TextEditingController();

  // Location suggestions and verification
  bool _isLocationVerified = true;
  bool _isVerifyingLocation = false;
  String _activeLocationField = '';
  List<String> _locationSuggestions = [];

  // Media upload state
  bool _isUploadingLogo = false;
  Uint8List? _logoBytes;
  String? _logoFileName;
  bool _isUploadingBanner = false;
  Uint8List? _bannerBytes;
  String? _bannerFileName;

  late ProfileRepository _profileRepository;
  bool _forceExpandSportsAndRulebooks = false;

  // Mock suggestions dictionary
  final Map<String, List<String>> _mockSuggestions = {
    'country': ['Germany', 'Austria', 'Switzerland', 'France', 'United States', 'United Kingdom', 'Canada', 'Spain', 'Italy'],
    'city': ['Hamburg', 'Berlin', 'Munich', 'Frankfurt', 'Vienna', 'Paris', 'London', 'New York', 'Tokyo'],
    'zip': ['22529', '10115', '80331', '60311', '1010', '75001', 'SW1A 1AA'],
    'area': ['Europe', 'Asia', 'North America', 'South America', 'Africa', 'Oceania'],
  };

  // Add Member Controllers
  final TextEditingController _memberUserIdController = TextEditingController();
  final TextEditingController _memberCustomTitleController =
      TextEditingController();
  String _memberRole = 'editor';
  List<String> _userMemberAssociationIds = [];
  List<CompetitionGroup> _appliedCompGroups = [];
  List<AthleteGroup> _appliedAthleteGroups = [];

  // Create Comp Group Controllers
  final TextEditingController _compGroupNameController =
      TextEditingController();
  String _compGroupSport = 'Streetlifting';
  String _compGroupFormat = 'Modern';

  // Create Athlete Group Controllers
  final TextEditingController _athleteGroupNameController =
      TextEditingController();
  String _athleteGroupSport = 'Streetlifting';
  String _athleteGroupFormat = 'Modern';
  String _athleteGroupGender = 'men';

  // Search & Filter state for Competition and Athlete Groups
  String cgSearchQuery = '';
  final Set<String> cgSelectedSports = {};
  final Set<String> cgSelectedFormats = {};
  String agSearchQuery = '';
  final Set<String> agSelectedSports = {};
  final Set<String> agSelectedFormats = {};
  final Set<String> agSelectedGenders = {};

  int _getTabIndexFromTabName(String? name) {
    switch (name) {
      case 'metadata':
        return 0;
      case 'members':
        return 1;
      case 'compgroups':
        return 2;
      case 'athletegroups':
        return 3;
      case 'network':
        return 4;
      default:
        return 0;
    }
  }

  String _getTabNameFromIndex(int index) {
    switch (index) {
      case 0:
        return 'metadata';
      case 1:
        return 'members';
      case 2:
        return 'compgroups';
      case 3:
        return 'athletegroups';
      case 4:
        return 'network';
      default:
        return 'metadata';
    }
  }

  void _onTabChanged() {
    if (_tabController.index != _currentIndex) {
      setState(() {
        _currentIndex = _tabController.index;
        _activeIndexedStackIndex = _tabController.index;
        _activatedIndices.add(_tabController.index);
        _lastActiveTabIndex = _tabController.index;
      });
    }
    if (!_tabController.indexIsChanging) {
      final tabName = _getTabNameFromIndex(_tabController.index);
      final id = widget.associationId;
      if (id != null) {
        final newPath = '/management/associations/$id/$tabName';
        try {
          if (GoRouterState.of(context).matchedLocation != newPath) {
            context.go(newPath);
          }
        } catch (_) {}
      }
    }
  }

  void _populateMetadataControllers(Association assoc, CompetitionProvider compProvider) {
    _nameController.text = assoc.name;
    _descController.text = assoc.description;
    _scope = assoc.scope;
    _isLocationVerified = true; // existing association has verified location
    
    _countryController.text = assoc.country ?? '';
    _areaNameController.text = '';
    _cityController.text = '';
    _zipController.text = '';
    
    if (assoc.scope == 'continental') {
      _areaNameController.text = assoc.areaName ?? '';
    } else if (assoc.scope == 'local') {
      if (assoc.areaName != null && assoc.areaName!.contains(' ')) {
        final parts = assoc.areaName!.split(' ');
        if (parts.isNotEmpty) {
          _zipController.text = parts[0];
          _cityController.text = parts.sublist(1).join(' ');
        }
      } else {
        _cityController.text = assoc.areaName ?? '';
      }
    } else if (assoc.scope == 'national') {
      _countryController.text = assoc.country ?? '';
    }

    _websiteController.text = assoc.website ?? '';
    _profilePictureUrlController.text = assoc.profilePictureUrl ?? '';
    _bannerUrlController.text = assoc.bannerUrl ?? '';
    
    _socialControllers.forEach((platform, controller) {
      controller.text = assoc.socialChannels[platform] ?? '';
    });

    _selectedSportsFormats.clear();
    for (var controller in _rulebookControllers.values) {
      controller.dispose();
    }
    _rulebookControllers.clear();

    for (var sport in assoc.supportedSports) {
      final validFormats = compProvider.sportConfig?.formats
          .where((f) => f.sportName == sport)
          .map((f) => f.name)
          .toList() ?? ['Modern', 'Classic'];
      final formatsForSport = assoc.supportedFormats.where((f) => validFormats.contains(f)).toList();
      _selectedSportsFormats[sport] = formatsForSport;
      _rulebookControllers[sport] = TextEditingController(text: assoc.rulebooks[sport] ?? '');
    }
    _isEditingMetadata = false;
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = _getTabIndexFromTabName(widget.initialTab);
    _currentIndex = initialIndex;
    _activeIndexedStackIndex = initialIndex;
    _activatedIndices.add(initialIndex);
    _lastActiveTabIndex = initialIndex;

    _tabController = TabController(length: 5, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(_onTabChanged);
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _areaNameController = TextEditingController();
    _profilePictureUrlController = TextEditingController();
    _bannerUrlController = TextEditingController();
    _countryController = TextEditingController();
    _cityController = TextEditingController();
    _zipController = TextEditingController();
    _websiteController = TextEditingController();

    // Check static cache
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    if (widget.associationId != null && widget.associationId == _cachedAssociationId && _cachedAssociation != null) {
      _association = _cachedAssociation;
      _members = _cachedMembers;
      _memberProfiles.addAll(_cachedMemberProfiles);
      _compGroups = _cachedCompGroups;
      _athleteGroups = _cachedAthleteGroups;
      _appliedCompGroups = _cachedAppliedCompGroups;
      _appliedAthleteGroups = _cachedAppliedAthleteGroups;
      _populateMetadataControllers(_association!, compProvider);
      _isLoading = false;
    } else {
      _isLoading = widget.associationId != null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void didUpdateWidget(AssociationManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab && widget.initialTab != null) {
      final newIndex = _getTabIndexFromTabName(widget.initialTab);
      if (_tabController.index != newIndex) {
        _tabController.index = newIndex;
      }
      if (_currentIndex != newIndex) {
        setState(() {
          _currentIndex = newIndex;
          _activeIndexedStackIndex = newIndex;
          _activatedIndices.add(newIndex);
          _lastActiveTabIndex = newIndex;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profileRepository = Provider.of<CompetitionProvider>(context, listen: false).profileRepository;
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _areaNameController.dispose();
    _profilePictureUrlController.dispose();
    _bannerUrlController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _websiteController.dispose();
    _activeRulebookController.dispose();
    for (var controller in _rulebookControllers.values) {
      controller.dispose();
    }
    for (var controller in _socialControllers.values) {
      controller.dispose();
    }
    _memberUserIdController.dispose();
    _memberCustomTitleController.dispose();
    _compGroupNameController.dispose();
    _athleteGroupNameController.dispose();
    super.dispose();
  }

  Association? get association => _association;
  List<AssociationMember> get members => _members;
  Map<String, Profile> get memberProfiles => _memberProfiles;
  List<CompetitionGroup> get compGroups => _compGroups;
  List<AthleteGroup> get athleteGroups => _athleteGroups;
  bool get isLoading => _isLoading;
  bool get isEditingMetadata => _isEditingMetadata;
  set isEditingMetadata(bool val) => setState(() => _isEditingMetadata = val);
  Set<String> get userCollapsedKeys => _userCollapsedKeys;
  bool get isReorderingAthleteGroups => _isReorderingAthleteGroups;
  set isReorderingAthleteGroups(bool val) => setState(() => _isReorderingAthleteGroups = val);
  List<AthleteGroup> get tempAthleteGroups => _tempAthleteGroups;
  set tempAthleteGroups(List<AthleteGroup> val) => setState(() => _tempAthleteGroups = val);
  Set<String> get selectedAthleteGroupIds => _selectedAthleteGroupIds;
  GlobalKey<FormState> get metadataFormKey => _metadataFormKey;
  TextEditingController get nameController => _nameController;
  TextEditingController get descController => _descController;
  String get scope => _scope;
  set scope(String val) => setState(() => _scope = val);
  TextEditingController get areaNameController => _areaNameController;
  TextEditingController get countryController => _countryController;
  TextEditingController get zipController => _zipController;
  TextEditingController get cityController => _cityController;
  TextEditingController get websiteController => _websiteController;
  TextEditingController get profilePictureUrlController => _profilePictureUrlController;
  TextEditingController get bannerUrlController => _bannerUrlController;
  Map<String, TextEditingController> get socialControllers => _socialControllers;
  Map<String, TextEditingController> get rulebookControllers => _rulebookControllers;
  Map<String, List<String>> get selectedSportsFormats => _selectedSportsFormats;
  String get activeLocationField => _activeLocationField;
  List<String> get locationSuggestions => _locationSuggestions;
  bool get isLocationVerified => _isLocationVerified;
  set isLocationVerified(bool val) => setState(() => _isLocationVerified = val);
  bool get isVerifyingLocation => _isVerifyingLocation;
  bool get isUploadingLogo => _isUploadingLogo;
  String? get logoFileName => _logoFileName;
  Uint8List? get logoBytes => _logoBytes;
  bool get isUploadingBanner => _isUploadingBanner;
  String? get bannerFileName => _bannerFileName;
  Uint8List? get bannerBytes => _bannerBytes;
  List<CompetitionGroup> get appliedCompGroups => _appliedCompGroups;
  List<AthleteGroup> get appliedAthleteGroups => _appliedAthleteGroups;
  ProfileRepository get profileRepository => _profileRepository;
  bool get forceExpandSportsAndRulebooks => _forceExpandSportsAndRulebooks;
  set forceExpandSportsAndRulebooks(bool val) => _forceExpandSportsAndRulebooks = val;

  void resetMetadataFields() => _resetMetadataFields();
  void saveMetadata() => _saveMetadata();
  void verifyLocation() => _verifyLocation();
  void updateLocationSuggestions(String type, String query) => _updateLocationSuggestions(type, query);
  Widget buildSuggestionsList(TextEditingController controller) => _buildSuggestionsList(controller);
  void pickLogoImage() => _pickLogoImage();
  void pickBannerImage() => _pickBannerImage();
  void exploreSharedResources({required String resourceType}) => _exploreSharedResources(resourceType: resourceType);
  void showSportConfigurationModal({String? editSportType}) => _showSportConfigurationModal(editSportType: editSportType);
  void configureRulebookSharing(String sport) => _configureRulebookSharing(sport);
  void removeAppliedRulebook(String sport, String format) => _removeAppliedRulebook(sport, format);
  void showDeleteAssociationConfirmation() => _showDeleteAssociationConfirmation();
  List<FlatListItem> buildMembersFlatList() => _buildMembersFlatList();
  void showAddMemberModal() => _showAddMemberModal();
  void showUpdateMemberModal(AssociationMember member, Profile? profile) => _showUpdateMemberModal(member, profile);
  void transferOwnership(String userId) => _transferOwnership(userId);
  void showRemoveMemberConfirmation(AssociationMember member, Profile? profile) => _showRemoveMemberConfirmation(member, profile);
  List<FlatListItem> buildCompGroupsFlatList(ThemeData theme) => _buildCompGroupsFlatList(theme);
  void showAddCompGroupModal() => _showAddCompGroupModal();
  void showUpdateCompGroupModal(CompetitionGroup group) => _showUpdateCompGroupModal(group);
  void showRemoveCompGroupConfirmation(CompetitionGroup group) => _showRemoveCompGroupConfirmation(group);
  void removeAppliedCompetitionGroup(CompetitionGroup group) => _removeAppliedCompetitionGroup(group);
  void configureCompGroupSharing(CompetitionGroup group) => _configureCompGroupSharing(group);
  void toggleCompGroup(CompetitionGroup group) => _toggleCompGroup(group);
  List<FlatListItem> buildAthleteGroupsFlatList(ThemeData theme) => _buildAthleteGroupsFlatList(theme);
  void saveReorderedAthleteGroups() => _saveReorderedAthleteGroups();
  void showAddAthleteGroupModal() => _showAddAthleteGroupModal();
  void showUpdateAthleteGroupModal(AthleteGroup group) => _showUpdateAthleteGroupModal(group);
  void showRemoveAthleteGroupConfirmation(AthleteGroup group) => _showRemoveAthleteGroupConfirmation(group);
  void removeAppliedAthleteGroup(AthleteGroup ag) => _removeAppliedAthleteGroup(ag);
  void configureAthleteGroupSharing(AthleteGroup ag) => _configureAthleteGroupSharing(ag);
  void toggleAthleteGroup(AthleteGroup ag) => _toggleAthleteGroup(ag);
  void shareAthleteGroupsForGender(String genderTitle, List<AthleteGroup> groups) => _shareAthleteGroupsForGender(genderTitle, groups);
  void removeAllAppliedAthleteGroupsForGender(List<AthleteGroup> groups) => _removeAllAppliedAthleteGroupsForGender(groups);

  bool get hasManagePermission => _hasManagePermission;
  bool get isOwner => _isOwner;

  Future<void> _loadData() async {
    if (!mounted) return;
    
    final isCacheHit = widget.associationId != null &&
        widget.associationId == _cachedAssociationId &&
        _cachedAssociation != null;

    if (!isCacheHit) {
      setState(() {
        _isLoading = true;
      });
    }

    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );

    if (widget.associationId == null) {
      // Load all associations first to show dashboard
      await compProvider.fetchAssociations();
      if (!mounted) return;
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.currentUserProfile?.id;
      final List<String> memberAssocs = [];
      if (currentUserId != null) {
        for (var assoc in compProvider.associations) {
          if (assoc.ownerId == currentUserId) {
            memberAssocs.add(assoc.id);
            continue;
          }
          try {
            final members = await compProvider.getAssociationMembers(assoc.id);
            if (members.any((m) => m.userId == currentUserId)) {
              memberAssocs.add(assoc.id);
            }
          } catch (_) {}
        }
      }
      if (!mounted) return;

      setState(() {
        _userMemberAssociationIds = memberAssocs;
        _isLoading = false;
      });
      return;
    }

    try {
      final assoc = await compProvider.getAssociationDetails(
        widget.associationId!,
      );
      if (!mounted) return;
      if (assoc != null) {
        // Fetch all remaining core details concurrently
        final results = await Future.wait([
          compProvider.fetchAssociations(),
          compProvider.getAssociationMembers(widget.associationId!),
          compProvider.getCompetitionGroups(widget.associationId!),
          compProvider.getAthleteGroups(widget.associationId!),
        ]);
        if (!mounted) return;

        var membersList = results[1] as List<AssociationMember>;
        final compGroupsList = results[2] as List<CompetitionGroup>;
        final athleteGroupsList = results[3] as List<AthleteGroup>;
        
        // Auto-heal owner membership: check if owner is in the member list
        if (!membersList.any((m) => m.userId == assoc.ownerId)) {
          final newMember = await compProvider.addAssociationMember(
            widget.associationId!,
            assoc.ownerId,
            'owner',
          );
          if (newMember != null) {
            membersList = await compProvider.getAssociationMembers(
              widget.associationId!,
            );
          }
        }
        if (!mounted) return;

        // Resolve applied shared resources concurrently
        final List<CompetitionGroup> resolvedCompGroups = [];
        final List<AthleteGroup> resolvedAthleteGroups = [];
        final appliedResources = assoc.appliedSharedResources;

        final Map<String, List<String>> compGroupOwners = {};
        for (var item in appliedResources['competition_groups'] as List? ?? []) {
          if (item is Map) {
            final id = item['id'] as String;
            final ownerId = item['owning_association_id'] as String;
            compGroupOwners.putIfAbsent(ownerId, () => []).add(id);
          }
        }

        final Map<String, List<String>> athleteGroupOwners = {};
        for (var item in appliedResources['athlete_groups'] as List? ?? []) {
          if (item is Map) {
            final id = item['id'] as String;
            final ownerId = item['owning_association_id'] as String;
            athleteGroupOwners.putIfAbsent(ownerId, () => []).add(id);
          }
        }

        final List<Future<void>> sharedFetchFutures = [];

        for (var ownerId in compGroupOwners.keys) {
          sharedFetchFutures.add(() async {
            try {
              final groups = await compProvider.getCompetitionGroups(ownerId);
              final targetIds = compGroupOwners[ownerId]!;
              resolvedCompGroups.addAll(groups.where((g) => targetIds.contains(g.id)));
            } catch (_) {}
          }());
        }

        for (var ownerId in athleteGroupOwners.keys) {
          sharedFetchFutures.add(() async {
            try {
              final groups = await compProvider.getAthleteGroups(ownerId);
              final targetIds = athleteGroupOwners[ownerId]!;
              resolvedAthleteGroups.addAll(groups.where((g) => targetIds.contains(g.id)));
            } catch (_) {}
          }());
        }

        await Future.wait(sharedFetchFutures);
        if (!mounted) return;

        // Fetch profiles of all members concurrently
        final Map<String, Profile> memberProfiles = {};
        final List<Future<void>> profileFutures = [];
        for (var member in membersList) {
          profileFutures.add(() async {
            try {
              final prof = await compProvider.profileRepository.getProfile(member.userId);
              if (prof != null) {
                memberProfiles[member.userId] = prof;
              }
            } catch (e) {
              debugPrint('Error fetching profile for member ${member.userId}: $e');
            }
          }());
        }
        await Future.wait(profileFutures);
        if (!mounted) return;

        setState(() {
          _association = assoc;
          _members = membersList;
          _memberProfiles.clear();
          _memberProfiles.addAll(memberProfiles);
          _compGroups = compGroupsList;
          _appliedCompGroups = resolvedCompGroups;
          athleteGroupsList.sort((a, b) {
            final cmp = a.sortOrder.compareTo(b.sortOrder);
            if (cmp != 0) return cmp;
            return a.id.compareTo(b.id);
          });
          _athleteGroups = athleteGroupsList;
          _appliedAthleteGroups = resolvedAthleteGroups;
          
          _populateMetadataControllers(assoc, compProvider);
        });

        // Update static cache
        _cachedAssociationId = widget.associationId;
        _cachedAssociation = assoc;
        _cachedMembers = membersList;
        _cachedMemberProfiles = memberProfiles;
        _cachedCompGroups = compGroupsList;
        _cachedAthleteGroups = athleteGroupsList;
        _cachedAppliedCompGroups = resolvedCompGroups;
        _cachedAppliedAthleteGroups = resolvedAthleteGroups;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  bool get _isOwner {
    if (_association == null) return false;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUserProfile?.id;
    if (currentUserId == null) return false;
    return _association!.ownerId == currentUserId ||
        _members.any((member) => member.userId == currentUserId && member.role == 'owner');
  }

  bool get _hasManagePermission {
    if (_association == null) return false;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUserProfile;
    if (currentUser == null) return false;
    if (currentUser.isAdmin) return true;
    if (_association!.ownerId == currentUser.id) return true;
    return _members.any((member) =>
        member.userId == currentUser.id &&
        (member.role == 'owner' || member.role == 'editor'));
  }

  void _resetMetadataFields() {
    _loadData();
  }

  Future<void> _saveMetadata() async {
    if (_metadataFormKey.currentState?.validate() != true) return;
    if (_association == null) return;

    if (_scope != 'global' && !_isLocationVerified) {
      await _verifyLocation();
    }
    if (_scope != 'global' && !_isLocationVerified) {
      return;
    }

    if (_selectedSportsFormats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure and add at least one sport to proceed.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);

    // Map scope variables
    String? areaName;
    String? country;

    if (_scope == 'continental') {
      areaName = _areaNameController.text.trim();
    } else if (_scope == 'national') {
      country = _countryController.text.trim();
    } else if (_scope == 'local') {
      country = _countryController.text.trim();
      final city = _cityController.text.trim();
      final zip = _zipController.text.trim();
      areaName = '$zip $city'; // Serialize city/zip in areaName
    }

    // Collect rulebooks and supported sports/formats
    final Map<String, String> rulebooks = {};
    final List<String> supportedSports = [];
    final List<String> supportedFormats = [];

    _selectedSportsFormats.forEach((sport, formats) {
      if (formats.isNotEmpty) {
        supportedSports.add(sport);
        supportedFormats.addAll(formats);
        final rulebookUrl = _rulebookControllers[sport]?.text.trim() ?? '';
        if (rulebookUrl.isNotEmpty) {
          rulebooks[sport] = rulebookUrl;
        }
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

    final updated = _association!.copyWith(
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      scope: _scope,
      areaName: areaName,
      country: country,
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      rulebooks: rulebooks,
      socialChannels: social,
      supportedSports: supportedSports,
      supportedFormats: supportedFormats,
      profilePictureUrl: _profilePictureUrlController.text.trim().isEmpty ? null : _profilePictureUrlController.text.trim(),
      bannerUrl: _bannerUrlController.text.trim().isEmpty ? null : _bannerUrlController.text.trim(),
    );

    final res = await compProvider.updateAssociation(updated);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Metadata updated successfully.')),
      );
      _loadData();
    }
  }

  // File Logo Upload
  Future<void> _pickLogoImage() async {
    setState(() {
      _isUploadingLogo = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null) {
          final provider = Provider.of<CompetitionProvider>(context, listen: false);
          final fileName = 'assoc-logo-${DateTime.now().millisecondsSinceEpoch}-${file.name}';
          final uploadedUrl = await provider.profileRepository.uploadFile(bytes, fileName);
          if (uploadedUrl != null) {
            setState(() {
              _logoBytes = bytes;
              _logoFileName = file.name;
              _profilePictureUrlController.text = uploadedUrl;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Logo uploaded successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            throw Exception('Failed to get GCS URL');
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading logo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingLogo = false;
        });
      }
    }
  }

  // File Banner Upload
  Future<void> _pickBannerImage() async {
    setState(() {
      _isUploadingBanner = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null) {
          final provider = Provider.of<CompetitionProvider>(context, listen: false);
          final fileName = 'assoc-banner-${DateTime.now().millisecondsSinceEpoch}-${file.name}';
          final uploadedUrl = await provider.profileRepository.uploadFile(bytes, fileName);
          if (uploadedUrl != null) {
            setState(() {
              _bannerBytes = bytes;
              _bannerFileName = file.name;
              _bannerUrlController.text = uploadedUrl;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Banner uploaded successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            throw Exception('Failed to get GCS URL');
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading banner: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingBanner = false;
        });
      }
    }
  }

  // Location suggestions logic
  Future<void> _updateLocationSuggestions(String field, String query) async {
    if (query.isEmpty) {
      setState(() {
        _locationSuggestions = [];
      });
      return;
    }

    if (MockSafety.isTesting) {
      final suggestions = _mockSuggestions[field] ?? [];
      setState(() {
        _locationSuggestions = suggestions
            .where((s) => s.toLowerCase().contains(query.toLowerCase()))
            .toList();
        _activeLocationField = field;
      });
      return;
    }

    try {
      final String apiBase = MockSafety.apiBaseUrl.endsWith('/') 
          ? MockSafety.apiBaseUrl.substring(0, MockSafety.apiBaseUrl.length - 1)
          : MockSafety.apiBaseUrl;
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse('$apiBase/location/search?q=$encodedQuery&limit=5');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<String> suggestions = [];
        for (var item in data) {
          final displayName = item['display_name'] as String?;
          if (displayName != null) {
            final parts = displayName.split(',');
            if (parts.isNotEmpty) {
              final mainText = parts[0].trim();
              if (!suggestions.contains(mainText)) {
                suggestions.add(mainText);
              }
            }
          }
        }
        if (mounted) {
          setState(() {
            _locationSuggestions = suggestions;
            _activeLocationField = field;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching location suggestions: $e');
    }
  }

  // Real-time location verification using OpenStreetMap Nominatim
  Future<void> _verifyLocation() async {
    bool valid = false;
    String query = '';
    
    if (_scope == 'continental') {
      final area = _areaNameController.text.trim();
      if (area.isNotEmpty) {
        valid = true;
        query = area;
      }
    } else if (_scope == 'national') {
      final country = _countryController.text.trim();
      if (country.isNotEmpty) {
        valid = true;
        query = country;
      }
    } else if (_scope == 'local') {
      final country = _countryController.text.trim();
      final city = _cityController.text.trim();
      final zip = _zipController.text.trim();
      if (country.isNotEmpty && city.isNotEmpty && zip.isNotEmpty) {
        valid = true;
        query = '$zip $city, $country';
      }
    }

    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill out the required address fields for the selected scope.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingLocation = true;
    });

    if (MockSafety.isTesting) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _isVerifyingLocation = false;
          _isLocationVerified = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location verified successfully! coordinates set.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    try {
      final String apiBase = MockSafety.apiBaseUrl.endsWith('/') 
          ? MockSafety.apiBaseUrl.substring(0, MockSafety.apiBaseUrl.length - 1)
          : MockSafety.apiBaseUrl;
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse('$apiBase/location/search?q=$encoded&limit=1&addressdetails=1');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = data[0]['lat'];
          final lon = data[0]['lon'];
          debugPrint('Location verified: lat=$lat, lon=$lon');
          if (mounted) {
            setState(() {
              _isVerifyingLocation = false;
              _isLocationVerified = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Location verified successfully! Coordinates: $lat, $lon'),
                backgroundColor: Colors.green,
              ),
            );
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          _isVerifyingLocation = false;
          _isLocationVerified = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location could not be verified. Please enter a valid address.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error verifying location: $e');
      if (mounted) {
        setState(() {
          _isVerifyingLocation = false;
          _isLocationVerified = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to verify location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Custom Dropdown Builder styled after Search Scope dropdown
  Widget _buildCustomDropdownField<T>({
    required String labelText,
    required T value,
    required List<PopupMenuEntry<T>> items,
    required Function(T) onChanged,
    Widget? prefixIcon,
    String Function(T)? displayValue,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final displayStr = displayValue != null ? displayValue(value) : value.toString();
    return Theme(
      data: theme.copyWith(
        cardColor: theme.colorScheme.surface,
      ),
      child: PopupMenuButton<T>(
        enabled: enabled,
        tooltip: enabled ? labelText : null,
        offset: const Offset(0, 48),
        onSelected: onChanged,
        itemBuilder: (BuildContext context) => items,
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
                    color: enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (enabled)
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

  Widget _buildSuggestionsList(TextEditingController controller) {
    final theme = Theme.of(context);
    return Listener(
      onPointerDown: (_) => FocusScope.of(context).unfocus(),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 150),
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
            ),
          ],
        ),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _locationSuggestions.length,
          itemBuilder: (context, idx) {
            final suggestion = _locationSuggestions[idx];
            return Material(
              color: Colors.transparent,
              child: ListTile(
                dense: true,
                title: Text(
                  suggestion,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                onTap: () {
                  setState(() {
                    controller.text = suggestion;
                    _locationSuggestions = [];
                    _isLocationVerified = false; // Re-verify on changes
                  });
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSportConfigurationModal({String? editSportType}) {
    final provider = Provider.of<CompetitionProvider>(context, listen: false);
    final sportConfig = provider.sportConfig;
    final sports = sportConfig?.sports.map((s) => s.name).toList() ?? ['Streetlifting'];

    showDialog<SportConfigResult>(
      context: context,
      builder: (context) => SportConfigDialog(
        editSportType: editSportType,
        sports: sports,
        sportConfig: sportConfig,
        selectedSportsFormats: _selectedSportsFormats,
        rulebookControllers: _rulebookControllers,
        activeSportType: _activeSportType,
        appliedSharedResources: _association?.appliedSharedResources ?? const {},
      ),
    ).then((result) {
      if (result != null && mounted) {
        setState(() {
          _selectedSportsFormats[result.sport] = result.formats;
          final oldController = _rulebookControllers[result.sport];
          _rulebookControllers[result.sport] = TextEditingController(text: result.rulebookUrl);
          oldController?.dispose();
        });
      }
    });
  }

  Future<void> _addMember() async {
    final userId = _memberUserIdController.text.trim();
    if (userId.isEmpty) return;
    setState(() => _isLoading = true);
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final res = await compProvider.addAssociationMember(
      widget.associationId!,
      userId,
      _memberRole,
      customTitle: _memberCustomTitleController.text.trim().isEmpty
          ? null
          : _memberCustomTitleController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (res != null) {
      _memberUserIdController.clear();
      _memberCustomTitleController.clear();
      _loadData();
    }
  }

  Future<void> _removeMember(String memberId, {String? role}) async {
    setState(() => _isLoading = true);
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final success = await compProvider.removeAssociationMember(
      widget.associationId!,
      memberId,
      role: role,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      _loadData();
    }
  }

  void _showDeleteAssociationConfirmation() {
    final displayedWord = _association?.name ?? 'DELETE';
    showDialog(
      context: context,
      builder: (context) {
        String enteredText = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isMatch = enteredText.trim() == displayedWord;
            return AlertDialog(
              title: const Text('Delete Association'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to delete the association "${_association?.name}"? This will permanently delete the association and all its groups, members, and data. This action cannot be undone.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'To confirm deletion, please type the exact word/name displayed below:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      displayedWord,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('delete_confirm_textfield'),
                    decoration: const InputDecoration(
                      hintText: 'Type the name here...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        enteredText = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  key: const Key('delete_confirm_button'),
                  onPressed: isMatch
                      ? () async {
                          Navigator.of(context).pop();
                          setState(() => _isLoading = true);
                          final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                          final success = await compProvider.deleteAssociation(widget.associationId!);
                          if (!mounted) return;
                          setState(() => _isLoading = false);
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Association deleted successfully.')),
                            );
                            context.pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to delete association.')),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('DELETE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createCompGroup() async {
    final name = _compGroupNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final group = CompetitionGroup(
      id: 'cg-${DateTime.now().millisecondsSinceEpoch}',
      associationId: widget.associationId!,
      name: name,
      sport: _compGroupSport,
      format: _compGroupFormat,
      isActive: true,
      isAthleteGroupsRequired: true,
    );
    final res = await compProvider.createCompetitionGroup(group);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (res != null) {
      _compGroupNameController.clear();
      _loadData();
    }
  }

  Future<void> _createAthleteGroup() async {
    final name = _athleteGroupNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final group = AthleteGroup(
      id: 'ag-${DateTime.now().millisecondsSinceEpoch}',
      associationId: widget.associationId!,
      name: name,
      sport: _athleteGroupSport,
      format: _athleteGroupFormat,
      gender: _athleteGroupGender,
      isActive: true,
    );
    final res = await compProvider.createAthleteGroup(group);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (res != null) {
      _athleteGroupNameController.clear();
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final compProvider = Provider.of<CompetitionProvider>(context);
    final isMobileWidth = MediaQuery.of(context).size.width < 600;

    if (_isLoading) {
      if (widget.isInline) {
        return const Center(child: CircularProgressIndicator());
      }
      if (isMobileWidth) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/management/associations');
                }
              },
            ),
            title: Text(
              'Manage Association',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      } else {
        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Associations  /  ...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Manage Association',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        );
      }
    }

    // Dashboard View (if no associationId provided)
    if (widget.associationId == null) {
      final managedAssociations = compProvider.searchedAssociations.where((assoc) {
        if (authProvider.isAdmin) return true;
        return assoc.ownerId == authProvider.currentUserProfile?.id ||
            _userMemberAssociationIds.contains(assoc.id);
      }).toList();

      final filteredAssocs = managedAssociations.where((assoc) {
        if (_selectedAssocScopes.isNotEmpty && !_selectedAssocScopes.contains(assoc.scope)) {
          return false;
        }
        if (_selectedAssocCountries.isNotEmpty || _selectedAssocAreas.isNotEmpty) {
          bool matchLocation = false;
          if (_selectedAssocCountries.contains('Global') && assoc.scope == 'global') {
            matchLocation = true;
          }
          if (assoc.country != null && _selectedAssocCountries.contains(assoc.country)) {
            matchLocation = true;
          }
          if (assoc.areaName != null && _selectedAssocAreas.contains(assoc.areaName)) {
            matchLocation = true;
          }
          if (!matchLocation) {
            return false;
          }
        }
        if (_selectedAssocSports.isNotEmpty && !_selectedAssocSports.any((s) => assoc.supportedSports.contains(s))) {
          return false;
        }
        if (_selectedAssocFormats.isNotEmpty && !_selectedAssocFormats.any((f) => assoc.supportedFormats.contains(f))) {
          return false;
        }
        return true;
      }).toList();

      if (_assocSortOrder == 'name_asc') {
        filteredAssocs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      } else if (_assocSortOrder == 'name_desc') {
        filteredAssocs.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      }

      final size = MediaQuery.of(context).size;
      final isDesktop = size.width >= 900;
      final isTablet = size.width >= 600 && size.width < 900;

      final resultsWidget = filteredAssocs.isEmpty
          ? _buildEmptyState(theme, compProvider)
          : (_assocIsCompactLayout
              ? _buildCompactListView(filteredAssocs, theme)
              : _buildGridListView(filteredAssocs, theme, isDesktop, isTablet));

      final createButton = ElevatedButton.icon(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AssociationCreationPage(),
            ),
          );
          _loadData();
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
        label: const Text('Create', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      );

      final mainWidget = isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Sidebar Filter
                Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      right: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                        child: Text(
                          'Filters',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _buildAssocFilterContent(context, compProvider, theme),
                        ),
                      ),
                    ],
                  ),
                ),
                // Results Panel
                Expanded(
                  child: Column(
                    children: [
                      DashboardHeader(
                        itemCount: filteredAssocs.length,
                        itemCountLabel: filteredAssocs.length == 1 ? 'Association' : 'Associations',
                        currentSortOrder: _assocSortOrder,
                        sortOptions: const {
                          'name_asc': 'Name: A-Z',
                          'name_desc': 'Name: Z-A',
                        },
                        onSortChanged: (val) {
                          setState(() {
                            _assocSortOrder = val;
                          });
                        },
                        isCompactLayout: _assocIsCompactLayout,
                        onLayoutChanged: (val) {
                          setState(() {
                            _assocIsCompactLayout = val;
                          });
                        },
                        trailing: (authProvider.isAssociationCreator || authProvider.isAdmin) ? createButton : null,
                      ),
                      Expanded(child: resultsWidget),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                DashboardHeader(
                  itemCount: filteredAssocs.length,
                  itemCountLabel: filteredAssocs.length == 1 ? 'Association' : 'Associations',
                  currentSortOrder: _assocSortOrder,
                  sortOptions: const {
                    'name_asc': 'Name: A-Z',
                    'name_desc': 'Name: Z-A',
                  },
                  onSortChanged: (val) {
                    setState(() {
                      _assocSortOrder = val;
                    });
                  },
                  isCompactLayout: _assocIsCompactLayout,
                  onLayoutChanged: (val) {
                    setState(() {
                      _assocIsCompactLayout = val;
                    });
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.filter_list,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Filter options',
                        onPressed: () {
                          _showMobileFilters(context);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(child: resultsWidget),
              ],
            );

      if (widget.isInline) {
        return mainWidget;
      } else {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Association Dashboard'),
          ),
          body: mainWidget,
          floatingActionButton: !isDesktop && (authProvider.isAssociationCreator || authProvider.isAdmin)
              ? FloatingActionButton.extended(
                  key: const Key('create_association_fab'),
                  backgroundColor: const Color(0xFFE94E1B),
                  foregroundColor: Colors.white,
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AssociationCreationPage(),
                      ),
                    );
                    _loadData();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Association'),
                )
              : null,
        );
      }
    }

    if (_association == null) {
      if (widget.isInline) {
        return const Center(child: Text('Error loading association details.'));
      }
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/management/associations');
              }
            },
          ),
          title: const Text('Management'),
        ),
        body: const Center(child: Text('Error loading association details.')),
      );
    }

    final assoc = _association!;

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    if (isDesktop) {
      return _buildDesktopView(context, assoc, theme);
    } else {
      return _buildMobileView(context, assoc, theme);
    }
  }

  Widget _buildDesktopView(BuildContext context, Association assoc, ThemeData theme) {
    final navItems = [
      {'label': 'Metadata', 'icon': Icons.settings},
      {'label': 'Member', 'icon': Icons.people},
      {'label': 'Competition Groups', 'icon': Icons.list_alt},
      {'label': 'Athlete Groups', 'icon': Icons.fitness_center},
      {'label': 'Network', 'icon': Icons.hub},
    ];

    final desktopBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full width header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumbs
              Row(
                children: [
                  HoverableBreadcrumb(
                    label: 'My Associations',
                    onTap: () => context.go('/management/associations'),
                  ),
                  Text(
                    '  /  ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    assoc.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Association Name Title
              Text(
                assoc.name,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        // Master-detail split view
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Custom Left Navigation Drawer
              Container(
                width: 250,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                ),
                child: ListView(
                  children: [
                    const SizedBox(height: 16),
                    ...List.generate(navItems.length, (idx) {
                      final item = navItems[idx];
                      final isSelected = _currentIndex == idx;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                        child: InkWell(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () {
                            if (idx == _currentIndex) return;
                            
                            final tabName = _getTabNameFromIndex(idx);
                            final id = widget.associationId;

                            setState(() {
                              _currentIndex = idx;
                              _activeIndexedStackIndex = idx;
                              _activatedIndices.add(idx);
                              _lastActiveTabIndex = idx;
                            });

                            if (id != null) {
                              final newPath = '/management/associations/$id/$tabName';
                              try {
                                if (GoRouterState.of(context).matchedLocation != newPath) {
                                  context.go(newPath);
                                }
                              } catch (_) {}
                            }
                          },
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.secondaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  color: isSelected
                                      ? theme.colorScheme.onSecondaryContainer
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item['label'] as String,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                          ? theme.colorScheme.onSecondaryContainer
                                          : theme.colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              // Content page right side
              Expanded(
                child: IndexedStack(
                  index: _activeIndexedStackIndex,
                  children: [
                    _activatedIndices.contains(0) ? MetadataTabView(state: this) : const SizedBox.shrink(),
                    _activatedIndices.contains(1) ? MembersTabView(state: this) : const SizedBox.shrink(),
                    _activatedIndices.contains(2) ? CompetitionGroupsTabView(state: this) : const SizedBox.shrink(),
                    _activatedIndices.contains(3) ? AthleteGroupsTabView(state: this) : const SizedBox.shrink(),
                    _activatedIndices.contains(4) ? _buildNetworkTab(theme) : const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.isInline) {
      return Material(
        color: Colors.transparent,
        child: desktopBody,
      );
    } else {
      return Scaffold(
        key: _assocScaffoldKey,
        body: desktopBody,
      );
    }
  }

  Widget _buildMobileView(BuildContext context, Association assoc, ThemeData theme) {
    final navItems = [
      {'label': 'Metadata', 'icon': Icons.settings},
      {'label': 'Member', 'icon': Icons.people},
      {'label': 'Competition Groups', 'icon': Icons.list_alt},
      {'label': 'Athlete Groups', 'icon': Icons.fitness_center},
      {'label': 'Network', 'icon': Icons.hub},
    ];

    final mobileAppBar = widget.isInline
        ? null
        : AppBar(
            leading: IconButton(
              key: const Key('assoc_back_btn'),
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/management/associations');
                }
              },
            ),
            title: Text(
              assoc.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          );

    final mobileBody = SafeArea(
      child: Column(
        children: [
          // Horizontally scrollable primary navigation bar (scrollable TabBar)
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: navItems.map((item) {
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item['icon'] as IconData, size: 16),
                    const SizedBox(width: 8),
                    Text(item['label'] as String),
                  ],
                ),
              );
            }).toList(),
          ),
          // Page content below
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _activatedIndices.contains(0) ? MetadataTabView(state: this) : const SizedBox.shrink(),
                _activatedIndices.contains(1) ? MembersTabView(state: this) : const SizedBox.shrink(),
                _activatedIndices.contains(2) ? CompetitionGroupsTabView(state: this) : const SizedBox.shrink(),
                _activatedIndices.contains(3) ? AthleteGroupsTabView(state: this) : const SizedBox.shrink(),
                _activatedIndices.contains(4) ? _buildNetworkTab(theme) : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );

    Widget? mobileFab;
    if (hasManagePermission) {
      if (_currentIndex == 1) {
        mobileFab = FloatingActionButton.extended(
          key: const Key('add_member_fab'),
          onPressed: showAddMemberModal,
          backgroundColor: const Color(0xFFE94E1B),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Add Member'),
        );
      } else if (_currentIndex == 2) {
        mobileFab = FloatingActionButton.extended(
          key: const Key('add_comp_group_fab'),
          onPressed: showAddCompGroupModal,
          backgroundColor: const Color(0xFFE94E1B),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Add Group'),
        );
      } else if (_currentIndex == 3 && !_isReorderingAthleteGroups) {
        mobileFab = FloatingActionButton.extended(
          key: const Key('add_athlete_group_fab'),
          onPressed: showAddAthleteGroupModal,
          backgroundColor: const Color(0xFFE94E1B),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Add Group'),
        );
      } else if (_currentIndex == 4 && _isOwner) {
        mobileFab = FloatingActionButton.extended(
          key: const Key('add_sub_assoc_fab'),
          onPressed: _showAddSubAssociationModal,
          backgroundColor: const Color(0xFFE94E1B),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Add Sub-Association'),
        );
      }
    }

    if (widget.isInline) {
      return Material(
        color: Colors.transparent,
        child: mobileBody,
      );
    } else {
      return Scaffold(
        key: _assocScaffoldKey,
        appBar: mobileAppBar,
        body: mobileBody,
        floatingActionButton: mobileFab,
      );
    }
  }

  Future<void> _transferOwnership(String newOwnerId) async {
    if (_association == null) return;
    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    final res = await compProvider.transferAssociationOwnership(
      _association!.id,
      newOwnerId,
    );
    if (!mounted) return;
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ownership transferred successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    }
  }

  Future<void> _toggleCompGroup(CompetitionGroup group) async {
    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    final updated = group.copyWith(isActive: !group.isActive);
    final res = await compProvider.updateCompetitionGroup(updated);
    if (!mounted) return;
    if (res != null) {
      _loadData();
    }
  }

  Future<void> _toggleAthleteGroup(AthleteGroup group) async {
    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    final updated = group.copyWith(isActive: !group.isActive);
    final res = await compProvider.updateAthleteGroup(updated);
    if (!mounted) return;
    if (res != null) {
      _loadData();
    }
  }

  void _configureRulebookSharing(String sport) async {
    if (_association == null) return;
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final currentConfig = _association!.rulebooksSharing[sport] as Map<String, dynamic>? ?? {'mode': 'private', 'targets': []};

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ShareResourceDialog(
        title: 'Share Rulebook for $sport',
        initialConfig: currentConfig,
        currentAssociation: _association!,
        allAssociations: compProvider.associations,
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      final updatedSharing = Map<String, dynamic>.from(_association!.rulebooksSharing);
      updatedSharing[sport] = result;
      final updatedAssoc = _association!.copyWith(rulebooksSharing: updatedSharing);
      final res = await compProvider.updateAssociation(updatedAssoc);
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rulebook sharing configured successfully.')),
        );
        _loadData();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _removeAppliedRulebook(String sport, String format) async {
    if (_association == null) return;
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    setState(() => _isLoading = true);

    final applied = Map<String, dynamic>.from(_association!.appliedSharedResources);
    final rulebooks = Map<String, dynamic>.from(applied['rulebooks'] as Map? ?? {});
    rulebooks.remove('$sport:$format');
    applied['rulebooks'] = rulebooks;

    final currentFmts = _selectedSportsFormats[sport] ?? [];
    currentFmts.remove(format);
    if (currentFmts.isEmpty) {
      _selectedSportsFormats.remove(sport);
    } else {
      _selectedSportsFormats[sport] = currentFmts;
    }

    final List<String> supportedFormats = [];
    final List<String> supportedSports = [];
    _selectedSportsFormats.forEach((s, fList) {
      supportedSports.add(s);
      supportedFormats.addAll(fList);
    });

    final updatedAssoc = _association!.copyWith(
      appliedSharedResources: applied,
      supportedSports: supportedSports,
      supportedFormats: supportedFormats,
    );
    final res = await compProvider.updateAssociation(updatedAssoc);
    if (res != null) {
      _forceExpandSportsAndRulebooks = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Applied rulebook removed successfully.')),
      );
      _loadData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _configureCompGroupSharing(CompetitionGroup group) async {
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final currentConfig = group.sharingConfig;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ShareResourceDialog(
        title: 'Share Competition Group: ${group.name}',
        initialConfig: currentConfig,
        currentAssociation: _association!,
        allAssociations: compProvider.associations,
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      final updatedGroup = group.copyWith(sharingConfig: result);
      final res = await compProvider.updateCompetitionGroup(updatedGroup);
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Competition Group sharing configured successfully.')),
        );
        _loadData();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _removeAppliedCompetitionGroup(CompetitionGroup group) async {
    if (_association == null) return;
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    setState(() => _isLoading = true);

    final applied = Map<String, dynamic>.from(_association!.appliedSharedResources);
    final compGroupsList = List<Map<String, dynamic>>.from(applied['competition_groups'] as List? ?? []);
    compGroupsList.removeWhere((item) => item['id'] == group.id);
    applied['competition_groups'] = compGroupsList;

    final updatedAssoc = _association!.copyWith(appliedSharedResources: applied);
    final res = await compProvider.updateAssociation(updatedAssoc);
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Applied competition group removed successfully.')),
      );
      _loadData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _configureAthleteGroupSharing(AthleteGroup group) async {
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final currentConfig = group.sharingConfig;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ShareResourceDialog(
        title: 'Share Athlete Group: ${group.name}',
        initialConfig: currentConfig,
        currentAssociation: _association!,
        allAssociations: compProvider.associations,
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      final updatedGroup = group.copyWith(sharingConfig: result);
      final res = await compProvider.updateAthleteGroup(updatedGroup);
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Athlete Group sharing configured successfully.')),
        );
        _loadData();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void shareCompetitionGroupsMulti() async {
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ShareResourceMultiDialog<CompetitionGroup>(
        title: 'Share Competition Groups',
        ownItems: _compGroups,
        itemHeadline: (g) => g.name,
        itemSubtitles: (g) => [g.sport, g.format],
        itemSport: (g) => g.sport,
        filterSports: compProvider.sportConfig?.sports.map((s) => s.name).toList() ?? ['Streetlifting'],
        filterFormats: compProvider.sportConfig?.formats.map((f) => f.name).toSet().toList() ?? ['Modern', 'Classic'],
        currentAssociation: _association!,
        allAssociations: compProvider.associations,
      ),
    );

    if (result != null) {
      final selectedItems = result['items'] as List<dynamic>;
      final sharingConfig = result['sharing'] as Map<String, dynamic>;

      if (selectedItems.isNotEmpty) {
        setState(() => _isLoading = true);
        int successCount = 0;
        for (var item in selectedItems) {
          if (item is CompetitionGroup) {
            final updatedGroup = item.copyWith(sharingConfig: sharingConfig);
            final res = await compProvider.updateCompetitionGroup(updatedGroup);
            if (res != null) {
              successCount++;
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully shared $successCount of ${selectedItems.length} Competition Groups.')),
        );
        _loadData();
      }
    }
  }

  void shareAthleteGroupsMulti() async {
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ShareResourceMultiDialog<AthleteGroup>(
        title: 'Share Athlete Groups',
        ownItems: _athleteGroups,
        itemHeadline: (g) => g.name,
        itemSubtitles: (g) => [g.sport, g.format, g.gender],
        itemSport: (g) => g.sport,
        itemGenders: (g) => [g.gender],
        filterSports: compProvider.sportConfig?.sports.map((s) => s.name).toList() ?? ['Streetlifting'],
        filterFormats: compProvider.sportConfig?.formats.map((f) => f.name).toSet().toList() ?? ['Modern', 'Classic'],
        filterGenders: const ['men', 'women', 'mixed'],
        currentAssociation: _association!,
        allAssociations: compProvider.associations,
      ),
    );

    if (result != null) {
      final selectedItems = result['items'] as List<dynamic>;
      final sharingConfig = result['sharing'] as Map<String, dynamic>;

      if (selectedItems.isNotEmpty) {
        setState(() => _isLoading = true);
        int successCount = 0;
        for (var item in selectedItems) {
          if (item is AthleteGroup) {
            final updatedGroup = item.copyWith(sharingConfig: sharingConfig);
            final res = await compProvider.updateAthleteGroup(updatedGroup);
            if (res != null) {
              successCount++;
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully shared $successCount of ${selectedItems.length} Athlete Groups.')),
        );
        _loadData();
      }
    }
  }

  void _removeAppliedAthleteGroup(AthleteGroup group) async {
    if (_association == null) return;
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    setState(() => _isLoading = true);

    final applied = Map<String, dynamic>.from(_association!.appliedSharedResources);
    final athleteGroupsList = List<Map<String, dynamic>>.from(applied['athlete_groups'] as List? ?? []);
    athleteGroupsList.removeWhere((item) => item['id'] == group.id);
    applied['athlete_groups'] = athleteGroupsList;

    final updatedAssoc = _association!.copyWith(appliedSharedResources: applied);
    final res = await compProvider.updateAssociation(updatedAssoc);
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Applied athlete group removed successfully.')),
      );
      _loadData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _removeAllAppliedAthleteGroupsForGender(List<AthleteGroup> groups) async {
    if (_association == null || groups.isEmpty) return;
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove All Applied Classes?'),
        content: Text('Are you sure you want to remove all ${groups.length} applied classes for this gender?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);

    final applied = Map<String, dynamic>.from(_association!.appliedSharedResources);
    final athleteGroupsList = List<Map<String, dynamic>>.from(applied['athlete_groups'] as List? ?? []);
    
    final groupIds = groups.map((g) => g.id).toSet();
    athleteGroupsList.removeWhere((item) => groupIds.contains(item['id']));
    applied['athlete_groups'] = athleteGroupsList;

    final updatedAssoc = _association!.copyWith(appliedSharedResources: applied);
    final res = await compProvider.updateAssociation(updatedAssoc);
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully removed ${groups.length} applied classes.')),
      );
      _loadData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _exploreSharedResources({required String resourceType}) async {
    if (_association == null) return;
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ExploreSharedResourcesDialog(
        currentAssociation: _association!,
        allAssociations: compProvider.associations,
        resourceType: resourceType,
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);

      final List<String> supportedSports = List<String>.from(_association!.supportedSports);
      final List<String> supportedFormats = List<String>.from(_association!.supportedFormats);

      if (resourceType == 'rulebooks') {
        final rulebooks = result['rulebooks'] as Map? ?? {};
        rulebooks.keys.forEach((key) {
          final parts = (key as String).split(':');
          if (parts.length == 2) {
            final sport = parts[0];
            final format = parts[1];
            if (!supportedSports.contains(sport)) {
              supportedSports.add(sport);
            }
            if (!supportedFormats.contains(format)) {
              supportedFormats.add(format);
            }
            
            final currentFmts = _selectedSportsFormats[sport] ?? [];
            if (!currentFmts.contains(format)) {
              currentFmts.add(format);
              _selectedSportsFormats[sport] = currentFmts;
            }
          }
        });
      }

      final updatedAssoc = _association!.copyWith(
        appliedSharedResources: result,
        supportedSports: supportedSports,
        supportedFormats: supportedFormats,
      );
      final res = await compProvider.updateAssociation(updatedAssoc);
      if (res != null) {
        if (resourceType == 'rulebooks') {
          _forceExpandSportsAndRulebooks = true;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Applied shared resources updated successfully.')),
        );
        _loadData();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _shareSelectedAthleteGroups(List<AthleteGroup> groups) async {
    if (groups.isEmpty) return;
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final initialConfig = groups.first.sharingConfig;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ShareResourceDialog(
        title: 'Share ${groups.length} Selected Athlete Groups',
        initialConfig: initialConfig,
        currentAssociation: _association!,
        allAssociations: compProvider.associations,
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      int successCount = 0;
      for (var group in groups) {
        final updatedGroup = group.copyWith(sharingConfig: result);
        final res = await compProvider.updateAthleteGroup(updatedGroup);
        if (res != null) {
          successCount++;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully shared $successCount of ${groups.length} Athlete Groups.')),
      );
      _selectedAthleteGroupIds.removeAll(groups.map((g) => g.id));
      _loadData();
    }
  }

  void _shareAthleteGroupsForGender(String genderTitle, List<AthleteGroup> ownGroups) async {
    final selectedGroups = await showDialog<List<AthleteGroup>>(
      context: context,
      builder: (context) => ShareAthleteGroupsSelectionDialog(
        genderTitle: genderTitle,
        ownGroups: ownGroups,
      ),
    );

    if (selectedGroups != null && selectedGroups.isNotEmpty) {
      _shareSelectedAthleteGroups(selectedGroups);
    }
  }

  String _memberCountText(int count) {
    return '$count ${count == 1 ? "Member" : "Members"}';
  }

  List<FlatListItem> _buildMembersFlatList() {
    final List<FlatListItem> items = [];
    final owners = _members.where((m) => m.role == 'owner').toList();
    final editors = _members.where((m) => m.role == 'editor').toList();
    final partners = _members.where((m) => m.role == 'partner').toList();

    if (owners.isNotEmpty) {
      const key = 'members/owners';
      items.add(FlatHeaderItem(
        key: key,
        title: 'Owner',
        level: 0,
        countText: _memberCountText(owners.length),
      ));
      if (!_userCollapsedKeys.contains(key)) {
        for (var member in owners) {
          items.add(FlatMemberCardItem(member: member));
        }
      }
    }

    if (editors.isNotEmpty) {
      const key = 'members/editors';
      items.add(FlatHeaderItem(
        key: key,
        title: 'Editors',
        level: 0,
        countText: _memberCountText(editors.length),
      ));
      if (!_userCollapsedKeys.contains(key)) {
        for (var member in editors) {
          items.add(FlatMemberCardItem(member: member));
        }
      }
    }

    if (partners.isNotEmpty) {
      const key = 'members/partners';
      items.add(FlatHeaderItem(
        key: key,
        title: 'Partners',
        level: 0,
        countText: _memberCountText(partners.length),
      ));
      if (!_userCollapsedKeys.contains(key)) {
        for (var member in partners) {
          items.add(FlatMemberCardItem(member: member));
        }
      }
    }

    return items;
  }

  void _showAddMemberModal() {
    showDialog<AddMemberResult>(
      context: context,
      builder: (context) => AddMemberDialog(profileRepository: _profileRepository),
    ).then((result) async {
      if (result != null && mounted) {
        setState(() => _isLoading = true);
        final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
        for (var userId in result.userIds) {
          if (result.role == 'owner') {
            await compProvider.transferAssociationOwnership(
              widget.associationId!,
              userId,
              customTitle: result.customTitle,
            );
          } else {
            await compProvider.addAssociationMember(
              widget.associationId!,
              userId,
              result.role,
              customTitle: result.customTitle,
            );
          }
        }
        _loadData();
      }
    });
  }

  void _showUpdateMemberModal(AssociationMember member, Profile? profile) {
    showDialog<UpdateMemberResult>(
      context: context,
      builder: (context) => UpdateMemberDialog(member: member, profile: profile),
    ).then((result) async {
      if (result != null && mounted) {
        setState(() => _isLoading = true);
        final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
        if (result.role == 'owner') {
          await compProvider.transferAssociationOwnership(
            widget.associationId!,
            member.userId,
            customTitle: result.customTitle,
          );
        } else {
          final removed = await compProvider.removeAssociationMember(
            widget.associationId!,
            member.userId,
            role: member.role,
          );
          if (removed) {
            await compProvider.addAssociationMember(
              widget.associationId!,
              member.userId,
              result.role,
              customTitle: result.customTitle,
            );
          }
        }
        _loadData();
      }
    });
  }

  void _showRemoveMemberConfirmation(AssociationMember member, Profile? profile) {
    final displayName = profile?.fullName ?? member.userId;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove $displayName from the association?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeMember(member.userId, role: member.role);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  String _cgCountText(int count) {
    return '$count ${count == 1 ? "Competition Group" : "Competition Groups"}';
  }

  List<FlatListItem> _buildCompGroupsFlatList(ThemeData theme) {
    final List<FlatListItem> items = [];
    final Map<String, List<CompetitionGroup>> grouped = {};
    final combinedGroups = [..._compGroups, ..._appliedCompGroups];

    final filtered = combinedGroups.where((g) {
      if (cgSearchQuery.isNotEmpty) {
        if (!g.name.toLowerCase().contains(cgSearchQuery.toLowerCase())) {
          return false;
        }
      }
      if (cgSelectedSports.isNotEmpty && !cgSelectedSports.contains(g.sport)) {
        return false;
      }
      if (cgSelectedFormats.isNotEmpty && !cgSelectedFormats.contains(g.format)) {
        return false;
      }
      return true;
    }).toList();

    for (var group in filtered) {
      grouped.putIfAbsent(group.sport, () => []).add(group);
    }

    for (var entry in grouped.entries) {
      final sport = entry.key;
      final groups = entry.value;
      final sportKey = 'cg/sport/$sport';

      items.add(FlatHeaderItem(
        key: sportKey,
        title: sport,
        level: 0,
        countText: '${groups.length}',
      ));

      if (!_userCollapsedKeys.contains(sportKey)) {
        for (var group in groups) {
          items.add(FlatCompGroupCardItem(compGroup: group));
        }
      }
    }

    return items;
  }

  void _showAddCompGroupModal() {
    showDialog<CompetitionGroup>(
      context: context,
      builder: (context) => CompetitionGroupDialog(
        association: _association!,
        sportConfig: Provider.of<CompetitionProvider>(context, listen: false).sportConfig,
      ),
    ).then((group) async {
      if (group != null && mounted) {
        setState(() => _isLoading = true);
        final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
        final created = await compProvider.createCompetitionGroup(group);
        if (created != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Competition group created successfully.')),
          );
        }
        _loadData();
      }
    });
  }

  void _showUpdateCompGroupModal(CompetitionGroup group) {
    showDialog<CompetitionGroup>(
      context: context,
      builder: (context) => CompetitionGroupDialog(
        group: group,
        association: _association!,
        sportConfig: Provider.of<CompetitionProvider>(context, listen: false).sportConfig,
      ),
    ).then((updated) async {
      if (updated != null && mounted) {
        setState(() => _isLoading = true);
        final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
        final res = await compProvider.updateCompetitionGroup(updated);
        if (res != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Competition group updated successfully.')),
          );
        }
        _loadData();
      }
    });
  }

  void _showRemoveCompGroupConfirmation(CompetitionGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Competition Group'),
        content: Text('Are you sure you want to delete "${group.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              setState(() => _isLoading = true);
              final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
              final success = await compProvider.deleteCompetitionGroup(group.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Competition group deleted successfully.')),
                );
              }
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  String _agCountText(int count) {
    return '$count ${count == 1 ? "Athlete Group" : "Athlete Groups"}';
  }

  List<FlatListItem> _buildAthleteGroupsFlatList(ThemeData theme) {
    final List<FlatListItem> items = [];
    final Map<String, List<AthleteGroup>> grouped = {};

    final sourceList = _isReorderingAthleteGroups ? _tempAthleteGroups : [..._athleteGroups, ..._appliedAthleteGroups];

    final filtered = sourceList.where((g) {
      if (agSearchQuery.isNotEmpty) {
        if (!g.name.toLowerCase().contains(agSearchQuery.toLowerCase())) {
          return false;
        }
      }
      if (agSelectedSports.isNotEmpty && !agSelectedSports.contains(g.sport)) {
        return false;
      }
      if (agSelectedFormats.isNotEmpty && !agSelectedFormats.contains(g.format)) {
        return false;
      }
      if (agSelectedGenders.isNotEmpty && !agSelectedGenders.contains(g.gender)) {
        return false;
      }
      return true;
    }).toList();

    for (var group in filtered) {
      grouped.putIfAbsent(group.sport, () => []).add(group);
    }

    for (var entry in grouped.entries) {
      final sport = entry.key;
      final groups = entry.value;
      final sportKey = 'ag/sport/$sport';

      items.add(FlatHeaderItem(
        key: sportKey,
        title: sport,
        level: 0,
        countText: '${groups.length}',
        athleteGroups: groups,
      ));

      if (!_userCollapsedKeys.contains(sportKey)) {
        if (_isReorderingAthleteGroups) {
          items.add(FlatReorderableGroupItem(
            genderKey: sportKey,
            athleteGroups: groups,
          ));
        } else {
          for (var ag in groups) {
            items.add(FlatAthleteGroupCardItem(athleteGroup: ag));
          }
        }
      }
    }

    return items;
  }

  Future<void> _saveReorderedAthleteGroups() async {
    setState(() => _isLoading = true);
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final List<Future<AthleteGroup?>> updateFutures = [];
    for (int i = 0; i < _tempAthleteGroups.length; i++) {
      final ag = _tempAthleteGroups[i];
      if (ag.sortOrder != i) {
        updateFutures.add(compProvider.updateAthleteGroup(ag.copyWith(sortOrder: i)));
      }
    }
    if (updateFutures.isNotEmpty) {
      await Future.wait(updateFutures);
    }
    setState(() {
      _isReorderingAthleteGroups = false;
      _tempAthleteGroups.clear();
    });
    _loadData();
  }

  void _showReorderAthleteGroupsDialog() {
    showDialog<List<AthleteGroup>>(
      context: context,
      builder: (context) => AthleteGroupsReorderDialog(
        athleteGroups: _athleteGroups,
      ),
    ).then((orderedList) async {
      if (orderedList != null && mounted) {
        setState(() => _isLoading = true);
        final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
        final List<Future<AthleteGroup?>> updateFutures = [];
        for (int i = 0; i < orderedList.length; i++) {
          final ag = orderedList[i];
          if (ag.sortOrder != i) {
            updateFutures.add(compProvider.updateAthleteGroup(ag.copyWith(sortOrder: i)));
          }
        }
        if (updateFutures.isNotEmpty) {
          await Future.wait(updateFutures);
        }
        _loadData();
      }
    });
  }

  void _showAddAthleteGroupModal() {
    showDialog<AthleteGroup>(
      context: context,
      builder: (context) => AthleteGroupDialog(
        association: _association!,
        sportConfig: Provider.of<CompetitionProvider>(context, listen: false).sportConfig,
      ),
    ).then((group) async {
      if (group != null && mounted) {
        setState(() => _isLoading = true);
        final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
        final created = await compProvider.createAthleteGroup(group);
        if (created != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Athlete class created successfully.')),
          );
        }
        _loadData();
      }
    });
  }

  void _showUpdateAthleteGroupModal(AthleteGroup group) {
    showDialog<AthleteGroup>(
      context: context,
      builder: (context) => AthleteGroupDialog(
        group: group,
        association: _association!,
        sportConfig: Provider.of<CompetitionProvider>(context, listen: false).sportConfig,
      ),
    ).then((updated) async {
      if (updated != null && mounted) {
        setState(() => _isLoading = true);
        final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
        final res = await compProvider.updateAthleteGroup(updated);
        if (res != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Athlete class updated successfully.')),
          );
        }
        _loadData();
      }
    });
  }

  void _showRemoveAthleteGroupConfirmation(AthleteGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Athlete Class'),
        content: Text('Are you sure you want to delete "${group.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              setState(() => _isLoading = true);
              final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
              final success = await compProvider.deleteAthleteGroup(group.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Athlete class deleted successfully.')),
                );
              }
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  Widget _buildAssociationRow(Association assoc, {bool showRemove = false, VoidCallback? onRemove}) {
    final theme = Theme.of(context);
    final logoUrl = ImageUrlResolver.resolve(context, assoc.profilePictureUrl);
    final initials = assoc.name.isNotEmpty ? assoc.name[0].toUpperCase() : 'A';

    Color scopeBg;
    Color scopeText;
    switch (assoc.scope.toLowerCase()) {
      case 'global':
        scopeBg = const Color(0xFFFFB300).withOpacity(0.2);
        scopeText = const Color(0xFFFF8F00);
        break;
      case 'continental':
      case 'area':
        scopeBg = Colors.blue.withOpacity(0.2);
        scopeText = Colors.blue.shade700;
        break;
      case 'national':
        scopeBg = Colors.green.withOpacity(0.2);
        scopeText = Colors.green.shade700;
        break;
      case 'local':
      default:
        scopeBg = Colors.purple.withOpacity(0.2);
        scopeText = Colors.purple.shade700;
        break;
    }

    final territory = assoc.scope.toLowerCase() != 'global'
        ? (assoc.areaName ?? assoc.country)
        : null;
    final showTerritory = territory != null && territory.isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
        child: logoUrl.isEmpty
            ? Text(
                initials,
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        assoc.name,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6.0),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (showTerritory)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  territory.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scopeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                assoc.scope.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scopeText,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
      trailing: showRemove && onRemove != null
          ? IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              tooltip: 'Remove Sub-Association',
              onPressed: onRemove,
            )
          : Icon(
              Icons.chevron_right,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
      onTap: () {
        context.push('/associations/${assoc.id}');
      },
    );
  }

  Widget _buildNetworkTab(ThemeData theme) {
    if (_association == null) return const SizedBox.shrink();

    final compProvider = Provider.of<CompetitionProvider>(context);
    final allAssociations = compProvider.associations;

    final parent = _association!.parentAssociationId != null
        ? allAssociations.where((a) => a.id == _association!.parentAssociationId).firstOrNull
        : null;

    final subAssociations = allAssociations.where((a) => a.parentAssociationId == _association!.id).toList();

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Parent Association Header
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Parent Association',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (parent == null)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'This association has no parent association. It is a root association in the network.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildAssociationRow(parent, showRemove: false),

          const SizedBox(height: 32),

          // Sub-Associations Header
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${subAssociations.length}',
                      key: const Key('network/subs/count'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sub-Associations',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_isOwner && isDesktop)
                  ElevatedButton.icon(
                    onPressed: _showAddSubAssociationModal,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Sub-Association'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE94E1B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
              ],
            ),
          ),
          if (subAssociations.isEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.hub_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'This association does not have any sub-associations configured.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...subAssociations.map((sub) => _buildAssociationRow(
                  sub,
                  showRemove: _isOwner,
                  onRemove: () => _showRemoveSubAssociationConfirmation(sub),
                )),
        ],
      ),
    );
  }

  Widget _buildNetworkHeader({
    required String key,
    required String title,
    required String? countText,
    required ThemeData theme,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Row(
        children: [
          if (countText != null) ...[
            Text(
              countText,
              key: Key('$key/count'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSubAssociationModal() async {
    if (_association == null) return;
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final selectedIds = await showDialog<List<String>>(
      context: context,
      builder: (context) => AddSubAssociationDialog(
        currentAssociation: _association!,
        allAssociations: compProvider.associations,
      ),
    );

    if (selectedIds != null && selectedIds.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        for (var assocId in selectedIds) {
          final assoc = compProvider.associations.where((a) => a.id == assocId).firstOrNull;
          if (assoc != null) {
            final updatedAssoc = assoc.copyWith(parentAssociationId: _association!.id);
            await compProvider.updateAssociation(updatedAssoc);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sub-associations added successfully.')),
        );
      } catch (e) {
        debugPrint('Error adding sub-associations: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add some sub-associations.')),
        );
      } finally {
        await _loadData();
      }
    }
  }

  void _showRemoveSubAssociationConfirmation(Association subAssoc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Sub-Association'),
        content: Text('Are you sure you want to remove "${subAssoc.name}" from being a sub-association of "${_association?.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              setState(() => _isLoading = true);
              final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
              try {
                final updatedAssoc = Association(
                  id: subAssoc.id,
                  name: subAssoc.name,
                  profilePictureUrl: subAssoc.profilePictureUrl,
                  bannerUrl: subAssoc.bannerUrl,
                  scope: subAssoc.scope,
                  areaName: subAssoc.areaName,
                  country: subAssoc.country,
                  website: subAssoc.website,
                  description: subAssoc.description,
                  rulebooks: subAssoc.rulebooks,
                  socialChannels: subAssoc.socialChannels,
                  parentAssociationId: null,
                  status: subAssoc.status,
                  ownerId: subAssoc.ownerId,
                  supportedSports: subAssoc.supportedSports,
                  supportedFormats: subAssoc.supportedFormats,
                );
                await compProvider.updateAssociation(updatedAssoc);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sub-association removed successfully.')),
                );
              } catch (e) {
                debugPrint('Error removing sub-association: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to remove sub-association.')),
                );
              } finally {
                await _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, CompetitionProvider provider) {
    return UnifiedEmptyState(
      title: 'No associations found',
      message: 'Try refining your search query or reset filters.',
      onReset: () {
        setState(() {
          _selectedAssocScopes.clear();
          _selectedAssocCountries.clear();
          _selectedAssocAreas.clear();
          _selectedAssocSports.clear();
          _selectedAssocFormats.clear();
        });
        provider.searchAssociations('');
      },
    );
  }

  Widget _buildCompactListView(List<Association> associations, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: associations.length,
      itemBuilder: (context, index) {
        final assoc = associations[index];
        return AssociationCompactRow(
          association: assoc,
          isManagement: true,
          onRefresh: _loadData,
        );
      },
    );
  }

  Widget _buildGridListView(
    List<Association> associations,
    ThemeData theme,
    bool isDesktop,
    bool isTablet,
  ) {
    final int crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 270,
      ),
      itemCount: associations.length,
      itemBuilder: (context, index) {
        final assoc = associations[index];
        return AssociationCard(
          association: assoc,
          isManagement: true,
          onRefresh: _loadData,
        );
      },
    );
  }

  void _showMobileFilters(BuildContext context) {
    final theme = Theme.of(context);
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);

    final drawerContent = Material(
      color: theme.colorScheme.surface,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
            Navigator.of(context).pop();
          }
        },
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildAssocFilterContent(context, compProvider, theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 56.0,
            child: drawerContent,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
    );
  }

  Widget _buildAssocFilterContent(BuildContext context, CompetitionProvider provider, ThemeData theme) {
    final allAssocs = provider.searchedAssociations;
    final scopes = ['global', 'area', 'national', 'local'];
    final scopeLabels = {
      'global': 'Global',
      'area': 'Area',
      'national': 'National',
      'local': 'Local',
    };

    final areas = allAssocs
        .map((e) => e.areaName)
        .where((a) => a != null && a.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    areas.sort();

    final countries = allAssocs
        .map((e) => e.country)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    countries.sort();

    final config = provider.sportConfig;
    final sports = config?.sports.map((s) => s.name).toSet().toList() ?? ['Streetlifting'];

    int getScopeCount(String scope) => allAssocs.where((assoc) => assoc.scope == scope).length;
    int getAreaCount(String area) => allAssocs.where((assoc) => assoc.areaName == area).length;
    int getCountryCount(String country) => allAssocs.where((assoc) => assoc.country == country).length;
    int getSportCount(String sport) => allAssocs.where((assoc) => assoc.supportedSports.contains(sport)).length;
    int getFormatCount(String format) => allAssocs.where((assoc) => assoc.supportedFormats.contains(format)).length;
    int getGlobalCount() => allAssocs.where((assoc) => assoc.scope == 'global').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollapsibleFilterSection(
          title: 'Sport & Format',
          isInitiallyExpanded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...sports.map((s) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterCheckboxRow(
                      label: s,
                      value: _selectedAssocSports.contains(s),
                      count: getSportCount(s),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedAssocSports.add(s);
                          } else {
                            _selectedAssocSports.remove(s);
                          }
                        });
                      },
                    ),
                    (() {
                      final sportFormats = config?.formats
                          .where((f) => f.sportName == s)
                          .map((f) => f.name)
                          .toList() ?? (s == 'Streetlifting' ? ['Modern', 'Classic'] : []);
                      if (sportFormats.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 20.0, top: 4.0, bottom: 4.0),
                        child: Column(
                          children: sportFormats.map((f) {
                            return FilterCheckboxRow(
                              label: f,
                              value: _selectedAssocFormats.contains(f),
                              count: getFormatCount(f),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedAssocFormats.add(f);
                                  } else {
                                    _selectedAssocFormats.remove(f);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      );
                    })(),
                  ],
                );
              }),
            ],
          ),
        ),
        CollapsibleFilterSection(
          title: 'Scope',
          isInitiallyExpanded: false,
          child: Column(
            children: scopes.map((s) {
              return FilterCheckboxRow(
                label: scopeLabels[s] ?? s,
                value: _selectedAssocScopes.contains(s),
                count: getScopeCount(s),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedAssocScopes.add(s);
                    } else {
                      _selectedAssocScopes.remove(s);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
        CollapsibleFilterSection(
          title: 'Location',
          isInitiallyExpanded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterCheckboxRow(
                label: 'Global',
                value: _selectedAssocCountries.contains('Global'),
                count: getGlobalCount(),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedAssocCountries.add('Global');
                    } else {
                      _selectedAssocCountries.remove('Global');
                    }
                  });
                },
              ),
              if (areas.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'AREAS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                ...areas.map((a) {
                  return FilterCheckboxRow(
                    label: a,
                    value: _selectedAssocAreas.contains(a),
                    count: getAreaCount(a),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedAssocAreas.add(a);
                        } else {
                          _selectedAssocAreas.remove(a);
                        }
                      });
                    },
                  );
                }),
              ],
              if (countries.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'COUNTRIES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                ...countries.map((c) {
                  return FilterCheckboxRow(
                    label: c,
                    value: _selectedAssocCountries.contains(c),
                    count: getCountryCount(c),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedAssocCountries.add(c);
                        } else {
                          _selectedAssocCountries.remove(c);
                        }
                      });
                    },
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
