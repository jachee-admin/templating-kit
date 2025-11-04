Collections in PL/SQL come in three flavors—**associative arrays, nested tables, and varrays**—and the right choice depends on whether you need bounded vs. unbounded size, dense vs. sparse indexing, and database storage. Here’s a decision tree to guide you.

---

## 🌳 PL/SQL Collection Type Decision Tree

**Step 1: Do you need to store the collection in a database column?**
- **Yes** → Use **Nested Table** or **Varray**.
  - **Do you need a fixed maximum size?**
    - **Yes** → **Varray** (bounded, always dense, `.LIMIT` available).
    - **No** → **Nested Table** (unbounded, can start dense but become sparse).
- **No** → Go to Step 2.

**Step 2: Do you need string or non-sequential keys for indexing?**
- **Yes** → **Associative Array** (index-by table, unbounded, sparse, only in PL/SQL).
- **No** → Go to Step 3.

**Step 3: Do you need bounded size?**
- **Yes** → **Varray**.
- **No** → **Nested Table**.

---

## 🔎 Quick Feature Comparison

| Feature                  | Associative Array | Nested Table | Varray |
|---------------------------|------------------|--------------|--------|
| **Bounded?**             | No (unbounded)   | No (unbounded) | Yes (fixed max) |
| **Dense or Sparse?**     | Sparse           | Starts dense, can become sparse | Always dense |
| **Index type**           | Integer or String| Integer       | Integer |
| **Database storage**     | No               | Yes           | Yes |
| **Collection methods**   | `.COUNT`, `.DELETE`, `.EXISTS`, `.FIRST`, `.LAST`, `.NEXT`, `.PRIOR` | Same as associative arrays + `.TRIM`, `.EXTEND` | Same as nested tables + `.LIMIT` |
| **Best for**             | Lookup tables, key-value pairs | Bulk operations, DB persistence | Small, fixed-size lists |

---

## ✅ Example Use Cases
- **Associative Array**: Caching salaries keyed by employee name.
- **Nested Table**: Storing a list of phone numbers per customer in a DB column.
- **Varray**: Storing up to 5 most recent order IDs inline with a row.

---

## ⚡ Key Takeaway
- **Associative arrays** → flexible, in-memory, sparse, not storable in DB.
- **Nested tables** → unbounded, storable in DB, good for bulk operations.
- **Varrays** → bounded, dense, storable inline, good for small fixed lists.

---

Would you like me to **draw this decision tree as a text-based flowchart** so you can visualize the branching more clearly?