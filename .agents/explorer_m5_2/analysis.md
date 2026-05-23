# System Notifications Integration Strategy

## Executive Summary
This document proposes a design and implementation strategy to integrate system notification triggers and persist user notification category preferences in the FinalRep platform. The core objectives are:
1. **Triggering** notifications across 5 standard categories: `registration`, `permissions`, `payments`, `schedule`, and `flights`.
2. **Persisting** user notification preference flags (opt-in/opt-out) for these categories via the user's profile database entry (in Supabase).
3. **Filtering** notifications dynamically on display based on these stored preferences, with local in-memory fallbacks when offline or unauthenticated.

---

## 1. Database Schema & Migration Proposals

To store notification settings on a per-user basis, we will extend the `profiles` table. Notifications themselves will be written to the existing `notifications` table.

### 1.1 `profiles` Table Column Addition
We propose adding a JSONB column `notification_settings` to the `profiles` table:
```sql
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS notification_settings JSONB DEFAULT '{"registration": true, "permissions": true, "payments": true, "schedule": true, "flights": true}'::jsonb;
```

### 1.2 `notifications` Table Schema (Verification / Setup)
If the `notifications` table does not exist or needs initialization, the following schema is recommended:
```sql
CREATE TABLE IF NOT EXISTS public.notifications (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('registration', 'permissions', 'payments', 'schedule', 'flights')),
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
```

### 1.3 Row-Level Security (RLS) Policies
In accordance with Supabase security guidelines:
- **SELECT / UPDATE (User-specific access control)**:
  ```sql
  ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

  CREATE POLICY "Users can view their own notifications" ON public.notifications
  FOR SELECT TO authenticated
  USING ( (select auth.uid()) = user_id );

  CREATE POLICY "Users can update their own notifications" ON public.notifications
  FOR UPDATE TO authenticated
  USING ( (select auth.uid()) = user_id )
  WITH CHECK ( (select auth.uid()) = user_id );
  ```
- **INSERT (Privileged Client-Side Operations)**:
  Since notifications are triggered client-side by admins, competition creators, or registering users on behalf of others, we must permit inserting notification entries if authenticated:
  ```sql
  CREATE POLICY "Authenticated users can insert notifications" ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK ( true );
  ```

---

## 2. Model Modifications

### 2.1 Profile Model (`lib/models/profile.dart`)
Add `notificationSettings` as a field in the `Profile` model with JSON serialization support:

```dart
// lib/models/profile.dart

class Profile {
  // ... existing fields ...
  final Map<String, bool> notificationSettings;

  Profile({
    // ... existing fields ...
    this.notificationSettings = const {
      'registration': true,
      'permissions': true,
      'payments': true,
      'schedule': true,
      'flights': true,
    },
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      // ... existing fields ...
      notificationSettings: json['notification_settings'] != null
          ? Map<String, bool>.from(json['notification_settings'] as Map)
          : const {
              'registration': true,
              'permissions': true,
              'payments': true,
              'schedule': true,
              'flights': true,
            },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // ... existing fields ...
      'notification_settings': notificationSettings,
    };
  }

  Profile copyWith({
    // ... existing fields ...
    Map<String, bool>? notificationSettings,
  }) {
    return Profile(
      // ... existing fields ...
      notificationSettings: notificationSettings ?? this.notificationSettings,
    );
  }
}
```

---

## 3. Dependency Injection & Repository Linkage

### 3.1 Constructor Injection in Providers
Both `AuthProvider` and `CompetitionProvider` will accept `NotificationRepository` in their constructors:

```dart
// lib/providers/auth_provider.dart
class AuthProvider with ChangeNotifier {
  final SupabaseClient _client;
  final ProfileRepository _profileRepository;
  final AdminRepository _adminRepository;
  final NotificationRepository _notificationRepository; // Add dependency

  AuthProvider(
    this._client,
    this._profileRepository, {
    required AdminRepository adminRepository,
    required NotificationRepository notificationRepository, // Inject here
  })  : _adminRepository = adminRepository,
        _notificationRepository = notificationRepository;
  // ...
}
```

```dart
// lib/providers/competition_provider.dart
class CompetitionProvider with ChangeNotifier {
  final CompetitionRepository _repository;
  final ProfileRepository _profileRepository;
  final AssociationRepository _associationRepository;
  final NotificationRepository _notificationRepository; // Add dependency

  CompetitionProvider(
    this._repository,
    this._profileRepository, {
    required AssociationRepository associationRepository,
    required NotificationRepository notificationRepository, // Inject here
  })  : _associationRepository = associationRepository,
        _notificationRepository = notificationRepository;
  // ...
}
```

