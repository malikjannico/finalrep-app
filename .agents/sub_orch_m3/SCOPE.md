# Scope: Milestone 3 - Competition Creation Wizard & Custom Fields

## Architecture
- **Data Models**: Update `Competition` (in `lib/models/competition.dart`) to support R5 fields (verified location details, meet/registration date-times, payment configs, registration mode, social links, athlete/volunteer limits, volunteer positions/shifts, custom fields, disclaimers, banner safe zone flags).
- **State Management**: Update `CompetitionProvider` (in `lib/providers/competition_provider.dart`) to support creating competitions with the new R5 parameters and volunteer applications (including preferences).
- **UI Views**:
  - Implement a new `CreateCompetitionWizard` widget (in `lib/views/competition_creation_wizard.dart`) using a multi-step form stepper.
  - In `lib/views/competition_detail_page.dart` (or as a dialog/page), support the volunteer application flow where users can select multiple roles and arrange preference order.
- **Verification**: Write unit/widget tests in `test/competition_creation_wizard_test.dart` to verify all steps, toggles, validators, and volunteer applications.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Exploration & Planning | Explore models, views, and write implementation details for R5 fields | None | DONE |
| 2 | Implementation | Implement R5 model fields, provider logic, and Wizard UI / Volunteer flow | M1 | DONE |
| 3 | Verification | Write widget and unit tests for the wizard and volunteer flows | M2 | DONE |
| 4 | Audit & Gate | Run Forensic Auditor and verify build/tests pass with clean verdict | M3 | DONE |

## Interface Contracts
### `Competition` (updated model)
- Adds properties for:
  - `registrationStart` (DateTime), `registrationEnd` (DateTime)
  - `requiresFees` (bool), `feeAmount` (double?), `feeCurrency` (String?), `bankDetails` (String?), `paymentDescription` (String?), `paymentStart` (DateTime?), `paymentEnd` (DateTime?)
  - `registrationMode` (String - 'fcfs' or 'approval')
  - `websiteUrl` (String?), `ticketShopUrl` (String?), `socials` (Map<String, String>?)
  - `maxAthletes` (int?), `maxAthletesPerGroup` (Map<String, int>?)
  - `maxVolunteers` (int?), `maxVolunteersPerPosition` (Map<String, int>?)
  - `enableWaitlist` (bool)
  - `volunteerNeeds` (bool), `volunteerPositions` (List<String>?), `volunteerShifts` (Map<String, List<String>>?)
  - `customAthleteFields` (List<Map<String, dynamic>>?), `customVolunteerFields` (List<Map<String, dynamic>>?)
  - `disclaimerText` (String?), `disclaimerUrl` (String?), `disclaimerType` (String - 'text', 'link', 'both', or null)
  - `bannerSafeZoneGuide` (bool)
