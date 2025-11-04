###### Oracle

## PL/SQL Collections - Usage

1. ***<u>Associative Arrays (a.k.a. Index-by Tables)</u>***

These are key-value pairs stored in memory, like a hash or Python dict. The index can be an integer or a string. They’re great for **lookups, temporary caching, or dynamic in-memory data structures** where you don’t need to persist data in a table column.

```plsql
TYPE t_prices IS TABLE OF NUMBER INDEX BY VARCHAR2(30);
v_prices t_prices;
v_prices('apple') := 1.25;
```

2. ***<u>Nested Tables</u>***

These are like resizable arrays that can be **stored in database columns or passed between SQL and PL/SQL**. You can query and manipulate them with `TABLE()` in SQL. They’re useful when you need persistence or want to join table data to in-memory data.

```plsql
TYPE t_ids IS TABLE OF NUMBER;
v_ids t_ids := t_ids(1,2,3);
SELECT * FROM employees WHERE emp_id IN (SELECT * FROM TABLE(v_ids));
```

3. ***<u>Varrays (Variable-size Arrays)</u>***

Varrays are ordered, bounded collections — you define a maximum size. They’re **compact and good for small, fixed-size datasets** that need to preserve order, such as top-N lists, coordinates, or version histories.

```plsql
TYPE t_colors IS VARRAY(5) OF VARCHAR2(20);
v_colors := t_colors('red','green','blue');
```

If you use SQL often, nested tables play nicely with SQL; associative arrays don’t.


