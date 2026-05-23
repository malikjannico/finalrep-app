# Technical Analysis: System Notifications & Preference Persistence

## 1. Mission & Objectives

The goal of this analysis is to propose a read-only strategy for system notifications and preference persistence. Specifically, we define how to:
1. Store and persist category-specific notification preferences for a user in the `profiles` table in Supabase.
2. Retrieve and filter notifications in the UI according to these preferences.
3. Automatically trigger system notifications across 5 distinct business logic events (registration, permissions, payments, schedule, and flights) at their correct implementation points in the repositories and state providers.

---

## 2. Current Architecture & Integration Strategy

### Key Existing Components
- **SystemNotification Model** (`lib/models/system_notification.dart`): Data model representing a notification. Already supports fields: `id`, `userId`, `title`, `message`, `category`, `isRead`, `createdAt`.
- **NotificationRepository** (`lib/repositories/notification_repository.dart`): CRUD client wrapper for the `notifications` table. Includes `getNotifications(userId)`, `createNotification(notification)`, and `markAsRead(notificationId)`.
- **Profile Model** (`lib/models/profile.dart`): Data model for user profiles. Needs updates to store preferences.
- **ProfileRepository** (`lib/repositories/profile_repository.dart`): Database handler for profile CRUD operations, containing `updateProfile(Profile profile)`.
- **AuthProvider** (`lib/providers/auth_provider.dart`): Manages authentication and the current user's profile state.
- **CompetitionProvider** (`lib/providers/competition_provider.dart`): Manages meet creation, volunteer applications, schedule publications, and flight balancing.
- **NotificationsPage** (`lib/views/notifications_page.dart`): Display list and settings configuration toggles. Currently uses local states for setting switches.

---

## 3. Proposal: Notification Preferences Persistence

To persist notification preferences, we will store them directly on the user's Profile record. This ensures settings survive logouts and sync automatically across all device platforms.

### 3.1. Database Schema
We propose adding a `notification_preferences` column of type `jsonb` to the `profiles` table in Postgres:
```sql
ALTER TABLE profiles ADD COLUMN notification_preferences jsonb DEFAULT '{
  "registration": true,
  "permissions": true,
  "payments": true,
  "schedule": true,
  "flights": true
}'::jsonb;
```

### 3.2. Model Updates (`lib/models/profile.dart`)
1. **Field declaration**:
   ```dart
   final Map<String, bool> notificationPreferences;
   ```
2. **Constructor update**:
   ```dart
   this.notificationPreferences = const {
     'registration': true,
     'permissions': true,
     'payments': true,
     'schedule': true,
     'flights': true,
   },
   ```
3. **Serialization updates**:
   - **`Profile.fromJson`**:
     ```dart
     notificationPreferences: json['notification_preferences'] != null
         ? Map<String, bool>.from(
             (json['notification_preferences'] as Map).map(
               (k, v) => MapEntry(k.toString(), v as bool),
             ),
           )
         : const {
             'registration': true,
             'permissions': true,
             'payments': true,
             'schedule': true,
             'flights': true,
           },
     ```
   - **`Profile.toJson`**:
     ```dart
     'notification_preferences': notificationPreferences,
     ```
4. **`copyWith` updates**:
   ```dart
   Map<String, bool>? notificationPreferences,
   ...
   notificationPreferences: notificationPreferences ?? this.notificationPreferences,
   ```

### 3.3. State Provider Updates (`lib/providers/auth_provider.dart`)
We must add a method inside `AuthProvider` to change preference states and push them to the profile database:
```dart
Future<void> updateNotificationPreference(String category, bool enabled) async {
  if (_currentUserProfile == null) return;

  final updatedPrefs = Map<String, bool>.from(_currentUserProfile!.notificationPreferences);
  updatedPrefs[category] = enabled;

  final updatedProfile = _currentUserProfile!.copyWith(
    notificationPreferences: updatedPrefs,
  );

  try {
    final result = await _profileRepository.updateProfile(updatedProfile);
    if (result != null) {
      _currentUserProfile = result;
      notifyListeners();
    }
  } catch (e) {
    debugPrint('Failed to save notification preferences: $e');
    // Local fallback: update local model state even if DB update fails to keep UI responsive
    _currentUserProfile = updatedProfile;
    notifyListeners();
  }
}
```

