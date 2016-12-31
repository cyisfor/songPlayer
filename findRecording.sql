CREATE FUNCTION findSong(_title text) RETURNS integer 
    LANGUAGE plpgsql
    AS $$
DECLARE
_id bigint;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM songs WHERE name = _title;
				IF FOUND THEN
            RETURN _id;
        END IF;
				BEGIN
					INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
          INSERT INTO songs (id, name) VALUES (_id, _song);
          RETURN _id;
        EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;

CREATE FUNCTION findArtist(_artist text) RETURNS integer 
    LANGUAGE plpgsql
    AS $$
DECLARE
_id bigint;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM artists WHERE name = _artist;
				IF FOUND THEN
            RETURN _id;
        END IF;
				BEGIN
					INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
          INSERT INTO artists (id, name) VALUES (_id, _artist);
          RETURN _id;
        EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;

CREATE FUNCTION findAlbum(_album text) RETURNS integer 
    LANGUAGE plpgsql
    AS $$
DECLARE
_id bigint;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM albums WHERE name = _album;
				IF FOUND THEN
            RETURN _id;
        END IF;
				BEGIN
					INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
          INSERT INTO albums (id, name) VALUES (_id, _album);
          RETURN _id;
        EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;


CREATE FUNCTION findRecording(_hash bytea, _title text, _artist text, _album text, _recorded timestamptz) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
_id bigint;
_songid bigint;
_artid bigint;
_alid bigint;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM recordings WHERE hash = _hash;
        -- check if the row is found
        IF FOUND THEN
            RETURN _id;
        END IF;
        BEGIN
					SELECT findSong(_title) INTO _songid;
					if _artist is not null then
						 select findArtist(_artist) into _artid;
					end if;
					if _album is not null then
						 select findAlbum(_albul) into _alid;
					end if;

            INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
            INSERT INTO recordings (id, hash, song, recorded, artist, album) VALUES
						  (_id, _hash,_songid,_recorded,_artid,_alid)
  						RETURNING id INTO _id;
            RETURN _id;
            EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;
