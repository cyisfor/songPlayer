--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: connectiontimesboo; Type: TYPE; Schema: public; Owner: ion
--

CREATE TYPE connectiontimesboo AS (
	song bigint,
	played timestamp with time zone,
	diff interval,
	strength double precision
);


ALTER TYPE public.connectiontimesboo OWNER TO ion;

--
-- Name: ratingboo; Type: TYPE; Schema: public; Owner: ion
--

CREATE TYPE ratingboo AS (
	rating bigint,
	adjust double precision,
	subrating bigint,
	subadjust double precision,
	strength double precision,
	depth integer
);


ALTER TYPE public.ratingboo OWNER TO ion;

--
-- Name: connectionstrength(bigint, bigint, double precision, boolean); Type: FUNCTION; Schema: public; Owner: ion
--

CREATE FUNCTION connectionstrength(_red bigint, _blue bigint, _strength double precision, _incrementally boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.connectionstrength(_red bigint, _blue bigint, _strength double precision, _incrementally boolean) OWNER TO ion;

--
-- Name: rate(integer, double precision); Type: FUNCTION; Schema: public; Owner: ion
--

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


ALTER FUNCTION public.rate(_rating integer, _adjust double precision) OWNER TO ion;

--
-- Name: ratefeep(bigint, double precision, integer); Type: FUNCTION; Schema: public; Owner: ion
--

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


ALTER FUNCTION public.ratefeep(_rating bigint, _adjust double precision, _depth integer) OWNER TO ion;

--
-- Name: tag(bigint, name[], double precision); Type: FUNCTION; Schema: public; Owner: ion
--

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


ALTER FUNCTION public.tag(_blue bigint, _tags name[], strength double precision) OWNER TO ion;

--
-- Name: timeconnectionthingy(bigint); Type: FUNCTION; Schema: public; Owner: ion
--

CREATE FUNCTION timeconnectionthingy(_timethingy bigint) RETURNS SETOF connectiontimesboo
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
	FOR _song,_played in SELECT id,played FROM songs LOOP
	    SELECT max(played) INTO _maxplayed FROM songs;
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
$$;


ALTER FUNCTION public.timeconnectionthingy(_timethingy bigint) OWNER TO ion;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: albums; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE albums (
    id bigint NOT NULL,
    recorded timestamp with time zone,
    title text
);


ALTER TABLE public.albums OWNER TO ion;

--
-- Name: artists; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE artists (
    id bigint NOT NULL,
    name text
);


ALTER TABLE public.artists OWNER TO ion;

--
-- Name: connections; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE connections (
    id bigint NOT NULL,
    red bigint NOT NULL,
    blue bigint NOT NULL,
    strength double precision
);


ALTER TABLE public.connections OWNER TO ion;

--
-- Name: connections_id_seq; Type: SEQUENCE; Schema: public; Owner: ion
--

CREATE SEQUENCE connections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.connections_id_seq OWNER TO ion;

--
-- Name: connections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ion
--

ALTER SEQUENCE connections_id_seq OWNED BY connections.id;


--
-- Name: duration; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE duration (
    id integer NOT NULL,
    duration bigint
);


ALTER TABLE public.duration OWNER TO ion;

--
-- Name: files; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE files (
    id integer NOT NULL,
    track integer,
    path text
);


ALTER TABLE public.files OWNER TO ion;

--
-- Name: files_id_seq; Type: SEQUENCE; Schema: public; Owner: ion
--

CREATE SEQUENCE files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.files_id_seq OWNER TO ion;

--
-- Name: files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ion
--

ALTER SEQUENCE files_id_seq OWNED BY files.id;


--
-- Name: history; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE history (
    id integer NOT NULL,
    song bigint NOT NULL,
    played timestamp with time zone DEFAULT now()
);


ALTER TABLE public.history OWNER TO ion;

--
-- Name: history_id_seq; Type: SEQUENCE; Schema: public; Owner: ion
--

CREATE SEQUENCE history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.history_id_seq OWNER TO ion;

--
-- Name: history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ion
--

ALTER SEQUENCE history_id_seq OWNED BY history.id;


--
-- Name: playing; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE playing (
    id bigint NOT NULL,
    which integer,
    song bigint NOT NULL
);


ALTER TABLE public.playing OWNER TO ion;

--
-- Name: queue; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE queue (
    id integer NOT NULL,
    recording bigint
);


ALTER TABLE public.queue OWNER TO ion;

--
-- Name: queue_id_seq; Type: SEQUENCE; Schema: public; Owner: ion
--

CREATE SEQUENCE queue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.queue_id_seq OWNER TO ion;

--
-- Name: queue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ion
--

ALTER SEQUENCE queue_id_seq OWNED BY queue.id;


--
-- Name: ratings; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE ratings (
    id bigint NOT NULL,
    score double precision DEFAULT 0.0
);


ALTER TABLE public.ratings OWNER TO ion;

--
-- Name: recordings; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE recordings (
    id bigint NOT NULL,
    artist bigint,
    album bigint,
    song bigint,
    recorded timestamp with time zone,
    plays integer DEFAULT 0,
    played timestamp with time zone
);


ALTER TABLE public.recordings OWNER TO ion;

--
-- Name: replaygain; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE replaygain (
    id integer NOT NULL,
    gain double precision,
    peak double precision,
    level double precision
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
-- Name: tracks; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE tracks (
    id integer NOT NULL,
    recording bigint NOT NULL,
    hash text,
    title text,
    which integer
);


ALTER TABLE public.tracks OWNER TO ion;

--
-- Name: tracks_id_seq; Type: SEQUENCE; Schema: public; Owner: ion
--

CREATE SEQUENCE tracks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tracks_id_seq OWNER TO ion;

--
-- Name: tracks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ion
--

ALTER SEQUENCE tracks_id_seq OWNED BY tracks.id;


--
-- Name: version; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE version (
    updated timestamp with time zone NOT NULL
);


ALTER TABLE public.version OWNER TO ion;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ion
--

ALTER TABLE ONLY connections ALTER COLUMN id SET DEFAULT nextval('connections_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ion
--

ALTER TABLE ONLY files ALTER COLUMN id SET DEFAULT nextval('files_id_seq'::regclass);


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
-- Name: id; Type: DEFAULT; Schema: public; Owner: ion
--

ALTER TABLE ONLY tracks ALTER COLUMN id SET DEFAULT nextval('tracks_id_seq'::regclass);


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
-- Name: files_path_key; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace: 
--

ALTER TABLE ONLY files
    ADD CONSTRAINT files_path_key UNIQUE (path);


--
-- Name: files_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace: 
--

ALTER TABLE ONLY files
    ADD CONSTRAINT files_pkey PRIMARY KEY (id);


--
-- Name: history_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace: 
--

ALTER TABLE ONLY history
    ADD CONSTRAINT history_pkey PRIMARY KEY (id);


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
-- Name: tracks_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace: 
--

ALTER TABLE ONLY tracks
    ADD CONSTRAINT tracks_pkey PRIMARY KEY (id);


--
-- Name: version_pkey; Type: CONSTRAINT; Schema: public; Owner: ion; Tablespace: 
--

ALTER TABLE ONLY version
    ADD CONSTRAINT version_pkey PRIMARY KEY (updated);


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
-- Name: unique_recordings_recorded_unknown; Type: INDEX; Schema: public; Owner: ion; Tablespace: 
--

CREATE UNIQUE INDEX unique_recordings_recorded_unknown ON recordings USING btree (song, artist) WHERE (recorded IS NULL);


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
-- Name: duration_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY duration
    ADD CONSTRAINT duration_id_fkey FOREIGN KEY (id) REFERENCES tracks(id);


--
-- Name: files_track_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY files
    ADD CONSTRAINT files_track_fkey FOREIGN KEY (track) REFERENCES tracks(id);


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
-- Name: playing_which_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY playing
    ADD CONSTRAINT playing_which_fkey FOREIGN KEY (which) REFERENCES tracks(id) ON DELETE CASCADE;


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
    ADD CONSTRAINT replaygain_id_fkey FOREIGN KEY (id) REFERENCES tracks(id);


--
-- Name: songs_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY songs
    ADD CONSTRAINT songs_id_fkey FOREIGN KEY (id) REFERENCES things(id) ON DELETE CASCADE;


--
-- Name: tracks_recording_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY tracks
    ADD CONSTRAINT tracks_recording_fkey FOREIGN KEY (recording) REFERENCES recordings(id) ON DELETE CASCADE;


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

