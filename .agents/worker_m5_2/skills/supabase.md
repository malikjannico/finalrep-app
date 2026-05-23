# Supabase Skill

## Core Principles

1. Supabase changes frequently — verify against changelog and current docs before implementing.
2. Verify your work.
3. Recover from errors, don't loop.
4. Exposing tables to the Data API.
5. RLS in exposed schemas.
6. Security checklist:
   - Never use `user_metadata` claims in JWT-based authorization decisions.
   - Deleting a user does not invalidate existing access tokens.
   - Never expose the `service_role` or secret key in public clients.
   - Views bypass RLS by default.
   - UPDATE requires a SELECT policy.
   - `auth.role()` is deprecated — use the `TO` clause instead.
   - `TO authenticated` alone is authentication without authorization.
   - UPDATE policies require both `USING` and `WITH CHECK`.
   - `SECURITY DEFINER` functions bypass RLS.
   - Storage upsert requires INSERT + SELECT + UPDATE.
