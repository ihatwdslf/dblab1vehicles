--
-- PostgreSQL database dump
--

\restrict thMUqYKNd5St7shRh8Xk6aEkeWidhTMUS8bY3blk9c4J4JgaQS1uS4UOJlHcnXN

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

-- Started on 2025-12-03 01:21:06

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 259 (class 1255 OID 16669)
-- Name: fn_trips_insert_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_trips_insert_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Перевіряємо статус машини
    IF (SELECT status_id FROM vehicles WHERE id = NEW.vehicle_id) <> 1 THEN
        RAISE EXCEPTION 'Vehicle is not available for a new trip';
    END IF;

    -- Міняємо статус на in_use
    UPDATE vehicles
    SET status_id = 2
    WHERE id = NEW.vehicle_id;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_trips_insert_trigger() OWNER TO postgres;

--
-- TOC entry 257 (class 1255 OID 16663)
-- Name: fn_users_update_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_users_update_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.updated_by = NEW.id;  -- СТАВИМО САМОГО СЕБЕ
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_users_update_trigger() OWNER TO postgres;

--
-- TOC entry 258 (class 1255 OID 16665)
-- Name: fn_vehicles_soft_delete_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_vehicles_soft_delete_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Перевіряємо, чи is_deleted стало TRUE
    IF NEW.is_deleted = TRUE AND OLD.is_deleted = FALSE THEN
        -- Оновлюємо дату зміни
        NEW.updated_at := NOW();

        -- Додаємо запис у AUDIT_LOG
        INSERT INTO audit_log (user_id, action, created_at)
        VALUES (NEW.updated_by, 
                'Vehicle ' || NEW.id || ' soft-deleted', 
                NOW());
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_vehicles_soft_delete_trigger() OWNER TO postgres;

--
-- TOC entry 262 (class 1255 OID 16673)
-- Name: get_active_drivers_by_department(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_active_drivers_by_department(p_department_id integer) RETURNS TABLE(driver_id integer, driver_name character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT d.id, u.name
    FROM drivers d
    JOIN users u ON d.user_id = u.id
    WHERE d.is_deleted = false
      AND d.department_id = p_department_id;
END;
$$;


ALTER FUNCTION public.get_active_drivers_by_department(p_department_id integer) OWNER TO postgres;

--
-- TOC entry 260 (class 1255 OID 16671)
-- Name: get_driver_trip_count(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_driver_trip_count(p_driver_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    trip_count integer;
BEGIN
    SELECT COUNT(*) INTO trip_count
    FROM trips
    WHERE driver_id = p_driver_id;

    RETURN trip_count;
END;
$$;


ALTER FUNCTION public.get_driver_trip_count(p_driver_id integer) OWNER TO postgres;

--
-- TOC entry 261 (class 1255 OID 16672)
-- Name: get_vehicle_total_fuel(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_vehicle_total_fuel(p_vehicle_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_fuel numeric;
BEGIN
    SELECT COALESCE(SUM(liters), 0) INTO total_fuel
    FROM fuel_records
    WHERE vehicle_id = p_vehicle_id;

    RETURN total_fuel;
END;
$$;


ALTER FUNCTION public.get_vehicle_total_fuel(p_vehicle_id integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 222 (class 1259 OID 16407)
-- Name: departments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.departments (
    id integer NOT NULL,
    name character varying(255)
);


ALTER TABLE public.departments OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16451)
-- Name: vehicle_status; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vehicle_status (
    id integer NOT NULL,
    name character varying(255)
);


ALTER TABLE public.vehicle_status OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 16443)
-- Name: vehicle_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vehicle_types (
    id integer NOT NULL,
    name character varying(255)
);


ALTER TABLE public.vehicle_types OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 16459)
-- Name: vehicles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vehicles (
    id integer NOT NULL,
    type_id integer,
    status_id integer,
    department_id integer,
    is_deleted boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone,
    updated_by integer
);


ALTER TABLE public.vehicles OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 16679)
-- Name: active_vehicles; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.active_vehicles AS
 SELECT v.id AS vehicle_id,
    vt.name AS vehicle_type,
    vs.name AS vehicle_status,
    d.name AS department_name
   FROM (((public.vehicles v
     JOIN public.vehicle_types vt ON ((v.type_id = vt.id)))
     JOIN public.vehicle_status vs ON ((v.status_id = vs.id)))
     JOIN public.departments d ON ((v.department_id = d.id)))
  WHERE ((v.is_deleted = false) AND ((vs.name)::text = 'available'::text));


ALTER VIEW public.active_vehicles OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 16647)
-- Name: audit_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_log (
    id integer NOT NULL,
    user_id integer,
    action character varying(255),
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.audit_log OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 16646)
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.audit_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_log_id_seq OWNER TO postgres;

--
-- TOC entry 5193 (class 0 OID 0)
-- Dependencies: 251
-- Name: audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.audit_log_id_seq OWNED BY public.audit_log.id;


--
-- TOC entry 221 (class 1259 OID 16406)
-- Name: departments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.departments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.departments_id_seq OWNER TO postgres;

--
-- TOC entry 5194 (class 0 OID 0)
-- Dependencies: 221
-- Name: departments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.departments_id_seq OWNED BY public.departments.id;


--
-- TOC entry 250 (class 1259 OID 16629)
-- Name: driver_license_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.driver_license_categories (
    id integer NOT NULL,
    driver_id integer,
    category_id integer
);


ALTER TABLE public.driver_license_categories OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 16628)
-- Name: driver_license_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.driver_license_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.driver_license_categories_id_seq OWNER TO postgres;

--
-- TOC entry 5195 (class 0 OID 0)
-- Dependencies: 249
-- Name: driver_license_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.driver_license_categories_id_seq OWNED BY public.driver_license_categories.id;


--
-- TOC entry 224 (class 1259 OID 16415)
-- Name: drivers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.drivers (
    id integer NOT NULL,
    user_id integer NOT NULL,
    department_id integer,
    is_deleted boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone,
    updated_by integer
);


ALTER TABLE public.drivers OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 16621)
-- Name: license_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.license_categories (
    id integer NOT NULL,
    code character varying(50)
);


