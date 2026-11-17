-- =====================================
-- NOTIFICATIONS SYSTEM SETUP
-- =====================================
-- Run this in your Supabase SQL Editor to create the notifications system

-- =====================================
-- NOTIFICATIONS TABLE
-- =====================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN (
        'bet_won', 
        'bet_lost', 
        'moment_revealed', 
        'moment_expired',
        'outcome_uploaded',
        'new_moment'
    )),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    data JSONB DEFAULT '{}', -- Additional context (bet_id, moment_id, amount, etc.)
    read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.notifications(read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);

-- Enable Row Level Security (RLS)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for notifications table
-- Users can only view their own notifications
CREATE POLICY "Users can view their own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

-- Users can only update their own notifications (for marking as read)
CREATE POLICY "Users can update their own notifications" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- System can insert notifications for any user
CREATE POLICY "System can insert notifications" ON public.notifications
    FOR INSERT WITH CHECK (true);

-- =====================================
-- NOTIFICATION PREFERENCES TABLE
-- =====================================
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    bet_results BOOLEAN DEFAULT true,
    moment_outcomes BOOLEAN DEFAULT true,
    push_enabled BOOLEAN DEFAULT true,
    email_enabled BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS for preferences
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

-- Users can only manage their own preferences
CREATE POLICY "Users can manage their own preferences" ON public.notification_preferences
    FOR ALL USING (auth.uid() = user_id);

-- =====================================
-- AUTOMATIC NOTIFICATION TRIGGERS
-- =====================================

-- Function to create bet result notifications
CREATE OR REPLACE FUNCTION create_bet_result_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create notifications for status changes from 'active' to 'won'/'lost'
  IF NEW.status IN ('won', 'lost') AND OLD.status = 'active' THEN
    INSERT INTO public.notifications (user_id, type, title, message, data)
    VALUES (
      NEW.user_id,
      CASE WHEN NEW.status = 'won' THEN 'bet_won' ELSE 'bet_lost' END,
      CASE 
        WHEN NEW.status = 'won' THEN '🎉 You Won!' 
        ELSE '😔 Bet Lost' 
      END,
      CASE 
        WHEN NEW.status = 'won' THEN 'Your €' || NEW.amount || ' bet on ' || NEW.outcome || ' won! Check your winnings.'
        ELSE 'Your €' || NEW.amount || ' bet on ' || NEW.outcome || ' didn''t win this time.'
      END,
      jsonb_build_object(
        'bet_id', NEW.id,
        'moment_id', NEW.moment_id,
        'amount', NEW.amount,
        'outcome', NEW.outcome,
        'status', NEW.status
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for bet notifications
DROP TRIGGER IF EXISTS bet_result_notification_trigger ON public.bets;
CREATE TRIGGER bet_result_notification_trigger
  AFTER UPDATE ON public.bets
  FOR EACH ROW
  EXECUTE FUNCTION create_bet_result_notification();

-- Function to create moment outcome notifications
CREATE OR REPLACE FUNCTION create_moment_outcome_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Create notification when moment status changes to 'revealed'
  IF NEW.status = 'revealed' AND OLD.status != 'revealed' THEN
    -- Create notifications for all users who bet on this moment
    INSERT INTO public.notifications (user_id, type, title, message, data)
    SELECT 
      DISTINCT b.user_id,
      'moment_revealed',
      '📊 Moment Outcome Revealed!',
      'The moment "' || LEFT(NEW.description, 50) || '..." outcome is now available.',
      jsonb_build_object(
        'moment_id', NEW.id,
        'outcome_result', NEW.outcome_result,
        'creator_id', NEW.creator_id
      )
    FROM public.bets b
    WHERE b.moment_id = NEW.id 
      AND b.status IN ('won', 'lost', 'active')  -- Include all relevant bets
      AND b.user_id != NEW.creator_id; -- Don't notify the creator
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for moment outcome notifications
DROP TRIGGER IF EXISTS moment_outcome_notification_trigger ON public.moments;
CREATE TRIGGER moment_outcome_notification_trigger
  AFTER UPDATE ON public.moments
  FOR EACH ROW
  EXECUTE FUNCTION create_moment_outcome_notification();

-- =====================================
-- UTILITY FUNCTIONS
-- =====================================

-- Function to mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_read(notification_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE public.notifications 
  SET read = true, updated_at = NOW()
  WHERE id = notification_id AND user_id = auth.uid();
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark all notifications as read for user
CREATE OR REPLACE FUNCTION mark_all_notifications_read()
RETURNS INTEGER AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE public.notifications 
  SET read = true, updated_at = NOW()
  WHERE user_id = auth.uid() AND read = false;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RETURN updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count()
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM public.notifications 
    WHERE user_id = auth.uid() AND read = false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean old notifications (optional - run periodically)
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM public.notifications 
  WHERE created_at < NOW() - INTERVAL '30 days'
    AND read = true;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================
-- TEST DATA (Optional - for development)
-- =====================================

-- Insert default notification preferences for existing users
INSERT INTO public.notification_preferences (user_id)
SELECT id FROM auth.users
ON CONFLICT (user_id) DO NOTHING;

-- You can manually test notifications with:
-- SELECT create_bet_result_notification();
-- SELECT get_unread_notification_count();

-- =====================================
-- SETUP COMPLETE!
-- =====================================
-- Your notifications system is now ready.
-- Next steps:
-- 1. Run this SQL in Supabase SQL Editor
-- 2. Implement NotificationService in Flutter
-- 3. Add notification UI components
-- 4. Test the complete flow
