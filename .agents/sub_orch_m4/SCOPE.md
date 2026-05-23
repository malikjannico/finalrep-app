# Scope: Milestone 4 - Streetlifting Rules & Competition Handling

## Architecture
The application is built in Flutter using the **Provider** pattern.
- **Rules Engine**: Stateless logic in `lib/utils/streetlifting_rules_engine.dart` containing attempt sequence validation, plate calculation, and judging verdict rules.
- **Models**:
  - `lib/models/streetlifting_attempt.dart`: Represents a single lift attempt with fields for athlete ID, weight, discipline, attempt number, judge votes, failure reason, and status.
  - Updates to `lib/models/competition.dart` to support slots/schedule, roster, roles, and status.
- **Repositories & Providers**:
  - `lib/repositories/competition_repository.dart` and `lib/providers/competition_provider.dart`: Add roster operations, slots scheduling, bodyweight/DQ, public/private publishing.
- **Views**:
  - `lib/views/competition_handling_page.dart`: Real administration/scoreboard view.
  - Integrate or update `test/e2e/mock_views.dart` / `test/e2e/tier2_boundary_test.dart` to point to the actual implementation.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|--------------|--------|
| 1 | Exploration & Architecture | Explore existing codebase, define database schemas (if any), and design rules engine APIs. | None | DONE |
| 2 | Rules Engine & Models | Implement `streetlifting_rules_engine.dart` and `streetlifting_attempt.dart` with unit tests. | M1 | DONE |
| 3 | Competition Management | Implement roster management, slot scheduling, bodyweight/DQ logic in provider & repo. | M2 | DONE |
| 4 | UI Integration & E2E Validation | Integrate views, make sure all tests in `test/e2e/tier2_boundary_test.dart` and any unit tests pass. | M3 | DONE |

## Interface Contracts
### Streetlifting Rules Engine (`lib/utils/streetlifting_rules_engine.dart`)
- `bool isValidAttemptSequence(double lastWeight, double newWeight, String discipline)`: Validates ascending weight order with correct increments (1.25kg for Muscle Up/Pull Up/Dip, 2.5kg for Squat).
- `PlateSelection calculatePlates(double targetWeight)`: Decomposes target weight into standard weight plates (25kg down to 1.25kg and micro-weights).
- `bool evaluateJudgingVerdict(List<bool> votes, String discipline, String? failureReason)`: Squats & Dips use 2:1 majority for specific errors, others require 3:0 unanimity.