ALTER TABLE public.license_categories OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16390)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    name character varying(255),
    email character varying(255),
    is_deleted boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone,
    updated_by integer
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 16674)
-- Name: driver_license_overview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.driver_license_overview AS
 SELECT u.id AS driver_id,
    u.name AS driver_name,
    string_agg((lc.code)::text, ', '::text) AS license_categories
   FROM (((public.drivers d
     JOIN public.users u ON ((d.user_id = u.id)))
     JOIN public.driver_license_categories dlc ON ((dlc.driver_id = d.id)))
     JOIN public.license_categories lc ON ((dlc.category_id = lc.id)))
  WHERE (d.is_deleted = false)
  GROUP BY u.id, u.name;


ALTER VIEW public.driver_license_overview OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16414)
-- Name: drivers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.drivers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.drivers_id_seq OWNER TO postgres;

--
-- TOC entry 5196 (class 0 OID 0)
-- Dependencies: 223
-- Name: drivers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.drivers_id_seq OWNED BY public.drivers.id;


--
-- TOC entry 242 (class 1259 OID 16570)
-- Name: fuel_records; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fuel_records (
    id integer NOT NULL,
    vehicle_id integer,
    user_id integer,
    liters numeric(10,2),
    price numeric(10,2),
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.fuel_records OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 16569)
-- Name: fuel_records_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fuel_records_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fuel_records_id_seq OWNER TO postgres;

--
-- TOC entry 5197 (class 0 OID 0)
-- Dependencies: 241
-- Name: fuel_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fuel_records_id_seq OWNED BY public.fuel_records.id;


--
-- TOC entry 246 (class 1259 OID 16608)
-- Name: insurance_policies; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.insurance_policies (
    id integer NOT NULL,
    vehicle_id integer,
    policy_number character varying(255),
    expires_at date
);


ALTER TABLE public.insurance_policies OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 16607)
-- Name: insurance_policies_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.insurance_policies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.insurance_policies_id_seq OWNER TO postgres;

--
-- TOC entry 5198 (class 0 OID 0)
-- Dependencies: 245
-- Name: insurance_policies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.insurance_policies_id_seq OWNED BY public.insurance_policies.id;


--
-- TOC entry 247 (class 1259 OID 16620)
-- Name: license_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.license_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.license_categories_id_seq OWNER TO postgres;

