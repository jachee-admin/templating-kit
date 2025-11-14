CREATE OR REPLACE PACKAGE BODY order_loader AS

  --------------------------------------------------------------------
  -- Error logger: autonomous transaction, persists errors immediately
  --------------------------------------------------------------------
  PROCEDURE log_err(
      p_op    VARCHAR2,
      p_batch NUMBER,
      p_row   NUMBER,
      p_code  NUMBER,
      p_msg   VARCHAR2
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO load_errors(op, batch_id, row_num, code, msg)
    VALUES (p_op, p_batch, p_row, p_code,
            DBMS_UTILITY.format_error_backtrace || ' | ' || p_msg);
    COMMIT;
  END log_err;

  --------------------------------------------------------------------
  -- Generate fake data into stage_orders_csv for testing
  --------------------------------------------------------------------
  PROCEDURE gen_fake_stage(p_batch_id IN NUMBER, p_rows IN PLS_INTEGER DEFAULT 5000) IS
  BEGIN
    INSERT /*+ APPEND */ INTO stage_orders_csv
    SELECT p_batch_id AS batch_id,
           LEVEL AS row_num,
           'user' || MOD(LEVEL, 500) || '@example.com' AS customer_email,
           'User ' || MOD(LEVEL, 500) AS customer_name,
           'SKU' || TO_CHAR(MOD(LEVEL, 800), 'FM000000') AS product_sku,
           'Product ' || MOD(LEVEL, 800),
           100 + MOD(LEVEL, 900) AS unit_cents,
           1 + MOD(LEVEL, 5) AS qty,
           SYSTIMESTAMP - NUMTODSINTERVAL(MOD(LEVEL, 1440), 'MINUTE') AS order_ts
    FROM dual
    CONNECT BY LEVEL <= p_rows;
    COMMIT;
  END gen_fake_stage;

  --------------------------------------------------------------------
  -- Upsert customers in bulk using BULK COLLECT + FORALL INSERT
  --------------------------------------------------------------------
  PROCEDURE upsert_customers(
      p_emails IN tp_bulk.t_email_tab,
      p_names  IN tp_bulk.t_email_tab,
      o_map    OUT tp_bulk.t_email_to_id
  ) IS
    TYPE t_email_tab IS TABLE OF VARCHAR2(320);
    TYPE t_id_tab    IS TABLE OF NUMBER;
    l_emails t_email_tab;
    l_ids    t_id_tab;

    l_missing_emails tp_bulk.t_email_tab := tp_bulk.t_email_tab();
    l_missing_names  tp_bulk.t_email_tab := tp_bulk.t_email_tab();

    -- preallocated ids for new rows
    l_new_ids tp_bulk.t_num_tab := tp_bulk.t_num_tab();

    -- SQL-visible collection
    l_sql_emails t_varchar2_320_tab := t_varchar2_320_tab();
  BEGIN
    o_map.DELETE;
    IF p_emails.COUNT = 0 THEN RETURN; END IF;

    -- copy to SQL type
    l_sql_emails.EXTEND(p_emails.COUNT);
    FOR i IN 1 .. p_emails.COUNT LOOP
      l_sql_emails(i) := p_emails(i);
    END LOOP;

    -- lookup existing
    SELECT c.email, c.customer_id
    BULK COLLECT INTO l_emails, l_ids
    FROM customers c
    WHERE c.email IN (SELECT COLUMN_VALUE FROM TABLE(l_sql_emails));

    FOR i IN 1 .. l_emails.COUNT LOOP
      o_map(l_emails(i)) := l_ids(i);
    END LOOP;

    -- find missing
    FOR i IN 1 .. p_emails.COUNT LOOP
      IF NOT o_map.EXISTS(p_emails(i)) THEN
        l_missing_emails.EXTEND; l_missing_emails(l_missing_emails.COUNT) := p_emails(i);
        l_missing_names.EXTEND;  l_missing_names(l_missing_names.COUNT)   := p_names(i);
      END IF;
    END LOOP;
    IF l_missing_emails.COUNT = 0 THEN RETURN; END IF;

    -- pre-generate IDs
    DECLARE
      l_me_rows PLS_INTEGER := l_missing_emails.COUNT;
    BEGIN
      SELECT seq_customers.NEXTVAL
      BULK COLLECT INTO l_new_ids
      FROM dual
      CONNECT BY LEVEL <= l_me_rows;
    END;
    -- insert with pre-gen ids
    FORALL i IN 1 .. l_missing_emails.COUNT SAVE EXCEPTIONS
      INSERT INTO customers(customer_id, email, full_name, updated_at)
      VALUES (l_new_ids(i), l_missing_emails(i), l_missing_names(i), SYSTIMESTAMP);

    -- hydrate map from pre-gen ids
    FOR i IN 1 .. l_missing_emails.COUNT LOOP
      o_map(l_missing_emails(i)) := l_new_ids(i);
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
        log_err('UPSERT_CUSTOMERS', NULL, NULL,
                SQL%BULK_EXCEPTIONS(j).ERROR_CODE,
                'index='||SQL%BULK_EXCEPTIONS(j).ERROR_INDEX);
      END LOOP;
      RAISE;
  END upsert_customers;


  --------------------------------------------------------------------
  -- Upsert products in bulk
  --------------------------------------------------------------------
  PROCEDURE upsert_products(
      p_skus  IN tp_bulk.t_sku_tab,
      p_names IN tp_bulk.t_email_tab,
      p_price IN tp_bulk.t_num_tab,
      o_map   OUT tp_bulk.t_sku_to_id
  ) IS
    TYPE t_sku_tab IS TABLE OF VARCHAR2(64);
    TYPE t_id_tab  IS TABLE OF NUMBER;
    l_skus t_sku_tab;
    l_ids  t_id_tab;

    l_missing_skus  tp_bulk.t_sku_tab   := tp_bulk.t_sku_tab();
    l_missing_names tp_bulk.t_email_tab := tp_bulk.t_email_tab();
    l_missing_price tp_bulk.t_num_tab   := tp_bulk.t_num_tab();

    l_new_ids tp_bulk.t_num_tab := tp_bulk.t_num_tab();
    l_sql_skus t_varchar2_64_tab := t_varchar2_64_tab();
  BEGIN
    o_map.DELETE;
    IF p_skus.COUNT = 0 THEN RETURN; END IF;

    -- copy to SQL type
    l_sql_skus.EXTEND(p_skus.COUNT);
    FOR i IN 1 .. p_skus.COUNT LOOP
      l_sql_skus(i) := p_skus(i);
    END LOOP;

    -- lookup existing
    SELECT p.sku, p.product_id
    BULK COLLECT INTO l_skus, l_ids
    FROM products p
    WHERE p.sku IN (SELECT COLUMN_VALUE FROM TABLE(l_sql_skus));

    FOR i IN 1 .. l_skus.COUNT LOOP
      o_map(l_skus(i)) := l_ids(i);
    END LOOP;

    -- find missing
    FOR i IN 1 .. p_skus.COUNT LOOP
      IF NOT o_map.EXISTS(p_skus(i)) THEN
        l_missing_skus.EXTEND;  l_missing_skus(l_missing_skus.COUNT)   := p_skus(i);
        l_missing_names.EXTEND; l_missing_names(l_missing_names.COUNT) := p_names(i);
        l_missing_price.EXTEND; l_missing_price(l_missing_price.COUNT) := p_price(i);
      END IF;
    END LOOP;
    IF l_missing_skus.COUNT = 0 THEN RETURN; END IF;

    DECLARE
      l_ms_rows PLS_INTEGER := l_missing_skus.COUNT;
    BEGIN
      SELECT seq_products.NEXTVAL
      BULK COLLECT INTO l_new_ids
      FROM dual
      CONNECT BY LEVEL <= l_ms_rows;
    END;
    -- pre-generate IDs


    -- insert with pre-gen ids
    FORALL i IN 1 .. l_missing_skus.COUNT SAVE EXCEPTIONS
      INSERT INTO products(product_id, sku, name, price_cents, updated_at)
      VALUES (l_new_ids(i), l_missing_skus(i), l_missing_names(i), l_missing_price(i), SYSTIMESTAMP);

    -- map
    FOR i IN 1 .. l_missing_skus.COUNT LOOP
      o_map(l_missing_skus(i)) := l_new_ids(i);
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
        log_err('UPSERT_PRODUCTS', NULL, NULL,
                SQL%BULK_EXCEPTIONS(j).ERROR_CODE,
                'index='||SQL%BULK_EXCEPTIONS(j).ERROR_INDEX);
      END LOOP;
      RAISE;
  END upsert_products;


  --------------------------------------------------------------------
  -- Main loader: bulk read from stage, upsert, insert orders/items
  --------------------------------------------------------------------
  PROCEDURE load_batch(p_batch_id IN NUMBER, p_fetch_limit IN PLS_INTEGER DEFAULT 500) IS
    CURSOR c_stage IS
      SELECT *
      FROM stage_orders_csv
      WHERE batch_id = p_batch_id
      ORDER BY row_num;

    l_rows tp_bulk.nt_stage_row;

    -- maps from the upsert steps
    l_email_to_id tp_bulk.t_email_to_id;
    l_sku_to_id   tp_bulk.t_sku_to_id;

    -- scalar arrays used ONLY inside FORALL binds
    TYPE t_ts_tab IS TABLE OF TIMESTAMP;
    l_customer_ids tp_bulk.t_num_tab := tp_bulk.t_num_tab();
    l_order_ts     t_ts_tab          := t_ts_tab();
    l_total_cents  tp_bulk.t_num_tab := tp_bulk.t_num_tab();

    l_order_ids    tp_bulk.t_num_tab := tp_bulk.t_num_tab();

    l_product_ids  tp_bulk.t_num_tab := tp_bulk.t_num_tab();
    l_qtys         tp_bulk.t_num_tab := tp_bulk.t_num_tab();
    l_units        tp_bulk.t_num_tab := tp_bulk.t_num_tab();

    -- helper buffers for upsert inputs
    l_email_set tp_bulk.t_email_tab := tp_bulk.t_email_tab();
    l_name_set  tp_bulk.t_email_tab := tp_bulk.t_email_tab();
    l_sku_set   tp_bulk.t_sku_tab   := tp_bulk.t_sku_tab();
    l_pname_set tp_bulk.t_email_tab := tp_bulk.t_email_tab();
    l_price_set tp_bulk.t_num_tab   := tp_bulk.t_num_tab();

    l_start     TIMESTAMP := SYSTIMESTAMP;
    l_rowcount  NUMBER    := 0;
    l_n         PLS_INTEGER;
  BEGIN
    OPEN c_stage;
    LOOP
      FETCH c_stage BULK COLLECT INTO l_rows LIMIT p_fetch_limit;
      EXIT WHEN l_rows.COUNT = 0;

      l_n := l_rows.COUNT;
      l_rowcount := l_rowcount + l_n;

      /* ------------------ Build deduped upsert inputs ------------------ */
      l_email_set.DELETE; l_name_set.DELETE;
      l_sku_set.DELETE;   l_pname_set.DELETE; l_price_set.DELETE;

      FOR i IN 1 .. l_n LOOP
        l_email_set.EXTEND; l_email_set(l_email_set.COUNT) := l_rows(i).customer_email;
        l_name_set.EXTEND;  l_name_set(l_name_set.COUNT)   := l_rows(i).customer_name;
        l_sku_set.EXTEND;   l_sku_set(l_sku_set.COUNT)     := l_rows(i).product_sku;
        l_pname_set.EXTEND; l_pname_set(l_pname_set.COUNT) := l_rows(i).product_name;
        l_price_set.EXTEND; l_price_set(l_price_set.COUNT) := l_rows(i).unit_cents;
      END LOOP;

      -- Bulk upserts populate associative maps
      upsert_customers(l_email_set, l_name_set, l_email_to_id);
      upsert_products(l_sku_set, l_pname_set, l_price_set, l_sku_to_id);

      /* --------- Precompute ALL scalar arrays (no lookups in FORALL) --------- */
      l_customer_ids.DELETE; l_order_ts.DELETE; l_total_cents.DELETE;
      l_order_ids.DELETE;
      l_product_ids.DELETE; l_qtys.DELETE; l_units.DELETE;

      l_customer_ids.EXTEND(l_n);
      l_order_ts.EXTEND(l_n);
      l_total_cents.EXTEND(l_n);
      l_order_ids.EXTEND(l_n);
      l_product_ids.EXTEND(l_n);
      l_qtys.EXTEND(l_n);
      l_units.EXTEND(l_n);

      FOR i IN 1 .. l_n LOOP
        -- resolve map lookups and compute totals BEFORE FORALL
        l_customer_ids(i) := l_email_to_id(l_rows(i).customer_email);
        l_order_ts(i)     := l_rows(i).order_ts;
        l_total_cents(i)  := NVL(l_rows(i).qty,0) * NVL(l_rows(i).unit_cents,0);

        -- pre-generate order IDs procedurally (no SQL COUNT usage)
        l_order_ids(i)    := seq_orders.NEXTVAL;

        -- item binds
        l_product_ids(i)  := l_sku_to_id(l_rows(i).product_sku);
        l_qtys(i)         := l_rows(i).qty;
        l_units(i)        := l_rows(i).unit_cents;
      END LOOP;

      /* ----------------------------- INSERTS ----------------------------- */
      -- Orders: only scalar collections in the VALUES clause
      FORALL i IN 1 .. l_n SAVE EXCEPTIONS
        INSERT INTO orders(order_id, customer_id, order_ts, total_cents)
        VALUES (l_order_ids(i), l_customer_ids(i), l_order_ts(i), l_total_cents(i));

      -- Order items: again only scalar collections
      FORALL i IN 1 .. l_n SAVE EXCEPTIONS
        INSERT INTO order_items(order_item_id, order_id, product_id, qty, unit_cents)
        VALUES (seq_order_items.NEXTVAL, l_order_ids(i), l_product_ids(i), l_qtys(i), l_units(i));

    END LOOP;
    CLOSE c_stage;

    DBMS_OUTPUT.put_line(
      'Batch ' || p_batch_id || ' loaded ' || l_rowcount ||
      ' rows in ' || TO_CHAR(SYSTIMESTAMP - l_start)
    );

  EXCEPTION
    WHEN OTHERS THEN
      log_err('LOAD_BATCH', p_batch_id, NULL, SQLCODE, SQLERRM);
      RAISE;
  END load_batch;


END order_loader;
/
