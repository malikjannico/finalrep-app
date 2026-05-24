import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import '../models/competition.dart';

class CreateCompetitionWizard extends StatefulWidget {
  const CreateCompetitionWizard({super.key});

  @override
  State<CreateCompetitionWizard> createState() =>
      _CreateCompetitionWizardState();
}

class _CreateCompetitionWizardState extends State<CreateCompetitionWizard> {
  int _currentStep = 0;
  final int _totalSteps = 6;
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();
  final _formKey4 = GlobalKey<FormState>();
  final _formKey5 = GlobalKey<FormState>();
  final _formKey6 = GlobalKey<FormState>();

  // Step 1: General Info & Subtypes
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _titleImageUrlController =
      TextEditingController();

  String _sportType = 'Streetlifting';
  String _sportSubtype = 'Modern';
  bool _bannerSafeZoneGuide = false;

  // Step 2: Dates & Deadlines
  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  DateTime _endDate = DateTime.now().add(const Duration(days: 8));
  DateTime _registrationStartDate = DateTime.now();
  DateTime _registrationEndDate = DateTime.now().add(const Duration(days: 6));

  // Step 3: Registration Mode & Capacity Limits
  String _registrationMode = 'fcfs'; // 'fcfs' or 'approval'
  bool _enableWaitlist = false;
  final TextEditingController _maxAthletesController = TextEditingController();

  // Category capacity
  final Map<String, int> _maxAthletesPerGroup = {};
  final TextEditingController _categoryNameController = TextEditingController();
  final TextEditingController _categoryLimitController =
      TextEditingController();

  // Step 4: Fees & Payment Config
  bool _requiresFees = false;
  final TextEditingController _feeAmountController = TextEditingController();
  String _feeCurrency = 'EUR';
  final TextEditingController _bankDetailsController = TextEditingController();
  final TextEditingController _paymentDescController = TextEditingController();
  DateTime? _paymentStartDate;
  DateTime? _paymentEndDate;

  // Step 5: Volunteer Setup
  bool _volunteerNeeds = false;
  final List<String> _volunteerPositions = [];
  final Map<String, List<String>> _volunteerShifts = {};
  final Map<String, int> _maxVolunteersPerPosition = {};
  final TextEditingController _maxVolunteersController =
      TextEditingController();

  final TextEditingController _newPositionController = TextEditingController();
  final Map<String, TextEditingController> _newShiftControllers = {};
  final Map<String, TextEditingController> _positionLimitControllers = {};

  // Step 6: Disclaimers & Custom Fields
  String _disclaimerType = 'none'; // 'none', 'text', 'link', 'both'
  final TextEditingController _disclaimerTextController =
      TextEditingController();
  final TextEditingController _disclaimerUrlController =
      TextEditingController();

  final List<Map<String, dynamic>> _customAthleteFields = [];
  final List<Map<String, dynamic>> _customVolunteerFields = [];

  final TextEditingController _athleteFieldNameController =
      TextEditingController();
  String _athleteFieldType = 'text';
  final TextEditingController _athleteFieldOptionsController =
      TextEditingController();

