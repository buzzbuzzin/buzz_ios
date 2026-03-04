-- Server-side cache for drone news to avoid redundant external fetches
-- Each source (faa, transport_canada, global) gets one row, upserted by the edge function

CREATE TABLE IF NOT EXISTS public.news_cache (
  source TEXT PRIMARY KEY,
  articles JSONB NOT NULL,
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.news_cache ENABLE ROW LEVEL SECURITY;

-- Allow service role full access (used by edge function)
CREATE POLICY "Service role full access" ON public.news_cache
  FOR ALL USING (auth.role() = 'service_role');

-- Allow public read access (news articles are not sensitive)
CREATE POLICY "Public can read news cache" ON public.news_cache
  FOR SELECT USING (true);
