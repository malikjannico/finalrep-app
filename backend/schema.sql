-- FinalRep Database Schema DDL for Google Cloud SQL (PostgreSQL 15)

-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    gender TEXT,
    country TEXT,
    profile_picture_url TEXT,
    description TEXT,
    color_mode TEXT NOT NULL DEFAULT 'system',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    is_competition_creator BOOLEAN DEFAULT false,
    is_association_creator BOOLEAN DEFAULT false,
    is_admin BOOLEAN DEFAULT false,
    notification_preferences JSONB DEFAULT '{"flights": true, "payments": true, "schedule": true, "permissions": true, "registration": true}'::jsonb,
    social_links JSONB DEFAULT '{}'::jsonb
);

-- 2. Competitions Table
CREATE TABLE IF NOT EXISTS public.competitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    location TEXT NOT NULL,
    sport_type TEXT NOT NULL DEFAULT 'Streetlifting',
    sport_subtype TEXT NOT NULL,
    comp_group_name TEXT,
    status TEXT NOT NULL DEFAULT 'upcoming',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    area TEXT,
    country TEXT,
    city TEXT,
    title_image_url TEXT,
    association_id TEXT,
    competition_group_id TEXT,
    athlete_group_ids JSONB,
    rulebook_url TEXT,
    registration_start TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    registration_end TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    requires_fees BOOLEAN NOT NULL DEFAULT false,
    fee_amount DOUBLE PRECISION,
    fee_currency TEXT,
    bank_details TEXT,
    payment_description TEXT,
    payment_start TIMESTAMP WITH TIME ZONE,
    payment_end TIMESTAMP WITH TIME ZONE,
    registration_mode TEXT NOT NULL DEFAULT 'fcfs',
    website_url TEXT,
    ticket_shop_url TEXT,
    socials JSONB,
    max_athletes INTEGER,
    max_athletes_per_group JSONB,
    max_volunteers INTEGER,
    max_volunteers_per_position JSONB,
    enable_waitlist BOOLEAN NOT NULL DEFAULT false,
    volunteer_needs BOOLEAN NOT NULL DEFAULT false,
    volunteer_positions JSONB,
    volunteer_shifts JSONB,
    custom_athlete_fields JSONB,
    custom_volunteer_fields JSONB,
    disclaimer_text TEXT,
    disclaimer_url TEXT,
    disclaimer_type TEXT,
    banner_safe_zone_guide BOOLEAN NOT NULL DEFAULT false,
    schedule_published BOOLEAN NOT NULL DEFAULT false
);

-- 3. Associations Table
CREATE TABLE IF NOT EXISTS public.associations (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    profile_picture_url TEXT,
    banner_url TEXT,
    scope TEXT NOT NULL DEFAULT 'global',
    area_name TEXT,
    country TEXT,
    website TEXT,
    description TEXT NOT NULL DEFAULT '',
    rulebooks JSONB NOT NULL DEFAULT '{}'::jsonb,
    social_channels JSONB NOT NULL DEFAULT '{}'::jsonb,
    parent_association_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    owner_id TEXT NOT NULL,
    supported_sports JSONB NOT NULL DEFAULT '[]'::jsonb,
    supported_formats JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- 4. Association Members Table
CREATE TABLE IF NOT EXISTS public.association_members (
    id TEXT PRIMARY KEY,
    association_id TEXT NOT NULL REFERENCES public.associations(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'editor',
    custom_title TEXT
);

-- 5. Competition Groups Table
CREATE TABLE IF NOT EXISTS public.competition_groups (
    id TEXT PRIMARY KEY,
    association_id TEXT NOT NULL REFERENCES public.associations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    sport TEXT NOT NULL,
    format TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_athlete_groups_required BOOLEAN NOT NULL DEFAULT false
);

-- 6. Athlete Groups Table
CREATE TABLE IF NOT EXISTS public.athlete_groups (
    id TEXT PRIMARY KEY,
    association_id TEXT NOT NULL REFERENCES public.associations(id) ON DELETE CASCADE,
    competition_group_id TEXT REFERENCES public.competition_groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    sport TEXT NOT NULL,
    format TEXT NOT NULL,
    gender TEXT NOT NULL DEFAULT 'Mixed',
    max_weight DOUBLE PRECISION,
    is_active BOOLEAN NOT NULL DEFAULT true
);

-- 7. Attempts Table
CREATE TABLE IF NOT EXISTS public.attempts (
    id TEXT PRIMARY KEY,
    competition_id UUID NOT NULL REFERENCES public.competitions(id) ON DELETE CASCADE,
    athlete_id TEXT NOT NULL,
    attempt_number INTEGER NOT NULL,
    weight DOUBLE PRECISION NOT NULL,
    discipline TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    judge_votes JSONB NOT NULL DEFAULT '[]'::jsonb,
    failure_reason TEXT,
    var_requested BOOLEAN NOT NULL DEFAULT false
);

-- 8. Flights Table
CREATE TABLE IF NOT EXISTS public.flights (
    id TEXT PRIMARY KEY,
    competition_id UUID NOT NULL REFERENCES public.competitions(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    athlete_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'pending'
);

-- 9. Highest Rankings Table
CREATE TABLE IF NOT EXISTS public.highest_rankings (
    id TEXT PRIMARY KEY,
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    discipline TEXT NOT NULL,
    rank TEXT NOT NULL,
    competition TEXT NOT NULL
);

-- 10. Meet Registrations Table
CREATE TABLE IF NOT EXISTS public.meet_registrations (
    id TEXT PRIMARY KEY,
    competition_id UUID NOT NULL REFERENCES public.competitions(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'registered',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    UNIQUE(profile_id, competition_id)
);

-- 11. Meet Results Table
CREATE TABLE IF NOT EXISTS public.meet_results (
    id TEXT PRIMARY KEY,
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    competition_id UUID NOT NULL REFERENCES public.competitions(id) ON DELETE CASCADE,
    competition_class TEXT,
    total_score DOUBLE PRECISION,
    rank INTEGER,
    best_lifts JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(profile_id, competition_id)
);

-- 12. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    category TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- 13. Permission Applications Table
CREATE TABLE IF NOT EXISTS public.permission_applications (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    type TEXT NOT NULL,
    reason TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- 14. Personal Records Table
CREATE TABLE IF NOT EXISTS public.personal_records (
    id TEXT PRIMARY KEY,
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    lift TEXT NOT NULL,
    weight TEXT NOT NULL,
    date TEXT NOT NULL
);

-- 15. Schedule Items Table
CREATE TABLE IF NOT EXISTS public.schedule_items (
    id TEXT PRIMARY KEY,
    competition_id UUID NOT NULL REFERENCES public.competitions(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    start_date_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date_time TIMESTAMP WITH TIME ZONE NOT NULL,
    assignees JSONB NOT NULL DEFAULT '[]'::jsonb
);

-- 16. Sport Configs Table
CREATE TABLE IF NOT EXISTS public.sport_configs (
    id TEXT PRIMARY KEY,
    config JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- 17. Volunteer Applications Table
CREATE TABLE IF NOT EXISTS public.volunteer_applications (
    id TEXT PRIMARY KEY,
    competition_id UUID NOT NULL REFERENCES public.competitions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    preferred_roles JSONB NOT NULL DEFAULT '[]'::jsonb,
    shift_availability JSONB NOT NULL DEFAULT '{}'::jsonb,
    custom_field_answers JSONB NOT NULL DEFAULT '{}'::jsonb,
    disclaimer_accepted BOOLEAN NOT NULL DEFAULT false,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
