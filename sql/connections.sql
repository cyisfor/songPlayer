create or replace function connectionStrength(
       _red bigint, 
       _blue bigint, 
       _strength double precision, 
       _incrementally boolean DEFAULT true) 
RETURNS void AS $foop$
DECLARE
       _plur double precision;
BEGIN
	IF _incrementally THEN
	   SELECT (strength + _strength) INTO _plur FROM connections WHERE red = _red AND blue = _blue;
	   IF _plur IS NOT NULL THEN
	      _strength = _plur;
	   END IF;
	END IF;
	   
	IF abs(_strength) < 0.0000001 THEN
	  DELETE FROM connections WHERE red = _red AND blue = _blue;
	  RETURN;
	END IF;

	UPDATE connections SET strength = _strength WHERE red = _red AND blue = _blue;

	IF FOUND THEN 
	   RETURN; 
	END IF;

	BEGIN
		INSERT INTO connections (red,blue,strength) VALUES (_red,_blue,_strength);
	EXCEPTION
		WHEN unique_violation THEN
		     -- something else inserted a strength... just use theirs
		     RETURN;
	END;
END;
$foop$ language 'plpgsql';

create type connectiontimesboo as (song bigint, played timestamptz, diff interval, strength double precision);

CREATE OR REPLACE FUNCTION timeConnectionThingy(_timethingy bigint) RETURNS SETOF connectiontimesboo AS $foop$
DECLARE
_strength double precision;
_song bigint;
_played timestamptz;
_diff interval;
_boo connectiontimesboo;
_maxplayed timestamptz;
_maxdiff interval;
BEGIN
        SELECT max(played) INTO _maxplayed FROM songs;
	FOR _song,_played in SELECT id,played FROM songs LOOP
	    IF (_played IS NULL) THEN
	       _diff = interval '100 years';
	       _strength := 2;
	    ELSE
		_diff := _maxplayed - _played;
		_maxdiff := _maxplayed-(select min(played) from songs);
	    	IF _maxdiff = interval '0' THEN
	    		_strength := 0;
	    	ELSE
			_strength :=
	       	    	  extract(epoch from _diff)
	       		  * 2
	       		  /
       	       		  extract(epoch from _maxdiff) - 1;
	    	END IF;
	    END IF;
	    _boo.song := _song;
	    _boo.played := _played;
	    _boo.diff := _diff;
	    _boo.strength := _strength;
	    RETURN NEXT _boo;
	    -- type 3 row 4 is "How much time has passed sorta" concept
	    -- type 0 is songs
	    PERFORM connectionStrength(_timethingy,_song,_strength,false);
 	END LOOP;
END;
$foop$ language 'plpgsql'
