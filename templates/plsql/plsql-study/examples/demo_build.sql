--------------------------------------------------------------------------------
-- APEX Demo Database Build
-- Objects: DEPTS, USERS, PRODUCT_CATEGORIES, PRODUCTS, INVENTORIES,
--          ORDER_STATUS_LU, PAYMENT_METHOD_LU,
--          ADDRESSES, ORDERS, ORDER_ITEMS, PAYMENTS, SHIPMENTS, ORDER_STATUS_HISTORY
-- Supporting: APP_CTX (pkg), generic audit trigger APP_AUDIT_TRG (pkg + per-table triggers),
--             LOV views, summary view V_ORDER_SUMMARY
-- Re-runnable: includes best-effort dropper
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 00) Best-effort cleanup (so this script is re-runnable)
--------------------------------------------------------------------------------
DECLARE
    PROCEDURE drop_if_exists (
        p_stmt VARCHAR2
    ) IS
    BEGIN
        EXECUTE IMMEDIATE p_stmt;
    EXCEPTION
        WHEN OTHERS THEN
            IF sqlcode NOT IN ( - 942,
                                - 4080,
                                - 2289,
                                - 2443,
                                - 04043 ) THEN
                RAISE;
            END IF;
    END;
BEGIN
  -- Views
    drop_if_exists('drop view v_lov_depts');
    drop_if_exists('drop view v_lov_users');
    drop_if_exists('drop view v_lov_products');
    drop_if_exists('drop view v_order_summary');

  -- Triggers (per-table audit)
    FOR t IN (
        SELECT trigger_name
          FROM user_triggers
         WHERE trigger_name IN ( 'TRG_DEPTS_AUD',
                                 'TRG_USERS_AUD',
                                 'TRG_PRODUCT_CATEGORIES_AUD',
                                 'TRG_PRODUCTS_AUD',
                                 'TRG_INVENTORIES_AUD',
                                 'TRG_ADDRESSES_AUD',
                                 'TRG_ORDERS_AUD',
                                 'TRG_ORDER_ITEMS_AUD',
                                 'TRG_PAYMENTS_AUD',
                                 'TRG_SHIPMENTS_AUD',
                                 'TRG_ORDER_STATUS_HISTORY_AUD' )
    ) LOOP
        drop_if_exists('drop trigger ' || t.trigger_name);
    END LOOP;

  -- Tables (children first)
    drop_if_exists('drop table order_status_history cascade constraints purge');
    drop_if_exists('drop table shipments cascade constraints purge');
    drop_if_exists('drop table payments cascade constraints purge');
    drop_if_exists('drop table order_items cascade constraints purge');
    drop_if_exists('drop table orders cascade constraints purge');
    drop_if_exists('drop table inventories cascade constraints purge');
    drop_if_exists('drop table products cascade constraints purge');
    drop_if_exists('drop table product_categories cascade constraints purge');
    drop_if_exists('drop table addresses cascade constraints purge');
    drop_if_exists('drop table users cascade constraints purge');
    drop_if_exists('drop table depts cascade constraints purge');
    drop_if_exists('drop table order_status_lu cascade constraints purge');
    drop_if_exists('drop table payment_method_lu cascade constraints purge');

  -- Packages
    drop_if_exists('drop package app_audit_trg');
    drop_if_exists('drop package app_ctx');
END;
/
--------------------------------------------------------------------------------
-- 01) Utility: who is the "app user"? (APEX or DB)
--------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE app_ctx AUTHID definer AS
    FUNCTION app_user RETURN VARCHAR2;
END app_ctx;
/
CREATE OR REPLACE PACKAGE BODY app_ctx AS
    FUNCTION app_user RETURN VARCHAR2 IS
        l_app_user VARCHAR2(255);
    BEGIN
    -- In APEX session this is set; otherwise NULL
        l_app_user := sys_context(
            'APEX$SESSION',
            'APP_USER'
        );
        IF l_app_user IS NOT NULL THEN
            RETURN l_app_user;
        ELSE
            RETURN sys_context(
                'USERENV',
                'SESSION_USER'
            );
        END IF;
    END;
END app_ctx;
/
--------------------------------------------------------------------------------
-- 02) Generic audit trigger helper (before insert/update on each table)
--------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE app_audit_trg AUTHID definer AS
    PROCEDURE stamp_ins_upd (
        p_created_by IN OUT NOCOPY VARCHAR2,
        p_created_at IN OUT NOCOPY TIMESTAMP,
        p_updated_by IN OUT NOCOPY VARCHAR2,
        p_updated_at IN OUT NOCOPY TIMESTAMP
    );
