# Handoff Report: Profile Data Models & Repositories

## 1. Observation

- **Profile Model Location**: `lib/models/profile.dart` contains the `Profile` model (lines 1 to 91). It has JSON serialization methods `fromJson` (line 28), `toJson` (line 48), and copy constructor `copyWith` (line 64).
- **Profile Repository Location**: `lib/repositories/profile_repository.dart` handles database updates. The update method uses generic serialisation:
  ```dart
  94: final data = profile.toJson();
  ...
  101: .update(data)
  ```
- **Requirements Context**: `/Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/.agents/sub_orch_m1/SCOPE.md` specifies:
  - Line 8: "sections (PRs, Rankings, Meets)"
  - Line 27: "New field `Map<String, String>? socialLinks`: stores social media channel names and handles/links."
- **Test Status**: Running `flutter test` completes successfully with output `All tests passed!`.
- **Network Mode Restriction**: Executing database queries in tests yields:
  ```
  DB INSPECT ERROR: PostgrestException(message: , code: 400, details: , hint: null)
  ```
  This is due to sandboxed CODE_ONLY network restrictions blocking external network calls to Supabase.

---

## 2. Logic Chain

1. **Social Media Link Representation**: The SCOPE.md requires storing social media channels and handles/links. A `Map<String, String>? socialLinks` field in `Profile` mapped to a Postgres JSONB field `social_links` in the `profiles` table satisfies this requirement cleanly without needing multiple column additions.
2. **Serialization**: In `lib/models/profile.dart`, `fromJson` must extract this map using `Map<String, String>.from(json['social_links'] as Map)`, and `toJson` must include `'social_links': socialLinks` when serializing.
3. **Repository Updates**: Since `ProfileRepository.updateProfile` delegates key-value serialization to `profile.toJson()` and executes updates dynamically, once serialization is updated and a `social_links` column of type `JSONB` is added in Supabase, the repository will automatically support storing/retrieving social links without any changes to its logic.
4. **Meets/Rankings/PRs Sections**: Since there are currently no models or databases representing these concepts (evidenced by search query yielding 0 results for `personal_records` or `rankings` in `lib/`), these must be added:
   - **Meets**: Modeled by a junction table `meet_registrations` (for upcoming meets) and a results table `meet_results` (for completed meets/rankings/scores).
   - **Rankings**: Modeled by a `highest_rankings` table (type, category, rank, score, source meet).
   - **Personal Records (PRs)**: Modeled by a `personal_records` table (discipline, weight, reps, location, is_verified).
5. **Retrieval**: Separate async methods (e.g. `getUserUpcomingMeets`, `getUserPersonalRecords`) must be added to `ProfileRepository` to prevent loading large relational lists during basic profile searches or logins.

---

## 3. Caveats

- **Database Inspection**: We cannot verify the exact remote Supabase table configurations because the network sandbox blocks outgoing HTTP connections to `https://vnseudpajhkicezdcsuj.supabase.co`. We assume the remote database profiles table needs the `social_links` JSONB column added.
- **UI & Layouts**: Desktop/mobile layouts and gear/avatar repositioning constraints (defined in SCOPE.md lines 8-11) are out of scope for this data model & repository analysis and will need UI implementation.

---

## 4. Conclusion

The data models and repositories for R2 (User Profiles Customization) should be configured as follows:
1. **Extend `Profile`**: Add `Map<String, String>? socialLinks`, update `fromJson`, `toJson`, and `copyWith`.
2. **Database Migration**: Run:
   ```sql
   ALTER TABLE public.profiles ADD COLUMN social_links JSONB DEFAULT '{}'::jsonb;
   ```
3. **New Section Tables**: Create tables for `meet_registrations`, `meet_results`, `highest_rankings`, and `personal_records` in Supabase.
4. **New Section Models**: Write corresponding Dart classes (`MeetRegistration`, `MeetResult`, `HighestRanking`, `PersonalRecord`).
5. **Repository Extensions**: Add four async methods in `ProfileRepository` to fetch these sections per user profile ID (using Supabase relational joins where appropriate).

Detailed implementation plans and SQL schemas are recorded in `/Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/.agents/explorer_m1_2/analysis.md`.

---

## 5. Verification Method

- Run the model unit tests: `flutter test test/profile_model_test.dart` to verify serialization behaves correctly with the new mapping.
- Inspect the file `/Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/.agents/explorer_m1_2/analysis.md` for structural consistency.
- Any change to `Profile.toJson()` or database structures must be validated against DB constraints to ensure no column mismatch errors.
