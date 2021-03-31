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
    START TRANSACTION;
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
                UPDATE Course_areas SET eid = new_eid WHERE name = area;
            END LOOP;
        ELSEIF category = 'instructor' THEN
            -- course areas must be nonempty
            IF array_length(course_areas, 1) = 0 THEN
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
            IF array_length(course_areas, 1) > 0 THEN
                RAISE EXCEPTION 'Course areas must be empty for adding an administrator.';
            END IF;
            INSERT INTO Full_time_Emp VALUES (new_eid, salary);
            INSERT INTO Administrators VALUES (new_eid);
        END IF;
    COMMIT;
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
    ) OR EXISTS (
        SELECT 1 FROM Sessions WHERE eid = eid_to_remove AND launch_date > depart_date_to_update 
    ) OR EXISTS (
        SELECT 1 FROM Course_areas WHERE eid = eid_to_remove
    ) THEN
        RAISE EXCEPTION 'Update operation is rejected.';
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
    START TRANSACTION;
        SELECT COALESCE(MAX(cust_id), 0) + 1 INTO new_cust_id FROM Customers;
        INSERT INTO Customers VALUES (new_cust_id, name, email, phone, address);
        INSERT INTO Credit_cards VALUES (card_number, expiry_date, cvv);
        INSERT INTO Owns VALUES (new_cust_id, card_number, CURRENT_DATE);
    COMMIT;
END;
$$ LANGUAGE plpgsql;

--4
CREATE OR REPLACE PROCEDURE update_credit_card (cust_id INT, card_number TEXT, expiry_date DATE, cvv INTEGER)
AS $$
BEGIN
    START TRANSACTION;
        INSERT INTO Credit_cards VALUES (card_number, expiry_date, cvv);
        INSERT INTO Owns VALUES (cust_id, card_number, CURRENT_DATE);
    COMMIT;
END;
$$ LANGUAGE plpgsql;

--5
CREATE OR REPLACE PROCEDURE add_course (title TEXT, description TEXT, area TEXT, duration INTEGER)
AS $$
DECLARE
    new_course_id INTEGER;
BEGIN
    SELECT  COALESCE(MAX(course_id), 0) + 1 INTO new_course_id FROM Courses;
    INSERT INTO Courses VALUES (new_course_id, title, description, area, duration);
END;
$$ LANGUAGE plpgsql;

--6
CREATE OR REPLACE FUNCTION find_instructors (cid INTEGER, session_date DATE, session_start_time NUMERIC)
RETURNS TABLE (eid INTEGER, name TEXT) AS $$ 
DECLARE
    curs CURSOR FOR (
        SELECT eid, name, area 
        FROM Instructors NATURAL JOIN Employees NATURAL JOIN Specializes
    ); 
    r RECORD;
    a TEXT;
    d NUMERIC;
    session_end_time NUMERIC;
    total_hours_that_month NUMERIC;
BEGIN 
-- an instructor who is assigned to teach a course session must be specialized in that course area. 
-- Each instructor can teach at most one course session at any hour. 
    -- s,e are new session
    -- overlap：s <= s' <= e or s <= e' <= e
-- there must be at least one hour of break between any two course sessions that the instructor is teaching
    -- s,e are new session
    -- <1h break: s-1 < e' <= s or e <= s' < e+1
-- Each part-time instructor must not teach more than 30 hours for each month
    -- the month that contains session_date
    SELECT course_area, duration INTO a, d FROM Courses WHERE course_id = cid;
    session_end_time := session_start_time + d;
    OPEN curs; 
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;
        SELECT SUM(end_time - start_time) + d INTO total_hours_that_month 
            FROM Sessions WHERE eid = r.eid AND 
            date BETWEEN 
                DATE_TRUNC('month', session_date)::DATE AND 
                (DATE_TRUNC('month', session_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        IF r.area = a
            AND NOT EXISTS (
                SELECT 1 FROM Sessions
                WHERE eid = r.eid
                AND date = session_date
                AND (
                    (start_time BETWEEN session_start_time AND session_end_time) 
                    OR (end_time BETWEEN session_start_time AND session_end_time)
                )
            )
            AND NOT EXISTS (
                SELECT 1 FROM Sessions
                WHERE eid = r.eid
                AND date = session_date
                AND (
                    (end_time > session_start_time - 1 AND end_time <= session_start_time)
                    OR (start_time >= session_end_time AND start_time < session_end_time + 1)
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
