CREATE DATABASE sqs_entity_resolution;
    --WITH
    --OWNER = senzing;

\connect sqs_entity_resolution

CREATE TABLE public.export_tracker
(
    ts timestamp without time zone NOT NULL default current_timestamp,
    entity_id bigint NOT NULL,
    export_status smallint NOT NULL DEFAULT 0,
    export_id character varying
)
