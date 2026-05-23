# Project: FinalRep Streetlifting Platform Features

## Architecture
The application is built in Flutter using the **Provider** pattern for state management and **Supabase** for Auth, Database, Storage, and Realtime communication.
- **Views**: UI Layer, contains forms, widgets, and wizards. It is responsive/adaptive (uses `isDesktop` flags).
- **Providers**: Application state controllers extending `ChangeNotifier`. They interact with repositories and notify views of changes.
- **Repositories**: Database abstraction layer mapping to Supabase tables.
- **Models**: Plain Dart classes representing application entities, with JSON serialization/deserialization.
- **Rules Engine**: Stateless algorithms (e.g. Streetlifting attempt validation, judging logic, plate calculator) that compute rules-based outcomes.

## Code Layout
- `lib/models/`: Entity definitions (`profile.dart`, `competition.dart`, `association.dart`, `permission_application.dart`, `notification.dart`, `streetlifting_attempt.dart`)
- `lib/providers/`: State management (`auth_provider.dart`, `competition_provider.dart`, `association_provider.dart`, `notification_provider.dart`)
- `lib/repositories/`: Database interfaces (`profile_repository.dart`, `competition_repository.dart`, `association_repository.dart`, `notification_repository.dart`)
- `lib/views/`: Layout and page navigation views
- `lib/widgets/`: Reusable user components and widgets
- `lib/utils/`: Static helpers and rules engine utilities (`streetlifting_rules_engine.dart`)
- `test/`: Integration, unit, and widget test files

## Milestones
| # | Name | Scope | Dependencies | Status | Conversation ID |
|---|------|-------|--------------|--------|-----------------|
| 1 | Auth & Profile | R1, R2, profile views, dynamic formatting, mobile drawer | None | DONE | 15c0c8a9-8346-4f0c-946c-09ba67080580 |
| 2 | Admin & Associations | R3, R4, admin panel, association wizard, roles | M1 | DONE | 75b80367-8135-44f9-aa4a-80e672fed73b |
| 3 | Competition Wizard | R5, competition stepper, payments, limits, custom fields | M2 | DONE | 45ecf464-e1d1-41aa-9d1e-73a3d02e077d |
| 4 | Streetlifting Engine & Mgmt | H1, rules engine, judging panels, roster, weigh-in, scheduler | M3 | DONE | c5b92702-1974-4379-8ab6-39f96b101876 |
| 5 | Notifications | N1, system notifications, category toggles | M4 | DONE | 76b71873-6dd1-4728-9a8c-ba99e7e73bd3 |
| 6 | E2E Testing Suite | Dual track: design and write E2E test infra and Tiers 1-4 | None | DONE | d3260406-ce8d-48d7-a6d4-78d99c9556fa |
| 7 | Integration & Final Gate | Pass 100% of E2E tests, Phase 2 Adversarial Hardening (Tier 5) | M5, M6 | DONE | 2f3209b1-914f-4376-8681-aabc2cc9f58c |

## Interface Contracts

### AuthProvider & ProfileRepository
- `Future<Profile?> getProfileByUsername(String username)`: Retrieves a user profile by username.
- `Future<void> sendPasswordResetEmail(String emailOrUsername)`: Resolves username to email if needed, then calls reset.

### Association & Competition Management
- `Future<void> createAssociation(Association assoc)`: Inserts new association metadata.
- `Future<void> updateAssociationMemberRole(String associationId, String userId, String role)`: Editor/Owner level permissions updates.

### Streetlifting Rules Engine
- `bool isValidAttemptSequence(double lastWeight, double newWeight)`: Validates ascending weight order (supports 1.25kg increments).
- `PlateSelection calculatePlates(double targetWeight)`: Decomposes target weight into standard weight plates (25kg down to 1.25kg and micro-weights).
- `bool evaluateJudgingVerdict(List<String> votes, String discipline)`: Squats & Dips use 2:1 majority, others require 3:0 unanimity.
