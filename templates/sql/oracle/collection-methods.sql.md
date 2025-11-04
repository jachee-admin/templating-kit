All PL/SQL collections (associative arrays, nested tables, varrays) support some common methods like `.COUNT`, `.DELETE`, `.EXISTS`, `.FIRST`, `.LAST`, `.NEXT`, and `.PRIOR`. But **not every method applies to every collection type** — for example, `.TRIM` and `.EXTEND` work only on nested tables and varrays, while `.LIMIT` applies only to varrays.

---

## 🔎 Collection Methods by Type

Here’s the breakdown:

| **Method**   | **Associative Array** | **Nested Table** | **Varray** |
|--------------|------------------------|------------------|------------|
| `.COUNT`     | ✅ Yes | ✅ Yes | ✅ Yes |
| `.DELETE`    | ✅ Yes (delete elements or whole collection) | ✅ Yes (delete elements or whole collection) | ❌ No |
| `.EXISTS(n)` | ✅ Yes | ✅ Yes | ✅ Yes |
| `.FIRST`     | ✅ Yes | ✅ Yes | ✅ Yes |
| `.LAST`      | ✅ Yes | ✅ Yes | ✅ Yes |
| `.NEXT(n)`   | ✅ Yes | ✅ Yes | ✅ Yes |
| `.PRIOR(n)`  | ✅ Yes | ✅ Yes | ✅ Yes |
| `.TRIM`      | ❌ No | ✅ Yes | ✅ Yes |
| `.EXTEND`    | ❌ No | ✅ Yes | ✅ Yes |
| `.LIMIT`     | ❌ No | ❌ No | ✅ Yes (returns max size of varray) |

---

## ✅ Usage Notes

- **Associative arrays**
  - Unbounded, sparse.
  - Support navigation methods (`FIRST`, `LAST`, `NEXT`, `PRIOR`) and deletion of arbitrary elements.
  - No `.TRIM` or `.EXTEND` because they grow/shrink automatically by assignment.

- **Nested tables**
  - Start dense but can become sparse after `.DELETE`.
  - Support `.TRIM` and `.EXTEND` to manage size.
  - Can be stored in database columns.

- **Varrays**
  - Always dense and bounded.
  - Support `.TRIM` and `.EXTEND` but within their declared maximum size.
  - `.LIMIT` is unique to varrays, returning the declared upper bound.

---

## ⚡ Example

```plsql
DECLARE
   TYPE t_numlist IS TABLE OF NUMBER;
   l_nums t_numlist := t_numlist(10, 20, 30);

   TYPE t_varray IS VARRAY(5) OF VARCHAR2(20);
   l_vnames t_varray := t_varray('A', 'B');
BEGIN
   DBMS_OUTPUT.PUT_LINE('Nested table count: ' || l_nums.COUNT); -- 3
   l_nums.TRIM; -- works
   DBMS_OUTPUT.PUT_LINE('After TRIM: ' || l_nums.COUNT); -- 2

   DBMS_OUTPUT.PUT_LINE('Varray limit: ' || l_vnames.LIMIT); -- 5
   l_vnames.EXTEND; -- works
   DBMS_OUTPUT.PUT_LINE('Varray count: ' || l_vnames.COUNT); -- 3
END;
```

---

## 📌 Key Takeaway
- **Common methods**: `.COUNT`, `.EXISTS`, `.FIRST`, `.LAST`, `.NEXT`, `.PRIOR` work on all collections.
- **Growth/shrink methods**: `.EXTEND` and `.TRIM` only for nested tables and varrays.
- **Special case**: `.LIMIT` only for varrays.
- **Deletion**: `.DELETE` works for associative arrays and nested tables, not varrays.
