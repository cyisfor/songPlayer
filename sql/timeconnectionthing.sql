CREATE OR REPLACE FUNCTION timeconnectionthingy(_timethingy bigint) RETURNS SETOF connectiontimesboo
    LANGUAGE plpgsql
    AS $$
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
    _maxdiff := _maxplayed-(select min(played) from songs);

    FOR _song,_played in SELECT id,played FROM songs LOOP
        IF (_played IS NULL) THEN
           _diff = interval '100 years';
           _strength := 2;
        ELSIF _maxdiff = interval '0' THEN
           _strength := 0;
        ELSE
            _diff := _maxplayed - _played;
            _strength :=
                         extract(epoch from _diff)
                     * 2
                     /
                            extract(epoch from _maxdiff) - 1;
        END IF;
        _boo.song := _song;
        _boo.played := _played;
        _boo.diff := _diff;
        _boo.strength := _strength;
        RETURN NEXT _boo;
        -- _timethingy is "like stuff better that hasn't been played in a while"
        PERFORM connectionStrength(_timethingy,_song,_strength,false);
     END LOOP;
END;
$$;
