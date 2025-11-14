-- Run once (idempotent drops are fine if you prefer)
CREATE OR REPLACE TYPE t_varchar2_320_tab AS TABLE OF VARCHAR2(320);
/
CREATE OR REPLACE TYPE t_varchar2_64_tab  AS TABLE OF VARCHAR2(64);
/
CREATE OR REPLACE TYPE obj_stage_row AS OBJECT (
  batch_id       NUMBER,
  row_num        NUMBER,
  customer_email VARCHAR2(320),
  customer_name  VARCHAR2(200),
  product_sku    VARCHAR2(64),
  product_name   VARCHAR2(200),
  unit_cents     NUMBER,
  qty            NUMBER,
  order_ts       TIMESTAMP
);
/
CREATE OR REPLACE TYPE tab_stage_row AS TABLE OF obj_stage_row;
/
