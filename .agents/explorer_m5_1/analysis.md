# Analysis & Proposal: Milestone 5 - System Notifications

This document outlines the detailed strategy and code injection plan for implementing system notification triggers, persisting user category preferences, and linking them to providers and views.

---

## 1. Notification Category Settings & Persistence

### Proposed Database Schema Update
To persist user notification settings (preferences) across devices, we will add a new column to the `profiles` database table:
- **Column Name**: `notification_preferences`
- **Data Type**: `JSONB`
- **Default Value**: `'{"registration": true, "permissions": true, "payments": true, "schedule": true, "flights": true}'::jsonb`

### Model Layer Integration
We will extend the `Profile` model in `lib/models/profile.dart` to support this new field.

#### `Profile` Class Signature:
```dart
class Profile {
  // ... existing fields ...
  final Map<String, bool> notificationPreferences;

  Profile({
    // ... existing fields ...
    this.notificationPreferences = const {
      'registration': true,
      'permissions': true,
      'payments': true,
      'schedule': true,
      'flights': true,
    },
  });
}
```

#### JSON Serialization (`Profile.fromJson`):
```dart
notificationPreferences: json['notification_preferences'] is Map
    ? Map<String, bool>.from(json['notification_preferences'] as Map)
    : const {
        'registration': true,
        'permissions': true,
        'payments': true,
        'schedule': true,
        'flights': true,
      },
```

#### JSON Serialization (`Profile.toJson`):
```dart
'notification_preferences': notificationPreferences,
```

### Provider & Repository Logic (`AuthProvider`)
We will add methods to `AuthProvider` (`lib/providers/auth_provider.dart`) to manage and update notification settings in the database:

```dart
/// Update notification category preferences for the logged-in user.
Future<void> updateNotificationPreferences(Map<String, bool> preferences) async {
  if (_currentUserProfile == null) return;
  
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();

  try {
    final updatedProfile = _currentUserProfile!.copyWith(
      notificationPreferences: preferences,
    );

    // Persist to Supabase database
    final result = await _profileRepository.updateProfile(updatedProfile);
    if (result != null) {
      _currentUserProfile = result;
    }
  } catch (e) {
    _errorMessage = e.toString();
    // Local fallback: update state even if DB query fails/offline
    _currentUserProfile = _currentUserProfile!.copyWith(
      notificationPreferences: preferences,
    );
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

/// Helper method to toggle a single category.
Future<void> toggleNotificationCategory(String category, bool enabled) async {
  if (_currentUserProfile == null) return;
  final currentPrefs = Map<String, bool>.from(_currentUserProfile!.notificationPreferences);
  currentPrefs[category] = enabled;
  await updateNotificationPreferences(currentPrefs);
}
```

### UI Integration (`NotificationsPage` settings)
In `lib/views/notifications_page.dart`, we will replace the local `_enabledAlerts` map with state loaded from `AuthProvider`:

#### State Initialization:
```dart
@override
void initState() {
  super.initState();
  _repository = NotificationRepository(Supabase.instance.client);
  _loadNotifications();
  _loadAlertSettings();
}

void _loadAlertSettings() {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final profile = authProvider.currentUserProfile;
  if (profile != null) {
    setState(() {
      _enabledAlerts.addAll(profile.notificationPreferences);
    });
  }
}
```

#### Settings Switch Toggles in `ExpansionTile`:
```dart
onChanged: (val) async {
  setState(() {
    _enabledAlerts[category] = val;
  });
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  await authProvider.toggleNotificationCategory(category, val);
},
```

---

## 2. Notification Trigger Points & Injection Strategy

We propose injecting triggers at the boundaries where domain modifications are successfully written to the database.

### Trigger A: Registration Updates
**Context**: Fired when a user registers for a meet (athlete registration) or applies as a volunteer.
**Category**: `registration`

