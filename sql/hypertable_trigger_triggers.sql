-- Creates a trigger on all chunk for a hypertable.
-- static
CREATE OR REPLACE FUNCTION _timescaledb_internal.create_trigger_on_all_chunks(
    hypertable_id INTEGER,
    hypertable_index_id    INTEGER,
    trigger_name     NAME,
    definition       TEXT
)
    RETURNS VOID LANGUAGE PLPGSQL VOLATILE AS
$BODY$
DECLARE
BEGIN
    PERFORM _timescaledb_internal.create_chunk_trigger_row(c.id, hypertable_index_id, trigger_name, definition)
    FROM _timescaledb_catalog.chunk c
    WHERE c.hypertable_id = create_trigger_on_all_chunks.hypertable_id;
END
$BODY$;

-- Drops trigger on all chunks for a hypertable.
-- static
CREATE OR REPLACE FUNCTION _timescaledb_internal.drop_trigger_on_all_chunks(
    hypertable_trigger_id INTEGER
)
    RETURNS VOID LANGUAGE SQL VOLATILE AS
$BODY$
    DELETE FROM _timescaledb_catalog.chunk_trigger ci
    WHERE ci.hypertable_trigger_id = drop_trigger_on_all_chunks.hypertable_trigger_id;
$BODY$;


-- Creates triggeres on chunk tables when hypertable_trigger rows created.
CREATE OR REPLACE FUNCTION _timescaledb_internal.on_change_hypertable_trigger()
    RETURNS TRIGGER LANGUAGE PLPGSQL AS
$BODY$
DECLARE
  hypertable_row _timescaledb_catalog.hypertable;
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- create trigger on all chunks
        PERFORM _timescaledb_internal.create_trigger_on_all_chunks(NEW.hypertable_id, NEW.id, NEW.trigger_name, NEW.definition);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM _timescaledb_internal.drop_trigger_on_all_chunks(OLD.id);
        RETURN OLD;
    END IF;
    PERFORM _timescaledb_internal.on_trigger_error(TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME);
END
$BODY$;