### 3.2 Main Initializer (`lib/main.dart`)
Instantiate the `NotificationRepository` and supply it to the providers:
```dart
// lib/main.dart

  final notificationRepository = NotificationRepository(supabase); // Instantiate

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CompetitionProvider(
            competitionRepository,
            profileRepository,
            associationRepository: associationRepository,
            notificationRepository: notificationRepository, // Inject
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            supabase,
            profileRepository,
            adminRepository: adminRepository,
            notificationRepository: notificationRepository, // Inject
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
```

---

## 4. Trigger Injections & Business Logic

### 4.1 Permission Updates
Trigger a notification in `AuthProvider` when an administrator approves or rejects a user's permission application:

```dart
// lib/providers/auth_provider.dart

  Future<PermissionApplication?> approvePermissionApplication(String applicationId) async {
    // ... logic to retrieve application and update database ...
    try {
      final app = await _adminRepository.approvePermissionApplication(applicationId);
      if (app != null && app.status == 'approved') {
        // Automatically promote the user's permissions in the profile database
        final isCompCreator = app.type == 'create_competition' ? true : null;
        final isAssocCreator = app.type == 'create_association' ? true : null;
        await _profileRepository.updatePermissions(
          app.userId,
          isCompetitionCreator: isCompCreator,
          isAssociationCreator: isAssocCreator,
        );

        // TRIGGER NOTIFICATION
        final typeName = app.type == 'create_competition' ? 'Competition Creator' : 'Association Creator';
        await _notificationRepository.createNotification(SystemNotification(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
          userId: app.userId,
          title: 'Permission Approved',
          message: 'Your application for the $typeName permission has been approved.',
          category: 'permissions',
          createdAt: DateTime.now(),
        ));
      }
      return app;
    } catch (e) {
      // ...
    }
  }

  Future<PermissionApplication?> rejectPermissionApplication(String applicationId) async {
    // ... logic to reject in DB ...
    try {
      final app = await _adminRepository.rejectPermissionApplication(applicationId);
      if (app != null && app.status == 'rejected') {
        // TRIGGER NOTIFICATION
        final typeName = app.type == 'create_competition' ? 'Competition Creator' : 'Association Creator';
        await _notificationRepository.createNotification(SystemNotification(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
          userId: app.userId,
          title: 'Permission Rejected',
          message: 'Your application for the $typeName permission has been rejected.',
          category: 'permissions',
          createdAt: DateTime.now(),
        ));
      }
      return app;
    } catch (e) {
      // ...
    }
  }
```

### 4.2 Schedule Releases
Trigger notifications under the `schedule` category in `CompetitionProvider.publishSchedule` for all registered athletes:

```dart
// lib/providers/competition_provider.dart

  Future<void> publishSchedule(String competitionId, {bool isPublic = true}) async {
    // ... existing logic ...
    try {
      final comp = await _repository.getCompetitionById(competitionId);
      if (comp != null) {
        final athletes = await _repository.getCompetitionAthletes(competitionId);
        for (final athlete in athletes) {
          await _notificationRepository.createNotification(SystemNotification(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}-${athlete.id}',
            userId: athlete.id,
            title: 'Schedule Released',
            message: 'The competition schedule for "${comp.title}" has been published.',
            category: 'schedule',
            createdAt: DateTime.now(),
          ));
        }
      }
    } catch (e) {
      debugPrint('Error triggering schedule release notifications: $e');
    }
    notifyListeners();
  }
```

### 4.3 Flight Listings
Trigger notifications under the `flights` category in `CompetitionProvider.balanceFlights` for all registered athletes:

```dart
// lib/providers/competition_provider.dart

  Future<void> balanceFlights(String competitionId) async {
    // ... existing balancing/insertion logic ...
    try {
      final comp = await _repository.getCompetitionById(competitionId);
      if (comp != null) {
        final athletes = await _repository.getCompetitionAthletes(competitionId);
        for (final athlete in athletes) {
          await _notificationRepository.createNotification(SystemNotification(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}-${athlete.id}',
            userId: athlete.id,
            title: 'Flights Released',
            message: 'Flights have been balanced for the competition "${comp.title}". Check your flight group assignment.',
            category: 'flights',
            createdAt: DateTime.now(),
          ));
        }
      }
    } catch (e) {
      debugPrint('Error triggering flight listing notifications: $e');
    }
    notifyListeners();
  }
```

### 4.4 Athlete Registration & Payment Deadlines
Since registering as an athlete is not fully implemented (currently stubs out in UI snackbars), we must build the provider methods in `CompetitionProvider` to register a user, trigger a registration notification, and trigger a payment reminder if fees are required.

