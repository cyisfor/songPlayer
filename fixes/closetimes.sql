-- was inserting into history ALL songs in the queue for a while there.
-- from 75735-75878
-- search for songs within a second of each other being played in the history and delete all but 
-- the highest id
create or replace function fixnearbytimes() returns void as $$
MEHHHHH
DECLARE
_retry boolean;
_nearby int[];
BEGIN
    LOOP
        _retry := FALSE;

        FOR _row in SELECT id,played FROM history LOOP
            SELECT array_agg(id) INTO _nearby FROM history WHERE played > _row.played - '1 second' AND played < _row.played + '1 second';
            IF array_length(_nearby,1) > 1 THEN
                SELECT array_remove(_nearby,(SELECT MAX(id.unpack) FROM unnest(_nearby) AS id));
                DELETE FROM history WHERE id = ANY(_nearby);
                _retry := TRUE;
                EXIT;
            END IF;
        END LOOP;
        IF _retry = FALSE; THEN 
            EXIT;
        END IF;
    END LOOP;
END; 
$$ language 'plpgsql';
