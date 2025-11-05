DECLARE
    CURSOR c IS
    SELECT account_id,
           SUM(total_cents) AS cents
      FROM orders
     WHERE created_at >= sysdate - 30
     GROUP BY account_id;

    TYPE t_acc IS
        TABLE OF NUMBER;
    TYPE t_cents IS
        TABLE OF NUMBER;
    v_acc   t_acc;
    v_cents t_cents;
BEGIN
  -- Bulk fetch in chunks
    OPEN c;
    LOOP
        FETCH c
        BULK COLLECT INTO
            v_acc,
            v_cents
        LIMIT 1000;
        EXIT WHEN v_acc.count = 0;

    -- Upsert with FORALL (parallel scalar arrays)
        FORALL i IN 1..v_acc.count
            MERGE INTO monthly_spend d
            USING (
                SELECT v_acc(i) AS account_id,
                       v_cents(i) AS cents
                  FROM dual
            ) s ON ( d.account_id = s.account_id
               AND d.month_key = trunc(
                sysdate,
                'MM'
            ) )
            WHEN MATCHED THEN UPDATE
            SET d.cents = s.cents
            WHEN NOT MATCHED THEN
            INSERT (
                account_id,
                month_key,
                cents )
            VALUES
                ( s.account_id,
                  trunc(
                      sysdate,
                      'MM'
                  ),
                  s.cents );
        COMMIT;
    END LOOP;
    CLOSE c;
END;
/