-- Conversation-level donation schema (multi-round emotional journeys)
-- Run in Supabase SQL Editor

create extension if not exists pgcrypto;

create table if not exists public.conversations (
    id uuid default gen_random_uuid() primary key,
    created_at timestamptz default now(),

    donor_token text not null,

    age_group text,
    gender text,
    time_of_day text,

    round_count int not null,
    duration_total_seconds real,

    r1_energy real,
    r1_tension real,
    r1_fatigue real,
    r1_warmth real,
    r1_expressiveness real,
    r1_tempo real,
    r1_arousal real,
    r1_mood text,

    final_energy real,
    final_tension real,
    final_fatigue real,
    final_warmth real,
    final_expressiveness real,
    final_tempo real,
    final_arousal real,
    final_mood text,

    delta_energy real,
    delta_tension real,
    delta_fatigue real,
    delta_warmth real,
    delta_expressiveness real,
    delta_tempo real,
    delta_arousal real,

    emotional_direction text,
    had_breakthrough boolean default false,
    contradiction_count int default 0,

    app_version text,
    entry_count_at_time int
);

create table if not exists public.conversation_rounds (
    id uuid default gen_random_uuid() primary key,
    created_at timestamptz default now(),

    conversation_id uuid not null references public.conversations(id) on delete cascade,
    round_index int not null,

    donor_token text not null,

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

    dim_energy real,
    dim_tension real,
    dim_fatigue real,
    dim_warmth real,
    dim_expressiveness real,
    dim_tempo real,

    arousal real,
    mood text,

    delta_energy real,
    delta_tension real,
    delta_fatigue real,
    delta_warmth real,
    delta_expressiveness real,
    delta_tempo real,

    question_asked text,
    question_type text,
    flags text,
    shift_description text,
    hedging_score real,
    distancing_score real,
    duration_seconds real,
    gain_applied real
);

create table if not exists public.question_effectiveness (
    id uuid default gen_random_uuid() primary key,
    created_at timestamptz default now(),

    donor_token text not null,
    conversation_id uuid references public.conversations(id) on delete set null,

    question_text text not null,
    question_type text,

    pre_energy real,
    pre_tension real,
    pre_fatigue real,
    pre_warmth real,
    pre_expressiveness real,
    pre_tempo real,
    pre_arousal real,
    pre_mood text,

    post_energy real,
    post_tension real,
    post_fatigue real,
    post_warmth real,
    post_expressiveness real,
    post_tempo real,
    post_arousal real,
    post_mood text,

    impact_tension real,
    impact_warmth real,
    impact_expressiveness real,
    opening_score real,

    round_index int,
    age_group text,
    gender text,
    time_of_day text
);

alter table public.conversations enable row level security;
alter table public.conversation_rounds enable row level security;
alter table public.question_effectiveness enable row level security;

drop policy if exists "Anyone can insert conversations" on public.conversations;
drop policy if exists "Anyone can insert rounds" on public.conversation_rounds;
drop policy if exists "Anyone can insert effectiveness" on public.question_effectiveness;

create policy "Anyone can insert conversations"
on public.conversations
for insert
to anon, authenticated
with check (true);

create policy "Anyone can insert rounds"
on public.conversation_rounds
for insert
to anon, authenticated
with check (true);

create policy "Anyone can insert effectiveness"
on public.question_effectiveness
for insert
to anon, authenticated
with check (true);

create index if not exists idx_conv_donor on public.conversations(donor_token);
create index if not exists idx_conv_created on public.conversations(created_at);
create index if not exists idx_conv_direction on public.conversations(emotional_direction);

create index if not exists idx_rounds_conv on public.conversation_rounds(conversation_id);
create index if not exists idx_rounds_donor on public.conversation_rounds(donor_token);
create index if not exists idx_rounds_index on public.conversation_rounds(round_index);

create index if not exists idx_qe_question_type on public.question_effectiveness(question_type);
create index if not exists idx_qe_opening on public.question_effectiveness(opening_score);
create index if not exists idx_qe_pre_tension on public.question_effectiveness(pre_tension);

create or replace view public.question_type_effectiveness as
select
    question_type,
    count(*) as times_asked,
    round(avg(opening_score)::numeric, 3) as avg_opening,
    round(avg(impact_tension)::numeric, 3) as avg_tension_change,
    round(avg(impact_warmth)::numeric, 3) as avg_warmth_change,
    round(avg(impact_expressiveness)::numeric, 3) as avg_expressiveness_change
from public.question_effectiveness
group by question_type
order by avg_opening desc;

create or replace view public.breakthrough_conversations as
select
    round_count,
    emotional_direction,
    count(*) as count,
    round(avg(delta_tension)::numeric, 3) as avg_tension_drop,
    round(avg(delta_warmth)::numeric, 3) as avg_warmth_gain
from public.conversations
where had_breakthrough = true
group by round_count, emotional_direction
order by count desc;

create or replace view public.conversation_depth as
select
    round_count,
    count(*) as conversations,
    round(avg(delta_tension)::numeric, 3) as avg_tension_change,
    round(avg(delta_warmth)::numeric, 3) as avg_warmth_change,
    count(*) filter (where had_breakthrough) as breakthroughs
from public.conversations
group by round_count
order by round_count;

create or replace view public.global_stats_v2 as
select
    (select count(*) from public.voice_donations where created_at > now() - interval '24 hours') as donations_today,
    (select count(*) from public.conversations where created_at > now() - interval '24 hours') as conversations_today,
    (select round(avg(round_count)::numeric, 1) from public.conversations where created_at > now() - interval '7 days') as avg_rounds_this_week,
    (select count(*) from public.conversations where had_breakthrough and created_at > now() - interval '7 days') as breakthroughs_this_week,
    (select question_type from public.question_type_effectiveness order by avg_opening desc limit 1) as most_effective_question_type;

grant usage on schema public to anon, authenticated;
grant insert on table public.conversations to anon, authenticated;
grant insert on table public.conversation_rounds to anon, authenticated;
grant insert on table public.question_effectiveness to anon, authenticated;
grant select on table public.conversations to anon, authenticated;
grant select on table public.conversation_rounds to anon, authenticated;
grant select on table public.question_effectiveness to anon, authenticated;
grant select on public.question_type_effectiveness to anon, authenticated;
grant select on public.breakthrough_conversations to anon, authenticated;
grant select on public.conversation_depth to anon, authenticated;
grant select on public.global_stats_v2 to anon, authenticated;
