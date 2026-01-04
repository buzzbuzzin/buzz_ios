-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.availability_blockouts (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  start_date timestamp with time zone NOT NULL,
  end_date timestamp with time zone NOT NULL,
  recurrence_type text NOT NULL DEFAULT 'none'::text CHECK (recurrence_type = ANY (ARRAY['none'::text, 'daily'::text, 'weekly'::text, 'weekdays'::text, 'weekends'::text, 'monthly'::text])),
  recurrence_end_date timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  label text,
  CONSTRAINT availability_blockouts_pkey PRIMARY KEY (id),
  CONSTRAINT availability_blockouts_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.badges (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  course_id uuid,
  course_title text,
  course_category text,
  provider text NOT NULL CHECK (provider = ANY (ARRAY['Buzz'::text, 'Amazon'::text, 'T-Mobile'::text, 'Other'::text])),
  earned_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  expires_at timestamp with time zone,
  is_recurrent boolean NOT NULL DEFAULT false,
  badge_type text DEFAULT 'course'::text CHECK (badge_type = ANY (ARRAY['course'::text, 'ex_military'::text, 'buzz'::text, 'government_employee'::text, 'faa'::text, 'flight_reviewer'::text, 'roc_a_examiner'::text, 'beacon_volunteer'::text])),
  CONSTRAINT badges_pkey PRIMARY KEY (id),
  CONSTRAINT badges_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT badges_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id)
);
CREATE TABLE public.badges_catalog (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  badge_type text NOT NULL CHECK (badge_type = ANY (ARRAY['course'::text, 'ex_military'::text, 'buzz'::text, 'government_employee'::text, 'faa'::text, 'flight_reviewer'::text, 'roc_a_examiner'::text, 'beacon_volunteer'::text])),
  title text NOT NULL,
  category text,
  course_id uuid,
  icon_name text NOT NULL,
  color_name text NOT NULL DEFAULT 'blue'::text,
  provider text NOT NULL DEFAULT 'Buzz'::text CHECK (provider = ANY (ARRAY['Buzz'::text, 'Amazon'::text, 'T-Mobile'::text, 'Other'::text])),
  is_recurrent boolean DEFAULT false,
  is_active boolean DEFAULT true,
  display_order integer DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT badges_catalog_pkey PRIMARY KEY (id),
  CONSTRAINT badges_catalog_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id)
);
CREATE TABLE public.beacon_training_progress (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  training_type text NOT NULL CHECK (training_type = ANY (ARRAY['cpr'::text, 'firefighting'::text])),
  certificate_url text NOT NULL,
  uploaded_at timestamp with time zone DEFAULT now(),
  verified boolean DEFAULT false,
  verified_at timestamp with time zone,
  verified_by uuid,
  CONSTRAINT beacon_training_progress_pkey PRIMARY KEY (id),
  CONSTRAINT beacon_training_progress_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT beacon_training_progress_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.beacon_volunteers (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL UNIQUE,
  enrolled_at timestamp with time zone DEFAULT now(),
  is_available boolean DEFAULT true,
  last_location_lat double precision,
  last_location_lng double precision,
  last_location_update timestamp with time zone,
  notification_radius_miles integer DEFAULT 25,
  total_missions_completed integer DEFAULT 0,
  total_hours_volunteered double precision DEFAULT 0,
  people_helped integer DEFAULT 0,
  CONSTRAINT beacon_volunteers_pkey PRIMARY KEY (id),
  CONSTRAINT beacon_volunteers_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.booking_checklists (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  booking_id uuid NOT NULL UNIQUE,
  has_insurance boolean DEFAULT false,
  has_flight_plan boolean DEFAULT false,
  has_faa_waiver boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT booking_checklists_pkey PRIMARY KEY (id),
  CONSTRAINT booking_checklists_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id)
);
CREATE TABLE public.booking_crew (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  booking_id uuid NOT NULL,
  pilot_id uuid NOT NULL,
  role text NOT NULL CHECK (role = ANY (ARRAY['lead'::text, 'crew'::text])),
  rank_at_acceptance integer NOT NULL CHECK (rank_at_acceptance >= 1 AND rank_at_acceptance <= 4),
  payout_amount numeric NOT NULL,
  transfer_id text,
  joined_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT booking_crew_pkey PRIMARY KEY (id),
  CONSTRAINT booking_crew_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id),
  CONSTRAINT booking_crew_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.booking_editors (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  booking_id uuid NOT NULL,
  editor_id uuid NOT NULL,
  assigned_by uuid,
  assigned_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT booking_editors_pkey PRIMARY KEY (id),
  CONSTRAINT booking_editors_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id),
  CONSTRAINT booking_editors_editor_id_fkey FOREIGN KEY (editor_id) REFERENCES public.profiles(id),
  CONSTRAINT booking_editors_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.booking_media_files (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  booking_id uuid NOT NULL,
  uploaded_by uuid NOT NULL,
  role text NOT NULL CHECK (role = ANY (ARRAY['pilot'::text, 'editor'::text, 'system'::text])),
  kind text NOT NULL DEFAULT 'raw'::text CHECK (kind = ANY (ARRAY['raw'::text, 'proxy'::text, 'final'::text, 'notes'::text])),
  storage_path text NOT NULL,
  file_name text,
  file_size bigint,
  mime_type text,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT booking_media_files_pkey PRIMARY KEY (id),
  CONSTRAINT booking_media_files_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id),
  CONSTRAINT booking_media_files_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.bookings (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  customer_id uuid NOT NULL,
  pilot_id uuid,
  location_lat double precision NOT NULL,
  location_lng double precision NOT NULL,
  location_name text NOT NULL,
  description text NOT NULL,
  payment_amount numeric NOT NULL,
  status text NOT NULL DEFAULT 'available'::text CHECK (status = ANY (ARRAY['available'::text, 'accepted'::text, 'completed'::text, 'cancelled'::text])),
  estimated_flight_hours double precision,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  scheduled_date timestamp with time zone,
  specialization text CHECK (specialization IS NULL OR (specialization = ANY (ARRAY['automotive'::text, 'motion_picture'::text, 'real_estate'::text, 'agriculture'::text, 'inspections'::text, 'search_rescue'::text, 'logistics'::text, 'drone_art'::text, 'surveillance_security'::text]))),
  tip_amount numeric DEFAULT 0,
  pilot_rated boolean DEFAULT false,
  customer_rated boolean DEFAULT false,
  payment_intent_id text,
  transfer_id text,
  charge_id text,
  end_date timestamp with time zone,
  required_minimum_rank integer DEFAULT 0,
  customer_completed boolean DEFAULT false,
  pilot_completed boolean DEFAULT false,
  completed_at timestamp with time zone,
  original_amount numeric,
  credits_applied numeric DEFAULT 0,
  final_amount numeric,
  is_internal_test boolean NOT NULL DEFAULT false,
  is_voluntary boolean DEFAULT false,
  hourly_rate numeric DEFAULT 0,
  final_hours_worked double precision,
  assignment_type text CHECK (assignment_type IS NULL OR (assignment_type = ANY (ARRAY['ground_search'::text, 'air_search'::text, 'water_rescue'::text, 'medical_emergency'::text, 'fire_emergency'::text, 'disaster_response'::text, 'missing_person'::text]))),
  government_agency text CHECK (government_agency IS NULL OR (government_agency = ANY (ARRAY['police_department'::text, 'fire_department'::text, 'sheriff_office'::text, 'state_emergency_management'::text]))),
  uses_beacon_program boolean DEFAULT false,
  number_of_pilots integer DEFAULT 1,
  CONSTRAINT bookings_pkey PRIMARY KEY (id),
  CONSTRAINT bookings_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.profiles(id),
  CONSTRAINT bookings_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.course_enrollments (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  course_id uuid NOT NULL,
  enrolled_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  completed_at timestamp with time zone,
  progress_percentage integer DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
  CONSTRAINT course_enrollments_pkey PRIMARY KEY (id),
  CONSTRAINT course_enrollments_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT course_enrollments_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id)
);
CREATE TABLE public.course_sections (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  course_id uuid NOT NULL,
  name text NOT NULL,
  display_order integer NOT NULL,
  description text,
  section_type text DEFAULT 'units'::text,
  requires_subscription boolean DEFAULT false,
  requires_test_passed boolean DEFAULT false,
  prerequisite_section_id uuid,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  exam_type text CHECK (exam_type IS NULL OR (exam_type = ANY (ARRAY['flight_review'::text, 'roc_a'::text]))),
  CONSTRAINT course_sections_pkey PRIMARY KEY (id),
  CONSTRAINT course_sections_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id),
  CONSTRAINT course_sections_prerequisite_fkey FOREIGN KEY (prerequisite_section_id) REFERENCES public.course_sections(id)
);
CREATE TABLE public.course_subscriptions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  course_id uuid NOT NULL,
  stripe_subscription_id text,
  stripe_price_id text,
  status text NOT NULL DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'canceled'::text, 'past_due'::text, 'incomplete'::text, 'trialing'::text])),
  current_period_start timestamp with time zone,
  current_period_end timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT course_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT course_subscriptions_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT course_subscriptions_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id)
);
CREATE TABLE public.course_tests (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  course_id uuid NOT NULL,
  test_name text NOT NULL,
  test_description text,
  test_type text NOT NULL DEFAULT 'multiple_choice'::text CHECK (test_type = ANY (ARRAY['multiple_choice'::text, 'practical'::text, 'written'::text, 'oral'::text])),
  passing_score integer NOT NULL DEFAULT 70 CHECK (passing_score >= 0 AND passing_score <= 100),
  required_for_progression boolean DEFAULT true,
  required_units ARRAY,
  order_index integer NOT NULL DEFAULT 0,
  questions jsonb,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT course_tests_pkey PRIMARY KEY (id),
  CONSTRAINT course_tests_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id)
);
CREATE TABLE public.course_units (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  course_id uuid NOT NULL,
  unit_number integer NOT NULL,
  title text NOT NULL,
  description text,
  content text,
  step_number integer,
  is_mandatory boolean DEFAULT false,
  order_index integer NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  pdf_url jsonb,
  section_id uuid,
  CONSTRAINT course_units_pkey PRIMARY KEY (id),
  CONSTRAINT course_units_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id),
  CONSTRAINT course_units_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.course_sections(id)
);
CREATE TABLE public.device_tokens (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  token text NOT NULL,
  platform text NOT NULL DEFAULT 'ios'::text CHECK (platform = ANY (ARRAY['ios'::text, 'android'::text])),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT device_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT device_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.direct_messages (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  from_user_id uuid NOT NULL,
  to_user_id uuid NOT NULL,
  text text NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  deleted_at timestamp with time zone,
  deleted_by uuid,
  CONSTRAINT direct_messages_pkey PRIMARY KEY (id),
  CONSTRAINT direct_messages_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES public.profiles(id),
  CONSTRAINT direct_messages_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES public.profiles(id),
  CONSTRAINT direct_messages_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.drone_registrations (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  file_url text NOT NULL,
  file_type text NOT NULL CHECK (file_type = ANY (ARRAY['pdf'::text, 'image'::text])),
  uploaded_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  registered_owner text,
  manufacturer text,
  model text,
  serial_number text,
  registration_number text,
  issued text,
  expires text,
  CONSTRAINT drone_registrations_pkey PRIMARY KEY (id),
  CONSTRAINT drone_registrations_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.email_change_tokens (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  old_email text NOT NULL,
  new_email text NOT NULL,
  token text NOT NULL CHECK (token ~ '^\d{6}$'::text),
  verified boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  expires_at timestamp with time zone NOT NULL,
  CONSTRAINT email_change_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT email_change_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.employee_profiles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  role text NOT NULL DEFAULT 'employee'::text CHECK (role = ANY (ARRAY['employee'::text, 'editor'::text, 'admin'::text, 'owner'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  name text,
  CONSTRAINT employee_profiles_pkey PRIMARY KEY (id)
);
CREATE TABLE public.exam_appointments (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  exam_type text NOT NULL CHECK (exam_type = ANY (ARRAY['flight_review'::text, 'roc_a'::text])),
  scheduled_date timestamp with time zone NOT NULL,
  duration_minutes integer NOT NULL DEFAULT 15,
  location_type text NOT NULL CHECK (location_type = ANY (ARRAY['in_person'::text, 'online'::text])),
  location_address text,
  meeting_link text,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'completed'::text, 'cancelled'::text])),
  stripe_payment_intent_id text,
  stripe_charge_id text,
  payment_amount numeric NOT NULL,
  notes text,
  examiner_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  zoom_meeting_id text,
  zoom_meeting_password text,
  CONSTRAINT exam_appointments_pkey PRIMARY KEY (id),
  CONSTRAINT exam_appointments_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT exam_appointments_examiner_id_fkey FOREIGN KEY (examiner_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.exam_type_config (
  exam_type text NOT NULL CHECK (exam_type = ANY (ARRAY['flight_review'::text, 'roc_a'::text])),
  display_name text NOT NULL,
  short_description text NOT NULL,
  full_description text NOT NULL,
  icon text NOT NULL,
  duration_minutes integer NOT NULL DEFAULT 30,
  allows_online boolean NOT NULL DEFAULT false,
  stripe_product_id text NOT NULL,
  prerequisites jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT exam_type_config_pkey PRIMARY KEY (exam_type)
);
CREATE TABLE public.express_promotion_applications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  pilot_id uuid NOT NULL,
  promotion_type text NOT NULL CHECK (promotion_type = ANY (ARRAY['lieutenant'::text, 'commander'::text])),
  document_type text NOT NULL CHECK (document_type = ANY (ARRAY['aviation_degree'::text, 'ppl'::text, 'ground_school_test'::text])),
  document_urls ARRAY NOT NULL DEFAULT '{}'::text[],
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'in_review'::text, 'verified'::text, 'rejected'::text])),
  target_tier integer NOT NULL CHECK (target_tier = ANY (ARRAY[2, 3])),
  submitted_at timestamp with time zone NOT NULL DEFAULT now(),
  reviewed_at timestamp with time zone,
  reviewed_by uuid,
  rejection_reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT express_promotion_applications_pkey PRIMARY KEY (id),
  CONSTRAINT express_promotion_applications_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT express_promotion_applications_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.flight_logs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  aircraft_number text NOT NULL,
  sheet_number integer NOT NULL DEFAULT 1,
  description_of_flight text NOT NULL,
  date timestamp with time zone NOT NULL,
  time_out timestamp with time zone NOT NULL,
  time_in timestamp with time zone NOT NULL,
  total_airtime_minutes integer NOT NULL,
  comments text,
  signature_data text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  is_locked boolean DEFAULT true,
  CONSTRAINT flight_logs_pkey PRIMARY KEY (id),
  CONSTRAINT flight_logs_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.government_ids (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL UNIQUE,
  file_url text,
  file_type text CHECK (file_type = ANY (ARRAY['pdf'::text, 'image'::text])),
  verification_status text NOT NULL DEFAULT 'pending'::text CHECK (verification_status = ANY (ARRAY['pending'::text, 'verified'::text, 'rejected'::text])),
  stripe_session_id text,
  uploaded_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT government_ids_pkey PRIMARY KEY (id),
  CONSTRAINT government_ids_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.ground_school_test_results (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  course_id uuid NOT NULL,
  score integer NOT NULL CHECK (score >= 0 AND score <= 100),
  passed boolean NOT NULL DEFAULT false,
  answers jsonb,
  completed_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT ground_school_test_results_pkey PRIMARY KEY (id),
  CONSTRAINT ground_school_test_results_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT ground_school_test_results_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id)
);
CREATE TABLE public.incident_logs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  booking_id uuid NOT NULL,
  pilot_id uuid NOT NULL,
  name text NOT NULL,
  phone_number text NOT NULL,
  date_of_incident timestamp with time zone NOT NULL,
  date_of_report timestamp with time zone NOT NULL,
  job_title text,
  operation_name text,
  organization text,
  pic text,
  region text,
  airspace_class text,
  reported_to_police boolean DEFAULT false,
  reported_to_atc boolean DEFAULT false,
  location_of_incident text NOT NULL,
  description_of_incident text NOT NULL,
  name_of_witness text,
  signature_data text NOT NULL,
  signature_date timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  is_locked boolean DEFAULT true,
  CONSTRAINT incident_logs_pkey PRIMARY KEY (id),
  CONSTRAINT incident_logs_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id),
  CONSTRAINT incident_logs_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.maintenance_logs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  aircraft_number text NOT NULL,
  sheet_number integer NOT NULL DEFAULT 1,
  date timestamp with time zone NOT NULL,
  repairs text NOT NULL,
  replacement_parts text,
  comments text,
  initials_data text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  is_locked boolean DEFAULT true,
  CONSTRAINT maintenance_logs_pkey PRIMARY KEY (id),
  CONSTRAINT maintenance_logs_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.messages (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  booking_id uuid NOT NULL,
  from_user_id uuid NOT NULL,
  to_user_id uuid NOT NULL,
  text text NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  deleted_at timestamp with time zone,
  deleted_by uuid,
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id),
  CONSTRAINT messages_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES public.profiles(id),
  CONSTRAINT messages_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES public.profiles(id),
  CONSTRAINT messages_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.pilot_licenses (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  file_url text NOT NULL,
  file_type text NOT NULL CHECK (file_type = ANY (ARRAY['pdf'::text, 'image'::text])),
  uploaded_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  name text,
  course_completed text,
  completion_date text,
  certificate_number text,
  license_type text,
  CONSTRAINT pilot_licenses_pkey PRIMARY KEY (id),
  CONSTRAINT pilot_licenses_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.pilot_stats (
  pilot_id uuid NOT NULL,
  total_flight_hours double precision NOT NULL DEFAULT 0.0,
  completed_bookings integer NOT NULL DEFAULT 0,
  tier integer NOT NULL DEFAULT 0 CHECK (tier >= 0 AND tier <= 10),
  CONSTRAINT pilot_stats_pkey PRIMARY KEY (pilot_id),
  CONSTRAINT pilot_stats_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  user_type text NOT NULL CHECK (user_type = ANY (ARRAY['pilot'::text, 'customer'::text])),
  call_sign text CHECK (call_sign IS NULL OR call_sign ~ '^[A-Z]+$'::text),
  email text,
  phone text,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  first_name text,
  last_name text,
  profile_picture_url text,
  communication_preference text DEFAULT 'email'::text CHECK (communication_preference = ANY (ARRAY['email'::text, 'text'::text, 'both'::text])),
  stripe_account_id text,
  balance numeric DEFAULT 0.0,
  role text CHECK (role IS NULL OR (role = ANY (ARRAY['individual'::text, 'company'::text, 'government'::text, 'non_profit'::text]))),
  specialization text CHECK (specialization IS NULL OR (specialization = ANY (ARRAY['automotive'::text, 'motion_picture'::text, 'real_estate'::text, 'agriculture'::text, 'inspections'::text, 'search_rescue'::text, 'logistics'::text, 'drone_art'::text, 'surveillance_security'::text, 'mapping_surveying'::text]))),
  is_ex_military boolean DEFAULT false,
  is_government_employee boolean DEFAULT false,
  has_faa_certification boolean DEFAULT false,
  is_buzz_affiliate boolean DEFAULT false,
  veteran_service_name text,
  veteran_service_country text,
  veteran_military_branch text,
  veteran_service_number text,
  last_location_lat double precision,
  last_location_lng double precision,
  last_location_update timestamp with time zone,
  referral_credits numeric DEFAULT 0.0,
  referred_by uuid,
  is_beacon_volunteer boolean DEFAULT false,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id),
  CONSTRAINT profiles_referred_by_fkey FOREIGN KEY (referred_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.ratings (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  booking_id uuid NOT NULL,
  from_user_id uuid NOT NULL,
  to_user_id uuid NOT NULL,
  rating integer NOT NULL CHECK (rating >= 0 AND rating <= 5),
  comment text,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT ratings_pkey PRIMARY KEY (id),
  CONSTRAINT ratings_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id),
  CONSTRAINT ratings_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES public.profiles(id),
  CONSTRAINT ratings_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.referral_codes (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL UNIQUE,
  code text NOT NULL UNIQUE CHECK (code ~ '^[A-Z0-9]{8}$'::text),
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT referral_codes_pkey PRIMARY KEY (id),
  CONSTRAINT referral_codes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.referrals (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  referrer_id uuid NOT NULL,
  referee_id uuid NOT NULL UNIQUE,
  referral_code text NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'completed'::text, 'expired'::text])),
  credit_amount numeric NOT NULL DEFAULT 25.0,
  credited_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT referrals_pkey PRIMARY KEY (id),
  CONSTRAINT referrals_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES public.profiles(id),
  CONSTRAINT referrals_referee_id_fkey FOREIGN KEY (referee_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.test_results (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  test_id uuid NOT NULL,
  course_id uuid NOT NULL,
  score integer NOT NULL CHECK (score >= 0 AND score <= 100),
  passed boolean NOT NULL DEFAULT false,
  answers jsonb,
  attempt_number integer DEFAULT 1,
  completed_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT test_results_pkey PRIMARY KEY (id),
  CONSTRAINT test_results_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT test_results_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.course_tests(id),
  CONSTRAINT test_results_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id)
);
CREATE TABLE public.topgun_pilots (
  pilot_id uuid NOT NULL,
  championship_score integer,
  selected_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT topgun_pilots_pkey PRIMARY KEY (pilot_id),
  CONSTRAINT topgun_pilots_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.training_courses (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  title text NOT NULL,
  description text NOT NULL,
  duration text NOT NULL,
  level text NOT NULL CHECK (level = ANY (ARRAY['Beginner'::text, 'Intermediate'::text, 'Advanced'::text])),
  category text NOT NULL CHECK (category = ANY (ARRAY['Safety & Regulations'::text, 'Flight Operations'::text, 'Aerial Photography'::text, 'Cinematography'::text, 'Inspections'::text, 'Mapping & Surveying'::text])),
  instructor text NOT NULL,
  rating double precision DEFAULT 0.0,
  students_count integer DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  provider text DEFAULT 'Buzz'::text CHECK (provider = ANY (ARRAY['Buzz'::text, 'Amazon'::text, 'T-Mobile'::text, 'Other'::text])),
  instructor_picture_url text,
  CONSTRAINT training_courses_pkey PRIMARY KEY (id)
);
CREATE TABLE public.transponders (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  device_name text NOT NULL,
  remote_id text NOT NULL,
  is_location_tracking_enabled boolean NOT NULL DEFAULT false,
  last_location_lat double precision,
  last_location_lng double precision,
  last_location_update timestamp with time zone,
  speed double precision,
  altitude double precision,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT transponders_pkey PRIMARY KEY (id),
  CONSTRAINT transponders_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.unit_completions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  unit_id uuid NOT NULL,
  course_id uuid NOT NULL,
  completed_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT unit_completions_pkey PRIMARY KEY (id),
  CONSTRAINT unit_completions_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT unit_completions_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.course_units(id),
  CONSTRAINT unit_completions_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id)
);
CREATE TABLE public.video_upload_reminders (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  booking_id uuid NOT NULL,
  pilot_id uuid NOT NULL,
  sent_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  reminder_type text NOT NULL DEFAULT '24h'::text CHECK (reminder_type = ANY (ARRAY['24h'::text, '48h'::text, '72h'::text])),
  CONSTRAINT video_upload_reminders_pkey PRIMARY KEY (id),
  CONSTRAINT video_upload_reminders_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id),
  CONSTRAINT video_upload_reminders_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id)
);