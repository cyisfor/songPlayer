create or replace function justPlayed(_who bigint, _song bigint) returns integer as
$$
DECLARE
_plays int;
BEGIN
    UPDATE plays SET plays = plays + 1 WHERE who = _who AND song = _song RETURNING plays INTO _plays;
    IF NOT FOUND THEN
        BEGIN
            INSERT INTO plays (who,song) VALUES (_who,_song);
            RETURN 0;
        EXCEPTION 
            WHEN unique_violation THEN
                SELECT plays INTO _plays FROM plays WHERE who = _who AND song = _song;
                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Something is wicked broke here.';
                END IF;
        END;
    END IF;
    RETURN _plays;
END
$$ language 'plpgsql'
