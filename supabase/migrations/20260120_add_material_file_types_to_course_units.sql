-- Migration: Add material file types support to course_units table
-- This allows course materials to be PDFs, images (JPEG, PNG, etc.), and other formats

-- Add material_urls column to replace pdf_url (supports multiple file types)
ALTER TABLE public.course_units
ADD COLUMN IF NOT EXISTS material_urls jsonb DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS material_names jsonb DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS material_types jsonb DEFAULT '[]'::jsonb;

-- Add comment explaining the new columns
COMMENT ON COLUMN public.course_units.material_urls IS 'Array of material file URLs (supports PDF, images, etc.)';
COMMENT ON COLUMN public.course_units.material_names IS 'Array of material file names corresponding to material_urls';
COMMENT ON COLUMN public.course_units.material_types IS 'Array of material file types (pdf, jpeg, png, etc.) corresponding to material_urls';

-- Migrate existing pdf_url and pdf_names data to new columns
-- This preserves backward compatibility while enabling new multi-format support
-- Note: pdf_url and pdf_names are JSONB columns that can contain arrays or strings

DO $$
DECLARE
    rec RECORD;
    url_array jsonb;
    name_array jsonb;
    type_array jsonb;
    array_length int;
BEGIN
    FOR rec IN SELECT id, pdf_url, pdf_names FROM public.course_units
    LOOP
        url_array := '[]'::jsonb;
        name_array := '[]'::jsonb;
        type_array := '[]'::jsonb;

        -- Process pdf_url (JSONB column)
        IF rec.pdf_url IS NOT NULL AND rec.pdf_url != 'null'::jsonb THEN
            -- Check the type of JSONB value
            CASE jsonb_typeof(rec.pdf_url)
                WHEN 'array' THEN
                    -- Already an array, use it directly
                    url_array := rec.pdf_url;
                WHEN 'string' THEN
                    -- It's a JSON string, check if it's empty
                    IF rec.pdf_url #>> '{}' != '' THEN
                        url_array := jsonb_build_array(rec.pdf_url #>> '{}');
                    END IF;
                ELSE
                    -- Other types (object, number, etc.) - shouldn't happen but handle gracefully
                    NULL;
            END CASE;
        END IF;

        -- Process pdf_names (JSONB column)
        IF rec.pdf_names IS NOT NULL AND rec.pdf_names != 'null'::jsonb THEN
            CASE jsonb_typeof(rec.pdf_names)
                WHEN 'array' THEN
                    name_array := rec.pdf_names;
                WHEN 'string' THEN
                    IF rec.pdf_names #>> '{}' != '' THEN
                        name_array := jsonb_build_array(rec.pdf_names #>> '{}');
                    END IF;
                ELSE
                    NULL;
            END CASE;
        END IF;

        -- If we have URLs but no names, generate default names
        IF jsonb_array_length(url_array) > 0 AND jsonb_array_length(name_array) = 0 THEN
            array_length := jsonb_array_length(url_array);
            IF array_length = 1 THEN
                name_array := jsonb_build_array('Course Material');
            ELSE
                -- Generate names for multiple materials
                name_array := '[]'::jsonb;
                FOR i IN 1..array_length LOOP
                    name_array := name_array || jsonb_build_array('Material ' || i);
                END LOOP;
            END IF;
        END IF;

        -- Generate type array (all PDFs for backward compatibility)
        IF jsonb_array_length(url_array) > 0 THEN
            type_array := '[]'::jsonb;
            FOR i IN 1..jsonb_array_length(url_array) LOOP
                type_array := type_array || jsonb_build_array('pdf');
            END LOOP;
        END IF;

        -- Update the record
        UPDATE public.course_units
        SET 
            material_urls = url_array,
            material_names = name_array,
            material_types = type_array,
            updated_at = timezone('utc'::text, now())
        WHERE id = rec.id;
    END LOOP;
END $$;

-- Create index for better query performance on material_urls
CREATE INDEX IF NOT EXISTS idx_course_units_material_urls ON public.course_units USING gin(material_urls);

-- Note: Keep pdf_url and pdf_names columns for backward compatibility
-- They can be removed in a future migration after confirming all clients are updated

-- Verification query (can be run manually):
-- SELECT id, title, material_urls, material_names, material_types, pdf_url, pdf_names
-- FROM public.course_units
-- WHERE jsonb_array_length(material_urls) > 0
-- LIMIT 5;