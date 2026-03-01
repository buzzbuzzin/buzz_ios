-- Fix case-sensitivity for flight-plans bucket (same LOWER() fix as other buckets)

DROP POLICY IF EXISTS "Pilots can upload their own flight plan PDFs" ON storage.objects;
CREATE POLICY "Pilots can upload their own flight plan PDFs"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'flight-plans'
    AND LOWER((storage.foldername(name))[1]) = auth.uid()::text
);

DROP POLICY IF EXISTS "Pilots can view their own flight plan PDFs" ON storage.objects;
CREATE POLICY "Pilots can view their own flight plan PDFs"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'flight-plans'
    AND LOWER((storage.foldername(name))[1]) = auth.uid()::text
);