END app_audit_trg;
/
CREATE OR REPLACE PACKAGE BODY app_audit_trg AS
    PROCEDURE stamp_ins_upd (
        p_created_by IN OUT NOCOPY VARCHAR2,
        p_created_at IN OUT NOCOPY TIMESTAMP,
        p_updated_by IN OUT NOCOPY VARCHAR2,
        p_updated_at IN OUT NOCOPY TIMESTAMP
    ) IS
        l_user VARCHAR2(255) := app_ctx.app_user;
    BEGIN
        IF inserting THEN
            IF p_created_by IS NULL THEN
                p_created_by := l_user;
            END IF;
            IF p_created_at IS NULL THEN
                p_created_at := systimestamp;
            END IF;
        END IF;
        IF inserting
        OR updating THEN
            p_updated_by := l_user;
            p_updated_at := systimestamp;
        END IF;
    END;
END app_audit_trg;
/
--------------------------------------------------------------------------------
-- 03) Lookup tables
--------------------------------------------------------------------------------
CREATE TABLE order_status_lu (
    status_code  VARCHAR2(30)
        CONSTRAINT pk_order_status_lu PRIMARY KEY,
    display_name VARCHAR2(100) NOT NULL,
    sort_order   NUMBER(3) NOT NULL,
    is_terminal  CHAR(1) DEFAULT 'N' CHECK ( is_terminal IN ( 'Y',
                                                             'N' ) )
);

CREATE TABLE payment_method_lu (
    method_code  VARCHAR2(30)
        CONSTRAINT pk_payment_method_lu PRIMARY KEY,
    display_name VARCHAR2(100) NOT NULL,
    sort_order   NUMBER(3) NOT NULL
);

--------------------------------------------------------------------------------
-- 04) Core entities
--------------------------------------------------------------------------------
CREATE TABLE depts (
    dept_id    NUMBER
        GENERATED ALWAYS AS IDENTITY
    PRIMARY KEY,
    dept_code  VARCHAR2(30) NOT NULL,
    dept_name  VARCHAR2(100) NOT NULL,
    created_by VARCHAR2(255),
    created_at TIMESTAMP(6),
    updated_by VARCHAR2(255),
    updated_at TIMESTAMP(6),
    deleted_at TIMESTAMP(6),
    CONSTRAINT uq_depts_code UNIQUE ( dept_code )
);

CREATE TABLE users (
    user_id    NUMBER
        GENERATED ALWAYS AS IDENTITY
    PRIMARY KEY,
    email      VARCHAR2(320) NOT NULL,
    full_name  VARCHAR2(200) NOT NULL,
    dept_id    NUMBER,
    is_active  CHAR(1) DEFAULT 'Y' CHECK ( is_active IN ( 'Y',
                                                         'N' ) ),
    created_by VARCHAR2(255),
    created_at TIMESTAMP(6),
    updated_by VARCHAR2(255),
    updated_at TIMESTAMP(6),
    deleted_at TIMESTAMP(6),
    CONSTRAINT uq_users_email UNIQUE ( email ),
    CONSTRAINT fk_users_dept FOREIGN KEY ( dept_id )
        REFERENCES depts ( dept_id )
);

CREATE TABLE product_categories (
    category_id   NUMBER
        GENERATED ALWAYS AS IDENTITY
    PRIMARY KEY,
    category_code VARCHAR2(30) NOT NULL,
    category_name VARCHAR2(100) NOT NULL,
    created_by    VARCHAR2(255),
    created_at    TIMESTAMP(6),
    updated_by    VARCHAR2(255),
    updated_at    TIMESTAMP(6),
    deleted_at    TIMESTAMP(6),
    CONSTRAINT uq_prodcat_code UNIQUE ( category_code )
);

CREATE TABLE products (
    product_id   NUMBER
        GENERATED ALWAYS AS IDENTITY
    PRIMARY KEY,
    sku          VARCHAR2(40) NOT NULL,
    product_name VARCHAR2(200) NOT NULL,
    category_id  NUMBER NOT NULL,
    unit_price   NUMBER(12,2) NOT NULL CHECK ( unit_price >= 0 ),
    active       CHAR(1) DEFAULT 'Y' CHECK ( active IN ( 'Y',
                                                   'N' ) ),
    created_by   VARCHAR2(255),
    created_at   TIMESTAMP(6),
    updated_by   VARCHAR2(255),
    updated_at   TIMESTAMP(6),
    deleted_at   TIMESTAMP(6),
    CONSTRAINT uq_products_sku UNIQUE ( sku ),
    CONSTRAINT fk_products_cat FOREIGN KEY ( category_id )
        REFERENCES product_categories ( category_id )
);