--
-- TOC entry 5199 (class 0 OID 0)
-- Dependencies: 247
-- Name: license_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.license_categories_id_seq OWNED BY public.license_categories.id;


--
-- TOC entry 240 (class 1259 OID 16542)
-- Name: maintenance_records; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maintenance_records (
    id integer NOT NULL,
    vehicle_id integer,
    maintenance_type_id integer,
    service_provider_id integer,
    user_id integer,
    performed_at timestamp without time zone
);


ALTER TABLE public.maintenance_records OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 16689)
-- Name: maintenance_due; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.maintenance_due AS
 SELECT v.id AS vehicle_id,
    v.type_id,
    v.status_id,
    v.department_id,
    max(m.performed_at) AS last_maintenance_date
   FROM (public.vehicles v
     LEFT JOIN public.maintenance_records m ON ((v.id = m.vehicle_id)))
  GROUP BY v.id, v.type_id, v.status_id, v.department_id
 HAVING ((max(m.performed_at) IS NULL) OR (max(m.performed_at) < (now() - '6 mons'::interval)));


ALTER VIEW public.maintenance_due OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 16541)
-- Name: maintenance_records_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.maintenance_records_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.maintenance_records_id_seq OWNER TO postgres;

--
-- TOC entry 5200 (class 0 OID 0)
-- Dependencies: 239
-- Name: maintenance_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.maintenance_records_id_seq OWNED BY public.maintenance_records.id;


--
-- TOC entry 236 (class 1259 OID 16526)
-- Name: maintenance_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maintenance_types (
    id integer NOT NULL,
    name character varying(255)
);


ALTER TABLE public.maintenance_types OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 16525)
-- Name: maintenance_types_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.maintenance_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.maintenance_types_id_seq OWNER TO postgres;

--
-- TOC entry 5201 (class 0 OID 0)
-- Dependencies: 235
-- Name: maintenance_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.maintenance_types_id_seq OWNED BY public.maintenance_types.id;


--
-- TOC entry 232 (class 1259 OID 16489)
-- Name: routes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.routes (
    id integer NOT NULL,
    name character varying(255),
    is_deleted boolean DEFAULT false,
    updated_at timestamp without time zone,
    updated_by integer
);


ALTER TABLE public.routes OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 16503)
-- Name: trips; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trips (
    id integer NOT NULL,
    driver_id integer,
    vehicle_id integer,
    route_id integer,
    start_time timestamp without time zone,
    end_time timestamp without time zone
);


ALTER TABLE public.trips OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 16684)
-- Name: recent_trips; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.recent_trips AS
 SELECT t.id AS trip_id,
    d.name AS driver_name,
    v.id AS vehicle_id,
    r.name AS route_name,
    t.start_time,
    t.end_time
   FROM ((((public.trips t
     JOIN public.drivers dr ON ((t.driver_id = dr.id)))
     JOIN public.users d ON ((dr.user_id = d.id)))
     JOIN public.vehicles v ON ((t.vehicle_id = v.id)))
     JOIN public.routes r ON ((t.route_id = r.id)))
  WHERE (t.start_time >= (now() - '30 days'::interval));


ALTER VIEW public.recent_trips OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 16488)
-- Name: routes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.routes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.routes_id_seq OWNER TO postgres;

--
-- TOC entry 5202 (class 0 OID 0)
-- Dependencies: 231
-- Name: routes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.routes_id_seq OWNED BY public.routes.id;


--
-- TOC entry 238 (class 1259 OID 16534)
-- Name: service_providers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.service_providers (
    id integer NOT NULL,
    name character varying(255)
);


ALTER TABLE public.service_providers OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 16533)
-- Name: service_providers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.service_providers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.service_providers_id_seq OWNER TO postgres;

--
-- TOC entry 5203 (class 0 OID 0)
-- Dependencies: 237
-- Name: service_providers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.service_providers_id_seq OWNED BY public.service_providers.id;


--
-- TOC entry 233 (class 1259 OID 16502)
-- Name: trips_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.trips_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trips_id_seq OWNER TO postgres;

--
-- TOC entry 5204 (class 0 OID 0)
-- Dependencies: 233
-- Name: trips_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.trips_id_seq OWNED BY public.trips.id;


