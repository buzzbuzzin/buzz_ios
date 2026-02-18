-- ============================================================================
-- Drone Parts Marketplace
-- Migration: 20260219_add_marketplace.sql
-- Description: Creates all marketplace tables, indexes, RLS policies, storage
-- ============================================================================

-- Create storage bucket for marketplace images
INSERT INTO storage.buckets (id, name, public) VALUES ('marketplace-images', 'marketplace-images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for marketplace-images bucket
CREATE POLICY "Users can upload marketplace images"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'marketplace-images' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Anyone can view marketplace images"
ON storage.objects FOR SELECT
USING (bucket_id = 'marketplace-images');

CREATE POLICY "Users can delete their own marketplace images"
ON storage.objects FOR DELETE
USING (bucket_id = 'marketplace-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ----------------------------------------------------------------------------
-- 1. marketplace_listings
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS marketplace_listings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    seller_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price > 0),
    category TEXT NOT NULL CHECK (category IN (
        'drones', 'batteries', 'propellers', 'controllers',
        'camera_gimbal', 'fpv_gear', 'cases_bags', 'accessories', 'other'
    )),
    condition TEXT NOT NULL CHECK (condition IN (
        'new', 'like_new', 'good', 'fair', 'parts_only'
    )),
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('ship', 'meetup', 'both')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
        'active', 'sold', 'reserved', 'expired', 'removed'
    )),
    image_urls TEXT[] NOT NULL DEFAULT '{}',
    location_name TEXT,
    location_lat DOUBLE PRECISION,
    location_lng DOUBLE PRECISION,
    brand TEXT,
    model TEXT,
    shipping_cost DECIMAL(10, 2),
    view_count INTEGER NOT NULL DEFAULT 0,
    favorite_count INTEGER NOT NULL DEFAULT 0,
    offer_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days')
);

CREATE INDEX idx_marketplace_listings_seller_id ON marketplace_listings(seller_id);
CREATE INDEX idx_marketplace_listings_category ON marketplace_listings(category);
CREATE INDEX idx_marketplace_listings_status ON marketplace_listings(status);
CREATE INDEX idx_marketplace_listings_created_at ON marketplace_listings(created_at DESC);
CREATE INDEX idx_marketplace_listings_price ON marketplace_listings(price);
CREATE INDEX idx_marketplace_listings_condition ON marketplace_listings(condition);
CREATE INDEX idx_marketplace_listings_transaction_type ON marketplace_listings(transaction_type);

ALTER TABLE marketplace_listings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active listings" ON marketplace_listings
    FOR SELECT USING (status = 'active' OR seller_id = auth.uid());

CREATE POLICY "Users can create listings" ON marketplace_listings
    FOR INSERT WITH CHECK (seller_id = auth.uid());

CREATE POLICY "Sellers can update their own listings" ON marketplace_listings
    FOR UPDATE USING (seller_id = auth.uid())
    WITH CHECK (seller_id = auth.uid());

CREATE POLICY "Sellers can delete their own listings" ON marketplace_listings
    FOR DELETE USING (seller_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 2. marketplace_favorites
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS marketplace_favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    listing_id UUID NOT NULL REFERENCES marketplace_listings(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT marketplace_favorites_unique UNIQUE (user_id, listing_id)
);

CREATE INDEX idx_marketplace_favorites_user_id ON marketplace_favorites(user_id);
CREATE INDEX idx_marketplace_favorites_listing_id ON marketplace_favorites(listing_id);

ALTER TABLE marketplace_favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own favorites" ON marketplace_favorites
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can favorite listings" ON marketplace_favorites
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can unfavorite listings" ON marketplace_favorites
    FOR DELETE USING (user_id = auth.uid());

-- Trigger to update favorite_count on marketplace_listings
CREATE OR REPLACE FUNCTION update_listing_favorite_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE marketplace_listings SET favorite_count = favorite_count + 1
        WHERE id = NEW.listing_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE marketplace_listings SET favorite_count = GREATEST(0, favorite_count - 1)
        WHERE id = OLD.listing_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_update_listing_favorite_count
AFTER INSERT OR DELETE ON marketplace_favorites
FOR EACH ROW EXECUTE FUNCTION update_listing_favorite_count();

-- ----------------------------------------------------------------------------
-- 3. marketplace_offers
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS marketplace_offers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    listing_id UUID NOT NULL REFERENCES marketplace_listings(id) ON DELETE CASCADE,
    buyer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    message TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'accepted', 'declined', 'withdrawn', 'expired'
    )),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_marketplace_offers_listing_id ON marketplace_offers(listing_id);
