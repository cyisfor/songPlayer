CREATE TABLE IF NOT EXISTS ratingHistory(
    id SERIAL PRIMARY KEY,
    red INTEGER REFERENCES things(id) ON DELETE CASCADE ON UPDATE CASCADE NOT NULL,
    blue INTEGER REFERENCES things(id) ON DELETE CASCADE ON UPDATE CASCADE NOT NULL,
    strength DOUBLE PRECISION,
    created timestamptz DEFAULT now());

CREATE OR REPLACE FUNCTION connectionstrength(_red bigint, _blue bigint, _strength double precision, _incrementally boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
       _plur double precision;
BEGIN
    IF _red != 1 THEN -- derp
        -- this shouldn't commit until the (unexcepted) end of function...
        INSERT INTO ratingHistory (red,blue,strength) VALUES (_red,_blue,_strength);
    END IF;

    IF _incrementally THEN
	   SELECT (strength + _strength) INTO _plur FROM connections WHERE red = _red AND blue = _blue;
	   IF _plur IS NOT NULL THEN
	      _strength = _plur;
	   END IF;
	END IF;

	UPDATE connections SET strength = _strength WHERE red = _red AND blue = _blue;

	IF FOUND THEN
	   RETURN;
	END IF;

    --    RAISE NOTICE 'um, insertingx';

	BEGIN
		INSERT INTO connections (red,blue,strength) VALUES (_red,_blue,_strength);
	EXCEPTION
		WHEN unique_violation THEN
		     -- something else inserted a strength... just use theirs
		     RETURN;
	END;
END;
$$;
