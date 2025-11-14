/*  COMPOSITE DATA TYPES */
DECLARE
  TYPE t_emp IS RECORD (
    id emp.id%TYPE,
    name emp.fname%TYPE,
    hire_date  emp.hire_date%TYPE
  );
  v_emp t_emp;
BEGIN
  SELECT id, fname, hire_date
  INTO v_emp
  FROM emp WHERE id = 1;
  DBMS_OUTPUT.PUT_LINE('ID: ' || v_emp.id || ', NAME: ' || v_emp.name || ', HIRE_DATE: ' || TO_CHAR(v_emp.hire_date,'MM/DD/YYYY HH24:MI:SS'));


END;

/* COLLECTIONS */
DECLARE
  TYPE t_nums IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  v_nums t_nums;
BEGIN
  v_nums(1) := 10;
  v_nums(2) := 20;
  v_nums(3) := 30;
  FOR i IN 1..v_nums.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE('Value at index ' || i || ': ' || v_nums(i));
  END LOOP;
      

END;




truncate table staging_emp 

select * from staging_emp

begin
-- INSERTING DATA INTO STAGING_EMP
Insert into STAGING_EMP (EMPNO,ENAME,JOB,MGR,HIREDATE,SAL,COMM,DEPTNO) values ('GB9369','SMITH','CLERK','7902','17-DEC-80','800',null,'20');
-- INVALID DATE
Insert into STAGING_EMP (EMPNO,ENAME,JOB,MGR,HIREDATE,SAL,COMM,DEPTNO) values ('9499','ALLEN','SALESMAN','7698','20-FEB-81','1600','300','30');
-- INVALID NUMBER FOR DEPTNO
Insert into STAGING_EMP (EMPNO,ENAME,JOB,MGR,HIREDATE,SAL,COMM,DEPTNO) values ('9521','WARD','SALESMAN','7698','22-FEB-81','1250','500','SALES');
-- INVALID NUMBER FOR EMPNO KEY
Insert into STAGING_EMP (EMPNO,ENAME,JOB,MGR,HIREDATE,SAL,COMM,DEPTNO) values ('US9566','JONES','MANAGER','7839','02-APR-81','2975',null,'20');
Insert into STAGING_EMP (EMPNO,ENAME,JOB,MGR,HIREDATE,SAL,COMM,DEPTNO) values ('9782','CLARK','MANAGER','7839','09-JUN-81','2450',null,'10');
-- INVALID NUMBER FOR EMPNO KEY
Insert into STAGING_EMP (EMPNO,ENAME,JOB,MGR,HIREDATE,SAL,COMM,DEPTNO) values ('FR9788','SCOTT','ANALYST','7566','19-APR-87','3000',null,'20');
-- INVALID NUMBER FOR MGR KEY
Insert into STAGING_EMP (EMPNO,ENAME,JOB,MGR,HIREDATE,SAL,COMM,DEPTNO) values ('9839','KING','PRESIDENT',null,'17-NOV-81','5000',null,'10');
-- INVALID NUMBER FOR EMPNO KEY
Insert into STAGING_EMP (EMPNO,ENAME,JOB,MGR,HIREDATE,SAL,COMM,DEPTNO) values ('DE9844','TURNER','SALESMAN','7698','08-SEP-81','1500',0,'30');
Insert into STAGING_EMP (EMPNO,ENAME,JOB,MGR,HIREDATE,SAL,COMM,DEPTNO) values ('9876','ADAMS','CLERK','7788','23-MAY-87','1100',null,'20');
end;


CREATE TABLE EMP
 ( EMPNO NUMBER(4,0), 
   ENAME VARCHAR2(10 BYTE),
   JOB VARCHAR2(9 BYTE),
   MGR NUMBER(4,0),
   HIREDATE DATE,
   SAL NUMBER(7,2),
   COMM NUMBER(7,2),
   DEPTNO NUMBER(2,0),
CONSTRAINT PK_EMP PRIMARY KEY (EMPNO));

INSERT INTO emp SELECT * FROM staging_emp;

SELECT
  VALIDATE_CONVERSION(empno AS NUMBER) AS is_empno,
  VALIDATE_CONVERSION(mgr AS NUMBER) AS is_mgr,
  VALIDATE_CONVERSION(hiredate AS DATE) AS is_hiredate,
  VALIDATE_CONVERSION(sal AS NUMBER) AS is_sal,
  VALIDATE_CONVERSION(comm AS NUMBER) AS is_comm,
  VALIDATE_CONVERSION(deptno AS NUMBER) AS is_deptno
FROM staging_emp;

INSERT INTO emp
SELECT
  empno,
  ename,
  job,
  CAST(mgr AS NUMBER DEFAULT 9999 ON CONVERSION ERROR),
  CAST(hiredate AS DATE DEFAULT sysdate ON CONVERSION ERROR),
  CAST(sal AS NUMBER DEFAULT 0 ON CONVERSION ERROR),
  CAST(comm AS NUMBER DEFAULT null ON CONVERSION ERROR),
  CAST(deptno AS NUMBER DEFAULT 99 ON CONVERSION ERROR)
FROM staging_emp
WHERE VALIDATE_CONVERSION(empno AS NUMBER) = 1;

 IF SQL%ROWCOUNT = 1 THEN
    ROLLBACK TO first_insert; -- undo Tesla, keep Curie
  END IF;

look up different collection TYPES

Cursor attributes:
SQL%FOUND
%NOTFOUND
SQL%ROWCOUNT
%ISOPEN  --explicit only


  OPEN emp_cur;
  LOOP
    FETCH emp_cur INTO v_id, v_name, v_salary;
    EXIT WHEN emp_cur%NOTFOUND; -- use attribute
    DBMS_OUTPUT.PUT_LINE('Fetched row ' || emp_cur%ROWCOUNT || ': ' ||
                         v_id || ' - ' || v_name || ' - ' || v_salary);
  END LOOP;

  IF dept_cur%ISOPEN THEN
    DBMS_OUTPUT.PUT_LINE('Cursor already open!');
  ELSE
    OPEN dept_cur;
  END IF;

-- ADVANCED: SAVE EXCEPTIONS
DECLARE
   TYPE t_ids IS TABLE OF NUMBER;
   l_ids t_ids := t_ids(301, 302, 9999); -- 9999 doesn’t exist
BEGIN
   FORALL i IN 1 .. l_ids.COUNT SAVE EXCEPTIONS
      DELETE FROM employees
      WHERE employee_id = l_ids(i);

EXCEPTION
   WHEN OTHERS THEN
      FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
         DBMS_OUTPUT.PUT_LINE('Error at index ' ||
           SQL%BULK_EXCEPTIONS(j).ERROR_INDEX ||
           ' : ' ||
           SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE));
      END LOOP;
END;
/