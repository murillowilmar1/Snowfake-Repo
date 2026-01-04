CREATE OR REPLACE TABLE DATAENGINNER.PUBLIC.CONTROL_TABLE_LOAD_CONFIG (
  src_db                STRING,
  src_schema            STRING,
  src_table             STRING,

  tgt_db                STRING,
  tgt_schema            STRING,
  tgt_table             STRING,

  enabled               BOOLEAN,         -- 1 = se procesa, 0 = se ignora

  load_type              STRING,          -- FULL / DELTA
  delta_column           STRING,          -- columna de fecha para incremental

  min_date               DATE,            -- histórico inicial
  max_date               DATE,            -- histórico final (opcional)
  last_processed_value   TIMESTAMP_NTZ,   -- watermark

  created_at             TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at             TIMESTAMP_NTZ
);


INSERT INTO DATAENGINNER.PUBLIC.CONTROL_TABLE_LOAD_CONFIG (
  src_db,
  src_schema,
  src_table,
  tgt_db,
  tgt_schema,
  tgt_table,
  enabled,
  load_type,
  delta_column,
  min_date,
  max_date,
  last_processed_value
)
VALUES
(
  'SNOWFLAKE_SAMPLE_DATA','TPCH_SF100','ORDERS',
  'SNOWFLAKE_DEV','RAW','ORDERS',
  TRUE,'DELTA','O_ORDERDATE','1992-01-01','1994-01-01',NULL
)
, 

(
  'SNOWFLAKE_SAMPLE_DATA','TPCH_SF100','CUSTOMER',
  'SNOWFLAKE_DEV','RAW','CUSTOMER',
  TRUE,'FULL',NULL,NULL,NULL,NULL
)



SELECT * FROM DATAENGINNER.PUBLIC.CONTROL_TABLE_LOAD_CONFIG
DELETE FROM DATAENGINNER.PUBLIC.CONTROL_TABLE_LOAD_CONFIG WHERE SRC_TABLE = 'ORDERS'