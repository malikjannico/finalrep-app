import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/competition_provider.dart';
import '../providers/auth_provider.dart';
import '../models/competition.dart';
import '../models/association.dart';
import '../models/athlete_group.dart';
import '../models/competition_group.dart';
import '../widgets/filter_widgets.dart';
import 'competition_detail_page.dart';
import 'competition_creation_page.dart';
import 'competition_judging_page.dart';
import 'competition_library_page.dart';
import 'association_creation_page.dart';
import 'association/widgets/hoverable_breadcrumb.dart';
import 'association/widgets/collapsible_section.dart';
import '../utils/uuid_helper.dart';
import '../utils/mock_safety.dart';
import '../widgets/verified_location_badge.dart';
import '../widgets/competition_card.dart';
import '../utils/image_url_resolver.dart';

class CompetitionManagementPage extends StatefulWidget {
  final String? competitionId;
  final String? initialTab;
  final bool isInline;

  const CompetitionManagementPage({
    super.key,
    this.competitionId,
    this.initialTab,
    this.isInline = false,
  });

  @override
  State<CompetitionManagementPage> createState() => _CompetitionManagementPageState();
}

class _CompetitionManagementPageState extends State<CompetitionManagementPage>
    with SingleTickerProviderStateMixin {
  String _selectedCompetitionStatus = 'upcoming';

  // Detail View State
  bool _isConfigExpanded = true;
  Competition? _competition;
  bool _isLoading = false;
  late TabController _tabController;
  int _currentIndex = 0;
  int _activeIndexedStackIndex = 0;
  final Set<int> _activatedIndices = {};
  int? _lastActiveTabIndex;

  // Metadata Form Controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _regStartController;
  late TextEditingController _regEndController;
  late TextEditingController _locationController;
  late TextEditingController _cityController;
  late TextEditingController _zipController;
  late TextEditingController _countryController;
  late TextEditingController _websiteController;
  late TextEditingController _ticketShopController;
  late TextEditingController _feeAmountController;
  late TextEditingController _bankDetailsController;
  late TextEditingController _paymentDescController;
  late TextEditingController _paymentStartController;
  late TextEditingController _paymentEndController;
  late TextEditingController _maxAthletesController;

  // Volunteer Controllers
  late TextEditingController _maxVolunteersController;
  late TextEditingController _rulebookUrlController;

  // Parent Association & Competition Group Variables
  List<Association> _eligibleAssociations = [];
  String? _selectedAssociationId;

  // Banner image controllers & states
  late TextEditingController _titleImageUrlController;
  bool _isUploadingBanner = false;
  Uint8List? _bannerBytes;
  String? _bannerFileName;

  // Split bank details controllers
  late TextEditingController _ibanController;
  late TextEditingController _bicController;
  late TextEditingController _bankNameController;

  // Payment reference type
  String _paymentRefType = 'auto'; // 'auto' or 'custom'

  // Social channels controllers
  final Map<String, TextEditingController> _socialControllers = {
    'Instagram': TextEditingController(),
    'YouTube': TextEditingController(),
    'Facebook': TextEditingController(),
    'Twitch': TextEditingController(),
    'Twitter/X': TextEditingController(),
    'TikTok': TextEditingController(),
  };

  // Sport & Rulebook state variables
  bool _isEditingSportRulebook = false;
  List<CompetitionGroup> _availableCompGroups = [];
  String _sportType = 'Streetlifting';
  String _rankingType = 'open';
  String? _selectedCompGroupName;

  // Form State Values
  final _metadataFormKey = GlobalKey<FormState>();
  bool _isEditingMetadata = false;
  bool _requiresFees = false;
  bool _volunteerNeeds = false;
  bool _enableWaitlist = false;
  String _registrationMode = 'fcfs';
  String _sportSubtype = 'Modern';
  String _feeCurrency = 'EUR';
  bool _bannerSafeZoneGuide = false;

  // Location suggestions and verification
  bool _isLocationVerified = true;
  bool _isVerifyingLocation = false;
  String _activeLocationField = '';
  List<String> _locationSuggestions = [];
  Timer? _debounce;

  String _parsedCountry = '';
  String _parsedCity = '';
  String _parsedZip = '';
  String _parsedAddress = '';
  double? _verifiedLatitude;
  double? _verifiedLongitude;

  // Lists for local edits
  List<Map<String, dynamic>> _compAthleteGroups = [];
  Map<String, int> _maxVolunteersPerPosition = {};
  List<Map<String, String>> _disclaimers = [];
  List<Map<String, dynamic>> _customAthleteFields = [];
  List<Map<String, dynamic>> _customVolunteerFields = [];

  // Mock suggestions dictionary
  final Map<String, List<String>> _mockSuggestions = {
    'country': ['Germany', 'Austria', 'Switzerland', 'France', 'United States', 'United Kingdom', 'Canada', 'Spain', 'Italy'],
    'city': ['Hamburg', 'Berlin', 'Munich', 'Frankfurt', 'Vienna', 'Paris', 'London', 'New York', 'Tokyo'],
    'zip': ['22529', '10115', '80331', '60311', '1010', '75001', 'SW1A 1AA'],
    'address': ['Marienplatz 1', 'Rütersbarg 50', 'Alexanderplatz 1', 'Brandenburger Tor', 'Stephansplatz 1', 'Champs-Élysées 10', 'Broadway 100'],
  };

  int _getTabIndexFromTabName(String? name) {
    switch (name) {
      case 'metadata':
        return 0;
      case 'athletegroups':
        return 1;
      case 'volunteer':
        return 2;
      case 'rulebook':
        return 3;
      case 'disclaimers':
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
        return 'athletegroups';
      case 2:
        return 'volunteer';
      case 3:
        return 'rulebook';
      case 4:
        return 'disclaimers';
      default:
        return 'metadata';
    }
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _regStartController = TextEditingController();
    _regEndController = TextEditingController();
    _locationController = TextEditingController();
    _cityController = TextEditingController();
    _zipController = TextEditingController();
    _countryController = TextEditingController();
    _websiteController = TextEditingController();
    _ticketShopController = TextEditingController();
    _feeAmountController = TextEditingController();
    _bankDetailsController = TextEditingController();
    _paymentDescController = TextEditingController();
    _paymentStartController = TextEditingController();
    _paymentEndController = TextEditingController();
    _maxAthletesController = TextEditingController();
    _maxVolunteersController = TextEditingController();
    _rulebookUrlController = TextEditingController();

    _titleImageUrlController = TextEditingController();
    _ibanController = TextEditingController();
    _bicController = TextEditingController();
    _bankNameController = TextEditingController();

    if (widget.competitionId != null) {
      final initialIndex = _getTabIndexFromTabName(widget.initialTab);
      _currentIndex = initialIndex;
      _activeIndexedStackIndex = initialIndex;
      _activatedIndices.add(initialIndex);
      _lastActiveTabIndex = initialIndex;
      _tabController = TabController(length: 5, vsync: this, initialIndex: initialIndex);
      _tabController.addListener(_onTabChanged);
      _isLoading = true;
    } else {
      _tabController = TabController(length: 1, vsync: this);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadEligibleAssociations();
        if (widget.competitionId != null) {
          _loadCompetitionData();
        } else {
          Provider.of<CompetitionProvider>(context, listen: false)
              .fetchCompetitions(status: _selectedCompetitionStatus);
        }
      }
    });
  }

  @override
  void didUpdateWidget(CompetitionManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.competitionId != null && widget.initialTab != oldWidget.initialTab && widget.initialTab != null) {
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
  void dispose() {
    if (widget.competitionId != null) {
      _tabController.removeListener(_onTabChanged);
    }
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _regStartController.dispose();
    _regEndController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _websiteController.dispose();
    _ticketShopController.dispose();
    _feeAmountController.dispose();
    _bankDetailsController.dispose();
    _paymentDescController.dispose();
    _paymentStartController.dispose();
    _paymentEndController.dispose();
    _maxAthletesController.dispose();
    _maxVolunteersController.dispose();
    _rulebookUrlController.dispose();
    _titleImageUrlController.dispose();
    _ibanController.dispose();
    _bicController.dispose();
    _bankNameController.dispose();
    _socialControllers.forEach((_, controller) => controller.dispose());
    _debounce?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && _tabController.index != _currentIndex) {
      final tabName = _getTabNameFromIndex(_tabController.index);
      final id = widget.competitionId;
      setState(() {
        _currentIndex = _tabController.index;
        _activeIndexedStackIndex = _tabController.index;
        _activatedIndices.add(_tabController.index);
        _lastActiveTabIndex = _tabController.index;
      });
      if (id != null) {
        final newPath = '/management/competitions/$id/$tabName';
        try {
          if (GoRouterState.of(context).matchedLocation != newPath) {
            context.go(newPath);
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _loadCompetitionData() async {
    setState(() {
      _isLoading = true;
    });
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    try {
      final comp = await compProvider.getCompetitionById(widget.competitionId!);
      if (comp != null && mounted) {
        List<CompetitionGroup> groups = [];
        if (comp.associationId != null) {
          groups = await compProvider.getCompetitionGroups(comp.associationId!);
        }
        setState(() {
          _competition = comp;
          _availableCompGroups = groups;
          _populateMetadataControllers(comp);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _parseBankDetails(String? bankDetailsStr) {
    _ibanController.text = '';
    _bicController.text = '';
    _bankNameController.text = '';
    if (bankDetailsStr == null || bankDetailsStr.isEmpty) return;

    final parts = bankDetailsStr.split('|').map((s) => s.trim()).toList();
    for (var part in parts) {
      if (part.startsWith('IBAN:')) {
        _ibanController.text = part.replaceFirst('IBAN:', '').trim();
      } else if (part.startsWith('BIC:')) {
        _bicController.text = part.replaceFirst('BIC:', '').trim();
      } else if (part.startsWith('Bank:')) {
        _bankNameController.text = part.replaceFirst('Bank:', '').trim();
      }
    }
  }

  Future<void> _loadEligibleAssociations() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    final currentUserId = authProvider.currentUserProfile?.id;
    if (currentUserId == null) return;

    await compProvider.fetchAssociations();
    final allAssocs = compProvider.associations;

    final List<Association> eligible = [];
    for (final assoc in allAssocs) {
      if (assoc.ownerId == currentUserId) {
        eligible.add(assoc);
        continue;
      }
      try {
        final members = await compProvider.getAssociationMembers(assoc.id);
        final hasAccess = members.any((m) => m.userId == currentUserId && (m.role == 'owner' || m.role == 'editor' || m.role == 'manager'));
        if (hasAccess) {
          eligible.add(assoc);
        }
      } catch (e) {
        debugPrint('Error getting members for assoc ${assoc.id}: $e');
      }
    }

    if (mounted) {
      setState(() {
        _eligibleAssociations = eligible;
      });
    }
  }

  Future<void> _loadAvailableCompetitionGroups() async {
    if (_selectedAssociationId == null) {
      setState(() {
        _availableCompGroups = [];
        _selectedCompGroupName = null;
      });
      return;
    }
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    try {
      final ownCGs = await compProvider.getCompetitionGroups(_selectedAssociationId!);
      final List<CompetitionGroup> resolvedCGs = [...ownCGs];

      final selectedAssoc = compProvider.associations.where((a) => a.id == _selectedAssociationId).firstOrNull;
      if (selectedAssoc != null && selectedAssoc.appliedSharedResources['competition_groups'] != null) {
        final appliedList = selectedAssoc.appliedSharedResources['competition_groups'] as List? ?? [];
        final Map<String, List<String>> owners = {};
        for (var item in appliedList) {
          if (item is Map) {
            final id = item['id'] as String;
            final ownerId = item['owning_association_id'] as String;
            owners.putIfAbsent(ownerId, () => []).add(id);
          }
        }
        for (var ownerId in owners.keys) {
          try {
            final sharedGroups = await compProvider.getCompetitionGroups(ownerId);
            final targetIds = owners[ownerId]!;
            resolvedCGs.addAll(sharedGroups.where((g) => targetIds.contains(g.id)));
          } catch (_) {}
        }
      }

      final filtered = resolvedCGs.where((g) =>
        g.isActive &&
        g.sport.toLowerCase() == _sportType.toLowerCase() &&
        g.format.toLowerCase() == _sportSubtype.toLowerCase()
      ).toList();

      if (mounted) {
        setState(() {
          _availableCompGroups = filtered;
          if (_selectedCompGroupName != null && !_availableCompGroups.any((g) => g.name == _selectedCompGroupName)) {
            _selectedCompGroupName = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading parent competition groups: $e');
    }
  }

  void _onParentOrSportChanged() {
    _loadAvailableCompetitionGroups();
    setState(() {
      _selectedCompGroupName = null;
    });
  }

  void _populateMetadataControllers(Competition comp) {
    _titleController.text = comp.title;
    _descriptionController.text = comp.description ?? '';
    _startDateController.text = DateFormat('yyyy-MM-dd HH:mm').format(comp.startDate);
    _endDateController.text = DateFormat('yyyy-MM-dd HH:mm').format(comp.endDate);
    _regStartController.text = DateFormat('yyyy-MM-dd HH:mm').format(comp.registrationStart);
    _regEndController.text = DateFormat('yyyy-MM-dd HH:mm').format(comp.registrationEnd);
    _websiteController.text = comp.websiteUrl ?? '';
    _ticketShopController.text = comp.ticketShopUrl ?? '';
    _feeAmountController.text = comp.feeAmount?.toString() ?? '';
    _bankDetailsController.text = comp.bankDetails ?? '';
    _paymentDescController.text = comp.paymentDescription ?? '';
    _paymentStartController.text = comp.paymentStart != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(comp.paymentStart!)
        : '';
    _paymentEndController.text = comp.paymentEnd != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(comp.paymentEnd!)
        : '';
    _maxAthletesController.text = comp.maxAthletes?.toString() ?? '';
    _maxVolunteersController.text = comp.maxVolunteers?.toString() ?? '';

    _locationController.text = comp.location;
    _cityController.text = comp.city ?? '';
    _countryController.text = comp.country ?? '';
    _zipController.text = '';

    _verifiedLatitude = comp.latitude;
    _verifiedLongitude = comp.longitude;
    _parsedCountry = comp.country ?? '';
    _parsedCity = comp.city ?? '';
    _parsedZip = '';
    _parsedAddress = comp.location;
    _isLocationVerified = comp.latitude != null && comp.latitude != 0.0 && comp.longitude != null && comp.longitude != 0.0;

    _requiresFees = comp.requiresFees;
    _volunteerNeeds = comp.volunteerNeeds;
    _enableWaitlist = comp.enableWaitlist;
    _registrationMode = comp.registrationMode;
    _sportSubtype = comp.sportSubtype;
    _feeCurrency = comp.feeCurrency ?? 'EUR';
    _bannerSafeZoneGuide = comp.bannerSafeZoneGuide;

    _rulebookUrlController.text = comp.rulebookUrl ?? '';
    _sportType = comp.sportType;
    _rankingType = comp.rankingType;

    _selectedAssociationId = comp.associationId;
    _selectedCompGroupName = comp.compGroupName;
    _titleImageUrlController.text = comp.titleImageUrl ?? '';

    _parseBankDetails(comp.bankDetails);

    final desc = comp.paymentDescription ?? '';
    if (desc.startsWith('Entry Fee: ') && desc.contains(' - User: ')) {
      _paymentRefType = 'auto';
    } else {
      _paymentRefType = 'custom';
    }

    _socialControllers.forEach((platform, controller) {
      controller.text = comp.socials?[platform] ?? '';
    });

    _loadAvailableCompetitionGroups();

    _compAthleteGroups = comp.maxAthletesPerGroup != null
        ? List<Map<String, dynamic>>.from(comp.maxAthletesPerGroup!)
        : [];
    _maxVolunteersPerPosition = comp.maxVolunteersPerPosition != null
        ? Map<String, int>.from(comp.maxVolunteersPerPosition!)
        : {};

    _disclaimers = [];
    if (comp.disclaimerText != null && comp.disclaimerText!.isNotEmpty) {
      try {
        final decoded = jsonDecode(comp.disclaimerText!);
        if (decoded is List) {
          _disclaimers = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
        }
      } catch (_) {}
    }

    _customAthleteFields = comp.customAthleteFields != null
        ? List<Map<String, dynamic>>.from(comp.customAthleteFields!)
        : [];
    _customVolunteerFields = comp.customVolunteerFields != null
        ? List<Map<String, dynamic>>.from(comp.customVolunteerFields!)
        : [];
  }

  Future<void> _pickBannerImage() async {
    setState(() {
      _isUploadingBanner = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null) {
          final provider = Provider.of<CompetitionProvider>(context, listen: false);
          final fileName = 'comp-banner-${DateTime.now().millisecondsSinceEpoch}-${file.name}';
          final uploadedUrl = await provider.profileRepository.uploadFile(bytes, fileName);
          if (uploadedUrl != null) {
            setState(() {
              _bannerBytes = bytes;
              _bannerFileName = file.name;
              _titleImageUrlController.text = uploadedUrl;
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
        SnackBar(content: Text('Failed to upload banner: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isUploadingBanner = false;
      });
    }
  }

  String _getGeneratedPaymentDesc() {
    final title = _titleController.text.trim().isEmpty ? '[Competition Name]' : _titleController.text.trim();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserProfile?.username ?? 'user';
    final desc = 'Entry Fee: $title - User: $user';
    return desc.length > 140 ? desc.substring(0, 140) : desc;
  }

  Future<void> _saveMetadata() async {
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    if (_competition == null) return;

    final locationText = _locationController.text.trim();
    if (locationText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location / Address is required'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!_isLocationVerified) {
      await _verifyLocation();
      if (!_isLocationVerified) {
        return; // Stop the save process because location verification failed!
      }
    }

    final start = DateTime.tryParse(_startDateController.text) ?? _competition!.startDate;
    final end = DateTime.tryParse(_endDateController.text) ?? _competition!.endDate;
    final regStart = DateTime.tryParse(_regStartController.text) ?? _competition!.registrationStart;
    final regEnd = DateTime.tryParse(_regEndController.text) ?? _competition!.registrationEnd;

    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be on or after start date'), backgroundColor: Colors.red),
      );
      return;
    }
    if (regEnd.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration end date must be on or before competition start date'), backgroundColor: Colors.red),
      );
      return;
    }
    if (regEnd.isBefore(regStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration end date must be on or after registration start date'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_requiresFees) {
      final iban = _ibanController.text.trim();
      final bic = _bicController.text.trim();
      final bankName = _bankNameController.text.trim();
      if (iban.isEmpty || bic.isEmpty || bankName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All bank account details (IBAN, BIC, Bank Name) are required when Entry Fees are enabled'), backgroundColor: Colors.red),
        );
        return;
      }

      if (_paymentRefType == 'custom' && _paymentDescController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom payment reference instructions are required'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final parsed = _parseAddressString(locationText);
    final cityVal = _parsedCity.isNotEmpty ? _parsedCity : (parsed['city']?.trim().isNotEmpty == true ? parsed['city']!.trim() : 'Hamburg');
    final countryVal = _parsedCountry.isNotEmpty ? _parsedCountry : (parsed['country']?.trim().isNotEmpty == true ? parsed['country']!.trim() : 'Germany');

    final String? finalBankDetails = _requiresFees
        ? 'IBAN: ${_ibanController.text.trim()} | BIC: ${_bicController.text.trim()} | Bank: ${_bankNameController.text.trim()}'
        : null;

    final String? finalPaymentDesc = _requiresFees
        ? (_paymentRefType == 'auto' ? _getGeneratedPaymentDesc() : _paymentDescController.text.trim())
        : null;

    final Map<String, String> socials = {};
    _socialControllers.forEach((key, controller) {
      final val = controller.text.trim();
      if (val.isNotEmpty) {
        socials[key] = val;
      }
    });

    final updatedComp = Competition(
      id: _competition!.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      startDate: DateTime.tryParse(_startDateController.text) ?? _competition!.startDate,
      endDate: DateTime.tryParse(_endDateController.text) ?? _competition!.endDate,
      location: locationText,
      sportType: _sportType,
      sportSubtype: _sportSubtype,
      compGroupName: _selectedCompGroupName,
      status: _competition!.status,
      area: _competition!.area,
      country: countryVal,
      city: cityVal,
      titleImageUrl: _titleImageUrlController.text.trim().isEmpty ? null : _titleImageUrlController.text.trim(),
      createdAt: _competition!.createdAt,
      updatedAt: DateTime.now(),
      associationId: _selectedAssociationId,
      competitionGroupId: _competition!.competitionGroupId,
      athleteGroupIds: _competition!.athleteGroupIds,
      rulebookUrl: _rulebookUrlController.text.trim().isEmpty ? null : _rulebookUrlController.text.trim(),
      registrationStart: DateTime.tryParse(_regStartController.text) ?? _competition!.registrationStart,
      registrationEnd: DateTime.tryParse(_regEndController.text) ?? _competition!.registrationEnd,
      requiresFees: _requiresFees,
      feeAmount: _requiresFees ? double.tryParse(_feeAmountController.text) : null,
      feeCurrency: _requiresFees ? _feeCurrency : null,
      bankDetails: finalBankDetails,
      paymentDescription: finalPaymentDesc,
      paymentStart: _requiresFees && _paymentStartController.text.isNotEmpty ? DateTime.tryParse(_paymentStartController.text) : null,
      paymentEnd: _requiresFees && _paymentEndController.text.isNotEmpty ? DateTime.tryParse(_paymentEndController.text) : null,
      registrationMode: _registrationMode,
      websiteUrl: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      ticketShopUrl: _ticketShopController.text.trim().isEmpty ? null : _ticketShopController.text.trim(),
      socials: socials,
      maxAthletes: int.tryParse(_maxAthletesController.text),
      maxAthletesPerGroup: _competition!.maxAthletesPerGroup,
      maxVolunteers: int.tryParse(_maxVolunteersController.text),
      maxVolunteersPerPosition: _competition!.maxVolunteersPerPosition,
      enableWaitlist: _enableWaitlist,
      volunteerNeeds: _competition!.volunteerNeeds,
      volunteerPositions: _competition!.volunteerPositions,
      volunteerShifts: _competition!.volunteerShifts,
      customAthleteFields: _competition!.customAthleteFields,
      customVolunteerFields: _competition!.customVolunteerFields,
      disclaimerText: _competition!.disclaimerText,
      disclaimerUrl: _competition!.disclaimerUrl,
      disclaimerType: _competition!.disclaimerType,
      bannerSafeZoneGuide: _bannerSafeZoneGuide,
      rankingType: _rankingType,
      latitude: _verifiedLatitude,
      longitude: _verifiedLongitude,
    );

    final result = await compProvider.updateCompetition(updatedComp);
    if (result != null && mounted) {
      setState(() {
        _competition = result;
        _populateMetadataControllers(result);
        _isEditingMetadata = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Competition metadata updated successfully!'), backgroundColor: Colors.green),
      );
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update competition metadata.'), backgroundColor: Colors.red),
      );
    }
  }

  Map<String, String> _parseAddressString(String rawString) {
    final parts = rawString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    String country = '';
    String city = '';
    String zip = '';
    String street = '';

    if (parts.isNotEmpty) {
      country = parts.last;
      if (parts.length >= 2) {
        final cityZipPart = parts[parts.length - 2];
        final czParts = cityZipPart.split(' ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (czParts.length == 1) {
          if (RegExp(r'^\d+$').hasMatch(czParts[0])) {
            zip = czParts[0];
          } else {
            city = czParts[0];
          }
        } else if (czParts.length >= 2) {
          if (RegExp(r'^\d+').hasMatch(czParts[0])) {
            zip = czParts[0];
            city = czParts.sublist(1).join(' ');
          } else if (RegExp(r'\d+$').hasMatch(czParts.last)) {
            zip = czParts.last;
            city = czParts.sublist(0, czParts.length - 1).join(' ');
          } else {
            city = czParts.join(' ');
          }
        }

        street = parts.sublist(0, parts.length - 2).join(', ');
      } else {
        street = parts.first;
      }
    }
    return {
      'country': country,
      'city': city,
      'zip': zip,
      'street': street,
    };
  }

  Future<void> _updateLocationSuggestions(String field, String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      setState(() {
        _locationSuggestions = [];
      });
      return;
    }

    if (MockSafety.isTesting) {
      final List<String> suggestions = [
        'Marienplatz 1, 80331 Munich, Germany',
        'Rütersbarg 50, 22529 Hamburg, Germany',
        'Alexanderplatz 1, 10178 Berlin, Germany',
        'Stephansplatz 1, 1010 Vienna, Austria',
        'Champs-Élysées 10, 75008 Paris, France',
        'Broadway 100, 10001 New York, United States',
      ];
      setState(() {
        _locationSuggestions = suggestions
            .where((s) => s.toLowerCase().contains(query.toLowerCase()))
            .toList();
        _activeLocationField = field;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
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
              if (!suggestions.contains(displayName)) {
                suggestions.add(displayName);
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
    });
  }

  Future<void> _verifyLocation() async {
    final query = _locationController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill out the location address field before verifying.'),
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
      final fallback = _parseAddressString(query);
      _parsedCountry = fallback['country'] ?? 'Germany';
      _parsedCity = fallback['city'] ?? 'Hamburg';
      _parsedZip = fallback['zip'] ?? '22529';
      _parsedAddress = fallback['street'] ?? query;

      _verifiedLatitude = 53.5511;
      _verifiedLongitude = 9.9937;

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
          final latStr = data[0]['lat'];
          final lonStr = data[0]['lon'];
          final lat = double.tryParse(latStr?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(lonStr?.toString() ?? '') ?? 0.0;
          
          _verifiedLatitude = lat;
          _verifiedLongitude = lon;

          final displayName = data[0]['display_name'] as String? ?? query;
          final addressMap = data[0]['address'] as Map<String, dynamic>?;

          String country = '';
          String city = '';
          String zip = '';

          if (addressMap != null) {
            country = addressMap['country']?.toString() ?? '';
            final cityObj = addressMap['city'] ?? addressMap['town'] ?? addressMap['village'] ?? addressMap['municipality'] ?? addressMap['suburb'] ?? addressMap['county'];
            city = cityObj?.toString() ?? '';
            zip = addressMap['postcode']?.toString() ?? '';
          }

          final fallback = _parseAddressString(displayName);
          if (country.isEmpty) country = fallback['country'] ?? '';
          if (city.isEmpty) city = fallback['city'] ?? '';
          if (zip.isEmpty) zip = fallback['zip'] ?? '';

          _parsedCountry = country;
          _parsedCity = city;
          _parsedZip = zip;
          _parsedAddress = fallback['street'] ?? displayName;

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
              color: Colors.black.withOpacity(0.08),
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
                    _isLocationVerified = false;
                  });
                },
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<CompetitionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUserProfile;

    if (currentUser == null) {
      final loginPrompt = Center(
        child: Text(
          'Please log in to manage competitions.',
          style: theme.textTheme.titleMedium,
        ),
      );
      if (widget.isInline) return loginPrompt;
      return Scaffold(
        appBar: AppBar(title: const Text('Competition Management')),
        body: loginPrompt,
      );
    }

    if (widget.competitionId != null) {
      if (_isLoading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (_competition == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Manage Competition')),
          body: const Center(child: Text('Error loading competition details.')),
        );
      }
      return _buildCompetitionDetailView(context, _competition!, theme);
    }

    final manageableComps = provider.competitions.where((comp) {
      if (currentUser.isAdmin) return true;
      final bool ownsAssociation = comp.associationId != null &&
          provider.associations.any(
            (assoc) =>
                assoc.id == comp.associationId &&
                assoc.ownerId == currentUser.id,
          );
      final bool canManageIndividual =
          comp.associationId == null && currentUser.isCompetitionCreator;
      return ownsAssociation || canManageIndividual;
    }).toList();

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final isTablet = size.width >= 600 && size.width < 900;

    final mainWidget = _buildMainContent(
      context,
      provider,
      theme,
      isDesktop,
      isTablet,
      manageableComps,
    );

    if (widget.isInline) {
      return mainWidget;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Competition Management'),
      ),
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width - 56.0,
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  child: CompetitionFilterContent(
                    provider: provider,
                    isDesktop: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: mainWidget,
      floatingActionButton: !isDesktop
          ? FloatingActionButton.extended(
              key: const Key('create_competition_fab'),
              backgroundColor: const Color(0xFFE94E1B),
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CompetitionCreationPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Competition'),
            )
          : null,
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
    bool isTablet,
    List<dynamic> manageableComps,
  ) {
    final resultsWidget = manageableComps.isEmpty
        ? _buildEmptyState(theme, provider)
        : (provider.layout == CompetitionsLayout.list
            ? _buildCompactList(theme, manageableComps)
            : _buildGridList(theme, manageableComps, isDesktop, isTablet));

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
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
                  color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: CompetitionFilterContent(
                      provider: provider,
                      isDesktop: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _buildResultsHeader(context, provider, theme, true, manageableComps.length),
                Expanded(child: resultsWidget),
              ],
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildResultsHeader(context, provider, theme, false, manageableComps.length),
          Expanded(child: resultsWidget),
        ],
      );
    }
  }

  Widget _buildResultsHeader(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
    int count,
  ) {
    final statusSelector = SegmentedButton<String>(
      segments: const [
        ButtonSegment<String>(
          value: 'upcoming',
          label: Text('Upcoming'),
          icon: Icon(Icons.upcoming, size: 16),
        ),
        ButtonSegment<String>(
          value: 'completed',
          label: Text('Completed'),
          icon: Icon(Icons.check_circle_outline, size: 16),
        ),
      ],
      selected: {_selectedCompetitionStatus},
      onSelectionChanged: (val) {
        final newStatus = val.first;
        setState(() {
          _selectedCompetitionStatus = newStatus;
        });
        provider.fetchCompetitions(status: newStatus);
      },
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: const Color(0xFFE94E1B),
        selectedForegroundColor: Colors.white,
      ),
    );

    final createButton = ElevatedButton.icon(
      key: const Key('create_competition_button'),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CompetitionCreationPage(),
          ),
        );
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

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$count Competitions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            statusSelector,
            const SizedBox(width: 12),
            createButton,
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              iconColor: theme.colorScheme.onSurfaceVariant,
              icon: Icon(
                Icons.sort,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Sort options',
              offset: const Offset(0, 40),
              onSelected: (val) {
                provider.setSortOrder(val);
              },
              itemBuilder: (BuildContext context) => [
                CheckedPopupMenuItem<String>(
                  value: 'date_asc',
                  checked: provider.sortOrder == 'date_asc',
                  child: const Text('Date: Asc'),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'date_desc',
                  checked: provider.sortOrder == 'date_desc',
                  child: const Text('Date: Desc'),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'name_asc',
                  checked: provider.sortOrder == 'name_asc',
                  child: const Text('Name: A-Z'),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'name_desc',
                  checked: provider.sortOrder == 'name_desc',
                  child: const Text('Name: Z-A'),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
            child: Row(
              children: [
                Expanded(child: statusSelector),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '$count Competitions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
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
                        if (!widget.isInline) {
                          Scaffold.of(context).openEndDrawer();
                        } else {
                          final ScaffoldState? shellScaffold = Scaffold.maybeOf(context);
                          if (shellScaffold != null && shellScaffold.hasEndDrawer) {
                            shellScaffold.openEndDrawer();
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      iconColor: theme.colorScheme.onSurfaceVariant,
                      icon: Icon(
                        Icons.sort,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Sort options',
                      offset: const Offset(0, 40),
                      onSelected: (val) {
                        provider.setSortOrder(val);
                      },
                      itemBuilder: (BuildContext context) => [
                        CheckedPopupMenuItem<String>(
                          value: 'date_asc',
                          checked: provider.sortOrder == 'date_asc',
                          child: const Text('Date: Asc'),
                        ),
                        CheckedPopupMenuItem<String>(
                          value: 'date_desc',
                          checked: provider.sortOrder == 'date_desc',
                          child: const Text('Date: Desc'),
                        ),
                        CheckedPopupMenuItem<String>(
                          value: 'name_asc',
                          checked: provider.sortOrder == 'name_asc',
                          child: const Text('Name: A-Z'),
                        ),
                        CheckedPopupMenuItem<String>(
                          value: 'name_desc',
                          checked: provider.sortOrder == 'name_desc',
                          child: const Text('Name: Z-A'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildEmptyState(ThemeData theme, CompetitionProvider provider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No competitions found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try refining your search query or reset filters.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: provider.clearFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset All Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactList(ThemeData theme, List<dynamic> competitions) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: competitions.length,
      itemBuilder: (context, index) {
        final comp = competitions[index];
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
            leading: Container(
              width: 80,
              padding: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('MMM dd').format(comp.startDate).toUpperCase(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    DateFormat('yyyy').format(comp.startDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              comp.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      comp.sportSubtype.toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      comp.location,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      comp.status.toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Manage',
                  onPressed: () {
                    context.go('/management/competitions/${comp.id}/metadata');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  tooltip: 'View Details',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CompetitionDetailPage(competition: comp),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Manage Attempts',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CompetitionJudgingPage(competitionId: comp.id),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridList(
    ThemeData theme,
    List<dynamic> competitions,
    bool isDesktop,
    bool isTablet,
  ) {
    final int crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        mainAxisExtent: 290,
      ),
      itemCount: competitions.length,
      itemBuilder: (context, index) {
        final comp = competitions[index] as Competition;
        return CompetitionCard(
          competition: comp,
          isManagement: true,
        );
      },
    );
  }

  // --- DETAIL VIEW LAYOUTS ---

  Widget _buildCompetitionLogoAvatar(BuildContext context, Competition comp, double size) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        comp.title.isNotEmpty ? comp.title[0].toUpperCase() : 'C',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.45,
        ),
      ),
    );
  }

  Widget _buildCompetitionDetailView(BuildContext context, Competition comp, ThemeData theme) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    if (isDesktop) {
      return _buildDesktopDetailView(context, comp, theme);
    } else {
      return _buildMobileDetailView(context, comp, theme);
    }
  }

  Widget _buildDesktopDetailView(BuildContext context, Competition comp, ThemeData theme) {
    final navItems = [
      {'label': 'Metadata', 'icon': Icons.settings},
      {'label': 'Athlete Groups', 'icon': Icons.fitness_center},
      {'label': 'Volunteer Setup', 'icon': Icons.people},
      {'label': 'Sport & Rulebook', 'icon': Icons.menu_book},
      {'label': 'Custom Fields', 'icon': Icons.assignment},
    ];

    final prevStatus = _getPreviousStatus(comp.status, comp.requiresFees);
    final nextStatus = _getNextStatus(comp.status, comp.requiresFees);
    final nextActionLabel = _getNextActionLabel(comp.status, comp.requiresFees);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
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
                Row(
                  children: [
                    HoverableBreadcrumb(
                      label: 'My Competitions',
                      onTap: () => context.go('/management/competitions'),
                    ),
                    Text(
                      '  /  ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      comp.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              comp.title,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),
                          _buildStatusBadge(context, theme, comp.status),
                        ],
                      ),
                    ),
                    // Action Buttons for Lifecycle
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (prevStatus != null)
                          IconButton(
                            icon: const Icon(Icons.undo),
                            tooltip: 'Regress status to ${prevStatus.toUpperCase()}',
                            onPressed: () => _updateStatus(prevStatus),
                          ),
                        if (nextStatus != null && nextActionLabel != null) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE94E1B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            onPressed: () => _updateStatus(nextStatus),
                            child: Text(nextActionLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Chevron Banner
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: _buildChevronBanner(theme, comp),
          ),
          // Sidebar split view
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      // Configuration Section Header
                      Padding(
                        padding: const EdgeInsets.only(left: 28.0, top: 16.0, bottom: 8.0),
                        child: Text(
                          'CONFIGURATION',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      // Display all configuration items directly (no toggle)
                      ...List.generate(5, (idx) {
                        final item = navItems[idx];
                        final isSelected = _currentIndex == idx;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                          child: InkWell(
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            onTap: () {
                              if (idx == _currentIndex) return;
                              final tabName = _getTabNameFromIndex(idx);
                              setState(() {
                                _currentIndex = idx;
                                _activeIndexedStackIndex = idx;
                                _activatedIndices.add(idx);
                                _lastActiveTabIndex = idx;
                              });
                              context.go('/management/competitions/${comp.id}/$tabName');
                            },
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              height: 48,
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
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item['label'] as String,
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? theme.colorScheme.onSecondaryContainer
                                            : theme.colorScheme.onSurface,
                                        fontSize: 13,
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
                Expanded(
                  child: IndexedStack(
                    index: _activeIndexedStackIndex,
                    children: [
                      _activatedIndices.contains(0) ? _buildMetadataTab(theme) : const SizedBox.shrink(),
                      _activatedIndices.contains(1) ? _buildAthleteGroupsTab(theme) : const SizedBox.shrink(),
                      _activatedIndices.contains(2) ? _buildVolunteerTab(theme) : const SizedBox.shrink(),
                      _activatedIndices.contains(3) ? _buildSportRulebookTab(theme) : const SizedBox.shrink(),
                      _activatedIndices.contains(4) ? _buildDisclaimersTab(theme) : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDetailView(BuildContext context, Competition comp, ThemeData theme) {
    final navItems = [
      {'label': 'Metadata', 'icon': Icons.settings},
      {'label': 'Athlete Groups', 'icon': Icons.fitness_center},
      {'label': 'Volunteer Setup', 'icon': Icons.people},
      {'label': 'Sport & Rulebook', 'icon': Icons.menu_book},
      {'label': 'Custom Fields', 'icon': Icons.assignment},
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/management/competitions');
            }
          },
        ),
        title: Text(
          comp.title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
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
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _activatedIndices.contains(0) ? _buildMetadataTab(theme) : const SizedBox.shrink(),
                  _activatedIndices.contains(1) ? _buildAthleteGroupsTab(theme) : const SizedBox.shrink(),
                  _activatedIndices.contains(2) ? _buildVolunteerTab(theme) : const SizedBox.shrink(),
                  _activatedIndices.contains(3) ? _buildSportRulebookTab(theme) : const SizedBox.shrink(),
                  _activatedIndices.contains(4) ? _buildDisclaimersTab(theme) : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DETAIL TABS ---

  Widget _buildMetadataTab(ThemeData theme) {
    final provider = Provider.of<CompetitionProvider>(context);
    final sportConfig = provider.sportConfig;
    final sports = sportConfig?.sports.map((s) => s.name).toList() ?? ['Streetlifting'];
    final formats = sportConfig?.formats
            .where((f) => f.sportName == _sportType)
            .map((f) => f.name)
            .toList() ?? ['Modern', 'Classic'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _metadataFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Competition Metadata',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (!_isEditingMetadata)
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isEditingMetadata = true),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('EDIT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE94E1B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isEditingMetadata = false;
                            _populateMetadataControllers(_competition!);
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text('CANCEL'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _saveMetadata,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE94E1B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text('SAVE'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // 1. General Information Card
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
                    TextFormField(
                      controller: _titleController,
                      enabled: _isEditingMetadata,
                      decoration: const InputDecoration(labelText: 'Title *', prefixIcon: Icon(Icons.title)),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: _isEditingMetadata,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined)),
                    ),
                    const SizedBox(height: 16),
                    _buildCustomDropdownField<String?>(
                      labelText: 'Parent Association',
                      value: _selectedAssociationId,
                      enabled: _isEditingMetadata,
                      prefixIcon: const Icon(Icons.business_outlined),
                      displayValue: (val) {
                        if (val == null) return 'None';
                        final found = _eligibleAssociations.firstWhere((a) => a.id == val, orElse: () {
                          final all = provider.associations;
                          return all.firstWhere((a) => a.id == val, orElse: () => Association(id: val, ownerId: '', name: 'Loading...', description: '', scope: '', supportedSports: [], supportedFormats: [], rulebooks: const {}, socialChannels: const {}));
                        });
                        return found.name;
                      },
                      items: [
                        const PopupMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._eligibleAssociations.map((assoc) => PopupMenuItem<String?>(
                              value: assoc.id,
                              child: Text(assoc.name),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedAssociationId = val;
                        });
                        _onParentOrSportChanged();
                      },
                    ),
                    if (_selectedAssociationId != null && _availableCompGroups.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildCustomDropdownField<String?>(
                        labelText: 'Competition Group',
                        value: _selectedCompGroupName,
                        enabled: _isEditingMetadata,
                        prefixIcon: const Icon(Icons.group_work_outlined),
                        displayValue: (val) => val ?? 'None (Individual)',
                        items: [
                          const PopupMenuItem<String?>(
                            value: null,
                            child: Text('None (Individual)'),
                          ),
                          ..._availableCompGroups.map((cg) => PopupMenuItem<String?>(
                                value: cg.name,
                                child: Text(cg.name),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedCompGroupName = val;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 2. Competition Location Card
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
                      'Location',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('comp_location_field'),
                      controller: _locationController,
                      enabled: _isEditingMetadata,
                      decoration: const InputDecoration(labelText: 'Location / Address *', prefixIcon: Icon(Icons.location_on)),
                      onChanged: (val) {
                        setState(() {
                          _isLocationVerified = false;
                        });
                        _updateLocationSuggestions('location', val);
                      },
                    ),
                    if (_isEditingMetadata && _activeLocationField == 'location' && _locationSuggestions.isNotEmpty)
                      _buildSuggestionsList(_locationController),
                    const SizedBox(height: 12),
                    VerifiedLocationBadge(
                      key: const Key('comp_location_verify_badge'),
                      isVerifying: _isVerifyingLocation,
                      isVerified: _isLocationVerified,
                      onVerify: _verifyLocation,
                      enabled: _isEditingMetadata,
                    ),
                  ],
                ),
              ),
            ),

            // 3. Sport & Format Card
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
                      'Sport & Format',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    _buildCustomDropdownField<String>(
                      labelText: 'Sport Type',
                      value: sports.contains(_sportType) ? _sportType : sports.first,
                      enabled: _isEditingMetadata && _selectedCompGroupName == null,
                      prefixIcon: Icon(Icons.sports, color: theme.colorScheme.primary, size: 20),
                      items: sports.map((s) => PopupMenuItem<String>(
                            value: s,
                            child: Text(s),
                          )).toList(),
                      onChanged: (val) {
                        setState(() {
                          _sportType = val;
                          final newFormats = sportConfig?.formats
                              .where((f) => f.sportName == _sportType)
                              .map((f) => f.name)
                              .toList() ?? ['Modern', 'Classic'];
                          _sportSubtype = newFormats.contains(_sportSubtype) ? _sportSubtype : newFormats.first;
                        });
                        _onParentOrSportChanged();
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildCustomDropdownField<String>(
                      labelText: 'Sport Format *',
                      value: formats.contains(_sportSubtype) ? _sportSubtype : formats.first,
                      enabled: _isEditingMetadata && _selectedCompGroupName == null,
                      prefixIcon: const Icon(Icons.format_list_bulleted_outlined),
                      items: formats.map((f) => PopupMenuItem<String>(
                            value: f,
                            child: Text(f),
                          )).toList(),
                      onChanged: (val) {
                        setState(() {
                          _sportSubtype = val;
                        });
                      },
                    ),
                    if (_selectedCompGroupName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Sport and format are locked to match the selected Competition Group: $_selectedCompGroupName',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildCustomDropdownField<String>(
                      labelText: 'Ranking Type',
                      value: _rankingType,
                      enabled: _isEditingMetadata,
                      prefixIcon: Icon(Icons.analytics, color: theme.colorScheme.primary, size: 20),
                      displayValue: (val) {
                        if (val == 'open') return 'Open';
                        if (val == 'gender') return 'By Gender';
                        if (val == 'athlete_group') return 'By Athlete Group';
                        return val;
                      },
                      items: const [
                        PopupMenuItem<String>(value: 'open', child: Text('Open')),
                        PopupMenuItem<String>(value: 'gender', child: Text('By Gender')),
                        PopupMenuItem<String>(value: 'athlete_group', child: Text('By Athlete Group')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _rankingType = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rulebookUrlController,
                      enabled: _isEditingMetadata,
                      decoration: const InputDecoration(
                        labelText: 'Rulebook URL',
                        hintText: 'Enter rulebook website link',
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Media Assets Card
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
                                onPressed: _isEditingMetadata ? (_isUploadingBanner ? null : _pickBannerImage) : null,
                                icon: _isUploadingBanner
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
                                  _bannerFileName ?? (_titleImageUrlController.text.isNotEmpty ? 'Custom banner set' : 'No image selected'),
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          if (_titleImageUrlController.text.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                ImageUrlResolver.resolve(context, _titleImageUrlController.text),
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

            // 5. Dates & Deadlines Card
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
                      'Dates & Deadlines',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    _buildDateRangeTile(
                      title: 'Competition Period',
                      start: DateTime.tryParse(_startDateController.text) ?? _competition?.startDate ?? DateTime.now(),
                      end: DateTime.tryParse(_endDateController.text) ?? _competition?.endDate ?? DateTime.now(),
                      enabled: _isEditingMetadata,
                      theme: theme,
                      onSelected: (start, end) {
                        setState(() {
                          _startDateController.text = DateFormat('yyyy-MM-dd HH:mm').format(start);
                          _endDateController.text = DateFormat('yyyy-MM-dd HH:mm').format(end);
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDateRangeTile(
                      title: 'Registration Period',
                      start: DateTime.tryParse(_regStartController.text) ?? _competition?.registrationStart ?? DateTime.now(),
                      end: DateTime.tryParse(_regEndController.text) ?? _competition?.registrationEnd ?? DateTime.now(),
                      enabled: _isEditingMetadata,
                      theme: theme,
                      onSelected: (start, end) {
                        setState(() {
                          _regStartController.text = DateFormat('yyyy-MM-dd HH:mm').format(start);
                          _regEndController.text = DateFormat('yyyy-MM-dd HH:mm').format(end);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 6. Registration Settings Card
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
                      'Registration Settings',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    _buildCustomDropdownField<String>(
                      labelText: 'Registration Mode',
                      value: _registrationMode,
                      enabled: _isEditingMetadata,
                      prefixIcon: const Icon(Icons.app_registration),
                      displayValue: (val) => val == 'fcfs' ? 'First Come, First Served' : 'Approval Required',
                      items: const [
                        PopupMenuItem<String>(value: 'fcfs', child: Text('First Come, First Served')),
                        PopupMenuItem<String>(value: 'approval', child: Text('Approval Required')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _registrationMode = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _maxAthletesController,
                      enabled: _isEditingMetadata,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Total Athlete Capacity Limit', prefixIcon: Icon(Icons.person_pin_outlined)),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Enable Waitlist'),
                      value: _enableWaitlist,
                      onChanged: _isEditingMetadata ? (val) => setState(() => _enableWaitlist = val) : null,
                    ),
                  ],
                ),
              ),
            ),

            // 7. Payment Settings Card
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
                      'Payment Settings',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Requires Entry Fees'),
                      value: _requiresFees,
                      onChanged: _isEditingMetadata ? (val) => setState(() => _requiresFees = val) : null,
                    ),
                    if (_requiresFees) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _feeAmountController,
                              enabled: _isEditingMetadata,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Fee Amount', prefixIcon: Icon(Icons.attach_money)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _buildCustomDropdownField<String>(
                              labelText: 'Currency',
                              value: _feeCurrency,
                              enabled: _isEditingMetadata,
                              displayValue: (val) {
                                if (val == 'EUR') return 'EUR (€)';
                                if (val == 'USD') return 'USD (\$)';
                                if (val == 'GBP') return 'GBP (£)';
                                return val;
                              },
                              items: const [
                                PopupMenuItem<String>(value: 'EUR', child: Text('EUR (€)')),
                                PopupMenuItem<String>(value: 'USD', child: Text('USD (\$)')),
                                PopupMenuItem<String>(value: 'GBP', child: Text('GBP (£)')),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _feeCurrency = val;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text('Bank Account Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ibanController,
                        enabled: _isEditingMetadata,
                        decoration: const InputDecoration(
                          labelText: 'IBAN *',
                          hintText: 'DE89 3704 0044 ...',
                          prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bicController,
                        enabled: _isEditingMetadata,
                        decoration: const InputDecoration(
                          labelText: 'BIC *',
                          hintText: 'WELADEDDXXX',
                          prefixIcon: Icon(Icons.code),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bankNameController,
                        enabled: _isEditingMetadata,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name *',
                          hintText: 'e.g. Deutsche Bank',
                          prefixIcon: Icon(Icons.account_balance_outlined),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text('Payment Reference', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildCustomDropdownField<String>(
                        labelText: 'Payment Reference Type',
                        value: _paymentRefType,
                        enabled: _isEditingMetadata,
                        prefixIcon: Icon(Icons.receipt_long_outlined, color: theme.colorScheme.primary, size: 20),
                        displayValue: (val) {
                          if (val == 'auto') return 'Auto-Generated Reference';
                          if (val == 'custom') return 'Custom Reference Instructions';
                          return val;
                        },
                        items: const [
                          PopupMenuItem(value: 'auto', child: Text('Auto-Generated Reference')),
                          PopupMenuItem(value: 'custom', child: Text('Custom Reference Instructions')),
                        ],
                        onChanged: (val) {
                          setState(() => _paymentRefType = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_paymentRefType == 'auto')
                        Card(
                          color: theme.colorScheme.surfaceContainerLow,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Preview Reference Example:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(_getGeneratedPaymentDesc(), style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFFE94E1B))),
                              ],
                            ),
                          ),
                        )
                      else
                        TextFormField(
                          controller: _paymentDescController,
                          enabled: _isEditingMetadata,
                          maxLength: 140,
                          decoration: const InputDecoration(
                            labelText: 'Custom Payment Reference *',
                            hintText: 'Enter custom payment instructions (max 140 char)',
                            prefixIcon: Icon(Icons.edit_note),
                          ),
                        ),
                      const SizedBox(height: 24),
                      _buildDateRangeTile(
                        title: 'Payment Period',
                        start: DateTime.tryParse(_paymentStartController.text) ?? DateTime.now(),
                        end: DateTime.tryParse(_paymentEndController.text) ?? DateTime.now().add(const Duration(days: 7)),
                        enabled: _isEditingMetadata,
                        onSelected: (start, end) => setState(() {
                          _paymentStartController.text = DateFormat('yyyy-MM-dd HH:mm').format(start);
                          _paymentEndController.text = DateFormat('yyyy-MM-dd HH:mm').format(end);
                        }),
                        theme: theme,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 8. Website and Social Media Card
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
                      'Website and Social Media',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _websiteController,
                      enabled: _isEditingMetadata,
                      decoration: const InputDecoration(
                        labelText: 'Official Website URL',
                        hintText: 'https://www.example.com',
                        prefixIcon: Icon(Icons.language),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ticketShopController,
                      enabled: _isEditingMetadata,
                      decoration: const InputDecoration(
                        labelText: 'Ticket Shop URL',
                        hintText: 'https://www.example.com/tickets',
                        prefixIcon: Icon(Icons.local_activity),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text('Social Media Handles / URLs', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _socialControllers.length,
                      itemBuilder: (context, idx) {
                        final platform = _socialControllers.keys.elementAt(idx);
                        final controller = _socialControllers[platform]!;
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
                            enabled: _isEditingMetadata,
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
    );
  }

  Widget _buildAthleteGroupsTab(ThemeData theme) {
    final Map<String, List<MapEntry<int, Map<String, dynamic>>>> grouped = {};
    for (int i = 0; i < _compAthleteGroups.length; i++) {
      final group = _compAthleteGroups[i];
      final genderKey = (group['gender'] ?? 'men').toString().toLowerCase().trim();
      grouped.putIfAbsent(genderKey, () => []).add(MapEntry(i, group));
    }

    const preferredOrder = ['men', 'women', 'open'];
    final sortedGenders = grouped.keys.toList()
      ..sort((a, b) {
        final idxA = preferredOrder.indexOf(a);
        final idxB = preferredOrder.indexOf(b);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Athlete Groups', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_competition?.associationId != null)
                    OutlinedButton.icon(
                      onPressed: _applyParentGroups,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Apply Parent Groups'),
                    ),
                  ElevatedButton.icon(
                    onPressed: () => _showAthleteGroupDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Group'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE94E1B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_compAthleteGroups.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No athlete groups defined yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            Column(
              children: sortedGenders.map((genderKey) {
                final entries = grouped[genderKey]!;
                final displayGender = genderKey == 'women'
                    ? 'Women'
                    : (genderKey.isEmpty ? '' : genderKey[0].toUpperCase() + genderKey.substring(1));

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: CollapsibleSection(
                    initiallyExpanded: true,
                    title: Row(
                      children: [
                        Text(
                          displayGender,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${entries.length}',
                            style: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: entries.map((entry) {
                      final idx = entry.key;
                      final group = entry.value;
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
                          title: Text(group['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              'Limit: ${group['limit'] ?? "Unlimited"}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                                onPressed: () => _showAthleteGroupDialog(editIndex: idx),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                onPressed: () async {
                                  setState(() {
                                    _compAthleteGroups.removeAt(idx);
                                  });
                                  final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                                  final updatedComp = _competition!.copyWith(maxAthletesPerGroup: _compAthleteGroups);
                                  await compProvider.updateCompetition(updatedComp);
                                  _loadCompetitionData();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _applyParentGroups() async {
    if (_competition?.associationId == null) return;
    setState(() {
      _isLoading = true;
    });
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    try {
      final List<AthleteGroup> parentGroups = await compProvider.getAthleteGroups(_competition!.associationId!);
      if (parentGroups.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No parent athlete groups found.')),
          );
        }
      } else {
        setState(() {
          for (var pg in parentGroups) {
            final exists = _compAthleteGroups.any((g) => g['name'] == pg.name && g['gender'] == pg.gender);
            if (!exists) {
              _compAthleteGroups.add({
                'name': pg.name,
                'gender': pg.gender,
                'limit': null,
              });
            }
          }
        });
        final updatedComp = _competition!.copyWith(maxAthletesPerGroup: _compAthleteGroups);
        await compProvider.updateCompetition(updatedComp);
        _loadCompetitionData();
      }
    } catch (_) {}
    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildVolunteerTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Volunteer Setup', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Enable Volunteer Needs'),
            value: _volunteerNeeds,
            onChanged: (val) async {
              setState(() {
                _volunteerNeeds = val;
              });
              final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
              final updatedComp = _competition!.copyWith(volunteerNeeds: val);
              await compProvider.updateCompetition(updatedComp);
              _loadCompetitionData();
            },
          ),
          if (_volunteerNeeds) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _maxVolunteersController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total Volunteer Limit', prefixIcon: Icon(Icons.groups)),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94E1B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () async {
                    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                    final updatedComp = _competition!.copyWith(maxVolunteers: int.tryParse(_maxVolunteersController.text));
                    await compProvider.updateCompetition(updatedComp);
                    _loadCompetitionData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Volunteer limit updated!')),
                    );
                  },
                  child: const Text('Save Limit'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Volunteer Positions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => _showVolunteerPositionDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Position'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94E1B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_maxVolunteersPerPosition.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No volunteer positions defined.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _maxVolunteersPerPosition.length,
                itemBuilder: (context, idx) {
                  final key = _maxVolunteersPerPosition.keys.elementAt(idx);
                  final limit = _maxVolunteersPerPosition[key]!;
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
                      title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          'Volunteer Limit: ${limit == 0 ? "Unlimited" : limit}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                            onPressed: () => _showVolunteerPositionDialog(editKey: key),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                            onPressed: () async {
                              setState(() {
                                _maxVolunteersPerPosition.remove(key);
                              });
                              final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                              final updatedComp = _competition!.copyWith(
                                maxVolunteersPerPosition: _maxVolunteersPerPosition,
                                volunteerPositions: _maxVolunteersPerPosition.keys.toList(),
                              );
                              await compProvider.updateCompetition(updatedComp);
                              _loadCompetitionData();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisclaimersTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Legal Disclaimers', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showDisclaimerDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Disclaimer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE94E1B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_disclaimers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text('No disclaimers added.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _disclaimers.length,
              itemBuilder: (context, idx) {
                final d = _disclaimers[idx];
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
                    title: Text(d['text'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: d['url'] != null && d['url']!.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              'Link: ${d['url']}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                          onPressed: () => _showDisclaimerDialog(editIndex: idx),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          onPressed: () async {
                            setState(() {
                              _disclaimers.removeAt(idx);
                            });
                            final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                            final updatedComp = _competition!.copyWith(
                              disclaimerText: _disclaimers.isEmpty ? null : jsonEncode(_disclaimers),
                            );
                            await compProvider.updateCompetition(updatedComp);
                            _loadCompetitionData();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const Divider(height: 48),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Custom Athlete Fields', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showCustomFieldDialog(true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Field'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE94E1B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_customAthleteFields.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text('No custom athlete fields.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _customAthleteFields.length,
              itemBuilder: (context, idx) {
                final f = _customAthleteFields[idx];
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
                    title: Text(f['name']),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        'Type: ${f['type'] == 'text' ? 'Text Input' : (f['type'] == 'boolean' ? 'Checkbox' : (f['type'] == 'dropdown' ? 'Dropdown' : f['type']))}'
                        '${f['options'] != null ? " (${(f['options'] as List).join(', ')})" : ""}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                          onPressed: () => _showCustomFieldDialog(true, editIndex: idx),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          onPressed: () async {
                            setState(() {
                              _customAthleteFields.removeAt(idx);
                            });
                            final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                            final updatedComp = _competition!.copyWith(customAthleteFields: _customAthleteFields);
                            await compProvider.updateCompetition(updatedComp);
                            _loadCompetitionData();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const Divider(height: 48),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Custom Volunteer Fields', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showCustomFieldDialog(false),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Field'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE94E1B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_customVolunteerFields.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text('No custom volunteer fields.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _customVolunteerFields.length,
              itemBuilder: (context, idx) {
                final f = _customVolunteerFields[idx];
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
                    title: Text(f['name']),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        'Type: ${f['type'] == 'text' ? 'Text Input' : (f['type'] == 'boolean' ? 'Checkbox' : (f['type'] == 'dropdown' ? 'Dropdown' : f['type']))}'
                        '${f['options'] != null ? " (${(f['options'] as List).join(', ')})" : ""}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                          onPressed: () => _showCustomFieldDialog(false, editIndex: idx),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          onPressed: () async {
                            setState(() {
                              _customVolunteerFields.removeAt(idx);
                            });
                            final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                            final updatedComp = _competition!.copyWith(customVolunteerFields: _customVolunteerFields);
                            await compProvider.updateCompetition(updatedComp);
                            _loadCompetitionData();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- DIALOGS ---

  void _showAthleteGroupDialog({int? editIndex}) {
    final isEdit = editIndex != null;
    final nameController = TextEditingController(text: isEdit ? _compAthleteGroups[editIndex!]['name'] : '');
    final limitController = TextEditingController(text: isEdit ? (_compAthleteGroups[editIndex!]['limit']?.toString() ?? '') : '');
    String gender = isEdit ? _compAthleteGroups[editIndex!]['gender'] ?? 'men' : 'men';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Athlete Group' : 'Add Athlete Group'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Group Name', hintText: 'e.g. -74kg'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: 'men', child: Text('Men')),
                        DropdownMenuItem(value: 'women', child: Text('Women')),
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            gender = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Athlete Limit (optional)', hintText: 'e.g. 15'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94E1B),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final limit = int.tryParse(limitController.text.trim());

                    final Map<String, dynamic> groupMap = {
                      'name': name,
                      'gender': gender,
                      if (limit != null) 'limit': limit,
                    };

                    setState(() {
                      if (isEdit) {
                        _compAthleteGroups[editIndex!] = groupMap;
                      } else {
                        _compAthleteGroups.add(groupMap);
                      }
                    });

                    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                    final updatedComp = _competition!.copyWith(maxAthletesPerGroup: _compAthleteGroups);
                    await compProvider.updateCompetition(updatedComp);
                    _loadCompetitionData();

                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showVolunteerPositionDialog({String? editKey}) {
    final isEdit = editKey != null;
    final nameController = TextEditingController(text: isEdit ? editKey : '');
    final limitController = TextEditingController(text: isEdit ? (_maxVolunteersPerPosition[editKey]?.toString() ?? '') : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Volunteer Position' : 'Add Volunteer Position'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                enabled: !isEdit,
                decoration: const InputDecoration(labelText: 'Position Name', hintText: 'e.g. Spotter/Loader'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: limitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Volunteer Limit (optional)', hintText: 'e.g. 5'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94E1B),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final limit = int.tryParse(limitController.text.trim()) ?? 0;

                setState(() {
                  _maxVolunteersPerPosition[name] = limit;
                });

                final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                final updatedComp = _competition!.copyWith(
                  maxVolunteersPerPosition: _maxVolunteersPerPosition,
                  volunteerPositions: _maxVolunteersPerPosition.keys.toList(),
                );
                await compProvider.updateCompetition(updatedComp);
                _loadCompetitionData();

                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDisclaimerDialog({int? editIndex}) {
    final isEdit = editIndex != null;
    final textController = TextEditingController(text: isEdit ? _disclaimers[editIndex!]['text'] : '');
    final urlController = TextEditingController(text: isEdit ? (_disclaimers[editIndex!]['url'] ?? '') : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Disclaimer' : 'Add Disclaimer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: textController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Disclaimer Text', hintText: 'e.g. I agree to the terms...'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'Disclaimer Link URL (optional)', hintText: 'e.g. https://...'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94E1B),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final text = textController.text.trim();
                if (text.isEmpty) return;
                final url = urlController.text.trim();

                final Map<String, String> disc = {
                  'text': text,
                  if (url.isNotEmpty) 'url': url,
                };

                setState(() {
                  if (isEdit) {
                    _disclaimers[editIndex!] = disc;
                  } else {
                    _disclaimers.add(disc);
                  }
                });

                final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                final updatedComp = _competition!.copyWith(
                  disclaimerText: _disclaimers.isEmpty ? null : jsonEncode(_disclaimers),
                );
                await compProvider.updateCompetition(updatedComp);
                _loadCompetitionData();

                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomFieldDialog(bool isAthlete, {int? editIndex}) {
    final isEdit = editIndex != null;
    final fieldsList = isAthlete ? _customAthleteFields : _customVolunteerFields;
    final nameController = TextEditingController(text: isEdit ? fieldsList[editIndex!]['name'] : '');
    String type = isEdit ? fieldsList[editIndex!]['type'] ?? 'text' : 'text';
    final optionsController = TextEditingController(
      text: isEdit && fieldsList[editIndex!]['options'] != null
          ? (fieldsList[editIndex!]['options'] as List).join(', ')
          : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Custom Field' : 'Add Custom Field'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Field Label/Name', hintText: 'e.g. T-Shirt Size'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Field Type'),
                      items: const [
                        DropdownMenuItem(value: 'text', child: Text('Text Input')),
                        DropdownMenuItem(value: 'boolean', child: Text('Checkbox')),
                        DropdownMenuItem(value: 'dropdown', child: Text('Dropdown / Select')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            type = val;
                          });
                        }
                      },
                    ),
                    if (type == 'dropdown') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: optionsController,
                        decoration: const InputDecoration(
                          labelText: 'Dropdown Options (comma-separated)',
                          hintText: 'e.g. S, M, L, XL',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94E1B),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    final Map<String, dynamic> fMap = {
                      'name': name,
                      'type': type,
                      if (type == 'dropdown' && optionsController.text.trim().isNotEmpty)
                        'options': optionsController.text.split(',').map((e) => e.trim()).toList(),
                    };

                    setState(() {
                      if (isEdit) {
                        fieldsList[editIndex!] = fMap;
                      } else {
                        fieldsList.add(fMap);
                      }
                    });

                    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                    final updatedComp = isAthlete
                        ? _competition!.copyWith(customAthleteFields: _customAthleteFields)
                        : _competition!.copyWith(customVolunteerFields: _customVolunteerFields);

                    await compProvider.updateCompetition(updatedComp);
                    _loadCompetitionData();

                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- SPORT & RULEBOOK TAB ---

  Widget _buildSportRulebookTab(ThemeData theme) {
    final provider = Provider.of<CompetitionProvider>(context);
    final sportConfig = provider.sportConfig;

    final sports = sportConfig?.sports.map((s) => s.name).toList() ?? ['Streetlifting'];
    final formats = sportConfig?.formats
            .where((f) => f.sportName == _sportType)
            .map((f) => f.name)
            .toList() ??
        ['Modern', 'Classic'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Sport & Rulebook Configuration',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (!_isEditingSportRulebook)
                ElevatedButton.icon(
                  onPressed: () => setState(() => _isEditingSportRulebook = true),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('EDIT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94E1B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isEditingSportRulebook = false;
                          _populateMetadataControllers(_competition!);
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text('CANCEL'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saveSportRulebook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE94E1B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text('SAVE'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),

          Card(
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
                    'Sport Format Details',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 20),
                  _buildCustomDropdownField<String>(
                    labelText: 'Sport Type',
                    value: sports.contains(_sportType) ? _sportType : sports.first,
                    enabled: _isEditingSportRulebook,
                    prefixIcon: Icon(Icons.sports, color: theme.colorScheme.primary, size: 20),
                    items: sports
                        .map((s) => PopupMenuItem<String>(
                              value: s,
                              child: Text(s),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _sportType = val;
                        final newFormats = sportConfig?.formats
                                .where((f) => f.sportName == _sportType)
                                .map((f) => f.name)
                                .toList() ??
                            ['Modern', 'Classic'];
                        _sportSubtype = newFormats.contains(_sportSubtype) ? _sportSubtype : newFormats.first;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildCustomDropdownField<String>(
                    labelText: 'Sport Format / Subtype',
                    value: formats.contains(_sportSubtype) ? _sportSubtype : formats.first,
                    enabled: _isEditingSportRulebook,
                    prefixIcon: Icon(Icons.sports_outlined, color: theme.colorScheme.primary, size: 20),
                    items: formats
                        .map((f) => PopupMenuItem<String>(
                              value: f,
                              child: Text(f),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _sportSubtype = val;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildCustomDropdownField<String>(
                    labelText: 'Ranking Type',
                    value: _rankingType,
                    enabled: _isEditingSportRulebook,
                    displayValue: (val) {
                      if (val == 'open') return 'Open';
                      if (val == 'gender') return 'By Gender';
                      if (val == 'athlete_group') return 'By Athlete Group';
                      return val;
                    },
                    prefixIcon: Icon(Icons.analytics, color: theme.colorScheme.primary, size: 20),
                    items: const [
                      PopupMenuItem<String>(
                        value: 'open',
                        child: Text('Open'),
                      ),
                      PopupMenuItem<String>(
                        value: 'gender',
                        child: Text('By Gender'),
                      ),
                      PopupMenuItem<String>(
                        value: 'athlete_group',
                        child: Text('By Athlete Group'),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _rankingType = val;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_competition?.associationId != null) ...[
                    _buildCustomDropdownField<String?>(
                      labelText: 'Competition Group',
                      value: _selectedCompGroupName,
                      enabled: _isEditingSportRulebook,
                      displayValue: (val) => val ?? 'None (Individual)',
                      prefixIcon: const Icon(Icons.group_work_outlined),
                      items: [
                        const PopupMenuItem<String?>(
                          value: null,
                          child: Text('None (Individual)'),
                        ),
                        ..._availableCompGroups.map((cg) => PopupMenuItem<String?>(
                              value: cg.name,
                              child: Text(cg.name),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedCompGroupName = val;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  TextFormField(
                    controller: _rulebookUrlController,
                    enabled: _isEditingSportRulebook,
                    decoration: const InputDecoration(
                      labelText: 'Rulebook URL',
                      hintText: 'Enter rulebook website link',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS & UTILITIES ---

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
        tooltip: labelText,
        offset: const Offset(0, 48),
        onSelected: onChanged,
        enabled: enabled,
        itemBuilder: (BuildContext context) => items,
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
                    color: enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.38),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: enabled ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurfaceVariant.withOpacity(0.38),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChevronBanner(ThemeData theme, Competition comp) {
    final requiresFees = comp.requiresFees;
    final currentStepIndex = _getStatusStepIndex(comp.status, requiresFees);
    final steps = [
      'Draft',
      'Published',
      'Registration',
      if (requiresFees) 'Payment',
      'Competition',
      'Completed'
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const height = 40.0;
        final indent = height * 0.25;
        const gap = 10.0;
        final n = steps.length;
        final w = (totalWidth + (n - 1) * (indent - gap)) / n;

        return Container(
          height: height,
          width: totalWidth,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: Stack(
            children: List.generate(n, (i) {
              final left = i * (w - indent + gap);
              final stepStatus = i < currentStepIndex
                  ? 'completed'
                  : (i == currentStepIndex ? 'active' : 'upcoming');

              Color bg;
              Color textCol;
              FontWeight fw;

              if (stepStatus == 'completed') {
                bg = const Color(0xFF2E7D32);
                textCol = Colors.white;
                fw = FontWeight.normal;
              } else if (stepStatus == 'active') {
                bg = const Color(0xFFE94E1B);
                textCol = Colors.white;
                fw = FontWeight.bold;
              } else {
                bg = theme.colorScheme.surfaceContainerLow;
                textCol = theme.colorScheme.onSurfaceVariant;
                fw = FontWeight.normal;
              }

              return Positioned(
                left: left,
                width: w,
                top: 0,
                bottom: 0,
                child: Stack(
                  children: [
                    ClipPath(
                      clipper: ChevronClipper(
                        isFirst: i == 0,
                        isLast: i == n - 1,
                        indent: indent,
                      ),
                      child: Container(
                        color: bg,
                        padding: EdgeInsets.only(
                          left: i == 0 ? height / 2 + 4.0 : indent + 6.0,
                          right: i == n - 1 ? height / 2 + 4.0 : indent + 6.0,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          steps[i],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textCol,
                            fontWeight: fw,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (stepStatus == 'upcoming')
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size(w, height),
                          painter: ChevronBorderPainter(
                            isFirst: i == 0,
                            isLast: i == n - 1,
                            indent: indent,
                            borderColor: theme.colorScheme.outlineVariant.withOpacity(0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  int _getStatusStepIndex(String status, bool requiresFees) {
    final normalized = status.toLowerCase();
    if (normalized == 'draft') return 0;
    if (normalized == 'published') return 1;
    if (normalized == 'registration started' || normalized == 'registration closed' || normalized == 'registration completed') return 2;
    if (requiresFees) {
      if (normalized == 'payment started' || normalized == 'payment completed') return 3;
      if (normalized == 'competition started') return 4;
      if (normalized == 'competition completed' || normalized == 'completed') return 5;
    } else {
      if (normalized == 'competition started') return 3;
      if (normalized == 'competition completed' || normalized == 'completed') return 4;
    }
    return 0;
  }

  String? _getNextStatus(String status, bool requiresFees) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'published';
      case 'published':
        return 'registration started';
      case 'registration started':
        return 'registration closed';
      case 'registration closed':
        return requiresFees ? 'payment started' : 'competition started';
      case 'payment started':
        return 'payment completed';
      case 'payment completed':
        return 'competition started';
      case 'competition started':
        return 'competition completed';
      default:
        return null;
    }
  }

  String? _getNextActionLabel(String status, bool requiresFees) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Publish Competition';
      case 'published':
        return 'Start Registration';
      case 'registration started':
        return 'Close Registration';
      case 'registration closed':
        return requiresFees ? 'Start Payment' : 'Start Competition';
      case 'payment started':
        return 'Complete Payment';
      case 'payment completed':
        return 'Start Competition';
      case 'competition started':
        return 'Complete Competition';
      default:
        return null;
    }
  }

  String? _getPreviousStatus(String status, bool requiresFees) {
    switch (status.toLowerCase()) {
      case 'published':
        return 'draft';
      case 'registration started':
        return 'published';
      case 'registration closed':
      case 'registration completed':
        return 'registration started';
      case 'payment started':
        return 'registration closed';
      case 'payment completed':
        return 'payment started';
      case 'competition started':
        return requiresFees ? 'payment completed' : 'registration closed';
      case 'competition completed':
      case 'completed':
        return 'competition started';
      default:
        return null;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    if (_competition == null) return;

    setState(() {
      _isLoading = true;
    });

    final updatedComp = _competition!.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );

    final result = await compProvider.updateCompetition(updatedComp);
    if (result != null && mounted) {
      setState(() {
        _competition = result;
        _populateMetadataControllers(result);
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Competition status updated to ${newStatus.toUpperCase()}'), backgroundColor: Colors.green),
      );
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update competition status.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveSportRulebook() async {
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    if (_competition == null) return;

    setState(() {
      _isLoading = true;
    });

    final updatedComp = _competition!.copyWith(
      sportType: _sportType,
      sportSubtype: _sportSubtype,
      rankingType: _rankingType,
      rulebookUrl: _rulebookUrlController.text.trim().isEmpty ? null : _rulebookUrlController.text.trim(),
      compGroupName: _selectedCompGroupName,
      updatedAt: DateTime.now(),
    );

    final result = await compProvider.updateCompetition(updatedComp);
    if (result != null && mounted) {
      setState(() {
        _competition = result;
        _populateMetadataControllers(result);
        _isEditingSportRulebook = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sport & Rulebook updated successfully!'), backgroundColor: Colors.green),
      );
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update Sport & Rulebook.'), backgroundColor: Colors.red),
      );
    }
  }


  Future<Map<String, DateTime>?> _selectDateTimeRange({
    required DateTime initialStart,
    required DateTime initialEnd,
  }) async {
    DateTimeRange? dateRange = DateTimeRange(start: initialStart, end: initialEnd);
    TimeOfDay startTime = TimeOfDay.fromDateTime(initialStart);
    TimeOfDay endTime = TimeOfDay.fromDateTime(initialEnd);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final use24Hour = authProvider.timeFormat == '24h';

    int currentStep = 0; // 0: DateRange, 1: StartTime, 2: EndTime

    while (currentStep >= 0 && currentStep < 3) {
      if (currentStep == 0) {
        final DateTimeRange? selected = await showDateRangePicker(
          context: context,
          initialDateRange: dateRange,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
          saveText: 'NEXT',
        );
        if (selected == null) {
          return null;
        }
        dateRange = selected;
        currentStep = 1;
      } else if (currentStep == 1) {
        final TimeOfDay? selected = await showTimePicker(
          context: context,
          initialTime: startTime,
          helpText: 'Select Start Time',
          cancelText: 'BACK',
          confirmText: 'NEXT',
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                alwaysUse24HourFormat: use24Hour,
              ),
              child: child!,
            );
          },
        );
        if (selected == null) {
          currentStep = 0;
        } else {
          startTime = selected;
          currentStep = 2;
        }
      } else if (currentStep == 2) {
        final TimeOfDay? selected = await showTimePicker(
          context: context,
          initialTime: endTime,
          helpText: 'Select End Time',
          cancelText: 'BACK',
          confirmText: 'SAVE',
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                alwaysUse24HourFormat: use24Hour,
              ),
              child: child!,
            );
          },
        );
        if (selected == null) {
          currentStep = 1;
        } else {
          endTime = selected;
          currentStep = 3;
        }
      }
    }

    if (dateRange == null) return null;

    final resolvedStart = DateTime(
      dateRange.start.year,
      dateRange.start.month,
      dateRange.start.day,
      startTime.hour,
      startTime.minute,
    );

    final resolvedEnd = DateTime(
      dateRange.end.year,
      dateRange.end.month,
      dateRange.end.day,
      endTime.hour,
      endTime.minute,
    );

    return {
      'start': resolvedStart,
      'end': resolvedEnd,
    };
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final day = dt.day.toString();
    final year = dt.year.toString();

    final use24Hour = Provider.of<AuthProvider>(context, listen: false).timeFormat == '24h';
    if (use24Hour) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$month $day, $year - $hour:$minute';
    } else {
      final isPm = dt.hour >= 12;
      final displayHour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final hour = displayHour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = isPm ? 'PM' : 'AM';
      return '$month $day, $year - $hour:$minute $period';
    }
  }

  Widget _buildDateRangeTile({
    required String title,
    required DateTime start,
    required DateTime end,
    required bool enabled,
    required Function(DateTime start, DateTime end) onSelected,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled
            ? () async {
                final result = await _selectDateTimeRange(
                  initialStart: start,
                  initialEnd: end,
                );
                if (result != null) {
                  onSelected(result['start']!, result['end']!);
                }
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.date_range_outlined, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (enabled)
                    Icon(Icons.edit_outlined, color: theme.colorScheme.onSurfaceVariant, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FROM',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(start),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_outlined,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TO',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(end),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, ThemeData theme, String status) {
    String text = status.toUpperCase();
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color textCol = theme.colorScheme.onSurfaceVariant;
    final normalized = status.toLowerCase();
    final isDark = theme.brightness == Brightness.dark;

    if (normalized == 'draft') {
      text = 'DRAFT';
      bg = theme.colorScheme.surfaceContainerHighest;
      textCol = theme.colorScheme.onSurfaceVariant;
    } else if (normalized == 'published') {
      text = 'PUBLISHED';
      bg = theme.colorScheme.secondaryContainer;
      textCol = theme.colorScheme.onSecondaryContainer;
    } else if (normalized == 'registration started') {
      text = 'REGISTRATION OPEN';
      bg = isDark ? const Color(0xFF1B5E20).withOpacity(0.3) : const Color(0xFFE8F5E9);
      textCol = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    } else if (normalized == 'registration closed' || normalized == 'registration completed') {
      text = 'REGISTRATION CLOSED';
      bg = theme.colorScheme.surfaceContainerHighest;
      textCol = theme.colorScheme.onSurfaceVariant;
    } else if (normalized == 'payment started') {
      text = 'PAYMENT OPEN';
      bg = isDark ? const Color(0xFF1B5E20).withOpacity(0.3) : const Color(0xFFE8F5E9);
      textCol = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    } else if (normalized == 'payment completed') {
      text = 'PAYMENT COMPLETED';
      bg = theme.colorScheme.surfaceContainerHighest;
      textCol = theme.colorScheme.onSurfaceVariant;
    } else if (normalized == 'competition started') {
      text = 'ONGOING';
      bg = isDark ? const Color(0xFF1B5E20).withOpacity(0.3) : const Color(0xFFE8F5E9);
      textCol = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    } else if (normalized == 'competition completed' || normalized == 'completed') {
      text = 'COMPLETED';
      bg = theme.colorScheme.surfaceContainerHighest;
      textCol = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textCol,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class ChevronClipper extends CustomClipper<Path> {
  final bool isFirst;
  final bool isLast;
  final double indent;

  ChevronClipper({
    required this.isFirst,
    required this.isLast,
    required this.indent,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final h = size.height;
    final w = size.width;
    final r = h / 2;

    if (isFirst) {
      path.moveTo(r, 0);
      path.arcToPoint(Offset(r, h), radius: Radius.circular(r), clockwise: false);
    } else {
      path.moveTo(0, 0);
      path.lineTo(indent, h / 2);
      path.lineTo(0, h);
    }

    if (isLast) {
      path.lineTo(w - r, h);
      path.arcToPoint(Offset(w - r, 0), radius: Radius.circular(r), clockwise: false);
    } else {
      path.lineTo(w - indent, h);
      path.lineTo(w, h / 2);
      path.lineTo(w - indent, 0);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant ChevronClipper oldClipper) {
    return oldClipper.isFirst != isFirst ||
        oldClipper.isLast != isLast ||
        oldClipper.indent != indent;
  }
}

class ChevronBorderPainter extends CustomPainter {
  final bool isFirst;
  final bool isLast;
  final double indent;
  final Color borderColor;
  final double strokeWidth;

  ChevronBorderPainter({
    required this.isFirst,
    required this.isLast,
    required this.indent,
    required this.borderColor,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final h = size.height;
    final w = size.width;
    final r = h / 2;

    if (isFirst) {
      path.moveTo(r, 0);
      path.arcToPoint(Offset(r, h), radius: Radius.circular(r), clockwise: false);
    } else {
      path.moveTo(0, 0);
      path.lineTo(indent, h / 2);
      path.lineTo(0, h);
    }

    if (isLast) {
      path.lineTo(w - r, h);
      path.arcToPoint(Offset(w - r, 0), radius: Radius.circular(r), clockwise: false);
    } else {
      path.lineTo(w - indent, h);
      path.lineTo(w, h / 2);
      path.lineTo(w - indent, 0);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ChevronBorderPainter oldDelegate) {
    return oldDelegate.isFirst != isFirst ||
        oldDelegate.isLast != isLast ||
        oldDelegate.indent != indent ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