CREATE TABLE inventories (
    inventory_id  NUMBER
        GENERATED ALWAYS AS IDENTITY
    PRIMARY KEY,
    product_id    NUMBER NOT NULL,
    qty_on_hand   NUMBER(12,0) DEFAULT 0 CHECK ( qty_on_hand >= 0 ),
    reorder_level NUMBER(12,0) DEFAULT 0 CHECK ( reorder_level >= 0 ),
    created_by    VARCHAR2(255),
    created_at    TIMESTAMP(6),
    updated_by    VARCHAR2(255),
    updated_at    TIMESTAMP(6),
    deleted_at    TIMESTAMP(6),
    CONSTRAINT uq_inv_product UNIQUE ( product_id ),
    CONSTRAINT fk_inv_product FOREIGN KEY ( product_id )
        REFERENCES products ( product_id )
);

CREATE TABLE addresses (
    address_id  NUMBER
        GENERATED ALWAYS AS IDENTITY
    PRIMARY KEY,
    owner_type  VARCHAR2(10) NOT NULL CHECK ( owner_type IN ( 'USER',
                                                             'DEPT' ) ),
    owner_id    NUMBER NOT NULL,
    line1       VARCHAR2(200) NOT NULL,
    line2       VARCHAR2(200),
    city        VARCHAR2(100) NOT NULL,
    region      VARCHAR2(100),
    postal_code VARCHAR2(20),
    country     VARCHAR2(100) DEFAULT 'USA',
    created_by  VARCHAR2(255),
    created_at  TIMESTAMP(6),
    updated_by  VARCHAR2(255),
    updated_at  TIMESTAMP(6),
    deleted_at  TIMESTAMP(6)
);
-- Polymorphic FK enforcement (owner_type -> table) is by check constraints + validations in app.
-- For demo simplicity, we won't add complex RLS/VPD here.

--------------------------------------------------------------------------------
-- 05) Orders domain
--------------------------------------------------------------------------------
CREATE TABLE orders (
    order_id        NUMBER
        GENERATED ALWAYS AS IDENTITY
    PRIMARY KEY,
    order_number    VARCHAR2(30) NOT NULL,
    user_id         NUMBER NOT NULL,
    dept_id         NUMBER,
    order_status    VARCHAR2(30) NOT NULL,
    order_date      DATE DEFAULT trunc(sysdate) NOT NULL,
    ship_to_address NUMBER,
    bill_to_address NUMBER,
    notes           VARCHAR2(4000),
    created_by      VARCHAR2(255),
    created_at      TIMESTAMP(6),
    updated_by      VARCHAR2(255),
    updated_at      TIMESTAMP(6),
    deleted_at      TIMESTAMP(6),
    CONSTRAINT uq_orders_number UNIQUE ( order_number ),
    CONSTRAINT fk_orders_user FOREIGN KEY ( user_id )
        REFERENCES users ( user_id ),
    CONSTRAINT fk_orders_dept FOREIGN KEY ( dept_id )
        REFERENCES depts ( dept_id ),
    CONSTRAINT fk_orders_status FOREIGN KEY ( order_status )
        REFERENCES order_status_lu ( status_code ),
    CONSTRAINT fk_orders_shipaddr FOREIGN KEY ( ship_to_address )
        REFERENCES addresses ( address_id ),
    CONSTRAINT fk_orders_billaddr FOREIGN KEY ( bill_to_address )
        REFERENCES addresses ( address_id )
);

CREATE TABLE order_items (
    order_item_id NUMBER
        GENERATED ALWAYS AS IDENTITY
    PRIMARY KEY,
    order_id      NUMBER NOT NULL,
    product_id    NUMBER NOT NULL,
    quantity      NUMBER(12,2) NOT NULL CHECK ( quantity > 0 ),
    unit_price    NUMBER(12,2) NOT NULL CHECK ( unit_price >= 0 ),
    created_by    VARCHAR2(255),
    created_at    TIMESTAMP(6),
    updated_by    VARCHAR2(255),
    updated_at    TIMESTAMP(6),
    deleted_at    TIMESTAMP(6),
    CONSTRAINT uq_item_unique UNIQUE ( order_id,
                                       product_id ),
    CONSTRAINT fk_items_order FOREIGN KEY ( order_id )
        REFERENCES orders ( order_id )
            ON DELETE CASCADE,
    CONSTRAINT fk_items_product FOREIGN KEY ( product_id )
        REFERENCES products ( product_id )
);

