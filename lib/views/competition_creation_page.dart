import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import '../models/competition.dart';
import '../models/association.dart';
import '../models/athlete_group.dart';
import '../models/competition_group.dart';
import '../utils/mock_safety.dart';
import '../utils/uuid_helper.dart';
import '../repositories/profile_repository.dart';
import '../widgets/verified_location_badge.dart';

const List<Map<String, String>> _allCurrencies = [
  {'code': 'AED', 'name': 'United Arab Emirates Dirham', 'symbol': 'د.إ'},
  {'code': 'AFN', 'name': 'Afghan Afghani', 'symbol': '؋'},
  {'code': 'ALL', 'name': 'Albanian Lek', 'symbol': 'L'},
  {'code': 'AMD', 'name': 'Armenian Dram', 'symbol': '֏'},
  {'code': 'ANG', 'name': 'Netherlands Antillean Guilder', 'symbol': 'ƒ'},
  {'code': 'AOA', 'name': 'Angolan Kwanza', 'symbol': 'Kz'},
  {'code': 'ARS', 'name': 'Argentine Peso', 'symbol': '\$'},
  {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$'},
  {'code': 'AWG', 'name': 'Aruban Florin', 'symbol': 'Afl.'},
  {'code': 'AZN', 'name': 'Azerbaijani Manat', 'symbol': '₼'},
  {'code': 'BAM', 'name': 'Bosnia-Herzegovina Convertible Mark', 'symbol': 'KM'},
  {'code': 'BBD', 'name': 'Barbadian Dollar', 'symbol': 'Bds\$'},
  {'code': 'BDT', 'name': 'Bangladeshi Taka', 'symbol': '৳'},
  {'code': 'BGN', 'name': 'Bulgarian Lev', 'symbol': 'лв'},
  {'code': 'BHD', 'name': 'Bahraini Dinar', 'symbol': '.د.ب'},
  {'code': 'BIF', 'name': 'Burundian Franc', 'symbol': 'FBu'},
  {'code': 'BMD', 'name': 'Bermudian Dollar', 'symbol': 'BD\$'},
  {'code': 'BND', 'name': 'Brunei Dollar', 'symbol': 'B\$'},
  {'code': 'BOB', 'name': 'Bolivian Boliviano', 'symbol': 'Bs.'},
  {'code': 'BRL', 'name': 'Brazilian Real', 'symbol': 'R\$'},
  {'code': 'BSD', 'name': 'Bahamian Dollar', 'symbol': 'B\$'},
  {'code': 'BTN', 'name': 'Bhutanese Ngultrum', 'symbol': 'Nu.'},
  {'code': 'BWP', 'name': 'Botswanan Pula', 'symbol': 'P'},
  {'code': 'BYN', 'name': 'Belarusian Ruble', 'symbol': 'Br'},
  {'code': 'BZD', 'name': 'Belize Dollar', 'symbol': 'BZ\$'},
  {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'C\$'},
  {'code': 'CDF', 'name': 'Congolese Franc', 'symbol': 'FC'},
  {'code': 'CHF', 'name': 'Swiss Franc', 'symbol': 'CHF'},
  {'code': 'CLP', 'name': 'Chilean Peso', 'symbol': '\$'},
  {'code': 'CNY', 'name': 'Chinese Yuan', 'symbol': '¥'},
  {'code': 'COP', 'name': 'Colombian Peso', 'symbol': '\$'},
  {'code': 'CRC', 'name': 'Costa Rican Colón', 'symbol': '₡'},
  {'code': 'CUP', 'name': 'Cuban Peso', 'symbol': '\$'},
  {'code': 'CVE', 'name': 'Cape Verdean Escudo', 'symbol': 'Esc'},
  {'code': 'CZK', 'name': 'Czech Koruna', 'symbol': 'Kč'},
  {'code': 'DJF', 'name': 'Djiboutian Franc', 'symbol': 'Fdj'},
  {'code': 'DKK', 'name': 'Danish Krone', 'symbol': 'kr.'},
  {'code': 'DOP', 'name': 'Dominican Peso', 'symbol': 'RD\$'},
  {'code': 'DZD', 'name': 'Algerian Dinar', 'symbol': 'د.ج'},
  {'code': 'EGP', 'name': 'Egyptian Pound', 'symbol': 'E£'},
  {'code': 'ERN', 'name': 'Eritrean Nakfa', 'symbol': 'Nkf'},
  {'code': 'ETB', 'name': 'Ethiopian Birr', 'symbol': 'Br'},
  {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
  {'code': 'FJD', 'name': 'Fijian Dollar', 'symbol': 'FJ\$'},
  {'code': 'FKP', 'name': 'Falkland Islands Pound', 'symbol': '£'},
  {'code': 'GBP', 'name': 'British Pound Sterling', 'symbol': '£'},
  {'code': 'GEL', 'name': 'Georgian Lari', 'symbol': '₾'},
  {'code': 'GHS', 'name': 'Ghanaian Cedi', 'symbol': '₵'},
  {'code': 'GIP', 'name': 'Gibraltar Pound', 'symbol': '£'},
  {'code': 'GMD', 'name': 'Gambian Dalasi', 'symbol': 'D'},
  {'code': 'GNF', 'name': 'Guinean Franc', 'symbol': 'FG'},
  {'code': 'GTQ', 'name': 'Guatemalan Quetzal', 'symbol': 'Q'},
  {'code': 'GYD', 'name': 'Guyanese Dollar', 'symbol': 'GY\$'},
  {'code': 'HKD', 'name': 'Hong Kong Dollar', 'symbol': 'HK\$'},
  {'code': 'HNL', 'name': 'Honduran Lempira', 'symbol': 'L'},
  {'code': 'HRK', 'name': 'Croatian Kuna', 'symbol': 'kn'},
  {'code': 'HTG', 'name': 'Haitian Gourde', 'symbol': 'G'},
  {'code': 'HUF', 'name': 'Hungarian Forint', 'symbol': 'Ft'},
  {'code': 'IDR', 'name': 'Indonesian Rupiah', 'symbol': 'Rp'},
  {'code': 'ILS', 'name': 'Israeli New Shekel', 'symbol': '₪'},
  {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
  {'code': 'IQD', 'name': 'Iraqi Dinar', 'symbol': 'ع.د'},
  {'code': 'IRR', 'name': 'Iranian Rial', 'symbol': '﷼'},
  {'code': 'ISK', 'name': 'Icelandic Króna', 'symbol': 'kr'},
  {'code': 'JMD', 'name': 'Jamaican Dollar', 'symbol': 'J\$'},
  {'code': 'JOD', 'name': 'Jordanian Dinar', 'symbol': 'د.ا'},
  {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
  {'code': 'KES', 'name': 'Kenyan Shilling', 'symbol': 'KSh'},
  {'code': 'KGS', 'name': 'Kyrgystani Som', 'symbol': 'сом'},
  {'code': 'KHR', 'name': 'Cambodian Riel', 'symbol': '៛'},
  {'code': 'KMF', 'name': 'Comorian Franc', 'symbol': 'CF'},
  {'code': 'KPW', 'name': 'North Korean Won', 'symbol': '₩'},
  {'code': 'KRW', 'name': 'South Korean Won', 'symbol': '₩'},
  {'code': 'KWD', 'name': 'Kuwaiti Dinar', 'symbol': 'د.ك'},
  {'code': 'KYD', 'name': 'Cayman Islands Dollar', 'symbol': 'CI\$'},
  {'code': 'KZT', 'name': 'Kazakhstani Tenge', 'symbol': '₸'},
  {'code': 'LAK', 'name': 'Laotian Kip', 'symbol': '₭'},
  {'code': 'LBP', 'name': 'Lebanese Pound', 'symbol': 'L£'},
  {'code': 'LKR', 'name': 'Sri Lankan Rupee', 'symbol': 'Rs'},
  {'code': 'LRD', 'name': 'Liberian Dollar', 'symbol': 'LD\$'},
  {'code': 'LSL', 'name': 'Lesotho Loti', 'symbol': 'M'},
  {'code': 'LYD', 'name': 'Libyan Dinar', 'symbol': 'د.ل'},
  {'code': 'MAD', 'name': 'Moroccan Dirham', 'symbol': 'د.م.'},
  {'code': 'MDL', 'name': 'Moldovan Leu', 'symbol': 'L'},
  {'code': 'MGA', 'name': 'Malagasy Ariary', 'symbol': 'Ar'},
  {'code': 'MKD', 'name': 'Macedonian Denar', 'symbol': 'ден'},
  {'code': 'MMK', 'name': 'Myanmar Kyat', 'symbol': 'K'},
  {'code': 'MNT', 'name': 'Mongolian Tugrik', 'symbol': '₮'},
  {'code': 'MOP', 'name': 'Macanese Pataca', 'symbol': 'MOP\$'},
  {'code': 'MRU', 'name': 'Mauritanian Ouguiya', 'symbol': 'UM'},
  {'code': 'MUR', 'name': 'Mauritian Rupee', 'symbol': '₨'},
  {'code': 'MVR', 'name': 'Maldivian Rufiyaa', 'symbol': 'Rf'},
  {'code': 'MWK', 'name': 'Malawian Kwacha', 'symbol': 'MK'},
  {'code': 'MXN', 'name': 'Mexican Peso', 'symbol': '\$'},
  {'code': 'MYR', 'name': 'Malaysian Ringgit', 'symbol': 'RM'},
  {'code': 'MZN', 'name': 'Mozambican Metical', 'symbol': 'MT'},
  {'code': 'NAD', 'name': 'Namibian Dollar', 'symbol': 'N\$'},
  {'code': 'NGN', 'name': 'Nigerian Naira', 'symbol': '₦'},
  {'code': 'NIO', 'name': 'Nicaraguan Córdoba', 'symbol': 'C\$'},
  {'code': 'NOK', 'name': 'Norwegian Krone', 'symbol': 'kr'},
  {'code': 'NPR', 'name': 'Nepalese Rupee', 'symbol': '₨'},
  {'code': 'NZD', 'name': 'New Zealand Dollar', 'symbol': 'NZ\$'},
  {'code': 'OMR', 'name': 'Omani Rial', 'symbol': 'ر.ع.'},
  {'code': 'PAB', 'name': 'Panamanian Balboa', 'symbol': 'B/.'},
  {'code': 'PEN', 'name': 'Peruvian Sol', 'symbol': 'S/.'},
  {'code': 'PGK', 'name': 'Papua New Guinean Kina', 'symbol': 'K'},
  {'code': 'PHP', 'name': 'Philippine Peso', 'symbol': '₱'},
  {'code': 'PKR', 'name': 'Pakistani Rupee', 'symbol': '₨'},
  {'code': 'PLN', 'name': 'Polish Złoty', 'symbol': 'zł'},
  {'code': 'PYG', 'name': 'Paraguayan Guarani', 'symbol': '₲'},
  {'code': 'QAR', 'name': 'Qatari Rial', 'symbol': 'ر.ق'},
  {'code': 'RON', 'name': 'Romanian Leu', 'symbol': 'lei'},
  {'code': 'RSD', 'name': 'Serbian Dinar', 'symbol': 'дин.'},
  {'code': 'RUB', 'name': 'Russian Ruble', 'symbol': '₽'},
  {'code': 'RWF', 'name': 'Rwandan Franc', 'symbol': 'FRw'},
  {'code': 'SAR', 'name': 'Saudi Riyal', 'symbol': 'ر.س'},
  {'code': 'SBD', 'name': 'Solomon Islands Dollar', 'symbol': 'SI\$'},
  {'code': 'SCR', 'name': 'Seychellois Rupee', 'symbol': '₨'},
  {'code': 'SDG', 'name': 'Sudanese Pound', 'symbol': 'ج.س.'},
  {'code': 'SEK', 'name': 'Swedish Krona', 'symbol': 'kr'},
  {'code': 'SGD', 'name': 'Singapore Dollar', 'symbol': 'S\$'},
  {'code': 'SHP', 'name': 'St. Helena Pound', 'symbol': '£'},
  {'code': 'SLL', 'name': 'Sierra Leonean Leone', 'symbol': 'Le'},
  {'code': 'SOS', 'name': 'Somali Shilling', 'symbol': 'Sh.So.'},
  {'code': 'SRD', 'name': 'Surinamese Dollar', 'symbol': '\$'},
  {'code': 'SSP', 'name': 'South Sudanese Pound', 'symbol': 'SS£'},
  {'code': 'STN', 'name': 'São Tomé & Príncipe Dobra', 'symbol': 'Db'},
  {'code': 'SYP', 'name': 'Syrian Pound', 'symbol': 'LS'},
  {'code': 'SZL', 'name': 'Swazi Lilangeni', 'symbol': 'E'},
  {'code': 'THB', 'name': 'Thai Baht', 'symbol': '฿'},
  {'code': 'TJS', 'name': 'Tajikistani Somoni', 'symbol': 'ЅМ'},
  {'code': 'TMT', 'name': 'Turkmenistani Manat', 'symbol': 'T'},
  {'code': 'TND', 'name': 'Tunisian Dinar', 'symbol': 'د.ت'},
  {'code': 'TOP', 'name': 'Tongan Paʻanga', 'symbol': 'T\$'},
  {'code': 'TRY', 'name': 'Turkish Lira', 'symbol': '₺'},
  {'code': 'TTD', 'name': 'Trinidad & Tobago Dollar', 'symbol': 'TT\$'},
  {'code': 'TWD', 'name': 'New Taiwan Dollar', 'symbol': 'NT\$'},
  {'code': 'TZS', 'name': 'Tanzanian Shilling', 'symbol': 'TSh'},
  {'code': 'UAH', 'name': 'Ukrainian Hryvnia', 'symbol': '₴'},
  {'code': 'UGX', 'name': 'Ugandan Shilling', 'symbol': 'USh'},
  {'code': 'USD', 'name': 'United States Dollar', 'symbol': '\$'},
  {'code': 'UYU', 'name': 'Uruguayan Peso', 'symbol': '\$'},
  {'code': 'UZS', 'name': 'Uzbekistani Som', 'symbol': 'so\'m'},
  {'code': 'VES', 'name': 'Venezuelan Bolívar Soberano', 'symbol': 'Bs.S'},
  {'code': 'VND', 'name': 'Vietnamese Đồng', 'symbol': '₫'},
  {'code': 'VUV', 'name': 'Vanuatu Vatu', 'symbol': 'VT'},
  {'code': 'WST', 'name': 'Samoan Tala', 'symbol': 'WS\$'},
  {'code': 'XAF', 'name': 'Central African CFA Franc', 'symbol': 'FCFA'},
  {'code': 'XCD', 'name': 'East Caribbean Dollar', 'symbol': 'EC\$'},
  {'code': 'XOF', 'name': 'West African CFA Franc', 'symbol': 'CFA'},
  {'code': 'XPF', 'name': 'CFP Franc', 'symbol': '₣'},
  {'code': 'YER', 'name': 'Yemeni Rial', 'symbol': '﷼'},
  {'code': 'ZAR', 'name': 'South African Rand', 'symbol': 'R'},
  {'code': 'ZMW', 'name': 'Zambian Kwacha', 'symbol': 'ZK'},
  {'code': 'ZWL', 'name': 'Zimbabwean Dollar', 'symbol': 'Z\$'}
];

class LocalAthleteGroup {
  String name;
  String gender; // 'men', 'women', 'open'
  int? limit;

  LocalAthleteGroup({required this.name, required this.gender, this.limit});

  Map<String, dynamic> toJson() => {
        'name': name,
        'gender': gender,
        'limit': limit,
      };
}

class CompetitionCreationPage extends StatefulWidget {
  const CompetitionCreationPage({super.key});

  @override
  State<CompetitionCreationPage> createState() => _CompetitionCreationPageState();
}

class _CompetitionCreationPageState extends State<CompetitionCreationPage> {
  int _currentStep = 0;
  final int _totalSteps = 11;

  final List<GlobalKey<FormState>> _formKeys = List.generate(11, (index) => GlobalKey<FormState>());

  // Step 1: General Info
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _titleImageUrlController = TextEditingController();

  // Step 2: Competition Location
  final TextEditingController _locationController = TextEditingController();

  String _parsedCountry = '';
  String _parsedCity = '';
  String _parsedZip = '';
  String _parsedAddress = '';

  late ProfileRepository _profileRepository;
  bool _isSubmitted = false;

  bool _isLocationVerified = false;
  bool _isVerifyingLocation = false;
  String _activeLocationField = ''; // 'location'
  List<String> _locationSuggestions = [];

  // Step 3: Sport & Format
  String _sportType = 'Streetlifting';
  String _sportSubtype = 'Modern';
  String _rankingType = 'open';
  final TextEditingController _rulebookUrlController = TextEditingController();
  List<CompetitionGroup> _availableCompGroups = [];
  String? _selectedCompGroupName;

  // Step 4: Banner Upload
  Uint8List? _bannerBytes;
  String? _bannerFileName;
  bool _isUploadingBanner = false;

  // Step 5: Dates & Deadlines
  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  DateTime _endDate = DateTime.now().add(const Duration(days: 8));
  DateTime _registrationStartDate = DateTime.now();
  DateTime _registrationEndDate = DateTime.now().add(const Duration(days: 6));

  // Step 6: Registration Settings
  String _registrationMode = 'fcfs'; // 'fcfs' or 'approval'
  bool _enableWaitlist = false;
  final TextEditingController _maxAthletesController = TextEditingController();

  // Step 7: Athlete Groups
  final List<LocalAthleteGroup> _athleteGroups = [];

  // Step 8: Fees & Bank Details
  bool _requiresFees = false;
  final TextEditingController _feeAmountController = TextEditingController();
  String _feeCurrency = 'EUR';
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _bicController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();

  // Step 9: Payment Settings
  String _paymentRefType = 'auto'; // 'auto' or 'custom'
  final TextEditingController _paymentDescController = TextEditingController();
  DateTime? _paymentStartDate;
  DateTime? _paymentEndDate;

  // Step 10: Volunteer Setup
  bool _volunteerNeeds = false;
  final TextEditingController _maxVolunteersController = TextEditingController();
  final Map<String, int> _maxVolunteersPerPosition = {};

  // Step 11: Disclaimers & Custom Fields
  final List<Map<String, String>> _disclaimers = [];
  final List<Map<String, dynamic>> _customAthleteFields = [];
  final List<Map<String, dynamic>> _customVolunteerFields = [];

  bool _isSaving = false;
  bool _isLoadingParentGroups = false;

  // Mock suggestions dictionary
  final Map<String, List<String>> _mockSuggestions = {
    'country': ['Germany', 'Austria', 'Switzerland', 'France', 'United States', 'United Kingdom', 'Canada', 'Spain', 'Italy'],
    'city': ['Hamburg', 'Berlin', 'Munich', 'Frankfurt', 'Ravensburg', 'Vienna', 'Paris', 'London', 'New York', 'Tokyo'],
    'zip': ['88212', '22529', '10115', '80331', '60311', '1010', '75001', 'SW1A 1AA'],
    'address': ['Marienplatz 1', 'Rütersbarg 50', 'Alexanderplatz 1', 'Brandenburger Tor', 'Stephansplatz 1', 'Champs-Élysées 10', 'Broadway 100'],
  };

  List<Association> _eligibleAssociations = [];
  String? _selectedAssociationId;

  @override
  void initState() {
    super.initState();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profileRepository = Provider.of<CompetitionProvider>(context, listen: false).profileRepository;
  }

  @override
  void dispose() {
    if (!_isSubmitted) {
      final bannerUrl = _titleImageUrlController.text.trim();
      if (bannerUrl.isNotEmpty) {
        _profileRepository.deleteFile(bannerUrl);
      }
    }
    _titleController.dispose();
    _rulebookUrlController.dispose();
    _descController.dispose();
    _titleImageUrlController.dispose();
    _locationController.dispose();
    _maxAthletesController.dispose();
    _feeAmountController.dispose();
    _ibanController.dispose();
    _bicController.dispose();
    _bankNameController.dispose();
    _paymentDescController.dispose();
    _maxVolunteersController.dispose();
    super.dispose();
  }

  // Location suggestions logic
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
  }

  // Real-time location verification using OpenStreetMap Nominatim
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

  void _showCurrencySelectorDialog(ThemeData theme) {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _allCurrencies.where((c) {
              final query = searchQuery.toLowerCase();
              return c['code']!.toLowerCase().contains(query) ||
                  c['name']!.toLowerCase().contains(query);
            }).toList();

            return AlertDialog(
              title: const Text('Select Currency'),
              content: SizedBox(
                width: 400,
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Currency',
                        hintText: 'e.g. USD, EUR, GBP...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final c = filtered[idx];
                          return ListTile(
                            title: Text('${c['code']} (${c['symbol']})'),
                            subtitle: Text(c['name']!),
                            trailing: _feeCurrency == c['code']
                                ? Icon(Icons.check, color: theme.colorScheme.primary)
                                : null,
                            onTap: () {
                              setState(() {
                                _feeCurrency = c['code']!;
                              });
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CLOSE'),
                ),
              ],
            );
          },
        );
      },
    );
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

  // DateTime and custom preference pickers
  Future<DateTime?> _selectDateTime(BuildContext context, DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null) return null;

    if (!context.mounted) return null;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final use24Hour = authProvider.timeFormat == '24h';

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: use24Hour,
          ),
          child: child!,
        );
      },
    );
    if (time == null) return DateTime(date.year, date.month, date.day);

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // Payment description generation
  String _getGeneratedPaymentDesc() {
    final title = _titleController.text.trim().isEmpty ? '[Competition Name]' : _titleController.text.trim();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserProfile?.username ?? 'user';
    final desc = 'Entry Fee: $title - User: $user';
    return desc.length > 140 ? desc.substring(0, 140) : desc;
  }

  String? _validateDates() {
    if (_endDate.isBefore(_startDate)) {
      return 'End date must be on or after start date';
    }
    if (_registrationEndDate.isAfter(_startDate)) {
      return 'Registration end date must be on or before competition start date';
    }
    if (_registrationEndDate.isBefore(_registrationStartDate)) {
      return 'Registration end date must be on or after registration start date';
    }
    if (_requiresFees) {
      if (_paymentStartDate != null && _paymentEndDate != null) {
        if (_paymentEndDate!.isBefore(_paymentStartDate!)) {
          return 'Payment end date must be on or after payment start date';
        }
      }
    }
    return null;
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

  // Modals for Athlete Groups, Volunteer Positions, Custom Fields, Disclaimers
  void _showAthleteGroupModal({int? editIndex}) {
    final theme = Theme.of(context);
    final nameController = TextEditingController(
      text: editIndex != null ? _athleteGroups[editIndex].name : '',
    );
    final limitController = TextEditingController(
      text: editIndex != null ? (_athleteGroups[editIndex].limit?.toString() ?? '') : '',
    );
    String gender = editIndex != null ? _athleteGroups[editIndex].gender : 'men';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(editIndex == null ? 'Add Athlete Group' : 'Edit Athlete Group'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Name *',
                        hintText: 'e.g. Junior, Open, -74kg',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCustomDropdownField<String>(
                      labelText: 'Gender',
                      value: gender,
                      displayValue: (val) => val[0].toUpperCase() + val.substring(1),
                      items: const [
                        PopupMenuItem(value: 'men', child: Text('Men')),
                        PopupMenuItem(value: 'women', child: Text('Women')),
                        PopupMenuItem(value: 'open', child: Text('Open')),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          gender = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Capacity Limit',
                        hintText: 'e.g. 10 (optional)',
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
                    final limitVal = limitController.text.trim();
                    final limit = limitVal.isEmpty ? null : int.tryParse(limitVal);
                    if (name.isNotEmpty) {
                      setState(() {
                        if (editIndex != null) {
                          _athleteGroups[editIndex] = LocalAthleteGroup(
                            name: name,
                            gender: gender,
                            limit: limit,
                          );
                        } else {
                          _athleteGroups.add(LocalAthleteGroup(
                            name: name,
                            gender: gender,
                            limit: limit,
                          ));
                        }
                      });
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Group Name is required.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94E1B),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(editIndex == null ? 'ADD GROUP' : 'UPDATE GROUP'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showVolunteerPositionModal({String? editKey}) {
    final nameController = TextEditingController(
      text: editKey ?? '',
    );
    final limitController = TextEditingController(
      text: editKey != null ? (_maxVolunteersPerPosition[editKey]?.toString() ?? '') : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(editKey == null ? 'Add Volunteer Position' : 'Edit Volunteer Position'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Position Name *',
                    hintText: 'e.g. Front Judge, Loader, Commentator',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: limitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Limit',
                    hintText: 'e.g. 4 (optional)',
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
                final limitVal = limitController.text.trim();
                final limit = limitVal.isEmpty ? 0 : (int.tryParse(limitVal) ?? 0);
                if (name.isNotEmpty) {
                  setState(() {
                    if (editKey != null) {
                      _maxVolunteersPerPosition.remove(editKey);
                    }
                    _maxVolunteersPerPosition[name] = limit;
                  });
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Position Name is required.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94E1B),
                foregroundColor: Colors.white,
              ),
              child: Text(editKey == null ? 'ADD POSITION' : 'UPDATE POSITION'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomFieldModal(bool isAthlete, {int? editIndex}) {
    final fields = isAthlete ? _customAthleteFields : _customVolunteerFields;
    final nameController = TextEditingController(
      text: editIndex != null ? fields[editIndex]['name'] : '',
    );
    String fieldType = editIndex != null ? fields[editIndex]['type'] : 'text';
    final optionsController = TextEditingController(
      text: editIndex != null && fields[editIndex]['options'] != null
          ? (fields[editIndex]['options'] as List).join(', ')
          : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(editIndex == null ? 'Add Custom Field' : 'Edit Custom Field'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Field Label/Question *',
                        hintText: 'e.g. Shirt Size, Years of Experience',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCustomDropdownField<String>(
                      labelText: 'Field Type',
                      value: fieldType,
                      displayValue: (val) {
                        if (val == 'text') return 'Text Input';
                        if (val == 'boolean') return 'Checkbox';
                        if (val == 'dropdown') return 'Dropdown';
                        return val;
                      },
                      items: const [
                        PopupMenuItem(value: 'text', child: Text('Text Input')),
                        PopupMenuItem(value: 'boolean', child: Text('Checkbox')),
                        PopupMenuItem(value: 'dropdown', child: Text('Dropdown')),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          fieldType = val;
                        });
                      },
                    ),
                    if (fieldType == 'dropdown') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: optionsController,
                        decoration: const InputDecoration(
                          labelText: 'Dropdown Options (comma-separated) *',
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
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Field Label is required.')),
                      );
                      return;
                    }
                    if (fieldType == 'dropdown' && optionsController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Dropdown options are required for dropdown type.')),
                      );
                      return;
                    }

                    setState(() {
                      final Map<String, dynamic> f = {
                        'name': name,
                        'type': fieldType,
                      };
                      if (fieldType == 'dropdown') {
                        f['options'] = optionsController.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                      }

                      if (editIndex != null) {
                        fields[editIndex] = f;
                      } else {
                        fields.add(f);
                      }
                    });
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94E1B),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(editIndex == null ? 'ADD FIELD' : 'UPDATE FIELD'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDisclaimerModal({int? editIndex}) {
    final textController = TextEditingController(
      text: editIndex != null ? _disclaimers[editIndex]['text'] : '',
    );
    final urlController = TextEditingController(
      text: editIndex != null ? _disclaimers[editIndex]['url'] : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(editIndex == null ? 'Add Disclaimer' : 'Edit Disclaimer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: textController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Disclaimer Text *',
                    hintText: 'Enter terms, conditions, legal waiver...',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Disclaimer URL (Optional)',
                    hintText: 'https://example.com/terms',
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
                final text = textController.text.trim();
                final url = urlController.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Disclaimer Text is required.')),
                  );
                  return;
                }
                if (url.isNotEmpty) {
                  final uri = Uri.tryParse(url);
                  if (uri == null || !uri.hasAbsolutePath) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid URL.')),
                    );
                    return;
                  }
                }

                setState(() {
                  final Map<String, String> disc = {
                    'text': text,
                    'url': url,
                  };
                  if (editIndex != null) {
                    _disclaimers[editIndex] = disc;
                  } else {
                    _disclaimers.add(disc);
                  }
                });
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94E1B),
                foregroundColor: Colors.white,
              ),
              child: Text(editIndex == null ? 'ADD' : 'SAVE'),
            ),
          ],
        );
      },
    );
  }

  String? _getInheritedRulebookUrl(Association assoc, String sport, String format) {
    if (assoc.rulebooks[sport] != null && assoc.rulebooks[sport]!.isNotEmpty) {
      return assoc.rulebooks[sport];
    }
    final applied = assoc.appliedSharedResources;
    if (applied['rulebooks'] != null) {
      final rulebooksMap = Map<String, dynamic>.from(applied['rulebooks'] as Map);
      final key = '$sport:$format';
      if (rulebooksMap[key] != null && rulebooksMap[key]['rulebook_url'] != null) {
        return rulebooksMap[key]['rulebook_url'] as String;
      }
    }
    return null;
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

  Future<void> _applyParentAssociationGroups() async {
    if (_selectedAssociationId == null) return;
    setState(() {
      _isLoadingParentGroups = true;
    });
    try {
      final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
      final groups = await compProvider.getAthleteGroups(_selectedAssociationId!);

      // Resolve applied shared athlete groups
      final selectedAssoc = compProvider.associations.where((a) => a.id == _selectedAssociationId).firstOrNull;
      if (selectedAssoc != null && selectedAssoc.appliedSharedResources['athlete_groups'] != null) {
        final appliedList = selectedAssoc.appliedSharedResources['athlete_groups'] as List? ?? [];
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
            final sharedGroups = await compProvider.getAthleteGroups(ownerId);
            final targetIds = owners[ownerId]!;
            groups.addAll(sharedGroups.where((g) => targetIds.contains(g.id)));
          } catch (_) {}
        }
      }

      // Filter matching sport and format
      final matching = groups.where((g) =>
        g.isActive &&
        g.sport.toLowerCase() == _sportType.toLowerCase() &&
        g.format.toLowerCase() == _sportSubtype.toLowerCase()
      ).toList();

      if (matching.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active athlete groups found for this sport & format in the parent association.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          int addedCount = 0;
          for (final g in matching) {
            final exists = _athleteGroups.any(
              (local) => local.name.toLowerCase() == g.name.toLowerCase()
            );
            if (!exists) {
              _athleteGroups.add(LocalAthleteGroup(
                name: g.name,
                gender: g.gender,
              ));
              addedCount++;
            }
          }
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully applied $addedCount athlete groups!'),
              backgroundColor: Colors.green,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load parent groups: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingParentGroups = false;
        });
      }
    }
  }

  // Submit competition logic
  Future<void> _submitCompetition() async {
    if (!_formKeys[_currentStep].currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);

    // Location field
    final addressText = _locationController.text.trim();
    final fullLocation = addressText;

    if (!_isLocationVerified || _parsedCountry.isEmpty) {
      final fallback = _parseAddressString(addressText);
      _parsedCountry = fallback['country'] ?? '';
      _parsedCity = fallback['city'] ?? '';
      _parsedZip = fallback['zip'] ?? '';
      _parsedAddress = fallback['street'] ?? addressText;
    }

    final country = _parsedCountry.isNotEmpty ? _parsedCountry : 'Germany';
    final city = _parsedCity.isNotEmpty ? _parsedCity : 'Hamburg';

    // Bank Details
    String? bankDetails;
    if (_requiresFees) {
      final iban = _ibanController.text.trim();
      final bic = _bicController.text.trim();
      final bankName = _bankNameController.text.trim();
      bankDetails = 'IBAN: $iban | BIC: $bic | Bank: $bankName';
    }

    // Payment Reference Description
    String? paymentDesc;
    if (_requiresFees) {
      paymentDesc = _paymentRefType == 'auto' ? _getGeneratedPaymentDesc() : _paymentDescController.text.trim();
    }

    final comp = Competition(
      id: UuidHelper.generateUuidV4(),
      associationId: _selectedAssociationId,
      compGroupName: _selectedCompGroupName,
      rankingType: _rankingType,
      rulebookUrl: _rulebookUrlController.text.trim().isEmpty ? null : _rulebookUrlController.text.trim(),
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      location: fullLocation,
      sportType: _sportType,
      sportSubtype: _sportSubtype,
      status: 'upcoming',
      country: country,
      city: city,
      area: country, // Map country as area as a fallback
      titleImageUrl: _titleImageUrlController.text.trim().isEmpty ? null : _titleImageUrlController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      registrationStart: _registrationStartDate,
      registrationEnd: _registrationEndDate,
      requiresFees: _requiresFees,
      feeAmount: _requiresFees ? double.tryParse(_feeAmountController.text) : null,
      feeCurrency: _requiresFees ? _feeCurrency : null,
      bankDetails: bankDetails,
      paymentDescription: paymentDesc,
      paymentStart: _requiresFees ? (_paymentStartDate ?? DateTime.now()) : null,
      paymentEnd: _requiresFees ? (_paymentEndDate ?? DateTime.now().add(const Duration(days: 7))) : null,
      registrationMode: _registrationMode,
      enableWaitlist: _enableWaitlist,
      maxAthletes: int.tryParse(_maxAthletesController.text),
      maxAthletesPerGroup: _athleteGroups.isEmpty ? null : _athleteGroups.map((e) => e.toJson()).toList(),
      volunteerNeeds: _volunteerNeeds,
      volunteerPositions: _volunteerNeeds ? _maxVolunteersPerPosition.keys.toList() : null,
      maxVolunteers: _volunteerNeeds ? int.tryParse(_maxVolunteersController.text) : null,
      maxVolunteersPerPosition: _volunteerNeeds ? Map<String, int>.from(_maxVolunteersPerPosition) : null,
      disclaimerType: _disclaimers.isEmpty ? null : 'both',
      disclaimerText: _disclaimers.isEmpty ? null : jsonEncode(_disclaimers),
      disclaimerUrl: null, // stored in JSON disclaimerText
      customAthleteFields: _customAthleteFields.isEmpty ? null : List<Map<String, dynamic>>.from(_customAthleteFields),
      customVolunteerFields: _customVolunteerFields.isEmpty ? null : List<Map<String, dynamic>>.from(_customVolunteerFields),
      bannerSafeZoneGuide: false, // removed guidance switch, keep it default false
    );

    try {
      final created = await compProvider.createCompetition(comp);
      if (!mounted) return;
      if (created != null) {
        setState(() {
          _isSubmitted = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Competition created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(created);
      } else {
        throw Exception(compProvider.errorMessage ?? 'Failed to create competition');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _nextStep() {
    if (_formKeys[_currentStep].currentState!.validate()) {
      if (_currentStep == 1 && !_isLocationVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please verify the location before proceeding.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_currentStep == 4) {
        final dateErr = _validateDates();
        if (dateErr != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(dateErr), backgroundColor: Colors.red),
          );
          return;
        }
      }
      if (_currentStep < _totalSteps - 1) {
        setState(() {
          _currentStep++;
          _locationSuggestions = [];
        });
      } else {
        _submitCompetition();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _locationSuggestions = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Competition'),
      ),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Saving competition...'),
                ],
              ),
            )
          : Column(
              children: [
                _buildStepperProgress(theme),
                Expanded(
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Card(
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
                      ),
                    ),
                  ),
                ),
                _buildStepperActions(theme),
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
        stepTitle = 'Competition Location';
        break;
      case 2:
        stepTitle = 'Sport & Format';
        break;
      case 3:
        stepTitle = 'Banner Image';
        break;
      case 4:
        stepTitle = 'Dates & Deadlines';
        break;
      case 5:
        stepTitle = 'Registration Settings';
        break;
      case 6:
        stepTitle = 'Athlete Groups';
        break;
      case 7:
        stepTitle = 'Fees & Bank Details';
        break;
      case 8:
        stepTitle = 'Payment Settings';
        break;
      case 9:
        stepTitle = 'Volunteer Setup';
        break;
      case 10:
        stepTitle = 'Disclaimers & Custom Fields';
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
        return _buildStep1Info(theme);
      case 1:
        return _buildStep2Location(theme);
      case 2:
        return _buildStep3SportFormat(theme);
      case 3:
        return _buildStep4Banner(theme);
      case 4:
        return _buildStep5Dates(theme);
      case 5:
        return _buildStep6RegSettings(theme);
      case 6:
        return _buildStep7AthleteGroups(theme);
      case 7:
        return _buildStep8FeesBank(theme);
      case 8:
        return _buildStep9PaymentSettings(theme);
      case 9:
        return _buildStep10Volunteers(theme);
      case 10:
        return _buildStep11DisclaimersCustomFields(theme);
      default:
        return Container();
    }
  }

  Widget _buildStep1Info(ThemeData theme) {
    return Form(
      key: _formKeys[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('General Informations', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('comp_name_field'),
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Competition Title *',
              hintText: 'Enter competition title',
              prefixIcon: Icon(Icons.emoji_events_outlined),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Title is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Enter details, format, requirements...',
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
          const SizedBox(height: 16),
          _buildCustomDropdownField<String?>(
            labelText: 'Parent Association',
            value: _selectedAssociationId,
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
                _selectedAssociationId = val;
              });
              _onParentOrSportChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Location(ThemeData theme) {
    return Form(
      key: _formKeys[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Competition Location', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('comp_location_field'),
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Location / Address *',
              hintText: 'e.g. Rütersbarg 50, 22529 Hamburg, Germany',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            onChanged: (val) {
              _updateLocationSuggestions('location', val);
            },
            validator: (value) => value == null || value.trim().isEmpty ? 'Location / Address is required' : null,
          ),
          if (_activeLocationField == 'location' && _locationSuggestions.isNotEmpty)
            _buildSuggestionsList(_locationController),
          VerifiedLocationBadge(
            isVerifying: _isVerifyingLocation,
            isVerified: _isLocationVerified,
            onVerify: _verifyLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(TextEditingController controller) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _locationSuggestions.length,
        itemBuilder: (context, idx) {
          final suggestion = _locationSuggestions[idx];
          return Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              title: Text(suggestion),
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
    );
  }

  Widget _buildStep3SportFormat(ThemeData theme) {
    final provider = Provider.of<CompetitionProvider>(context);
    final sportConfig = provider.sportConfig;

    final sports = sportConfig?.sports.map((s) => s.name).toList() ?? ['Streetlifting'];
    final formats = sportConfig?.formats
            .where((f) => f.sportName == _sportType)
            .map((f) => f.name)
            .toList() ??
        ['Modern', 'Classic'];

    final linkedDisciplines = sportConfig?.links
            .where((link) => link.sportName == _sportType && link.formatName == _sportSubtype)
            .map((link) => link.disciplineName)
            .toList() ??
        [];

    final disciplines = linkedDisciplines.isNotEmpty
        ? linkedDisciplines
        : (_sportType == 'Streetlifting'
            ? (_sportSubtype == 'Classic'
                ? ['Pull-up', 'Dip']
                : ['Squat', 'Pull-up', 'Dip', 'Deadlift'])
            : <String>[]);

    return Form(
      key: _formKeys[2],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sport & Format', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildCustomDropdownField<String>(
            labelText: 'Sport Type',
            value: sports.contains(_sportType) ? _sportType : sports.first,
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
              _onParentOrSportChanged();
            },
          ),
          const SizedBox(height: 20),
          _buildCustomDropdownField<String>(
            labelText: 'Sport Format',
            value: formats.contains(_sportSubtype) ? _sportSubtype : formats.first,
            prefixIcon: Icon(Icons.tune, color: theme.colorScheme.primary, size: 20),
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
              _onParentOrSportChanged();
            },
          ),
          const SizedBox(height: 20),
          _buildCustomDropdownField<String>(
            labelText: 'Ranking Type',
            value: _rankingType,
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
          TextFormField(
            controller: _rulebookUrlController,
            decoration: const InputDecoration(
              labelText: 'Rulebook URL',
              hintText: 'Enter rulebook website link',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          Builder(builder: (context) {
            final selectedAssoc = _selectedAssociationId != null
                ? provider.associations.where((a) => a.id == _selectedAssociationId).firstOrNull
                : null;
            final inheritedUrl = selectedAssoc != null ? _getInheritedRulebookUrl(selectedAssoc, _sportType, _sportSubtype) : null;
            if (inheritedUrl != null && inheritedUrl.isNotEmpty && inheritedUrl != _rulebookUrlController.text) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ActionChip(
                  avatar: const Icon(Icons.arrow_downward, size: 16),
                  label: Text('Inherit: $inheritedUrl'),
                  onPressed: () {
                    setState(() {
                      _rulebookUrlController.text = inheritedUrl;
                    });
                  },
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          if (disciplines.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Disciplines of Selected Format',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: disciplines
                  .map((d) => Chip(
                        label: Text(d, style: const TextStyle(fontSize: 12)),
                        backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.4),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep4Banner(ThemeData theme) {
    return Form(
      key: _formKeys[3],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Banner Image', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
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
                        'Recommended Size: 1200 x 400 px (3:1 Aspect Ratio)\nSafe-zone: Keep critical content in the central 800 x 300 px area.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isUploadingBanner ? null : _pickBannerImage,
                      icon: _isUploadingBanner
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload),
                      label: const Text('Upload Banner'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _bannerFileName ?? 'No image selected',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
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
                      height: 120,
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

  Widget _buildStep5Dates(ThemeData theme) {
    return Form(
      key: _formKeys[4],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dates & Deadlines', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text('Competition Period', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildDateTimePickerTile('Competition Start Date *', _startDate, (val) => setState(() => _startDate = val)),
          const SizedBox(height: 12),
          _buildDateTimePickerTile('Competition End Date *', _endDate, (val) => setState(() => _endDate = val)),
          const SizedBox(height: 20),
          Text('Registration Period', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildDateTimePickerTile('Registration Start Date *', _registrationStartDate, (val) => setState(() => _registrationStartDate = val)),
          const SizedBox(height: 12),
          _buildDateTimePickerTile('Registration End Date *', _registrationEndDate, (val) => setState(() => _registrationEndDate = val)),
        ],
      ),
    );
  }

  Widget _buildDateTimePickerTile(String label, DateTime value, Function(DateTime) onSelected) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(value.toLocal().toString().substring(0, 16)),
        trailing: const Icon(Icons.calendar_today, size: 20),
        onTap: () async {
          final dt = await _selectDateTime(context, value);
          if (dt != null) onSelected(dt);
        },
      ),
    );
  }

  Widget _buildStep6RegSettings(ThemeData theme) {
    return Form(
      key: _formKeys[5],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registration Settings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildCustomDropdownField<String>(
            labelText: 'Registration Mode',
            value: _registrationMode,
            prefixIcon: Icon(Icons.app_registration, color: theme.colorScheme.primary, size: 20),
            displayValue: (val) {
              if (val == 'fcfs') return 'First Come First Served (FCFS)';
              if (val == 'approval') return 'Manual Approval';
              if (val == 'random') return 'Random Draw';
              return val;
            },
            items: const [
              PopupMenuItem(value: 'fcfs', child: Text('First Come First Served (FCFS)')),
              PopupMenuItem(value: 'approval', child: Text('Manual Approval')),
              PopupMenuItem(value: 'random', child: Text('Random Draw')),
            ],
            onChanged: (val) {
              setState(() => _registrationMode = val);
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _maxAthletesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total Athlete Capacity Limit',
              hintText: 'e.g. 50 (leave empty for unlimited)',
              prefixIcon: Icon(Icons.people_outline),
            ),
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final capacity = int.tryParse(value.trim());
                if (capacity == null || capacity <= 0) {
                  return 'Capacity limit must be positive';
                }
              } else if (_enableWaitlist) {
                return 'Capacity limit is required to enable waitlist';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const Key('comp_waitlist_toggle'),
            title: const Text('Enable Waitlist'),
            subtitle: const Text('Allows waitlist when athlete capacity is full'),
            value: _enableWaitlist,
            onChanged: (val) => setState(() => _enableWaitlist = val),
          ),
        ],
      ),
    );
  }

  Widget _buildStep7AthleteGroups(ThemeData theme) {
    final provider = Provider.of<CompetitionProvider>(context);
    return Form(
      key: _formKeys[6],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedAssociationId != null) ...[
            _buildCustomDropdownField<String?>(
              labelText: 'Competition Group',
              value: _selectedCompGroupName,
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
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Athlete Groups', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const Key('apply_parent_groups_btn'),
                    onPressed: _selectedAssociationId == null || _isLoadingParentGroups
                        ? null
                        : _applyParentAssociationGroups,
                    icon: _isLoadingParentGroups
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Apply Parent Groups'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAthleteGroupModal(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Group'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_athleteGroups.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No athlete groups defined yet. Every competition should have at least one weight class or division.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _athleteGroups.length,
              itemBuilder: (context, idx) {
                final group = _athleteGroups[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
                  child: ListTile(
                    title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Gender: ${group.gender.toUpperCase()} • Limit: ${group.limit ?? "Unlimited"}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                          onPressed: () => _showAthleteGroupModal(editIndex: idx),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          onPressed: () {
                            setState(() {
                              _athleteGroups.removeAt(idx);
                            });
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

  Widget _buildStep8FeesBank(ThemeData theme) {
    return Form(
      key: _formKeys[7],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fees & Bank Details', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const Key('comp_fees_toggle'),
            title: const Text('Requires Registration/Participation Fees'),
            subtitle: const Text('Organizers collect fee directly via bank transfer'),
            value: _requiresFees,
            onChanged: (val) {
              setState(() {
                _requiresFees = val;
                if (val) {
                  _paymentStartDate ??= DateTime.now();
                  _paymentEndDate ??= DateTime.now().add(const Duration(days: 7));
                }
              });
            },
          ),
          if (_requiresFees) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _feeAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Fee Amount *',
                      hintText: 'e.g. 25.00',
                      prefixIcon: Icon(Icons.monetization_on_outlined),
                    ),
                    validator: (value) {
                      if (_requiresFees) {
                        final parsed = value != null ? double.tryParse(value) : null;
                        if (parsed == null || parsed < 0) {
                          return 'Fee amount is required and cannot be negative';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _showCurrencySelectorDialog(theme),
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Currency *',
                        prefixIcon: Icon(Icons.monetization_on_outlined),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$_feeCurrency (${_allCurrencies.firstWhere((c) => c['code'] == _feeCurrency)['symbol']})',
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
              decoration: const InputDecoration(
                labelText: 'IBAN *',
                hintText: 'DE89 3704 0044 ...',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              validator: (value) => _requiresFees && (value == null || value.trim().isEmpty) ? 'IBAN is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bicController,
              decoration: const InputDecoration(
                labelText: 'BIC *',
                hintText: 'WELADEDDXXX',
                prefixIcon: Icon(Icons.code),
              ),
              validator: (value) => _requiresFees && (value == null || value.trim().isEmpty) ? 'BIC is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bankNameController,
              decoration: const InputDecoration(
                labelText: 'Bank Name *',
                hintText: 'e.g. Deutsche Bank',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              validator: (value) => _requiresFees && (value == null || value.trim().isEmpty) ? 'Bank Name is required' : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep9PaymentSettings(ThemeData theme) {
    return Form(
      key: _formKeys[8],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Settings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (!_requiresFees)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Fees are not required for this competition. You can proceed to the next step.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            Text('Payment Reference', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildCustomDropdownField<String>(
              labelText: 'Payment Reference Type',
              value: _paymentRefType,
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
                      Text(_getGeneratedPaymentDesc(), style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.blue)),
                    ],
                  ),
                ),
              )
            else
              TextFormField(
                controller: _paymentDescController,
                maxLength: 140,
                decoration: const InputDecoration(
                  labelText: 'Custom Payment Reference *',
                  hintText: 'Enter custom payment instructions (max 140 char)',
                  prefixIcon: Icon(Icons.edit_note),
                ),
                validator: (value) => _requiresFees && _paymentRefType == 'custom' && (value == null || value.trim().isEmpty)
                    ? 'Custom payment reference is required'
                    : null,
              ),
            const SizedBox(height: 24),
            Text('Payment Period', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildDateTimePickerTile('Payment Period Start', _paymentStartDate ?? DateTime.now(), (val) => setState(() => _paymentStartDate = val)),
            const SizedBox(height: 12),
            _buildDateTimePickerTile(
                'Payment Period End', _paymentEndDate ?? DateTime.now().add(const Duration(days: 7)), (val) => setState(() => _paymentEndDate = val)),
          ],
        ],
      ),
    );
  }

  Widget _buildStep10Volunteers(ThemeData theme) {
    return Form(
      key: _formKeys[9],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Volunteer Setup', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Enable Volunteer Needs'),
            subtitle: const Text('Allow volunteers to apply for positions'),
            value: _volunteerNeeds,
            onChanged: (val) => setState(() => _volunteerNeeds = val),
          ),
          if (_volunteerNeeds) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxVolunteersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Volunteer Limit',
                hintText: 'e.g. 20 (optional)',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Volunteer Positions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (_volunteerNeeds)
                  ElevatedButton.icon(
                    onPressed: () => _showVolunteerPositionModal(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Position'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
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
                    'No volunteer positions defined. Add positions like Loader, Ref, etc.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
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
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
                    child: ListTile(
                      title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Volunteer Limit: ${limit == 0 ? "Unlimited" : limit}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                            onPressed: () => _showVolunteerPositionModal(editKey: key),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                            onPressed: () {
                              setState(() {
                                _maxVolunteersPerPosition.remove(key);
                              });
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

  Widget _buildStep11DisclaimersCustomFields(ThemeData theme) {
    return Form(
      key: _formKeys[10],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Disclaimers & Custom Fields', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Disclaimers', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showDisclaimerModal(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Disclaimer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_disclaimers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'No disclaimers added.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _disclaimers.length,
              itemBuilder: (context, idx) {
                final d = _disclaimers[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
                  child: ListTile(
                    title: Text(d['text'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: d['url'] != null && d['url']!.isNotEmpty ? Text('Link: ${d['url']}') : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                          onPressed: () => _showDisclaimerModal(editIndex: idx),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          onPressed: () {
                            setState(() {
                              _disclaimers.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Custom Athlete Fields', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showCustomFieldModal(true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Field'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_customAthleteFields.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'No custom athlete fields.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _customAthleteFields.length,
              itemBuilder: (context, idx) {
                final f = _customAthleteFields[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
                  child: ListTile(
                    title: Text(f['name']),
                    subtitle: Text(
                      'Type: ${f['type'] == 'text' ? 'Text Input' : (f['type'] == 'boolean' ? 'Checkbox' : (f['type'] == 'dropdown' ? 'Dropdown' : f['type']))}'
                      '${f['options'] != null ? " (${(f['options'] as List).join(', ')})" : ""}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                          onPressed: () => _showCustomFieldModal(true, editIndex: idx),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          onPressed: () {
                            setState(() {
                              _customAthleteFields.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Custom Volunteer Fields', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showCustomFieldModal(false),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Field'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_customVolunteerFields.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'No custom volunteer fields.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _customVolunteerFields.length,
              itemBuilder: (context, idx) {
                final f = _customVolunteerFields[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
                  child: ListTile(
                    title: Text(f['name']),
                    subtitle: Text(
                      'Type: ${f['type'] == 'text' ? 'Text Input' : (f['type'] == 'boolean' ? 'Checkbox' : (f['type'] == 'dropdown' ? 'Dropdown' : f['type']))}'
                      '${f['options'] != null ? " (${(f['options'] as List).join(', ')})" : ""}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                          onPressed: () => _showCustomFieldModal(false, editIndex: idx),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          onPressed: () {
                            setState(() {
                              _customVolunteerFields.removeAt(idx);
                            });
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

  Widget _buildStepperActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: _prevStep,
              child: const Text('BACK'),
            )
          else
            const SizedBox(),
          ElevatedButton(
            key: const Key('comp_next_btn'),
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE94E1B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              _currentStep == _totalSteps - 1 ? 'SUBMIT' : 'NEXT',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