CREATE INDEX idx_marketplace_offers_buyer_id ON marketplace_offers(buyer_id);
CREATE INDEX idx_marketplace_offers_status ON marketplace_offers(status);

ALTER TABLE marketplace_offers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Buyers and sellers can view relevant offers" ON marketplace_offers
    FOR SELECT USING (
        buyer_id = auth.uid()
        OR listing_id IN (SELECT id FROM marketplace_listings WHERE seller_id = auth.uid())
    );

CREATE POLICY "Users can create offers" ON marketplace_offers
    FOR INSERT WITH CHECK (buyer_id = auth.uid());

CREATE POLICY "Participants can update offers" ON marketplace_offers
    FOR UPDATE USING (
        buyer_id = auth.uid()
        OR listing_id IN (SELECT id FROM marketplace_listings WHERE seller_id = auth.uid())
    )
    WITH CHECK (
        (status = 'accepted' AND listing_id IN (SELECT id FROM marketplace_listings WHERE seller_id = auth.uid()))
        OR (status = 'declined' AND listing_id IN (SELECT id FROM marketplace_listings WHERE seller_id = auth.uid()))
        OR (status = 'withdrawn' AND buyer_id = auth.uid())
    );

-- Trigger to update offer_count on marketplace_listings
CREATE OR REPLACE FUNCTION update_listing_offer_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE marketplace_listings SET offer_count = offer_count + 1
        WHERE id = NEW.listing_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE marketplace_listings SET offer_count = GREATEST(0, offer_count - 1)
        WHERE id = OLD.listing_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_update_listing_offer_count
AFTER INSERT OR DELETE ON marketplace_offers
FOR EACH ROW EXECUTE FUNCTION update_listing_offer_count();

-- Restrict offer updates to status column only
CREATE OR REPLACE FUNCTION marketplace_offers_restrict_update_columns()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.amount IS DISTINCT FROM OLD.amount
       OR NEW.message IS DISTINCT FROM OLD.message
       OR NEW.listing_id IS DISTINCT FROM OLD.listing_id
       OR NEW.buyer_id IS DISTINCT FROM OLD.buyer_id THEN
        RAISE EXCEPTION 'Only the status column can be updated on offers';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_marketplace_offers_restrict_update
BEFORE UPDATE ON marketplace_offers
FOR EACH ROW EXECUTE FUNCTION marketplace_offers_restrict_update_columns();

-- ----------------------------------------------------------------------------
-- 4. marketplace_transactions
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS marketplace_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    listing_id UUID NOT NULL REFERENCES marketplace_listings(id) ON DELETE CASCADE,
    buyer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    offer_id UUID REFERENCES marketplace_offers(id),
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('ship', 'meetup')),
    status TEXT NOT NULL DEFAULT 'pending_payment' CHECK (status IN (
        'pending_payment', 'paid', 'shipped', 'delivered', 'releasing', 'completed',
        'meetup_scheduled', 'meetup_completed',
        'disputed', 'refunded', 'cancelled'
    )),
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    platform_fee DECIMAL(10, 2) NOT NULL DEFAULT 0,
    seller_payout DECIMAL(10, 2) NOT NULL DEFAULT 0,
    payment_intent_id TEXT,
    charge_id TEXT,
    transfer_id TEXT,
    tracking_number TEXT,
    tracking_carrier TEXT,
    meetup_location_name TEXT,
    meetup_location_lat DOUBLE PRECISION,
    meetup_location_lng DOUBLE PRECISION,
    meetup_scheduled_at TIMESTAMPTZ,
    buyer_confirmed_at TIMESTAMPTZ,
    seller_confirmed_at TIMESTAMPTZ,
    shipped_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT marketplace_transactions_no_self_purchase CHECK (buyer_id != seller_id)
);

CREATE INDEX idx_marketplace_transactions_listing_id ON marketplace_transactions(listing_id);
CREATE INDEX idx_marketplace_transactions_buyer_id ON marketplace_transactions(buyer_id);
CREATE INDEX idx_marketplace_transactions_seller_id ON marketplace_transactions(seller_id);
CREATE INDEX idx_marketplace_transactions_status ON marketplace_transactions(status);

