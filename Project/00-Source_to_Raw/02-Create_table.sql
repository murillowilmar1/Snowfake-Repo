
---- 1 

CREATE OR REPLACE PROCEDURE DATAENGINNER.PUBLIC.CLONE_TABLE_STRUCTURE(
  SRC_DB STRING,
  SRC_SCHEMA STRING,
  SRC_TABLE STRING,
  TGT_DB STRING,
  TGT_SCHEMA STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
  v_sql STRING;
  v_rs RESULTSET;
  v_stmt STRING;
BEGIN

  -- 1️ Crear tabla respetando tipos (CTAS)
  v_sql :=
    'CREATE OR REPLACE TABLE ' || TGT_DB || '.' || TGT_SCHEMA || '.' || SRC_TABLE ||
    ' AS SELECT * FROM ' || SRC_DB || '.' || SRC_SCHEMA || '.' || SRC_TABLE || ' WHERE 1=0';

  EXECUTE IMMEDIATE v_sql;

  -- 2️ Query dinámica para columnas NOT NULL
  v_stmt :=
    'SELECT COLUMN_NAME
     FROM ' || SRC_DB || '.INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = ''' || SRC_SCHEMA || '''
       AND TABLE_NAME = ''' || SRC_TABLE || '''
       AND IS_NULLABLE = ''NO''';

  v_rs := (EXECUTE IMMEDIATE v_stmt);

  -- 3️ Reaplicar NOT NULL
  FOR rec IN v_rs DO
    EXECUTE IMMEDIATE
      'ALTER TABLE ' || TGT_DB || '.' || TGT_SCHEMA || '.' || SRC_TABLE ||
      ' MODIFY COLUMN ' || rec.COLUMN_NAME || ' SET NOT NULL';
  END FOR;

  RETURN 'OK';

END;
$$;

---- 2 
CREATE OR REPLACE PROCEDURE DATAENGINNER.PUBLIC.RUN_TABLE_LOADS_JS()
RETURNS STRING
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
function toSnowflakeTimestamp(jsDate) {
  if (jsDate === null) return null;
  return jsDate.toISOString().replace('T', ' ').replace('Z', '');
}

function toSnowflakeDate(jsDate) {
  if (jsDate === null) return null;
  return jsDate.toISOString().substring(0, 10);
}

var sqlText = `
  SELECT
    src_db,
    src_schema,
    src_table,
    tgt_db,
    tgt_schema,
    tgt_table,
    load_type,
    delta_column,
    min_date,
    last_processed_value
  FROM DATAENGINNER.PUBLIC.CONTROL_TABLE_LOAD_CONFIG
  WHERE enabled = TRUE
`;

var rs = snowflake.createStatement({ sqlText }).execute();

while (rs.next()) {

  // ===== METADATA =====
  var srcDb = rs.getColumnValue("SRC_DB");
  var srcSchema = rs.getColumnValue("SRC_SCHEMA");
  var srcTable = rs.getColumnValue("SRC_TABLE");
  var tgtDb = rs.getColumnValue("TGT_DB");
  var tgtSchema = rs.getColumnValue("TGT_SCHEMA");
  var tgtTable = rs.getColumnValue("TGT_TABLE");
  var loadType = rs.getColumnValue("LOAD_TYPE");
  var deltaColumn = rs.getColumnValue("DELTA_COLUMN");

  var minDateRaw = rs.getColumnValue("MIN_DATE");
  var minDate = minDateRaw ? toSnowflakeDate(minDateRaw) : null;

  var lastProcessedRaw = rs.getColumnValue("LAST_PROCESSED_VALUE");
  var lastProcessed = lastProcessedRaw ? toSnowflakeTimestamp(lastProcessedRaw) : null;

  // ===== 1️ CLONAR ESTRUCTURA =====
  var cloneSql = `
    CALL DATAENGINNER.PUBLIC.CLONE_TABLE_STRUCTURE(
      '${srcDb}',
      '${srcSchema}',
      '${srcTable}',
      '${tgtDb}',
      '${tgtSchema}'
    )
  `;
  snowflake.createStatement({ sqlText: cloneSql }).execute();

  // ===== 2️ FULL LOAD =====
  if (loadType === 'FULL') {

    var fullSql = `
      INSERT INTO ${tgtDb}.${tgtSchema}.${tgtTable}
      SELECT * FROM ${srcDb}.${srcSchema}.${srcTable}
    `;
    snowflake.createStatement({ sqlText: fullSql }).execute();
    continue;
  }

  // ===== 3️ DELTA LOAD =====
  if (loadType === 'DELTA') {

    // 3.1 MAX real de la fuente
    var maxSql = `
      SELECT MAX(${deltaColumn}) AS MAX_VAL
      FROM ${srcDb}.${srcSchema}.${srcTable}
    `;
    var rsMax = snowflake.createStatement({ sqlText: maxSql }).execute();
    rsMax.next();

    var maxSourceRaw = rsMax.getColumnValue("MAX_VAL");
    if (maxSourceRaw === null) {
      continue;
    }

    var maxSourceValue = toSnowflakeTimestamp(maxSourceRaw);

    // 3.2 Fecha inicio
    var startValue = lastProcessed ? lastProcessed : minDate;

    // 3.3 Insert incremental
    var deltaSql = `
      INSERT INTO ${tgtDb}.${tgtSchema}.${tgtTable}
      SELECT * FROM ${srcDb}.${srcSchema}.${srcTable}
      WHERE ${deltaColumn} > '${startValue}'
        AND ${deltaColumn} <= '${maxSourceValue}'
    `;
    snowflake.createStatement({ sqlText: deltaSql }).execute();

    // 3.4 Update watermark
    var updateSql = `
      UPDATE DATAENGINNER.PUBLIC.CONTROL_TABLE_LOAD_CONFIG
      SET last_processed_value = '${maxSourceValue}',
          updated_at = CURRENT_TIMESTAMP
      WHERE src_db = '${srcDb}'
        AND src_schema = '${srcSchema}'
        AND src_table = '${srcTable}'
    `;
    snowflake.createStatement({ sqlText: updateSql }).execute();
  }
}

return 'OK';
$$;


CALL DATAENGINNER.PUBLIC.RUN_TABLE_LOADS_JS();







