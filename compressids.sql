CREATE OR REPLACE FUNCTION compressids ()
    RETURNS VOID
    LANGUAGE plpgsql
AS $$
DECLARE
_id bigint;
_counter bigint;
BEGIN
    _counter := 0;
    FOR _id IN SELECT id FROM things ORDER BY id DESC LOOP
        LOOP
           IF _id < _counter THEN
               RETURN;
           END IF;
           _counter := _counter + 1;
           PERFORM id FROM things WHERE id = _counter;
           IF FOUND THEN
              RAISE NOTICE '% taken',_counter;
           ELSE
              EXIT;
           END IF;
        END LOOP;
        RAISE NOTICE 'Move % to %',_id,_counter;
        UPDATE things SET id = _counter WHERE id = _id;
    END LOOP;
END;
$$;
