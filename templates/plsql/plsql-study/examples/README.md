## Oracle PL/SQL(Procedural Language / Standard Query Language) CheatSheet

### Contents
- [Blocks](#blocks)
- [Variables](#variables)
- [Constant](#constant)
- [Select Into](#select-into)
- [%Type](#type)
- [Conditions](#conditions)
- [Case](#case)
- [Loops](#loops)
- [Triggers](#triggers)
- [Cursors](#cursors)
- [Records](#records)
- [Functions](#functions)
- [Stored Procedure](#stored-procedure)
- [Package](#package)
- [Exceptions](#exceptions)
- [Collections](#collections)
- [Object Oriented](#object-oriented)

### Blocks
```sql
SET SERVEROUTPUT ON;
DECLARE
    --Declaration statements
BEGIN
    --Executable statements
    NULL;
EXCEPTION
    WHEN OTHERS THEN NULL;
    --Exception handling statements
END;
```

### Variables
###### Data Types
- Scalar
> Number, Date, Boolean, Character
- Large Object
> Large Text, Picture - BFILE, BLOB, CLOB, NCLOB
- Composite
> Collections, Records
- Reference

```sql
--NUMBER(precision,scale)
v_number NUMBER(5,2) := 5.01;
v_character VARCHAR2(20) := 'test';
newyear DATE:='01-JAN-2020';
current_date DATE:=SYSDATE;
```

### Constant
```sql
DECLARE
	v_pi CONSTANT NUMBER(7,6) := 3.141592;
BEGIN
	DBMS_OUTPUT.PUT_LINE(v_pi);
END;
```
### Select Into
```sql
DECLARE
	v_last_name VARCHAR2(20);
BEGIN
	SELECT last_name INTO v_last_name FROM persons WHERE person_id = 1;
	DBMS_OUTPUT.PUT_LINE('Last name: ' || v_last_name);
END;
```

### %Type
```sql
DECLARE
	v_last_name persons.last_name%TYPE;
BEGIN
	SELECT last_name INTO v_last_name FROM persons WHERE person_id = 1;
	DBMS_OUTPUT.PUT_LINE('Last Name: ' || v_last_name);
END;
```

### Conditions
```sql
DECLARE
	v_num NUMBER := &enter_a_number;
BEGIN
	IF MOD(v_num,2) = 0 THEN
	    DBMS_OUTPUT.PUT_LINE(v_num || ' is even');
	ELSIF MOD(v_num,2) = 1 THEN
	    DBMS_OUTPUT.PUT_LINE(v_num || ' is odd');
	ELSE
	    DBMS_OUTPUT.PUT_LINE('None');
	END IF;
END;
```
### Case
```sql
SET SERVEROUTPUT ON;
DECLARE
    a NUMBER :=65;
    b NUMBER :=2;
    arth_operation VARCHAR2(20) :='MULTIPLY';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Program started.' );
    CASE (arth_operation)
        WHEN 'ADD' THEN
	        DBMS_OUTPUT.PUT_LINE('Addition of the numbers are: '|| a+b );
        WHEN 'SUBTRACT' THEN
	        DBMS_OUTPUT.PUT_LINE('Subtraction of the numbers are: '||a-b );
        WHEN 'MULTIPLY' THEN
	        DBMS_OUTPUT.PUT_LINE('Multiplication of the numbers are: '|| a*b);
        WHEN 'DIVIDE' THEN
	        DBMS_OUTPUT.PUT_LINE('Division of the numbers are:'|| a/b);
        ELSE
	        DBMS_OUTPUT.PUT_LINE('No operation action defined. Invalid operation');
    END CASE;
    DBMS_OUTPUT.PUT_LINE('Program completed.' );
END;

--Searched case
DECLARE
    a NUMBER :=70;
    b NUMBER :=2;
    arth_operation VARCHAR2(20) :='DIVIDE';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Program started.' );
    CASE
        WHEN arth_operation = 'ADD' THEN
            DBMS_OUTPUT.PUT_LINE('Addition of the numbers are: '||a+b );
        WHEN arth_operation = 'SUBTRACT' THEN
            DBMS_OUTPUT.PUT_LINE('Subtraction of the numbers are: '|| a-b);
        WHEN arth_operation = 'MULTIPLY' THEN
            DBMS_OUTPUT.PUT_LINE('Multiplication of the numbers are: '|| a*b );
        WHEN arth_operation = 'DIVIDE' THEN
            DBMS_OUTPUT.PUT_LINE('Division of the numbers are: '|| a/b );
        ELSE
            DBMS_OUTPUT.PUT_LINE('No operation action defined. Invalid operation');
    END CASE;
    DBMS_OUTPUT.PUT_LINE('Program completed.' );
END;
```

### Loops
```sql
--Simple Loop
DECLARE
	v_num number(5) := 0;
BEGIN
	LOOP
	    v_num := v_num + 1;
	    DBMS_OUTPUT.PUT_LINE('Number: ' || v_num);

	    EXIT WHEN v_num = 3;
	    /*
	    if v_num = 3 then
	        exit;
	    end if;
	    */
	END LOOP;
END;

--While Loop
DECLARE
	v_num NUMBER := 0;
BEGIN
	WHILE v_num <= 100 LOOP

	    EXIT WHEN v_num > 40;

	    IF v_num = 20 THEN
	        v_num := v_num + 1;
	        CONTINUE;
	    END IF;

	    IF MOD(v_num,10) = 0 THEN
	        DBMS_OUTPUT.PUT_LINE(v_num || ' CAN BE DIVIDED BY 10.');
	    END IF;

	    v_num := v_num + 1;

	END LOOP;
END;

--FOR LOOP
DECLARE
	v_num NUMBER := 0;
BEGIN
	FOR x IN 10 .. 13 LOOP
	    DBMS_OUTPUT.PUT_LINE(x);
	END LOOP;

	FOR x IN REVERSE 13 .. 15 LOOP
	    IF MOD(x,2) = 0 THEN
	        DBMS_OUTPUT.PUT_LINE('EVEN: ' || x);
	    ELSE
	        DBMS_OUTPUT.PUT_LINE('ODD: ' || x);
	    END IF;
	END LOOP;
END;
```

### Triggers
```sql
-- DML Triggers
CREATE OR REPLACE TRIGGER tr_persons
BEFORE INSERT OR DELETE OR UPDATE ON persons
FOR EACH ROW
ENABLE
DECLARE
	v_user varchar2(20);
BEGIN
	SELECT user INTO v_user FROM dual;
	IF INSERTING THEN
		DBMS_OUTPUT.PUT_LINE('One line inserted by ' || v_user);
	ELSIF DELETING THEN
		DBMS_OUTPUT.PUT_LINE('One line Deleted by ' || v_user);
	ELSIF UPDATING THEN
		DBMS_OUTPUT.PUT_LINE('One line Updated by ' || v_user);
	END IF;
END;

--

CREATE OR REPLACE TRIGGER persons_audit
BEFORE INSERT OR DELETE OR UPDATE ON persons
FOR EACH ROW
ENABLE
DECLARE
  v_user varchar2 (30);
  v_date  varchar2(30);
BEGIN
  SELECT user, TO_CHAR(sysdate, 'DD/MON/YYYY HH24:MI:SS') INTO v_user, v_date  FROM dual;
  IF INSERTING THEN
    INSERT INTO sh_audit (new_name,old_name, user_name, entry_date, operation)
    VALUES(:NEW.LAST_NAME, Null , v_user, v_date, 'Insert');
  ELSIF DELETING THEN
    INSERT INTO sh_audit (new_name,old_name, user_name, entry_date, operation)
    VALUES(NULL,:OLD.LAST_NAME, v_user, v_date, 'Delete');
  ELSIF UPDATING THEN
    INSERT INTO sh_audit (new_name,old_name, user_name, entry_date, operation)
    VALUES(:NEW.LAST_NAME, :OLD.LAST_NAME, v_user, v_date,'Update');
  END IF;
END;

-- DDL Triggers
CREATE OR REPLACE TRIGGER db_audit_tr
AFTER DDL ON DATABASE
BEGIN
    INSERT INTO schema_audit VALUES (
		SYSDATE,
		sys_context('USERENV','CURRENT_USER'),
		ora_dict_obj_type,
		ora_dict_obj_name,
		ora_sysevent);
END;

-- Instead of Triggers
CREATE VIEW vw_twotable AS
SELECT full_name, subject_name FROM persons, subjects;

CREATE OR REPLACE TRIGGER tr_Insert
INSTEAD OF INSERT ON vw_twotable
FOR EACH ROW
BEGIN
  INSERT INTO persons (full_name) VALUES (:new.full_name);
  INSERT INTO subjects (subject_name) VALUES (:new.subject_name);
END;

INSERT INTO vw_twotable VALUES ('Caner','subject');
```
### Cursors
```sql
--%FOUND
--%NOTFOUND
--%ISOPEN
--%ROWCOUNT

DECLARE
    v_first_name VARCHAR2(20);
    v_last_name  VARCHAR2(20);
    CURSOR test_cursor IS
    SELECT first_name,
           last_name
      FROM persons;
BEGIN
    OPEN test_cursor;
    LOOP
        FETCH test_cursor INTO
            v_first_name,
            v_last_name;
        EXIT WHEN test_cursor%notfound;
        DBMS_OUTPUT.PUT_LINE('Name: ' || v_first_name || ', Lastname: '|| v_last_name);
    END LOOP;
    CLOSE test_cursor;
END;

----

DECLARE
    v_first_name VARCHAR2(20);
    v_last_name  VARCHAR2(20);
    CURSOR test_cursor ( first_name_parameter VARCHAR2 ) IS
    SELECT first_name,
           last_name
      FROM persons
     WHERE first_name = first_name_parameter;
BEGIN
    OPEN test_cursor('caner');
    LOOP
        FETCH test_cursor INTO
            v_first_name,
            v_last_name;
        EXIT WHEN test_cursor%notfound;
        DBMS_OUTPUT.PUT_LINE('Name: '|| v_first_name|| ', Lastname: '|| v_last_name);
    END LOOP;
    CLOSE test_cursor;
END;

----

DECLARE
    v_first_name VARCHAR2(20);
    v_last_name  VARCHAR2(20);
    CURSOR test_cursor (first_name_parameter VARCHAR2 := 'caner') IS
    SELECT first_name,
           last_name
      FROM persons
     WHERE first_name = first_name_parameter;
BEGIN
    OPEN test_cursor;
    LOOP
        FETCH test_cursor INTO
            v_first_name,
            v_last_name;
        EXIT WHEN test_cursor%notfound;
        DBMS_OUTPUT.PUT_LINE('Name: '|| v_first_name|| ', Lastname: '|| v_last_name);
    END LOOP;
    CLOSE test_cursor;
END;

--for
DECLARE
    CURSOR test_cursor IS
    SELECT first_name,
           last_name
      FROM persons;
BEGIN
    FOR obj IN test_cursor LOOP
        DBMS_OUTPUT.PUT_LINE('Name: '|| obj.first_name|| ', Lastname: '|| obj.last_name);
    END LOOP;
END;

--for parameter
DECLARE
    CURSOR test_cursor (first_name_parameter VARCHAR2 := 'caner') IS
    SELECT first_name,
           last_name
      FROM persons
     WHERE first_name = first_name_parameter;
BEGIN
    FOR obj IN test_cursor('caner') LOOP
        DBMS_OUTPUT.PUT_LINE('Name: '|| obj.first_name || ', Lastname: ' || obj.last_name);
    END LOOP;
END;

```

### Records
```sql
--table based
DECLARE
    v_person persons%ROWTYPE;
BEGIN
    SELECT * INTO v_person FROM persons WHERE person_id = 2;
    DBMS_OUTPUT.PUT_LINE('NAME: ' || v_person.first_name || ', LASTNAME: ' || v_person.last_name);
END;

--

DECLARE
    v_person persons%ROWTYPE;
BEGIN
    SELECT first_name,last_name INTO v_person.first_name,v_person.last_name
    	FROM persons WHERE person_id = 2;
    DBMS_OUTPUT.PUT_LINE('NAME: ' || v_person.first_name || ', LASTNAME: ' || v_person.last_name);
END;

--CURSOR BASED RECORD
DECLARE
    CURSOR test_cursor IS SELECT first_name,last_name FROM persons WHERE person_id = 2;
    v_person test_cursor%ROWTYPE;
BEGIN
    OPEN test_cursor;
    FETCH test_cursor INTO v_person;
    DBMS_OUTPUT.PUT_LINE('NAME: ' || v_person.first_name || ', LASTNAME: ' || v_person.last_name);
    CLOSE test_cursor;
END;

--

DECLARE
    CURSOR test_cursor IS SELECT first_name,last_name FROM persons;
    v_person test_cursor%ROWTYPE;
BEGIN
    OPEN test_cursor;
    LOOP
        FETCH test_cursor INTO v_person;
        EXIT WHEN test_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('NAME: ' || v_person.first_name || ', LASTNAME: ' || v_person.last_name);
    END LOOP;
    CLOSE test_cursor;
END;

--USER BASED

DECLARE
    TYPE rv_person IS RECORD(
        f_name VARCHAR2(20),
        l_name PERSONS.LAST_NAME%TYPE
    );
    v_person rv_person;
BEGIN
    SELECT first_name,last_name INTO v_person.f_name,v_person.l_name FROM persons WHERE person_id = 2;
    DBMS_OUTPUT.PUT_LINE('NAME: ' || v_person.f_name || ', LASTNAME: ' || v_person.l_name);
END;
```

### Functions
```sql
CREATE OR REPLACE FUNCTION circle_area (radius NUMBER)
RETURN NUMBER IS
--Declare a constant and a variable
    pi      CONSTANT NUMBER(7,3) := 3.141;
    area    NUMBER(7,3);
BEGIN
    --Area of Circle pi*r*r;
    area := pi * (radius * radius);
    RETURN area;
END;

BEGIN
	DBMS_OUTPUT.PUT_LINE('Alan: ' || circle_area(10));
END;
```

### Stored Procedure
```sql
CREATE OR REPLACE PROCEDURE pr_test IS
    v_name VARCHAR(20) := 'CANER';
    v_city VARCHAR(20) := 'ISTANBUL';
BEGIN
    DBMS_OUTPUT.PUT_LINE(v_name || ',' || v_city);
END pr_test;
--
EXECUTE pr_test;
--
BEGIN
    pr_test;
END;

----

CREATE OR REPLACE PROCEDURE pr_test_param(V_NAME VARCHAR2 DEFAULT 'CAZ')
IS
    v_city VARCHAR(20) := 'ISTANBUL';
BEGIN
    DBMS_OUTPUT.PUT_LINE(v_name || ',' || v_city);
END pr_test_param;
--
EXECUTE pr_test_param(v_name => 'CAM');

----

CREATE OR REPLACE PROCEDURE pr_test_param(v_name VARCHAR2)
IS
    v_city VARCHAR(20) := 'ISTANBUL';
BEGIN
    DBMS_OUTPUT.PUT_LINE(v_name || ',' || v_city);
END pr_test_param;
--
EXECUTE pr_test_param('CANER');
--
BEGIN
    pr_test_param('CANER');
END;
```

### Package
```sql
CREATE OR REPLACE PACKAGE pkg_person
IS
    FUNCTION get_name (v_name VARCHAR2) RETURN VARCHAR2;
    PROCEDURE proc_update_lastname(p_id NUMBER, l_name VARCHAR2);
END pkg_person;

--Package Body
CREATE OR REPLACE PACKAGE BODY pkg_person
IS
  --Function Implementation
    FUNCTION get_name (v_name VARCHAR2)
    RETURN VARCHAR2
    IS
    BEGIN
        RETURN v_name;
    END get_name;

  --Procedure Implementation
   PROCEDURE proc_update_lastname(p_id NUMBER, l_name VARCHAR2)
   IS
   BEGIN
        UPDATE persons SET last_name = l_name where person_id = p_id;
   END;

END pkg_person;

--
BEGIN
    DBMS_OUTPUT.PUT_LINE(pkg_person.get_name('Caner'));
END;
EXECUTE pkg_person.proc_update_lastname(2,'new lastname');
```

### Exceptions
```sql
ACCEPT p_divisor NUMBER PROMPT 'Enter divisor';
DECLARE
    v_divided NUMBER := 24;
    v_divisor NUMBER := &p_divisor;
    v_result NUMBER;
    ex_four EXCEPTION;
    PRAGMA EXCEPTION_INIT(ex_four,-20001); --20000 , 20999
BEGIN
    IF v_divisor = 4 THEN
        RAISE ex_four;
    END IF;

    IF v_divisor = 5 THEN
        RAISE_APPLICATION_ERROR(-20001,'div five');
    END IF;

    IF v_divisor = 6 THEN
        RAISE_APPLICATION_ERROR(-20002,'div six');
    END IF;

    v_result := v_divided/v_divisor;

    EXCEPTION
        WHEN ex_four THEN  --USER DEFINED
            DBMS_OUTPUT.PUT_LINE('Div four');
            DBMS_OUTPUT.PUT_LINE(SQLERRM);
        WHEN ZERO_DIVIDE THEN --SYSTEM DEFINED
            DBMS_OUTPUT.PUT_LINE('Div zero');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Other exception');
            DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
```

### Collections
```sql
--Nested table
DECLARE
    TYPE my_nested_table IS TABLE OF NUMBER;
    var_nt  my_nested_table :=  my_nested_table (5,12,17,66,44,88,25,45,65);
BEGIN
    FOR i IN 1..var_nt.COUNT
    LOOP
        DBMS_OUTPUT.PUT_LINE ('Value stored at index '||i||' is '||var_nt(i));
    END LOOP;
END;

--VARRAY
DECLARE
    TYPE inBlock_vry IS VARRAY (5) OF NUMBER;
    vry_obj inBlock_vry  :=  inBlock_vry(); --inBlock_vry(null,null,null,null,null);
BEGIN
    --vry_obj.EXTEND(5);
    FOR i IN 1 .. vry_obj.LIMIT
    LOOP
        vry_obj.EXTEND;
        vry_obj (i):= 10*i;
        DBMS_OUTPUT.PUT_LINE (vry_obj (i));
    END LOOP;
END;

--Associative Array(dictionary)
DECLARE
    TYPE books IS TABLE OF NUMBER INDEX BY VARCHAR2 (20);
    isbn books;
BEGIN
    -- How to insert data into the associative array
    isbn('Oracle Database') := 1122;
    isbn('MySQL') := 6543;
    DBMS_OUTPUT.PUT_LINE('Value Before Updation '||isbn('MySQL'));

    -- How to update data of associative array.
    isbn('MySQL') := 2222;

    -- how to retrieve data using key from associative array.
    DBMS_OUTPUT.PUT_LINE('Value After Updation '||isbn('MySQL'));
END;

--

DECLARE
    TYPE books IS TABLE OF NUMBER INDEX BY VARCHAR2 (20);
    isbn books;
    flag VARCHAR2(20);
BEGIN
    isbn('Oracle Database') := 1122;
    isbn('MySQL') := 6543;
    isbn('MySQL') := 2222;
    flag := isbn.FIRST;
    WHILE flag IS NOT NULL
    LOOP
        DBMS_OUTPUT.PUT_LINE('Key -> '||flag||'Value -> '||isbn(flag));
        flag := isbn.NEXT(flag);
    END LOOP;
END;

-----Collection Methods
--Count
DECLARE
    TYPE my_nested_table IS TABLE OF NUMBER;
    var_nt my_nested_table := my_nested_table (5,12,17,66,44,88,25,45,65);
BEGIN
    DBMS_OUTPUT.PUT_LINE ('The Size of the Nested Table is ' ||var_nt.count);
END;


--EXISTS
DECLARE
    TYPE my_nested_table IS TABLE OF VARCHAR2 (20);
	col_var_1   my_nested_table := my_nested_table('Super Man','Iron Man','Bat Man');
BEGIN
    IF col_var_1.EXISTS (4) THEN
        DBMS_OUTPUT.PUT_LINE ('Hey we found '||col_var_1 (1));
    ELSE
        DBMS_OUTPUT.PUT_LINE ('Sorry, no data at this INDEX');
        col_var_1.EXTEND;
        col_var_1(4) := 'Spiderman';
    END IF;
    IF col_var_1.EXISTS (4) THEN
        DBMS_OUTPUT.PUT_LINE ('New data at index 4 '||col_var_1 (4));
    END IF;
END;

--FIRST AND LAST
SET SERVEROUTPUT ON;
DECLARE
    TYPE nt_tab IS TABLE OF NUMBER;
    col_var nt_tab := nt_tab(10, 20, 30, 40, 50);
BEGIN
    col_var.DELETE(1);
    col_var.TRIM;
    DBMS_OUTPUT.PUT_LINE ('First Index of the Nested table is ' || col_var.FIRST);
    DBMS_OUTPUT.PUT_LINE ('Last Index of the Nested table is ' || col_var.LAST);

    DBMS_OUTPUT.PUT_LINE ('Value stored at First Index is ' || col_var(col_var.FIRST));
    DBMS_OUTPUT.PUT_LINE ('Value stored at First Index is ' || col_var(col_var.LAST));
END;

--LIMIT
DECLARE
    TYPE inBlock_vry IS VARRAY (5) OF NUMBER;
    vry_obj inBlock_vry := inBlock_vry();
BEGIN
    DBMS_OUTPUT.PUT_LINE ('Total Indexes '||vry_obj.LIMIT);
END;

--VARRAY
DECLARE
    --Create VARRAY of 5 element
    TYPE inblock_vry IS VARRAY ( 5 ) OF NUMBER;
    vry_obj   inblock_vry := inblock_vry ();
BEGIN
    vry_obj.EXTEND;
    vry_obj(1) := 10 * 2;
    DBMS_OUTPUT.PUT_LINE('Total Number of Index ' || vry_obj.limit);
    DBMS_OUTPUT.PUT_LINE('Total Number of Index which are occupied ' || vry_obj.count);
END;

-- PRIOR AND NEXT
DECLARE
    TYPE my_nested_table IS TABLE OF NUMBER;
    var_nt   my_nested_table := my_nested_table(5,12,17,66,44,88,25,45,65);
BEGIN
    var_nt.DELETE(2);
    DBMS_OUTPUT.PUT_LINE('Index prior to index 3 is '||var_nt.PRIOR(3));
    DBMS_OUTPUT.PUT_LINE('Value before 3rd Index is '||var_nt(var_nt.PRIOR(3)));
END;
--
DECLARE
    TYPE my_nested_table IS TABLE OF NUMBER;
    var_nt   my_nested_table := my_nested_table(5,12,17,66,44,88,25,45,65);
BEGIN
    DBMS_OUTPUT.PUT_LINE('Next Higher Index to index 3 is '||var_nt.NEXT(3));
    DBMS_OUTPUT.PUT_LINE('Value after 3rd Index is '||var_nt(var_nt.NEXT(3)));
END;

--DELETE
DECLARE
    TYPE my_nested_table IS TABLE OF NUMBER;
    var_nt my_nested_table := my_nested_table(2,4,6,8,10,12,14,16,18,20);
BEGIN

    --DELETE RANGE
    var_nt.DELETE(2,6);
    FOR i IN 1..var_nt.LAST LOOP
        IF var_nt.EXISTS(i) THEN
            DBMS_OUTPUT.PUT_LINE('Value at Index ['||i||'] is '|| var_nt(i));
        END IF;
    END LOOP;
END;

--EXTEND
DECLARE
    TYPE my_nestedTable IS TABLE OF number;
    nt_obj  my_nestedTable := my_nestedTable();
BEGIN
    nt_obj.EXTEND;
    nt_obj(1) := 28;
    nt_obj.EXTEND(3);
    nt_obj(2) := 10;
    nt_obj(3) := 20;
    nt_obj(4) := 30;
    DBMS_OUTPUT.PUT_LINE ('Data at index 1 is '||nt_obj(1));
    DBMS_OUTPUT.PUT_LINE ('Data at index 2 is '||nt_obj(2));
    DBMS_OUTPUT.PUT_LINE ('Data at index 3 is '||nt_obj(3));
    DBMS_OUTPUT.PUT_LINE ('Data at index 4 is '||nt_obj(4));
    nt_obj.EXTEND(2,4);
    DBMS_OUTPUT.PUT_LINE ('Data at index 5 is '||nt_obj(5));
    DBMS_OUTPUT.PUT_LINE ('Data at index 6 is '||nt_obj(6));
END;

--TRIM
DECLARE
    TYPE inBlock_vry IS VARRAY (5) OF NUMBER;
    vry_obj inBlock_vry := inBlock_vry(1, 2, 3, 4, 5);
BEGIN
    --TRIM without parameter
    vry_obj.TRIM;
    DBMS_OUTPUT.PUT_LINE ('After TRIM procedure');
    FOR i IN 1..vry_obj.COUNT
    LOOP
        DBMS_OUTPUT.PUT_LINE (vry_obj(i));
    END LOOP;
    --TRIM with Parameter
    vry_obj.TRIM (2);
    DBMS_OUTPUT.PUT_LINE ('After TRIM procedure');
    FOR i IN 1..vry_obj.COUNT
    LOOP
        DBMS_OUTPUT.PUT_LINE (vry_obj(i));
    END LOOP;
END;
--
DECLARE
    TYPE my_nestedTable IS TABLE OF NUMBER;
    nt_obj  my_nestedTable := my_nestedTable(1,2,3,4,5);
BEGIN
    nt_obj.TRIM (3);
    DBMS_OUTPUT.PUT_LINE ('After TRIM procedure');
    FOR i IN 1..nt_obj.COUNT
    LOOP
        DBMS_OUTPUT.PUT_LINE (nt_obj(i));
    END LOOP;
END;
```

### Object Oriented
```sql
CREATE OR REPLACE TYPE Worker AS OBJECT (
    v_id NUMBER(3),
    v_name VARCHAR2(10),
    v_last_name VARCHAR(10),
    v_email VARCHAR(20),
    MEMBER PROCEDURE display,
    MEMBER FUNCTION getName RETURN VARCHAR2,
    STATIC PROCEDURE displaySquare(v_num NUMBER)
);

CREATE OR REPLACE TYPE BODY Worker AS

    MEMBER PROCEDURE display IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('id: '||SELF.v_id);
        DBMS_OUTPUT.PUT_LINE('name: '||SELF.v_name);
        DBMS_OUTPUT.PUT_LINE('lastName : '||SELF.v_last_name);
        DBMS_OUTPUT.PUT_LINE('mail: '||SELF.v_email);
    END;

    MEMBER FUNCTION getName RETURN VARCHAR2 IS
    BEGIN
        RETURN SELF.v_name || ' ' || SELF.v_last_name;
    END;

    STATIC PROCEDURE displaySquare(v_num NUMBER) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Square : '||v_num);
    END;
END;

DECLARE
    v_person Worker := new Worker(1, 'Caner', 'lastName', 'mail@.com');	--constructor
BEGIN
    DBMS_OUTPUT.PUT_LINE('Name: '||v_person.getName());
    v_person.display;
    Worker.displaySquare(2);
END;

```
