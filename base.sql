CREATE TYPE connectiontimesboo AS (
	song bigint,
	played timestamp with time zone,
	diff interval,
	strength double precision
);

CREATE TYPE ratingboo AS (
	rating bigint,
	adjust double precision,
	subrating bigint,
	subadjust double precision,
	strength double precision,
	depth integer
);


CREATE FUNCTION rate(_rating integer, _adjust double precision) RETURNS SETOF ratingboo
    LANGUAGE plpgsql
    AS $$
DECLARE
_row ratingboo;
BEGIN
	FOR _row IN SELECT * FROM rateFeep(_rating,_adjust,0) LOOP
	    RETURN NEXT _row;
	END LOOP;
END;
$$;

CREATE FUNCTION ratefeep(_rating bigint, _adjust double precision, _depth integer) RETURNS SETOF ratingboo
    LANGUAGE plpgsql
    AS $$
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
$$;


CREATE FUNCTION selinsthingalbums(_title text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
_id integer;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM albums WHERE title = _title;
        -- check if the row is found
        IF FOUND THEN
            RETURN _id;
        END IF;
        BEGIN
            INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
            INSERT INTO albums (id, title) VALUES (_id, _title) RETURNING id INTO _id;
            RETURN _id;
            EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;


CREATE FUNCTION selinsthingartists(_name text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
_id integer;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM artists WHERE name = _name;
        -- check if the row is found
        IF FOUND THEN
            RETURN _id;
        END IF;
        BEGIN
            INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
            INSERT INTO artists (id, name) VALUES (_id, _name) RETURNING id INTO _id;
            RETURN _id;
            EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;


ALTER FUNCTION public.selinsthingartists(_name text) OWNER TO ion;

CREATE FUNCTION selinsthingsongs(_title text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
_id integer;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM songs WHERE title = _title;
        -- check if the row is found
        IF FOUND THEN
            RETURN _id;
        END IF;
        BEGIN
            INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
            INSERT INTO songs (id, title) VALUES (_id, _title) RETURNING id INTO _id;
            RETURN _id;
            EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;

CREATE FUNCTION setpid(_who integer, _pid integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
   INSERT INTO pids (id,pid) VALUES (_who,_pid);
EXCEPTION
   WHEN unique_violation THEN
        UPDATE pids SET pid = _pid WHERE id = _who;
END;
$$;

CREATE FUNCTION songwasplayed(_recording bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
_now timestamptz;
BEGIN
        _now = now();

        UPDATE recordings SET played = _now, plays = plays + 1 WHERE id = _recording;
        UPDATE songs SET played = _now, plays = plays + 1 WHERE id = (SELECT song FROM recordings WHERE id = _recording);
END;
$$;

CREATE FUNCTION tag(_blue bigint, _tags name[], strength double precision) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;

CREATE TABLE albums (
    id bigint NOT NULL,
    recorded timestamp with time zone,
    title text
);

CREATE TABLE artists (
    id bigint NOT NULL,
    name text
);

CREATE TABLE connections (
    id bigint NOT NULL,
    red bigint NOT NULL,
    blue bigint NOT NULL,
    strength double precision
);

CREATE SEQUENCE connections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE connections_id_seq OWNED BY connections.id;

CREATE TABLE duration (
    id integer NOT NULL,
    duration bigint
);

CREATE TABLE history (
    id integer NOT NULL,
    song bigint NOT NULL,
    played timestamp with time zone DEFAULT now()
);

CREATE SEQUENCE history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE history_id_seq OWNED BY history.id;

SELECT pg_catalog.setval('history_id_seq', 1, false);

CREATE TABLE pids (
    id integer NOT NULL,
    pid integer
);

CREATE TABLE playing (
    id bigint NOT NULL,
    song bigint NOT NULL
);

CREATE TABLE queue (
    id integer NOT NULL,
    recording bigint
);


CREATE SEQUENCE queue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE queue_id_seq OWNED BY queue.id;
SELECT pg_catalog.setval('queue_id_seq', 1, false);

create table playlists(
recording bigint references recordings(id) not null,
list integer not null,
which integer not null,
unique(list,which));

CREATE TABLE ratings (
    id bigint NOT NULL,
    score double precision DEFAULT 0.0
);

CREATE TABLE recordings (
    id bigint NOT NULL,
    artist bigint,
    album bigint,
    song bigint,
    recorded timestamp with time zone,
    plays integer DEFAULT 0,
    played timestamp with time zone,
    hash text,
    path bytea
);


ALTER TABLE public.recordings OWNER TO ion;

--
-- Name: replaygain; Type: TABLE; Schema: public; Owner: ion; Tablespace:
--

CREATE TABLE replaygain (
    gain double precision,
    peak double precision,
    level double precision,
    id bigint NOT NULL
);


ALTER TABLE public.replaygain OWNER TO ion;

--
-- Name: songs; Type: TABLE; Schema: public; Owner: ion; Tablespace:
--

CREATE TABLE songs (
    id bigint NOT NULL,
    title text,
    plays integer DEFAULT 0,
    played timestamp with time zone
);


ALTER TABLE public.songs OWNER TO ion;

--
-- Name: things; Type: TABLE; Schema: public; Owner: ion; Tablespace:
--

CREATE TABLE things (
    id bigint NOT NULL,
    description text
);


ALTER TABLE public.things OWNER TO ion;

--
-- Name: things_id_seq; Type: SEQUENCE; Schema: public; Owner: ion
--

CREATE SEQUENCE things_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.things_id_seq OWNER TO ion;

--
-- Name: things_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ion
--

ALTER SEQUENCE things_id_seq OWNED BY things.id;


--
-- Name: things_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ion
--

SELECT pg_catalog.setval('things_id_seq', 660, true);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ion
--

ALTER TABLE ONLY connections ALTER COLUMN id SET DEFAULT nextval('connections_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ion
--

ALTER TABLE ONLY history ALTER COLUMN id SET DEFAULT nextval('history_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ion
--

ALTER TABLE ONLY queue ALTER COLUMN id SET DEFAULT nextval('queue_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ion
--

ALTER TABLE ONLY things ALTER COLUMN id SET DEFAULT nextval('things_id_seq'::regclass);


--
-- Name: albums_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY albums
    ADD CONSTRAINT albums_pkey PRIMARY KEY (id);


--
-- Name: albums_title_key; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY albums
    ADD CONSTRAINT albums_title_key UNIQUE (title);


--
-- Name: artists_name_key; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_name_key UNIQUE (name);


--
-- Name: artists_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_pkey PRIMARY KEY (id);


--
-- Name: connections_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY connections
    ADD CONSTRAINT connections_pkey PRIMARY KEY (id);


--
-- Name: connections_red_blue_key; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY connections
    ADD CONSTRAINT connections_red_blue_key UNIQUE (red, blue);


--
-- Name: duration_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY duration
    ADD CONSTRAINT duration_pkey PRIMARY KEY (id);


--
-- Name: history_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY history
    ADD CONSTRAINT history_pkey PRIMARY KEY (id);


--
-- Name: pids_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY pids
    ADD CONSTRAINT pids_pkey PRIMARY KEY (id);


--
-- Name: playing_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY playing
    ADD CONSTRAINT playing_pkey PRIMARY KEY (id);


--
-- Name: queue_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY queue
    ADD CONSTRAINT queue_pkey PRIMARY KEY (id);


--
-- Name: queue_recording_key; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY queue
    ADD CONSTRAINT queue_recording_key UNIQUE (recording);


--
-- Name: ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY ratings
    ADD CONSTRAINT ratings_pkey PRIMARY KEY (id);


--
-- Name: recordings_hash_key; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY recordings
    ADD CONSTRAINT recordings_hash_key UNIQUE (hash);


--
-- Name: recordings_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY recordings
    ADD CONSTRAINT recordings_pkey PRIMARY KEY (id);


--
-- Name: replaygain_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY replaygain
    ADD CONSTRAINT replaygain_pkey PRIMARY KEY (id);


--
-- Name: songs_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY songs
    ADD CONSTRAINT songs_pkey PRIMARY KEY (id);


--
-- Name: songs_title_key; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY songs
    ADD CONSTRAINT songs_title_key UNIQUE (title);


--
-- Name: things_description_key; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY things
    ADD CONSTRAINT things_description_key UNIQUE (description);


--
-- Name: things_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace:
--

ALTER TABLE ONLY things
    ADD CONSTRAINT things_pkey PRIMARY KEY (id);


--
-- Name: by_last_recording; Type: INDEX; Schema: public; Owner: ion; Tablespace:
--

CREATE INDEX by_last_recording ON recordings USING btree (played);


--
-- Name: by_last_song; Type: INDEX; Schema: public; Owner: ion; Tablespace:
--

CREATE INDEX by_last_song ON songs USING btree (played);


--
-- Name: hell_if_i_know; Type: INDEX; Schema: public; Owner: ion; Tablespace:
--

CREATE UNIQUE INDEX hell_if_i_know ON recordings USING btree (song) WHERE ((artist IS NULL) AND (recorded IS NULL));


--
-- Name: unique_recordings; Type: INDEX; Schema: public; Owner: ion; Tablespace:
--

CREATE UNIQUE INDEX unique_recordings ON recordings USING btree (song, artist, recorded);


--
-- Name: unique_recordings_artist_unknown; Type: INDEX; Schema: public; Owner: ion; Tablespace:
--

CREATE UNIQUE INDEX unique_recordings_artist_unknown ON recordings USING btree (song, recorded) WHERE (artist IS NULL);


--
-- Name: albums_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY albums
    ADD CONSTRAINT albums_id_fkey FOREIGN KEY (id) REFERENCES things(id) ON DELETE CASCADE;


--
-- Name: artists_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_id_fkey FOREIGN KEY (id) REFERENCES things(id) ON DELETE CASCADE;


--
-- Name: connections_blue_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY connections
    ADD CONSTRAINT connections_blue_fkey FOREIGN KEY (blue) REFERENCES things(id) ON DELETE CASCADE;


--
-- Name: connections_red_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY connections
    ADD CONSTRAINT connections_red_fkey FOREIGN KEY (red) REFERENCES things(id) ON DELETE CASCADE;


--
-- Name: history_song_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY history
    ADD CONSTRAINT history_song_fkey FOREIGN KEY (song) REFERENCES songs(id) ON DELETE CASCADE;


--
-- Name: playing_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY playing
    ADD CONSTRAINT playing_id_fkey FOREIGN KEY (id) REFERENCES recordings(id) ON DELETE CASCADE;


--
-- Name: playing_song_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY playing
    ADD CONSTRAINT playing_song_fkey FOREIGN KEY (song) REFERENCES songs(id) ON DELETE CASCADE;


--
-- Name: queue_recording_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY queue
    ADD CONSTRAINT queue_recording_fkey FOREIGN KEY (recording) REFERENCES recordings(id) ON DELETE CASCADE;


--
-- Name: ratings_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY ratings
    ADD CONSTRAINT ratings_id_fkey FOREIGN KEY (id) REFERENCES things(id) ON DELETE CASCADE;


--
-- Name: recordings_album_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY recordings
    ADD CONSTRAINT recordings_album_fkey FOREIGN KEY (album) REFERENCES albums(id) ON DELETE RESTRICT;


--
-- Name: recordings_artist_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY recordings
    ADD CONSTRAINT recordings_artist_fkey FOREIGN KEY (artist) REFERENCES artists(id) ON DELETE RESTRICT;


--
-- Name: recordings_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY recordings
    ADD CONSTRAINT recordings_id_fkey FOREIGN KEY (id) REFERENCES things(id) ON DELETE CASCADE;


--
-- Name: recordings_song_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY recordings
    ADD CONSTRAINT recordings_song_fkey FOREIGN KEY (song) REFERENCES songs(id) ON DELETE CASCADE;


--
-- Name: replaygain_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY replaygain
    ADD CONSTRAINT replaygain_id_fkey FOREIGN KEY (id) REFERENCES recordings(id) ON DELETE CASCADE;


--
-- Name: songs_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY songs
    ADD CONSTRAINT songs_id_fkey FOREIGN KEY (id) REFERENCES things(id) ON DELETE CASCADE;


--
-- Name: public; Type: ACL; Schema: -; Owner: ion
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM ion;
GRANT ALL ON SCHEMA public TO ion;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--