1. **Meet Athlete Registration**:
   Add a new method `registerForCompetition` to `CompetitionProvider` (`lib/providers/competition_provider.dart`) and corresponding db insert logic in `CompetitionRepository`:
   
   *Provider signature*:
   ```dart
   Future<bool> registerForCompetition({
     required String competitionId,
     required String userId,
   }) async {
     _isLoading = true;
     notifyListeners();
     try {
       // Insert registration record in `meet_registrations`
       final success = await _repository.registerForMeet(
         competitionId: competitionId,
         userId: userId,
         status: 'registered',
       );
       
       if (success) {
         final comp = await getCompetitionById(competitionId);
         final compTitle = comp?.title ?? 'Meet';
         
         // Trigger Registration Notification
         final notification = SystemNotification(
           id: 'notification-reg-${competitionId}-$userId-${DateTime.now().millisecondsSinceEpoch}',
           userId: userId,
           title: 'Registration Successful',
           message: 'You have successfully registered for "$compTitle".',
           category: 'registration',
           createdAt: DateTime.now(),
           isRead: false,
         );
         
         final notificationRepo = NotificationRepository(_repository.client);
         await notificationRepo.createNotification(notification);
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

2. **Volunteer Registration**:
   Inject trigger into the existing `submitVolunteerApplication` method in `CompetitionProvider` right after successful insertion into the database (around line 800):
   
   *Snippet*:
   ```dart
   // ... existing database insert logic ...
   await _repository.client.from('volunteer_applications').insert(payload);
   
   // Trigger Notification
   final comp = await getCompetitionById(competitionId);
   final compTitle = comp?.title ?? 'Meet';
   final notification = SystemNotification(
     id: 'notification-vol-${competitionId}-$userId-${DateTime.now().millisecondsSinceEpoch}',
     userId: userId,
     title: 'Volunteer Application Pending',
     message: 'Your volunteer application for "$compTitle" was submitted.',
     category: 'registration',
     createdAt: DateTime.now(),
     isRead: false,
   );
   await NotificationRepository(_repository.client).createNotification(notification);
   ```

---

### Trigger B: Permission Updates
**Context**: Fired when a volunteer/creator application is approved or rejected.
**Category**: `permissions`

Inject triggers inside `AuthProvider` methods in `lib/providers/auth_provider.dart`:

1. **Approval Trigger** (inside `approvePermissionApplication`, around line 380):
   ```dart
   final app = await _adminRepository.approvePermissionApplication(applicationId);
   if (app != null && app.status == 'approved') {
     // ... existing update permissions logic ...
     
     final typeName = app.type == 'create_competition' ? 'Competition Creator' : 'Association Creator';
     final notification = SystemNotification(
       id: 'notification-perm-appr-${app.id}-${DateTime.now().millisecondsSinceEpoch}',
       userId: app.userId,
       title: 'Permission Approved',
       message: 'Your application for "$typeName" role permissions has been approved.',
       category: 'permissions',
       createdAt: DateTime.now(),
       isRead: false,
     );
     await NotificationRepository(_client).createNotification(notification);
   }
   ```

2. **Rejection Trigger** (inside `rejectPermissionApplication`, around line 410):
   ```dart
   final app = await _adminRepository.rejectPermissionApplication(applicationId);
   if (app != null && app.status == 'rejected') {
     final typeName = app.type == 'create_competition' ? 'Competition Creator' : 'Association Creator';
     final notification = SystemNotification(
       id: 'notification-perm-rej-${app.id}-${DateTime.now().millisecondsSinceEpoch}',
       userId: app.userId,
       title: 'Permission Rejected',
       message: 'Your application for "$typeName" role permissions has been rejected.',
       category: 'permissions',
       createdAt: DateTime.now(),
       isRead: false,
     );
     await NotificationRepository(_client).createNotification(notification);
   }
   ```

---

### Trigger C: Payment Deadlines
**Context**: Fired when a competition requires registration fees upon creation, or when a user registers for a fee-requiring competition.
**Category**: `payments`

1. **Competition Creation with Fees**:
   Inject trigger into `CompetitionProvider.createCompetition(Competition competition)` in `lib/providers/competition_provider.dart` (around line 760):
   
   ```dart
   final created = await _repository.createCompetition(compToCreate);
   if (created != null) {
     _allCompetitions.add(created);
     _applyFilters();
     
     // Trigger creator payment notification if fees are active
     if (created.requiresFees) {
       final notification = SystemNotification(
         id: 'notification-pay-setup-${created.id}-${DateTime.now().millisecondsSinceEpoch}',
         userId: created.associationId != null ? 'assoc-owner-placeholder' : 'admin-placeholder', // fallback to creator
         title: 'Payment Verification Required',
         message: 'Your competition "${created.title}" requires registration fees. Ensure bank details are set.',
         category: 'payments',
         createdAt: DateTime.now(),
         isRead: false,
       );
       await NotificationRepository(_repository.client).createNotification(notification);
     }
   }
   ```

2. **User Registration Fee Deadline**:
   Inject trigger inside the newly defined `registerForCompetition` (see Trigger A) when registration is successful:
   
   ```dart
   if (success && comp != null && comp.requiresFees) {
     final fee = comp.feeAmount != null ? '${comp.feeAmount} ${comp.feeCurrency ?? 'EUR'}' : 'required amount';
     final deadline = comp.paymentEnd ?? comp.registrationEnd;
     final deadlineStr = "${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')}";
     
     final notification = SystemNotification(
       id: 'notification-pay-dl-${competitionId}-$userId-${DateTime.now().millisecondsSinceEpoch}',
       userId: userId,
       title: 'Payment Deadline Reminder',
       message: 'Please pay the fee of $fee by $deadlineStr for your registration at "${comp.title}".',
       category: 'payments',
       createdAt: DateTime.now(),
       isRead: false,
     );
     await NotificationRepository(_repository.client).createNotification(notification);
   }
   ```

---

### Trigger D: Schedule Releases
**Context**: Fired when a staff schedule is published or updated for a meet.
**Category**: `schedule`

Inject trigger inside `CompetitionProvider.publishSchedule` in `lib/providers/competition_provider.dart` (around line 982):

```dart
Future<void> publishSchedule(String competitionId, {bool isPublic = true}) async {
  _isLoading = true;
  notifyListeners();
  try {
    final comp = await _repository.getCompetitionById(competitionId);
    if (comp == null) return;

    // Retrieve all athletes registered for the competition
    final athletes = await _repository.getCompetitionAthletes(competitionId);

    // Trigger notification for each registered athlete
    final notificationRepo = NotificationRepository(_repository.client);
    for (final athlete in athletes) {
      final notification = SystemNotification(
        id: 'notification-sched-${competitionId}-${athlete.id}-${DateTime.now().millisecondsSinceEpoch}',
        userId: athlete.id,
        title: 'Schedule Published',
        message: 'The official event schedule for "${comp.title}" is now available.',
        category: 'schedule',
        createdAt: DateTime.now(),
        isRead: false,
      );
      await notificationRepo.createNotification(notification);
    }
  } catch (e) {
    debugPrint('Error publishing schedule notifications: $e');
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

---

### Trigger E: Flight Listings
**Context**: Fired when flights are balanced/updated by the administrator.
**Category**: `flights`

Inject trigger inside `CompetitionProvider.balanceFlights` in `lib/providers/competition_provider.dart` (around line 965):

```dart
  Future<void> balanceFlights(String competitionId) async {
    final athletes = await _repository.getCompetitionAthletes(competitionId);
    if (athletes.isEmpty) return;
    
    final comp = await _repository.getCompetitionById(competitionId);
    final compTitle = comp?.title ?? 'Meet';
    
    final numFlights = (athletes.length / 12).ceil();
    final athletesPerFlight = (athletes.length / numFlights).ceil();
    
    final notificationRepo = NotificationRepository(_repository.client);
    
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
      
      // Notify each assigned athlete about their new flight assignment
      for (final athleteId in flightAthletes) {
        final notification = SystemNotification(
          id: 'notification-flight-${competitionId}-$athleteId-${DateTime.now().millisecondsSinceEpoch}',
          userId: athleteId,
          title: 'Flight Assigned',
          message: 'You have been assigned to "$flightName" for "$compTitle".',
          category: 'flights',
          createdAt: DateTime.now(),
          isRead: false,
        );
        await notificationRepo.createNotification(notification);
      }
    }
    notifyListeners();
  }
```

---

## 3. Interaction Between Triggers and Preferences

We recommend **Filtering on Display (Option A)** as the primary method:
- All notifications are created and saved in the database table `notifications`.
- The user's preferences are retrieved and parsed in the `Profile` model via `AuthProvider`.
- The `NotificationsPage` retrieves all user notifications but filters them out of view if the user has disabled the category switch settings.
- **Advantage**: If a user temporarily disables a category but re-enables it later, past notifications are not lost. It also avoids complex recipient checking logic inside the background providers.
