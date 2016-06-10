CREATE OR REPLACE FUNCTION selinsThingrecordings (_song bigint,_recorded timestamptz,_artist bigint,_hash text)
    RETURNS int
    LANGUAGE plpgsql
AS $$
DECLARE
_id integer;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM recordings WHERE (song = _song) AND (recorded IS NULL OR recorded = _recorded) AND (artist IS NULL OR artist = _artist);
        -- check if the row is found
        IF FOUND THEN
            RETURN _id;
        END IF;
        BEGIN
            INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
            INSERT INTO recordings (id, song,recorded,artist,hash) VALUES (_id, _song,_recorded,_artist,_hash) RETURNING id INTO _id;
            RETURN _id;
            EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;
CREATE OR REPLACE FUNCTION selinsThingsongs (_title text)
    RETURNS int
    LANGUAGE plpgsql
AS $$
DECLARE
_id integer;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM songs WHERE title = _title;
        -- check if the row is found
        IF FOUND THEN
            RETURN _id;
        END IF;
        BEGIN
            INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
            INSERT INTO songs (id, title) VALUES (_id, _title) RETURNING id INTO _id;
            RETURN _id;
            EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;
CREATE OR REPLACE FUNCTION selinsThingartists (_name text)
    RETURNS int
    LANGUAGE plpgsql
AS $$
DECLARE
_id integer;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM artists WHERE name = _name;
        -- check if the row is found
        IF FOUND THEN
            RETURN _id;
        END IF;
        BEGIN
            INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
            INSERT INTO artists (id, name) VALUES (_id, _name) RETURNING id INTO _id;
            RETURN _id;
            EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;
CREATE OR REPLACE FUNCTION selinsThingalbums (_title text)
    RETURNS int
    LANGUAGE plpgsql
AS $$
DECLARE
_id integer;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM albums WHERE title = _title;
        -- check if the row is found
        IF FOUND THEN
            RETURN _id;
        END IF;
        BEGIN
            INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
            INSERT INTO albums (id, title) VALUES (_id, _title) RETURNING id INTO _id;
            RETURN _id;
            EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;
