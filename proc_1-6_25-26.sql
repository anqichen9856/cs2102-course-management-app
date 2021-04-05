-- 1
CREATE OR REPLACE PROCEDURE add_employee (
    name TEXT, address TEXT, phone TEXT, email TEXT, salary_type TEXT, salary NUMERIC, join_date DATE, category TEXT, course_areas TEXT ARRAY
    -- course_areas: '{"a", "b", ...}'
)
AS $$
DECLARE
    new_eid INTEGER;
    area TEXT;
BEGIN
    IF salary_type NOT IN ('monthly', 'hourly') THEN 
        RAISE EXCEPTION 'Salary type must be one of the following: monthly, hourly.';
    END IF;
    IF category NOT IN ('administrator', 'manager', 'instructor') THEN 
        RAISE EXCEPTION 'Category of employee must be one of the following: administrator, manager, instructor.';
    END IF;
    
    SELECT COALESCE(MAX(eid), 0) + 1 INTO new_eid FROM Employees;
    INSERT INTO Employees VALUES (new_eid, name, email, phone, address, join_date, NULL);
    IF category = 'manager' THEN
        -- must be full-time
        IF salary_type <> 'monthly' THEN 
            RAISE EXCEPTION 'Salary type of manager must be monthly as all managers are full-time.';
        END IF;
        INSERT INTO Full_time_Emp VALUES (new_eid, salary);
        INSERT INTO Managers VALUES (new_eid);
        -- set eid of areas to manager eid in Course_areas (can be empty)
        FOREACH area IN ARRAY course_areas LOOP
            UPDATE Course_areas CA SET eid = new_eid WHERE CA.name = area;
        END LOOP;
    ELSEIF category = 'instructor' THEN
        -- course areas must be nonempty
        IF array_length(course_areas, 1) IS NULL THEN
            RAISE EXCEPTION 'Course areas must be non-empty for adding an instructor.';
        END IF;
        INSERT INTO Instructors VALUES (new_eid);
        -- insert (eid, area) to Specializes
        FOREACH area IN ARRAY course_areas LOOP
            INSERT INTO Specializes VALUES (new_eid, area);
        END LOOP;
        -- Full-time
        IF salary_type = 'monthly' THEN
            INSERT INTO Full_time_Emp VALUES (new_eid, salary);
            INSERT INTO Full_time_instructors VALUES (new_eid);
        -- Part-time
        ELSE 
            INSERT INTO Part_time_Emp VALUES (new_eid, salary);
            INSERT INTO Part_time_instructors VALUES (new_eid);
        END IF;
    ELSE 
        -- administrator
        -- must be full-time
        IF salary_type <> 'monthly' THEN 
            RAISE EXCEPTION 'Salary type of administrator must be monthly as all administrators are full-time.';
        END IF;
        -- course areas must be empty
        IF array_length(course_areas, 1) IS NOT NULL THEN
            RAISE EXCEPTION 'Course areas must be empty for adding an administrator.';
        END IF;
        INSERT INTO Full_time_Emp VALUES (new_eid, salary);
        INSERT INTO Administrators VALUES (new_eid);
    END IF;
END;
$$ LANGUAGE plpgsql;


-- 2
CREATE OR REPLACE PROCEDURE remove_employee (
    eid_to_remove INTEGER, depart_date_to_update DATE
)
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM Offerings WHERE eid = eid_to_remove AND registration_deadline > depart_date_to_update
    ) THEN RAISE EXCEPTION 'Update operation is rejected: registration deadline of some course offering is after this administrator’s departure date.';
    ELSEIF EXISTS (
        SELECT 1 FROM Sessions WHERE eid = eid_to_remove AND launch_date > depart_date_to_update 
    ) THEN RAISE EXCEPTION 'Update operation is rejected: some course session taught by this instructor starts after his/her departure date.';
    ELSEIF EXISTS (
        SELECT 1 FROM Course_areas WHERE eid = eid_to_remove
    ) THEN RAISE EXCEPTION 'Update operation is rejected: some course area is managed by this manager.';
    END IF;
    UPDATE Employees
    SET depart_date = depart_date_to_update
    WHERE eid = eid_to_remove;
END;
$$ LANGUAGE plpgsql;

--3
CREATE OR REPLACE PROCEDURE add_customer (
    name TEXT, address TEXT, phone TEXT, email TEXT, card_number TEXT, expiry_date DATE, cvv INTEGER
)
AS $$
DECLARE
    new_cust_id INTEGER;
BEGIN
    SELECT COALESCE(MAX(cust_id), 0) + 1 INTO new_cust_id FROM Customers;
    INSERT INTO Customers VALUES (new_cust_id, name, email, phone, address);
    INSERT INTO Credit_cards VALUES (card_number, expiry_date, cvv);
    INSERT INTO Owns VALUES (new_cust_id, card_number, CURRENT_DATE);
