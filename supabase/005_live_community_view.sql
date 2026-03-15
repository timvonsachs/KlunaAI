CREATE OR REPLACE VIEW live_community AS
SELECT
    COUNT(DISTINCT donor_token) FILTER (WHERE created_at > now() - interval '24 hours') AS active_today,
    MODE() WITHIN GROUP (ORDER BY final_mood) FILTER (WHERE created_at > now() - interval '24 hours') AS dominant_mood_today,
    COUNT(*) FILTER (WHERE created_at > now() - interval '24 hours') AS conversations_today,
    ROUND(AVG(round_count) FILTER (WHERE created_at > now() - interval '24 hours')::numeric, 1) AS avg_depth_today
FROM conversations;
