-- 1
CREATE OR REPLACE PROCEDURE add_employee (
    name TEXT, address TEXT, phone TEXT, email TEXT, salary NUMERIC, join_date DATE, category TEXT, course_areas ANY
    -- course_areas may be enumeratable strings
)
AS $$
DECLARE
    new_eid INTEGER;
    area TEXT;
BEGIN
    IF category NOT IN ('Administrator', 'Manager', 'Part-time Instructor', 'Full-time Instructor') THEN 
        RAISE EXCEPTION 'Category of employee must be one of the following: Administrator, Manager, Part-time Instructor, Full-time Instructor.'
    END IF;
    BEGIN TRANSACTION;
        SELECT MAX(eid) + 1 INTO new_eid FROM Employees;
        -- empty table?
        INSERT INTO Employees VALUES (new_eid, name, email, phone, address, join_date, NULL);
        IF category = 'Manager' THEN
            --course areas must be nonempty
            --set eid of areas to manager eid in Course_areas
            INSERT INTO Full_time_Emp VALUES (new_eid, salary);
            INSERT INTO Managers VALUES (new_eid);
            FOR area IN course_areas
            LOOP
                UPDATE Course_areas
                SET eid = new_eid
                WHERE name = area;
            END LOOP;
        ELSEIF category = 'Full-time Instructor' THEN
            --course areas must be nonempty
            --insert (eid, area) to Specializes
            IF course_areas IS EMPTY THEN
                RAISE EXCEPTION 'Course areas must be non-empty for adding an instructor.';
            END IF;
            INSERT INTO Full_time_Emp VALUES (new_eid, salary);
            INSERT INTO Full_time_instructors VALUES (new_eid);
            INSERT INTO Instructors VALUES (new_eid);
            FOR area IN course_areas
            LOOP
                INSERT INTO Specializes VALUES (new_eid, area);
            END LOOP;
        ELSEIF category = 'Part-time Instructor' THEN
            IF course_areas IS EMPTY THEN
                RAISE EXCEPTION 'Course areas must be non-empty for adding an instructor.';
            END IF;
            INSERT INTO Part_time_Emp VALUES (new_eid, salary);
            INSERT INTO Part_time_instructors VALUES (new_eid);
            INSERT INTO Instructors VALUES (new_eid);
            FOR area IN course_areas
            LOOP
                INSERT INTO Specializes VALUES (new_eid, area);
            END LOOP;
        ELSE 
            -- administrator
            --course areas must be empty
            IF course_areas IS NOT EMPTY THEN
                RAISE EXCEPTION 'Course areas must be empty for adding an administrator.';
            END IF;
            INSERT INTO Full_time_Emp VALUES (new_eid, salary);
            INSERT INTO Administrators VALUES (new_eid);
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
    BEGIN TRANSACTION;
        SELECT MAX(cust_id) + 1 INTO new_cust_id FROM Customers;
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
    BEGIN TRANSACTION;
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
    SELECT MAX(course_id) + 1 INTO new_course_id FROM Courses;
    INSERT INTO Courses VALUES (new_course_id, title, description, area, duration);
END;
$$ LANGUAGE plpgsql;

--6
CREATE OR REPLACE FUNCTION find_instructors (cid INTEGER, session_date DATE, session_start_hour INTEGER)
RETURNS TABLE (eid INTEGER, name TEXT) AS $$ 
DECLARE
    curs CURSOR FOR (
        SELECT eid, name, area 
        FROM Instructors NATURAL JOIN Employees NATURAL JOIN Specializes
    ); 
    r RECORD;
    area TEXT;
    session_end_hour INTEGER;
    total_hours_that_month INTEGER;
BEGIN 
-- an instructor who is assigned to teach a course session must be specialized in that course area. 
-- Each instructor can teach at most one course session at any hour. 
/* clarify: different day, same hour can or not? */
    -- not exists (same date, same start hour)
-- there must be at least one hour of break between any two course sessions that the instructor is teaching
    -- not exists (start - 1 < prev_end <= start or end <= next_start < end + 1 on the same day)
-- Each part-time instructor must not teach more than 30 hours for each month
    -- the month that contains session_date

    SELECT course_area INTO area FROM Courses WHERE course_id = cid;
    session_end_hour := session_start_hour + 1;
    OPEN curs; 
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;
        SELECT COUNT(*) + 1 INTO total_hours_that_month 
            FROM Sessions WHERE eid = r.eid AND 
            date BETWEEN 
                DATE_TRUNC('month', session_date)::DATE AND 
                (DATE_TRUNC('month', session_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        IF r.area = area 
            AND NOT EXISTS (
                SELECT 1 FROM Sessions
                WHERE eid = r.eid
                AND date = session_date
                AND start_time = session_start_hour
            )
            AND NOT EXISTS (
                SELECT 1 FROM Sessions
                WHERE eid = r.eid
                AND date = session_date
                AND (end_time > session_start_hour - 1 AND end_time <= session_start_hour)
                AND (start_time >= session_end_hour AND start_time < session_end_hour + 1)
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
