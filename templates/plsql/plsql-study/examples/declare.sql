DECLARE
  -- Record and collection for bulk operations
    TYPE t_rec IS RECORD (
            order_id   NUMBER,
            product_id NUMBER,
            qty        NUMBER,
            price      NUMBER
    );
    TYPE t_tab IS
        TABLE OF t_rec;
    l_batch   t_tab;               -- current batch
    c_limit   PLS_INTEGER := 1000; -- tune per environment

-- For RETURNING to get generated surrogate keys if needed
    TYPE t_ids IS
        TABLE OF NUMBER;
    l_new_ids t_ids;
    CURSOR cur_src IS
    SELECT order_id,
           product_id,
           qty,
           price
      FROM order_lines_stg
     WHERE is_valid = 'Y';

  -- Error logging: name of auto-created table ERR$_ORDER_LINES
    l_errors  NUMBER := 0;
BEGIN
-- Optional: create error log table once (idempotent in deployment scripts)
    BEGIN
        dbms_errlog.create_error_log(dml_table_name => 'ORDER_LINES');
    EXCEPTION
        WHEN OTHERS THEN
-- ignore "name already exists"
            IF sqlcode NOT IN ( - 955,
                                - 1408 ) THEN
                RAISE;
            END IF;
    END;

    OPEN cur_src;
    LOOP
        FETCH cur_src
        BULK COLLECT INTO l_batch LIMIT c_limit;
        EXIT WHEN l_batch.count = 0;
        BEGIN
-- Bulk insert. Use a sequence or identity—NOT hardcoded values.
            FORALL i IN 1..l_batch.count SAVE EXCEPTIONS
                INSERT INTO order_lines (
                    order_line_id,
                    order_id,
                    product_id,
                    qty,
                    price,
                    created_at
                ) VALUES ( order_lines_seq.NEXTVAL,
                           l_batch(i).order_id,
                           l_batch(i).product_id,
                           l_batch(i).qty,
                           l_batch(i).price,
                           systimestamp )
                    LOG ERRORS INTO err$_order_lines ( 'LOAD' ) REJECT LIMIT UNLIMITED;

      -- Optionally capture generated IDs (Oracle supports RETURNING BULK COLLECT)
      -- Uncomment if you need them downstream:
      -- FORALL i IN 1 .. l_batch.COUNT
      --   INSERT INTO order_lines (...) VALUES (...)
      --   RETURNING order_line_id BULK COLLECT INTO l_new_ids;

            COMMIT; -- commit per batch (tune frequency)
        EXCEPTION
            WHEN dml_errors THEN  -- raised when LOG ERRORS is NOT used; here we used LOG ERRORS
-- If you skip LOG ERRORS, handle row failures here via SQL%BULK_EXCEPTIONS
                FOR j IN 1..SQL%bulk_exceptions.count LOOP
                    dbms_output.put_line('Failed index '
                                         || SQL%bulk_exceptions(j).error_index
                                         || ' ORA-'
                                         || SQL%bulk_exceptions(j).error_code);
                END LOOP;
                ROLLBACK; -- rollback this batch
                l_errors := l_errors + SQL%bulk_exceptions.count;
            WHEN OTHERS THEN
-- Unexpected batch failure; rollback just this batch
                dbms_output.put_line('Batch failure: ' || sqlerrm);
                ROLLBACK;
                RAISE; -- or continue, depending on your tolerance
        END;
    END LOOP;
    CLOSE cur_src;
    dbms_output.put_line('Done. Check ERR$_ORDER_LINES for row-level failures.');
END;
/