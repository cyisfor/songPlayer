CREATE FUNCTION findRecording(_hash bytea, _song bigint, _recorded timestamptz, _artist bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
_id integer;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM recordings WHERE hash = _hash;
        -- check if the row is found
        IF FOUND THEN
            RETURN _id;
        END IF;
        BEGIN
            INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
            INSERT INTO recordings (id, hash,song,recorded,artist) VALUES (_id, _hash,_song,_recorded,_artist) RETURNING id INTO _id;
            RETURN _id;
            EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;