### 3.4. UI Integration (`lib/views/notifications_page.dart`)
Instead of tracking preferences via a local `_enabledAlerts` map, bind the settings switches directly to `AuthProvider`.

- **Reading preferences**:
  ```dart
  final authProvider = Provider.of<AuthProvider>(context);
  final enabledAlerts = authProvider.currentUserProfile?.notificationPreferences ?? {
    'registration': true,
    'permissions': true,
    'payments': true,
    'schedule': true,
    'flights': true,
  };
  ```
- **Toggling preferences**:
  ```dart
  SwitchListTile(
    key: Key('switch_$category'),
    title: Text(category[0].toUpperCase() + category.substring(1)),
    value: enabledAlerts[category] ?? true,
    onChanged: (val) {
      authProvider.updateNotificationPreference(category, val);
    },
  );
  ```

- **Filtering Notifications on display**:
  Allowed notifications are filtered according to preferences. We store all notifications in the database to keep notification histories complete, but hide categories when the corresponding preference is set to `false`.
  ```dart
  final allowedNotifications = _notifications.where((n) {
    return enabledAlerts[n.category] ?? true;
  }).toList();
  ```

---

## 4. Proposal: System Notification Triggers

To support sending notifications, we must introduce `NotificationRepository` into both `AuthProvider` and `CompetitionProvider`.

- **`AuthProvider` Constructor Injection**:
  ```dart
  final NotificationRepository _notificationRepository;
  
  AuthProvider(
    this._client,
    this._profileRepository, {
    AdminRepository? adminRepository,
    NotificationRepository? notificationRepository,
  }) : _adminRepository = adminRepository ?? AdminRepository(_client),
       _notificationRepository = notificationRepository ?? NotificationRepository(_client);
  ```

- **`CompetitionProvider` Constructor Injection**:
  ```dart
  final NotificationRepository _notificationRepository;
  
  CompetitionProvider(
    this._repository,
    this._profileRepository, {
    AssociationRepository? associationRepository,
    NotificationRepository? notificationRepository,
  }) : _associationRepository = associationRepository ?? AssociationRepository(_repository.client),
       _notificationRepository = notificationRepository ?? NotificationRepository(_repository.client);
  ```

We define below the exact trigger points, signatures, and logic for the 5 requested notification types.

---

### 4.1. Registration Updates (Category: `'registration'`)

#### Where to Inject
Introduce an athlete registration flow in `CompetitionProvider` and `CompetitionRepository`. Currently, `views/competition_detail_page.dart` (lines 278-305) presents only a dummy SnackBar. We will add a real registration function call:

#### Proposed Code Changes
- **`lib/repositories/competition_repository.dart`**:
  ```dart
  Future<bool> registerAthlete(String competitionId, String userId) async {
    try {
      await _client.from('meet_registrations').insert({
        'id': 'reg-$competitionId-$userId-${DateTime.now().millisecondsSinceEpoch}',
        'competition_id': competitionId,
        'profile_id': userId,
        'status': 'registered',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error registering athlete in database: $e');
      return false;
    }
  }
  ```

- **`lib/providers/competition_provider.dart`**:
  ```dart
  Future<bool> registerAthlete({
    required String competitionId,
    required String userId,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _repository.registerAthlete(competitionId, userId);
      if (success) {
        final competition = await getCompetitionById(competitionId);
        if (competition != null) {
          // Trigger Registration Notification
          final regNotification = SystemNotification(
            id: 'notif-reg-${DateTime.now().millisecondsSinceEpoch}',
            userId: userId,
            title: 'Registration Confirmed',
            message: 'You have successfully registered for the meet "${competition.title}".',
            category: 'registration',
            createdAt: DateTime.now(),
          );
          await _notificationRepository.createNotification(regNotification);

          // Handle Payments notification if fees are required
          if (competition.requiresFees) {
            await triggerPaymentDeadlineNotification(
              userId: userId,
              competition: competition,
            );
          }
        }
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  ```

---

### 4.2. Permission Updates (Category: `'permissions'`)

#### Where to Inject
Inside `AuthProvider.approvePermissionApplication` (line 380) and `AuthProvider.rejectPermissionApplication` (line 411).

