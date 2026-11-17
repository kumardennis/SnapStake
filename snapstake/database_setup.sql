-- SnapStake Database Setup Script
-- Run this in your Supabase SQL Editor to create the required tables

-- =====================================
-- BETS TABLE
-- =====================================
-- This table stores all bet placements by users on moments

CREATE TABLE IF NOT EXISTS public.bets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    moment_id UUID NOT NULL REFERENCES public.moments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    outcome TEXT NOT NULL CHECK (outcome IN ('yes', 'no')),
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'won', 'lost')),
    placed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_bets_moment_id ON public.bets(moment_id);
CREATE INDEX IF NOT EXISTS idx_bets_user_id ON public.bets(user_id);
CREATE INDEX IF NOT EXISTS idx_bets_status ON public.bets(status);
CREATE INDEX IF NOT EXISTS idx_bets_placed_at ON public.bets(placed_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.bets ENABLE ROW LEVEL SECURITY;

-- RLS Policies for bets table
-- Users can view all bets (for public betting data)
CREATE POLICY "Bets are viewable by everyone" ON public.bets
    FOR SELECT USING (true);

-- Users can only insert their own bets
CREATE POLICY "Users can insert their own bets" ON public.bets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Only users can update their own bets (for status changes)
CREATE POLICY "Users can update their own bets" ON public.bets
    FOR UPDATE USING (auth.uid() = user_id);

-- =====================================
-- UPDATE MOMENTS TABLE (if needed)
-- =====================================
-- Add any missing columns to moments table

-- Check if total_bets and total_amount columns exist
DO $$ 
BEGIN
    -- Add total_bets column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='moments' AND column_name='total_bets') THEN
        ALTER TABLE public.moments ADD COLUMN total_bets INTEGER DEFAULT 0;
    END IF;
    
    -- Add total_amount column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='moments' AND column_name='total_amount') THEN
        ALTER TABLE public.moments ADD COLUMN total_amount DECIMAL(10,2) DEFAULT 0;
    END IF;
END $$;

-- =====================================
-- FUNCTIONS AND TRIGGERS
-- =====================================

-- Function to update moment statistics when bets are placed
CREATE OR REPLACE FUNCTION update_moment_bet_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update moment statistics
    UPDATE public.moments 
    SET 
        total_bets = (
            SELECT COUNT(*) 
            FROM public.bets 
            WHERE moment_id = COALESCE(NEW.moment_id, OLD.moment_id)
        ),
        total_amount = (
            SELECT COALESCE(SUM(amount), 0) 
            FROM public.bets 
            WHERE moment_id = COALESCE(NEW.moment_id, OLD.moment_id)
        )
    WHERE id = COALESCE(NEW.moment_id, OLD.moment_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create triggers to automatically update moment statistics
DROP TRIGGER IF EXISTS trigger_update_moment_bet_stats_insert ON public.bets;
CREATE TRIGGER trigger_update_moment_bet_stats_insert
    AFTER INSERT ON public.bets
    FOR EACH ROW EXECUTE FUNCTION update_moment_bet_stats();

DROP TRIGGER IF EXISTS trigger_update_moment_bet_stats_update ON public.bets;
CREATE TRIGGER trigger_update_moment_bet_stats_update
    AFTER UPDATE ON public.bets
    FOR EACH ROW EXECUTE FUNCTION update_moment_bet_stats();

DROP TRIGGER IF EXISTS trigger_update_moment_bet_stats_delete ON public.bets;
CREATE TRIGGER trigger_update_moment_bet_stats_delete
    AFTER DELETE ON public.bets
    FOR EACH ROW EXECUTE FUNCTION update_moment_bet_stats();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at on bets table
DROP TRIGGER IF EXISTS trigger_bets_updated_at ON public.bets;
CREATE TRIGGER trigger_bets_updated_at
    BEFORE UPDATE ON public.bets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================
-- SAMPLE DATA (Optional - for testing)
-- =====================================
-- Uncomment the following to add some test data

/*
-- Add some sample bets (only if you have existing moments and users)
INSERT INTO public.bets (moment_id, user_id, outcome, amount) VALUES
-- Replace these UUIDs with actual moment and user IDs from your database
-- ('your-moment-id-1', 'your-user-id-1', 'yes', 10.00),
-- ('your-moment-id-1', 'your-user-id-2', 'no', 15.50),
-- ('your-moment-id-2', 'your-user-id-1', 'yes', 25.00);
*/

-- =====================================
-- VERIFICATION QUERIES
-- =====================================
-- Run these to verify the setup worked correctly

-- Check if bets table was created successfully
SELECT 
    table_name, 
    column_name, 
    data_type, 
    is_nullable 
FROM information_schema.columns 
WHERE table_name = 'bets' 
ORDER BY ordinal_position;

-- Check if policies were created
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    cmd, 
    qual 
FROM pg_policies 
WHERE tablename = 'bets';

-- Check if triggers were created
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    trigger_schema
FROM information_schema.triggers 
WHERE event_object_table = 'bets';

COMMENT ON TABLE public.bets IS 'Stores user bets on moments with outcomes and amounts';
COMMENT ON COLUMN public.bets.outcome IS 'User prediction: yes or no';
COMMENT ON COLUMN public.bets.status IS 'Bet status: active, won, or lost';
COMMENT ON COLUMN public.bets.amount IS 'Bet amount in dollars';