CREATE TABLE payments (
    payment_id   NUMBER
        GENERATED ALWAYS AS IDENTITY
    PRIMARY KEY,
    order_id     NUMBER NOT NULL,
    method_code  VARCHAR2(30) NOT NULL,
    amount       NUMBER(12,2) NOT NULL CHECK ( amount >= 0 ),
    paid_at      TIMESTAMP(6),
    reference_no VARCHAR2(100),
    created_by   VARCHAR2(255),
    created_at   TIMESTAMP(6),
    updated_by   VARCHAR2(255),
    updated_at   TIMESTAMP(6),
    deleted_at   TIMESTAMP(6),
    CONSTRAINT fk_pay_order FOREIGN KEY ( order_id )
        REFERENCES orders ( order_id )
            ON DELETE CASCADE,
    CONSTRAINT fk_pay_method FOREIGN KEY ( method_code )
        REFERENCES payment_method_lu ( method_code )
);

CREATE TABLE shipments (
    shipment_id  NUMBER
        GENERATED ALWAYS AS IDENTITY
    PRIMARY KEY,
    order_id     NUMBER NOT NULL,
    carrier      VARCHAR2(50),
    tracking_no  VARCHAR2(100),
    shipped_at   TIMESTAMP(6),
    delivered_at TIMESTAMP(6),
    created_by   VARCHAR2(255),
    created_at   TIMESTAMP(6),
    updated_by   VARCHAR2(255),
    updated_at   TIMESTAMP(6),
    deleted_at   TIMESTAMP(6),
    CONSTRAINT fk_ship_order FOREIGN KEY ( order_id )
        REFERENCES orders ( order_id )
            ON DELETE CASCADE
);

CREATE TABLE order_status_history (
    hist_id     NUMBER
        GENERATED ALWAYS AS IDENTITY
    PRIMARY KEY,
    order_id    NUMBER NOT NULL,
    from_status VARCHAR2(30),
    to_status   VARCHAR2(30) NOT NULL,
    changed_at  TIMESTAMP(6) DEFAULT systimestamp NOT NULL,
    changed_by  VARCHAR2(255) NOT NULL,
    note        VARCHAR2(1000),
    CONSTRAINT fk_hist_order FOREIGN KEY ( order_id )
        REFERENCES orders ( order_id )
            ON DELETE CASCADE,
    CONSTRAINT fk_hist_to_status FOREIGN KEY ( to_status )
        REFERENCES order_status_lu ( status_code ),
    CONSTRAINT fk_hist_from_status FOREIGN KEY ( from_status )
        REFERENCES order_status_lu ( status_code )
);

--------------------------------------------------------------------------------
-- 06) Indexes (FKs and common filters)
--------------------------------------------------------------------------------
CREATE INDEX ix_users_dept ON
    users (
        dept_id
    );
CREATE INDEX ix_products_category ON
    products (
        category_id
    );
--CREATE INDEX ix_inv_product ON
--    inventories (
--        product_id
--    );
CREATE INDEX ix_addresses_owner ON
    addresses (
        owner_type,
        owner_id
    );
CREATE INDEX ix_orders_user ON
    orders (
        user_id
    );
CREATE INDEX ix_orders_dept ON
    orders (
        dept_id
    );
CREATE INDEX ix_orders_status ON
    orders (
        order_status
    );
CREATE INDEX ix_items_order ON
    order_items (
        order_id
    );
CREATE INDEX ix_items_product ON
    order_items (
        product_id
    );
CREATE INDEX ix_payments_order ON
    payments (
        order_id
    );
CREATE INDEX ix_shipments_order ON
    shipments (
        order_id
    );

--------------------------------------------------------------------------------
-- 07) Audit triggers per table (uniform)
--------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_depts_aud BEFORE
    INSERT OR UPDATE ON depts
    FOR EACH ROW
BEGIN
    app_audit_trg.stamp_ins_upd(
        :new.created_by,
        :new.created_at,
        :new.updated_by,
        :new.updated_at
    );
END;
/
CREATE OR REPLACE TRIGGER trg_users_aud BEFORE
    INSERT OR UPDATE ON users
    FOR EACH ROW
BEGIN
    app_audit_trg.stamp_ins_upd(
        :new.created_by,
        :new.created_at,
        :new.updated_by,
        :new.updated_at
    );
END;
/
CREATE OR REPLACE TRIGGER trg_product_categories_aud BEFORE
    INSERT OR UPDATE ON product_categories
    FOR EACH ROW
BEGIN
    app_audit_trg.stamp_ins_upd(
        :new.created_by,
        :new.created_at,
        :new.updated_by,
        :new.updated_at
    );
END;
/
CREATE OR REPLACE TRIGGER trg_products_aud BEFORE
    INSERT OR UPDATE ON products
    FOR EACH ROW