--
-- TOC entry 219 (class 1259 OID 16389)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- TOC entry 5205 (class 0 OID 0)
-- Dependencies: 219
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 244 (class 1259 OID 16589)
-- Name: vehicle_documents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vehicle_documents (
    id integer NOT NULL,
    vehicle_id integer,
    name character varying(255),
    is_deleted boolean DEFAULT false,
    updated_at timestamp without time zone,
    updated_by integer
);


ALTER TABLE public.vehicle_documents OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 16588)
-- Name: vehicle_documents_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vehicle_documents_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vehicle_documents_id_seq OWNER TO postgres;

--
-- TOC entry 5206 (class 0 OID 0)
-- Dependencies: 243
-- Name: vehicle_documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vehicle_documents_id_seq OWNED BY public.vehicle_documents.id;


--
-- TOC entry 227 (class 1259 OID 16450)
-- Name: vehicle_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vehicle_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vehicle_status_id_seq OWNER TO postgres;

--
-- TOC entry 5207 (class 0 OID 0)
-- Dependencies: 227
-- Name: vehicle_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vehicle_status_id_seq OWNED BY public.vehicle_status.id;


--
-- TOC entry 225 (class 1259 OID 16442)
-- Name: vehicle_types_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vehicle_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vehicle_types_id_seq OWNER TO postgres;

--
-- TOC entry 5208 (class 0 OID 0)
-- Dependencies: 225
-- Name: vehicle_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vehicle_types_id_seq OWNED BY public.vehicle_types.id;


--
-- TOC entry 229 (class 1259 OID 16458)
-- Name: vehicles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vehicles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vehicles_id_seq OWNER TO postgres;

--
-- TOC entry 5209 (class 0 OID 0)
-- Dependencies: 229
-- Name: vehicles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vehicles_id_seq OWNED BY public.vehicles.id;


--
-- TOC entry 4936 (class 2604 OID 16650)
-- Name: audit_log id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN id SET DEFAULT nextval('public.audit_log_id_seq'::regclass);


--
-- TOC entry 4914 (class 2604 OID 16410)
-- Name: departments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments ALTER COLUMN id SET DEFAULT nextval('public.departments_id_seq'::regclass);


--
-- TOC entry 4935 (class 2604 OID 16632)
-- Name: driver_license_categories id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_license_categories ALTER COLUMN id SET DEFAULT nextval('public.driver_license_categories_id_seq'::regclass);


--
-- TOC entry 4915 (class 2604 OID 16418)
-- Name: drivers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers ALTER COLUMN id SET DEFAULT nextval('public.drivers_id_seq'::regclass);


--
-- TOC entry 4929 (class 2604 OID 16573)
-- Name: fuel_records id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fuel_records ALTER COLUMN id SET DEFAULT nextval('public.fuel_records_id_seq'::regclass);


--
-- TOC entry 4933 (class 2604 OID 16611)
-- Name: insurance_policies id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.insurance_policies ALTER COLUMN id SET DEFAULT nextval('public.insurance_policies_id_seq'::regclass);


--
-- TOC entry 4934 (class 2604 OID 16624)
-- Name: license_categories id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.license_categories ALTER COLUMN id SET DEFAULT nextval('public.license_categories_id_seq'::regclass);


--
-- TOC entry 4928 (class 2604 OID 16545)
-- Name: maintenance_records id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenance_records ALTER COLUMN id SET DEFAULT nextval('public.maintenance_records_id_seq'::regclass);


--
-- TOC entry 4926 (class 2604 OID 16529)
-- Name: maintenance_types id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenance_types ALTER COLUMN id SET DEFAULT nextval('public.maintenance_types_id_seq'::regclass);


--
-- TOC entry 4923 (class 2604 OID 16492)
-- Name: routes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.routes ALTER COLUMN id SET DEFAULT nextval('public.routes_id_seq'::regclass);


--
-- TOC entry 4927 (class 2604 OID 16537)
-- Name: service_providers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_providers ALTER COLUMN id SET DEFAULT nextval('public.service_providers_id_seq'::regclass);


--
-- TOC entry 4925 (class 2604 OID 16506)
-- Name: trips id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trips ALTER COLUMN id SET DEFAULT nextval('public.trips_id_seq'::regclass);


--
-- TOC entry 4911 (class 2604 OID 16393)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 4931 (class 2604 OID 16592)
-- Name: vehicle_documents id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicle_documents ALTER COLUMN id SET DEFAULT nextval('public.vehicle_documents_id_seq'::regclass);


