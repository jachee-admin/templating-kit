CREATE OR REPLACE PACKAGE order_loader AS
  --------------------------------------------------------------------
  -- Generates fake staging data for testing
  --------------------------------------------------------------------
  PROCEDURE gen_fake_stage(
    p_batch_id IN NUMBER,
    p_rows     IN PLS_INTEGER DEFAULT 5000
  );

  --------------------------------------------------------------------
  -- Bulk load one batch from stage_orders_csv into main tables
  --------------------------------------------------------------------
  PROCEDURE load_batch(
    p_batch_id    IN NUMBER,
    p_fetch_limit IN PLS_INTEGER DEFAULT 500
  );

  --------------------------------------------------------------------
  -- Optional: expose helper upserts for testing (not required)
  --------------------------------------------------------------------
  PROCEDURE upsert_customers(
    p_emails IN tp_bulk.t_email_tab,
    p_names  IN tp_bulk.t_email_tab,
    o_map    OUT tp_bulk.t_email_to_id
  );

  PROCEDURE upsert_products(
    p_skus  IN tp_bulk.t_sku_tab,
    p_names IN tp_bulk.t_email_tab,
    p_price IN tp_bulk.t_num_tab,
    o_map   OUT tp_bulk.t_sku_to_id
  );

  --------------------------------------------------------------------
  -- Internal logger exposed for debugging (optional)
  --------------------------------------------------------------------
  PROCEDURE log_err(
    p_op    VARCHAR2,
    p_batch NUMBER,
    p_row   NUMBER,
    p_code  NUMBER,
    p_msg   VARCHAR2
  );

END order_loader;
/