BEGIN
    app_audit_trg.stamp_ins_upd(
        :new.created_by,
        :new.created_at,
        :new.updated_by,
        :new.updated_at
    );
END;
/
CREATE OR REPLACE TRIGGER trg_inventories_aud BEFORE
    INSERT OR UPDATE ON inventories
    FOR EACH ROW
BEGIN
    app_audit_trg.stamp_ins_upd(
        :new.created_by,
        :new.created_at,
        :new.updated_by,
        :new.updated_at
    );
END;
/
CREATE OR REPLACE TRIGGER trg_addresses_aud BEFORE
    INSERT OR UPDATE ON addresses
    FOR EACH ROW
BEGIN
    app_audit_trg.stamp_ins_upd(
        :new.created_by,
        :new.created_at,
        :new.updated_by,
        :new.updated_at
    );
END;
/
CREATE OR REPLACE TRIGGER trg_orders_aud BEFORE
    INSERT OR UPDATE ON orders
    FOR EACH ROW
BEGIN
    app_audit_trg.stamp_ins_upd(
        :new.created_by,
        :new.created_at,
        :new.updated_by,
        :new.updated_at
    );
END;
/
CREATE OR REPLACE TRIGGER trg_order_items_aud BEFORE
    INSERT OR UPDATE ON order_items
    FOR EACH ROW
BEGIN
    app_audit_trg.stamp_ins_upd(
        :new.created_by,
        :new.created_at,
        :new.updated_by,
        :new.updated_at
    );
END;
/
CREATE OR REPLACE TRIGGER trg_payments_aud BEFORE
    INSERT OR UPDATE ON payments
    FOR EACH ROW
BEGIN
    app_audit_trg.stamp_ins_upd(
        :new.created_by,
        :new.created_at,
        :new.updated_by,
        :new.updated_at
    );
END;
/
CREATE OR REPLACE TRIGGER trg_shipments_aud BEFORE
    INSERT OR UPDATE ON shipments
    FOR EACH ROW
BEGIN
    app_audit_trg.stamp_ins_upd(
        :new.created_by,
        :new.created_at,
        :new.updated_by,
        :new.updated_at
    );
END;
/
CREATE OR REPLACE TRIGGER trg_order_status_history_aud BEFORE
    INSERT OR UPDATE ON order_status_history
    FOR EACH ROW
BEGIN
    IF inserting THEN
        :new.changed_by := app_ctx.app_user;
    END IF;
END;
/

--------------------------------------------------------------------------------
-- 08) Seed reference data
--------------------------------------------------------------------------------
MERGE INTO order_status_lu d
USING (
    SELECT 'NEW' status_code,
           'New' display_name,
           10 sort_order,
           'N' is_terminal
      FROM dual
    UNION ALL
    SELECT 'PAID',
           'Paid',
           20,
           'N'
      FROM dual
    UNION ALL
    SELECT 'PICK',
           'Picking',
           30,
           'N'
      FROM dual
    UNION ALL
    SELECT 'SHIP',
           'Shipped',
           40,
           'N'
      FROM dual
    UNION ALL
    SELECT 'DONE',
           'Completed',
           50,
           'Y'
      FROM dual
    UNION ALL
    SELECT 'CANC',
           'Cancelled',
           60,
           'Y'
      FROM dual
) s ON ( d.status_code = s.status_code )
WHEN MATCHED THEN UPDATE
SET d.display_name = s.display_name,
    d.sort_order = s.sort_order,
    d.is_terminal = s.is_terminal
WHEN NOT MATCHED THEN
INSERT (
    status_code,
    display_name,
    sort_order,
    is_terminal )
VALUES
    ( s.status_code,
      s.display_name,
      s.sort_order,
      s.is_terminal );

MERGE INTO payment_method_lu d
USING (
    SELECT 'CARD' method_code,
           'Credit Card' display_name,
           10 sort_order
      FROM dual
    UNION ALL
    SELECT 'ACH',
           'ACH',
           20
      FROM dual
    UNION ALL
    SELECT 'CASH',
           'Cash',
           30
      FROM dual
) s ON ( d.method_code = s.method_code )
WHEN MATCHED THEN UPDATE
SET d.display_name = s.display_name,
    d.sort_order = s.sort_order
WHEN NOT MATCHED THEN
INSERT (
    method_code,
    display_name,
    sort_order )
VALUES
    ( s.method_code,
      s.display_name,
      s.sort_order );