  final TextEditingController _volunteerFieldNameController =
      TextEditingController();
  String _volunteerFieldType = 'text';
  final TextEditingController _volunteerFieldOptionsController =
      TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _areaController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _titleImageUrlController.dispose();
    _maxAthletesController.dispose();
    _categoryNameController.dispose();
    _categoryLimitController.dispose();
    _feeAmountController.dispose();
    _bankDetailsController.dispose();
    _paymentDescController.dispose();
    _maxVolunteersController.dispose();
    _newPositionController.dispose();
    _disclaimerTextController.dispose();
    _disclaimerUrlController.dispose();
    _athleteFieldNameController.dispose();
    _athleteFieldOptionsController.dispose();
    _volunteerFieldNameController.dispose();
    _volunteerFieldOptionsController.dispose();
    for (var c in _newShiftControllers.values) {
      c.dispose();
    }
    for (var c in _positionLimitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _selectDateTime(
    BuildContext context,
    DateTime initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null) return null;

    if (!context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return DateTime(date.year, date.month, date.day);

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _verifyLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location verified successfully! coordinates set.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _updatePaymentDescription() {
    final title = _titleController.text.trim();
    final userId =
        Provider.of<AuthProvider>(
          context,
          listen: false,
        ).currentUserProfile?.id ??
        '';
    final defaultDesc = 'Entry Fee: $title - User: $userId';
    if (_paymentDescController.text.isEmpty) {
      _paymentDescController.text = defaultDesc.length > 140
          ? defaultDesc.substring(0, 140)
          : defaultDesc;
    }
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

  Future<void> _submitCompetition() async {
    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );

    setState(() {
      _isSaving = true;
    });

    final comp = Competition(
      id: 'comp-${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      location: _locationController.text.trim(),
      sportType: _sportType,
      sportSubtype: _sportSubtype,
      status: 'upcoming',
      area: _areaController.text.trim().isEmpty
          ? null
          : _areaController.text.trim(),
      country: _countryController.text.trim().isEmpty
          ? null
          : _countryController.text.trim(),
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      titleImageUrl: _titleImageUrlController.text.trim().isEmpty
          ? null
          : _titleImageUrlController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      registrationStart: _registrationStartDate,
      registrationEnd: _registrationEndDate,
      requiresFees: _requiresFees,
      feeAmount: _requiresFees
          ? double.tryParse(_feeAmountController.text)
          : null,
      feeCurrency: _requiresFees ? _feeCurrency : null,
      bankDetails: _requiresFees ? _bankDetailsController.text.trim() : null,
      paymentDescription: _requiresFees
          ? _paymentDescController.text.trim()
          : null,
      paymentStart: _requiresFees ? _paymentStartDate : null,
      paymentEnd: _requiresFees ? _paymentEndDate : null,
      registrationMode: _registrationMode,
      enableWaitlist: _enableWaitlist,
      maxAthletes: int.tryParse(_maxAthletesController.text),
      maxAthletesPerGroup: _maxAthletesPerGroup.isEmpty
          ? null
          : Map<String, int>.from(_maxAthletesPerGroup),
      volunteerNeeds: _volunteerNeeds,
      volunteerPositions: _volunteerNeeds
          ? List<String>.from(_volunteerPositions)
          : null,
      volunteerShifts: _volunteerNeeds
          ? Map<String, List<String>>.from(_volunteerShifts)
          : null,
      maxVolunteers: _volunteerNeeds
          ? int.tryParse(_maxVolunteersController.text)
          : null,
      maxVolunteersPerPosition: _volunteerNeeds
          ? Map<String, int>.from(_maxVolunteersPerPosition)
          : null,
      disclaimerType: _disclaimerType == 'none' ? null : _disclaimerType,
      disclaimerText:
          _disclaimerType != 'none' && _disclaimerTextController.text.isNotEmpty
          ? _disclaimerTextController.text
          : null,
      disclaimerUrl:
          _disclaimerType != 'none' && _disclaimerUrlController.text.isNotEmpty
          ? _disclaimerUrlController.text
          : null,
      customAthleteFields: _customAthleteFields.isEmpty
          ? null
          : List<Map<String, dynamic>>.from(_customAthleteFields),
      customVolunteerFields: _customVolunteerFields.isEmpty
          ? null
          : List<Map<String, dynamic>>.from(_customVolunteerFields),
      bannerSafeZoneGuide: _bannerSafeZoneGuide,
    );

    try {
      final created = await compProvider.createCompetition(comp);
      if (!mounted) return;
      if (created != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Competition created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(created);
      } else {
        throw Exception(
          compProvider.errorMessage ?? 'Failed to create competition',
        );
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
    final formKeys = [
      _formKey1,
      _formKey2,
      _formKey3,
      _formKey4,
      _formKey5,
      _formKey6,
    ];

    if (_currentStep == 3) {
      _updatePaymentDescription();
    }

    if (formKeys[_currentStep].currentState!.validate()) {
      if (_currentStep == 1) {
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Competition')),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating competition...'),
                ],
              ),
            )
          : Column(
              children: [
                _buildProgressHeader(theme),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildStepContent(theme),
                  ),
                ),
                _buildActionButtons(theme),
              ],
            ),
    );
  }

  Widget _buildProgressHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalSteps, (index) {
          final isCompleted = _currentStep > index;
          final isActive = _currentStep == index;
          return Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isCompleted
                    ? Colors.green
                    : isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive || isCompleted
                              ? Colors.white
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              if (index < _totalSteps - 1)
                Container(
                  width: 24,
                  height: 2,
                  color: isCompleted
                      ? Colors.green
                      : theme.colorScheme.outlineVariant,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(ThemeData theme) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Info(theme);
      case 1:
        return _buildStep2Dates(theme);
      case 2:
        return _buildStep3Registration(theme);
      case 3:
        return _buildStep4Fees(theme);
      case 4:
        return _buildStep5Volunteers(theme);
      case 5:
        return _buildStep6Disclaimers(theme);
      default:
        return Container();
    }
  }

  Widget _buildStep1Info(ThemeData theme) {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step 1: General Info & Subtypes',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('comp_name_field'),
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Competition Title *',
              hintText: 'Enter competition title',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Title is required'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Enter description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('comp_location_field'),
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Location / Venue *',
              hintText: 'e.g. Fit Gym, Hamburg',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Location is required'
                : null,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _verifyLocation,
            icon: const Icon(Icons.location_searching),
            label: const Text('Verify Location'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _areaController,
            decoration: const InputDecoration(
              labelText: 'Area / Region',
              hintText: 'e.g. Northern Germany',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _countryController,
            decoration: const InputDecoration(
              labelText: 'Country',
              hintText: 'e.g. Germany',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'City',
              hintText: 'e.g. Hamburg',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _sportType,
            decoration: const InputDecoration(
              labelText: 'Sport Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Streetlifting',
                child: Text('Streetlifting'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _sportType = val);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _sportSubtype,
            decoration: const InputDecoration(
              labelText: 'Sport Subtype',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Modern',
                child: Text('Modern (Muscleup, Pullup, Dip, Squat)'),
              ),
              DropdownMenuItem(
                value: 'Classic',
                child: Text('Classic (Pullup, Dip)'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _sportSubtype = val);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleImageUrlController,
            decoration: const InputDecoration(
              labelText: 'Title Image URL',
              hintText: 'https://example.com/banner.jpg',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListBorderRow(
            title: 'Enable Banner Safe Zone Guide',
            value: _bannerSafeZoneGuide,
            onChanged: (val) => setState(() => _bannerSafeZoneGuide = val),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Dates(ThemeData theme) {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 2: Dates & Deadlines', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          _buildDateTimePickerTile(
            'Competition Start Date',
            _startDate,
            (val) => setState(() => _startDate = val),
          ),
          const SizedBox(height: 16),
          _buildDateTimePickerTile(
            'Competition End Date',
            _endDate,
            (val) => setState(() => _endDate = val),
          ),
          const SizedBox(height: 16),
          _buildDateTimePickerTile(
            'Registration Start Date',
            _registrationStartDate,
            (val) => setState(() => _registrationStartDate = val),
          ),
          const SizedBox(height: 16),
          _buildDateTimePickerTile(
            'Registration End Date',
            _registrationEndDate,
            (val) => setState(() => _registrationEndDate = val),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePickerTile(
    String label,
    DateTime value,
    Function(DateTime) onSelected,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value.toLocal().toString().substring(0, 16)),
        trailing: const Icon(Icons.calendar_today),
        onTap: () async {
          final dt = await _selectDateTime(context, value);
          if (dt != null) onSelected(dt);
        },
      ),
    );
  }

  Widget _buildStep3Registration(ThemeData theme) {
    return Form(
      key: _formKey3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step 3: Registration Mode & Capacity Limits',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _registrationMode,
            decoration: const InputDecoration(
              labelText: 'Registration Mode',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'fcfs',
                child: Text('First Come First Served (FCFS)'),
              ),
              DropdownMenuItem(
                value: 'approval',
                child: Text('Manual Approval'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _registrationMode = val);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _maxAthletesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total Athlete Capacity Limit',
              hintText: 'e.g. 50 (leave empty for unlimited)',
              border: OutlineInputBorder(),
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
          const SizedBox(height: 8),
          SwitchListBorderRow(
            key: const Key('comp_waitlist_toggle'),
            title: 'Enable Waitlist',
            value: _enableWaitlist,
            onChanged: (val) => setState(() => _enableWaitlist = val),
          ),
          const SizedBox(height: 24),
          Text(
            'Category Limits (Optional)',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _categoryNameController,
                  decoration: const InputDecoration(
                    labelText: 'Category/Group',
                    hintText: 'e.g. Men -74kg',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: _categoryLimitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Limit',
                    hintText: '10',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                onPressed: () {
                  final name = _categoryNameController.text.trim();
                  final limit = int.tryParse(
                    _categoryLimitController.text.trim(),
                  );
                  if (name.isNotEmpty && limit != null) {
                    setState(() {
                      _maxAthletesPerGroup[name] = limit;
                      _categoryNameController.clear();
                      _categoryLimitController.clear();
                    });
                  }
                },
              ),
            ],
          ),
          if (_maxAthletesPerGroup.isNotEmpty) ...[
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _maxAthletesPerGroup.length,
              itemBuilder: (context, idx) {
                final key = _maxAthletesPerGroup.keys.elementAt(idx);
                final val = _maxAthletesPerGroup[key];
                return ListTile(
                  title: Text(key),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$val athletes max'),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _maxAthletesPerGroup.remove(key);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep4Fees(ThemeData theme) {
    return Form(
      key: _formKey4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step 4: Fees & Payment Config',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SwitchListBorderRow(
            key: const Key('comp_fees_toggle'),
            title: 'Requires Registration/Participation Fees',
            value: _requiresFees,
            onChanged: (val) {
              setState(() {
                _requiresFees = val;
                if (val) {
                  _paymentStartDate ??= DateTime.now();
                  _paymentEndDate ??= DateTime.now().add(
                    const Duration(days: 7),
                  );
                }
              });
            },
          ),
          if (_requiresFees) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _feeAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Fee Amount *',
                hintText: 'e.g. 25.00',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (_requiresFees) {
                  final parsed = value != null ? double.tryParse(value) : null;
                  if (parsed == null || parsed < 0) {
                    return 'Fee amount cannot be negative';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _feeCurrency,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _feeCurrency = val);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bankDetailsController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'IBAN / Bank Details *',
                hintText: 'Enter IBAN, BIC, Bank Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  _requiresFees && (value == null || value.trim().isEmpty)
                  ? 'Bank details are required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _paymentDescController,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'Payment Reference / Description *',
                hintText: 'Defaults to auto-generated details',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  _requiresFees && (value == null || value.trim().isEmpty)
                  ? 'Payment description is required'
                  : null,
            ),
            const SizedBox(height: 16),
            _buildDateTimePickerTile(
              'Payment Window Start',
              _paymentStartDate ?? DateTime.now(),
              (val) => setState(() => _paymentStartDate = val),
            ),
            const SizedBox(height: 16),
            _buildDateTimePickerTile(
              'Payment Window End',
              _paymentEndDate ?? DateTime.now().add(const Duration(days: 7)),
              (val) => setState(() => _paymentEndDate = val),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep5Volunteers(ThemeData theme) {
    return Form(
      key: _formKey5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 5: Volunteer Setup', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          SwitchListBorderRow(
            title: 'Enable Volunteer Needs',
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
                hintText: 'e.g. 10 (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Volunteer Positions & Shifts',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _newPositionController,
                    decoration: const InputDecoration(
                      labelText: 'Add Volunteer Position',
                      hintText: 'e.g. Loader, Judge, Scorekeeper',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  onPressed: () {
                    final pos = _newPositionController.text.trim();
                    if (pos.isNotEmpty && !_volunteerPositions.contains(pos)) {
                      setState(() {
                        _volunteerPositions.add(pos);
                        _volunteerShifts[pos] = ['Morning', 'Afternoon'];
                        _newShiftControllers[pos] = TextEditingController();
                        _positionLimitControllers[pos] =
                            TextEditingController();
                        _newPositionController.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._volunteerPositions.map((pos) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            pos,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _volunteerPositions.remove(pos);
                                _volunteerShifts.remove(pos);
                                _maxVolunteersPerPosition.remove(pos);
                                _newShiftControllers[pos]?.dispose();
                                _newShiftControllers.remove(pos);
                                _positionLimitControllers[pos]?.dispose();
                                _positionLimitControllers.remove(pos);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Shifts
                      Text('Shifts:', style: theme.textTheme.bodySmall),
                      Wrap(
                        spacing: 8,
                        children: (_volunteerShifts[pos] ?? []).map((shift) {
                          return Chip(
                            label: Text(shift),
                            onDeleted: () {
                              setState(() {
                                _volunteerShifts[pos]?.remove(shift);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _newShiftControllers[pos],
                              decoration: const InputDecoration(
                                labelText: 'New Shift Name',
                                hintText: 'e.g. Night',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              final shName = _newShiftControllers[pos]?.text
                                  .trim();
                              if (shName != null && shName.isNotEmpty) {
                                setState(() {
                                  _volunteerShifts[pos]?.add(shName);
                                  _newShiftControllers[pos]?.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _positionLimitControllers[pos],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Volunteers for this Position',
                          hintText: 'e.g. 4',
                        ),
                        onChanged: (val) {
                          final lim = int.tryParse(val.trim());
                          if (lim != null) {
                            _maxVolunteersPerPosition[pos] = lim;
                          } else {
                            _maxVolunteersPerPosition.remove(pos);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildStep6Disclaimers(ThemeData theme) {
    return Form(
      key: _formKey6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step 6: Disclaimers & Custom Fields',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _disclaimerType,
            decoration: const InputDecoration(
              labelText: 'Disclaimer Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('None')),
              DropdownMenuItem(value: 'text', child: Text('Text Only')),
              DropdownMenuItem(value: 'link', child: Text('Link Only')),
              DropdownMenuItem(
                value: 'both',
                child: Text('Both Text and Link'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _disclaimerType = val);
            },
          ),
          if (_disclaimerType == 'text' || _disclaimerType == 'both') ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _disclaimerTextController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Disclaimer Text *',
                hintText: 'Enter disclaimer conditions...',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (_disclaimerType == 'text' || _disclaimerType == 'both') &&
                      (value == null || value.trim().isEmpty)
                  ? 'Disclaimer text is required'
                  : null,
            ),
          ],
          if (_disclaimerType == 'link' || _disclaimerType == 'both') ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _disclaimerUrlController,
              decoration: const InputDecoration(
                labelText: 'Disclaimer URL *',
                hintText: 'https://example.com/terms',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (_disclaimerType == 'link' || _disclaimerType == 'both') {
                  if (value == null || value.trim().isEmpty)
                    return 'Disclaimer URL is required';
                  final uri = Uri.tryParse(value);
                  if (uri == null || !uri.hasAbsolutePath)
                    return 'Enter a valid URL';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Custom Athlete Registration Fields',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildCustomFieldsBuilder(
            fields: _customAthleteFields,
            nameController: _athleteFieldNameController,
            typeValue: _athleteFieldType,
            optionsController: _athleteFieldOptionsController,
            onTypeChanged: (val) => setState(() => _athleteFieldType = val),
            onAdd: () {
              final name = _athleteFieldNameController.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  final Map<String, dynamic> f = {
                    'name': name,
                    'type': _athleteFieldType,
                  };
                  if (_athleteFieldType == 'dropdown') {
                    f['options'] = _athleteFieldOptionsController.text
                        .split(',')
                        .map((e) => e.trim())
                        .toList();
                  }
                  _customAthleteFields.add(f);
                  _athleteFieldNameController.clear();
                  _athleteFieldOptionsController.clear();
                });
              }
            },
            onDelete: (idx) =>
                setState(() => _customAthleteFields.removeAt(idx)),
          ),
          const SizedBox(height: 24),
          Text(
            'Custom Volunteer Application Fields',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildCustomFieldsBuilder(
            fields: _customVolunteerFields,
            nameController: _volunteerFieldNameController,
            typeValue: _volunteerFieldType,
            optionsController: _volunteerFieldOptionsController,
            onTypeChanged: (val) => setState(() => _volunteerFieldType = val),
            onAdd: () {
              final name = _volunteerFieldNameController.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  final Map<String, dynamic> f = {
                    'name': name,
                    'type': _volunteerFieldType,
                  };
                  if (_volunteerFieldType == 'dropdown') {
                    f['options'] = _volunteerFieldOptionsController.text
                        .split(',')
                        .map((e) => e.trim())
                        .toList();
                  }
                  _customVolunteerFields.add(f);
                  _volunteerFieldNameController.clear();
                  _volunteerFieldOptionsController.clear();
                });
              }
            },
            onDelete: (idx) =>
                setState(() => _customVolunteerFields.removeAt(idx)),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomFieldsBuilder({
    required List<Map<String, dynamic>> fields,
    required TextEditingController nameController,
    required String typeValue,
    required TextEditingController optionsController,
    required Function(String) onTypeChanged,
    required VoidCallback onAdd,
    required Function(int) onDelete,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Field Label/Question',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: typeValue,
              items: const [
                DropdownMenuItem(value: 'text', child: Text('Text Input')),
                DropdownMenuItem(value: 'boolean', child: Text('Checkbox')),
                DropdownMenuItem(value: 'dropdown', child: Text('Dropdown')),
              ],
              onChanged: (val) {
                if (val != null) onTypeChanged(val);
              },
            ),
          ],
        ),
        if (typeValue == 'dropdown') ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: optionsController,
            decoration: const InputDecoration(
              labelText: 'Dropdown Options (comma-separated)',
              hintText: 'e.g. Yes, No, Maybe',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 8),
        ElevatedButton(onPressed: onAdd, child: const Text('Add Custom Field')),
        if (fields.isNotEmpty) ...[
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fields.length,
            itemBuilder: (context, idx) {
              final f = fields[idx];
              return ListTile(
                title: Text(f['name']),
                subtitle: Text(
                  'Type: ${f['type']} ${f['options'] != null ? "(${f['options']})" : ""}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => onDelete(idx),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(onPressed: _prevStep, child: const Text('BACK'))
          else
            const SizedBox(),
          ElevatedButton(
            key: const Key('comp_next_btn'),
            onPressed: _nextStep,
            child: Text(_currentStep == _totalSteps - 1 ? 'SUBMIT' : 'NEXT'),
          ),
        ],
      ),
    );
  }
}

class SwitchListBorderRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwitchListBorderRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
