# Sub-orchestrator Task: Milestone 1 - Auth & Profile Enhancements

## Objective
Implement and verify all requirements under R1 (Login & Forgot Password) and R2 (User Profiles Customization) in the FinalRep Streetlifting application.

## Scope
- **R1. Login & Forgot Password**:
  - Dynamically convert characters in the username field to lowercase on the login page.
  - Verify username in lowercase.
  - Allow either username or email in the forgot password flow (resolving username to email before requesting reset).
- **R2. User Profiles Customization**:
  - Add social media links to profiles and display them with names and icons.
  - Place settings gear icon directly after the full name on "My Profile".
  - Render other profiles inline in desktop layout with banner touching subheader.
  - Position avatar shifted up (half above banner), left-aligned name, username, gender, country below it.
  - Mobile UX: Drawer navigation matching profile tab, Users search header touching viewport top, hide/show username in AppBar depending on scroll.
  - Profile sections: Upcoming/Completed Meets, Highest Rankings, Personal Records.

## Execution Pattern
You must act as a Sub-orchestrator.
1. Create a `SCOPE.md` in your working directory.
2. Run the iteration loop: Explorer → Worker → Reviewer → gate.
3. Verify using tests.
4. When done, write a `handoff.md` report and send a message back to the Project Orchestrator (conversation ID a99aada5-77f3-425e-8c36-b8635bc01363).
