CREATE OR REPLACE FUNCTION selinsThing%(table)s (%(parametersWithType)s)
    RETURNS int
    LANGUAGE plpgsql
AS $$
DECLARE
_id integer;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM %(table)s WHERE %(clause)s;
        -- check if the row is found
        IF FOUND THEN
            RETURN _id;
        END IF;
        BEGIN
            INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
            INSERT INTO %(table)s (id, %(paramnames)s) VALUES (_id, %(parameters)s) RETURNING id INTO _id;
            RETURN _id;
            EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;