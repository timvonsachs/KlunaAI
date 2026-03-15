CREATE TABLE IF NOT EXISTS coach_feedback (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT now(),
    donor_token TEXT NOT NULL,
    entry_id TEXT,
    feedback INT NOT NULL,
    mood TEXT,
    round_index INT,
    app_version TEXT
);

ALTER TABLE coach_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can insert feedback" ON coach_feedback;
CREATE POLICY "Anyone can insert feedback"
ON coach_feedback
FOR INSERT
WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_coach_feedback_created_at ON coach_feedback(created_at);
CREATE INDEX IF NOT EXISTS idx_coach_feedback_feedback ON coach_feedback(feedback);
CREATE INDEX IF NOT EXISTS idx_coach_feedback_donor ON coach_feedback(donor_token);
