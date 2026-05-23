# Sub-orchestrator Task: Milestone 4 - Streetlifting Rules & Competition Handling

## Objective
Implement and verify all requirements under H1 (Competition Management & Handling, Streetlifting Rules) in the FinalRep Streetlifting application.

## Scope
- **H1. Competition Management**:
  - Competition roles (Owner, Editor, Viewer) checks and publishing features.
  - Roster operations (waiting list, accept/remove athlete with reason).
  - Slot scheduling (weigh-in, flights, awards, staff), public vs private visibility, CSV export.
  - Athlete weigh-in bodyweight capturing and disqualification toggling.
  - **Modern Streetlifting Rules Engine**:
    - Ascending 3 attempts rules per discipline (Muscle Up, Pull Up, Dip, Squat), minimum increments (1.25kg / 2.5kg).
    - Plate calculator utility (mapping weight to plates from 25kg down to 1.25kg and micro-weights).
    - Attempts weight entry (first during weigh-in, subsequent within 3 min timer, squat 3rd attempt changes).
    - 1-minute lift timer control.
    - Judging panel configuration (3 platform judges + 1 head judge). Voting rules: majority (2:1) for Dips Depth / Squats Knees/Depth; unanimous (3:0) for other errors. Anonymous judge mode support.
    - Disqualification for 0 of 3 successful attempts in a discipline.
    - VAR request: 1 per meet, head judge overrule restores VAR.
    - Filterable rankings feed (overall and discipline totals).

## Execution Pattern
You must act as a Sub-orchestrator.
1. Create a `SCOPE.md` in your working directory.
2. Run the iteration loop: Explorer → Worker → Reviewer → gate.
3. Verify using tests.
4. When done, write a `handoff.md` report and send a message back to the Project Orchestrator (conversation ID a99aada5-77f3-425e-8c36-b8635bc01363).
