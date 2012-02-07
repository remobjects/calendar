--
-- PostgreSQL database dump
--

-- Dumped from database version 8.4.9
-- Dumped by pg_dump version 9.0.1
-- Started on 2012-01-31 19:04:33

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- TOC entry 1816 (class 1262 OID 100487)
-- Name: calendar; Type: DATABASE; Schema: -; Owner: -
--

CREATE DATABASE calendar WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


\connect calendar

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 1509 (class 1259 OID 100718)
-- Dependencies: 1796 6
-- Name: Alarms; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Alarms" (
    "ID" bigint NOT NULL,
    "EventID" bigint NOT NULL,
    "Summary" text,
    "Description" text,
    "Repeat" integer DEFAULT 0 NOT NULL,
    "Time" timestamp without time zone,
    "RelativeTime" integer,
    "TriggerRelation" integer NOT NULL
);


--
-- TOC entry 1508 (class 1259 OID 100716)
-- Dependencies: 1509 6
-- Name: Alarm_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "Alarm_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 1818 (class 0 OID 0)
-- Dependencies: 1508
-- Name: Alarm_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "Alarm_ID_seq" OWNED BY "Alarms"."ID";


--
-- TOC entry 1505 (class 1259 OID 100490)
-- Dependencies: 1790 1791 1792 6
-- Name: Calendars; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Calendars" (
    "ID" bigint NOT NULL,
    "Name" character varying(128) NOT NULL,
    "Description" text,
    "Group" boolean DEFAULT false NOT NULL,
    "LdapGroup" character varying(128),
    "DisplayName" character varying(128),
    "Order" integer DEFAULT 0 NOT NULL,
    "Color" character varying(16) DEFAULT '#AAAAAAFF'::character varying NOT NULL,
    "CTag" character varying(64)
);


--
-- TOC entry 1504 (class 1259 OID 100488)
-- Dependencies: 6 1505
-- Name: Calendars_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "Calendars_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 1819 (class 0 OID 0)
-- Dependencies: 1504
-- Name: Calendars_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "Calendars_ID_seq" OWNED BY "Calendars"."ID";


--
-- TOC entry 1507 (class 1259 OID 100503)
-- Dependencies: 1794 6
-- Name: Events; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Events" (
    "ID" bigint NOT NULL,
    "CalendarID" bigint NOT NULL,
    "DTStart" timestamp without time zone NOT NULL,
    "DTEnd" timestamp without time zone NOT NULL,
    "TimeZone" character varying(128),
    "Location" text,
    "GEOLat" double precision,
    "GEOLon" double precision,
    "Status" integer NOT NULL,
    "Created" timestamp without time zone NOT NULL,
    "LastUpdated" timestamp without time zone NOT NULL,
    "Resources" text,
    "Categories" text,
    "Description" text,
    "Priority" integer NOT NULL,
    "Summary" text NOT NULL,
    "ICSName" character varying(256) NOT NULL,
    "RecurID" timestamp without time zone,
    "AllDay" boolean DEFAULT false NOT NULL,
    "TimeZoneInfo" text,
    "ETag" character varying(40),
	"Uid" text
);


--
-- TOC entry 1820 (class 0 OID 0)
-- Dependencies: 1507
-- Name: COLUMN "Events"."TimeZone"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN "Events"."TimeZone" IS 'timezone names';


--
-- TOC entry 1506 (class 1259 OID 100501)
-- Dependencies: 1507 6
-- Name: Events_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "Events_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 1821 (class 0 OID 0)
-- Dependencies: 1506
-- Name: Events_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "Events_ID_seq" OWNED BY "Events"."ID";


--
-- TOC entry 1511 (class 1259 OID 100734)
-- Dependencies: 6
-- Name: Recurrences; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Recurrences" (
    "ID" bigint NOT NULL,
    "EventID" bigint NOT NULL,
    "Value" text NOT NULL
);


