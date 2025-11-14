CREATE OR REPLACE PACKAGE stage_pipe AS
  FUNCTION clean_stage(p_batch_id NUMBER) RETURN tab_stage_row PIPELINED;
END stage_pipe;
/

CREATE OR REPLACE PACKAGE BODY stage_pipe AS
  FUNCTION clean_stage(p_batch_id NUMBER) RETURN tab_stage_row PIPELINED IS
    CURSOR c IS
      SELECT batch_id, row_num,
             LOWER(TRIM(customer_email)) AS customer_email,
             TRIM(customer_name)         AS customer_name,
             UPPER(TRIM(product_sku))    AS product_sku,
             TRIM(product_name)          AS product_name,
             NVL(unit_cents,0)           AS unit_cents,
             NVL(qty,1)                  AS qty,
             order_ts
      FROM stage_orders_csv
      WHERE batch_id = p_batch_id
      ORDER BY row_num;
    r c%ROWTYPE;
  BEGIN
    OPEN c;
    LOOP
      FETCH c INTO r; EXIT WHEN c%NOTFOUND;
      PIPE ROW (obj_stage_row(
        r.batch_id, r.row_num, r.customer_email, r.customer_name,
        r.product_sku, r.product_name, r.unit_cents, r.qty, r.order_ts
      ));
    END LOOP;
    CLOSE c;
    RETURN;
  END clean_stage;
END stage_pipe;
/
