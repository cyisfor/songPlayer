CREATE FUNCTION track2song(_track bigint) RETURNS bigint
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
BEGIN
        SELECT title, files.path,recordings.played,recordings.recorded,
                       recordings.artist,recordings.album INTO 
               _title, _path, _played, _recorded, _artist, _album
                 FROM tracks 
                 INNER JOIN recordings ON recordings.id = track.recording 
                 INNER JOIN files ON files.track = tracks.id
                   WHERE track = _track;
        INSERT INTO songs (title,played) VALUES (_title,_played) RETURNING id INTO _newsong;
        INSERT INTO recordings (artist,album,song,recorded,played)
               VALUES (_artist,_album,_newsong,_recorded,_played) RETURNING id INTO _newrecording;
        INSERT INTO newFiles (recording,path) VALUES (_newrecording,_path);
END;
$$;