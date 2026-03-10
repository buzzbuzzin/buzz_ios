alter table public.profiles
add column if not exists preferred_measurement_system text
check (
  preferred_measurement_system is null
  or preferred_measurement_system = any (array['imperial'::text, 'metric'::text])
);

comment on column public.profiles.preferred_measurement_system is
'Pilot measurement system override. Null means use the region-based default.';
