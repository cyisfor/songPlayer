CREATE OR REPLACE FUNCTION timeconnectionthingy(_timethingy bigint) RETURNS SETOF connectiontimesboo
    LANGUAGE plpgsql
    AS $$
DECLARE
_strength double precision;
_song bigint;
_played timestamptz;
_boo connectiontimesboo;
_numsongs integer;
_counter integer;
BEGIN
    SELECT count(*) INTO _numsongs FROM songs;

    _counter := 0;

    FOR _song in SELECT id FROM songs order by played asc nulls last,random() LOOP
        _strength := _counter * 2 / _numsongs - 1;

        _boo.song := _song;
        _boo._counter = _counter;
        _boo.strength := _strength;
        RETURN NEXT _boo;
        -- _timethingy is "like stuff better that hasn't been played in a while"
        PERFORM connectionStrength(_timethingy,_song,_strength,false);
     END LOOP;
END;
$$;