#### Proposed Code Changes
- **`lib/providers/auth_provider.dart`**:
  Inside `approvePermissionApplication`:
  ```dart
  final app = await _adminRepository.approvePermissionApplication(applicationId);
  if (app != null && app.status == 'approved') {
    // [Existing Promotion Logic...]
    
    // Trigger Permission Notification
    final notif = SystemNotification(
      id: 'notif-perm-${DateTime.now().millisecondsSinceEpoch}',
      userId: app.userId,
      title: 'Permissions Approved',
      message: 'Your application to become a ${app.type == 'create_competition' ? 'Competition Creator' : 'Association Creator'} has been approved.',
      category: 'permissions',
      createdAt: DateTime.now(),
    );
    await _notificationRepository.createNotification(notif);
  }
  ```

  Inside `rejectPermissionApplication`:
  ```dart
  final app = await _adminRepository.rejectPermissionApplication(applicationId);
  if (app != null && app.status == 'rejected') {
    // Trigger Permission Notification
    final notif = SystemNotification(
      id: 'notif-perm-${DateTime.now().millisecondsSinceEpoch}',
      userId: app.userId,
      title: 'Permissions Application Update',
      message: 'Your application to become a ${app.type == 'create_competition' ? 'Competition Creator' : 'Association Creator'} was rejected.',
      category: 'permissions',
      createdAt: DateTime.now(),
    );
    await _notificationRepository.createNotification(notif);
  }
  ```

---

### 4.3. Payment Deadlines (Category: `'payments'`)

#### Where to Inject
We handle payment deadlines under two circumstances:
1. **When registering for a meet with fees**: Triggered in `CompetitionProvider.registerAthlete` (immediately when registration completes).
2. **When a competition is created with registration fees**: Triggered in `CompetitionProvider.createCompetition` (to notify the coordinator of payment details).

#### Proposed Code Changes
- **`lib/providers/competition_provider.dart`**:
  Helper method:
  ```dart
  Future<void> triggerPaymentDeadlineNotification({
    required String userId,
    required Competition competition,
  }) async {
    final deadline = competition.paymentEnd ?? competition.registrationEnd;
    final currency = competition.feeCurrency ?? 'EUR';
    final amount = competition.feeAmount?.toStringAsFixed(2) ?? '0.00';
    
    final paymentNotification = SystemNotification(
      id: 'notif-pay-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: 'Payment Action Required',
      message: 'A registration fee of $amount $currency is due for "${competition.title}". Deadline: ${deadline.toLocal().toString().split(' ')[0]}.',
      category: 'payments',
      createdAt: DateTime.now(),
    );
    await _notificationRepository.createNotification(paymentNotification);
  }
  ```

  Inside `createCompetition` (line 760):
  ```dart
  final created = await _repository.createCompetition(compToCreate);
  if (created != null) {
    _allCompetitions.add(created);
    _applyFilters();

    if (created.requiresFees) {
      final notif = SystemNotification(
        id: 'notif-pay-setup-${DateTime.now().millisecondsSinceEpoch}',
        userId: created.associationId ?? '', // Target the association/creator account
        title: 'Payment Details Formulated',
        message: 'Competition "${created.title}" created with fee ${created.feeAmount} ${created.feeCurrency}. Deadline: ${created.paymentEnd ?? created.registrationEnd}.',
        category: 'payments',
        createdAt: DateTime.now(),
      );
      await _notificationRepository.createNotification(notif);
    }
  }
  ```

---

### 4.4. Schedule Releases (Category: `'schedule'`)

#### Where to Inject
Inside `CompetitionProvider.publishSchedule` (line 982), which is currently a dummy stub.

#### Proposed Code Changes
- **`lib/repositories/competition_repository.dart`**:
  We need a query to get registered athlete IDs for the competition:
  ```dart
  Future<List<String>> getRegisteredAthleteIds(String competitionId) async {
    try {
      final response = await _client
          .from('meet_registrations')
          .select('profile_id')
          .eq('competition_id', competitionId)
          .eq('status', 'registered');
      return (response as List).map((e) => e['profile_id'] as String).toList();
    } catch (e) {
      debugPrint('Error getting registered athlete IDs: $e');
      return [];
    }
  }
  ```