--------------------------------------------------------------------------------
-- 09) Seed core data (depts, users, categories, products, inventories, addresses)
--------------------------------------------------------------------------------
MERGE INTO depts d
USING (
    SELECT 'ENG' dept_code,
           'Engineering' dept_name
      FROM dual
    UNION ALL
    SELECT 'OPS',
           'Operations'
      FROM dual
    UNION ALL
    SELECT 'SALES',
           'Sales'
      FROM dual
) s ON ( d.dept_code = s.dept_code )
WHEN MATCHED THEN UPDATE
SET d.dept_name = s.dept_name
WHEN NOT MATCHED THEN
INSERT (
    dept_code,
    dept_name )
VALUES
    ( s.dept_code,
      s.dept_name );

MERGE INTO users u
USING (
    SELECT 'alice@example.com' email,
           'Alice Quinn' full_name,
           'ENG' dept_code
      FROM dual
    UNION ALL
    SELECT 'bob@example.com',
           'Bob Stone',
           'OPS'
      FROM dual
    UNION ALL
    SELECT 'cora@example.com',
           'Cora Vance',
           'SALES'
      FROM dual
) s ON ( u.email = s.email )
WHEN MATCHED THEN UPDATE
SET u.full_name = s.full_name,
    u.dept_id = (
    SELECT dept_id
      FROM depts
     WHERE dept_code = s.dept_code
)
WHEN NOT MATCHED THEN
INSERT (
    email,
    full_name,
    dept_id )
VALUES
    ( s.email,
      s.full_name,
      (
          SELECT dept_id
            FROM depts
           WHERE dept_code = s.dept_code
      ) );

MERGE INTO product_categories c
USING (
    SELECT 'HW' category_code,
           'Hardware' category_name
      FROM dual
    UNION ALL
    SELECT 'SW',
           'Software'
      FROM dual
    UNION ALL
    SELECT 'SV',
           'Services'
      FROM dual
) s ON ( c.category_code = s.category_code )
WHEN MATCHED THEN UPDATE
SET c.category_name = s.category_name
WHEN NOT MATCHED THEN
INSERT (
    category_code,
    category_name )
VALUES
    ( s.category_code,
      s.category_name );

MERGE INTO products p
USING (
    SELECT 'SKU-100' sku,
           'Mechanical Keyboard' product_name,
           'HW' cat,
           129.00 price
      FROM dual
    UNION ALL
    SELECT 'SKU-200',
           'Pro Dev License',
           'SW',
           299.00
      FROM dual
    UNION ALL
    SELECT 'SKU-300',
           'Onboarding Package',
           'SV',
           499.00
      FROM dual
) s ON ( p.sku = s.sku )
WHEN MATCHED THEN UPDATE
SET p.product_name = s.product_name,
    p.category_id = (
    SELECT category_id
      FROM product_categories
     WHERE category_code = s.cat
),
    p.unit_price = s.price
WHEN NOT MATCHED THEN
INSERT (
    sku,
    product_name,
    category_id,
    unit_price )
VALUES
    ( s.sku,
      s.product_name,
      (
          SELECT category_id
            FROM product_categories
           WHERE category_code = s.cat
      ),
      s.price );

-- inventories one-per-product
MERGE INTO inventories i
USING (
    SELECT product_id
      FROM products
) s ON ( i.product_id = s.product_id )
WHEN MATCHED THEN UPDATE
SET i.qty_on_hand = i.qty_on_hand
WHEN NOT MATCHED THEN
INSERT (
    product_id,
    qty_on_hand,
    reorder_level )
VALUES
    ( s.product_id,
      100,
      25 );

-- addresses for users
MERGE INTO addresses a
USING (
    SELECT 'USER' owner_type,
           (
               SELECT user_id
                 FROM users
                WHERE email = 'alice@example.com'
           ) owner_id,
           '10 First Ave' line1,
           NULL line2,
           'Raleigh' city,
           'NC' region,
           '27601' postal,
           'USA' country
      FROM dual
    UNION ALL
    SELECT 'USER',
           (
               SELECT user_id
                 FROM users
                WHERE email = 'bob@example.com'
           ),
           '99 Ops Way',
           NULL,
           'Raleigh',
           'NC',
           '27606',
           'USA'
      FROM dual
    UNION ALL
    SELECT 'USER',
           (
               SELECT user_id
                 FROM users
                WHERE email = 'cora@example.com'
           ),
           '500 Sales Blvd',
           'Suite 3',
           'Durham',
           'NC',
           '27701',
           'USA'
      FROM dual
) s ON ( a.owner_type = s.owner_type
   AND a.owner_id = s.owner_id
   AND a.line1 = s.line1
   AND nvl(
    a.line2,
    '~'
) = nvl(
    s.line2,
    '~'
) )
WHEN MATCHED THEN UPDATE
SET a.city = s.city,
    a.region = s.region,
    a.postal_code = s.postal,
    a.country = s.country
