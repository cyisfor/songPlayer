CREATE OR REPLACE FUNCTION splitTracks(_recording bigint, _maxwhich int) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
_newsong bigint;
_newrecording bigint;
_title text;
_played timestamptz;
_recorded timestamptz;
_artist bigint;
_album bigint;
BEGIN
        SELECT tracks.title,recordings.played,recordings.recorded,
                       recordings.artist,recordings.album INTO 
               _title, _played, _recorded, _artist, _album
                 FROM tracks 
                 INNER JOIN recordings ON recordings.id = tracks.recording 
                 INNER JOIN files ON files.track = tracks.id
                   WHERE recordings.id = _recording
                   ORDER BY tracks.which LIMIT 1;
        INSERT INTO things (description) VALUES ('song:' || _title) RETURNING id INTO _newsong;
        INSERT INTO songs (id,title,played) VALUES (_newsong,_title,_played);
        INSERT INTO things (description) VALUES ('recording:'||_newsong::text||_title) RETURNING id INTO _newrecording;
        INSERT INTO recordings (id,artist,album,song,recorded,played)
               VALUES (_newrecording,_artist,_album,_newsong,_recorded,_played);

        UPDATE tracks SET recording = _newrecording
            WHERE recording = _recording AND which <= _maxwhich;
        RETURN _newrecording;
END;
$$;