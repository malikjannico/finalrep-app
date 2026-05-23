# Milestone 7: Integration & Final Gate

Your mission is to perform the final integration, verification, and hardening of all platform features.

## Work Description
1. **Phase 1: E2E and Unit Test Verification (Tiers 1-4)**:
   - Run the full test suite using `flutter test`. Ensure all unit, widget, and E2E tests (including the 30 tests in `test/e2e/` and all other tests in `test/`) compile and pass.
   - Verify that all implemented features (R1-R5, H1, N1) are fully covered and function correctly.

2. **Phase 2: Adversarial Coverage Hardening (Tier 5)**:
   - Spawn Challenger agents to inspect the codebase, find coverage gaps or untested edge cases, write adversarial tests (e.g. in `test/notification_adversarial_test.dart` or other files), and fix any bugs found in the implementation.
   - Ensure the implementation is robust against corner cases, invalid inputs, and unexpected state changes.

3. **Phase 3: Final Forensic Integrity Audit**:
   - Spawn the Forensic Auditor (`teamwork_preview_auditor`) to run a complete, global clean audit.
   - Verify that there are no mock/dummy or facade implementations that bypass verification.
   - Ensure that the auditor's verdict is CLEAN.

## Expected Outputs
- Handoff report (`handoff.md`) detailing the verification steps, test command outputs, coverage hardening results, and Forensic Auditor output.
- All unit, widget, and E2E tests compile and pass.
- Clean Forensic Auditor report.

Once complete, write your handoff report and notify the parent Project Orchestrator.