--
-- TOC entry 1510 (class 1259 OID 100732)
-- Dependencies: 6 1511
-- Name: Recurrrences_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "Recurrrences_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 1822 (class 0 OID 0)
-- Dependencies: 1510
-- Name: Recurrrences_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "Recurrrences_ID_seq" OWNED BY "Recurrences"."ID";


--
-- TOC entry 1795 (class 2604 OID 100721)
-- Dependencies: 1509 1508 1509
-- Name: ID; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE "Alarms" ALTER COLUMN "ID" SET DEFAULT nextval('"Alarm_ID_seq"'::regclass);


--
-- TOC entry 1789 (class 2604 OID 100493)
-- Dependencies: 1504 1505 1505
-- Name: ID; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE "Calendars" ALTER COLUMN "ID" SET DEFAULT nextval('"Calendars_ID_seq"'::regclass);


--
-- TOC entry 1793 (class 2604 OID 100506)
-- Dependencies: 1506 1507 1507
-- Name: ID; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE "Events" ALTER COLUMN "ID" SET DEFAULT nextval('"Events_ID_seq"'::regclass);


--
-- TOC entry 1797 (class 2604 OID 100737)
-- Dependencies: 1510 1511 1511
-- Name: ID; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE "Recurrences" ALTER COLUMN "ID" SET DEFAULT nextval('"Recurrrences_ID_seq"'::regclass);


--
-- TOC entry 1807 (class 2606 OID 100739)
-- Dependencies: 1509 1509
-- Name: Alarms_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Alarms"
    ADD CONSTRAINT "Alarms_pkey" PRIMARY KEY ("ID");


--
-- TOC entry 1799 (class 2606 OID 100500)
-- Dependencies: 1505 1505
-- Name: Calendars_Name_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Calendars"
    ADD CONSTRAINT "Calendars_Name_key" UNIQUE ("Name");


--
-- TOC entry 1801 (class 2606 OID 100498)
-- Dependencies: 1505 1505
-- Name: Calendars_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Calendars"
    ADD CONSTRAINT "Calendars_pkey" PRIMARY KEY ("ID");


--
-- TOC entry 1803 (class 2606 OID 100543)
-- Dependencies: 1507 1507 1507
-- Name: Events_CalendarID_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Events"
    ADD CONSTRAINT "Events_CalendarID_key" UNIQUE ("CalendarID", "ICSName");


--
-- TOC entry 1805 (class 2606 OID 100508)
-- Dependencies: 1507 1507
-- Name: Events_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Events"
    ADD CONSTRAINT "Events_pkey" PRIMARY KEY ("ID");


--
-- TOC entry 1810 (class 2606 OID 100750)
-- Dependencies: 1511 1511
-- Name: Recurrrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Recurrences"
    ADD CONSTRAINT "Recurrrences_pkey" PRIMARY KEY ("ID");


--
-- TOC entry 1811 (class 1259 OID 100756)
-- Dependencies: 1511
-- Name: fki_RecurrencesPK; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX "fki_RecurrencesPK" ON "Recurrences" USING btree ("EventID");


--
-- TOC entry 1808 (class 1259 OID 100745)
-- Dependencies: 1509
-- Name: fki_def; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fki_def ON "Alarms" USING btree ("EventID");


--
-- TOC entry 1813 (class 2606 OID 100751)
-- Dependencies: 1507 1511 1804
-- Name: RecurrencesPK; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Recurrences"
    ADD CONSTRAINT "RecurrencesPK" FOREIGN KEY ("EventID") REFERENCES "Events"("ID") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 1812 (class 2606 OID 100740)
-- Dependencies: 1509 1804 1507
-- Name: def; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Alarms"
    ADD CONSTRAINT def FOREIGN KEY ("EventID") REFERENCES "Events"("ID") ON UPDATE CASCADE ON DELETE CASCADE;


-- Completed on 2012-01-31 19:04:36

--
-- PostgreSQL database dump complete
--

