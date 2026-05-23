# Supabase Skill Copied Local

See main instructions in /Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/.agents/skills/supabase/SKILL.md.
Core methodology check:
1. Verify Supabase changes.
2. Enable RLS on every table.
3. Use App metadata, not user_metadata, for role/permission decisions in Postgres if using Postgres auth. But since this is a Flutter/Dart application with in-memory fallbacks, we must model Profile with isCompetitionCreator, isAssociationCreator, isAdmin.
