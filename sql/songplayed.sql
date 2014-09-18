CREATE OR REPLACE FUNCTION songWasPlayed(_recording bigint) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
_now timestamptz;
_song bigint;
_who bigint;
BEGIN
        _now = clock_timestamp();
        
        UPDATE recordings SET played = _now, plays = plays + 1 WHERE id = _recording;
        SELECT song into _song FROM recordings WHERE id = _recording;
        UPDATE songs SET played = _now, plays = plays + 1 WHERE id = _song;
        SELECT id INTO _who FROM mode;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'NObody is playing rinow';
        END IF;
        PERFORM justPlayed(_who,_song);
        INSERT into history (song,played,who) SELECT song,_now,_who FROM recordings WHERE id = _recording;
END;
$$;
CREATE TABLE history (
    id SERIAL PRIMARY KEY,
    song bigint NOT NULL REFERENCES songs(id),
    who bigint REFERENCES things(id),
    played timestamptz NOT NULL);
CREATE UNIQUE INDEX byPlayed on history(played);
CREATE INDEX byWho ON history(who);
CREATE UNIQUE INDEX whenPlayed on history(song,played);
