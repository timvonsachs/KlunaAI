-- Minimal anonymous product analytics for Kluna
-- Run in Supabase SQL Editor

create extension if not exists pgcrypto;

create table if not exists public.app_events (
    id uuid primary key default gen_random_uuid(),
    created_at timestamptz default now(),

    -- Anonymous install token (random UUID, locally generated)
    user_token text not null,

    -- Event name
    event text not null,

    -- Optional event value
    value text,

    -- App version for release diagnostics
    app_version text
);

alter table public.app_events enable row level security;

drop policy if exists "Anyone can insert events" on public.app_events;
create policy "Anyone can insert events"
on public.app_events
for insert
to anon, authenticated
with check (true);

create index if not exists idx_events_event on public.app_events(event);
create index if not exists idx_events_token on public.app_events(user_token);
create index if not exists idx_events_created on public.app_events(created_at);