--
-- TOC entry 4919 (class 2604 OID 16454)
-- Name: vehicle_status id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicle_status ALTER COLUMN id SET DEFAULT nextval('public.vehicle_status_id_seq'::regclass);


--
-- TOC entry 4918 (class 2604 OID 16446)
-- Name: vehicle_types id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicle_types ALTER COLUMN id SET DEFAULT nextval('public.vehicle_types_id_seq'::regclass);


--
-- TOC entry 4920 (class 2604 OID 16462)
-- Name: vehicles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicles ALTER COLUMN id SET DEFAULT nextval('public.vehicles_id_seq'::regclass);


--
-- TOC entry 5187 (class 0 OID 16647)
-- Dependencies: 252
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_log (id, user_id, action, created_at) FROM stdin;
1	1	Vehicle 1 soft-deleted	2025-12-02 01:20:16.373929
\.


--
-- TOC entry 5157 (class 0 OID 16407)
-- Dependencies: 222
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.departments (id, name) FROM stdin;
1	Test department1
3	Test department3
2	Test department2
\.


--
-- TOC entry 5185 (class 0 OID 16629)
-- Dependencies: 250
-- Data for Name: driver_license_categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.driver_license_categories (id, driver_id, category_id) FROM stdin;
1	1	1
2	2	2
3	3	3
\.


--
-- TOC entry 5159 (class 0 OID 16415)
-- Dependencies: 224
-- Data for Name: drivers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.drivers (id, user_id, department_id, is_deleted, created_at, updated_at, updated_by) FROM stdin;
1	1	1	f	2025-12-02 01:24:24.491486	\N	\N
2	2	2	f	2025-12-02 01:26:59.534119	\N	\N
3	3	3	f	2025-12-02 01:26:59.542049	\N	\N
\.


--
-- TOC entry 5177 (class 0 OID 16570)
-- Dependencies: 242
-- Data for Name: fuel_records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.fuel_records (id, vehicle_id, user_id, liters, price, created_at) FROM stdin;
1	1	1	20.00	120.00	2025-12-02 01:43:35.197127
\.


--
-- TOC entry 5181 (class 0 OID 16608)
-- Dependencies: 246
-- Data for Name: insurance_policies; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.insurance_policies (id, vehicle_id, policy_number, expires_at) FROM stdin;
\.


--
-- TOC entry 5183 (class 0 OID 16621)
-- Dependencies: 248
-- Data for Name: license_categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.license_categories (id, code) FROM stdin;
1	A
2	B
3	C
4	D
\.


--
-- TOC entry 5175 (class 0 OID 16542)
-- Dependencies: 240
-- Data for Name: maintenance_records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.maintenance_records (id, vehicle_id, maintenance_type_id, service_provider_id, user_id, performed_at) FROM stdin;
1	1	1	1	1	2025-12-02 02:12:43.520985
\.


--
-- TOC entry 5171 (class 0 OID 16526)
-- Dependencies: 236
-- Data for Name: maintenance_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.maintenance_types (id, name) FROM stdin;
1	Test maint1
2	Test maint2
3	Test maint3
\.


--
-- TOC entry 5167 (class 0 OID 16489)
-- Dependencies: 232
-- Data for Name: routes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.routes (id, name, is_deleted, updated_at, updated_by) FROM stdin;
1	Test route1	f	\N	\N
2	Test route2	f	\N	\N
3	Test route2	f	\N	\N
\.


--
-- TOC entry 5173 (class 0 OID 16534)
-- Dependencies: 238
-- Data for Name: service_providers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.service_providers (id, name) FROM stdin;
1	Test prov1
2	Test prov2
3	Test prov3
\.


--
-- TOC entry 5169 (class 0 OID 16503)
-- Dependencies: 234
-- Data for Name: trips; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trips (id, driver_id, vehicle_id, route_id, start_time, end_time) FROM stdin;
2	1	1	1	2025-12-02 01:34:19.178241	2025-12-02 03:34:19.178241
7	1	1	1	2025-12-02 01:37:25.530344	2025-12-02 03:37:25.530344
\.


