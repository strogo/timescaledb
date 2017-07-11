-- Convert a general trigger definition to a create trigger sql command for a
-- particular table and trigger name.
-- static
CREATE OR REPLACE FUNCTION _timescaledb_internal.get_trigger_definition_for_table(
    chunk_id INTEGER,
    general_defintion TEXT
  )
    RETURNS TEXT LANGUAGE PLPGSQL AS
$BODY$
DECLARE
    chunk_row _timescaledb_catalog.chunk;
    sql_code TEXT;
BEGIN
    SELECT * INTO STRICT chunk_row FROM _timescaledb_catalog.chunk WHERE id = chunk_id;
    sql_code := replace(general_defintion, '/*TABLE_NAME*/', format('%I.%I', chunk_row.schema_name, chunk_row.table_name));
    RETURN sql_code;
END
$BODY$;

-- Creates a chunk_trigger_row.
CREATE OR REPLACE FUNCTION _timescaledb_internal.create_chunk_trigger_row(
    chunk_id INTEGER,
    hypertable_trigger_id INTEGER,
    trigger_name NAME,
    def TEXT
)
    RETURNS VOID LANGUAGE PLPGSQL AS
$BODY$
DECLARE
    sql_code    TEXT;
BEGIN
    sql_code := _timescaledb_internal.get_trigger_definition_for_table(chunk_id, def);
    INSERT INTO _timescaledb_catalog.chunk_trigger (chunk_id, hypertable_trigger_id, trigger_name, definition)
    VALUES (chunk_id, hypertable_trigger_id, trigger_name, sql_code);
END
$BODY$;

CREATE OR REPLACE FUNCTION _timescaledb_internal.on_change_chunk_trigger()
    RETURNS TRIGGER LANGUAGE PLPGSQL AS
$BODY$
DECLARE
    chunk_row _timescaledb_catalog.chunk;
BEGIN
    IF TG_OP = 'INSERT' THEN
        EXECUTE NEW.definition;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        SELECT * INTO chunk_row FROM _timescaledb_catalog.chunk WHERE id = OLD.chunk_id;
        IF FOUND THEN 
            EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I.%I', OLD.trigger_name, chunk_row.schema_name, chunk_row.table_name);
        END IF;
        RETURN OLD;
    END IF;

    PERFORM _timescaledb_internal.on_trigger_error(TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME);
END
$BODY$;
