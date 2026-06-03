import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import '../models/association.dart';
import '../models/admin_config.dart';
import '../utils/mock_safety.dart';
import '../utils/uuid_helper.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../repositories/profile_repository.dart';
import '../widgets/verified_location_badge.dart';
import 'association/dialogs/sport_config_dialog.dart';

class AssociationCreationPage extends StatefulWidget {
  const AssociationCreationPage({super.key});

  @override
  State<AssociationCreationPage> createState() => _AssociationCreationPageState();
}

class _AssociationCreationPageState extends State<AssociationCreationPage> {
  int _currentStep = 0;
  final int _totalSteps = 5;

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();
  final _formKey4 = GlobalKey<FormState>();
  final _formKey5 = GlobalKey<FormState>();

  // Form Fields - Step 1: Metadata
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _profilePictureUrlController = TextEditingController();
  final TextEditingController _bannerUrlController = TextEditingController();

  String _scope = 'local'; // 'global', 'continental', 'national', 'local'

  // Location fields based on scope
  final TextEditingController _areaNameController = TextEditingController(); // Continental
  final TextEditingController _countryController = TextEditingController(); // National, Local
  final TextEditingController _cityController = TextEditingController(); // Local
  final TextEditingController _zipController = TextEditingController(); // Local

  bool _isLocationVerified = false;
  bool _isVerifyingLocation = false;
  String _activeLocationField = '';
  List<String> _locationSuggestions = [];
  Timer? _debounce;

  // Form Fields - Step 4: Sports & Formats Config
  String _activeSportType = 'Streetlifting';
  List<String> _activeFormats = [];
  final TextEditingController _activeRulebookController = TextEditingController();
  final Map<String, List<String>> _selectedSportsFormats = {};

  // Upload state variables
  bool _isUploadingLogo = false;
  Uint8List? _logoBytes;
  String? _logoFileName;

  bool _isUploadingBanner = false;
  Uint8List? _bannerBytes;
  String? _bannerFileName;

  // Rulebooks mapping
  final Map<String, TextEditingController> _rulebookControllers = {};

  // Form Fields - Step 5: Channels (Website & Social Media)
  final TextEditingController _websiteController = TextEditingController();
  final Map<String, TextEditingController> _socialControllers = {
    'Instagram': TextEditingController(),
    'YouTube': TextEditingController(),
    'Facebook': TextEditingController(),
    'Twitch': TextEditingController(),
    'Twitter/X': TextEditingController(),
    'TikTok': TextEditingController(),
  };

  bool _isSaving = false;
  late ProfileRepository _profileRepository;
  bool _isSubmitted = false;

  List<Association> _eligibleAssociations = [];
  String? _selectedParentAssociationId;

  // Mock suggestions dictionary
  final Map<String, List<String>> _mockSuggestions = {
    'country': ['Germany', 'Austria', 'Switzerland', 'France', 'United States', 'United Kingdom', 'Canada', 'Spain', 'Italy'],
    'city': ['Hamburg', 'Berlin', 'Munich', 'Frankfurt', 'Vienna', 'Paris', 'London', 'New York', 'Tokyo'],
    'zip': ['22529', '10115', '80331', '60311', '1010', '75001', 'SW1A 1AA'],
    'area': ['Europe', 'Asia', 'North America', 'South America', 'Africa', 'Oceania'],
  };