END;
$$ LANGUAGE plpgsql;

--4
CREATE OR REPLACE PROCEDURE update_credit_card (cust_id INT, card_number TEXT, expiry_date DATE, cvv INTEGER)
AS $$
BEGIN
    INSERT INTO Credit_cards VALUES (card_number, expiry_date, cvv);
    INSERT INTO Owns VALUES (cust_id, card_number, CURRENT_DATE);
END;
$$ LANGUAGE plpgsql;

--5
CREATE OR REPLACE PROCEDURE add_course (title TEXT, description TEXT, area TEXT, duration INTEGER)
AS $$
DECLARE
    new_course_id INTEGER;
BEGIN
    SELECT COALESCE(MAX(course_id), 0) + 1 INTO new_course_id FROM Courses;
    INSERT INTO Courses VALUES (new_course_id, title, description, area, duration);
END;
$$ LANGUAGE plpgsql;

--6
-- instructor must be active employee (depart_date is null or <= session_date)
-- an instructor who is assigned to teach a course session must be specialized in that course area. 
-- Each instructor can teach at most one course session at any hour. 
    -- s,e are new session
    -- overlap：s <= s' <= e or s <= e' <= e
-- there must be at least one hour of break between any two course sessions that the instructor is teaching
    -- s,e are new session
    -- <1h break: s-1 < e' <= s or e <= s' < e+1
-- Each part-time instructor must not teach more than 30 hours for each month
    -- the month that contains session_date
CREATE OR REPLACE FUNCTION find_instructors (cid INTEGER, session_date DATE, session_start_time NUMERIC)
RETURNS TABLE (eid INTEGER, name TEXT) AS $$ 
DECLARE
    curs CURSOR FOR (
        SELECT DISTINCT X.eid, X.name, X.area
        FROM (Instructors NATURAL JOIN Employees NATURAL JOIN Specializes) X
        WHERE X.depart_date IS NULL OR X.depart_date >= session_date
    ); 
    r RECORD;
    a TEXT;
    d NUMERIC;
    session_end_time NUMERIC;
    total_hours_that_month NUMERIC;
