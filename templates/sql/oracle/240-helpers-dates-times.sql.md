###### Oracle PL/SQL
### Dates/Times & NULL helpers — practical toolkit (Oracle 19c)
Copy/paste snippets you’ll actually use in apps, ETL, and reports.

---

## 0) Quick references
```sql
-- Literals
DATE '2025-11-01'                                  -- date (no time)
TIMESTAMP '2025-11-01 14:30:00.000000'             -- timestamp
TIMESTAMP '2025-11-01 14:30:00.000000 +00:00' AT TIME ZONE 'UTC' -- with TZ

-- Current “now”
SELECT SYSDATE, SYSTIMESTAMP, CURRENT_DATE, CURRENT_TIMESTAMP FROM dual;

-- Add/subtract
SELECT SYSDATE + 7 AS in_7_days, SYSDATE - 1 AS yesterday FROM dual;   -- days
SELECT SYSTIMESTAMP + NUMTODSINTERVAL(90,'MINUTE') FROM dual;           -- minutes
````

---

## 1) Parsing & formatting (robust)

```sql
-- Strict parse with FX (exact format); raise on bad data
SELECT TO_DATE('2025-11-01', 'FXYYYY-MM-DD') FROM dual;

-- 12c+ tolerant parse with default value on error
SELECT TO_DATE('BAD',
       'YYYY-MM-DD'
       DEFAULT DATE '1900-01-01' ON CONVERSION ERROR)
FROM dual;

-- Timestamp with TZ
SELECT TO_TIMESTAMP_TZ('2025-11-01T16:30:00-0400',
       'YYYY-MM-DD"T"HH24:MI:SS TZH:TZM')
FROM dual;

-- Formatting
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS') AS isoish FROM dual;
```

**Tip:** Keep a single `constant` for your canonical format (e.g., `'YYYY-MM-DD"T"HH24:MI:SSFF3'`).

---

## 2) Time zones (safe conversions)

```sql
-- Treat a naive timestamp as UTC, then show in America/New_York
SELECT FROM_TZ(TIMESTAMP '2025-11-01 18:00:00', 'UTC')
         AT TIME ZONE 'America/New_York' AS ny_local
FROM dual;

-- Convert DB server time to UTC
SELECT SYSTIMESTAMP AT TIME ZONE 'UTC' FROM dual;

-- Store UTC, display local (example paramized)
SELECT (FROM_TZ(:ts_utc, 'UTC') AT TIME ZONE :tz) FROM dual;
```

**Rules that pay:** Store UTC, convert at the edge; never string-hack time zones.

---

## 3) Truncation & bucketing (report-friendly)

```sql
-- Start of day/week/month/ISO week
SELECT TRUNC(SYSDATE)                         AS day_start,
       TRUNC(SYSDATE, 'IW')                   AS iso_week_start,
       TRUNC(SYSDATE, 'MM')                   AS month_start,
       TRUNC(SYSDATE, 'YYYY')                 AS year_start
FROM dual;

-- Bucket by hour (timestamp)
SELECT CAST(TRUNC(SYSTIMESTAMP, 'HH') AS TIMESTAMP) FROM dual;

-- Last/Next helpers
SELECT LAST_DAY(SYSDATE) AS month_end,
       NEXT_DAY(SYSDATE, 'FRIDAY') AS next_friday
FROM dual;

-- Add months, difference in months (fractions)
SELECT ADD_MONTHS(SYSDATE, 3), MONTHS_BETWEEN(SYSDATE, DATE '2025-01-01')
FROM dual;
```

---

## 4) Intervals & arithmetic

```sql
-- INTERVAL literals
SELECT SYSTIMESTAMP + INTERVAL '2' DAY           AS plus_2d,
       SYSTIMESTAMP + INTERVAL '03:30' HOUR TO MINUTE AS plus_3h30m
FROM dual;

-- Build programmatically
SELECT SYSTIMESTAMP + NUMTODSINTERVAL(45,'MINUTE') FROM dual;
SELECT SYSTIMESTAMP + NUMTOYMINTERVAL(1,'MONTH')  FROM dual;
```

---

## 5) Date series (generate rows)

```sql
-- Daily series between two dates
WITH params AS (
  SELECT DATE '2025-10-01' AS d0, DATE '2025-10-31' AS d1 FROM dual
)
SELECT d0 + LEVEL - 1 AS d
FROM   params
CONNECT BY LEVEL <= (d1 - d0) + 1;

