-- Migration: Add exam_appointments table for Test Center feature
-- This table stores exam bookings for Flight Review and ROC-A exams

-- Create exam_appointments table
CREATE TABLE IF NOT EXISTS public.exam_appointments (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  exam_type text NOT NULL CHECK (exam_type IN ('flight_review', 'roc_a')),
  scheduled_date timestamp with time zone NOT NULL,
  duration_minutes integer NOT NULL DEFAULT 15,
  location_type text NOT NULL CHECK (location_type IN ('in_person', 'online')),
  location_address text, -- For in-person exams
  meeting_link text,     -- For online exams (placeholder URL)
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  stripe_payment_intent_id text,
  stripe_charge_id text,
  payment_amount numeric NOT NULL,
  notes text, -- Additional notes or special instructions
  examiner_id uuid, -- Future: assigned examiner
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT exam_appointments_pkey PRIMARY KEY (id),
  CONSTRAINT exam_appointments_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT exam_appointments_examiner_id_fkey FOREIGN KEY (examiner_id) REFERENCES public.profiles(id),
  -- Ensure in-person exams have an address
  CONSTRAINT exam_appointments_location_check CHECK (
    (location_type = 'in_person' AND location_address IS NOT NULL) OR
    (location_type = 'online')
  ),
  -- Ensure Flight Review is always in-person
  CONSTRAINT exam_appointments_flight_review_in_person CHECK (
    (exam_type = 'flight_review' AND location_type = 'in_person') OR
    (exam_type = 'roc_a')
  )
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_exam_appointments_pilot_id ON public.exam_appointments(pilot_id);
CREATE INDEX IF NOT EXISTS idx_exam_appointments_exam_type ON public.exam_appointments(exam_type);
CREATE INDEX IF NOT EXISTS idx_exam_appointments_status ON public.exam_appointments(status);
CREATE INDEX IF NOT EXISTS idx_exam_appointments_scheduled_date ON public.exam_appointments(scheduled_date);

-- Enable Row Level Security
ALTER TABLE public.exam_appointments ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Pilots can view their own exam appointments
CREATE POLICY "Pilots can view own exam appointments"
  ON public.exam_appointments
  FOR SELECT
  USING (auth.uid() = pilot_id);

-- Pilots can create their own exam appointments
CREATE POLICY "Pilots can create own exam appointments"
  ON public.exam_appointments
  FOR INSERT
  WITH CHECK (auth.uid() = pilot_id);

-- Pilots can update their own pending appointments (e.g., to cancel)
CREATE POLICY "Pilots can update own pending exam appointments"
  ON public.exam_appointments
  FOR UPDATE
  USING (auth.uid() = pilot_id AND status = 'pending')
  WITH CHECK (auth.uid() = pilot_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_exam_appointments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
DROP TRIGGER IF EXISTS trigger_update_exam_appointments_updated_at ON public.exam_appointments;
CREATE TRIGGER trigger_update_exam_appointments_updated_at
  BEFORE UPDATE ON public.exam_appointments
  FOR EACH ROW
  EXECUTE FUNCTION public.update_exam_appointments_updated_at();

-- Add comment for documentation
COMMENT ON TABLE public.exam_appointments IS 'Stores exam appointment bookings for Flight Review and ROC-A exams in the Test Center';
COMMENT ON COLUMN public.exam_appointments.exam_type IS 'Type of exam: flight_review (in-person only) or roc_a (in-person or online)';
COMMENT ON COLUMN public.exam_appointments.location_type IS 'Whether the exam is in_person or online';
COMMENT ON COLUMN public.exam_appointments.meeting_link IS 'Zoom or video call link for online exams';
COMMENT ON COLUMN public.exam_appointments.status IS 'Appointment status: pending (awaiting confirmation), confirmed, completed, or cancelled';

