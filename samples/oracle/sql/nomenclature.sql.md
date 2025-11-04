###### Oracle PL/SQL

## Use of `l_`

- **Scope clarity**: `l_` indicates the variable is declared inside a block, procedure, or function and is not global or a parameter.
- **Readability**: When you see `l_emp`, you immediately know it’s a *local variable* holding employee data.
- **Avoids conflicts**: Helps distinguish between variables, parameters, constants, and database column names.

---

## Common PL/SQL Naming Prefixes

Here are some widely used conventions:

| Prefix | Meaning                 | Example                |
| ------ | ----------------------- | ---------------------- |
| `l_`   | Local variable          | `l_emp`, `l_count`     |
| `p_`   | Parameter               | `p_deptno`, `p_salary` |
| `g_`   | Global/package variable | `g_cache`, `g_user_id` |
| `c_`   | Constant                | `c_max_salary`         |
| `r_`   | Record type variable    | `r_emp`                |
| `t_`   | Collection type         | `t_emp_tab`            |
| `e_`   | Exception               | `e_invalid_data`       |

---

## Example in Context

```plsql
CREATE OR REPLACE PROCEDURE give_raise (
   p_empno   IN emp.empno%TYPE,
   p_percent IN NUMBER
) IS
   l_old_sal emp.sal%TYPE;
   l_new_sal emp.sal%TYPE;
BEGIN
   SELECT sal INTO l_old_sal
   FROM emp
   WHERE empno = p_empno;

   l_new_sal := l_old_sal * (1 + p_percent/100);

   UPDATE emp
      SET sal = l_new_sal
    WHERE empno = p_empno;
END;
```

- `p_empno`, `p_percent` → parameters.
- `l_old_sal`, `l_new_sal` → local variables.

---

## Key Takeaway

The `l_` prefix is not enforced by Oracle—it’s a **best practice convention**. It makes code easier to read, maintain, and debug, especially in large PL/SQL programs where you juggle parameters, globals, locals, and database columns.