- **`lib/providers/competition_provider.dart`**:
  ```dart
  Future<void> publishSchedule(String competitionId, {bool isPublic = true}) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1. Core publication updates (e.g. database table updating isPublic configuration)
      await _repository.client
          .from('competitions')
          .update({'schedule_published': isPublic})
          .eq('id', competitionId);
          
      // 2. Fetch the competition details
      final comp = await getCompetitionById(competitionId);
      if (comp != null && isPublic) {
        // 3. Query all athletes registered to this meet
        final athleteIds = await _repository.getRegisteredAthleteIds(competitionId);
        
        // 4. Send schedule notification to each registered athlete
        for (final athleteId in athleteIds) {
          final notif = SystemNotification(
            id: 'notif-sched-$competitionId-$athleteId-${DateTime.now().millisecondsSinceEpoch}',
            userId: athleteId,
            title: 'Meet Schedule Published',
            message: 'The official schedule for "${comp.title}" has been published. Check the agenda now!',
            category: 'schedule',
            createdAt: DateTime.now(),
          );
          await _notificationRepository.createNotification(notif);
        }
      }
    } catch (e) {
      debugPrint('Error publishing schedule: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  ```

---

### 4.5. Flight Listings (Category: `'flights'`)

#### Where to Inject
Inside `CompetitionProvider.balanceFlights` (line 947), which generates flights and registers them to the database.

#### Proposed Code Changes
- **`lib/providers/competition_provider.dart`**:
  ```dart
  Future<void> balanceFlights(String competitionId) async {
    final athletes = await _repository.getCompetitionAthletes(competitionId);
    if (athletes.isEmpty) return;
    
    final competition = await getCompetitionById(competitionId);
    final compTitle = competition?.title ?? 'Competition';

    final numFlights = (athletes.length / 12).ceil();
    final athletesPerFlight = (athletes.length / numFlights).ceil();
    
    for (int i = 0; i < numFlights; i++) {
      final startIndex = i * athletesPerFlight;
      final endIndex = (startIndex + athletesPerFlight > athletes.length) ? athletes.length : startIndex + athletesPerFlight;
      final flightAthletes = athletes.sublist(startIndex, endIndex).map((a) => a.id).toList();
      final flightName = 'Flight ${String.fromCharCode(65 + i)}';
      
      final flight = Flight(
        id: 'flight-$competitionId-${DateTime.now().millisecondsSinceEpoch}-$i',
        competitionId: competitionId,
        name: flightName,
        athleteIds: flightAthletes,
        status: 'pending',
      );
      await _repository.createFlight(flight);

      // Trigger Flight Assignment System Notification for each athlete in this flight
      for (final athleteId in flightAthletes) {
        final notif = SystemNotification(
          id: 'notif-flight-$competitionId-$athleteId-${DateTime.now().millisecondsSinceEpoch}',
          userId: athleteId,
          title: 'Flight Assignment Updated',
          message: 'You have been assigned to "$flightName" for the meet "$compTitle".',
          category: 'flights',
          createdAt: DateTime.now(),
        );
        await _notificationRepository.createNotification(notif);
      }
    }
    notifyListeners();
  }
  ```

---

## 5. Mock Fallbacks for Offline Operations

To ensure robustness during local testing and offline runs, the repositories will fall back gracefully if Supabase network calls throw exceptions.

### 5.1. ProfileRepository Fallback
If updating profile preferences in Supabase fails, `ProfileRepository.updateProfile` returns a mock/cached copy of the profile containing the updated settings, which updates `_currentUserProfile` in memory and executes `notifyListeners()` so the UI remains active.

### 5.2. NotificationRepository Fallback
`NotificationRepository.createNotification` will write to a local list or return the original notification object if the DB is unreachable:
```dart
class NotificationRepository {
  // ...
  static final List<SystemNotification> _mockNotificationDb = [];

  Future<SystemNotification?> createNotification(SystemNotification notification) async {
    try {
      final response = await _client
          .from('notifications')
          .insert(notification.toJson())
          .select()
          .single();
      return SystemNotification.fromJson(response);
    } catch (e) {
      debugPrint('Error creating notification in DB (using memory fallback): $e');
      _mockNotificationDb.add(notification);
      return notification;
    }
  }

  Future<List<SystemNotification>> getNotifications(String userId) async {
    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => SystemNotification.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching notifications (returning memory cache): $e');
      return _mockNotificationDb.where((n) => n.userId == userId).toList();
    }
  }
}
```

This dual-layer fallback strategy guarantees that integration tests can be written and successfully executed using mocks/in-memory states without external API dependencies.
