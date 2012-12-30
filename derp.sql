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
-- Name: selinsthingalbums(text); Type: FUNCTION; Schema: public; Owner: ion
--

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


ALTER FUNCTION public.selinsthingalbums(_title text) OWNER TO ion;

--
-- Name: selinsthingartists(text); Type: FUNCTION; Schema: public; Owner: ion
--

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

--
-- Name: selinsthingrecordings(text); Type: FUNCTION; Schema: public; Owner: ion
--

CREATE FUNCTION selinsthingrecordings(_hash text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
_id integer;
BEGIN
    LOOP
        -- first try to find it
        SELECT id INTO _id FROM recordings WHERE (hash = _hash);
        -- check if the row is found
        IF FOUND THEN
            RETURN _id;
        END IF;
        BEGIN
            INSERT INTO things DEFAULT VALUES RETURNING id INTO _id;
            INSERT INTO recordings (id, hash) VALUES (_id, _hash) RETURNING id INTO _id;
            RETURN _id;
            EXCEPTION WHEN unique_violation THEN
                -- do nothing and loop
        END;
    END LOOP;
END;
$$;


ALTER FUNCTION public.selinsthingrecordings(_hash text) OWNER TO ion;

--
-- Name: selinsthingsongs(text); Type: FUNCTION; Schema: public; Owner: ion
--

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


ALTER FUNCTION public.selinsthingsongs(_title text) OWNER TO ion;

--
-- Name: setpid(integer, integer); Type: FUNCTION; Schema: public; Owner: ion
--

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


ALTER FUNCTION public.setpid(_who integer, _pid integer) OWNER TO ion;

--
-- Name: songwasplayed(bigint); Type: FUNCTION; Schema: public; Owner: ion
--

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


ALTER FUNCTION public.songwasplayed(_recording bigint) OWNER TO ion;

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
-- Name: connections_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ion
--

SELECT pg_catalog.setval('connections_id_seq', 294, true);


--
-- Name: duration; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE duration (
    id integer NOT NULL,
    duration bigint
);


ALTER TABLE public.duration OWNER TO ion;

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
-- Name: history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ion
--

SELECT pg_catalog.setval('history_id_seq', 1, false);


--
-- Name: pids; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE pids (
    id integer NOT NULL,
    pid integer
);


ALTER TABLE public.pids OWNER TO ion;

--
-- Name: playing; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE playing (
    id bigint NOT NULL,
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
-- Name: queue_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ion
--

SELECT pg_catalog.setval('queue_id_seq', 1, false);


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
    played timestamp with time zone,
    hash text,
    path text
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

SELECT pg_catalog.setval('things_id_seq', 8163305, true);


--
-- Name: versions; Type: TABLE; Schema: public; Owner: ion; Tablespace: 
--

CREATE TABLE versions (
    version bigint
);


ALTER TABLE public.versions OWNER TO ion;

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
-- Data for Name: albums; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY albums (id, recorded, title) FROM stdin;
663	\N	An Ancient Muse
682	\N	Live in Paris and Toronto (disc 1)
699	\N	Live in Paris and Toronto (disc 2)
718	\N	Winter Garden
729	\N	Parallel Dreams
746	\N	The Mask and Mirror
759	\N	To Drive The Cold Winter Away (Remastered 2004)
779	\N	The Books Of Secrets
789	\N	The visit
804	\N	Elemental (Limited Edition with Bonus DVD)
824	\N	Star Trek: First Contact (Complete - CD2)
861	\N	Star Trek: First Contact (Complete - CD1)
920	\N	Star Trek IV: The Voyage Home
947	\N	Star Trek II: Wrath of Khan
967	\N	Star Trek VII (Generations)
1043	\N	Star Trek Nemesis (Complete Score CD 1)
1082	\N	Star Trek Nemesis (Complete Sc
1085	\N	Star Trek Nemesis (Complete Score CD 2)
1124	\N	Star Trek III: The Search for Spock
1142	\N	Star Trek: Insurrection OST
1165	\N	Star Trek V: The Final Frontier (Expanded)
1206	\N	Star Trek: The Undiscovered Country
1234	\N	Star Trek: The Motion Picture Soundtrack
1254	\N	Homestuck Vol. 5
1460	\N	The Wanderers
1493	\N	Tomb of the Ancestors
1526	\N	Homestuck Vol. 1-4
1608	\N	Homestuck Vol. 4
1626	\N	Strife!
1641	\N	Homestuck Vol. 7: At the Price of Oblivion
1682	\N	Alternia
1719	\N	Song of Skaia
1726	\N	Sburb
1751	\N	Prospit & Derse
1768	\N	Land of Fans and Music
1875	\N	Homestuck for the Holidays
1920	\N	AlterniaBound
1981	\N	The Felt
2016	\N	Jailbreak Vol. 1
2079	\N	Homestuck Vol. 6: Heir Transparent
2121	\N	Homestuck Vol. 3
2135	\N	Homestuck Vol. 1
2150	\N	Medium
2165	\N	Midnight Crew: Drawing Dead
2204	\N	Mobius Trip and Hadron Kaleido
2223	\N	Squiddles!
2269	\N	Homestuck Vol. 2
2286	\N	Homestuck Vol. 8
2372	\N	The Lord Of The Rings - The Fellowship Of The Ring
2409	\N	The Lord Of The Rings - The Return of the King
2448	\N	The Lord Of The Rings - The Two Towers
2490	\N	The Greatest Hits: 1969-1999 Disc 1
2493	\N	The Greatest Hits: 1969-1999 Disc 2
2549	\N	Masters Of Classical Music (Vol. 1)
2583	\N	Master Of Classical Music (Vol. 7)
2608	\N	Masters Of Classical Music (Vol. 6)
2634	\N	Masters Of Classical Music (Vol. 8)
2669	\N	Masters Of Classical Music (Vol. 2)
2708	\N	Masters Of Classical Music (Vol. 9)
2734	\N	Masters Of Classical Music (Vol. 5)
2753	\N	Masters Of Classical Music (Vol. 4)
2772	\N	Master Of Classical Music ( Vol. 3)
2798	\N	Master Of Classical Music (Vol. 10)
2823	\N	Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)
2873	\N	Box Set CD 1
2908	\N	Box Set CD 2
2943	\N	Box Set CD 3
2970	\N	A Passage in Time
2977	\N	A Passage In Time
3000	\N	Eye of the Hunter
3003	\N	Eye Of The Hunter
3016	\N	Dead Can Dance
3041	\N	Serpent's Egg
3058	\N	Wake [CD1]
3081	\N	Wake [CD2]
3103	\N	Toward the Within
3127	\N	Within the Realm of a Dying Sun
3132	\N	Within The Realm Of A Dying Sun
3140	\N	Aion
3160	\N	Duality
3182	\N	The Mirror Pool
3238	\N	Ashes And Snow
3264	\N	A Thousand Roads
3305	\N	Whalerider
3336	\N	The Insider
3370	\N	Gladiator Music From The Motion Picture
3405	\N	Spleen and Ideal
3416	\N	Spleen And Ideal
3422	\N	Spiritchaser
3438	\N	Lille 16 March 05 CD1
3454	\N	Lille 16 March 2005 CD2
3470	\N	Into the Labyrinth
3531	\N	Ideas from CBC Radio (Highlights)
1042461	\N	東方乙女囃子
1042520	\N	0.93569946
1042524	\N	0.97952271
1042528	\N	0.99990845
1042532	\N	1.00000000
1042542	\N	0.99996948
1042546	\N	0.78979492
1042555	\N	0.98156738
1042559	\N	0.97903442
1042562	\N	0.99151611
1042566	\N	0.95294189
1042573	\N	0.98217773
1042579	\N	0.99902344
1042583	\N	0.97198486
1042599	\N	0.99389648
1042607	\N	0.98065186
1042616	\N	0.95278931
1042620	\N	0.99401855
1042626	\N	0.97720337
1042632	\N	Carl Orff - Carmina Burana
1042635	\N	0.99908447
1042659	\N	0.97616577
1042671	\N	0.99993896
1042677	\N	0.88735962
1042687	\N	1159b1ae-ab44-36bb-a265-d153eec8b8f7
1042695	\N	Symphony No. 3 (Warsaw Philharmonic Orchestra feat. conductor: Kazimierz Kord, soprano: Joanna Kozłowska)
1042701	\N	Merriweather Post Pavilion
1042725	\N	Realpeople Holland
1042728	\N	March of the Zapotec
1042750	\N	Brendan et le secret de Kells (Bande originale du film)
1042757	\N	Unwritten
1042761	\N	The Raccoons
1042768	\N	Keep your Jesus off my Penis Enhanced CD Single
1042772	\N	Angels & Airwaves
1042776	\N	"FINAL FANTASY CRYSTAL CHRONICLES" Original Soundtrack (Disc 1)
1042780	\N	Wishmaster
1042784	\N	Imagine
1042788	\N	Imaginary
1042795	\N	Spaceman
1042799	\N	Bad Hair Day
1042803	\N	Disco Estrella Vol.6
1042813	\N	Chrono Trigger
1042817	\N	Around The World
1042821	\N	.hack SIGN - Ost 1
1042825	\N	Live at Carnegie Hall: May 9, 1958
1042832	\N	Classical Music Top 100
1043034	\N	Animaniacs
1043045	\N	MOTHER
1043051	\N	Unknown Album
1043055	\N	Beyond The Valley Of The Gift Police
1043074	\N	Ebichu
1043078	\N	420station.com
1043082	\N	Logic Port
1043086	\N	Mount Eden Album
1043090	\N	0.99456787
1043118	\N	0.94754028
1043177	\N	0.92202759
1043239	\N	0.95782471
1299422	\N	Watermark
1299434	\N	Celebration of life
1299438	\N	Neverending Story
1299448	\N	Best Of
1947239	\N	www.BooM4u.info By V.a.L.e.R.i
\.


--
-- Data for Name: artists; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY artists (id, name) FROM stdin;
662	Loreena McKennitt
823	Jerry Goldsmith
829	Roy Orbison
858	Steppenwolf
919	Leonard Rosenman
923	Edge of Etiquette (Kirk Thatcher)
946	James Horner
966	Dennis Mccarthy
1205	Cliff Eidelman
1233	Star Trek: TMP
1253	Homestuck
2371	Various
2489	John Williams
2548	Sandor Vegh, Franz Liszt Chamber Orchestra, Janos Rolla
2552	Budapest Wind Ensemble
2555	Bela Drahos, flute; Franz Liszt Chamber Orchestra, Janos Rolla
2558	Vienna Mozart Ensemble, Herber Kraus
2561	Christian Altenburger, violin, German Bach Soloists, Helmut Winschermann
2564	Zoltan Kocsis. Piano. Franz Liszt Chamber Orchestra, Janos Rolla
2567	Evelyne Dubourg, piano
2570	Mozarteum Orchestra Salzburg, Hans Graf
2573	Bela Kovacs, clarinet, Camerata Salzburg, Franz Liszt Chamber Orchestra, Janos Rolla
2576	Camerata Salzburg, Sandor Vegh
2579	Bernd Heiser, Horn Vienna Mozart Ensemble, Herber Kraus
2582	Budapest Strings, Karoly Botvay
2590	Roland Straumer, Heinz Dieter Richter, Vlolker Dietzsch, Brigitte Gabsch, violin; Virtuosi Saxoniale Ludwig Güttler
2595	Burkhard Glaetzner, oboe; Christine Schornsheim, harpsichord; Siegfied Pank, viola da gamba
2598	Ludwig Güttler, Corno da caccia 1, Kurt Sandau, Corno da caccia 2; Virtuosi Saxoniae, Ludwig Güttler
2601	Franz Liszt Chamber Orchestra
2604	Burchard Glaetzner, oboe; New Bach Collegium Musicum, Max Pommer
2607	Emmy Verhey, violin; Budapest Symphony Orchestra, Arpad Joo
2611	Bavarian Radio Symphony Orchestra, Hans Vonk
2614	Berlin Chamber Orchestra, Peter Wohlert
2619	Vienna Symphony, Yuri URI Ahronoviych
2626	Jenö Jando, piano; Budapest Philharmonic Orchestra, Andras Ligeti
2633	Stanislav Bunin, piano
2641	Jean-Marc Luisada, piano
2644	Yuval Fichman, piano
2647	Krzysztof Jablonski, piano
2668	Hannes Kästner, organ
2672	Walter Heinz Bernstein, virginals
2675	Ludwig Güttler, trumpet; Friedrich Kircheis, organ
2678	Ludwig Güttler, trumpet; New Bach Collegium Musicum, Max Pommer
2683	New Bach Collegium Musicum, Max Pommer
2686	Eckart Haupt, flute; Bach Collegium Musicum, Max Pommer
2691	Miklos Szenthelyi, violin; Hungarian Chamber Orchestra G.Gyorivanyi-Rath
2694	Karl-Heinz Passin, flute; Walter Heinz Bernstein, harpsichord
2707	Budapest Philharmonic, Janos Kovacs
2711	Budapest Strings
2714	Hungarian State Opera Orchestra, Adam Fischer
2717	Jenö Jando, piano
2730	Emmy Verhey, violin; Danielle Dechenne, piano; Colorado String Quartet
2733	Budapest Symphonic Orchestra, György Lehel
2737	Sofia Philharmonic Orchestra, Vassil Kazandjiev
2752	Vienna Strauss Orchestra, Joseph Francek
2760	RTL Symphony, Kurt Redel
2771	Anton Dikov, piano; Sofia Philharmonic Orchestra, Emil Tabakov
2775	London Philharmonic Orchestra, Alfred Scholz
2778	Dresden Philharmonic, Herbert Kegel
2783	Dresden Philharmonic; Herbert Kegel
2792	Miklos Szenthelyi, violin
2797	Bulgarian National Choir 'Svetoslav Obretenov',Sofia Philharmonic Orchestra,Vassil Stefanov
2801	Bulgarian National Choir 'Svetoslav Obretenov',Sofia Philharmonic Orchestra,Georgi Robev
2822	dead can dance
2872	Dead Can Dance
2999	Brendan Perry
3159	Lisa Gerrard & Pieter Bourke
3167	Lisa Gerrard
3237	Lisa Gerrard & Patrick Cassidy
3263	Lisa Gerrard & Jeff Rona
3369	Hans Zimmer and Lisa Gerrard
3437	Dead Can Dance - Live
3530	Ideas from CBC Radio (Highlights)
3534	Tamias
3539	Xploding Plastix
1042460	IOSYS
1042464	DJ Sharpnel
1042467	Lemon Demon
1042470	Lemon Demon, Marty Allen
1042519	Robert Spring
1042523	Evgeny Svetlanov
1042527	Berlin Philharmoniker HERBERT VON KARAJAN
1042531	Antal Dorati
1042535	Camille Saint-Saens
1042538	Cincinnati Pops Orchestra (Kunzel, 1997)
1042541	Khachaturian
1042545	John Barbirolli: New Philharmonia Orchestra
1042551	P.D.Q. Bach
1042554	San Francisco Symphony (Blomstedt)
1042558	Boston symphony orchestra, Seiji Ozawa
1042565	Jean Sibelius
1042569	Ravel
1042572	Vaughan Williams
1042578	Edvard Grieg
1042582	Dvorák
1042586	Gustav Mahler
1042591	Pierre Monteux, London Symphony Orchestra
1042598	Boston Symphony Orchestra, Seiji Ozawa, Kiri Te Kanawa (soprano) & Marilyn Horne (mezzo-soprano)
1042602	Gustav Holst
1042612	Smetana
1042615	Orquesta Estable del Teatro Colón
1042619	Sibelius
1042625	Antonin Dvorak
1042631	Janowitz, Stolze, Fischer-Dieskau
1042658	Sibelius  - Vladimir Ashkenazy
1042670	Richard Strauss
1042674	Seattle SO, Gerard Schwarz
1042686	7a837d63-a434-47e8-8b48-1d50e54ebb74
1042694	Henryk Mikołaj Górecki
1042700	Animal Collective
1042724	Beirut
1042749	Bruno Coulais
1042753	Simple Plan
1042756	Natasha Bedingfield
1042760	Lisa Lougheed
1042764	Anime - Lunar
1042767	Eric Schwartz
1042771	Angels & Airwaves
1042775	Kumi Tanioka
1042779	Nightwish
1042783	Beatles
1042787	Evanescence
1042791	Josh Groban
1042794	Bif Naked
1042798	Weird Al Yankovic
1042802	Dr Reanimator
1042806	Rammstein
1042809	Pokémon
1042812	Yasunori Mitsuda
1042816	ATC
1042820	Yuki Kajiura
1042824	Paul Robeson
1042828	Squarepusher
1042831	VA
1043033	Animaniacs
1043041	Len
1043044	Catherine Warwick
1043050	Unknown Artist
1043054	Jello Biafra
1043058	www.zug.com
1043065	Craig Jacks
1043068	Trapezoid
1043073	Mitsuishi Kotono
1043077	Bill Hicks
1043081	East Clubbers
1043085	Mt Eden
1043089	Chieftains
1043117	The Chieftains
1043176	Jon Vickers
1043202	Kitaro
1043205	John Tesh
1043208	Enya
1043211	Vangelis
1043216	Constance Demby
1043219	Chris Spheeris
1043222	Yanni
1043225	Chris Spheeris, Paul Voudouris
1043230	Suzanne Ciani
1043232	Jim Chappell
1043235	Steve Howe, Constance Demby, Paul Sutin
1043238	Sehnsucht nach dem Frühling K 596
1043242	La Serenata
1043245	Ständchen
1043248	Ave Maria
1043251	Der Lindenbaum
1043253	Liebesbotschaft
1043256	Heidenröslein
1043259	Funiculi, funicula
1043262	Gretchen am Spinnadre, D.118
1043265	O sole mio
1043268	Torna a Surriento
1043271	Hallelujah!
1043274	Auf Flügeln das Gesanges
1043276	Ave Maria Op 52, No 6
1043279	Jesu, joy of man's desiring
1043282	Sandmännchen
1043285	Core 'ngrato
1043287	Wiegenlied D.498
1299425	pj harvey
1299428	inchadney
1299433	Bill Danoff, Taffy Nivert, John Denver
1299437	Klaus Doldinger/Giorgio Moroder/Limahl
1299441	Hard'n'Firm
1299444	Clown Staples
1299447	Bach
1299517	Lara Ameterasu
1946807	www.BooM4u.info By V.a.L.e.R.i
\.


--
-- Data for Name: connections; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY connections (id, red, blue, strength) FROM stdin;
\.


--
-- Data for Name: duration; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY duration (id, duration) FROM stdin;
\.


--
-- Data for Name: history; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY history (id, song, played) FROM stdin;
\.


--
-- Data for Name: pids; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY pids (id, pid) FROM stdin;
0	2707
\.


--
-- Data for Name: playing; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY playing (id, song) FROM stdin;
\.


--
-- Data for Name: queue; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY queue (id, recording) FROM stdin;
\.


--
-- Data for Name: ratings; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY ratings (id, score) FROM stdin;
\.


--
-- Data for Name: recordings; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY recordings (id, artist, album, song, recorded, plays, played, hash, path) FROM stdin;
687	662	682	686	2012-11-30 05:04:03+00	0	\N	df7dc6e2852669548126d90c546fd31e583bc5790264b7a31e10033d721cd6bb	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD1/02 Loreena McKennitt The Mummers' Dance.mp3
668	662	663	667	2012-11-30 05:04:00+00	0	\N	4350f131b916118c872231f8af003312586a880ae8d05fb1d41607350aeb4039	/home/extra/user/torrents/Loreena McKennitt Discography/2006 An Ancient Muse/02-loreena_mckennitt--the_gates_of_istanbul.mp3
697	662	682	696	2012-11-30 05:04:04+00	0	\N	45247685f299120c17ce8a745ac6af6bff408c0e2890819c0e0683f1c4ac080f	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD1/06 Loreena McKennitt La Serenissima.mp3
670	662	663	669	2012-11-30 05:04:00+00	0	\N	c4e9665b0db1adfc41b766cf50c86b6447a1392cf1015c76733d5df521707833	/home/extra/user/torrents/Loreena McKennitt Discography/2006 An Ancient Muse/08-loreena_mckennitt--beneath_a_phrygian_sky.mp3
689	662	682	688	2012-11-30 05:04:03+00	0	\N	2a9a3fda28bc420b49ceb4c7ae3e648a549f99deab75d41ab790686ff32a70d7	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD1/04 Loreena McKennitt Marco Polo.mp3
672	662	663	671	2012-11-30 05:04:01+00	0	\N	27e1d40c9ac40c087d0028a58bcd77437474a8c5ab0131ed3ec173040560aa63	/home/extra/user/torrents/Loreena McKennitt Discography/2006 An Ancient Muse/09-loreena_mckennitt--never-ending_road_(amhran_duit).mp3
674	662	663	673	2012-11-30 05:04:01+00	0	\N	464d3523fe814606e3fe83166c89e7c9928c55d8693ae81b691db120ff3a0ad1	/home/extra/user/torrents/Loreena McKennitt Discography/2006 An Ancient Muse/05-loreena_mckennitt--kecharitomene.mp3
676	662	663	675	2012-11-30 05:04:01+00	0	\N	fed97d3cac60271244cfb73d868928723bcf6181def52c7c4bc9e0c657e15a68	/home/extra/user/torrents/Loreena McKennitt Discography/2006 An Ancient Muse/01-loreena_mckennitt--incantation.mp3
691	662	682	690	2012-11-30 05:04:03+00	0	\N	6bd1fac5ab2de92a6899568931ac8efe51b20bc91effd6ef33ac4a883bfb3793	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD1/03 Loreena McKennitt Skellig.mp3
678	662	663	677	2012-11-30 05:04:01+00	0	\N	5484ff16d88219d91dde66da70195ce6119fa250f9fc2abc4a43a24eb532993d	/home/extra/user/torrents/Loreena McKennitt Discography/2006 An Ancient Muse/03-loreena_mckennitt--caravanserai.mp3
680	662	663	679	2012-11-30 05:04:02+00	0	\N	8522f12d4ee1d0e4dc04fbca734886a018408c3ae66ffe78332d0e2d3bd06298	/home/extra/user/torrents/Loreena McKennitt Discography/2006 An Ancient Muse/04-loreena_mckennitt--the_english_ladye_and_the_knight.mp3
704	662	699	703	2012-11-30 05:04:05+00	0	\N	d73186cd1fcb997ba591ffa672597c47cd5bf9a16e4535f58ed687fab9473f51	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD2/04 Loreena McKennitt Between the Shadows.mp3
685	662	682	684	2012-11-30 05:04:02+00	0	\N	3deb72a4d1daed483fed5b8cd3f2a869451e4d37f8bd32fddd1ece818d22d975	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD1/08 Loreena McKennitt Dante's Prayer.mp3
693	662	682	692	2012-11-30 05:04:04+00	0	\N	5d452b9cc7e1bbf026adb82568d6e0296bc41c8ce1d794ef05bcf2d63acd365a	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD1/07 Loreena McKennitt Night Ride Across the Caucasus.mp3
695	662	682	694	2012-11-30 05:04:04+00	0	\N	a50517b8dd792af4b23a60962deb4d60c35d50f9fbaeda2e3e8db607a893cefe	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD1/01 Loreena McKennitt Prologue.mp3
700	662	699	698	2012-11-30 05:04:05+00	0	\N	c549d71f964f16e22ac99db001d0f3c97443f9da500c61aa331d2d09e2b443f5	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD2/08 Loreena McKennitt All Souls Night.mp3
702	662	699	701	2012-11-30 05:04:05+00	0	\N	47d4a4573f288d4b04f295a61df0329a4fed1b0ae6771f1663fe2bde00d6c684	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD2/06 Loreena McKennitt The Bonny Swans.mp3
706	662	699	705	2012-11-30 05:04:05+00	0	\N	8bfc73915778f7b3a523d08750f033814ffc058e010645630d67e9ee7c09146b	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD2/02 Loreena McKennitt Santiago.mp3
708	662	699	707	2012-11-30 05:04:06+00	0	\N	09f1b73422cbf6762ddc806efa3df5e8965a66aa6409753d05cbb86a95ef6663	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD2/09 Loreena McKennitt Cymbeline.mp3
710	662	699	709	2012-11-30 05:04:06+00	0	\N	4ba121285c6b66ec8d2d3c02ff0f000e7e8d4ea84e74354e67327c836e78deb3	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD2/01 Loreena McKennitt The Mystic's Dream.mp3
666	662	663	665	2012-11-30 05:04:00+00	0	\N	7bc42773a094be5705d68e8806379ff8ea6913567a97ea392a0c87cde3ebd069	/home/extra/user/torrents/Loreena McKennitt Discography/2006 An Ancient Muse/07-loreena_mckennitt--sacred_shabbat.mp3
1299515	\N	\N	1299514	2012-11-30 07:25:54+00	0	\N	291fd388f96e8352b036b7dcc5be2d25fada79862fa17180bf364a957de72e04	/home/extra/youtube/music/PSY_-_GANGNAM_STYLE_(강남스타일)_M_V-9bZkp7q19f0.vorbis.ogg
744	662	729	743	2006-03-12 00:00:00+00	0	\N	251e3af391f4058499a272c7714e5875456d2a94b7acf02ecf08911c9fadd969	/home/extra/user/torrents/Loreena McKennitt Discography/1989 Parallel Dreams/Parallel Dreams/Loreena McKennitt - Parallel Dreams/08 Loreena McKennitt Ancient Pines.mp3
734	662	729	733	2006-03-12 00:00:00+00	0	\N	99cff78789ab7b97ac939b34d8c47ac22a95002e724d4bfeac1e44f386a71327	/home/extra/user/torrents/Loreena McKennitt Discography/1989 Parallel Dreams/Parallel Dreams/Loreena McKennitt - Parallel Dreams/04 Loreena McKennitt Annachie Gordon.mp3
716	662	699	715	2012-11-30 05:04:06+00	0	\N	f66619641508ca859d2f8e0d6835e8c3709e40c640eba962fe121a0e6ad1cf70	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD2/07 Loreena McKennitt The Old Ways.mp3
719	662	718	717	2012-11-30 05:04:07+00	0	\N	9b5abcc7fa76cf8cf63f578de21c7071784171cd8be5c2bffd3cc3f106a9e62a	/home/extra/user/torrents/Loreena McKennitt Discography/1995 A Winter Garden Five Songs For The Season/Winter Garden/Loreena McKennitt - Winter Garden/Loreena McKennitt - Winter Garden - 01.mp3
721	662	718	720	2012-11-30 05:04:07+00	0	\N	31e8b79cdf8e4157f2ab138588a8351a4d222a3299ba71ca1d939c2a52f11273	/home/extra/user/torrents/Loreena McKennitt Discography/1995 A Winter Garden Five Songs For The Season/Winter Garden/Loreena McKennitt - Winter Garden/Loreena McKennitt - Winter Garden - 05.mp3
736	662	729	735	2006-03-12 00:00:00+00	0	\N	14600b3b5b76176eea4d87fbd547aed93a46ee02437c46316db98ea275bbc0b9	/home/extra/user/torrents/Loreena McKennitt Discography/1989 Parallel Dreams/Parallel Dreams/Loreena McKennitt - Parallel Dreams/07 Loreena McKennitt Breaking the Silence.mp3
723	662	718	722	2012-11-30 05:04:07+00	0	\N	d65044117390669d7674d5174044c3e2b7a2abc5c9a8c54d48cdb488f47beb88	/home/extra/user/torrents/Loreena McKennitt Discography/1995 A Winter Garden Five Songs For The Season/Winter Garden/Loreena McKennitt - Winter Garden/Loreena McKennitt - Winter Garden - 02.mp3
725	662	718	724	2012-11-30 05:04:08+00	0	\N	f005ffe894be26714fbb23183dd08096d7738c1da9abca32d1750b563a38b625	/home/extra/user/torrents/Loreena McKennitt Discography/1995 A Winter Garden Five Songs For The Season/Winter Garden/Loreena McKennitt - Winter Garden/Loreena McKennitt - Winter Garden - 03.mp3
727	662	718	726	2012-11-30 05:04:08+00	0	\N	ae8edd004c8e95d003489da2dfbe363c4f61432fcd88185ed2eab500215b130c	/home/extra/user/torrents/Loreena McKennitt Discography/1995 A Winter Garden Five Songs For The Season/Winter Garden/Loreena McKennitt - Winter Garden/Loreena McKennitt - Winter Garden - 04.mp3
738	662	729	737	2006-03-12 00:00:00+00	0	\N	32260ee5f8d382af2e0a46222f0bfb7344e061194e1424307a72cc6a34e599f1	/home/extra/user/torrents/Loreena McKennitt Discography/1989 Parallel Dreams/Parallel Dreams/Loreena McKennitt - Parallel Dreams/05 Loreena McKennitt Standing Stones.mp3
730	662	729	728	2006-03-12 00:00:00+00	0	\N	8b72e8b7232c424dcccbf6dbcbe06e1956d11e8f5c1a6aa4a6ae41a4a191fa7c	/home/extra/user/torrents/Loreena McKennitt Discography/1989 Parallel Dreams/Parallel Dreams/Loreena McKennitt - Parallel Dreams/06 Loreena McKennitt Dickens' Dublin (The Palace).mp3
732	662	729	731	2006-03-12 00:00:00+00	0	\N	8c7a02f8619e9c95d09043739eeb48755e8c6c070763c75be9c46d6d7d6919e5	/home/extra/user/torrents/Loreena McKennitt Discography/1989 Parallel Dreams/Parallel Dreams/Loreena McKennitt - Parallel Dreams/02 Loreena McKennitt Moon Cradle.mp3
747	662	746	745	2006-03-02 00:00:00+00	0	\N	34c29391e59348d2eea57d68b9a607f49dc6830e4803dcf7710dc7689c1c60f6	/home/extra/user/torrents/Loreena McKennitt Discography/1994 The mask and the mirror/The mask and the mirror/The mask and the mirror/07 Loreena McKennitt Cé hé mise le ulaingt  (The Two Trees).mp3
740	662	729	739	2006-03-12 00:00:00+00	0	\N	040d1d1c7e0b8667648daf44961eadeb6b588ca0cd6692b17e78ab5f077e69de	/home/extra/user/torrents/Loreena McKennitt Discography/1989 Parallel Dreams/Parallel Dreams/Loreena McKennitt - Parallel Dreams/01 Loreena McKennitt Samain Night.mp3
742	662	729	741	2006-03-12 00:00:00+00	0	\N	7f856796e18509785b8800856409118158cccf0fcec1d463b795d1179826f1fe	/home/extra/user/torrents/Loreena McKennitt Discography/1989 Parallel Dreams/Parallel Dreams/Loreena McKennitt - Parallel Dreams/03 Loreena McKennitt Huron 'Beltane' Fire Dance.mp3
750	662	746	705	2006-03-02 00:00:00+00	0	\N	a2758a3e8f93dd1f2b16768625cef076309d61e571a7f1440af12f66a8484526	/home/extra/user/torrents/Loreena McKennitt Discography/1994 The mask and the mirror/The mask and the mirror/The mask and the mirror/06 Loreena McKennitt Santiago.mp3
749	662	746	748	2006-03-02 00:00:00+00	0	\N	28f16f221de6921969fdb3042df4b082e5e87d7acd0563cf7592e6b3ca4f89d5	/home/extra/user/torrents/Loreena McKennitt Discography/1994 The mask and the mirror/The mask and the mirror/The mask and the mirror/04 Loreena McKennitt Marrakesh Night Market.mp3
753	662	746	752	2006-03-02 00:00:00+00	0	\N	64bd71384030d71304d42a13e20fc210edb0538929c4233302d77179d3c466e7	/home/extra/user/torrents/Loreena McKennitt Discography/1994 The mask and the mirror/The mask and the mirror/The mask and the mirror/03 Loreena McKennitt The Dark Night of the Soul.mp3
751	662	746	709	2006-03-02 00:00:00+00	0	\N	845e3bc59d4f2dbd267d384556c1152e40d3fcd6ed6520a0828cb0c77ebbcffb	/home/extra/user/torrents/Loreena McKennitt Discography/1994 The mask and the mirror/The mask and the mirror/The mask and the mirror/01 Loreena McKennitt The Mystic's Dream.mp3
755	662	746	754	2006-03-02 00:00:00+00	0	\N	9942cbb9f9b45f29daa34600bddb0b53b7291cb01ee73301ef2da9a1e8dac6e6	/home/extra/user/torrents/Loreena McKennitt Discography/1994 The mask and the mirror/The mask and the mirror/The mask and the mirror/08 Loreena McKennitt Prospero's Speech.mp3
714	662	699	713	2012-11-30 05:04:06+00	0	\N	fc932d413f1d42e34ed263922bfdb68d68219986c9de4ca36de7d9fb1e5e40ad	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD2/05 Loreena McKennitt The Lady of Shalott.mp3
776	662	759	775	2012-11-30 05:04:17+00	0	\N	64c752f71ea1c28e4bd9baf8f10505c939538d462eec683842e328fce8a7b4c2	/home/extra/user/torrents/Loreena McKennitt Discography/1987 To drive the cold winter away/To drive the cold winter away/To drive the cold winter away/06 Loreena McKennitt Balulalow.mp3
762	662	759	761	2012-11-30 05:04:15+00	0	\N	4fa845fa015566eea876caeee7dc6c3a971a6337b188c4e3ceade9a48c17e1df	/home/extra/user/torrents/Loreena McKennitt Discography/1987 To drive the cold winter away/To drive the cold winter away/To drive the cold winter away/02 Loreena McKennitt The Seasons.mp3
783	662	779	684	2012-11-30 05:04:18+00	0	\N	c1288cfae6c445fd6827d81610f1910f3c93cea1d88980b4f43b123f410382e2	/home/extra/user/torrents/Loreena McKennitt Discography/1997 Book of secrets/The Book of Secrets/Loreena McKennitt - 08 - Dante's Prayer.mp3
764	662	759	763	2012-11-30 05:04:15+00	0	\N	6bb7046a7108ea87c3ac644187b9045e8372441a6f0beb662efc3d6307e21441	/home/extra/user/torrents/Loreena McKennitt Discography/1987 To drive the cold winter away/To drive the cold winter away/To drive the cold winter away/10 Loreena McKennitt Let All That Are To Mirth Inclined.mp3
778	662	759	777	2012-11-30 05:04:17+00	0	\N	73f63744cf3f3d5be1ccf2d58ce1f8abcbc1dd53e0d91e65c7de17692ee83aaa	/home/extra/user/torrents/Loreena McKennitt Discography/1987 To drive the cold winter away/To drive the cold winter away/To drive the cold winter away/03 Loreena McKennitt The King.mp3
766	662	759	765	2012-11-30 05:04:15+00	0	\N	bda80d9e2af4e8ba08a48e82cc1ee55f9a60b2a20908fc8d70ffe85f052f4284	/home/extra/user/torrents/Loreena McKennitt Discography/1987 To drive the cold winter away/To drive the cold winter away/To drive the cold winter away/01 Loreena McKennitt In Praise Of Christmas.mp3
768	662	759	767	2012-11-30 05:04:15+00	0	\N	6271c74c5fd0e05446f6cc68c1a535c0066dc3626fbdbfec959ffab379cb688b	/home/extra/user/torrents/Loreena McKennitt Discography/1987 To drive the cold winter away/To drive the cold winter away/To drive the cold winter away/08 Loreena McKennitt The Wexford Carol.mp3
770	662	759	769	2012-11-30 05:04:16+00	0	\N	c861e1fde70daa062ab8ed1268334499881aedaff90498a2848282abf0f75a5c	/home/extra/user/torrents/Loreena McKennitt Discography/1987 To drive the cold winter away/To drive the cold winter away/To drive the cold winter away/04 Loreena McKennitt Banquet Hall.mp3
780	662	779	694	2012-11-30 05:04:17+00	0	\N	bb180fcbde4fdb227a06ccdfdf4f639b5292f9644efd4a72e10b9fab3adbc6da	/home/extra/user/torrents/Loreena McKennitt Discography/1997 Book of secrets/The Book of Secrets/Loreena McKennitt - 01 - Prologue.mp3
772	662	759	771	2012-11-30 05:04:16+00	0	\N	2dbaeac740a7aee201c6cf0dcda6a33a52d3d7db05b0333ca18e6cc4eab9b216	/home/extra/user/torrents/Loreena McKennitt Discography/1987 To drive the cold winter away/To drive the cold winter away/To drive the cold winter away/09 Loreena McKennitt The Stockford Carol.mp3
774	662	759	773	2012-11-30 05:04:16+00	0	\N	d84a50a6c686513fab667cc306b924d989dd12f8f1a32066ffb6b6c6d0ecabe1	/home/extra/user/torrents/Loreena McKennitt Discography/1987 To drive the cold winter away/To drive the cold winter away/To drive the cold winter away/07 Loreena McKennitt Let Us The Infant Greet.mp3
1299518	1299517	1042813	1299516	2012-11-30 07:25:54+00	0	\N	0c4148f2d912375dfc19f1f43a7d2a3ba4e442929ad2c693a715b24b5b396c50	/home/extra/youtube/music/Chrono_Trigger_-_Corridors_of_Time_Piano_Violin_Trio_feat_Lara_Amaterasu-kGjfRhBXwzw.vorbis.ogg
784	662	779	690	2012-11-30 05:04:19+00	0	\N	8eee861c7c038ef016ea1de00e71dd08de81bd694fd40fb82f8abdc0926a8d0d	/home/extra/user/torrents/Loreena McKennitt Discography/1997 Book of secrets/The Book of Secrets/Loreena McKennitt - 03 - Skellig.mp3
781	662	779	688	2012-11-30 05:04:17+00	0	\N	182aa994c880d4ea14d2db94d6128c330c8834d42f5d9b047056f3c9b6c759af	/home/extra/user/torrents/Loreena McKennitt Discography/1997 Book of secrets/The Book of Secrets/Loreena McKennitt - 04 - Marco Polo.mp3
782	662	779	696	2012-11-30 05:04:18+00	0	\N	51d0b9f72a72ad0cb56f07e9972443f3544b64596ae68701c58af57c8189ff38	/home/extra/user/torrents/Loreena McKennitt Discography/1997 Book of secrets/The Book of Secrets/Loreena McKennitt - 06 - La Serenissima.mp3
787	662	779	692	2012-11-30 05:04:20+00	0	\N	babcaf9bae8153d859d5b7a0991cb0434d2c989749e43f5d1ca14852873a5e9a	/home/extra/user/torrents/Loreena McKennitt Discography/1997 Book of secrets/The Book of Secrets/Loreena McKennitt - 07 - Night Ride Across the Caucasus.mp3
785	662	779	686	2012-11-30 05:04:20+00	0	\N	504f3dad551686ed0d4495c380a10df5de398b9dda09c1ffdf8e23722d1e8058	/home/extra/user/torrents/Loreena McKennitt Discography/1997 Book of secrets/The Book of Secrets/Loreena McKennitt - 02 - The Mummers' Dance.mp3
791	662	789	711	2012-11-30 05:04:21+00	0	\N	dfeb4958763dfb35f4ae330a586550f4789729cb655f6d79eb6c3f52e3fc6dce	/home/extra/user/torrents/Loreena McKennitt Discography/1991 The Visit/The visit/The visit/02. Bonny Portmore.mp3
786	662	779	681	2012-11-30 05:04:20+00	0	\N	85a1f560fb42bb72ab46d3a6997cad087963af0f8fa09cc6996d1b2942ff23ce	/home/extra/user/torrents/Loreena McKennitt Discography/1997 Book of secrets/The Book of Secrets/Loreena McKennitt - 05 - The Highwayman.mp3
790	662	789	788	2012-11-30 05:04:20+00	0	\N	3ac174b0818ffeb2840e404880c16f01c4c260cfe5e6a04339504d561746d857	/home/extra/user/torrents/Loreena McKennitt Discography/1991 The Visit/The visit/The visit/06. Tango To Evora.mp3
793	662	789	792	2012-11-30 05:04:21+00	0	\N	5077fb98a5a26e05bd6a7e0c30b0dfe2ed1aa987805a0330b169a67883c7e511	/home/extra/user/torrents/Loreena McKennitt Discography/1991 The Visit/The visit/The visit/01. All Souls Night.mp3
794	662	789	707	2012-11-30 05:04:22+00	0	\N	b6640a4ce8403be749b67bbb8fe5d3d821b4abbafa6c003f20982ec2837392e3	/home/extra/user/torrents/Loreena McKennitt Discography/1991 The Visit/The visit/The visit/09. Cymbeline.mp3
760	662	759	726	2012-11-30 05:04:14+00	0	\N	d6f3d0524a3e479eaba01e36217198689c49701fdd8f5697afac84fc8c07ab2f	/home/extra/user/torrents/Loreena McKennitt Discography/1987 To drive the cold winter away/To drive the cold winter away/To drive the cold winter away/05 Loreena McKennitt Snow.mp3
1043042	1043041	\N	1043040	2012-11-30 06:04:21+00	0	\N	0d5082e28cc85dde8f9c4675b99b2ab6ca036eeaf81aa031a0bd9eff3300617d	/home/extra/music/shared/refrain.mp3
819	662	804	818	2012-11-30 05:04:26+00	0	\N	3c6cda3124e75cf481c9a6836a0c3b88fac8d9649bccab809d3ad86d9db1c1cb	/home/extra/user/torrents/Loreena McKennitt Discography/1985 Elemental/Elemental/Elemental/02 Loreena McKennitt She Moved Through The Fair.mp3
800	662	789	715	2012-11-30 05:04:23+00	0	\N	7ec79bd093d9353615790d1f8331caa9fb9bd568f6f32c92a5afc53a56f23a07	/home/extra/user/torrents/Loreena McKennitt Discography/1991 The Visit/The visit/The visit/08. The Old Ways.mp3
840	823	824	839	2012-11-30 05:04:28+00	0	\N	fa3cf30a170ff729f2c13816ae4bf39151fbfb4efdba54b79bbaa7b7decdf176	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/07 - Assimilation (Second Alternate Version).mp3
802	662	789	801	2012-11-30 05:04:24+00	0	\N	1ab514e71198797f09677835034fb13d03d1cb64cfbe887566f147e99043504f	/home/extra/user/torrents/Loreena McKennitt Discography/1991 The Visit/The visit/The visit/04. The Lady of Shalott.mp3
821	662	804	820	2012-11-30 05:04:26+00	0	\N	0ab40c46767e086ad5ffb63792954f2b540fbafe17bc3109b8eab387d6432266	/home/extra/user/torrents/Loreena McKennitt Discography/1985 Elemental/Elemental/Elemental/04 Loreena McKennitt The Lark In The Clear Air.mp3
805	662	804	803	2012-11-30 05:04:24+00	0	\N	f836c962254f517d69c56269c2d4c0e2a777fd2286283757b692fb027563e599	/home/extra/user/torrents/Loreena McKennitt Discography/1985 Elemental/Elemental/Elemental/09 Loreena McKennitt Lullaby.mp3
807	662	804	806	2012-11-30 05:04:24+00	0	\N	871c8f44f146344139394c6a808c47d8c0c1b1abb4b3e7b2290963b3cc05d15a	/home/extra/user/torrents/Loreena McKennitt Discography/1985 Elemental/Elemental/Elemental/05 Loreena McKennitt Carrighfergus.mp3
834	823	824	833	2012-11-30 05:04:28+00	0	\N	2504d0cf1ec638e15ffd4e390f9ac6fc134a17c11b01d9a9221603a6de4fa95d	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/11 - All The Time (Unused Cue).mp3
809	662	804	808	2012-11-30 05:04:25+00	0	\N	685be98a146ec1b017849235756a2821fe9354ad3b60c9ccb433fb5cf874035e	/home/extra/user/torrents/Loreena McKennitt Discography/1985 Elemental/Elemental/Elemental/08 Loreena McKennitt Come By The Hills.mp3
825	823	824	822	2012-11-30 05:04:27+00	0	\N	2d13b650d0ee7e20c7dc4758e085e04826daaa7979ed24083b90d7ec00773927	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/16 - Raw Sessions.mp3
811	662	804	810	2012-11-30 05:04:25+00	0	\N	d16a875e769c7aedd4c4324c9089a00084370431e2dff915e8891a47c106e99a	/home/extra/user/torrents/Loreena McKennitt Discography/1985 Elemental/Elemental/Elemental/07 Loreena McKennitt Banks Of Claudy.mp3
813	662	804	812	2012-11-30 05:04:25+00	0	\N	c13967919aa59c60232dff0ddc0d5928f6f89018a5dd93af93df74f979c9e860	/home/extra/user/torrents/Loreena McKennitt Discography/1985 Elemental/Elemental/Elemental/06 Loreena McKennitt Kellswater.mp3
815	662	804	814	2012-11-30 05:04:26+00	0	\N	29638ff5f43a368e9da71db49af6a038fe9ae62dacb621152b5d1828c8881884	/home/extra/user/torrents/Loreena McKennitt Discography/1985 Elemental/Elemental/Elemental/01 Loreena McKennitt Blacksmith.mp3
827	823	824	826	2012-11-30 05:04:27+00	0	\N	f2114fdc61f907bf372a046ad32476d11564d7ce1a794e340263be135bc86262	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/15 - After The Scoring Sessions.mp3
817	662	804	816	2012-11-30 05:04:26+00	0	\N	8644ab317638c1d59c78aa01c9ab46babf30630c0619361f8011d95022ae5726	/home/extra/user/torrents/Loreena McKennitt Discography/1985 Elemental/Elemental/Elemental/03 Loreena McKennitt Stolen Child.mp3
836	823	824	835	2012-11-30 05:04:28+00	0	\N	50300a8e759462a9c28fb3fba401d78d2a099f041dd22c3911f47f1a12db7fca	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/05 - Retreat (Commercial Release).mp3
830	829	824	828	2012-11-30 05:04:27+00	0	\N	763f19cfaa746a5aa8464485e7d315164e5f471b95e95fad704c053ccad313f1	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/14 - Ooby Dooby.mp3
832	823	824	831	2012-11-30 05:04:28+00	0	\N	f6ffc11017c848ca95265dbbc092a54471a84b5eb65edda4dfed16d6502145cb	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/08 - Fully Functional (Alternate Version).mp3
844	823	824	843	2012-11-30 05:04:29+00	0	\N	2486aa55a1d293b0d5239fd70223d53b18a4db75034ed507c5b84c417086c982	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/02 - Greetings (Alternate Version).mp3
838	823	824	837	2012-11-30 05:04:28+00	0	\N	f2cf54da19a88bf177d9efad701e39dfe97a416a2f7b7b26e2bbf76b3318d3b6	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/12 - End Credits (Insert).mp3
842	823	824	841	2012-11-30 05:04:28+00	0	\N	53588022c846ef41aa3dbbe48ccc7b75d28c9a529b99b1030c3106989b5cbf20	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/10 - First Contact (Commercial Release).mp3
846	823	824	845	2012-11-30 05:04:29+00	0	\N	7ab6f929e53427efdd9e7b56ba158b1f83cd462b751dcaaa17ca8e6218185df3	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/03 - 39 1 Degrees Celcius (Insert).mp3
848	823	824	847	2012-11-30 05:04:29+00	0	\N	93d6a436877afc81daddac0098f34b8cc0c4b9e188611f9352835d7346853cc7	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/04 - 39 1 Degrees Celcius (Alternate Version).mp3
1299520	\N	\N	1299519	2012-11-30 07:25:55+00	0	\N	b107da1a819d607f47a6372d937afa9275c0f5e5809f14e5c1b952f4b8b86a39	/home/extra/youtube/music/Eric_Whitacre_s_Virtual_Choir_-_Lux_Aurumque-D7o7BrlbaDs.aac
1299522	\N	\N	1299521	2012-11-30 07:25:55+00	0	\N	5de982a570058cf198e634effee8fe307aa111840bcd98b371b2690a25b67cbe	/home/extra/youtube/ponies/Heaven's_light_(ANIMATIC)-NL_99jYTV5I.vorbis.ogg
799	662	789	703	2012-11-30 05:04:23+00	0	\N	292a204db154f831a30c04c3b121ce0a4cfb25baaf268344731145e7f2bf101c	/home/extra/user/torrents/Loreena McKennitt Discography/1991 The Visit/The visit/The visit/03. Between the Shadows.mp3
856	823	824	855	2012-11-30 05:04:30+00	0	\N	ca7729adda1aa3ccd0d4f4ae72c6537a0b69599d80c626a2d5e96bd055779b14	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/17 - First Contact (Live In Concert 6-2001).mp3
876	823	861	875	2012-11-30 05:04:33+00	0	\N	c42e06119f4e2484712ee37d909f307780ebce27554432b84428f22217f5f7f1	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/02 - Locutus.mp3
859	858	824	857	2012-11-30 05:04:31+00	0	\N	e3385c3bdbac2cebe54a9297d35ab71b26bba78f1a7811acf607583932f5f20b	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/13 - Magic Carpet Ride.mp3
862	823	861	860	2012-11-30 05:04:31+00	0	\N	cc464d270acb9b5d844d49b8aa5e775c38b12f461c006d0e4a51293a4bb451ad	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/24 - The Escape Pods - Into The Lion's Den.mp3
894	823	861	893	2012-11-30 05:04:35+00	0	\N	cf99052c8e1fe645771fca7cbbc14b897fd350d25089aa8b6d0b5a827d3941bf	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/20 - The Dish (Film Version).mp3
864	823	861	863	2012-11-30 05:04:31+00	0	\N	01e5f14973c16d29018358603cf267bc953ed6941f7c927394e8a304868b4062	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/25 - The Starship Chase.mp3
878	823	861	877	2012-11-30 05:04:33+00	0	\N	255747a1548d4b1a26c8901a463220361c383740d2b01c9e20280fc76a8af8c7	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/16 - The Gift Of Flesh.mp3
866	823	861	865	2012-11-30 05:04:31+00	0	\N	42554df2112ac0d79f6a07a18ed2b95c5b8b94b01bdb74d03727fad59b282546	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/27 - The Future Restored - Victory Over The Borg.mp3
868	823	861	867	2012-11-30 05:04:32+00	0	\N	129bcf2b59da3096692a9fb6c29778f5cedf6602b458474de89a7369bb258aa4	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/04 - Starfleet Engages The Borg.mp3
888	823	861	887	2012-11-30 05:04:34+00	0	\N	df2370641293a0b14385625e97afc977f9227ce1c00baed3354705f6d147b16b	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/18 - Watch Your Caboose- Dix.mp3
870	823	861	869	2012-11-30 05:04:32+00	0	\N	be980789819a193703297cd41eb9c76552951376aa515d98a906f0d1ed4744ad	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/21 - Bridge Argument.mp3
880	823	861	879	2012-11-30 05:04:33+00	0	\N	fd89f40796df2798e3ab21d8d01f59345b3451c15457ebc8318bd67513112780	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/09 - First Sign Of Borg.mp3
872	823	861	871	2012-11-30 05:04:32+00	0	\N	1c49d8c10699a91c82fcc43197e556716d5cb6bc6c8954f6864f275873407ef5	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/29 - End Credits.mp3
874	823	861	873	2012-11-30 05:04:32+00	0	\N	13979118adf562bd24946ebed98c7c7edea1235ee47938b9c5b67deea47a6afc	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/11 - Approaching Engineering.mp3
882	823	861	881	2012-11-30 05:04:33+00	0	\N	f6516c8371df2c3bbfaf0543453a921242d07ca78633cccafa3adad7147a0e8e	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/06 - Temporal Wake.mp3
884	823	861	883	2012-11-30 05:04:33+00	0	\N	678d2673a9e6bf934bea7b3c3aac71e19c67e93c04b0ceb6b0a8e566f302580b	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/13 - Data Awakes In Engineering.mp3
890	823	861	889	2012-11-30 05:04:34+00	0	\N	4efc13ca6fa0114b1d0037a6da42effe810085a01553efc81e34139636257126	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/01 - Main Title.mp3
886	823	861	885	2012-11-30 05:04:34+00	0	\N	ab27b79e648e19b457fb8cea92a1d789f66df13f43dec139f74e7f64ae4ac308	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/10 - 39 1 Degrees Celcius.mp3
898	823	861	897	2012-11-30 05:04:35+00	0	\N	ed3ddc69dddbb732c89e10c761f495133a006639e93dd1fdbb2cf8992d80326b	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/03 - The Enterprise E - Captain's Log.mp3
892	823	861	891	2012-11-30 05:04:35+00	0	\N	128610affa2a1f0fcb1dd2b5a96cafc78832bb9bc67354451bf4629720954d8b	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/19 - Fully Functional.mp3
896	823	861	895	2012-11-30 05:04:35+00	0	\N	a06f0ea665d3e0ed53bf2639709db5f40cb3fa1f7d2b55b5bab642bbbfab6e7d	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/22 - A Quest For Vengeance.mp3
900	823	861	899	2012-11-30 05:04:35+00	0	\N	92d373c06e2f7d211b3f1561445f01c1d7b00b30022fc8432ee24e9f21c79015	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/08 - Greetings.mp3
902	823	861	901	2012-11-30 05:04:36+00	0	\N	e89b991c2c2f85f17ab8194abea0ae646952cc68862f5bc8773c6bf20e774c52	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/14 - Assimilation.mp3
904	823	861	903	2012-11-30 05:04:36+00	0	\N	9734312aa44a26a137bd53ad74831aaf43ec333a2effc5a67d6eb4c8c9d65f36	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/28 - First Contact.mp3
1299524	\N	\N	1299523	2012-11-30 07:25:55+00	0	\N	60cbbe58a759c2f75c63ba6b38e71d61184cfc1c11519e0766070aec14942266	/home/extra/youtube/ponies/Alice_Manikin_Sacrifice-l5Vg9zNGGrA.vorbis.ogg
854	823	824	853	2012-11-30 05:04:30+00	0	\N	3932bb2d54c9811ff434d1389f859053c2d4ca92b90b0a5756e7ed5f4e47a1c2	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/01 - Main Title (Different Take).mp3
932	919	920	931	2012-11-30 05:04:38+00	0	\N	1855c1361095dd93908870513a1e63cab7b11f3e23bf22eabecbeef38a741dd1	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 04 - The Voyage Home 1986/08-Time Travel.mp3
912	823	861	911	2012-11-30 05:04:36+00	0	\N	221db3c5c51d0962cc926d2c27b347aa00c105b6cf0f1a8acff07e0b0899dc1b	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/15 - Welcome Aboard.mp3
944	919	920	943	2012-11-30 05:04:40+00	0	\N	98b25ab756bc6b7207b25b971c6c6f1efd4aeffb17308be621c598c8452215b9	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 04 - The Voyage Home 1986/04-Crash-Whale Fugue.mp3
914	823	861	913	2012-11-30 05:04:37+00	0	\N	dda44c36cbc467961730c46fc71e3b0b6f89609101b40a1cf8f1a919f6ff6c31	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/05 - Red Alert.mp3
934	919	920	933	2012-11-30 05:04:39+00	0	\N	673972d32de4fe01749ff29dd1f9bc88be66628e73505ed2260b4d73fac0f39d	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 04 - The Voyage Home 1986/07-Chekov's Run.mp3
916	823	861	915	2012-11-30 05:04:37+00	0	\N	0c41cd8d24a31788329bdeb3ef4c087e6a4ea696a2458ca5494bffe8ca0f4610	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/07 - April 4Th- 2063.mp3
918	823	861	917	2012-11-30 05:04:37+00	0	\N	3b23641e5a44b7a20c69a742e4f9170a610af8e926698c4795040944a74d52f9	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/12 - Retreat.mp3
921	919	920	889	2012-11-30 05:04:37+00	0	\N	be4495965abfcc49e6360684ed7bb3e764a0fa8a4d53b171f8fea6ed4afcc241	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 04 - The Voyage Home 1986/01-Main Title.mp3
936	919	920	935	2012-11-30 05:04:39+00	0	\N	bf31c7801eb6265dcd2c603a3384dea77106ef9dc18b3cbc8ecf83d08c077673	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 04 - The Voyage Home 1986/03-The Yellowjackets _ Market Street.mp3
924	923	920	922	2012-11-30 05:04:38+00	0	\N	fbfea46c926056a1910efaebabe01201fdb5829245403e125de19c0f61446d8c	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 04 - The Voyage Home 1986/12 - Edge Of Ettiquette (Kirk Thatcher) - I Hate You.mp3
926	919	920	925	2012-11-30 05:04:38+00	0	\N	1a8377e2b5ce1bc28b2c9ebc876d5267299f885dc35c371f17066e0d28779fec	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 04 - The Voyage Home 1986/02-The Whaler.mp3
928	919	920	927	2012-11-30 05:04:38+00	0	\N	2f6e9c178bf558f901602690f431a5227ffe338c57204d5930923ac6a86413ca	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 04 - The Voyage Home 1986/11-Home Again_ End Credits.mp3
938	919	920	937	2012-11-30 05:04:39+00	0	\N	c0f8b9f937c40b900dee239189e92872f701d7efe546b60761b07663793eaf06	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 04 - The Voyage Home 1986/05-The Yellowjackets _ Ballad of the Whale.mp3
930	919	920	929	2012-11-30 05:04:38+00	0	\N	d87bd816b7f9b6bee9602943e9fab1d2e4fc95597a0a55ef8776ff24662096ac	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 04 - The Voyage Home 1986/10-The Probe.mp3
948	946	947	945	2012-11-30 05:04:40+00	0	\N	e02776773818c0da26c7c8b76576edbc0c1cde483cd95e3f838f55ff568e12be	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 02 - The Wrath of Khan 1982/01 - ST II - Main Title.mp3
940	919	920	939	2012-11-30 05:04:39+00	0	\N	78e3cca77e31470b2fd9c6ef7f357871332961936bc93b0ea8affd0fb1dcb77d	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 04 - The Voyage Home 1986/09-Hospital Chase.mp3
942	919	920	941	2012-11-30 05:04:40+00	0	\N	422e5503e1331a660b7e0ba0cec788bbdc58dea3931804341d7cae84ba48b0b6	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 04 - The Voyage Home 1986/06-Gillian Seeks Kirk.mp3
954	946	947	953	2012-11-30 05:04:41+00	0	\N	29ca7e6b352499bf81fcce1018aed6b53f76a06c88a308204acb6094135197e5	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 02 - The Wrath of Khan 1982/04 - ST II - Kirk's Explosive Reply.mp3
950	946	947	949	2012-11-30 05:04:40+00	0	\N	2cb7e4b524f27f87df0a9fe38f038fffe63722b31d94fd5997bb466c899f5d6f	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 02 - The Wrath of Khan 1982/05 - ST II - Khan's Pets.mp3
952	946	947	951	2012-11-30 05:04:41+00	0	\N	d5199797f6968d7a3bab11ce3e133b9f2b137344639ee3a2d4e9cd04ac36a6c3	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 02 - The Wrath of Khan 1982/08 - ST II - Genesis Countdown.mp3
958	946	947	957	2012-11-30 05:04:42+00	0	\N	84c694ebf3414e597610d9eb0730e8e552d2ed77f389bffb83ccc176ccc9cc9c	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 02 - The Wrath of Khan 1982/03 - ST II - Spock.mp3
956	946	947	955	2012-11-30 05:04:41+00	0	\N	23afd826275aa92adf29a20442c64a06a298f1fc89b9db975d0b0199ab75c68d	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 02 - The Wrath of Khan 1982/07 - ST II - Battle In The Mutara Nebula.mp3
960	946	947	959	2012-11-30 05:04:42+00	0	\N	ee7fcf2ffcf9dc25ec8078570c264d66c768f3f1015026553c9d9da123ff4ed2	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 02 - The Wrath of Khan 1982/06 - ST II - Enterprise Clears Moorings.mp3
962	946	947	961	2012-11-30 05:04:42+00	0	\N	dd376f2b409c3178e591ca5871fa2cf403dc8905b33a07b55014f711a07d0718	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 02 - The Wrath of Khan 1982/09 - ST II - Epilogue - End Title.mp3
1299526	\N	\N	1299525	2012-11-30 07:25:55+00	0	\N	8b7b1a8ea754c5f50a106e0dd253acd685934117c2b59faebe3182e3daad92f6	/home/extra/youtube/ponies/Fluttershy_gets﻿_BEEBEEPED_in_the_maze-AH_ulLbQr0Y.vorbis.ogg
908	823	861	907	2012-11-30 05:04:36+00	0	\N	cb93fb68290533ff362f50d3733e4122330471123ace063701363fbb1cf6e0a0	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/23 - Evacuate.mp3
989	966	967	988	2012-11-30 05:04:45+00	0	\N	e409f746c0dfbe25e9668a17c834acc6b276af9687b10759d7ff28faabea73c9	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/14 - Kirk's Death.mp3
971	966	967	970	2012-11-30 05:04:43+00	0	\N	b2781396574a59ae816dd3ae426f9c5c4f95cf475e3c4707e3e374cbf91da886	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/21 - Enterprise B Deflector Beam.mp3
1001	966	967	1000	2012-11-30 05:04:46+00	0	\N	709c94975f463a129b3df8b7257049a2cbf622aec1e80ff8ca716d127ae20aab	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/20 - Nexus Energy Ribbon.mp3
973	966	967	972	2012-11-30 05:04:43+00	0	\N	ae30fa2752bb4080d699ff30fb9255fd401ebe1e12fff658931eb2e2e1d6db32	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/08 - Out Of Control - The Crash.mp3
991	966	967	990	2012-11-30 05:04:45+00	0	\N	9e69b02b1c0a1a10a4f15608c2051923cb0175f5f156007ae5664b46bb82f487	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/38 - Enterprise D Warp-out #2.mp3
975	966	967	974	2012-11-30 05:04:44+00	0	\N	f5842d6977a7c61bc65e5cca1ce3dd107bdc296d35b3fffa4817b5d8e69f821b	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/31 - Bird Of Prey Cloaks.mp3
977	966	967	976	2012-11-30 05:04:44+00	0	\N	79274a1a70e3f53ae6cd48c76117aa0483dd9dee98d136864aa7fd63953a5e1d	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/11 - Jumping The Ravine.mp3
979	966	967	978	2012-11-30 05:04:44+00	0	\N	4cffb05cef6fc7d6edbe263d9fdd33723c8ffe8ad90e8b18f10c66dfed123c84	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/23 - Enterprise D Transporter.mp3
993	966	967	992	2012-11-30 05:04:45+00	0	\N	715341b304427350cd404d65112996bd3d79c28bdf342c331de0cbb611b812f7	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/04 - Deck 15.mp3
981	966	967	980	2012-11-30 05:04:44+00	0	\N	c33cc3da5e4dc85a10c8383a841f56e0d339d91ac7c088cdaf581b681608afa1	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/15 - To Live Forever.mp3
983	966	967	982	2012-11-30 05:04:44+00	0	\N	a6efa3a55e3e74c80063b8b1b939d1f17aef49e88fd1cac762b30fa45b7f4d5b	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/34 - Soran's Gun.mp3
985	966	967	984	2012-11-30 05:04:44+00	0	\N	875777b37ce13fbcbdd4755d4150b400d1dfde2eff636efd5bd24e3bb0e473e9	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/06 - Prisoner Exchange.mp3
995	966	967	994	2012-11-30 05:04:45+00	0	\N	f92c27656cfedb8171a4120129226e572d3b7660e2e76723f886e2a2a2dc64bb	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/32 - Bird Of Prey De-cloaks.mp3
987	966	967	986	2012-11-30 05:04:44+00	0	\N	94ecfd36511a3a8fa1bcfbacbbdb11226fdeca1ba4f1491bf4c0532ed0c97e3b	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/35 - Soran's Rocket De-cloaks.mp3
1003	966	967	1002	2012-11-30 05:04:46+00	0	\N	915a7fd74962f627c8eea2d1e76c9ddd2a1e188b016aa914077ab167a2c1cb45	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/07 - Outgunned.mp3
997	966	967	996	2012-11-30 05:04:45+00	0	\N	20c9204cf9965bea0e23b515b81e231f7dc145b2ecc390d018b986a6e487dce3	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/03 - The Enterprise B - Kirk Saves The Day.mp3
1013	966	967	1012	2012-11-30 05:04:47+00	0	\N	18954ed0df85880dd8981bedabeebe31571f1b51ff1b3db762b8e590d8da333e	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/01 - Star Trek Generations Overture.mp3
999	966	967	998	2012-11-30 05:04:46+00	0	\N	6d361fd8b158ccf3ab8eafc0a4424b7035413c9a17b3405ebd808be95a7278ff	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/16 - Enterprise B Bridge.mp3
1009	966	967	1008	2012-11-30 05:04:47+00	0	\N	4e6d2e04c59d176b39166bdf00bf5ea7fe8d4147ad388e3634efdc54fbb94fb8	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/19 - Enterprise B Helm Controls.mp3
1005	966	967	1004	2012-11-30 05:04:46+00	0	\N	e0cf5e59d88a8d7007bec9b85a5f9d39bc418da300582d7b52d62f55c0658d54	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/13 - The Final Fight.mp3
1007	966	967	1006	2012-11-30 05:04:47+00	0	\N	bbd92c99f2b29c5a9fab824a9e97f6511ee3a425b7e0a01c0e63cf7317ca40d4	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/27 - Door Chime.mp3
1011	966	967	1010	2012-11-30 05:04:47+00	0	\N	fa47d4d8862c42b0a5afd8ad32b56fdb6755244601e7695dc9920af810cc86b5	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/28 - Enterprise D Warp Out #1.mp3
1015	966	967	1014	2012-11-30 05:04:47+00	0	\N	10b65e3248a4d319809ca60542652c675e4a7fc7b71c284dbc34fe8c22249288	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/36 - Shuttlecraft Pass-by.mp3
1017	966	967	1016	2012-11-30 05:04:48+00	0	\N	cd992d12bceb349e95dc6f1a088113527da4a2fe2e4ddf1748d8ff6ec654ca1d	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/12 - Two Captains.mp3
1299528	\N	\N	1299527	2012-11-30 07:25:55+00	0	\N	7a33578610c60bca6a6464a850148d7eb7d8c150bb2366117a53b4f187c31db7	/home/extra/youtube/ponies/[PMV]_-_The_Garden-MAVQk8CSU9w.vorbis.ogg
969	966	967	889	2012-11-30 05:04:43+00	0	\N	7eca6dae6d3565c3bd535cd63047f644720a1e5a5155ca91a5e0a1e56a781417	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/02 - Main Title.mp3
968	966	967	965	2012-11-30 05:04:43+00	0	\N	5ca92a454e44c108f0d9235697db87c8cf37ef081cbae8c30df73c7f533f721c	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/18 - Distress Call Alert.mp3
1044	823	1043	1042	2012-11-30 05:04:50+00	0	\N	2e61ce515bde6424952ce20e64db408408c27808734f573134ccb37eeab9b8cd	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/15 - Ideals.mp3
1025	966	967	1024	2012-11-30 05:04:48+00	0	\N	79ee05fdda6f7786fda3f4d199d0a74a6f7bb7ed76a97b692fb40b3992643688	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/09 - Coming To Rest.mp3
1027	966	967	1026	2012-11-30 05:04:48+00	0	\N	fb42eaea7de2dfcbfdbf2df5a53da4a3ecc21bf75cdf1f99cdddd2f5b744aba3	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/24 - Tricorder.mp3
1046	823	1043	1045	2012-11-30 05:04:50+00	0	\N	293f0ce699beb1b957206b60309143e19c6b7ed8256f29a18a34a45fa74256da	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/16 - 'We Are Wasting Time'.mp3
1029	966	967	1028	2012-11-30 05:04:48+00	0	\N	6ff217f2ab3b295c0c726905d8f9ef825ebd682eaa31ed1050865f7edd7159e4	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/30 - Klingon Sensor Alert.mp3
1031	966	967	1030	2012-11-30 05:04:49+00	0	\N	e234d0676d456b5f9fd0ad768343bd3a057bf3de3eef3ce539f4fd4aa60546e0	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/37 - Enterprise D Bridge - Crash Sequence.mp3
1033	966	967	1032	2012-11-30 05:04:49+00	0	\N	173423643221b2b00adbbb684587cd8d90827504e37dd4d27ab3ad30b1d56a5d	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/33 - Klingon Transporter.mp3
1048	823	1043	1047	2012-11-30 05:04:50+00	0	\N	9c90d16c638c1db2f6da6254634add9b9712122f7f358a0aabc9775c36b8e454	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/18 - B-4 Beams to the Scimitar.mp3
1035	966	967	1034	2012-11-30 05:04:49+00	0	\N	ec13b5cb9b2ca85d29bde9ace71f1c54df727ac517d6555a43c138deb73cd022	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/10 - The Nexus - A Christmas Hug.mp3
1037	966	967	1036	2012-11-30 05:04:49+00	0	\N	8d5ec6e9a2878e1a01f25d6d59abbfe494566c522bc45e226d4bc55f7561b772	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/26 - Communicator Chirp.mp3
1056	823	1043	1055	2012-11-30 05:04:51+00	0	\N	e6a8ab22b9648d42545d1a44be4ac6510d5c93b795488a82255d65130cba3870	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/10 - Repairs.mp3
1039	966	967	1038	2012-11-30 05:04:49+00	0	\N	ef87baf4ddd8222f91c1c1c318a09fb0622671c0b13188120d93342014a48c3d	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/17 - Enterprise B Doors Open.mp3
1050	823	1043	1049	2012-11-30 05:04:50+00	0	\N	c007c73648bafd952ede005d225dc2a246a7a0a9e80fc157e75444c626500b43	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/01 - Remus.mp3
1041	966	967	1040	2012-11-30 05:04:50+00	0	\N	dae022bad0ee5b058f6c964bbe38509fef5b76f6c72bfd495a9da37e63d84e02	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/25 - Hypo Injector.mp3
1062	823	1043	1061	2012-11-30 05:04:52+00	0	\N	04792c1f0cd697b1b7c1edd6711d4f1a7f831231efe33f99396fab09326b3aef	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/19 - Capturing Picard.mp3
1052	823	1043	1051	2012-11-30 05:04:51+00	0	\N	4242353e9d8d4a47360b375a966d540e4ba6df9c83dcaaf310d020165a1fcb5f	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/13 - Donatra and Shinzon.mp3
1058	823	1043	1057	2012-11-30 05:04:51+00	0	\N	c699b5731f4f6fdf3ef1f1c1d9c059bdf6e94a95ca2ba074268c49450a94250c	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/20 - The Mirror.mp3
1054	823	1043	1053	2012-11-30 05:04:51+00	0	\N	7c0be7f87257ff5d892acb200aa2f4b5169426833a2b33cfb560e5dd2133e376	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/12 - Shinzon and the Senate.mp3
1060	823	1043	1059	2012-11-30 05:04:52+00	0	\N	d5bcc1bbf1e9ad19c44b58da3ac2dd221d18fda508169b64dd127a277932da6f	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/05 - Catching a Positron Signal.mp3
1064	823	1043	1063	2012-11-30 05:04:53+00	0	\N	15846cf834d8b709c73ad0e8f80422859d04f37a64febaa93f49d090c89a8956	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/03 - My Right Arm.mp3
1066	823	1043	1065	2012-11-30 05:04:53+00	0	\N	a5043766a24151bb780a7511b64d8001314c816d9bb47575a6b6eac0418216b7	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/02 - The Box.mp3
1068	823	1043	1067	2012-11-30 05:04:53+00	0	\N	35ac8cb5c578bb0214d261fa010b6d52d7f5ef437b50a585cb0015065b586b26	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/17 - Shinzon's Violation.mp3
1299530	\N	\N	1299529	2012-11-30 07:25:55+00	0	\N	6e32dd7f6248e180841fcfa925e1f798ca5878aadd5a25a85dff6906b025d52b	/home/extra/youtube/ponies/PinkiePieSwear_-_Luna,_Please_Fill_My_Empty_Sky-uZ_7xq1TIW4.vorbis.ogg
1023	966	967	1022	2012-11-30 05:04:48+00	0	\N	3cd3e00cc2c67719f5f02c31b2a6077d95c376e16dbc5e4ba7136aa9353712a2	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/05 - Time Is Running Out.mp3
1076	823	1043	1075	2012-11-30 05:04:54+00	0	\N	68c0bbd5d1e964b12200b1718986a3d686327726c31d5d0631242ebf7bb0a37c	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/07 - Odds and Ends.mp3
1094	823	1085	1093	2012-11-30 05:04:56+00	0	\N	ad71e04350efb745b936f1498db342606664c1ec2f722d840a8ce6308587c476	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/16 - A New Friend.mp3
1078	823	1043	1077	2012-11-30 05:04:55+00	0	\N	73e04eb9340e8884edf34a6bf33be1659fd7af510f93a573229bfcd49bc3a8d8	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/11 - The Knife.mp3
1080	823	1043	1079	2012-11-30 05:04:55+00	0	\N	d7d933a7f0a5fbe333f0057bdbcb8b691abef6e1d2dfc19978019d5a768aa3ed	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/14 - The Dilithium Mines of Remus.mp3
1104	823	1085	1103	2012-11-30 05:04:58+00	0	\N	39107bf06e466ab65de8fab77c4c48ac71ec2285ced33d1455952ca5863a64b9	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/17 - Remembering Data - The Enterprise.mp3
1083	823	1082	1081	2012-11-30 05:04:55+00	0	\N	be9d7f7ad52350f79c8b4483d1755a6d747db5f8c9f2d07a3eec4da389a1e990	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/08 - Assembling B-4.mp3
1096	823	1085	1095	2012-11-30 05:04:57+00	0	\N	83182dbe99f0615bb2e80dabe632bea5ada128f54b6362b12b721bf7f5f4a43b	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/03 - De-Activating B-4.mp3
1086	823	1085	1084	2012-11-30 05:04:55+00	0	\N	471e4b3f2ab48d1cba3a9a6e23ac4268976fb36fb74f1942243c8b120715730f	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/02 - The Senate Changes Attitude.mp3
1088	823	1085	1087	2012-11-30 05:04:56+00	0	\N	6376f07192fb01b02dbb6c99d4757146d00600057785573a8ccbb2e0f59d35f4	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/13 - The Thaleron Matrix.mp3
1090	823	1085	1089	2012-11-30 05:04:56+00	0	\N	68968cc07d52a7fa445bbfa1154711155a110fa80173bf097393c161bee90ebf	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/18 - 'It's Been an Honor'.mp3
1098	823	1085	1097	2012-11-30 05:04:57+00	0	\N	99fa680b99f25ebc7d5048723a0ae2a31aa0bef298e0fc0e8f63011ac8d398bb	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/08 - Team Work.mp3
1092	823	1085	1091	2012-11-30 05:04:56+00	0	\N	ea568f064c6a81e78e8d66ba2d8bb8a6ce93402a763ed123fbe72f2f80fe860a	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/11 - Engage.mp3
1100	823	1085	1099	2012-11-30 05:04:58+00	0	\N	3ce5e990afd4fc8d116754aae461888875e7cde94a370ffccced1ccae1d2d1e3	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/09 - Lateral Run.mp3
1106	823	1085	1105	2012-11-30 05:04:58+00	0	\N	6920cd82aedcf9830a2793c41b0dc921d6fa0175437da2dc395098335c24cd3f	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/07 - 'Our True Nature'.mp3
1102	823	1085	1101	2012-11-30 05:04:58+00	0	\N	5198606bbd689c6d25b66fc872b060f130e32dc80d9e00542e64aa00346036d5	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/10 - Riker vs. Viceroy.mp3
1110	823	1085	1109	2012-11-30 05:04:59+00	0	\N	472a784f898b1572d7159ef7e5d00858ce10aed870a7275a0e4ee4fb03bf949f	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/12 - Riker's Victory.mp3
1108	823	1085	1107	2012-11-30 05:04:58+00	0	\N	dd4dd14853bd73f05285830fffc1843d6d41a096510c499ac2f0793f7ff33108	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/05 - The Battle Begins.mp3
1112	823	1085	1111	2012-11-30 05:04:59+00	0	\N	35b47d13966c7dd9550d210c0eba932a8b4549efde811d226d45f19df91a6ee7	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/06 - Meeting in the Ready Room.mp3
1114	823	1085	1113	2012-11-30 05:04:59+00	0	\N	3dd5730176361e1215b07e09f2cf5ef3fa3a8a0484db6312c21cfd1bb2e32742	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/19 - A New Ending.mp3
1116	823	1085	1115	2012-11-30 05:05:00+00	0	\N	39dc0ae6ae21cac240d97a81623a2d2c31188434f1c3abc9a231cdbdbc48d80e	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/04 - Preparing for Battle.mp3
1299532	\N	\N	1299531	2012-11-30 07:25:56+00	0	\N	fa8828a6ce2a543091b489aea38ab067790239f13e63a94bc55f9ccdace91f27	/home/extra/youtube/ponies/PinkiePieSwear_-_Trixie_s_Good_Side-TFWpr_wkgV8.vorbis.ogg
1074	823	1043	1073	2012-11-30 05:04:54+00	0	\N	fddbe2b24ab66ee24af1e56549d535b4c300310ae6aadb74543b8b05a73c5ea0	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/06 - The Argo.mp3
1147	823	1142	1146	2012-11-30 05:05:04+00	0	\N	ee41685509ae383fd9559b5d113f30661a3b04e56586b7f31a364330a1dd1873	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 09 - Insurrection 1998/03 - Children's Story.mp3
1139	946	1124	1138	2012-11-30 05:05:03+00	0	\N	04ea5c1fa2f8f8d7f2808e24aac36960bbbf0d53d9164cd6a3ab6ed7c3831e51	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 03 - The Search for Spock 1983/03-Stealing the Enterprise.mp3
1155	823	1142	1154	2012-11-30 05:05:04+00	0	\N	2c0b0176ca699489bfa4ad0b1b3a329c3c6c9926e1080c129df8c209a9d76042	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 09 - Insurrection 1998/04 - Not Functioning.mp3
1149	823	1142	1148	2012-11-30 05:05:04+00	0	\N	6bfe922a58b2142a228784ee6f8219defd03a86532f75dbb755a0c300e4c2af4	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 09 - Insurrection 1998/01 - Ba'Ku Village.mp3
1141	946	1124	1140	2012-11-30 05:05:03+00	0	\N	f2193093e0d0beb67072e281a481a4af8c0a6bc3627e5a69dd6e38006ebf2c86	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 03 - The Search for Spock 1983/02-Klingons.mp3
1163	823	1142	1162	2012-11-30 05:05:05+00	0	\N	d6897edab9d0c52df3b4a7350a65b05c6d2785ffa29418d12df0a46383ff22ce	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 09 - Insurrection 1998/07 - The Riker Maneuver.mp3
1157	823	1142	1156	2012-11-30 05:05:05+00	0	\N	ab5c57b2f0da338e57b1bc00efb1a8dd8e34b1360ebb114bd982f63a0f91a359	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 09 - Insurrection 1998/02 - In Custody.mp3
1151	823	1142	1150	2012-11-30 05:05:04+00	0	\N	9b8b061bd910e6a3a84895b930bfde26da5b2129ad9a0471768a33f4f55d2748	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 09 - Insurrection 1998/09 - No Threat.mp3
1143	823	1142	871	2012-11-30 05:05:03+00	0	\N	a7d63d447ce822eac68b1046c496286a66d6e2d0909160573b4e7964a92181be	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 09 - Insurrection 1998/11 - End Credits.mp3
1172	823	1165	1171	2012-11-30 05:05:06+00	0	\N	7fee249f4aa091622576ec3c70f1e2e36f0b92fcf70a5b5cfa934c7044f538a5	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/19 - Life Is A Dream (Film Version).mp3
1145	823	1142	1144	2012-11-30 05:05:04+00	0	\N	f77f77d20b829a76bdd495f8eee04316bc5165c72c3c539b1eea4954865e8233	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 09 - Insurrection 1998/05 - New Sight.mp3
1153	823	1142	1152	2012-11-30 05:05:04+00	0	\N	04b29e3812e739f5f05b75273cc7ac9a59c596abfd142bad9436e367afbe6b78	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 09 - Insurrection 1998/06 - The Drones Attack.mp3
1159	823	1142	1158	2012-11-30 05:05:05+00	0	\N	e702fb8d1bb231f4114bf0d0e714b1670dd2f7e8811ec8f216437b6e467fd14c	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 09 - Insurrection 1998/08 - The Same Race.mp3
1166	823	1165	1164	2012-11-30 05:05:05+00	0	\N	ac80b3d30b3cbd48c7b15fc8d9bc5001157f1cf83b1057bd5322f342f7057d90	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/09 - Open The Gates.mp3
1168	823	1165	1167	2012-11-30 05:05:05+00	0	\N	27b453858189db57639f071d7f6ca88414da931f61ff5d48c2bd3b33f82374c1	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/10 - Well Done.mp3
1161	823	1142	1160	2012-11-30 05:05:05+00	0	\N	f31620ae2fcd8f8e9ed42f9a950cd18604270d3f63d203d7ea0d4fac10727816	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 09 - Insurrection 1998/10 - The Healing Process.mp3
1170	823	1165	1169	2012-11-30 05:05:06+00	0	\N	63f3fbdc9b24415ca5165f11dfa327c0248386bb78ac9fcc4f584181f9b8cc95	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/05 - Paradise Lost  -  Spacedock.mp3
1299534	\N	\N	1299533	2012-11-30 07:25:56+00	0	\N	1443e4f5f67b0784a6e702880218a5e711096b76ea1a25dc923f2f3f14293445	/home/extra/youtube/ponies/Nightmare_Night_-_[WoodenToaster___Mic_The_Microphone]-9PCEp8z7FNg.vorbis.ogg
1197	823	1165	1196	2012-11-30 05:05:08+00	0	\N	4c969ea39fbca4ddc1105efaa7fa47d700c5d9899c695dc76fedd2fe7f57302d	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/20 - Life Is A Dream (Alternate).mp3
1179	823	1165	1178	2012-11-30 05:05:06+00	0	\N	cfcf16fe4a557d03ab70444a5310a40e659213354bcea4ffc51880758f52f728	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/08 - No Harm.mp3
1181	823	1165	1180	2012-11-30 05:05:07+00	0	\N	c71d74e76467880a67eb4d65083f721c3699fd8ed08551979b594eed8a540203	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/12 - Free Minds.mp3
1217	1205	1206	1216	2012-11-30 05:05:10+00	0	\N	b446e7d0de9fff798bbf8806d954827354ee5ccf8480c80b3b14fca9f48a35b5	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 06 - The Undiscovered Country 1991/01 Overture.mp3
1183	823	1165	1182	2012-11-30 05:05:07+00	0	\N	29dbc7076636f8e62ffb11c8940d2b17a4cd53c756b77abdf56c021c7f36fde7	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/06 - A Tall Ship.mp3
1199	823	1165	1198	2012-11-30 05:05:08+00	0	\N	db84f737e75ca6b008242d3d2ef5e5f9249ed08710157918e7b9ef98458d4114	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/03 - Games With Life.mp3
1185	823	1165	1184	2012-11-30 05:05:07+00	0	\N	81c604a2f41f99cec1ad6b8191ff6124680727f0b3dcab9708c20dcc6e485fdf	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/16 - An Angry God.mp3
1187	823	1165	1186	2012-11-30 05:05:07+00	0	\N	8b397a5c17d00ab6581f29ffae8525ffb0dfa02d91acb6dc27b8d1841c38319f	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/04 - The Big Drop.mp3
1211	1205	1206	1210	2012-11-30 05:05:09+00	0	\N	78c2fbe09f669617f7955bc6e97ae6de8aba30622fdf34f815101e066451a989	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 06 - The Undiscovered Country 1991/09 Escape From Rura Penthe.mp3
1189	823	1165	1188	2012-11-30 05:05:07+00	0	\N	4c691e56757cfe3c65a1b60849191d4e64e4484083b1bd243eb6af7129f1db8c	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/07 - Plot Course.mp3
1201	823	1165	1200	2012-11-30 05:05:08+00	0	\N	2607052cd18e62909043ab007c3f59326efe6a73bd62134a3ff06ab54a88151c	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/02 - Main Title  -  The Mountain.mp3
1191	823	1165	1190	2012-11-30 05:05:08+00	0	\N	281010e69b01a375f4c2451b9a1c4619e731cf383d0cb845c85391d873ab6b62	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/13 - Pain And Prophecy.mp3
1193	823	1165	1192	2012-11-30 05:05:08+00	0	\N	124976a6b078d957c7a546f5030ba8110beed4efc1a49e3cbc23d273f28eece4	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/15 - A Busy Man.mp3
1195	823	1165	1194	2012-11-30 05:05:08+00	0	\N	4a10b007b828444f4232cab9ee95f2ad4bfdf6b164bdb5628d4a441150a8956e	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/14 - The Barrier.mp3
1203	823	1165	1202	2012-11-30 05:05:09+00	0	\N	3a8caf5f434617b11bd454a1e6326033fbc0aa55e239218f41b666ffb0685884	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/11 - Without Help.mp3
1207	1205	1206	1204	2012-11-30 05:05:09+00	0	\N	483dbebbb43aa78263b045c8031792d3cb41254c3fda63e48d018d2971969574	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 06 - The Undiscovered Country 1991/08 Revealed.mp3
1213	1205	1206	1212	2012-11-30 05:05:10+00	0	\N	17b2688adf390342d7774dbf43e010cf70c77e9c091153ddf9bbeb92e35f2536	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 06 - The Undiscovered Country 1991/06 Death Of Gorkon.mp3
1209	1205	1206	1208	2012-11-30 05:05:09+00	0	\N	786ad2f2a7d94f57b82c6dc54594463c539b38040344a2208de696866f518e8c	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 06 - The Undiscovered Country 1991/02 An Incident.mp3
1221	1205	1206	1220	2012-11-30 05:05:11+00	0	\N	7eb2b903e1ed809fe2b410169be4cb5964c6118b5667f8891f56b86b11eb42b9	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 06 - The Undiscovered Country 1991/04 Assassination.mp3
1215	1205	1206	1214	2012-11-30 05:05:10+00	0	\N	592cca44ad4e03bbb2f278035a65187bf4eafd879811e1a2152aaaa15b6e4dc6	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 06 - The Undiscovered Country 1991/11 The Battle For Peace.mp3
1219	1205	1206	1218	2012-11-30 05:05:11+00	0	\N	8f9f99d94a296499206309d857900d4126eae9ec3b0b5928c14c1b0903f88123	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 06 - The Undiscovered Country 1991/13 Star Trek VI Suite.mp3
1223	1205	1206	1222	2012-11-30 05:05:11+00	0	\N	d6d8a6da05d30b649b6853cae35ab09da447d5f666526ba5d43c2f7847b9008c	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 06 - The Undiscovered Country 1991/05 Surrender For Peace.mp3
1225	1205	1206	1224	2012-11-30 05:05:12+00	0	\N	ae08d84107f640404558dc85a8558061a9aa2f836015788ed688b4ff55cf7ce4	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 06 - The Undiscovered Country 1991/12 Sign Off.mp3
1299536	\N	\N	1299535	2012-11-30 07:25:56+00	0	\N	604004d24345f9f8f89f72c82756125005146b826c6901ef860efbb610e6f6f2	/home/extra/youtube/ponies/Epic_Final_Bosses_of_Equestria__Mystic_Fury_-_Twilight_Sparkle-71A-Lv9vghA.vorbis.ogg
1291	1253	1254	1290	2012-11-30 05:05:22+00	0	\N	f7338fae50cffceeb26380fc47e761065e24f361cf85d7532bfef962dcb087c0	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/18 - Sarabande.mp3
1177	823	1165	1176	2012-11-30 05:05:06+00	0	\N	817387fbcd339fccfafe79a0a5b5b3e8e5f2f61193eac61739ff5942bb3f7ac4	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/17 - Let's Get Out Of Here.mp3
1265	1253	1254	1264	2012-11-30 05:05:16+00	0	\N	9e6152192317a30bd37e4e2cf849d59ccddc4ac532d804e314142da6743b4b2d	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/68 - Song of Life.mp3
1235	1233	1234	1232	2012-11-30 05:05:13+00	0	\N	1bd18a03d31b9a8b3ee014f496c82e621a390f1e3feb64b41c36667af35fe2e1	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 01 - The Motion Picture 1979/06 - Jerry Goldsmith - Vejur Flyover.mp3
1237	1233	1234	1236	2012-11-30 05:05:13+00	0	\N	bc836c3d606ffe9504e8b15b6e48e6bb042cc7615e9cfbfae253a5386b0dac5e	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 01 - The Motion Picture 1979/02 - Jerry Goldsmith - Leaving Drydock.mp3
1239	1233	1234	1238	2012-11-30 05:05:13+00	0	\N	7ed0a39c2c8c787ba69212e58012a54d52a0bb9c314c2697239bdf6753167503	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 01 - The Motion Picture 1979/03 - Jerry Goldsmith - The Cloud.mp3
1241	1233	1234	1240	2012-11-30 05:05:13+00	0	\N	051b9bc7c74d522ab8df270d1075ce0911592bca4e5a7445da9622df60a17723	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 01 - The Motion Picture 1979/01 - Jerry Goldsmith - Main Title - Klingon Battle.mp3
1255	1253	1254	1252	2012-11-30 05:05:15+00	0	\N	6616bdadea4608d5866bdb32b444e46448db8fc5d11d4ef73bd7945f56a2fe27	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/44 - Clockwork Contrivance.mp3
1243	1233	1234	1242	2012-11-30 05:05:14+00	0	\N	5b9eb13b1cdcd317b8e38c39289f9f3daa0e0a25f2a88768e41165c5aa53b4cc	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 01 - The Motion Picture 1979/08 - Jerry Goldsmith - Spock Walk.mp3
1299538	\N	\N	1299537	2012-11-30 07:25:56+00	0	\N	acffea7a0c71e5ecac8eced3e76710423b862a78d948374882a746aa156e45df	/home/extra/youtube/ponies/Dash's_Determination-mC7Bl8BkKTw.vorbis.ogg
1245	1233	1234	1244	2012-11-30 05:05:14+00	0	\N	1bd60f2c5b9ea7f26cb8971186d91f3e6688a732d5fc81ff998518253ebee940	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 01 - The Motion Picture 1979/07 - Jerry Goldsmith - The Meld.mp3
1273	1253	1254	1272	2012-11-30 05:05:18+00	0	\N	63145a7730390aba3ec144f826542d76dd812e0a246c5407192431ee7b9c428c	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/01 - Homestuck Anthem.mp3
1247	1233	1234	1246	2012-11-30 05:05:14+00	0	\N	8512486d7f5451da035b6c2ee42ac01fcd50b64d172ee26422a18095f7a7f171	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 01 - The Motion Picture 1979/04 - Jerry Goldsmith - The Enterprise.mp3
1249	1233	1234	1248	2012-11-30 05:05:14+00	0	\N	7a5a1438ab01e2c49ef846f1a3b7b2b85d5d695f63c4479af309f13df4859754	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 01 - The Motion Picture 1979/05 - Jerry Goldsmith - Ilia's Theme.mp3
1251	1233	1234	1250	2012-11-30 05:05:14+00	0	\N	6566490238acec143c3db7381a458ba15f6402b793f39b7d920473137c1defd9	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 01 - The Motion Picture 1979/09 - Jerry Goldsmith - End Title.mp3
1231	1205	1206	1230	2012-11-30 05:05:12+00	0	\N	bc4fb0d62039fe52627995725e295e452e354c20d3ed0fd84f4f9aec1f9862c7	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 06 - The Undiscovered Country 1991/03 Clear All Moorings.mp3
1259	1253	1254	1258	2012-11-30 05:05:15+00	0	\N	24a1c9a5adddf4ef4b6b154bb7bd20fd0b912135e56bf7cd2e41ed7f1d8821fa	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/31 - Dupliblaze COMAGMA.mp3
1283	1253	1254	1282	2012-11-30 05:05:20+00	0	\N	0d0be468d5ffa1a76f5d1d62dccf74d55307a5be45be51b5241484c4943f41e2	/home/extra/music/Homestuck/Homestuck Volume 5/16 Crystalanthemums.mp3
1263	1253	1254	1262	2012-11-30 05:05:16+00	0	\N	39079c9328b2e7803c55e461af9b28af3d87e90f977aa8b1c77aa0ec25b3f2af	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/26 - Versus.mp3
1269	1253	1254	1268	2012-11-30 05:05:17+00	0	\N	d7e633eb45b78d137af4a8663d2adddc961246d741d9cb05b27e1bbb8eb81b96	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/71 - Homestuck.mp3
1275	1253	1254	1274	2012-11-30 05:05:18+00	0	\N	570f4a1b5b468cfde932124dc35d8da99a4f2f084d7948a76ef0618f580d4d04	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/15 - Welcome to the New Extreme.mp3
1271	1253	1254	1270	2012-11-30 05:05:18+00	0	\N	3ddd26f3482c827d35254277dce1723594bcecd7990a1314f6a7182316173b44	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/10 - An Unbreakable Union.mp3
1042447	1253	1920	1938	2012-11-30 05:57:31+00	0	\N	5c0ddcb1480efacec728fcfd20655184a9c2fa162b0aa18d45eccc177eacbd79	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 01 Arisen Anew.mp3
1279	1253	1254	1278	2012-11-30 05:05:19+00	0	\N	dccc328cc75ae915936e001d729de54b9ac3e165a2b0140b8ef4eb40d0ddd707	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/55 - Softly.mp3
1287	1253	1254	1286	2012-11-30 05:05:21+00	0	\N	45b512b158b5fd1d48d589c62e5918e9f7bb82b597fe39ff50afcd6a9390cd82	/home/extra/music/Homestuck/Homestuck Volume 5/41 Medical Emergency.mp3
1299540	\N	\N	1299539	2012-11-30 07:25:57+00	0	\N	4c3307642ebef1630c9e8851d661dc5114567af0c779b0716bef60b978b7cf51	/home/extra/youtube/ponies/PMV_-_Pony_Polka_Face-video_VI-P_wP2Oj2Z5I.vorbis.ogg
1285	1253	1254	1284	2012-11-30 05:05:21+00	0	\N	26a5af8f3a7e98fde643da0a8c4a84a744e073fccf7c89754e88cbd7b868ffe2	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/69 - Cathedral of the End.mp3
1227	1205	1206	1226	2012-11-30 05:05:12+00	0	\N	e7d9cf9a28d6727a440b5afa9da9c1a397b1b8f101cc8f6bd0fbd28f9267cc5a	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 06 - The Undiscovered Country 1991/07 Rura Penthe.mp3
1281	1253	1254	1280	2012-11-30 05:05:20+00	0	\N	a3f5416fae5d5f4167757cdfe106c4fa5924c42f14ff18a6c4d4a2f4e8ca896e	/home/extra/music/Homestuck/Homestuck Volume 5/56 Snow Pollen.mp3
1277	1253	1254	1276	2012-11-30 05:05:19+00	0	\N	1afcabc58fd85b820f5e4120c175b30b923ba311400281c3a7b83dbcedcd749e	/home/extra/music/Homestuck/Homestuck Volume 5/49 Valhalla.mp3
1229	1205	1206	1228	2012-11-30 05:05:12+00	0	\N	faddbe6f38a6ea0765f5e7ad95a754c237b80be87e61a2eacd70131478b17d54	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 06 - The Undiscovered Country 1991/10 Dining On Ashes.mp3
1299542	\N	\N	1299541	2012-11-30 07:25:57+00	0	\N	f68aa4f5a75fedc7f0a151a769025a6af5da9d8c81f6872cf727502cd9202f39	/home/extra/youtube/ponies/APPLEBLOOM-JH8eRff9DCs.vorbis.ogg
1322	1253	1254	1262	2012-11-30 05:05:28+00	0	\N	b5071a7b98ad4ea73c478156e0c4a655f5105171a47a0b8f15116679fbe0afbd	/home/extra/music/Homestuck/Homestuck Volume 5/25 Versus.mp3
1315	1253	1254	1314	2012-11-30 05:05:27+00	0	\N	163c53bea398e5e27bb3301568c037f50520d44205d086e95ccc524629bc6740	/home/extra/music/Homestuck/Homestuck Volume 5/35 Ectobiology.mp3
1333	1253	1254	1332	2012-11-30 05:05:31+00	0	\N	3688e13dcc60fbf35de519b528f2085fd2d2aa88fa67023fc0d903c1eb3fb85b	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/19 - Clockwork Sorrow.mp3
1299	1253	1254	1260	2012-11-30 05:05:24+00	0	\N	af337efa9ad18d022b85315bec1523c224916834253acf2bf690a9fc3b71f086	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/57 - Space Prankster.mp3
1318	1253	1254	1317	2012-11-30 05:05:27+00	0	\N	0550451a362dd3ea256b2baf3258f929c8155f5cc126f4afe980ef0c2a851e4c	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/23 - Chorale for War.mp3
1316	1253	1254	1258	2012-11-30 05:05:27+00	0	\N	a17e035f8090a7419ec88d927539b6ddc9e36b80433ec8c45f786fd8c7daa481	/home/extra/music/Homestuck/Homestuck Volume 5/30 Dupliblaze COMAGMA.mp3
1303	1253	1254	1302	2012-11-30 05:05:24+00	0	\N	e2f67759354775c459d09fcae4450b03278ce631cef711052c4e58d00dd8968a	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/64 - Enlightenment.mp3
1319	1253	1254	1272	2012-11-30 05:05:28+00	0	\N	29142d4e93b218696db918c42a1f29b5e0743f13acfd188248541447922fd0ad	/home/extra/music/Homestuck/Homestuck Volume 5/01 Homestuck Anthem.mp3
1327	1253	1254	1326	2012-11-30 05:05:30+00	0	\N	ea6df2fcb83f5e707c14e6178b7b7b4194ddfd3a0d443ce359ed8973698e32ae	/home/extra/music/Homestuck/Homestuck Volume 5/57 Candles and Clockwork.mp3
1307	1253	1254	1306	2012-11-30 05:05:25+00	0	\N	25f61711b4db241a78a4127f1d6c24ec3ebf9e039d772545b6c603a393b4cc02	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/11 - Skaian Ride.mp3
1309	1253	1254	1308	2012-11-30 05:05:26+00	0	\N	befd2500b1ad4556ea9026c8a4d9a39a75137d06cec5507acb678ea92b6b5353	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/56 - Greenhouse.mp3
1311	1253	1254	1310	2012-11-30 05:05:26+00	0	\N	3771d8ca9441e0d73a3c05aab14c4b7328b4011d74dea3200bbc78405c7bfa02	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/37 - Upholding the Law.mp3
1329	1253	1254	1328	2012-11-30 05:05:30+00	0	\N	9e576ac8222de3eaaaa83e3745af2507f72e6efc19d02c7406b4c7b30f5e5d55	/home/extra/music/Homestuck/Homestuck Volume 5/62 Biophosphoradelecrystalluminescence.mp3
1313	1253	1254	1312	2012-11-30 05:05:26+00	0	\N	1fe0b4e1e29ac2f7603e8828659f29a83cca231ed02aa35556b74b549a218839	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/32 - Moonshatter.mp3
1321	1253	1254	1320	2012-11-30 05:05:28+00	0	\N	9a14a6d6b42bd35e0731d000c54511c0c9b274f7effc05c2a3e0ee24b7c28d4c	/home/extra/music/Homestuck/Homestuck Volume 5/13 Octoroon Rangoon.mp3
1334	1253	1254	1270	2012-11-30 05:05:32+00	0	\N	784964da3a8a325a5a89079bd45985381882e5d236293502a8f705f7ed6c9a67	/home/extra/music/Homestuck/Homestuck Volume 5/10 An Unbreakable Union.mp3
1340	1253	1254	1323	2012-11-30 05:05:33+00	0	\N	68deeec80ffe170848f7ed329f422343fac22e371676da794a44aa2ef7447ef5	/home/extra/music/Homestuck/Homestuck Volume 5/34 Ruins (With Strings).mp3
1324	1253	1254	1323	2012-11-30 05:05:29+00	0	\N	ee3b77273c9294b4c5ef3ade0a366f6c5d4df9056a25f11f701e8589f47b8838	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/35 - Ruins (With Strings).mp3
1342	1253	1254	1341	2012-11-30 05:05:34+00	0	\N	e384e6c021d9b2d44e2526d7536e8e298e4f5a83a5b12d228e8daf34a62422e6	/home/extra/music/Homestuck/Homestuck Volume 5/44 Vertical Motion.mp3
1325	1253	1254	1292	2012-11-30 05:05:29+00	0	\N	2813c8dde7981c365a2ff8e7aa4cd09a29e7d48d4164cfbd0570d44868fcefa0	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/06 - Jade's Lullaby.mp3
1336	1253	1254	1335	2012-11-30 05:05:32+00	0	\N	bce9cae1e1ead1025873ef036c810bb5abb8bc8ded5091822821d33da254c0b0	/home/extra/music/Homestuck/Homestuck Volume 5/64 Descend.mp3
1331	1253	1254	1330	2012-11-30 05:05:31+00	0	\N	2bb588b1a859fb558c2cae1024236ec69c1f2b829ed57680112953a6368e61f3	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/67 - Switchback.mp3
1337	1253	1254	1300	2012-11-30 05:05:33+00	0	\N	7a60a5977acdef6fd6ca7a29b7b9c2e306fb4a61e28b471bac5733ced5075f65	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/20 - Phantasmagoric Waltz.mp3
1344	1253	1254	1343	2012-11-30 05:05:34+00	0	\N	a7bdb71c245626502e7e2ddbd251fd27476e9171468026a128d8d27402085235	/home/extra/music/Homestuck/Homestuck Volume 5/28 Skaian Flight.mp3
1339	1253	1254	1338	2012-11-30 05:05:33+00	0	\N	4eb53efa160f3be18b72a5dd5400de698aa1350ff86dc9f30f6bc1be473f56be	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/09 - Hardchorale.mp3
1299544	\N	\N	1299543	2012-11-30 07:25:57+00	0	\N	13578e7a0ae01ec0baccbdc33f4f7e1aae002f9d6f0d7945a1fee908cab02f8d	/home/extra/youtube/ponies/Eurobeat_Brony_-_Discord_The_Living_Tombstone_Remix_Music_Video-9QZMjFC_RgY.aac
1305	1253	1254	1304	2012-11-30 05:05:25+00	0	\N	0950cd2a406f3fe0e4898d29d9022bad2a26aff7c8e43ab1c32046ea42de18d6	/home/extra/music/Homestuck/Homestuck Volume 5/02 Skaian Skirmish.mp3
1346	1253	1254	1345	2012-11-30 05:05:34+00	0	\N	b23b90fb896fd5ca03f9e44f16fdcc5c8868999a2c57275436d9743c9b56b195	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/53 - Amphibious Subterrain.mp3
1301	1253	1254	1300	2012-11-30 05:05:24+00	0	\N	b9b9c74319c65ab22d04bb44670245263807b5d579ed98f2dceccba771c778f9	/home/extra/music/Homestuck/Homestuck Volume 5/20 Phantasmagoric Waltz.mp3
1298	1253	1254	1297	2012-11-30 05:05:23+00	0	\N	3f6ed15d3dd72e78f738b854071360eafeea1ac4187abd4355b0698f0c592a11	/home/extra/music/Homestuck/Homestuck Volume 5/32 Sunsetter.mp3
1299546	\N	\N	1299545	2012-11-30 07:25:57+00	0	\N	ee6b7d9d21100c8c97b33363ec2df043331cff440f9a20385a106223b9e43026	/home/extra/youtube/ponies/The_Moon_Rises-kPjVCIX5Fvs.vorbis.ogg
1299548	\N	\N	1299547	2012-11-30 07:25:57+00	0	\N	8feb8d31b253c58a14d9d2b85a33c2d4db9ba0beaacb43751174b6aeeb057558	/home/extra/youtube/ponies/Green_And_Purple_[PMV]-9w6Wa0W2y_o.vorbis.ogg
1348	1253	1254	1347	2012-11-30 05:05:35+00	0	\N	9578dbdb59e2223a7b1cfa7d95211bb30280430cfbdd20d6d1fc4ea7a02e1daa	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/48 - Pyrocumulus (Kickstart).mp3
1350	1253	1254	1349	2012-11-30 05:05:35+00	0	\N	e70a611248772b794adabf67a0cff0930b5717a99cec9a8f4d53dc7ad0d1c26f	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/38 - Underworld.mp3
1370	1253	1254	1369	2012-11-30 05:05:39+00	0	\N	38dee8b62a33db709cbe5a7a33ac4d716ab2b2a4c46a8dcbf52d6b37367de39f	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/45 - Get Up.mp3
1299550	\N	\N	1299549	2012-11-30 07:25:58+00	0	\N	958e1092d56408abd09f7371edc6a490fec540a37f60b38c0ce42f1d4af04bc3	/home/extra/youtube/ponies/Children_of_the_Night_(Animatic)-6-3wp2VVhKQ.vorbis.ogg
1389	1253	1254	1268	2012-11-30 05:05:43+00	0	\N	c413601b40157c98f5693c002e5b340433b78ad42959c77de8a98c5f0cd9ac78	/home/extra/music/Homestuck/Homestuck Volume 5/65 Homestuck.mp3
1356	1253	1254	1355	2012-11-30 05:05:36+00	0	\N	2cd3f49158b86c42a2fef4db37f0a64d1a2740a44cb208d81b0a02e2f821dcd4	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/43 - Shatterface.mp3
1372	1253	1254	1371	2012-11-30 05:05:39+00	0	\N	0efac7aeaaccf3775a4cc8cb18b656f497d9423f98d8660630046cee0d0f517e	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/39 - Crystamanthequins.mp3
1357	1253	1254	1304	2012-11-30 05:05:36+00	0	\N	c7437a3eb83d158b40771020f7e07b6d2c23c831b759e9026ebb06d8d7321bd5	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/02 - Skaian Skirmish.mp3
1359	1253	1254	1358	2012-11-30 05:05:36+00	0	\N	3b92b612446250f49b7e1d0e4df8557896d9aae0092f05be2fa03e6b5167e385	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/28 - Bed of Rose's - Dreams of Derse.mp3
1374	1253	1254	1373	2012-11-30 05:05:39+00	0	\N	b5853d05d479f274cca267a21da3d7dedb5b6133a037e424357211b29bf5fb59	/home/extra/music/Homestuck/Homestuck Volume 5/29 How Do I Live (Bunny Back in the Box Version).mp3
1387	1253	1254	1386	2012-11-30 05:05:42+00	0	\N	276be0ff647e04d2dd43cf4de79b826d0823bcc6b5fe14e705a0b6c34a342beb	/home/extra/music/Homestuck/Homestuck Volume 5/58 Can Town.mp3
1376	1253	1254	1375	2012-11-30 05:05:40+00	0	\N	4a344dae4dd875e9c4dff6749963a3f89aa4a2c149b8ef43530211dfe38d62c8	/home/extra/music/Homestuck/Homestuck Volume 5/22 Lotus Land Story.mp3
1363	1253	1254	1256	2012-11-30 05:05:37+00	0	\N	15527f9365f40fdc8bf325596743b5b6f70c26ab0ef458714e5c836f84190e12	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/25 - Unsheath'd.mp3
1391	1253	1254	1371	2012-11-30 05:05:44+00	0	\N	5dcc6109120f140a1041a2036f3ad85a9f1b3eaa65366d997e483407ec516176	/home/extra/music/Homestuck/Homestuck Volume 5/38 Crystamanthequins.mp3
1382	1253	1254	1338	2012-11-30 05:05:41+00	0	\N	76b249a05b5af001e50bc57121fbebe9e1c27fb4f618b3ce35b68804dcef2c33	/home/extra/music/Homestuck/Homestuck Volume 5/09 Hardchorale.mp3
1388	1253	1254	1310	2012-11-30 05:05:43+00	0	\N	bf42d081df89e907102a712da4c39ffdd831c5acaf08d517ba9797a04dfd8ee9	/home/extra/music/Homestuck/Homestuck Volume 5/36 Upholding the Law.mp3
1366	1253	1254	1365	2012-11-30 05:05:38+00	0	\N	bf5f146999f607176b878cd76b048223335a9541f443111d781d58f37b5b6fde	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/07 - Aggrievance.mp3
1368	1253	1254	1367	2012-11-30 05:05:38+00	0	\N	aaaed6457afae9471f95c514758dc6234a138e42593b4cf4de4efac31bcbb21b	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/40 - Endless Climbing.mp3
1384	1253	1254	1383	2012-11-30 05:05:42+00	0	\N	33d85b4cd2b04e6088fe5e3efd0e3a77d33b90817996462c7bd55ebf59d4a051	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/51 - Darkened.mp3
1378	1253	1254	1377	2012-11-30 05:05:40+00	0	\N	54b9adaa19b0b780b29b7bc9b0b02b8ea43587d0d57be0ca838cf7bca2c27bf8	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/08 - Happy Cat Song!.mp3
1380	1253	1254	1379	2012-11-30 05:05:40+00	0	\N	5281c1306f3f8a35b9f7ab779c9a576ebca4e6666ae6ff11076d2247cdc9ddb7	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/49 - Skaian Skuffle.mp3
1381	1253	1254	1266	2012-11-30 05:05:40+00	0	\N	596bdf06ef42acfe8f36f1a2433026d66f6edf5bfb38632c48d56c9e15a6a9b0	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/14 - Pumpkin Cravings.mp3
1385	1253	1254	1335	2012-11-30 05:05:42+00	0	\N	bd4aabc5ed62fee7997f437d3eead39c87b3527ee6a0bec85aa267ac3ad74f45	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/70 - Descend.mp3
1393	1253	1254	1392	2012-11-30 05:05:44+00	0	\N	96a1ac6de43ae2dc553bf3090c7104ed39a88e5a2d91ef0aeb113197a296d358	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/47 - The Beginning of Something Really Excellent.mp3
1390	1253	1254	1264	2012-11-30 05:05:44+00	0	\N	741ded4d9f7e6f137a3e436f85e4a365c1fff59d1df01f5f8c69e15bc5cd96dd	/home/extra/music/Homestuck/Homestuck Volume 5/63 Song of Life.mp3
1398	1253	1254	1392	2012-11-30 05:05:46+00	0	\N	6f6989ad98fbd34a66e171dc90a42b07920caad1ed5d8e4051bb34a988b5cc33	/home/extra/music/Homestuck/Homestuck Volume 5/45 The Beginning of Something Really Excellent.mp3
1299552	\N	\N	1299551	2012-11-30 07:25:58+00	0	\N	f44c95a09ace07f6438fb9bd6b754b9ca4b720b4b5554c06798cafb9e3127afa	/home/extra/youtube/ponies/Magic_is_Free_-_MC_Fluttershy_[Kimi]-fggzApOmGgU.vorbis.ogg
1042448	1253	1920	1934	2012-11-30 05:57:31+00	0	\N	1cdffe1898234efb2b9f39f780adfe3b694aee6a80d0f7f90274718ac3397911	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 06 Dreamers and The Dead.mp3
1395	1253	1254	1394	2012-11-30 05:05:45+00	0	\N	38b7b133aa92298aaa79bd989868651b139193f3cdc6baf4fe0238ac0b9d7a17	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/60 - Endless Heart.mp3
1397	1253	1254	1396	2012-11-30 05:05:45+00	0	\N	3e26f0163b7c03b089ff7673f8f2db43b551f788deefc25179474feca57dc4d9	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/21 - Sunslammer.mp3
1364	1253	1254	1278	2012-11-30 05:05:38+00	0	\N	a6fe9979c029e00c0a9ec6fa2b5a5248c235068639fbd52f4e297c4d03117d6a	/home/extra/music/Homestuck/Homestuck Volume 5/52 Softly.mp3
1299554	\N	\N	1299553	2012-11-30 07:25:58+00	0	\N	aa15d4685b3efa380b40cbf09a03430a9aae217801bca75c8f44e8c65bde8166	/home/extra/youtube/ponies/ieavan_s_Polka_for_Headbucket_in_E_Minor_aka_YOUR_FACE-mn0Q2XlXRs0.vorbis.ogg
1299556	\N	\N	1299555	2012-11-30 07:25:58+00	0	\N	ceab0fd069af2a6c33599bb41d154f9ded656c939ad1e880a8b3b57edb8956e0	/home/extra/youtube/ponies/Super_Ponybeat_-_Luna_(DREAM_MODE)-bn7uMwXYU9U.aac
1434	1253	1254	1433	2012-11-30 05:05:57+00	0	\N	5ed6810da2ae10c0dff3bd7771c707909b11e212a6291216f85864abccef6da2	/home/extra/music/Homestuck/Homestuck Volume 5/05 Heirfare.mp3
1418	1253	1254	1396	2012-11-30 05:05:52+00	0	\N	6fc56232391741ad3bcb8d5a26e5cfa7ceabb310034dcf8f3b407b503177d93a	/home/extra/music/Homestuck/Homestuck Volume 5/21 Sunslammer.mp3
1403	1253	1254	1402	2012-11-30 05:05:48+00	0	\N	595861681567b58f7049e4518543c2975a6885a6d0b801f246c9b9a030a2753e	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/41 - Land of the Salamanders.mp3
1421	1253	1254	1420	2012-11-30 05:05:53+00	0	\N	1b10ef9f7cb578b3cbe2a506856489ab3530fa07f191e3f29a60c17c322c3fec	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/17 Skaia (Incipisphere Mix).mp3
1404	1253	1254	1320	2012-11-30 05:05:48+00	0	\N	d970f08f8784a96229792cef1edb109aeb1af920e39d9c387f16c2c7a74e9547	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/13 - Octoroon Rangoon.mp3
1426	1253	1254	1312	2012-11-30 05:05:55+00	0	\N	9fa9b0e878153f3ed7028cae924e8840224d52ea9b5d658bb0e500996c9056d1	/home/extra/music/Homestuck/Homestuck Volume 5/31 Moonshatter.mp3
1405	1253	1254	1343	2012-11-30 05:05:48+00	0	\N	308ef65628ee373abd0c7e256f28f9d4a444f8f1f171bdee4669552c077deb20	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/29 - Skaian Flight.mp3
1414	1253	1254	1274	2012-11-30 05:05:51+00	0	\N	7ed5b51d6caaa757a2206dc71f9d5340df1d5c1d5abbf61c207a1762134749cf	/home/extra/music/Homestuck/Homestuck Volume 5/15 Welcome to the New Extreme.mp3
1416	1253	1254	1290	2012-11-30 05:05:51+00	0	\N	524611dadad4818d04fa3ba250f270233ed158f89667d75b86a2f538a1e23d1c	/home/extra/music/Homestuck/Homestuck Volume 5/18 Sarabande.mp3
1431	1253	1254	1345	2012-11-30 05:05:56+00	0	\N	099c0bbd2c03e8ac18ea052caad10f2de4c4bc49218546549c5e9b5d06ba12d8	/home/extra/music/Homestuck/Homestuck Volume 5/50 Amphibious Subterrain.mp3
1408	1253	1254	1288	2012-11-30 05:05:49+00	0	\N	b19f8c244c1b86f6b7e8b7b2729a43906fc73c808dae87015fed7eef4fd88d5b	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/65 - Doctor Remix.mp3
1409	1253	1254	1294	2012-11-30 05:05:49+00	0	\N	00cb92231b9200f29336291ec2e5602dd367561a7913d98f4d4baee770d2176a	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/54 - Light.mp3
1411	1253	1254	1410	2012-11-30 05:05:50+00	0	\N	45d70c2b91dfe9ca23a78de00f606f7dc1be81eaccd98669cce238f58a3b5454	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/03 - Savior of the Waking World.mp3
1417	1253	1254	1297	2012-11-30 05:05:52+00	0	\N	ac13934278b5d2aae8d8b2b88d4fb066d51d3edfd415bd0efea1a83f87f832f7	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/33 - Sunsetter.mp3
1428	1253	1254	1427	2012-11-30 05:05:55+00	0	\N	bf6dd125e567540f9ccad1c393354e76f26b8e146201657385d82177f16a8703	/home/extra/music/Homestuck/Homestuck Volume 5/04 Clockwork Melody.mp3
1413	1253	1254	1351	2012-11-30 05:05:50+00	0	\N	af28939ffb47ae087e9cb4e0c0d1dbd9f179db9246081a282fa7f0af26e3b0dd	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/63 - Plague Doctor.mp3
1422	1253	1254	1282	2012-11-30 05:05:54+00	0	\N	0c67729f32b6ffe25674863c504b6ad3d4cf324d3e3cabc2e8f4542ca2ab18a4	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/16 - Crystalanthemums.mp3
1042449	1253	1920	1976	2012-11-30 05:57:31+00	0	\N	66065faf09357afa9340f17790f44372f3d92d35e187172962c712a6c5bb593c	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 29 You Won A Combat.mp3
1299558	\N	\N	1299557	2012-11-30 07:25:58+00	0	\N	a80aa6ff16c73783e0b78eb955132ca1086f75807338e22ac17164cbfe67bf42	/home/extra/youtube/ponies/Want_It,_Need_It_(Hold_Me)-E20jsywkLaY.vorbis.ogg
1299560	\N	\N	1299559	2012-11-30 07:25:59+00	0	\N	fdba9c46d358fb63e96d148850e9b01727025a8b908949534c6e96ea7b834f7e	/home/extra/youtube/ponies/Got_My_Party_Cannon_(Scootaloo_Chicken's_Theme)_[PMV]-9NN6hQeLfyA.vorbis.ogg
1424	1253	1254	1423	2012-11-30 05:05:54+00	0	\N	7be1bc5900c46aa29016193224d547c6691dbe19ef64319fa012c3e8b8f276fa	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/58 - Ecstasy.mp3
1299562	\N	\N	1299561	2012-11-30 07:25:59+00	0	\N	bf2e9d0bb8c6f4f8eba77e9b05ba43fda394b02b813d36e175b5a3c18b384768	/home/extra/youtube/ponies/UnderpΩny_-_A_Different_Kind_of_Spark-Ga32VpsRuVE.aac
1430	1253	1254	1429	2012-11-30 05:05:55+00	0	\N	21c10bda0aefb399c3719a8ece89d169ff9cc39f1a1db1fc76d96089b9add27e	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/24 - Electromechanism.mp3
1432	1253	1254	1276	2012-11-30 05:05:56+00	0	\N	a1e08e25ec572dde6cd27258c42230f35c9bcbf696a4efa7d9ee1f505eba1976	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/52 - Valhalla.mp3
1436	1253	1254	1435	2012-11-30 05:05:57+00	0	\N	b8b2080d383d93a8739bf3074d867792fe7e4f7052eb1940b1add5facf753f02	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/27 - Planet Healer.mp3
1437	1253	1254	1353	2012-11-30 05:05:57+00	0	\N	89e171b1c7a1ebfb5075fe51371bed0f2d00f1f2b05c608704c1d7abd4a9a695	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/12 - White.mp3
1438	1253	1254	1314	2012-11-30 05:05:57+00	0	\N	80e4729c02430a275f92afc0ae5b747a14ae10716cdbd23bdab86719a19400bb	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/36 - Ectobiology.mp3
1412	1253	1254	1402	2012-11-30 05:05:50+00	0	\N	57e7c7e834efe67f7ec6e0ed047e9e6472a1099abbaa112ea204c53c8433943b	/home/extra/music/Homestuck/Homestuck Volume 5/40 Land of the Salamanders.mp3
1407	1253	1254	1332	2012-11-30 05:05:49+00	0	\N	4c80948689af52eb63ee8a3c34dfe78bc9d049fa6196ec1be6e326d56e083a8f	/home/extra/music/Homestuck/Homestuck Volume 5/19 Clockwork Sorrow.mp3
1406	1253	1254	1349	2012-11-30 05:05:48+00	0	\N	aa06b8f8590dae303b25c9d96e784811a7cf224e7407c5b677a2421e1b37c50f	/home/extra/music/Homestuck/Homestuck Volume 5/37 Underworld.mp3
1425	1253	1254	1377	2012-11-30 05:05:54+00	0	\N	ee9aa984e29cbf1107b4e163de8281e6a9306880948f75e1e36cd0a69482ecd5	/home/extra/music/Homestuck/Homestuck Volume 5/08 Happy Cat Song!.mp3
1401	1253	1254	1308	2012-11-30 05:05:47+00	0	\N	b85bedda6eff2a48fbc2e9c84f427e3fadd8aaac27dc824cd7334eeac7c0013b	/home/extra/music/Homestuck/Homestuck Volume 5/53 Greenhouse.mp3
1440	1253	1254	1341	2012-11-30 05:05:58+00	0	\N	d94d64238aa852b9afb717cd4645fbd42d8a98ed656bbef215046594adae93e0	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/46 - Vertical Motion.mp3
1477	1253	1460	1476	2012-11-30 05:06:07+00	0	\N	2d27cbc7d25777909f70ea0971cbbd34eee77383a96a9f5aa68ccd9732fdb250	/home/extra/user/torrents/Homestuck Discography/The Wanderers/16 - Tomahawk Head.mp3
1441	1253	1254	1286	2012-11-30 05:05:58+00	0	\N	4052cdeace8cbfb5cfe89af93ab756fc372a52f7a95227c4cf1201fbeaed7e27	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/42 - Medical Emergency.mp3
1454	1253	1254	1375	2012-11-30 05:06:03+00	0	\N	73343caefba06510f8db3ae86dad97d9d63a4df78690d82affb71b8162d53ff1	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/22 - Lotus Land Story.mp3
1442	1253	1254	1360	2012-11-30 05:05:59+00	0	\N	5f69716b0b1ebc79bc7143a173909894617246f25cc9608c6734802911166a91	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/34 - Lotus.mp3
1443	1253	1254	1328	2012-11-30 05:05:59+00	0	\N	0534076833e8c5020b6dd02ffaddad2a9748b2d372239754ab3bdd378b826999	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/66 - Biophosphoradelecrystalluminescence.mp3
1299564	\N	\N	1299563	2012-11-30 07:25:59+00	0	\N	2b267613f1232d56fdcbe9ebf641c3a815c00480adc69b628037851f8b9fcb97	/home/extra/youtube/ponies/Want_It_Need_It-HsGPsqFEFXE.vorbis.ogg
1465	1253	1460	1464	2012-11-30 05:06:05+00	0	\N	089343dbf1edc8323e8543ba797c2d45131dc2a7f8380469dda6ea51d42ab492	/home/extra/user/torrents/Homestuck Discography/The Wanderers/01 - Carapacian Dominion.mp3
1299566	\N	\N	1299565	2012-11-30 07:25:59+00	0	\N	ff4aa8c65104ff1c97d3a1820587868da10aeb919f0e198a5a11f7d42d6b2d77	/home/extra/youtube/ponies/PinkiePieSwear_-_Giggle_at_the_Ghostly_Simple_Joy_Mix-ZQYqPo4NDXQ.aac
1447	1253	1254	1446	2012-11-30 05:06:00+00	0	\N	bc1cf4446484b6634aac283f46d412d18f262b82205994a25beb903d6d277dd5	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/50 - Throwdown.mp3
1456	1253	1254	1427	2012-11-30 05:06:03+00	0	\N	9a932814e3597635b0f7adc8ab268114eb326121dee9a8c33ae73e5ad3aaf497	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/04 - Clockwork Melody.mp3
1449	1253	1254	1433	2012-11-30 05:06:01+00	0	\N	86c4b664b0e1e9b05e5ee8b9044daa32b7c53560b1a1a5cc311f32e3ca3c3ecf	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/05 - Heirfare.mp3
1473	1253	1460	1472	2012-11-30 05:06:07+00	0	\N	11ee3c887ce0bf1e49fd5cdf5d0469df4cbe3c13e16817552e84c62d895424f1	/home/extra/user/torrents/Homestuck Discography/The Wanderers/02 - Aimless Morning Gold.mp3
1451	1253	1254	1280	2012-11-30 05:06:02+00	0	\N	23d528d41d13a43b57a5a08e2eceabb007aa865f24a26b002d1c45b7b43ad891	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/59 - Snow Pollen.mp3
1457	1253	1254	1373	2012-11-30 05:06:03+00	0	\N	e507b787f3ec9921babf9388c6a015e97ec7104b507582329b54726903de20fc	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/30 - How Do I Live (Bunny Back in the Box Version).mp3
1453	1253	1254	1386	2012-11-30 05:06:02+00	0	\N	ef411bfd4ccf49283ae7ec6fd52a98255017cb09cc195f52ff2c13f015afa890	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 5/62 - Can Town.mp3
1467	1253	1460	1466	2012-11-30 05:06:06+00	0	\N	729ee954aa765d9068bad6b07573a669652946df2f79e31d5cd1ef4f789ba368	/home/extra/user/torrents/Homestuck Discography/The Wanderers/08 - Requiem for an Exile.mp3
1461	1253	1460	1459	2012-11-30 05:06:04+00	0	\N	681c8cd369ac349dbeee727ed39f741ddd3ede6912e91178884d21841e202d19	/home/extra/user/torrents/Homestuck Discography/The Wanderers/03 - Endless Expanse.mp3
1463	1253	1460	1462	2012-11-30 05:06:05+00	0	\N	b411f8992c6d960b700325d6e4dee1e691b3cc89600445f623841b3940a8111f	/home/extra/user/torrents/Homestuck Discography/The Wanderers/07 - We Walk.mp3
1469	1253	1460	1468	2012-11-30 05:06:06+00	0	\N	58073ed44d47f245d76b3fc97294b0946936e68170a80f7e2676b9474f458c34	/home/extra/user/torrents/Homestuck Discography/The Wanderers/05 - Years in the Future.mp3
1471	1253	1460	1470	2012-11-30 05:06:06+00	0	\N	827e640aecabe0a63ccdf5f1fb77c29a63f42ec87a077bac4474b2ed386df3a8	/home/extra/user/torrents/Homestuck Discography/The Wanderers/12 - Ruins Rising.mp3
1475	1253	1460	1474	2012-11-30 05:06:07+00	0	\N	d706458f145349e6d6e19c6cb3bcf74f8417bd1fd1925cab3dde2e476b3b4612	/home/extra/user/torrents/Homestuck Discography/The Wanderers/10 - Riches to Ruins Movements I & II.mp3
1481	1253	1460	1480	2012-11-30 05:06:08+00	0	\N	405930521ea167e489dd9849982dc805912f9403ab36510742c183444bc2501e	/home/extra/user/torrents/Homestuck Discography/The Wanderers/14 - Nightmare.mp3
1479	1253	1460	1478	2012-11-30 05:06:08+00	0	\N	7e73f3632937c7863ceab59ab02aa8bd2517d0f4a074012e7338e6b394bbf2aa	/home/extra/user/torrents/Homestuck Discography/The Wanderers/09 - Raggy Looking Dance.mp3
1483	1253	1460	1482	2012-11-30 05:06:08+00	0	\N	250fbfcadee791e04c180ac171488c4d9231a1c47971c6a00c8b2fc7e26696dc	/home/extra/user/torrents/Homestuck Discography/The Wanderers/06 - Mayor Maynot.mp3
1485	1253	1460	1484	2012-11-30 05:06:09+00	0	\N	baed0e7c188131c95fd181ccfaa6b02e6521af7f9ffce388ac0bc16485adeb28	/home/extra/user/torrents/Homestuck Discography/The Wanderers/13 - What a Daring Dream.mp3
1487	1253	1460	1486	2012-11-30 05:06:09+00	0	\N	4127467f6e11ca84743169c1d9a08d7b3e3459e71d67f18f89d401e6b9e18d57	/home/extra/user/torrents/Homestuck Discography/The Wanderers/04 - Gilded Sands.mp3
1042533	1042531	1042532	1042530	2012-11-30 05:58:24+00	0	\N	e85fee3c6dfcbd56e55893054923d1bae3663e7899d699f6271727de78a72795	/home/extra/music/restitch/15d9.flac
1537	1253	1526	1536	2012-11-30 05:06:16+00	0	\N	779f43643755bb99e97f8f8b7857c7c26e08eb70efcad6cf56756f0a680e4ad8	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/38 - Endless Climb.mp3
1489	1253	1460	1488	2012-11-30 05:06:09+00	0	\N	a0f18bed7affb1eb1c714e669858d9082c90668ad9fd352e8402f379af1bfda4	/home/extra/user/torrents/Homestuck Discography/The Wanderers/15 - Vagabounce Remix.mp3
1514	1253	1493	1513	2012-11-30 05:06:13+00	0	\N	ef870637d4d70972ffe87594ed9ce26a27a5dae062a621ff730a100b9a130ee6	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/05 - Dishonorable Highb100d.mp3
1491	1253	1460	1490	2012-11-30 05:06:10+00	0	\N	5be8e1d575c78ef335a7d6fe28dda38933e33042e6d18419bccfb3f7fa165100	/home/extra/user/torrents/Homestuck Discography/The Wanderers/11 - Litrichean Rioghail.mp3
1494	1253	1493	1492	2012-11-30 05:06:10+00	0	\N	7822ba7beaf2448ce91f53a7ad5b3d8a8e7b6933e8aad68b4ae6bd329b1206a4	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/03 - wwretched wwaltz.mp3
1529	1253	1526	1528	2012-11-30 05:06:15+00	0	\N	e7cb0316b0067a6872e28c619349870e1da65cbe36cd289b6800faa5f1425417	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/32 - Hardlyquin.mp3
1496	1253	1493	1495	2012-11-30 05:06:11+00	0	\N	5bdfdcdc41ad1f843411a4f29582cc5731fa51f7e31a598e25f4902e808f0723	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/12 - Spider8ite!!!!!!!!.mp3
1516	1253	1493	1515	2012-11-30 05:06:14+00	0	\N	45059ffce9f99139baf979e9b1c556778bce143454c45083fbc2a2d1711553ba	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/07 - Immaculate Peacekeeper.mp3
1498	1253	1493	1497	2012-11-30 05:06:11+00	0	\N	6d60bb068445ca32d71627d78abb372d8e447b8002504218dc2d7ceb28009491	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/01 - ETERNAL SUFFERING.mp3
1500	1253	1493	1499	2012-11-30 05:06:11+00	0	\N	54544291a2426fd35817bc18e8a6a7efceab148d33622df947cbdc74a536a91b	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/04 - --Empirical.mp3
1502	1253	1493	1501	2012-11-30 05:06:12+00	0	\N	48fc322599f47ef789f236dc674804a6e885c4bb2c7883d458d1944e9aafeebd	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/11 - R3DGL4R3.mp3
1518	1253	1493	1517	2012-11-30 05:06:14+00	0	\N	38f75d1a25a8e127458eadac51d56c2f555c87331f14c9d65adfd013d2a02392	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/06 - aN UNHOLY RITUAL,.mp3
1504	1253	1493	1503	2012-11-30 05:06:12+00	0	\N	60c9262bc8f59684aa8459ea71d9943961e5d8c94c4ce9556dc11cfa2534db3a	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/14 - June, Or July.mp3
1506	1253	1493	1505	2012-11-30 05:06:12+00	0	\N	8092a6044f38bd71b04c210b2704dd43cfe6ee60a2b58c50a77b7305782be25b	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/02 - twoward2 the heaven2.mp3
1508	1253	1493	1507	2012-11-30 05:06:13+00	0	\N	760ca33652946cc4f08e1da8f42333dd4c1162dc4971725be2d48a861ddf3568	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/15 - Valhalla (Scratched Disc Edit).mp3
1520	1253	1493	1519	2012-11-30 05:06:14+00	0	\N	4ea2242bcafc6c72a8c220bee485e0bc6e0c882dd3116a4e171d9b94dae407af	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/08 - 0_0.mp3
1510	1253	1493	1509	2012-11-30 05:06:13+00	0	\N	0677a18f67bc54e4697ae4386238873bd1ab8ed5b0c23d618250ca3c9906b725	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/13 - Green Sun.mp3
1512	1253	1493	1511	2012-11-30 05:06:13+00	0	\N	021a3141a70de65145996070050b4e8c0b507a22a2386b58c047dd550d779ba2	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/09 - SUBJUGGLATION.mp3
1531	1253	1526	1530	2012-11-30 05:06:16+00	0	\N	53618788b932a784d82eebb03d616c01e22df0ca3bca92910a034c090843c546	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/41 - Doctor (Original Loop).mp3
1522	1253	1493	1521	2012-11-30 05:06:14+00	0	\N	7f48c5144fea7dbc9128a6293bf6bfcbb97212e6a69bf4f7f49bbb324797a875	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/10 - pawnce!.mp3
1524	1253	1493	1523	2012-11-30 05:06:15+00	0	\N	e9f8ef8bb28946df6a9b47a1d9254712d0eccaa2eed9523f64b6e6816a91c151	/home/extra/user/torrents/Homestuck Discography/Tomb of the Ancestors/16 - Spider8ite (Thief of Lounge Mix).mp3
1545	1253	1526	1544	2012-11-30 05:06:17+00	0	\N	bea7eff11723d1612bc0c0cd34ba6af7111f023d9ac91586630a9368e8ac6e2f	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/16 - Showtime Remix.mp3
1527	1253	1526	1525	2012-11-30 05:06:15+00	0	\N	a29936e59b975379fbfca1d7dd6ab4e99800ac7ccbcfbf11102cb279af766c3b	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/34 - Ballad of Awakening.mp3
1533	1253	1526	1532	2012-11-30 05:06:16+00	0	\N	e4c4ecbf238a10d2c958b3587598eea7916213167c3d06b8385cf8faeba1e2ea	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/39 - Atomyk Ebonpyre.mp3
1539	1253	1526	1538	2012-11-30 05:06:16+00	0	\N	e5ca581612ee6d049d99b8e9a0064b1b063d11fdf6b931ef9c034133cf664139	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/03 - Showtime (Original Mix).mp3
1535	1253	1526	1534	2012-11-30 05:06:16+00	0	\N	6805f25bae0e8e875fa9151e36219b3e6c8064e30f5aecca97f502d9fa57b2e3	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/33 - Carefree Victory.mp3
1543	1253	1526	1542	2012-11-30 05:06:17+00	0	\N	99371ef5a523ef71cc94b29e628d22c84c6711b15d5344ac7725cb735342ef17	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/25 - Ohgodwhat.mp3
1541	1253	1526	1540	2012-11-30 05:06:17+00	0	\N	d6d349d1a3fb26e779e3d672747c6219976fd9cff631c0b538fe48219b2428f1	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/23 - Dissension (Original).mp3
1547	1253	1526	1546	2012-11-30 05:06:17+00	0	\N	63420c24cfd605829dc7230a0e1733c48809c53901964d412924127d03e57893	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/18 - Verdancy (Bassline).mp3
1549	1253	1526	1548	2012-11-30 05:06:17+00	0	\N	8ebdcf9f8263fb50eb808add41e887e55703350554ce6eb62f0640029c6c198a	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/08 - Nannaquin.mp3
1551	1253	1526	1550	2012-11-30 05:06:18+00	0	\N	b929e88410c3201ea07b988b70c5b7f4b8ea99b3cfe9898433443b3a4d63d807	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/29 - Chorale for Jaspers.mp3
1299568	\N	\N	1299567	2012-11-30 07:25:59+00	0	\N	38cd675d70b1d40e9663e89004c418ca800ee4df7799ab85d4e83c3eede4e3ab	/home/extra/youtube/ponies/PinkiePieSwear_-_Sunshine_and_Celery_Stalks-cP0f5rvVkAU.vorbis.ogg
1553	1253	1526	1552	2012-11-30 05:06:18+00	0	\N	a26b8787305f6671f3f00dbf3c5557cebbe1add636def6bc375ee5ae3cac11ef	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/10 - Harlequin (Rock Version).mp3
1577	1253	1526	1576	2012-11-30 05:06:21+00	0	\N	3b0a5093efe4e81a4ae04e9b5e97b89b95b1d6a21fbcc6d0c953549c505c0331	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/28 - Explore Remix.mp3
1555	1253	1526	1554	2012-11-30 05:06:18+00	0	\N	22a55760e4407a757475a064cb91673e3aba46a4cb8ecfa9c363017a04f8ea4b	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/36 - Three in the Morning (RJ's I Can Barely Sleep In This Casino Remix).mp3
1557	1253	1526	1556	2012-11-30 05:06:18+00	0	\N	8ee90a1247063104e199f4585155bf9121c02a937d7ca8920dc7b40f1b2b6353	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/15 - Gardener.mp3
1599	1253	1526	1598	2012-11-30 05:06:24+00	0	\N	1d4691819dd333af575d83d8c1d6e85443475cf3dec55ada362f60a554798bde	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/09 - Skies of Skaia.mp3
1559	1253	1526	1558	2012-11-30 05:06:19+00	0	\N	9c67ebf22ea7b3ca292b1f688f897ca6348c5247d0b38b4f003887dc34345566	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/19 - Potential Verdancy.mp3
1579	1253	1526	1578	2012-11-30 05:06:21+00	0	\N	6aaef67e646fd829b4d9d4e3ffeea0413d359fadac9ebb392fdf6062f8c3115e	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/11 - John Sleeps - Skaian Magicant.mp3
1561	1253	1526	1560	2012-11-30 05:06:19+00	0	\N	94d92619df5320ad0fc269548fb49df3c0901ff4ecffbf74c0bd10c0530cf5af	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/04 - Aggrieve (Violin Refrain).mp3
1563	1253	1526	1562	2012-11-30 05:06:19+00	0	\N	b60c2edb0cad6dabe2946dde37e89e32571e30c698d1140238d2e39c344ba5eb	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/31 - Revelawesome.mp3
1591	1253	1526	1590	2012-11-30 05:06:23+00	0	\N	ca86bf4a938e021f0eae3259bfd4ce370505db2cd1bbad13dc192cad99d901c6	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/14 - Explore.mp3
1565	1253	1526	1564	2012-11-30 05:06:19+00	0	\N	53a081b9268b1b3ef2f8051438ada770167c4141ca5ad320e2f1bb6db73904ab	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/22 - Beatdown Round 2.mp3
1581	1253	1526	1580	2012-11-30 05:06:21+00	0	\N	fe413c42556a2059c9da1a2cede0ea4c9972c90278c3e7203a0a07dde56b28c3	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/17 - Aggrieve Remix.mp3
1567	1253	1526	1566	2012-11-30 05:06:20+00	0	\N	f1bf31f81860aa30beee3a6ba168b9f8ca2ec5c38b894cc48bfc54cc3c161bc8	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/35 - Sburban Jungle.mp3
1569	1253	1526	1568	2012-11-30 05:06:20+00	0	\N	6d3bec1f8da6a5182cf3a92de4929fd3f6dfb10de334debd1ab81274a0bc3f6c	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/40 - Black.mp3
1571	1253	1526	1570	2012-11-30 05:06:20+00	0	\N	15aa662ce98d3db12337a3254f5b3d079e74f87062f2d9a81578b12562c31411	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/13 - Vagabounce.mp3
1583	1253	1526	1582	2012-11-30 05:06:22+00	0	\N	e81291f61b30c2dcd4cabd6ea483edb635133542d85a8acca5b76b377a8a5a38	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/01 - Showtime (Piano Refrain).mp3
1573	1253	1526	1572	2012-11-30 05:06:20+00	0	\N	960aa7a81aaaf938f30339688216a79618851aae914a9799a2f12c7482bb6c6f	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/26 - Ohgodwhat Remix.mp3
1575	1253	1526	1574	2012-11-30 05:06:21+00	0	\N	3cbcc10453b080a9e7542d7065fb2fe71933a94ffb7688d8fe5efe25a9b9ea24	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/21 - Harleboss.mp3
1593	1253	1526	1592	2012-11-30 05:06:23+00	0	\N	9a853cfbd8431cbe6854f91a9b941187107fac6d32e6308c8f5d43e26942f5a0	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/06 - Aggrieve.mp3
1585	1253	1526	1584	2012-11-30 05:06:22+00	0	\N	b9ee9b6f893f225ff5b7fc907ef81cd19eeca66e5b09b10d019c60c4328e7bc6	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/27 - Rediscover Fusion.mp3
1587	1253	1526	1586	2012-11-30 05:06:22+00	0	\N	e4f42cbc20e2c2ec3b70a31421537668d187c6764f1c3544c71d840397b85154	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/37 - Doctor.mp3
1607	1253	1526	1606	2012-11-30 05:06:24+00	0	\N	e02289118f5cebcf7cc13474e22a0a1ac36c80d2a2f94164b04bbe880ef28f7b	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/12 - Upward Movement (Dave Owns).mp3
1589	1253	1526	1588	2012-11-30 05:06:22+00	0	\N	209c2eecbfb7d9f9f9c1dedd1b62277496036e53245d3c315840f3e0fcc0a909	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/07 - Showtime (Imp Strife Mix).mp3
1595	1253	1526	1594	2012-11-30 05:06:23+00	0	\N	79665c6aef4421e57ad7524d2358cf7f2628c2ae1300ed49bcf5784651616019	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/20 - Beatdown (Strider Style).mp3
1601	1253	1526	1600	2012-11-30 05:06:24+00	0	\N	943128f27a8de847bce7e6b5579de4e00a258d1b8a2e06ff74af7d439625a9e7	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/24 - Dissension (Remix).mp3
1597	1253	1526	1596	2012-11-30 05:06:23+00	0	\N	bf65169da385cd284407e7c36769e81857be2f2f83ff634d90f026a4cfeb7473	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/02 - Harlequin.mp3
1605	1253	1526	1604	2012-11-30 05:06:24+00	0	\N	f5634ac76bdf31fb2fc0d6ca35c98fc89fac38cd04fe1f0f5a1e1716c80ff685	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/05 - Sburban Countdown.mp3
1603	1253	1526	1602	2012-11-30 05:06:24+00	0	\N	817a40764c41055716f9e4958046351d576be4fadb84a24abdc468cfc3296aaf	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1-4/30 - Pony Chorale.mp3
1042474	1253	2079	2101	2012-11-30 05:57:34+00	0	\N	3f9a263cfcba7294b1fb8673c6348692436ad601ca83798d9f72f10a71d561af	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 17 Nic Cage Song.mp3
1609	1253	1608	1536	2012-11-30 05:06:25+00	0	\N	1d2eb1dfb52bbd200732356c0e87414878d3846ea9648d3961e9708de762a1b3	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 4/11 - Endless Climb.mp3
1611	1253	1608	1610	2012-11-30 05:06:25+00	0	\N	39c221fa162ffe8e94f6a9a462b27c4607b289b898165a54ebdf410bcf1b6e8c	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 4/05 - Guardian V2.mp3
1612	1253	1608	1532	2012-11-30 05:06:25+00	0	\N	42068c71ed72997bcfc0c27555607b2cdcc0e64fd444c18972f008d4901b5bee	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 4/12 - Atomyk Ebonpyre.mp3
1613	1253	1608	1525	2012-11-30 05:06:26+00	0	\N	5e0073f2118c81743ab8c1ea1833aba5accad22e25715c01d7a7ae6621d4e5c4	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 4/07 - Ballad of Awakening.mp3
1662	1253	1641	1661	2012-11-30 05:06:34+00	0	\N	fb4332a6dcae1bc0ce1ec9a37a979b98693d99aa02ad2572b27f529738686f99	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/18 - Maplehoof's Adventure.mp3
1614	1253	1608	1534	2012-11-30 05:06:26+00	0	\N	f63223260fbcd6ad440a6c45bdcffbc251aecdbeb568362b29cd7b3830c54e50	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 4/04 - Carefree Victory.mp3
1633	1253	1626	1632	2012-11-30 05:06:30+00	0	\N	2342a3b944ca7c2366ad136068378bb67df977adb3ad2c5c7b5424fc50e15f88	/home/extra/user/torrents/Homestuck Discography/Strife!/03 - Dance of Thorns.mp3
1616	1253	1608	1615	2012-11-30 05:06:26+00	0	\N	53f8e6615852353c6b3bbba370fc91be371535d6392094f72907e698743ef2dd	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 4/06 - Contention.mp3
1617	1253	1608	1586	2012-11-30 05:06:26+00	0	\N	83878f90c9fe870142b9a69080407c321c97ce258df2e23d5e139ee4076de27b	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 4/10 - Doctor.mp3
1648	1253	1641	1647	2012-11-30 05:06:32+00	0	\N	16e4a9dde8e0e8ecc2cd00c181c84afdbbdddd6191131d08a87b95eeab832538	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/13 - Let's All Rock the Heist.mp3
1618	1253	1608	1562	2012-11-30 05:06:27+00	0	\N	246d66b05a1c9588e04316091e8760441ca42e97da3d7f9a167da95eb71a1610	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 4/01 - Revelawesome.mp3
1635	1253	1626	1634	2012-11-30 05:06:30+00	0	\N	6a07ae2952d033ff392400ee9d0e5b9efa0d0af238e1bae1d20d2b86a2d72ecc	/home/extra/user/torrents/Homestuck Discography/Strife!/02 - Heir Conditioning.mp3
1619	1253	1608	1568	2012-11-30 05:06:27+00	0	\N	0889b1e714d7cf66fba13ba55a87898142f83222cfcf13757c3f547822b6c3fc	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 4/13 - Black.mp3
1620	1253	1608	1566	2012-11-30 05:06:27+00	0	\N	b3d02836cf10c5e03dc35fc813eae225625b58b78fcea1d6d48561fc15992492	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 4/08 - Sburban Jungle.mp3
1622	1253	1608	1621	2012-11-30 05:06:27+00	0	\N	5a8ae280b8b14cf0e3ce3d0cd8a273a7f70baaf8e570eb64126730805c53c894	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 4/03 - Mutiny.mp3
1637	1253	1626	1636	2012-11-30 05:06:31+00	0	\N	af176f47ae1950c52d7b9238fbb5135134464d9a82eb0646f217adc46c1f3d7a	/home/extra/user/torrents/Homestuck Discography/Strife!/01 - Stormspirit.mp3
1623	1253	1608	1528	2012-11-30 05:06:28+00	0	\N	af04938f36fa033ce86c6982769014bdd7f727fcc289c333a02243b8ceb291ba	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 4/02 - Hardlyquin.mp3
1624	1253	1608	1554	2012-11-30 05:06:28+00	0	\N	81d2ec1c0d44ab136bd8162611946c63e7288e636a1a066ed9d0105ad2bec5f4	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 4/09 - Three in the Morning (RJ's I Can Barely Sleep In This Casino Remix).mp3
1656	1253	1641	1655	2012-11-30 05:06:33+00	0	\N	b991dfe1420fd14b04d06eca946c2c236cfd80c4360c03af82769d9e171e78cd	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/12 - Rumble at the Rink.mp3
1627	1253	1626	1625	2012-11-30 05:06:29+00	0	\N	aa8714be1c0ab93ec8c6a468cd9c56fdac1420614037f4da40d719cb19a915e2	/home/extra/user/torrents/Homestuck Discography/Strife!/06 - Knife's Edge.mp3
1639	1253	1626	1638	2012-11-30 05:06:31+00	0	\N	b4aea608e628df99a10dac38a5cf0681d801d9edebff764860d1b74801d82cd3	/home/extra/user/torrents/Homestuck Discography/Strife!/05 - Atomic Bonsai.mp3
1629	1253	1626	1628	2012-11-30 05:06:29+00	0	\N	2ec085876991d2499e40b783931609f6b82bdcc6a588f11ff4a3f5f30e14ab09	/home/extra/user/torrents/Homestuck Discography/Strife!/07 - Make a Wish.mp3
1631	1253	1626	1630	2012-11-30 05:06:29+00	0	\N	3f3556df3a215312654691fae97bdc71343f6a6ab036a491aba11755e91f52d2	/home/extra/user/torrents/Homestuck Discography/Strife!/04 - Time on My Side.mp3
1650	1253	1641	1649	2012-11-30 05:06:32+00	0	\N	f2deb4b21ee5e01c1bc0fd17c6f6d57b81972c0cdf8559e2c0c3ddb9ad1f7124	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/03 - Even in Death.mp3
1642	1253	1641	1640	2012-11-30 05:06:31+00	0	\N	e6893037141943d3d96d63d7b4b86b61c522ffcc68ae14f44dda5db5772f236a	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/07 - Spider8reath.mp3
1644	1253	1641	1643	2012-11-30 05:06:31+00	0	\N	c45bd3b82c5cec05093b10a71b5a30b90e0141527fe19d70264e67f5ee26bb71	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/10 - Havoc To Be Wrought.mp3
1646	1253	1641	1645	2012-11-30 05:06:32+00	0	\N	8780b7b7add0bdf215d1644c3a1da2748c3c83f57464922605131be138ac83d8	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/15 - Earthsea Borealis.mp3
1652	1253	1641	1651	2012-11-30 05:06:32+00	0	\N	63bc55a57d8e949986a78a1eee0ae2c8ef55cb2d35a17e5980b3d44986778e60	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/06 - The Carnival.mp3
1660	1253	1641	1659	2012-11-30 05:06:34+00	0	\N	d1e5092f4393a62c648ac4bb80b40e6ef1b446cf7c449f841f83854560130ff6	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/01 - Black Rose - Green Sun.mp3
1654	1253	1641	1653	2012-11-30 05:06:33+00	0	\N	4606fb8dd69e8e3540cf405c55ad41b79421d36df5af54709ecb009bb77a03d3	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/11 - Play The Wind.mp3
1658	1253	1641	1657	2012-11-30 05:06:33+00	0	\N	6de6fa0bf7d4ce680bb3d93bbd6ca5dba680dfedf0d9456d080b3bbe9678d033	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/16 - Warhammer of Zillyhoo.mp3
1261	1253	1254	1260	2012-11-30 05:05:16+00	0	\N	0102d743e9ffa4927b2e70a71547c3cadd568588f310c1f3c7f7f188664509cf	/home/extra/music/Homestuck/Homestuck Volume 5/54 Space Prankster.mp3
1664	1253	1641	1663	2012-11-30 05:06:34+00	0	\N	76bd7881a423544647754ad94f31688bb36562f29dd4509b5bab495536fc14b9	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/14 - WSW-Beatdown.mp3
1666	1253	1641	1665	2012-11-30 05:06:35+00	0	\N	eb691c554565cd1ca3f33807a253f6f088e8302366be264f3040ed7d6230c51f	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/17 - Savior of the Dreaming Dead.mp3
1267	1253	1254	1266	2012-11-30 05:05:17+00	0	\N	7bbbd72639e46ae13a0be2835bb7389642ac2c8a3012251aab5cffa17e0683ee	/home/extra/music/Homestuck/Homestuck Volume 5/14 Pumpkin Cravings.mp3
1668	1253	1641	1667	2012-11-30 05:06:35+00	0	\N	785adac4080d202172c0c80e2a2f13042003e85cfb37567c21af24eec757c1e8	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/08 - Lifdoff.mp3
1715	1253	1682	1714	2012-11-30 05:06:42+00	0	\N	76780602f83c06d963c766628926ca339f66fca06f5ec69abdd69698b5019810	/home/extra/user/torrents/Homestuck Discography/Alternia/01 - Crustacean.mp3
1670	1253	1641	1669	2012-11-30 05:06:35+00	0	\N	27c21f7f6976fe885d9625793757696d4cf1e8943a41d3243a941828e745cf15	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/04 - Terezi Owns.mp3
1693	1253	1682	1692	2012-11-30 05:06:39+00	0	\N	c5514de90998b77da82c86da717b9491a57c215b05bf818c8507fd6f56cdc941	/home/extra/user/torrents/Homestuck Discography/Alternia/13 - The Thirteenth Hour.mp3
1672	1253	1641	1671	2012-11-30 05:06:36+00	0	\N	acdcb40d71d0e4f3eb409e8930aedf0a02fc972248b3401cbc757ccc134e2179	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/20 - White Host, Green Room.mp3
1674	1253	1641	1673	2012-11-30 05:06:36+00	0	\N	69ae2becdaf4ed8ddd6a68109800e5460efc6abf809d678e0e99bbaffb60fcad	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/02 - At The Price of Oblivion.mp3
1707	1253	1682	1706	2012-11-30 05:06:41+00	0	\N	8b4f0dcecb04d0b1f790e869798e2d7a023d26ce3004c4d219358b7ef058d509	/home/extra/user/torrents/Homestuck Discography/Alternia/12 - Skaian Summoning.mp3
1676	1253	1641	1675	2012-11-30 05:06:36+00	0	\N	fbe7ecb2e85d68a255efc82a3e21d294ca49954a8ed7f89482bed68bd015c563	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/09 - Awakening.mp3
1695	1253	1682	1694	2012-11-30 05:06:39+00	0	\N	4e05704259e66e54e68e5b39156f6f6852759b7554d291a34a43510899317006	/home/extra/user/torrents/Homestuck Discography/Alternia/16 - Keepers (Bonus).mp3
1678	1253	1641	1677	2012-11-30 05:06:37+00	0	\N	673de397ea56042a238fa15b6ad4200842194e26fdf30a1009d226362d01e436	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/05 - Trial and Execution.mp3
1680	1253	1641	1679	2012-11-30 05:06:37+00	0	\N	1d883451e7143315862e8a07aa1e799df18c1df16e9c493070794f1180ea519b	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 7 - At the Price of Oblivion/19 - Sburban Reversal.mp3
1683	1253	1682	1681	2012-11-30 05:06:37+00	0	\N	2b0870a437b44fa42c2e00f23d6ebd0dcb1b5decb94d570b433e9d6e6f0e6e08	/home/extra/user/torrents/Homestuck Discography/Alternia/07 - Walls Covered In Blood.mp3
1697	1253	1682	1696	2012-11-30 05:06:39+00	0	\N	1a3c1f0521019b673fe34d7ca89cd5c788da24f264d4c0936f6b27a6974c53d1	/home/extra/user/torrents/Homestuck Discography/Alternia/11 - The La2t Frontiier.mp3
1685	1253	1682	1684	2012-11-30 05:06:38+00	0	\N	3e733565d5a6fc8c99df5547d12e781599ddc9f0e48a234b41d2e97d607605d1	/home/extra/user/torrents/Homestuck Discography/Alternia/18 - Walls Covered in Blood DX (Bonus).mp3
1687	1253	1682	1686	2012-11-30 05:06:38+00	0	\N	9be22bb825ac25005a55b9da42421761b064843930b9267e447c1043d4a0ef45	/home/extra/user/torrents/Homestuck Discography/Alternia/14 - Spider's Claw (Bonus).mp3
1689	1253	1682	1688	2012-11-30 05:06:38+00	0	\N	bc432c2ad0a75ca10b64cf77e9eec5d0cf99ec6e7371c9fd7089d970ab2fe8d1	/home/extra/user/torrents/Homestuck Discography/Alternia/17 - Theme (Bonus).mp3
1699	1253	1682	1698	2012-11-30 05:06:39+00	0	\N	27b9c69bcae1d03fe2348bc3286cfdc1c90485a044aeac280db716aadfcfb0f4	/home/extra/user/torrents/Homestuck Discography/Alternia/06 - psych0ruins.mp3
1691	1253	1682	1690	2012-11-30 05:06:38+00	0	\N	e3d4b489d5388837c5cb13d9fc1b56dd3ba5928a09b6304f0ee668bbe59a4ae3	/home/extra/user/torrents/Homestuck Discography/Alternia/05 - Phaze and Blood.mp3
1709	1253	1682	1708	2012-11-30 05:06:41+00	0	\N	54acedeef349ee6d4ef36c747b347a81b0994f7295818f4d36c667cc099ebd50	/home/extra/user/torrents/Homestuck Discography/Alternia/08 - dESPERADO ROCKET CHAIRS,.mp3
1701	1253	1682	1700	2012-11-30 05:06:40+00	0	\N	262685663435d3ed67873d900361147de8c310aec6503da6f7afd752ff07b772	/home/extra/user/torrents/Homestuck Discography/Alternia/15 - Staring (Bonus).mp3
1703	1253	1682	1702	2012-11-30 05:06:40+00	0	\N	b68dc1e60d903b1f26797842d0a7f06b2e6886ea5566595a9c47af775f281921	/home/extra/user/torrents/Homestuck Discography/Alternia/10 - Virgin Orb.mp3
1289	1253	1254	1288	2012-11-30 05:05:22+00	0	\N	b10194fac5106520aa991ad6c1fe661c9464a3f31aea764c6923a10d0c90e096	/home/extra/music/Homestuck/Homestuck Volume 5/61 Doctor Remix.mp3
1705	1253	1682	1704	2012-11-30 05:06:41+00	0	\N	b2f614fa003f8421603e91b907a48a90b82bbdfc7cbf299c58e8d837b5bca2c1	/home/extra/user/torrents/Homestuck Discography/Alternia/03 - mIrAcLeS.mp3
1711	1253	1682	1710	2012-11-30 05:06:42+00	0	\N	06af6c942b2b23d5f7970c05ce7752141720102c6aa3feba23b4a8661617f088	/home/extra/user/torrents/Homestuck Discography/Alternia/04 - The Lemonsnout Turnabout.mp3
1717	1253	1682	1716	2012-11-30 05:06:42+00	0	\N	cf2f07778f6936072604f60d3f457335bdf6cebb9d14a5b1b6ee160bb0109b04	/home/extra/user/torrents/Homestuck Discography/Alternia/09 - Death of the Lusii.mp3
1713	1253	1682	1712	2012-11-30 05:06:42+00	0	\N	ba1f99f8d522eb80593464383c77496d674cf25b76f691292b1f3313b60fd4c2	/home/extra/user/torrents/Homestuck Discography/Alternia/02 - Showdown.mp3
1722	1253	1719	1721	2012-11-30 05:06:43+00	0	\N	11b20314798861387fc1550f315a6a0f336d3c4e2d588c1765bed073185d1953	/home/extra/user/torrents/Homestuck Discography/Song of Skaia/01 - Null.mp3
1720	1253	1719	1718	2012-11-30 05:06:43+00	0	\N	68e4b4d667d0423f783baacfef9a4c1593e193573fc94862dc85a36d2622932a	/home/extra/user/torrents/Homestuck Discography/Song of Skaia/02 - Skaian Birth.mp3
1727	1253	1726	1725	2012-11-30 05:06:43+00	0	\N	39437b4ede36bec6c7477ab8dc16c76ebd7e211f25ab6b5b96f9c51480a118eb	/home/extra/user/torrents/Homestuck Discography/Sburb/07 - Chronicles.mp3
1724	1253	1719	1723	2012-11-30 05:06:43+00	0	\N	f05587a41b9861c221702314906841e3b11b3d71e0d5f9a487dc91159af1c1f9	/home/extra/user/torrents/Homestuck Discography/Song of Skaia/03 - Song of Skaia.mp3
1729	1253	1726	1728	2012-11-30 05:06:44+00	0	\N	cfd105d62b974e5f6dfc250d8015cb0c141d387f127b717cc38ef7e030b8966f	/home/extra/user/torrents/Homestuck Discography/Sburb/04 - Exodus.mp3
1731	1253	1726	1730	2012-11-30 05:06:44+00	0	\N	6adb250b958e487b5adf531998501d0bd7e6a153d34cd381d7ff6b2785d44917	/home/extra/user/torrents/Homestuck Discography/Sburb/05 - Requiem.mp3
1733	1253	1726	1732	2012-11-30 05:06:44+00	0	\N	036a5dfc44ff1a64fc1030f373f5adfa28ae268ab586082d7102117f80eb1b8a	/home/extra/user/torrents/Homestuck Discography/Sburb/03 - Eden.mp3
1735	1253	1726	1734	2012-11-30 05:06:45+00	0	\N	3cbd82bce774f9aea1df8f23103d047ef9f997196739266f6d8c47039dc6d4ab	/home/extra/user/torrents/Homestuck Discography/Sburb/11 - Revelations II.mp3
1789	1253	1768	1788	2012-11-30 05:06:53+00	0	\N	33a15447acf0450cf571b19c4caa38a37bb1bd83d1a77bf651d92f5c054e4ea0	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/21 - Jackie Treats.mp3
1737	1253	1726	1736	2012-11-30 05:06:45+00	0	\N	bacf758ad1be38b01d06d04784ad5dc10e084db888db57b646a3e67de3a40a50	/home/extra/user/torrents/Homestuck Discography/Sburb/10 - Revelations I.mp3
1762	1253	1751	1761	2012-11-30 05:06:49+00	0	\N	aebbc42bd243aab56cd2db042d8f28664b5026b2c49c4f111c693c34ea19b0f2	/home/extra/user/torrents/Homestuck Discography/Prospit & Derse/05 - Darkened Streets.mp3
1739	1253	1726	1738	2012-11-30 05:06:45+00	0	\N	3ed245bda45ed23475cbc5473b182180e9bc11b7d4f49bd37dc3f1ee803c2397	/home/extra/user/torrents/Homestuck Discography/Sburb/01 - The Prelude.mp3
1741	1253	1726	1740	2012-11-30 05:06:45+00	0	\N	78f31b22bf01958ceeedec3eba255b25731a23f3fe3ccab331e3ca0731e0d3c2	/home/extra/user/torrents/Homestuck Discography/Sburb/08 - Rapture.mp3
1777	1253	1768	1776	2012-11-30 05:06:51+00	0	\N	a73059e74c397f90d706f2f77f637924ba27d120b1177ade1093a371180cc186	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/29 - Under the Hat.mp3
1743	1253	1726	1742	2012-11-30 05:06:46+00	0	\N	69ff0d343f1f77ae0f970c61dbdf1c3f6ec376dbe90d4128ed8cbbd88029fc29	/home/extra/user/torrents/Homestuck Discography/Sburb/06 - The Meek.mp3
1764	1253	1751	1763	2012-11-30 05:06:49+00	0	\N	49b003a5e02ce0af8e5a6027b867a0b52bef70270f8e4a9884013c354357fbd1	/home/extra/user/torrents/Homestuck Discography/Prospit & Derse/07 - Derse Dreamers.mp3
1745	1253	1726	1744	2012-11-30 05:06:46+00	0	\N	1e777a9dd41f48460424d05807b01e118ed8b455cbfab1c151cf6365b7aead5d	/home/extra/user/torrents/Homestuck Discography/Sburb/02 - Genesis.mp3
1747	1253	1726	1746	2012-11-30 05:06:46+00	0	\N	06502904650a2ab9a4205fc4a128313cc90e0369d00059056d688fe07903b52d	/home/extra/user/torrents/Homestuck Discography/Sburb/12 - Revelations III.mp3
1749	1253	1726	1748	2012-11-30 05:06:47+00	0	\N	d01d0c8a7a90bfc44c8633da043b6ef6176c3897c5f1e7f0c0646838548ba50d	/home/extra/user/torrents/Homestuck Discography/Sburb/09 - Creation.mp3
1766	1253	1751	1765	2012-11-30 05:06:49+00	0	\N	a9a1c25faabdcfce3ac8105e20388a81ac0773ab1cffc012c3ccd70738129665	/home/extra/user/torrents/Homestuck Discography/Prospit & Derse/04 - Center of Brilliance.mp3
1752	1253	1751	1750	2012-11-30 05:06:47+00	0	\N	f1616edc622e2cedc48f0228511b814fe13addf917ccd7de8fa9a1ec642f3346	/home/extra/user/torrents/Homestuck Discography/Prospit & Derse/01 - Hallowed Halls.mp3
1754	1253	1751	1753	2012-11-30 05:06:48+00	0	\N	b5dbfedd58ce3419a9d8cb0605ac19d3f6f025fbc3d3c13f0b671417b4e0a183	/home/extra/user/torrents/Homestuck Discography/Prospit & Derse/06 - The Obsidian Towers.mp3
1785	1253	1768	1784	2012-11-30 05:06:53+00	0	\N	3b2b710a10a275b27478d23c8edba879e9b4e96caf774a72c2b28246b374ffa4	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/13 - Clockbreaker.mp3
1756	1253	1751	1755	2012-11-30 05:06:48+00	0	\N	5bc1540be8eb2dab75e5751ce271ea1474428abf88017a12e56100864977c916	/home/extra/user/torrents/Homestuck Discography/Prospit & Derse/02 - The Golden Towers.mp3
1769	1253	1768	1767	2012-11-30 05:06:50+00	0	\N	c357130ce5f88ebc294d050830ac39c9a2ac4f53e9f702f3c81a7eb246a1f522	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/51 - Farewell.mp3
1758	1253	1751	1757	2012-11-30 05:06:48+00	0	\N	ccbc71b35d17bacb8adcefecde7d2b5860413347652a34ba112ead95a5a064b6	/home/extra/user/torrents/Homestuck Discography/Prospit & Derse/03 - Prospit Dreamers.mp3
1760	1253	1751	1759	2012-11-30 05:06:49+00	0	\N	e3ab3f75af306c98675e443ced8ef760788237c0f9df082424f8abed5db48bb6	/home/extra/user/torrents/Homestuck Discography/Prospit & Derse/08 - Core of Darkness.mp3
1779	1253	1768	1778	2012-11-30 05:06:52+00	0	\N	11e351587a864e94c3e03081efe526d68d5b77b6e655b3802abf5147a7cb058d	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/49 - Ira quod Angelus.mp3
1771	1253	1768	1770	2012-11-30 05:06:50+00	0	\N	f4ce02415a067697a838322fc7a95180b744c4f08cfaf4c70ad61bc1ebdf9154	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/39 - Vigilante.mp3
1773	1253	1768	1772	2012-11-30 05:06:50+00	0	\N	2cc9aacb1eee21ee67e67f1ecca37cc8fbcf6787b4cb395efd78a680afeec848	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/38 - Nakkadile.mp3
1775	1253	1768	1774	2012-11-30 05:06:51+00	0	\N	b385de06250ec7c2a087695db4e3f793c2e21b1ae1a0e7f8270acfc574e9d744	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/11 - Vigilante ~ Cornered.mp3
1781	1253	1768	1780	2012-11-30 05:06:52+00	0	\N	bb7f1e6966e673eceaab1aaf565adc4aa16a30598926b51b760e5c6031b2c75c	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/07 - Thought and Flow.mp3
1783	1253	1768	1782	2012-11-30 05:06:52+00	0	\N	2d479e246987cfb14bb7da9945ef64a4f04d553ba65223ff944beb8ab72f8278	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/12 - A Fashionable Escape.mp3
1787	1253	1768	1786	2012-11-30 05:06:53+00	0	\N	c4fe8562c238050fa822643bf3052298aaecba82cfaeb147f501796f3b73552b	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/09 - Land of Wrath and Angels.mp3
1295	1253	1254	1294	2012-11-30 05:05:23+00	0	\N	23e002fc596df29083187913b1dcaeb854512d04adc374a2ffaeaca345bf21dc	/home/extra/music/Homestuck/Homestuck Volume 5/51 Light.mp3
1793	1253	1768	1792	2012-11-30 05:06:54+00	0	\N	cb440b1e9bf53f0dbd332607d41a6a894f41ad570181a2a9f9a49deeb42596c0	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/23 - Sburban Elevator.mp3
1791	1253	1768	1790	2012-11-30 05:06:54+00	0	\N	41a7cab91ae37b4fcd9ebbdb86285feb486f26edbb324bae9c0fe7fb2f04e6e6	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/47 - Growing Up.mp3
1795	1253	1768	1794	2012-11-30 05:06:54+00	0	\N	d148eaf3d66a9e22cca6d37382b5558f038a456925a82c353a78989e6dfbc02d	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/28 - SadoMasoPedoRoboNecroBestiality.mp3
1797	1253	1768	1796	2012-11-30 05:06:54+00	0	\N	4739fecc279abe4e61cf90e413727521dac1b4c2659b6c78d2eb925013ca90d3	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/04 - Meltwater.mp3
1799	1253	1768	1798	2012-11-30 05:06:55+00	0	\N	4eb0925efc74ba1d8cc2261d380a946dd98615d499bf38d0b8e4f97346129256	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/26 - Maibasojen.mp3
1296	1253	1254	1252	2012-11-30 05:05:23+00	0	\N	0c3d871f8f913884036db744f023a71d59f4c9e32e3962d464307092a564483d	/home/extra/music/Homestuck/Homestuck Volume 5/42 Clockwork Contrivance.mp3
1801	1253	1768	1800	2012-11-30 05:06:55+00	0	\N	fdea719b3d454388d450149189c390c2c44e742ae92fda2ca5378a951df87979	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/53 - Cutscene at the End of the Hallway.mp3
1825	1253	1768	1824	2012-11-30 05:06:58+00	0	\N	136ae9a5fd9104df91686511d8486e088ca1b7ad159bc1b3526589b3daff7c71	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/01 - Beginnings (Press Start to Play).mp3
1803	1253	1768	1802	2012-11-30 05:06:55+00	0	\N	3c80bc23012f6f169cae2e4896bb9bef2f70fbf0c879249b22180ad7e7f66b81	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/24 - Moody Mister Gemini.mp3
1805	1253	1768	1804	2012-11-30 05:06:55+00	0	\N	cfb4fce8420e81d045ff9b6101ba52544dc89f9e626c10c6edb1a3d9e44a691b	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/14 - Quartz Lullaby.mp3
1851	1253	1768	1850	2012-11-30 05:07:03+00	0	\N	82811128d1bbf2f7f2923a902320b3ed1390afc9fdf8f55cf44167aa367718ad	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/37 - Growin' Up Strider.mp3
1807	1253	1768	1806	2012-11-30 05:06:56+00	0	\N	34472aa646fd124266ff610ab607f28fe3258a2e235fa965ad8978bc02f23b97	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/06 - The Land of Wind and Shade.mp3
1827	1253	1768	1826	2012-11-30 05:06:59+00	0	\N	0dd6d6d2bb5158b2c53c0388dfbec954d9e3d081bc27c318060e30f57f170c2f	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/34 - Midnight Spider.mp3
1809	1253	1768	1808	2012-11-30 05:06:56+00	0	\N	3c95b0fe22581c95627c7c5ece26df2ca7a1fcfd2b43d83700a7034e13e21a3a	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/31 - The Hymn of Making Babies.mp3
1811	1253	1768	1810	2012-11-30 05:06:56+00	0	\N	dcc76fd879cf51ac4531f05d5fc5e313caf3088d5eb8867719b8dcaca78597bc	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/16 - Joker Strife.mp3
1839	1253	1768	1838	2012-11-30 05:07:01+00	0	\N	505a5738461b7e03c4f675af1dc456e824bc6235cba09e75f6432fce88dcb823	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/10 - Ruins of Rajavihara.mp3
1813	1253	1768	1812	2012-11-30 05:06:56+00	0	\N	acb972f7c4fdc541494f9f0105cb924a7f56094cf25067841d063b3e03855438	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/02 - Downtime.mp3
1829	1253	1768	1828	2012-11-30 05:06:59+00	0	\N	9d73ac651f22d5cd717332861cd2a82f7d299e61f472ba64f5bcb1a5fca2c35d	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/44 - MegaloVaniaC.mp3
1815	1253	1768	1814	2012-11-30 05:06:57+00	0	\N	8e0ac546b665d0915290b54eec885142bef7d22ed25104a8fac1d7418a8e941c	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/08 - First Guardian, Last Stand.mp3
1817	1253	1768	1816	2012-11-30 05:06:57+00	0	\N	5dc5d9b6807ac74f1f7c0e1ff21e33cdd81eeb3a15cef2660f51cfb84aa4d50b	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/25 - Starkind.mp3
1819	1253	1768	1818	2012-11-30 05:06:57+00	0	\N	86201a3b1a7449e46b131cf5a5a94196ea39d6a5cf06417eab1cafd39b5517b4	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/45 - Shame and Doubt.mp3
1831	1253	1768	1830	2012-11-30 05:06:59+00	0	\N	6458a187048826625f9af20d2f8f359da7ac8bd4b741adbf61bf2a2d0b902d19	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/32 - Emissary of Wind.mp3
1821	1253	1768	1820	2012-11-30 05:06:58+00	0	\N	8669513192f79700bec176cbda07bf9a8d6d59058933c3790d9f6f73ee568927	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/46 - SWEET BRO AND HELLA JEFF SHOW.mp3
1823	1253	1768	1822	2012-11-30 05:06:58+00	0	\N	c4aee0498cd82ab987289fb2de575fac23de1f1c36375a78546536b57cc0c5b5	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/15 - Dance of the Wayward Vagabond.mp3
1847	1253	1768	1846	2012-11-30 05:07:02+00	0	\N	3569057506e800fc6164dc9d2423691ca5f1f2ac1fe4db98131cac2aeb4f90fc	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/35 - House of Lalonde.mp3
1841	1253	1768	1840	2012-11-30 05:07:01+00	0	\N	5735296241c5c3eaf656de18bc21ae9be81f4e48c7ba6d608ccca48682b8a49d	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/20 - Atomik Meltdown.mp3
1833	1253	1768	1832	2012-11-30 05:07:00+00	0	\N	6da70a5fcc314b52a8b7969f4bd109d69e49350e3e70c96a00d9f2267e54b066	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/42 - Corpse Casanova.mp3
1835	1253	1768	1834	2012-11-30 05:07:00+00	0	\N	d875f6648985abf8bf4b85dd013ddbac9670190cc281e584049da4615ad8757e	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/19 - Prince of Seas.mp3
1837	1253	1768	1836	2012-11-30 05:07:00+00	0	\N	7c7ed27abad6b2f22c62363ea85134aac30e83dd0a33711b1e625b362194dff9	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/48 - The Drawing of the Four.mp3
1843	1253	1768	1842	2012-11-30 05:07:02+00	0	\N	55fc95105fd93202db9776f7ea49c09b8a1620b816907743122aa07f311dc9a0	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/36 - L'etat de l'ambivalence.mp3
1845	1253	1768	1844	2012-11-30 05:07:02+00	0	\N	cedd7154df79e5d44258c2ca2e3d04d451f10213cb9d35f058c1e8fc50cb4e35	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/27 - MeGaDanceVaNia.mp3
1849	1253	1768	1848	2012-11-30 05:07:02+00	0	\N	c0e4cdb684d984e672657888efc50e57195a75d7cb4324441c842181d9c50a81	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/41 - A War of One Bullet.mp3
1855	1253	1768	1854	2012-11-30 05:07:03+00	0	\N	114cd03966334163bb71708898a7eb1ab3be371209c7924b813c19c9fb563158	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/22 - Skaian Air.mp3
1853	1253	1768	1852	2012-11-30 05:07:03+00	0	\N	e2182b5aaa8933e0458643f3a0c9400eb825768f9f64373b5dbc887e0a3e509d	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/18 - Sburban Rush.mp3
1857	1253	1768	1856	2012-11-30 05:07:03+00	0	\N	045c7e2b3651c370c79520db19975109547bb99260c42f9364e891bcbd9c08f1	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/40 - Jack and Black Queen.mp3
1859	1253	1768	1858	2012-11-30 05:07:04+00	0	\N	f08accd04bde5503b0d46d83e1d7a862daf118ee0d32ba56a1bf206f4156e36b	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/52 - Heir-Seer-Knight-Witch.mp3
2053	1253	2016	2052	2012-11-30 05:07:32+00	0	\N	828f6f9744cea850d9ee2cbb30d95c815f5b285d7992f0c5e07e15e6b79406e5	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/06 - Phantom Echoes.mp3
1861	1253	1768	1860	2012-11-30 05:07:04+00	0	\N	06732ebdfb9908970aac7eca8f54cc069cfbabc4d999735a673ee5e78f9ea1a2	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/33 - Land of Quartz and Melody.mp3
1886	1253	1875	1885	2012-11-30 05:07:08+00	0	\N	8a2e86862b82601af422a09549d21ea033b393282d100390088b3ad2b3e2dd51	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/07 - The Squiddles Save Christmas.mp3
1863	1253	1768	1862	2012-11-30 05:07:05+00	0	\N	9b23f15e60ae0e9deab06eb9a2f113c9141ecc42258b084b87107b9dada32bcc	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/17 - Sunshaker.mp3
1865	1253	1768	1864	2012-11-30 05:07:05+00	0	\N	0deef80fd274601c29450f4f00d82893d6f81c9aab6de80a9a4d5b5ff378dc5c	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/43 - Salamander Fiesta.mp3
1912	1253	1875	1911	2012-11-30 05:07:12+00	0	\N	24342a43c481b11f9fda68484e067f6c6ffb39a7640f0f45da0f3c1bd93df7fa	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/14 - Candlelight.mp3
1867	1253	1768	1866	2012-11-30 05:07:05+00	0	\N	9b6d06beeb9f4a1c3333d073c92d93b06bbc4419d09702e187c7c185b1e3dcc9	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/30 - Sburban Piano Doctor.mp3
1888	1253	1875	1887	2012-11-30 05:07:09+00	0	\N	010fdc45826a9abe92d8ecfd4e56d99fb3bf59b084c2597ceb7af17ceb907413	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/05 - Carefree Perigee.mp3
1869	1253	1768	1868	2012-11-30 05:07:06+00	0	\N	1db4a978b7d4fcb67d9fbdab8758781e2871b7a7a7904d0108a4586490ffe31f	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/03 - Doctor (Deep Breeze Mix).mp3
1871	1253	1768	1870	2012-11-30 05:07:06+00	0	\N	6f81daf2278d495bed9b1469a21e964906f5da4373ecd637a4f559871bd336e2	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/50 - Final Stand.mp3
1900	1253	1875	1899	2012-11-30 05:07:10+00	0	\N	04bdefa9326141c2398200519bcb17bf7172902d8086d8369c0151773426afa2	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/08 - Billy the Bellsuit Diver Has Something to Say.mp3
1873	1253	1768	1872	2012-11-30 05:07:06+00	0	\N	cf575fda4ee7597f791e4d36422cf909326bb6f8718d533d2de58462f26fae80	/home/extra/user/torrents/Homestuck Discography/Land of Fans and Music/05 - Crystalanachrony.mp3
1890	1253	1875	1889	2012-11-30 05:07:09+00	0	\N	dbcd0a7f3448ecaf8d93b7f2f39f9ae288145e408dba5a988dd65265278ec4f1	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/17 - Hella Sweet.mp3
1876	1253	1875	1874	2012-11-30 05:07:07+00	0	\N	1c6c76806527aa5a7d1447cd0ba3d65068209084e146db9d7ef093b8c1ec76fa	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/16 - Let it Snow.mp3
1878	1253	1875	1877	2012-11-30 05:07:07+00	0	\N	265f039aa802c80e5a4014b04e8fd22ea8b536f5cc3918c9fed8370798b7757a	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/12 - Gog Rest Ye Merry Prospitians.mp3
1880	1253	1875	1879	2012-11-30 05:07:07+00	0	\N	034295a0b7feedd8199ec12e4d5ea1ba9adfc336cf37e76b886bcaa683ceb494	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/19 - Choo Choo.mp3
1892	1253	1875	1891	2012-11-30 05:07:09+00	0	\N	11e89b43f812c0dc18253ba842358757be3630f00f4e72e220dd3613b30c14a4	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/18 - Shit, Let's Be Santa.mp3
1882	1253	1875	1881	2012-11-30 05:07:08+00	0	\N	c9cedfed12179492c6baddfe1615832c9101b30c8af63380c51a8c84a2635952	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/13 - Carolmanthetime.mp3
1884	1253	1875	1883	2012-11-30 05:07:08+00	0	\N	11befe57852c77e3f8161170c6798b4276db470c4eb0fe17a48c3e1acdbd2fdf	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/03 - Anthem of Rime.mp3
1908	1253	1875	1907	2012-11-30 05:07:11+00	0	\N	9ead48e80347e48d29872bf330730dddf524de7d9fc2f6f58110045153b8affd	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/02 - A Skaian Christmas.mp3
1902	1253	1875	1901	2012-11-30 05:07:11+00	0	\N	66f9f5cc3059a00f5974351c6e9b4c7f3eb9dd87409aaa4c4778b8c5ffe53d85	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/21 - A Very Special Time.mp3
1894	1253	1875	1893	2012-11-30 05:07:09+00	0	\N	e3a50ac19d92d3878531df3e255c7d3485cd192f2f2118c0048d840a6273b818	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/22 - Candles and Merry Gentlemen.mp3
1896	1253	1875	1895	2012-11-30 05:07:10+00	0	\N	06db1631de8a5bcaa368e06a2c030c3b957bd08400b45cee18c2f9611c874bd9	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/11 - Land of Light and Cheer.mp3
1898	1253	1875	1897	2012-11-30 05:07:10+00	0	\N	b8561f7f902bdfafdc74a2c26ef45cd2d88d84ad91e1149817124c4915ba4342	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/06 - The More You Know.mp3
1904	1253	1875	1903	2012-11-30 05:07:11+00	0	\N	12da90f3e4221b1d34ab2393f9f727d3fae8c4f44f71f24def9be47c8142d087	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/09 - Squiddly Night.mp3
1906	1253	1875	1905	2012-11-30 05:07:11+00	0	\N	287729264d683fb8dd5c77a9a07863014b4ae76ee664748ce970f92a37d903ad	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/01 - Time for a Story.mp3
1910	1253	1875	1909	2012-11-30 05:07:12+00	0	\N	e4267b21c404065872a53ab6795c98d1e7f9f52598d601650de8ab688e627d72	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/10 - The Santa Claus Interdimensional Travel Sleigh.mp3
1914	1253	1875	1913	2012-11-30 05:07:12+00	0	\N	649211990e7ec814eacb1e26a03ff2b46bcea8e0d2c36ccdbd5816005b317a2f	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/04 - Pachelbel's Gardener.mp3
1916	1253	1875	1915	2012-11-30 05:07:12+00	0	\N	33c9bdd8db5bbe108d6558c51769c6cc8e67eeb16ff9e3863e9acb46fc9aa83b	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/20 - Oh, God, Christmas!.mp3
1918	1253	1875	1917	2012-11-30 05:07:12+00	0	\N	baee664b0a86c53b2bf0dc0cd53cfa3972ef0aab7fe9eced63ed1e645be05b37	/home/extra/user/torrents/Homestuck Discography/Homestuck for the Holidays/15 - Oh, No! It's the Midnight Crew!.mp3
1361	1253	1254	1360	2012-11-30 05:05:37+00	0	\N	fe2ab1e8806908fa2486d5cae2f0dde123f19bb5580628f9ad48e798f2a6f5fb	/home/extra/music/Homestuck/Homestuck Volume 5/33 Lotus.mp3
1921	1253	1920	1919	2012-11-30 05:07:13+00	0	\N	0e95f81dbf621083c3103be7ece13abc8a253ffcb9697de6b2aedf9bbd3b6aae	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/17 - Midnight Calliope.mp3
1362	1253	1254	1358	2012-11-30 05:05:37+00	0	\N	4afb4794fa8b12307ac00abab0482280752034e0f64bc691b79a5ef45067a209	/home/extra/music/Homestuck/Homestuck Volume 5/27 Bed of Rose's - Dreams of Derse.mp3
1923	1253	1920	1922	2012-11-30 05:07:13+00	0	\N	c8064d27ac405df9f5a728e2fac0e731a5cf3fa969fb2a60af708cd54bc02b6e	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/11 - Requiem Of Sunshine And Rainbows.mp3
1975	1253	1920	1974	2012-11-30 05:07:20+00	0	\N	8b2dd4befed1eebad2265f0dc1b1da25aef9418bfaef3c8308e0737db4970ebd	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/19 - Trollian Standoff.mp3
1925	1253	1920	1924	2012-11-30 05:07:13+00	0	\N	feeace1cb96c85863699879dd822cef8cd9fcfb2b692314467d9a9f28173e3c6	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/24 - Catapult Capuchin.mp3
1949	1253	1920	1948	2012-11-30 05:07:17+00	0	\N	78158547505ffffcf9ae3d3d8ed6d9cf6d8db6869b509a0695a2f6e6566d8cf1	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/23 - Trollcops (Radio Play).mp3
1927	1253	1920	1926	2012-11-30 05:07:13+00	0	\N	a4498f5320a4c09abe183689a001b6633ccba438589f047f18ebcdfb375dc39c	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/09 - FIDUSPAWN, GO!.mp3
1929	1253	1920	1928	2012-11-30 05:07:14+00	0	\N	669c91f47f509a2e140fbaf51dc021b308a20a0a636ecf0783df1526ef6ee9eb	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/12 - Eridan's Theme.mp3
1963	1253	1920	1962	2012-11-30 05:07:18+00	0	\N	b3b34006b8f26dcd131719a8a886ab84e7d9a51673cf1fbad319d17f6e9506fd	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/13 - Nautical Nightmare.mp3
1931	1253	1920	1930	2012-11-30 05:07:14+00	0	\N	31e1597cd2737f93eb8b5d92c1c2601e90b391bdde87dba1b556fa0a20d562b4	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/20 - Rex Duodecim Angelus.mp3
1951	1253	1920	1950	2012-11-30 05:07:17+00	0	\N	e9e864f6f74c5456d4097948e85feff4d669816d861389cde90e0ba156b69a8a	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/02 - Karkat's Theme.mp3
1933	1253	1920	1932	2012-11-30 05:07:15+00	0	\N	35ad012150904ad546794725463eef31e011257d720cfd8582ce3c855b402a34	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/30 - Rest A While.mp3
1935	1253	1920	1934	2012-11-30 05:07:15+00	0	\N	53345f675ca6f84837caddfcf351b4c0581c3ee56f9312ade3a81077564b14fe	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/06 - Dreamers and The Dead.mp3
1937	1253	1920	1936	2012-11-30 05:07:15+00	0	\N	d730a472d3f6f076ee03cdae286cdc937262cd3400d4df54093acf9a9da1c59c	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/22 - Alternia.mp3
1953	1253	1920	1952	2012-11-30 05:07:17+00	0	\N	50c49b81ab1d906b8ccccb10e8c371a0d9414290ab2a8a60953be1af3af2ba3c	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/03 - Trollcops.mp3
1939	1253	1920	1938	2012-11-30 05:07:15+00	0	\N	8b368d5d19de13beb6c33411973bef7fbeb72f7c68c16320de18b1f0c7e6b845	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/01 - Arisen Anew.mp3
1941	1253	1920	1940	2012-11-30 05:07:16+00	0	\N	2583a8e3639d3a2807b3870b9c19750f7ac65802aa9447730ca694f3e5aea2cf	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/07 - Vriska's Theme.mp3
1971	1253	1920	1970	2012-11-30 05:07:19+00	0	\N	2126608c9f1f680e9f06944666b083e37bc585c3ce970d380131a30453575129	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/25 - Science Seahorse.mp3
1943	1253	1920	1942	2012-11-30 05:07:16+00	0	\N	521cede08cd8aea8893d080bc8ec9cf6d3d412b1b6d37d06e74a6af010feee36	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/10 - Darling Kanaya.mp3
1955	1253	1920	1954	2012-11-30 05:07:17+00	0	\N	7cf07efc9ae0e7674924350ab243c254e35af8fdeb4c8e87269896970939bdd1	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/16 - Blackest Heart (With Honks).mp3
1945	1253	1920	1944	2012-11-30 05:07:16+00	0	\N	6d0b614c7ec77e62c08ec92e2e5b4426c61bf02f09ca85078a782374020175dd	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/27 - The Blind Prophet.mp3
1947	1253	1920	1946	2012-11-30 05:07:16+00	0	\N	ac9b27534b20a06f46666c0a8b0d308bf25608c673767a46be9a5aea58c5cfd7	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/21 - Killed by BR8K Spider!!!!!!!!.mp3
1965	1253	1920	1964	2012-11-30 05:07:19+00	0	\N	1e50befdb1f160623d0e34527c577f306524ca0a2ed1c39f7cb921b2f905a2eb	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/15 - Horschestra STRONG Version.mp3
1957	1253	1920	1956	2012-11-30 05:07:18+00	0	\N	2961a444b05233199fb80d8e8d321ebce0d16b491a9b1c74102aaf6eb1739f8f	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/05 - Terezi's Theme.mp3
1959	1253	1920	1958	2012-11-30 05:07:18+00	0	\N	b02c91021a5cb2702c297607368da6ec9836fa640957cfb88ce80f2848e7e54e	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/14 - Nepeta's Theme.mp3
1961	1253	1920	1960	2012-11-30 05:07:18+00	0	\N	8e4de0ef9edf6129cdcc539673dcdff1153627ebbbcb2bfce86a1f7c2a6a8f0c	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/28 - AlterniaBound.mp3
1967	1253	1920	1966	2012-11-30 05:07:19+00	0	\N	b143840bc7d11b24b47edaa3f1a43e613e3e55b51085218e2f4242473ea7ec48	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/08 - She's a Sp8der.mp3
1969	1253	1920	1968	2012-11-30 05:07:19+00	0	\N	f32b89d8c535feb2a270ef404d4ecd3975ee13268afeb9318c3abfd611fc1199	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/04 - BL1ND JUST1C3 - 1NV3ST1G4T1ON !!.mp3
1973	1253	1920	1972	2012-11-30 05:07:20+00	0	\N	7ca7650e2d6fe3b7c98ad9cacdaf5057d16b5d72b68545203f826e819fe0c012	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/26 - A Fairy Battle.mp3
1979	1253	1920	1978	2012-11-30 05:07:20+00	0	\N	74356c02f5a2f5b54c6c94e7c1a6e52e0c864c0826d5a85ee002776e632aae7c	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/18 - Chaotic Strength.mp3
1977	1253	1920	1976	2012-11-30 05:07:20+00	0	\N	79d970a289aa67a81df69807b4e4d7e1c140914ed2d6a0b4656271cf33befc66	/home/extra/user/torrents/Homestuck Discography/AlterniaBound/29 - You Won A Combat.mp3
1400	1253	1254	1302	2012-11-30 05:05:47+00	0	\N	c91e5a2ef08b02ff1674464ecc446f9394591c1c37a1c71ceb868620271eca4f	/home/extra/music/Homestuck/Homestuck Volume 5/60 Enlightenment.mp3
1982	1253	1981	1980	2012-11-30 05:07:21+00	0	\N	91c4a09253ea3afca9a2a5aaac74144d62f287d50cbe68e19a6bbf4adbf9b63f	/home/extra/user/torrents/Homestuck Discography/The Felt/17 - Variations.mp3
1984	1253	1981	1983	2012-11-30 05:07:22+00	0	\N	3c611e83cf4e17636a4f5dee68e43d4bf5e116e7c5d76057e9db608aa30ad9b6	/home/extra/user/torrents/Homestuck Discography/The Felt/02 - Swing of the Clock.mp3
1986	1253	1981	1985	2012-11-30 05:07:22+00	0	\N	c9f490f357bc21f14b46ab46aec7ef8b8fd58e99da746c6207f5e38196a88091	/home/extra/user/torrents/Homestuck Discography/The Felt/05 - Clockwork Reversal.mp3
1988	1253	1981	1987	2012-11-30 05:07:22+00	0	\N	8689cef5021eeb6d7d345109a8a72a7ac5f967a63e8ee21e626a4661658fb006	/home/extra/user/torrents/Homestuck Discography/The Felt/10 - Baroqueback Bowtier (Scratch's Lament).mp3
2041	1253	2016	2040	2012-11-30 05:07:31+00	0	\N	247b51a432a4d3210bc3a20e81468e9cbcbf1d2d055a2c7562972a6619d9ecee	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/29 - b a w s.mp3
1990	1253	1981	1989	2012-11-30 05:07:23+00	0	\N	bacc4863fcfc4a7de33a7fd4000355296817237fbc633402f06e58b87a16bb08	/home/extra/user/torrents/Homestuck Discography/The Felt/12 - Omelette Sandwich.mp3
2014	1253	1981	2013	2012-11-30 05:07:26+00	0	\N	800e85a61d340f2ea70dc85f6fe17ec98273c8c731f683160471aeab62c593dd	/home/extra/user/torrents/Homestuck Discography/The Felt/14 - Time Paradox.mp3
1992	1253	1981	1991	2012-11-30 05:07:23+00	0	\N	e179c7b6cb1a4bb0e439d2399adc4cfe4f22600457abca1d596a15b92b8b3c29	/home/extra/user/torrents/Homestuck Discography/The Felt/04 - Humphrey's Lullaby.mp3
1994	1253	1981	1993	2012-11-30 05:07:23+00	0	\N	0eb7eb2a682ece553f0bac30792a2363c56f0c4ddd0fe7a8f6fd09c8af3d6661	/home/extra/user/torrents/Homestuck Discography/The Felt/08 - Apocryphal Antithesis.mp3
2029	1253	2016	2028	2012-11-30 05:07:30+00	0	\N	663adbd68cb0ff614f1309963eaed6b5d3b730fe6b65c564ed5292a9a0a6c424	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/17 - Drillgorg.mp3
1996	1253	1981	1995	2012-11-30 05:07:24+00	0	\N	ddb67369e179b67e116dfee4b911e664d42ff0b0acc90c4691fc8b813eba28f2	/home/extra/user/torrents/Homestuck Discography/The Felt/07 - The Broken Clock.mp3
2017	1253	2016	2015	2012-11-30 05:07:27+00	0	\N	5efacf78adab4dea65a9042f260edc674eaed8495a8f8eaeb79aa3a0f8b03dfb	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/10 - Moment of Pause.mp3
1998	1253	1981	1997	2012-11-30 05:07:24+00	0	\N	f9749d1f2a3de03c17e73d7667f27ebae8afd1d1f8a833a18fd594e0537b27c9	/home/extra/user/torrents/Homestuck Discography/The Felt/01 - Jade Dragon.mp3
2000	1253	1981	1999	2012-11-30 05:07:24+00	0	\N	42e65afa8837ef5f35d8d71e758050e4931bebaa4b08cc2f2148ab90aeb492fd	/home/extra/user/torrents/Homestuck Discography/The Felt/06 - Chartreuse Rewind.mp3
2002	1253	1981	2001	2012-11-30 05:07:25+00	0	\N	eefb8b0fff6b5dabdbd6de7ba7c28bc036742f6916698eb7ce310522865f4434	/home/extra/user/torrents/Homestuck Discography/The Felt/16 - English.mp3
2019	1253	2016	2018	2012-11-30 05:07:27+00	0	\N	0562a689648e54e4a5e7b0eb4e8eb6eb48a70a2584103771952e4b9c83922a95	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/07 - Assail.mp3
2004	1253	1981	2003	2012-11-30 05:07:25+00	0	\N	0fe392d8aa9d11f45c71238c577ad74504fb19e50890b806fb03ed88b73ebd9b	/home/extra/user/torrents/Homestuck Discography/The Felt/11 - Scratch.mp3
2006	1253	1981	2005	2012-11-30 05:07:25+00	0	\N	8b2f80a0211762e696e4e51574453799c6a902fab0c48f1433e76049568acbbf	/home/extra/user/torrents/Homestuck Discography/The Felt/03 - Rhapsody in Green.mp3
2037	1253	2016	2036	2012-11-30 05:07:31+00	0	\N	11e7761e7933cb75e84bbafb3dd0a266dff6db0617522a2464764013f47b824b	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/18 - Retrobution.mp3
2008	1253	1981	2007	2012-11-30 05:07:26+00	0	\N	63fd5d4ec4179c1c1760657f293ae147b55bd524c5da015409e561b7ccb551a3	/home/extra/user/torrents/Homestuck Discography/The Felt/15 - Eldritch.mp3
2021	1253	2016	2020	2012-11-30 05:07:27+00	0	\N	eea8182678ed2f03d2a65434a003384e78487f164ad0aca42a143a4939218788	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/12 - Jackknive.mp3
2010	1253	1981	2009	2012-11-30 05:07:26+00	0	\N	0cd4a668b63ed4fcba5f82210283be848150f0ae797ba0c28676007f9758bf06	/home/extra/user/torrents/Homestuck Discography/The Felt/09 - Trails.mp3
2012	1253	1981	2011	2012-11-30 05:07:26+00	0	\N	eaa4146d38d1048270158bd948edc4484c8543fd7ba279f09bebf81b97c20ff5	/home/extra/user/torrents/Homestuck Discography/The Felt/13 - Temporal Piano.mp3
2031	1253	2016	2030	2012-11-30 05:07:31+00	0	\N	2a33bab8fa8889f4bab547692878dc7855fd026e6ee13e2afceb6e62b3bcfa63	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/01 - Fanfare.mp3
2023	1253	2016	2022	2012-11-30 05:07:27+00	0	\N	5943aafbf736502f0f9bf75c9d16a877b1eeaab730f663bab251601313c9a110	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/22 - nsfasoft presents.mp3
2025	1253	2016	2024	2012-11-30 05:07:28+00	0	\N	0941beb0dfdef5269e567bf42dce4a3fb0146c66e2d725ff1d86aeba41bf7690	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/31 - Audio Commentary Featuring Robert J! Lake, Nick Smalley, Luke GFD Benjamins, and Erik Jit Scheele.mp3
2027	1253	2016	2026	2012-11-30 05:07:30+00	0	\N	3e5505c5bcfbf5b0f01edb9c62481219b05a9abf11fe9500d3a924de232b77a9	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/05 - Elf Shanty.mp3
2033	1253	2016	2032	2012-11-30 05:07:31+00	0	\N	445ae616ce7a2f2a1dcb11ed02258cdeebdf6635f83dbead2fcdee7880d015cb	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/30 - Softbit (Original GFD Please Shut the Fuckass Mix By Request Demo Version).mp3
2035	1253	2016	2034	2012-11-30 05:07:31+00	0	\N	b2e719321afe16d6e9602f55b04b79a45ffca994c3b896f11fde5eaf37c580bf	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/02 - Jailstuck (Intro).mp3
2039	1253	2016	2038	2012-11-30 05:07:31+00	0	\N	33c5130088d282cd778255f49064b96507f3d47cdc17261874d4133a0f495472	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/19 - Game Over.mp3
2045	1253	2016	2044	2012-11-30 05:07:32+00	0	\N	171c343118365b93c8f0a16880e556708917888386a8e8fe0fac4f16f5653422	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/25 - Dr. Squiddle.mp3
2043	1253	2016	2042	2012-11-30 05:07:32+00	0	\N	8f0df57ffb5c4740ed94ab1a7176483d0bb60cbf060463a26d3bd849217ddbe9	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/23 - A Common Occurance (Every Night, To Be Exact).mp3
2047	1253	2016	2046	2012-11-30 05:07:32+00	0	\N	06ca6ef6b05594b04a27a08a821ed9016c8a9893df2c3a103ab1da907dfba49f	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/24 - Useful or Otherwise.mp3
2049	1253	2016	2048	2012-11-30 05:07:32+00	0	\N	3ebad60fdba1a5630f88c656fb5d37bbc504aec278c31d19d7a4ea39ef04eefe	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/27 - Mechanic Panic.mp3
2051	1253	2016	2050	2012-11-30 05:07:32+00	0	\N	b0bbb096e20b68808bc710792772ddf1024e7f1ada23fb9618acb8edd8961e92	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/09 - Rising Water (Oh, Shit!).mp3
2055	1253	2016	2054	2012-11-30 05:07:33+00	0	\N	61b5f177b5ca4120cffd182a603479571b61dedacd1755f24ff81c7f72101c3a	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/13 - Intestinal Fortification.mp3
2094	1253	2079	2093	2012-11-30 05:07:39+00	0	\N	5b35cccb979fae772a065480d9f0af39e54e28e3801d39908a098eb79a03d259	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/16 - Blackest Heart.mp3
2057	1253	2016	2056	2012-11-30 05:07:33+00	0	\N	5eb73a2d36c7891234a1a0beb990d57ad3bf410adfe91fdb9113999d309cab85	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/04 - Logorg.mp3
2082	1253	2079	2081	2012-11-30 05:07:37+00	0	\N	56c63cbcbbbbc6c2d890be663904faa1cd8da51153af317fa95561a68c178ad2	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/01 - Frost.mp3
2059	1253	2016	2058	2012-11-30 05:07:33+00	0	\N	723d8447b91a5bb12c4d9d152d22f1dfd2fe760fa43baa99675edca5bc53a756	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/03 - Title Screen.mp3
2061	1253	2016	2060	2012-11-30 05:07:33+00	0	\N	78386a8c9f2a8d79f80726e658e99d0b2e6ff5eb19e28342d1a85284a0d2c29f	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/11 - Bars.mp3
2063	1253	2016	2062	2012-11-30 05:07:34+00	0	\N	d55402b58e4ed5ee59dc004a44dbac02bcf8cf8dbaff69dc9c69b1b0f035e59d	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/08 - Confrontation.mp3
2084	1253	2079	2083	2012-11-30 05:07:37+00	0	\N	c936c00cf6dd1debb9095360513352976ae91935ea68d6d70272c01575d6d739	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/06 - I Don't Want to Miss a Thing.mp3
2065	1253	2016	2064	2012-11-30 05:07:34+00	0	\N	efdbee3b2c7bad08f67fdd4428b6310b144c185aaeb1cb9415b1da624da36b75	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/26 - Distanced.mp3
2067	1253	2016	2066	2012-11-30 05:07:34+00	0	\N	322fff684a10c9a2c429831bb8c298557b4e8b76313b58d496394e44d1542d54	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/15 - Be the Other Guy.mp3
2106	1253	2079	2105	2012-11-30 05:07:43+00	0	\N	1979bd0468d73fc4829f51774f55d909c7cb9d5c5c417b0c890d86ed642d7a75	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/14 - Boy Skylark (Brief).mp3
2069	1253	2016	2068	2012-11-30 05:07:35+00	0	\N	1fba180f7a365e56c4f39dfbe8a1b07326cb0776ef39600f1940e9cbab8aa908	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/14 - Console Thunder.mp3
2086	1253	2079	2085	2012-11-30 05:07:37+00	0	\N	e8ed0c99a47030f053b7633cb7920cc2ed84a1b7713552c44686104cae188eb4	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/08 - Walk-Stab-Walk (R&E).mp3
2071	1253	2016	2070	2012-11-30 05:07:35+00	0	\N	61c7bf0f1759c5422312cbf3f26adbff3ae64884521700cba9ef177e8f621e1c	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/16 - Softbit.mp3
2073	1253	2016	2072	2012-11-30 05:07:36+00	0	\N	8ec7825e928c28635e380ba5a1117dc498aa1b0eda2d92a1ffb01a722cc15fcf	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/20 - Is This the End.mp3
2096	1253	2079	2095	2012-11-30 05:07:39+00	0	\N	edd8cfe370a89f24f2a6ed624c696f500f5692bce181cc14be9c3eec99d346d2	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/13 - Heir Transparent.mp3
2075	1253	2016	2074	2012-11-30 05:07:36+00	0	\N	07676df1f27644d9dbb8b716e72aa642e280f8fef56d619cf2b821b30e7097fc	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/21 - This is the End.mp3
2088	1253	2079	2087	2012-11-30 05:07:38+00	0	\N	b0c47a32d884f586019984584064d009beae4510d6af6e0e2f9fe99c62cedbf8	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/18 - Phrenic Phever.mp3
2077	1253	2016	2076	2012-11-30 05:07:36+00	0	\N	db77aed70c880afa06c45cf02117e56c42e15df8663c13bb106c3c93bfee6cac	/home/extra/user/torrents/Homestuck Discography/Jailbreak Vol. 1/28 - i told you about ladders.mp3
2080	1253	2079	2078	2012-11-30 05:07:36+00	0	\N	7444e9125e8dc5a980914af9a4b40a70734906c87fb9c9792057d793be842ea5	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/20 - A Tender Moment.mp3
2090	1253	2079	2089	2012-11-30 05:07:38+00	0	\N	bf2fe4f324c12163feef7da57d2ffce97957c3958124685d26ddb59b68d34241	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/12 - Horschestra.mp3
2102	1253	2079	2101	2012-11-30 05:07:41+00	0	\N	6859e5a7670e5293cc0b3f38f42456666c142f3659d96acac48c3dfc68032a92	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/17 - Nic Cage Song.mp3
2092	1253	2079	2091	2012-11-30 05:07:38+00	0	\N	53d2f66654f7f839a679a8bb7b85d4d2231e394065844688729e5bdc290861e1	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/02 - Courser.mp3
2098	1253	2079	2097	2012-11-30 05:07:39+00	0	\N	e29ae6389e93122c58ff6991de0dc9893f85a0eccc20bee96db4da1ecb4831b8	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/03 - Umbral Ultimatum.mp3
2100	1253	2079	2099	2012-11-30 05:07:40+00	0	\N	958e0ff441afd24ee62ab0e2ef9d1b327f3773c7eeef19abb109d39177f66752	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/21 - Crystalanthology.mp3
2104	1253	2079	2103	2012-11-30 05:07:42+00	0	\N	1907c921b76be338300729bd93ad99e2b212533eb37f3f15067d48f75921f1d1	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/07 - MeGaLoVania.mp3
2110	1253	2079	2109	2012-11-30 05:07:43+00	0	\N	d31f4cb279677fcd3108c50572025f1d3c7313c8d0fc56efbbc001419598996c	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/19 - 3 In The Morning (Pianokind).mp3
2108	1253	2079	2107	2012-11-30 05:07:43+00	0	\N	7ba472b7cffd337cf705280b3f1207928c2cccb664b03746f853ac866b157c07	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/10 - Elevatorstuck.mp3
2112	1253	2079	2111	2012-11-30 05:07:44+00	0	\N	44dad23acf57548ae60baaa7229813c70b76e68c72323887ff372d1e2b36919b	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/09 - Gaia Queen.mp3
2114	1253	2079	2113	2012-11-30 05:07:44+00	0	\N	569cd04c25902740b3ff1799f8d7f650bb132e142c2e4b9fc98b35f87e2fd04c	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/15 - Squidissension.mp3
2161	1253	2150	1294	2012-11-30 05:07:53+00	0	\N	9e419052ae0591f5a49e47370a1c99caf119af25c45b95dece2d2915c72d53df	/home/extra/user/torrents/Homestuck Discography/Medium/01 - Light.mp3
2116	1253	2079	2115	2012-11-30 05:07:44+00	0	\N	bf0cdc91e2dbf0b62b21a05a9caf8e39051af35ee1c3f678b9353bed9ca8cfe4	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/04 - GameBro (Original 1990 Mix).mp3
2132	1253	2121	2131	2012-11-30 05:07:48+00	0	\N	54f01e35bf7a4e3f8d39253d69522e8ce8a97a260c482aa3d26bb2e5b08d1c26	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 3/09 - Rediscover Fusion Remix.mp3
2118	1253	2079	2117	2012-11-30 05:07:45+00	0	\N	500cb9fc424da0ae2aa0dc74b88350b02ed003c5d31e7400130cabb808dc7b09	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/05 - Tribal Ebonpyre.mp3
2120	1253	2079	2119	2012-11-30 05:07:45+00	0	\N	09af4da524149f1d9edb494d30da11ea375813a0af7fa34c2be684e81ec2033f	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 6 - Heir Transparent/11 - Wacky Antics.mp3
2146	1253	2135	1604	2012-11-30 05:07:50+00	0	\N	797362e6d7aec1ba33dd232bf0b7b1772067d34c448e2e40313371ee93a846b8	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1/06 - Sburban Countdown.mp3
2122	1253	2121	1584	2012-11-30 05:07:45+00	0	\N	b88f7d8a002a83776e8654aeec26eb699338e322d37b558de5c50b0532ef8600	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 3/08 - Rediscover Fusion.mp3
2133	1253	2121	1600	2012-11-30 05:07:48+00	0	\N	74075819fc3f8dab305715d14686aa63f1b1fe1fb2f894ca8b4572073098c420	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 3/05 - Dissension (Remix).mp3
2123	1253	2121	1540	2012-11-30 05:07:46+00	0	\N	4924a204af1b367f06de5fe5705f0ac5fb0be23df57a58d4209d8ef26035567e	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 3/04 - Dissension (Original).mp3
2124	1253	2121	1550	2012-11-30 05:07:46+00	0	\N	9667f88873329f6ad0fce993851cb9a18c5d9925fc09920683b585a56da093d5	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 3/11 - Chorale for Jaspers.mp3
2142	1253	2135	1548	2012-11-30 05:07:49+00	0	\N	21fbe64ad001f4623d50d18478f0d173adb317df3c08b37df52fbca4380ca295	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1/09 - Nannaquin.mp3
2125	1253	2121	1602	2012-11-30 05:07:46+00	0	\N	fe06735a32a045127b045449fa47259588d086c33e623afe10f3fe7c1d096170	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 3/12 - Pony Chorale.mp3
2134	1253	2121	1542	2012-11-30 05:07:48+00	0	\N	d12d2d61c594c948867d42026dd88e2480f2d46785fb5a401cfc8e7529edae1b	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 3/06 - Ohgodwhat.mp3
2126	1253	2121	1564	2012-11-30 05:07:46+00	0	\N	9a1bacba28aa1140e63fc248b189640875d30b10eed2993db1dc167a136b354e	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 3/03 - Beatdown Round 2.mp3
2127	1253	2121	1574	2012-11-30 05:07:46+00	0	\N	f1e1b47a5096ac289aefb415aad128fbe5e7dc74289ec919f5242e3ed383ad5a	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 3/02 - Harleboss.mp3
2128	1253	2121	1594	2012-11-30 05:07:47+00	0	\N	5498aa59e8cff6d8233587ca3924f2cf1addb5c75a91f1f19e3825d13f379b97	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 3/01 - Beatdown (Strider Style).mp3
2136	1253	2135	1588	2012-11-30 05:07:48+00	0	\N	c18bda9a138ec2cf323dd0d58260d3b24326959e2c64e18f7335d739fea323bb	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1/08 - Showtime (Imp Strife Mix).mp3
2129	1253	2121	1572	2012-11-30 05:07:47+00	0	\N	dd81ee9e2bf6f4e44b20b808da1e9cb2d6bfc61b21ecea66a1e39ea44d478120	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 3/07 - Ohgodwhat Remix.mp3
2130	1253	2121	1576	2012-11-30 05:07:47+00	0	\N	72367c0e7cf4578c72b33129dbca0dd84bc68ed97f58d2365d34e8a0e2f0a2bc	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 3/10 - Explore Remix.mp3
2143	1253	2135	1560	2012-11-30 05:07:50+00	0	\N	d57b973293eb22a2ca71ef1d58e9dd5026b03d1c6d6a0124ddfd0bbc82246d9c	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1/05 - Aggrieve (Violin Refrain).mp3
2138	1253	2135	2137	2012-11-30 05:07:49+00	0	\N	2f42df148dbe984a0d4178594a2762fa27775bcbb6065acac65643d6d5cae906	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1/04 - Sburban Jungle (Brief Mix).mp3
2140	1253	2135	2139	2012-11-30 05:07:49+00	0	\N	85f37e3b5c79d47816c5eb969b44ef92b2c184843651d2928e61e8fdf6684f3f	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1/11 - Aggrieve (Violin Redux).mp3
2152	1253	2150	2081	2012-11-30 05:07:51+00	0	\N	b67dbccd57054f5602f49222d052f075a16e2790bfe5a6898471050cd133b636	/home/extra/user/torrents/Homestuck Discography/Medium/05 - Frost.mp3
2141	1253	2135	1538	2012-11-30 05:07:49+00	0	\N	cdaca9e9e9e00313cd87233576683b18e55faa66c9325d5ce1dccc196fb6d85c	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1/03 - Showtime (Original Mix).mp3
2144	1253	2135	1582	2012-11-30 05:07:50+00	0	\N	84a70e2c51a6837d72d87142bb70bf139a6ebfbd63468d2acec78e7da245033c	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1/01 - Showtime (Piano Refrain).mp3
2147	1253	2135	1598	2012-11-30 05:07:50+00	0	\N	2a79d75f01fb76510d5f7f41e237b90ea148db7ae744a4188faa2a1454043c48	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1/10 - Skies of Skaia.mp3
2145	1253	2135	1592	2012-11-30 05:07:50+00	0	\N	c4d2485549e6c60c33dc88ac7fdf1f324b908a0589eda38453cdb082719337df	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1/07 - Aggrieve.mp3
2151	1253	2150	2149	2012-11-30 05:07:51+00	0	\N	86abf621ff22e0f365f41ca90e2b0eb12dc7854e12b2db62ef807b880892dcba	/home/extra/user/torrents/Homestuck Discography/Medium/08 - Wind.mp3
2148	1253	2135	1596	2012-11-30 05:07:51+00	0	\N	c255d3938d8d5b99d0b0896ac2eff295a5ed38b80baaaba91be749ed9b408c62	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 1/02 - Harlequin.mp3
1445	1253	1254	1367	2012-11-30 05:06:00+00	0	\N	bc4c1cd41cd893d6d2cd0427af839e9a5e0d23bdd53f676c35db80336d277120	/home/extra/music/Homestuck/Homestuck Volume 5/39 Endless Climbing.mp3
2154	1253	2150	2153	2012-11-30 05:07:52+00	0	\N	b36499b4737f4a7649c506a30f6b849a3a10c5867f56289ccb11c9e6bbe01248	/home/extra/user/torrents/Homestuck Discography/Medium/07 - Heat.mp3
2156	1253	2150	2155	2012-11-30 05:07:52+00	0	\N	f292265a8aa9b99a759edc7e4dca2ff7c188bfd61ecfe54e4069945162f2e980	/home/extra/user/torrents/Homestuck Discography/Medium/04 - Frogs.mp3
2158	1253	2150	2157	2012-11-30 05:07:52+00	0	\N	8663c120dd49e16886410df3cdbedfe47041fa82467f9954b835bddbfcdf07db	/home/extra/user/torrents/Homestuck Discography/Medium/02 - Shade.mp3
2160	1253	2150	2159	2012-11-30 05:07:53+00	0	\N	289031f783e5f70e995c54881f7f3709e4450bb9498cca800fcc60edf86b4670	/home/extra/user/torrents/Homestuck Discography/Medium/06 - Clockwork.mp3
2163	1253	2150	2162	2012-11-30 05:07:53+00	0	\N	bd3b28c85f6a08527df7436917ff485c179c901865581596dc4847b5ca8a35e7	/home/extra/user/torrents/Homestuck Discography/Medium/03 - Rain.mp3
2188	1253	2165	2187	2012-11-30 05:07:59+00	0	\N	a1709d46e861cc319217babda1d21e7ad489300a083be2c0a5a6ea6d9c3a0b48	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/08 - Ante Matter.mp3
2166	1253	2165	2164	2012-11-30 05:07:55+00	0	\N	30ba92a29e6c404962485943ebb70e8690933cef7df332a4c11e018d019ff721	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/14 - Moonshine.mp3
2168	1253	2165	2167	2012-11-30 05:07:56+00	0	\N	8a0e929b112d6ee39c3ff5267eb8e3882a62d6dd71af6a0a0a4d7db0a4b71887	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/12 - Carbon Nadsat-Cuestick Genius.mp3
2215	1253	2204	2214	2012-11-30 05:08:04+00	0	\N	864dbd2021c255a07e69241949c0e2db1300bb43f60d3a990c14e6515846a3e3	/home/extra/user/torrents/Homestuck Discography/Mobius Trip and Hadron Kaleido/03 - Beta Version.mp3
2170	1253	2165	2169	2012-11-30 05:07:56+00	0	\N	24ca7d6d103fe24fedd20f85c4531b6ac664985f05f8d0da69c7ee6fca89c640	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/10 - Lunar Eclipse.mp3
2190	1253	2165	2189	2012-11-30 05:07:59+00	0	\N	fb47b338a02c057a06123a98ebae756534a1feb1f84e45d6627d5d60078d781a	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/13 - Ace of Trump.mp3
2172	1253	2165	2171	2012-11-30 05:07:57+00	0	\N	6317fd13825d2c3ba2a4ec1e71fc302ca8ac4fffa287c3ec52324af6a7b0888e	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/19 - Nightlife (Extended).mp3
2174	1253	2165	2173	2012-11-30 05:07:57+00	0	\N	40c7058517a3fe9a30f04cc8cf8e32766071d2463377e389d69004f2a26e0d64	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/16 - Joker's Wild.mp3
2202	1253	2165	2201	2012-11-30 05:08:01+00	0	\N	e108f075cca3effcbd93fe5fbaec2c483714b08849c58b6013498701e49234a0	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/15 - Tall, Dark and Loathsome.mp3
2176	1253	2165	2175	2012-11-30 05:07:57+00	0	\N	2b038f1ebf2ccc3de1b3b676a6131830bc297ccb305499d3c30b5a1256dfb945	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/02 - Blue Noir.mp3
2192	1253	2165	2191	2012-11-30 05:08:00+00	0	\N	466205ab7d580d35667c3e309d089749553e924dad6c9d1abff15b9b38134085	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/17 - Livin' It Up.mp3
2178	1253	2165	2177	2012-11-30 05:07:57+00	0	\N	73edc50e106bde3c4b817f0271c6dfce58a49019c320bcfe7957a76c7b0d4dd3	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/05 - Knives and Ivory.mp3
2180	1253	2165	2179	2012-11-30 05:07:58+00	0	\N	e029b03be49b22ac4fd26477ee60c2c672e2de127c232921b4418b9fe19f7fbc	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/11 - Hauntjam.mp3
2182	1253	2165	2181	2012-11-30 05:07:58+00	0	\N	11c49aefd5c4a4d34cda1363b7436421bb067995993babe8e06abfc0d814d4db	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/09 - The Ballad of Jack Noir.mp3
2194	1253	2165	2193	2012-11-30 05:08:00+00	0	\N	bccd5d8d467c37755553b4ebe2758919f2e751fc4a0af92b001023da4a98ff2f	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/06 - Liquid Negrocity.mp3
2184	1253	2165	2183	2012-11-30 05:07:58+00	0	\N	3f6c1bf54ef224744bca09bf5f08a3d9e27e32f7047274b0ccf02e8518deb4d8	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/07 - Hollow Suit.mp3
2186	1253	2165	2185	2012-11-30 05:07:59+00	0	\N	5c6c72bba8bc6b8a120680d6292b0c7a97f7d13364f81e77e06edded38e19e06	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/03 - Dead Shuffle.mp3
2211	1253	2204	2210	2012-11-30 05:08:03+00	0	\N	b2ea6d1f23feac8d213b808de46f91139078b3d965165a3b33ae4adf8cb93372	/home/extra/user/torrents/Homestuck Discography/Mobius Trip and Hadron Kaleido/07 - Chain of Prospit.mp3
2205	1253	2204	2203	2012-11-30 05:08:01+00	0	\N	d4617301c31b0a9a8487535095cf24ad1e67f65a98d9121427caf2a050f8697a	/home/extra/user/torrents/Homestuck Discography/Mobius Trip and Hadron Kaleido/08 - Pumpkin Tide.mp3
2196	1253	2165	2195	2012-11-30 05:08:00+00	0	\N	ecd94f98fc0d1c57e12c33bd09fe98ebf693a30daf8bcc991a2ecd9a9fefdb3a	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/04 - Hearts Flush.mp3
2198	1253	2165	2197	2012-11-30 05:08:00+00	0	\N	59b5445310086fb78806f4e0e737e0f2fc5d8b36c53fdda0a3b37a1250ebe32b	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/01 - Three in the Morning.mp3
2200	1253	2165	2199	2012-11-30 05:08:01+00	0	\N	b69fadde8d70639a7bcbb65a5456ffa5e62136c89c6041d58e89ffb5942550d1	/home/extra/user/torrents/Homestuck Discography/Midnight Crew - Drawing Dead/18 - Hauntjelly.mp3
2207	1253	2204	2206	2012-11-30 05:08:02+00	0	\N	fe7d423a3ceb223caaf2448d7162b2627ebecf555ea41571ca26ee95aa3398e3	/home/extra/user/torrents/Homestuck Discography/Mobius Trip and Hadron Kaleido/02 - Dawn of Man.mp3
2209	1253	2204	2208	2012-11-30 05:08:02+00	0	\N	e5583d5c40ff97109867fbd624e0bfbf6fba9ebd1b861353eef7463c44709cf3	/home/extra/user/torrents/Homestuck Discography/Mobius Trip and Hadron Kaleido/06 - Lies with the Sea.mp3
2213	1253	2204	2212	2012-11-30 05:08:04+00	0	\N	48fce9e61d7e30a8b89a14471f4d326bd10f7d3bcaddbf4bf4582808bc8460ff	/home/extra/user/torrents/Homestuck Discography/Mobius Trip and Hadron Kaleido/04 - No Release.mp3
1448	1253	1254	1347	2012-11-30 05:06:01+00	0	\N	739eb3558f70c7d13adb8a12d566151d37f4779cc148eec9dcb4ded9a1a9c6c1	/home/extra/music/Homestuck/Homestuck Volume 5/46 Pyrocumulus (Kickstart).mp3
2217	1253	2204	2216	2012-11-30 05:08:04+00	0	\N	6295b195f9a6520ae79fc9737362b1de2714bc821739ef3b191c979efdb0c9b2	/home/extra/user/torrents/Homestuck Discography/Mobius Trip and Hadron Kaleido/01 - Forever.mp3
2219	1253	2204	2218	2012-11-30 05:08:05+00	0	\N	b39a6916fb775b8c9eb9bb3e0d155c6c65e491ca80967f61661b798cdf7b508d	/home/extra/user/torrents/Homestuck Discography/Mobius Trip and Hadron Kaleido/09 - The Deeper You Go.mp3
2221	1253	2204	2220	2012-11-30 05:08:05+00	0	\N	c568f7738c8ed9bda2bb1f7c7a64cc41fde63facf4bc2ab88043241381c24950	/home/extra/user/torrents/Homestuck Discography/Mobius Trip and Hadron Kaleido/05 - Fly.mp3
2224	1253	2223	2222	2012-11-30 05:08:06+00	0	\N	9645467c0a983a4cbbea6c462e83d0964cd17f16e85f0ef90f03cf07f152a682	/home/extra/user/torrents/Homestuck Discography/Squiddles!/09 - Lazybones.mp3
2226	1253	2223	2225	2012-11-30 05:08:06+00	0	\N	696413cd73930aabd7a2b8b3e3972a7b577c1911de59d97b494c0091e19b3d9c	/home/extra/user/torrents/Homestuck Discography/Squiddles!/17 - Plumbthroat Gives Chase.mp3
2228	1253	2223	2227	2012-11-30 05:08:06+00	0	\N	36b59415e30acf7ff0afd04063676ec110ecd71525151ffa0edbe61928ed1e39	/home/extra/user/torrents/Homestuck Discography/Squiddles!/04 - Squiddle March.mp3
2252	1253	2223	2251	2012-11-30 05:08:10+00	0	\N	ca31ce97378265b7f1e02da7e42b8cdd2a27f31548fc68a04972091a2d28ccbe	/home/extra/user/torrents/Homestuck Discography/Squiddles!/01 - Squiddles!.mp3
2230	1253	2223	2229	2012-11-30 05:08:06+00	0	\N	2489202659e0498e47bf15046b7bada0bf179b472ae949f9f68c5c4844f89656	/home/extra/user/torrents/Homestuck Discography/Squiddles!/08 - Friendship is Paramount.mp3
2232	1253	2223	2231	2012-11-30 05:08:07+00	0	\N	5ccf686f587e5cc21db1644b7887f4b1e1d6e50c69046802752357f14b60dae1	/home/extra/user/torrents/Homestuck Discography/Squiddles!/13 - Squiddle Samba.mp3
2273	1253	2269	1606	2012-11-30 05:08:13+00	0	\N	c38de4755eb0b1131804908a468d484e8186f6042b3faa15d295995e3daa2353	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 2/03 - Upward Movement (Dave Owns).mp3
2234	1253	2223	2233	2012-11-30 05:08:07+00	0	\N	5907363b62e2595b46bbc7434a01ee787ccb5332ef4cdc87c5fbb300120f55da	/home/extra/user/torrents/Homestuck Discography/Squiddles!/16 - Catchyegrabber (Skipper Plumbthroat's Song).mp3
2254	1253	2223	2253	2012-11-30 05:08:10+00	0	\N	ec8d736b670427b53d76059eeddbf2d7c1c9b7aab7f5cf306cd87feef63a0f88	/home/extra/user/torrents/Homestuck Discography/Squiddles!/21 - Ocean Stars.mp3
2236	1253	2223	2235	2012-11-30 05:08:07+00	0	\N	09dff9840db8928575442826873e121486d1b86425895de8532a9b522634a274	/home/extra/user/torrents/Homestuck Discography/Squiddles!/10 - Tentacles.mp3
2238	1253	2223	2237	2012-11-30 05:08:08+00	0	\N	93ecb92e77b495887b616106af9dc05e313b3e1e21c38a487caad92f46246683	/home/extra/user/torrents/Homestuck Discography/Squiddles!/11 - Squiddles Happytime Fun Go!.mp3
2266	1253	2223	2265	2012-11-30 05:08:12+00	0	\N	74e1fd5d548e36172bb357315fabd756ff20a97fd09b449fdc75222806c2fe23	/home/extra/user/torrents/Homestuck Discography/Squiddles!/07 - Squiddles Campfire.mp3
2240	1253	2223	2239	2012-11-30 05:08:08+00	0	\N	74e1ec268620c7efa573ecfc3886291a67868b80d808eec9bc82c0ced85fd809	/home/extra/user/torrents/Homestuck Discography/Squiddles!/03 - Squiddle Parade.mp3
2256	1253	2223	2255	2012-11-30 05:08:10+00	0	\N	93908f95e16be94330f3695d1b1afb323233ed5952803b129b7cecd8d1f75c55	/home/extra/user/torrents/Homestuck Discography/Squiddles!/18 - Squiddles the Movie Trailer - The Day the Unicorns Couldn't Play.mp3
2242	1253	2223	2241	2012-11-30 05:08:08+00	0	\N	e955d9da734a268eda392d81998ed71d621180d962a1be00993ca2f527adb6f0	/home/extra/user/torrents/Homestuck Discography/Squiddles!/23 - Bonus Track - Friendship Aneurysm.mp3
2244	1253	2223	2243	2012-11-30 05:08:08+00	0	\N	b1673d8a63d8e36bca4b7d63c9e650371d410247980918a7c1825c919e99ab30	/home/extra/user/torrents/Homestuck Discography/Squiddles!/20 - Mister Bowman Tells You About the Squiddles.mp3
2246	1253	2223	2245	2012-11-30 05:08:08+00	0	\N	3f35382560ae2289767136e829393eb3f703005403eec2022420687d7965703f	/home/extra/user/torrents/Homestuck Discography/Squiddles!/22 - Let the Squiddles Sleep (End Theme).mp3
2258	1253	2223	2257	2012-11-30 05:08:10+00	0	\N	cde8ef8587ba5f089061009a7a0baad91b18badb35abd0b68cc14db2f33f4762	/home/extra/user/torrents/Homestuck Discography/Squiddles!/05 - Tangled Waltz.mp3
2248	1253	2223	2247	2012-11-30 05:08:09+00	0	\N	3616b87d82b42d7c77c4f47f1dbd60c89f081bd9a8d9ea08e665e70cf26bcfb2	/home/extra/user/torrents/Homestuck Discography/Squiddles!/14 - Squiddles in Paradise.mp3
2250	1253	2223	2249	2012-11-30 05:08:09+00	0	\N	1655b72ebd37b278427d24faae1b42f28c192aed6b6edac9171a7dfcd2acd870	/home/extra/user/torrents/Homestuck Discography/Squiddles!/06 - Sun-Speckled Squiddly Afternoon.mp3
2268	1253	2223	2267	2012-11-30 05:08:12+00	0	\N	50aac091b09a8dea8c57861d5dc8f7fe8bcfa2ab3194d6e68d2bcbd21749fd78	/home/extra/user/torrents/Homestuck Discography/Squiddles!/19 - Carefree Princess Berryboo.mp3
2260	1253	2223	2259	2012-11-30 05:08:11+00	0	\N	bcceaf34b2770245ed24b391f77f7943460b72bd1d98688e187c8732d415622d	/home/extra/user/torrents/Homestuck Discography/Squiddles!/12 - The Sound of Pure Squid Giggles.mp3
2262	1253	2223	2261	2012-11-30 05:08:11+00	0	\N	73ecbbf18628868a8930563a4d2f2c207a7109c27aec4e967ee0d6ddf9df82ed	/home/extra/user/torrents/Homestuck Discography/Squiddles!/02 - Rainbow Valley.mp3
2277	1253	2269	1546	2012-11-30 05:08:14+00	0	\N	498bfab842047794dd73fb7f0d9b12dd26fc47a4d1cdb850055099a1f9ba4a0d	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 2/10 - Verdancy (Bassline).mp3
2264	1253	2223	2263	2012-11-30 05:08:12+00	0	\N	bd99978a81b874e10acff83e978b8a57219a56b43898a0a7f7fd5b874483d74f	/home/extra/user/torrents/Homestuck Discography/Squiddles!/15 - Squiddidle!.mp3
2270	1253	2269	1544	2012-11-30 05:08:12+00	0	\N	c8308dceb4ed42292cc87646c20c4ce110cfa8e87c6d9787d7947a8808db658e	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 2/08 - Showtime Remix.mp3
2274	1253	2269	1552	2012-11-30 05:08:13+00	0	\N	5c840775f7c1bf7e2ebac9ac59bf38095ee893c6ef7f3f54ead5357b332304fb	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 2/01 - Harlequin (Rock Version).mp3
2272	1253	2269	2271	2012-11-30 05:08:13+00	0	\N	5d54a4a2fd430bd5de09506feb6b4ab9e4f61113a7cc513ba27667426b7e9147	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 2/02 - Skaian Dreams (Remix).mp3
2276	1253	2269	1580	2012-11-30 05:08:14+00	0	\N	694bea8e3196e217edc52c7f407733fc2a614d41642025423f709f33f2439f9b	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 2/09 - Aggrieve Remix.mp3
2275	1253	2269	1570	2012-11-30 05:08:14+00	0	\N	b19fdfd53a5b98b07512821be16ed42e672bc10f5c6d7cd6028c131a6a424e41	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 2/04 - Vagabounce.mp3
2279	1253	2269	2278	2012-11-30 05:08:14+00	0	\N	0368978b191c0568fc96895974e15ca9353846cfa833dacf14bcc74316040bcb	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 2/11 - Kinetic Verdancy.mp3
2281	1253	2269	2280	2012-11-30 05:08:15+00	0	\N	5d030fb54f007f8809e843472a157e918497f3a0bc22933a3406b1aa527299bd	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 2/06 - Guardian.mp3
2283	1253	2269	2282	2012-11-30 05:08:15+00	0	\N	274a8e8bd4b46e02335504f48f798cd5d58226462d973cfb787e75f5b6553a0b	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 2/07 - Nightlife.mp3
1042465	1042464	\N	1042463	2012-11-30 05:57:34+00	0	\N	61012b1f985ec9241934582721cb997c9c5d4c7ae73959a8f3761aa1e0abc2fe	/home/extra/music/pandora/AOAO(royal mix).mp3
1042468	1042467	\N	1042466	2012-11-30 05:57:34+00	0	\N	c7fe9649e869b0258fffc14d76afa022e098f476ff543bd9c318b81672806870	/home/extra/music/pandora/Ben Bernanke.mp3
2284	1253	2269	1590	2012-11-30 05:08:15+00	0	\N	2131977a2f4f788bb7a98e2cce6275f73982023446b05a553d4dd04583d8991e	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 2/05 - Explore.mp3
2337	1253	2286	2336	2012-11-30 05:08:25+00	0	\N	3afef6573bd53d180633a04effa62a68079f15842b2a4f47316c9701f2a40ac2	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/26 - Frostbite.mp3
2287	1253	2286	2285	2012-11-30 05:08:16+00	0	\N	0e9ae85e83fced2bd123243893e1e56c423df496dae8ea693b7ea6416b9bd5fc	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/19 - Pyrocumulus (Sicknasty).mp3
2311	1253	2286	2310	2012-11-30 05:08:21+00	0	\N	cb6035ed99b8fcf83929f7a0badf1ba0b7e978fec1470044cb12a58ea5e3a9b1	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/08 - Ocean Stars Falling.mp3
2289	1253	2286	2288	2012-11-30 05:08:16+00	0	\N	9e7f0f3e9b860c3ade07528dbee9493fd2548934dba2b49e1d79df71f2159740	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/03 - Flare.mp3
2291	1253	2286	2290	2012-11-30 05:08:16+00	0	\N	86bf8c72e61ef3a460c472a7fbb80e44b84308db9b8ef3efec0e36ddc27734b6	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/02 - Do You Remem8er Me.mp3
2325	1253	2286	2324	2012-11-30 05:08:23+00	0	\N	c26ab909a55ebe6e9e122c23fbed138c6504ed721bc66707eb0c6e5a87770255	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/13 - Terraform.mp3
2293	1253	2286	2292	2012-11-30 05:08:17+00	0	\N	7939cd8509c70e8147e833845cd01920ae0e4b11a6f0909d468fa7c96150f954	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/12 - Frog Hunt.mp3
2313	1253	2286	2312	2012-11-30 05:08:21+00	0	\N	8526db604827bac3becea9dfdf8944743a699ae2026411bfb74cfb01ed3836e6	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/06 - Frog Forager.mp3
2295	1253	2286	2294	2012-11-30 05:08:17+00	0	\N	ff1d1604126b3c83f25b1e45af94c880e8d13a5befc94a9dca7574e545e22009	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/40 - Black Hole - Green Sun.mp3
2297	1253	2286	2296	2012-11-30 05:08:18+00	0	\N	a8db9732001dcf5c922bd6b9c0d255a525c8204b47149a2768f44696a78ef40f	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/14 - Unite Synchronization.mp3
2299	1253	2286	2298	2012-11-30 05:08:18+00	0	\N	993e71f70a7cb4f3640287b6931ae9a61dcc71f8b84f610390f04d337557bcf0	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/01 - Calamity.mp3
2315	1253	2286	2314	2012-11-30 05:08:21+00	0	\N	2e3688a77f5e5ce4a2088d83261beccb3dd9e2eb4a77099748f796fabe3c9f75	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/05 - Serenade.mp3
2301	1253	2286	2300	2012-11-30 05:08:18+00	0	\N	e88027630c12c53b9b87ac2bd42a076a2b7cd5af2073a673dcac0f62d11ece5f	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/27 - The Lost Child.mp3
2303	1253	2286	2302	2012-11-30 05:08:18+00	0	\N	6ac6e8acb05a00b07da48a7ea2bab55e8226170f5a8706bfc1a067dcc972e58e	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/11 - Airtime.mp3
2333	1253	2286	2332	2012-11-30 05:08:24+00	0	\N	9a094b1853d1140a467bd22f61d0d74bab253d7d4c001e3d4b3789ba1262571e	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/34 - Judgment Day.mp3
2305	1253	2286	2304	2012-11-30 05:08:19+00	0	\N	42f578793f5102515eaa4ef40a013dc96fb95f8a58e325784478821f2fd06c99	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/36 - Cascade.mp3
2317	1253	2286	2316	2012-11-30 05:08:22+00	0	\N	48e2547a64871bbb8266a19f4e3523cd43c7469d33000921ca4f3ec06fbb2312	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/29 - Hussie Hunt.mp3
2307	1253	2286	2306	2012-11-30 05:08:20+00	0	\N	dcf8f1453bef8a3595dbaab7e4230197805dc337fd4fbaffcc583dc091e48841	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/35 - Lotus (Bloom).mp3
2309	1253	2286	2308	2012-11-30 05:08:20+00	0	\N	5974f150d25811a2c5618f7749bd5dbbbfe7e4f4caa650b7e645f271791ca9ea	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/28 - Questant's Lament.mp3
2327	1253	2286	2326	2012-11-30 05:08:23+00	0	\N	cee3adbb9707ce91e06ea33eaebe6aff4dd04d674e5be980f62cc7ef0ce5a444	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/41 - Carefree Action.mp3
2319	1253	2286	2318	2012-11-30 05:08:22+00	0	\N	61b1d3fc45df110a17c4d4e020d7cba672249278d903ec88a7daaf38f862828a	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/38 - How Do I Live (D8 Night Version).mp3
2321	1253	2286	2320	2012-11-30 05:08:22+00	0	\N	e371c8fdf6ffdaac2a0b9de9e59a433a3fcaa68c61b43afe3e95389687e934c4	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/37 - I'm a Member of the Midnight Crew (Acapella).mp3
2323	1253	2286	2322	2012-11-30 05:08:22+00	0	\N	8ec4c1ad734eb1cef60336b76e0f1f936f7c9d7ac30be9e830e65bfcc02bba40	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/22 - Gust of Heir.mp3
2329	1253	2286	2328	2012-11-30 05:08:23+00	0	\N	b3053feabc4d6804c023ccae6928150f8f02d908d2455821626c3e96381c2890	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/17 - Scourge Sisters.mp3
2331	1253	2286	2330	2012-11-30 05:08:24+00	0	\N	908b768a46a90c171042a0c2a48f69e8d3b4978c09d88a94e343b382c81d7595	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/25 - Bargaining with the Beast.mp3
2335	1253	2286	2334	2012-11-30 05:08:25+00	0	\N	06041859febe561dbb41f7b9b5daa95f26fa14d29ac8ae2ef5905a23890a6d5a	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/31 - Drift into the Sun.mp3
2341	1253	2286	2340	2012-11-30 05:08:25+00	0	\N	007dededb50c624a3f8a9e31866e6c49338885652f77bfbda4d2ddd1069f8006	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/30 - Havoc.mp3
2339	1253	2286	2338	2012-11-30 05:08:25+00	0	\N	271ffc17fe3413f8f493d1f10c49b02088770d23fee62e4eafd579062cb442a7	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/10 - Davesprite.mp3
2343	1253	2286	2342	2012-11-30 05:08:26+00	0	\N	eac8de59786c18aceb4511da6050b2ec86ede058643f7501a4dcd27354216147	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/09 - Escape Pod.mp3
2345	1253	2286	2344	2012-11-30 05:08:26+00	0	\N	7b8d3471217dab825483da17b1358be7d8108df27a6fb40056a984721b17ea3c	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/32 - Infinity Mechanism.mp3
2347	1253	2286	2346	2012-11-30 05:08:26+00	0	\N	0e1ba62b2d31598c1a59dd7f1488586651fdecccc61538b4f2c4d1da8f733df9	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/07 - Love You (Feferi's Theme).mp3
1042471	1042470	\N	1042469	2012-11-30 05:57:34+00	0	\N	4ad6ce79a53c4de8ccc3f87c2462bdccd8528b7ded902a3160bbfa66b609ae9a	/home/extra/music/pandora/Knife Fight.mp3
2349	1253	2286	2348	2012-11-30 05:08:27+00	0	\N	7973539997d5e98e3aa5b039d217f3b3c19e9d65b23a9b37052ba9d9be8b41c4	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/20 - Kingside Castle.mp3
2375	2371	2372	2374	2012-11-30 05:08:30+00	0	\N	a170b3757aecf30152241a26936570dba20102d21917b579ea18f08d716d070e	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/06 - At The Sign Of The Prancing Pony.mp3
2351	1253	2286	2350	2012-11-30 05:08:27+00	0	\N	687889b8cc39b0229f772088aed0278b710bcca5bc0b1ff72b3424c66619a75c	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/39 - Cascade (Beta).mp3
2353	1253	2286	2352	2012-11-30 05:08:27+00	0	\N	3d2fbd9cb7aea638bd64a8d5bfb0212bc6be409425ef11d23f11abccfa4c23d4	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/16 - Galaxy Hearts.mp3
2393	2371	2372	2392	2012-11-30 05:08:33+00	0	\N	055cc9b0ba714a844aa7752352de2c577fad6dedb92dd51df193d9b89064eb1b	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/10 - The Council Of Elrond.mp3
2355	1253	2286	2354	2012-11-30 05:08:28+00	0	\N	4ce55b9f814112f74c44c7b8f8ea7bb0a09250726185848352390f315879089b	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/23 - Afraid of the Darko.mp3
2377	2371	2372	2376	2012-11-30 05:08:31+00	0	\N	958c5fa81afc4a4562a4c808d074d4a2a9669cbcfbdf5cece087008294d06782	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/14 - Lothlorien.mp3
2357	1253	2286	2356	2012-11-30 05:08:28+00	0	\N	911ec8fe7fa9215a4104c7f62d1485868b10d393452acbef25ee2e139c3df0a8	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/18 - Arcade Thunder.mp3
2359	1253	2286	2358	2012-11-30 05:08:28+00	0	\N	65d484db971fa4fc19f761dba1d1d46f9a25c0cf1da5239bf4524615db275732	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/21 - Temporary.mp3
2387	2371	2372	2386	2012-11-30 05:08:32+00	0	\N	500923ab6e15f440d0f586aab3c8097a4bb5c3a222532b9d885ad9fd058d4c8d	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/15 - The Great River.mp3
2361	1253	2286	2360	2012-11-30 05:08:29+00	0	\N	4e775218ec66446a9595ba3c8d7a6b579baefc45042cfa7c93be8740174ca562	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/24 - Even in Death (T'Morra's Belly Mix).mp3
2379	2371	2372	2378	2012-11-30 05:08:31+00	0	\N	2e6765f3c26d9b088e0b0133e059c08266a0528f3690a1c775f559aaa1b5c863	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/03 - The Shadow Of The Past.mp3
2363	1253	2286	2362	2012-11-30 05:08:29+00	0	\N	fbd28ee2b55976e25d9bb26ddabd4612581c49fe4c067593b36067c189644b3e	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/33 - Revered Return.mp3
2365	1253	2286	2364	2012-11-30 05:08:29+00	0	\N	27106335ffdad916ba00c0e4c8815f81834f43f1bb59ef9dacbb427c66684a92	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/42 - null.mp3
2367	1253	2286	2366	2012-11-30 05:08:29+00	0	\N	ded943dcdc20eea9c56b13abc735a61f12227e1ffa85afd39adbef9f612a58c8	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/15 - Homefree.mp3
2381	2371	2372	2380	2012-11-30 05:08:31+00	0	\N	f42a8cc20e2d90764f48adf5aa44740f5c4dcb44bcd13707586a6497f5886c9f	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/08 - Flight To The Ford.mp3
2369	1253	2286	2368	2012-11-30 05:08:30+00	0	\N	6041c909812699c4f037d574574ec5ddd10044b64d0a372ee5bf70e8fe683044	/home/extra/user/torrents/Homestuck Discography/Homestuck Vol. 8/04 - Galactic Cancer.mp3
2373	2371	2372	2370	2012-11-30 05:08:30+00	0	\N	5809113d5aff67e11c70d9a12facaa71f9b39d2ef897b23819413b76c76416d1	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/16 - Amon Hen.mp3
2389	2371	2372	2388	2012-11-30 05:08:32+00	0	\N	7b895fa1f08bed1efe301839dae62b2a277719c81826902fae685996e93c7ab0	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/17 - The Breaking Of The Fellowship.mp3
2383	2371	2372	2382	2012-11-30 05:08:32+00	0	\N	8b97d1b7dea25471bedd476dafd232fd70540c2d5404beed6c37a894ab8299d3	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/13 - The Bridge Of Khazad Dum.mp3
2385	2371	2372	2384	2012-11-30 05:08:32+00	0	\N	ffeff72e1db17b279dbe11df0ea8895ddb987f8ade22c9cd711f5ea0996b0a8b	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/18 - May It Be.mp3
2397	2371	2372	2396	2012-11-30 05:08:34+00	0	\N	f22afdf2c40c93fa0aa194ea5c93e0fbe2bffa0ae035c98ab2c3edba992bc67c	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/11 - The Ring Goes South.mp3
2391	2371	2372	2390	2012-11-30 05:08:33+00	0	\N	1f26329c186b2eeaf71a83a1813272a42dae4d29c40a4bf2e51128214d6ef3da	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/12 - A Journey In The Dark.mp3
2395	2371	2372	2394	2012-11-30 05:08:34+00	0	\N	1098df342be59a1a2fd0683d4bddcdae9b31e436a18e8285732b9b1955cb2350	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/01 - The Prophecy.mp3
2399	2371	2372	2398	2012-11-30 05:08:34+00	0	\N	37fba8d8b3da5e5c479ae52244fed10639ca095aa00699814dd0e66299b37499	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/05 - The Black Rider.mp3
2401	2371	2372	2400	2012-11-30 05:08:35+00	0	\N	6e08ffa4c866ad5024aeb4630c85003302dda3bad0320069e0959eaa14bf5cda	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/09 - Many Meetings.mp3
2403	2371	2372	2402	2012-11-30 05:08:35+00	0	\N	fca9f55756b4b6d4631d022861d0745152fa5ebb551896943b387b7b26fc47ad	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/07 - A Knife In The Dark.mp3
1042473	\N	\N	1042472	2012-11-30 05:57:34+00	0	\N	32f590180662ea82f56d63fce46e505050e3bde81c19cf05e94288fc91bb7d4e	/home/extra/music/pandora/SegaSonictheHedgehogSonicElectronic.mp3
1450	1253	1254	1423	2012-11-30 05:06:01+00	0	\N	78d84739a89cb5dc19c08a532f96a888723157b77ed17031d90d315f5d06406c	/home/extra/music/Homestuck/Homestuck Volume 5/55 Ecstasy.mp3
2405	2371	2372	2404	2012-11-30 05:08:35+00	0	\N	cd9567fadf809ec6435ea7e5a97d475661738a0ed61e6658ea3ce0141427e483	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/02 - Concerning Hobbits.mp3
2426	2371	2409	2425	2012-11-30 05:08:39+00	0	\N	fde2de1c3c4c2bf08045a99ebbabab97dde1f21b3f353982f183e17c8046f628	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/03 - Minas Tirith (feat. Ben Del Maestro).mp3
2407	2371	2372	2406	2012-11-30 05:08:36+00	0	\N	7a87c33f3f356a9d8ca436f63fc931ad0e8697b6f0a791587966161c23b55f02	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/1_The_Fellowship_of_the_Ring/04 - The Treason Of Isengard.mp3
2410	2371	2409	2408	2012-11-30 05:08:36+00	0	\N	5e7294a63a2be081004d0f7dbf72a296158b4085b8ee431ac423d10bd98911d8	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/13 - The Fields of the Pelennor.mp3
2444	2371	2409	2443	2012-11-30 05:08:42+00	0	\N	98a14aee1229a668b43673d3f0b85965bc827a0aac848d137ee306f26cfd6dba	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/08 - Twilight and Shadow (feat. Renee Fleming).mp3
2412	2371	2409	2411	2012-11-30 05:08:36+00	0	\N	e27d4c528132d8c0dbf7fcb2d3560d67eed01cadc55392e7e2629099d3590053	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/07 - The Ride of the Rohirrim.mp3
2428	2371	2409	2427	2012-11-30 05:08:39+00	0	\N	df84199f8ab45475422590c8f1f40f86136f07b6d3e6e6dbd19e61dce0edece0	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/16 - The End of All Things (feat. Renee Fleming).mp3
2414	2371	2409	2413	2012-11-30 05:08:37+00	0	\N	153737fa089def89722d6481c5c804f36be7035d61c59dc12bb861ac5ee8a72c	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/09 - Cirith Ungol.mp3
2416	2371	2409	2415	2012-11-30 05:08:37+00	0	\N	fa1dd4a294da5e63da58b02000dc89ec1cc5f92794ce340e179ff2fb191de1d0	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/12 - Ash and Smoke.mp3
2438	2371	2409	2437	2012-11-30 05:08:41+00	0	\N	5ba82f5791d61895c98fb41d14ed3a16fe4d436de97c8eb58a6c5e5bf9a63bdf	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/01 - A Storm Is Coming.mp3
2418	2371	2409	2417	2012-11-30 05:08:37+00	0	\N	c9e08ba7d7713af194793fb4de6691e8994989b464d4106c18c5bf8a916d32b7	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/06 - Minas Morgul.mp3
2430	2371	2409	2429	2012-11-30 05:08:39+00	0	\N	0e483054492f0ac0176b23841ddaf2ba98294f803bd3db6e6f813f47ee1e516e	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/18 - The Grey Havens (feat. Sir James Galway).mp3
2420	2371	2409	2419	2012-11-30 05:08:37+00	0	\N	1af29fa93dc1189f6351e17fda49df82d19c91634b19f843b14d15c8bca4971b	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/17 - The Return of the King (feat. Sir James Galway, Viggo Mortensen & Renee Fleming).mp3
2422	2371	2409	2421	2012-11-30 05:08:38+00	0	\N	a69963be9743970666180a335e87d39d78b7fe2b94c867d195f2a982dac8b098	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/15 - The Black Gate Opens (feat. Sir James Galway).mp3
2424	2371	2409	2423	2012-11-30 05:08:38+00	0	\N	e59232b241bdc065fcced535fbc2b1a2a08c680d956e8f10710d4bef8d1b7fa5	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/19 - Into the West (feat. Annie Lennox).mp3
2432	2371	2409	2431	2012-11-30 05:08:40+00	0	\N	3ca3dd92ac8a46a60f26cbd9902b2a9d554ef0ba4ba2d40238d6fa8d0edb91fd	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/04 - The White Tree.mp3
2440	2371	2409	2439	2012-11-30 05:08:41+00	0	\N	0fdeaca4bbe7de4c280d062a97c4d177eba0f6fc0988c4cb4772e3a10d858d61	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/11 - Shelob's Lair.mp3
2434	2371	2409	2433	2012-11-30 05:08:40+00	0	\N	7e9134ba9ff72828f6670641b2c87382c3816e72311692a07100d6af6a5641a0	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/10 - Anduril.mp3
2436	2371	2409	2435	2012-11-30 05:08:40+00	0	\N	36fc0452eaf8c9952bd2d5c2fbf0a9413bc869e11534881a4e7aec9699d07ed7	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/02 - Hope and Memory.mp3
2451	2371	2448	2450	2012-11-30 05:08:42+00	0	\N	0182a2b963cf28a7943c01335533831f5fa2f91679db10d23b0f79bfcb07e288	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/15 - The Hornburg.mp3
2442	2371	2409	2441	2012-11-30 05:08:41+00	0	\N	ee7e52c8010d11515ffc4c30abd91a78224990fd3be613ee1df9fcb8bc2b36d9	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/14 - Hope Fails.mp3
2449	2371	2448	2447	2012-11-30 05:08:42+00	0	\N	a53b9bf9435771e99e6f4c300202ebd16ba3d955bd167149e2bed57ef56f5cab	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/20 - Farewell to Lorien (feat. Hilary Summers).mp3
2446	2371	2409	2445	2012-11-30 05:08:42+00	0	\N	29eb6e475d9262ddbf24f1bf94d0e038e6ffea35e7c065b8a7dbdd57a043c3a4	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/3_The_Return_of_the_King/05 - The Steward of Gondor (feat. Billy Boyd).mp3
2453	2371	2448	2452	2012-11-30 05:08:43+00	0	\N	17acecc9aab538e733d2c2b76644ff5941017f1ca1b093b528ace3d8a35dec95	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/07 - The Black Gate is Closed.mp3
2455	2371	2448	2454	2012-11-30 05:08:43+00	0	\N	3382d0c96883b23d51d59be17a93a5a00264c0b9cd4b41923c15cc9792c74da3	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/08 - Evenstar (feat. Isabel Bayrakdarian).mp3
1452	1253	1254	1435	2012-11-30 05:06:02+00	0	\N	0c2b9cfaa9002b34149dfc855735e0c0c9e4905cf61251f9bf891cec04ffdf44	/home/extra/music/Homestuck/Homestuck Volume 5/26 Planet Healer.mp3
2457	2371	2448	2456	2012-11-30 05:08:43+00	0	\N	5413a143ead19395ecf12455fa1fb1b3d2b2b52342ab5484b42dbd287b85950e	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/01 - Foundations of Stone.mp3
2459	2371	2448	2458	2012-11-30 05:08:44+00	0	\N	42b06abd6fe380f692a65989585d02ff950ac13fe1f43dca408bc425f1109e6a	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/03 - The Riders of Rohan.mp3
2479	2371	2448	2478	2012-11-30 05:08:47+00	0	\N	c98eb8779c796ec33e46bd4a7ebf58fd5542c9cb7f4daa5d5cb500ae8dc18733	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/12 - Helm's Deep.mp3
2461	2371	2448	2460	2012-11-30 05:08:44+00	0	\N	751361a6481758457015386ccfd4174c669f4ad8c5be3768b247dad610fe1313	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/17 - Isengard Unleashed (feat. Elizabeth Fraser & Ben Del Maestro).mp3
2463	2371	2448	2462	2012-11-30 05:08:44+00	0	\N	d6f24b10bc9ed6223cda32e3f5b449d84fa5cd79d51dbc3e216f3bb8a33c05c1	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/06 - The King of the Golden Hall.mp3
2465	2371	2448	2464	2012-11-30 05:08:45+00	0	\N	bd6d0d7120e0e31625de81c201c6784614ccb6ffbd9f27b33ab1aab20e10f689	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/11 - The Leave Taking.mp3
2481	2371	2448	2480	2012-11-30 05:08:48+00	0	\N	7f5d0e8052e5dd2fed5333b149d3e2521bbdc3ee6090e7a7b43186eda445c5cb	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/10 - Treebeard.mp3
2467	2371	2448	2466	2012-11-30 05:08:45+00	0	\N	998537fc859c33c081c22e8ad5808442ec6e0f09b19714639c1bef1ffab096b6	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/18 - Samwise the Brave.mp3
2469	2371	2448	2468	2012-11-30 05:08:45+00	0	\N	9ae502427233bc43298a36f9845b029caa460683227581b1f59c007609206b6b	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/04 - The Passage of the Marshes.mp3
2471	2371	2448	2470	2012-11-30 05:08:46+00	0	\N	fa433db7179bbf608994fb08b0afec63436ce8227f1a6e67a1167a7aecbf2e18	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/14 - Breath of Life (feat. Sheila Chandra).mp3
2483	2371	2448	2482	2012-11-30 05:08:48+00	0	\N	9f8c5b6f573366ffeb3e8633ea150501cb432dd46f52c29684d57a51be77e212	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/05 - The Uruk-hai.mp3
2473	2371	2448	2472	2012-11-30 05:08:46+00	0	\N	7139dc8a4465102774ef5ae496edb9b948a3011b2ffc8a7aca12c67a739aae54	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/09 - The White Rider.mp3
2475	2371	2448	2474	2012-11-30 05:08:46+00	0	\N	2a801e74bbb698226352574a207438910c298b7748aca02db232960f0f589fc9	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/19 - Gollum's Song (perf. by Emiliana Torrini).mp3
2502	2489	2490	2501	2012-11-30 05:08:50+00	0	\N	6952eef1139f596dd175d57af6efb30ad56dde7473254aaf4daa8518b0d26f32	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-09 - 'Main Title' from The Reviers (1969).mp3
2477	2371	2448	2476	2012-11-30 05:08:47+00	0	\N	14edf3c2ed648558fb082d665edca352d49e882808289cd3b515699cb4ab8fc5	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/16 - Forth Eorlingas (feat. Ben del Maestro).mp3
2485	2371	2448	2484	2012-11-30 05:08:48+00	0	\N	b80cc4404fbaf46112c8cec4b20d40b2326f8d3d95956adf41d70f537b26f14a	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/02 - The Taming of Smeagol.mp3
2498	2489	2490	2497	2012-11-30 05:08:50+00	0	\N	5402936951a25fa744c180141af3c6955a740456b632e907746a15a97849e0bf	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-07 - 'Bugler's Dream'-'Olympic Fanfare and Theme' (1984).mp3
2487	2371	2448	2486	2012-11-30 05:08:48+00	0	\N	977ce18e7c2e26d2d05e551b35260843aaf03262ccf95b00d94b123ddd08d5ff	/home/extra/user/torrents/The Lord Of The Rings - The Trilogy Soundtrack/Original_OST/2_The_Two_Towers/13 - The Forbidden Pool.mp3
2496	2489	2493	2495	2012-11-30 05:08:49+00	0	\N	9b7d924f4adeb43ff394d1631c2be48a911d342569c20dc2930c5f18afbe1dfe	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-02 - 'Theme' from Jurassic Park (1993).mp3
2500	2489	2490	2499	2012-11-30 05:08:50+00	0	\N	46b256986ad8ffb1079508ce5a6f656f7f034de26a4a27fe287b7354137d1f3d	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-05 - 'Theme' from Sugarland Express (1974).mp3
2506	2489	2490	2505	2012-11-30 05:08:51+00	0	\N	7a47c464b5d3357c7e8eac186acc5d318f8d63cbdcd6c9ee3125f2c81abda6e7	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-04 - 'Parade of the Slave Children' from Indiana Jones and the Temple of Doom (1984).mp3
2504	2489	2490	2503	2012-11-30 05:08:51+00	0	\N	76677bfadc338238d8c73cc072be539b2387c06823377f672288bb61d8cec033	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-12 - 'Cadillac of the Skies' from Empire of the Sun (1987).mp3
1455	1253	1254	1365	2012-11-30 05:06:03+00	0	\N	370da64ec82dd4d693286297d51571c5b2610bd21e9f99b0a637f47163448aec	/home/extra/music/Homestuck/Homestuck Volume 5/07 Aggrievance.mp3
2494	2489	2493	2492	2012-11-30 05:08:49+00	0	\N	baa5ba8815c6cdad77856ca1b550969de4b2b1b76a7703ec717d96ee647fc2ac	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-08 - 'March' from 1941 (1979).mp3
2530	2489	2493	2529	2012-11-30 05:08:55+00	0	\N	b46257c7e9d19797c69cdb00e480de47e9878f4f1ef60f53d2073611153743a4	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-14 - 'Duel of the Fates' from Star Wars Episode 1- The Phantom Menace (1999).mp3
2514	2489	2490	2513	2012-11-30 05:08:53+00	0	\N	75a52bea71b03865e3a744de04508b6aab4b38e65b1f3cc5b2041c8659f6a893	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-01 - 'Main Title' from Star Wars (1977).mp3
2516	2489	2493	2515	2012-11-30 05:08:53+00	0	\N	3187ad1141a825e3d42c984150653196d1f978d01cb921d7693371758eb71260	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-10 - 'Summon the Heroes' (for Tim Morrison) (1996).mp3
2540	2489	2490	2539	2012-11-30 05:08:57+00	0	\N	d15482625177669b3481b1ec10510af00f3fce2b214562bef3fd5c51bda9320a	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-11 - 'Scherzo for Motorcycle and Orchestra' from Indiana Jones and the Last Crusade (1989).mp3
2518	2489	2493	2517	2012-11-30 05:08:53+00	0	\N	99454d9bee71c63d53d5d1538e7fb14cf89cea5a750e22925e8be25c412678e0	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-05 - 'Seven Years in Tibet' from Seven Years in Tibet (1997).mp3
2532	2489	2490	2531	2012-11-30 05:08:56+00	0	\N	aca374af8352c370cb8aded0de660829547985a1b3a68a4f71476f3fe29adb66	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-13 - 'The Raiders March' from Raiders of the Lost Ark (1981).mp3
2520	2489	2493	2519	2012-11-30 05:08:54+00	0	\N	9936ed338899a3169f2dab5fda408dd7c5c5fac97cdbb1c8a1d6a16f73e87524	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-13 - 'Theme' from Born on the Fourth of July (1989).mp3
2522	2489	2493	2521	2012-11-30 05:08:54+00	0	\N	1760989ee243605ccacc7ad8052066df3561d073080313f088bad96ec6797b8e	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-12 - 'Theme' from Far and Away (1992).mp3
2524	2489	2490	2523	2012-11-30 05:08:54+00	0	\N	43466e9715155ef5d70a9ec3a1053dcde259e0847089c954e591388bb6ec7f82	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-14 - 'Suite' from Close Encounters of the Third Kind (1977).mp3
2534	2489	2490	2533	2012-11-30 05:08:56+00	0	\N	eac4c641ab9d5967d4e985e325561b16a32eaf29ba8199c0012d07a21d8090e7	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-10 - 'The Imperial March' from The Empire Strikes Back (1980).mp3
2526	2489	2490	2525	2012-11-30 05:08:55+00	0	\N	ba13d791cf0b4ec16468eae36a73ce5dbb32ad3368a11dee6229589456b966b1	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-03 - 'Main Title' from Superman (1978).mp3
2528	2489	2493	2527	2012-11-30 05:08:55+00	0	\N	dda40dda8b3d02d512909667670364fa791abe0c887569c99c46ce9dfc401945	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-01 - 'Hymn to the Fallen' from Saving Private Ryan (1998).mp3
2546	2489	2493	2545	2012-11-30 05:08:57+00	0	\N	e72702e0d343992bf94f5b16ecccb4cdff3608bff9824cd4deb76e3112890dd2	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-07 - 'The Days Between' from Stepmom (1998).mp3
2536	2489	2493	2535	2012-11-30 05:08:56+00	0	\N	561be7afb12f11583f3a9789f689506c803ada23c679ebb2564a5eaade9b70b9	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-03 - 'Theme' from Schindler's List (1993).mp3
2542	2489	2493	2541	2012-11-30 05:08:57+00	0	\N	be55d89fa4ec1b8a17cd573db9317c30750c24c38e0dc636a5fa6f79fd181348	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-11 - 'Look Down, Lord' Reprise and Finale from Rosewood (1997).mp3
2538	2489	2493	2537	2012-11-30 05:08:57+00	0	\N	38d467acc181ca176f108b8c66b77dc363e52d6b6c07ff0a3a9410bd9c6e7171	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-06 - 'Prologue' from JFK (1991).mp3
2544	2489	2490	2543	2012-11-30 05:08:57+00	0	\N	a4b25f8e730f28d34aeed185fff601e7181fbaeb53685f6188f56af0d20248b6	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-08 - 'Luke and Leia' from Return of the Jedi (1983).mp3
2512	2489	2493	2511	2012-11-30 05:08:52+00	0	\N	5b027cbaa6875331bb180c16c0ad6ea1e6bd91351ca5e58106c5cb036c19de18	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-04 - 'Flight to Neverland' from Hook (1991).mp3
2556	2555	2549	2554	2012-11-30 05:08:58+00	0	\N	305ce17a25b9a694ec80e88e1803fc584bbba7dfb18726a9f43218572ad61419	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 1 - Mozart/03-Flute Concerto in D major, K 314- Allegro.mp3
2508	2489	2493	2507	2012-11-30 05:08:52+00	0	\N	6c8a6de6e0bd477bfb9ae45ae4deebc1e24c37d0ef88bfd945d17a040dee8660	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/2-09 - 'Somewhere in My Memory' Main Title from Home Alone (1990).mp3
1458	1253	1254	1446	2012-11-30 05:06:04+00	0	\N	41093ea2af2354fca35f71d4865fb1c569043cf5dcc976902f00dda478a71b19	/home/extra/music/Homestuck/Homestuck Volume 5/48 Throwdown.mp3
2510	2489	2490	2509	2012-11-30 05:08:52+00	0	\N	d453a1f6dff0a5719afae2692870c401dd6a4a42d9063d08c452a3b683199026	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-02 - 'Flying Theme' from from E.T. the Extra-Terrestrial (1977).mp3
2593	2582	2583	2592	2012-11-30 05:09:05+00	0	\N	4d6929e09405635d2634a9c839291d8eb21dd95eb58701c3d4cab46b374d0343	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 7 - Vivaldi/09-The 4 Seasons- Concerto No 4 in F minor Winter.mp3
2571	2570	2549	2569	2012-11-30 05:09:01+00	0	\N	bbb32dec1691c71aef6be6f031b1b7a83af7ccb96a07494b514c84c55462ea95	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 1 - Mozart/04-Symphony No.40 in G minor- Molto allegro.mp3
2609	2607	2608	2606	2012-11-30 05:09:08+00	0	\N	a97368758a246bb184e7f6214d51095a53f820561918ef2bc50b90ad3d197944	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 6 - Tchaikovsky/03-Violin Concerto- Andante.mp3
2574	2573	2549	2572	2012-11-30 05:09:01+00	0	\N	49e90e6fb72cc80bbf0a0a2f845881b71cbd037d5ebebe5b611f8534023ce817	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 1 - Mozart/05-Clarinet Concerto KV 622- Adagio.mp3
2596	2595	2583	2594	2012-11-30 05:09:06+00	0	\N	2203adfae4091b15f03e34265f999148ec2ed9214d1720e793a6ff04e98a2cde	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 7 - Vivaldi/05-Oboe Sonata in B flat major, RV 34 (Adagio, Allegro, Largo, Allegro).mp3
2577	2576	2549	2575	2012-11-30 05:09:02+00	0	\N	380f2cc27246c06984945b608dcca8fe4ead83fb7f57a210d01aee2f2cda4663	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 1 - Mozart/09-Divertimento, K 334- Menuetto.mp3
2580	2579	2549	2578	2012-11-30 05:09:02+00	0	\N	7251f926ad0e1a2acf90f12c99ab398ce5fabef320be842c0bd521d2d913848b	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 1 - Mozart/10-Horn Concerto, K 447- Allegro.mp3
2584	2582	2583	2581	2012-11-30 05:09:03+00	0	\N	18bfa5ebc4e70c943a8d5aac9a38a1654bcbc23752e7fa4e8241f8786b49b9dc	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 7 - Vivaldi/06-The 4 Seasons- Concerto No. 3 In F major Autumn.mp3
2599	2598	2583	2597	2012-11-30 05:09:06+00	0	\N	e100b3e3b54388864fd508480b00f8da21ba4a36b251e4ee40d2ebf42ef80f9e	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 7 - Vivaldi/03-Concerto for 2 Corni da caccia in F major, RV 539- Allegro.mp3
2586	2582	2583	2585	2012-11-30 05:09:03+00	0	\N	d260ad3a4c31d3d96616d3f2dd76fe4a9f6e7cca2dc3c3c65bc0233cebcdfdf1	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 7 - Vivaldi/04-The 4 Seasons- Concerto No. 2 in G minor Summer.mp3
2588	2582	2583	2587	2012-11-30 05:09:04+00	0	\N	ea56b78750adfe43c2dd32fa1c6de939fb97e2d6719decf9f6a41db98de016ac	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 7 - Vivaldi/01-The 4 Seasons- Concerto No. 1 in E major Spring.mp3
2617	2611	2608	2616	2012-11-30 05:09:09+00	0	\N	9d87c5979ff7be664553b6008e94336176b985c1344910f5c10a32392263a854	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 6 - Tchaikovsky/06-The Sleeping Beauty- Ballet Suite-Waltz.mp3
2591	2590	2583	2589	2012-11-30 05:09:04+00	0	\N	aa03bdb60bccb76da3ff48e17bfa42e4cfaee035c23a218845bdac7fd5df793f	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 7 - Vivaldi/08-Concerto for 4 Violins in E minor, RV 550- Allegro assai.mp3
2612	2611	2608	2610	2012-11-30 05:09:09+00	0	\N	b7dab0952a0685981510963f2f06c57c94f4ab4a5b6311109797a6446ac26d34	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 6 - Tchaikovsky/05-The Sleeping Beauty- Ballet Suite-Pas d'action – Adagio.mp3
2602	2601	2583	2600	2012-11-30 05:09:07+00	0	\N	bd682c0000c213b2b980b4be5e3b217956cbfadf581813fe5d3f6d4954b65d9a	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 7 - Vivaldi/02-Siciliano.mp3
2605	2604	2583	2603	2012-11-30 05:09:07+00	0	\N	710a3a51140e39e69bc7735696c7c2c04f94f93307b148a2dcc693300abc4329	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 7 - Vivaldi/07-Oboe Concerto (Allegro non tasto - Largo, Allegro non molto).mp3
2622	2611	2608	2621	2012-11-30 05:09:11+00	0	\N	f0e02bb77d5d5937e3656ff77a44952a2e1c7fd69c78c3afd20360b3c88037d4	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 6 - Tchaikovsky/09-Swan Lake- Ballet Suite-Waltz.mp3
2615	2614	2608	2613	2012-11-30 05:09:09+00	0	\N	96ef0db381d582b188356506f7c5c3197c0a37cc082f6b9b851559b4dcc7f0bb	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 6 - Tchaikovsky/02-String Serenade- Waltz.mp3
2620	2619	2608	2618	2012-11-30 05:09:10+00	0	\N	e7922bc8759359e9c45c6bdabad33df0dd8050e90db9bb8bcb818bea86639746	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 6 - Tchaikovsky/07-Capriccio italien Op.45.mp3
2624	2611	2608	2623	2012-11-30 05:09:11+00	0	\N	f6f10f963c62dde3fe0597aa5cc2d094deab9c21e6221f1449ae49fc2643c0d6	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 6 - Tchaikovsky/04-The Sleeping Beauty- Ballet Suite-Introduction.mp3
3488	\N	\N	3487	2012-11-30 05:11:54+00	0	\N	60de4ce4b75793b07dcc9f55bfaa59033dfb32a21d4ef6ad5b42e4ba639b4968	/home/extra/user/podcasts/News/Free Speech Radio Documentaries/20111125hifi.mp3
2627	2626	2608	2625	2012-11-30 05:09:12+00	0	\N	ca8ba06c1959956121f5e003b7c0b9ae3c8e5947bc3e2ec35da943a126ea0216	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 6 - Tchaikovsky/01-Piano Concerto No.1- Allegro non troppo.mp3
3492	\N	\N	3491	2012-11-30 05:11:55+00	0	\N	2cf8f64d7f9e083add6f642a2b2188bcbebee8fb26e2135b0d60690dc21452c3	/home/extra/user/podcasts/News/Free Speech Radio Documentaries/20120903hifi.mp3
2568	2567	2549	2566	2012-11-30 05:09:00+00	0	\N	6030aed9f61df4ce2af33313a3b983663f923767af33c218f2da3b8a0241760c	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 1 - Mozart/07-Turkish March.mp3
2656	2633	2634	2655	2012-11-30 05:09:16+00	0	\N	c51fca1ce13875964fb572a759d5dd327101a4a21fb126cf83ddd5fa87b8f3de	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/08-24 Preludes, Op. 28- No. 16 in B flat minor.mp3
2637	2633	2634	2636	2012-11-30 05:09:13+00	0	\N	72728221af66fc15aff277f205798f7db99a9521379b68760ac64e12498e1b6f	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/09-24 Preludes, Op. 28- No. 17 in A flat major.mp3
2639	2633	2634	2638	2012-11-30 05:09:13+00	0	\N	de2532fdca923b4e6c0324a5567c23b7deb6f632a5e8734a3af3aebbfd43a4d1	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/06-24 Preludes, Op. 28- No. 14 in E flat minor.mp3
2658	2567	2634	2657	2012-11-30 05:09:16+00	0	\N	5f339c2bcaf9759a7893961c256bcfcdbd98b4e3acbc585d101d287966b76424	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/13-Nocturne in C sharp minor, Op. posth..mp3
2642	2641	2634	2640	2012-11-30 05:09:13+00	0	\N	09ef1d1713930a916318935cb57f40c54bad81186ec4093b91f9ddc3c7d06b1b	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/15-Four Mazurkas, Op. 24- No. 4 in B flat minor.mp3
2645	2644	2634	2643	2012-11-30 05:09:14+00	0	\N	f57decfe47be6be84fb53708b98d830b59ae04dbd42e93b9a71630baf3900d9c	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/11-Scherzo No. 2 in B flat minor, Op. 31.mp3
2670	2668	2669	2667	2012-11-30 05:09:18+00	0	\N	51306d930cc35c69efc75dfd04cead81967a53b2c5e97c3d10e3d472523c3107	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/13-„Wachet auf, ruft uns die Stimme, Chorale, BWV 645.mp3
2648	2647	2634	2646	2012-11-30 05:09:14+00	0	\N	cc69c1899300de6a82ddc11e45be6ad0569970a93b2d7d630c4516f4fa60ecf3	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/04-Twelve Etudes, Op. 25- No. 10 in B minor.mp3
2660	2633	2634	2659	2012-11-30 05:09:17+00	0	\N	3ae80c721c2798ab530e10f7ef3b3e3b996fc0dcfaae4207c46ffbcae4f3bd15	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/07-24 Preludes, Op. 28- No. 15 in D flat major Raindrops.mp3
2650	2641	2634	2649	2012-11-30 05:09:15+00	0	\N	4ca22fc2533e75fb75f9ba83b602cc1760d97243ee76b3561e09164959fc8e18	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/14-Four Mazurkas, Op. 24- No. 3 in A flat major.mp3
2652	2647	2634	2651	2012-11-30 05:09:15+00	0	\N	93606c66d7d80f2821ced28ce70b793f980ae2dcbd02767c6b68403dd704cdce	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/02-Three Nocturnes, Op. 9- No. 3 in B major.mp3
2654	2647	2634	2653	2012-11-30 05:09:15+00	0	\N	1e350199b4c60a7d73d90c5ee22f23a3b2327683edd6d93cb2ece6a41d285510	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/01-Scherzo No. 1 in B minor, Op. 20.mp3
2679	2678	2669	2677	2012-11-30 05:09:19+00	0	\N	8b27a1efba7b18abb1ca1c46b92c8730c9eebf5c3e8f2ce9fcf6b2a853649c1e	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/11-Easter Oratorio, BWV 249- Sinfonia.mp3
2662	2641	2634	2661	2012-11-30 05:09:17+00	0	\N	19d62a3e2f626f6c01a8b5ff3a90663569c3ffe59a5a91230e37d6e7e598e559	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/12-Waltz in E flat major, Op. 18.mp3
2673	2672	2669	2671	2012-11-30 05:09:18+00	0	\N	cef2b77d4c7aa247e681340787ae27e7a51d3a90bc8f405068dd8ce51eaab628	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/06-Minuet in G major, BWV Anh. 116.mp3
2664	2633	2634	2663	2012-11-30 05:09:17+00	0	\N	65ffea01e3b2960ba68233a893b67e046e19d278ae39545c2f4e996b3bf72179	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/05-24 Preludes, Op. 28- No. 13 in F sharp major.mp3
2666	2647	2634	2665	2012-11-30 05:09:18+00	0	\N	d2831762366191440ed625ba62716efba184bfdfd146a616ceb1bf9016f8493a	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/03-Twelve Etudes, Op. 10- No. 5 in G flat major.mp3
2676	2675	2669	2674	2012-11-30 05:09:19+00	0	\N	1933ee41873686222e74d6a674e73caa2c035f25a92eb3c60e329209e6b63b50	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/15-„Kommst du nun, Jesu, vom Himmel herunter, Chorale, BWV 650.mp3
2684	2683	2669	2682	2012-11-30 05:09:20+00	0	\N	1347286460cc5e7906a9b3679bee3b7362aff4faf6c98bf1185a881bf247f3d2	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/10-Brandenburg Concerto No.2 in F major, BWV 1047- Andante.mp3
2681	2668	2669	2680	2012-11-30 05:09:20+00	0	\N	e5358cd4aaa0f1c3dc6d1790c259d7fe33e8058e77c4b667c8c6bc65b9d998ee	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/08-Toccata and Fugue in D minor, BWV 565.mp3
2687	2686	2669	2685	2012-11-30 05:09:21+00	0	\N	c0380924c5645e5fdec043645534344cbc72ef7aa0c24cae4f4b54b4c96b7709	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/03-Overture No. 2- Badinerie.mp3
2635	2633	2634	2632	2012-11-30 05:09:13+00	0	\N	2ae7c3287ea9b9ce2949231ce31024c8aa231a452752dce147518a65d1018b73	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 8 - Chopin/10-24 Preludes, Op. 28- No. 18 in F minor.mp3
2631	2611	2608	2630	2012-11-30 05:09:12+00	0	\N	52b8d263cacc9d3d6f7c788286e7c63bc4e9195f3e1b1ab32c6e7b4a6ba02c45	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 6 - Tchaikovsky/08-Swan Lake- Ballet Suite-Scene No.10.mp3
2718	2717	2708	2716	2012-11-30 05:09:26+00	0	\N	9153e7b9d678544d0082f8c7279db75606f7ad5821b520cb13c7696305baf610	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 9 - Schubert/06-Moment musical in A flat major.mp3
2697	2683	2669	2696	2012-11-30 05:09:22+00	0	\N	66db73897ec30ecd4670ec3286a97577e87e8182f575d20af83a8561b015d46f	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/09-„lch liebe den Höchsten von ganzem Gemüte, Cantata, BWV 174- Sinfonia.mp3
2699	2683	2669	2698	2012-11-30 05:09:22+00	0	\N	dd600ef89eb1bf349ac36153ea44de2690065e6b4a73f8f232a86cc2c6127df4	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/02-Overture No. 3- Air.mp3
2720	2707	2708	2719	2012-11-30 05:09:27+00	0	\N	69a725d0160beae8b891a47c86876f4fc23d3885757844d8641413e7c91831de	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 9 - Schubert/09-Ballet Music No. 2 aus,from ''Rosamunde''.mp3
2701	2683	2669	2700	2012-11-30 05:09:23+00	0	\N	4075407a297aad0f082ea9c3caaf0aa0327e4bc4aa54b3e57f436c08a794850d	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/14-Brandenburg Concerto No.1 in F major, BWV 1046- Adagio.mp3
2703	2678	2669	2702	2012-11-30 05:09:23+00	0	\N	dddfb45c5df438e4e86749e965684ba9e49ec6a561f625a2b573427b7d90ec08	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/01-Overture No. 4- Réjouissance.mp3
2705	2683	2669	2704	2012-11-30 05:09:23+00	0	\N	d945c03c579c6dd6f80bbab6685b846eb55ffab2a371454ce0241a6a02142fbd	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/07-Overture No.1- Passepied.mp3
2722	2717	2708	2721	2012-11-30 05:09:27+00	0	\N	24772bea5e2e2583c41f45cf7ec4a6da4c94fa3e9b2a4e18b4162c7c3f826e1c	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 9 - Schubert/02- Impromptu in E flat major.mp3
2709	2707	2708	2706	2012-11-30 05:09:24+00	0	\N	7c91c0c4ac9cc5e847a559f44960dc179815d7623aff62fa0d83e588a900fe0c	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 9 - Schubert/10-Symphony No. 6 in B minor Unfinished- Allegro moderato.mp3
2712	2711	2708	2710	2012-11-30 05:09:25+00	0	\N	205c34b26d1043cb163ce74520265479fc37383224a080732fb34a98f1683fd4	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 9 - Schubert/08-Moment musical No. 3 in F minor.mp3
2731	2730	2708	2729	2012-11-30 05:09:28+00	0	\N	93ce6fff5fd6a76ccf7a58e930c7a6918ebd8b028806e8edd2c6f55998e85e65	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 9 - Schubert/04-Trout Quintet- Tema con variazioni.mp3
2715	2714	2708	2713	2012-11-30 05:09:25+00	0	\N	11637e79612ef3e1e45652b7fd31291816d1b8dd734e054c146c96820e87cecf	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 9 - Schubert/05-Entr'acte No. 1 from Rosamunde.mp3
2724	2711	2708	2723	2012-11-30 05:09:27+00	0	\N	e0d5f14a83b8e722fee7c4a0e7b24313177b1497afb7784732be5ab8837f97b1	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 9 - Schubert/01-Ave Maria.mp3
2740	2733	2734	2739	2012-11-30 05:09:30+00	0	\N	570b6aa150aff42e586eaee9981a824def444a991699de60f36e1cd4c4b5f1a4	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 5 - Wagner/05-Der Fliegende Holländer- Overture.mp3
2726	2707	2708	2725	2012-11-30 05:09:28+00	0	\N	8d9a374c466b19661d77de4b5d2a4a04746ab1959ec278dc25d95c9247242cdd	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 9 - Schubert/07-Entr'acte No. 2 from ''Rosamunde''.mp3
2728	2711	2708	2727	2012-11-30 05:09:28+00	0	\N	240625f3fbe081ed5fa8d03fb74587361be4dcb12b491aa0abbafe0dcae006fe	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 9 - Schubert/03-Ständchen.mp3
2735	2733	2734	2732	2012-11-30 05:09:29+00	0	\N	03c3d6f854bed0c4fc47ce8f8784a4419e1d928adce116e66491f26ea1151b4e	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 5 - Wagner/08-Tannhäuser- Arrival of the Guests at Wartburg.mp3
3032	2872	3016	3031	2012-11-30 05:10:33+00	0	\N	03848b1d56357035ace39643672df274907968d73478f7fca82e905575075f0c	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/02 - Dead Can Dance - The Trial.mp3
2738	2737	2734	2736	2012-11-30 05:09:30+00	0	\N	1e87f1ab85ad2ebb241e86b88aa0a588fc70f060ed4899dcca6fa75a0a2e3d0f	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 5 - Wagner/03-Die Meistersinger von Nürnberg- Prelude Act 3.mp3
2742	2733	2734	2741	2012-11-30 05:09:31+00	0	\N	62ff94cc0ab5a89c4a12a0e5fa65110e74924fd325649658d5336d2846b40b60	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 5 - Wagner/07-Tristan und Isolde- Prelude and Liebestod.mp3
2744	2737	2734	2743	2012-11-30 05:09:32+00	0	\N	079e12c6a5856d4a25577ce93d41972dd086f054d2f46cbae7a6ab786ea4b916	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 5 - Wagner/01-Tannhäuser- Overture.mp3
2746	2733	2734	2745	2012-11-30 05:09:33+00	0	\N	01ce019e602435c4b35d3294bd9cfd13ee1b537c202e0f18ba06b1b2c3f0ae5c	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 5 - Wagner/06-Lohengrin- Prelude.mp3
2550	2548	2549	2547	2012-11-30 05:08:58+00	0	\N	e7b2cf4569f0c82f4f2c3ac7a0fe29f30f400fc322c1d1775d4aac1bbd059fb3	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 1 - Mozart/11-Cassation, K99- Allegro.mp3
2695	2694	2669	2693	2012-11-30 05:09:22+00	0	\N	99f47a5f97942a345979ff5a6479193ce4d5d0b3b14811e02a3513c6d684e2c1	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/05-Minuet in D minor, BWV Anh. 132.mp3
2790	2567	2772	2789	2012-11-30 05:09:42+00	0	\N	1ea426980cffd6a4321e042ad3d1271fe5dd448d171b3ca31b9beb780a98a61a	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 3 - Beethoven/04-”Moonlight” Sonata- Adagio sostenuto.mp3
2779	2778	2772	2777	2012-11-30 05:09:39+00	0	\N	6ef9583ddd44f1386920792ef969bd6c22bb3d13dfe490896c77b806c189956e	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 3 - Beethoven/07-”Coriolan” Overture.mp3
2756	2752	2753	2755	2012-11-30 05:09:34+00	0	\N	b84411fc87a3c42b8dfdde22f1a135c4f535a113a1f9412224fc4e813c8d8209	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 4 - Strauss/06-Annen Polka.mp3
2758	2752	2753	2757	2012-11-30 05:09:34+00	0	\N	4694d7e5a5487fef21819dc971de56a3dff3c8d1b519860b1cd0209739691335	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 4 - Strauss/02-Wine, Woman and Song.mp3
2761	2760	2753	2759	2012-11-30 05:09:35+00	0	\N	3032391fbd60d2852b56d09fcc59162921d7318a487bdeb33bccdeb49b42592f	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 4 - Strauss/01-Die Fledemiaus (Excerpts).mp3
2781	2778	2772	2780	2012-11-30 05:09:40+00	0	\N	1208628b8c7190b4e47f2d7955116abc17c6e58bc748573a4471dcdf4916df73	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 3 - Beethoven/06-Symphony No.8 in F major- Allegretto scherzando.mp3
2763	2752	2753	2762	2012-11-30 05:09:36+00	0	\N	da885f86c18a4f48774ffd6eada082d964e53d61edb134b37bcc82901b1c2189	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 4 - Strauss/08-The Gypsy Baron- Einzugsmarsch.mp3
2765	2760	2753	2764	2012-11-30 05:09:36+00	0	\N	1c28aa06a3bee58205f406d15499b27ad66cfc6484792b406416277e9682e8c4	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 4 - Strauss/05-The Gypsy Baron- Introduction.mp3
2799	2797	2798	2796	2012-11-30 05:09:43+00	0	\N	f1cc091baa2d9a96ea48284467eb550111b8d8accc82ec9d6dc057234c8d080b	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 10 - Verdi/01-Nabucco- Overture.mp3
2767	2752	2753	2766	2012-11-30 05:09:37+00	0	\N	0c9483d8c6e5190728d6c13b3a78f524c6c5e7353da1c378eadb130ced36d393	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 4 - Strauss/04-The Blue Danube.mp3
2784	2783	2772	2782	2012-11-30 05:09:40+00	0	\N	c10e03f1fec7c42e4e181b724b5417950d77688a3d461da21e273f18b34cf9a5	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 3 - Beethoven/01-Symphony No.5- Allegro con brio.mp3
2769	2752	2753	2768	2012-11-30 05:09:38+00	0	\N	fae798a327c0cca1dab07bc910a4d349b8529f91367f398c264396453792aa25	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 4 - Strauss/03-Tritsch Tratsch Polka.mp3
2773	2771	2772	2770	2012-11-30 05:09:38+00	0	\N	d88e1c28aa48815e82656923e12db9e8d17bf8cec8eaa0f58b5f02b218bfeecc	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 3 - Beethoven/08-Piano Concerto No.2- Adagio.mp3
2793	2792	2772	2791	2012-11-30 05:09:42+00	0	\N	5cce1797c7ce4961b79f54f5dab5863ebebfe3cbaf6eb61d52da033c3221bfef	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 3 - Beethoven/03-Violin Romance No.2.mp3
2776	2775	2772	2774	2012-11-30 05:09:38+00	0	\N	03b297f7b20625147706f2241ab19350e28f25988c34cc60af84ad000d63aef2	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 3 - Beethoven/10-”Egmont”- Overture.mp3
2786	2783	2772	2785	2012-11-30 05:09:41+00	0	\N	ed6a5be566388eb963ce7f26c16f5bc739af2e8cf3abf2645ced1bdd1eb7f1ef	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 3 - Beethoven/09-ymphony No.5 in C minor- Allegro.mp3
2788	2567	2772	2787	2012-11-30 05:09:41+00	0	\N	ee895d39e95b6b5b91fb41b770def718d49725035f131b6771870fdb4e9b493a	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 3 - Beethoven/02-Für Elise.mp3
2804	2801	2798	2803	2012-11-30 05:09:44+00	0	\N	0ad0b7283ae5a57623af5b284f2d5c68239b7a91ef3ff046235e5f48664857e5	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 10 - Verdi/02-Nabucco- Va pensiero, sull'ali dorate.mp3
2795	2711	2772	2794	2012-11-30 05:09:43+00	0	\N	ede8638dc00f5359257520dd9d87e6b87249dffdf9fd8bfa4d99f13fa02d1071	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 3 - Beethoven/05-Minuet.mp3
2802	2801	2798	2800	2012-11-30 05:09:43+00	0	\N	a2f0a34896b604eba30bab928495252f9aa0700a353ec809406ab97801d0ecf6	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 10 - Verdi/04-Il Trovatore- Vedi! le fosche notturne (Gypsies' Chorus).mp3
2806	2797	2798	2805	2012-11-30 05:09:44+00	0	\N	68b66885488d7aaa0552f44c57237ee8c23acdf50c0376228d60294761fdd44f	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 10 - Verdi/03-Aida- Prelude.mp3
2808	2801	2798	2807	2012-11-30 05:09:45+00	0	\N	41a8893f4acb7bafacc6c744912cde45e9e28669601f81da6b24c19745c9d01d	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 10 - Verdi/10-La Traviata- Di Madride noi siam mattadori.mp3
2553	2552	2549	2551	2012-11-30 05:08:58+00	0	\N	6565351aaa65959eaf396d5dce516d4658bd0110144b6760c931327586869ed8	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 1 - Mozart/06-Serenade, K375- Menuetto.mp3
2754	2752	2753	2751	2012-11-30 05:09:34+00	0	\N	a908e1b26f52f48d71081b6a978d4e3356e852490a4c3a17c85552be0d40b9b2	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 4 - Strauss/07-Vienna Blood.mp3
2832	2822	2823	2831	2012-11-30 05:09:50+00	0	\N	3e7612fd3628e97979f6a882b4892a58a1dcccc88f9371470b485ab4b69ded7b	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/09 dead can dance - saltarello (live in Warsaw 31.03.2005).mp3
2816	2797	2798	2815	2012-11-30 05:09:46+00	0	\N	47c76a2e4c620a3516a6355a1ff8389912d9a2dccff84330f8f7c452cb3c5e50	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 10 - Verdi/07-La Traviata- Prelude.mp3
2818	2801	2798	2817	2012-11-30 05:09:47+00	0	\N	cb5055a83f87a98bc82d9ed05f26f64e1cc89f05e7409c1bb1fced6919a4aff5	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 10 - Verdi/05-Il Trovatore- Or co' daddi, ma fra poco (Soldiers' Chorus).mp3
2842	2822	2823	2841	2012-11-30 05:09:51+00	0	\N	3b36be415bce7feb4304222664a72317c98a998c7d4aeb8b7bdfeedbf64d92b9	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/02 dead can dance - saffron (live in Warsaw 31.03.2005).mp3
2820	2797	2798	2819	2012-11-30 05:09:47+00	0	\N	db2f0546da8b4f51bda1b57b32acd94f930558b9c67c73339d85f66ad93cd1e1	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 10 - Verdi/11-La Forza del destino- Overture.mp3
2834	2822	2823	2833	2012-11-30 05:09:50+00	0	\N	99e4e5b278b01a1cca0bdbd20d1a652abd9898dbfd5f8aff12603e4d211bfd7f	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/21 dead can dance - severance (live in Warsaw 31.03.2005).mp3
2824	2822	2823	2821	2012-11-30 05:09:48+00	0	\N	9eadc80a93948f98efa0c4c1704816975c2983ac4c0aab133498f8c6dc353c5b	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/18 dead can dance - black sun (live in Warsaw 31.03.2005).mp3
2826	2822	2823	2825	2012-11-30 05:09:48+00	0	\N	8a7e72d7ec4027bb26506ed5756033c5023fc88b0030f3d7bf5fe75a7a3508c1	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/07 dead can dance - cresent (live in Warsaw 31.03.2005).mp3
2836	2822	2823	2835	2012-11-30 05:09:50+00	0	\N	0c9c296708442e390032baf4f401a9159a199fea45e9de52950385f250187a86	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/23 dead can dance - hymn for the fallen (live in Warsaw 31.03.2005).mp3
2828	2822	2823	2827	2012-11-30 05:09:49+00	0	\N	743ecf5e5ad1f54746af9fb50f2db43684e88572456d6f63b474909e183d8243	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/11 dead can dance - how fortunate the man with none (live in Warsaw 31.03.2005).mp3
2830	2822	2823	2829	2012-11-30 05:09:49+00	0	\N	79ebc7ea9cfd7b899cf67508afc6130dd13216d722c2676567186076a20cd7ad	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/15 dead can dance - sanvean (live in Warsaw 31.03.2005).mp3
2848	2822	2823	2847	2012-11-30 05:09:52+00	0	\N	9912469fbcf8d46e940648821640df08dfc1b2ea4ca18b56cf0b4a7d68bd5485	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/04 dead can dance - the ubiquitous mr. lovegrove (live in Warsaw 31.03.2005).mp3
2838	2822	2823	2837	2012-11-30 05:09:50+00	0	\N	f07a5139da446f9755165f04c0843bd5c81cc11dce5fcdb42fc83d1d0198e65d	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/17 dead can dance - standing ovation (live in Warsaw 31.03.2005).mp3
2844	2822	2823	2843	2012-11-30 05:09:51+00	0	\N	df6b67db9b6ced21369423c9c4e4847d001f91eb6d9e436b921281f2d18aa99f	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/06 dead can dance - lotus eaters (live in Warsaw 31.03.2005).mp3
2840	2822	2823	2839	2012-11-30 05:09:51+00	0	\N	8f6a925ee972cc896f0a895c6a691ba5a66f4af75616e3971ae5cdff227ed928	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/14 dead can dance - american dreaming (live in Warsaw 31.03.2005).mp3
2846	2822	2823	2845	2012-11-30 05:09:51+00	0	\N	5c462849cd215b841c30e2d44dd9d4a14eb93ccc364a81a7d052b6c8c66a7cf7	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/22 dead can dance - standing ovation II (live in Warsaw 31.03.2005).mp3
2852	2822	2823	2851	2012-11-30 05:09:52+00	0	\N	dcdd7cce46b69452d47de8873ee37797d4be4d77eaea88620c1ab26cfa0a79fc	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/05 dead can dance - the love that cannot be (live in Warsaw 31.03.2005).mp3
2850	2822	2823	2849	2012-11-30 05:09:52+00	0	\N	a59f62e0187a6bf2c46c95dbe32f05d302cb718b70ff1cd30aba5d121be738b6	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/16 dead can dance - rakim (live in Warsaw 31.03.2005).mp3
2854	2822	2823	2853	2012-11-30 05:09:53+00	0	\N	41c1c2591baeb195512e161f1024226f431b155979b94c602864d915bd13281f	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/08 dead can dance - minus sanctus (live in Warsaw 31.03.2005).mp3
2856	2822	2823	2855	2012-11-30 05:09:53+00	0	\N	f541d51dfff20e9ffa90366673859b86bbe7238d917923e3e17c8e74187176b4	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/00 dead can dance - intro (applause) (live in Warsaw 31.03.2005).mp3
2814	2797	2798	2813	2012-11-30 05:09:46+00	0	\N	79864a077c04a43a243cb906376c2c25b90c778a3f5e37e382a6cca560e901c8	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 10 - Verdi/06-Aroldo- Overture.mp3
2812	2801	2798	2811	2012-11-30 05:09:45+00	0	\N	9f7576aebc319ba5848a84c14075f262b768c72190866856347d05ca5e225db2	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 10 - Verdi/08-La Traviata- Noi siamo zingarelle.mp3
2858	2822	2823	2857	2012-11-30 05:09:53+00	0	\N	e3330bd118aeaa71801b570cfba9f28f90fe20250ca97c7bfece3cc89139ad08	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/19 dead can dance - salems lot - aria (live in Warsaw 31.03.2005).mp3
2880	2872	2873	2879	2012-11-30 05:09:56+00	0	\N	0b1ab51ab391122d4f791f8bc564711501bc8756b720a56846b89972428f4e82	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/15 - Dead Can Dance - In The Kingdom Of The Blind The One Eyed Are Kings.mp3
2860	2822	2823	2859	2012-11-30 05:09:53+00	0	\N	97e8c12f2c8bb047fb340e9248983735954161d2f45a6454740375c0d958a30d	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/03 dead can dance - yamyinar (live in Warsaw 31.03.2005).mp3
2862	2822	2823	2861	2012-11-30 05:09:54+00	0	\N	d2c8d50be15846f7a0de7b1070fcb9d29cf0c5d13bc1c5cbcc88d36fc665500d	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/13 dead can dance - i can see now (live in Warsaw 31.03.2005).mp3
2892	2872	2873	2891	2012-11-30 05:09:58+00	0	\N	4608e65314fb578b93f86c7f50a9b70fa5f0aa79e7f69872f8b665875e77180c	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/13 - Dead Can Dance - Windfall.mp3
2864	2822	2823	2863	2012-11-30 05:09:54+00	0	\N	c91db390e5f3f5fd8393fe5a7d910efcb27211fe4fffc6707d2b80257c312d7a	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/20 dead can dance - yulunga (live in Warsaw 31.03.2005).mp3
2882	2872	2873	2881	2012-11-30 05:09:56+00	0	\N	1d0f74d96bb058386d8af5424323506b20acfc330ecf0e6a457a96d16a995c27	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/04 - Dead Can Dance - Orion.mp3
2866	2822	2823	2865	2012-11-30 05:09:54+00	0	\N	1658e1bd9d2e4a580b3ca42111b832043c6c3ac26ee8de0f59fb8b06ba1a4724	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/12 dead can dance - dreams made flash (live in Warsaw 31.03.2005).mp3
2868	2822	2823	2867	2012-11-30 05:09:54+00	0	\N	d230610c65f345e6f4a9e812560782ab1f870279dc162913c281ee7dc2796f85	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/01 dead can dance - nierika (live in Warsaw 31.03.2005).mp3
2870	2822	2823	2869	2012-11-30 05:09:55+00	0	\N	21a1115dd72ca3bf376cc1374dcb0ec3728db351a3e1812a7b0e6c6aa5a8a18f	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance - Exorcism in the Palace, live in Warsaw 31.03.2005 (bootleg)/10 dead can dance - the wind that shakes the barley (live in Warsaw 31.03.2005).mp3
2884	2872	2873	2883	2012-11-30 05:09:57+00	0	\N	6b5f63f11a1fd9fad19c992ab58d3632f6c793ccae0fad071dd4ad121afa0afb	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/17 - Dead Can Dance - The Protagonist.mp3
2874	2872	2873	2871	2012-11-30 05:09:55+00	0	\N	ea2fa11be3661c355559814c6ac58b781b1fb37ea6cca6137a4501880403d3a8	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/09 - Dead Can Dance - Avatar.mp3
2876	2872	2873	2875	2012-11-30 05:09:55+00	0	\N	77d378528060f9735e08b845c6f9cb7a34a8b8680ba62190be73cf881e4528a9	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/16 - Dead Can Dance - Bird.mp3
2904	2872	2873	2903	2012-11-30 05:10:01+00	0	\N	e70d6bc6ab841a8165154f8c6f035a6639472c1fd3133c158b56ce2c7c0b790e	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/14 - Dead Can Dance - Cantara.mp3
2878	2872	2873	2877	2012-11-30 05:09:56+00	0	\N	70dc76d3d3854973b334c75d0bd559c5dbaa391806066983da377fbd40c29d8c	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/06 - Dead Can Dance - Carnival Of Light.mp3
2894	2872	2873	2893	2012-11-30 05:09:59+00	0	\N	1c48c0b961b3781cc24034dc765122674c84d8c50b74e053d85619ae7a13f55d	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/03 - Dead Can Dance - Ocean.mp3
2886	2872	2873	2885	2012-11-30 05:09:57+00	0	\N	0cfdca5e1325ab24202a854b6587986736f76c09d686293f6972d46943e47d57	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/11 - Dead Can Dance - Summoning Of The Muse.mp3
2888	2872	2873	2887	2012-11-30 05:09:58+00	0	\N	bafff8efebb22076da4e7e662f44f4310e7555b523af96bce96df3069e1b78bf	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/08 - Dead Can Dance - De Profundis (Out Of The Depths Of Sorrow).mp3
2900	2872	2873	2899	2012-11-30 05:10:00+00	0	\N	40275ce9e5150585385a698f9c4be6a37749edc66c6087332a0415fc16f62e4d	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/01 - Dead Can Dance - Frontier.mp3
2890	2872	2873	2889	2012-11-30 05:09:58+00	0	\N	bdc60aece46255d09775eea1aa72464b0deb1a4a5d71ef95a312e4dafa665f91	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/12 - Dead Can Dance - Anywhere Out Of The World.mp3
2896	2872	2873	2895	2012-11-30 05:09:59+00	0	\N	9634bddc1ae34b99703fb2e8e614b28000ee29318b6032a92565848dc3d75b2c	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/05 - Dead Can Dance - Threshold.mp3
2898	2872	2873	2897	2012-11-30 05:10:00+00	0	\N	b1c73282e104bdf02b01757daff0448e7f85de0ca24ed56a1a60b092293d8098	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/02 - Dead Can Dance - Labour Of Love.mp3
2902	2872	2873	2901	2012-11-30 05:10:00+00	0	\N	cfeb0e713bad79a4595c9f89705600780e488765773f3ff7684452503bcd5732	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/07 - Dead Can Dance - In Power We Entrust The Love Advocated.mp3
2559	2558	2549	2557	2012-11-30 05:08:59+00	0	\N	bfab6d9d98e237bcbcfe6396c7e3cf18b01b933d5f80de75ff44feba8191204d	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 1 - Mozart/01-Eine kleine Nachtmusik- Allegro.mp3
2906	2872	2873	2905	2012-11-30 05:10:03+00	0	\N	34203ea492173a678d8323602f36b7428a3835dfa46f7573cc62ec4664fca2a5	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 1/10 - Dead Can Dance - Enigma Of The Absolute.mp3
2909	2872	2908	2907	2012-11-30 05:10:04+00	0	\N	1a2826f968729879f07225a1658f043d049af9915b4d32e13c72077171904005	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/17 - Dead Can Dance - How Fortunate The Man With None.mp3
2911	2872	2908	2910	2012-11-30 05:10:06+00	0	\N	317fc1ac3a37697d4229f570f13f78fd4502cc4f240f73d6985095b4de74f573	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/01 - Dead Can Dance - Severance.mp3
2913	2872	2908	2912	2012-11-30 05:10:07+00	0	\N	0866b183c26471ccd988141a89d119827f5e833b65e58ae4ad72413e60dd5b12	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/12 - Dead Can Dance - Sloth.mp3
2915	2872	2908	2914	2012-11-30 05:10:08+00	0	\N	e87bb6883aee8676be51e3c8c9016a2319fb414d33c18a12164c60a0c387be10	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/11 - Dead Can Dance - The Ubiquitous Mr. Lovegrove.mp3
2966	2872	2943	2965	2012-11-30 05:10:21+00	0	\N	b72cdb43e80e39ed1363a67993d4b3693621696b48407d36d2269407548b0d2a	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 3/11 - Dead Can Dance - Indus.mp3
2917	2872	2908	2916	2012-11-30 05:10:10+00	0	\N	73aa812a85ec250554fe754c1b3864532bd65ec76abf38913463f9ce73462a74	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/02 - Dead Can Dance - The Host Of Seraphim.mp3
2939	2872	2908	2938	2012-11-30 05:10:16+00	0	\N	20cc6a3cc9d254d9512fed4e479ab36831a9c780c8aa509e52d5fa6953e9a61d	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/05 - Dead Can Dance - Black Sun.mp3
2919	2872	2908	2918	2012-11-30 05:10:11+00	0	\N	cbc95ec0ed512581697f86bfaf2a6bba655d5b8917172c5ce9d1e278246da52e	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/03 - Dead Can Dance - Song Of Sophia.mp3
2921	2872	2908	2920	2012-11-30 05:10:11+00	0	\N	0baee827a0c905b3c3a9bc00724e7a9750d92514236d593a6396105ddd0dfdd3	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/06 - Dead Can Dance - The Promised Womb.mp3
2954	2872	2943	2953	2012-11-30 05:10:19+00	0	\N	2b2d6bdb09232695e390eaeaa0b603d9b48239190c930a1b1461dc84eb99a3f0	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 3/13 - Dead Can Dance - The Lotus Eaters.mp3
2923	2872	2908	2922	2012-11-30 05:10:12+00	0	\N	4d2e37b22658494d6ede7ae502c12c1ae97eb5031ac4d3d3b9255ee98686ac99	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/04 - Dead Can Dance - The Arrival & The Reunion.mp3
2941	2872	2908	2940	2012-11-30 05:10:17+00	0	\N	93ce0a39589635c7bb3fc04b87715f42f6e2aec7a753cdb166c613fceca8b04d	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/07 - Dead Can Dance - Saltarello.mp3
2925	2872	2908	2924	2012-11-30 05:10:12+00	0	\N	84535babb55281997ad96a5bb6976d9dfc6184bb774cc0a165ef6648e5e8d460	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/16 - Dead Can Dance - The Wind That Shakes The Barley.mp3
2927	2872	2908	2926	2012-11-30 05:10:13+00	0	\N	46632470ddb08068ff6d0c754d3f607c72e0562410d5318d7e8920606254acab	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/15 - Dead Can Dance - The Spider's Stratagem.mp3
2929	2872	2908	2928	2012-11-30 05:10:14+00	0	\N	acb56b957f152028c8c159c0f9c21ad9c4b45499a6f9e5e1d6ab8fc979bf16c1	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/09 - Dead Can Dance - Spirit.mp3
2944	2872	2943	2942	2012-11-30 05:10:17+00	0	\N	264a703ab2876a8de0d7b0fa6dcdfb177b0cdd46faabc795e570acd6eb2fc4a2	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 3/03 - Dead Can Dance - Tristan.mp3
2931	2872	2908	2930	2012-11-30 05:10:15+00	0	\N	b1be36930c42666ecf3b869b2f12f2410b4a9bd869bc3ee9f9c28aa14ac5d290	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/13 - Dead Can Dance - Bylar.mp3
2933	2872	2908	2932	2012-11-30 05:10:15+00	0	\N	ab2970a96a8b40f154a4374dcebba04613aec1826c98e3b25b5e40d4dd8ba460	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/14 - Dead Can Dance - The Carnival Is Over.mp3
2962	2872	2943	2961	2012-11-30 05:10:20+00	0	\N	b96b032abd9f9f80e33f77cf9672443e10e51fdc7bf08b78839bf460cf7d007d	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 3/07 - Dead Can Dance - Don't Fade Away.mp3
2935	2872	2908	2934	2012-11-30 05:10:16+00	0	\N	f3d43059118642f041c5da9ac8709adc5b873d6680fe2d1125f28030eceef277	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/10 - Dead Can Dance - Yulunga.mp3
2946	2872	2943	2945	2012-11-30 05:10:17+00	0	\N	518fd4176f4d54dbe46923ce96926a884fcc974b8980e70a3e79d5b71cc2f505	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 3/12 - Dead Can Dance - The Snake & The Moon.mp3
2937	2872	2908	2936	2012-11-30 05:10:16+00	0	\N	383d55cdfbbb3681dce5fdaf94923977cce181ce618b57aeda10f7acda0a1082	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 2/08 - Dead Can Dance - The Song Of The Sibyl.mp3
2956	2872	2943	2955	2012-11-30 05:10:19+00	0	\N	1c2eaae53c3de831baed827682676cc2bef3724c5633b459263ace79a64b1b49	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 3/10 - Dead Can Dance - Sambatiki.mp3
2948	2872	2943	2947	2012-11-30 05:10:17+00	0	\N	66536b05a746a3d03a4cff3c4f3290c48ce44c7029a82042a384a81b09f826a4	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 3/06 - Dead Can Dance - Gloridean.mp3
2950	2872	2943	2949	2012-11-30 05:10:18+00	0	\N	d80c786f98e042fbb0aed93d47922b90316579fa44c8768144887eb63db0db18	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 3/01 - Dead Can Dance - I Can See Now.mp3
2952	2872	2943	2951	2012-11-30 05:10:18+00	0	\N	385d850f4a3d26d7ab8eb2d84ecbce3010b1357b4855273fcf58fe55c4cea11b	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 3/08 - Dead Can Dance - Nierika.mp3
2958	2872	2943	2957	2012-11-30 05:10:19+00	0	\N	d59e45d382e362128093c86fda3e9ef2f24168a2344b97afb6f5e050a6c11842	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 3/05 - Dead Can Dance - Rakim.mp3
2960	2872	2943	2959	2012-11-30 05:10:20+00	0	\N	81f792d524fc584c4be023503e99a620b53ca16ee91404ac40bad3c7c6f45a38	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 3/02 - Dead Can Dance - American Dreaming.mp3
2964	2872	2943	2963	2012-11-30 05:10:20+00	0	\N	083b596644125644f64f59814519c8f817afdd11d924af505762ea4eba6fb24c	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 3/04 - Dead Can Dance - Sanvean.mp3
2968	2872	2943	2967	2012-11-30 05:10:21+00	0	\N	5fb79980e6f16f91460ab260378894ad0a6c36df5032982bcbcb2701663da0ce	/home/extra/user/torrents/Dead Can Dance/2001 - Box Set/CD 3/09 - Dead Can Dance - Song Of The Nile.mp3
2971	2872	2970	2969	2012-11-30 05:10:22+00	0	\N	253d4284f6685524b8338b859112f5a5403a96003804eeffd10ad9d410761ea0	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/13 - Dead Can Dance - Fortune Presents Gifts Not According To The Book.mp3
2973	2872	2970	2972	2012-11-30 05:10:22+00	0	\N	5968e25bea2b8565ddc72d21418eb30261f458a7fa649accf760df2027f982ba	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/14 - Dead Can Dance - In The Kingdom Of The Blind The One Eyed Are Kings.mp3
2975	2872	2970	2974	2012-11-30 05:10:22+00	0	\N	859849c3eb981e545d5535f16a09de7cd14feb149213472c3039186d94f8764d	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/08 - Dead Can Dance - The Host Of Seraphin.mp3
2978	2872	2977	2976	2012-11-30 05:10:23+00	0	\N	a746108950ebdd8263b75b478b68f69c3a9ee60552d7ab3c1322c01175162bd2	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/10 - Dead Can Dance - The Wrtiting On My Father's Hand.mp3
3011	2999	3000	3010	2012-11-30 05:10:29+00	0	\N	d590ae0f6bd2a5f84353523ad738d8fbbc1fb0ef83a92fecae23a57924238060	/home/extra/user/torrents/Dead Can Dance/BRENDAN PERRY/1999 - Eye Of The Hunter/01 - Brendan Perry - Saturday's Child.mp3
2980	2872	2970	2979	2012-11-30 05:10:23+00	0	\N	af6d5438867c7f9000bc26087478d4cc430900ca7a4256fcbaa20e6d1ec2d7dd	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/09 - Dead Can Dance - Anywhere Out Of The World.mp3
2997	2872	2970	2996	2012-11-30 05:10:27+00	0	\N	f1764260c2cba2df3ca466a209d34324253b74b5adff02709a720afde17f8edd	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/03 - Dead Can Dance - Ullyses.mp3
2981	2872	2970	2940	2012-11-30 05:10:24+00	0	\N	15ebd048a6b923b019a5da8b76c395d81657e89541d6a005fa28edf73bac8855	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/01 - Dead Can Dance - Saltarello.mp3
2983	2872	2970	2982	2012-11-30 05:10:24+00	0	\N	2330e0343614b59d417e287dd9322fec55732d5d2d6ccb277a6f7f3b370e8fec	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/07 - Dead Can Dance - Wilderness.mp3
2985	2872	2970	2984	2012-11-30 05:10:24+00	0	\N	7085055353231e9ba2496591ee5e5a4ea260fb9587f3dcc0c2f7cecc416e4062	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/12 - Dead Can Dance - The Song Of The Sibyl.mp3
3001	2999	3000	2998	2012-11-30 05:10:27+00	0	\N	a1d30fc5cddc7fea40dd88b35d8650f43a9471408851634197324b5dfdc59ce2	/home/extra/user/torrents/Dead Can Dance/BRENDAN PERRY/1999 - Eye Of The Hunter/05 - Brendan Perry - I Must Have Been Blind.mp3
2987	2872	2970	2986	2012-11-30 05:10:25+00	0	\N	b8011d9dba31de6bd7781cbf305870f76983ac037cfe09d196daf565e13f0ca6	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/06 - Dead Can Dance - Enigma Of The Absolute.mp3
2988	2872	2970	2910	2012-11-30 05:10:25+00	0	\N	351d569c188733d2973ee7baf845835e765543c1ffca13c822f6cfcd861ec28d	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/11 - Dead Can Dance - Severance.mp3
3022	2872	3016	3021	2012-11-30 05:10:31+00	0	\N	84884439291e318e8e25ac00ff77889ba26caffd5fae759fcd8d588a668f5ccd	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/12 - Dead Can Dance - In Power We Trust The Love Advocated.mp3
2990	2872	2970	2989	2012-11-30 05:10:25+00	0	\N	c0757f539bf1f1d3743d1cf682187a143ad165162653915aeb89df62cc63932a	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/02 - Dead Can Dance - Song Of Sophia.mp3
3004	2999	3003	3002	2012-11-30 05:10:27+00	0	\N	e98b757f445194225eac2c96a7fc9e5b2868f589bb943ae2371d767d2ed060da	/home/extra/user/torrents/Dead Can Dance/BRENDAN PERRY/1999 - Eye Of The Hunter/06 - Brendan Perry - The Captive Heart.mp3
2991	2872	2970	2928	2012-11-30 05:10:25+00	0	\N	b7658ef7fa4d469b2c750f438ce2bb452fc0529b15624461a77db98a72317f72	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/16 - Dead Can Dance - Spirit.mp3
2992	2872	2970	2903	2012-11-30 05:10:26+00	0	\N	b6ba46c03a05e901224e522ab7459e8ceb68f003954ee5bdbfd6f5aa733a9d28	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/04 - Dead Can Dance - Cantara.mp3
3013	2999	3000	3012	2012-11-30 05:10:29+00	0	\N	b6c7764a7722b8ae14727548df4b8ca8cc99d00dc5b10392d5095cb7fce4d15d	/home/extra/user/torrents/Dead Can Dance/BRENDAN PERRY/1999 - Eye Of The Hunter/03 - Brendan Perry - Medusa.mp3
2993	2872	2970	2875	2012-11-30 05:10:26+00	0	\N	a16666c347ea9701c194917b127fb4fa3377568d971c56a1ffb9492fd08f5f52	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/15 - Dead Can Dance - Bird.mp3
3005	2999	3000	2912	2012-11-30 05:10:28+00	0	\N	ffe4d8f134ccfee16ddab20cf4f103f4fb8fda405a340509061061d6f03c5e64	/home/extra/user/torrents/Dead Can Dance/BRENDAN PERRY/1999 - Eye Of The Hunter/04 - Brendan Perry - Sloth.mp3
2995	2872	2970	2994	2012-11-30 05:10:26+00	0	\N	d6a5f9dd591e67e54ca96d969e0d8b373d2fb45ef3ef576bd6c168f29def8d42	/home/extra/user/torrents/Dead Can Dance/1991 - A Passage In Time/05 - Dead Can Dance - The Garden Of Zephirus.mp3
3007	2999	3000	3006	2012-11-30 05:10:28+00	0	\N	331711578dbd910b0d372cbadfaeae20ea4f98768908a9d819d9f81a6f8c81d4	/home/extra/user/torrents/Dead Can Dance/BRENDAN PERRY/1999 - Eye Of The Hunter/08 - Brendan Perry - Archangel.mp3
3019	2872	3016	3018	2012-11-30 05:10:31+00	0	\N	9ea99836ac131076db0c8bec20c0de2bb30d7b263350e600020185ad3d23fe2e	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/13 - Dead Can Dance - The Arcane.mp3
3009	2999	3000	3008	2012-11-30 05:10:28+00	0	\N	f6d3b1b2a42402577b269d9a8899841d2ee36b9cd1249d3dc4ba2dd26d03afd7	/home/extra/user/torrents/Dead Can Dance/BRENDAN PERRY/1999 - Eye Of The Hunter/07 - Brendan Perry - Death Will Be My Bride.mp3
3015	2999	3000	3014	2012-11-30 05:10:30+00	0	\N	d641a98e10e53f37222850a5c15fd3f10442a90ce750907306db7de0b445c2fe	/home/extra/user/torrents/Dead Can Dance/BRENDAN PERRY/1999 - Eye Of The Hunter/02 - Brendan Perry - Voyage Of Bran.mp3
3017	2872	3016	2895	2012-11-30 05:10:30+00	0	\N	c39aa71386b856db4077c294f214c77c3efe6226a7cbb984733e90279d91797f	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/07 - Dead Can Dance - Threshold.mp3
3020	2872	3016	2877	2012-11-30 05:10:31+00	0	\N	e431d7c4a3c9e3d3d12c44bb20ccdce0bd423df313ed6ca4f59ee8d5d13614dd	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/11 - Dead Can Dance - Carnival Of Light.mp3
3024	2872	3016	3023	2012-11-30 05:10:32+00	0	\N	d6c0d8ddc9df1c4a9d6e7e66fcabf8ca85f7b7f81798581c31b0cfcf62191baa	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/08 - Dead Can Dance - A Passage In Time.mp3
2562	2561	2549	2560	2012-11-30 05:08:59+00	0	\N	71b9cc0b107ad757bde5ab2373bf7476328f921dd745aaea9693d3921d3c7271	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 1 - Mozart/08-Violin Concerto, K 216- Allegro.mp3
3026	2872	3016	3025	2012-11-30 05:10:32+00	0	\N	ff7bb925cde8dd53583ec34e55933a55cf9b4d6e242ffcafd307578e0c587c05	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/10 - Dead Can Dance - Musica Eternal.mp3
3028	2872	3016	3027	2012-11-30 05:10:32+00	0	\N	c208472c1609eb91c8820e02058f5719ced9a7dc5bbb22f9409565f7854a4f5e	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/01 - Dead Can Dance - The Fatal Impact.mp3
3030	2872	3016	3029	2012-11-30 05:10:33+00	0	\N	25c31cb7305aa63eb0cc0c9e4d7b04373990acc74484b2a556382fb17e336acc	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/04 - Dead Can Dance - Fortune.mp3
3033	2872	3016	2893	2012-11-30 05:10:33+00	0	\N	1d7b47483842140d88289966149585515bdb5ede1c54daf22eea9affe227eeaa	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/05 - Dead Can Dance - Ocean.mp3
3067	2872	3058	2891	2012-11-30 05:10:40+00	0	\N	2d60b7d26cdc4e72afc4ac0470b0e1a4b9781b7cc2c003069d6f124869cfdf9e	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 07 - Windfall.mp3
3035	2872	3016	3034	2012-11-30 05:10:34+00	0	\N	1e59ae052318bc67322c5805f0d7f4e25f3732ab25f465321665cb11835f758b	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/09 - Dead Can Dance - Wild In The Woods.mp3
3053	2872	3041	3052	2012-11-30 05:10:38+00	0	\N	429585941a851c5344dc8e3263a9209414c42954de758c45e87487198a760fda	/home/extra/user/torrents/Dead Can Dance/1988 - The Serpent's Egg/02 - Dead Can Dance - Orbis De Ignis.mp3
3036	2872	3016	2899	2012-11-30 05:10:34+00	0	\N	be85b69b91e428be456f667923782ce3a87882293a537d61f2691c6f904ea199	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/03 - Dead Can Dance - Frontier.mp3
3038	2872	3016	3037	2012-11-30 05:10:34+00	0	\N	b55e17add18a433c95d9d674b0f344a4a781e967f8f9777131f1283da5474b3a	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/06 - Dead Can Dance - East Of Eden.mp3
3062	2872	3058	2903	2012-11-30 05:10:39+00	0	\N	e209e9b1a72a6a9b09ec80aad4de7d2fae5ee1293a066fc3a6d821a203203c3d	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 11 - Cantara.mp3
3040	2872	3016	3039	2012-11-30 05:10:34+00	0	\N	c9c76a3cc87552d00a347b02092bda08f89d7dfa1b6e129610d6e742a1299f64	/home/extra/user/torrents/Dead Can Dance/1984 - Dead Can Dance/14 - Dead Can Dance - Flowers Of The Sea.mp3
3055	2872	3041	3054	2012-11-30 05:10:38+00	0	\N	a0cfe311d2612dc27eb9fb8a38778defc8358d9cae0f1dcc53a24d6349d8c843	/home/extra/user/torrents/Dead Can Dance/1988 - The Serpent's Egg/06 - Dead Can Dance - Chant Of The Paladin.mp3
3042	2872	3041	2996	2012-11-30 05:10:35+00	0	\N	1150ebf6f7259590ec131e916333bfaba088812bc855f7556bad8c2d4a09cee3	/home/extra/user/torrents/Dead Can Dance/1988 - The Serpent's Egg/10 - Dead Can Dance - Ullyses.mp3
3044	2872	3041	3043	2012-11-30 05:10:35+00	0	\N	2c388c9676c7bd7bb377aeffe388f1baee320d91b2601c52c3d8585fa319c2c8	/home/extra/user/torrents/Dead Can Dance/1988 - The Serpent's Egg/09 - Dead Can Dance - Mother Tongue.mp3
3045	2872	3041	2989	2012-11-30 05:10:36+00	0	\N	41db295464a3378c9e3b0c0fe2f6164ebd5de15b5db7100ce6866e4ecdb6919b	/home/extra/user/torrents/Dead Can Dance/1988 - The Serpent's Egg/07 - Dead Can Dance - Song Of Sophia.mp3
3056	2872	3041	2910	2012-11-30 05:10:38+00	0	\N	dcb9e37058c9394c9d3eddf512b8df00ccd969c18106a8cf77bc9123d2a71d04	/home/extra/user/torrents/Dead Can Dance/1988 - The Serpent's Egg/03 - Dead Can Dance - Severance.mp3
3047	2872	3041	3046	2012-11-30 05:10:36+00	0	\N	a0db88d29297e6a17f007d1b7ac1ecf3399a01ba918d62ca43066e2d33d420ed	/home/extra/user/torrents/Dead Can Dance/1988 - The Serpent's Egg/08 - Dead Can Dance - Echolalia.mp3
3048	2872	3041	2972	2012-11-30 05:10:37+00	0	\N	6177cdfa814d2e68301a9f372cf963eabba050bed1633e7fcd14a2b3fe8a0d63	/home/extra/user/torrents/Dead Can Dance/1988 - The Serpent's Egg/05 - Dead Can Dance - In The Kingdom Of The Blind The One Eyed Are Kings.mp3
3049	2872	3041	2974	2012-11-30 05:10:37+00	0	\N	a0977e6858542f77dc7f1a6fcaf31402045257c5edf3be884466df53ae3080c8	/home/extra/user/torrents/Dead Can Dance/1988 - The Serpent's Egg/01 - Dead Can Dance - The Host Of Seraphim.mp3
3059	2872	3058	3057	2012-11-30 05:10:39+00	0	\N	9387d042e20630ce0ebdaef8df833773e64a4e473b1c0be95b7871146665c4fd	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 14 - Black sun.mp3
3051	2872	3041	3050	2012-11-30 05:10:37+00	0	\N	26cb9bed12158e03cb2cc3794b270c892d572f42ffca94bc1a5da9969cd17716	/home/extra/user/torrents/Dead Can Dance/1988 - The Serpent's Egg/04 - Dead Can Dance - The Writing On My Father's Hand.mp3
3064	2872	3058	3063	2012-11-30 05:10:40+00	0	\N	d2a9f084d25a42e291ff93351c420a346cf8676d4ea11e05df234caf96b99937	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 02 - Anywhere out of the world.mp3
3060	2872	3058	2940	2012-11-30 05:10:39+00	0	\N	0a8065ed7692308c2e921f135ee7cc30f6e229fcc62dafa22702d964dc18a50b	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 13 - Saltarello.mp3
3061	2872	3058	2910	2012-11-30 05:10:39+00	0	\N	63d8df1b120af01a8a1eeb3a3b50fb8a5b2637d1af6a4e15905ec3a0d469162e	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 12 - Severance.mp3
3073	2872	3058	3072	2012-11-30 05:10:41+00	0	\N	1409bb6c6c4b3a36189799d38d939e7cb8ca3a538a6184a41748d91aec5f3bca	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 03 - Enigma of the absolute.mp3
3066	2872	3058	3065	2012-11-30 05:10:40+00	0	\N	e9c16b61a0463b4c10cb0cc4163d34d68cca304e8c4d5702aecb05849a085f71	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 06 - Summoning of the muse.mp3
3071	2872	3058	3070	2012-11-30 05:10:41+00	0	\N	5005e1f2a3b3b06f7df9219d923052fb1b08df2c2c0042ecf033fdd097acf9cb	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 08 - In the kingdom of the blind the one-eyed are kings.mp3
3069	2872	3058	3068	2012-11-30 05:10:41+00	0	\N	1ab72b2589dd6f11863e67089954d8b2fcc85bca8ed95013896435f135188a0f	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 01 - Frontier (demo).mp3
2565	2564	2549	2563	2012-11-30 05:09:00+00	0	\N	9a3c41b1c472b6fffd9314f64bb96079a24272dcc418f17de40aef0ea041a6ad	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 1 - Mozart/02-Piano Concerto in A major, K 488- Adagio.mp3
3075	2872	3058	3074	2012-11-30 05:10:42+00	0	\N	3f5aec1aa4a83c52152d7d9c8e9e52f0af81a404b53e11254383f436a9903aa1	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 05 - In power we entrust the love advocated.mp3
3076	2872	3058	2875	2012-11-30 05:10:42+00	0	\N	d92f92ece6b71fd7c36b37debd023b83c33d84e6cb7c9db523555a545b26c4fb	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 10 - Bird.mp3
3078	2872	3058	3077	2012-11-30 05:10:42+00	0	\N	7206dcb271a786494c4c3bb64d4eed32e885bcd1b6983e06ca0aa9056415a6c8	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 09 - The host of Seraphim.mp3
3096	2872	3081	2963	2012-11-30 05:10:46+00	0	\N	22be79bbaff1dc9b979971ea8431192bf321d49406fd53e738b07bb5d6d3e567	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD2]/Dead Can Dance - Wake [CD2] - 06 - Sanvean.mp3
3080	2872	3058	3079	2012-11-30 05:10:42+00	0	\N	da068fa8354e79f8c6ad8da63ca2c98f000a03af729d6fcc2684b8340acf14e2	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD1]/Dead Can Dance - Wake [CD1] - 04 - Carnival of light.mp3
3082	2872	3081	2957	2012-11-30 05:10:43+00	0	\N	5e06d012880e7d6542c5cef2873840d02eeb2a43f0898683107b126615af5a8d	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD2]/Dead Can Dance - Wake [CD2] - 04 - Rakim.mp3
3115	2872	3103	2942	2012-11-30 05:10:51+00	0	\N	c2e141f27a50985653272dba2cc7f6a4c7814500cb740327bf1419a50ac0aba2	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/13 - Dead Can Dance - Tristan.mp3
3084	2872	3081	3083	2012-11-30 05:10:44+00	0	\N	d6d117a93d6a179710ef5738da987228465a8b5d464f590808debeb37ad6ac7e	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD2]/Dead Can Dance - Wake [CD2] - 07 - Song of the Nile.mp3
3097	2872	3081	2934	2012-11-30 05:10:46+00	0	\N	1120d7874b4d566c0cd8e0cf07c839fb0f967873c1fe9625b9f1f40a943a640a	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD2]/Dead Can Dance - Wake [CD2] - 01 - Yulunga.mp3
3086	2872	3081	3085	2012-11-30 05:10:44+00	0	\N	9be3b40869be93e226aa6ee1ec91ebd975bfaa28f152daa166aa1fb5c03a57e9	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD2]/Dead Can Dance - Wake [CD2] - 08 - The spider's stratagem.mp3
3088	2872	3081	3087	2012-11-30 05:10:44+00	0	\N	22b7f8945f21d1f3858bc16c5fccab707e02d5731e38de465c0d41e508f58425	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD2]/Dead Can Dance - Wake [CD2] - 02 - The carnival is over.mp3
3107	2872	3103	3106	2012-11-30 05:10:48+00	0	\N	1b1168bcc9667081ff9bc8a3438bbe3216fcf05fb9c55cf114d1c9cfc5213844	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/11 - Dead Can Dance - Oman.mp3
3090	2872	3081	3089	2012-11-30 05:10:45+00	0	\N	0bc1b77cfcabde233289b2589e67881882555730f49c579c5eab84dc18dde141	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD2]/Dead Can Dance - Wake [CD2] - 05 - The ubiquitous mr. Lovegrove.mp3
3099	2872	3081	3098	2012-11-30 05:10:47+00	0	\N	6e4424dbff91c44b477b4d6d543fb7d54ba14c956d5afdfd8df2e31c47972df3	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD2]/Dead Can Dance - Wake [CD2] - 03 - The lotus eaters.mp3
3091	2872	3081	2951	2012-11-30 05:10:45+00	0	\N	20b10ff67af69931e269a4a23dc99c4828ab2a83bb3b8127cc87db8a826b23b5	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD2]/Dead Can Dance - Wake [CD2] - 11 - Nierika.mp3
3093	2872	3081	3092	2012-11-30 05:10:46+00	0	\N	48fa37894028d00227ab8bd8e7f40f334bbd6051c5bfe4d895d753e20fc6a13f	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD2]/Dead Can Dance - Wake [CD2] - 10 - American dreaming.mp3
3095	2872	3081	3094	2012-11-30 05:10:46+00	0	\N	73e4b7ba52af50ab3b661c9ed00a5a97a33f42ae1363b0fc2dc43cc7ff26e042	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD2]/Dead Can Dance - Wake [CD2] - 09 - I can see now.mp3
3113	2872	3103	2903	2012-11-30 05:10:50+00	0	\N	fca25a5086be8a79c81d1cbd62904732dffce78df2c86598f59279772557c0c4	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/10 - Dead Can Dance - Cantara.mp3
3101	2872	3081	3100	2012-11-30 05:10:47+00	0	\N	5c33e0f201fe11c9342b21c545b335108d9dbc2e5e9bb3dcce617c4b66198c83	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance- Wake/Dead Can Dance (2003) - Wake [CD2]/Dead Can Dance - Wake [CD2] - 12 - How fortunate the man with none.mp3
3108	2872	3103	2961	2012-11-30 05:10:49+00	0	\N	2e13ecadebd3d45dc141f74fb5f6af4db15ee7c0ae9d8fb668b221f0ea5f25f0	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/15 - Dead Can Dance - Don't Fade Away.mp3
3104	2872	3103	3102	2012-11-30 05:10:47+00	0	\N	ba6b94da5055164e28ea55ddd361411b9bc3002ca7c3453de7c422e701a6e3b8	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/04 - Dead Can Dance - Yulunga (Spirit Dance).mp3
3105	2872	3103	2949	2012-11-30 05:10:48+00	0	\N	a33872b80053dce2e0aa27398696ea94b2dd8de8c6e8573fc2eb9e432b56697b	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/08 - Dead Can Dance - I Can See Now.mp3
3110	2872	3103	3109	2012-11-30 05:10:49+00	0	\N	15a308c4c7f9e90757bb1e3c776a0e08ac9382d337100ffa7ea6dcd1978e5cb6	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/12 - Dead Can Dance - The Song Of The Sibyl.mp3
3112	2872	3103	3111	2012-11-30 05:10:50+00	0	\N	f7619ea88b037cf0f3dcd914dbe3890c7b78ec177c9b92c1dcea05cd8ec24a71	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/03 - Dead Can Dance - Desert Song.mp3
3114	2872	3103	2963	2012-11-30 05:10:50+00	0	\N	0a398d5c16bd98b97c108d574833f9db03dd7db5366a53df593a3c08ec3edb9f	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/14 - Dead Can Dance - Sanvean.mp3
3117	2872	3103	3116	2012-11-30 05:10:51+00	0	\N	69d0d7133815075bec6c4dccb6febb5de20be82190decc527e358b82a758ea1f	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/07 - Dead Can Dance - I Am Stretched On Your Grave.mp3
3119	2872	3103	3118	2012-11-30 05:10:51+00	0	\N	c6ef80ff64f2fd2a3a1c4c3660b1026b34c444cabd184699b798181c767f6815	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/02 - Dead Can Dance - Persian Love Song.mp3
2629	2611	2608	2628	2012-11-30 05:09:12+00	0	\N	54b9f5381c449fc6eb2f15de3e5bfc803ad5a22545a0287ca4783d4d1e92176b	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 6 - Tchaikovsky/10-Eugene Onegin- Polonaise.mp3
3120	2872	3103	2957	2012-11-30 05:10:52+00	0	\N	39ee76d942b0d732cae21dd90368e938a492b9211084b46f8c8960fcfd1c41c1	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/01 - Dead Can Dance - Rakim.mp3
3122	2872	3103	3121	2012-11-30 05:10:52+00	0	\N	e2f40a6a57c10404da7726c0a745621b1a846b28aaa0f4257488d614d1ed9ee1	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/05 - Dead Can Dance - Piece For Solo Flute.mp3
3123	2872	3103	2959	2012-11-30 05:10:52+00	0	\N	d25acef8dc174926b19b5d0243580652abfd8b8f4a984e60d019b4f709f62018	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/09 - Dead Can Dance - American Dreaming.mp3
3143	2872	3140	3142	2012-11-30 05:10:56+00	0	\N	4cbc2abf31af9e447f88c0ce95bc675872bc83c6c09607e55c7944308e0d8e69	/home/extra/user/torrents/Dead Can Dance/1990 - Aion/03 - Dead Can Dance - Mephisto.mp3
3125	2872	3103	3124	2012-11-30 05:10:53+00	0	\N	1a46f59b3f4cc25c936dc045ef872000a376fc8195b6cad457b356efe6c29186	/home/extra/user/torrents/Dead Can Dance/1994 - Toward The Within/06 - Dead Can Dance - The Wind That Shakes The Barley.mp3
3128	2872	3127	3126	2012-11-30 05:10:53+00	0	\N	0e30172b6d585bfb93147453da7dd5123f4954440a08e750194657a32546ab9b	/home/extra/user/torrents/Dead Can Dance/1987 - Within The Realm Of A Dying Sun/03 - Dead Can Dance - In The Wake Of Adversity.mp3
3165	3159	3160	3164	2012-11-30 05:11:00+00	0	\N	6038b900cc36740f72cca25994bf6186e2ed78bca0b0b2dac3455071212bf038	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1998 - Duality/10 - Lisa Gerrard - Nadir (Synchronicity).mp3
3130	2872	3127	3129	2012-11-30 05:10:53+00	0	\N	138bb0cf02b7d6112363534c02956eb034a0b8f2b50dd21632843157e1e8f00f	/home/extra/user/torrents/Dead Can Dance/1987 - Within The Realm Of A Dying Sun/05 - Dead Can Dance - Dawn Of The Iconoclast.mp3
3145	2872	3140	3144	2012-11-30 05:10:57+00	0	\N	f56465bb7cef73a7035b38e541ef29bbb22a4f139cae4ba1e71c86b8c6fb4fb0	/home/extra/user/torrents/Dead Can Dance/1990 - Aion/07 - Dead Can Dance - The End Of Words.mp3
3131	2872	3127	2891	2012-11-30 05:10:54+00	0	\N	5af13e30f27edc543dc862cf46988daec8b8f132b796caf5ac41a23be6bf273a	/home/extra/user/torrents/Dead Can Dance/1987 - Within The Realm Of A Dying Sun/02 - Dead Can Dance - Windfall.mp3
3133	2872	3132	2885	2012-11-30 05:10:54+00	0	\N	95d8f8ab040e7fa000659112ca4e9a3dae79db9d8185318f9a64afe08c8e2729	/home/extra/user/torrents/Dead Can Dance/1987 - Within The Realm Of A Dying Sun/07 - Dead Can Dance - Summoning Of The Muse.mp3
3153	2872	3140	3152	2012-11-30 05:10:58+00	0	\N	dba534a26899496458099c287ef2cab091d9c917ea28590eb2a9d4f2d3b5f2a8	/home/extra/user/torrents/Dead Can Dance/1990 - Aion/12 - Dead Can Dance - Radharc.mp3
3134	2872	3127	2979	2012-11-30 05:10:54+00	0	\N	5537c5a876e2d29e6412824ed72496291e3fb3dd0d9c1c5c8c98541f82d8fb18	/home/extra/user/torrents/Dead Can Dance/1987 - Within The Realm Of A Dying Sun/01 - Dead Can Dance - Anywhere Out Of The World.mp3
3147	2872	3140	3146	2012-11-30 05:10:57+00	0	\N	6bff51c6264c0813173d4db004b041d6e9a54cb2b597589de758a80bedf9b20e	/home/extra/user/torrents/Dead Can Dance/1990 - Aion/01 - Dead Can Dance - The Arrival And The Reunion.mp3
3135	2872	3127	2903	2012-11-30 05:10:55+00	0	\N	8b1a12fbd2730886763a1ffc61e11cd0d2b1eca9aed1189dc7f9c67b4b6a87a4	/home/extra/user/torrents/Dead Can Dance/1987 - Within The Realm Of A Dying Sun/06 - Dead Can Dance - Cantara.mp3
3137	2872	3132	3136	2012-11-30 05:10:55+00	0	\N	7429d7e6ea69edea3641344bffd0272f9f5d161f80aec700fbcd860e956e87c3	/home/extra/user/torrents/Dead Can Dance/1987 - Within The Realm Of A Dying Sun/08 - Dead Can Dance - Persephone (The Gathering Of Flowers).mp3
3139	2872	3127	3138	2012-11-30 05:10:56+00	0	\N	0cd087f3a7188cb47e9800ad82e0377636ab90c1f385b6e307eaaa87ad4839b9	/home/extra/user/torrents/Dead Can Dance/1987 - Within The Realm Of A Dying Sun/04 - Dead Can Dance - Xavier.mp3
3148	2872	3140	2969	2012-11-30 05:10:57+00	0	\N	7d52a19adba574e47444e84a377e9375057c6c171fb585d652628a6acf85c48c	/home/extra/user/torrents/Dead Can Dance/1990 - Aion/05 - Dead Can Dance - Fortune Presents Gifts Not According To The Book.mp3
3141	2872	3140	2982	2012-11-30 05:10:56+00	0	\N	1ac9b685b3ddec003a4a2a16b2ab294ad336ebcdc8fbe207c71081c7146a9ebc	/home/extra/user/torrents/Dead Can Dance/1990 - Aion/09 - Dead Can Dance - Wilderness.mp3
3161	3159	3160	3158	2012-11-30 05:10:59+00	0	\N	9a375ecf7b727906ad65e79d54c79ca8fe7cdfdb6b8cf2f0f1fe1d1cb16c75fe	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1998 - Duality/07 - Lisa Gerrard - The Human Game.mp3
3155	2872	3140	3154	2012-11-30 05:10:58+00	0	\N	91b9bd4b40d7d9d5c33b628dddcf6a446d2dd789e879ee080df32272170afd48	/home/extra/user/torrents/Dead Can Dance/1990 - Aion/06 - Dead Can Dance - As The Bell Rings The Maypole Spins.mp3
3149	2872	3140	2938	2012-11-30 05:10:57+00	0	\N	a8c5d9fd78a6e9b7fc089135c496d7174c9e0c043ffd8fb957aa1d81b09a15a0	/home/extra/user/torrents/Dead Can Dance/1990 - Aion/08 - Dead Can Dance - Black Sun.mp3
3150	2872	3140	2984	2012-11-30 05:10:58+00	0	\N	06b6f6572d09171d5d433d24cc1c469f23ac7c56e43525aece8657ab2b4a66e0	/home/extra/user/torrents/Dead Can Dance/1990 - Aion/04 - Dead Can Dance - The Song Of The Sibyl.mp3
3151	2872	3140	2920	2012-11-30 05:10:58+00	0	\N	1f14283b16ba1f8b4ae93c32c47d4343e1c13608ca14ed3cd7b669613827fa43	/home/extra/user/torrents/Dead Can Dance/1990 - Aion/10 - Dead Can Dance - The Promised Womb.mp3
3156	2872	3140	2940	2012-11-30 05:10:59+00	0	\N	e35190e489223d9e7723ac8a5a7c2e541f6447ba071445c9ceb3a9f6df1ee543	/home/extra/user/torrents/Dead Can Dance/1990 - Aion/02 - Dead Can Dance - Saltarello.mp3
3157	2872	3140	2994	2012-11-30 05:10:59+00	0	\N	81cafe926c906b11012440886f5c33e7f75f7734f23ac968ae13dd1ded69f65a	/home/extra/user/torrents/Dead Can Dance/1990 - Aion/11 - Dead Can Dance - The Garden Of Zephirus.mp3
3163	3159	3160	3162	2012-11-30 05:11:00+00	0	\N	25f50287a0afbb04d7753abf50762ba41c6dfcd04918a8830d1d6bbe9d50900b	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1998 - Duality/03 - Lisa Gerrard - Forest Veil.mp3
3168	3167	3160	3166	2012-11-30 05:11:01+00	0	\N	3e0291ddab8e5e6c31db63f1540eeaa5f9693454a36474045b596b8d6b6db4d1	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1998 - Duality/08 - Lisa Gerrard - The Circulation Of Shadows.mp3
3170	3159	3160	3169	2012-11-30 05:11:01+00	0	\N	d030aa70d71149db8c81660b31eb0901585f69ce49124c450dc9e268eef3994b	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1998 - Duality/02 - Lisa Gerrard - Tempest.mp3
3172	3159	3160	3171	2012-11-30 05:11:01+00	0	\N	780eafad0e5dd27217375d547a8b235449035189719d318cdbe01edce47785cb	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1998 - Duality/09 - Lisa Gerrard - Sacrifice.mp3
3174	3159	3160	3173	2012-11-30 05:11:02+00	0	\N	2b431aed2935d9962ed7d827f9b62c5542a18f46d5b81f8e3e50ffde9f54a548	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1998 - Duality/06 - Lisa Gerrard - Pilgrimage Of Lost Children.mp3
3176	3159	3160	3175	2012-11-30 05:11:02+00	0	\N	ea86627ffbd31c638a8b6cabb2cf54bf3f85da0947cb9ef304912b09a20034e0	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1998 - Duality/01 - Lisa Gerrard - Shadow Magnet.mp3
3213	3167	3182	3212	2012-11-30 05:11:09+00	0	\N	fd53d8a4c7bf04fd580a1fe2f0f8a8899c1f4207a78562c5ea75c5d9e0bbe8eb	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/15 - Lisa Gerrard - Nilleshna.mp3
3178	3159	3160	3177	2012-11-30 05:11:03+00	0	\N	549bd839c9d80c1baa42a6ef38ff495ad5bceb9c76f84c62152bbecd806b6501	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1998 - Duality/05 - Lisa Gerrard - The Unfolding.mp3
3201	3167	3182	3200	2012-11-30 05:11:06+00	0	\N	e42687af25e43ddbc50523201e5ce8f9213cd7761c777f5dafdecf4065aa41e9	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/10 - Lisa Gerrard - Werd.mp3
3180	3167	3160	3179	2012-11-30 05:11:03+00	0	\N	2286209f93728f26ea19ad61b395c7458febea9e9f592f70e473d57b938057b6	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1998 - Duality/04 - Lisa Gerrard - The Comforter.mp3
3183	3167	3182	3181	2012-11-30 05:11:03+00	0	\N	22232f77e3509aa7977dc17f43d91f0410a1d1ba1eb9177200d022505babd92d	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/08 - Lisa Gerrard - Majhnavea's Music Box.mp3
3185	3167	3182	3184	2012-11-30 05:11:03+00	0	\N	7fdf5b29a6fe8959c19afacdce89d86125cc141c52a3378fa53a13778313a465	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/01 - Lisa Gerrard - Violina (The Last Embrace).mp3
3203	3167	3182	3202	2012-11-30 05:11:07+00	0	\N	0c8433f8aaf73a2ec8357ac659c595b03e17ba03351af64c541c578f98c069d2	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/06 - Lisa Gerrard - Ajhon.mp3
3187	3167	3182	3186	2012-11-30 05:11:04+00	0	\N	5b090fc9164be49dfcbe6b182fac073d4eaafb3837bd310d0fd45ccc2f362bfa	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/02 - Lisa Gerrard - La Bas (Song Of The Drowned).mp3
3189	3167	3182	3188	2012-11-30 05:11:04+00	0	\N	5b7e3c120d5f717a5876a46999b1ab64df94d0b8c8d87570a595045a0b13c717	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/07 - Lisa Gerrard - Glorafin.mp3
3223	\N	\N	3222	2012-11-30 05:11:11+00	0	\N	ae6b8d1ea5501d542edf05710c8f1e5cd8bc541ccdfe80dac17c75811e7d3cbc	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Patrick Cassidy - Immortal Memory/ 03. Lisa Gerrard & Patrick Cassidy - Amergin's Invocation.mp3
3191	3167	3182	3190	2012-11-30 05:11:05+00	0	\N	1677709e8572180d1f5705041cc202158415dcc65df4c11f07197a6cb5444335	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/04 - Lisa Gerrard - Sanvean (I Am Your Shadow).mp3
3193	\N	\N	3192	2012-11-30 05:11:05+00	0	\N	6d08abe10b9788a0196daa0f691bb690a43ece28a5a838c0fbbc96ecc3f07eac	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/Lisa Gerrard - The Mirror Pool - 17 - Bonus track.mp3
3205	3167	3182	3204	2012-11-30 05:11:07+00	0	\N	a98c6c2ebffab3a3dbf0ab617622a7cc0a89fa27421ca7c87aecbe26900b0d65	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/16 - Lisa Gerrard - Gloradin.mp3
3195	3167	3182	3194	2012-11-30 05:11:05+00	0	\N	7726e160b1dddfcff0447a6d0ba452e275522e26e83c84a0afde8096698e48cc	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/09 - Lisa Gerrard - Largo.mp3
3197	3167	3182	3196	2012-11-30 05:11:05+00	0	\N	8ddced1e31eda96af57e08fb30487a65afdf1576824989707e1b5e66a880f366	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/14 - Lisa Gerrard - Swans.mp3
3215	3167	3182	3214	2012-11-30 05:11:09+00	0	\N	bc295bd0abdfa74b142a1a13e7bd0bb64a9d14c27b67cd7d01d5d2508118a578	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/03 - Lisa Gerrard - Persian Love Song (The Silver Gun).mp3
3199	3167	3182	3198	2012-11-30 05:11:06+00	0	\N	dcea788770a07329f08cec17e1e4a072c188292e46136a740c372112fe51cb16	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/12 - Lisa Gerrard - Celon.mp3
3207	3167	3182	3206	2012-11-30 05:11:07+00	0	\N	0a564341d9620b2ae0d9726c2d62d6cfdc81d07396b1e309518583dff37bb167	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/11 - Lisa Gerrard - Laurelei.mp3
3209	3167	3182	3208	2012-11-30 05:11:08+00	0	\N	10c3da2589c842a704215a7167d94cfc5ad2bb9d95763872064d333c7db9f5fd	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/13 - Lisa Gerrard - Venteles.mp3
3217	\N	\N	3216	2012-11-30 05:11:09+00	0	\N	8ed085ffc3f5aca43d9ba1d0d6de91a5ba6c79a10ecf93deb54eb0cb8adaaa97	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Patrick Cassidy - Immortal Memory/ 06. Lisa Gerrard & Patrick Cassidy - Abwoon (Our Father).mp3
3211	3167	3182	3210	2012-11-30 05:11:08+00	0	\N	45c483f92f6bd458412e24aab61e1b886caf1e70e805a5a30256cd936cfab95a	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/1995 - The Mirror Pool/05 - Lisa Gerrard - The Rite.mp3
3219	\N	\N	3218	2012-11-30 05:11:10+00	0	\N	d338b1dd8956b161a148af837437b9dc3371f8b3702c57083e6664babafff64c	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Patrick Cassidy - Immortal Memory/ 04. Lisa Gerrard & Patrick Cassidy - Elegy.mp3
3221	\N	\N	3220	2012-11-30 05:11:10+00	0	\N	d39d74dfdc837f1272885783b3c5586d2b8de3f96d4b42389d99fb64ed696191	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Patrick Cassidy - Immortal Memory/ 10. Lisa Gerrard & Patrick Cassidy - Psallit in Aure Dei.mp3
3225	\N	\N	3224	2012-11-30 05:11:11+00	0	\N	87bfa1cf4a73b70fecaa6843b0acd4853f6c4f31f9b7212d8cb03c1deeb4ff9a	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Patrick Cassidy - Immortal Memory/ 02. Lisa Gerrard & Patrick Cassidy - Maranatha (Come Lord).mp3
3227	\N	\N	3226	2012-11-30 05:11:12+00	0	\N	a7b1811892f0b7afa6f1dc6808ae785a93c28057c2a2b11ace6c8d6433d33251	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Patrick Cassidy - Immortal Memory/ 07. Lisa Gerrard & Patrick Cassidy - Immortal Memory.mp3
3229	\N	\N	3228	2012-11-30 05:11:12+00	0	\N	62fbb44a3e9624c91ea8ec4cacb5fcbc0b794cf9016f6a66342daf6de8649b08	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Patrick Cassidy - Immortal Memory/ 05. Lisa Gerrard & Patrick Cassidy - Sailing to Byzantium.mp3
3231	\N	\N	3230	2012-11-30 05:11:12+00	0	\N	5c61426dac02bddd1e077163a1decec5c803d2d9cf8ed6afacbaf2f70f5128d8	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Patrick Cassidy - Immortal Memory/ 09. Lisa Gerrard & Patrick Cassidy - I Asked for Love.mp3
3233	\N	\N	3232	2012-11-30 05:11:13+00	0	\N	2974557b4807162b9f192252b00011074586e03b36f93443cfad4f2e3c14e074	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Patrick Cassidy - Immortal Memory/ 01. Lisa Gerrard & Patrick Cassidy - The Song of Amergin.mp3
3235	\N	\N	3234	2012-11-30 05:11:13+00	0	\N	9a2be0d1414e6883c3c07a8d68e0ff802d6709880784977cbd4426c0725d0f42	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Patrick Cassidy - Immortal Memory/ 08. Lisa Gerrard & Patrick Cassidy - Paradise Lost.mp3
3257	3237	3238	3256	2012-11-30 05:11:16+00	0	\N	6186749c7eaae5cf3e53accf4209b4c764b44ac3b2c2926f8a0ade8f409d3b34	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/2006 - Ashes and Snow - Lisa Gerrard & Patrick Cassidy - BSO 192/07 - Slow Dawn.mp3
3239	3237	3238	3236	2012-11-30 05:11:14+00	0	\N	db5261952f2bf5b910598a2b9a47e76ac59eee9f36284785b408babf55626188	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/2006 - Ashes and Snow - Lisa Gerrard & Patrick Cassidy - BSO 192/02 - Pasadena.mp3
3241	3237	3238	3240	2012-11-30 05:11:14+00	0	\N	b05559e1598c87bf0331d3e6a40dbc35f3d50cb58cab339d04b8d69db313badd	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/2006 - Ashes and Snow - Lisa Gerrard & Patrick Cassidy - BSO 192/12 - Badnamgar.mp3
3277	3263	3264	3276	2012-11-30 05:11:19+00	0	\N	9717d031e326f0ac0f25ce8d0c253a42292213cddc143c7a23c8daf6e784be3e	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/14-Who are We to Say (vocal).mp3
3243	3237	3238	3242	2012-11-30 05:11:14+00	0	\N	02763fbe485e609413eb95ce253f27dcf6ed3668482e23da3f78d07b3c5cd511	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/2006 - Ashes and Snow - Lisa Gerrard & Patrick Cassidy - BSO 192/11 - Tears Of Light.mp3
3259	3237	3238	3258	2012-11-30 05:11:17+00	0	\N	90d53df83a906eeac22227d41f8a65048f90882572f87f6f3bd35550b894025a	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/2006 - Ashes and Snow - Lisa Gerrard & Patrick Cassidy - BSO 192/08 - Elephant Pond.mp3
3245	3237	3238	3244	2012-11-30 05:11:14+00	0	\N	6590798ba601c64a15712e81c9e82b2f84531600ba565b92b8b19de234cc6cf3	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/2006 - Ashes and Snow - Lisa Gerrard & Patrick Cassidy - BSO 192/10 - Wisdom.mp3
3247	3237	3238	3246	2012-11-30 05:11:15+00	0	\N	9119163e020614a582a04d95b9d5f3ce40a3182a2f2b0a1ecf42a8c085ff4e95	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/2006 - Ashes and Snow - Lisa Gerrard & Patrick Cassidy - BSO 192/03 - Slow River.mp3
3271	3263	3264	3270	2012-11-30 05:11:18+00	0	\N	48a6167dc453ad037df94ef6e0e1853a584edb3e4ee49d1ff1825eb28fcb3327	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/07-The Northern Lights.mp3
3249	3237	3238	3248	2012-11-30 05:11:15+00	0	\N	11208eab3a989f78a74d7a93cf43718565672fd469131def61cae3afadb45c1d	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/2006 - Ashes and Snow - Lisa Gerrard & Patrick Cassidy - BSO 192/09 - The Absence Of Time.mp3
3261	3237	3238	3260	2012-11-30 05:11:17+00	0	\N	1d45f5a107bb0b3773d4bdd72cccf9fcc053b111e360ba7ce0bdcbceb982782e	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/2006 - Ashes and Snow - Lisa Gerrard & Patrick Cassidy - BSO 192/04 - Mater Mea.mp3
3251	3237	3238	3250	2012-11-30 05:11:15+00	0	\N	d033b73edc62fec1ee50856cea9b12d86067e75641413bd947bee081969b0a0f	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/2006 - Ashes and Snow - Lisa Gerrard & Patrick Cassidy - BSO 192/01 - Devota.mp3
3253	3237	3238	3252	2012-11-30 05:11:16+00	0	\N	0759dbafa4d178c676b7a67c1e4808fc5082c7934b2d3f1340061129b3fff125	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/2006 - Ashes and Snow - Lisa Gerrard & Patrick Cassidy - BSO 192/05 - Vespers.mp3
3255	3237	3238	3254	2012-11-30 05:11:16+00	0	\N	d4fb195427f7622c2b1568fd3f57fc938e07e669599bbf8ac023b164c4c32e25	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/2006 - Ashes and Snow - Lisa Gerrard & Patrick Cassidy - BSO 192/06 - Womb.mp3
3265	3263	3264	3262	2012-11-30 05:11:17+00	0	\N	4159d7ce97c5f0f14e35e06f77ee12ad0e2d2080fa2ab57349388fccc2854d17	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/12-A Thousand Roads.mp3
3273	3263	3264	3272	2012-11-30 05:11:18+00	0	\N	7335f0b66b9723ce326123cec9ac415554272bef11e3715604629c00a087faa9	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/06-Dawn Across the Snow.mp3
3267	3263	3264	3266	2012-11-30 05:11:17+00	0	\N	0fd53ff6db1145232f847af25b5cd6edbbe46e66242be976a74a0d862cec28f3	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/05-All your Relatives.mp3
3269	3263	3264	3268	2012-11-30 05:11:18+00	0	\N	61a20caed50158bab93136c241d22d25c10ae29dc621aee7e4f1387dc1392916	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/19-Song of the Trees.mp3
3281	3263	3264	3280	2012-11-30 05:11:20+00	0	\N	a847b0a347c5fa01f11e1a74c14f3d70599f59dae905327c1ba271cf80fe268f	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/09-Walk in a Beauty's Way.mp3
3275	3263	3264	3274	2012-11-30 05:11:18+00	0	\N	44203553f64d6abe182d9cd5dae09498fc05432b1da35c9b7f1117d5a8aaa652	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/11-Who Are We to Say.mp3
3279	3263	3264	3278	2012-11-30 05:11:19+00	0	\N	d3df64f9c69b6a8893606d6d3d6c7a057ba6c9a150927b57b0467d2d948b1d42	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/10-A Healer's Life.mp3
3283	3263	3264	3282	2012-11-30 05:11:20+00	0	\N	ba2328801b4342abe248f6301a5db947de8f1114a6cbd86b70a5a1b62d2b6836	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/08-Johnny in the Dark.mp3
3285	3263	3264	3284	2012-11-30 05:11:20+00	0	\N	1427c813ce4cc410b979408d3306f6801415469112f948bc9fea3ddd4f029695	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/18-All My Relations.mp3
3287	3263	3264	3286	2012-11-30 05:11:21+00	0	\N	009c42d66d7379a2b4153bfb82b84327cc2916797bfbdfb618ddd4bd431cc2c1	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/04-Coming to Barrow.mp3
2689	2604	2669	2688	2012-11-30 05:09:21+00	0	\N	fb61a794db930e34f49c99a664dfc3e0da6863e276a0c5faddcf3c4e5194b7c7	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/04-Oboe Concerto in D minor- Adagio.mp3
3289	3263	3264	3288	2012-11-30 05:11:21+00	0	\N	416e8ebb7c8dbf107710fc3c419d0872e748e4347d5a81d62ae7586805d4837a	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/20-Crazy Horse.mp3
3291	3263	3264	3290	2012-11-30 05:11:21+00	0	\N	97bc9b8e44553fc494160a4caacf9e8e74719187066759063c284a591b02f0db	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/03-Canyons of Manhattan.mp3
3314	3167	3305	3313	2012-11-30 05:11:24+00	0	\N	669182a217c501bdf0aced4d23f56b1d1e6e6a1b2c70ecd3f5497adb24777e2a	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/06. Lisa Gerrard - Suitcase.mp3
3293	3263	3264	3292	2012-11-30 05:11:21+00	0	\N	2b0ab998a50453b6cf7ba7b164dd1c4c2e00b9f10094939f0884c859aa0ae0a9	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/17-Mahk Jchi.mp3
3295	3263	3264	3294	2012-11-30 05:11:22+00	0	\N	cf10d461540ee595b6a6d483424ea5bba61e4e279959f110549c139f3428cdf2	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/16-Nemi.mp3
3297	3263	3264	3296	2012-11-30 05:11:22+00	0	\N	874e1a665d65026fa56ab1a9992c3cf5c2653224de4df5d803dd4c86b8762f44	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/13-End Titles.mp3
3316	3167	3305	3315	2012-11-30 05:11:24+00	0	\N	dd8cf1afb5443963acba2de53d6f7e99fa59432b28383e303ff70619d6b3bed3	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/08. Lisa Gerrard - Reiputa.mp3
3299	3263	3264	3298	2012-11-30 05:11:22+00	0	\N	ec9f70da39f7402300b8c02ad9355508878a23be7a990bfbb6c45b2e6f70296f	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/01-Good Morning Indian Country.mp3
3301	3263	3264	3300	2012-11-30 05:11:23+00	0	\N	628ae105af83883c14c22375d534e9b9b003729b828eb7cb322a2e01c92fd5b7	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/02-Rowing Warriors.mp3
3328	3167	3305	3327	2012-11-30 05:11:26+00	0	\N	b5f557657ebec78af6872d7f99cd1b9a757f4ca08799228759613fbf0b0436d9	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/13. Lisa Gerrard - Empty Water.mp3
3303	3263	3264	3302	2012-11-30 05:11:23+00	0	\N	75605ac6dd8e8fecd382c1b5e90e7c5fd6bca675b6279f50bae14ea5733bcc1f	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Jeff Rona/A Thousand Roads/15-Shaman's Call.mp3
3318	3167	3305	3317	2012-11-30 05:11:25+00	0	\N	8def3a0dca4100de225517c5a070ad51a0869f4e60cbf3d9581a529edca0a14c	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/05. Lisa Gerrard - Ancestors.mp3
3306	3167	3305	3304	2012-11-30 05:11:23+00	0	\N	1ba50ee1453d79e0e3fe27454446ef5cb91ec615ff729549cc3165a3e9a8911a	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/07. Lisa Gerrard - Pai Calls the Whales.mp3
3308	3167	3305	3307	2012-11-30 05:11:23+00	0	\N	8ef4577e442d3f748fe0df19453df277edb30c335fe235d7a199e43e4878a015	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/15. Lisa Gerrard - Go Forward.mp3
3310	3167	3305	3309	2012-11-30 05:11:24+00	0	\N	d17befabd2f9153cfd8e001a9f098fd64c82442d757145b9d0d2477ee6bfa110	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/11. Lisa Gerrard - Pai Theme.mp3
3320	3167	3305	3319	2012-11-30 05:11:25+00	0	\N	2ce040e5b25131d70598652f77916989eea0297eab8f3c7d916900de5ac4e4e2	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/01. Lisa Gerrard - Paikea Legend.mp3
3312	3167	3305	3311	2012-11-30 05:11:24+00	0	\N	1e805b1510cef5283436e787831fe0b7a1e885320ce367e3a0cbe62067d543fb	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/02. Lisa Gerrard - Journey Away.mp3
3337	3159	3336	3335	2012-11-30 05:11:26+00	0	\N	3f1578656552015d691a5809346b68026f659a30b0d5cf260051ba8e79d0cf66	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/16 - Lisa Gerrard, Pieter Bourke , Meltdown.mp3
3330	3167	3305	3329	2012-11-30 05:11:26+00	0	\N	f85b9baba20b96ba0a9a663f56c89fdbc1ec3019acd15d30bed260f03e28e189	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/09. Lisa Gerrard - Disappointed.mp3
3322	3167	3305	3321	2012-11-30 05:11:25+00	0	\N	6a1f5c34b635a1e3ac468f6e526cd38e3de90811bc78f667a805d32bbda33021	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/04. Lisa Gerrard - Biking Home.mp3
3324	3167	3305	3323	2012-11-30 05:11:25+00	0	\N	7c05bf584607fd9616321dca50e525b2dc06e6f22c9adc73e2db823899e23147	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/10. Lisa Gerrard - They Came To Die.mp3
3326	3167	3305	3325	2012-11-30 05:11:26+00	0	\N	1175c60405ba0def186b75bea7a9e34b87326f7c9f05f48d61fc4bddbdd781bb	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/03. Lisa Gerrard - Rejection.mp3
3332	3167	3305	3331	2012-11-30 05:11:26+00	0	\N	12398685839ee0f781b1e8671973e476637d4756c93ce8804cea1b680b0fb17e	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/14. Lisa Gerrard - Waka In The Sky.mp3
2692	2691	2669	2690	2012-11-30 05:09:21+00	0	\N	2b537fab209e2859e1dd90c545f5c4b3a37131ce00f0e2ed6ca839443eeec82c	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 2 - J. S. Bach/12-Violin Concerto in E major, BWV 1042- Adagio.mp3
3334	3167	3305	3333	2012-11-30 05:11:26+00	0	\N	a1d7402cb5f1d6def82e9c68a0ecf73966ab65c915a568469088681baecad3ab	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard - Whale Rider/12. Lisa Gerrard - Paikeas Whale.mp3
3339	3159	3336	3338	2012-11-30 05:11:26+00	0	\N	96fb02c1918577fdbd7e9d545090a190a6e4f695ef554e733528807cb67be266	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/07 - Lisa Gerrard, Pieter Bourke , Broken.mp3
3341	3159	3336	3340	2012-11-30 05:11:27+00	0	\N	8bac72e1487ec3200cbbb38274645a3626c3889121ec820120270269c6b003df	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/15 - Massive Attack , Safe from Harm - Perfecto Mix.mp3
3343	3159	3336	3342	2012-11-30 05:11:27+00	0	\N	d8f0c0775d8b4895efb964b72f1256d5561433bb6df4f10ec582a4636a0720fd	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/11 - Graeme Revell , Palladino Montage.mp3
3345	3159	3336	3344	2012-11-30 05:11:27+00	0	\N	cda8254c56b79a9b022dacb8ab03529823b7851d4a21d4455d3335c22fde52cd	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/04 - Lisa Gerrard, Pieter Bourke , The Subordinate.mp3
3347	3159	3336	3346	2012-11-30 05:11:27+00	0	\N	18c26044e3036a6ceac75896548759d31985a9aebb232ec3f963af7e42f8b0f4	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/12 - Gustavo Santaolalla , Iguazu.mp3
3367	3159	3336	3366	2012-11-30 05:11:29+00	0	\N	a9fefad607df37a4078f5ac3319ced351d119f1b8a165283f35eacb9f5099c4d	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/13 - Lisa Gerrard, Pieter Bourke , Liquid Moon.mp3
3349	3159	3336	3348	2012-11-30 05:11:28+00	0	\N	56608450f28e3f2b1dc7afc81e6102596e990e42cdadc85951643077ae8d6047	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/02 - Lisa Gerrard, Pieter Bourke , Dawn of the Truth.mp3
3351	3159	3336	3350	2012-11-30 05:11:28+00	0	\N	8ff611659558f67abc8ba789adac46eb25933559712c35b8f609ee2555c63d66	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/03 - Lisa Gerrard, Pieter Bourke , Sacrifice.mp3
3379	3369	3370	3378	2012-11-30 05:11:31+00	0	\N	9ab462f8f407ca587d4937033cb19d10a672610a2f55f5a4cb3cdfc5dbedd898	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/15 - Hans Zimmer and Lisa Gerrard - Elysium.mp3
3353	3159	3336	3352	2012-11-30 05:11:28+00	0	\N	fef405364d10413153e14307c70d7051b21f2f8cd611791414857ad383832ffe	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/05 - Lisa Gerrard, Pieter Bourke , Exile.mp3
3371	3369	3370	3368	2012-11-30 05:11:30+00	0	\N	9535b787d74cda4980f3908958173f9d91263761cb465a13709fb87d925843a2	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/06 - Hans Zimmer and Lisa Gerrard - To Zucchabar.mp3
3355	3159	3336	3354	2012-11-30 05:11:28+00	0	\N	a5d377b7ddb2542bd23a570edb1e10ec2e5c6fd3f3c55cce4909ba9f7ff85810	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/14 - Jan Garbarek , Rites - Special Edit for the Film.mp3
3357	3159	3336	3356	2012-11-30 05:11:29+00	0	\N	34528ad72397d51972cf59afde954565565a0a5418cbcd40f373fd5cb45160ec	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/10 - Graeme Revell , LB in Montana.mp3
3359	3159	3336	3358	2012-11-30 05:11:29+00	0	\N	588830c7184a9200e31ab1840bce81289c0317942086e1c2da2e020b2d6e5c33	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/08 - Lisa Gerrard, Pieter Bourke , Faith.mp3
3373	3369	3370	3372	2012-11-30 05:11:30+00	0	\N	3d7f5b0b7a9b0ea5d212997fc6d80a1ea7de930540f2cbaa32f44a8755c21999	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/13 - Hans Zimmer and Lisa Gerrard - Barbarian Horde.mp3
3361	3159	3336	3360	2012-11-30 05:11:29+00	0	\N	f946bc7e7c00be09cc7313ee3289ab08fe397daffb5db900355294fa97a1ec5a	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/06 - Lisa Gerrard, Pieter Bourke , The Silencer.mp3
3363	3159	3336	3362	2012-11-30 05:11:29+00	0	\N	3663aa03813ce9c678ebfb5e752aba26e1a632d016cd8d58f028dac75cffa776	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/01 - Lisa Gerrard, Pieter Bourke , Tempest.mp3
3365	3159	3336	3364	2012-11-30 05:11:29+00	0	\N	36ac5da765921fd3f889b8da48703d8304e6304a5b8f66d459db8f9f5908948f	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Lisa Gerrard & Pieter Bourke - The Insider (1999 mp3+cover)/09 - Graeme Revell , I'm Alone on This.mp3
3381	3369	3370	3380	2012-11-30 05:11:31+00	0	\N	f7e7fd3bc13de06d7e7c856862cb1ce305311ae27d58a393a91da9a02a05f41d	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/07 - Hans Zimmer and Lisa Gerrard - Patricide.mp3
3375	3369	3370	3374	2012-11-30 05:11:30+00	0	\N	29f8c58e28a58791291fcf7c31fc41aa72478d42c691ac1b2e7b4590fcb5da74	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/03 - Hans Zimmer and Lisa Gerrard - The Battle.mp3
3377	3369	3370	3376	2012-11-30 05:11:31+00	0	\N	8b84ebb9dad5edd125f80d745ac74f3977e234eb6271f020c6154eee502b0f11	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/08 - Hans Zimmer and Lisa Gerrard - The Emperor Is Dead.mp3
3385	3369	3370	3384	2012-11-30 05:11:32+00	0	\N	293eee3d1314a93cd6c279e9173cfe1e1510783bb6fe5af6dd0505a153fb3ff7	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/01 - Hans Zimmer and Lisa Gerrard - Progeny.mp3
3383	3369	3370	3382	2012-11-30 05:11:31+00	0	\N	85ac5dd3d79215f8efe71bf5e8bbf6b780043cdaf8d7ee4376cffdbc912cf6d3	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/16 - Hans Zimmer and Lisa Gerrard - Honor Him.mp3
3389	3369	3370	3388	2012-11-30 05:11:32+00	0	\N	fd6ef795e76671fd0dc4db1e62806c6981ca57691184674298cdf131b3412159	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/10 - Hans Zimmer and Lisa Gerrard - Strength And Honor.mp3
3387	3369	3370	3386	2012-11-30 05:11:32+00	0	\N	2d7333d71c1046cdcc7067ed212a0a6532a4fbdbd09ea6c33d5dcdc55b2cc5d5	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/12 - Hans Zimmer and Lisa Gerrard - Slaves To Rome.mp3
3391	3369	3370	3390	2012-11-30 05:11:32+00	0	\N	9ac0983ddb9eb497715d3f7f833d779b5fb92c15c9a8253ed1fd7bd028cdea6e	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/14 - Hans Zimmer and Lisa Gerrard - Am I Not Merciful .mp3
3393	3369	3370	3392	2012-11-30 05:11:32+00	0	\N	fcc6c43737edd5055c0e11e12f108255fdf8daf51ab9a1a7f277d5877b6f9714	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/09 - Hans Zimmer and Lisa Gerrard - The Might Of Rome.mp3
3490	\N	\N	3489	2012-11-30 05:11:54+00	0	\N	ef03b5543898eeb09c318349e387b525a8e3b4eecbfff764263e7acefa7caaba	/home/extra/user/podcasts/News/Free Speech Radio Documentaries/20111124hifi.mp3
3395	3369	3370	3394	2012-11-30 05:11:33+00	0	\N	c44bba5e1cef533a61b2e19a5c4c3585c303e2ab99b2dfe9f5a1c8bfb4debc3c	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/17 - Hans Zimmer and Lisa Gerrard - Now We Are Free.mp3
3429	2872	3422	3428	2012-11-30 05:11:38+00	0	\N	a29a3070edbf1ef82d0c406e3b4018c823de1dc6053454a804eb81f3147ba6dd	/home/extra/user/torrents/Dead Can Dance/1996 - Spiritchaser/02 - Dead Can Dance - Song Of The Stars.mp3
3397	3369	3370	3396	2012-11-30 05:11:33+00	0	\N	582f44868c9a17eb60df8fc64879ea54414f25b3e98ca8a7da8b66f1f05901fc	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/02 - Hans Zimmer and Lisa Gerrard - The Wheat.mp3
3417	2872	3416	3415	2012-11-30 05:11:36+00	0	\N	8de9e6f17a7e2b7606ca75add7083b89a056e4ea8f35c1116d0d40eab2023e48	/home/extra/user/torrents/Dead Can Dance/1986 - Spleen And Ideal/03 - Dead Can Dance - Circunradiant Dawn.mp3
3399	3369	3370	3398	2012-11-30 05:11:33+00	0	\N	03b29f24c3539c05fd7a48a758836ac8fe07e200db2734b6e7c0b9c2c110b57c	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/04 - Hans Zimmer and Lisa Gerrard - Earth.mp3
3401	3369	3370	3400	2012-11-30 05:11:33+00	0	\N	48b88a4d25e6194d7fd8eb885614b98bb72bd4a94e2f62903f03cbe85d456bca	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/11 - Hans Zimmer and Lisa Gerrard - Reunion.mp3
3403	3369	3370	3402	2012-11-30 05:11:33+00	0	\N	8d09423fdd94b9dc7cfb6c5107bc23223a4a2983a667f2d19b719b9d17b0c9fd	/home/extra/user/torrents/Dead Can Dance/LISA GERRARD/Hans Zimmer and Lisa Gerrard/Gladiator Music From The Motion Picture/05 - Hans Zimmer and Lisa Gerrard - Sorrow.mp3
3419	2872	3405	3418	2012-11-30 05:11:36+00	0	\N	653253fc2ce5b1939a61ba8f8ed14d5083be48ea402480f6bb74c6bc3f8adf9c	/home/extra/user/torrents/Dead Can Dance/1986 - Spleen And Ideal/07 - Dead Can Dance - Advent.mp3
3406	2872	3405	3404	2012-11-30 05:11:34+00	0	\N	b779cf07435df2df464347e86042d80809077dd85d17218256ede2d9be891a6b	/home/extra/user/torrents/Dead Can Dance/1986 - Spleen And Ideal/01 - Dead Can Dance - De Profundis (Out Of The Depths Of Sorrow).mp3
3407	2872	3405	2871	2012-11-30 05:11:34+00	0	\N	337ea22f1f11e7edbac4949c5e4979ff985fb8ef16b8b5a3b7e1d197282adc14	/home/extra/user/torrents/Dead Can Dance/1986 - Spleen And Ideal/08 - Dead Can Dance - Avatar.mp3
3441	3437	3438	2924	2012-11-30 05:11:42+00	0	\N	87d0268920bf94f0021abd849ad57257431a2fbc0cbc9508e538a6b552809f4c	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 1/Dead Can Dance - Live - 10 - The Wind That Shakes The Barley.mp3
3409	2872	3405	3408	2012-11-30 05:11:34+00	0	\N	9bd4e6931ed535761b9f0fcc07ee6b2e1ccf13d73e6278820f9b687d42a1de5d	/home/extra/user/torrents/Dead Can Dance/1986 - Spleen And Ideal/04 - Dead Can Dance - The Cardinal Sin.mp3
3421	2872	3405	3420	2012-11-30 05:11:36+00	0	\N	073c62a314a25068ee8dbf4036b0cdb635f7d492972a04feeaa39f23d9baca9f	/home/extra/user/torrents/Dead Can Dance/1986 - Spleen And Ideal/09 - Dead Can Dance - Indoctrination (A Design For Living).mp3
3411	2872	3405	3410	2012-11-30 05:11:35+00	0	\N	3243c4bb885afe93fe503813ab68c94b1c73e87df9f71456d44888a108b325c0	/home/extra/user/torrents/Dead Can Dance/1986 - Spleen And Ideal/02 - Dead Can Dance - Ascension.mp3
3413	2872	3405	3412	2012-11-30 05:11:35+00	0	\N	76df8c03616b8f1f714b2c9aa573d16d647f6583f36eccbd0d50f600e5a6a848	/home/extra/user/torrents/Dead Can Dance/1986 - Spleen And Ideal/05 - Dead Can Dance - Mesmerism.mp3
3431	2872	3422	3430	2012-11-30 05:11:39+00	0	\N	c706342d45bda845347367699c48f1011938e1ec0fe6c4a7d2e29a9e6ec7b349	/home/extra/user/torrents/Dead Can Dance/1996 - Spiritchaser/04 - Dead Can Dance - Song Of The Dispossessed.mp3
3414	2872	3405	2986	2012-11-30 05:11:35+00	0	\N	fc50f56f2089c0c68b99265ce799eb1b2122c7e29abc0409728834eb0a4e790b	/home/extra/user/torrents/Dead Can Dance/1986 - Spleen And Ideal/06 - Dead Can Dance - Enigma Of The Absolute.mp3
3423	2872	3422	3083	2012-11-30 05:11:37+00	0	\N	a8d3a8055c289de4f6f25f2d800f400e97f59143a06fe30650b276042addd9ae	/home/extra/user/torrents/Dead Can Dance/1996 - Spiritchaser/07 - Dead Can Dance - Song Of The Nile.mp3
3425	2872	3422	3424	2012-11-30 05:11:37+00	0	\N	e1981cdf23f05b6828ae85a7c42c70159108af5f403daad1ef7cdd45609e5cd4	/home/extra/user/torrents/Dead Can Dance/1996 - Spiritchaser/06 - Dead Can Dance - The Snake And The Moon.mp3
3435	2872	3422	2965	2012-11-30 05:11:41+00	0	\N	64fa9889deb3a990c99fd82af23f3504bbe917ee55c7cccb4aeb162bf7347242	/home/extra/user/torrents/Dead Can Dance/1996 - Spiritchaser/03 - Dead Can Dance - Indus.mp3
3427	2872	3422	3426	2012-11-30 05:11:38+00	0	\N	860c22ce04e9125fb067ee1e608d2b3cfdbe5f4c2725ec70f63aa635921b466b	/home/extra/user/torrents/Dead Can Dance/1996 - Spiritchaser/08 - Dead Can Dance - Devorzhum.mp3
3433	2872	3422	3432	2012-11-30 05:11:40+00	0	\N	1b0f66c3c42e2be26cb42e4d9fae7569a9fe67d9115c3a8e4660a2d0ec3d4498	/home/extra/user/torrents/Dead Can Dance/1996 - Spiritchaser/05 - Dead Can Dance - Dedicacé Dutò.mp3
3440	3437	3438	2953	2012-11-30 05:11:42+00	0	\N	4152d7d953bf7065ac9d006262061983a6541348309281293ad04acb00a49238	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 1/Dead Can Dance - Live - 06 - The Lotus Eaters.mp3
3434	2872	3422	2951	2012-11-30 05:11:40+00	0	\N	687ddf12ed9688162678a0980a75700e73c50b8f1a7f801b716564194f0cd353	/home/extra/user/torrents/Dead Can Dance/1996 - Spiritchaser/01 - Dead Can Dance - Nierika.mp3
3439	3437	3438	3436	2012-11-30 05:11:41+00	0	\N	672a9717cd1520625d1629ab178fcda96bb82caee62987a300f3ef1f7d1cdf6a	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 1/Dead Can Dance - Live - 04 - The Ubiquitous Mr Lovegrove.mp3
3442	3437	3438	2940	2012-11-30 05:11:43+00	0	\N	5c06b70079b783fdbd99c7e9d6d181c94eb5e045091e16979b72a95187a633d2	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 1/Dead Can Dance - Live - 09 - Saltarello.mp3
3443	3437	3438	2951	2012-11-30 05:11:43+00	0	\N	ab68aae81ba2487a1f9a37ce929ca77928eaeb092316c92e93fe6d91f16740b5	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 1/Dead Can Dance - Live - 01 - Nierika.mp3
3445	3437	3438	3444	2012-11-30 05:11:43+00	0	\N	abafdec4cb783d0048d05968ff45f3e77374eb3f4d35678828e426482970686f	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 1/Dead Can Dance - Live - 08 - Minus Sanctus.mp3
3462	3437	3454	3461	2012-11-30 05:11:47+00	0	\N	0565f9166c666d98329901a399bd4ef9f6813a646b2e5bad167b53a76d4b73e9	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 2/Dead Can Dance - Live - 01 - Dreams Made Flesh.mp3
3447	3437	3438	3446	2012-11-30 05:11:44+00	0	\N	a5e43a58ee2237563cf193e1b1dcb9ebf800a9246591a2df799bfbc6ac8f18ec	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 1/Dead Can Dance - Live - 05 - The Love That Cannot Be.mp3
3449	3437	3438	3448	2012-11-30 05:11:44+00	0	\N	7059b1d4f193dd70a44c4015f27a17b37a19aabdff8ef348d357cb764121fcb4	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 1/Dead Can Dance - Live - 03 - Yamyinar.mp3
3477	2872	3470	2932	2012-11-30 05:11:51+00	0	\N	d5bfe2aa3a5a04450bcb529ed6b0cfc8dc107f10c3be04f2ebf698c09a906647	/home/extra/user/torrents/Dead Can Dance/1993 - Into The Labyrinth/04 - Dead Can Dance - The Carnival Is Over.mp3
3451	3437	3438	3450	2012-11-30 05:11:44+00	0	\N	c2dcd4e5df74057ba43ab2905675e3e3fd093bda7e2da3d95776bf11bcb1dd40	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 1/Dead Can Dance - Live - 02 - Saffron.mp3
3464	3437	3454	3463	2012-11-30 05:11:48+00	0	\N	1e9b24460a5c92a400d573ef470c120c6d76f28f01068b24ff103ac428f1ce11	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 2/Dead Can Dance - Live - 10 - Hymn For The Fallen.mp3
3453	3437	3438	3452	2012-11-30 05:11:45+00	0	\N	556c5d573c815419b134cc4c18ad9c1c5b065a9a4d690f4e8d3158b62de9aaa9	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 1/Dead Can Dance - Live - 07 - Crescent.mp3
3455	3437	3454	2963	2012-11-30 05:11:45+00	0	\N	89db0eecf2e80f14888517b415bc2f5b6a3cea72030f40af32431b5aaa1417ac	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 2/Dead Can Dance - Live - 04 - Sanvean.mp3
3473	2872	3470	3472	2012-11-30 05:11:50+00	0	\N	e99e32903cbc1fe6a9d4af7d610f6c60a3401358b10faf635c31e43fb3dc4ade	/home/extra/user/torrents/Dead Can Dance/1993 - Into The Labyrinth/06 - Dead Can Dance - Saldek.mp3
3457	3437	3454	3456	2012-11-30 05:11:46+00	0	\N	95486b2c5d0ec31d94e3a474c71f0d13a5886e84b22a2d23a2e2faaa92ed0dcf	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 2/Dead Can Dance - Live - 07 - Salems Lot.mp3
3465	3437	3454	2938	2012-11-30 05:11:48+00	0	\N	9f72e0fb49910b85b83e468e268baa70103e83dae7797a3e968f7d46fe549475	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 2/Dead Can Dance - Live - 06 - Black Sun.mp3
3458	3437	3454	2910	2012-11-30 05:11:46+00	0	\N	a071c987f637a293b7f7062b8ba4d656ef1975c2e64fd974cf430b8fe4a4cafe	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 2/Dead Can Dance - Live - 09 - Severance.mp3
3459	3437	3454	2957	2012-11-30 05:11:47+00	0	\N	c2c8cd3b2e7674b2fb064b16cf2dd6c6e22729c2f62204965267f194eb67a881	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 2/Dead Can Dance - Live - 05 - Rakim.mp3
3460	3437	3454	2959	2012-11-30 05:11:47+00	0	\N	0c911a8212d50bc67052b7918cfeb3ae8b441daf6aa0081f29e76697d6ef93c0	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 2/Dead Can Dance - Live - 03 - American Dreaming.mp3
3466	3437	3454	2934	2012-11-30 05:11:48+00	0	\N	fcf6545618c3a1b301ead35dbde8d49d42254f2b11fa760cd2baf09462add23d	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 2/Dead Can Dance - Live - 08 - Yulunga.mp3
3475	2872	3470	3474	2012-11-30 05:11:50+00	0	\N	9c8917363e385de9151bc5311e1118667726c23eaa76100edba86ccefb7fc0e6	/home/extra/user/torrents/Dead Can Dance/1993 - Into The Labyrinth/08 - Dead Can Dance - Tell Me About The Forest (You Once Called Home).mp3
3468	3437	3454	3467	2012-11-30 05:11:49+00	0	\N	5afe1f3fa2ccde7fab2947c336673f4c141c18351d81944cb0c06e5797f933ec	/home/extra/user/torrents/Dead Can Dance/Dead Can Dance Live in Lille 16 March 2005 2CD/DCD Live 2005 - CD 2/Dead Can Dance - Live - 02 - I Can See You.mp3
3471	2872	3470	3469	2012-11-30 05:11:50+00	0	\N	a42743cbc7c9d7836fe90641c2ac955ef635d3b75ed9adfeb8dc22270cce82c7	/home/extra/user/torrents/Dead Can Dance/1993 - Into The Labyrinth/11 - Dead Can Dance - How Fortunate The Man With None.mp3
3480	2872	3470	3124	2012-11-30 05:11:52+00	0	\N	23199d5840e03ea45259527e7a8e9cd1940196e801e2a8e546feb162a6900550	/home/extra/user/torrents/Dead Can Dance/1993 - Into The Labyrinth/03 - Dead Can Dance - The Wind That Shakes The Barley.mp3
3476	2872	3470	2926	2012-11-30 05:11:51+00	0	\N	648b2b97f63560e26eee9975daf423609b39962f64023eac23d7668fbc18be59	/home/extra/user/torrents/Dead Can Dance/1993 - Into The Labyrinth/09 - Dead Can Dance - The Spider's Stratagem.mp3
3479	2872	3470	3478	2012-11-30 05:11:51+00	0	\N	d50d5d40a66f0fe70326fde383a68366927d714439980aced3e6f0fb050f8a3d	/home/extra/user/torrents/Dead Can Dance/1993 - Into The Labyrinth/10 - Dead Can Dance - Emmeleia.mp3
3481	2872	3470	3102	2012-11-30 05:11:52+00	0	\N	b98de7e9c0099a2eaeb5d2167a26e2c24cf9d26967ffd74128bf2ea1922f2a4c	/home/extra/user/torrents/Dead Can Dance/1993 - Into The Labyrinth/01 - Dead Can Dance - Yulunga (Spirit Dance).mp3
2748	2737	2734	2747	2012-11-30 05:09:33+00	0	\N	3e32e4995f98792061d57001c63fd1cd9c26a5485ff3de36711b4b66d23f32a0	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 5 - Wagner/04-Die Meistersinger von Nürnberg- Aufzug der Meistersinger.mp3
3483	2872	3470	3482	2012-11-30 05:11:53+00	0	\N	9c7631760267ec47a0f3db8207c09bdbb72cc29a6340ef15f5de56b88febd651	/home/extra/user/torrents/Dead Can Dance/1993 - Into The Labyrinth/05 - Dead Can Dance - Ariadne.mp3
3485	2872	3470	3484	2012-11-30 05:11:53+00	0	\N	fcfffa9d86224d2a913bfe52a1a808ea19f124159f42a1018a23218bd1967d68	/home/extra/user/torrents/Dead Can Dance/1993 - Into The Labyrinth/07 - Dead Can Dance - Towards The Within.mp3
3486	2872	3470	2914	2012-11-30 05:11:53+00	0	\N	e3035f2836917c064d95823ea97fb9bbb6de69fc16fa5a1cca49f555d50ffad6	/home/extra/user/torrents/Dead Can Dance/1993 - Into The Labyrinth/02 - Dead Can Dance - The Ubiquitous Mr. Lovegrove.mp3
3498	\N	\N	3497	2012-11-30 05:11:58+00	0	\N	f4f1ec5bec52ace138298ea4c3d7567184d0a126976814f8a1e8e547ec89e897	/home/extra/user/podcasts/News/Free Speech Radio Documentaries/20101224FSRNhifi.mp3
3500	\N	\N	3499	2012-11-30 05:11:58+00	0	\N	ae2726a7c956cf4055e026e9ce1994a64cafaa992b2a5ed7756cbf1b251a8ab4	/home/extra/user/podcasts/News/Free Speech Radio Documentaries/20101231FSRN-hifi.mp3
3502	\N	\N	3501	2012-11-30 05:11:59+00	0	\N	0fc1bb09c7ad750d757ae65cb5bf1a37986dc065fe0d83400b390bf75507e821	/home/extra/user/podcasts/News/Free Speech Radio Documentaries/20101227FSRNhifi.mp3
3504	\N	\N	3503	2012-11-30 05:12:00+00	0	\N	ddd017f931cba11656b3c6ac4d183deb335ce0528f5960f2891326e734a3ad5c	/home/extra/user/podcasts/News/Free Speech Radio Documentaries/20120704_hifi.mp3
3506	\N	\N	3505	2012-11-30 05:12:01+00	0	\N	b69dc9a98c64baca8420e6aaac2c7b6d7934a8fb36570b5268b80f6cc8eae2f1	/home/extra/user/podcasts/News/Free Speech Radio Documentaries/0_MEMORIALDAY_final.mp3
2750	2737	2734	2749	2012-11-30 05:09:33+00	0	\N	f4e4a0a84222a9dd75a1bd2d099ba47db615360fe9477cf62cfc57ea2fac542b	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 5 - Wagner/02-Die Meistersinger von Nürnberg- Dance of the Prentices.mp3
3508	\N	\N	3507	2012-11-30 05:12:02+00	0	\N	cf019c7c5e2401399eece16486a574d42d51b01f1f897b5d1b8c5efc99d678cd	/home/extra/user/2/2rant-safe_sex.mp3
3510	\N	\N	3509	2012-11-30 05:12:02+00	0	\N	e11b6ee4494060e264df130c8377169efefae5de0ddc3a20a6ac9a1c3cd2e159	/home/extra/user/2/2rant-furry_discrimination.mp3
3512	\N	\N	3511	2012-11-30 05:12:02+00	0	\N	0a1778575e2fa874cc5e2562c8da73c710083c0b61e2b372ded0401f59ddfe85	/home/extra/user/2/2rant-prayer.mp3
3514	\N	\N	3513	2012-11-30 05:12:02+00	0	\N	a646ff9724aafb3cc4ea031daa8d38c7c29c0d6d454f390b4aa837240fce331b	/home/extra/user/2/2rant-military.mp3
3516	\N	\N	3515	2012-11-30 05:12:03+00	0	\N	8e4c595cc6998b4c80342f61dc43511967547882a1400557bfc077502d6e6cd2	/home/extra/user/2/2rant-overboard.mp3
3518	\N	\N	3517	2012-11-30 05:12:03+00	0	\N	97cb0bd9edde2098d071d23396425c4f06d1a9b192006adf6b1dcfa22591ceea	/home/extra/user/2/2rant-badbehavior.mp3
3520	\N	\N	3519	2012-11-30 05:12:03+00	0	\N	491e1611c7eb6249ae7eac5529986b9846216a262d3d5c9bbb7afcac549760cd	/home/extra/user/2/2rant-aging.mp3
3522	\N	\N	3521	2012-11-30 05:12:03+00	0	\N	4b58f2cf7ca6e7bd731ba753c165ce8f643187c077dc8745715ba3b3e0d2918c	/home/extra/user/2/2rant-christmas.mp3
3524	\N	\N	3523	2012-11-30 05:12:03+00	0	\N	61ccbaec6552d15c598594116c38e858da0f3bf71706fe8e6c4e32d9f2b1ecfb	/home/extra/user/2/2rant-apathy.mp3
3526	\N	\N	3525	2012-11-30 05:12:03+00	0	\N	4c84cfc62f5156082c0a576687760e3f9cc9e2a15e5bad8051a99f8ed7f5b775	/home/extra/user/2/2rant-religion.mp3
3528	\N	\N	3527	2012-11-30 05:12:03+00	0	\N	9c722d07b7191324333e91d02a4afd995d8c45cf91d5345b39f4e3a756b6e867	/home/extra/user/2/2rant-animal_spirits.mp3
3532	3530	3531	3529	2012-11-30 05:12:04+00	0	\N	3372eb84172758ec47cc9ab45a95d809958d0426941fa113f9936558397deca7	/home/extra/user/ideas/Idolatry for Beginners.mp3
3494	\N	\N	3493	2012-11-30 05:11:56+00	0	\N	5ad8ab2c2bbccccc444fae7a1c5e54b118dedb77e531ef1268aa423bf1722a9e	/home/extra/user/podcasts/News/Free Speech Radio Documentaries/20101230FSRNhifi.mp3
1042484	1253	2079	2119	2012-11-30 05:57:37+00	0	\N	42d2db3ecf964eea08566189c0aa97e3a48f2072e9de58a2474d4e8136a92c3b	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 11 Wacky Antics.mp3
3544	1253	1920	1970	2012-11-30 05:51:10+00	0	\N	c02a227254480cb83d595952cd2a979fe2882990eb75fb0408845e85f33e44bd	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 25 Science Seahorse.mp3
3543	1253	1920	1978	2012-11-30 05:51:09+00	0	\N	597f7907a7d8e1ba279627e83eb672bec5554b2e768ed25942c8bb55fc65e748	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 18 Chaotic Strength.mp3
3545	1253	1920	1958	2012-11-30 05:51:10+00	0	\N	01ce122a0c20ae0cc1c94ecc6ae8ad6171919117195daeecd5f5061ef8d3089a	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 14 Nepeta's Theme.mp3
3549	1253	1920	1962	2012-11-30 05:51:11+00	0	\N	635959970acfb04d28fffcbe6171a6189f8b2190799ab69718cf64d508890439	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 13 Nautical Nightmare.mp3
3546	1253	1920	1956	2012-11-30 05:51:10+00	0	\N	8bdcb024133cd0af395d0808ddef4306a877406de93ab671f2be4a6e334adfac	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 05 Terezi's Theme.mp3
3547	1253	1920	1972	2012-11-30 05:51:10+00	0	\N	b66e484ea55c34b5883918aa6ad3b58bf049c01669598067bfbd3266f8e027ed	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 26 A Fairy Battle.mp3
3552	1253	1920	1974	2012-11-30 05:51:12+00	0	\N	e5c55c6edc961b1f9a1321b010c33b38452995636a73da21d3b3930f0e9cd347	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 19 Trollian Standoff.mp3
3548	1253	1920	1942	2012-11-30 05:51:10+00	0	\N	e84f3bd33f1e7cb897e5418ef3ef55ab8bc8b8e94b217acca408f5f753008554	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 10 Darling Kanaya.mp3
3550	1253	1920	1966	2012-11-30 05:51:11+00	0	\N	c13fc25e0575fcc4566b5c94801fc0d8a5effe243395bc56a3226de1fffd680e	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 08 She's a Sp8der.mp3
3551	1253	1920	1926	2012-11-30 05:51:11+00	0	\N	d937f5fb634d5029dd747165b675a498446aa34457868596633e4af4a4b1d6f0	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 09 FIDUSPAWN, GO!.mp3
3553	1253	1920	1964	2012-11-30 05:51:12+00	0	\N	de1cd235a1cc6d5e31c9caabe0dac97b31e82b8204c3588941b7b705ab7f3d32	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 15 Horschestra STRONG Version.mp3
3554	1253	1920	1960	2012-11-30 05:51:12+00	0	\N	a7453113253fbe170f4606254b4fc198b948391e1d8509436dcf416fdcecbff8	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 28 AlterniaBound.mp3
3496	\N	\N	3495	2012-11-30 05:11:57+00	0	\N	44a056b0f032a314505912ab2f098587614a0b23e0311d7423019defaa39a437	/home/extra/user/podcasts/News/Free Speech Radio Documentaries/20110704hifi.mp3
1042549	1042541	1042542	1042548	2012-11-30 05:58:45+00	0	\N	712a6efde4a8b9d47522c737b111984f387625fec4496a56792b83f5eb6d4c29	/home/extra/music/restitch/37d.flac
2810	2801	2798	2809	2012-11-30 05:09:45+00	0	\N	4b4597ff514213264bf2d9414dc74795f121a58c235393572526724912185350	/home/extra/user/torrents/Masters Of Classical Music [10 CD set][www.lokotorrents.com][mp3]/Vol. 10 - Verdi/09-La Traviata- Libiamo ne' lieti calici.mp3
1042498	1253	1641	1679	2012-11-30 05:58:08+00	0	\N	ab5cdb51d152c60f9d310e9da41d2c044b1d0570ff1d20ff8ca23ee1c6e0bbbe	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 19 Sburban Reversal.flac
1042487	1253	2079	2095	2012-11-30 05:57:38+00	0	\N	0fee71f4d66db1cf4094bfbea15fb82ab2069d9ad617e4bbd20ce96479e72483	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 13 Heir Transparent.mp3
1293	1253	1254	1292	2012-11-30 05:05:22+00	0	\N	c2f6482fe268d6386ae9cdcad707a66e46106101c5d4ce47509855739fd2961f	/home/extra/music/Homestuck/Homestuck Volume 5/06 Jade's Lullaby.mp3
1042488	1253	2079	2111	2012-11-30 05:57:38+00	0	\N	0976cad4adf20b35db1b03862c071819f68389bf4e10f12490b5a5b24507310f	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 09 Gaia Queen.mp3
1042489	1253	2079	2085	2012-11-30 05:57:38+00	0	\N	5923461f20122092f4694a1367830e38b58dfc7ac32b73148511f59915f71b4d	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 08 Walk-Stab-Walk (R&E).mp3
1042490	1253	2079	2107	2012-11-30 05:57:39+00	0	\N	e6ff644fd01c0a2c58d9d6dddf3a9cc6c4df99450381a277544fb43ab6a07b4a	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 10 Elevatorstuck.mp3
1042491	1253	2079	2091	2012-11-30 05:57:39+00	0	\N	8d6973a3c7fb5c3db8d5d3a06cf49877e440ded3789d878521951a76b48ce7d9	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 02 Courser.mp3
1399	1253	1254	1379	2012-11-30 05:05:47+00	0	\N	abb89195585f8a0cc0242557b48a8b9557fe7f94dabb7505961990470c8b263f	/home/extra/music/Homestuck/Homestuck Volume 5/47 Skaian Skuffle.mp3
1042492	1253	2079	2087	2012-11-30 05:57:39+00	0	\N	9ee39a04213e0bad6dbf135f70bda8830d60136ff24811dce963b0f21234bf4d	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 18 Phrenic Phever.mp3
1042493	1253	2079	2103	2012-11-30 05:57:39+00	0	\N	572e73247c28b01f08c5fd9449bef7660e81d0bc3ed2bd0af85fb96575413b13	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 07 MeGaLoVania.mp3
1042494	1253	2079	2109	2012-11-30 05:57:40+00	0	\N	09e471118c3932013e65dc8d2f185a736572e156b4d9f4ab210ffefdfdfbdb9d	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 19 3 In The Morning (Pianokind).mp3
1257	1253	1254	1256	2012-11-30 05:05:15+00	0	\N	28c06eff216f9e082140e5ef30b92cfc3bfceef965c33976353e495bb1bbacce	/home/extra/music/Homestuck/Homestuck Volume 5/24 Unsheath'd.mp3
3541	1253	1920	1922	2012-11-30 05:51:09+00	0	\N	937e96403fb629cf0de02fb97d9f3ddbc10957db39150d6e1c692b57ac88903b	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 11 Requiem Of Sunshine And Rainbows.mp3
1042497	1253	1641	1649	2012-11-30 05:58:08+00	0	\N	7c86e3836dccc91c0aa6379d60961950ef0338aa072d2db7bd83d350c0b5cbfe	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 03 Even in Death.flac
1042485	1253	2079	2105	2012-11-30 05:57:37+00	0	\N	7008e4490f9d1a6de29924169107cc62806c7a5fd25c52e8e8ed30432933cd4e	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 14 Boy Skylark (Brief).mp3
1042499	1253	1641	1659	2012-11-30 05:58:09+00	0	\N	820c8fcce9cbcd5e58bed296c058a266d063b857445c0d91430af41a37227aee	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 01 Black Rose - Green Sun.flac
1042502	1253	1641	1661	2012-11-30 05:58:10+00	0	\N	705a21ebbd5e970f2e9f007e2a52a8bc041125a59a2a683e7c08ee43f8d3597a	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 18 Maplehoof's Adventure.flac
1042500	1253	1641	1677	2012-11-30 05:58:09+00	0	\N	9ca6e557489f89bb276ba26fc2f16dbb00c3cfc70226d2553ece2ecfaf10c899	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 05 Trial and Execution.flac
1042501	1253	1641	1640	2012-11-30 05:58:10+00	0	\N	fee107057b5350dd413037c8de94c041efa30045104dfe5c5c7794608fb60241	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 07 Spider8reath.flac
1042503	1253	1641	1673	2012-11-30 05:58:11+00	0	\N	e414915891d62d300b363ce20692695271bc45cae6c784bbe07914f1d2b4c944	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 02 At The Price of Oblivion.flac
1042486	1253	2079	2078	2012-11-30 05:57:38+00	0	\N	1f95acfb4deb4c028beb2a481925236cae94cbf060ed9a972b7db37bd84c7623	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 20 A Tender Moment.mp3
1352	1253	1254	1351	2012-11-30 05:05:35+00	0	\N	ea638503ea2c0ee3c9fa1c574093f55d57ccc11a51bd2bec614023392d686a0b	/home/extra/music/Homestuck/Homestuck Volume 5/59 Plague Doctor.mp3
1354	1253	1254	1353	2012-11-30 05:05:36+00	0	\N	da93a4ea61b7d58ed94dd143c6f7782dd2b8a4d606f3a40285f72d5e2d7e8eda	/home/extra/music/Homestuck/Homestuck Volume 5/12 White.mp3
3555	1253	1920	1924	2012-11-30 05:51:12+00	0	\N	1dbb74851c5211108f26bed011661a8855a42f51dbb312332e4ddd9458e6f6a3	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 24 Catapult Capuchin.mp3
1042495	1253	1254	1420	2012-11-30 05:58:02+00	0	\N	05bba29a851343a120fe35aee10917cc27220ca592d12a480227d6612510bc3d	/home/extra/music/Homestuck/Homestuck Volume 5/17 Skaia (Incipisphere Mix).mp3
1439	1253	1254	1369	2012-11-30 05:05:58+00	0	\N	d98eca434b986d70afddca7d6d7c583e81c413b12a034b17a28022decc39fb77	/home/extra/music/Homestuck/Homestuck Volume 5/43 Get Up.mp3
1042762	1042760	1042761	1042759	2012-11-30 06:03:38+00	0	\N	5ec3b502bd301978df8892fb3d06cb4e87698627bc365b1bc536c46665277950	/home/extra/music/songsIam/RunWithUs.mp3
1042505	1253	1641	1665	2012-11-30 05:58:12+00	0	\N	1536d3c2a17a505a00fc36ca041ca2db2e9ae97258bd1ccf321c48a62dca7545	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 17 Savior of the Dreaming Dead.flac
1042509	1253	1641	1645	2012-11-30 05:58:14+00	0	\N	469c92c9aace61b03f5c6af017c3b709a7c19b5c1c77f478f969f847fb694f74	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 15 Earthsea Borealis.flac
2491	2489	2490	2488	2012-11-30 05:08:49+00	0	\N	b53a88eb9328c15b42be15011998916504b49fb73c737c633b0bb3858e7004a5	/home/extra/user/torrents/John Williams - Greatest Hits (1969-1999) [2CD]/John Williams - Greatest Hits (1969-1999) [2CD]/1-06 - 'Theme' from Jaws (1975).mp3
1042513	1253	1641	1653	2012-11-30 05:58:16+00	0	\N	10c7fb2c9a7b908d3b43c368821aedb0a855cb1d20fa3ba39de02861099f3aaf	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 11 Play The Wind.flac
1042510	1253	1641	1667	2012-11-30 05:58:15+00	0	\N	68fc807af4a08d3e4927209f6011c42a2e8790643e045216025bd5268191b926	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 08 Lifdoff.flac
1042511	1253	1641	1675	2012-11-30 05:58:15+00	0	\N	7d5be1bc3db72ba9f183b152648e8dcd59baad96dfdd5166f4094e4817727816	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 09 Awakening.flac
1042514	1253	1641	1669	2012-11-30 05:58:17+00	0	\N	e0db475453de33f0ffba24009c812e7484d4ce494bb514c8336d42d46159c09e	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 04 Terezi Owns.flac
1042521	1042519	1042520	1042518	2012-11-30 05:58:18+00	0	\N	f4790e9c694680fc71cef5583f66eb3ee9bee41ad596e56e94a925133e1a3982	/home/extra/music/restitch/4e0.flac
1042515	1253	1641	1657	2012-11-30 05:58:17+00	0	\N	01259719701990c380ccc6619ed5ce992e57c6bbb0419d6945d897399558b3b5	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 16 Warhammer of Zillyhoo.flac
1042506	1253	1641	1655	2012-11-30 05:58:12+00	0	\N	16d6876deccfda5a6c1d6619490123821c9b203efd15557a5781545776bea334	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 12 Rumble at the Rink.flac
1042525	1042523	1042524	1042522	2012-11-30 05:58:19+00	0	\N	771c4a75123e77973517b44c4d9564bf4e05a895b8a89099cc89d00c34b5bfa8	/home/extra/music/restitch/2f9.flac
1042529	1042527	1042528	1042526	2012-11-30 05:58:23+00	0	\N	a7b7a840e9a80f01d07e1387f68453f6052b6c34177f3b644879206f4da76284	/home/extra/music/restitch/2cc.flac
1042507	1253	1641	1671	2012-11-30 05:58:13+00	0	\N	5ebeae87e81b4bf4df277ca84fa0fbf43b51fc392df216b1a981ffb3a8e5fc3a	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 20 White Host, Green Room.flac
1042512	1253	1641	1651	2012-11-30 05:58:16+00	0	\N	a74bb53abcf5ea087e7e66bb6ccb4bf4c6214a8482d1eb5fdac11f709488f633	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 06 The Carnival.flac
1042504	1253	1641	1643	2012-11-30 05:58:11+00	0	\N	828256c44b8859187c57b0bd4298e34ce0ceb014ffe806c5151628b55f1af20a	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 10 Havoc To Be Wrought.flac
1042508	1253	1641	1647	2012-11-30 05:58:13+00	0	\N	5cb1aedf3d38aabf3bc1ea26ccf21b4cd7034e59f651838a41e4dfa1ef24e54d	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 13 Let's All Rock the Heist.flac
664	662	663	661	2012-11-30 05:04:00+00	0	\N	9c2d35d71183cf798e52e42f6285b5a97d9a719d9d6b9ba0c33ecb8142743d68	/home/extra/user/torrents/Loreena McKennitt Discography/2006 An Ancient Muse/06-loreena_mckennitt--penelopes_song.mp3
1042450	1253	1920	1930	2012-11-30 05:57:31+00	0	\N	616e0655f24eed7792d2c3370b6ee1b9a6a80757ffa6218557b0d2390c07f156	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 20 Rex Duodecim Angelus.mp3
1042453	1253	1920	1946	2012-11-30 05:57:32+00	0	\N	e5e07b70fac42f2be5311db9306e32435b28b85bb8afa9c2f90595b1727b0fa6	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 21 Killed by BR8K Spider!!!!!!!!.mp3
1042454	1253	1920	1940	2012-11-30 05:57:33+00	0	\N	2eac1203503fafc803c3c9972defa7c48cd07124c4ac9124b0495a5e3eeb118c	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 07 Vriska's Theme.mp3
683	662	682	681	2012-11-30 05:04:02+00	0	\N	a85eb5eded56fa169e050b32302f00cce94c0d1a6ddc1705e69ec36d22c4ead6	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD1/05 Loreena McKennitt The Highwayman.mp3
1042475	1253	2079	2097	2012-11-30 05:57:34+00	0	\N	fd4c41ae54890fbb55cebb7ad14a8167dd130273273c15dcfd5b4681cf9d47f8	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 03 Umbral Ultimatum.mp3
1042476	1253	2079	2117	2012-11-30 05:57:35+00	0	\N	b3ca5ef3a1cc178cb7c80de6f285b1d7d11ed7093baa0173fdc761364c0350e9	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 05 Tribal Ebonpyre.mp3
1042477	1253	2079	2081	2012-11-30 05:57:35+00	0	\N	57727b17ef22779b376828785637fed81c7e820169b131fba4aea482c2533afa	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 01 Frost.mp3
1042478	1253	2079	2093	2012-11-30 05:57:35+00	0	\N	2ff151557bdd8919d8e3bf03b4b867472cdaf463efe27a8a2de197a1d03b7cd6	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 16 Blackest Heart.mp3
1042479	1253	2079	2113	2012-11-30 05:57:36+00	0	\N	0282d56c59d35c7a279fe779da1b091287a6cde4300b3eff848d1b84621e462b	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 15 Squidissension.mp3
1042481	1253	2079	2115	2012-11-30 05:57:36+00	0	\N	2445bdbf5dd3ee45b3ffca669686c2a38a0a590dfa9d1520f9604f6621878f11	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 04 GameBro (Original 1990 Mix).mp3
1042482	1253	2079	2083	2012-11-30 05:57:37+00	0	\N	b32ea7a2449220001ce2ed2464ff243c5b89cf3d8744e9e4fd9277359f45300f	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 06 I Don't Want to Miss a Thing.mp3
1042483	1253	2079	2099	2012-11-30 05:57:37+00	0	\N	18b1fe67be864fdf127fa02f4a369f3d235f044679e54a668c2d8c751b66c949	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 21 Crystalanthology.mp3
1415	1253	1254	1317	2012-11-30 05:05:51+00	0	\N	0481182d7c08c0cdc59c66e5717ecb54a2e54cb39b6e034edd75e23eddda80ab	/home/extra/music/Homestuck/Homestuck Volume 5/23 Chorale for War.mp3
1444	1253	1254	1306	2012-11-30 05:06:00+00	0	\N	29a5c96a6a3598d9ac00fbf53ec41fb1509ececc15710aeb4e96d5ba1a181301	/home/extra/music/Homestuck/Homestuck Volume 5/11 Skaian Ride.mp3
1042496	1253	1641	1663	2012-11-30 05:58:07+00	0	\N	fc4f294fc52fd914ec9d9c4fea366c9d37ed9edc2432a9b4ca743e91d894211d	/home/extra/music/Homestuck/Homestuck - Homestuck Vol. 7- At the Price of Oblivion/Homestuck - Homestuck Vol. 7- At the Price of Oblivion - 14 WSW-Beatdown.flac
1042480	1253	2079	2089	2012-11-30 05:57:36+00	0	\N	899a0c97422b7d8a0dce2d1afa1325725560d370a1482b2e4001365dcf91408a	/home/extra/music/Homestuck/10 - Vol. 6 - Heir Transparent/Homestuck - Homestuck Vol. 6- Heir Transparent - 12 Horschestra.mp3
1419	1253	1254	1410	2012-11-30 05:05:53+00	0	\N	3aae1804f71f81bd34e94493dddbd70e37e43810596dd18d2a7181f6e78e57cd	/home/extra/music/Homestuck/Homestuck Volume 5/03 Savior of the Waking World.mp3
1042462	1042460	1042461	1042459	2012-11-30 05:57:33+00	0	\N	6a9ca515258ed590ee2a1c82ad501828e8d5c4b6dea09aa427e15a6e6e6f5f06	/home/extra/music/pandora/IOSYS_-_Border_of_Death.mp3
3542	1253	1920	1919	2012-11-30 05:51:09+00	0	\N	86ec881492cae4fab99b979310e4c7ab9641b162732266a4102b0df1bf544f8a	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 17 Midnight Calliope.mp3
1042439	1253	1920	1952	2012-11-30 05:57:29+00	0	\N	aac7a7259538daee5b7dd495b7acb506b604004d127d94c4795d64d4912ced8c	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 03 Trollcops.mp3
1042440	1253	1920	1948	2012-11-30 05:57:29+00	0	\N	84fe7d9fdeca5e23c9d75edccded9f8e5239ea5d9f7c93069cfe4abba1ccc60b	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 23 Trollcops (Radio Play).mp3
1042442	1253	1920	1042441	2012-11-30 05:57:30+00	0	\N	bb166b5b297dff3e7d83488c201b4af3a5b4601ca7746a550f9beb725fe66bcc	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 04 BL1ND JUST1C3 - 1NV3ST1G4T1ON !!.mp3
1042443	1253	1920	1932	2012-11-30 05:57:30+00	0	\N	594bb6be29f374aa1b8a97f2e1df12c3508ee99cae5b73eb4d225bff29ea3a8d	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 30 Rest A While.mp3
1042444	1253	1920	1954	2012-11-30 05:57:30+00	0	\N	befb2dc01c73ef784454160d24cc0c766d0f77f3366f845cf4401053efb1b81b	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 16 Blackest Heart (With Honks).mp3
1042445	1253	1920	1944	2012-11-30 05:57:30+00	0	\N	894234329c09c2cc8050f3cef89c3f2ad539b9e0abe81c4c386f4f10d81d7d8b	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 27 The Blind Prophet.mp3
1042446	1253	1920	1928	2012-11-30 05:57:31+00	0	\N	46b0c524c2b76bb5153eee5022770865283d8aa17739648c40af1b89f048e4c9	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 12 Eridan's Theme.mp3
1042451	1253	1920	1936	2012-11-30 05:57:32+00	0	\N	5b147ac57f465d8547ee55005a08be20e59fe68f5746c5c166449d7825dea3c3	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 22 Alternia.mp3
1042452	1253	1920	1950	2012-11-30 05:57:32+00	0	\N	ac14f3c021f1a35ae5acfdcb7f9c8fdf086d2b2b164aca9cf440459d51d1e7ea	/home/extra/music/Homestuck - AlterniaBound/Homestuck - AlterniaBound - 02 Karkat's Theme.mp3
1042458	\N	\N	1042457	2012-11-30 05:57:33+00	0	\N	8fb3a39034880f4c8a189def117e575bed9d8595d852741164037e8e4510479e	/home/extra/music/Rose_of_May_FF9_-_lyrics_by_katethegreat19-bNHtbw4Kyf0.vorbis.ogg
712	662	699	711	2012-11-30 05:04:06+00	0	\N	f9fe19869d1ee3b1b42cbd92c0ed9104e0a051c7aad65cc7a8823bb0380624d1	/home/extra/user/torrents/Loreena McKennitt Discography/1999 Loreena McKennitt - Live in Paris and Toronto/Live in Paris and Toronto/Live in Paris and Toronto/CD2/03 Loreena McKennitt Bonny Portmore.mp3
1042596	1042551	1042532	1042595	2012-11-30 06:01:46+00	0	\N	021b535d3fbe1a14db43703b39d5dedcaf37511f4ecca52391378eff3d559eb1	/home/extra/music/restitch/15ef.flac
1042560	1042558	1042559	1042557	2012-11-30 06:01:14+00	0	\N	5afc799e16ed898afa3f6e1024f4ffa191bb5542f175fe22243b8fc11a855dbe	/home/extra/music/restitch/2d5.flac
1042563	1042535	1042562	1042561	2012-11-30 06:01:17+00	0	\N	a166104773cfbcee6fb8a71af7a3f61e03833e294b5bd4a543e0d3807a7552de	/home/extra/music/restitch/308.flac
1042621	1042619	1042620	1042618	2012-11-30 06:02:12+00	0	\N	aec1515582155c0b91b3eaa715004fb7aa86575998ac93fb45df2271a10dd382	/home/extra/music/restitch/392.flac
1042567	1042565	1042566	1042564	2012-11-30 06:01:20+00	0	\N	c6d1fbc647efc2d1816b7ffd91477a741de6f997a1af2933bca1a7ab3bea420b	/home/extra/music/restitch/32d.flac
1042600	1042598	1042599	1042597	2012-11-30 06:01:46+00	0	\N	748956c62caf53a5dfc501a0761531d8e54cbe5a1293447343d571d12c2b7132	/home/extra/music/restitch/2cf.flac
1042570	1042569	1042532	1042568	2012-11-30 06:01:26+00	0	\N	a36d0f08eb7346c52d62b6b38ee5af8e5a80797287cd48c373e49c7cac111109	/home/extra/music/restitch/15df.flac
1042574	1042572	1042573	1042571	2012-11-30 06:01:28+00	0	\N	5d5a73923477d2e4fb0c7303e1c3277834c078d898697d2412f775053c60057d	/home/extra/music/restitch/2ea.flac
1042576	1042551	1042532	1042575	2012-11-30 06:01:32+00	0	\N	5e4104aff2631a47351a95c91b05ed25dd7ef1fe65611797fd96f43f834e7ed6	/home/extra/music/restitch/15f3.flac
1042603	1042602	1042532	1042601	2012-11-30 06:01:51+00	0	\N	ad00a086963d417e0c13e9ee47172c6ec2a600be879d8a86d2ce9c7b8fa1595e	/home/extra/music/restitch/341.flac
1042580	1042578	1042579	1042577	2012-11-30 06:01:32+00	0	\N	3b9aac4730e5921ef7b36fff10ac0780fff7ff96da0867ca5d0e403db2a6d189	/home/extra/music/restitch/15cf.flac
1042584	1042582	1042583	1042581	2012-11-30 06:01:36+00	0	\N	8cd61f596e25fcc829359b1fc917a16285c647f7e56eb510e9bcb53a88f4b818	/home/extra/music/restitch/15e1.flac
1042636	1042625	1042635	1042634	2012-11-30 06:02:34+00	0	\N	7d2af906d919e7f35e4326eb67f2500cb2225617c4de9c9e78f1eec583338233	/home/extra/music/restitch/15f5.flac
1042587	1042586	1042542	1042585	2012-11-30 06:01:37+00	0	\N	cdc5521ce55a645f63fdd424c524d0a3a980298e59bfbb3ea45deaa4030abc07	/home/extra/music/restitch/321.flac
1042605	1042541	1042542	1042604	2012-11-30 06:01:56+00	0	\N	177fc29307a4ce06817cff27458be3c08571cbb0fe7297591300f43d7705a00e	/home/extra/music/restitch/15f9.flac
1042589	1042551	1042532	1042588	2012-11-30 06:01:42+00	0	\N	316ffdda72804c2f9211fd52c6333755db21c7278743682de056935ea7c97921	/home/extra/music/restitch/15e9.flac
1042592	1042591	1042542	1042590	2012-11-30 06:01:42+00	0	\N	7b5978f7031fd7e88da513662b8ffc24ae28105e5972a6d6b4a9a8f0484d1fd7	/home/extra/music/restitch/316.flac
1042623	1042523	1042607	1042622	2012-11-30 06:02:17+00	0	\N	edf7759def5c19c0548c584a0c5c2897b44dd778fe4a6e41f8482208f7302c31	/home/extra/music/restitch/310.flac
1042594	1042535	1042532	1042593	2012-11-30 06:01:44+00	0	\N	521c1a0e1404fa15a23fba05ae4e3fc6b36b6765de4df697709cd2130b0d834c	/home/extra/music/restitch/338.flac
1042608	1042523	1042607	1042606	2012-11-30 06:01:58+00	0	\N	15ec80cb3205a4f587df873bff8440823d44992d4f56d23b763908fbfbc9d0e7	/home/extra/music/restitch/15c3.flac
1042610	1042527	1042528	1042609	2012-11-30 06:02:02+00	0	\N	e0e47ba80819a0e042fe68b19dc385a15556bcaa7b50a341fcb4250e7c8f301c	/home/extra/music/restitch/15c7.flac
1042627	1042625	1042626	1042624	2012-11-30 06:02:21+00	0	\N	c3182bd2bc0391f16da6864539e2bf380c485c6c53f09bce2046a63fbb134b6a	/home/extra/music/restitch/15e3.flac
1042613	1042612	1042583	1042611	2012-11-30 06:02:07+00	0	\N	e49ea1b6d86b0d5c068c0aaa2bd37684706f223c7c6d99c2099d40c4af74afde	/home/extra/music/restitch/349.flac
1042617	1042615	1042616	1042614	2012-11-30 06:02:08+00	0	\N	4e2a1afe747cb0fec3bb38413662d40ec6ad63285189bd476a84f62dac15600a	/home/extra/music/restitch/2fc.flac
1042642	1042551	1042532	1042641	2012-11-30 06:02:42+00	0	\N	de9e6718641079657eefcff7303c191ba398ae445ca297adb111d5e5de1a09ee	/home/extra/music/restitch/35e.flac
1042638	1042578	1042579	1042637	2012-11-30 06:02:39+00	0	\N	a78b285c4e7408f96caefbe0c975519f4866f0ebbf7cd7d9060e4ee46512152f	/home/extra/music/restitch/2f0.flac
1042629	1042535	1042562	1042628	2012-11-30 06:02:26+00	0	\N	b9e621f57dc2b71e5f475dce08499e92203cd9d121421a82152f365151f8ae44	/home/extra/music/restitch/15d3.flac
1042633	1042631	1042632	1042630	2012-11-30 06:02:28+00	0	\N	8db033e602a989ee1d7a13c357025fd641ed20cda361d8814726bca1533e95f5	/home/extra/music/restitch/302.flac
1042646	1042569	1042532	1042645	2012-11-30 06:02:43+00	0	\N	682e83acfb731a50e83c9e05a7e94b5309ff02d601e5951ccf9ac6ec06296088	/home/extra/music/restitch/33a.flac
1042640	1042625	1042635	1042639	2012-11-30 06:02:40+00	0	\N	6bf115745018b2f6049c259677d49dd437f6b9fb766d38dea5c98402e839a12d	/home/extra/music/restitch/363.flac
1042644	1042551	1042532	1042643	2012-11-30 06:02:43+00	0	\N	811177d96f80587f5e3df916d3e76ac3fb4644b7c5ac6f8f282c59e63412dfb5	/home/extra/music/restitch/15e7.flac
1042650	1042523	1042524	1042649	2012-11-30 06:02:45+00	0	\N	f97db157443b1adf7156f9f32f94996d22ec812a0bff0a147853a6b35546f9a3	/home/extra/music/restitch/15d1.flac
1042648	1042551	1042532	1042647	2012-11-30 06:02:45+00	0	\N	5f79f14f41ca766bdeff7fd90410e2074e4f1fbff97a309d0c6ce9ebdb772553	/home/extra/music/restitch/15f1.flac
1042652	1042582	1042583	1042651	2012-11-30 06:02:48+00	0	\N	5e86c7e8c9f868cb0ff90287cfb4e017387333d1f8641e7cf7f78b666f0f1f37	/home/extra/music/restitch/347.flac
1042654	1042531	1042532	1042653	2012-11-30 06:02:49+00	0	\N	57a2c912d7059a283bf58790fbea4ef9ee020a19e530963a6abc9b38923e4744	/home/extra/music/restitch/31e.flac
1042556	1042554	1042555	1042553	2012-11-30 06:01:10+00	0	\N	fea0dd88379b2d63c54334c59574027370c6ef4153572fda828cc5ffa4788201	/home/extra/music/restitch/15d7.flac
1042539	1042538	1042532	1042537	2012-11-30 05:58:33+00	0	\N	6624ad82d8c777919dcf68c3888d878b0445b2692155a16748ad4141d67b738c	/home/extra/music/restitch/324.flac
1042543	1042541	1042542	1042540	2012-11-30 05:58:35+00	0	\N	bb43eade3f6c6d201f6b3b63dda616dcbeeaf3fabc5f5d118f5b5437c266c58b	/home/extra/music/restitch/15f7.flac
1042547	1042545	1042546	1042544	2012-11-30 05:58:37+00	0	\N	189ac075152d399db2140a15b77b58a7892fb7ac5a6bfc5d54abe97411380816	/home/extra/music/restitch/327.flac
1042552	1042551	1042532	1042550	2012-11-30 05:58:47+00	0	\N	44ea20f9c27c1377c9ab55fd90a36e942447bdde51055ccaca36ea0cc6b50551	/home/extra/music/restitch/15e5.flac
1042668	1042554	1042555	1042667	2012-11-30 06:03:04+00	0	\N	c6c0ce395a43b274e4cb3f77c500ebfafee1ca339a623796e33b929fae46b504	/home/extra/music/restitch/31b.flac
756	662	746	701	2006-03-02 00:00:00+00	0	\N	bd8099dc74b0ded71e3dbc605a8bd62596ffdabc76f610d2472d926b766fe310	/home/extra/user/torrents/Loreena McKennitt Discography/1994 The mask and the mirror/The mask and the mirror/The mask and the mirror/02 Loreena McKennitt The Bonny Swans.mp3
1042672	1042670	1042671	1042669	2012-11-30 06:03:07+00	0	\N	4357e6782ac87d55dc5a8c558d38780a50cd901706aaf3488b17fdfd0fcaae01	/home/extra/music/restitch/336.flac
758	662	746	757	2006-03-02 00:00:00+00	0	\N	474f8c73b3668afe0bc98886da9bca2717016cf4009ff9f7cd1739bd86a3925b	/home/extra/user/torrents/Loreena McKennitt Discography/1994 The mask and the mirror/The mask and the mirror/The mask and the mirror/05 Loreena McKennitt Full Circle.mp3
1042675	1042674	1042532	1042673	2012-11-30 06:03:11+00	0	\N	4c73db7b40133eaea1553489bbe907d4b834bdb14289e5a2b36f1da3ad849c4c	/home/extra/music/restitch/305.flac
1042678	1042619	1042677	1042676	2012-11-30 06:03:13+00	0	\N	4c50e5673719b935f56e2a7b0e75112acb6d6389ddc75aa34f9e752431c8d501	/home/extra/music/restitch/15c1.flac
796	662	789	795	2012-11-30 05:04:22+00	0	\N	e4d3ac42ef96081c98454cc1a8ce2b7473808d65e03bc8657955178e594c992a	/home/extra/user/torrents/Loreena McKennitt Discography/1991 The Visit/The visit/The visit/07. Courtyard Lullaby.mp3
798	662	789	797	2012-11-30 05:04:23+00	0	\N	27a2c4ea73e0477f8f95a84508679c9df46ea795de0de32f96bb140749e4d62a	/home/extra/user/torrents/Loreena McKennitt Discography/1991 The Visit/The visit/The visit/05. Greensleeves.mp3
1042680	1042625	1042626	1042679	2012-11-30 06:03:16+00	0	\N	2f15d7f1e7dff2999bcc3fb02cf8ff284727a8850f2590793c4f898bf87095bd	/home/extra/music/restitch/34c.flac
1042682	1042619	1042677	1042681	2012-11-30 06:03:19+00	0	\N	4de5d552211d4b3caae571e40a3247a5957d62d35de74b543cb5e62301fb7082	/home/extra/music/restitch/318.flac
1042656	1042551	1042532	1042655	2012-11-30 06:02:52+00	0	\N	adf13810049d16057a8a8f34d04bda69f425171f222be5b02f18a90d22c2326a	/home/extra/music/restitch/15ed.flac
1042660	1042658	1042659	1042657	2012-11-30 06:02:53+00	0	\N	477806aa1aac4dfcb88a5ddaf6c21e51649a04f14a6e307b023b30b0dc888d43	/home/extra/music/restitch/2d2.flac
1042662	1042535	1042532	1042661	2012-11-30 06:02:56+00	0	\N	f97aeddbfca5377f053392123d19d6504d375e9319087898b042ab3f4af8f165	/home/extra/music/restitch/15dd.flac
1042664	1042551	1042532	1042663	2012-11-30 06:02:57+00	0	\N	207c326b3b273391f9483a5aa8a15c4f6e1e0f756f9e531256f66d00a986a488	/home/extra/music/restitch/15eb.flac
1042666	1042591	1042542	1042665	2012-11-30 06:02:58+00	0	\N	30f81067c13205fd672426713250e8c03cdedb76096dafe142e66c464de8880d	/home/extra/music/restitch/15d5.flac
1042684	\N	\N	1042683	2012-11-30 06:03:23+00	0	\N	6b6057b6183ab88a093dd260e8cd0ea5c6195ca7b26d71713585dd8fd5f5f4c8	/home/extra/music/Walt_Disney_s_Robin_Hood_Whistle_Stop-OzFYb7_ySbU.aac
1042714	1042700	1042701	1042713	2012-11-30 06:03:32+00	0	\N	a8ebd193539dcce59657393f4a489a880c395a46a1da9c3d942c1a2b839e3313	/home/extra/music/Merriweather Post Pavilion/03 Also Frightened.mp3
1042688	1042686	1042687	1042685	2012-11-30 06:03:23+00	0	\N	63cc709c9984602691b29fefdfe4cd673c1f98288c3d5a7b291baac20e40084f	/home/extra/music/Henryk Mikołaj Górecki - Symphony No. 3 (Warsaw Philharmonic Orchestra feat. conductor: Kazimierz Kord, soprano: Joanna Kozłowska)/03. Henryk Mikołaj Górecki - Symphony No. 3, Op. 36 "Symphony of Sorrowful Songs": III. Lento: Cantabile semplice.flac
850	823	824	849	2012-11-30 05:04:29+00	0	\N	bf4626801cfb5e6cee3f25ed0ad0895ea9820dd7306d7ca7e6b8ec8405247ff6	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/06 - Assimilation (Alternate Version).mp3
1042743	1042724	1042725	1042742	2012-11-30 06:03:36+00	0	\N	c78cba33398ab1bf608565ea97d1a70f44bc4f42b0dd321a1287833ec2c436b0	/home/extra/music/Beirut - March Of The Zapotec - Holland [mp3-vbr-2009]/2.04 Beirut - The Concubine.mp3
1042692	1042686	1042687	1042691	2012-11-30 06:03:28+00	0	\N	399f79275c6ecafdd32ede44320b8610a6dfacf9ee50eb8846906e3a6aaa0c4e	/home/extra/music/Henryk Mikołaj Górecki - Symphony No. 3 (Warsaw Philharmonic Orchestra feat. conductor: Kazimierz Kord, soprano: Joanna Kozłowska)/02. Henryk Mikołaj Górecki - Symphony No. 3, Op. 36 "Symphony of Sorrowful Songs": II. Lento e largo: Tranquillissimo - Cantabilissimo - Dolcissimo - Legatissimo.flac
1042754	1042753	\N	1042752	2012-11-30 06:03:37+00	0	\N	03c321730ecb05d89ef630d11db1df67920f2d108fbebae1c11deb9653fdd845	/home/extra/music/songsIam/Simple Plan - Me Against The World.mp3
1042716	1042700	1042701	1042715	2012-11-30 06:03:33+00	0	\N	a2e8c0ce435432edcfac6c22edd300b834453cc81f2cfeda284d22189d7cdb12	/home/extra/music/Merriweather Post Pavilion/11 Brother Sport.mp3
1042702	1042700	1042701	1042699	2012-11-30 06:03:30+00	0	\N	b95944f9e4eb2bb476dbaa6a499bf08a5dba38f06b6d916543330c566d7ab736	/home/extra/music/Merriweather Post Pavilion/02 My Girls.mp3
1042704	1042700	1042701	1042703	2012-11-30 06:03:30+00	0	\N	0d02677da9510be6f4ddf100145da9c93ff4c5993654c91257d87cbd2e583e48	/home/extra/music/Merriweather Post Pavilion/09 Lion In A Coma.mp3
1042731	1042724	1042725	1042730	2012-11-30 06:03:35+00	0	\N	5c1718aae803ecf6c64f386d7c419eb9d26953fe4c720fdbdf1631cae23550c8	/home/extra/music/Beirut - March Of The Zapotec - Holland [mp3-vbr-2009]/2.03 Beirut - Venice.mp3
1042706	1042700	1042701	1042705	2012-11-30 06:03:31+00	0	\N	3285eadf7456197165d4bc2f1dc6ca9f2f91e165ce9aedea5b3cd72c479bf50f	/home/extra/music/Merriweather Post Pavilion/10 No More Runnin.mp3
1042718	1042700	1042701	1042717	2012-11-30 06:03:34+00	0	\N	832d76012c6ac97fa3402ffb14cb9e09f50f4bcb088ed259f4e0dee9816f23d7	/home/extra/music/Merriweather Post Pavilion/06 Bluish.mp3
1042708	1042700	1042701	1042707	2012-11-30 06:03:31+00	0	\N	4d773eb64f43e041f045d44f7122274be03410d1923770d7b8e57635cac2ef2b	/home/extra/music/Merriweather Post Pavilion/05 Daily Routine.mp3
1042710	1042700	1042701	1042709	2012-11-30 06:03:32+00	0	\N	247e9d424dbe77d3014dac31de0c24b1eca32373574a4964534cfe7cb31972f0	/home/extra/music/Merriweather Post Pavilion/07 Guys Eyes.mp3
1042712	1042700	1042701	1042711	2012-11-30 06:03:32+00	0	\N	056ec206dff243357652fece5433c305853f877046984ef2a38c6f1ab86cf657	/home/extra/music/Merriweather Post Pavilion/08 Taste.mp3
1042739	1042724	1042725	1042738	2012-11-30 06:03:36+00	0	\N	e6c9161520d7b01dc32b0b632ec0746041331433f7555e5e1b9ea1f522a1a59e	/home/extra/music/Beirut - March Of The Zapotec - Holland [mp3-vbr-2009]/2.02 Beirut - My Wife, Lost in the Wild.mp3
1042720	1042700	1042701	1042719	2012-11-30 06:03:34+00	0	\N	9916f2e721bdb1805f25446b603836bca34ddba821b62e2cd9aec4cad43c2816	/home/extra/music/Merriweather Post Pavilion/01 In The Flowers.mp3
1042733	1042724	1042728	1042732	2012-11-30 06:03:35+00	0	\N	9d81d4ae451ac74852818fef77c26608bb0740a1458c7bf50269ae3f2c67220c	/home/extra/music/Beirut - March Of The Zapotec - Holland [mp3-vbr-2009]/1.03 Beirut - My Wife.mp3
1042722	1042700	1042701	1042721	2012-11-30 06:03:34+00	0	\N	05cd64427a1add4ccaf14570abaf83868c0b44b0a3bccc1cc297ab1a4063d23a	/home/extra/music/Merriweather Post Pavilion/04 Summertime Clothes.mp3
1042726	1042724	1042725	1042723	2012-11-30 06:03:35+00	0	\N	f8e79c2afcc429001e41aeb8911d37789f5a3d7420cb3629d03c1b5fcf2d6eb9	/home/extra/music/Beirut - March Of The Zapotec - Holland [mp3-vbr-2009]/2.05 Beirut - No Dice.mp3
1042729	1042724	1042728	1042727	2012-11-30 06:03:35+00	0	\N	07700e9064770f29c099e609697b6634a3eba65c1521875c187817d700578b6d	/home/extra/music/Beirut - March Of The Zapotec - Holland [mp3-vbr-2009]/1.02 Beirut - La Llorona.mp3
1042735	1042724	1042728	1042734	2012-11-30 06:03:36+00	0	\N	ab2afa83d96a111eac41cd3b207fcd360588694d3b86b491d28a366f2073d6f7	/home/extra/music/Beirut - March Of The Zapotec - Holland [mp3-vbr-2009]/1.05 Beirut - On A Bayonet.mp3
1042737	1042724	1042728	1042736	2012-11-30 06:03:36+00	0	\N	6cdb7303235e2dea251968b2dab39fb0f4c009a4c052f3b05c4e6c1b64f696dd	/home/extra/music/Beirut - March Of The Zapotec - Holland [mp3-vbr-2009]/1.01 Beirut - El Zocalo.mp3
1042741	1042724	1042728	1042740	2012-11-30 06:03:36+00	0	\N	3bfbdcfd0ff2495acc245f77cff9951c8a60883312c038be9057bb6b69d1c455	/home/extra/music/Beirut - March Of The Zapotec - Holland [mp3-vbr-2009]/1.04 Beirut - The Akara.mp3
1042745	1042724	1042725	1042744	2012-11-30 06:03:36+00	0	\N	8e18e50bd43084c3af96ab7b355b0281f2db236d4aadc83a452e68d7e7e7eba0	/home/extra/music/Beirut - March Of The Zapotec - Holland [mp3-vbr-2009]/2.01 Beirut - My Night with the Prostitute From Marseille.mp3
1042690	1042686	1042687	1042689	2012-11-30 06:03:25+00	0	\N	bebb9b2a350c80c0ce715615ed094480f21b9a8473a9751d89df9890870a075a	/home/extra/music/Henryk Mikołaj Górecki - Symphony No. 3 (Warsaw Philharmonic Orchestra feat. conductor: Kazimierz Kord, soprano: Joanna Kozłowska)/01. Henryk Mikołaj Górecki - Symphony No. 3, Op. 36 "Symphony of Sorrowful Songs": I. Lento: Sostenuto tranquillo ma cantabile.flac
1042747	1042724	1042728	1042746	2012-11-30 06:03:37+00	0	\N	bfb4156d1c5cc8eeb70bf5402204294c646f8deacd3237bc032ac3dab940ee0e	/home/extra/music/Beirut - March Of The Zapotec - Holland [mp3-vbr-2009]/1.06 Beirut - The Shrew.mp3
852	823	824	851	2012-11-30 05:04:29+00	0	\N	9e5753ce1d426a062a8fbcbc7af45e5604c44a4a33e0f15d37bb3f9cb173bb1b	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd2/09 - The Dish (Commercial Release).mp3
1042698	\N	\N	1042697	2012-11-30 06:03:30+00	0	\N	3e1b8be4b174ada2b29fa7496dcfd0057bf485b3bcbafede9fe30cebea732a63	/home/extra/music/Secret_of_Mana_Opening_Theme-T6YAiLHXw_c.aac
1042751	1042749	1042750	1042748	2012-11-30 06:03:37+00	0	\N	8664c3d43fd2507931202afb71375500c4bd2a1e48732009ff7dbda5a9946c47	/home/extra/music/songsIam/04_-_Aisling_Song.mp3
1042810	1042809	\N	1042808	2012-11-30 06:03:40+00	0	\N	298990c6bd363031feeb202f00a7d5b4e3ae0d31c0c432be86a435c5d5285101	/home/extra/music/songsIam/Cartoni Animati - Pokemon - Jigglypuff remix.mp3
1042818	1042816	1042817	1042815	2012-11-30 06:03:40+00	0	\N	ad0928a54644e4ac1b29cb2278d39f3d3fc958cf8b14f690712b56eb4f860aa5	/home/extra/music/songsIam/ATC- It Goes Around The World LaDaDaDaDa.mp3
1042792	1042791	\N	1042790	2012-11-30 06:03:39+00	0	\N	1ea68085b8c50dc855348cede63fb61d9a1713316a33240dc26580fbc884c20a	/home/extra/music/songsIam/YouAreLoved.mp3
1042796	1042794	1042795	1042793	2012-11-30 06:03:39+00	0	\N	ebb0d3d4b9637b5e442fd928f13f37971c4e04bb9c286e2cdf5f4ef2b5cbba73	/home/extra/music/songsIam/Bif Naked - Spaceman (original).mp3
1042800	1042798	1042799	1042797	2012-11-30 06:03:40+00	0	\N	6e8d38fa0cfd97d8aa8cd900dd046b443015a0f75a93967779d647aeb5a153b1	/home/extra/music/songsIam/Weird Al Yankovic - Everything You Know Is Wrong.mp3
1042855	1042831	1042832	1042854	2012-11-30 06:03:45+00	0	\N	ed0cfe98758ffcde1276d8501d144a03ac9b570ac7a2c343c02b3338a5048d2a	/home/extra/music/Classical Music Top 100/011. Johann Sebastian Bach - Matthäus Passion (BWV 244) - Kommt, Ihr Töchter.mp3
1042851	1042831	1042832	1042850	2012-11-30 06:03:44+00	0	\N	15c4f4fd82520f06d897eb4bbdae890f59bac52486484f1e85d51fa7505f29d1	/home/extra/music/Classical Music Top 100/073. Johann Sebastian Bach - Doppelkonzert F√ºr Zwei Violinen (BWV 1043) - Largo Ma Non Tanto.mp3
1042822	1042820	1042821	1042819	2012-11-30 06:03:41+00	0	\N	d285637455e74ccde4c5d05a477098dd329f2a56dfa8610d99f40e497ce26b20	/home/extra/music/songsIam/hack sign - a stray child.mp3
1042857	1042831	1042832	1042856	2012-11-30 06:03:46+00	0	\N	e35bed05ca6686c6a5d75e284e6da440e994eaead10a03284d5cb2f3ec7f67c8	/home/extra/music/Classical Music Top 100/038. Max Christian Friedrich Bruch - Violinkonzert Nr. 1 (Op. 26) - Allegro Moderato.mp3
1042849	1042831	1042832	1042848	2012-11-30 06:03:44+00	0	\N	daab4b5cea73471894e5dd676666648a865b2e03d8b4a16f77519a3d669a59a3	/home/extra/music/Classical Music Top 100/003. Ludwig van Beethoven - Piano Concerto No. 5 (Op. 73) - Adagio Un Poco Mosso.mp3
906	823	861	905	2012-11-30 05:04:36+00	0	\N	e372f4fa7e95c7d9f55f80f5e450592b8d15c82a2070b1454814038dfe732d53	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/17 - Definitely Not Swedish.mp3
1042773	1042771	1042772	1042770	2012-11-30 06:03:38+00	0	\N	35230a0151b2aa41b813c9742765652c8c1794ad95fd551660425c5f79e836b0	/home/extra/music/songsIam/Angels And Airwaves - The Adventure.mp3
1042777	1042775	1042776	1042774	2012-11-30 06:03:38+00	0	\N	bd72900c96e70c1d6e7082ccf3009030c613c9f33db02cff5b45bdaffcbc9a1d	/home/extra/music/songsIam/126 I'm Moogle.mp3
1042814	1042812	1042813	1042811	2012-11-30 06:03:40+00	0	\N	04a31bd7a3cf55f8e2f958e0f9b0c20797120cc199152b70c8864d7761e9cb7e	/home/extra/music/songsIam/Chrono Trigger - Schala's Theme.mp3
1042789	1042787	1042788	1042786	2012-11-30 06:03:39+00	0	\N	f7f902ed3116d83418c26fa29aeb066515de3dac68a2fe2f40344c3a5049511c	/home/extra/music/songsIam/Evanescence - Imaginary.mp3
1042837	1042831	1042832	1042836	2012-11-30 06:03:42+00	0	\N	fa97a67240f8ec442236c3f0c6c51ee6a52adaf89ae8ede7bc8a57bdf34a70b6	/home/extra/music/Classical Music Top 100/087. Ennio Morricone - C'era Una Volta Il West (Once Upon A Time In The West).mp3
1042785	1042783	1042784	1042782	2012-11-30 06:03:39+00	0	\N	535a3a34c4eb8d40b7733d8c14c19488cf2023ebcc8dcab7913efbc97cdec412	/home/extra/music/songsIam/Beatles - Imagine.mp3
1042769	1042767	1042768	1042766	2012-11-30 06:03:38+00	0	\N	5e0783f474d4fbe646c28abe8c7e1982b8bcc0367a60cd35db74e469eebef67d	/home/extra/music/songsIam/Keep_Your_Jesus_off_My_Penis.mp3
1042861	1042831	1042832	1042860	2012-11-30 06:03:47+00	0	\N	15e1a7ebc45d5ea18ae99e57b7ec5fccf67afcc79712104da2668f7a1b533d62	/home/extra/music/Classical Music Top 100/089. Georg Friederich H√§ndel - Solomon (HWV 67) - The Arrival Of The Queen Of Sheba.mp3
1042853	1042831	1042832	1042852	2012-11-30 06:03:45+00	0	\N	90a5895e5ec58fc5746474a89bfebd609920361376be9b49ecd1e8512d65fc61	/home/extra/music/Classical Music Top 100/022. Giulio Caccini - Ave Maria.mp3
1042847	1042831	1042832	1042846	2012-11-30 06:03:44+00	0	\N	c0eea679d9c2c69b27431f9567d952a47dbe002a22188d0008ff4ceed2d6dd02	/home/extra/music/Classical Music Top 100/063. Wolfgang Amadeus Mozart - Exsultate, Jubilate (K. 165).mp3
1042839	1042831	1042832	1042838	2012-11-30 06:03:42+00	0	\N	99e7eff6a7b78bbcce07eed6bb3dc78b25c507e4cf05857df63de35fdbe21ac4	/home/extra/music/Classical Music Top 100/056. Johann Sebastian Bach - Jesu, Der Du Meine Seele (BWV 78) - Wir Eilen Mit Schwachen.mp3
910	823	861	909	2012-11-30 05:04:36+00	0	\N	739613d758ba095ae72156e40168e2da658995a64149e6f597e80e3375c29655	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 08 - First Contact 1996/cd1/26 - Resistance Is Futile!.mp3
1042845	1042831	1042832	1042844	2012-11-30 06:03:43+00	0	\N	45feb1a1696fe4dcb0118fd23bd5bbde75de52383a61ac55d031ee10f2a903b3	/home/extra/music/Classical Music Top 100/016. Ludwig van Beethoven - Symphony No. 9 (Op. 125).mp3
1042859	1042831	1042832	1042858	2012-11-30 06:03:47+00	0	\N	3f4afafc409ac52d5f607f8afe75de631d1eea09a20b45120ec720349173644e	/home/extra/music/Classical Music Top 100/080. Joaqu√≠n Rodrigo Vidre - Concierto De Aranjuez - Adagio.mp3
1042833	1042831	1042832	1042830	2012-11-30 06:03:41+00	0	\N	dcd3fc8aacb8d1645c3719a885dce566aee6aee80a6bff890ac910f03cf9ca59	/home/extra/music/Classical Music Top 100/027. Georges Bizet - Les Pêcheurs De Perles - Au Fond Du Temple Saint.mp3
1042835	1042831	1042832	1042834	2012-11-30 06:03:42+00	0	\N	9c5c0f6268f23e1794abfaafd9cb90f609d99585b451df1eb928f5524fdd9501	/home/extra/music/Classical Music Top 100/083. Johann Sebastian Bach - Wachet Auf, Ruft Uns Die Stimme (BWV 140).mp3
1042807	1042806	\N	1042805	2012-11-30 06:03:40+00	0	\N	261c0852731fa892ebd3c1e1d78f92d037d2a9dc1487745eff95553aa9439598	/home/extra/music/songsIam/01 - Rammstein - Feuer frei.mp3
1042841	1042831	1042832	1042840	2012-11-30 06:03:43+00	0	\N	81d27476ea6612151a3e917cbe4c95ba2c0db14b0ff4b8c812803ad1b77fa762	/home/extra/music/Classical Music Top 100/040. Giuseppe Fortunino Francesco Verdi - Aida - Marcia Trionfale.mp3
1042826	1042824	1042825	1042823	2012-11-30 06:03:41+00	0	\N	e566674b0bcfbc23ac117c92df425df042d427634a15095aa1fed9fba1fa49af	/home/extra/music/Paul Robeson - Going Home (Dvorak).mp3
1042781	1042779	1042780	1042778	2012-11-30 06:03:39+00	0	\N	eb21d01ab315f04843656277bbc2678aaa5e87d73d7df088e873facbfb099c15	/home/extra/music/songsIam/Nightwish - Wishmaster.mp3
964	946	947	963	2012-11-30 05:04:43+00	0	\N	66088c5cba9bbe681a1b308d32cfea2b27b010fa6b31d2a6ae5cdf878cc67fd6	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 02 - The Wrath of Khan 1982/02 - ST II - Surprise Attack.mp3
1042907	1042831	1042832	1042906	2012-11-30 06:03:56+00	0	\N	454fac27a167c88713d29ee001a57301dbadfaf38d348b89994ed34219d80003	/home/extra/music/Classical Music Top 100/052. Gabriel Urbain Faur√© - Requiem (Op. 48) - Pie Jesu.mp3
1042903	1042831	1042832	1042902	2012-11-30 06:03:56+00	0	\N	9bda4d8d44ab049f3f6bcf040e38bca899c21fa1021ed3751cc41c931b8c56f6	/home/extra/music/Classical Music Top 100/061. Pyotr Ilyich Tchaikovsky - The Nutcracker (Op. 71) - Waltz Of The Flowers - –©–µ–ª–∫—É–Ω—á–∏–∫.mp3
1042883	1042831	1042832	1042882	2012-11-30 06:03:52+00	0	\N	f937f65d38680037aa6cd0fea118382ae67834f0f1cd12e27a79f189ee02b600	/home/extra/music/Classical Music Top 100/026. Johann Sebastian Bach - Weihnachtsoratorium (BWV 248) - Jauchzet, Frohlocket.mp3
1042877	1042831	1042832	1042876	2012-11-30 06:03:50+00	0	\N	cc6ab266308adbcb5301c58d8b032ca7fb0c88b8f4d4649f64e96c3bb924caae	/home/extra/music/Classical Music Top 100/009. Sergej Vassiljevitsj Rachmaninoff - Piano Concerto No. 2 (Op. 18) - Adagio Sostenuto.mp3
1042887	1042831	1042832	1042886	2012-11-30 06:03:52+00	0	\N	8336055edbab0a305f4bff8ab51168a9f4fecf14233a0ad9fca85d1cd3d9c1a6	/home/extra/music/Classical Music Top 100/051. Fr√©d√©ric Fran√ßois Chopin - Concerto Pour Piano No. 1 (Op. 11) - Romance.mp3
1042901	1042831	1042832	1042900	2012-11-30 06:03:55+00	0	\N	2e3fa0daca338dcd33abcff65fd1b617a52306a9d22ab756ebb4329d911ecef1	/home/extra/music/Classical Music Top 100/088. Wolfgang Amadeus Mozart - 23. Klavierkonzert (K. 488) - Adagio.mp3
1042905	1042831	1042832	1042904	2012-11-30 06:03:56+00	0	\N	ee113dbaca0675faecd4d8896cda08df67f8491dc664eb75e07f6982618d3ba9	/home/extra/music/Classical Music Top 100/067. Jules √âmile Fr√©d√©ric Massenet - Tha√_s - M√©ditation.mp3
1042911	1042831	1042832	1042910	2012-11-30 06:03:57+00	0	\N	b33c24907dc17af0b3c224bbdddcc9014ee372dc0e815d6d89d4ea31b819c6e2	/home/extra/music/Classical Music Top 100/076. Pyotr Ilyich Tchaikovsky - Piano Concerto No. 1 (Op. 23) - Allegro Non Troppo E Molto Maestoso.mp3
1042865	1042831	1042832	1042864	2012-11-30 06:03:48+00	0	\N	67210161b0600317cc545fd2c4308919a471233834b3e27118654bd8db2d1cf1	/home/extra/music/Classical Music Top 100/010. Tomaso Giovanni Albinoni - Adagio In Sol Minore.mp3
1042915	1042831	1042832	1042914	2012-11-30 06:03:58+00	0	\N	1f7eed38fe37ff2e26e3dba04c9399ba02b907cb54d87c89f4ce2e1c635a0d94	/home/extra/music/Classical Music Top 100/097. Aram Ilich Khachaturian - Spartacus - Adagio Of Spartacus And Phrygia.mp3
1042869	1042831	1042832	1042868	2012-11-30 06:03:49+00	0	\N	a3e66f353493d0f414f9bfac60a229cb99c53ed63c7537ad44806ed79c9d1ab7	/home/extra/music/Classical Music Top 100/008. Antonín Dvořák - New World Symphony (Op. 95) - Largo.mp3
1042885	1042831	1042832	1042884	2012-11-30 06:03:52+00	0	\N	29cee91f2b71d1469752554da1056a37f317773b6dfdfeb31dc4610ef6e9258c	/home/extra/music/Classical Music Top 100/054. Wolfgang Amadeus Mozart - Symphony No. 40 (K. 550) - Molto Allegro.mp3
1042917	1042831	1042832	1042916	2012-11-30 06:03:58+00	0	\N	aa8dd79da4bc24df9c13ca5e34cccd3d8aa837bc8c67082d73f31de757bb9ba3	/home/extra/music/Classical Music Top 100/034. Wolfgang Amadeus Mozart - Eine Kleine Nachtmusik (K. 525).mp3
1042867	1042831	1042832	1042866	2012-11-30 06:03:48+00	0	\N	702afbfaf98d3e557b67c2746244b5136dfcfa9f2514b138e30daf65e76fbdb7	/home/extra/music/Classical Music Top 100/059. Gregorio Allegri - Miserere (Psalm 51).mp3
1042893	1042831	1042832	1042892	2012-11-30 06:03:53+00	0	\N	050fefdac6ebbbd8507ae55d72f36da327693de61bf08240089a37d4d3f36e2e	/home/extra/music/Classical Music Top 100/058. Ludwig van Beethoven - Mondscheinsonate (Op. 27).mp3
1042863	1042831	1042832	1042862	2012-11-30 06:03:48+00	0	\N	f379921078b8d36ef4f732db7562635a3ad39abc40565f1e4a6091b8bcdac5a0	/home/extra/music/Classical Music Top 100/091. Johann Strauss, Jr. - An Der Sch√∂nen Blauen Donau (Op. 314).mp3
1042875	1042831	1042832	1042874	2012-11-30 06:03:50+00	0	\N	8066401cacf5c1ae54a67b105da7c6307a8014e1abf5ad52f458c9592433e403	/home/extra/music/Classical Music Top 100/075. Georges Bizet - Carmen - Habanera.mp3
1042913	1042831	1042832	1042912	2012-11-30 06:03:58+00	0	\N	34e3777c0c3979224343b8038fabe88a602f075763730fdcdf7edd75dbd2a136	/home/extra/music/Classical Music Top 100/042. Ludwig van Beethoven - Symphony No. 6 (Op. 68).mp3
1042873	1042831	1042832	1042872	2012-11-30 06:03:50+00	0	\N	612c4020cecd6630f82955a2af9f424e652d693f791d65257b1ad5f6b41fb26d	/home/extra/music/Classical Music Top 100/066. Aafje Heynis - Dank Sei Dir, Herr.mp3
1042909	1042831	1042832	1042908	2012-11-30 06:03:57+00	0	\N	412280350d39d2ec9c19f2c76ba1d4a831b11c30aaff589a4ce883e73c0f87d0	/home/extra/music/Classical Music Top 100/079. Gabriel Urbain Faur√© - Requiem (Op. 48) - In Paradisum.mp3
1042895	1042831	1042832	1042894	2012-11-30 06:03:54+00	0	\N	38c63624721de71ce866d02d3945abbedf488c314deba488032bc3dd8b0ad84d	/home/extra/music/Classical Music Top 100/071. Giuseppe Fortunino Francesco Verdi - Rigoletto - La Donna √à Mobile.mp3
1042889	1042831	1042832	1042888	2012-11-30 06:03:53+00	0	\N	341bd5b9f27c15cf9d950f213846a975efb9e33523b2e886bcd4eadc5433861b	/home/extra/music/Classical Music Top 100/085. Christoph Willibald Ritter von Gluck - Orfeo Ed Euridice - Dance Of The Blessed Spirits.mp3
1042871	1042831	1042832	1042870	2012-11-30 06:03:49+00	0	\N	71eb09bba098688c4fdf9f66a250d72a8fc51b0c361c699902e4014eff4d9650	/home/extra/music/Classical Music Top 100/046. Wolfgang Amadeus Mozart - Vesperae De Dominica (K. 321) - Laudate Dominum.mp3
1042881	1042831	1042832	1042880	2012-11-30 06:03:51+00	0	\N	dc279e9351c17acf175461acd852c202d3072b2a756f86b04430cd5d1b3a734e	/home/extra/music/Classical Music Top 100/100. C√©sar-Auguste-Jean-Guillaume-Hubert Franck - Panis Angelicus.mp3
1042897	1042831	1042832	1042896	2012-11-30 06:03:54+00	0	\N	5e9f98c084815a7930397457a485ee57060c2df10a2b69c18dc71c0d28aba87d	/home/extra/music/Classical Music Top 100/037. Johann Sebastian Bach - Orchestersuite Nr. 2 (BWV 1067) - Badinerie.mp3
1042879	1042831	1042832	1042878	2012-11-30 06:03:51+00	0	\N	9a06d0fb3361d2c633c442b45d42163caa04bc1f58345aff1eab0e14bdddc0bd	/home/extra/music/Classical Music Top 100/004. Wolfgang Amadeus Mozart - Klarinettenkonzert (K. 622) - Adagio.mp3
1042891	1042831	1042832	1042890	2012-11-30 06:03:53+00	0	\N	783fa2f0bf00f956d7068a0f5511e61329c92c772ebfb333736b6c855d886895	/home/extra/music/Classical Music Top 100/092. Wolfgang Amadeus Mozart - Klarinettenkonzert (K. 622) - Rondo.mp3
1019	966	967	1018	2012-11-30 05:04:48+00	0	\N	f3dff79e2086a2384d4c8374149ac22aa08aba1c8249e10f6aac88f0373b293c	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/22 - Enterprise B Warp Pass-by.mp3
1042921	1042831	1042832	1042920	2012-11-30 06:03:59+00	0	\N	d846357de32c054e932c1ce7b3886886a20da4cd7f942993d799126901f8c12c	/home/extra/music/Classical Music Top 100/068. Wolfgang Amadeus Mozart - Piano Concerto No. 21 (K. 467).MP3
1042959	1042831	1042832	1042958	2012-11-30 06:04:06+00	0	\N	1c325baf485f85b7c98a1e063c04f0f0f0b06af2267fc32ddde39909da925ffd	/home/extra/music/Classical Music Top 100/065. Fr√©d√©ric Fran√ßois Chopin - Concerto Pour Piano No. 2 (Op. 21).mp3
1042943	1042831	1042832	1042942	2012-11-30 06:04:03+00	0	\N	5db1fc4def9304bcaec2fa17f781eb4f41dd1f88972c447085f89a95b1547731	/home/extra/music/Classical Music Top 100/062. Vincenzo Salvatore Carmelo Francesco Bellini - Norma - Casta Diva.mp3
1042965	1042831	1042832	1042964	2012-11-30 06:04:07+00	0	\N	7d34c5dafadd3561263b2c07e8c98ad5bfb50ffee7fcc6d39c6a594b73127993	/home/extra/music/Classical Music Top 100/044. George Gershwin - Rhapsody In Blue.mp3
1042953	1042831	1042832	1042952	2012-11-30 06:04:05+00	0	\N	0ece71f40b54f9d73c41e57f79831fae47f79cd34937b60b56762d107f145640	/home/extra/music/Classical Music Top 100/093. Jean Sibelius - Finlandia (Op. 26).mp3
1042935	1042831	1042832	1042934	2012-11-30 06:04:02+00	0	\N	e7b8d1a0a7369f3c60340f690f2da4b4acceee8afc22dacd2db41a931cfbe10a	/home/extra/music/Classical Music Top 100/029. Maurice Ravel - Boléro.mp3
1042951	1042831	1042832	1042950	2012-11-30 06:04:04+00	0	\N	a38f267707e5c757c588e305474863764b4fbb0a6fc63f170fbb9d8cac7d46d8	/home/extra/music/Classical Music Top 100/078. Niccol√≤ Paganini - Concerto Pour Violon No. 1 (Op. 6).mp3
1042967	1042831	1042832	1042966	2012-11-30 06:04:08+00	0	\N	5927548accce327a5ce41e4661445a602acfd5a0b8343620be9606dfa9b7b74c	/home/extra/music/Classical Music Top 100/Orfeo Ed Euridice - Che Farò Senza Euridice_.mp3
1021	966	967	1020	2012-11-30 05:04:48+00	0	\N	795eb70c47fbc9baffddf537f0ab57fbe25cfb823b61999453a40640ea32d50a	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 07 - Generations 1994/29 - Bird Of Prey Bridge - Explosion.mp3
1042957	1042831	1042832	1042956	2012-11-30 06:04:05+00	0	\N	ac856d53d03c2d800169a628c10032540c7cc2d45f680b5b4427b46813a9514c	/home/extra/music/Classical Music Top 100/035. Ludwig van Beethoven - Für Elise (WoO 59).mp3
1042933	1042831	1042832	1042932	2012-11-30 06:04:01+00	0	\N	988f413e71a82d486289c77a734d93858c7978015edde9a73bb8c598b50035cd	/home/extra/music/Classical Music Top 100/033. Charles-François Gounod - Ave Maria.mp3
1042947	1042831	1042832	1042946	2012-11-30 06:04:04+00	0	\N	8ec934ebbe79e07431ba54a5c74662733a9be24dac6793c812b4ba85ba157e25	/home/extra/music/Classical Music Top 100/031. Johann Sebastian Bach - Toccata E Fuga (BWV 565).mp3
1042961	1042831	1042832	1042960	2012-11-30 06:04:06+00	0	\N	afe74bb89a6cb30107e63d9a1f4c11b33b1f476e84a6b968ccbb2d6ae64b8f26	/home/extra/music/Classical Music Top 100/024. Bedřich Smetana - Má Vlast - Vltava.mp3
1042973	1042831	1042832	1042972	2012-11-30 06:04:09+00	0	\N	d8564aa697780f56a405690155d5c9c92a931dcd1c2b59109cf7399edde11a82	/home/extra/music/Classical Music Top 100/036. Wolfgang Amadeus Mozart - Die Zauberflöte (K. 620) - Der Hölle Rache Kocht In Meinem Herzen.mp3
1042937	1042831	1042832	1042936	2012-11-30 06:04:02+00	0	\N	a602f058a1da0f83af9549b6a5c0cd998433c0534aecb27d40a429d8b878d352	/home/extra/music/Classical Music Top 100/023. Wolfgang Amadeus Mozart - Ave Verum Corpus (K. 618).mp3
1042945	1042831	1042832	1042944	2012-11-30 06:04:04+00	0	\N	784abfabcea23520ac1b894437a2755a2cf0449d1569eb0881c4a24c7cb3b8bb	/home/extra/music/Classical Music Top 100/021. Carl Orff - Carmina Burana - O Fortuna.mp3
1042955	1042831	1042832	1042954	2012-11-30 06:04:05+00	0	\N	b738710bff04459e67eed31fb68758f1f8defcad248f615bcc0d8b2040226160	/home/extra/music/Classical Music Top 100/060. Wolfgang Amadeus Mozart - Requiem (K. 626) - Dies Irae.mp3
1042927	1042831	1042832	1042926	2012-11-30 06:04:00+00	0	\N	75ddc2c4ebdbd1cecdaba0923575821155b8c3c23293df4daee4aa3f2665359e	/home/extra/music/Classical Music Top 100/086. Wolfgang Amadeus Mozart - Konzert F√ºr Fl√∂te, Harfe Und Orchester (K. 299) - Allegro.mp3
1042919	1042831	1042832	1042918	2012-11-30 06:03:59+00	0	\N	5e4994086b83abcc4ebefd21c1575049004aa8fb90b910bf1c158d328dc9dd72	/home/extra/music/Classical Music Top 100/018. Samuel Osborne Barber - Adagio For Strings.mp3
1042931	1042831	1042832	1042930	2012-11-30 06:04:01+00	0	\N	45c937f8f542dd7f31f24716c50666dd4fc00967ea10da3ce745512905d67944	/home/extra/music/Classical Music Top 100/096. Wolfgang Amadeus Mozart - Le Nozze Di Figaro (K. 492) - Voi, Che Sapete Che Cosa E Amor.mp3
1042929	1042831	1042832	1042928	2012-11-30 06:04:01+00	0	\N	7962a9504faf02244ee44d3f1c4986eb64c0eb4f3da4b0f6e598a82598d8de77	/home/extra/music/Classical Music Top 100/070. Wolfgang Amadeus Mozart - Requiem (K. 626) - Kyrie Eleison.mp3
1042925	1042831	1042832	1042924	2012-11-30 06:04:00+00	0	\N	5c47b43c34c76c52450e8e827b28119ca377688bbd1485dabcf7e6f4419f4d54	/home/extra/music/Classical Music Top 100/028. Giuseppe Fortunino Francesco Verdi - Nabucco - Va, Pensiero.mp3
1042977	1042831	1042832	1042976	2012-11-30 06:04:09+00	0	\N	dbbf72ad6d2d2913b4ff5d004f83d4897df5129789e3d8650aa69af87b83c8a6	/home/extra/music/Classical Music Top 100/048. Ludwig van Beethoven - Piano Concerto No. 5 (Op. 73) - Rondo.mp3
1042975	1042831	1042832	1042974	2012-11-30 06:04:09+00	0	\N	bf84f51336a0404bd204ae68dd30aa6498d30fe74b4e4bc2aeb959660bc2f4a3	/home/extra/music/Classical Music Top 100/015. Gustav Mahler - Symphony No. 5.mp3
1042923	1042831	1042832	1042922	2012-11-30 06:03:59+00	0	\N	9a6f03a2bb8714ad51f97f6b2bdb1631cd9514d0b8bb9e77b291967e73979e7b	/home/extra/music/Classical Music Top 100/041. Giovanni Battista Pergolesi - Stabat Mater.mp3
1042941	1042831	1042832	1042940	2012-11-30 06:04:03+00	0	\N	ab20fe033395f47aa694f4a37fae2893b83f0869fd98788df7ce43807ba76fe9	/home/extra/music/Classical Music Top 100/057. Anton√≠n Dvo≈ô√°k - Rusalka - Mƒõs√≠ƒçku Na Nebi Hlubok√©m.mp3
1042971	1042831	1042832	1042970	2012-11-30 06:04:08+00	0	\N	34e11f4c2dda2a788c8c20f3fe7c04a4c08b622e958ba9effd1d80d4b13a345c	/home/extra/music/Classical Music Top 100/039. Wolfgang Amadeus Mozart - Requiem (K. 626) - Introitus.mp3
1042963	1042831	1042832	1042962	2012-11-30 06:04:07+00	0	\N	c15b7dc71cb5a56b8be09cdfcf3058f0af37e52dd8f9d889f51d0cb444daf4e3	/home/extra/music/Classical Music Top 100/017. Johann Sebastian Bach - Jesus Bleibet Meine Freude (BWV 147).mp3
1042969	1042831	1042832	1042968	2012-11-30 06:04:08+00	0	\N	82cffd61aebae68248974e5cad97e794ebced1b86d53814edd2e0bc32eab96eb	/home/extra/music/Classical Music Top 100/050. Ludwig van Beethoven - Symphony No. 5 (Op. 67).mp3
1042949	1042831	1042832	1042948	2012-11-30 06:04:04+00	0	\N	cfb51c0e373cac8c28db650786943aef043478b471317a2f442c283343f5fa29	/home/extra/music/Classical Music Top 100/020. Wolfgang Amadeus Mozart - Die Zauberflöte (K. 620) - Der Vogelfänger Bin Ich Ja.mp3
1042979	1042831	1042832	1042978	2012-11-30 06:04:09+00	0	\N	39e1776decbfe8aeba3edf2b4bdf131ecb6bcffa0c07fe1f93cdddf22ac1cfc3	/home/extra/music/Classical Music Top 100/081. Pietro Mascagni - Cavalleria Rusticana - Intermezzo.mp3
1043023	1042831	1042832	1043022	2012-11-30 06:04:17+00	0	\N	b07272f22da619b360e4c725bb2f42332d4fce1f16cc8c8cdf1d2ad886ecabf0	/home/extra/music/Classical Music Top 100/094. Wolfgang Amadeus Mozart - Kr√∂nungsmesse (K. 317) - Agnus Dei.mp3
1070	823	1043	1069	2012-11-30 05:04:53+00	0	\N	e4b61a5339ae7b2738006624c555e216ae00e9723ce979136001bdabf9038dbb	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/09 - To Romulus.mp3
1042981	1042831	1042832	1042980	2012-11-30 06:04:10+00	0	\N	b46c30605614f5f5de74b957642e2c86b0339414c600d32142359cdaa76cc3e5	/home/extra/music/Classical Music Top 100/077. Giacomo Antonio Domenico Michele Secondo Maria Puccini - Turandot - Nessun Dorma.mp3
1043027	1042831	1042832	1043026	2012-11-30 06:04:18+00	0	\N	802adc409d3d3c9305521871f277a80ff2aa8a5913a5a649c3035606133c3948	/home/extra/music/Classical Music Top 100/014. Edvard Hagerup Grieg - Peer Gynt Suite No. 1 (Op. 46) - Morgenstemning.mp3
1043015	1042831	1042832	1043014	2012-11-30 06:04:16+00	0	\N	0da3597de1432af2bacea92f0d3ec0f8e6b2f08b07fde9a98430af7dc4849fef	/home/extra/music/Classical Music Top 100/069. Johann Sebastian Bach - Brandenburgisches Konzert Nr. 1 (BWV 1046) - Allegro.mp3
1043011	1042831	1042832	1043010	2012-11-30 06:04:15+00	0	\N	11fadfb31fd03660cb30ab94af4abf20b9d66dfd303a9e6343bdb2a47298cb63	/home/extra/music/Classical Music Top 100/006. Johann Pachelbel - Kanon In D.mp3
1043017	1042831	1042832	1043016	2012-11-30 06:04:16+00	0	\N	053ddee372e4fa4c883fab76c493e12a5716d8d9d0e647ff24a9fa806d941a99	/home/extra/music/Classical Music Top 100/099. Wolfgang Amadeus Mozart - 23. Klavierkonzert (K. 488) - Allegro.mp3
1043001	1042831	1042832	1043000	2012-11-30 06:04:14+00	0	\N	c5b88b2920873a69d0f6ecf301c11112f2ef007602d140ccf5fe2c7759dac9ed	/home/extra/music/Classical Music Top 100/074. Georg Friederich H√§ndel - Serse (HWV 40) - Ombra Mai F√π.mp3
1042989	1042831	1042832	1042988	2012-11-30 06:04:11+00	0	\N	55261fa846039b2287676b844aa2bffb5a9a15b7dfcf4d1a1129411cdacb3b4f	/home/extra/music/Classical Music Top 100/098. Max Christian Friedrich Bruch - Violinkonzert Nr. 1 (Op. 26) - Adagio.mp3
1042993	1042831	1042832	1042992	2012-11-30 06:04:12+00	0	\N	526293a80f00a849441b9e6e5d825eca3ea5df89f47dd11abcfbe49800444bf8	/home/extra/music/Classical Music Top 100/053. Sergei Sergeyevich Prokofiev - Romeo And Juliet Suite No. 2 (Op. 64b) - The Montagues And Capulets.mp3
1043003	1042831	1042832	1043002	2012-11-30 06:04:14+00	0	\N	27d52fdf4315f32fe6d3d458acb1b06c67e2a7a776ff9189e0155a22fa070534	/home/extra/music/Classical Music Top 100/055. Sergej Vassiljevitsj Rachmaninoff - Piano Concerto No. 2 (Op. 18) - Moderato.mp3
1043021	1042831	1042832	1043020	2012-11-30 06:04:17+00	0	\N	47db43822cbd88580de18409a7d1befe331651bbd6f05fd7f5c18da8c99da8fd	/home/extra/music/Classical Music Top 100/045. Charles Camille Saint-Saëns - Danse Macabre.mp3
1042983	1042831	1042832	1042982	2012-11-30 06:04:10+00	0	\N	31eb7e11383ad4f6f655d946f3804c75b749887f2be20953fde973bb8af873d9	/home/extra/music/Classical Music Top 100/090. Wolfgang Amadeus Mozart - Requiem (K. 626) - Domine Jesu Christe.mp3
1042995	1042831	1042832	1042994	2012-11-30 06:04:12+00	0	\N	452c8df0fe2edb7379aafdaee53097edb91a065f9e01ce42ee15bfd2245167c1	/home/extra/music/Classical Music Top 100/043. Georg Friederich Händel - Messiah (HWV 56) - For Unto Us A Child Is Born.mp3
1043005	1042831	1042832	1043004	2012-11-30 06:04:14+00	0	\N	c80d330eccdad84a66c1db56c08d4c6d3a9ec95ae2d14ba7926ef95a047f2c34	/home/extra/music/Classical Music Top 100/049. Antonio Lucio Vivaldi - Le Quattro Stagioni (Op. 8, RV 293) - l'Autunno.mp3
1042991	1042831	1042832	1042990	2012-11-30 06:04:12+00	0	\N	bc4b6ce0ca472101fd72add4836962ba8327174bdcd1b128c2e223c9376c5ddb	/home/extra/music/Classical Music Top 100/095. Erik Alfred Leslie Satie - Gymnop√©die No.1.mp3
1043039	\N	\N	1043038	2012-11-30 06:04:20+00	0	\N	0b0d401d3dcb14807abdf1f06bda6300f3ed7966209c33a952b6b7c5fc0228eb	/home/extra/music/brahms-haydn-variations_vbr.mp3
1043007	1042831	1042832	1043006	2012-11-30 06:04:15+00	0	\N	367d5cd5385e772067a3719a284996400bfd5448c9fd21b677a9dbb3c32489a8	/home/extra/music/Classical Music Top 100/032. Clément Philibert Léo Delibes - Lakmé - Duo Des Fleurs.mp3
1043025	1042831	1042832	1043024	2012-11-30 06:04:18+00	0	\N	a2fa7e6384d6f098fc405caa9e4289586c65349e2e7a3d98b559dcaa0e421044	/home/extra/music/Classical Music Top 100/007. Johann Sebastian Bach - Matthäus Passion (BWV 244) - Wir Setzen Uns Mit Tränen Nieder.mp3
1043009	1042831	1042832	1043008	2012-11-30 06:04:15+00	0	\N	741263020dcd8d798fd2c088750bed9fc8b6fc3f52c0f9ba93fb858d4302b27b	/home/extra/music/Classical Music Top 100/030. Gabriel Urbain Fauré - Cantique De Jean Racine (Op. 11).mp3
1043013	1042831	1042832	1043012	2012-11-30 06:04:16+00	0	\N	2cc1debc9bb42ad850a10730374cc2d26223116ca333837a980ad928073de598	/home/extra/music/Classical Music Top 100/025. Pyotr Ilyich Tchaikovsky - Swan Lake (Op. 20) - Лебединое Озеро.mp3
1043019	1042831	1042832	1043018	2012-11-30 06:04:17+00	0	\N	3355aa1bd16b8aa5a67a544be0dd481fe6d1e369d30dc76bbeeb405b936b288b	/home/extra/music/Classical Music Top 100/019. Johann Sebastian Bach - Orchestersuite Nr. 3 (BWV 1068) - Air.mp3
1042999	1042831	1042832	1042998	2012-11-30 06:04:13+00	0	\N	629784944f216866a59acf21628b8b9220ebc8e45891adc37d32d514cee5c997	/home/extra/music/Classical Music Top 100/047. Georg Friederich Händel - Wassermusik (HWV 348-350).mp3
1043029	1042831	1042832	1043028	2012-11-30 06:04:18+00	0	\N	d9f43fce6ce364f3c49aaebf24aa094693787682630ab314834eec3035761c48	/home/extra/music/Classical Music Top 100/012. Georg Friederich Händel - Messiah (HWV 56) - Hallelujah.mp3
1043037	\N	\N	1043036	2012-11-30 06:04:20+00	0	\N	da6d868309d5d92865d3b1a68dab1ae33ec81e05c634c77b2902871279969527	/home/extra/music/Symphony_of_Science-The_Poetry_of_RealityFLAC.flac
1042997	1042831	1042832	1042996	2012-11-30 06:04:13+00	0	\N	47425e8e155c6d653bafafc6a547ab9cac4e28da7b909b72d97388770d455779	/home/extra/music/Classical Music Top 100/084. Giuseppe Fortunino Francesco Verdi - La Traviata - Libiamo Ne' Lieti Calici.mp3
1043031	1042831	1042832	1043030	2012-11-30 06:04:19+00	0	\N	980af4678d3138246a43777101ff4aea3710ff1649b2694005ae093c3f68cca0	/home/extra/music/Classical Music Top 100/082. Wolfgang Amadeus Mozart - Die Zauberfl√∂te (K. 620) - Overture.mp3
1072	823	1043	1071	2012-11-30 05:04:54+00	0	\N	8910b7174e4de65efb40c3f882fcd5c752d441f3834eff9e8ddd3b7952925f4f	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 1)/04 - Enterprise Flyover.mp3
1043052	1043050	1043051	1043049	2012-11-30 06:04:21+00	0	\N	8b45eaa89ac2a8229ff9336a6a4b863957985ca88883a681419470538ea0792e	/home/extra/music/shared/If.I.Survive.mp3
1118	823	1085	1117	2012-11-30 05:05:00+00	0	\N	03d83024fc8fbb8283c8b4f6c725a3bbc9f45fac11aca05c2501fad35692ec56	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/14 - Final Flight.mp3
1120	823	1085	1119	2012-11-30 05:05:01+00	0	\N	bd69615e3b56c21fe951883af231fbbeaaf1d296742c83851b3b83e01f7bed58	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/01 - The Scorpion.mp3
1122	823	1085	1121	2012-11-30 05:05:01+00	0	\N	689e64fae841f56be478d72f88834cafdeac3e86e29135a352d6fde609a893d9	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 10 - Nemesis 2003/Jerry Goldsmith - Star Trek Nemesis (Complete Score CD 2)/15 - Goodbye!.mp3
1043056	1043054	1043055	1043053	2012-11-30 06:04:22+00	0	\N	1559670668d8f029179ddc5810dad77ce32041b2d379d20a16104d651e4cd531	/home/extra/music/shared/I_Have_A_Dream.mp3
1125	946	1124	1123	2012-11-30 05:05:01+00	0	\N	d53dbfaad6744c2f83dd7cfbe37a0169a5469426dcb9765dc02669c5ae8d0fc3	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 03 - The Search for Spock 1983/05-Bird of Prey Decloaks.mp3
1043066	1043065	\N	1043064	2012-11-30 06:04:22+00	0	\N	a84a5d62b1a21f1b7b1fd0af6c48b5285e3f5c9d76e3a91e4021251df99ffeed	/home/extra/music/shared/Jiffypop.mp3
1043069	1043068	\N	1043067	2012-11-30 06:04:22+00	0	\N	87683782617159fa2629a00d62c861a49172868345a5c10a9f3456874f2b7156	/home/extra/music/shared/murraymightydemonicskull.mp3
1127	946	1124	1126	2012-11-30 05:05:01+00	0	\N	48527f7c4f976132ff033de308074c6406c03d360bd3c6ad3771bb5bc5752134	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 03 - The Search for Spock 1983/09-The Search for Spock.mp3
1043075	1043073	1043074	1043072	2012-11-30 06:04:23+00	0	\N	a511a9bb1e1543f9b479713cd244e19ed8ef4abd17adf30b3f15c1a848ec1e52	/home/extra/music/shared/OruchubanEbichu.mp3
1043059	1043058	\N	1043057	2012-11-30 06:04:22+00	0	\N	5f22436729acfb59ede2255ec9aac03285238edc0df0b47722b5c28cb5c0ae02	/home/extra/music/shared/RIAA_Phone_Call.mp3
1043061	1043041	\N	1043060	2012-11-30 06:04:22+00	0	\N	3846d25df01e52fffad5e7f104202de44869eeb7b7b85857d67e34dc89da24d9	/home/extra/music/shared/water_rabbit.mp3
1129	946	1124	1128	2012-11-30 05:05:01+00	0	\N	2882a87ba538ccdf526bfb9f7e6227d4bd4ba4dd9be6cdb9616c41c13ae762a1	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 03 - The Search for Spock 1983/04-The Mind Meld.mp3
1043046	1043044	1043045	1043043	2012-11-30 06:04:21+00	0	\N	a2bb2868e7c66318c86b29448b7b8e46eff8311d2a0e2b9ccf32dfa820dfce72	/home/extra/music/shared/01_-_pollyanna_i_believe_in_you.mp3
1043063	\N	\N	1043062	2012-11-30 06:04:22+00	0	\N	6dc2ce111f1c88a92fe290aa2c1fb233ce4b04c68796d5598afbf821cbcbaa82	/home/extra/music/shared/28283_acclivity_UnderTreeInRain.mp3
1043048	\N	\N	1043047	2012-11-30 06:04:21+00	0	\N	273b3153ab3a872ae67f7170559f4fbb906dabf5a8801e8c96d2638de1eed49e	/home/extra/music/shared/8d38d2fd1f0cc6024134db92f1887116.mp3
1043071	\N	\N	1043070	2012-11-30 06:04:23+00	0	\N	aa5d998afc7c207b9478135ce4a468bb08585aa2df9a93d7bf6714336ec4f790	/home/extra/music/shared/akaranorabureta_.mp3
1043079	1043077	1043078	1043076	2012-11-30 06:04:23+00	0	\N	58258fc5f652891b4f73e7890616282eeed64a6ec7d59ca4c7e8dff81b73ad56	/home/extra/music/shared/Bill Hicks - Beer Vs Pot (1).mp3
1131	946	1124	1130	2012-11-30 05:05:01+00	0	\N	0af6df06e905c7dac3e38fd86973d4fa894102795e19fb2116a0dcd268292508	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 03 - The Search for Spock 1983/08-End Title.mp3
1043083	1043081	1043082	1043080	2012-11-30 06:04:23+00	0	\N	1e47171a0100d90cc9d4da0bc4ba388386d5c2841b14a071deaca0b40c71b8d7	/home/extra/music/shared/East Clubbers - Beat Is Coming (T.Z. Remix).mp3
1133	946	1124	1132	2012-11-30 05:05:02+00	0	\N	f067ffbab1dee62da49f698f6c798b929a3fdea9f7fc31f199ecb3131390bd1b	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 03 - The Search for Spock 1983/01-Prologue and Main Title.mp3
1135	946	1124	1134	2012-11-30 05:05:02+00	0	\N	27abb42a15c6482f57564f4ddf34cad2a12da157ebcb72c3e5c1e8d7a142a669	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 03 - The Search for Spock 1983/07-The Katra Ritual.mp3
1043087	1043085	1043086	1043084	2012-11-30 06:04:23+00	0	\N	fb5b34a4d0c1760d2c6581405c788dabaa236943888bebbb60c9550bc8fb8aee	/home/extra/music/01 Omen.mp3
1043091	1043089	1043090	1043088	2012-11-30 06:04:24+00	0	\N	5a3eae1afe9e3e8ebdbd9a15fc4ebd961102d0a9a636917b161a6bce4f1d508d	/home/extra/music/rip/out/Chieftains' Collection Vol. 2/Chieftains - Chieftains' Collection Vol. 2 - 09 - Away with Ye.flac
1043133	1043117	1043118	1043132	2012-11-30 06:04:35+00	0	\N	8dfcd710a8afbe21f00466aa0bd7110c933aee689e030d818d599414f7335e01	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 20 - The Year Of The French - Cooper's Tune % The Bolero.flac
1043093	1043089	1043090	1043092	2012-11-30 06:04:25+00	0	\N	883f522ad123f7f47ace8473266b64c7e8d03bca7dd024a83327209ebdc1e85c	/home/extra/music/rip/out/Chieftains' Collection Vol. 2/Chieftains - Chieftains' Collection Vol. 2 - 13 - Ril Mhor.flac
1043113	1043089	1043090	1043112	2012-11-30 06:04:31+00	0	\N	e353b9681f4cb7cf7085a9ee7821c951b891726a0cd81e6c9f0bd22393794eb4	/home/extra/music/rip/out/Chieftains' Collection Vol. 2/Chieftains - Chieftains' Collection Vol. 2 - 07 - Ceol Bhriotanach.flac
1043095	1043089	1043090	1043094	2012-11-30 06:04:25+00	0	\N	6004eb35ec13d0a3e643f06161752b874e2a7fea2bf2745b3073a7b6370a767f	/home/extra/music/rip/out/Chieftains' Collection Vol. 2/Chieftains - Chieftains' Collection Vol. 2 - 02 - The Hunter's Purse.flac
1043097	1043089	1043090	1043096	2012-11-30 06:04:26+00	0	\N	574456149b5fdcbb0dd776d5c3d6dd9523e103ddb6333324527691a13dc18713	/home/extra/music/rip/out/Chieftains' Collection Vol. 2/Chieftains - Chieftains' Collection Vol. 2 - 11 - Cherish the Ladies.flac
1043127	1043117	1043118	1043126	2012-11-30 06:04:34+00	0	\N	6e3e7025e79aa807c0a82d4f0e7ef3be31ee722f075dbe5a9236bcaa00b8b0d2	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 06 - Treasure Island - Blind Pew.flac
1043099	1043089	1043090	1043098	2012-11-30 06:04:26+00	0	\N	614a83228dcc6db029ddf235c5cf81b289df1accfde472f0f71d6c543af720d2	/home/extra/music/rip/out/Chieftains' Collection Vol. 2/Chieftains - Chieftains' Collection Vol. 2 - 10 - Carolan's Concerto.flac
1043115	1043089	1043090	1043114	2012-11-30 06:04:31+00	0	\N	5d3b37f37ea2723cf9e3393ba3713612a6c72a5937fd42c222ee67aebd0a138b	/home/extra/music/rip/out/Chieftains' Collection Vol. 2/Chieftains - Chieftains' Collection Vol. 2 - 06 - An Mhaighdean Mhara.flac
1043101	1043089	1043090	1043100	2012-11-30 06:04:27+00	0	\N	238c295ca1420b62d8aacd68b0f29323056a8529239b60f18b243632060f20c9	/home/extra/music/rip/out/Chieftains' Collection Vol. 2/Chieftains - Chieftains' Collection Vol. 2 - 05 - Brian Boru March.flac
1043103	1043089	1043090	1043102	2012-11-30 06:04:27+00	0	\N	edbe2a70711b6883ce00bf6a448dea0fcdffcbcbce37e0f2b7ea02fa724e8765	/home/extra/music/rip/out/Chieftains' Collection Vol. 2/Chieftains - Chieftains' Collection Vol. 2 - 08 - Drowsy Maggie.flac
1043105	1043089	1043090	1043104	2012-11-30 06:04:28+00	0	\N	8bcdf5be718f6bd88505640ef16dcf7788460a6928194a614209cb01b984ac5c	/home/extra/music/rip/out/Chieftains' Collection Vol. 2/Chieftains - Chieftains' Collection Vol. 2 - 12 - Donall Og.flac
1043119	1043117	1043118	1043116	2012-11-30 06:04:32+00	0	\N	357673d13b33517b4511625bbf11153cf68f3e1e8410ff3ad722f16cf3e9ca70	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 16 - Tristan And Isolde - Escape And Chase.flac
1043107	1043089	1043090	1043106	2012-11-30 06:04:29+00	0	\N	5ec08920f22d78e2cbfecf7e67a8ea9f379fe21aab231dbbbccae687eb2ff2d8	/home/extra/music/rip/out/Chieftains' Collection Vol. 2/Chieftains - Chieftains' Collection Vol. 2 - 01 - Kerry Slides.flac
1043109	1043089	1043090	1043108	2012-11-30 06:04:30+00	0	\N	6be28e0b456180593257d04fea62fda079f9be112f4aaed80c9257e6a1ea4a64	/home/extra/music/rip/out/Chieftains' Collection Vol. 2/Chieftains - Chieftains' Collection Vol. 2 - 04 - Round the House and Mind the Dresser.flac
1043111	1043089	1043090	1043110	2012-11-30 06:04:30+00	0	\N	020c89c10a78e27bbc705e6d4e5cd21e4832825fbf36663aad87bcbedc63054b	/home/extra/music/rip/out/Chieftains' Collection Vol. 2/Chieftains - Chieftains' Collection Vol. 2 - 03 - Callaghan's; Byrne's.flac
1043121	1043117	1043118	1043120	2012-11-30 06:04:32+00	0	\N	22aa19314dd88c38dd66648785daef5a2e4d3b059b2e067b9ead62442c2efafc	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 04 - Treasure Island - Setting Sail.flac
1043129	1043117	1043118	1043128	2012-11-30 06:04:34+00	0	\N	94245048ffda3f36b76664d0a4de5d7f038a734f54082d9876ac6e892580bc4c	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 08 - Treasure Island - The Hispanola % Silver And Loyals March.flac
1043123	1043117	1043118	1043122	2012-11-30 06:04:33+00	0	\N	187bd00dd70c4a94147abfb5bbd8481e2d8afb022a4553a8ba2faec53a045d8f	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 03 - Treasure Island - Island Theme.flac
1043125	1043117	1043118	1043124	2012-11-30 06:04:33+00	0	\N	2871313f603a21a08b92a8a26544fdae35df85306530a8a6323f1b3fe14fd3c3	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 07 - Treasure Island - Treasure Cave.flac
1043139	1043117	1043118	1043138	2012-11-30 06:04:36+00	0	\N	5bc6ba7e98fbd429b3ddfbc2d37b254244ad0dd6ef356dd2b933f7e8189196d5	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 01 - Treasure Island - Opening Theme.flac
1043131	1043117	1043118	1043130	2012-11-30 06:04:34+00	0	\N	35d3fe02c674884d099faf5cdf4a547e35c566e292fbca14ba00face2d49d03c	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 17 - Tristan And Isolde - The Departure.flac
1043137	1043117	1043118	1043136	2012-11-30 06:04:35+00	0	\N	0ca6d3c13943a672f90dd2fd31cf1d671a9aac2c6680f10cf3418f7a77857979	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 02 - Treasure Island - Loyals March.flac
1043135	1043117	1043118	1043134	2012-11-30 06:04:35+00	0	\N	a604a145386179e61d59b4a434edfaf12621a55ce36e246a3d141234601b41a5	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 09 - Barry Lyndon - Love Theme.flac
1137	946	1124	1136	2012-11-30 05:05:02+00	0	\N	7061fee0b089f5db855ee899fb9f3319f23bca4cd2c830abc7c9b88248a31d87	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 03 - The Search for Spock 1983/06-Returning to Vulcan.mp3
1043141	1043117	1043118	1043140	2012-11-30 06:04:36+00	0	\N	30c05a868f36e34ca092d0749ffc0c03ace16caa3f4a8a60f22d204e3ea42540	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 11 - Three Wishes For Jamie - The Matchmaking.flac
1043143	1043117	1043118	1043142	2012-11-30 06:04:36+00	0	\N	52e67fd5d0fb5cb588aae5682a43cb159dfe2bd3200962196b39404540178858	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 14 - Tristan And Isolde - March Of The King Of Cornwall.flac
1043145	1043117	1043118	1043144	2012-11-30 06:04:37+00	0	\N	825a5a0d371000e973ad86695068086148ba3ad6c6b2e61be337054da51eebaf	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 10 - Three Wishes For Jamie - Love Theme.flac
1043165	1042612	1042583	1043164	2012-11-30 06:04:40+00	0	\N	87ab7edbd6c78250348a4e74e071caebe8d50b0d15f1a2a80837d04bb6523e54	/home/extra/music/rip/out/Smetana - The Moldau/Smetana - The Moldau - 01 - Smetana - The Moldau.flac
1043147	1043117	1043118	1043146	2012-11-30 06:04:37+00	0	\N	0633daa54ebb84a93cf79fa40edcf126d790d2dde6f3dc8172a3b9e31fdd5b72	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 19 - The Year Of The French - The French March.flac
1043149	1043117	1043118	1043148	2012-11-30 06:04:37+00	0	\N	a85ccc5c00c5dea5ab670cfa0f283b752a1e99423f2f382a1365925403b0c418	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 13 - Tristan And Isolde - Love Theme.flac
1043190	1043176	1043177	1043189	2012-11-30 06:04:48+00	0	\N	bd24079d853cfe2511e7799f8c59081422d84bc4e11dfe2ac704d99a88fe823d	/home/extra/music/rip/out/Italian Opera Arias/Jon Vickers - Italian Opera Arias - 02 - M'appari - Flotow.flac
1043151	1043117	1043118	1043150	2012-11-30 06:04:38+00	0	\N	42a49c16b2eb2487e62aa427578c2217028046c534be1c37298a99b82afc81ac	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 12 - Three Wishes For Jamie - Mountain Fall % Main Theme.flac
1043167	1042582	1042583	1043166	2012-11-30 06:04:42+00	0	\N	83198c4e31699f5ca1769bfee3386741ebdbddbfd61ef5cf56687ea2e72c3254	/home/extra/music/rip/out/Smetana - The Moldau/Smetana - The Moldau - 05 - Dvorák - Carnival Overture, Op. 92.flac
1043153	1043117	1043118	1043152	2012-11-30 06:04:38+00	0	\N	cbd968eadc4fcfdf383c735ab23400e6eb96afb96453d48746e32f226effb2da	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 15 - Tristan And Isolde - The Falcon.flac
1043155	1043117	1043118	1043154	2012-11-30 06:04:38+00	0	\N	6cb3e38e68c4d4dd70487ce175e97f60628783c715ad6af9e9110483acc5214e	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 18 - The Grey Fox - Main Theme.flac
1043174	1042582	1042583	1042581	2012-11-30 06:04:45+00	0	\N	b43dfdca085648197ef09b68c4988f190c89fa273b3a34e39237f105714e7783	/home/extra/music/rip/out/Smetana - The Moldau/Smetana - The Moldau - 06 - Dvorák - Op. 46, No. 1 in C Major (Bohemian Furiant, Presto).flac
1043157	1043117	1043118	1043156	2012-11-30 06:04:39+00	0	\N	e3c6c06cd9ca2a91b75949222a4bbbd06425cf50ca88f9a9f82beb7b551ded21	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 05 - Treasure Island - French Leave.flac
1043168	1042582	1042583	1042651	2012-11-30 06:04:43+00	0	\N	7a12108ce1736fb4203d445bc3fd739eb79b9f257a3be48fdced9ea6d714df58	/home/extra/music/rip/out/Smetana - The Moldau/Smetana - The Moldau - 08 - Dvorák - Op. 72, No. 2 in E Minor (Polish Mazurka, Allegro grazioso).flac
1043159	1043117	1043118	1043158	2012-11-30 06:04:39+00	0	\N	e9d973e63a947082bb868d5673180f7e6be62eb529f34bb287837a70a783775c	/home/extra/music/rip/out/Reel Music - The Film Scores/The Chieftains - Reel Music - The Film Scores - 21 - The Year Of The French - Closing Theme & March.flac
1043161	1042582	1042583	1043160	2012-11-30 06:04:39+00	0	\N	375fb7057e7e2c25d80a74ddabc1a0a166d225c80b91cb9852e4f95ff80b487f	/home/extra/music/rip/out/Smetana - The Moldau/Smetana - The Moldau - 09 - Dvorák - Op. 72, No. 7 in C Major (Serbian Kolo, Allegro vivace).flac
1043163	1042612	1042583	1043162	2012-11-30 06:04:40+00	0	\N	04360d241159f4d79db0862221169e8dcc104651e82e05b5bb6c3fa92cf68ade	/home/extra/music/rip/out/Smetana - The Moldau/Smetana - The Moldau - 04 - Smetana - The Bartered Bride; Dance of the Comedians (Act III, Scene 2).flac
1043184	1043176	1043177	1043183	2012-11-30 06:04:47+00	0	\N	f1a67bfdc5839042ad08fe7a1b762c76c0ac6791f72614d0bd804b7dfb16de01	/home/extra/music/rip/out/Italian Opera Arias/Jon Vickers - Italian Opera Arias - 10 - Ah! sì, ben mio - Verdi.flac
1043170	1042612	1042583	1043169	2012-11-30 06:04:44+00	0	\N	961d337cad0da2ec734b56432a15c4dc3af7327a520aa373eec2bd1a8c8eebd1	/home/extra/music/rip/out/Smetana - The Moldau/Smetana - The Moldau - 03 - Smetana - The Bartered Bride; Furiant (Act II, Scene 1).flac
1043178	1043176	1043177	1043175	2012-11-30 06:04:46+00	0	\N	70bc26fdaa45e62d2d7742c119e731e123a9a3cc90be94b5349d978dea59e746	/home/extra/music/rip/out/Italian Opera Arias/Jon Vickers - Italian Opera Arias - 08 - Come un bel dì di maggio - Giordano.flac
1043172	1042582	1042583	1043171	2012-11-30 06:04:44+00	0	\N	69f92aca53fdd1f3c94189c3826bfc494f1c7d42355347c931e4590b7f331b45	/home/extra/music/rip/out/Smetana - The Moldau/Smetana - The Moldau - 07 - Dvorák - Op. 46, No. 2 in A-Flat Minor (Bohemian Polka, Poco Allegro).flac
1043173	1042612	1042583	1042611	2012-11-30 06:04:44+00	0	\N	3d6dd2c40ef924b0075577546120780d283b4608c52e6ad4bdc9d150391d1898	/home/extra/music/rip/out/Smetana - The Moldau/Smetana - The Moldau - 02 - Smetana - The Bartered Bride; Polka (Act I, Scene 5).flac
1043180	1043176	1043177	1043179	2012-11-30 06:04:46+00	0	\N	6e5762be20cdccc00427afba1545bbbdc4f5b025b045abc30f89778381a67c87	/home/extra/music/rip/out/Italian Opera Arias/Jon Vickers - Italian Opera Arias - 03 - Io l'ho perduta! - Verdi.flac
1043188	1043176	1043177	1043187	2012-11-30 06:04:48+00	0	\N	1ece3b747870fe6cc1e2355c6d9c0e5ec3c4991e01b21f4752a2abb115b6ff1a	/home/extra/music/rip/out/Italian Opera Arias/Jon Vickers - Italian Opera Arias - 05 - Vesti la giubba - Leoncavallo.flac
1043182	1043176	1043177	1043181	2012-11-30 06:04:46+00	0	\N	16553816c4ee7dc3ab0cff9a413dd43416adc9b9119f40e6911100ddd317e904	/home/extra/music/rip/out/Italian Opera Arias/Jon Vickers - Italian Opera Arias - 01 - Cielo e mar - Ponchielli.flac
1043186	1043176	1043177	1043185	2012-11-30 06:04:47+00	0	\N	cbe562fc7e1d8b9664d2c4d954446d51da029eee3ce58f7e6f9cb3bd86e6836f	/home/extra/music/rip/out/Italian Opera Arias/Jon Vickers - Italian Opera Arias - 12 - Niun mi tema - Verdi.flac
1043192	1043176	1043177	1043191	2012-11-30 06:04:49+00	0	\N	bc0e2a025f4555049e3b3cdf54326a55b7c6c73d3ca4e8fe69211b6d34833e0f	/home/extra/music/rip/out/Italian Opera Arias/Jon Vickers - Italian Opera Arias - 04 - E la solita storia - Cilea.flac
1043194	1043176	1043177	1043193	2012-11-30 06:04:49+00	0	\N	647fdc23abb32b828ea5eb55b19eee02e61578aa7b31c09ea20db0efd39fd452	/home/extra/music/rip/out/Italian Opera Arias/Jon Vickers - Italian Opera Arias - 06 - No, Pagliaccio non son! - Leoncavallo.flac
1173	823	1165	1128	2012-11-30 05:05:06+00	0	\N	fc18b776760ce327488de440bbe2422b6fc346c60e01f45fd20b411e48a5101d	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/01 - The Mind Meld.mp3
1043196	1043176	1043177	1043195	2012-11-30 06:04:50+00	0	\N	ee5e1ed94fecd1e5ed03c21f324efd109bbf111187b1653e44172b09fe3e3ed1	/home/extra/music/rip/out/Italian Opera Arias/Jon Vickers - Italian Opera Arias - 07 - Un dì all'azzurro spazio - Giordano.flac
1043228	1043222	1042542	1043227	2012-11-30 06:04:58+00	0	\N	233828119c1722dc4f83b2e95cb60a3c5036f218e55e5ebc5f0a68f9052392c1	/home/extra/music/rip/out/Polar Shift/Polar Shift - 02 - Yanni - Secret Vows.flac
1043198	1043176	1043177	1043197	2012-11-30 06:04:50+00	0	\N	f2f643d604e8ae0ac03a2865d828331303e13cb9af883e5bbcb3138eaa4eacd2	/home/extra/music/rip/out/Italian Opera Arias/Jon Vickers - Italian Opera Arias - 09 - Recondita armonia - Puccini.flac
1043200	1043176	1043177	1043199	2012-11-30 06:04:50+00	0	\N	2c88d4be487eb91ef081458ba41225b3ab752c3d72e6ae3038654137a03ca8f0	/home/extra/music/rip/out/Italian Opera Arias/Jon Vickers - Italian Opera Arias - 11 - Dio! mi potevi scagliar - Verdi.flac
1043266	1043265	1043239	1043264	2012-11-30 06:05:03+00	0	\N	5b47351838fd429e48e172fc09c2ddc862cfe11d8e2343bb6df3470060b2498c	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 11 - O sole mio - si Capua.flac
1043203	1043202	1042542	1043201	2012-11-30 06:04:51+00	0	\N	61753c460ce1651413d3f71c0d4652a811fd761dcbd4b1e404309de626f14d05	/home/extra/music/rip/out/Polar Shift/Polar Shift - 13 - Kitaro - Light of the Spirit.flac
1043231	1043230	1042542	1043229	2012-11-30 06:04:58+00	0	\N	382f5a8be76f0d479b252ca0cdbe2a8b33fd552077ba797ebe9f87efaf1b4e80	/home/extra/music/rip/out/Polar Shift/Polar Shift - 09 - Suzanne Ciani - Anthem.flac
1043206	1043205	1042542	1043204	2012-11-30 06:04:52+00	0	\N	983907affe4102776dc1c051595ed7f3f2371bf2724f042be3fb99bcee54b3e6	/home/extra/music/rip/out/Polar Shift/Polar Shift - 08 - John Tesh - Day One.flac
1043209	1043208	1042542	1043207	2012-11-30 06:04:53+00	0	\N	d5a4951109382fb4a093041c2073b66ad8e28c3038c490a00cb7c60e3301587d	/home/extra/music/rip/out/Polar Shift/Polar Shift - 06 - Enya - Watermark.flac
1043249	1043248	1043239	1043247	2012-11-30 06:05:01+00	0	\N	392e878752fdbf41bd8bb07699d605e5af5923a73c9aea9ff6965153e36d3908	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 17 - Ave Maria - Gounod, Bach.flac
1043212	1043211	1042542	1043210	2012-11-30 06:04:53+00	0	\N	bf5c696db3c6169684f82391f9a2b3be45163e48f7107a7b7acf8b6a2d9dfe8b	/home/extra/music/rip/out/Polar Shift/Polar Shift - 11 - Vangelis - Antarctic Echoes.flac
1043233	1043232	1042542	803	2012-11-30 06:04:59+00	0	\N	33308875553c35d7234a610e631f1700218889fd997f8d8d6e6b8a857caef9f8	/home/extra/music/rip/out/Polar Shift/Polar Shift - 05 - Jim Chappell - Lullaby.flac
1043214	1043211	1042542	1043213	2012-11-30 06:04:54+00	0	\N	0107855d3e25e28d099034ddf91f631ff427b838063d0e633cee4541064c149c	/home/extra/music/rip/out/Polar Shift/Polar Shift - 01 - Vangelis - Theme from Antarctica.flac
1043217	1043216	1042542	1043215	2012-11-30 06:04:55+00	0	\N	edfe6186e727e21d00d0196feb10c9127c34e11e13cdcdf6cd2a621e6acbec89	/home/extra/music/rip/out/Polar Shift/Polar Shift - 10 - Constance Demby - Into Forever.flac
1043220	1043219	1042542	1043218	2012-11-30 06:04:56+00	0	\N	d3e85ef513c47683ec94a1c15775ee43e93fe316e68419f5042bee48119b78e0	/home/extra/music/rip/out/Polar Shift/Polar Shift - 12 - Chris Spheeris - Field of Tears.flac
1043236	1043235	1042542	1043234	2012-11-30 06:05:00+00	0	\N	00f95d8d8fc5cb16a771a3d578a6d53ae1c8a8ba03389ef0a56f7013dccb3f6f	/home/extra/music/rip/out/Polar Shift/Polar Shift - 07 - Steve Howe, Constance Demby, Paul Sutin - Polar Flight.flac
1043223	1043222	1042542	1043221	2012-11-30 06:04:56+00	0	\N	f0171a516c35013bfd5a3482f16d5719f9f8f503f21c63b9bd0c4bd83167198c	/home/extra/music/rip/out/Polar Shift/Polar Shift - 04 - Yanni - Song for Antarctica.flac
1043226	1043225	1042542	1043224	2012-11-30 06:04:57+00	0	\N	147d48488c835d8557573c970153d73cea90d2f135494193003438a18df8fc54	/home/extra/music/rip/out/Polar Shift/Polar Shift - 03 - Chris Spheeris, Paul Voudouris - Pura Vida.flac
1043260	1043259	1043239	1043258	2012-11-30 06:05:03+00	0	\N	d9f1abae9ab7e6a4dbb1398a3a19c8dd7a622008de949e22f264cefe3f0b73f8	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 12 - Funiculi, funicula - Denza.flac
1043252	1043251	1043239	1043250	2012-11-30 06:05:01+00	0	\N	4bf996cda8ca93cd556fe1bb1b3ca11b5a4b3df93a0ba70c8bd7fa2a1f38bca5	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 02 - Der Lindenbaum - Winterreise, D. 911, Schubert.flac
1043240	1043238	1043239	1043237	2012-11-30 06:05:00+00	0	\N	14857f62c9b087fbfec6e45e1e24afc9aa463b0be3a51665d98606b5f0e4bde3	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 04 - Sehnsucht nach dem Frühling K 596 - Mozart.flac
1043243	1043242	1043239	1043241	2012-11-30 06:05:01+00	0	\N	8c6851b50ecf1d04e8236705d87771d91541b906cf70a0ed5a15c472581cb109	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 10 - La Serenata - Tosti.flac
1043246	1043245	1043239	1043244	2012-11-30 06:05:01+00	0	\N	377248dbcfd9ae6d4888461fe74bf38617d313e6f889faf7792f1e754eef3f5a	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 05 - Ständchen - Schwanengesang, D.957, Schubert.flac
1043254	1043253	1043239	1043244	2012-11-30 06:05:02+00	0	\N	4f53dffd9a13c8fd9289a19bbfca68ae21268ad336e9a941426a3ca29b1405c4	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 06 - Liebesbotschaft - Schwanengesang, D.957, Schubert.flac
1043257	1043256	1043239	1043255	2012-11-30 06:05:02+00	0	\N	141289ef6e71c62ad0ce0e1253b52751a25eb68e211d193b089195d161dd4016	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 01 - Heidenröslein - Werner.flac
1043263	1043262	1043239	1043261	2012-11-30 06:05:03+00	0	\N	c6a736d262c5c6199eef515a7cdde1878aaaf5afe3148986b01c911233edc69a	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 07 - Gretchen am Spinnadre, D.118 - Schubert.flac
1043269	1043268	1043239	1043267	2012-11-30 06:05:04+00	0	\N	35a90fefa4040e859acd9651b967fce86308e59f4f6f53a692581340de19b38b	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 13 - Torna a Surriento - de Curtis.flac
1043272	1043271	1043239	1043270	2012-11-30 06:05:05+00	0	\N	d84b9a016464e4fd5cb7f022dcda887647759ff970b9667cbf02539b9a3967de	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 15 - Hallelujah! - Messiah, Handel.flac
1043275	1043274	1043239	1043273	2012-11-30 06:05:05+00	0	\N	33afc92dbadca6a8e1c49768d842528e1ea1d4b76efd7030610ebbbb208f9c09	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 03 - Auf Flügeln das Gesanges - Mendelssohn.flac
1043277	1043276	1043239	1043261	2012-11-30 06:05:06+00	0	\N	46c1ef18bef2ac5632f3216979968a9c45c9804141454b90055550ee5bec7354	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 18 - Ave Maria Op 52, No 6 - Schubert.flac
1175	823	1165	1174	2012-11-30 05:05:06+00	0	\N	eeb66ea2324769c1a8a33666521cb3d11d4a82e546638bf56dac9ea42fbfcccf	/home/extra/user/torrents/Star Trek 01-10 Soundtrack Complete/Star Trek 05 - Final Frontier (Expanded) 1989/18 - Cosmic Thoughts.mp3
1299431	\N	\N	1299430	2012-11-30 07:11:03+00	0	\N	e071930ccd6d6810a2753f45196c1e3a6a0f12c7eff1f513f0bc96f309bdbad3	/home/extra/music/songsIam/StingDesertRoseRadioVersion.aac
1043280	1043279	1043239	1043278	2012-11-30 06:05:06+00	0	\N	3af0a813ce6ba587ce02968bface16e955897bad36ca1f5e93a05ee8144ce6e4	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 16 - Jesu, joy of man's desiring - Cantata Bach.flac
1043283	1043282	1043239	1043281	2012-11-30 06:05:06+00	0	\N	d3ffea93e78ff6df4c891fc196438b1c56967377dcd10cbd9f362a7fa563b840	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 09 - Sandmännchen - Brahms.flac
1043286	1043285	1043239	1043284	2012-11-30 06:05:07+00	0	\N	60b68c39803c06dd7911d538d419eeee2e16cdf7610869478e064eccf5bbbad5	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 14 - Core 'ngrato - Cardillo.flac
1043288	1043287	1043239	1043261	2012-11-30 06:05:07+00	0	\N	51d17ae6039b2d505e9b2aa70a3984fa250500508c7f1822ce313e96b2e3ea2a	/home/extra/music/rip/out/On Wings of Song/On Wings of Song - 08 - Wiegenlied D.498 - Schubert.flac
1043290	1042519	1042520	1043289	2012-11-30 06:05:07+00	0	\N	b04bbe6836644009136158b09073dd000d9940ce829c1db5100f0df1a9429104	/home/extra/music/rip/out/Tarantella/Robert Spring - Tarantella - 03 - La fille aux cheveux de lin.flac
1043291	1042519	1042520	1042518	2012-11-30 06:05:08+00	0	\N	5b290c2ddd267fcb7db3a85cfceb52de3ab8684c41699e614c23a15526ce24f2	/home/extra/music/rip/out/Tarantella/Robert Spring - Tarantella - 11 - Concierto in Sib Maggiore.flac
1299570	\N	\N	1299569	2012-11-30 07:35:55+00	0	\N	05270a93a8d3e83c8d0b3d13babe870d34baa68a5ae1323633cb360ea9a22e32	/home/extra/music/Pornophonique_Sad_Robot_High_Quality-u7Dg3LrhmIY.aac
1299572	\N	\N	1299571	2012-11-30 07:37:08+00	0	\N	f288150bfe7132507467a323f3802c2427a189f79ce9aab3c6c4bd8c64d3aca9	/home/extra/music/Richard_Wagner_Ride_Of_The_Valkyries-GGU1P6lBW6Q.aac
1299574	\N	\N	1299573	2012-11-30 07:37:08+00	0	\N	679fbebb971a4429a242387f123ef16f37720a0262b7f6f8224633fa58a43604	/home/extra/music/R_Kelly_I_Believe_I_Can_Fly-16FdJrrAWSo.aac
1299576	\N	\N	1299575	2012-11-30 07:37:33+00	0	\N	96ed4e58eee9077466803a5aba6ce9a86d98c8fc5702eae309d85cffb01e3569	/home/extra/music/Tomorrow_annie_Lyrics-5PzL8aL6jtI.aac
1299578	\N	\N	1299577	2012-11-30 07:38:55+00	0	\N	9ef6abba6412957ac394bbcba0e71bb97dc13cbe2b26e739d4086f4a9a8acc0a	/home/extra/music/Once_Upon_a_Time_in_Animation-f2Nwp4IuJl0.aac
3535	3534	\N	3533	2012-11-30 05:51:08+00	0	\N	3107be25290dfb4d68a2717611c13d1495adc435a6aedd0263a4a2dc1b2ecb8f	/home/extra/music/1246851451.tamias_through_a_pikachu_s_eyes__lq_.mp3
1299580	\N	\N	1299579	2012-11-30 07:58:02+00	0	\N	9ebfc73c81d25b24bbb6f6297fab2889392390ca0c9479d39cbb7dcc782ea282	/home/extra/music/Aerith_s_Theme_original_lyrics_by_katethegreat19-1-as6Kbcj4c.aac
1299582	\N	\N	1299581	2012-11-30 07:58:02+00	0	\N	cba644116e27c9df1193ad7ca3c86fd1416a2c6b94145af5d74a62f99b890164	/home/extra/music/Banana_Phone-1L65Ek5aKWQ.aac
1299584	\N	\N	1299583	2012-11-30 07:58:02+00	0	\N	4bac1d9387c53f7c6bf958c713ed3314d4e82d720b838bbf38cb2d80803502a7	/home/extra/music/Beverly_Hills_Cop_Theme_Song-IG8EdbrSVtc.aac
1299586	\N	\N	1299585	2012-11-30 07:58:03+00	0	\N	8864dacbd703495b728731c846957337319417eb8970ec653630283a52150938	/home/extra/music/Calculus_Rhapsody-uqwC41RDPyg.aac
1299588	\N	\N	1299587	2012-11-30 07:58:03+00	0	\N	553951d93fc77b722232aa8086ea1398091fa65c3f110699247ec12b34a434cd	/home/extra/music/DJ_Earworm_United_State_of_Pop_2009_Blame_It_on_the_Pop_Mashup_of_Top_25_Billboard_Hits-iNzrwh2Z2hQ.aac
1299590	\N	\N	1299589	2012-11-30 07:58:03+00	0	\N	95b90809e5600d0bc99c4e6d9d4dc7e776a376409e5305540ccb5967587399c0	/home/extra/music/Electric_Cello-dH9fh-T9qHU.aac
1042536	1042535	1042532	1042534	2012-11-30 05:58:29+00	0	\N	101deb284ad3bba247a602d7300932cebfae9d5a21c4b58c9647e791415be06b	/home/extra/music/restitch/15db.flac
1042758	1042756	1042757	1042755	2012-11-30 06:03:37+00	0	\N	50feabda82662b9de283199ee486a8b2ce49bb50c51a1a621f76a518a6d22ea3	/home/extra/music/songsIam/Natasha_Bedingfield_Unwritten.mp3
1299423	1043208	1299422	1043207	2012-11-30 07:08:14+00	0	\N	f35d3197e96612ea1808cadf3b630fa8787f58769998c837c4bf557cd67ef2e2	/home/extra/music/songsIam/Enya - Watermark - 01.ogg
1299426	1299425	\N	1299424	2012-11-30 07:08:14+00	0	\N	fbef6f297cbde3cab691e7afd33850aa2469d94068d09cb6943ebbd6d6427013	/home/extra/music/songsIam/pj harvey - who will love me now.ogg
1299429	1299428	\N	1299427	2012-11-30 07:08:14+00	0	\N	e1d457575256d9ea8fc5b4272a85a939045895723148e55a75e46878ac47d3b6	/home/extra/music/songsIam/Rain_in_the_Backyard.ogg
1042804	1042802	1042803	1042801	2012-11-30 06:03:40+00	0	\N	991578e572f0f94345a67da2451894068fb16523133a6c5e93145bc23947ab26	/home/extra/music/songsIam/119_Dr Reanimator Move Your Dead Bones .mp3
1042765	1042764	\N	1042763	2012-11-30 06:03:38+00	0	\N	b395bef8a980dc8aca65a5f4657a9161b80b3a942fe0df72bc220caa70bb08d8	/home/extra/music/songsIam/Lunar Silverstar Story - Luna's Boat Song (Japanese).mp3
1042696	1042694	1042695	1042693	2012-11-30 06:03:29+00	0	\N	824c54aa17341740efca25aa0d388d75b0497dcc14751961fbd21f91e09097d8	/home/extra/music/Henryk Mikołaj Górecki - Symphony No. 3 (Warsaw Philharmonic Orchestra feat. conductor: Kazimierz Kord, soprano: Joanna Kozłowska)/00. Henryk Mikołaj Górecki - Hidden Track One Audio.flac
1299459	1299447	1299448	1299458	2012-11-30 07:22:13+00	0	\N	21e9e262f3d46b818906704c893bb7c05646d35d9f8a5d1cf55bebfd88ec5fe8	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Double Concerto in D minor, BWV 1043 Largo ma non Tanto.flac
1299435	1299433	1299434	1299432	2012-11-30 07:21:24+00	0	\N	af32c3597dd0a55974b65251028175f1f30b56bf04efc859aedaa70688850ffd	/home/extra/music/shared/Country_Roads.ogg
1299439	1299437	1299438	1299436	2012-11-30 07:21:25+00	0	\N	a48ccca0eceb48ba8d6016b1aa5f5e1bbcf977aa06b8fe4f5e7093e3c0f530f4	/home/extra/music/shared/nes-IvoryTower.ogg
1299442	1299441	\N	1299440	2012-11-30 07:21:26+00	0	\N	4397c65563ad6174b609d72df57fe9fbfe9d8af5cc358a6b5968a6822b2c7a09	/home/extra/music/shared/Song_of_Pi.ogg
1299445	1299444	\N	1299443	2012-11-30 07:21:26+00	0	\N	e2315e98c9eabb216187440abf4aeea601d10005e7c42f9155bed7b1bec67162	/home/extra/music/shared/windows_noises.ogg
1299449	1299447	1299448	1299446	2012-11-30 07:22:10+00	0	\N	04a852066657b846f760e8faa8284cae69a40fbeeceaa354a916351cd10899b5	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Brandenburg Concerto No. 1 in F major, BWV 1046 Adagio.flac
1299461	1299447	1299448	1299460	2012-11-30 07:22:14+00	0	\N	6d4ab25ddcdbfebdfa4983f502e45df7ee05a88ff87416a7ee4cc2b13cefe17a	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Goldberg Variations, BWV 988 Aria.flac
1299451	1299447	1299448	1299450	2012-11-30 07:22:11+00	0	\N	bf5d173663840ffb8313cf21b16df60bae35e69d3965b508af89fc917da1266b	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Brandenburg Concerto No. 2 in F major, BWV 1047 Allegro Assai.flac
1299453	1299447	1299448	1299452	2012-11-30 07:22:12+00	0	\N	81bc5d6997738692a8fd7ef160f9424cd5eb58e4d9c5a5eea6241876f743bb04	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Brandenburg Copncerto No. 3 in G Major, BWV 1048 Allegro.flac
1299469	1299447	1299448	1299468	2012-11-30 07:22:16+00	0	\N	9a046bfeb90ab68552496ccc8677394be586db8464229d4688bb9dc89b0649db	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Sonata No. 3 in C major for Solo Violin, BWV 1005 Largo.flac
1299455	1299447	1299448	1299454	2012-11-30 07:22:12+00	0	\N	2dfc88bc70b7bf2f7152135364cb09512da598b4c8013726aa4837eba89c513b	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Christmas Oratorio, BWV 248 Sinfonia.flac
1299463	1299447	1299448	1299462	2012-11-30 07:22:15+00	0	\N	2a67fd571496d122855c62a730e966d5798e3bcd09f4db0bbd2582a29ee15c34	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Jesu Joy of Man's Desiring, BWV 147.flac
1299457	1299447	1299448	1299456	2012-11-30 07:22:13+00	0	\N	8732bfbd4facd4878cc8186fc9bf16b9326cd6772afadc35810d0effd2465540	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Concerto in C minor for Violin and Oboe, BWV 1060 Adagio.flac
1299475	1299447	1299448	1299474	2012-11-30 07:22:17+00	0	\N	1b1bd863592b9ca4c680e4ce5d078a1afe26371b267dd5eeb34bd15652cf1942	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Suite No. 4 in D major, BWV 1069 Rejouissance.flac
1299465	1299447	1299448	1299464	2012-11-30 07:22:15+00	0	\N	8f09ec12260bfedffbc52190fdc33043915943369ee487f7ea84bb75391b1966	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Nun komm, der Heiden Heiland, BWV 659.flac
1299471	1299447	1299448	1299470	2012-11-30 07:22:17+00	0	\N	df1ef418bbc6c8e995a62269502657b6e284f336befeaed29a47e1a08d6ed568	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Suite No. 2 in B minor, BWV 1067 Badinerie.flac
1299467	1299447	1299448	1299466	2012-11-30 07:22:16+00	0	\N	6abf164af3ab6343cd01934076bf79a07f5747dfcadcaaa7f45e1ae24c438c37	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Piano Concerto No. 5 in F minor, BWV 1056 Largo.flac
1299473	1299447	1299448	1299472	2012-11-30 07:22:17+00	0	\N	bca2fc73431f5feef541d5434e27cee61e105282d3ffa8588514fd0ae5990afd	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Suite No. 3 in D major, BWV 1068 Air.flac
1299479	1299447	1299448	1299478	2012-11-30 07:22:18+00	0	\N	28247e7e19b111d951f59f1274b83f181a4766f424c474c1ef47814201554500	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Violin Concerto in A minor, BWV 1041 Allegro Assai.flac
1299477	1299447	1299448	1299476	2012-11-30 07:22:18+00	0	\N	968646d00fdc5265cd9dcd17df3d8455cc6d063f95d5c118a25f29d8b829386b	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Toccata and Fugue in D minor, BWV 565 Toccata.flac
1299481	1299447	1299448	1299480	2012-11-30 07:22:18+00	0	\N	4e236ee036409dc865ad96eabcf51cb86002002821aa2f200156af6b7e8c14c8	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Violin Concerto No. 2 in E major, BWV 1042 Adagio.flac
1299483	1299447	1299448	1299482	2012-11-30 07:22:19+00	0	\N	0b31e7f097f6451e350543fac67550e1d56c30eadae6b07569041d5cb4697747	/home/extra/music/J S Bach, The Best Of/Bach The Best Of/Bach - Wachet auf, Cantata, BWV 140 No 1.flac
1042987	1042831	1042832	1042986	2012-11-30 06:04:11+00	0	\N	56e9e84cf40791c43ca04d56716111911f081930f45f4d56a285282fb5d56f69	/home/extra/music/Classical Music Top 100/001. Wolfgang Amadeus Mozart - Requiem (K. 626) - Lacrimosa.mp3
1042899	1042831	1042832	1042898	2012-11-30 06:03:55+00	0	\N	fc4008e5608c8a7a9b2e3b4a29549c1f5dcd185fdc654a2b9da2998a79abbe28	/home/extra/music/Classical Music Top 100/002. Johann Sebastian Bach - Matthäus Passion (BWV 244) - Erbarme Dich.mp3
1042985	1042831	1042832	1042984	2012-11-30 06:04:10+00	0	\N	51ac5b7121b0a37998a9e1009090846f251a7884c45c3447b9ada68f054ddbe1	/home/extra/music/Classical Music Top 100/005. Antonio Lucio Vivaldi - Le Quattro Stagioni (Op. 8, RV 269) - La Primavera.mp3
1042939	1042831	1042832	1042938	2012-11-30 06:04:02+00	0	\N	9748e7e36565ccb3baef9d852ccad020fde4501dcbd4393f6b50364f876f223a	/home/extra/music/Classical Music Top 100/013. Ludwig van Beethoven - Symphony No. 7 (Op. 92).mp3
1042843	1042831	1042832	1042842	2012-11-30 06:03:43+00	0	\N	b3230dbc49558fe10793d16d2933cac8f800b1e1fb800d342c045f298019002e	/home/extra/music/Classical Music Top 100/072. Pyotr Ilyich Tchaikovsky - The Nutcracker (Op. 71) - Dance Of The Sugar-Plum Fairy - –©–µ–ª–∫—É–Ω—á–∏–∫.mp3
1299485	\N	\N	1299484	2012-11-30 07:24:36+00	0	\N	9ed99b6175e16469558fa9a4a4c345d8ae8ef0e7e121eade5bb2ab835296a32a	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/01 overture to Cublai gran kan de Tartari in D majjor.ape
1299487	\N	\N	1299486	2012-11-30 07:24:36+00	0	\N	cd30a5f39e8ffbf5aedef534452ec5586d3f59be91c8aaf9de7c7d1ab6e6a8c0	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/02 Twenty six Variations on La Folia de Spagna.ape
1299489	\N	\N	1299488	2012-11-30 07:24:38+00	0	\N	fa7feddc1330c72aafc72967c6290204d16807788e0614560226919b72f5b682	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/03 Overture to Angolina ossia Il matrimonio per sussuro in D major.ape
1299491	\N	\N	1299490	2012-11-30 07:24:39+00	0	\N	766994af4ef2c24264fcc93535bdca298953aec9abd54501765e8653b18b8186	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/04 allegro assai Sinfonia Veneziana in D major.ape
1299493	\N	\N	1299492	2012-11-30 07:24:40+00	0	\N	1fbf40b39817b50b50ccee74b4896b4fc574a8b4e966ef0ee4136a7d57fc5c8a	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/05 andantino grazioso Sinfonia Veneziana in D major.ape
1299495	\N	\N	1299494	2012-11-30 07:24:41+00	0	\N	7c7f2b13f1586b0347d859b1f758a2eb66654b3b04cc9c73c79be9a7bb4e0323	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/06 presto Sinfonia Veneziana in D major.ape
1299497	\N	\N	1299496	2012-11-30 07:24:41+00	0	\N	96eadfd8ef4ef5fb8c624edce26ad51431968ca1c0ced48c497308008e9ad1f6	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/07 allegro assai Overture to La locandiera in D major.ape
1299499	\N	\N	1299498	2012-11-30 07:24:42+00	0	\N	a61590c2838f357427a36ad60c78e465cddb052d09778c85082997048892e0d8	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/08 andantino Overture to La locandiera in D major.ape
1299501	\N	\N	1299500	2012-11-30 07:24:42+00	0	\N	74d87be58c060499f9f787714343c814d115015b706e73e64bb94d246827e738	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/09 presto Overture to La locandiera in D major.ape
1299503	\N	\N	1299502	2012-11-30 07:24:42+00	0	\N	0f7a8cc54c80f72adc2b96c30e2b712570ee8dabf4005211a5e79d36887f43b1	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/10 allegro quasi presto Sinfonia Il giorno onamastico in D major.ape
1299505	\N	\N	1299504	2012-11-30 07:24:43+00	0	\N	9c2b8f32124f36b740ebcdcb878b4ad9829cd757b4ade96034e6160edba6a1aa	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/11 larghetto Sinfonia Il giorno onamastico in D major.ape
1299507	\N	\N	1299506	2012-11-30 07:24:43+00	0	\N	1aac6cbd43c451387de98d349a3d28f76881fe4a133fec37bff7e39788b6ff61	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/12 menuetto trio Sinfonia Il giorno onamastico in D major.ape
1299509	\N	\N	1299508	2012-11-30 07:24:44+00	0	\N	134d88d8f115d69dcf6abc00c9bf73a506b7f770bf96485336ead73383662792	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/13 allegretto e sempre Sinfonia Il giorno onamastico in D major.ape
1299511	\N	\N	1299510	2012-11-30 07:24:44+00	0	\N	2348b7fbc7533752a72ce33a3b8325b6a7060f49a1a66582057c30cdeecd306a	/home/extra/music/Antonio Salieri - Symphonies Overtures and Variations/14 Overture to Falstaff ossia Le tre burle in D major.ape
1938204	\N	\N	1937825	2012-11-30 07:59:40+00	0	\N	b5fa049c0b9aa09a629b1ddef91e507709b2e4eae74f0c3c044c0391f324d334	/home/extra/music/Fischer_Dieskau_Sings_Mahler_Ging_heut_Morgen_bers_Feld-tKtRombx5DM.aac
1938896	\N	\N	1938574	2012-11-30 07:59:40+00	0	\N	3e5ab1abec4e5d132287ca5acaf72328ad44da104855bda9c3e709bd7729897f	/home/extra/music/Foxy_Shazam_Unstoppable_Video-OFt3OqmGSbI.aac
1939740	\N	\N	1939166	2012-11-30 07:59:40+00	0	\N	ec9b91a9b4fe11ada11e5f1dc89ec3a1539f97de5322b20f37d19b4fe8b79b94	/home/extra/music/Franz_Schubert_Ellens_Gesang_Nr_3_Ave_Maria-mVMmIJiqSJc.aac
1942511	\N	\N	1940702	2012-11-30 07:59:40+00	0	\N	e5afd43299ae61e9a53799abcfd300e6227045598b4222b06f74fa338dbf21de	/home/extra/music/Gregorian_Chant_Dies_Irae-Dlr90NLDp-0.aac
1943974	\N	\N	1942903	2012-11-30 07:59:41+00	0	\N	fbac11ea1fe3a2b0a8cc948ccefcc110b9c48be1c747e84ef54c80d6b50c5836	/home/extra/music/Hanson_MMMBop-NHozn0YXAeE.aac
1945142	\N	\N	1944393	2012-11-30 07:59:41+00	0	\N	0abf867bc59ff168dd447991a7328efa64cdab4270aad8ebaf6fad323a57efb5	/home/extra/music/Hermes_House_Band_Country_Roads_Remix-AmMtCGs5wAc.aac
1946299	\N	\N	1945723	2012-11-30 07:59:41+00	0	\N	a31b2011a6b96b6c49652b64e41e334bf1303d556037b9b4719abcfe01071563	/home/extra/music/HyadainRapdeChocoboEnglishSubtitles.aac
1947559	1946807	1947239	1946803	2012-11-30 07:59:42+00	0	\N	cfaa2e06d52a961f2b5f8921c8abb7046f56966e90937be679ac02b6d47084dc	/home/extra/music/Infected Mushroom - Killing Time (feat. Perry Ferrell) [www.boom4u.info].mp3
3540	3539	\N	3538	2012-11-30 05:51:09+00	0	\N	dc0778f2ce86594fe51300eaff484be6ae61d5e4908d6681aed21d687c129c2f	/home/extra/music/InTheMorning.mp3
1950661	\N	\N	1949642	2012-11-30 07:59:42+00	0	\N	939719b95d893b7d563ffba3d6686e3c1f126dfe8189fad68d4a777b846c47a7	/home/extra/music/Mt_Eden_Dubstep_HD_Sierra_Leone-iy2TOdvr8QY.aac
1952479	\N	\N	1951335	2012-11-30 07:59:42+00	0	\N	079220676fd2598e381918f19ba00a534677661981ef6358fbeb0361e62a713d	/home/extra/music/Nagual_Sound_Experiment_Frontier-yJWp083Pv3Y.aac
1954331	\N	\N	1953524	2012-11-30 07:59:42+00	0	\N	8ba51b6274cda6d510b4c0a4e6a1a425c74f1176a547895d79578348f8e969b9	/home/extra/music/Origa_I_am_Taken_Away-h75-C-pMZ5M.aac
1042517	\N	\N	1042516	2012-11-30 05:58:17+00	0	\N	32f65d62a1ccee089ed685a04f01fe93c3a6c1624769f067acdf5480b714724f	/home/extra/music/pendulum_through_the_loop.aac
1959276	\N	\N	1958523	2012-11-30 07:59:43+00	0	\N	1a9515443fead928109695185fce0f8bcc59e16970f6312be347939932cf40e9	/home/extra/music/Quick_from_Rockman2_Megaman2-AXgoMsRg4SI.aac
1962148	\N	\N	1960550	2012-11-30 07:59:43+00	0	\N	739fa2093af356d86554694997bbf547b7c6f646ba537d2a51547e01f9785802	/home/extra/music/Robot_Unicorn_Attack_Song_HD_Erasure_Always-FUaKxFjlOpw.aac
1967602	\N	\N	1965964	2012-11-30 07:59:44+00	0	\N	9fce59254311eac066dcb9ffe46fc3294fdb635d46c07b66d18fc4c6faa2d198	/home/extra/music/SNES_Secret_of_Mana_In_the_beginning-SnsJI4rmoVE.aac
1042829	1042828	\N	1042827	2012-11-30 06:03:41+00	0	\N	2bc81c347a29d90266294747ec7675da8479a4d04e213fbab594cd4ffeb274fd	/home/extra/music/Squarepusher - Port Rhombus.mp3
1043035	1043033	1043034	1043032	2012-11-30 06:04:19+00	0	\N	368cf9bb9b3419e4a7fcf8d029118d932cb703d10fdef53eadaf325e3883cc2d	/home/extra/music/Themes_-_TV_Shows_-_Pinky_And_The_Brain.mp3
1042456	\N	\N	1042455	2012-11-30 05:57:33+00	0	\N	4d52d691481b2d29468adac51c87661c05d92774e6c465c36900f1ceceb71945	/home/extra/music/Toy box - Miss Papaya - Supergirl.mp3
1975536	\N	\N	1973735	2012-11-30 07:59:45+00	0	\N	ca1aa35fdc371df67f4d01517374586c2ec0dea751f76054b45ab2c705b90338	/home/extra/music/You_re_Not_Alone_fan_vocal_version-qmbgCBZ86z4.aac
3537	\N	\N	3536	2012-11-30 08:13:20+00	0	\N	711a2a6f5fc1f467400983983ee51c24d552ba0c33c16966220b6556c6d7266a	/home/extra/music/Simple Plan - Me Against The World.mp3
4087283	\N	\N	1042755	2012-11-30 08:12:56+00	0	\N	71d5dcc959d82e928cf5c241bf72c1fe8e21fda34c2ba169878dc6bdfcd34d15	/home/extra/music/Unwritten.aac
7411946	\N	\N	7408501	2012-11-30 08:13:58+00	0	\N	ce48a72f51cd2182a2039e4ed632f62cb385f5d120ab5eed622197b24fa4ca45	/home/extra/music/YouAreAPirateLazyTown.aac
\.


--
-- Data for Name: replaygain; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY replaygain (gain, peak, level, id) FROM stdin;
1	-4.29999999999999982	89	685
1	-8.11999999999999922	89	664
0.999337000000000031	-3.75	89	666
1	-2.93999999999999995	89	695
1	-6	89	668
1	-5.66000000000000014	89	687
1	-6.95000000000000018	89	670
0.98731100000000005	-6.34999999999999964	89	672
1	-5.58000000000000007	89	674
1	-2.81000000000000005	89	689
0.953964999999999952	-4.86000000000000032	89	676
1	-7.15000000000000036	89	678
1	-5.07000000000000028	89	702
0.92045699999999997	-3.60999999999999988	89	680
1	-5.53000000000000025	89	691
1	-4.29000000000000004	89	683
0.899681999999999982	-0.709999999999999964	89	697
1	-4.21999999999999975	89	693
1	-3.68000000000000016	89	700
1	-4.87999999999999989	89	706
1	-4.40000000000000036	89	704
0.873211999999999988	-2.41000000000000014	89	708
1	-4.04000000000000004	89	710
0.846847000000000016	0.520000000000000018	89	742
0.999179999999999957	-5.46999999999999975	89	712
0.805750999999999995	0.239999999999999991	89	732
1	-5.04000000000000004	89	714
1	-4.91999999999999993	89	716
0.920158000000000031	-4.61000000000000032	89	719
0.873207999999999984	-2.31999999999999984	89	734
0.907348999999999961	-4.67999999999999972	89	721
0.994887999999999995	-4.41000000000000014	89	723
0.893321000000000032	-4.03000000000000025	89	725
0.84265000000000001	-1.23999999999999999	89	736
0.886298999999999948	-6.11000000000000032	89	727
1	-2.45000000000000018	89	730
0.793073999999999946	-1.84000000000000008	89	744
0.961241000000000012	-2.70000000000000018	89	738
0.790563000000000016	-1.87999999999999989	89	740
1	-4.37000000000000011	89	749
0.994576000000000016	-4.13999999999999968	89	747
1	-4.09999999999999964	89	751
0.947369000000000017	-3.43000000000000016	89	750
1	-5.28000000000000025	89	753
0.855760999999999994	-1.55000000000000004	89	755
1	-3.72999999999999998	89	756
1	-5.75	89	774
0.967234000000000038	-3.75999999999999979	89	758
1	-8.19999999999999929	89	760
1	-2.97999999999999998	89	782
0.992207999999999979	-7.50999999999999979	89	762
0.992846000000000006	-6.16000000000000014	89	776
0.990922999999999998	-4.91000000000000014	89	764
0.987501999999999991	-6.23000000000000043	89	766
1	-8.33999999999999986	89	768
1	-6.54999999999999982	89	778
1	-6.33000000000000007	89	770
1	-5.15000000000000036	89	772
1	-5.65000000000000036	89	783
0.918592999999999993	-1.46999999999999997	89	780
1	-4.53000000000000025	89	781
1	-5.32000000000000028	89	786
1	-6.21999999999999975	89	784
0.81180399999999997	-1.57000000000000006	89	790
1	-5.66999999999999993	89	785
1	-5.28000000000000025	89	787
0.702227000000000046	-2.54000000000000004	89	791
0.894418999999999964	-0.309999999999999998	89	793
0.694250999999999951	2.33000000000000007	89	794
0.735419000000000045	-0.760000000000000009	89	796
1	-9.8100000000000005	89	817
0.673760000000000026	-1.44999999999999996	89	798
0.859550999999999954	0.510000000000000009	89	799
0.508831000000000033	2.87999999999999989	89	838
0.688197999999999976	-0.170000000000000012	89	800
1	-8.94999999999999929	89	819
0.813849000000000045	-0.859999999999999987	89	802
1	-7.62000000000000011	89	805
0.532344000000000039	6.86000000000000032	89	832
1	-7.46999999999999975	89	807
0.981333000000000011	-6.19000000000000039	89	821
1	-8.83000000000000007	89	809
1	-7.54999999999999982	89	811
1	-9.75	89	813
1	-5.74000000000000021	89	825
1	-9.89000000000000057	89	815
0.095100000000000004	14.8000000000000007	89	834
0.302703	4.33000000000000007	89	827
0.581125000000000003	1.22999999999999998	89	830
0.962172999999999945	0.0700000000000000067	89	842
0.87766999999999995	3.20000000000000018	89	836
0.933212999999999959	2.41999999999999993	89	840
0.425578999999999985	9.33000000000000007	89	844
0.416829999999999978	6.16000000000000014	89	846
0.684761999999999982	7.70999999999999996	89	848
1	-5.95000000000000018	89	1439
0.86582899999999996	1.94999999999999996	89	850
0.914062000000000041	1.29000000000000004	89	852
0.860617999999999994	1	89	854
0.636595000000000022	5.83999999999999986	89	874
1	-6.70000000000000018	89	856
0.68210000000000004	0.709999999999999964	89	859
0.502803	7.16999999999999993	89	892
0.680776000000000048	4.40000000000000036	89	862
0.862245999999999957	-0.359999999999999987	89	876
0.501983999999999986	3.33999999999999986	89	864
0.327286000000000021	9.61999999999999922	89	866
0.926470000000000016	5.53000000000000025	89	886
0.402156999999999987	11.2899999999999991	89	868
0.138579000000000008	19.3000000000000007	89	878
0.283999999999999975	10.4700000000000006	89	870
0.957945000000000046	-2.54999999999999982	89	872
0.959494999999999987	7.63999999999999968	89	880
0.41046100000000002	5.16999999999999993	89	882
0.197360000000000008	9.6899999999999995	89	888
0.231108000000000008	11.5600000000000005	89	884
0.293161000000000005	9.61999999999999922	89	896
0.977528999999999981	-0.910000000000000031	89	890
0.898850999999999956	3.85000000000000009	89	894
0.0947179999999999966	13.8200000000000003	89	898
0.308748000000000022	11.3499999999999996	89	900
0.727293999999999996	1.40999999999999992	89	902
0.766457000000000055	3.72999999999999998	89	904
0.888414999999999955	3.93999999999999995	89	906
0.908063999999999982	-0.239999999999999991	89	930
0.49648500000000001	2.7200000000000002	89	908
0.856874000000000025	-1.33000000000000007	89	910
0.827718999999999983	0.82999999999999996	89	942
0.133339999999999986	14	89	912
0.819100999999999968	0.0500000000000000028	89	932
0.708199000000000023	1.78000000000000003	89	914
0.602770000000000028	2.47999999999999998	89	916
0.98983500000000002	1.1100000000000001	89	918
0.84034399999999998	-1.53000000000000003	89	934
0.81201000000000001	-1.67999999999999994	89	921
1	-8.35999999999999943	89	924
0.951377000000000028	-0.839999999999999969	89	926
0.895264999999999977	-0.819999999999999951	89	936
0.870738000000000012	-1.8600000000000001	89	928
0.992883999999999989	-0.429999999999999993	89	944
0.589041999999999955	1.65999999999999992	89	938
0.917679000000000022	-2.45999999999999996	89	940
1	-3.89000000000000012	89	952
0.980667999999999984	-3.10999999999999988	89	948
0.459913999999999989	7.70999999999999996	89	950
0.882781000000000038	-4.51999999999999957	89	956
1	-4.29999999999999982	89	954
0.238716000000000012	8.74000000000000021	89	958
1	-3.95999999999999996	89	960
0.939996000000000054	-3.45000000000000018	89	962
0.96930700000000003	-4.40000000000000036	89	964
0.420155999999999974	4.88999999999999968	89	987
0.0396519999999999997	19.7800000000000011	89	968
0.484966000000000008	6	89	969
0.077218999999999996	24.2600000000000016	89	999
0.271901999999999977	6.58000000000000007	89	971
0.135495000000000004	14.3499999999999996	89	989
0.616036000000000028	1.37000000000000011	89	973
0.521298999999999957	2.0299999999999998	89	975
0.936595999999999984	-4.25	89	977
0.587342000000000031	-3.33999999999999986	89	991
0.526195999999999997	0.23000000000000001	89	979
0.903433999999999959	-0.270000000000000018	89	981
0.756043000000000021	-3.68000000000000016	89	983
0.190479000000000009	11.4900000000000002	89	993
0.511321000000000025	3.60999999999999988	89	985
0.484088000000000018	2.12000000000000011	89	1001
0.833122999999999947	2.43999999999999995	89	995
0.92950200000000005	3.04999999999999982	89	1011
0.629066000000000014	1.06000000000000005	89	997
0.132171000000000011	11.5199999999999996	89	1007
0.798324999999999951	0.299999999999999989	89	1003
0.892117999999999967	-0.510000000000000009	89	1005
0.0778660000000000047	10.8800000000000008	89	1009
0.689293999999999962	0.520000000000000018	89	1013
0.883051999999999948	0.400000000000000022	89	1015
0.191878999999999994	11.9000000000000004	89	1017
0.948980999999999963	-4.20999999999999996	89	1289
0.825408000000000031	2.08999999999999986	89	1019
0.274930999999999981	18.370000000000001	89	1041
0.885237999999999969	0.939999999999999947	89	1021
0.135809999999999986	17.0199999999999996	89	1023
0.113952999999999999	15.6500000000000004	89	1025
0.226940000000000003	10.9000000000000004	89	1044
0.0846879999999999994	14.5199999999999996	89	1027
0.142084999999999989	6.48000000000000043	89	1029
0.715698999999999974	1.52000000000000002	89	1031
0.196199000000000012	10.9700000000000006	89	1046
0.516786999999999996	-0.589999999999999969	89	1033
0.53867200000000004	3.89999999999999991	89	1035
0.228243000000000001	11.6500000000000004	89	1054
0.26335900000000001	15.9800000000000004	89	1037
0.160702000000000012	16.9600000000000009	89	1048
0.259566999999999992	3.16000000000000014	89	1039
0.221134999999999998	14.0199999999999996	89	1060
0.698394999999999988	1	89	1050
0.690205999999999986	5.74000000000000021	89	1056
0.112884999999999999	14.6300000000000008	89	1052
1	2.41000000000000014	89	1058
0.57263799999999998	6.55999999999999961	89	1062
0.253867000000000009	9.33000000000000007	89	1064
0.826600000000000001	0.23000000000000001	89	1066
0.664862999999999982	2.64000000000000012	89	1068
0.496352000000000015	3.9700000000000002	89	1070
0.843894999999999951	-0.309999999999999998	89	1072
0.805332000000000048	0.0899999999999999967	89	1074
1	0.0400000000000000008	89	1092
0.907694000000000001	1.57000000000000006	89	1076
0.242020999999999986	15.9000000000000004	89	1078
0.891855999999999982	-0.569999999999999951	89	1102
0.122010999999999994	17.8099999999999987	89	1080
0.0963100000000000067	17.7899999999999991	89	1094
0.119155999999999998	19.2100000000000009	89	1083
0.148991000000000012	14.0899999999999999	89	1086
0.430248000000000019	5.20999999999999996	89	1088
0.0637989999999999946	21.620000000000001	89	1096
0.0973099999999999937	16.6099999999999994	89	1090
0.707481000000000027	1	89	1098
0.266537999999999997	7.63999999999999968	89	1104
0.704570999999999947	1.25	89	1100
0.944239999999999968	-1.28000000000000003	89	1108
0.799305999999999961	-0.790000000000000036	89	1106
0.710587999999999997	0.110000000000000001	89	1110
0.392108999999999985	4.41999999999999993	89	1112
1	1.07000000000000006	89	1114
0.547127999999999948	3.16000000000000014	89	1116
0.829255999999999993	1.35000000000000009	89	1118
0.824173999999999962	0.680000000000000049	89	1120
0.329573999999999978	5.83999999999999986	89	1122
0.801710000000000034	-1	89	1141
0.774908999999999959	-1.05000000000000004	89	1125
0.690053999999999945	2.25999999999999979	89	1127
0.938100000000000045	-1.60000000000000009	89	1153
0.311161999999999994	6.67999999999999972	89	1129
0.894742000000000037	-0.82999999999999996	89	1143
0.710152000000000005	-0.969999999999999973	89	1131
0.708852000000000038	-0.450000000000000011	89	1133
0.734669000000000016	3.20999999999999996	89	1135
0.902197000000000027	4.96999999999999975	89	1145
0.704763000000000028	0.369999999999999996	89	1137
0.951675000000000049	-2.04999999999999982	89	1139
0.261506999999999989	9.48000000000000043	89	1147
0.951969999999999983	-2.37000000000000011	89	1155
0.957525999999999988	1.44999999999999996	89	1149
0.927893999999999997	2.87000000000000011	89	1151
0.936092000000000035	-0.689999999999999947	89	1161
0.86989099999999997	-2.77000000000000002	89	1157
0.982404000000000055	0.780000000000000027	89	1159
0.743693999999999966	-0.179999999999999993	89	1166
0.957613999999999965	-1.46999999999999997	89	1163
0.453208999999999973	7.70999999999999996	89	1168
0.961836000000000024	2.12999999999999989	89	1170
1	-3.39999999999999991	89	1172
0.254413999999999974	10.1300000000000008	89	1173
0.263954999999999995	8.11999999999999922	89	1175
0.682889999999999997	3.04999999999999982	89	1195
0.94785699999999995	2.27000000000000002	89	1177
0.311354999999999993	8.33000000000000007	89	1179
0.960022000000000042	1.03000000000000003	89	1215
0.133256999999999987	13.9399999999999995	89	1181
0.894688000000000039	-0.849999999999999978	89	1197
0.914344000000000046	-1.76000000000000001	89	1183
0.906213999999999964	2.79000000000000004	89	1185
0.278569999999999984	7.87999999999999989	89	1209
0.968508000000000036	-4.08000000000000007	89	1187
0.51714899999999997	0.739999999999999991	89	1199
1	2.81999999999999984	89	1189
0.620797999999999961	3.14999999999999991	89	1191
0.363377999999999979	5.83000000000000007	89	1193
0.906510000000000038	-1.51000000000000001	89	1201
0.889507999999999965	0.400000000000000022	89	1203
0.555937000000000014	3.25999999999999979	89	1211
0.666598000000000024	10.6799999999999997	89	1207
0.850848000000000049	-1.3600000000000001	89	1219
0.243983000000000005	10.9100000000000001	89	1213
0.589735000000000009	1.23999999999999999	89	1217
0.677605000000000013	2.2200000000000002	89	1221
0.508318999999999965	5.33999999999999986	89	1223
0.730720000000000036	-0.270000000000000018	89	1225
1	-2.85000000000000009	89	1291
0.849625999999999992	3.06999999999999984	89	1227
0.212073000000000012	10.1199999999999992	89	1229
0.863022999999999985	-4.25	89	1265
0.741433000000000009	1.54000000000000004	89	1231
0.959021000000000012	-0.170000000000000012	89	1251
0.739003999999999994	2.83999999999999986	89	1235
0.848478999999999983	-0.140000000000000013	89	1237
0.420182999999999973	7.96999999999999975	89	1239
1	-2.99000000000000021	89	1255
0.969160000000000021	0.560000000000000053	89	1241
0.780827000000000049	1.18999999999999995	89	1243
1	-3.99000000000000021	89	1273
0.629031000000000007	2.35000000000000009	89	1245
0.97165199999999996	-1.23999999999999999	89	1257
0.928846999999999978	1.81000000000000005	89	1247
0.876391000000000031	-0.489999999999999991	89	1249
0.795781999999999989	-2.41999999999999993	89	1267
1	-6.71999999999999975	89	1259
0.781221000000000054	-2.47999999999999998	89	1261
1	-6.20000000000000018	89	1263
1	-2.49000000000000021	89	1269
0.922089000000000047	-4.08000000000000007	89	1275
0.740317000000000003	-2.43999999999999995	89	1271
1	-6.12000000000000011	89	1281
0.676781999999999995	-2.0299999999999998	89	1279
1	-9.17999999999999972	89	1277
0.90137299999999998	-2.06000000000000005	89	1283
0.946894000000000013	-2.37000000000000011	89	1285
1	-6.07000000000000028	89	1287
0.499477999999999978	0.810000000000000053	89	1293
1	-6.25	89	1295
1	-6.71999999999999975	89	1316
1	-2.99000000000000021	89	1296
1	-6.05999999999999961	89	1298
0.43142999999999998	1.54000000000000004	89	1333
0.781221000000000054	-2.47999999999999998	89	1299
0.88497899999999996	-6.08999999999999986	89	1318
0.986956000000000055	-1.58000000000000007	89	1301
1	-5.42999999999999972	89	1303
0.846910000000000052	-5	89	1305
1	-3.99000000000000021	89	1319
1	-5.41000000000000014	89	1307
0.885809999999999986	-5.87999999999999989	89	1309
1	-3.2799999999999998	89	1311
1	-6.01999999999999957	89	1321
1	-6.46999999999999975	89	1313
0.957583999999999991	-5.08000000000000007	89	1315
1	-6.20000000000000018	89	1322
0.768491999999999953	-3.50999999999999979	89	1329
1	-5.84999999999999964	89	1324
0.740317000000000003	-2.43999999999999995	89	1334
0.499477999999999978	0.810000000000000053	89	1325
0.990110000000000046	-4.05999999999999961	89	1327
0.915730000000000044	-2.33999999999999986	89	1331
0.986956000000000055	-1.58000000000000007	89	1337
1	-7.41000000000000014	89	1336
0.958624999999999949	-4.08999999999999986	89	1339
1	-5.84999999999999964	89	1340
1	-1.65999999999999992	89	1342
1	-5.78000000000000025	89	1344
0.980094000000000021	-4.58999999999999986	89	1346
0.973852000000000051	-7.24000000000000021	89	1348
0.871701999999999977	-6.54999999999999982	89	1350
1	-5.95000000000000018	89	1370
0.915028999999999981	-5.57000000000000028	89	1352
0.733053999999999983	-1.20999999999999996	89	1354
0.958624999999999949	-4.08999999999999986	89	1382
1	-6.36000000000000032	89	1356
0.928213999999999984	-6.62000000000000011	89	1372
0.846910000000000052	-5	89	1357
0.789923000000000042	-2.45000000000000018	89	1359
0.995074000000000014	-3.83999999999999986	89	1361
1	-7.33000000000000007	89	1374
0.789923000000000042	-2.45000000000000018	89	1362
0.97165199999999996	-1.23999999999999999	89	1363
1	-3.2799999999999998	89	1388
0.676781999999999995	-2.0299999999999998	89	1364
0.807082999999999995	-3.41000000000000014	89	1376
1	-4.20000000000000018	89	1366
0.817393000000000036	-5.57000000000000028	89	1368
0.838894999999999946	-6.66999999999999993	89	1384
0.522716999999999987	-0.770000000000000018	89	1378
0.653445000000000054	-3.37999999999999989	89	1380
0.795781999999999989	-2.41999999999999993	89	1381
1	-7.41000000000000014	89	1385
0.97414400000000001	-0.939999999999999947	89	1393
0.997985000000000011	-1.8600000000000001	89	1387
1	-2.49000000000000021	89	1389
0.928213999999999984	-6.62000000000000011	89	1391
0.863022999999999985	-4.25	89	1390
0.815178999999999987	-5.04000000000000004	89	1395
1	-3.81999999999999984	89	1397
0.97414400000000001	-0.939999999999999947	89	1398
0.653445000000000054	-3.37999999999999989	89	1399
1	-6.46999999999999975	89	1426
1	-5.42999999999999972	89	1400
0.922089000000000047	-4.08000000000000007	89	1414
0.885809999999999986	-5.87999999999999989	89	1401
1	-6.20999999999999996	89	1403
0.784757000000000038	-4.82000000000000028	89	1421
1	-6.01999999999999957	89	1404
0.88497899999999996	-6.08999999999999986	89	1415
1	-5.78000000000000025	89	1405
0.871701999999999977	-6.54999999999999982	89	1406
0.43142999999999998	1.54000000000000004	89	1407
1	-2.85000000000000009	89	1416
0.948980999999999963	-4.20999999999999996	89	1408
1	-6.25	89	1409
0.914192000000000005	-6.54000000000000004	89	1411
1	-6.05999999999999961	89	1417
1	-6.20999999999999996	89	1412
0.915028999999999981	-5.57000000000000028	89	1413
0.90137299999999998	-2.06000000000000005	89	1422
1	-3.81999999999999984	89	1418
0.914192000000000005	-6.54000000000000004	89	1419
0.259655999999999998	5.79999999999999982	89	1428
0.872006999999999977	0.599999999999999978	89	1424
0.522716999999999987	-0.770000000000000018	89	1425
0.980094000000000021	-4.58999999999999986	89	1431
0.719884999999999997	-4.41000000000000014	89	1430
0.71377400000000002	-5.30999999999999961	89	1434
1	-9.17999999999999972	89	1432
0.835859000000000019	-5.26999999999999957	89	1436
0.733053999999999983	-1.20999999999999996	89	1437
0.957583999999999991	-5.08000000000000007	89	1438
1	-1.65999999999999992	89	1440
1	-5.88999999999999968	89	1477
1	-6.07000000000000028	89	1441
0.807082999999999995	-3.41000000000000014	89	1454
0.995074000000000014	-3.83999999999999986	89	1442
0.768491999999999953	-3.50999999999999979	89	1443
1	-5.71999999999999975	89	1465
1	-5.41000000000000014	89	1444
1	-4.20000000000000018	89	1455
0.817393000000000036	-5.57000000000000028	89	1445
0.872214000000000045	-5.51999999999999957	89	1447
0.973852000000000051	-7.24000000000000021	89	1448
0.259655999999999998	5.79999999999999982	89	1456
0.71377400000000002	-5.30999999999999961	89	1449
0.872006999999999977	0.599999999999999978	89	1450
0.999138999999999999	-4.41999999999999993	89	1473
1	-6.12000000000000011	89	1451
1	-7.33000000000000007	89	1457
0.835859000000000019	-5.26999999999999957	89	1452
0.997985000000000011	-1.8600000000000001	89	1453
1	-2.4700000000000002	89	1467
0.872214000000000045	-5.51999999999999957	89	1458
0.840893000000000002	-1.41999999999999993	89	1461
0.780923000000000034	-3.37999999999999989	89	1463
0.895854999999999957	-2.45000000000000018	89	1469
1	-3.75	89	1471
1	-5.59999999999999964	89	1475
1	-3.37000000000000011	89	1481
0.971252000000000004	-1.96999999999999997	89	1479
1	-5.50999999999999979	89	1483
0.794049000000000005	-2.27000000000000002	89	1485
0.989897000000000027	-3.66999999999999993	89	1487
0.548783000000000021	-3.12000000000000011	89	1537
0.880624999999999991	-5.26999999999999957	89	1489
1	-10.5600000000000005	89	1514
1	-1.87999999999999989	89	1491
1	-7.62999999999999989	89	1494
1	-2.00999999999999979	89	1529
1	-9.89000000000000057	89	1496
0.247648000000000007	9.17999999999999972	89	1516
1	-8.91000000000000014	89	1498
0.53451700000000002	2.06000000000000005	89	1500
1	-6.11000000000000032	89	1502
1	-10.6600000000000001	89	1518
1	-5.08000000000000007	89	1504
1	-10.8800000000000008	89	1506
1	-9.03999999999999915	89	1508
1	-8.92999999999999972	89	1520
1	-5.74000000000000021	89	1510
0.986917999999999962	-5.44000000000000039	89	1512
0.726165999999999978	-5.33999999999999986	89	1531
1	-2.54999999999999982	89	1522
1	-7.15000000000000036	89	1524
0.888422000000000045	-2.83000000000000007	89	1545
0.978659999999999974	-4.71999999999999975	89	1527
1	-6.95000000000000018	89	1533
0.730737999999999999	-0.0400000000000000008	89	1539
1	-5.37000000000000011	89	1535
0.962971000000000021	-2.99000000000000021	89	1543
0.883275000000000032	-7	89	1541
0.944185000000000052	-9.50999999999999979	89	1547
1	-3.02000000000000002	89	1549
0.603678999999999966	0.630000000000000004	89	1551
0.825517999999999974	-6.78000000000000025	89	1553
1	-8.25	89	1577
1	-5.03000000000000025	89	1555
1	-3.35999999999999988	89	1557
1	0.359999999999999987	89	1599
1	-5.61000000000000032	89	1559
0.833689000000000013	-0.630000000000000004	89	1579
0.596745999999999999	-2.66999999999999993	89	1561
0.798158000000000034	-4.66999999999999993	89	1563
1	-6.08000000000000007	89	1591
0.631556000000000006	-3.58000000000000007	89	1565
1	-5.05999999999999961	89	1581
1	-6.98000000000000043	89	1567
1	-7.08000000000000007	89	1569
0.703775000000000039	-1.30000000000000004	89	1571
0.993912000000000018	-1.84000000000000008	89	1583
1	-8.41000000000000014	89	1573
1	-3.56999999999999984	89	1575
0.807227999999999946	-3.37999999999999989	89	1593
0.686459000000000041	-0.280000000000000027	89	1585
1	-5.26999999999999957	89	1587
0.821896999999999989	-5.73000000000000043	89	1607
1	-6.54000000000000004	89	1589
0.931350000000000011	-6.03000000000000025	89	1595
0.37600699999999998	-2.64000000000000012	89	1601
0.661712999999999996	-1.37000000000000011	89	1597
1	-1.87999999999999989	89	1605
0.469505000000000006	4.32000000000000028	89	1603
1	-8.91999999999999993	89	1609
1	-3.97999999999999998	89	1611
1	-6.95000000000000018	89	1612
0.979847000000000024	-4.71999999999999975	89	1613
1	-8.71000000000000085	89	1662
1	-5.37000000000000011	89	1614
1	-10.7899999999999991	89	1633
1	-2.33000000000000007	89	1616
1	-5.25999999999999979	89	1617
1	-4.49000000000000021	89	1648
0.800024999999999986	-4.66999999999999993	89	1618
1	-10.5700000000000003	89	1635
1	-7.08000000000000007	89	1619
1	-6.98000000000000043	89	1620
0.868916000000000022	-0.5	89	1622
0.886623999999999968	-4.63999999999999968	89	1637
1	-2.00999999999999979	89	1623
1	-5.03000000000000025	89	1624
1	-6.61000000000000032	89	1656
1	-10.3399999999999999	89	1627
1	-10.9600000000000009	89	1639
0.956794000000000033	-5.45999999999999996	89	1629
1	-10.7699999999999996	89	1631
1	-5.96999999999999975	89	1650
1	-8.77999999999999936	89	1642
0.991446999999999967	-5.99000000000000021	89	1644
0.995191999999999966	-6.53000000000000025	89	1646
0.985967000000000038	-5.23000000000000043	89	1652
1	-3.85000000000000009	89	1660
1	-5.26999999999999957	89	1654
0.977601000000000053	-5.99000000000000021	89	1658
1	-5.03000000000000025	89	1664
1	-4.32000000000000028	89	1666
0.993213000000000013	-5.19000000000000039	89	1668
1	-6.15000000000000036	89	1715
1	-7.41000000000000014	89	1670
1	-8.76999999999999957	89	1693
0.991396000000000055	-5.73000000000000043	89	1672
1	-6.46999999999999975	89	1674
1	-8.33999999999999986	89	1707
1	-5.33000000000000007	89	1676
1	-3.08999999999999986	89	1695
1	-1.6100000000000001	89	1678
0.989983999999999975	-2.29000000000000004	89	1680
1	-7.19000000000000039	89	1683
1	-7.99000000000000021	89	1697
1	-7.32000000000000028	89	1685
1	-7.28000000000000025	89	1687
0.992754000000000025	-3.64999999999999991	89	1689
1	-5.34999999999999964	89	1699
1	-8.5600000000000005	89	1691
1	-6.26999999999999957	89	1709
1	-4.58999999999999986	89	1701
1	-2.2200000000000002	89	1703
1	-3.74000000000000021	89	1705
1	-4.08000000000000007	89	1711
1	-2.95999999999999996	89	1717
1	-7.87000000000000011	89	1713
0.267907999999999979	9.1899999999999995	89	1722
0.645689999999999986	-0.349999999999999978	89	1720
0.996055000000000024	-1.62000000000000011	89	1727
0.979837999999999987	-3.04999999999999982	89	1724
1	-1.30000000000000004	89	1729
0.777139000000000024	0.380000000000000004	89	1731
0.997801999999999967	0.390000000000000013	89	1733
0.996667999999999998	-0.0400000000000000008	89	1735
1	-7.95999999999999996	89	1789
0.99945700000000004	-2.83000000000000007	89	1737
1	0.869999999999999996	89	1762
1	1.22999999999999998	89	1739
0.997979999999999978	-2.33000000000000007	89	1741
1	-4.04999999999999982	89	1777
0.959123999999999977	-1.57000000000000006	89	1743
1	-3.2200000000000002	89	1764
0.998542999999999958	-1.33000000000000007	89	1745
0.887041999999999997	0.429999999999999993	89	1747
0.996893999999999947	-0.239999999999999991	89	1749
1	-5.40000000000000036	89	1766
1	-4.51999999999999957	89	1752
1	-1.84000000000000008	89	1754
0.998059000000000029	-6.04999999999999982	89	1785
1	-4.28000000000000025	89	1756
0.985771999999999982	-5.62000000000000011	89	1769
1	-4.79999999999999982	89	1758
1	-3.56000000000000005	89	1760
1	-5.21999999999999975	89	1779
1	-5.41000000000000014	89	1771
1	-2.9700000000000002	89	1773
1	-6.80999999999999961	89	1775
1	-6.51999999999999957	89	1781
1	-6.71999999999999975	89	1783
1	-5.20000000000000018	89	1787
1	-2.43999999999999995	89	1793
1	-3.95999999999999996	89	1791
1	-5.04999999999999982	89	1795
0.993555999999999995	-5.67999999999999972	89	1797
1	-5.21999999999999975	89	1799
1	-5.07000000000000028	89	1801
1	-7.11000000000000032	89	1825
1	-6.95999999999999996	89	1803
0.990527999999999964	-6.86000000000000032	89	1805
1	-5.34999999999999964	89	1851
1	-9.58999999999999986	89	1807
1	-6.46999999999999975	89	1827
1	-5.11000000000000032	89	1809
1	-3.72999999999999998	89	1811
0.997221000000000024	-7.44000000000000039	89	1839
1	-9.91999999999999993	89	1813
0.898283999999999971	-6	89	1829
0.991218000000000043	-8.5	89	1815
1	-4.41000000000000014	89	1817
1	-5.54999999999999982	89	1819
1	-7.54999999999999982	89	1831
1	-11.6899999999999995	89	1821
1	-6.54999999999999982	89	1823
1	-7.19000000000000039	89	1847
1	-1.54000000000000004	89	1841
1	-3.52000000000000002	89	1833
1	-7.16000000000000014	89	1835
1	-6.88999999999999968	89	1837
1	-5.58000000000000007	89	1843
1	-3.77000000000000002	89	1845
1	-4.84999999999999964	89	1849
1	-5.48000000000000043	89	1855
1	-3.83999999999999986	89	1853
1	-5.57000000000000028	89	1857
1	-6	89	1859
0.770334999999999992	-5.09999999999999964	89	2053
1	-4.23000000000000043	89	1861
0.73369300000000004	0.739999999999999991	89	1886
1	-4.41999999999999993	89	1863
1	-5.37000000000000011	89	1865
0.783653000000000044	-0.910000000000000031	89	1912
1	-5.73000000000000043	89	1867
0.733936999999999951	-2.25999999999999979	89	1888
1	-2.54000000000000004	89	1869
1	-5.48000000000000043	89	1871
0.572819999999999996	1.64999999999999991	89	1900
1	-6.36000000000000032	89	1873
0.354903000000000024	1.8600000000000001	89	1890
0.647630000000000039	2.43000000000000016	89	1876
0.988233000000000028	-2.5	89	1878
1	1.30000000000000004	89	1880
0.669429000000000052	1.18999999999999995	89	1892
0.998260999999999954	-4.20000000000000018	89	1882
0.889457999999999971	-3.25	89	1884
1	-5.29999999999999982	89	1908
1	-6.90000000000000036	89	1902
0.984709999999999974	-3	89	1894
0.892523999999999984	-2.60999999999999988	89	1896
0.536209999999999964	1.09000000000000008	89	1898
0.687275999999999998	1.44999999999999996	89	1904
0.57470600000000005	-2.08000000000000007	89	1906
0.546740000000000004	-4.08999999999999986	89	1910
1	-3.7799999999999998	89	1914
1	-8.21000000000000085	89	1916
0.352057999999999982	0.520000000000000018	89	1918
1	-1.54000000000000004	89	1921
1	-5.28000000000000025	89	1923
0.954060000000000019	-1.68999999999999995	89	1975
1	-5.95000000000000018	89	1925
0.976272000000000029	-3.24000000000000021	89	1949
1	-5.17999999999999972	89	1927
0.908062999999999954	-5.59999999999999964	89	1929
0.998693000000000053	-6.09999999999999964	89	1963
0.990538999999999947	-4.34999999999999964	89	1931
1	-5.73000000000000043	89	1951
0.498562000000000005	1.12999999999999989	89	1933
0.977234999999999965	-3.25	89	1935
1	-7.83000000000000007	89	1937
0.956987000000000032	-3.08000000000000007	89	1953
1	-5.61000000000000032	89	1939
1	-6.95000000000000018	89	1941
1	-5.54000000000000004	89	1971
1	-2.10999999999999988	89	1943
0.89326899999999998	-1.17999999999999994	89	1955
1	-8.46000000000000085	89	1945
1	-8.41999999999999993	89	1947
0.978952000000000044	-2.16999999999999993	89	1965
1	-4.11000000000000032	89	1957
0.989725999999999995	-5.41999999999999993	89	1959
0.796399999999999997	-2.18000000000000016	89	1961
0.990812000000000026	-3.06999999999999984	89	1967
1	-2.70999999999999996	89	1969
1	-6.70999999999999996	89	1973
0.981820000000000026	-5.24000000000000021	89	1979
0.902917999999999998	-5.00999999999999979	89	1977
1	-5.41999999999999993	89	1982
0.584735000000000005	-3.20999999999999996	89	1984
0.938756999999999953	-3.2799999999999998	89	1986
0.968500000000000028	-7.13999999999999968	89	1988
0.715060999999999947	-2.43000000000000016	89	2041
1	-3.68000000000000016	89	1990
0.976713000000000053	-2.54000000000000004	89	2014
0.891283000000000047	-0.949999999999999956	89	1992
1	-7.78000000000000025	89	1994
0.590443000000000051	-0.429999999999999993	89	2029
1	-5.21999999999999975	89	1996
1	4.15000000000000036	89	2017
1	-5.87999999999999989	89	1998
0.594540999999999986	-4.41999999999999993	89	2000
1	-4.95000000000000018	89	2002
0.817142000000000035	-2.33999999999999986	89	2019
0.939683000000000046	-4.91000000000000014	89	2004
1	-7.58999999999999986	89	2006
0.596720000000000028	0.429999999999999993	89	2037
0.966161999999999965	-5.25	89	2008
0.859481999999999968	-4.08999999999999986	89	2021
0.746882999999999964	-0.680000000000000049	89	2010
1	-3.16000000000000014	89	2012
0.447174999999999989	-0.149999999999999994	89	2031
0.307049000000000016	0	89	2023
1	-2.08999999999999986	89	2025
0.741202000000000027	-0.890000000000000013	89	2027
1	-8.21000000000000085	89	2033
0.871879999999999988	-2.20999999999999996	89	2035
0.782166000000000028	0.100000000000000006	89	2039
1	-9.5600000000000005	89	2045
0.982582999999999984	-8.33999999999999986	89	2043
1	0.739999999999999991	89	2047
1	-6.00999999999999979	89	2049
0.616597999999999979	0.530000000000000027	89	2051
0.813282999999999978	-1.6399999999999999	89	2055
0.980041999999999969	-2.39999999999999991	89	2094
0.798194999999999988	-1.8600000000000001	89	2057
0.980262999999999995	-4.29999999999999982	89	2082
0.996751000000000054	-3.22999999999999998	89	2059
0.629350999999999994	0.719999999999999973	89	2061
0.68019099999999999	-1.53000000000000003	89	2063
1	-10.1400000000000006	89	2084
1	-5.46999999999999975	89	2065
0.584408000000000039	-0.149999999999999994	89	2067
0.987211999999999978	-3.02000000000000002	89	2106
0.730674999999999963	-2.14000000000000012	89	2069
1	-4.58000000000000007	89	2086
0.994420999999999999	-4.73000000000000043	89	2071
1	-5.44000000000000039	89	2073
1	-4.87000000000000011	89	2096
0.829281000000000046	-3.06999999999999984	89	2075
0.982735000000000025	-5.80999999999999961	89	2088
0.443778000000000006	0.890000000000000013	89	2077
0.985167000000000015	-3.10000000000000009	89	2080
1	-5.55999999999999961	89	2090
1	-5.28000000000000025	89	2102
0.98830399999999996	-6.88999999999999968	89	2092
1	-8.42999999999999972	89	2098
1	-4.95999999999999996	89	2100
1	-7.58999999999999986	89	2104
1	-4.30999999999999961	89	2110
0.994701999999999975	-6.01999999999999957	89	2108
1	-9.14000000000000057	89	2112
0.985921000000000047	-2.79000000000000004	89	2114
1	-3.33000000000000007	89	2161
0.990653000000000006	-4.21999999999999975	89	2116
1	-10.2100000000000009	89	2132
0.990021999999999958	-6.21999999999999975	89	2118
1	-8.74000000000000021	89	2120
1	-1.87999999999999989	89	2146
0.695088000000000039	-0.280000000000000027	89	2122
0.37600699999999998	-2.64000000000000012	89	2133
0.884901999999999966	-7	89	2123
0.603995999999999977	0.619999999999999996	89	2124
1	-3.00999999999999979	89	2142
0.469455999999999984	4.30999999999999961	89	2125
0.941682000000000019	-3	89	2134
0.620692000000000021	-3.56999999999999984	89	2126
1	-3.56000000000000005	89	2127
0.923571000000000031	-6.04000000000000004	89	2128
1	-6.48000000000000043	89	2136
1	-8.41000000000000014	89	2129
1	-8.25	89	2130
0.598091000000000039	-2.66999999999999993	89	2143
1	-3.39000000000000012	89	2138
0.499952999999999981	-0.270000000000000018	89	2140
1	-5.09999999999999964	89	2152
0.736472000000000016	-0.0299999999999999989	89	2141
0.993477999999999972	-1.84000000000000008	89	2144
1	0.359999999999999987	89	2147
0.816073999999999966	-3.37999999999999989	89	2145
1	-6.80999999999999961	89	2151
0.659132000000000051	-1.37000000000000011	89	2148
1	-3.4700000000000002	89	2154
1	-4.83000000000000007	89	2156
1	-2.33000000000000007	89	2158
1	-4.95000000000000018	89	2160
0.567640999999999951	-4.84999999999999964	89	2163
1	-3.22999999999999998	89	2188
1	-7.38999999999999968	89	2166
1	-2.41999999999999993	89	2168
1	-8.91000000000000014	89	2215
1	-0.0800000000000000017	89	2170
1	-2.4700000000000002	89	2190
1	-4.42999999999999972	89	2172
1	-3.2799999999999998	89	2174
1	-0.75	89	2202
0.96328999999999998	-1.90999999999999992	89	2176
1	-4.12999999999999989	89	2192
0.94111800000000001	-0.900000000000000022	89	2178
0.773251000000000022	-2.54000000000000004	89	2180
0.92579800000000001	-5.08000000000000007	89	2182
1	-4.84999999999999964	89	2194
0.963453000000000004	-6.41000000000000014	89	2184
1	-3.45999999999999996	89	2186
1	-7.59999999999999964	89	2211
1	-10.5700000000000003	89	2205
1	-1.55000000000000004	89	2196
1	-3.31999999999999984	89	2198
0.955415000000000014	-1.31000000000000005	89	2200
1	-10.8599999999999994	89	2207
1	-6.58999999999999986	89	2209
1	-7.87999999999999989	89	2213
1	-1.62000000000000011	89	2217
1	-7.75999999999999979	89	2219
1	-9.8100000000000005	89	2221
0.855357000000000034	-8.90000000000000036	89	2224
0.992924000000000029	-8.00999999999999979	89	2226
0.891577999999999982	-5.91000000000000014	89	2228
0.920246000000000008	-5.62000000000000011	89	2252
1	-9.90000000000000036	89	2230
1	-3.52000000000000002	89	2232
1	-7.62999999999999989	89	2273
1	-6.37999999999999989	89	2234
1	-2.06000000000000005	89	2254
1	-8.66999999999999993	89	2236
0.951512000000000024	-8.08000000000000007	89	2238
0.879851999999999967	-5.46999999999999975	89	2266
0.998507000000000033	-3.70999999999999996	89	2240
0.991308999999999996	-5.12999999999999989	89	2256
1	-9.4399999999999995	89	2242
0.991268000000000038	-2.14000000000000012	89	2244
1	-8.98000000000000043	89	2246
1	-3.87999999999999989	89	2258
0.883251000000000008	-4.95999999999999996	89	2248
1	-3.18999999999999995	89	2250
1	-7.92999999999999972	89	2268
0.992083999999999966	-6.96999999999999975	89	2260
0.897564999999999946	-4.08000000000000007	89	2262
0.944191000000000003	-9.50999999999999979	89	2277
0.998480999999999952	-2.50999999999999979	89	2264
0.886238999999999999	-2.83000000000000007	89	2270
0.82456700000000005	-6.78000000000000025	89	2274
0.937324000000000046	-0.0599999999999999978	89	2272
1	-5.05999999999999961	89	2276
0.364219999999999988	4.49000000000000021	89	2275
1	-6.08000000000000007	89	2279
1	-5.46999999999999975	89	2281
1	-4.42999999999999972	89	2283
1	-6.08999999999999986	89	2284
0.923414999999999986	-4.04000000000000004	89	2337
0.898417000000000021	-4.08999999999999986	89	2287
0.717559999999999976	-3.9700000000000002	89	2311
0.696721000000000035	-1.72999999999999998	89	2289
0.982786999999999966	-0.340000000000000024	89	2291
0.99879399999999996	-2.12000000000000011	89	2325
0.734531999999999963	-0.92000000000000004	89	2293
0.897548000000000012	-3	89	2313
1	-6.41000000000000014	89	2295
1	-3.25999999999999979	89	2297
0.918564000000000047	-6.25	89	2299
0.637889999999999957	-0.82999999999999996	89	2315
0.900900000000000034	-1.04000000000000004	89	2301
0.622709999999999986	-3.81999999999999984	89	2303
0.927730000000000055	-3.93000000000000016	89	2333
1	-5.08999999999999986	89	2305
0.955539999999999945	-0.880000000000000004	89	2317
1	-6.28000000000000025	89	2307
0.953969999999999985	-5.17999999999999972	89	2309
0.458129000000000008	2.99000000000000021	89	2327
0.991094999999999948	-5.16999999999999993	89	2319
0.960598999999999981	-3.75999999999999979	89	2321
0.732539000000000051	0.910000000000000031	89	2323
0.932835999999999999	-2.39999999999999991	89	2329
0.941104000000000052	-2.70000000000000018	89	2331
0.87977099999999997	-1.6100000000000001	89	2335
1	-3.70999999999999996	89	2341
0.866338000000000052	-4.32000000000000028	89	2339
0.77349699999999999	-5.63999999999999968	89	2343
0.935761999999999983	-3.43999999999999995	89	2345
0.95351600000000003	-3.54999999999999982	89	2347
0.75053700000000001	-1.75	89	2349
1	-4.83999999999999986	89	2375
0.983980999999999995	-5.23000000000000043	89	2351
0.933220000000000049	-2.31000000000000005	89	2353
1	-2.64000000000000012	89	2393
0.831708000000000003	-0.959999999999999964	89	2355
0.836946999999999997	0.179999999999999993	89	2377
1	-1.82000000000000006	89	2357
0.984966000000000008	-4.53000000000000025	89	2359
0.998388999999999971	-4.25999999999999979	89	2387
0.723631000000000024	-4.23000000000000043	89	2361
1	-3.99000000000000021	89	2379
0.762113999999999958	-5.13999999999999968	89	2363
0.000335999999999999981	64.0600000000000023	89	2365
0.970937999999999968	-2.14000000000000012	89	2367
1	-5.48000000000000043	89	2381
0.980307000000000039	-2.18999999999999995	89	2369
1	-4.25	89	2373
0.895321999999999951	-0.340000000000000024	89	2389
1	-5.32000000000000028	89	2383
1	-4.70999999999999996	89	2385
1	-5.33999999999999986	89	2397
0.995110999999999968	-2.95000000000000018	89	2391
1	-4.40000000000000036	89	2395
0.998951000000000033	-6.58000000000000007	89	2399
0.872906999999999988	-1.70999999999999996	89	2401
1	-6.00999999999999979	89	2403
0.505377999999999994	3.56999999999999984	89	2405
0.89919300000000002	-2.85999999999999988	89	2426
1	-6.86000000000000032	89	2407
0.979543000000000053	-3.95000000000000018	89	2410
0.594814999999999983	1.1399999999999999	89	2444
0.868788000000000005	-2.79999999999999982	89	2412
0.939776999999999973	-3.66000000000000014	89	2428
0.913721000000000005	1.75	89	2414
0.932964000000000016	-3.31000000000000005	89	2416
0.892430999999999974	0.309999999999999998	89	2438
0.870838000000000001	-1.34000000000000008	89	2418
0.365582000000000018	5.61000000000000032	89	2430
0.769908000000000037	2.74000000000000021	89	2420
0.912124999999999964	-1.91999999999999993	89	2422
0.707636000000000043	0.390000000000000013	89	2424
0.981712999999999947	-3.68999999999999995	89	2432
0.939115000000000033	-3.25999999999999979	89	2440
0.835641999999999996	-3.16000000000000014	89	2434
0.687200999999999951	1.42999999999999994	89	2436
0.992492999999999959	-2.83000000000000007	89	2451
0.827782000000000018	0.390000000000000013	89	2442
0.589106000000000019	2.89000000000000012	89	2449
0.753268000000000049	0.0200000000000000004	89	2446
1	-3.16000000000000014	89	2453
0.342193000000000025	4.15000000000000036	89	2455
0.988375000000000004	-5.04999999999999982	89	2457
0.995245999999999964	-4.95000000000000018	89	2459
0.996287999999999951	-4.96999999999999975	89	2479
0.99325399999999997	-5.17999999999999972	89	2461
0.990619000000000027	-0.440000000000000002	89	2463
1	1.09000000000000008	89	2494
0.350156000000000023	6.51999999999999957	89	2465
0.965234000000000036	-0.309999999999999998	89	2481
0.847150999999999987	-1.02000000000000002	89	2467
0.986056000000000044	0.0400000000000000008	89	2469
0.996640999999999999	-3.68000000000000016	89	2471
0.995184999999999986	-4.59999999999999964	89	2483
1	-3.9700000000000002	89	2473
0.994751000000000052	-4.69000000000000039	89	2475
0.620978999999999948	9.03999999999999915	89	2500
1	-7.07000000000000028	89	2477
0.939678000000000013	1.18999999999999995	89	2485
0.996804000000000023	-1.23999999999999999	89	2496
0.491495999999999988	5.71999999999999975	89	2487
1	2.27000000000000002	89	2491
1	-2.18000000000000016	89	2498
0.76368999999999998	0.739999999999999991	89	2504
0.62938700000000003	-0.260000000000000009	89	2502
0.875744999999999996	1.26000000000000001	89	2506
0.481298000000000004	4.62999999999999989	89	2559
0.759229000000000043	0.220000000000000001	89	2508
0.536185000000000023	3.72999999999999998	89	2546
0.82291000000000003	0.400000000000000022	89	2510
0.953061000000000047	0.200000000000000011	89	2528
0.825791000000000053	0.440000000000000002	89	2512
0.902468000000000048	-1.12000000000000011	89	2514
0.891361999999999988	-2.29000000000000004	89	2538
1	-2.2200000000000002	89	2516
0.963561000000000001	-2.33999999999999986	89	2530
0.678505000000000025	-0.0899999999999999967	89	2518
1	-0.910000000000000031	89	2520
1	3.91000000000000014	89	2522
0.969369999999999954	-0.609999999999999987	89	2532
1	5.91999999999999993	89	2524
1	-3.06999999999999984	89	2526
0.554374999999999951	4.16999999999999993	89	2544
1	-1.93999999999999995	89	2534
0.977833999999999981	2.22999999999999998	89	2540
0.286196000000000006	7.11000000000000032	89	2536
0.740774000000000044	-0.119999999999999996	89	2542
0.505175999999999958	3.70999999999999996	89	2550
0.478891000000000011	3.33000000000000007	89	2553
0.619929999999999981	1.51000000000000001	89	2556
0.647479000000000027	0.839999999999999969	89	2562
0.313379000000000019	7	89	2591
0.641163000000000038	3.72999999999999998	89	2565
0.475501000000000007	3.33999999999999986	89	2568
0.502937999999999996	5.03000000000000025	89	2605
0.843466000000000049	-0.890000000000000013	89	2571
0.410723000000000005	7.54999999999999982	89	2593
0.682351999999999959	1.97999999999999998	89	2574
0.851493000000000055	4.23000000000000043	89	2577
0.754340000000000011	0.790000000000000036	89	2580
0.366064000000000001	7.55999999999999961	89	2596
0.600816000000000017	4.09999999999999964	89	2584
0.691581000000000001	3.81999999999999984	89	2586
0.335488000000000008	7.12999999999999989	89	2615
0.696401000000000048	2.54999999999999982	89	2588
0.232613999999999987	11.6199999999999992	89	2609
0.783085999999999949	1.30000000000000004	89	2599
0.535753000000000035	3.7200000000000002	89	2602
0.837477999999999945	-1.19999999999999996	89	2620
0.939521000000000051	-0.819999999999999951	89	2612
0.703721999999999959	2.68000000000000016	89	2617
0.815432999999999963	0.729999999999999982	89	2622
0.923254000000000019	-0.800000000000000044	89	2624
0.897935000000000039	0.910000000000000031	89	2627
0.829622999999999999	-1.47999999999999998	89	2629
0.507565000000000044	5.83000000000000007	89	2654
0.824421999999999988	-1.28000000000000003	89	2631
0.486808999999999992	1.41999999999999993	89	2635
0.444628999999999996	5.37000000000000011	89	2637
0.430489999999999984	3.72999999999999998	89	2656
0.349329000000000001	4.45999999999999996	89	2639
0.376767999999999992	6.29000000000000004	89	2642
0.548401999999999945	1.83000000000000007	89	2666
0.624426000000000037	3.20999999999999996	89	2645
0.171811999999999993	15.1600000000000001	89	2658
0.659602000000000022	0.969999999999999973	89	2648
0.22761300000000001	7.45000000000000018	89	2650
0.421186999999999978	6.03000000000000025	89	2652
0.252062999999999982	6.95000000000000018	89	2676
0.612437000000000009	5.13999999999999968	89	2660
0.214174000000000003	11.5099999999999998	89	2670
0.565124999999999988	3.74000000000000021	89	2662
0.159504000000000007	13.8000000000000007	89	2664
0.134998000000000007	20.1499999999999986	89	2673
0.863059000000000021	-0.340000000000000024	89	2681
0.865569999999999951	-0.160000000000000003	89	2679
0.349700999999999984	6.36000000000000032	89	2684
0.461461999999999983	4	89	2687
0.274550000000000016	8.9399999999999995	89	2689
0.629622000000000015	1.89999999999999991	89	2715
0.337917000000000023	6.83999999999999986	89	2692
0.171583000000000013	10.2799999999999994	89	2695
0.726848999999999967	1.15999999999999992	89	2697
0.685463000000000044	5.28000000000000025	89	2718
0.405727999999999978	5.08000000000000007	89	2699
0.263832999999999984	9.0600000000000005	89	2701
0.858231999999999995	-0.709999999999999964	89	2703
0.643511999999999973	3.56000000000000005	89	2720
0.736326999999999954	2.83999999999999986	89	2705
0.729063000000000017	0.390000000000000013	89	2709
0.457538999999999974	4.99000000000000021	89	2728
0.284826999999999997	7.04999999999999982	89	2712
0.804865000000000053	1.12000000000000011	89	2722
0.288619000000000014	11.2400000000000002	89	2738
0.304933999999999983	7.34999999999999964	89	2724
0.226965	11.3200000000000003	89	2726
0.594119999999999981	7.82000000000000028	89	2731
0.760526000000000035	-2.20000000000000018	89	3032
0.757194999999999951	1.05000000000000004	89	2735
0.879395999999999955	-0.28999999999999998	89	2740
0.630847000000000047	4.32000000000000028	89	2742
0.636495000000000033	2.20999999999999996	89	2744
0.931041000000000007	3.00999999999999979	89	2746
0.650595000000000034	0.930000000000000049	89	2748
0.285434000000000021	9.6899999999999995	89	2788
0.447489000000000026	5.98000000000000043	89	2750
0.81917300000000004	0.119999999999999996	89	2776
0.686817000000000011	2.37000000000000011	89	2754
0.579902999999999946	4.08000000000000007	89	2756
0.668563000000000018	1.51000000000000001	89	2758
1	0.939999999999999947	89	2779
0.908402999999999961	-3.14999999999999991	89	2761
0.794012999999999969	0.489999999999999991	89	2763
0.24221100000000001	9.75999999999999979	89	2795
0.717087999999999948	0.469999999999999973	89	2765
0.532341999999999982	6.26999999999999957	89	2781
0.756414999999999949	2.58999999999999986	89	2767
0.762643999999999989	0.450000000000000011	89	2769
0.134145999999999987	17.9699999999999989	89	2790
0.287048999999999999	9.78999999999999915	89	2773
0.819438	0.0599999999999999978	89	2784
0.906158000000000019	-2.43999999999999995	89	2786
0.843647000000000036	-0.939999999999999947	89	2802
0.707007000000000052	2.62999999999999989	89	2793
0.911513000000000018	-1.55000000000000004	89	2799
0.758628999999999998	1.40999999999999992	89	2804
0.497844000000000009	3.87999999999999989	89	2806
0.697371999999999992	0.650000000000000022	89	2808
0.751414000000000026	1.06000000000000005	89	2810
0.734968999999999983	4.20000000000000018	89	2812
1	-0.110000000000000001	89	2832
0.774212000000000011	-0.979999999999999982	89	2814
0.188936999999999994	13.9299999999999997	89	2816
1	-2.89000000000000012	89	2842
0.635307999999999984	1.25	89	2818
1	-1.8600000000000001	89	2834
0.711562000000000028	0.280000000000000027	89	2820
1	-2.70000000000000018	89	2824
1	-1.85000000000000009	89	2826
1	-1.89999999999999991	89	2836
1	-1.01000000000000001	89	2828
1	-2.37999999999999989	89	2830
1	-2.56000000000000005	89	2848
1	-5.82000000000000028	89	2838
1	-1.54000000000000004	89	2844
1	-2.37000000000000011	89	2840
1	-5.29999999999999982	89	2846
1	-0.930000000000000049	89	2852
1	-2.18999999999999995	89	2850
1	0.979999999999999982	89	2854
1	-3.29000000000000004	89	2856
1	-1.29000000000000004	89	2858
0.949933999999999945	-3.31000000000000005	89	2880
1	-0.650000000000000022	89	2860
1	-2.37999999999999989	89	2862
0.994550000000000045	-3.16999999999999993	89	2892
1	-0.800000000000000044	89	2864
1	-4.11000000000000032	89	2882
1	-2.25999999999999979	89	2866
1	-2.20999999999999996	89	2868
1	2.35999999999999988	89	2870
0.990693000000000046	-3.45000000000000018	89	2884
0.99416199999999999	-3.20999999999999996	89	2874
1	-2.50999999999999979	89	2876
1	-4.58000000000000007	89	2904
0.915144999999999986	-2.87000000000000011	89	2878
0.833452999999999999	-3.91000000000000014	89	2894
0.994697999999999971	-5.08999999999999986	89	2886
0.991458999999999979	-2.4700000000000002	89	2888
1	-4.63999999999999968	89	2900
0.994820000000000038	-4.16999999999999993	89	2890
1	-3.62000000000000011	89	2896
1	-4.03000000000000025	89	2898
1	-3.02000000000000002	89	2902
0.994554000000000049	-3.60000000000000009	89	2906
0.993732999999999977	-3.14000000000000012	89	2909
0.845292000000000043	-0.939999999999999947	89	2911
0.633418000000000037	-1.80000000000000004	89	2913
0.901827999999999963	-4.16000000000000014	89	2915
1	-3.81999999999999984	89	2966
1	-3.08999999999999986	89	2917
0.958065000000000055	-4.29999999999999982	89	2939
0.471368000000000009	-0.440000000000000002	89	2919
0.752577000000000051	-3.00999999999999979	89	2921
1	-2.87000000000000011	89	2954
0.857091000000000047	-0.400000000000000022	89	2923
0.894136000000000042	-1.47999999999999998	89	2941
0.418159000000000003	-0.270000000000000018	89	2925
1	-5.23000000000000043	89	2927
1	-5.96999999999999975	89	2929
0.737978000000000023	-3.25	89	2944
1	-2.60999999999999988	89	2931
0.865312999999999999	-4.41000000000000014	89	2933
1	-5.62000000000000011	89	2962
1	-3.49000000000000021	89	2935
1	-5.54999999999999982	89	2946
0.894947000000000048	-3.89000000000000012	89	2937
1	-7.20999999999999996	89	2956
0.782974999999999977	-1.37999999999999989	89	2948
0.936829000000000023	-2.64999999999999991	89	2950
1	-6.41999999999999993	89	2952
1	-3.64000000000000012	89	2958
1	-5.51999999999999957	89	2960
0.943714000000000053	-4.58000000000000007	89	2964
1	-3.52000000000000002	89	2968
0.501207999999999987	-0.260000000000000009	89	2971
0.745056000000000052	-1.39999999999999991	89	2973
0.907618000000000036	-1.03000000000000003	89	2975
0.662363999999999953	1.5	89	2978
0.977754000000000012	-3.95999999999999996	89	3011
0.944392000000000009	-2.64000000000000012	89	2980
0.985908000000000007	-3.37999999999999989	89	2997
0.774782999999999999	0.0299999999999999989	89	2981
0.43324600000000002	2.24000000000000021	89	2983
0.677143999999999968	-1.20999999999999996	89	2985
0.898244000000000042	-2.95999999999999996	89	3001
0.909924999999999984	-1.27000000000000002	89	2987
0.700567999999999969	0.530000000000000027	89	2988
0.755572000000000021	-0.969999999999999973	89	3022
0.471426000000000012	-0.450000000000000011	89	2990
0.802050000000000041	-2.04999999999999982	89	3004
0.90251300000000001	-2.64999999999999991	89	2991
0.994049999999999989	-3.39000000000000012	89	2992
0.697931999999999997	-1.16999999999999993	89	3013
0.839068000000000036	-0.110000000000000001	89	2993
0.853840000000000043	-3.20999999999999996	89	3005
0.169242000000000004	10.5999999999999996	89	2995
0.968458999999999959	-2.2799999999999998	89	3007
0.854462999999999973	-0.0700000000000000067	89	3019
0.963353000000000015	-2.16999999999999993	89	3009
0.924609000000000014	-3.10999999999999988	89	3015
0.740605999999999987	-1.16999999999999993	89	3017
0.776719000000000048	-1.47999999999999998	89	3020
0.756711000000000023	-0.849999999999999978	89	3024
0.438995999999999997	4.46999999999999975	89	3026
0.737530000000000019	-3.10000000000000009	89	3028
0.842987000000000042	-1.5	89	3030
0.602327999999999975	-1.56000000000000005	89	3033
0.964149000000000034	-2.85000000000000009	89	3067
0.651275000000000048	-0.110000000000000001	89	3035
0.490586000000000022	0.309999999999999998	89	3053
0.649024999999999963	-1.15999999999999992	89	3036
0.753641000000000005	-0.160000000000000003	89	3038
0.971941000000000055	-4.30999999999999961	89	3062
0.81379199999999996	0.0700000000000000067	89	3040
0.592243999999999993	2.89999999999999991	89	3055
0.669309000000000043	0.0100000000000000002	89	3042
0.770834000000000019	3.43000000000000016	89	3044
0.374724000000000002	1.60000000000000009	89	3045
0.629209000000000018	1.60000000000000009	89	3056
0.505642999999999954	0.0800000000000000017	89	3047
0.688918999999999948	-0.800000000000000044	89	3048
0.923399999999999999	-1.07000000000000006	89	3049
0.899410999999999961	-4.03000000000000025	89	3059
0.588260000000000005	2.43000000000000016	89	3051
0.982813000000000048	-3.87999999999999989	89	3064
0.850148000000000015	-1.22999999999999998	89	3060
0.811732000000000009	-0.729999999999999982	89	3061
0.968067000000000011	-3.35000000000000009	89	3073
0.969886000000000026	-4.79000000000000004	89	3066
0.914816999999999991	-3.06999999999999984	89	3071
0.969996999999999998	-4.32000000000000028	89	3069
0.98692599999999997	-3.39000000000000012	89	3075
0.992281999999999997	-2.10999999999999988	89	3076
0.977862000000000009	-2.81999999999999984	89	3078
0.906293000000000015	-4.25999999999999979	89	3096
0.973920000000000008	-3.58999999999999986	89	3080
0.991179000000000032	-3.37000000000000011	89	3082
0.740198000000000023	-3.22999999999999998	89	3115
0.980410000000000004	-3.2799999999999998	89	3084
1	-3.20999999999999996	89	3097
1	-4.95000000000000018	89	3086
0.848882000000000025	-4.11000000000000032	89	3088
1	-4.36000000000000032	89	3107
0.872221000000000024	-3.54000000000000004	89	3090
0.990075000000000038	-2.56999999999999984	89	3099
1	-6.08999999999999986	89	3091
0.988092999999999999	-5.20999999999999996	89	3093
0.894210999999999978	-2.31999999999999984	89	3095
1	-7.26999999999999957	89	3113
0.961605999999999961	-2.81999999999999984	89	3101
1	-5.33000000000000007	89	3108
1	-4.54999999999999982	89	3104
0.89513699999999996	-2.5	89	3105
0.989319999999999977	-6.30999999999999961	89	3110
1	-5.16999999999999993	89	3112
0.937966999999999995	-4.42999999999999972	89	3114
0.994948000000000055	-4.84999999999999964	89	3117
0.911058999999999952	-2.74000000000000021	89	3119
1	-3.54000000000000004	89	3120
0.622855000000000047	-2.12000000000000011	89	3122
0.99732299999999996	-5.32000000000000028	89	3123
0.420308000000000015	2.9700000000000002	89	3143
0.984121000000000024	-5.05999999999999961	89	3125
0.955803999999999987	-3.12999999999999989	89	3128
0.970871999999999957	-3.95999999999999996	89	3165
0.997191999999999967	-2.47999999999999998	89	3130
0.658085999999999949	-1.03000000000000003	89	3145
0.998867999999999978	-2.64999999999999991	89	3131
1	-4.33999999999999986	89	3133
0.730420999999999987	-2.25999999999999979	89	3153
1	-3.39000000000000012	89	3134
0.831197999999999992	-0.25	89	3147
0.979126000000000052	-3.35000000000000009	89	3135
0.975878000000000023	-2.89000000000000012	89	3137
0.862671999999999994	-2.64000000000000012	89	3139
0.538856000000000002	-1.1100000000000001	89	3148
0.468895999999999979	1.20999999999999996	89	3141
1	-5.33999999999999986	89	3161
0.485458000000000001	0.390000000000000013	89	3155
0.810799000000000047	-3.08999999999999986	89	3149
0.778723000000000054	-2.7200000000000002	89	3150
0.656333000000000055	-1.81000000000000005	89	3151
0.754395999999999955	-0.309999999999999998	89	3156
0.235152	7.79000000000000004	89	3157
0.788742999999999972	-3.10999999999999988	89	3163
0.702280000000000015	0.599999999999999978	89	3168
1	-3.56000000000000005	89	3170
0.989315999999999973	-3.25999999999999979	89	3172
0.978913000000000033	-3.04000000000000004	89	3174
0.978899999999999992	-3.83999999999999986	89	3176
0.613682999999999979	0.560000000000000053	89	3213
0.992264000000000035	-4.59999999999999964	89	3178
0.551470000000000016	0.0599999999999999978	89	3201
0.787824999999999998	-3.06999999999999984	89	3180
0.71966399999999997	-2.58999999999999986	89	3183
0.916143000000000041	-4.41999999999999993	89	3185
0.856222000000000039	-1.87000000000000011	89	3203
0.958744999999999958	-3.12999999999999989	89	3187
0.958373999999999948	-4.76999999999999957	89	3189
0.973300000000000054	-3.47999999999999998	89	3223
0.956516000000000033	-4.55999999999999961	89	3191
0.903085000000000027	-2.16999999999999993	89	3193
0.915139000000000036	-2.2200000000000002	89	3205
0.790155000000000052	-3.22999999999999998	89	3195
0.957493999999999956	-3.5299999999999998	89	3197
0.860543999999999976	-3.77000000000000002	89	3215
0.67685799999999996	0.380000000000000004	89	3199
0.517866999999999966	0.900000000000000022	89	3207
0.609285999999999994	-1.3899999999999999	89	3209
0.672162999999999955	-1.52000000000000002	89	3217
0.954396000000000022	-2.54000000000000004	89	3211
0.602604999999999946	0.0299999999999999989	89	3219
0.858651999999999971	-1.72999999999999998	89	3221
0.576641999999999988	-0.589999999999999969	89	3225
0.755105000000000026	-3.81000000000000005	89	3227
0.986527999999999961	-6.37000000000000011	89	3229
0.954253000000000018	-3.45999999999999996	89	3231
0.996253999999999973	-1.12000000000000011	89	3492
0.968316999999999983	-2.68999999999999995	89	3233
0.957165000000000044	-0.200000000000000011	89	3235
0.901738999999999957	-6.99000000000000021	89	3257
0.903035000000000032	-5.59999999999999964	89	3239
0.922417000000000042	-3.9700000000000002	89	3241
0.97617200000000004	-6.45999999999999996	89	3277
0.927795999999999954	-0.520000000000000018	89	3243
0.910851999999999995	-6.15000000000000036	89	3259
0.922511999999999999	-6.83999999999999986	89	3245
0.842747000000000024	-2.93000000000000016	89	3247
0.966304000000000052	-4.54999999999999982	89	3271
0.944401000000000046	-7.17999999999999972	89	3249
0.925791000000000031	-8.8100000000000005	89	3261
0.949987000000000026	-5.21999999999999975	89	3251
0.880630000000000024	-4.25999999999999979	89	3253
0.996990000000000043	-6.42999999999999972	89	3255
0.978831000000000007	-6.61000000000000032	89	3265
0.967486999999999986	-5.66000000000000014	89	3273
0.968171000000000004	-2.45000000000000018	89	3267
0.946408999999999945	-3.16000000000000014	89	3269
1	-6.53000000000000025	89	3281
0.974411000000000027	-6.37999999999999989	89	3275
0.970654000000000017	-3.60000000000000009	89	3279
0.922332000000000041	-4.04999999999999982	89	3283
0.79772299999999996	-3.10999999999999988	89	3285
0.967535999999999952	-1.56000000000000005	89	3287
0.95527200000000001	-4.58999999999999986	89	3289
0.981829999999999981	-5.34999999999999964	89	3291
0.956987000000000032	-3.08000000000000007	89	1042439
0.976272000000000029	-3.24000000000000021	89	1042440
1	-2.70999999999999996	89	1042442
0.498562000000000005	1.12999999999999989	89	1042443
0.89326899999999998	-1.17999999999999994	89	1042444
1	-8.46000000000000085	89	1042445
0.908062999999999954	-5.59999999999999964	89	1042446
1	-5.61000000000000032	89	1042447
0.977234999999999965	-3.25	89	1042448
0.902917999999999998	-5.00999999999999979	89	1042449
0.990538999999999947	-4.34999999999999964	89	1042450
1	-7.83000000000000007	89	1042451
1	-5.73000000000000043	89	1042452
1	-8.41999999999999993	89	1042453
1	-6.95000000000000018	89	1042454
1	-10.6699999999999999	89	1042456
0.78053399999999995	4.57000000000000028	89	1042458
1	-11.8900000000000006	89	1042462
1	-6.42999999999999972	89	1042465
1	-3.25	89	1042468
1	-4.66999999999999993	89	1042471
1	-5.79000000000000004	89	1042473
1	-5.28000000000000025	89	1042474
1	-8.42999999999999972	89	1042475
0.990021999999999958	-6.21999999999999975	89	1042476
0.980262999999999995	-4.29999999999999982	89	1042477
0.118591000000000002	19.3299999999999983	89	1042533
0.980041999999999969	-2.39999999999999991	89	1042478
0.985921000000000047	-2.79000000000000004	89	1042479
0.865264999999999951	0.630000000000000004	89	1042536
1	-5.55999999999999961	89	1042480
1	3.62999999999999989	89	1042539
0.990653000000000006	-4.21999999999999975	89	1042481
0.999968999999999997	-2.14000000000000012	89	1042543
1	-10.1400000000000006	89	1042482
0.479096999999999995	2.70000000000000018	89	3314
1	-7.91999999999999993	89	3293
0.560559999999999947	-2.75999999999999979	89	3295
0.968852999999999964	-6.91999999999999993	89	3297
0.972524000000000055	-2.08999999999999986	89	3316
0.973188999999999971	-6.04000000000000004	89	3299
1	-4.41999999999999993	89	3301
0.756735999999999964	0.200000000000000011	89	3328
0.538082999999999978	-1.80000000000000004	89	3303
0.611013999999999946	0.380000000000000004	89	3318
0.990754000000000024	-2.91999999999999993	89	3306
1	-2.20000000000000018	89	3308
0.689698000000000033	0.200000000000000011	89	3310
0.748047000000000017	-0.540000000000000036	89	3320
1	-2.12000000000000011	89	3312
1	-4.59999999999999964	89	3337
0.910236999999999963	-1.44999999999999996	89	3330
1	-2.35000000000000009	89	3322
0.85484899999999997	-1.58000000000000007	89	3324
0.51405500000000004	2.02000000000000002	89	3326
0.993777000000000021	-3.04000000000000004	89	3332
0.880453999999999959	-0.75	89	3334
1	-2.77000000000000002	89	3339
0.902939999999999965	-5.79000000000000004	89	3341
0.978099000000000052	-6.63999999999999968	89	3343
1	-3.41000000000000014	89	3345
0.963716000000000017	-6.12000000000000011	89	3347
1	-4.20000000000000018	89	3367
0.863066	-3.85999999999999988	89	3349
1	-4.75	89	3351
0.47121200000000002	2.91999999999999993	89	3379
0.85844100000000001	-3.87999999999999989	89	3353
0.712165999999999966	5.66000000000000014	89	3371
0.677490999999999954	-2.75999999999999979	89	3355
0.914277000000000006	1.23999999999999999	89	3357
1	-5.94000000000000039	89	3359
1	-6.24000000000000021	89	3373
0.878647999999999985	-3.9700000000000002	89	3361
1	-8.07000000000000028	89	3363
0.843574999999999964	-2.93000000000000016	89	3365
0.842399000000000009	-1.17999999999999994	89	3381
1	-5.44000000000000039	89	3375
0.211909999999999987	7.67999999999999972	89	3377
0.285380000000000023	10.5800000000000001	89	3385
0.939934999999999965	-1.76000000000000001	89	3383
0.33507300000000001	5.58000000000000007	89	3389
1	-5	89	3387
1	-5.62000000000000011	89	3391
1	-3.02000000000000002	89	3393
0.902032999999999974	-4.79999999999999982	89	3488
0.913197000000000036	-4.45000000000000018	89	3490
1	-0.819999999999999951	89	3395
1	-4.16000000000000014	89	3429
0.407274999999999998	6.84999999999999964	89	3397
0.523985999999999952	0.900000000000000022	89	3417
0.347007999999999983	8.03999999999999915	89	3399
0.899124999999999952	-0.959999999999999964	89	3401
0.50143800000000005	2.16999999999999993	89	3403
0.915764000000000022	-0.680000000000000049	89	3419
0.978403000000000023	0.0299999999999999989	89	3406
0.811031999999999975	-0.489999999999999991	89	3407
1	-2.37999999999999989	89	3441
0.881927000000000016	0.890000000000000013	89	3409
0.871090999999999949	-0.390000000000000013	89	3421
0.687803999999999971	1.06000000000000005	89	3411
0.937506999999999979	-0.57999999999999996	89	3413
1	-4.24000000000000021	89	3431
0.973481999999999958	-0.220000000000000001	89	3414
1	-3.5299999999999998	89	3423
1	-4.07000000000000028	89	3425
1	-3.81000000000000005	89	3435
0.993878999999999957	-4.49000000000000021	89	3427
0.789835999999999983	2.91000000000000014	89	3433
1	-8.00999999999999979	89	3440
1	-6.38999999999999968	89	3434
1	-6.96999999999999975	89	3439
1	-6.30999999999999961	89	3442
1	-4.75999999999999979	89	3443
0.998516999999999988	-3.85000000000000009	89	3445
1	-6.32000000000000028	89	3462
1	-3.99000000000000021	89	3447
0.999349999999999961	-3.43999999999999995	89	3449
0.964969999999999994	-4.12999999999999989	89	3477
1	-6.66000000000000014	89	3451
0.998994000000000049	-2.77000000000000002	89	3464
1	-8.3100000000000005	89	3453
0.998669999999999947	-4.33000000000000007	89	3455
0.915240000000000054	-1.69999999999999996	89	3473
0.995960999999999985	-3.9700000000000002	89	3457
1	-7.54999999999999982	89	3465
0.999242999999999992	-4.36000000000000032	89	3458
1	-6.08000000000000007	89	3459
1	-8.84999999999999964	89	3460
1	-5.17999999999999972	89	3466
1	-3.68000000000000016	89	3475
1	-6.20000000000000018	89	3468
0.993792000000000009	-3.12000000000000011	89	3471
1	-1.21999999999999997	89	3480
0.985227999999999993	-2.77000000000000002	89	3476
1	-5.21999999999999975	89	3479
0.96115600000000001	-2.4700000000000002	89	3481
0.980994000000000033	-3.81999999999999984	89	3483
0.975218999999999947	-2.35000000000000009	89	3485
0.905390999999999946	-3.79999999999999982	89	3486
1	-4.33000000000000007	89	3494
1	-6.82000000000000028	89	1043042
0.993869000000000002	-0.640000000000000013	89	3496
0.993869000000000002	-1.87000000000000011	89	3498
0.993869000000000002	-1.8899999999999999	89	3500
0.993869000000000002	-3.00999999999999979	89	3502
1	-3.24000000000000021	89	3504
0.993869000000000002	-0.689999999999999947	89	3506
1	-4.38999999999999968	89	3508
0.947648999999999964	-3.95000000000000018	89	3510
1	-6.87999999999999989	89	3512
1	-8.25999999999999979	89	3514
1	-8.33999999999999986	89	3516
1	-7.08999999999999986	89	3518
1	-4.69000000000000039	89	3520
1	-6.36000000000000032	89	3522
1	-8.0600000000000005	89	3524
0.995936999999999961	-4.03000000000000025	89	3526
1	-6.45999999999999996	89	3528
1	-3.58999999999999986	89	3532
1	-6.75999999999999979	89	3540
0.981820000000000026	-5.24000000000000021	89	3543
1	-10.0999999999999996	89	3537
1	-2.10999999999999988	89	3548
1	-5.54000000000000004	89	3544
0.989725999999999995	-5.41999999999999993	89	3545
1	-5.17999999999999972	89	3551
1	-4.11000000000000032	89	3546
0.998693000000000053	-6.09999999999999964	89	3549
1	-6.70999999999999996	89	3547
0.990812000000000026	-3.06999999999999984	89	3550
0.978952000000000044	-2.16999999999999993	89	3553
0.954060000000000019	-1.68999999999999995	89	3552
0.796399999999999997	-2.18000000000000016	89	3554
1	-8.74000000000000021	89	1042484
0.82681300000000002	-4.75999999999999979	89	1042549
0.982666000000000039	-2.2799999999999998	89	1042498
0.985167000000000015	-3.10000000000000009	89	1042486
1	-4.87000000000000011	89	1042487
1	-9.14000000000000057	89	1042488
1	-4.58000000000000007	89	1042489
0.994701999999999975	-6.01999999999999957	89	1042490
0.98830399999999996	-6.88999999999999968	89	1042491
0.982735000000000025	-5.80999999999999961	89	1042492
1	-7.58999999999999986	89	1042493
1	-4.30999999999999961	89	1042494
0.983337000000000017	-5.96999999999999975	89	1042497
0.991638000000000019	-3.87000000000000011	89	1042499
0.992125999999999952	-8.73000000000000043	89	1042502
0.978180000000000049	-1.62000000000000011	89	1042500
1	-8.78999999999999915	89	1042501
0.999968999999999997	-6.45999999999999996	89	1042503
0.987211999999999978	-3.02000000000000002	89	1042485
1	-5.28000000000000025	89	3541
1	-5.95000000000000018	89	3555
0.784757000000000038	-4.82000000000000028	89	1042495
0.858011999999999997	-2.37999999999999989	89	1042762
0.998901000000000039	-4.29000000000000004	89	1042505
0.986937999999999982	-6.54000000000000004	89	1042509
0.997375000000000012	-5.29999999999999982	89	1042513
0.982025000000000037	-5.20000000000000018	89	1042510
0.993438999999999961	-5.33999999999999986	89	1042511
0.999968999999999997	-7.41000000000000014	89	1042514
0.86673	-5.80999999999999961	89	1042521
0.977966000000000002	-5.96999999999999975	89	1042515
0.982330000000000036	-6.62000000000000011	89	1042506
0.798583999999999961	-2.4700000000000002	89	1042525
0.176178000000000001	13.7899999999999991	89	1042529
1	-7.54999999999999982	89	1042517
0.983550999999999953	-5.76999999999999957	89	1042507
0.979156000000000026	-5.23000000000000043	89	1042512
0.983643000000000045	-6	89	1042504
0.998113999999999946	-4.46999999999999975	89	1042508
1	-3.0299999999999998	89	3535
1	-1.54000000000000004	89	3542
1	-4.95999999999999996	89	1042483
0.995574999999999988	-5.04000000000000004	89	1042496
0.507384999999999975	4.79000000000000004	89	1042596
0.97903399999999996	1.01000000000000001	89	1042560
0.905120999999999953	0.82999999999999996	89	1042563
0.988891999999999993	0.949999999999999956	89	1042621
0.708740000000000037	2.29999999999999982	89	1042567
0.993896000000000002	4.70999999999999996	89	1042600
0.996124000000000009	-3.04000000000000004	89	1042570
0.676970999999999989	2.58999999999999986	89	1042574
0.28759800000000002	8.34999999999999964	89	1042576
1	-1.47999999999999998	89	1042603
0.637390000000000012	-0.280000000000000027	89	1042580
0.722320999999999991	-0.0299999999999999989	89	1042584
0.846984999999999988	-1.26000000000000001	89	1042636
0.999968999999999997	1.41999999999999993	89	1042587
0.919617000000000018	-1.54000000000000004	89	1042605
0.601134999999999975	1.09000000000000008	89	1042589
0.549927000000000055	7.28000000000000025	89	1042592
0.791564999999999963	0.0599999999999999978	89	1042623
0.95877100000000004	1.79000000000000004	89	1042594
0.980530000000000013	3.14999999999999991	89	1042608
0.999847000000000041	-2.83000000000000007	89	1042610
0.900726000000000027	-0.409999999999999976	89	1042627
0.971984999999999988	1.1399999999999999	89	1042613
0.79586800000000002	-2.04000000000000004	89	1042617
1	-2.04000000000000004	89	1042642
0.415497000000000005	4.79000000000000004	89	1042638
0.925109999999999988	1.55000000000000004	89	1042629
0.999939000000000022	-3.79999999999999982	89	1042633
0.507996000000000003	5.79999999999999982	89	1042646
0.571135999999999977	1.62999999999999989	89	1042640
1	3.81999999999999984	89	1042644
0.979523000000000033	-4.58999999999999986	89	1042650
0.392699999999999994	4.17999999999999972	89	1042648
0.60690299999999997	3.5299999999999998	89	1042652
0.999968999999999997	-0.0700000000000000067	89	1042654
0.767669999999999964	3.27000000000000002	89	1042556
0.771728999999999998	1.25	89	1042547
0.999968999999999997	0.469999999999999973	89	1042552
0.975280999999999954	0.28999999999999998	89	1042668
0.999939000000000022	-4.63999999999999968	89	1042672
0.740203999999999973	3.93999999999999995	89	1042675
0.887360000000000038	-0.530000000000000027	89	1042678
0.92071499999999995	-0.130000000000000004	89	1042680
0.849731000000000014	2.72999999999999998	89	1042682
0.522460999999999953	-3.66999999999999993	89	1042684
0.79440299999999997	4.88999999999999968	89	1042656
0.976165999999999978	-1.21999999999999997	89	1042660
0.650787000000000004	1.06000000000000005	89	1042662
0.380188000000000026	3.31000000000000005	89	1042664
0.666259999999999963	-0.819999999999999951	89	1042666
0.934814000000000034	3.25	89	1042688
1	-9.25	89	1042714
0.954071000000000002	-0.330000000000000016	89	1042690
0.66522199999999998	2.14999999999999991	89	1042692
1	-7.15000000000000036	89	1042743
3.10000000000000014e-05	64.8199999999999932	89	1042696
1	-10.0999999999999996	89	1042754
1	-8.86999999999999922	89	1042716
1	-8.03999999999999915	89	1042702
1	-9.41000000000000014	89	1042704
1	-7.62999999999999989	89	1042731
0.945852000000000026	-8.08000000000000007	89	1042706
1	-8.41000000000000014	89	1042718
1	-8.42999999999999972	89	1042708
1	-7.96999999999999975	89	1042710
1	-8.84999999999999964	89	1042712
1	-7.57000000000000028	89	1042739
1	-8.33000000000000007	89	1042720
1	-8.69999999999999929	89	1042733
1	-9.75999999999999979	89	1042722
1	-7.55999999999999961	89	1042726
1	-7.80999999999999961	89	1042729
1	-7.41000000000000014	89	1042735
1	-3.85000000000000009	89	1042737
1	-8.26999999999999957	89	1042741
1	-7.16999999999999993	89	1042745
1	-7.19000000000000039	89	1042747
0.769256999999999969	-1.08000000000000007	89	1042698
0.710899999999999976	0.949999999999999956	89	1042751
0.907510999999999957	7.29000000000000004	89	1042849
1	-7.41000000000000014	89	1042810
0.512831999999999955	3.08000000000000007	89	1042826
1	-8.02999999999999936	89	1042818
1	-6.13999999999999968	89	1042792
1	-3.97999999999999998	89	1042829
1	-9.21000000000000085	89	1042796
1	-8.35999999999999943	89	1042800
0.434205000000000008	11.3100000000000005	89	1042843
1	-6.00999999999999979	89	1042822
0.90150600000000003	3.18999999999999995	89	1042833
1	-5.91000000000000014	89	1042773
0.544332999999999956	0.349999999999999978	89	1042777
0.916435	-3.81000000000000005	89	1042814
1	-8.91000000000000014	89	1042789
0.569247999999999976	3.41000000000000014	89	1042835
0.865480999999999945	-2.99000000000000021	89	1042785
1	-4.91000000000000014	89	1042769
0.644599999999999951	-0.910000000000000031	89	1042837
0.992751999999999968	-2.41999999999999993	89	1042845
0.803119000000000027	-1.43999999999999995	89	1042839
0.821570000000000022	-0.790000000000000036	89	1042841
0.846063000000000009	-1.02000000000000002	89	1042855
0.512525000000000008	2.12999999999999989	89	1042847
1	-2.47999999999999998	89	1042853
0.558663000000000021	4.70000000000000018	89	1042851
1	-9.27999999999999936	89	1042807
0.89151899999999995	-1.26000000000000001	89	1042857
0.938614999999999977	-0.92000000000000004	89	1042859
0.875948999999999978	-1.96999999999999997	89	1042861
1	-8.88000000000000078	89	1042781
1	-1.87999999999999989	89	1042863
0.331083999999999989	7.21999999999999975	89	1042865
0.870010999999999979	2.45000000000000018	89	1042887
0.731773000000000007	0.0800000000000000017	89	1042867
0.851473000000000035	1.70999999999999996	89	1042869
0.763661000000000034	1.46999999999999997	89	1042899
0.734388999999999958	-1.20999999999999996	89	1042871
0.836691999999999991	0.330000000000000016	89	1042889
0.957376000000000005	-2.2799999999999998	89	1042873
0.935142999999999947	-3.20000000000000018	89	1042875
0.905024999999999968	1.48999999999999999	89	1042877
0.810583000000000053	0.57999999999999996	89	1042891
0.669530999999999987	2.06000000000000005	89	1042879
0.979172000000000042	-5.67999999999999972	89	1042881
0.543977999999999962	3.18999999999999995	89	1042907
0.817841999999999958	-1.08000000000000007	89	1042883
0.465843000000000007	5.88999999999999968	89	1042893
0.849253000000000036	-0.910000000000000031	89	1042885
0.449137999999999982	5.11000000000000032	89	1042901
0.800018000000000007	-3.87999999999999989	89	1042895
0.463175999999999977	2.60999999999999988	89	1042897
0.778456999999999955	3.10999999999999988	89	1042903
0.812115999999999949	1.78000000000000003	89	1042911
1	-5.49000000000000021	89	1042905
0.86432500000000001	-0.130000000000000004	89	1042909
0.966976999999999975	-1.09000000000000008	89	1042913
1	-0.650000000000000022	89	1042915
0.625835999999999948	0.540000000000000036	89	1042917
0.257626000000000022	8.17999999999999972	89	1042919
0.937486000000000042	-3.95999999999999996	89	1042955
0.324284000000000017	7.25999999999999979	89	1042921
0.798216999999999954	-4.91999999999999993	89	1042943
0.578968999999999956	2.45000000000000018	89	1042923
0.581674000000000024	3.25999999999999979	89	1042925
0.842084999999999972	1.06000000000000005	89	1042927
0.933957000000000037	-0.280000000000000027	89	1042945
0.906903000000000015	-3.47999999999999998	89	1042929
0.549903999999999948	-0.689999999999999947	89	1042931
0.548039000000000054	2.06999999999999984	89	1042967
0.159289999999999987	10.5700000000000003	89	1042933
0.976651999999999965	-3.89000000000000012	89	1042947
0.764537000000000022	0.369999999999999996	89	1042935
0.68168200000000001	1.15999999999999992	89	1042937
0.168192000000000008	14.2400000000000002	89	1042957
0.837412999999999963	0.400000000000000022	89	1042939
0.529160999999999992	4.41000000000000014	89	1042949
0.932696999999999998	3.0299999999999998	89	1042941
0.711810999999999972	2.91000000000000014	89	1042951
0.891552000000000011	-0.390000000000000013	89	1042963
0.848806999999999978	-0.5	89	1042953
0.468498999999999999	5.58999999999999986	89	1042959
0.859327999999999981	0.530000000000000027	89	1042961
1	-1.04000000000000004	89	1042965
0.737138999999999989	-1.79000000000000004	89	1042971
0.86875800000000003	-0.110000000000000001	89	1042969
0.738897000000000026	-3.79999999999999982	89	1042973
0.579415000000000013	5.05999999999999961	89	1042975
0.852628000000000053	1.25	89	1042977
0.757668000000000008	-1.87000000000000011	89	1042979
0.417233000000000021	3.79999999999999982	89	1043001
0.794735999999999998	-5.5	89	1042981
0.919255000000000044	-2.74000000000000021	89	1042983
0.750021999999999966	-2.2200000000000002	89	1043029
1	-3.9700000000000002	89	1042985
1	-5.28000000000000025	89	1043003
0.997808000000000028	-3.06999999999999984	89	1042987
0.866060000000000052	-2.33000000000000007	89	1042989
0.941903000000000046	-2.37999999999999989	89	1043015
0.262031999999999987	11.1600000000000001	89	1042991
0.894136000000000042	-0.409999999999999976	89	1043005
0.763025999999999982	1.98999999999999999	89	1042993
0.98395100000000002	1.87999999999999989	89	1042995
0.525047999999999959	-1.30000000000000004	89	1042997
1	-4.19000000000000039	89	1043007
0.740819000000000005	0.23000000000000001	89	1042999
0.833126000000000033	-2.56999999999999984	89	1043023
0.593613999999999975	0.400000000000000022	89	1043017
0.876064999999999983	2.18000000000000016	89	1043009
0.522002999999999995	2.4700000000000002	89	1043011
0.644859999999999989	1.05000000000000004	89	1043013
0.545937000000000006	7.71999999999999975	89	1043019
0.782510000000000039	-0.0100000000000000002	89	1043027
0.963489999999999958	0.770000000000000018	89	1043021
0.808958999999999984	1.32000000000000006	89	1043025
0.975739000000000023	-8.83999999999999986	89	1043037
1	-3.54999999999999982	89	1043031
0.444226999999999983	5.12999999999999989	89	1043035
0.998553000000000024	0.739999999999999991	89	1043039
1	-1.8600000000000001	89	1043046
0.822037000000000018	-6.45000000000000018	89	1043048
1	-5.79999999999999982	89	1043052
0.889074999999999949	-1.64999999999999991	89	1043056
1	-10.6999999999999993	89	1043059
1	-8.94999999999999929	89	1043061
0.639866999999999964	12.7300000000000004	89	1043063
1	-8.77999999999999936	89	1043066
1	-10.0899999999999999	89	1043069
1	-8.86999999999999922	89	1043071
0.92091400000000001	-3.10999999999999988	89	1043075
0.869425000000000003	-6.12000000000000011	89	1043079
1	-6.30999999999999961	89	1043083
1	-8.49000000000000021	89	1043087
0.944640999999999953	-5.91999999999999993	89	1043091
0.82565299999999997	2.2799999999999998	89	1043133
0.994568000000000008	-6.50999999999999979	89	1043093
0.83392299999999997	-7.57000000000000028	89	1043113
0.787658999999999998	-6.84999999999999964	89	1043095
0.958556999999999992	-10.1899999999999995	89	1043097
0.947540000000000049	-2.58000000000000007	89	1043127
0.946899000000000046	-7.79999999999999982	89	1043099
0.989898999999999973	-6.48000000000000043	89	1043115
0.888977000000000017	-6.38999999999999968	89	1043101
0.771453999999999973	-7.69000000000000039	89	1043103
0.789734000000000047	-6.34999999999999964	89	1043105
0.824004999999999987	-1.97999999999999998	89	1043119
0.994568000000000008	-6.5	89	1043107
0.984496999999999955	-7.75	89	1043109
0.979949999999999988	-9.10999999999999943	89	1043111
0.745148000000000033	-0.92000000000000004	89	1043121
0.826232999999999995	-2.24000000000000021	89	1043129
0.658173000000000008	0.67000000000000004	89	1043123
0.756866000000000039	-0.450000000000000011	89	1043125
0.655608999999999997	-0.630000000000000004	89	1043139
0.493530000000000024	2.14000000000000012	89	1043131
0.771606000000000014	-1.80000000000000004	89	1043137
0.411652000000000018	2.33999999999999986	89	1043135
0.730499000000000009	-0.140000000000000013	89	1043141
0.675109999999999988	1.64999999999999991	89	1043143
0.630095999999999989	1.1399999999999999	89	1043145
0.86099199999999998	0.440000000000000002	89	1043165
0.924560999999999966	-1.60000000000000009	89	1043147
0.372954999999999981	5.32000000000000028	89	1043149
0.922027999999999959	-3.81999999999999984	89	1043190
0.648163000000000045	-2.5299999999999998	89	1043151
0.941467000000000054	-0.119999999999999996	89	1043167
0.41900599999999999	1.52000000000000002	89	1043153
0.787780999999999954	1.80000000000000004	89	1043155
0.722320999999999991	-0.0299999999999999989	89	1043174
0.415374999999999994	6.16000000000000014	89	1043157
0.60690299999999997	3.5299999999999998	89	1043168
0.869597999999999982	-1.95999999999999996	89	1043159
0.797332999999999958	0.270000000000000018	89	1043161
0.643951000000000051	1.45999999999999996	89	1043163
0.598601999999999967	-1.96999999999999997	89	1043184
0.836426000000000003	-0.200000000000000011	89	1043170
0.648681999999999981	-2.93000000000000016	89	1043178
0.770081000000000016	1.16999999999999993	89	1043172
0.971984999999999988	1.1399999999999999	89	1043173
0.748229999999999951	-3.66000000000000014	89	1043180
0.748352000000000017	-3.91999999999999993	89	1043188
0.721802000000000055	-3.35999999999999988	89	1043182
0.739044000000000034	1.5	89	1043186
0.718292000000000042	-3.91999999999999993	89	1043192
0.800567999999999946	-5.54999999999999982	89	1043194
0.774962999999999957	-4.08000000000000007	89	1043196
0.916351000000000027	-2.97999999999999998	89	1043228
0.636199999999999988	-2.31999999999999984	89	1043198
0.910950000000000037	-4.00999999999999979	89	1043200
0.941010000000000013	-0.0599999999999999978	89	1043266
0.999968999999999997	-4.33000000000000007	89	1043203
0.928069999999999951	-2.66999999999999993	89	1043231
0.999968999999999997	-2.72999999999999998	89	1043206
0.98785400000000001	-1.98999999999999999	89	1043209
0.664703000000000044	-1.67999999999999994	89	1043249
0.729279000000000011	0.82999999999999996	89	1043212
0.776580999999999966	1.18999999999999995	89	1043233
0.930510999999999977	-0.839999999999999969	89	1043214
0.643310999999999966	-2.2200000000000002	89	1043217
0.735321000000000002	-2.20999999999999996	89	1043220
0.874542000000000042	-2	89	1043236
0.997650000000000037	-3.12999999999999989	89	1043223
0.998322000000000043	-0.900000000000000022	89	1043226
0.656341999999999981	0.880000000000000004	89	1043260
0.426483000000000001	10.1300000000000008	89	1043252
0.339905000000000013	8.09999999999999964	89	1043240
0.754912999999999945	3.9700000000000002	89	1043243
0.754730000000000012	4.45000000000000018	89	1043246
0.397094999999999976	7.33000000000000007	89	1043254
0.721252000000000004	1.46999999999999997	89	1043257
0.816741999999999968	-0.209999999999999992	89	1043263
0.70877100000000004	1.62999999999999989	89	1043269
0.957825000000000037	-2.02000000000000002	89	1043272
0.432769999999999988	3.62000000000000011	89	1043275
0.744781000000000026	0.800000000000000044	89	1043277
0.402863000000000027	2.7799999999999998	89	1299431
0.703613000000000044	-0.28999999999999998	89	1043280
0.517822000000000005	4.36000000000000032	89	1043283
0.647460999999999953	0.910000000000000031	89	1043286
0.403229000000000004	7.87999999999999989	89	1043288
0.832214000000000009	-3.00999999999999979	89	1043290
0.863739000000000035	-5.66999999999999993	89	1043291
1	-9.21000000000000085	89	1042758
0.618071999999999955	1.89999999999999991	89	1299423
0.960689000000000015	-3.29000000000000004	89	1299426
1.03356300000000001	-4.66000000000000014	89	1299429
1	-6.40000000000000036	89	1042804
0.655770999999999993	-0.380000000000000004	89	1042765
0.438568000000000013	5.96999999999999975	89	1299459
1.16122299999999989	-8.58000000000000007	89	1299435
1.02606200000000003	-0.810000000000000053	89	1299439
0.772731999999999974	0.46000000000000002	89	1299442
1.0510520000000001	-2.89999999999999991	89	1299445
0.88165300000000002	-0.369999999999999996	89	1299449
0.302368000000000026	5.88999999999999968	89	1299461
0.540008999999999961	1.32000000000000006	89	1299451
0.480988000000000027	3.77000000000000002	89	1299453
0.469268999999999992	3.7200000000000002	89	1299469
0.374450999999999978	5.16000000000000014	89	1299455
0.260222999999999982	9.30000000000000071	89	1299463
0.498566000000000009	2.7799999999999998	89	1299457
0.739257999999999971	-0.369999999999999996	89	1299475
0.470459000000000016	5.98000000000000043	89	1299465
0.584412000000000043	1.55000000000000004	89	1299471
0.251923000000000008	10.6600000000000001	89	1299467
0.407013000000000014	6.5	89	1299473
0.724639999999999951	0.569999999999999951	89	1299479
0.860106999999999955	-2.37000000000000011	89	1299477
0.732238999999999973	3.52000000000000002	89	1299481
0.758422999999999958	-0.100000000000000006	89	1299483
1.14739799999999992	-10.3100000000000005	89	1299515
1.01206499999999999	-5.42999999999999972	89	1299518
0.61068699999999998	1.23999999999999999	89	1299520
1.06991799999999992	-7.87000000000000011	89	1299522
1.15979199999999993	-9.88000000000000078	89	1299524
0.378581000000000001	0.92000000000000004	89	1299526
1.16721800000000009	-7.20999999999999996	89	1299528
1.0231269999999999	-6.08999999999999986	89	1299530
1.15968500000000008	-6.04000000000000004	89	1299532
1.12720500000000001	-10.3000000000000007	89	1299534
0.945980000000000043	-3.99000000000000021	89	1299536
1.07416299999999998	-7.59999999999999964	89	1299538
1.13038700000000003	-11.6899999999999995	89	1299540
1.14336499999999996	-10.4299999999999997	89	1299542
1	-8.58000000000000007	89	1299544
1.04986500000000005	-5.13999999999999968	89	1299546
1.08770499999999992	-8.77999999999999936	89	1299548
1.02404699999999993	-4.75	89	1299550
0.980783999999999989	-5.91000000000000014	89	1299552
1.186944	-7.62999999999999989	89	1299554
0.923247999999999958	-0.82999999999999996	89	1299556
1.14234199999999997	-8.80000000000000071	89	1299558
0.987240000000000006	-7.63999999999999968	89	1299560
1	-5.71999999999999975	89	1299562
1.19054100000000007	-7	89	1299564
1	-10.2599999999999998	89	1299566
1.10765000000000002	-8.59999999999999964	89	1299568
0.966125000000000012	-1.05000000000000004	89	1299485
0.984924000000000022	-0.469999999999999973	89	1299487
0.977203000000000044	-1.39999999999999991	89	1299489
0.530608999999999997	4.33000000000000007	89	1299491
0.246338000000000001	11.0099999999999998	89	1299493
0.424835000000000018	4.71999999999999975	89	1299495
0.460876000000000008	3.70000000000000018	89	1299497
0.32974199999999998	9.09999999999999964	89	1299499
0.567107999999999945	2.62999999999999989	89	1299501
0.975463999999999998	1.1100000000000001	89	1299503
0.227051000000000003	11.8100000000000005	89	1299505
0.668640000000000012	2.64999999999999991	89	1299507
0.873473999999999973	2.58000000000000007	89	1299509
0.979369999999999963	-1.1100000000000001	89	1299511
1	-7.59999999999999964	89	1299570
0.820099000000000022	0.0599999999999999978	89	1299572
1	-9.34999999999999964	89	1299574
1	-8.26999999999999957	89	1299576
1	-4.40000000000000036	89	1299578
1	-4.70000000000000018	89	1299580
\.


--
-- Data for Name: songs; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY songs (id, title, plays, played) FROM stdin;
661	Penelope's Song	0	\N
665	Sacred Shabbat	0	\N
667	The Gates of Istanbul	0	\N
669	Beneath A Phrygian Sky	0	\N
671	Never-Ending Road (Amhrán Duit)	0	\N
673	Kecharitomene	0	\N
675	Incantation	0	\N
677	Caravanserai	0	\N
679	The English Ladye and The Knight	0	\N
681	The Highwayman	0	\N
684	Dante's Prayer	0	\N
686	The Mummers' Dance	0	\N
688	Marco Polo	0	\N
690	Skellig	0	\N
692	Night Ride Across the Caucasus	0	\N
694	Prologue	0	\N
696	La Serenissima	0	\N
698	All Souls Night	0	\N
701	The Bonny Swans	0	\N
703	Between the Shadows	0	\N
705	Santiago	0	\N
707	Cymbeline	0	\N
709	The Mystic's Dream	0	\N
711	Bonny Portmore	0	\N
713	The Lady of Shalott	0	\N
715	The Old Ways	0	\N
717	Conventry Carol	0	\N
720	Seeds of Love	0	\N
722	God Rest Ye Mern, Gentlemen	0	\N
724	Good King Wenceslas	0	\N
726	Snow	0	\N
728	Dickens' Dublin (The Palace)	0	\N
731	Moon Cradle	0	\N
733	Annachie Gordon	0	\N
735	Breaking the Silence	0	\N
737	Standing Stones	0	\N
739	Samain Night	0	\N
741	Huron 'Beltane' Fire Dance	0	\N
743	Ancient Pines	0	\N
745	Cé hé mise le ulaingt? (The ..	0	\N
748	Marrakesh Night Market	0	\N
752	The Dark Night of the Soul	0	\N
754	Prospero's Speech	0	\N
757	Full Circle	0	\N
761	The Seasons	0	\N
763	Let All That Are To Mirth Inclined	0	\N
765	In Praise Of Christmas	0	\N
767	The Wexford Carol	0	\N
769	Banquet Hall	0	\N
771	The Stockford Carol	0	\N
773	Let Us The Infant Greet	0	\N
775	Balulalow	0	\N
777	The King	0	\N
788	Tango to Evora	0	\N
792	All souls night	0	\N
795	Courtyard Lullaby	0	\N
797	Greensleeves	0	\N
801	The Lady of Shalot	0	\N
803	Lullaby	0	\N
806	Carrighfergus	0	\N
808	Come By The Hills	0	\N
810	Banks Of Claudy	0	\N
812	Kellswater	0	\N
814	Blacksmith	0	\N
816	Stolen Child	0	\N
818	She Moved Through The Fair	0	\N
820	The Lark In The Clear Air	0	\N
822	Raw Sessions	0	\N
826	After The Scoring Sessions	0	\N
828	Ooby Dooby	0	\N
831	Fully Functional (Alternate Version)	0	\N
833	All The Time (Unused Cue)	0	\N
835	Retreat (Commercial Release)	0	\N
837	End Credits (Insert)	0	\N
839	Assimilation (Second Alternate Version)	0	\N
841	First Contact (Commercial Release)	0	\N
843	Greetings (Alternate Version)	0	\N
845	39.1 Degrees Celcius (Insert)	0	\N
847	39.1 Degrees Celcius (Alternate Version)	0	\N
849	Assimilation (Alternate Version)	0	\N
851	The Dish (Commercial Release)	0	\N
853	Main Title (Different Take)	0	\N
855	First Contact (Live In Concert 6-2001)	0	\N
857	Magic Carpet Ride	0	\N
860	The Escape Pods - Into The Lion's Den	0	\N
863	The Starship Chase	0	\N
865	The Future Restored - Victory Over The Borg	0	\N
867	Starfleet Engages The Borg	0	\N
869	Bridge Argument	0	\N
871	End Credits	0	\N
873	Approaching Engineering	0	\N
875	Locutus	0	\N
877	The Gift Of Flesh	0	\N
879	First Sign Of Borg	0	\N
881	Temporal Wake	0	\N
883	Data Awakes In Engineering	0	\N
885	39.1 Degrees Celcius	0	\N
887	Watch Your Caboose, Dix	0	\N
889	Main Title	0	\N
891	Fully Functional	0	\N
893	The Dish (Film Version)	0	\N
895	A Quest For Vengeance	0	\N
897	The Enterprise E - Captain's Log	0	\N
899	Greetings	0	\N
901	Assimilation	0	\N
903	First Contact	0	\N
905	Definitely Not Swedish	0	\N
907	Evacuate	0	\N
909	Resistance Is Futile!	0	\N
911	Welcome Aboard	0	\N
913	Red Alert	0	\N
915	April 4th, 2063	0	\N
917	Retreat	0	\N
922	I Hate You	0	\N
925	The Whaler	0	\N
927	Home Again: End Credits	0	\N
929	The Probe	0	\N
931	Time Travel	0	\N
933	Chekov's Run	0	\N
935	The Yellowjackets / Market Street	0	\N
937	The Yellowjackets / Ballad of the Whale	0	\N
939	Hospital Chase	0	\N
941	Gillian Seeks Kirk	0	\N
943	Crash-Whale Fugue	0	\N
945	ST II - 01 - Main Title	0	\N
949	ST II - 05 - Khan's Pets	0	\N
951	ST II - 08 - Genesis Countdown	0	\N
953	ST II - 04 - Kirk's Explosive Reply	0	\N
955	ST II - 07 - Battle in the Mutara Nebula	0	\N
957	ST II - 03 - Spock	0	\N
959	ST II - 06 - Enterprise Clears Moorings	0	\N
961	ST II - 09 - Epilogue/End Title	0	\N
963	ST II - 02 - Surprise Attack	0	\N
965	Distress Call Alert	0	\N
970	Enterprise B Deflector Beam	0	\N
972	Out Of Control - The Crash	0	\N
974	Bird Of Prey Cloaks	0	\N
976	Jumping The Ravine	0	\N
978	Enterprise D Transporter	0	\N
980	To Live Forever	0	\N
982	Soran's Gun	0	\N
984	Prisoner Exchange	0	\N
986	Soran's Rocket De-cloaks	0	\N
988	Kirk's Death	0	\N
990	Enterprise D Warp-out #2	0	\N
992	Deck 15	0	\N
994	Bird Of Prey De-cloaks	0	\N
996	The Enterprise B - Kirk Saves The Day	0	\N
998	Enterprise B Bridge	0	\N
1000	Nexus Energy Ribbon	0	\N
1002	Outgunned	0	\N
1004	The Final Fight	0	\N
1006	Door Chime	0	\N
1008	Enterprise B Helm Controls	0	\N
1010	Enterprise D Warp Out #1	0	\N
1012	Star Trek Generations Overture	0	\N
1014	Shuttlecraft Pass-by	0	\N
1016	Two Captains	0	\N
1018	Enterprise B Warp Pass-by	0	\N
1020	Bird Of Prey Bridge - Explosion	0	\N
1022	Time Is Running Out	0	\N
1024	Coming To Rest	0	\N
1026	Tricorder	0	\N
1028	Klingon Sensor Alert	0	\N
1030	Enterprise D Bridge - Crash Sequence	0	\N
1032	Klingon Transporter	0	\N
1034	The Nexus - A Christmas Hug	0	\N
1036	Communicator Chirp	0	\N
1038	Enterprise B Doors Open	0	\N
1040	Hypo Injector	0	\N
1042	Ideals	0	\N
1045	'We Are Wasting Time'	0	\N
1047	B-4 Beams to the Scimitar	0	\N
1049	Remus	0	\N
1051	Donatra and Shinzon	0	\N
1053	Shinzon and the Senate	0	\N
1055	Repairs	0	\N
1057	The Mirror	0	\N
1059	Catching a Positron Signal	0	\N
1061	Capturing Picard	0	\N
1063	My Right Arm	0	\N
1065	The Box	0	\N
1067	Shinzon's Violation	0	\N
1069	To Romulus	0	\N
1071	Enterprise Flyover	0	\N
1073	The Argo	0	\N
1075	Odds and Ends	0	\N
1077	The Knife	0	\N
1079	The Dilithium Mines of Remus	0	\N
1081	Assembling B-4	0	\N
1084	The Senate Changes Attitude	0	\N
1087	The Thaleron Matrix	0	\N
1089	'It's Been an Honor'	0	\N
1091	Engage	0	\N
1093	A New Friend	0	\N
1095	De-Activating B-4	0	\N
1097	Team Work	0	\N
1099	Lateral Run	0	\N
1101	Riker vs. Viceroy	0	\N
1103	Remembering Data - The Enterprise	0	\N
1105	'Our True Nature'	0	\N
1107	The Battle Begins	0	\N
1109	Riker's Victory	0	\N
1111	Meeting in the Ready Room	0	\N
1113	A New Ending	0	\N
1115	Preparing for Battle	0	\N
1117	Final Flight	0	\N
1119	The Scorpion	0	\N
1121	Goodbye!	0	\N
1123	Bird of Prey Decloaks	0	\N
1126	The Search for Spock	0	\N
1128	The Mind Meld	0	\N
1130	End Title	0	\N
1132	Prologue and Main Title	0	\N
1134	The Katra Ritual	0	\N
1136	Returning to Vulcan	0	\N
1138	Stealing the Enterprise	0	\N
1140	Klingons	0	\N
1144	New Sight	0	\N
1146	Children's Story	0	\N
1148	Ba'Ku Village	0	\N
1150	No Threat	0	\N
1152	The Drones Attack	0	\N
1154	Not Functioning	0	\N
1156	In Custody	0	\N
1158	The Same Race	0	\N
1160	The Healing Process	0	\N
1162	The Riker Maneuver	0	\N
1164	Open The Gates	0	\N
1167	Well Done	0	\N
1169	Paradise Lost / Spacedock	0	\N
1171	Life Is A Dream (Film Version)	0	\N
1174	Cosmic Thoughts	0	\N
1176	Let's Get Out Of Here	0	\N
1178	No Harm	0	\N
1180	Free Minds	0	\N
1182	A Tall Ship	0	\N
1184	An Angry God	0	\N
1186	The Big Drop	0	\N
1188	Plot Course	0	\N
1190	Pain And Prophecy	0	\N
1192	A Busy Man	0	\N
1194	The Barrier	0	\N
1196	Life Is A Dream (Alternate)	0	\N
1198	Games With Life	0	\N
1200	Main Title / The Mountain	0	\N
1202	Without Help	0	\N
1204	Revealed	0	\N
1208	An Incident	0	\N
1210	Escape From Rura Penthe	0	\N
1212	Death Of Gorkon	0	\N
1214	The Battle For Peace	0	\N
1216	Overture	0	\N
1218	Star Trek VI Suite	0	\N
1220	Assassination	0	\N
1222	Surrender For Peace	0	\N
1224	Sign Off	0	\N
1226	Rura Penthe	0	\N
1228	Dining On Ashes	0	\N
1230	Clear All Moorings	0	\N
1232	06 - Vejur Flyover	0	\N
1236	02 - Leaving Drydock	0	\N
1238	03 - The Cloud	0	\N
1240	01 - Main Title / Klingon Battle	0	\N
1242	08 - Spock Walk	0	\N
1244	07 - The Meld	0	\N
1246	04 - The Enterprise	0	\N
1248	05 - Ilia's Theme	0	\N
1250	09 - End Title	0	\N
1252	Clockwork Contrivance	0	\N
1256	Unsheath'd	0	\N
1258	Dupliblaze COMAGMA	0	\N
1260	Space Prankster	0	\N
1262	Versus	0	\N
1264	Song of Life	0	\N
1266	Pumpkin Cravings	0	\N
1268	Homestuck	0	\N
1270	An Unbreakable Union	0	\N
1272	Homestuck Anthem	0	\N
1274	Welcome to the New Extreme	0	\N
1276	Valhalla	0	\N
1278	Softly	0	\N
1280	Snow Pollen	0	\N
1282	Crystalanthemums	0	\N
1284	Cathedral of the End	0	\N
1286	Medical Emergency	0	\N
1288	Doctor Remix	0	\N
1290	Sarabande	0	\N
1292	Jade's Lullaby	0	\N
1294	Light	0	\N
1297	Sunsetter	0	\N
1300	Phantasmagoric Waltz	0	\N
1302	Enlightenment	0	\N
1304	Skaian Skirmish	0	\N
1306	Skaian Ride	0	\N
1308	Greenhouse	0	\N
1310	Upholding the Law	0	\N
1312	Moonshatter	0	\N
1314	Ectobiology	0	\N
1317	Chorale for War	0	\N
1320	Octoroon Rangoon	0	\N
1323	Ruins (With Strings)	0	\N
1326	Candles and Clockwork	0	\N
1328	Biophosphoradelecrystalluminescence	0	\N
1330	Switchback	0	\N
1332	Clockwork Sorrow	0	\N
1335	Descend	0	\N
1338	Hardchorale	0	\N
1341	Vertical Motion	0	\N
1343	Skaian Flight	0	\N
1345	Amphibious Subterrain	0	\N
1347	Pyrocumulus (Kickstart)	0	\N
1349	Underworld	0	\N
1351	Plague Doctor	0	\N
1353	White	0	\N
1355	Shatterface	0	\N
1358	Bed of Rose's / Dreams of Derse	0	\N
1360	Lotus	0	\N
1365	Aggrievance	0	\N
1367	Endless Climbing	0	\N
1369	Get Up	0	\N
1371	Crystamanthequins	0	\N
1373	How Do I Live (Bunny Back in the Box Version)	0	\N
1375	Lotus Land Story	0	\N
1377	Happy Cat Song!	0	\N
1379	Skaian Skuffle	0	\N
1383	Darkened	0	\N
1386	Can Town	0	\N
1392	The Beginning of Something Really Excellent	0	\N
1394	Endless Heart	0	\N
1396	Sunslammer	0	\N
1402	Land of the Salamanders	0	\N
1410	Savior of the Waking World	0	\N
1420	Skaia (Incipisphere Mix)	0	\N
1423	Ecstasy	0	\N
1427	Clockwork Melody	0	\N
1429	Electromechanism	0	\N
1433	Heirfare	0	\N
1435	Planet Healer	0	\N
1446	Throwdown	0	\N
1459	Endless Expanse	0	\N
1462	We Walk	0	\N
1464	Carapacian Dominion	0	\N
1466	Requiem for an Exile	0	\N
1468	Years in the Future	0	\N
1470	Ruins Rising	0	\N
1472	Aimless Morning Gold	0	\N
1474	Riches to Ruins Movements I & II	0	\N
1476	Tomahawk Head	0	\N
1478	Raggy Looking Dance	0	\N
1480	Nightmare	0	\N
1482	Mayor Maynot	0	\N
1484	What a Daring Dream	0	\N
1486	Gilded Sands	0	\N
1488	Vagabounce Remix	0	\N
1490	Litrichean Rioghail	0	\N
1492	wwretched wwaltz	0	\N
1495	Spider8ite!!!!!!!!	0	\N
1497	ETERNAL SUFFERING	0	\N
1499	--Empirical	0	\N
1501	R3DGL4R3	0	\N
1503	June, Or July	0	\N
1505	twoward2 the heaven2	0	\N
1507	Valhalla (Scratched Disc Edit)	0	\N
1509	Green Sun	0	\N
1511	SUBJUGGLATION	0	\N
1513	Dishonorable Highb100d	0	\N
1515	Immaculate Peacekeeper	0	\N
1517	aN UNHOLY RITUAL,	0	\N
1519	0_0	0	\N
1521	pawnce!	0	\N
1523	Spider8ite (Thief of Lounge Mix)	0	\N
1525	Ballad of Awakening	0	\N
1528	Hardlyquin	0	\N
1530	Doctor (Original Loop)	0	\N
1532	Atomyk Ebonpyre	0	\N
1534	Carefree Victory	0	\N
1536	Endless Climb	0	\N
1538	Showtime (Original Mix)	0	\N
1540	Dissension (Original)	0	\N
1542	Ohgodwhat	0	\N
1544	Showtime Remix	0	\N
1546	Verdancy (Bassline)	0	\N
1548	Nannaquin	0	\N
1550	Chorale for Jaspers	0	\N
1552	Harlequin (Rock Version)	0	\N
1554	Three in the Morning (RJ's I Can Barely Sleep In This Casino Remix)	0	\N
1556	Gardener	0	\N
1558	Potential Verdancy	0	\N
1560	Aggrieve (Violin Refrain)	0	\N
1562	Revelawesome	0	\N
1564	Beatdown Round 2	0	\N
1566	Sburban Jungle	0	\N
1568	Black	0	\N
1570	Vagabounce	0	\N
1572	Ohgodwhat Remix	0	\N
1574	Harleboss	0	\N
1576	Explore Remix	0	\N
1578	John Sleeps / Skaian Magicant	0	\N
1580	Aggrieve Remix	0	\N
1582	Showtime (Piano Refrain)	0	\N
1584	Rediscover Fusion	0	\N
1586	Doctor	0	\N
1588	Showtime (Imp Strife Mix)	0	\N
1590	Explore	0	\N
1592	Aggrieve	0	\N
1594	Beatdown (Strider Style)	0	\N
1596	Harlequin	0	\N
1598	Skies of Skaia	0	\N
1600	Dissension (Remix)	0	\N
1602	Pony Chorale	0	\N
1604	Sburban Countdown	0	\N
1606	Upward Movement (Dave Owns)	0	\N
1610	Guardian V2	0	\N
1615	Contention	0	\N
1621	Mutiny	0	\N
1625	Knife's Edge	0	\N
1628	Make a Wish	0	\N
1630	Time on My Side	0	\N
1632	Dance of Thorns	0	\N
1634	Heir Conditioning	0	\N
1636	Stormspirit	0	\N
1638	Atomic Bonsai	0	\N
1640	Spider8reath	0	\N
1643	Havoc To Be Wrought	0	\N
1645	Earthsea Borealis	0	\N
1647	Let's All Rock the Heist	0	\N
1649	Even in Death	0	\N
1651	The Carnival	0	\N
1653	Play The Wind	0	\N
1655	Rumble at the Rink	0	\N
1657	Warhammer of Zillyhoo	0	\N
1659	Black Rose / Green Sun	0	\N
1661	Maplehoof's Adventure	0	\N
1663	WSW-Beatdown	0	\N
1665	Savior of the Dreaming Dead	0	\N
1667	Lifdoff	0	\N
1669	Terezi Owns	0	\N
1671	White Host, Green Room	0	\N
1673	At The Price of Oblivion	0	\N
1675	Awakening	0	\N
1677	Trial and Execution	0	\N
1679	Sburban Reversal	0	\N
1681	Walls Covered In Blood	0	\N
1684	Walls Covered in Blood DX (Bonus)	0	\N
1686	Spider's Claw (Bonus)	0	\N
1688	Theme (Bonus)	0	\N
1690	Phaze and Blood	0	\N
1692	The Thirteenth Hour	0	\N
1694	Keepers (Bonus)	0	\N
1696	The La2t Frontiier	0	\N
1698	psych0ruins	0	\N
1700	Staring (Bonus)	0	\N
1702	Virgin Orb	0	\N
1704	mIrAcLeS	0	\N
1706	Skaian Summoning	0	\N
1708	dESPERADO ROCKET CHAIRS,	0	\N
1710	The Lemonsnout Turnabout	0	\N
1712	Showdown	0	\N
1714	Crustacean	0	\N
1716	Death of the Lusii	0	\N
1718	Skaian Birth	0	\N
1721	Null	0	\N
1723	Song of Skaia	0	\N
1725	Chronicles	0	\N
1728	Exodus	0	\N
1730	Requiem	0	\N
1732	Eden	0	\N
1734	Revelations II	0	\N
1736	Revelations I	0	\N
1738	The Prelude	0	\N
1740	Rapture	0	\N
1742	The Meek	0	\N
1744	Genesis	0	\N
1746	Revelations III	0	\N
1748	Creation	0	\N
1750	Hallowed Halls	0	\N
1753	The Obsidian Towers	0	\N
1755	The Golden Towers	0	\N
1757	Prospit Dreamers	0	\N
1759	Core of Darkness	0	\N
1761	Darkened Streets	0	\N
1763	Derse Dreamers	0	\N
1765	Center of Brilliance	0	\N
1767	Farewell	0	\N
1770	Vigilante	0	\N
1772	Nakkadile	0	\N
1774	Vigilante ~ Cornered	0	\N
1776	Under the Hat	0	\N
1778	Ira quod Angelus	0	\N
1780	Thought and Flow	0	\N
1782	A Fashionable Escape	0	\N
1784	Clockbreaker	0	\N
1786	Land of Wrath and Angels	0	\N
1788	Jackie Treats	0	\N
1790	Growing Up	0	\N
1792	Sburban Elevator	0	\N
1794	SadoMasoPedoRoboNecroBestiality	0	\N
1796	Meltwater	0	\N
1798	Maibasojen	0	\N
1800	Cutscene at the End of the Hallway	0	\N
1802	Moody Mister Gemini	0	\N
1804	Quartz Lullaby	0	\N
1806	The Land of Wind and Shade	0	\N
1808	The Hymn of Making Babies	0	\N
1810	Joker Strife	0	\N
1812	Downtime	0	\N
1814	First Guardian, Last Stand	0	\N
1816	Starkind	0	\N
1818	Shame and Doubt	0	\N
1820	SWEET BRO AND HELLA JEFF SHOW	0	\N
1822	Dance of the Wayward Vagabond	0	\N
1824	Beginnings (Press Start to Play)	0	\N
1826	Midnight Spider	0	\N
1828	MegaloVaniaC	0	\N
1830	Emissary of Wind	0	\N
1832	Corpse Casanova	0	\N
1834	Prince of Seas	0	\N
1836	The Drawing of the Four	0	\N
1838	Ruins of Rajavihara	0	\N
1840	Atomik Meltdown	0	\N
1842	L'etat de l'ambivalence	0	\N
1844	MeGaDanceVaNia	0	\N
1846	House of Lalonde	0	\N
1848	A War of One Bullet	0	\N
1850	Growin' Up Strider	0	\N
1852	Sburban Rush	0	\N
1854	Skaian Air	0	\N
1856	Jack and Black Queen	0	\N
1858	Heir-Seer-Knight-Witch	0	\N
1860	Land of Quartz and Melody	0	\N
1862	Sunshaker	0	\N
1864	Salamander Fiesta	0	\N
1866	Sburban Piano Doctor	0	\N
1868	Doctor (Deep Breeze Mix)	0	\N
1870	Final Stand	0	\N
1872	Crystalanachrony	0	\N
1874	Let it Snow	0	\N
1877	Gog Rest Ye Merry Prospitians	0	\N
1879	Choo Choo	0	\N
1881	Carolmanthetime	0	\N
1883	Anthem of Rime	0	\N
1885	The Squiddles Save Christmas	0	\N
1887	Carefree Perigee	0	\N
1889	Hella Sweet	0	\N
1891	Shit, Let's Be Santa	0	\N
1893	Candles and Merry Gentlemen	0	\N
1895	Land of Light and Cheer	0	\N
1897	The More You Know	0	\N
1899	Billy the Bellsuit Diver Has Something to Say	0	\N
1901	A Very Special Time	0	\N
1903	Squiddly Night	0	\N
1905	Time for a Story	0	\N
1907	A Skaian Christmas	0	\N
1909	The Santa Claus Interdimensional Travel Sleigh	0	\N
1911	Candlelight	0	\N
1913	Pachelbel's Gardener	0	\N
1915	Oh, God, Christmas!	0	\N
1917	Oh, No! It's the Midnight Crew!	0	\N
1919	Midnight Calliope	0	\N
1922	Requiem Of Sunshine And Rainbows	0	\N
1924	Catapult Capuchin	0	\N
1926	FIDUSPAWN, GO!	0	\N
1928	Eridan's Theme	0	\N
1930	Rex Duodecim Angelus	0	\N
1932	Rest A While	0	\N
1934	Dreamers and The Dead	0	\N
1936	Alternia	0	\N
1938	Arisen Anew	0	\N
1940	Vriska's Theme	0	\N
1942	Darling Kanaya	0	\N
1944	The Blind Prophet	0	\N
1946	Killed by BR8K Spider!!!!!!!!	0	\N
1948	Trollcops (Radio Play)	0	\N
1950	Karkat's Theme	0	\N
1952	Trollcops	0	\N
1954	Blackest Heart (With Honks)	0	\N
1956	Terezi's Theme	0	\N
1958	Nepeta's Theme	0	\N
1960	AlterniaBound	0	\N
1962	Nautical Nightmare	0	\N
1964	Horschestra STRONG Version	0	\N
1966	She's a Sp8der	0	\N
1968	BL1ND JUST1C3: 1NV3ST1G4T1ON !!	0	\N
1970	Science Seahorse	0	\N
1972	A Fairy Battle	0	\N
1974	Trollian Standoff	0	\N
1976	You Won A Combat	0	\N
1978	Chaotic Strength	0	\N
1980	Variations	0	\N
1983	Swing of the Clock	0	\N
1985	Clockwork Reversal	0	\N
1987	Baroqueback Bowtier (Scratch's Lament)	0	\N
1989	Omelette Sandwich	0	\N
1991	Humphrey's Lullaby	0	\N
1993	Apocryphal Antithesis	0	\N
1995	The Broken Clock	0	\N
1997	Jade Dragon	0	\N
1999	Chartreuse Rewind	0	\N
2001	English	0	\N
2003	Scratch	0	\N
2005	Rhapsody in Green	0	\N
2007	Eldritch	0	\N
2009	Trails	0	\N
2011	Temporal Piano	0	\N
2013	Time Paradox	0	\N
2015	Moment of Pause	0	\N
2018	Assail	0	\N
2020	Jackknive	0	\N
2022	nsfasoft presents	0	\N
2024	Audio Commentary Featuring Robert J! Lake, Nick Smalley, Luke "GFD" Benjamins, and Erik "Jit" Scheele	0	\N
2026	Elf Shanty	0	\N
2028	Drillgorg	0	\N
2030	Fanfare	0	\N
2032	Softbit (Original GFD Please Shut the Fuckass Mix By Request Demo Version)	0	\N
2034	Jailstuck (Intro)	0	\N
2036	Retrobution	0	\N
2038	Game Over	0	\N
2040	b a w s	0	\N
2042	A Common Occurance (Every Night, To Be Exact)	0	\N
2044	Dr. Squiddle	0	\N
2046	Useful or Otherwise	0	\N
2048	Mechanic Panic	0	\N
2050	Rising Water (Oh, Shit!)	0	\N
2052	Phantom Echoes	0	\N
2054	Intestinal Fortification	0	\N
2056	Logorg	0	\N
2058	Title Screen	0	\N
2060	Bars	0	\N
2062	Confrontation	0	\N
2064	Distanced	0	\N
2066	Be the Other Guy	0	\N
2068	Console Thunder	0	\N
2070	Softbit	0	\N
2072	Is This the End?	0	\N
2074	This is the End	0	\N
2076	i told you about ladders	0	\N
2078	A Tender Moment	0	\N
2081	Frost	0	\N
2083	I Don't Want to Miss a Thing	0	\N
2085	Walk-Stab-Walk (R&E)	0	\N
2087	Phrenic Phever	0	\N
2089	Horschestra	0	\N
2091	Courser	0	\N
2093	Blackest Heart	0	\N
2095	Heir Transparent	0	\N
2097	Umbral Ultimatum	0	\N
2099	Crystalanthology	0	\N
2101	Nic Cage Song	0	\N
2103	MeGaLoVania	0	\N
2105	Boy Skylark (Brief)	0	\N
2107	Elevatorstuck	0	\N
2109	3 In The Morning (Pianokind)	0	\N
2111	Gaia Queen	0	\N
2113	Squidissension	0	\N
2115	GameBro (Original 1990 Mix)	0	\N
2117	Tribal Ebonpyre	0	\N
2119	Wacky Antics	0	\N
2131	Rediscover Fusion Remix	0	\N
2137	Sburban Jungle (Brief Mix)	0	\N
2139	Aggrieve (Violin Redux)	0	\N
2149	Wind	0	\N
2153	Heat	0	\N
2155	Frogs	0	\N
2157	Shade	0	\N
2159	Clockwork	0	\N
2162	Rain	0	\N
2164	Moonshine	0	\N
2167	Carbon Nadsat/Cuestick Genius	0	\N
2169	Lunar Eclipse	0	\N
2171	Nightlife (Extended)	0	\N
2173	Joker's Wild	0	\N
2175	Blue Noir	0	\N
2177	Knives and Ivory	0	\N
2179	Hauntjam	0	\N
2181	The Ballad of Jack Noir	0	\N
2183	Hollow Suit	0	\N
2185	Dead Shuffle	0	\N
2187	Ante Matter	0	\N
2189	Ace of Trump	0	\N
2191	Livin' It Up	0	\N
2193	Liquid Negrocity	0	\N
2195	Hearts Flush	0	\N
2197	Three in the Morning	0	\N
2199	Hauntjelly	0	\N
2201	Tall, Dark and Loathsome	0	\N
2203	Pumpkin Tide	0	\N
2206	Dawn of Man	0	\N
2208	Lies with the Sea	0	\N
2210	Chain of Prospit	0	\N
2212	No Release	0	\N
2214	Beta Version	0	\N
2216	Forever	0	\N
2218	The Deeper You Go	0	\N
2220	Fly	0	\N
2222	Lazybones	0	\N
2225	Plumbthroat Gives Chase	0	\N
2227	Squiddle March	0	\N
2229	Friendship is Paramount	0	\N
2231	Squiddle Samba	0	\N
2233	Catchyegrabber (Skipper Plumbthroat's Song)	0	\N
2235	Tentacles	0	\N
2237	Squiddles Happytime Fun Go!	0	\N
2239	Squiddle Parade	0	\N
2241	Bonus Track: Friendship Aneurysm	0	\N
2243	Mister Bowman Tells You About the Squiddles	0	\N
2245	Let the Squiddles Sleep (End Theme)	0	\N
2247	Squiddles in Paradise	0	\N
2249	Sun-Speckled Squiddly Afternoon	0	\N
2251	Squiddles!	0	\N
2253	Ocean Stars	0	\N
2255	Squiddles the Movie Trailer - The Day the Unicorns Couldn't Play	0	\N
2257	Tangled Waltz	0	\N
2259	The Sound of Pure Squid Giggles	0	\N
2261	Rainbow Valley	0	\N
2263	Squiddidle!	0	\N
2265	Squiddles Campfire	0	\N
2267	Carefree Princess Berryboo	0	\N
2271	Skaian Dreams (Remix)	0	\N
2278	Kinetic Verdancy	0	\N
2280	Guardian	0	\N
2282	Nightlife	0	\N
2285	Pyrocumulus (Sicknasty)	0	\N
2288	Flare	0	\N
2290	Do You Remem8er Me	0	\N
2292	Frog Hunt	0	\N
2294	Black Hole / Green Sun	0	\N
2296	Unite Synchronization	0	\N
2298	Calamity	0	\N
2300	The Lost Child	0	\N
2302	Airtime	0	\N
2304	Cascade	0	\N
2306	Lotus (Bloom)	0	\N
2308	Questant's Lament	0	\N
2310	Ocean Stars Falling	0	\N
2312	Frog Forager	0	\N
2314	Serenade	0	\N
2316	Hussie Hunt	0	\N
2318	How Do I Live (D8 Night Version)	0	\N
2320	I'm a Member of the Midnight Crew (Acapella)	0	\N
2322	Gust of Heir	0	\N
2324	Terraform	0	\N
2326	Carefree Action	0	\N
2328	Scourge Sisters	0	\N
2330	Bargaining with the Beast	0	\N
2332	Judgment Day	0	\N
2334	Drift into the Sun	0	\N
2336	Frostbite	0	\N
2338	Davesprite	0	\N
2340	Havoc	0	\N
2342	Escape Pod	0	\N
2344	Infinity Mechanism	0	\N
2346	Love You (Feferi's Theme)	0	\N
2348	Kingside Castle	0	\N
2350	Cascade (Beta)	0	\N
2352	Galaxy Hearts	0	\N
2354	Afraid of the Darko	0	\N
2356	Arcade Thunder	0	\N
2358	Temporary	0	\N
2360	Even in Death (T'Morra's Belly Mix)	0	\N
2362	Revered Return	0	\N
2364	null	0	\N
2366	Homefree	0	\N
2368	Galactic Cancer	0	\N
2370	Howard Shore / Amon Hen	0	\N
2374	Howard Shore / At The Sign Of The Prancing Pony	0	\N
2376	Howard Shore / Lothlorien	0	\N
2378	Howard Shore / The Shadow Of The Past	0	\N
2380	Howard Shore / Flight To The Ford	0	\N
2382	Howard Shore / The Bridge Of Khazad Dum	0	\N
2384	Enya / May It Be	0	\N
2386	Howard Shore / The Great River	0	\N
2388	Howard Shore / The Breaking Of The Fellowship	0	\N
2390	Howard Shore / A Journey In The Dark	0	\N
2392	Enya / The Council Of Elrond	0	\N
2394	Howard Shore / The Prophecy	0	\N
2396	Howard Shore / The Ring Goes South	0	\N
2398	Howard Shore / The Black Rider	0	\N
2400	Howard Shore / Many Meetings	0	\N
2402	Howard Shore / A Knife In The Dark	0	\N
2404	Howard Shore / Concerning Hobbits	0	\N
2406	Howard Shore / The Treason Of Isengard	0	\N
2408	The Fields of the Pelennor	0	\N
2411	The Ride of the Rohirrim	0	\N
2413	Cirith Ungol	0	\N
2415	Ash and Smoke	0	\N
2417	Minas Morgul	0	\N
2419	The Return of the King (feat. Sir James Galway, Viggo Mortensen & Renée Fleming)	0	\N
2421	The Black Gate Opens (feat. Sir James Galway)	0	\N
3509	2rant-furry_discrimination	0	\N
2423	Into the West (feat. Annie Lennox)	0	\N
2425	Minas Tirith (feat. Ben Del Maestro)	0	\N
2427	The End of All Things (feat. Renée Fleming)	0	\N
2429	The Grey Havens (feat. Sir James Galway)	0	\N
2431	The White Tree	0	\N
2433	Andúril	0	\N
2435	Hope and Memory	0	\N
2437	A Storm Is Coming	0	\N
2439	Shelob's Lair	0	\N
2441	Hope Fails	0	\N
2443	Twilight and Shadow (feat. Renée Fleming)	0	\N
2445	The Steward of Gondor (feat. Billy Boyd)	0	\N
2447	Farewell to Lórien (feat. Hilary Summers)	0	\N
2450	The Hornburg	0	\N
2452	The Black Gate is Closed	0	\N
2454	Evenstar (feat. Isabel Bayrakdarian)	0	\N
2456	Foundations of Stone	0	\N
2458	The Riders of Rohan	0	\N
2460	Isengard Unleashed (feat. Elizabeth Fraser & Ben Del Maestro)	0	\N
2462	The King of the Golden Hall	0	\N
2464	The Leave Taking	0	\N
2466	Samwise the Brave	0	\N
2468	The Passage of the Marshes	0	\N
2470	Breath of Life (feat. Sheila Chandra)	0	\N
2472	The White Rider	0	\N
2474	Gollum's Song (perf. by Emiliana Torrini)	0	\N
2476	Forth Eorlingas (feat. Ben del Maestro)	0	\N
2478	Helm's Deep	0	\N
2480	Treebeard	0	\N
2482	The Uruk-hai	0	\N
2484	The Taming of Sméagol	0	\N
2486	The Forbidden Pool	0	\N
2488	Jaws (Main Title) [From Jaws]	0	\N
2492	'March' from 1941 (1979)	0	\N
2495	Jurassic Park (Theme) [From Jurassic Park]	0	\N
2497	Bugler's Dream/Olympic Fanfare and Theme	0	\N
2499	'Theme' from Sugarland Express (1974)	0	\N
2501	'Main Title' from The Reviers (1969)	0	\N
2503	'Cadillac of the Skies' from Empire of the Sun (1987)	0	\N
2505	'Parade of the Slave Children' from Indiana Jones and the Temple of Doom (1984)	0	\N
2507	'Somewhere in My Memory' Main Title from Home Alone (1990)	0	\N
2509	'Flying Theme' from from E.T. the Extra-Terrestrial (1977)	0	\N
2511	'Flight to Neverland' from Hook (1991)	0	\N
2513	Star Wars (Main Title) [From Star Wars]	0	\N
2515	'Summon the Heroes' (for Tim Morrison) (1996)	0	\N
2517	'Seven Years in Tibet' from Seven Years in Tibet (1997)	0	\N
2519	'Theme' from Born on the Fourth of July (1989)	0	\N
2521	'Theme' from Far and Away (1992)	0	\N
2523	'Suite' from Close Encounters of the Third Kind (1977)	0	\N
2525	Superman (Main Title) [From Superman]	0	\N
2527	'Hymn to the Fallen' from Saving Private Ryan (1998)	0	\N
2529	Duel of the Fates [From Star Wars Episode 1]	0	\N
2531	The Raiders March [From Raiders of the Lost Ark]	0	\N
2533	'The Imperial March' from The Empire Strikes Back (1980)	0	\N
2535	'Theme' from Schindler's List (1993)	0	\N
2537	'Prologue' from JFK (1991)	0	\N
2539	'Scherzo for Motorcycle and Orchestra' from Indiana Jones and the Last Crusade (1989)	0	\N
2541	'Look Down, Lord' Reprise and Finale from Rosewood (1997)	0	\N
2543	'Luke and Leia' from Return of the Jedi (1983)	0	\N
2545	'The Days Between' from Stepmom (1998)	0	\N
2547	Cassation, K99: Allegro	0	\N
2551	Serenade, K375: Menuetto	0	\N
2554	Flute Concerto in D major, K 314: Allegro	0	\N
2557	Eine kleine Nachtmusik: Allegro	0	\N
2560	Violin Concerto, K 216: Allegro	0	\N
2563	Piano Concerto in A major, K 488: Adagio	0	\N
2566	Turkish March	0	\N
2569	Symphony No.40 in G minor: Molto allegro	0	\N
2572	Clarinet Concerto KV 622: Adagio	0	\N
2575	Divertimento, K 334: Menuetto	0	\N
2578	Horn Concerto, K 447: Allegro	0	\N
2581	The 4 Seasons: Concerto No. 3 In F major "Autumn"	0	\N
2585	The 4 Seasons: Concerto No. 2 in G minor "Summer"	0	\N
2587	The 4 Seasons: Concerto No. 1 in E major "Spring"	0	\N
2589	Concerto for 4 Violins in E minor, RV 550: Allegro assai	0	\N
2592	The 4 Seasons: Concerto No 4 in F minor "Winter"	0	\N
2594	Oboe Sonata in B flat major, RV 34 (Adagio, Allegro, Largo, Allegro)	0	\N
2597	Concerto for 2 Corni da caccia in F major, RV 539: Allegro	0	\N
2600	Siciliano	0	\N
2603	Oboe Concerto (Allegro non tasto - Largo, Allegro non molto)	0	\N
2606	Violin Concerto: Andante	0	\N
2610	The Sleeping Beauty: Ballet Suite-Pas d'action – Adagio	0	\N
2613	String Serenade: Waltz	0	\N
2616	The Sleeping Beauty: Ballet Suite-Waltz	0	\N
2618	Capriccio italien Op.45	0	\N
2621	Swan Lake: Ballet Suite-Waltz	0	\N
2623	The Sleeping Beauty: Ballet Suite-Introduction	0	\N
2625	Piano Concerto No.1: Allegro non troppo	0	\N
2628	Eugene Onegin: Polonaise	0	\N
2630	Swan Lake: Ballet Suite-Scene No.10	0	\N
2632	24 Preludes, Op. 28: No. 18 in F minor	0	\N
2636	24 Preludes, Op. 28: No. 17 in A flat major	0	\N
2638	24 Preludes, Op. 28: No. 14 in E flat minor	0	\N
2640	Four Mazurkas, Op. 24: No. 4 in B flat minor	0	\N
2643	Scherzo No. 2 in B flat minor, Op. 31	0	\N
2646	Twelve Etudes, Op. 25: No. 10 in B minor	0	\N
2649	Four Mazurkas, Op. 24: No. 3 in A flat major	0	\N
2651	Three Nocturnes, Op. 9: No. 3 in B major	0	\N
2653	Scherzo No. 1 in B minor, Op. 20	0	\N
2655	24 Preludes, Op. 28: No. 16 in B flat minor	0	\N
2657	Nocturne in C sharp minor, Op. posth.	0	\N
2659	24 Preludes, Op. 28: No. 15 in D flat major "Raindrops"	0	\N
2661	Waltz in E flat major, Op. 18	0	\N
2663	24 Preludes, Op. 28: No. 13 in F sharp major	0	\N
2665	Twelve Etudes, Op. 10: No. 5 in G flat major	0	\N
2667	„Wachet auf, ruft uns die Stimme", Chorale, BWV 645	0	\N
2671	Minuet in G major, BWV Anh. 116	0	\N
2674	„Kommst du nun, Jesu, vom Himmel herunter", Chorale, BWV 650	0	\N
2677	Easter Oratorio, BWV 249: Sinfonia	0	\N
2680	Toccata and Fugue in D minor, BWV 565	0	\N
2682	Brandenburg Concerto No.2 in F major, BWV 1047: Andante	0	\N
2685	Overture No. 2: Badinerie	0	\N
2688	Oboe Concerto in D minor: Adagio	0	\N
2690	Violin Concerto in E major, BWV 1042: Adagio	0	\N
2693	Minuet in D minor, BWV Anh. 132	0	\N
2696	„lch liebe den Höchsten von ganzem Gemüte", Cantata, BWV 174: Sinfonia	0	\N
2698	Overture No. 3: Air	0	\N
2700	Brandenburg Concerto No.1 in F major, BWV 1046: Adagio	0	\N
2702	Overture No. 4: Réjouissance	0	\N
2704	Overture No.1: Passepied	0	\N
2706	Symphony No. 6 in B minor "Unfinished": Allegro moderato	0	\N
2710	Moment musical No. 3 in F minor	0	\N
2713	Entr'acte No. 1 from "Rosamunde"	0	\N
2716	Moment musical in A flat major	0	\N
2719	Ballet Music No. 2 aus/trom "Rosamunde"	0	\N
2721	Impromptu in E flat major	0	\N
2723	Ave Maria	0	\N
2725	Entr'acte No. 2 from ''Rosamunde''	0	\N
2727	Ständchen	0	\N
2729	Trout Quintet: Tema con variazioni	0	\N
2732	Tannhäuser: Arrival of the Guests at Wartburg	0	\N
2736	Die Meistersinger von Nürnberg: Prelude Act 3	0	\N
2739	Der Fliegende Holländer: Overture	0	\N
2741	Tristan und Isolde: Prelude and Liebestod	0	\N
2743	Tannhäuser: Overture	0	\N
2745	Lohengrin: Prelude	0	\N
2747	Die Meistersinger von Nürnberg: Aufzug der Meistersinger	0	\N
2749	Die Meistersinger von Nürnberg: Dance of the Prentices	0	\N
2751	Vienna Blood	0	\N
2755	Annen Polka	0	\N
2757	Wine, Woman and Song	0	\N
2759	Die Fledermaus (Excerpts)	0	\N
2762	The Gypsy Baron: Einzugsmarsch	0	\N
2764	The Gypsy Baron: Introduction	0	\N
2766	The Blue Danube	0	\N
2768	Tritsch Tratsch Polka	0	\N
2770	Piano Concerto No.2: Adagio	0	\N
2774	”Egmont”: Overture	0	\N
2777	”Coriolan” Overture	0	\N
2780	Symphony No.8 in F major: Allegretto scherzando	0	\N
2782	Symphony No.5: Allegro con brio	0	\N
2785	ymphony No.5 in C minor: Allegro	0	\N
2787	Für Elise	0	\N
2789	”Moonlight” Sonata: Adagio sostenuto	0	\N
2791	Violin Romance No.2	0	\N
2794	Minuet	0	\N
2796	Nabucco: Overture	0	\N
2800	Il Trovatore: Vedi! le fosche notturne (Gypsies' Chorus)	0	\N
2803	Nabucco: Va pensiero, sull'ali dorate	0	\N
2805	Aida: Prelude	0	\N
2807	La Traviata: Di Madride noi siam mattadori	0	\N
2809	La Traviata: Libiamo ne' lieti calici	0	\N
2811	La Traviata: Noi siamo zingarelle	0	\N
2813	Aroldo: Overture	0	\N
2815	La Traviata: Prelude	0	\N
2817	Il Trovatore: Or co' daddi, ma fra poco (Soldiers' Chorus)	0	\N
2819	La Forza del destino: Overture	0	\N
2821	black sun (live in Warsaw 31.03.2005)	0	\N
2825	cresent (live in Warsaw 31.03.2005)	0	\N
2827	how fortunate the man with none (live in Warsaw 31.03.2005)	0	\N
2829	sanvean (live in Warsaw 31.03.2005)	0	\N
2831	saltarello (live in Warsaw 31.03.2005)	0	\N
2833	severance (live in Warsaw 31.03.2005)	0	\N
2835	hymn for the fallen (live in Warsaw 31.03.2005)	0	\N
2837	standing ovation (live in Warsaw 31.03.2005)	0	\N
2839	american dreaming (live in Warsaw 31.03.2005)	0	\N
2841	saffron (live in Warsaw 31.03.2005)	0	\N
2843	lotus eaters (live in Warsaw 31.03.2005)	0	\N
2845	standing ovation II (live in Warsaw 31.03.2005)	0	\N
2847	the ubiquitous mr. lovegrove (live in Warsaw 31.03.2005)	0	\N
2849	rakim (live in Warsaw 31.03.2005)	0	\N
2851	the love that cannot be (live in Warsaw 31.03.2005)	0	\N
2853	minus sanctus (live in Warsaw 31.03.2005)	0	\N
2855	intro (applause) (live in Warsaw 31.03.2005)	0	\N
2857	salems lot - aria (live in Warsaw 31.03.2005)	0	\N
2859	yamyinar (live in Warsaw 31.03.2005)	0	\N
2861	i can see now (live in Warsaw 31.03.2005)	0	\N
2863	yulunga (live in Warsaw 31.03.2005)	0	\N
2865	dreams made flash (live in Warsaw 31.03.2005)	0	\N
2867	nierika (live in Warsaw 31.03.2005)	0	\N
2869	the wind that shakes the barley (live in Warsaw 31.03.2005)	0	\N
2871	Avatar	0	\N
2875	Bird	0	\N
2877	Carnival Of Light	0	\N
2879	In The Kingdom Of The Blind The One Eyed Are Kings	0	\N
2881	Orion	0	\N
2883	The Protagonist	0	\N
2885	Summoning Of The Muse	0	\N
2887	De Profundis (Out Of The Depths Of Sorrow)	0	\N
2889	Anywhere Out Of The World	0	\N
2891	Windfall	0	\N
2893	Ocean	0	\N
2895	Threshold	0	\N
2897	Labour Of Love	0	\N
2899	Frontier	0	\N
2901	In Power We Entrust The Love Advocated	0	\N
2903	Cantara	0	\N
2905	Enigma Of The Absolute	0	\N
2907	How Fortunate The Man With None	0	\N
2910	Severance	0	\N
2912	Sloth	0	\N
2914	The Ubiquitous Mr. Lovegrove	0	\N
2916	The Host Of Seraphim	0	\N
2918	Song Of Sophia	0	\N
2920	The Promised Womb	0	\N
2922	The Arrival & The Reunion	0	\N
2924	The Wind That Shakes The Barley	0	\N
2926	The Spider's Stratagem	0	\N
2928	Spirit	0	\N
2930	Bylar	0	\N
2932	The Carnival Is Over	0	\N
2934	Yulunga	0	\N
2936	The Song Of The Sibyl	0	\N
2938	Black Sun	0	\N
2940	Saltarello	0	\N
2942	Tristan	0	\N
2945	The Snake & The Moon	0	\N
2947	Gloridean	0	\N
2949	I Can See Now	0	\N
2951	Nierika	0	\N
2953	The Lotus Eaters	0	\N
2955	Sambatiki	0	\N
2957	Rakim	0	\N
2959	American Dreaming	0	\N
2961	Don't Fade Away	0	\N
2963	Sanvean	0	\N
2965	Indus	0	\N
2967	Song Of The Nile	0	\N
2969	Fortune Presents Gifts Not According to the Book	0	\N
2972	In the Kingdom of the Blind the One-Eyed Are Kings	0	\N
2974	The Host of Seraphim	0	\N
2976	The Wrtiting On My Father's Hand	0	\N
2979	Anywhere Out of the World	0	\N
2982	Wilderness	0	\N
2984	The Song of the Sibyl	0	\N
2986	Enigma of the Absolute	0	\N
2989	Song of Sophia	0	\N
2994	The Garden of Zephirus	0	\N
2996	Ullyses	0	\N
2998	I Must Have Been Blind	0	\N
3002	The Captive Heart	0	\N
3006	Archangel	0	\N
3008	Death Will Be My Bride	0	\N
3010	Saturday's Child	0	\N
3012	Medusa	0	\N
3014	Voyage of Bran	0	\N
3018	The Arcane	0	\N
3021	In Power We Trust The Love Advocated	0	\N
3023	A Passage in Time	0	\N
3025	Musica Eternal	0	\N
3027	The Fatal Impact	0	\N
3029	Fortune	0	\N
3031	The Trial	0	\N
3034	Wild in the Woods	0	\N
3037	East of Eden	0	\N
3039	Flowers Of The Sea	0	\N
3043	Mother Tongue	0	\N
3046	Echolalia	0	\N
3050	The Writing on My Father's Hand	0	\N
3052	Orbis de Ignis	0	\N
3054	Chant of the Paladin	0	\N
3057	Black sun	0	\N
3063	Anywhere out of the world	0	\N
3065	Summoning of the muse	0	\N
3068	Frontier (demo)	0	\N
3070	In the kingdom of the blind the one-eyed are kings	0	\N
3072	Enigma of the absolute	0	\N
3074	In power we entrust the love advocated	0	\N
3077	The host of Seraphim	0	\N
3079	Carnival of light	0	\N
3083	Song of the Nile	0	\N
3085	The spider's stratagem	0	\N
3087	The carnival is over	0	\N
3089	The ubiquitous mr. Lovegrove	0	\N
3092	American dreaming	0	\N
3094	I can see now	0	\N
3098	The lotus eaters	0	\N
3100	How fortunate the man with none	0	\N
3102	Yulunga [Spirit Dance]	0	\N
3106	Oman	0	\N
3109	Song of the Sibyl	0	\N
3111	Desert Song	0	\N
3116	I Am Stretched on Your Grave	0	\N
3118	Persian Love Song	0	\N
3121	Piece for Solo Flute	0	\N
3124	The Wind That Shakes the Barley	0	\N
3126	In the Wake of Adversity	0	\N
3129	Dawn of the Iconoclast	0	\N
3136	Persephone (The Gathering Of Flowers)	0	\N
3138	Xavier	0	\N
3142	Mephisto	0	\N
3144	The End of Words	0	\N
3146	The Arrival and the Reunion	0	\N
3152	Radharc	0	\N
3154	As the Bell Rings the Maypole Spins	0	\N
3158	The Human Game	0	\N
3162	Forest Veil	0	\N
3164	Nadir (Synchronicity)	0	\N
3166	The Circulation Of Shadows	0	\N
3169	Tempest	0	\N
3171	The Circulation of Shadows	0	\N
3173	Pilgrimage of Lost Children	0	\N
3175	Shadow Magnet	0	\N
3177	The Unfolding	0	\N
3179	Duality	0	\N
3181	Majhnavea's Music Box	0	\N
3184	Violina: The Last Embrace	0	\N
3186	La Bas: Song of the Drowned	0	\N
3188	Glorafin	0	\N
3190	Sanvean: I Am Your Shadow	0	\N
3192	Lisa Gerrard - The Mirror Pool - 17 - Bonus track	0	\N
3194	Largo	0	\N
3196	Swans	0	\N
3198	Celon	0	\N
3200	Werd	0	\N
3202	Ajhon	0	\N
3204	Gloradin	0	\N
3206	Laurelei	0	\N
3208	Venteles	0	\N
3210	The Rite	0	\N
3212	Nilleshna	0	\N
3214	Persian Love Song: The Silver Gun	0	\N
3216	 06. Lisa Gerrard & Patrick Cassidy - Abwoon (Our Father)	0	\N
3218	 04. Lisa Gerrard & Patrick Cassidy - Elegy	0	\N
3220	 10. Lisa Gerrard & Patrick Cassidy - Psallit in Aure Dei	0	\N
3222	 03. Lisa Gerrard & Patrick Cassidy - Amergin's Invocation	0	\N
3224	 02. Lisa Gerrard & Patrick Cassidy - Maranatha (Come Lord)	0	\N
3226	 07. Lisa Gerrard & Patrick Cassidy - Immortal Memory	0	\N
3228	 05. Lisa Gerrard & Patrick Cassidy - Sailing to Byzantium	0	\N
3230	 09. Lisa Gerrard & Patrick Cassidy - I Asked for Love	0	\N
3232	 01. Lisa Gerrard & Patrick Cassidy - The Song of Amergin	0	\N
3234	 08. Lisa Gerrard & Patrick Cassidy - Paradise Lost	0	\N
3236	Pasadena	0	\N
3240	Badnamgar	0	\N
3242	Tears Of Light	0	\N
3244	Wisdom	0	\N
3246	Slow River	0	\N
3248	The Absence Of Time	0	\N
3250	Devota	0	\N
3252	Vespers	0	\N
3254	Womb	0	\N
3256	Slow Dawn	0	\N
3258	Elephant Pond	0	\N
3260	Mater Mea	0	\N
3262	A Thousand Roads	0	\N
3266	All your Relatives	0	\N
3268	Song of the Trees	0	\N
3270	The Northern Lights	0	\N
3272	Dawn Across the Snow	0	\N
3274	Who Are We to Say	0	\N
3276	Who are We to Say (vocal)	0	\N
3278	A Healer's Life	0	\N
3280	Walk in a Beauty's Way	0	\N
3282	Johnny in the Dark	0	\N
3284	All My Relations	0	\N
3286	Coming to Barrow	0	\N
3288	Crazy Horse	0	\N
3290	Canyons of Manhattan	0	\N
3292	Mahk Jchi	0	\N
3294	Nemi	0	\N
3296	End Titles	0	\N
3298	Good Morning Indian Country	0	\N
3300	Rowing Warriors	0	\N
3302	Shaman's Call	0	\N
3304	Pai Calls the Whales	0	\N
3307	Go Forward	0	\N
3309	Pai Theme	0	\N
3311	Journey Away	0	\N
3313	Suitcase	0	\N
3315	Reiputa	0	\N
3317	Ancestors	0	\N
3319	Paikea Legend	0	\N
3321	Biking Home	0	\N
3323	They Came To Die	0	\N
3325	Rejection	0	\N
3327	Empty Water	0	\N
3329	Disappointed	0	\N
3331	Waka in the Sky	0	\N
3333	Paikeas Whale	0	\N
3335	Lisa Gerrard, Pieter Bourke / Meltdown	0	\N
3338	Lisa Gerrard, Pieter Bourke / Broken	0	\N
3340	Massive Attack / Safe from Harm - Perfecto Mix	0	\N
3342	Graeme Revell / Palladino Montage	0	\N
3344	Lisa Gerrard, Pieter Bourke / The Subordinate	0	\N
3346	Gustavo Santaolalla / Iguazu	0	\N
3348	Lisa Gerrard, Pieter Bourke / Dawn of the Truth	0	\N
3350	Lisa Gerrard, Pieter Bourke / Sacrifice	0	\N
3352	Lisa Gerrard, Pieter Bourke / Exile	0	\N
3354	Jan Garbarek / Rites - Special Edit for the Film	0	\N
3356	Graeme Revell / LB in Montana	0	\N
3358	Lisa Gerrard, Pieter Bourke / Faith	0	\N
3360	Lisa Gerrard, Pieter Bourke / The Silencer	0	\N
3362	Lisa Gerrard, Pieter Bourke / Tempest	0	\N
3364	Graeme Revell / I'm Alone on This	0	\N
3366	Lisa Gerrard, Pieter Bourke / Liquid Moon	0	\N
3368	To Zucchabar	0	\N
3372	Barbarian Horde	0	\N
3374	The Battle	0	\N
3376	The Emperor Is Dead	0	\N
3378	Elysium	0	\N
3380	Patricide	0	\N
3382	Honor Him	0	\N
3384	Progeny	0	\N
3386	Slaves To Rome	0	\N
3388	Strength And Honor	0	\N
3390	Am I Not Merciful?	0	\N
3392	The Might Of Rome	0	\N
3394	Now We Are Free	0	\N
3396	The Wheat	0	\N
3398	Earth	0	\N
3400	Reunion	0	\N
3402	Sorrow	0	\N
3404	De Profundis [Out of the Depths of Sorrow]	0	\N
3408	The Cardinal Sin	0	\N
3410	Ascension	0	\N
3412	Mesmerism	0	\N
3415	Circunradiant Dawn	0	\N
3418	Advent	0	\N
3420	Indoctrination (A Design for Living)	0	\N
3424	The Snake and the Moon	0	\N
3426	Devorzhum	0	\N
3428	Song of the Stars	0	\N
3430	Song of the Dispossessed	0	\N
3432	Dedicacé Dutò	0	\N
3436	The Ubiquitous Mr Lovegrove	0	\N
3444	Minus Sanctus	0	\N
3446	The Love That Cannot Be	0	\N
3448	Yamyinar	0	\N
3450	Saffron	0	\N
3452	Crescent	0	\N
3456	Salems Lot	0	\N
3461	Dreams Made Flesh	0	\N
3463	Hymn For The Fallen	0	\N
3467	I Can See You	0	\N
3469	How Fortunate the Man With None	0	\N
3472	Saldek	0	\N
3474	Tell Me About the Forest (You Once Called Home)	0	\N
3478	Emmeleia	0	\N
3482	Ariadne	0	\N
3484	Towards the Within	0	\N
3487	20111125hifi	0	\N
3489	20111124hifi	0	\N
3491	20120903hifi	0	\N
3493	20101230FSRNhifi	0	\N
3495	20110704hifi	0	\N
3497	20101224FSRNhifi	0	\N
3499	20101231FSRN-hifi	0	\N
3501	20101227FSRNhifi	0	\N
3503	20120704_hifi	0	\N
3505	0_MEMORIALDAY_final	0	\N
3507	2rant-safe_sex	0	\N
3511	2rant-prayer	0	\N
3513	2rant-military	0	\N
3515	2rant-overboard	0	\N
3517	2rant-badbehavior	0	\N
3519	2rant-aging	0	\N
3521	2rant-christmas	0	\N
3523	2rant-apathy	0	\N
3525	2rant-religion	0	\N
3527	2rant-animal_spirits	0	\N
3529	Idolatry for Beginners	0	\N
3533	Through A Pikachu's Eyes	0	\N
3536	Simple Plan - Me Against The World	0	\N
3538	Joy Comes In The Morning	0	\N
1042441	BL1ND JUST1C3 : 1NV3ST1G4T1ON !!	0	\N
1042455	Toy box - Miss Papaya - Supergirl	0	\N
1042457	Rose_of_May_FF9_-_lyrics_by_katethegreat19-bNHtbw4Kyf0	0	\N
1042459	惑いて来たれ、遊惰な神隠し　～ Border of Death	0	\N
1042463	AOAO (beggar and king mix)	0	\N
1042466	Ben Bernanke	0	\N
1042469	Knife Fight	0	\N
1042472	SegaSonictheHedgehogSonicElectronic	0	\N
1042516	pendulum_through_the_loop	0	\N
1042518	Concierto in Sib Maggiore	0	\N
1042522	5.Symphony No.1 in E Minor,Op.1-Largo assai-Allegro	0	\N
1042526	La Damnation de Faust, Op. 24 - Ballet des sylphes	0	\N
1042530	The Firebird - Introduction	0	\N
1042534	Violin Concerto # 3 In B Minor, Op 61- Allegro Non Troppo	0	\N
1042537	Rodeo: Buckaroo Holiday	0	\N
1042540	Spartacus / Varitaion of Aegina and Bacchanal	0	\N
1042544	Symphony No. 5 in C sharp minor: Part I, I: Trauermarsch. In gemessenem Schritt. Streng. Wie ein Kondukt	0	\N
1042548	Gayaneh / Sabre Dance	0	\N
1042550	This is Professor Pete	0	\N
1042553	Symphony No.4 in A minor, op.63 - I. Tempo molto moderato, quasi adagio	0	\N
1042557	Mit durchaus ernstem und feierlichem Ausdruck	0	\N
1042561	Symphony # 3 In C Minor, Op 78 <Organ> - 1.1. Adagio - Allegro Moderato	0	\N
1042564	Symphony No. 2 in D Major, Op. 43 - I. Allegretto	0	\N
1042568	Daphnis et Chloe, Suite No. 2: Lever du jour	0	\N
1042571	Sinfonia Antartica (Symphony No.7) First Movement: Prelude	0	\N
1042575	Four Folk Song Upsettings: Introduction	0	\N
1042577	Peer Gynt: Suite No. 1, Op. 46	0	\N
1042581	Op. 46, No. 1 in C Major (Bohemian Furiant, Presto)	0	\N
1042585	Langsam, schleppend / Im Anfang sehr gemaechlich	0	\N
1042588	WTWP Station ID	0	\N
1042590	Ravel - Rapsodie espagnole: 1. Prélude à la nuit	0	\N
1042593	Piano Concerto # 2 - Andante Sostenuto	0	\N
1042595	The Short-Tempered Clavier: Introduction	0	\N
1042597	Mahler Symphony No.2 in C minor "Resurrection" - III. In ruhig fliessender bewegung	0	\N
1042601	The Planets, Op. 32: Mars, the Bringer of War	0	\N
1042604	Masquerade / Waltz	0	\N
1042606	1.Antar,Op.9 Symphonic Suite (Symphony No.2)-Largo-Allegro giocoso	0	\N
1042609	Symphonie fantastique, Op. 14 - I. Rêveries - Passions	0	\N
1042611	The Bartered Bride; Polka (Act I, Scene 5)	0	\N
1042614	Prologue (Tonio)	0	\N
1042618	Lemminkäinen Suite, Op.22 - I. Lemminkäinen and the maiden of the island	0	\N
1042622	5.Symphony No.3 in C Major,Op.32-Moderato assai	0	\N
1042624	Symphony No. 7, Op.70 / 1-Allegro maestoso	0	\N
1042628	Piano Concerto # 4 In C Minor, Op 44, 1. Allegro Moderato	0	\N
1042630	O Fortuna	0	\N
1042634	Symphony No. 9 in E minor, Op. 95 / 1-Adagio-Allegro molto	0	\N
1042637	Two Elegiac Melodies, Op. 56 No. 3	0	\N
1042639	Symphonic Variations, Op. 78 / Theme	0	\N
1042641	Minuet Militaire: Introduction	0	\N
1042643	Love Me: Introduction	0	\N
1042645	Rapsodie espagnole: Prélude à la Nuit	0	\N
1042647	Grand Serenade For An Awful Lot of Winds & Percussion: Introduction	0	\N
1042649	1.Scheherazade,Op.35-The Sea and Sindbad's Ship	0	\N
1042651	Op. 72, No. 2 in E Minor (Polish Mazurka, Allegro grazioso)	0	\N
1042653	The Song of the Nightingale (Symphonic Poem) - Introduction	0	\N
1042655	Classical Rap: Introduction	0	\N
1042657	Symphony No. 5 in E flat major, Op. 82 / 1. Tempo molto moderato	0	\N
1042661	Carnival Of The Animals - Introduction & March Of The Lion	0	\N
1042663	The Musical Sacrifice: Introduction	0	\N
1042665	Ravel - Daphnis et Chloé: Part one - Introduction	0	\N
1042667	Symphony No.5 in E flat major, op.82 - I. Tempo molto moderato - Largamente - Tempo molto moderato - Allegro moderato	0	\N
1042669	Also sprach Zarathustra: Einleitung	0	\N
1042673	Hovhaness Symphony No.2 'Mysterious Mountain' - 1. Andante con moto	0	\N
1042676	Symphony No. 3 - I. Allegro moderato	0	\N
1042679	Symphony No. 8, Op.88 / 1-Allegro con brio	0	\N
1042681	Symphony No. 6 - I. Allegro molto moderato	0	\N
1042683	Walt_Disney_s_Robin_Hood_Whistle_Stop-OzFYb7_ySbU	0	\N
1042685	Symphony No. 3, Op. 36 "Symphony of Sorrowful Songs": III. Lento: Cantabile semplice	0	\N
1042689	Symphony No. 3, Op. 36 "Symphony of Sorrowful Songs": I. Lento: Sostenuto tranquillo ma cantabile	0	\N
1042691	Symphony No. 3, Op. 36 "Symphony of Sorrowful Songs": II. Lento e largo: Tranquillissimo - Cantabilissimo - Dolcissimo - Legatissimo	0	\N
1042693	Hidden Track One Audio	0	\N
1042697	Secret_of_Mana_Opening_Theme-T6YAiLHXw_c	0	\N
1042699	My Girls	0	\N
1042703	Lion In A Coma	0	\N
1042705	No More Runnin	0	\N
1042707	Daily Routine	0	\N
1042709	Guys Eyes	0	\N
1042711	Taste	0	\N
1042713	Also Frightened	0	\N
1042715	Brother Sport	0	\N
1042717	Bluish	0	\N
1042719	In The Flowers	0	\N
1042721	Summertime Clothes	0	\N
1042723	No Dice	0	\N
1042727	La Llorona	0	\N
1042730	Venice	0	\N
1042732	My Wife	0	\N
1042734	On A Bayonet	0	\N
1042736	El Zocalo	0	\N
1042738	My Wife, Lost in the Wild	0	\N
1042740	The Akara	0	\N
1042742	The Concubine	0	\N
1042744	My Night with the Prostitute From Marseille	0	\N
1042746	The Shrew	0	\N
1042748	Aisling Song	0	\N
1042752	Me Against The World	0	\N
1042755	Unwritten	0	\N
1042759	Run With Us	0	\N
1042763	Luna's Boat Song (Japanese)	0	\N
1042766	Unbleeped Keep Your Jesus off my Penis	0	\N
1042770	The Adventure	0	\N
1042774	I'm Moogle	0	\N
1042778	Wishmaster	0	\N
1042782	Imagine	0	\N
1042786	Imaginary	0	\N
1042790	You Are Loved	0	\N
1042793	Spaceman	0	\N
1042797	Everything You Know Is Wrong	0	\N
1042801	Move Your Dead Bones	0	\N
1042805	Feuer frei	0	\N
1042808	Jigglypuff Dance Remix	0	\N
1042811	Schala's Theme	0	\N
1042815	Around The World (Radio Edit)	0	\N
1042819	A Stray Child	0	\N
1042823	Paul Robeson - Dvorak Carnegie	0	\N
1042827	Port Rhombus	0	\N
1042830	027. Georges Bizet - Les Pêcheurs De Perles - Au Fond Du Temple Saint	0	\N
1042834	083. Johann Sebastian Bach - Wachet Auf, Ruft Uns Die Stimme (BWV 140)	0	\N
1042836	087. Ennio Morricone - C'era Una Volta Il West (Once Upon A Time In The West)	0	\N
1042838	056. Johann Sebastian Bach - Jesu, Der Du Meine Seele (BWV 78) - Wir Eilen Mit Schwachen	0	\N
1042840	040. Giuseppe Fortunino Francesco Verdi - Aida - Marcia Trionfale	0	\N
1042842	072. Pyotr Ilyich Tchaikovsky - The Nutcracker (Op. 71) - Dance Of The Sugar-Plum Fairy - –©–µ–ª–∫—É–Ω—á–∏–∫	0	\N
1042844	016. Ludwig van Beethoven - Symphony No. 9 (Op. 125)	0	\N
1042846	063. Wolfgang Amadeus Mozart - Exsultate, Jubilate (K. 165)	0	\N
1042848	003. Ludwig van Beethoven - Piano Concerto No. 5 (Op. 73) - Adagio Un Poco Mosso	0	\N
1042850	073. Johann Sebastian Bach - Doppelkonzert F√ºr Zwei Violinen (BWV 1043) - Largo Ma Non Tanto	0	\N
1042852	022. Giulio Caccini - Ave Maria	0	\N
1042854	011. Johann Sebastian Bach - Matthäus Passion (BWV 244) - Kommt, Ihr Töchter	0	\N
1042856	038. Max Christian Friedrich Bruch - Violinkonzert Nr. 1 (Op. 26) - Allegro Moderato	0	\N
1042858	080. Joaqu√≠n Rodrigo Vidre - Concierto De Aranjuez - Adagio	0	\N
1042860	089. Georg Friederich H√§ndel - Solomon (HWV 67) - The Arrival Of The Queen Of Sheba	0	\N
1042862	091. Johann Strauss, Jr. - An Der Sch√∂nen Blauen Donau (Op. 314)	0	\N
1042864	010. Tomaso Giovanni Albinoni - Adagio In Sol Minore	0	\N
1042866	059. Gregorio Allegri - Miserere (Psalm 51)	0	\N
1042868	008. Antonín Dvořák - New World Symphony (Op. 95) - Largo	0	\N
1042870	046. Wolfgang Amadeus Mozart - Vesperae De Dominica (K. 321) - Laudate Dominum	0	\N
1042872	066. Aafje Heynis - Dank Sei Dir, Herr	0	\N
1042874	075. Georges Bizet - Carmen - Habanera	0	\N
1042876	009. Sergej Vassiljevitsj Rachmaninoff - Piano Concerto No. 2 (Op. 18) - Adagio Sostenuto	0	\N
1042878	004. Wolfgang Amadeus Mozart - Klarinettenkonzert (K. 622) - Adagio	0	\N
1042880	100. C√©sar-Auguste-Jean-Guillaume-Hubert Franck - Panis Angelicus	0	\N
1042882	026. Johann Sebastian Bach - Weihnachtsoratorium (BWV 248) - Jauchzet, Frohlocket	0	\N
1042884	054. Wolfgang Amadeus Mozart - Symphony No. 40 (K. 550) - Molto Allegro	0	\N
1042886	051. Fr√©d√©ric Fran√ßois Chopin - Concerto Pour Piano No. 1 (Op. 11) - Romance	0	\N
1042888	085. Christoph Willibald Ritter von Gluck - Orfeo Ed Euridice - Dance Of The Blessed Spirits	0	\N
1042890	092. Wolfgang Amadeus Mozart - Klarinettenkonzert (K. 622) - Rondo	0	\N
1042892	058. Ludwig van Beethoven - Mondscheinsonate (Op. 27)	0	\N
1042894	071. Giuseppe Fortunino Francesco Verdi - Rigoletto - La Donna √à Mobile	0	\N
1042896	037. Johann Sebastian Bach - Orchestersuite Nr. 2 (BWV 1067) - Badinerie	0	\N
1042898	002. Johann Sebastian Bach - Matthäus Passion (BWV 244) - Erbarme Dich	0	\N
1042900	088. Wolfgang Amadeus Mozart - 23. Klavierkonzert (K. 488) - Adagio	0	\N
1042902	061. Pyotr Ilyich Tchaikovsky - The Nutcracker (Op. 71) - Waltz Of The Flowers - –©–µ–ª–∫—É–Ω—á–∏–∫	0	\N
1042904	067. Jules √âmile Fr√©d√©ric Massenet - Tha√_s - M√©ditation	0	\N
1042906	052. Gabriel Urbain Faur√© - Requiem (Op. 48) - Pie Jesu	0	\N
1042908	079. Gabriel Urbain Faur√© - Requiem (Op. 48) - In Paradisum	0	\N
1042910	076. Pyotr Ilyich Tchaikovsky - Piano Concerto No. 1 (Op. 23) - Allegro Non Troppo E Molto Maestoso	0	\N
1042912	042. Ludwig van Beethoven - Symphony No. 6 (Op. 68)	0	\N
1042914	097. Aram Ilich Khachaturian - Spartacus - Adagio Of Spartacus And Phrygia	0	\N
1042916	034. Wolfgang Amadeus Mozart - Eine Kleine Nachtmusik (K. 525)	0	\N
1042918	018. Samuel Osborne Barber - Adagio For Strings	0	\N
1042920	068. Wolfgang Amadeus Mozart - Piano Concerto No. 21 (K. 467)	0	\N
1042922	041. Giovanni Battista Pergolesi - Stabat Mater	0	\N
1042924	028. Giuseppe Fortunino Francesco Verdi - Nabucco - Va, Pensiero	0	\N
1042926	086. Wolfgang Amadeus Mozart - Konzert F√ºr Fl√∂te, Harfe Und Orchester (K. 299) - Allegro	0	\N
1042928	070. Wolfgang Amadeus Mozart - Requiem (K. 626) - Kyrie Eleison	0	\N
1042930	096. Wolfgang Amadeus Mozart - Le Nozze Di Figaro (K. 492) - Voi, Che Sapete Che Cosa E Amor	0	\N
1042932	033. Charles-François Gounod - Ave Maria	0	\N
1042934	029. Maurice Ravel - Boléro	0	\N
1042936	023. Wolfgang Amadeus Mozart - Ave Verum Corpus (K. 618)	0	\N
1042938	013. Ludwig van Beethoven - Symphony No. 7 (Op. 92)	0	\N
1042940	057. Anton√≠n Dvo≈ô√°k - Rusalka - Mƒõs√≠ƒçku Na Nebi Hlubok√©m	0	\N
1042942	062. Vincenzo Salvatore Carmelo Francesco Bellini - Norma - Casta Diva	0	\N
1042944	021. Carl Orff - Carmina Burana - O Fortuna	0	\N
1042946	031. Johann Sebastian Bach - Toccata E Fuga (BWV 565)	0	\N
1042948	020. Wolfgang Amadeus Mozart - Die Zauberflöte (K. 620) - Der Vogelfänger Bin Ich Ja	0	\N
1042950	078. Niccol√≤ Paganini - Concerto Pour Violon No. 1 (Op. 6)	0	\N
1042952	093. Jean Sibelius - Finlandia (Op. 26)	0	\N
1042954	060. Wolfgang Amadeus Mozart - Requiem (K. 626) - Dies Irae	0	\N
1042956	035. Ludwig van Beethoven - Für Elise (WoO 59)	0	\N
1042958	065. Fr√©d√©ric Fran√ßois Chopin - Concerto Pour Piano No. 2 (Op. 21)	0	\N
1042960	024. Bedřich Smetana - Má Vlast - Vltava	0	\N
1042962	017. Johann Sebastian Bach - Jesus Bleibet Meine Freude (BWV 147)	0	\N
1042964	044. George Gershwin - Rhapsody In Blue	0	\N
1042966	Orfeo Ed Euridice - Che Farò Senza Euridice?	0	\N
1042968	050. Ludwig van Beethoven - Symphony No. 5 (Op. 67)	0	\N
1042970	039. Wolfgang Amadeus Mozart - Requiem (K. 626) - Introitus	0	\N
1042972	036. Wolfgang Amadeus Mozart - Die Zauberflöte (K. 620) - Der Hölle Rache Kocht In Meinem Herzen	0	\N
1042974	015. Gustav Mahler - Symphony No. 5	0	\N
1042976	048. Ludwig van Beethoven - Piano Concerto No. 5 (Op. 73) - Rondo	0	\N
1042978	081. Pietro Mascagni - Cavalleria Rusticana - Intermezzo	0	\N
1042980	077. Giacomo Antonio Domenico Michele Secondo Maria Puccini - Turandot - Nessun Dorma	0	\N
1042982	090. Wolfgang Amadeus Mozart - Requiem (K. 626) - Domine Jesu Christe	0	\N
1042984	005. Antonio Lucio Vivaldi - Le Quattro Stagioni (Op. 8, RV 269) - La Primavera	0	\N
1042986	001. Wolfgang Amadeus Mozart - Requiem (K. 626) - Lacrimosa	0	\N
1042988	098. Max Christian Friedrich Bruch - Violinkonzert Nr. 1 (Op. 26) - Adagio	0	\N
1042990	095. Erik Alfred Leslie Satie - Gymnop√©die No.1	0	\N
1042992	053. Sergei Sergeyevich Prokofiev - Romeo And Juliet Suite No. 2 (Op. 64b) - The Montagues And Capulets	0	\N
1042994	043. Georg Friederich Händel - Messiah (HWV 56) - For Unto Us A Child Is Born	0	\N
1042996	084. Giuseppe Fortunino Francesco Verdi - La Traviata - Libiamo Ne' Lieti Calici	0	\N
1042998	047. Georg Friederich Händel - Wassermusik (HWV 348-350)	0	\N
1043000	074. Georg Friederich H√§ndel - Serse (HWV 40) - Ombra Mai F√π	0	\N
1043002	055. Sergej Vassiljevitsj Rachmaninoff - Piano Concerto No. 2 (Op. 18) - Moderato	0	\N
1043004	049. Antonio Lucio Vivaldi - Le Quattro Stagioni (Op. 8, RV 293) - l'Autunno	0	\N
1043006	032. Clément Philibert Léo Delibes - Lakmé - Duo Des Fleurs	0	\N
1043008	030. Gabriel Urbain Fauré - Cantique De Jean Racine (Op. 11)	0	\N
1043010	006. Johann Pachelbel - Kanon In D	0	\N
1043012	025. Pyotr Ilyich Tchaikovsky - Swan Lake (Op. 20) - Лебединое Озеро	0	\N
1043014	069. Johann Sebastian Bach - Brandenburgisches Konzert Nr. 1 (BWV 1046) - Allegro	0	\N
1043016	099. Wolfgang Amadeus Mozart - 23. Klavierkonzert (K. 488) - Allegro	0	\N
1043018	019. Johann Sebastian Bach - Orchestersuite Nr. 3 (BWV 1068) - Air	0	\N
1043020	045. Charles Camille Saint-Saëns - Danse Macabre	0	\N
1043022	094. Wolfgang Amadeus Mozart - Kr√∂nungsmesse (K. 317) - Agnus Dei	0	\N
1043024	007. Johann Sebastian Bach - Matthäus Passion (BWV 244) - Wir Setzen Uns Mit Tränen Nieder	0	\N
1043026	014. Edvard Hagerup Grieg - Peer Gynt Suite No. 1 (Op. 46) - Morgenstemning	0	\N
1043028	012. Georg Friederich Händel - Messiah (HWV 56) - Hallelujah	0	\N
1043030	082. Wolfgang Amadeus Mozart - Die Zauberfl√∂te (K. 620) - Overture	0	\N
1043032	Pinky and the Brain	0	\N
1043036	Symphony_of_Science-The_Poetry_of_RealityFLAC	0	\N
1043038	Brahms: Variations on a Theme of Haydn, op. 56a	0	\N
1043040	Refrain	0	\N
1043043	Pollyanna (I believe in you)	0	\N
1043047	8d38d2fd1f0cc6024134db92f1887116	0	\N
1043049	Track 10	0	\N
1043053	I Have A Dream	0	\N
1043057	RIAA Phone Call	0	\N
1043060	Water Rabbit	0	\N
1043062	28283_acclivity_UnderTreeInRain	0	\N
1043064	Jiffypop	0	\N
1043067	(Murray Mix)	0	\N
1043070	akaranorabureta_	0	\N
1043072	Nanda Ka na	0	\N
1043076	Beer Vs Pot	0	\N
1043080	Beat Is Coming [T.Z. Remix]	0	\N
1043084	Omen	0	\N
1043088	Away with Ye	0	\N
1043092	Ril Mhor	0	\N
1043094	The Hunter's Purse	0	\N
1043096	Cherish the Ladies	0	\N
1043098	Carolan's Concerto	0	\N
1043100	Brian Boru March	0	\N
1043102	Drowsy Maggie	0	\N
1043104	Donall Og	0	\N
1043106	Kerry Slides	0	\N
1043108	Round the House and Mind the Dresser	0	\N
1043110	Callaghan's; Byrne's	0	\N
1043112	Ceol Bhriotanach	0	\N
1043114	An Mhaighdean Mhara	0	\N
1043116	Tristan And Isolde - Escape And Chase	0	\N
1043120	Treasure Island - Setting Sail	0	\N
1043122	Treasure Island - Island Theme	0	\N
1043124	Treasure Island - Treasure Cave	0	\N
1043126	Treasure Island - Blind Pew	0	\N
1043128	Treasure Island - The Hispanola / Silver And Loyals March	0	\N
1043130	Tristan And Isolde - The Departure	0	\N
1043132	The Year Of The French - Cooper's Tune / The Bolero	0	\N
1043134	Barry Lyndon - Love Theme	0	\N
1043136	Treasure Island - Loyals March	0	\N
1043138	Treasure Island - Opening Theme	0	\N
1043140	Three Wishes For Jamie - The Matchmaking	0	\N
1043142	Tristan And Isolde - March Of The King Of Cornwall	0	\N
1043144	Three Wishes For Jamie - Love Theme	0	\N
1043146	The Year Of The French - The French March	0	\N
1043148	Tristan And Isolde - Love Theme	0	\N
1043150	Three Wishes For Jamie - Mountain Fall / Main Theme	0	\N
1043152	Tristan And Isolde - The Falcon	0	\N
1043154	The Grey Fox - Main Theme	0	\N
1043156	Treasure Island - French Leave	0	\N
1043158	The Year Of The French - Closing Theme & March	0	\N
1043160	Op. 72, No. 7 in C Major (Serbian Kolo, Allegro vivace)	0	\N
1043162	The Bartered Bride; Dance of the Comedians (Act III, Scene 2)	0	\N
1043164	The Moldau	0	\N
1043166	Carnival Overture, Op. 92	0	\N
1043169	The Bartered Bride; Furiant (Act II, Scene 1)	0	\N
1043171	Op. 46, No. 2 in A-Flat Minor (Bohemian Polka, Poco Allegro)	0	\N
1043175	Come un bel dì di maggio - Giordano	0	\N
1043179	Io l'ho perduta! - Verdi	0	\N
1043181	Cielo e mar - Ponchielli	0	\N
1043183	Ah! sì, ben mio - Verdi	0	\N
1043185	Niun mi tema - Verdi	0	\N
1043187	Vesti la giubba - Leoncavallo	0	\N
1043189	M'appari - Flotow	0	\N
1043191	E la solita storia - Cilea	0	\N
1043193	No, Pagliaccio non son! - Leoncavallo	0	\N
1043195	Un dì all'azzurro spazio - Giordano	0	\N
1043197	Recondita armonia - Puccini	0	\N
1043199	Dio! mi potevi scagliar - Verdi	0	\N
1043201	Light of the Spirit	0	\N
1043204	Day One	0	\N
1043207	Watermark	0	\N
1043210	Antarctic Echoes	0	\N
1043213	Theme from Antarctica	0	\N
1043215	Into Forever	0	\N
1043218	Field of Tears	0	\N
1043221	Song for Antarctica	0	\N
1043224	Pura Vida	0	\N
1043227	Secret Vows	0	\N
1043229	Anthem	0	\N
1043234	Polar Flight	0	\N
1043237	Mozart	0	\N
1043241	Tosti	0	\N
1043244	Schwanengesang, D.957, Schubert	0	\N
1043247	Gounod, Bach	0	\N
1043250	Winterreise, D. 911, Schubert	0	\N
1043255	Werner	0	\N
1043258	Denza	0	\N
1043261	Schubert	0	\N
1043264	si Capua	0	\N
1043267	de Curtis	0	\N
1043270	Messiah, Handel	0	\N
1043273	Mendelssohn	0	\N
1043278	Cantata Bach	0	\N
1043281	Brahms	0	\N
1043284	Cardillo	0	\N
1043289	La fille aux cheveux de lin	0	\N
1299424	Who Will Love Me Now?	0	\N
1299427	Rain in the Backyard	0	\N
1299430	StingDesertRoseRadioVersion	0	\N
1299432	Country Roads	0	\N
1299436	The Ivory Tower	0	\N
1299440	π	0	\N
1299443	Windows Noises	0	\N
1299446	Brandenburg Concerto No. 1 in F major, BWV 1046 Adagio	0	\N
1299450	Brandenburg Concerto No. 2 in F major, BWV 1047 Allegro Assai	0	\N
1299452	Brandenburg Copncerto No. 3 in G Major, BWV 1048 Allegro	0	\N
1299454	Christmas Oratorio, BWV 248 Sinfonia	0	\N
1299456	Concerto in C minor for Violin and Oboe, BWV 1060 Adagio	0	\N
1299458	Double Concerto in D minor, BWV 1043 Largo ma non Tanto	0	\N
1299460	Goldberg Variations, BWV 988 Aria	0	\N
1299462	Jesu Joy of Man's Desiring, BWV 147	0	\N
1299464	Nun komm, der Heiden Heiland, BWV 659	0	\N
1299466	Piano Concerto No. 5 in F minor, BWV 1056 Largo	0	\N
1299468	Sonata No. 3 in C major for Solo Violin, BWV 1005 Largo	0	\N
1299470	Suite No. 2 in B minor, BWV 1067 Badinerie	0	\N
1299472	Suite No. 3 in D major, BWV 1068 Air	0	\N
1299474	Suite No. 4 in D major, BWV 1069 Rejouissance	0	\N
1299476	Toccata and Fugue in D minor, BWV 565 Toccata	0	\N
1299478	Violin Concerto in A minor, BWV 1041 Allegro Assai	0	\N
1299480	Violin Concerto No. 2 in E major, BWV 1042 Adagio	0	\N
1299482	Wachet auf, Cantata, BWV 140 No 1	0	\N
1299484	01 overture to Cublai gran kan de Tartari in D majjor	0	\N
1299486	02 Twenty six Variations on La Folia de Spagna	0	\N
1299488	03 Overture to Angolina ossia Il matrimonio per sussuro in D major	0	\N
1299490	04 allegro assai Sinfonia Veneziana in D major	0	\N
1299492	05 andantino grazioso Sinfonia Veneziana in D major	0	\N
1299494	06 presto Sinfonia Veneziana in D major	0	\N
1299496	07 allegro assai Overture to La locandiera in D major	0	\N
1299498	08 andantino Overture to La locandiera in D major	0	\N
1299500	09 presto Overture to La locandiera in D major	0	\N
1299502	10 allegro quasi presto Sinfonia Il giorno onamastico in D major	0	\N
1299504	11 larghetto Sinfonia Il giorno onamastico in D major	0	\N
1299506	12 menuetto trio Sinfonia Il giorno onamastico in D major	0	\N
1299508	13 allegretto e sempre Sinfonia Il giorno onamastico in D major	0	\N
1299510	14 Overture to Falstaff ossia Le tre burle in D major	0	\N
1299512	Chrono_Trigger_-_Corridors_of_Time_Piano_Violin_Trio_feat_Lara_Amaterasu-kGjfRhBXwzw	0	\N
1299514	PSY_-_GANGNAM_STYLE_(강남스타일)_M_V-9bZkp7q19f0	0	\N
1299516	Corridors of Time Piano Violin Trio	0	\N
1299519	Eric_Whitacre_s_Virtual_Choir_-_Lux_Aurumque-D7o7BrlbaDs	0	\N
1299521	Heaven's_light_(ANIMATIC)-NL_99jYTV5I	0	\N
1299523	Alice_Manikin_Sacrifice-l5Vg9zNGGrA	0	\N
1299525	Fluttershy_gets﻿_BEEBEEPED_in_the_maze-AH_ulLbQr0Y	0	\N
1299527	[PMV]_-_The_Garden-MAVQk8CSU9w	0	\N
1299529	PinkiePieSwear_-_Luna,_Please_Fill_My_Empty_Sky-uZ_7xq1TIW4	0	\N
1299531	PinkiePieSwear_-_Trixie_s_Good_Side-TFWpr_wkgV8	0	\N
1299533	Nightmare_Night_-_[WoodenToaster___Mic_The_Microphone]-9PCEp8z7FNg	0	\N
1299535	Epic_Final_Bosses_of_Equestria__Mystic_Fury_-_Twilight_Sparkle-71A-Lv9vghA	0	\N
1299537	Dash's_Determination-mC7Bl8BkKTw	0	\N
1299539	PMV_-_Pony_Polka_Face-video_VI-P_wP2Oj2Z5I	0	\N
1299541	APPLEBLOOM-JH8eRff9DCs	0	\N
1299543	Eurobeat_Brony_-_Discord_The_Living_Tombstone_Remix_Music_Video-9QZMjFC_RgY	0	\N
1299545	The_Moon_Rises-kPjVCIX5Fvs	0	\N
1299547	Green_And_Purple_[PMV]-9w6Wa0W2y_o	0	\N
1299549	Children_of_the_Night_(Animatic)-6-3wp2VVhKQ	0	\N
1299551	Magic_is_Free_-_MC_Fluttershy_[Kimi]-fggzApOmGgU	0	\N
1299553	ieavan_s_Polka_for_Headbucket_in_E_Minor_aka_YOUR_FACE-mn0Q2XlXRs0	0	\N
1299555	Super_Ponybeat_-_Luna_(DREAM_MODE)-bn7uMwXYU9U	0	\N
1299557	Want_It,_Need_It_(Hold_Me)-E20jsywkLaY	0	\N
1299559	Got_My_Party_Cannon_(Scootaloo_Chicken's_Theme)_[PMV]-9NN6hQeLfyA	0	\N
1299561	UnderpΩny_-_A_Different_Kind_of_Spark-Ga32VpsRuVE	0	\N
1299563	Want_It_Need_It-HsGPsqFEFXE	0	\N
1299565	PinkiePieSwear_-_Giggle_at_the_Ghostly_Simple_Joy_Mix-ZQYqPo4NDXQ	0	\N
1299567	PinkiePieSwear_-_Sunshine_and_Celery_Stalks-cP0f5rvVkAU	0	\N
1299569	Pornophonique_Sad_Robot_High_Quality-u7Dg3LrhmIY	0	\N
1299571	Richard_Wagner_Ride_Of_The_Valkyries-GGU1P6lBW6Q	0	\N
1299573	R_Kelly_I_Believe_I_Can_Fly-16FdJrrAWSo	0	\N
1299575	Tomorrow_annie_Lyrics-5PzL8aL6jtI	0	\N
1299577	Once_Upon_a_Time_in_Animation-f2Nwp4IuJl0	0	\N
1299579	Aerith_s_Theme_original_lyrics_by_katethegreat19-1-as6Kbcj4c	0	\N
1299581	Banana_Phone-1L65Ek5aKWQ	0	\N
1299583	Beverly_Hills_Cop_Theme_Song-IG8EdbrSVtc	0	\N
1299585	Calculus_Rhapsody-uqwC41RDPyg	0	\N
1299587	DJ_Earworm_United_State_of_Pop_2009_Blame_It_on_the_Pop_Mashup_of_Top_25_Billboard_Hits-iNzrwh2Z2hQ	0	\N
1299589	Electric_Cello-dH9fh-T9qHU	0	\N
1299591	Eric_Whitacre_s_Virtual_Choir_Lux_Aurumque-D7o7BrlbaDs	0	\N
1937825	Fischer_Dieskau_Sings_Mahler_Ging_heut_Morgen_bers_Feld-tKtRombx5DM	0	\N
1938574	Foxy_Shazam_Unstoppable_Video-OFt3OqmGSbI	0	\N
1939166	Franz_Schubert_Ellens_Gesang_Nr_3_Ave_Maria-mVMmIJiqSJc	0	\N
1940702	Gregorian_Chant_Dies_Irae-Dlr90NLDp-0	0	\N
1942903	Hanson_MMMBop-NHozn0YXAeE	0	\N
1944393	Hermes_House_Band_Country_Roads_Remix-AmMtCGs5wAc	0	\N
1945723	HyadainRapdeChocoboEnglishSubtitles	0	\N
1946803	www.BooM4u.info By V.a.L.e.R.i	0	\N
1949642	Mt_Eden_Dubstep_HD_Sierra_Leone-iy2TOdvr8QY	0	\N
1951335	Nagual_Sound_Experiment_Frontier-yJWp083Pv3Y	0	\N
1953524	Origa_I_am_Taken_Away-h75-C-pMZ5M	0	\N
1958523	Quick_from_Rockman2_Megaman2-AXgoMsRg4SI	0	\N
1960550	Robot_Unicorn_Attack_Song_HD_Erasure_Always-FUaKxFjlOpw	0	\N
1965964	SNES_Secret_of_Mana_In_the_beginning-SnsJI4rmoVE	0	\N
1973735	You_re_Not_Alone_fan_vocal_version-qmbgCBZ86z4	0	\N
7408501	YouAreAPirateLazyTown	0	\N
\.


--
-- Data for Name: things; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY things (id, description) FROM stdin;
661	\N
662	\N
663	\N
664	\N
665	\N
666	\N
667	\N
668	\N
669	\N
670	\N
671	\N
672	\N
673	\N
674	\N
675	\N
676	\N
677	\N
678	\N
679	\N
680	\N
681	\N
682	\N
683	\N
684	\N
685	\N
686	\N
687	\N
688	\N
689	\N
690	\N
691	\N
692	\N
693	\N
694	\N
695	\N
696	\N
697	\N
698	\N
699	\N
700	\N
701	\N
702	\N
703	\N
704	\N
705	\N
706	\N
707	\N
708	\N
709	\N
710	\N
711	\N
712	\N
713	\N
714	\N
715	\N
716	\N
717	\N
718	\N
719	\N
720	\N
721	\N
722	\N
723	\N
724	\N
725	\N
726	\N
727	\N
728	\N
729	\N
730	\N
731	\N
732	\N
733	\N
734	\N
735	\N
736	\N
737	\N
738	\N
739	\N
740	\N
741	\N
742	\N
743	\N
744	\N
745	\N
746	\N
747	\N
748	\N
749	\N
750	\N
751	\N
752	\N
753	\N
754	\N
755	\N
756	\N
757	\N
758	\N
759	\N
760	\N
761	\N
762	\N
763	\N
764	\N
765	\N
766	\N
767	\N
768	\N
769	\N
770	\N
771	\N
772	\N
773	\N
774	\N
775	\N
776	\N
777	\N
778	\N
779	\N
780	\N
781	\N
782	\N
783	\N
784	\N
785	\N
786	\N
787	\N
788	\N
789	\N
790	\N
791	\N
792	\N
793	\N
794	\N
795	\N
796	\N
797	\N
798	\N
799	\N
800	\N
801	\N
802	\N
803	\N
804	\N
805	\N
806	\N
807	\N
808	\N
809	\N
810	\N
811	\N
812	\N
813	\N
814	\N
815	\N
816	\N
817	\N
818	\N
819	\N
820	\N
821	\N
822	\N
823	\N
824	\N
825	\N
826	\N
827	\N
828	\N
829	\N
830	\N
831	\N
832	\N
833	\N
834	\N
835	\N
836	\N
837	\N
838	\N
839	\N
840	\N
841	\N
842	\N
843	\N
844	\N
845	\N
846	\N
847	\N
848	\N
849	\N
850	\N
851	\N
852	\N
853	\N
854	\N
855	\N
856	\N
857	\N
858	\N
859	\N
860	\N
861	\N
862	\N
863	\N
864	\N
865	\N
866	\N
867	\N
868	\N
869	\N
870	\N
871	\N
872	\N
873	\N
874	\N
875	\N
876	\N
877	\N
878	\N
879	\N
880	\N
881	\N
882	\N
883	\N
884	\N
885	\N
886	\N
887	\N
888	\N
889	\N
890	\N
891	\N
892	\N
893	\N
894	\N
895	\N
896	\N
897	\N
898	\N
899	\N
900	\N
901	\N
902	\N
903	\N
904	\N
905	\N
906	\N
907	\N
908	\N
909	\N
910	\N
911	\N
912	\N
913	\N
914	\N
915	\N
916	\N
917	\N
918	\N
919	\N
920	\N
921	\N
922	\N
923	\N
924	\N
925	\N
926	\N
927	\N
928	\N
929	\N
930	\N
931	\N
932	\N
933	\N
934	\N
935	\N
936	\N
937	\N
938	\N
939	\N
940	\N
941	\N
942	\N
943	\N
944	\N
945	\N
946	\N
947	\N
948	\N
949	\N
950	\N
951	\N
952	\N
953	\N
954	\N
955	\N
956	\N
957	\N
958	\N
959	\N
960	\N
961	\N
962	\N
963	\N
964	\N
965	\N
966	\N
967	\N
968	\N
969	\N
970	\N
971	\N
972	\N
973	\N
974	\N
975	\N
976	\N
977	\N
978	\N
979	\N
980	\N
981	\N
982	\N
983	\N
984	\N
985	\N
986	\N
987	\N
988	\N
989	\N
990	\N
991	\N
992	\N
993	\N
994	\N
995	\N
996	\N
997	\N
998	\N
999	\N
1000	\N
1001	\N
1002	\N
1003	\N
1004	\N
1005	\N
1006	\N
1007	\N
1008	\N
1009	\N
1010	\N
1011	\N
1012	\N
1013	\N
1014	\N
1015	\N
1016	\N
1017	\N
1018	\N
1019	\N
1020	\N
1021	\N
1022	\N
1023	\N
1024	\N
1025	\N
1026	\N
1027	\N
1028	\N
1029	\N
1030	\N
1031	\N
1032	\N
1033	\N
1034	\N
1035	\N
1036	\N
1037	\N
1038	\N
1039	\N
1040	\N
1041	\N
1042	\N
1043	\N
1044	\N
1045	\N
1046	\N
1047	\N
1048	\N
1049	\N
1050	\N
1051	\N
1052	\N
1053	\N
1054	\N
1055	\N
1056	\N
1057	\N
1058	\N
1059	\N
1060	\N
1061	\N
1062	\N
1063	\N
1064	\N
1065	\N
1066	\N
1067	\N
1068	\N
1069	\N
1070	\N
1071	\N
1072	\N
1073	\N
1074	\N
1075	\N
1076	\N
1077	\N
1078	\N
1079	\N
1080	\N
1081	\N
1082	\N
1083	\N
1084	\N
1085	\N
1086	\N
1087	\N
1088	\N
1089	\N
1090	\N
1091	\N
1092	\N
1093	\N
1094	\N
1095	\N
1096	\N
1097	\N
1098	\N
1099	\N
1100	\N
1101	\N
1102	\N
1103	\N
1104	\N
1105	\N
1106	\N
1107	\N
1108	\N
1109	\N
1110	\N
1111	\N
1112	\N
1113	\N
1114	\N
1115	\N
1116	\N
1117	\N
1118	\N
1119	\N
1120	\N
1121	\N
1122	\N
1123	\N
1124	\N
1125	\N
1126	\N
1127	\N
1128	\N
1129	\N
1130	\N
1131	\N
1132	\N
1133	\N
1134	\N
1135	\N
1136	\N
1137	\N
1138	\N
1139	\N
1140	\N
1141	\N
1142	\N
1143	\N
1144	\N
1145	\N
1146	\N
1147	\N
1148	\N
1149	\N
1150	\N
1151	\N
1152	\N
1153	\N
1154	\N
1155	\N
1156	\N
1157	\N
1158	\N
1159	\N
1160	\N
1161	\N
1162	\N
1163	\N
1164	\N
1165	\N
1166	\N
1167	\N
1168	\N
1169	\N
1170	\N
1171	\N
1172	\N
1173	\N
1174	\N
1175	\N
1176	\N
1177	\N
1178	\N
1179	\N
1180	\N
1181	\N
1182	\N
1183	\N
1184	\N
1185	\N
1186	\N
1187	\N
1188	\N
1189	\N
1190	\N
1191	\N
1192	\N
1193	\N
1194	\N
1195	\N
1196	\N
1197	\N
1198	\N
1199	\N
1200	\N
1201	\N
1202	\N
1203	\N
1204	\N
1205	\N
1206	\N
1207	\N
1208	\N
1209	\N
1210	\N
1211	\N
1212	\N
1213	\N
1214	\N
1215	\N
1216	\N
1217	\N
1218	\N
1219	\N
1220	\N
1221	\N
1222	\N
1223	\N
1224	\N
1225	\N
1226	\N
1227	\N
1228	\N
1229	\N
1230	\N
1231	\N
1232	\N
1233	\N
1234	\N
1235	\N
1236	\N
1237	\N
1238	\N
1239	\N
1240	\N
1241	\N
1242	\N
1243	\N
1244	\N
1245	\N
1246	\N
1247	\N
1248	\N
1249	\N
1250	\N
1251	\N
1252	\N
1253	\N
1254	\N
1255	\N
1256	\N
1257	\N
1258	\N
1259	\N
1260	\N
1261	\N
1262	\N
1263	\N
1264	\N
1265	\N
1266	\N
1267	\N
1268	\N
1269	\N
1270	\N
1271	\N
1272	\N
1273	\N
1274	\N
1275	\N
1276	\N
1277	\N
1278	\N
1279	\N
1280	\N
1281	\N
1282	\N
1283	\N
1284	\N
1285	\N
1286	\N
1287	\N
1288	\N
1289	\N
1290	\N
1291	\N
1292	\N
1293	\N
1294	\N
1295	\N
1296	\N
1297	\N
1298	\N
1299	\N
1300	\N
1301	\N
1302	\N
1303	\N
1304	\N
1305	\N
1306	\N
1307	\N
1308	\N
1309	\N
1310	\N
1311	\N
1312	\N
1313	\N
1314	\N
1315	\N
1316	\N
1317	\N
1318	\N
1319	\N
1320	\N
1321	\N
1322	\N
1323	\N
1324	\N
1325	\N
1326	\N
1327	\N
1328	\N
1329	\N
1330	\N
1331	\N
1332	\N
1333	\N
1334	\N
1335	\N
1336	\N
1337	\N
1338	\N
1339	\N
1340	\N
1341	\N
1342	\N
1343	\N
1344	\N
1345	\N
1346	\N
1347	\N
1348	\N
1349	\N
1350	\N
1351	\N
1352	\N
1353	\N
1354	\N
1355	\N
1356	\N
1357	\N
1358	\N
1359	\N
1360	\N
1361	\N
1362	\N
1363	\N
1364	\N
1365	\N
1366	\N
1367	\N
1368	\N
1369	\N
1370	\N
1371	\N
1372	\N
1373	\N
1374	\N
1375	\N
1376	\N
1377	\N
1378	\N
1379	\N
1380	\N
1381	\N
1382	\N
1383	\N
1384	\N
1385	\N
1386	\N
1387	\N
1388	\N
1389	\N
1390	\N
1391	\N
1392	\N
1393	\N
1394	\N
1395	\N
1396	\N
1397	\N
1398	\N
1399	\N
1400	\N
1401	\N
1402	\N
1403	\N
1404	\N
1405	\N
1406	\N
1407	\N
1408	\N
1409	\N
1410	\N
1411	\N
1412	\N
1413	\N
1414	\N
1415	\N
1416	\N
1417	\N
1418	\N
1419	\N
1420	\N
1421	\N
1422	\N
1423	\N
1424	\N
1425	\N
1426	\N
1427	\N
1428	\N
1429	\N
1430	\N
1431	\N
1432	\N
1433	\N
1434	\N
1435	\N
1436	\N
1437	\N
1438	\N
1439	\N
1440	\N
1441	\N
1442	\N
1443	\N
1444	\N
1445	\N
1446	\N
1447	\N
1448	\N
1449	\N
1450	\N
1451	\N
1452	\N
1453	\N
1454	\N
1455	\N
1456	\N
1457	\N
1458	\N
1459	\N
1460	\N
1461	\N
1462	\N
1463	\N
1464	\N
1465	\N
1466	\N
1467	\N
1468	\N
1469	\N
1470	\N
1471	\N
1472	\N
1473	\N
1474	\N
1475	\N
1476	\N
1477	\N
1478	\N
1479	\N
1480	\N
1481	\N
1482	\N
1483	\N
1484	\N
1485	\N
1486	\N
1487	\N
1488	\N
1489	\N
1490	\N
1491	\N
1492	\N
1493	\N
1494	\N
1495	\N
1496	\N
1497	\N
1498	\N
1499	\N
1500	\N
1501	\N
1502	\N
1503	\N
1504	\N
1505	\N
1506	\N
1507	\N
1508	\N
1509	\N
1510	\N
1511	\N
1512	\N
1513	\N
1514	\N
1515	\N
1516	\N
1517	\N
1518	\N
1519	\N
1520	\N
1521	\N
1522	\N
1523	\N
1524	\N
1525	\N
1526	\N
1527	\N
1528	\N
1529	\N
1530	\N
1531	\N
1532	\N
1533	\N
1534	\N
1535	\N
1536	\N
1537	\N
1538	\N
1539	\N
1540	\N
1541	\N
1542	\N
1543	\N
1544	\N
1545	\N
1546	\N
1547	\N
1548	\N
1549	\N
1550	\N
1551	\N
1552	\N
1553	\N
1554	\N
1555	\N
1556	\N
1557	\N
1558	\N
1559	\N
1560	\N
1561	\N
1562	\N
1563	\N
1564	\N
1565	\N
1566	\N
1567	\N
1568	\N
1569	\N
1570	\N
1571	\N
1572	\N
1573	\N
1574	\N
1575	\N
1576	\N
1577	\N
1578	\N
1579	\N
1580	\N
1581	\N
1582	\N
1583	\N
1584	\N
1585	\N
1586	\N
1587	\N
1588	\N
1589	\N
1590	\N
1591	\N
1592	\N
1593	\N
1594	\N
1595	\N
1596	\N
1597	\N
1598	\N
1599	\N
1600	\N
1601	\N
1602	\N
1603	\N
1604	\N
1605	\N
1606	\N
1607	\N
1608	\N
1609	\N
1610	\N
1611	\N
1612	\N
1613	\N
1614	\N
1615	\N
1616	\N
1617	\N
1618	\N
1619	\N
1620	\N
1621	\N
1622	\N
1623	\N
1624	\N
1625	\N
1626	\N
1627	\N
1628	\N
1629	\N
1630	\N
1631	\N
1632	\N
1633	\N
1634	\N
1635	\N
1636	\N
1637	\N
1638	\N
1639	\N
1640	\N
1641	\N
1642	\N
1643	\N
1644	\N
1645	\N
1646	\N
1647	\N
1648	\N
1649	\N
1650	\N
1651	\N
1652	\N
1653	\N
1654	\N
1655	\N
1656	\N
1657	\N
1658	\N
1659	\N
1660	\N
1661	\N
1662	\N
1663	\N
1664	\N
1665	\N
1666	\N
1667	\N
1668	\N
1669	\N
1670	\N
1671	\N
1672	\N
1673	\N
1674	\N
1675	\N
1676	\N
1677	\N
1678	\N
1679	\N
1680	\N
1681	\N
1682	\N
1683	\N
1684	\N
1685	\N
1686	\N
1687	\N
1688	\N
1689	\N
1690	\N
1691	\N
1692	\N
1693	\N
1694	\N
1695	\N
1696	\N
1697	\N
1698	\N
1699	\N
1700	\N
1701	\N
1702	\N
1703	\N
1704	\N
1705	\N
1706	\N
1707	\N
1708	\N
1709	\N
1710	\N
1711	\N
1712	\N
1713	\N
1714	\N
1715	\N
1716	\N
1717	\N
1718	\N
1719	\N
1720	\N
1721	\N
1722	\N
1723	\N
1724	\N
1725	\N
1726	\N
1727	\N
1728	\N
1729	\N
1730	\N
1731	\N
1732	\N
1733	\N
1734	\N
1735	\N
1736	\N
1737	\N
1738	\N
1739	\N
1740	\N
1741	\N
1742	\N
1743	\N
1744	\N
1745	\N
1746	\N
1747	\N
1748	\N
1749	\N
1750	\N
1751	\N
1752	\N
1753	\N
1754	\N
1755	\N
1756	\N
1757	\N
1758	\N
1759	\N
1760	\N
1761	\N
1762	\N
1763	\N
1764	\N
1765	\N
1766	\N
1767	\N
1768	\N
1769	\N
1770	\N
1771	\N
1772	\N
1773	\N
1774	\N
1775	\N
1776	\N
1777	\N
1778	\N
1779	\N
1780	\N
1781	\N
1782	\N
1783	\N
1784	\N
1785	\N
1786	\N
1787	\N
1788	\N
1789	\N
1790	\N
1791	\N
1792	\N
1793	\N
1794	\N
1795	\N
1796	\N
1797	\N
1798	\N
1799	\N
1800	\N
1801	\N
1802	\N
1803	\N
1804	\N
1805	\N
1806	\N
1807	\N
1808	\N
1809	\N
1810	\N
1811	\N
1812	\N
1813	\N
1814	\N
1815	\N
1816	\N
1817	\N
1818	\N
1819	\N
1820	\N
1821	\N
1822	\N
1823	\N
1824	\N
1825	\N
1826	\N
1827	\N
1828	\N
1829	\N
1830	\N
1831	\N
1832	\N
1833	\N
1834	\N
1835	\N
1836	\N
1837	\N
1838	\N
1839	\N
1840	\N
1841	\N
1842	\N
1843	\N
1844	\N
1845	\N
1846	\N
1847	\N
1848	\N
1849	\N
1850	\N
1851	\N
1852	\N
1853	\N
1854	\N
1855	\N
1856	\N
1857	\N
1858	\N
1859	\N
1860	\N
1861	\N
1862	\N
1863	\N
1864	\N
1865	\N
1866	\N
1867	\N
1868	\N
1869	\N
1870	\N
1871	\N
1872	\N
1873	\N
1874	\N
1875	\N
1876	\N
1877	\N
1878	\N
1879	\N
1880	\N
1881	\N
1882	\N
1883	\N
1884	\N
1885	\N
1886	\N
1887	\N
1888	\N
1889	\N
1890	\N
1891	\N
1892	\N
1893	\N
1894	\N
1895	\N
1896	\N
1897	\N
1898	\N
1899	\N
1900	\N
1901	\N
1902	\N
1903	\N
1904	\N
1905	\N
1906	\N
1907	\N
1908	\N
1909	\N
1910	\N
1911	\N
1912	\N
1913	\N
1914	\N
1915	\N
1916	\N
1917	\N
1918	\N
1919	\N
1920	\N
1921	\N
1922	\N
1923	\N
1924	\N
1925	\N
1926	\N
1927	\N
1928	\N
1929	\N
1930	\N
1931	\N
1932	\N
1933	\N
1934	\N
1935	\N
1936	\N
1937	\N
1938	\N
1939	\N
1940	\N
1941	\N
1942	\N
1943	\N
1944	\N
1945	\N
1946	\N
1947	\N
1948	\N
1949	\N
1950	\N
1951	\N
1952	\N
1953	\N
1954	\N
1955	\N
1956	\N
1957	\N
1958	\N
1959	\N
1960	\N
1961	\N
1962	\N
1963	\N
1964	\N
1965	\N
1966	\N
1967	\N
1968	\N
1969	\N
1970	\N
1971	\N
1972	\N
1973	\N
1974	\N
1975	\N
1976	\N
1977	\N
1978	\N
1979	\N
1980	\N
1981	\N
1982	\N
1983	\N
1984	\N
1985	\N
1986	\N
1987	\N
1988	\N
1989	\N
1990	\N
1991	\N
1992	\N
1993	\N
1994	\N
1995	\N
1996	\N
1997	\N
1998	\N
1999	\N
2000	\N
2001	\N
2002	\N
2003	\N
2004	\N
2005	\N
2006	\N
2007	\N
2008	\N
2009	\N
2010	\N
2011	\N
2012	\N
2013	\N
2014	\N
2015	\N
2016	\N
2017	\N
2018	\N
2019	\N
2020	\N
2021	\N
2022	\N
2023	\N
2024	\N
2025	\N
2026	\N
2027	\N
2028	\N
2029	\N
2030	\N
2031	\N
2032	\N
2033	\N
2034	\N
2035	\N
2036	\N
2037	\N
2038	\N
2039	\N
2040	\N
2041	\N
2042	\N
2043	\N
2044	\N
2045	\N
2046	\N
2047	\N
2048	\N
2049	\N
2050	\N
2051	\N
2052	\N
2053	\N
2054	\N
2055	\N
2056	\N
2057	\N
2058	\N
2059	\N
2060	\N
2061	\N
2062	\N
2063	\N
2064	\N
2065	\N
2066	\N
2067	\N
2068	\N
2069	\N
2070	\N
2071	\N
2072	\N
2073	\N
2074	\N
2075	\N
2076	\N
2077	\N
2078	\N
2079	\N
2080	\N
2081	\N
2082	\N
2083	\N
2084	\N
2085	\N
2086	\N
2087	\N
2088	\N
2089	\N
2090	\N
2091	\N
2092	\N
2093	\N
2094	\N
2095	\N
2096	\N
2097	\N
2098	\N
2099	\N
2100	\N
2101	\N
2102	\N
2103	\N
2104	\N
2105	\N
2106	\N
2107	\N
2108	\N
2109	\N
2110	\N
2111	\N
2112	\N
2113	\N
2114	\N
2115	\N
2116	\N
2117	\N
2118	\N
2119	\N
2120	\N
2121	\N
2122	\N
2123	\N
2124	\N
2125	\N
2126	\N
2127	\N
2128	\N
2129	\N
2130	\N
2131	\N
2132	\N
2133	\N
2134	\N
2135	\N
2136	\N
2137	\N
2138	\N
2139	\N
2140	\N
2141	\N
2142	\N
2143	\N
2144	\N
2145	\N
2146	\N
2147	\N
2148	\N
2149	\N
2150	\N
2151	\N
2152	\N
2153	\N
2154	\N
2155	\N
2156	\N
2157	\N
2158	\N
2159	\N
2160	\N
2161	\N
2162	\N
2163	\N
2164	\N
2165	\N
2166	\N
2167	\N
2168	\N
2169	\N
2170	\N
2171	\N
2172	\N
2173	\N
2174	\N
2175	\N
2176	\N
2177	\N
2178	\N
2179	\N
2180	\N
2181	\N
2182	\N
2183	\N
2184	\N
2185	\N
2186	\N
2187	\N
2188	\N
2189	\N
2190	\N
2191	\N
2192	\N
2193	\N
2194	\N
2195	\N
2196	\N
2197	\N
2198	\N
2199	\N
2200	\N
2201	\N
2202	\N
2203	\N
2204	\N
2205	\N
2206	\N
2207	\N
2208	\N
2209	\N
2210	\N
2211	\N
2212	\N
2213	\N
2214	\N
2215	\N
2216	\N
2217	\N
2218	\N
2219	\N
2220	\N
2221	\N
2222	\N
2223	\N
2224	\N
2225	\N
2226	\N
2227	\N
2228	\N
2229	\N
2230	\N
2231	\N
2232	\N
2233	\N
2234	\N
2235	\N
2236	\N
2237	\N
2238	\N
2239	\N
2240	\N
2241	\N
2242	\N
2243	\N
2244	\N
2245	\N
2246	\N
2247	\N
2248	\N
2249	\N
2250	\N
2251	\N
2252	\N
2253	\N
2254	\N
2255	\N
2256	\N
2257	\N
2258	\N
2259	\N
2260	\N
2261	\N
2262	\N
2263	\N
2264	\N
2265	\N
2266	\N
2267	\N
2268	\N
2269	\N
2270	\N
2271	\N
2272	\N
2273	\N
2274	\N
2275	\N
2276	\N
2277	\N
2278	\N
2279	\N
2280	\N
2281	\N
2282	\N
2283	\N
2284	\N
2285	\N
2286	\N
2287	\N
2288	\N
2289	\N
2290	\N
2291	\N
2292	\N
2293	\N
2294	\N
2295	\N
2296	\N
2297	\N
2298	\N
2299	\N
2300	\N
2301	\N
2302	\N
2303	\N
2304	\N
2305	\N
2306	\N
2307	\N
2308	\N
2309	\N
2310	\N
2311	\N
2312	\N
2313	\N
2314	\N
2315	\N
2316	\N
2317	\N
2318	\N
2319	\N
2320	\N
2321	\N
2322	\N
2323	\N
2324	\N
2325	\N
2326	\N
2327	\N
2328	\N
2329	\N
2330	\N
2331	\N
2332	\N
2333	\N
2334	\N
2335	\N
2336	\N
2337	\N
2338	\N
2339	\N
2340	\N
2341	\N
2342	\N
2343	\N
2344	\N
2345	\N
2346	\N
2347	\N
2348	\N
2349	\N
2350	\N
2351	\N
2352	\N
2353	\N
2354	\N
2355	\N
2356	\N
2357	\N
2358	\N
2359	\N
2360	\N
2361	\N
2362	\N
2363	\N
2364	\N
2365	\N
2366	\N
2367	\N
2368	\N
2369	\N
2370	\N
2371	\N
2372	\N
2373	\N
2374	\N
2375	\N
2376	\N
2377	\N
2378	\N
2379	\N
2380	\N
2381	\N
2382	\N
2383	\N
2384	\N
2385	\N
2386	\N
2387	\N
2388	\N
2389	\N
2390	\N
2391	\N
2392	\N
2393	\N
2394	\N
2395	\N
2396	\N
2397	\N
2398	\N
2399	\N
2400	\N
2401	\N
2402	\N
2403	\N
2404	\N
2405	\N
2406	\N
2407	\N
2408	\N
2409	\N
2410	\N
2411	\N
2412	\N
2413	\N
2414	\N
2415	\N
2416	\N
2417	\N
2418	\N
2419	\N
2420	\N
2421	\N
2422	\N
2423	\N
2424	\N
2425	\N
2426	\N
2427	\N
2428	\N
2429	\N
2430	\N
2431	\N
2432	\N
2433	\N
2434	\N
2435	\N
2436	\N
2437	\N
2438	\N
2439	\N
2440	\N
2441	\N
2442	\N
2443	\N
2444	\N
2445	\N
2446	\N
2447	\N
2448	\N
2449	\N
2450	\N
2451	\N
2452	\N
2453	\N
2454	\N
2455	\N
2456	\N
2457	\N
2458	\N
2459	\N
2460	\N
2461	\N
2462	\N
2463	\N
2464	\N
2465	\N
2466	\N
2467	\N
2468	\N
2469	\N
2470	\N
2471	\N
2472	\N
2473	\N
2474	\N
2475	\N
2476	\N
2477	\N
2478	\N
2479	\N
2480	\N
2481	\N
2482	\N
2483	\N
2484	\N
2485	\N
2486	\N
2487	\N
2488	\N
2489	\N
2490	\N
2491	\N
2492	\N
2493	\N
2494	\N
2495	\N
2496	\N
2497	\N
2498	\N
2499	\N
2500	\N
2501	\N
2502	\N
2503	\N
2504	\N
2505	\N
2506	\N
2507	\N
2508	\N
2509	\N
2510	\N
2511	\N
2512	\N
2513	\N
2514	\N
2515	\N
2516	\N
2517	\N
2518	\N
2519	\N
2520	\N
2521	\N
2522	\N
2523	\N
2524	\N
2525	\N
2526	\N
2527	\N
2528	\N
2529	\N
2530	\N
2531	\N
2532	\N
2533	\N
2534	\N
2535	\N
2536	\N
2537	\N
2538	\N
2539	\N
2540	\N
2541	\N
2542	\N
2543	\N
2544	\N
2545	\N
2546	\N
2547	\N
2548	\N
2549	\N
2550	\N
2551	\N
2552	\N
2553	\N
2554	\N
2555	\N
2556	\N
2557	\N
2558	\N
2559	\N
2560	\N
2561	\N
2562	\N
2563	\N
2564	\N
2565	\N
2566	\N
2567	\N
2568	\N
2569	\N
2570	\N
2571	\N
2572	\N
2573	\N
2574	\N
2575	\N
2576	\N
2577	\N
2578	\N
2579	\N
2580	\N
2581	\N
2582	\N
2583	\N
2584	\N
2585	\N
2586	\N
2587	\N
2588	\N
2589	\N
2590	\N
2591	\N
2592	\N
2593	\N
2594	\N
2595	\N
2596	\N
2597	\N
2598	\N
2599	\N
2600	\N
2601	\N
2602	\N
2603	\N
2604	\N
2605	\N
2606	\N
2607	\N
2608	\N
2609	\N
2610	\N
2611	\N
2612	\N
2613	\N
2614	\N
2615	\N
2616	\N
2617	\N
2618	\N
2619	\N
2620	\N
2621	\N
2622	\N
2623	\N
2624	\N
2625	\N
2626	\N
2627	\N
2628	\N
2629	\N
2630	\N
2631	\N
2632	\N
2633	\N
2634	\N
2635	\N
2636	\N
2637	\N
2638	\N
2639	\N
2640	\N
2641	\N
2642	\N
2643	\N
2644	\N
2645	\N
2646	\N
2647	\N
2648	\N
2649	\N
2650	\N
2651	\N
2652	\N
2653	\N
2654	\N
2655	\N
2656	\N
2657	\N
2658	\N
2659	\N
2660	\N
2661	\N
2662	\N
2663	\N
2664	\N
2665	\N
2666	\N
2667	\N
2668	\N
2669	\N
2670	\N
2671	\N
2672	\N
2673	\N
2674	\N
2675	\N
2676	\N
2677	\N
2678	\N
2679	\N
2680	\N
2681	\N
2682	\N
2683	\N
2684	\N
2685	\N
2686	\N
2687	\N
2688	\N
2689	\N
2690	\N
2691	\N
2692	\N
2693	\N
2694	\N
2695	\N
2696	\N
2697	\N
2698	\N
2699	\N
2700	\N
2701	\N
2702	\N
2703	\N
2704	\N
2705	\N
2706	\N
2707	\N
2708	\N
2709	\N
2710	\N
2711	\N
2712	\N
2713	\N
2714	\N
2715	\N
2716	\N
2717	\N
2718	\N
2719	\N
2720	\N
2721	\N
2722	\N
2723	\N
2724	\N
2725	\N
2726	\N
2727	\N
2728	\N
2729	\N
2730	\N
2731	\N
2732	\N
2733	\N
2734	\N
2735	\N
2736	\N
2737	\N
2738	\N
2739	\N
2740	\N
2741	\N
2742	\N
2743	\N
2744	\N
2745	\N
2746	\N
2747	\N
2748	\N
2749	\N
2750	\N
2751	\N
2752	\N
2753	\N
2754	\N
2755	\N
2756	\N
2757	\N
2758	\N
2759	\N
2760	\N
2761	\N
2762	\N
2763	\N
2764	\N
2765	\N
2766	\N
2767	\N
2768	\N
2769	\N
2770	\N
2771	\N
2772	\N
2773	\N
2774	\N
2775	\N
2776	\N
2777	\N
2778	\N
2779	\N
2780	\N
2781	\N
2782	\N
2783	\N
2784	\N
2785	\N
2786	\N
2787	\N
2788	\N
2789	\N
2790	\N
2791	\N
2792	\N
2793	\N
2794	\N
2795	\N
2796	\N
2797	\N
2798	\N
2799	\N
2800	\N
2801	\N
2802	\N
2803	\N
2804	\N
2805	\N
2806	\N
2807	\N
2808	\N
2809	\N
2810	\N
2811	\N
2812	\N
2813	\N
2814	\N
2815	\N
2816	\N
2817	\N
2818	\N
2819	\N
2820	\N
2821	\N
2822	\N
2823	\N
2824	\N
2825	\N
2826	\N
2827	\N
2828	\N
2829	\N
2830	\N
2831	\N
2832	\N
2833	\N
2834	\N
2835	\N
2836	\N
2837	\N
2838	\N
2839	\N
2840	\N
2841	\N
2842	\N
2843	\N
2844	\N
2845	\N
2846	\N
2847	\N
2848	\N
2849	\N
2850	\N
2851	\N
2852	\N
2853	\N
2854	\N
2855	\N
2856	\N
2857	\N
2858	\N
2859	\N
2860	\N
2861	\N
2862	\N
2863	\N
2864	\N
2865	\N
2866	\N
2867	\N
2868	\N
2869	\N
2870	\N
2871	\N
2872	\N
2873	\N
2874	\N
2875	\N
2876	\N
2877	\N
2878	\N
2879	\N
2880	\N
2881	\N
2882	\N
2883	\N
2884	\N
2885	\N
2886	\N
2887	\N
2888	\N
2889	\N
2890	\N
2891	\N
2892	\N
2893	\N
2894	\N
2895	\N
2896	\N
2897	\N
2898	\N
2899	\N
2900	\N
2901	\N
2902	\N
2903	\N
2904	\N
2905	\N
2906	\N
2907	\N
2908	\N
2909	\N
2910	\N
2911	\N
2912	\N
2913	\N
2914	\N
2915	\N
2916	\N
2917	\N
2918	\N
2919	\N
2920	\N
2921	\N
2922	\N
2923	\N
2924	\N
2925	\N
2926	\N
2927	\N
2928	\N
2929	\N
2930	\N
2931	\N
2932	\N
2933	\N
2934	\N
2935	\N
2936	\N
2937	\N
2938	\N
2939	\N
2940	\N
2941	\N
2942	\N
2943	\N
2944	\N
2945	\N
2946	\N
2947	\N
2948	\N
2949	\N
2950	\N
2951	\N
2952	\N
2953	\N
2954	\N
2955	\N
2956	\N
2957	\N
2958	\N
2959	\N
2960	\N
2961	\N
2962	\N
2963	\N
2964	\N
2965	\N
2966	\N
2967	\N
2968	\N
2969	\N
2970	\N
2971	\N
2972	\N
2973	\N
2974	\N
2975	\N
2976	\N
2977	\N
2978	\N
2979	\N
2980	\N
2981	\N
2982	\N
2983	\N
2984	\N
2985	\N
2986	\N
2987	\N
2988	\N
2989	\N
2990	\N
2991	\N
2992	\N
2993	\N
2994	\N
2995	\N
2996	\N
2997	\N
2998	\N
2999	\N
3000	\N
3001	\N
3002	\N
3003	\N
3004	\N
3005	\N
3006	\N
3007	\N
3008	\N
3009	\N
3010	\N
3011	\N
3012	\N
3013	\N
3014	\N
3015	\N
3016	\N
3017	\N
3018	\N
3019	\N
3020	\N
3021	\N
3022	\N
3023	\N
3024	\N
3025	\N
3026	\N
3027	\N
3028	\N
3029	\N
3030	\N
3031	\N
3032	\N
3033	\N
3034	\N
3035	\N
3036	\N
3037	\N
3038	\N
3039	\N
3040	\N
3041	\N
3042	\N
3043	\N
3044	\N
3045	\N
3046	\N
3047	\N
3048	\N
3049	\N
3050	\N
3051	\N
3052	\N
3053	\N
3054	\N
3055	\N
3056	\N
3057	\N
3058	\N
3059	\N
3060	\N
3061	\N
3062	\N
3063	\N
3064	\N
3065	\N
3066	\N
3067	\N
3068	\N
3069	\N
3070	\N
3071	\N
3072	\N
3073	\N
3074	\N
3075	\N
3076	\N
3077	\N
3078	\N
3079	\N
3080	\N
3081	\N
3082	\N
3083	\N
3084	\N
3085	\N
3086	\N
3087	\N
3088	\N
3089	\N
3090	\N
3091	\N
3092	\N
3093	\N
3094	\N
3095	\N
3096	\N
3097	\N
3098	\N
3099	\N
3100	\N
3101	\N
3102	\N
3103	\N
3104	\N
3105	\N
3106	\N
3107	\N
3108	\N
3109	\N
3110	\N
3111	\N
3112	\N
3113	\N
3114	\N
3115	\N
3116	\N
3117	\N
3118	\N
3119	\N
3120	\N
3121	\N
3122	\N
3123	\N
3124	\N
3125	\N
3126	\N
3127	\N
3128	\N
3129	\N
3130	\N
3131	\N
3132	\N
3133	\N
3134	\N
3135	\N
3136	\N
3137	\N
3138	\N
3139	\N
3140	\N
3141	\N
3142	\N
3143	\N
3144	\N
3145	\N
3146	\N
3147	\N
3148	\N
3149	\N
3150	\N
3151	\N
3152	\N
3153	\N
3154	\N
3155	\N
3156	\N
3157	\N
3158	\N
3159	\N
3160	\N
3161	\N
3162	\N
3163	\N
3164	\N
3165	\N
3166	\N
3167	\N
3168	\N
3169	\N
3170	\N
3171	\N
3172	\N
3173	\N
3174	\N
3175	\N
3176	\N
3177	\N
3178	\N
3179	\N
3180	\N
3181	\N
3182	\N
3183	\N
3184	\N
3185	\N
3186	\N
3187	\N
3188	\N
3189	\N
3190	\N
3191	\N
3192	\N
3193	\N
3194	\N
3195	\N
3196	\N
3197	\N
3198	\N
3199	\N
3200	\N
3201	\N
3202	\N
3203	\N
3204	\N
3205	\N
3206	\N
3207	\N
3208	\N
3209	\N
3210	\N
3211	\N
3212	\N
3213	\N
3214	\N
3215	\N
3216	\N
3217	\N
3218	\N
3219	\N
3220	\N
3221	\N
3222	\N
3223	\N
3224	\N
3225	\N
3226	\N
3227	\N
3228	\N
3229	\N
3230	\N
3231	\N
3232	\N
3233	\N
3234	\N
3235	\N
3236	\N
3237	\N
3238	\N
3239	\N
3240	\N
3241	\N
3242	\N
3243	\N
3244	\N
3245	\N
3246	\N
3247	\N
3248	\N
3249	\N
3250	\N
3251	\N
3252	\N
3253	\N
3254	\N
3255	\N
3256	\N
3257	\N
3258	\N
3259	\N
3260	\N
3261	\N
3262	\N
3263	\N
3264	\N
3265	\N
3266	\N
3267	\N
3268	\N
3269	\N
3270	\N
3271	\N
3272	\N
3273	\N
3274	\N
3275	\N
3276	\N
3277	\N
3278	\N
3279	\N
3280	\N
3281	\N
3282	\N
3283	\N
3284	\N
3285	\N
3286	\N
3287	\N
3288	\N
3289	\N
3290	\N
3291	\N
3292	\N
3293	\N
3294	\N
3295	\N
3296	\N
3297	\N
3298	\N
3299	\N
3300	\N
3301	\N
3302	\N
3303	\N
3304	\N
3305	\N
3306	\N
3307	\N
3308	\N
3309	\N
3310	\N
3311	\N
3312	\N
3313	\N
3314	\N
3315	\N
3316	\N
3317	\N
3318	\N
3319	\N
3320	\N
3321	\N
3322	\N
3323	\N
3324	\N
3325	\N
3326	\N
3327	\N
3328	\N
3329	\N
3330	\N
3331	\N
3332	\N
3333	\N
3334	\N
3335	\N
3336	\N
3337	\N
3338	\N
3339	\N
3340	\N
3341	\N
3342	\N
3343	\N
3344	\N
3345	\N
3346	\N
3347	\N
3348	\N
3349	\N
3350	\N
3351	\N
3352	\N
3353	\N
3354	\N
3355	\N
3356	\N
3357	\N
3358	\N
3359	\N
3360	\N
3361	\N
3362	\N
3363	\N
3364	\N
3365	\N
3366	\N
3367	\N
3368	\N
3369	\N
3370	\N
3371	\N
3372	\N
3373	\N
3374	\N
3375	\N
3376	\N
3377	\N
3378	\N
3379	\N
3380	\N
3381	\N
3382	\N
3383	\N
3384	\N
3385	\N
3386	\N
3387	\N
3388	\N
3389	\N
3390	\N
3391	\N
3392	\N
3393	\N
3394	\N
3395	\N
3396	\N
3397	\N
3398	\N
3399	\N
3400	\N
3401	\N
3402	\N
3403	\N
3404	\N
3405	\N
3406	\N
3407	\N
3408	\N
3409	\N
3410	\N
3411	\N
3412	\N
3413	\N
3414	\N
3415	\N
3416	\N
3417	\N
3418	\N
3419	\N
3420	\N
3421	\N
3422	\N
3423	\N
3424	\N
3425	\N
3426	\N
3427	\N
3428	\N
3429	\N
3430	\N
3431	\N
3432	\N
3433	\N
3434	\N
3435	\N
3436	\N
3437	\N
3438	\N
3439	\N
3440	\N
3441	\N
3442	\N
3443	\N
3444	\N
3445	\N
3446	\N
3447	\N
3448	\N
3449	\N
3450	\N
3451	\N
3452	\N
3453	\N
3454	\N
3455	\N
3456	\N
3457	\N
3458	\N
3459	\N
3460	\N
3461	\N
3462	\N
3463	\N
3464	\N
3465	\N
3466	\N
3467	\N
3468	\N
3469	\N
3470	\N
3471	\N
3472	\N
3473	\N
3474	\N
3475	\N
3476	\N
3477	\N
3478	\N
3479	\N
3480	\N
3481	\N
3482	\N
3483	\N
3484	\N
3485	\N
3486	\N
3487	\N
3488	\N
3489	\N
3490	\N
3491	\N
3492	\N
3493	\N
3494	\N
3495	\N
3496	\N
3497	\N
3498	\N
3499	\N
3500	\N
3501	\N
3502	\N
3503	\N
3504	\N
3505	\N
3506	\N
3507	\N
3508	\N
3509	\N
3510	\N
3511	\N
3512	\N
3513	\N
3514	\N
3515	\N
3516	\N
3517	\N
3518	\N
3519	\N
3520	\N
3521	\N
3522	\N
3523	\N
3524	\N
3525	\N
3526	\N
3527	\N
3528	\N
3529	\N
3530	\N
3531	\N
3532	\N
3533	\N
3534	\N
3535	\N
3536	\N
3537	\N
3538	\N
3539	\N
3540	\N
3541	\N
3542	\N
3543	\N
3544	\N
3545	\N
3546	\N
3547	\N
3548	\N
3549	\N
3550	\N
3551	\N
3552	\N
3553	\N
3554	\N
3555	\N
1042439	\N
1042440	\N
1042441	\N
1042442	\N
1042443	\N
1042444	\N
1042445	\N
1042446	\N
1042447	\N
1042448	\N
1042449	\N
1042450	\N
1042451	\N
1042452	\N
1042453	\N
1042454	\N
1042455	\N
1042456	\N
1042457	\N
1042458	\N
1042459	\N
1042460	\N
1042461	\N
1042462	\N
1042463	\N
1042464	\N
1042465	\N
1042466	\N
1042467	\N
1042468	\N
1042469	\N
1042470	\N
1042471	\N
1042472	\N
1042473	\N
1042474	\N
1042475	\N
1042476	\N
1042477	\N
1042478	\N
1042479	\N
1042480	\N
1042481	\N
1042482	\N
1042483	\N
1042484	\N
1042485	\N
1042486	\N
1042487	\N
1042488	\N
1042489	\N
1042490	\N
1042491	\N
1042492	\N
1042493	\N
1042494	\N
1042495	\N
1042496	\N
1042497	\N
1042498	\N
1042499	\N
1042500	\N
1042501	\N
1042502	\N
1042503	\N
1042504	\N
1042505	\N
1042506	\N
1042507	\N
1042508	\N
1042509	\N
1042510	\N
1042511	\N
1042512	\N
1042513	\N
1042514	\N
1042515	\N
1042516	\N
1042517	\N
1042518	\N
1042519	\N
1042520	\N
1042521	\N
1042522	\N
1042523	\N
1042524	\N
1042525	\N
1042526	\N
1042527	\N
1042528	\N
1042529	\N
1042530	\N
1042531	\N
1042532	\N
1042533	\N
1042534	\N
1042535	\N
1042536	\N
1042537	\N
1042538	\N
1042539	\N
1042540	\N
1042541	\N
1042542	\N
1042543	\N
1042544	\N
1042545	\N
1042546	\N
1042547	\N
1042548	\N
1042549	\N
1042550	\N
1042551	\N
1042552	\N
1042553	\N
1042554	\N
1042555	\N
1042556	\N
1042557	\N
1042558	\N
1042559	\N
1042560	\N
1042561	\N
1042562	\N
1042563	\N
1042564	\N
1042565	\N
1042566	\N
1042567	\N
1042568	\N
1042569	\N
1042570	\N
1042571	\N
1042572	\N
1042573	\N
1042574	\N
1042575	\N
1042576	\N
1042577	\N
1042578	\N
1042579	\N
1042580	\N
1042581	\N
1042582	\N
1042583	\N
1042584	\N
1042585	\N
1042586	\N
1042587	\N
1042588	\N
1042589	\N
1042590	\N
1042591	\N
1042592	\N
1042593	\N
1042594	\N
1042595	\N
1042596	\N
1042597	\N
1042598	\N
1042599	\N
1042600	\N
1042601	\N
1042602	\N
1042603	\N
1042604	\N
1042605	\N
1042606	\N
1042607	\N
1042608	\N
1042609	\N
1042610	\N
1042611	\N
1042612	\N
1042613	\N
1042614	\N
1042615	\N
1042616	\N
1042617	\N
1042618	\N
1042619	\N
1042620	\N
1042621	\N
1042622	\N
1042623	\N
1042624	\N
1042625	\N
1042626	\N
1042627	\N
1042628	\N
1042629	\N
1042630	\N
1042631	\N
1042632	\N
1042633	\N
1042634	\N
1042635	\N
1042636	\N
1042637	\N
1042638	\N
1042639	\N
1042640	\N
1042641	\N
1042642	\N
1042643	\N
1042644	\N
1042645	\N
1042646	\N
1042647	\N
1042648	\N
1042649	\N
1042650	\N
1042651	\N
1042652	\N
1042653	\N
1042654	\N
1042655	\N
1042656	\N
1042657	\N
1042658	\N
1042659	\N
1042660	\N
1042661	\N
1042662	\N
1042663	\N
1042664	\N
1042665	\N
1042666	\N
1042667	\N
1042668	\N
1042669	\N
1042670	\N
1042671	\N
1042672	\N
1042673	\N
1042674	\N
1042675	\N
1042676	\N
1042677	\N
1042678	\N
1042679	\N
1042680	\N
1042681	\N
1042682	\N
1042683	\N
1042684	\N
1042685	\N
1042686	\N
1042687	\N
1042688	\N
1042689	\N
1042690	\N
1042691	\N
1042692	\N
1042693	\N
1042694	\N
1042695	\N
1042696	\N
1042697	\N
1042698	\N
1042699	\N
1042700	\N
1042701	\N
1042702	\N
1042703	\N
1042704	\N
1042705	\N
1042706	\N
1042707	\N
1042708	\N
1042709	\N
1042710	\N
1042711	\N
1042712	\N
1042713	\N
1042714	\N
1042715	\N
1042716	\N
1042717	\N
1042718	\N
1042719	\N
1042720	\N
1042721	\N
1042722	\N
1042723	\N
1042724	\N
1042725	\N
1042726	\N
1042727	\N
1042728	\N
1042729	\N
1042730	\N
1042731	\N
1042732	\N
1042733	\N
1042734	\N
1042735	\N
1042736	\N
1042737	\N
1042738	\N
1042739	\N
1042740	\N
1042741	\N
1042742	\N
1042743	\N
1042744	\N
1042745	\N
1042746	\N
1042747	\N
1042748	\N
1042749	\N
1042750	\N
1042751	\N
1042752	\N
1042753	\N
1042754	\N
1042755	\N
1042756	\N
1042757	\N
1042758	\N
1042759	\N
1042760	\N
1042761	\N
1042762	\N
1042763	\N
1042764	\N
1042765	\N
1042766	\N
1042767	\N
1042768	\N
1042769	\N
1042770	\N
1042771	\N
1042772	\N
1042773	\N
1042774	\N
1042775	\N
1042776	\N
1042777	\N
1042778	\N
1042779	\N
1042780	\N
1042781	\N
1042782	\N
1042783	\N
1042784	\N
1042785	\N
1042786	\N
1042787	\N
1042788	\N
1042789	\N
1042790	\N
1042791	\N
1042792	\N
1042793	\N
1042794	\N
1042795	\N
1042796	\N
1042797	\N
1042798	\N
1042799	\N
1042800	\N
1042801	\N
1042802	\N
1042803	\N
1042804	\N
1042805	\N
1042806	\N
1042807	\N
1042808	\N
1042809	\N
1042810	\N
1042811	\N
1042812	\N
1042813	\N
1042814	\N
1042815	\N
1042816	\N
1042817	\N
1042818	\N
1042819	\N
1042820	\N
1042821	\N
1042822	\N
1042823	\N
1042824	\N
1042825	\N
1042826	\N
1042827	\N
1042828	\N
1042829	\N
1042830	\N
1042831	\N
1042832	\N
1042833	\N
1042834	\N
1042835	\N
1042836	\N
1042837	\N
1042838	\N
1042839	\N
1042840	\N
1042841	\N
1042842	\N
1042843	\N
1042844	\N
1042845	\N
1042846	\N
1042847	\N
1042848	\N
1042849	\N
1042850	\N
1042851	\N
1042852	\N
1042853	\N
1042854	\N
1042855	\N
1042856	\N
1042857	\N
1042858	\N
1042859	\N
1042860	\N
1042861	\N
1042862	\N
1042863	\N
1042864	\N
1042865	\N
1042866	\N
1042867	\N
1042868	\N
1042869	\N
1042870	\N
1042871	\N
1042872	\N
1042873	\N
1042874	\N
1042875	\N
1042876	\N
1042877	\N
1042878	\N
1042879	\N
1042880	\N
1042881	\N
1042882	\N
1042883	\N
1042884	\N
1042885	\N
1042886	\N
1042887	\N
1042888	\N
1042889	\N
1042890	\N
1042891	\N
1042892	\N
1042893	\N
1042894	\N
1042895	\N
1042896	\N
1042897	\N
1042898	\N
1042899	\N
1042900	\N
1042901	\N
1042902	\N
1042903	\N
1042904	\N
1042905	\N
1042906	\N
1042907	\N
1042908	\N
1042909	\N
1042910	\N
1042911	\N
1042912	\N
1042913	\N
1042914	\N
1042915	\N
1042916	\N
1042917	\N
1042918	\N
1042919	\N
1042920	\N
1042921	\N
1042922	\N
1042923	\N
1042924	\N
1042925	\N
1042926	\N
1042927	\N
1042928	\N
1042929	\N
1042930	\N
1042931	\N
1042932	\N
1042933	\N
1042934	\N
1042935	\N
1042936	\N
1042937	\N
1042938	\N
1042939	\N
1042940	\N
1042941	\N
1042942	\N
1042943	\N
1042944	\N
1042945	\N
1042946	\N
1042947	\N
1042948	\N
1042949	\N
1042950	\N
1042951	\N
1042952	\N
1042953	\N
1042954	\N
1042955	\N
1042956	\N
1042957	\N
1042958	\N
1042959	\N
1042960	\N
1042961	\N
1042962	\N
1042963	\N
1042964	\N
1042965	\N
1042966	\N
1042967	\N
1042968	\N
1042969	\N
1042970	\N
1042971	\N
1042972	\N
1042973	\N
1042974	\N
1042975	\N
1042976	\N
1042977	\N
1042978	\N
1042979	\N
1042980	\N
1042981	\N
1042982	\N
1042983	\N
1042984	\N
1042985	\N
1042986	\N
1042987	\N
1042988	\N
1042989	\N
1042990	\N
1042991	\N
1042992	\N
1042993	\N
1042994	\N
1042995	\N
1042996	\N
1042997	\N
1042998	\N
1042999	\N
1043000	\N
1043001	\N
1043002	\N
1043003	\N
1043004	\N
1043005	\N
1043006	\N
1043007	\N
1043008	\N
1043009	\N
1043010	\N
1043011	\N
1043012	\N
1043013	\N
1043014	\N
1043015	\N
1043016	\N
1043017	\N
1043018	\N
1043019	\N
1043020	\N
1043021	\N
1043022	\N
1043023	\N
1043024	\N
1043025	\N
1043026	\N
1043027	\N
1043028	\N
1043029	\N
1043030	\N
1043031	\N
1043032	\N
1043033	\N
1043034	\N
1043035	\N
1043036	\N
1043037	\N
1043038	\N
1043039	\N
1043040	\N
1043041	\N
1043042	\N
1043043	\N
1043044	\N
1043045	\N
1043046	\N
1043047	\N
1043048	\N
1043049	\N
1043050	\N
1043051	\N
1043052	\N
1043053	\N
1043054	\N
1043055	\N
1043056	\N
1043057	\N
1043058	\N
1043059	\N
1043060	\N
1043061	\N
1043062	\N
1043063	\N
1043064	\N
1043065	\N
1043066	\N
1043067	\N
1043068	\N
1043069	\N
1043070	\N
1043071	\N
1043072	\N
1043073	\N
1043074	\N
1043075	\N
1043076	\N
1043077	\N
1043078	\N
1043079	\N
1043080	\N
1043081	\N
1043082	\N
1043083	\N
1043084	\N
1043085	\N
1043086	\N
1043087	\N
1043088	\N
1043089	\N
1043090	\N
1043091	\N
1043092	\N
1043093	\N
1043094	\N
1043095	\N
1043096	\N
1043097	\N
1043098	\N
1043099	\N
1043100	\N
1043101	\N
1043102	\N
1043103	\N
1043104	\N
1043105	\N
1043106	\N
1043107	\N
1043108	\N
1043109	\N
1043110	\N
1043111	\N
1043112	\N
1043113	\N
1043114	\N
1043115	\N
1043116	\N
1043117	\N
1043118	\N
1043119	\N
1043120	\N
1043121	\N
1043122	\N
1043123	\N
1043124	\N
1043125	\N
1043126	\N
1043127	\N
1043128	\N
1043129	\N
1043130	\N
1043131	\N
1043132	\N
1043133	\N
1043134	\N
1043135	\N
1043136	\N
1043137	\N
1043138	\N
1043139	\N
1043140	\N
1043141	\N
1043142	\N
1043143	\N
1043144	\N
1043145	\N
1043146	\N
1043147	\N
1043148	\N
1043149	\N
1043150	\N
1043151	\N
1043152	\N
1043153	\N
1043154	\N
1043155	\N
1043156	\N
1043157	\N
1043158	\N
1043159	\N
1043160	\N
1043161	\N
1043162	\N
1043163	\N
1043164	\N
1043165	\N
1043166	\N
1043167	\N
1043168	\N
1043169	\N
1043170	\N
1043171	\N
1043172	\N
1043173	\N
1043174	\N
1043175	\N
1043176	\N
1043177	\N
1043178	\N
1043179	\N
1043180	\N
1043181	\N
1043182	\N
1043183	\N
1043184	\N
1043185	\N
1043186	\N
1043187	\N
1043188	\N
1043189	\N
1043190	\N
1043191	\N
1043192	\N
1043193	\N
1043194	\N
1043195	\N
1043196	\N
1043197	\N
1043198	\N
1043199	\N
1043200	\N
1043201	\N
1043202	\N
1043203	\N
1043204	\N
1043205	\N
1043206	\N
1043207	\N
1043208	\N
1043209	\N
1043210	\N
1043211	\N
1043212	\N
1043213	\N
1043214	\N
1043215	\N
1043216	\N
1043217	\N
1043218	\N
1043219	\N
1043220	\N
1043221	\N
1043222	\N
1043223	\N
1043224	\N
1043225	\N
1043226	\N
1043227	\N
1043228	\N
1043229	\N
1043230	\N
1043231	\N
1043232	\N
1043233	\N
1043234	\N
1043235	\N
1043236	\N
1043237	\N
1043238	\N
1043239	\N
1043240	\N
1043241	\N
1043242	\N
1043243	\N
1043244	\N
1043245	\N
1043246	\N
1043247	\N
1043248	\N
1043249	\N
1043250	\N
1043251	\N
1043252	\N
1043253	\N
1043254	\N
1043255	\N
1043256	\N
1043257	\N
1043258	\N
1043259	\N
1043260	\N
1043261	\N
1043262	\N
1043263	\N
1043264	\N
1043265	\N
1043266	\N
1043267	\N
1043268	\N
1043269	\N
1043270	\N
1043271	\N
1043272	\N
1043273	\N
1043274	\N
1043275	\N
1043276	\N
1043277	\N
1043278	\N
1043279	\N
1043280	\N
1043281	\N
1043282	\N
1043283	\N
1043284	\N
1043285	\N
1043286	\N
1043287	\N
1043288	\N
1043289	\N
1043290	\N
1043291	\N
1299422	\N
1299423	\N
1299424	\N
1299425	\N
1299426	\N
1299427	\N
1299428	\N
1299429	\N
1299430	\N
1299431	\N
1299432	\N
1299433	\N
1299434	\N
1299435	\N
1299436	\N
1299437	\N
1299438	\N
1299439	\N
1299440	\N
1299441	\N
1299442	\N
1299443	\N
1299444	\N
1299445	\N
1299446	\N
1299447	\N
1299448	\N
1299449	\N
1299450	\N
1299451	\N
1299452	\N
1299453	\N
1299454	\N
1299455	\N
1299456	\N
1299457	\N
1299458	\N
1299459	\N
1299460	\N
1299461	\N
1299462	\N
1299463	\N
1299464	\N
1299465	\N
1299466	\N
1299467	\N
1299468	\N
1299469	\N
1299470	\N
1299471	\N
1299472	\N
1299473	\N
1299474	\N
1299475	\N
1299476	\N
1299477	\N
1299478	\N
1299479	\N
1299480	\N
1299481	\N
1299482	\N
1299483	\N
1299484	\N
1299485	\N
1299486	\N
1299487	\N
1299488	\N
1299489	\N
1299490	\N
1299491	\N
1299492	\N
1299493	\N
1299494	\N
1299495	\N
1299496	\N
1299497	\N
1299498	\N
1299499	\N
1299500	\N
1299501	\N
1299502	\N
1299503	\N
1299504	\N
1299505	\N
1299506	\N
1299507	\N
1299508	\N
1299509	\N
1299510	\N
1299511	\N
1299512	\N
1299513	\N
1299514	\N
1299515	\N
1299516	\N
1299517	\N
1299518	\N
1299519	\N
1299520	\N
1299521	\N
1299522	\N
1299523	\N
1299524	\N
1299525	\N
1299526	\N
1299527	\N
1299528	\N
1299529	\N
1299530	\N
1299531	\N
1299532	\N
1299533	\N
1299534	\N
1299535	\N
1299536	\N
1299537	\N
1299538	\N
1299539	\N
1299540	\N
1299541	\N
1299542	\N
1299543	\N
1299544	\N
1299545	\N
1299546	\N
1299547	\N
1299548	\N
1299549	\N
1299550	\N
1299551	\N
1299552	\N
1299553	\N
1299554	\N
1299555	\N
1299556	\N
1299557	\N
1299558	\N
1299559	\N
1299560	\N
1299561	\N
1299562	\N
1299563	\N
1299564	\N
1299565	\N
1299566	\N
1299567	\N
1299568	\N
1299569	\N
1299570	\N
1299571	\N
1299572	\N
1299573	\N
1299574	\N
1299575	\N
1299576	\N
1299577	\N
1299578	\N
1299579	\N
1299580	\N
1299581	\N
1299582	\N
1299583	\N
1299584	\N
1299585	\N
1299586	\N
1299587	\N
1299588	\N
1299589	\N
1299590	\N
1299591	\N
1937825	\N
1938204	\N
1938574	\N
1938896	\N
1939166	\N
1939740	\N
1940702	\N
1942511	\N
1942903	\N
1943974	\N
1944393	\N
1945142	\N
1945723	\N
1946299	\N
1946803	\N
1946807	\N
1947239	\N
1947559	\N
1949642	\N
1950661	\N
1951335	\N
1952479	\N
1953524	\N
1954331	\N
1958523	\N
1959276	\N
1960550	\N
1962148	\N
1965964	\N
1967602	\N
1973735	\N
1975536	\N
4087283	\N
7408501	\N
7411946	\N
\.


--
-- Data for Name: versions; Type: TABLE DATA; Schema: public; Owner: ion
--

COPY versions (version) FROM stdin;
2
\.


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
    ADD CONSTRAINT albums_id_fkey FOREIGN KEY (id) REFERENCES things(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: artists_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_id_fkey FOREIGN KEY (id) REFERENCES things(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: connections_blue_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY connections
    ADD CONSTRAINT connections_blue_fkey FOREIGN KEY (blue) REFERENCES things(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: connections_red_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ion
--

ALTER TABLE ONLY connections
    ADD CONSTRAINT connections_red_fkey FOREIGN KEY (red) REFERENCES things(id) ON UPDATE CASCADE ON DELETE CASCADE;


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
    ADD CONSTRAINT ratings_id_fkey FOREIGN KEY (id) REFERENCES things(id) ON UPDATE CASCADE ON DELETE CASCADE;


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
    ADD CONSTRAINT recordings_id_fkey FOREIGN KEY (id) REFERENCES things(id) ON UPDATE CASCADE ON DELETE CASCADE;


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
    ADD CONSTRAINT songs_id_fkey FOREIGN KEY (id) REFERENCES things(id) ON UPDATE CASCADE ON DELETE CASCADE;


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