BEGIN 
    SELECT course_area, duration INTO a, d FROM Courses WHERE course_id = cid;
    session_end_time := session_start_time + d;
    OPEN curs; 
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;
        SELECT COALESCE(SUM(end_time - start_time), 0) + d INTO total_hours_that_month 
            FROM Sessions S WHERE S.eid = r.eid AND 
            S.date BETWEEN 
                DATE_TRUNC('month', session_date)::DATE AND 
                (DATE_TRUNC('month', session_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        IF r.area = a
            AND NOT EXISTS (
                SELECT 1 FROM Sessions S
                WHERE S.eid = r.eid
                AND S.date = session_date
                AND (
                    (S.start_time BETWEEN session_start_time AND session_end_time) 
                    OR (S.end_time BETWEEN session_start_time AND session_end_time)
                )
            )
            AND NOT EXISTS (
                SELECT 1 FROM Sessions S
                WHERE S.eid = r.eid
                AND date = session_date
                AND (
                    (S.end_time > session_start_time - 1 AND S.end_time <= session_start_time)
                    OR (S.start_time >= session_end_time AND S.start_time < session_end_time + 1)
                ) 
            )
            AND total_hours_that_month <= 30
        THEN
            eid := r.eid;
            name := r.name;
            RETURN NEXT;
        END IF;
    END LOOP; 
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;


-- 25

/*
- find employees whose depart_date >= first day of month

- For a full-time employees, number of work hours for the month and hourly rate should be null.
- salary amount = monthly salary * number of work days for the month / number of days in the month
  The number of work days for the month is given by (last work day - first work day + 1). 
  The first work day = joined date if joined date is within the month of payment; otherwise 1.
  The last work day = departed date if departed date is within the month of payment; otherwise the number of days in the month.   

- For a part-time employees, number of work days for the month and monthly salary should be null. 
  The salary amount = hourly rate * number of work hours for the month
*/

CREATE OR REPLACE FUNCTION pay_salary ()
RETURNS TABLE (eid INTEGER, name TEXT, status TEXT, num_work_days INTEGER, num_work_hours NUMERIC, hourly_rate NUMERIC, monthly_salary NUMERIC, amount NUMERIC) AS $$ 
DECLARE
    curs CURSOR FOR (
        SELECT X.eid, X.name, X.monthly_salary, X.hourly_rate, X.join_date, X.depart_date
        FROM (Employees NATURAL LEFT JOIN Full_time_Emp NATURAL LEFT JOIN Part_time_Emp) X
        WHERE X.depart_date IS NULL OR X.depart_date >= DATE_TRUNC('month', CURRENT_DATE)::DATE /* don't consider employees departed before this month */
    ); 
    r RECORD;
    first_day_of_month DATE;
    last_day_of_month DATE;
    first_work_day DATE;
    last_work_day DATE;
BEGIN 
    OPEN curs; 
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;
        
        first_day_of_month := DATE_TRUNC('month', CURRENT_DATE)::DATE;
        last_day_of_month := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

        IF r.hourly_rate IS NULL THEN /* Full-time */
            IF r.join_date BETWEEN first_day_of_month AND last_day_of_month THEN
                first_work_day := r.join_date;
            ELSE 
                first_work_day := first_day_of_month;
            END IF;

            IF r.depart_date BETWEEN first_day_of_month AND last_day_of_month THEN
                last_work_day := r.depart_date;
            ELSE
                last_work_day := last_day_of_month;
            END IF;

            eid := r.eid;
            name := r.name;
            status := 'Full-time';
            num_work_days := last_work_day - first_work_day + 1;
            num_work_hours := NULL; 
            hourly_rate := NULL; 
            monthly_salary := r.monthly_salary;
            amount := TRUNC(monthly_salary * num_work_days / (last_day_of_month - first_day_of_month + 1), 2);
            INSERT INTO Pay_slips VALUES (eid, CURRENT_DATE, amount, num_work_hours, num_work_days);
            RETURN NEXT;
        
        ELSE  /* Part-time */
            SELECT COALESCE(SUM(end_time - start_time), 0) INTO num_work_hours FROM Sessions S 
                WHERE S.eid = r.eid AND S.date BETWEEN first_day_of_month AND last_day_of_month;
            eid := r.eid;
            name := r.name;
            status := 'Part-time';
            num_work_days := NULL;
            hourly_rate := r.hourly_rate; 
            monthly_salary := NULL;
            amount := TRUNC(hourly_rate * num_work_hours, 2);
            INSERT INTO Pay_slips VALUES (eid, CURRENT_DATE, amount, num_work_hours, num_work_days);
            RETURN NEXT;
        END IF;
    END LOOP; 
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;

-- 26

/*
- inactive customer: has not registered for some course offering in the last six months (inclusive of the current month)

- A course area A is of interest to a customer C if there is some course offering in area A among the three most recent course offerings registered by C. 
- If a customer has not yet registered for any course offering, we assume that every course area is of interest to that customer.

Returns a table of records with information for each inactive customer: 
    customer identifier, 
    customer name, 
    course area A that is of interest to the customer, 
    course identifier of a course C in area A, 
    course title of C, 
    launch date of course offering of course C that still accepts registrations, 
    course offering’s registration deadline, 
    fees for the course offering. 
    
The output is sorted in ascending order of customer identifier and course offering’s registration deadline.
*/

CREATE OR REPLACE FUNCTION promote_courses ()
RETURNS TABLE (cust_id INTEGER, name TEXT, course_area TEXT, course_id INTEGER, title TEXT, launch_date DATE, registration_deadline DATE, fees NUMERIC(10,2)) AS $$ 
    WITH Reg AS (
        SELECT card_number, course_id, date FROM Registers 
        UNION 
        SELECT card_number, course_id, date FROM Redeems
    ),
    Cust_Reg AS (
        SELECT DISTINCT cust_id, name, course_id, date AS reg_date
        FROM Customers NATURAL JOIN Owns NATURAL LEFT JOIN Reg 
    ),
    Inactive_Cust_Reg AS (
        SELECT cust_id, name, course_id, reg_date
        FROM Cust_Reg CR
        WHERE NOT EXISTS (
            SELECT 1 FROM Cust_Reg CR2 WHERE CR2.cust_id = CR.cust_id 
            AND CR2.reg_date BETWEEN (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '5 month')::DATE 
                AND (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE
        )
    ),
    Inactive_Cust_Reg_Recent AS (
        SELECT * FROM Inactive_Cust_Reg ICR
        WHERE (SELECT COUNT(*) FROM Inactive_Cust_Reg ICR2 WHERE ICR2.cust_id = ICR.cust_id AND ICR2.reg_date > ICR.reg_date) < 3
    ),
    Inactive_Cust_Area AS (
        (SELECT * FROM 
            (SELECT cust_id, name FROM Inactive_Cust_Reg_Recent ICRR WHERE ICRR.course_id IS NULL) Cust_No_Reg, 
            (SELECT name AS course_area FROM Course_areas) Areas
        )
        UNION
        SELECT cust_id, name, course_area 
        FROM Inactive_Cust_Reg_Recent NATURAL JOIN Courses
    )
    SELECT cust_id, name, course_area, course_id, title, launch_date, registration_deadline, fees
    FROM Inactive_Cust_Area NATURAL JOIN Courses NATURAL JOIN Offerings
    WHERE registration_deadline >= CURRENT_DATE
    ORDER BY cust_id, registration_deadline;
$$ LANGUAGE sql;