--
-- TOC entry 5155 (class 0 OID 16390)
-- Dependencies: 220
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, name, email, is_deleted, created_at, updated_at, updated_by) FROM stdin;
2	Test User2	test2@example.com	f	2025-12-02 01:26:30.350191	\N	\N
3	Test User3	test3@example.com	f	2025-12-02 01:26:30.352528	\N	\N
1	Test User1	test1@example.com	f	2025-12-02 01:16:42.004471	2025-12-02 01:26:30.354225	1
\.


--
-- TOC entry 5179 (class 0 OID 16589)
-- Dependencies: 244
-- Data for Name: vehicle_documents; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vehicle_documents (id, vehicle_id, name, is_deleted, updated_at, updated_by) FROM stdin;
\.


--
-- TOC entry 5163 (class 0 OID 16451)
-- Dependencies: 228
-- Data for Name: vehicle_status; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vehicle_status (id, name) FROM stdin;
2	in use
3	maintenance
1	available
\.


--
-- TOC entry 5161 (class 0 OID 16443)
-- Dependencies: 226
-- Data for Name: vehicle_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vehicle_types (id, name) FROM stdin;
2	Test type2
3	Test type3
1	Test type1
\.


--
-- TOC entry 5165 (class 0 OID 16459)
-- Dependencies: 230
-- Data for Name: vehicles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vehicles (id, type_id, status_id, department_id, is_deleted, created_at, updated_at, updated_by) FROM stdin;
2	2	2	2	f	2025-12-02 01:30:45.653884	\N	\N
3	3	3	3	f	2025-12-02 01:30:45.656607	\N	\N
1	1	1	1	f	2025-12-02 01:20:01.303415	2025-12-02 01:20:16.373929	1
\.


--
-- TOC entry 5210 (class 0 OID 0)
-- Dependencies: 251
-- Name: audit_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.audit_log_id_seq', 1, true);


--
-- TOC entry 5211 (class 0 OID 0)
-- Dependencies: 221
-- Name: departments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.departments_id_seq', 1, false);


--
-- TOC entry 5212 (class 0 OID 0)
-- Dependencies: 249
-- Name: driver_license_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.driver_license_categories_id_seq', 1, false);


--
-- TOC entry 5213 (class 0 OID 0)
-- Dependencies: 223
-- Name: drivers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.drivers_id_seq', 1, false);


--
-- TOC entry 5214 (class 0 OID 0)
-- Dependencies: 241
-- Name: fuel_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.fuel_records_id_seq', 1, false);


--
-- TOC entry 5215 (class 0 OID 0)
-- Dependencies: 245
-- Name: insurance_policies_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.insurance_policies_id_seq', 1, false);


--
-- TOC entry 5216 (class 0 OID 0)
-- Dependencies: 247
-- Name: license_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.license_categories_id_seq', 1, false);


--
-- TOC entry 5217 (class 0 OID 0)
-- Dependencies: 239
-- Name: maintenance_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.maintenance_records_id_seq', 1, false);


--
-- TOC entry 5218 (class 0 OID 0)
-- Dependencies: 235
-- Name: maintenance_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.maintenance_types_id_seq', 1, false);


--
-- TOC entry 5219 (class 0 OID 0)
-- Dependencies: 231
-- Name: routes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.routes_id_seq', 1, false);


--
-- TOC entry 5220 (class 0 OID 0)
-- Dependencies: 237
-- Name: service_providers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_providers_id_seq', 1, false);


--
-- TOC entry 5221 (class 0 OID 0)
-- Dependencies: 233
-- Name: trips_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.trips_id_seq', 7, true);


--
-- TOC entry 5222 (class 0 OID 0)
-- Dependencies: 219
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 1, true);


--
-- TOC entry 5223 (class 0 OID 0)
-- Dependencies: 243
-- Name: vehicle_documents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.vehicle_documents_id_seq', 1, false);


--
-- TOC entry 5224 (class 0 OID 0)
-- Dependencies: 227
-- Name: vehicle_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.vehicle_status_id_seq', 1, false);


--
-- TOC entry 5225 (class 0 OID 0)
-- Dependencies: 225
-- Name: vehicle_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.vehicle_types_id_seq', 1, false);


--
-- TOC entry 5226 (class 0 OID 0)
-- Dependencies: 229
-- Name: vehicles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.vehicles_id_seq', 1, false);


