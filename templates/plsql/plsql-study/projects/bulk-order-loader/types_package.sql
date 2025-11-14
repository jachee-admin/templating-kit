CREATE OR REPLACE PACKAGE tp_bulk AS
  TYPE t_email_tab       IS TABLE OF VARCHAR2(320);
  TYPE t_sku_tab         IS TABLE OF VARCHAR2(64);
  TYPE t_num_tab         IS TABLE OF NUMBER;

  TYPE r_stage_row IS RECORD(
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
  TYPE nt_stage_row IS TABLE OF r_stage_row;

  TYPE t_email_to_id IS TABLE OF NUMBER INDEX BY VARCHAR2(320);
  TYPE t_sku_to_id   IS TABLE OF NUMBER INDEX BY VARCHAR2(64);

  -- MERGE-friendly dense records
  TYPE r_customer_upsert   IS RECORD(email VARCHAR2(320), full_name VARCHAR2(200));
  TYPE nt_customer_upsert  IS TABLE OF r_customer_upsert;

  TYPE r_product_upsert    IS RECORD(sku VARCHAR2(64), name VARCHAR2(200), price_cents NUMBER);
  TYPE nt_product_upsert   IS TABLE OF r_product_upsert;
END tp_bulk;
/
