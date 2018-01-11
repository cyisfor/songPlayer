CREATE OR REPLACE FUNCTION findFile (_hash TEXT, _path TEXT)
    RETURNS int
    LANGUAGE plpgsql
AS $$
DECLARE
_id integer;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM files where hash = _hash;
        -- check if the row is found
        IF FOUND THEN
            UPDATE files SET path = _path WHERE id = _id;
            RETURN _id;
        END IF;
        BEGIN
            INSERT INTO files (hash,path) VALUES (_hash,_path) RETURNING id INTO _id;
            RETURN _id;
            EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;