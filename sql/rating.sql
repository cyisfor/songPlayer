create type ratingboo as (rating bigint, adjust float, subrating bigint, subadjust float, strength double precision, depth integer);

create or replace function rateFeep(_rating bigint, _adjust float, _depth integer) RETURNS SETOF ratingboo AS $FOOP$
DECLARE
_subrating bigint;
_subadjust float;
_strength double precision;
_subrow ratingboo;
BEGIN
	IF _depth > 4 THEN
	   RETURN;
	END IF;
	UPDATE ratings SET score = score + _adjust where id = _rating;
	IF NOT FOUND THEN
	   INSERT INTO ratings (id,score) VALUES (_rating,_adjust);
	END IF;
	FOR _subrating,_strength IN SELECT blue,strength FROM connections WHERE red = _rating LOOP
	    _subadjust = _adjust * _strength;
	    RETURN QUERY SELECT _rating,_adjust,_subrating,_subadjust,_strength,_depth;
	    IF abs(_subadjust) > 0.01 THEN
	       FOR _subrow IN SELECT * FROM rateFeep(_subrating, _subadjust, _depth + 1) LOOP
	       	   RETURN NEXT _subrow;
	       END LOOP;
	    END IF;
	END LOOP;
END;
$FOOP$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION rate(_rating integer, _adjust float) RETURNS SETOF ratingboo AS $FOOP$
DECLARE
_row ratingboo;
BEGIN
	FOR _row IN SELECT * FROM rateFeep(_rating,_adjust,0) LOOP
	    RETURN NEXT _row;
	END LOOP;
END;
$FOOP$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION tag(_blue bigint, _tags name[],strength double precision) RETURNS VOID AS $FOOP$
DECLARE
_i integer;
_red bigint;
_blue bigint;
_connection bigint;
BEGIN
	FOR _i IN array_lower(_tags)..array_upper(_tags) LOOP
	  SELECT id INTO _red FROM things WHERE description = _tags[_name];
	  IF NOT FOUND THEN
	    BEGIN
		INSERT INTO things (name) VALUES (_tags[_i]) 
		       RETURNING id INTO _red;
            EXCEPTION
		WHEN unique_violation THEN
		     SELECT id INTO _red FROM things WHERE description = _tags[_name];		   
	    END;
	  END IF;
	  UPDATE connections SET strength = _strength WHERE red = _red AND blue = _blue;
	  IF NOT FOUND THEN
	     BEGIN
		INSERT INTO connections (red,blue,strength) VALUES (_red,_blue,_strength);
	     EXCEPTION
		WHEN unique_violation THEN
		     NULL; -- no need since something else set the strength
	     END;
	  END IF;
	END LOOP;
END; 
$FOOP$ LANGUAGE 'plpgsql';