--
-- TOC entry 4975 (class 2606 OID 16654)
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- TOC entry 4942 (class 2606 OID 16413)
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- TOC entry 4973 (class 2606 OID 16635)
-- Name: driver_license_categories driver_license_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_license_categories
    ADD CONSTRAINT driver_license_categories_pkey PRIMARY KEY (id);


--
-- TOC entry 4944 (class 2606 OID 16424)
-- Name: drivers drivers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_pkey PRIMARY KEY (id);


--
-- TOC entry 4946 (class 2606 OID 16426)
-- Name: drivers drivers_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_user_id_key UNIQUE (user_id);


--
-- TOC entry 4965 (class 2606 OID 16577)
-- Name: fuel_records fuel_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fuel_records
    ADD CONSTRAINT fuel_records_pkey PRIMARY KEY (id);


--
-- TOC entry 4969 (class 2606 OID 16614)
-- Name: insurance_policies insurance_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.insurance_policies
    ADD CONSTRAINT insurance_policies_pkey PRIMARY KEY (id);


--
-- TOC entry 4971 (class 2606 OID 16627)
-- Name: license_categories license_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.license_categories
    ADD CONSTRAINT license_categories_pkey PRIMARY KEY (id);


--
-- TOC entry 4963 (class 2606 OID 16548)
-- Name: maintenance_records maintenance_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenance_records
    ADD CONSTRAINT maintenance_records_pkey PRIMARY KEY (id);


--
-- TOC entry 4959 (class 2606 OID 16532)
-- Name: maintenance_types maintenance_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenance_types
    ADD CONSTRAINT maintenance_types_pkey PRIMARY KEY (id);


--
-- TOC entry 4954 (class 2606 OID 16496)
-- Name: routes routes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT routes_pkey PRIMARY KEY (id);


--
-- TOC entry 4961 (class 2606 OID 16540)
-- Name: service_providers service_providers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_providers
    ADD CONSTRAINT service_providers_pkey PRIMARY KEY (id);


--
-- TOC entry 4956 (class 2606 OID 16509)
-- Name: trips trips_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT trips_pkey PRIMARY KEY (id);


--
-- TOC entry 4940 (class 2606 OID 16400)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 4967 (class 2606 OID 16596)
-- Name: vehicle_documents vehicle_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicle_documents
    ADD CONSTRAINT vehicle_documents_pkey PRIMARY KEY (id);


--
-- TOC entry 4950 (class 2606 OID 16457)
-- Name: vehicle_status vehicle_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicle_status
    ADD CONSTRAINT vehicle_status_pkey PRIMARY KEY (id);


--
-- TOC entry 4948 (class 2606 OID 16449)
-- Name: vehicle_types vehicle_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicle_types
    ADD CONSTRAINT vehicle_types_pkey PRIMARY KEY (id);


--
-- TOC entry 4952 (class 2606 OID 16467)
-- Name: vehicles vehicles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_pkey PRIMARY KEY (id);


--
-- TOC entry 4957 (class 1259 OID 16695)
-- Name: idx_maintenance_types_name_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_maintenance_types_name_gin ON public.maintenance_types USING gin (to_tsvector('english'::regconfig, (name)::text));


--
-- TOC entry 4938 (class 1259 OID 16694)
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- TOC entry 5002 (class 2620 OID 16670)
-- Name: trips trg_trips_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_trips_insert BEFORE INSERT ON public.trips FOR EACH ROW EXECUTE FUNCTION public.fn_trips_insert_trigger();


--
-- TOC entry 5000 (class 2620 OID 16664)
-- Name: users trg_users_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_users_update BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.fn_users_update_trigger();


--
-- TOC entry 5001 (class 2620 OID 16666)
-- Name: vehicles trg_vehicles_soft_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_vehicles_soft_delete BEFORE UPDATE ON public.vehicles FOR EACH ROW EXECUTE FUNCTION public.fn_vehicles_soft_delete_trigger();


--
-- TOC entry 4999 (class 2606 OID 16655)
-- Name: audit_log fk_audit_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 4994 (class 2606 OID 16602)
-- Name: vehicle_documents fk_docs_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicle_documents
    ADD CONSTRAINT fk_docs_updated_by FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- TOC entry 4995 (class 2606 OID 16597)
-- Name: vehicle_documents fk_docs_vehicle; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicle_documents
    ADD CONSTRAINT fk_docs_vehicle FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id);


