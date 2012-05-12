CREATE OR REPLACE FUNCTION songWasPlayed(_recording bigint) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
_now timestamptz;
BEGIN
        _now = now();
        
        UPDATE recordings SET played = _now, plays = plays + 1 WHERE id = _recording;
        UPDATE songs SET played = _now, plays = plays + 1 WHERE id = (SELECT song FROM recordings WHERE id = _recording);
END;
$$;
