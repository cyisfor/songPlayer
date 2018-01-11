--
-- PostgreSQL database dump
--

-- Dumped from database version 10devel
-- Dumped by pg_dump version 10devel

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: problems; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE problems (
    id integer NOT NULL,
    reason text,
    created timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


ALTER TABLE problems OWNER TO "user";

--
-- Name: problems problems_created_key; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY problems
    ADD CONSTRAINT problems_created_key UNIQUE (created);


--
-- Name: problems problems_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY problems
    ADD CONSTRAINT problems_pkey PRIMARY KEY (id);


--
-- Name: problems problems_nodups; Type: RULE; Schema: public; Owner: user
--

CREATE RULE problems_nodups AS
    ON INSERT TO problems
   WHERE (EXISTS ( SELECT 1
           FROM problems
          WHERE (problems.id = new.id))) DO INSTEAD NOTHING;


--
-- Name: problems problems_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY problems
    ADD CONSTRAINT problems_id_fkey FOREIGN KEY (id) REFERENCES recordings(id) ON UPDATE CASCADE ON DELETE CASCADE;

--
-- Name: song_problems; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE song_problems (
    id integer NOT NULL,
    reason text,
    created timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


ALTER TABLE song_problems OWNER TO "user";

--
-- Name: song_problems song_problems_created_key; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY song_problems
    ADD CONSTRAINT song_problems_created_key UNIQUE (created);


--
-- Name: song_problems song_problems_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY song_problems
    ADD CONSTRAINT song_problems_pkey PRIMARY KEY (id);


--
-- Name: song_problems song_problems_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY song_problems
    ADD CONSTRAINT song_problems_id_fkey FOREIGN KEY (id) REFERENCES songs(id);


--
-- PostgreSQL database dump complete
--