WHEN NOT MATCHED THEN
INSERT (
    owner_type,
    owner_id,
    line1,
    line2,
    city,
    region,
    postal_code,
    country )
VALUES
    ( s.owner_type,
      s.owner_id,
      s.line1,
      s.line2,
      s.city,
      s.region,
      s.postal,
      s.country );

--------------------------------------------------------------------------------
-- 10) Seed some orders, items, payments, shipments, history
--------------------------------------------------------------------------------
-- Orders
MERGE INTO orders o
USING (
    SELECT 'ORD-1001' order_number,
           (
               SELECT user_id
                 FROM users
                WHERE email = 'alice@example.com'
           ) user_id,
           (
               SELECT dept_id
                 FROM depts
                WHERE dept_code = 'ENG'
           ) dept_id,
           'NEW' order_status,
           trunc(sysdate) order_date,
           (
               SELECT MIN(address_id)
                 FROM addresses
                WHERE owner_type = 'USER'
                  AND owner_id = (
                   SELECT user_id
                     FROM users
                    WHERE email = 'alice@example.com'
               )
           ) ship_addr,
           (
               SELECT MIN(address_id)
                 FROM addresses
                WHERE owner_type = 'USER'
                  AND owner_id = (
                   SELECT user_id
                     FROM users
                    WHERE email = 'alice@example.com'
               )
           ) bill_addr
      FROM dual
    UNION ALL
    SELECT 'ORD-1002',
           (
               SELECT user_id
                 FROM users
                WHERE email = 'bob@example.com'
           ),
           (
               SELECT dept_id
                 FROM depts
                WHERE dept_code = 'OPS'
           ),
           'PAID',
           trunc(sysdate) - 1,
           (
               SELECT MIN(address_id)
                 FROM addresses
                WHERE owner_type = 'USER'
                  AND owner_id = (
                   SELECT user_id
                     FROM users
                    WHERE email = 'bob@example.com'
               )
           ),
           (
               SELECT MIN(address_id)
                 FROM addresses
                WHERE owner_type = 'USER'
                  AND owner_id = (
                   SELECT user_id
                     FROM users
                    WHERE email = 'bob@example.com'
               )
           )
      FROM dual
) s ON ( o.order_number = s.order_number )
WHEN MATCHED THEN UPDATE
SET o.user_id = s.user_id,
    o.dept_id = s.dept_id,
    o.order_status = s.order_status,
    o.order_date = s.order_date,
    o.ship_to_address = s.ship_addr,
    o.bill_to_address = s.bill_addr
WHEN NOT MATCHED THEN
INSERT (
    order_number,
    user_id,
    dept_id,
    order_status,
    order_date,
    ship_to_address,
    bill_to_address )
VALUES
    ( s.order_number,
      s.user_id,
      s.dept_id,
      s.order_status,
      s.order_date,
      s.ship_addr,
      s.bill_addr );

-- Items
MERGE INTO order_items i
USING (
    SELECT (
        SELECT order_id
          FROM orders
         WHERE order_number = 'ORD-1001'
    ) order_id,
           (
               SELECT product_id
                 FROM products
                WHERE sku = 'SKU-100'
           ) product_id,
           2 quantity,
           (
               SELECT unit_price
                 FROM products
                WHERE sku = 'SKU-100'
           ) unit_price
      FROM dual
    UNION ALL
    SELECT (
        SELECT order_id
          FROM orders
         WHERE order_number = 'ORD-1001'
    ),
           (
               SELECT product_id
                 FROM products
                WHERE sku = 'SKU-200'
           ),
           1,
           (
               SELECT unit_price
                 FROM products
                WHERE sku = 'SKU-200'
           )
      FROM dual
    UNION ALL
    SELECT (
        SELECT order_id
          FROM orders
         WHERE order_number = 'ORD-1002'
    ),
           (
               SELECT product_id
                 FROM products
                WHERE sku = 'SKU-300'
           ),
           1,
           (
               SELECT unit_price
                 FROM products
                WHERE sku = 'SKU-300'
           )
      FROM dual
) s ON ( i.order_id = s.order_id
   AND i.product_id = s.product_id )
WHEN MATCHED THEN UPDATE
SET i.quantity = s.quantity,
    i.unit_price = s.unit_price
WHEN NOT MATCHED THEN
INSERT (
    order_id,
    product_id,
    quantity,
    unit_price )
VALUES
    ( s.order_id,
      s.product_id,
      s.quantity,
      s.unit_price );