--
-- TOC entry 4997 (class 2606 OID 16641)
-- Name: driver_license_categories fk_driver_category_category; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_license_categories
    ADD CONSTRAINT fk_driver_category_category FOREIGN KEY (category_id) REFERENCES public.license_categories(id);


--
-- TOC entry 4998 (class 2606 OID 16636)
-- Name: driver_license_categories fk_driver_category_driver; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_license_categories
    ADD CONSTRAINT fk_driver_category_driver FOREIGN KEY (driver_id) REFERENCES public.drivers(id);


--
-- TOC entry 4977 (class 2606 OID 16432)
-- Name: drivers fk_drivers_department; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT fk_drivers_department FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- TOC entry 4978 (class 2606 OID 16437)
-- Name: drivers fk_drivers_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT fk_drivers_updated_by FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- TOC entry 4979 (class 2606 OID 16427)
-- Name: drivers fk_drivers_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT fk_drivers_user FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 4992 (class 2606 OID 16583)
-- Name: fuel_records fk_fuel_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fuel_records
    ADD CONSTRAINT fk_fuel_user FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 4993 (class 2606 OID 16578)
-- Name: fuel_records fk_fuel_vehicle; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fuel_records
    ADD CONSTRAINT fk_fuel_vehicle FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id);


--
-- TOC entry 4996 (class 2606 OID 16615)
-- Name: insurance_policies fk_insurance_vehicle; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.insurance_policies
    ADD CONSTRAINT fk_insurance_vehicle FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id);


--
-- TOC entry 4988 (class 2606 OID 16559)
-- Name: maintenance_records fk_maintenance_provider; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenance_records
    ADD CONSTRAINT fk_maintenance_provider FOREIGN KEY (service_provider_id) REFERENCES public.service_providers(id);


--
-- TOC entry 4989 (class 2606 OID 16554)
-- Name: maintenance_records fk_maintenance_type; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenance_records
    ADD CONSTRAINT fk_maintenance_type FOREIGN KEY (maintenance_type_id) REFERENCES public.maintenance_types(id);


--
-- TOC entry 4990 (class 2606 OID 16564)
-- Name: maintenance_records fk_maintenance_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenance_records
    ADD CONSTRAINT fk_maintenance_user FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 4991 (class 2606 OID 16549)
-- Name: maintenance_records fk_maintenance_vehicle; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenance_records
    ADD CONSTRAINT fk_maintenance_vehicle FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id);


--
-- TOC entry 4984 (class 2606 OID 16497)
-- Name: routes fk_routes_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT fk_routes_updated_by FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- TOC entry 4985 (class 2606 OID 16510)
-- Name: trips fk_trips_driver; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT fk_trips_driver FOREIGN KEY (driver_id) REFERENCES public.drivers(id);


--
-- TOC entry 4986 (class 2606 OID 16520)
-- Name: trips fk_trips_route; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT fk_trips_route FOREIGN KEY (route_id) REFERENCES public.routes(id);


--
-- TOC entry 4987 (class 2606 OID 16515)
-- Name: trips fk_trips_vehicle; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT fk_trips_vehicle FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id);


--
-- TOC entry 4976 (class 2606 OID 16401)
-- Name: users fk_users_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_users_updated_by FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- TOC entry 4980 (class 2606 OID 16478)
-- Name: vehicles fk_vehicles_department; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT fk_vehicles_department FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- TOC entry 4981 (class 2606 OID 16473)
-- Name: vehicles fk_vehicles_status; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT fk_vehicles_status FOREIGN KEY (status_id) REFERENCES public.vehicle_status(id);


--
-- TOC entry 4982 (class 2606 OID 16468)
-- Name: vehicles fk_vehicles_type; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT fk_vehicles_type FOREIGN KEY (type_id) REFERENCES public.vehicle_types(id);


--
-- TOC entry 4983 (class 2606 OID 16483)
-- Name: vehicles fk_vehicles_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT fk_vehicles_updated_by FOREIGN KEY (updated_by) REFERENCES public.users(id);


-- Completed on 2025-12-03 01:21:06

--
-- PostgreSQL database dump complete
--

\unrestrict thMUqYKNd5St7shRh8Xk6aEkeWidhTMUS8bY3blk9c4J4JgaQS1uS4UOJlHcnXN

