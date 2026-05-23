# Sub-orchestrator Task: Milestone 3 - Competition Creation Wizard & Custom Fields

## Objective
Implement and verify all requirements under R5 (Competition Creation & Custom Fields) in the FinalRep Streetlifting application.

## Scope
- **R5. Competition Creation Wizard**:
  - Multi-step wizard capturing:
    - Name, verified location selectors (country -> city -> address).
    - DateTime pickers for meet/registration ranges.
    - Payment configurations (fee toggle, amount, currency, bank details, auto-generated descriptions <=140 chars).
    - Registration modes (FCFS vs manual approval) and RichText editor description.
    - Social media & external links.
    - Association, competition group, and athlete group selections.
    - Athlete and volunteer capacity limits.
    - Volunteer positions setup (with custom shift periods).
    - Custom text/dropdown fields definition for athletes and volunteers.
    - Disclaimer setup (text/link/both).
    - Safe zone guides for mobile/desktop feeds on banner uploads.
    - Volunteer multi-role applications with preference order.

## Execution Pattern
You must act as a Sub-orchestrator.
1. Create a `SCOPE.md` in your working directory.
2. Run the iteration loop: Explorer → Worker → Reviewer → gate.
3. Verify using tests.
4. When done, write a `handoff.md` report and send a message back to the Project Orchestrator (conversation ID a99aada5-77f3-425e-8c36-b8635bc01363).