-- Hourly buckets last 24h
SELECT TRUNC(SYSTIMESTAMP - NUMTODSINTERVAL(LEVEL-1,'HOUR'),'HH') AS bucket
FROM dual
CONNECT BY LEVEL <= 24;
```

---

## 6) Range overlap checks (inclusive/exclusive)

```sql
-- Overlap (inclusive end)
-- (a_start <= b_end) AND (b_start <= a_end)
CREATE OR REPLACE FUNCTION ranges_overlap(
  a_start IN DATE, a_end IN DATE, b_start IN DATE, b_end IN DATE
) RETURN BOOLEAN IS
BEGIN
  RETURN (a_start <= b_end) AND (b_start <= a_end);
END;
/

-- Exclusive end (half-open [start, end))
-- (a_start < b_end) AND (b_start < a_end)
```

**Pick one convention and stick to it.** For schedules, half-open is often simpler.

---

## 7) Business-day helpers

```sql
-- Next business day (skip Sat/Sun); extend for holidays via a table
CREATE OR REPLACE FUNCTION next_business_day(p_d IN DATE)
  RETURN DATE
IS
  v DATE := TRUNC(p_d) + 1;
BEGIN
  WHILE TO_CHAR(v,'D') IN ('1','7')  -- NLS dependent! Prefer NLS_DDATE_LANGUAGE='ENGLISH'
  LOOP v := v + 1; END LOOP;
  RETURN v;
END;
/

-- Add N business days
CREATE OR REPLACE FUNCTION add_business_days(p_d IN DATE, p_n IN PLS_INTEGER)
  RETURN DATE
IS
  v DATE := TRUNC(p_d); i PLS_INTEGER := 0;
BEGIN
  WHILE i < p_n LOOP
    v := v + 1;
    IF TO_CHAR(v,'DY','NLS_DATE_LANGUAGE=ENGLISH') NOT IN ('SAT','SUN') THEN
      i := i + 1;
    END IF;
  END LOOP;
  RETURN v;
END;
/
```

---

## 8) NULL helpers (what to use when)

```sql
-- COALESCE: first non-NULL
SELECT COALESCE(email, alt_email, '(missing)') FROM accounts;

-- NVL: two-arg coalesce
SELECT NVL(full_name, '(unknown)') FROM accounts;

-- NVL2(expr, when_not_null, when_null)
SELECT NVL2(updated_at, 'touched', 'never') FROM accounts;

-- NULLIF(a,b): NULL if equal (great for divide-by-zero)
SELECT total / NULLIF(cnt, 0) AS safe_avg FROM stats;

-- GREATEST/LEAST with dates (watch NULL → NULL)
SELECT GREATEST(date_a, date_b) FROM dual;
```

**Patterns**

* Use `COALESCE` in SQL for n-ary fallbacks.
* Use `NULLIF(x,0)` to avoid `ORA-01476: divisor is equal to zero`.
* Be mindful: `GREATEST/LEAST` return **NULL** if any argument is NULL; wrap with `COALESCE`.

---

## 9) SAFE utilities (drop-in)

### 9.1) Safe parse with default

```sql
CREATE OR REPLACE FUNCTION safe_to_date(p_txt IN VARCHAR2, p_fmt IN VARCHAR2,
                                        p_def IN DATE DEFAULT DATE '1900-01-01')
  RETURN DATE
IS
BEGIN
  RETURN TO_DATE(p_txt, 'FX' || p_fmt  -- strict
          DEFAULT p_def ON CONVERSION ERROR);
END;
/

CREATE OR REPLACE FUNCTION safe_to_ts_tz(p_txt IN VARCHAR2, p_fmt IN VARCHAR2,
                                         p_tz  IN VARCHAR2 DEFAULT 'UTC')
  RETURN TIMESTAMP WITH TIME ZONE
IS
  v_ts TIMESTAMP WITH TIME ZONE;
BEGIN
  v_ts := TO_TIMESTAMP_TZ(p_txt, p_fmt
           DEFAULT NULL ON CONVERSION ERROR);
  RETURN COALESCE(v_ts, FROM_TZ(TIMESTAMP '1900-01-01 00:00:00', p_tz));
