CREATE FUNCTION currentSongWasPlayed() RETURNS void AS $$
DECLARE
        _song int;
        _recording int;
BEGIN
        SELECT id INTO _recording, song INTO _song FROM playing;
        INSERT INTO history (song) VALUES (_song);
        UPDATE songs SET plays = plays + 1, played = now() WHERE id = _song;
        UPDATE recordings SET plays = plays + 1, played = now() WHERE id = _recording;
END;
$$ LANGUAGE plpgsql;