  @override
  void initState() {
    super.initState();
    _activeSportType = 'Streetlifting';
    _activeFormats = [];
    _activeRulebookController.text = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadEligibleAssociations();
      }
    });
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
        final hasAccess = members.any((m) => m.userId == currentUserId && (m.role == 'partner' || m.role == 'owner' || m.role == 'editor'));
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profileRepository = Provider.of<CompetitionProvider>(context, listen: false).profileRepository;
  }

  @override
  void dispose() {
    if (!_isSubmitted) {
      final logoUrl = _profilePictureUrlController.text.trim();
      final bannerUrl = _bannerUrlController.text.trim();
      if (logoUrl.isNotEmpty) {
        _profileRepository.deleteFile(logoUrl);
      }
      if (bannerUrl.isNotEmpty) {
        _profileRepository.deleteFile(bannerUrl);
      }
    }
    _nameController.dispose();
    _debounce?.cancel();
    _descController.dispose();
    _profilePictureUrlController.dispose();
    _bannerUrlController.dispose();
    _areaNameController.dispose();
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
    super.dispose();
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
    if (_debounce?.isActive ?? false) _debounce!.cancel();

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
    });
  }

  // Custom Dropdown Builder styled after Search Scope dropdown
  Widget _buildCustomDropdownField<T>({
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

  void _applyParentAssociationSportsAndRulebooks() {
    if (_selectedParentAssociationId == null) return;
    
    final parent = _eligibleAssociations.firstWhere(
      (a) => a.id == _selectedParentAssociationId,
      orElse: () => _eligibleAssociations.first,
    );
    
    final provider = Provider.of<CompetitionProvider>(context, listen: false);
    final sportConfig = provider.sportConfig;

    setState(() {
      for (final sport in parent.supportedSports) {
        List<String> formatsToApply = [];
        if (sportConfig != null) {
          final sportFormats = sportConfig.formats
              .where((f) => f.sportName == sport)
              .map((f) => f.name)
              .toList();
          formatsToApply = parent.supportedFormats
              .where((f) => sportFormats.contains(f))
              .toList();
        }
        
        if (formatsToApply.isEmpty && parent.supportedFormats.isNotEmpty) {
          final List<String> validFormatsForSport = sportConfig?.formats
                  .where((f) => f.sportName == sport)
                  .map((f) => f.name)
                  .toList() ??
              (sport == 'Streetlifting' ? ['Classic', 'Multilift'] : ['Modern', 'Classic']);
          formatsToApply = parent.supportedFormats
              .where((fmt) => validFormatsForSport.contains(fmt))
              .toList();
          
          if (formatsToApply.isEmpty) {
            formatsToApply = List<String>.from(validFormatsForSport);
          }
        }
        
        _selectedSportsFormats[sport] = formatsToApply;
        
        final rulebookUrl = parent.rulebooks[sport] ?? '';
        final oldController = _rulebookControllers[sport];
        _rulebookControllers[sport] = TextEditingController(text: rulebookUrl);
        oldController?.dispose();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied sports and rulebooks from "${parent.name}"!'),
        backgroundColor: Colors.green,
      ),
    );
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

  Future<void> _submitAssociation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);

    if (authProvider.currentUserProfile == null) return;

    setState(() {
      _isSaving = true;
    });

    final name = _nameController.text.trim();
    final description = _descController.text.trim();

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

    final newAssoc = Association(
      id: UuidHelper.generateUuidV4(),
      name: name,
      scope: _scope,
      areaName: areaName,
      country: country,
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      description: description,
      rulebooks: rulebooks,
      socialChannels: social,
      status: 'approved', // Auto-approved
      ownerId: authProvider.currentUserProfile!.id,
      supportedSports: supportedSports,
      supportedFormats: supportedFormats,
      profilePictureUrl: _profilePictureUrlController.text.trim().isEmpty ? null : _profilePictureUrlController.text.trim(),
      bannerUrl: _bannerUrlController.text.trim().isEmpty ? null : _bannerUrlController.text.trim(),
      parentAssociationId: _selectedParentAssociationId,
    );

    try {
      final result = await compProvider.createAssociation(newAssoc);
      if (result != null) {
        await compProvider.addAssociationMember(
          result.id,
          authProvider.currentUserProfile!.id,
          'owner',
        );
        _isSubmitted = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Association created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to create association');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating association: $e'),
          backgroundColor: Colors.red,
        ),
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
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (!authProvider.isAssociationCreator && !authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text(
            'Only authorized Association Creators can access this wizard.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create Association')),
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
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: _buildCurrentStepContent(theme),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildStepperActions(theme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStepperProgress(ThemeData theme) {
    final progress = _currentStep / (_totalSteps - 1);
    String stepTitle = '';
    switch (_currentStep) {
      case 0:
        stepTitle = 'General Informations';
        break;
      case 1:
        stepTitle = 'Association Scope';
        break;
      case 2:
        stepTitle = 'Media Assets';
        break;
      case 3:
        stepTitle = 'Sports & Rulebooks';
        break;
      case 4:
        stepTitle = 'Social & Channels';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Step ${_currentStep + 1} of $_totalSteps',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).toInt()}% Completed',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent(ThemeData theme) {
    switch (_currentStep) {
      case 0:
        return _buildStep1GeneralInfo(theme);
      case 1:
        return _buildStep2ScopeLocation(theme);
      case 2:
        return _buildStep3MediaAssets(theme);
      case 3:
        return _buildStep4SportsRules(theme);
      case 4:
        return _buildStep5SocialChannels(theme);
      default:
        return Container();
    }
  }

  void _onActiveSportTypeChanged(String val) {
    setState(() {
      _activeSportType = val;
      _activeFormats = List<String>.from(_selectedSportsFormats[val] ?? []);
      _activeRulebookController.text = _rulebookControllers[val]?.text ?? '';
    });
  }

  Widget _buildStep1GeneralInfo(ThemeData theme) {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('General Informations', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Association Name *',
              hintText: 'e.g. FinalRep',
              prefixIcon: Icon(Icons.business_outlined),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter the association name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description / Bio',
              hintText: 'Tell athletes about this association...',
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2ScopeLocation(ThemeData theme) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Association Scope', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildCustomDropdownField<String>(
            labelText: 'Scope',
            value: _scope,
            prefixIcon: Icon(Icons.map_outlined, color: theme.colorScheme.primary, size: 20),
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
            onChanged: (val) {
              setState(() {
                _scope = val;
                _isLocationVerified = false; // Re-verify on scope change
              });
            },
          ),
          const SizedBox(height: 16),
          // Scope-based location fields
          if (_scope == 'continental') ...[
            TextFormField(
              controller: _areaNameController,
              decoration: const InputDecoration(
                labelText: 'Continent / Regional Area *',
                hintText: 'e.g. Europe, Asia, North America',
                prefixIcon: Icon(Icons.language),
              ),
              onChanged: (val) => _updateLocationSuggestions('area', val),
              validator: (val) => _scope == 'continental' && (val == null || val.trim().isEmpty) ? 'Area name is required' : null,
            ),
            if (_activeLocationField == 'area' && _locationSuggestions.isNotEmpty)
              _buildSuggestionsList(_areaNameController),
          ],
          if (_scope == 'national') ...[
            TextFormField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'Country *',
                hintText: 'e.g. Germany',
                prefixIcon: Icon(Icons.public),
              ),
              onChanged: (val) => _updateLocationSuggestions('country', val),
              validator: (val) => _scope == 'national' && (val == null || val.trim().isEmpty) ? 'Country is required' : null,
            ),
            if (_activeLocationField == 'country' && _locationSuggestions.isNotEmpty)
              _buildSuggestionsList(_countryController),
          ],
          if (_scope == 'local') ...[
            TextFormField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'Country *',
                hintText: 'e.g. Germany',
                prefixIcon: Icon(Icons.public),
              ),
              onChanged: (val) => _updateLocationSuggestions('country', val),
              validator: (val) => _scope == 'local' && (val == null || val.trim().isEmpty) ? 'Country is required' : null,
            ),
            if (_activeLocationField == 'country' && _locationSuggestions.isNotEmpty)
              _buildSuggestionsList(_countryController),
            const SizedBox(height: 16),
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _zipController,
                            decoration: const InputDecoration(
                              labelText: 'ZIP Code *',
                              hintText: 'e.g. 22529',
                              prefixIcon: Icon(Icons.pin_drop_outlined),
                            ),
                            onChanged: (val) => _updateLocationSuggestions('zip', val),
                            validator: (val) => _scope == 'local' && (val == null || val.trim().isEmpty) ? 'ZIP Code is required' : null,
                          ),
                          if (_activeLocationField == 'zip' && _locationSuggestions.isNotEmpty)
                            _buildSuggestionsList(_zipController),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'City *',
                              hintText: 'e.g. Hamburg',
                              prefixIcon: Icon(Icons.location_city),
                            ),
                            onChanged: (val) => _updateLocationSuggestions('city', val),
                            validator: (val) => _scope == 'local' && (val == null || val.trim().isEmpty) ? 'City is required' : null,
                          ),
                          if (_activeLocationField == 'city' && _locationSuggestions.isNotEmpty)
                            _buildSuggestionsList(_cityController),
                        ],
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _zipController,
                              decoration: const InputDecoration(
                                labelText: 'ZIP Code *',
                                hintText: 'e.g. 22529',
                                prefixIcon: Icon(Icons.pin_drop_outlined),
                              ),
                              onChanged: (val) => _updateLocationSuggestions('zip', val),
                              validator: (val) => _scope == 'local' && (val == null || val.trim().isEmpty) ? 'ZIP Code is required' : null,
                            ),
                            if (_activeLocationField == 'zip' && _locationSuggestions.isNotEmpty)
                              _buildSuggestionsList(_zipController),
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
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'City *',
                                hintText: 'e.g. Hamburg',
                                prefixIcon: Icon(Icons.location_city),
                              ),
                              onChanged: (val) => _updateLocationSuggestions('city', val),
                              validator: (val) => _scope == 'local' && (val == null || val.trim().isEmpty) ? 'City is required' : null,
                            ),
                            if (_activeLocationField == 'city' && _locationSuggestions.isNotEmpty)
                              _buildSuggestionsList(_cityController),
                          ],
                        ),
                      ),
                    ],
                  ),
          ],

          const SizedBox(height: 16),
          _buildCustomDropdownField<String?>(
            labelText: 'Parent Association',
            value: _selectedParentAssociationId,
            displayValue: (val) {
              if (val == null) return 'None';
              final found = _eligibleAssociations.firstWhere((a) => a.id == val, orElse: () => _eligibleAssociations.first);
              return found.name;
            },
            prefixIcon: const Icon(Icons.business_outlined),
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
                _selectedParentAssociationId = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep3MediaAssets(ThemeData theme) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Form(
      key: _formKey3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Media Assets', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // Logo Upload
          Text('Logo / Profile Image', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recommended Size: 500 x 500 px (1:1 Aspect Ratio)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isUploadingLogo ? null : _pickLogoImage,
                            icon: _isUploadingLogo
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
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                _logoFileName != null ? Icons.check_circle : Icons.insert_drive_file_outlined,
                                size: 18,
                                color: _logoFileName != null ? Colors.green : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _logoFileName ?? 'No image selected',
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: _logoFileName != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: _logoFileName != null ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isUploadingLogo ? null : _pickLogoImage,
                            icon: _isUploadingLogo
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
                          const SizedBox(width: 16),
                          Icon(
                            _logoFileName != null ? Icons.check_circle : Icons.insert_drive_file_outlined,
                            size: 18,
                            color: _logoFileName != null ? Colors.green : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _logoFileName ?? 'No image selected',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _logoFileName != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                                fontWeight: _logoFileName != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                if (_logoBytes != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _logoBytes!,
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Banner Upload
          Text('Banner Image', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recommended Size: 1200 x 400 px (3:1 Aspect Ratio)\nSafe-zone: Keep critical content in central 800 x 300 px.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isUploadingBanner ? null : _pickBannerImage,
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
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                _bannerFileName != null ? Icons.check_circle : Icons.insert_drive_file_outlined,
                                size: 18,
                                color: _bannerFileName != null ? Colors.green : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _bannerFileName ?? 'No image selected',
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: _bannerFileName != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: _bannerFileName != null ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isUploadingBanner ? null : _pickBannerImage,
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
                          const SizedBox(width: 16),
                          Icon(
                            _bannerFileName != null ? Icons.check_circle : Icons.insert_drive_file_outlined,
                            size: 18,
                            color: _bannerFileName != null ? Colors.green : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _bannerFileName ?? 'No image selected',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _bannerFileName != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                                fontWeight: _bannerFileName != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                if (_bannerBytes != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _bannerBytes!,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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

  Widget _buildStep4SportsRules(ThemeData theme) {
    final provider = Provider.of<CompetitionProvider>(context);
    final sportConfig = provider.sportConfig;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Collect all disciplines for configured sports and formats grouped
    final Map<String, List<String>> disciplinesBySportAndFormat = {};
    _selectedSportsFormats.forEach((sport, formatsList) {
      for (var fmt in formatsList) {
        final linked = sportConfig?.links
                .where((link) => link.sportName == sport && link.formatName == fmt)
                .map((link) => link.disciplineName)
                .toList() ??
            [];
        final discs = linked.isNotEmpty
            ? linked
            : (sport == 'Streetlifting'
                ? (fmt == 'Classic'
                    ? ['Pull-up', 'Dip']
                    : ['Squat', 'Pull-up', 'Dip', 'Deadlift'])
                : <String>[]);
        if (discs.isNotEmpty) {
          disciplinesBySportAndFormat['$sport - $fmt'] = discs;
        }
      }
    });

    return Form(
      key: _formKey4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Sports & Rulebooks', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showSportConfigurationModal(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Sport'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE94E1B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sports & Rulebooks', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: () => _showSportConfigurationModal(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Sport'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE94E1B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
          if (_selectedParentAssociationId != null) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final parentName = _eligibleAssociations.isEmpty
                    ? 'Parent'
                    : _eligibleAssociations.firstWhere(
                        (a) => a.id == _selectedParentAssociationId,
                        orElse: () => _eligibleAssociations.first,
                      ).name;
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _applyParentAssociationSportsAndRulebooks,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE94E1B),
                      side: const BorderSide(color: Color(0xFFE94E1B), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.copy_all),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Apply Sports & Rulebook of $parentName',
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            ),
          ],
          const SizedBox(height: 20),
          if (_selectedSportsFormats.isNotEmpty) ...[
            Text('Configured Sports & Formats:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedSportsFormats.length,
              itemBuilder: (context, idx) {
                final sport = _selectedSportsFormats.keys.elementAt(idx);
                final fmts = _selectedSportsFormats[sport]!;
                final rulebookUrl = _rulebookControllers[sport]?.text.trim() ?? '';
                
                return Card(
                  key: ValueKey('sport_card_$sport'),
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              sport,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                                  onPressed: () => _showSportConfigurationModal(editSportType: sport),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                  onPressed: () {
                                    setState(() {
                                      _selectedSportsFormats.remove(sport);
                                      final controller = _rulebookControllers.remove(sport);
                                      controller?.dispose();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Formats',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: fmts.map((fmt) {
                            final key = '$sport - $fmt';
                            final discs = disciplinesBySportAndFormat[key] ?? <String>[];
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              color: theme.colorScheme.surfaceContainerLow.withOpacity(0.5),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fmt,
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    if (discs.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: discs.map((d) => Chip(
                                          label: Text(d, style: const TextStyle(fontSize: 10)),
                                          backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.25),
                                          visualDensity: VisualDensity.compact,
                                        )).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Rulebooks',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (rulebookUrl.isNotEmpty)
                          Text(
                            rulebookUrl,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                          )
                        else
                          Text(
                            'No rulebook set.',
                            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Text(
                  'No sports configured. Click "Add Sport" above to add one.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ],
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
        appliedSharedResources: const <String, dynamic>{},
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

  Widget _buildStep5SocialChannels(ThemeData theme) {
    return Form(
      key: _formKey5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Social & Digital Channels', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _websiteController,
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
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text('Social Media Handles / URLs', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextFormField(
                  controller: controller,
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
    );
  }

  Widget _buildStepperActions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentStep--;
                  _locationSuggestions = [];
                });
              },
              child: const Text('BACK'),
            )
          else
            const SizedBox(),
          ElevatedButton(
            onPressed: _isVerifyingLocation
                ? null
                : () async {
                    if (_currentStep == 0) {
                      if (_formKey1.currentState!.validate()) {
                        setState(() {
                          _currentStep++;
                        });
                      }
                    } else if (_currentStep == 1) {
                      if (_formKey2.currentState!.validate()) {
                        if (_scope != 'global' && !_isLocationVerified) {
                          await _verifyLocation();
                        }
                        if (_scope == 'global' || _isLocationVerified) {
                          setState(() {
                            _currentStep++;
                            _locationSuggestions = [];
                          });
                        }
                      }
                    } else if (_currentStep == 2) {
                      if (_formKey3.currentState!.validate()) {
                        setState(() {
                          _currentStep++;
                        });
                      }
                    } else if (_currentStep == 3) {
                      if (_formKey4.currentState!.validate()) {
                        if (_selectedSportsFormats.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please configure and add at least one sport to proceed.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        setState(() {
                          _currentStep++;
                        });
                      }
                    } else {
                      if (_formKey5.currentState!.validate()) {
                        _submitAssociation();
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE94E1B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _isVerifyingLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _currentStep == _totalSteps - 1 ? 'SUBMIT' : 'NEXT',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}

