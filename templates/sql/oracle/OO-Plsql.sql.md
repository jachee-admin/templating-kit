###### Oracle PL/SQL

# Object-Oriented PL/SQL
---

## 1. Object with Attributes + Methods
```sql
-- Object type specification
CREATE OR REPLACE TYPE account_obj AS OBJECT (
   acct_no   NUMBER,
   balance   NUMBER,
   MEMBER PROCEDURE deposit (amt NUMBER),
   MEMBER FUNCTION get_balance RETURN NUMBER
);
/

-- Object type body
CREATE OR REPLACE TYPE BODY account_obj AS
   MEMBER PROCEDURE deposit (amt NUMBER) IS
   BEGIN
      SELF.balance := NVL(SELF.balance,0) + amt;
   END;
   MEMBER FUNCTION get_balance RETURN NUMBER IS
   BEGIN
      RETURN SELF.balance;
   END;
END;
/

-- Usage
DECLARE
   l_acct account_obj := account_obj(1001, 500);
BEGIN
   l_acct.deposit(250);
   DBMS_OUTPUT.PUT_LINE('Balance = ' || l_acct.get_balance); -- 750
END;
/
```

---

## 2. Custom Constructor
```sql
CREATE OR REPLACE TYPE email_obj AS OBJECT (
   address VARCHAR2(320),
   CONSTRUCTOR FUNCTION email_obj(p_addr VARCHAR2) RETURN SELF AS RESULT
);
/

CREATE OR REPLACE TYPE BODY email_obj AS
   CONSTRUCTOR FUNCTION email_obj(p_addr VARCHAR2) RETURN SELF AS RESULT IS
   BEGIN
      IF NOT REGEXP_LIKE(p_addr, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
         RAISE_APPLICATION_ERROR(-20001, 'Invalid email format');
      END IF;
      SELF.address := p_addr;
      RETURN;
   END;
END;
/

-- Usage
DECLARE
   l_email email_obj;
BEGIN
   l_email := email_obj('john.doe@example.com');
   DBMS_OUTPUT.PUT_LINE('Email = ' || l_email.address);
END;
/
```

---

## 3. Inheritance + Polymorphism
```sql
-- Base type
CREATE OR REPLACE TYPE person_obj AS OBJECT (
   name VARCHAR2(50),
   MEMBER PROCEDURE display
) NOT FINAL;
/

CREATE OR REPLACE TYPE BODY person_obj AS
   MEMBER PROCEDURE display IS
   BEGIN
      DBMS_OUTPUT.PUT_LINE('Person: ' || name);
   END;
END;
/

-- Subtype
CREATE OR REPLACE TYPE employee_obj UNDER person_obj (
   empno NUMBER,
   OVERRIDING MEMBER PROCEDURE display
);
/

CREATE OR REPLACE TYPE BODY employee_obj AS
   OVERRIDING MEMBER PROCEDURE display IS
   BEGIN
      DBMS_OUTPUT.PUT_LINE('Employee: ' || name || ' (ID ' || empno || ')');
   END;
END;
/

-- Usage
DECLARE
   p person_obj := person_obj('Generic Person');
   e employee_obj := employee_obj('Alice', 101);
BEGIN
   p.display; -- Person: Generic Person
   e.display; -- Employee: Alice (ID 101)
END;
/
```

---

## 4. Object Tables
```sql
-- Object type
CREATE OR REPLACE TYPE customer_obj AS OBJECT (
   cust_id   NUMBER,
   cust_name VARCHAR2(50)
);
/

-- Object table
CREATE TABLE customers OF customer_obj;

-- Insert rows
INSERT INTO customers VALUES (customer_obj(1,'John'));
INSERT INTO customers VALUES (customer_obj(2,'Mary'));

-- Query
SELECT c.cust_id, c.cust_name
FROM customers c;
```

---

## 5. Nested Collections of Objects
```sql
-- Phone object
CREATE OR REPLACE TYPE phone_obj AS OBJECT (
   phone_no VARCHAR2(20),
   phone_type VARCHAR2(10)
);
/

-- Nested table of phones
CREATE OR REPLACE TYPE phone_tab AS TABLE OF phone_obj;
/

-- Customer with nested table
CREATE OR REPLACE TYPE customer2_obj AS OBJECT (
   cust_id   NUMBER,
   cust_name VARCHAR2(50),
   phones    phone_tab
);
/

-- Table of customers
CREATE TABLE customers2 OF customer2_obj
   NESTED TABLE phones STORE AS phones_nt;

-- Insert with nested collection
INSERT INTO customers2 VALUES (
   customer2_obj(1,'John',
      phone_tab(phone_obj('123-4567','HOME'),
                phone_obj('987-6543','WORK')))
);

-- Query unnesting phones
SELECT c.cust_name, p.phone_no, p.phone_type
FROM customers2 c, TABLE(c.phones) p;
```

---

## ⚡ Key Takeaways
- **Objects with methods** let you encapsulate behavior.
- **Constructors** allow validation/logic at creation time.
- **Inheritance** enables polymorphism and method overriding.
- **Object tables** persist objects directly in relational form.
- **Nested collections** model one‑to‑many relationships inside a single row.

---