END;
/
```

### 9.2) Start/end helpers (half-open ranges)

```sql
CREATE OR REPLACE FUNCTION start_of_day(p_ts IN TIMESTAMP) RETURN TIMESTAMP IS
BEGIN
  RETURN TRUNC(p_ts);
END;
/

CREATE OR REPLACE FUNCTION end_of_day_exclusive(p_ts IN TIMESTAMP) RETURN TIMESTAMP IS
BEGIN
  RETURN TRUNC(p_ts) + INTERVAL '1' DAY; -- exclusive
END;
/
```

### 9.3) UTC helpers

```sql
CREATE OR REPLACE FUNCTION utc_now RETURN TIMESTAMP WITH TIME ZONE IS
BEGIN
  RETURN SYSTIMESTAMP AT TIME ZONE 'UTC';
END;
/

CREATE OR REPLACE FUNCTION to_tz(p_ts IN TIMESTAMP WITH TIME ZONE, p_tz IN VARCHAR2)
  RETURN TIMESTAMP WITH TIME ZONE IS
BEGIN
  RETURN p_ts AT TIME ZONE p_tz;
END;
/
```

---

## 10) Common “gotchas” & fixes

* **NLS traps:** `TO_DATE('01-11-2025','DD-MM-YYYY')` is safe; `TO_DATE('01-11-2025')` is **not** (NLS-dependent). Always pass a format model.
* **CURRENT_DATE** is in the **session time zone**; **SYSDATE** uses the server’s. Prefer `SYSTIMESTAMP AT TIME ZONE 'UTC'` for audit columns.
* **BETWEEN** is inclusive on both ends; for date-time ranges prefer half-open (`>= start AND < next_bucket`).
* **Day-of-week with `TO_CHAR(...,'D')`** depends on NLS settings; use `'DY'` with fixed `NLS_DATE_LANGUAGE` or compare to `NEXT_DAY`.
* **GREATEST/LEAST+NULL:** wrap with `COALESCE`.
* **Time zone names:** use IANA zones (e.g., `'America/New_York'`, `'Europe/Copenhagen'`), not fixed offsets—DST matters.

---

## 11) End-to-end example: bucket & aggregate last 30 days (hourly, UTC → local)

```sql
-- Parameters
VAR p_tz VARCHAR2; EXEC :p_tz := 'Europe/Copenhagen';

WITH raw AS (
  SELECT order_id,
         created_at_utc  AS ts_utc
  FROM   orders
  WHERE  created_at_utc >= (SYSTIMESTAMP AT TIME ZONE 'UTC') - INTERVAL '30' DAY
),
loc AS (
  SELECT order_id,
         (FROM_TZ(CAST(ts_utc AS TIMESTAMP), 'UTC') AT TIME ZONE :p_tz) AS ts_local
  FROM   raw
),
bucketed AS (
  SELECT TRUNC(ts_local, 'HH') AS hour_bucket,
         COUNT(*)              AS cnt
  FROM   loc
  GROUP  BY TRUNC(ts_local, 'HH')
)
SELECT hour_bucket, cnt
FROM   bucketed
ORDER  BY hour_bucket;
```

---

## 12) Quick null/date cheat sheet (memory jogger)

```sql
-- Nulls
COALESCE(a,b,c)    NVL(a,b)        NVL2(a,when_not_null,when_null)  NULLIF(a,b)

-- Dates
TRUNC(d[,fmt])     ADD_MONTHS(d,n) MONTHS_BETWEEN(a,b) LAST_DAY(d) NEXT_DAY(d,'MON')
NUMTODSINTERVAL(n,'MINUTE|HOUR|DAY|SECOND')   NUMTOYMINTERVAL(n,'MONTH|YEAR')
FROM_TZ(ts,'UTC') AT TIME ZONE 'Europe/Copenhagen'
TO_DATE(txt, 'FXYYYY-MM-DD' DEFAULT DATE '1900-01-01' ON CONVERSION ERROR)
```
```yaml
---
id: templates/sql/oracle/240-helpers-dates-times.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.13"
tested_on: "Oracle 19c"
tags: [plsql, dates, timestamps, timezones, intervals, parsing, truncation, bucket, business-day, nulls, nvl, coalesce, nullif]
description: "Practical date/time + NULL helpers for Oracle 19c: parsing/formatting, timezone-safe conversion, interval math, bucketing, working-day utilities, range overlap checks, date series, and all the NULL functions with idiomatic patterns."
---
```