-- Payments
MERGE INTO payments p
USING (
    SELECT (
        SELECT order_id
          FROM orders
         WHERE order_number = 'ORD-1002'
    ) order_id,
           'CARD' method_code,
           499.00 amount,
           systimestamp paid_at,
           'AUTH-XYZ-001' ref_no
      FROM dual
) s ON ( p.order_id = s.order_id
   AND p.reference_no = s.ref_no )
WHEN MATCHED THEN UPDATE
SET p.amount = s.amount,
    p.paid_at = s.paid_at,
    p.method_code = s.method_code
WHEN NOT MATCHED THEN
INSERT (
    order_id,
    method_code,
    amount,
    paid_at,
    reference_no )
VALUES
    ( s.order_id,
      s.method_code,
      s.amount,
      s.paid_at,
      s.ref_no );

-- Shipments
MERGE INTO shipments sh
USING (
    SELECT (
        SELECT order_id
          FROM orders
         WHERE order_number = 'ORD-1002'
    ) order_id,
           'UPS' carrier,
           '1Z9999999999999999' tracking_no,
           systimestamp - 1 shipped_at,
           NULL delivered_at
      FROM dual
) s ON ( sh.order_id = s.order_id )
WHEN MATCHED THEN UPDATE
SET sh.carrier = s.carrier,
    sh.tracking_no = s.tracking_no,
    sh.shipped_at = s.shipped_at
WHEN NOT MATCHED THEN
INSERT (
    order_id,
    carrier,
    tracking_no,
    shipped_at,
    delivered_at )
VALUES
    ( s.order_id,
      s.carrier,
      s.tracking_no,
      s.shipped_at,
      s.delivered_at );

-- Status history
MERGE INTO order_status_history h
USING (
    SELECT (
        SELECT order_id
          FROM orders
         WHERE order_number = 'ORD-1002'
    ) order_id,
           'NEW' from_status,
           'PAID' to_status,
           systimestamp - 2 changed_at,
           'System' changed_by,
           'Auto-capture' note
      FROM dual
) s ON ( 1 = 0 )  -- append-only history
WHEN NOT MATCHED THEN
INSERT (
    order_id,
    from_status,
    to_status,
    changed_at,
    changed_by,
    note )
VALUES
    ( s.order_id,
      s.from_status,
      s.to_status,
      s.changed_at,
      s.changed_by,
      s.note );

--------------------------------------------------------------------------------
-- 11) Derived & LOV Views
--------------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_order_summary AS
    SELECT o.order_id,
           o.order_number,
           o.order_date,
           u.full_name AS customer_name,
           d.dept_name,
           o.order_status,
           (
               SELECT
                   LISTAGG(p.product_name,
                           ', ') WITHIN GROUP(
                    ORDER BY oi.order_item_id)
                 FROM order_items oi
                 JOIN products p
               ON p.product_id = oi.product_id
                WHERE oi.order_id = o.order_id
           ) AS items,
           (
               SELECT SUM(oi.quantity * oi.unit_price)
                 FROM order_items oi
                WHERE oi.order_id = o.order_id
           ) AS subtotal,
           (
               SELECT nvl(
                   sum(amount),
                   0
               )
                 FROM payments p
                WHERE p.order_id = o.order_id
           ) AS total_paid,
           (
               SELECT MAX(shipped_at)
                 FROM shipments s
                WHERE s.order_id = o.order_id
           ) AS last_shipped_at
      FROM orders o
      JOIN users u
    ON u.user_id = o.user_id
      LEFT JOIN depts d
    ON d.dept_id = o.dept_id;

CREATE OR REPLACE VIEW v_lov_depts AS
    SELECT dept_id AS return_value,
           dept_name AS display_value
      FROM depts
     WHERE deleted_at IS NULL
     ORDER BY dept_name;

CREATE OR REPLACE VIEW v_lov_users AS
    SELECT user_id AS return_value,
           full_name
           || ' <'
           || email
           || '>' AS display_value
      FROM users
     WHERE is_active = 'Y'
       AND deleted_at IS NULL
     ORDER BY full_name;

CREATE OR REPLACE VIEW v_lov_products AS
    SELECT product_id AS return_value,
           product_name
           || ' ('
           || sku
           || ') - $'
           || to_char(
               unit_price,
               '999,990.00'
           ) AS display_value
      FROM products
     WHERE active = 'Y'
       AND deleted_at IS NULL
     ORDER BY product_name;

--------------------------------------------------------------------------------
-- 12) Simple data sanity checks (optional)
--------------------------------------------------------------------------------
-- select * from v_order_summary order by order_id;
-- select * from v_lov_products;
-- select * from orders;
--------------------------------------------------------------------------------
-- Done.
--------------------------------------------------------------------------------