```dart
// lib/providers/competition_provider.dart

  Future<bool> registerAthlete(String competitionId, String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // 1. Write registration record to the db
      await _repository.client.from('meet_registrations').insert({
        'competition_id': competitionId,
        'profile_id': userId,
        'status': 'registered',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      final comp = await _repository.getCompetitionById(competitionId);
      if (comp != null) {
        // 2. TRIGGER REGISTRATION NOTIFICATION
        await _notificationRepository.createNotification(SystemNotification(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}-reg',
          userId: userId,
          title: 'Meet Registration Successful',
          message: 'You have registered for the competition "${comp.title}".',
          category: 'registration',
          createdAt: DateTime.now(),
        ));

        // 3. TRIGGER PAYMENT REMINDER (if registration requires fees)
        if (comp.requiresFees && comp.feeAmount != null) {
          final deadlineStr = comp.paymentEnd != null 
              ? comp.paymentEnd!.toIso8601String().substring(0, 10) 
              : 'the deadline';
          await _notificationRepository.createNotification(SystemNotification(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}-pay',
            userId: userId,
            title: 'Payment Reminder',
            message: 'Please pay the registration fee of ${comp.feeAmount} ${comp.feeCurrency ?? 'EUR'} by $deadlineStr.',
            category: 'payments',
            createdAt: DateTime.now(),
          ));
        }
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
```

If a Competition is created that requires fees, we also send a payments notification to the competition creator:
```dart
// lib/providers/competition_provider.dart -> createCompetition

  Future<Competition?> createCompetition(Competition competition) async {
    // ... existing logic to create competition ...
    if (created != null && created.requiresFees) {
      await _notificationRepository.createNotification(SystemNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}-owner-pay',
        userId: created.id, // Or target organizer's profile ID
        title: 'Payment Setup Required',
        message: 'Your competition "${created.title}" requires fees. Ensure your bank details are set.',
        category: 'payments',
        createdAt: DateTime.now(),
      ));
    }
  }
```

---

## 5. Persistence and Filtering of Notification Settings

### 5.1 Setting State Management in `AuthProvider`
Add a method inside `AuthProvider` to update the notification settings in the user's profile and persist to the database:

```dart
// lib/providers/auth_provider.dart

  Future<void> updateNotificationSettings(String category, bool enabled) async {
    if (_currentUserProfile == null) return;

    final updatedSettings = Map<String, bool>.from(_currentUserProfile!.notificationSettings);
    updatedSettings[category] = enabled;

    final updatedProfile = _currentUserProfile!.copyWith(
      notificationSettings: updatedSettings,
    );

    // Call ProfileRepository to write changes to Supabase 'profiles' table
    final savedProfile = await _profileRepository.updateProfile(updatedProfile);
    if (savedProfile != null) {
      _currentUserProfile = savedProfile;
      notifyListeners();
    }
  }
```

*Note on Local Fallbacks*: If `updateProfile` fails (e.g. offline/mocked Database), we gracefully fall back to updating the local `_currentUserProfile` state in-memory so the settings page reflects changes for the remainder of the session.

### 5.2 Connecting UI to Persistent Settings (`lib/views/notifications_page.dart`)
Initialize and bind the UI switches in `NotificationsPage` to the user's persisted profile settings:

```dart
// lib/views/notifications_page.dart

class _NotificationsPageState extends State<NotificationsPage> {
  // ...
  final Map<String, bool> _enabledAlerts = {
    'registration': true,
    'permissions': true,
    'payments': true,
    'schedule': true,
    'flights': true,
  };

  @override
  void initState() {
    super.initState();
    _repository = NotificationRepository(Supabase.instance.client);
    _loadNotifications();
    
    // Load persisted settings from AuthProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && authProvider.currentUserProfile != null) {
        setState(() {
          _enabledAlerts.addAll(authProvider.currentUserProfile!.notificationSettings);
        });
      }
    });
  }
  
  // Inside settings switch build:
  Switch(
    value: _enabledAlerts[category] ?? true,
    onChanged: (val) async {
      setState(() {
        _enabledAlerts[category] = val;
      });
      // Persist the change
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        await authProvider.updateNotificationSettings(category, val);
      }
    },
  )
}
```

---

## 6. Implementation Sequence & Instructions for Implementer

1. **Database Migration**: Run the migration query to add the `notification_settings` column to the `profiles` table, configure the check constraints and defaults on `notifications`, and enable RLS policies.
2. **Model Update**: Update the `Profile` model's fields, constructors, JSON functions, and `copyWith` to handle `notificationSettings`.
3. **Provider Initialization**: Update the constructors of `AuthProvider` and `CompetitionProvider` to take `NotificationRepository`. Pass the instance in `main.dart`.
4. **Trigger Injections**: Inject notification creations in the target methods (`approvePermissionApplication`, `rejectPermissionApplication`, `publishSchedule`, `balanceFlights`, `registerAthlete`).
5. **Persisted Settings Method**: Add the `updateNotificationSettings` method to `AuthProvider` to save settings modifications to the DB (via `ProfileRepository.updateProfile`).
6. **UI Integration**: Update `NotificationsPage` to initialize switches from `AuthProvider.currentUserProfile.notificationSettings` and dispatch setting updates on change.
7. **Verification**: Run unit or widget tests to ensure notification category filtering works correctly.
