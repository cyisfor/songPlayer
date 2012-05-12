CREATE OR REPLACE FUNCTION track2song(_track bigint) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
_album bigint;
_artist bigint;
_title text;
_path text;
_recorded timestamptz;
_played timestamptz;
_newsong bigint;
_newrecording bigint;
_newtrack bigint;
BEGIN
        SELECT title, files.path,recordings.played,recordings.recorded,
                       recordings.artist,recordings.album INTO 
               _title, _path, _played, _recorded, _artist, _album
                 FROM tracks 
                 INNER JOIN recordings ON recordings.id = tracks.recording 
                 INNER JOIN files ON files.track = tracks.id
                   WHERE track = _track;
        INSERT INTO things (description) VALUES ('song:' || _title) RETURNING id INTO _newsong;
        INSERT INTO songs (id,title,played) VALUES (_newsong,_title,_played);
        INSERT INTO things (description) VALUES ('recording:'||_newsong||_title) RETURNING id INTO _newrecording;
        INSERT INTO recordings (id,artist,album,song,recorded,played)
               VALUES (_newrecording,_artist,_album,_newsong,_recorded,_played);
        INSERT INTO newreplaygain (id,gain,peak,level) SELECT _newrecording,gain,peak,level FROM replaygain WHERE id = _track;
        INSERT INTO newFiles (recording,path) VALUES (_newrecording,_path);

        INSERT INTO newtracks (recording,title,which,startpos,endpos) VALUES (_newrecording,_title,0,0,(select duration from duration where id = _track)) RETURNING id INTO _newtrack;
        DELETE FROM tracks where id = _track;
        RETURN _newtrack;
END;
$$;
DROP FUNCTION oldtrack2new(bigint);
DROP FUNCTION oldtrack2new(bigint,bigint);
CREATE OR REPLACE FUNCTION oldtrack2new(_track bigint, _newrecording bigint) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
_album bigint;
_artist bigint;
_title text;
_path text;
_recorded timestamptz;
_played timestamptz;
_song bigint;
_newtrack bigint;
BEGIN
        SELECT title, files.path,recordings.played,recordings.recorded,
                       recordings.artist,recordings.album,
                       tracks.id INTO
               _title, _path, _played, _recorded, _artist, _album, 
               _track
                 FROM tracks 
                 INNER JOIN recordings ON recordings.id = tracks.recording 
                 INNER JOIN files ON files.track = tracks.id
                   WHERE tracks.id = _track;
        BEGIN
                INSERT INTO newreplaygain (id,gain,peak,level) SELECT _newrecording,gain,peak,level FROM replaygain WHERE id = _track;
                INSERT INTO newFiles (recording,path) VALUES (_newrecording,_path);
        EXCEPTION
                WHEN unique_violation THEN
                     -- nothin
        END;

        INSERT INTO newtracks (recording,title,which,startpos,endpos) VALUES (
               _newrecording,
               _title,
               (SELECT coalesce(max(which)+1,0) FROM newtracks WHERE recording = _newrecording),
               (SELECT coalesce(max(endpos),0) FROM newtracks WHERE recording = _newrecording),
               (SELECT coalesce(max(endpos),0) FROM newtracks WHERE recording = _newrecording)
                       + (select duration from duration where id = _track))
               RETURNING id INTO _newtrack;
        DELETE FROM tracks where id = _track;
        RETURN _newtrack;
END;
$$;
CREATE OR REPLACE FUNCTION oldtrack2new(_track bigint) RETURNS bigint
LANGUAGE plpgsql
AS $$
BEGIN
   RETURN oldtrack2new(_track,(SELECT recording FROM tracks where id = _track));
END;
$$;

-- only use this AFTER every recording has only (old) tracks for ONE SONG

CREATE OR REPLACE FUNCTION finalmigrate() RETURNS SETOF bigint
LANGUAGE plpgsql
AS $$
DECLARE
_track bigint;
BEGIN
   FOR _track IN select id from tracks order by which LOOP
       RETURN NEXT oldtrack2new(_track);
   END LOOP;
END;
$$;