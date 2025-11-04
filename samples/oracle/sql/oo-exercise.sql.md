**Here’s a concrete, real‑world style assignment:** Build an **Object‑Oriented PL/SQL domain model** for a simplified **Banking & Customer Management System**. This goes beyond CRUD procedures and forces you to use **object types, inheritance, methods, nested collections, and object tables** to model real entities and behaviors inside the database.

---

## 📘 Assignment: Banking & Customer Domain in Object‑Oriented PL/SQL

### Scenario
Your company wants to model customers, their accounts, and transactions directly in Oracle using **object types**. The goal is to encapsulate both **data** and **behavior** in the database layer, so that business logic is reusable across PL/SQL and SQL queries.

---

### 🔎 Requirements

1. **Define Object Types**
   - `person_obj` (base type): attributes `first_name`, `last_name`, `dob`, and a `display` method.
   - `customer_obj` (subtype of `person_obj`): adds `cust_id`, `email`, and a nested table of `account_obj`.
   - `account_obj`: attributes `acct_no`, `balance`, `acct_type`, with methods:
     - `deposit(amount NUMBER)`
     - `withdraw(amount NUMBER)`
     - `get_balance RETURN NUMBER`
   - `transaction_obj`: attributes `txn_id`, `txn_date`, `amount`, `txn_type`.

2. **Use Inheritance & Polymorphism**
   - `employee_obj` should inherit from `person_obj` and override `display` to show employee role.

3. **Nested Collections**
   - `customer_obj` contains a nested table of `account_obj`.
   - `account_obj` contains a nested table of `transaction_obj`.

4. **Object Tables**
   - Create an object table `customers` of type `customer_obj`.
   - Store multiple customers, each with their own accounts and transactions.

5. **Methods in Action**
   - Write a PL/SQL block that:
     - Creates a new `customer_obj` with two accounts.
     - Calls `deposit` and `withdraw` methods.
     - Inserts the customer into the `customers` object table.
     - Queries back the customer and unnests accounts/transactions with `TABLE()`.

6. **Bonus: Pipelined Function**
   - Write a pipelined function `get_all_transactions` that returns all transactions across all customers as rows, so you can query:
     ```sql
     SELECT * FROM TABLE(get_all_transactions());
     ```

---

### ✅ Example Skeleton

```sql
-- Base type
CREATE TYPE person_obj AS OBJECT (
   first_name VARCHAR2(50),
   last_name  VARCHAR2(50),
   dob        DATE,
   MEMBER PROCEDURE display
) NOT FINAL;
/

-- Subtype
CREATE TYPE customer_obj UNDER person_obj (
   cust_id NUMBER,
   email   VARCHAR2(100),
   accounts account_tab, -- nested table of accounts
   OVERRIDING MEMBER PROCEDURE display
);
/

-- Account type
CREATE TYPE account_obj AS OBJECT (
   acct_no   NUMBER,
   balance   NUMBER,
   acct_type VARCHAR2(20),
   txns      transaction_tab,
   MEMBER PROCEDURE deposit(p_amt NUMBER),
   MEMBER PROCEDURE withdraw(p_amt NUMBER),
   MEMBER FUNCTION get_balance RETURN NUMBER
);
/
```

*(You’d then define `transaction_obj`, the nested table types, and the type bodies with method logic.)*

---

### 🎯 Deliverables
- **DDL**: All object types, nested table types, and object tables.
- **DML**: PL/SQL block that instantiates customers, accounts, and transactions.
- **Queries**: SQL queries using `TABLE()` to unnest accounts and transactions.
- **Bonus**: Pipelined function to expose transactions as a queryable table.

---

## ⚡ Why This Matters
This assignment mimics **real business domains** (banking, insurance, telecom) where:
- Customers have multiple accounts/policies/contracts.
- Accounts have transactions/events.
- Employees and customers share attributes but differ in behavior.
- Business logic (deposit, withdraw, calculate interest) belongs with the data.

It forces you to use **object‑oriented PL/SQL** to model entities, relationships, and behaviors, not just procedural CRUD.

---

👉 I can expand this into a **step‑by‑step lab** (with full code for each type, body, and test block) so you can run it end‑to‑end. Do you want me to flesh out the **full banking example with working code**?