DECLARE
    TYPE obj_type IS TABLE OF VARCHAR2(30);
    v_objects obj_type := obj_type(
      'DEPTS',
      'USERS',
      'PRODUCT_CATEGORIES',
      'PRODUCTS',
      'INVENTORIES',
      'ADDRESSES',
      'ORDERS',
      'ORDER_ITEMS',
      'PAYMENTS',
      'SHIPMENTS',
      'ORDER_STATUS_HISTORY'
    );
  
    PROCEDURE drop_if_exists(p_stmt IN VARCHAR2) 
    IS
    BEGIN
        EXECUTE IMMEDIATE p_stmt;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE NOT IN ( -942, -4080, -2289, -2443, -04043 ) THEN
                RAISE;
            END IF;
    END;
BEGIN
    --Views
    drop_if_exists('drop view v_lov_depts');
    drop_if_exists('drop view v_lov_users');
    drop_if_exists('drop view v_lov_products');
    drop_if_exists('drop view v_order_summary');

    --Triggers
    FOR i IN v_objects.FIRST .. v_objects.LAST LOOP
        drop_if_exists('drop trigger trg_' || LOWER(v_objects(i)) || '_aud');
    END LOOP;
    
    --Tables
    FOR i IN v_objects.FIRST .. v_objects.LAST LOOP
        drop_if_exists('drop table ' || LOWER(v_objects(i)) || ' CASCADE CONSTRAINTS PURGE');
    END LOOP;
    drop_if_exists('drop table order_status_lu cascade constraints purge');
    drop_if_exists('drop table payment_method_lu cascade constraints purge');    
    
    --Packages
    drop_if_exists('drop package app_audit_trg');
    drop_if_exists('drop package app_ctx');
END;
/