ALTER TABLE marketplace_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Buyers and sellers can view their transactions" ON marketplace_transactions
    FOR SELECT USING (buyer_id = auth.uid() OR seller_id = auth.uid());

CREATE POLICY "Service role creates transactions" ON marketplace_transactions
    FOR INSERT WITH CHECK (false);

-- Block direct client updates on transactions; use SECURITY DEFINER functions for allowed transitions
CREATE POLICY "Service role updates transactions" ON marketplace_transactions
    FOR UPDATE USING (false);

-- Allow transaction participants to confirm meetup completion
CREATE OR REPLACE FUNCTION marketplace_confirm_meetup(p_transaction_id UUID)
RETURNS VOID AS $$
DECLARE
    v_tx marketplace_transactions%ROWTYPE;
BEGIN
    -- Lock the row to prevent concurrent confirmation races
    SELECT * INTO v_tx FROM marketplace_transactions WHERE id = p_transaction_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transaction not found';
    END IF;

    IF v_tx.buyer_id != auth.uid() AND v_tx.seller_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    IF v_tx.status NOT IN ('meetup_scheduled') THEN
        RAISE EXCEPTION 'Transaction not in meetup_scheduled status';
    END IF;

    IF auth.uid() = v_tx.buyer_id THEN
        UPDATE marketplace_transactions
        SET buyer_confirmed_at = NOW(), updated_at = NOW()
        WHERE id = p_transaction_id;
    ELSE
        UPDATE marketplace_transactions
        SET seller_confirmed_at = NOW(), updated_at = NOW()
        WHERE id = p_transaction_id;
    END IF;

    -- If both parties have confirmed, transition to meetup_completed
    SELECT * INTO v_tx FROM marketplace_transactions WHERE id = p_transaction_id;
    IF v_tx.buyer_confirmed_at IS NOT NULL AND v_tx.seller_confirmed_at IS NOT NULL THEN
        UPDATE marketplace_transactions
        SET status = 'meetup_completed', updated_at = NOW()
        WHERE id = p_transaction_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION marketplace_confirm_meetup(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. marketplace_reviews
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS marketplace_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID NOT NULL REFERENCES marketplace_transactions(id) ON DELETE CASCADE,
    from_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    to_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT marketplace_reviews_unique UNIQUE (transaction_id, from_user_id)
);

CREATE INDEX idx_marketplace_reviews_to_user_id ON marketplace_reviews(to_user_id);
CREATE INDEX idx_marketplace_reviews_from_user_id ON marketplace_reviews(from_user_id);
CREATE INDEX idx_marketplace_reviews_transaction_id ON marketplace_reviews(transaction_id);

ALTER TABLE marketplace_reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view marketplace reviews" ON marketplace_reviews
    FOR SELECT USING (true);

CREATE POLICY "Transaction participants can create reviews" ON marketplace_reviews
    FOR INSERT WITH CHECK (
        from_user_id = auth.uid()
        AND to_user_id != auth.uid()
        AND to_user_id IN (
            SELECT buyer_id FROM marketplace_transactions WHERE id = transaction_id
            UNION
            SELECT seller_id FROM marketplace_transactions WHERE id = transaction_id
        )
        AND transaction_id IN (
            SELECT id FROM marketplace_transactions
            WHERE buyer_id = auth.uid() OR seller_id = auth.uid()
        )
    );

-- ----------------------------------------------------------------------------
-- 6. Composite indexes for common queries
-- ----------------------------------------------------------------------------
CREATE INDEX idx_marketplace_listings_status_created_at ON marketplace_listings(status, created_at DESC);
CREATE INDEX idx_marketplace_transactions_buyer_status ON marketplace_transactions(buyer_id, status);
CREATE INDEX idx_marketplace_transactions_seller_status ON marketplace_transactions(seller_id, status);

-- ----------------------------------------------------------------------------
-- 7. Auto-update updated_at trigger for all marketplace tables
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION marketplace_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_marketplace_listings_updated_at
BEFORE UPDATE ON marketplace_listings
FOR EACH ROW EXECUTE FUNCTION marketplace_update_updated_at();

CREATE TRIGGER trigger_marketplace_offers_updated_at
BEFORE UPDATE ON marketplace_offers
FOR EACH ROW EXECUTE FUNCTION marketplace_update_updated_at();

CREATE TRIGGER trigger_marketplace_transactions_updated_at
BEFORE UPDATE ON marketplace_transactions
FOR EACH ROW EXECUTE FUNCTION marketplace_update_updated_at();
