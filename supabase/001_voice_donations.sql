-- Kluna Voice Donations schema (full biomarkers + segments)
-- Run in Supabase SQL Editor (project: qncvvovhtojcpfammrlw)

create extension if not exists pgcrypto;

drop table if exists public.voice_segments;
drop table if exists public.voice_donations;

create table public.voice_donations (
    id uuid primary key default gen_random_uuid(),
    created_at timestamptz default now(),

    -- Demography
    age_group text not null,
    gender text not null,
    mood text not null,

    -- Raw features
    f0_mean real,
    f0_range_st real,
    f0_var real,
    f0_std_dev real,
    jitter real,
    shimmer real,
    hnr real,
    f1 real,
    f2 real,
    f3 real,
    f4 real,
    formant_dispersion real,
    speech_rate real,
    articulation_rate real,
    pause_rate real,
    pause_dur real,
    loudness_rms real,
    loudness_rms_original real,
    loudness_std_dev real,
    loudness_dynamic_range real,
    spectral_body_ratio real,
    spectral_warmth_ratio real,
    spectral_presence_ratio real,
    spectral_air_ratio real,

    -- Derived values
    arousal real,
    acoustic_valence real,
    dim_energy real,
    dim_tension real,
    dim_fatigue real,
    dim_warmth real,
    dim_expressiveness real,
    dim_tempo real,
    pillar_voice_quality real,
    pillar_clarity real,
    pillar_dynamics real,
    pillar_rhythm real,
    overall_score real,
    dna_authority real,
    dna_charisma real,
    dna_warmth real,
    dna_composure real,

    -- Baseline comparisons
    arousal_z_score real,
    f0_z_score real,
    jitter_z_score real,
    hnr_z_score real,
    speech_rate_z_score real,
    loudness_z_score real,

    -- Flags + meta
    flags text[],
    duration_seconds real,
    gain_applied real,
    entry_count_at_time int,
    has_baseline boolean default false,
    app_version text default '1.0.0'
);

create table public.voice_segments (
    id uuid primary key default gen_random_uuid(),
    donation_id uuid references public.voice_donations(id) on delete cascade,
    segment_index int not null,
    start_seconds real not null,
    end_seconds real not null,
    f0_mean real,
    f0_range_st real,
    jitter real,
    shimmer real,
    hnr real,
    speech_rate real,
    articulation_rate real,
    pause_rate real,
    pause_dur real,
    loudness_rms real,
    loudness_dynamic_range real,
    f1 real,
    f2 real,
    f3 real,
    f4 real
);

alter table public.voice_donations enable row level security;
alter table public.voice_segments enable row level security;

drop policy if exists "Anyone can donate" on public.voice_donations;
drop policy if exists "Anyone can add segments" on public.voice_segments;
create policy "Anyone can donate"
on public.voice_donations
for insert
to anon, authenticated
with check (true);

create policy "Anyone can add segments"
on public.voice_segments
for insert
to anon, authenticated
with check (true);

create index idx_donations_mood on public.voice_donations(mood);
create index idx_donations_created on public.voice_donations(created_at);
create index idx_segments_donation on public.voice_segments(donation_id);

create or replace view public.global_stats as
select
    count(*) as total_donations,
    count(distinct date(created_at)) as active_days,
    round(avg(dim_energy)::numeric, 3) as avg_energy,
    round(avg(dim_tension)::numeric, 3) as avg_tension,
    round(avg(dim_fatigue)::numeric, 3) as avg_fatigue,
    round(avg(dim_warmth)::numeric, 3) as avg_warmth,
    round(avg(dim_expressiveness)::numeric, 3) as avg_expressiveness,
    round(avg(dim_tempo)::numeric, 3) as avg_tempo,
    -- compatibility aliases used by existing app screens
    round(avg(dim_tension)::numeric, 3) as avg_stability,
    round(avg(dim_expressiveness)::numeric, 3) as avg_openness,
    round(avg(arousal)::numeric, 1) as avg_arousal,
    round(avg(f0_mean)::numeric, 1) as avg_f0,
    round(avg(hnr)::numeric, 2) as avg_hnr,
    round(avg(speech_rate)::numeric, 2) as avg_speech_rate,
    mode() within group (order by mood) as most_common_mood
from public.voice_donations;

grant usage on schema public to anon, authenticated;
grant select on public.global_stats to anon, authenticated;
