/* ROUNTINES */

DROP PROCEDURE IF EXISTS add_employee (TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, DATE, TEXT, TEXT[]);
DROP PROCEDURE IF EXISTS remove_employee (INTEGER, DATE);
DROP PROCEDURE IF EXISTS add_customer (TEXT, TEXT, TEXT, TEXT, TEXT, DATE, INTEGER);
DROP PROCEDURE IF EXISTS update_credit_card (INT, TEXT, DATE, INTEGER);
DROP PROCEDURE IF EXISTS add_course (TEXT, TEXT, TEXT, INTEGER);
DROP FUNCTION IF EXISTS find_instructors (INTEGER, DATE, NUMERIC);
DROP FUNCTION IF EXISTS pay_salary ();
DROP FUNCTION IF EXISTS promote_courses ();

DROP PROCEDURE IF EXISTS add_course_offering (INT, NUMERIC, DATE, DATE, INT, INT, TEXT[][]);
DROP PROCEDURE IF EXISTS add_course_package (TEXT, INT, DATE, DATE, NUMERIC);
DROP FUNCTION IF EXISTS get_available_instructors (INT, DATE, DATE);
DROP FUNCTION IF EXISTS find_rooms (DATE, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS get_available_rooms (DATE, DATE);
DROP FUNCTION IF EXISTS get_available_course_packages();
DROP FUNCTION IF EXISTS top_packages (INT);
DROP FUNCTION IF EXISTS popular_courses ();

DROP PROCEDURE IF EXISTS buy_course_package (INT, INT);
DROP PROCEDURE IF EXISTS register_session (INT, INT, DATE, INT, INT);
DROP FUNCTION IF EXISTS get_my_course_package (INT);
DROP FUNCTION IF EXISTS get_available_course_offerings ();
DROP FUNCTION IF EXISTS get_available_course_sessions (INT, DATE);
DROP FUNCTION IF EXISTS get_my_registrations (INT);
DROP FUNCTION IF EXISTS view_summary_report (INT);

DROP PROCEDURE IF EXISTS update_course_session(INTEGER, INTEGER, DATE, INTEGER);
DROP PROCEDURE IF EXISTS cancel_registration(INTEGER, INTEGER, DATE);
DROP PROCEDURE IF EXISTS update_instructor(INTEGER, DATE, INTEGER, INTEGER);
DROP PROCEDURE IF EXISTS update_room(INTEGER, DATE, INTEGER, INTEGER);
DROP PROCEDURE IF EXISTS remove_session(INTEGER, DATE, INTEGER);
DROP PROCEDURE IF EXISTS add_session(INTEGER, DATE, INTEGER, DATE, NUMERIC(4,2), INTEGER, INTEGER);
DROP FUNCTION IF EXISTS find_cards(INTEGER);
DROP FUNCTION IF EXISTS in_registers(INTEGER, INTEGER, DATE);
DROP FUNCTION IF EXISTS student_in_session(INTEGER, DATE, INTEGER);
DROP FUNCTION IF EXISTS check_cancel(INTEGER, DATE, INTEGER);
DROP FUNCTION IF EXISTS fee_one_offering(INTEGER, DATE, NUMERIC);
DROP FUNCTION IF EXISTS total_fee(INTEGER);
DROP FUNCTION IF EXISTS highest_total_fees(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS view_manager_report();

-- 1
CREATE OR REPLACE PROCEDURE add_employee (
    name TEXT, address TEXT, phone TEXT, email TEXT, salary_type TEXT, salary NUMERIC, join_date DATE, category TEXT, course_areas TEXT[]
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
    IF eid_to_remove NOT IN (SELECT E.eid FROM Employees E) THEN
        RAISE EXCEPTION 'Employee % does not exist.', eid_to_remove;
    END IF;
    IF EXISTS (
        SELECT 1 FROM Offerings WHERE eid = eid_to_remove AND registration_deadline > depart_date_to_update
    ) THEN RAISE EXCEPTION 'Update operation is rejected: registration deadline of some course offering is after this administrator’s departure date.';
    ELSEIF EXISTS (
        SELECT 1 FROM Sessions WHERE eid = eid_to_remove AND date > depart_date_to_update
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
    IF cust_id NOT IN (SELECT C.cust_id FROM Customers C) THEN
        RAISE EXCEPTION 'Customer % does not exist.', cust_id;
    END IF;
    INSERT INTO Credit_cards VALUES (card_number, expiry_date, cvv);
    INSERT INTO Owns VALUES (cust_id, card_number, CURRENT_DATE);
END;
$$ LANGUAGE plpgsql;

--5
CREATE OR REPLACE PROCEDURE add_course (title TEXT, description TEXT, area TEXT, duration NUMERIC)
AS $$
DECLARE
    new_course_id INTEGER;
BEGIN
    SELECT COALESCE(MAX(course_id), 0) + 1 INTO new_course_id FROM Courses;
    INSERT INTO Courses VALUES (new_course_id, title, description, area, duration);
END;
$$ LANGUAGE plpgsql;

--6
/*
- instructor must be active employee (depart_date is null or >= session_date)
- an instructor who is assigned to teach a course session must be specialized in that course area.
- Each instructor can teach at most one course session at any hour.
    - s,e are new session
    - overlap：s <= s' <= e or s <= e' <= e (mutual)
- there must be at least one hour of break between any two course sessions that the instructor is teaching
    - s,e are new session
    - <1h break: s-1 < e' <= s or e <= s' < e+1
- Each part-time instructor must not teach more than 30 hours for each month
    - the month that contains session_date
*/
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
    IF (EXTRACT(DOW FROM session_date)) NOT IN (1,2,3,4,5) THEN
        RAISE EXCEPTION 'Session date % is not a weekday.', session_date;
    END IF;
    IF NOT ((session_start_time >= 9 AND session_end_time <= 12) OR (session_start_time >= 14 AND session_end_time <= 18)) THEN
        RAISE EXCEPTION 'Sessions should be conducted at 9-12am or 2-6pm.';
    END IF;
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
                    OR (session_start_time BETWEEN S.start_time AND S.end_time)
                    OR (session_end_time BETWEEN S.start_time AND S.end_time)
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
            AND (r.eid IN (SELECT FI.eid FROM Full_time_instructors FI)
                    OR total_hours_that_month <= 30)
        THEN
            eid := r.eid;
            name := r.name;
            RETURN NEXT;
        END IF;
    END LOOP;
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;

-- 7 DONE
-- we need to assume that the start_date and end_date are within the same month.
-- hour array indicates whether the instructor is available for the entire hour. eg. if a session starting from 15:30, 15 will not be in available hours.
CREATE OR REPLACE FUNCTION get_available_instructors(cid INT, start_date DATE, end_date DATE)
RETURNS TABLE (eid INT, name TEXT, hours INT, day DATE, available_hours INT[]) AS $$
DECLARE
    hours_array INT[];
    curr_hour INT;
    r_instructor RECORD;
    r_day RECORD;
    curs_instructor CURSOR FOR (SELECT Employees.eid, Employees.name, area, depart_date FROM Instructors NATURAL JOIN Employees NATURAL JOIN Specializes ORDER BY eid);
    curs_day CURSOR FOR (SELECT d.as_of_date::DATE FROM GENERATE_SERIES(start_date - '1 day'::INTERVAL, end_date, '1 day'::INTERVAL) d (as_of_date));
    total_hours_that_month INT;
    d INT;
    area TEXT;
BEGIN
    IF DATE_TRUNC('month', start_date)::DATE <> DATE_TRUNC('month', end_date)::DATE
    THEN RAISE EXCEPTION 'start date and end date should be in the same month.';
    END IF;
    SELECT course_area, duration INTO area, d FROM Courses WHERE course_id = cid;
    OPEN curs_instructor;
    OPEN curs_day;
    LOOP
        FETCH curs_instructor INTO r_instructor;
        EXIT WHEN NOT FOUND;
        -- get total hours that month, if no sessions taught, 0 hour
        SELECT COALESCE(SUM(end_time - start_time),0) INTO total_hours_that_month
        FROM Sessions S
 		WHERE S.eid = r_instructor.eid
 		AND S.date BETWEEN
                 DATE_TRUNC('month', start_date)::DATE AND
                 (DATE_TRUNC('month', start_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        IF r_instructor.area = area AND ((r_instructor.eid IN (SELECT FI.eid FROM Full_time_instructors FI) OR total_hours_that_month + d <= 30))
        THEN
            eid := r_instructor.eid;
            name := r_instructor.name;
            hours := total_hours_that_month;
            -- get date and available hours
		    MOVE FIRST FROM curs_day;
            LOOP
                FETCH curs_day INTO r_day;
                EXIT WHEN NOT FOUND;
                day := r_day.as_of_date::DATE;
                hours_array := '{}';
                curr_hour := 9;
                IF (r_instructor.depart_date IS NULL OR r_instructor.depart_date >= end_date)
                THEN
                    LOOP
                        EXIT WHEN curr_hour >= 18;
                        IF (curr_hour < 12 OR curr_hour >= 14)
                        -- no lesson at curr_hour
                        AND NOT EXISTS (
                            SELECT 1
                            FROM Sessions S
                            WHERE S.date = day
                            AND S.eid = r_instructor.eid
                            AND ((curr_hour = S.start_time)
                                    OR (S.start_time > curr_hour AND S.start_time < curr_hour + 1)
                                    OR (curr_hour > S.start_time AND curr_hour < S.end_time))
                        )
                        -- no lesson before and after curr_hour
                        AND NOT EXISTS (
                            SELECT 1
                            FROM Sessions S
                            WHERE S.date = day
                            AND S.eid = r_instructor.eid
                            AND (
                                (S.end_time > curr_hour - 1 AND S.end_time <= curr_hour)
                                OR (S.start_time >= curr_hour AND S.start_time < curr_hour + 1)
                            )
                        )
                        THEN hours_array := hours_array || curr_hour;
                        END IF;
                        curr_hour := curr_hour + 1;
                    END LOOP;
                    available_hours := hours_array;
                    RETURN NEXT;
                END IF;
            END LOOP;
        END IF;
    END LOOP;
    CLOSE curs_instructor;
    CLOSE curs_day;
END;
$$ LANGUAGE plpgsql;

-- 8 DONE
-- checked: the room cannot be occupied by another session at the same day and has overlap timing with the input session
CREATE OR REPLACE FUNCTION find_rooms(session_date DATE, start_hour NUMERIC, duration NUMERIC)
RETURNS TABLE (rid INT) AS $$
DECLARE
    curs CURSOR FOR (SELECT * FROM Rooms);
    r RECORD;
    end_hour NUMERIC;
BEGIN
    end_hour := start_hour + duration;
    IF (EXTRACT(DOW FROM session_date)) NOT IN (1,2,3,4,5) THEN
        RAISE EXCEPTION 'Session date % is not a weekday.', session_date;
    END IF;
    IF NOT ((start_hour >= 9 AND end_hour <= 12) OR (start_hour >= 14 AND end_hour <= 18)) THEN
        RAISE EXCEPTION 'Sessions should be conducted at 9-12am or 2-6pm.';
    END IF;
    OPEN curs;
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;
        IF NOT EXISTS (
            SELECT 1
            FROM Sessions S
            WHERE S.rid = r.rid
            AND S.date = session_date
            AND ((start_hour >= S.start_time AND start_hour < S.end_time) OR (end_hour > S.start_time AND end_hour <= S.end_time)
                OR (S.start_time >= start_hour AND S.start_time < end_hour) OR (S.end_time > start_hour AND S.end_time <= end_hour))
        )
        THEN
            rid := r.rid;
            RETURN NEXT;
        END IF;
    END LOOP;
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;

-- 9 DONE
-- start_date, end_date both inclusive
-- hour array indicates whether the room is available for the entire hour. eg. if the room has a session starting from 15:30, 15 will not be in available hours.
CREATE OR REPLACE FUNCTION get_available_rooms(start_date DATE, end_date DATE)
RETURNS TABLE (rid INT, capacity INT, day DATE, available_hours INT[]) AS $$
DECLARE
    hours_array INT[];
    curr_hour INT;
    r_room RECORD;
    r_day RECORD;
    curs_room CURSOR FOR (SELECT * FROM Rooms ORDER BY rid);
    curs_day CURSOR FOR (SELECT d.as_of_date::DATE FROM GENERATE_SERIES(start_date - '1 day'::INTERVAL, end_date, '1 day'::INTERVAL) d (as_of_date));
BEGIN
    OPEN curs_room;
	OPEN curs_day;
    LOOP
        FETCH curs_room INTO r_room;
        EXIT WHEN NOT FOUND;
        rid := r_room.rid;
        capacity := r_room.seating_capacity;
		MOVE FIRST FROM curs_day;
        LOOP
            FETCH curs_day INTO r_day;
            EXIT WHEN NOT FOUND;
            day := r_day.as_of_date::DATE;
            hours_array := '{}';
            curr_hour := 9;
            LOOP
                EXIT WHEN curr_hour >= 18;
                IF (curr_hour < 12 OR curr_hour >= 14)
                AND NOT EXISTS (
                    SELECT 1
                    FROM Sessions S
                    WHERE S.date = day
                    AND S.rid = r_room.rid
                    AND ((curr_hour = S.start_time)
							 	OR (S.start_time > curr_hour AND S.start_time < curr_hour + 1)
							 	OR (curr_hour > S.start_time AND curr_hour < S.end_time))
				)
                THEN hours_array := hours_array || curr_hour;
                END IF;
                curr_hour := curr_hour + 1;
            END LOOP;
			available_hours := hours_array;
            RETURN NEXT;
        END LOOP;
    END LOOP;
    CLOSE curs_room;
    CLOSE curs_day;
END;
$$ LANGUAGE plpgsql;

-- 10 TODO: check with add_session
-- course offering id: cid + launch date
CREATE OR REPLACE PROCEDURE add_course_offering(cid INT, fees NUMERIC, launch_date DATE, registration_deadline DATE, target INT, eid INT, session_info TEXT[][])
AS $$
DECLARE
    date DATE;
    start_hour NUMERIC;
    curr_rid INT;
    start_date DATE := session_info[1][1];
    end_date DATE := session_info[1][1];
    seating_capacity INT := 0;
    curr_capacity INT;
    sid INT := 0;
    instructor_id INT;
	m TEXT[];
	duration NUMERIC;
BEGIN
    IF cid NOT IN (SELECT course_id FROM Courses) THEN
      RAISE EXCEPTION 'Course does not exist.';
    END IF;
    FOREACH m SLICE 1 IN ARRAY session_info
    LOOP
        date := m[1]::DATE;
        start_hour := m[2]::NUMERIC;
        curr_rid := m[3]::INT;
        IF NOT EXISTS (
            SELECT 1 FROM find_instructors(cid, date, start_hour)
        )
        THEN
            RAISE EXCEPTION 'No available instructor for session on %, start hour %, rid %', date, start_hour, rid;
        END IF;

        -- insert into sessions table
        sid := sid + 1;
        SELECT MIN(I.eid) INTO instructor_id FROM find_instructors(cid, date, start_hour) I;
		SELECT C.duration INTO duration FROM Courses C WHERE C.course_id = cid;
        INSERT INTO Sessions VALUES (cid, launch_date, sid, date, start_hour, start_hour+duration, instructor_id, curr_rid);

        IF date < start_date
        THEN start_date := date;
        END IF;

        IF date > end_date
        THEN end_date := date;
        END IF;

        -- if rid fails foreign key constraint, the adding will fail at add_session step.
          SELECT R.seating_capacity INTO curr_capacity FROM Rooms R WHERE R.rid = curr_rid;
          seating_capacity := seating_capacity + curr_capacity;
    END LOOP;
    IF seating_capacity < target THEN 
      RAISE EXCEPTION 'seating capacity should be at least equal to target nunber of registration.';
    END IF;
	  INSERT INTO Offerings VALUES (cid, launch_date, start_date, end_date, registration_deadline, target, seating_capacity, fees, eid);
END;
$$ LANGUAGE plpgsql;

-- CALL add_course_offering(10, 10, DATE '2021-06-01', '2021-06-20', 1, 10, '{{"2021-07-01", "14", "21"}}');


-- 11 DONE
-- checked in schema: (1) unique entry; (2) start_date <= end date; (3) price >= 0.
-- checked in procedure: start date >= curr_date
CREATE OR REPLACE PROCEDURE add_course_package(name TEXT, num_free_registrations INT, start_date DATE, end_date DATE, price NUMERIC)
AS $$
DECLARE
    new_pkg_id INT;

BEGIN
    SELECT COALESCE(MAX(package_id), 0) + 1 INTO new_pkg_id FROM Course_packages;
    IF CURRENT_DATE > start_date
    THEN RAISE EXCEPTION 'start date is before current date.';
    END IF;

    INSERT INTO Course_packages VALUES (new_pkg_id, num_free_registrations, start_date, end_date, name, price);
END;
$$ LANGUAGE plpgsql;

-- 12 DONE
CREATE OR REPLACE FUNCTION get_available_course_packages()
RETURNS TABLE (name TEXT, num_free_registrations INT, sale_end_date DATE, price NUMERIC) AS $$
DECLARE
    curr_date DATE;
    curs CURSOR FOR (SELECT * FROM Course_packages);
    r RECORD;
BEGIN
    SELECT CURRENT_DATE INTO curr_date;
    OPEN curs;
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;
        IF curr_date >= r.sale_start_date AND curr_date <= r.sale_end_date
        THEN
            name := r.name;
            num_free_registrations := r.num_free_registrations;
            sale_end_date := r.sale_end_date;
            price := r.price;
            RETURN NEXT;
        END IF;
    END LOOP;
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;


--13 with TRIGGER buy_package_trigger
CREATE OR REPLACE PROCEDURE buy_course_package (custId INT,packageId INT)
AS $$
DECLARE
  n INTEGER;
  cardNumber TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM Customers WHERE Customers.cust_id = custId) THEN
  RAISE EXCEPTION 'Customer ID % is not valid', custId;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM Course_packages WHERE Course_packages.package_id = packageId) THEN
  RAISE EXCEPTION 'Package ID % is not valid', packageId;
  END IF;
  SELECT num_free_registrations FROM Course_packages P WHERE P.package_id = packageId INTO n;
  SELECT card_number FROM Owns O WHERE O.cust_id = custId ORDER BY O.from_date DESC LIMIT 1 INTO cardNumber;
  INSERT INTO Buys VALUES (packageId, cardNumber, CURRENT_DATE, n);
  RAISE NOTICE 'The purchase of package % by customer % on % is successful', packageId, custId, CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;
-- CALL buy_course_package(1,1);
-- SELECT * FROM Buys


--14 package name, purchase date, price of package, number of free sessions included in the package, number of sessions that have not been redeemed,
-- and information for each redeemed session (course name, session date, session start hour)
CREATE OR REPLACE FUNCTION get_my_course_package (custId INT)
RETURNS json AS $$
DECLARE
  result JSON;
  buyDate Date;
  packageId INT;
  cardNumber TEXT;
  remainingRedem INT;
  hasPackage INT := 0;
BEGIN
IF NOT EXISTS (SELECT 1 FROM Customers WHERE Customers.cust_id = custId) THEN
RAISE EXCEPTION 'Customer ID % is not valid', custId;
END IF;

--check if the customer has an active or partially active package
IF EXISTS (SELECT 1 FROM Buys NATURAL JOIN Owns WHERE cust_id = custId) THEN
  SELECT date, package_id, card_number, num_remaining_redemptions INTO buyDate, packageId, cardNumber, remainingRedem
  FROM Buys NATURAL JOIN Owns WHERE cust_id = custId
  ORDER BY date DESC LIMIT 1;
  IF remainingRedem = 0 THEN
    IF EXISTS(
    SELECT 1 FROM Redeems R
    WHERE R.package_id = packageId AND R.card_number = cardNumber AND R.buy_date = buyDate
    AND EXISTS (SELECT 1 FROM Sessions S WHERE S.course_id = R.course_id AND S.launch_date = R.launch_date AND S.sid = R.sid AND CURRENT_DATE <= S.date - 7)
    ) THEN
    hasPackage := 1;
    END IF;
  ELSE
    hasPackage := 1;
  END IF;
END IF;

IF hasPackage = 1 THEN
  With count_cancels AS (
    SELECT count(*) AS c1, course_id, launch_date, sid
    FROM Cancels
    WHERE cust_id = custId
    GROUP BY course_id, launch_date, sid
  ), count_redeems AS (
    SELECT count(*) AS c2, course_id, launch_date, sid
    FROM Redeems
    WHERE package_id = packageID AND card_number = cardNumber AND buy_date = buyDate
    GROUP BY course_id, launch_date, sid
  ), redeemed_sessions AS (
    SELECT S.course_id, S.launch_date, S.sid, C.title AS course_name, S.date AS session_date, S.start_time AS session_start_hour
    FROM Courses C, Sessions S, Redeems R
    WHERE R.package_id = packageId AND R.card_number = cardNumber AND R.buy_date = buyDate
    AND C.course_id = S.course_id AND S.course_id = R.course_id AND S.sid = R.sid AND S.launch_date = R.launch_date
  )

  SELECT row_to_json(info) INTO result
  FROM (
    SELECT name, date AS purchase_date, price, num_free_registrations, num_remaining_redemptions, (SELECT json_agg(sessions) FROM (
    SELECT course_name, session_date, session_start_hour
    FROM redeemed_sessions NATURAL LEFT OUTER JOIN count_cancels NATURAL LEFT OUTER JOIN count_redeems
    WHERE COALESCE (c2, 0) - COALESCE (c1, 0) = 1
    ORDER BY session_date, session_start_hour) sessions) AS redeemed_sessions
    FROM Course_packages NATURAL JOIN Buys
    WHERE package_id = packageID AND date = buyDate AND card_number = cardNumber
  ) info;
END IF;

RETURN result;

END;
$$ LANGUAGE plpgsql;
--select * FROM get_my_course_package(5);
--select * from buys;
--select * from redeems;


--15 retrieve all the available course offerings that could be registered.
CREATE OR REPLACE FUNCTION get_available_course_offerings()
RETURNS TABLE(course_title TEXT, course_area TEXT, start_date DATE, end_date DATE, registration_deadline DATE, course_fees NUMERIC, num_remaining_seats INT)
AS $$
SELECT title, course_area, start_date, end_date, registration_deadline, fees, (seating_capacity - count_registers - count_redeems + count_cancels)::INT AS num_remaining_seats
FROM (
  SELECT title, course_area, start_date, end_date, registration_deadline, fees, seating_capacity
  , COALESCE (count1, 0) AS count_registers
  , COALESCE (count2, 0) AS count_redeems
  , COALESCE (count3, 0) AS count_cancels
  FROM Courses
  NATURAL JOIN Offerings
  NATURAL LEFT OUTER JOIN(SELECT course_id, launch_date, count(*) AS count1 FROM Registers GROUP BY course_id, launch_date) AS R1
  NATURAL LEFT OUTER JOIN(SELECT course_id, launch_date, count(*) AS count2 FROM Redeems GROUP BY course_id, launch_date) AS R2
  NATURAL LEFT OUTER JOIN(SELECT course_id, launch_date, count(*) AS count3 FROM Redeems GROUP BY course_id, launch_date) AS R3
) AS OO
WHERE registration_deadline >= CURRENT_DATE AND (count_registers + count_redeems - count_cancels) < seating_capacity
ORDER BY registration_deadline, title;
$$ LANGUAGE sql;
--TEST select * from get_available_course_offerings()

--16
CREATE OR REPLACE FUNCTION get_available_course_sessions(courseId INT, launchDate DATE)
RETURNS TABLE(session_date DATE, start_time NUMERIC, instructor_name TEXT, num_remaining_seats INT)
AS $$
BEGIN
IF NOT EXISTS (SELECT 1 FROM Offerings WHERE course_id = courseId AND launch_date = launchDate) THEN
RAISE EXCEPTION 'Course Offering of % launched on % is invalid', courseId, launchDate;
END IF;
IF NOT EXISTS (SELECT 1 FROM Offerings WHERE course_id = courseId AND launch_date = launchDate AND registration_deadline >= CURRENT_DATE) THEN
RAISE EXCEPTION 'Registration deadline for course Offering of % launched on % is passed', courseId, launchDate;
END IF;

RETURN QUERY SELECT SS.session_date, SS.start_time, SS.instructor_name, (SS.seating_capacity - SS.count_registers - SS.count_redeems + SS.count_cancels)::INT AS num_remaining_seats
FROM (
  SELECT S.date AS session_date, S.start_time, E.name AS instructor_name, R.seating_capacity
  , COALESCE (count1, 0) AS count_registers
  , COALESCE (count2, 0) AS count_redeems
  , COALESCE (count3, 0) AS count_cancels
  FROM Sessions S
  NATURAL JOIN Employees E
  NATURAL JOIN Rooms R
  NATURAL LEFT OUTER JOIN (SELECT course_id, launch_date, sid, count(*) AS count1 FROM Registers GROUP BY course_id, launch_date, sid) AS R1
  NATURAL LEFT OUTER JOIN (SELECT course_id, launch_date, sid, count(*) AS count2 FROM Redeems GROUP BY course_id, launch_date, sid) AS R2
  NATURAL LEFT OUTER JOIN (SELECT course_id, launch_date, sid, count(*) AS count3 FROM Cancels GROUP BY course_id, launch_date, sid) AS R3
  WHERE course_id = courseId AND launch_date = launchDate
) AS SS
WHERE SS.count_registers + SS.count_redeems - SS.count_cancels < SS.seating_capacity
ORDER BY SS.session_date, SS.start_time;
END;
$$ LANGUAGE plpgsql;
--select * from get_available_course_sessions(2, '2022-09-01') RETURN error message'Course Offering...is invalid'
--select * from get_available_course_sessions(1, '2020-09-01') RETURN error message'Registration deadline...is passed'
--select * from get_available_course_sessions(1, '2020-09-01') RETURN an empty table
--select * from get_available_course_sessions(7, '2021-03-30') RETURN 3 rows


--17 either update Registers or Redeems--check if available session--check if payment method is correct
--(0 for credit card or 1 for redemption from active package)
CREATE OR REPLACE PROCEDURE register_session(custId INT, courseId INT, launchDate DATE, sessionNumber INT, paymentMethod INT)
AS $$
DECLARE
packageId INT;
cardNumber TEXT;
buyDate DATE;

BEGIN
IF NOT EXISTS (SELECT 1 FROM Customers WHERE Customers.cust_id = custId) THEN
RAISE EXCEPTION 'Customer ID % is not valid', custId;
END IF;
IF NOT EXISTS (SELECT 1 FROM Sessions WHERE course_id = courseId AND launch_date = launchDate AND sid = sessionNumber) THEN
RAISE EXCEPTION 'The session % of course offering of % launched on % is invalid', sessionNumber, courseId, launchDate;
END IF;
IF paymentMethod != 0 AND paymentMethod != 1 THEN
RAISE EXCEPTION 'Payment method must be either INTEGER 0 or 1, which represent using credit card or redemption from active package respectively';
END IF;

--start check payment method
IF paymentMethod = 1 THEN
    SELECT B.package_id, B.card_number, B.date INTO packageId, cardNumber, buyDate
    FROM Buys B
    WHERE EXISTS (SELECT 1 FROM Owns O WHERE O.cust_id = custId AND O.card_number = B.card_number)
    AND B.num_remaining_redemptions >= 1
    ORDER BY B.num_remaining_redemptions LIMIT 1;
    IF packageId ISNULL THEN
      RAISE EXCEPTION 'Customer % has no active package', custId;
    END IF;
    INSERT INTO Redeems VALUES(packageId, cardNumber, buyDate, courseId, launchDate, sessionNumber, CURRENT_DATE);
    RAISE NOTICE 'The session successfully redeemed with package %', packageId;
ELSE
    SELECT O.card_number INTO cardNumber
    FROM Owns O
    WHERE O.cust_id = custId AND EXISTS (SELECT 1 FROM Credit_cards C WHERE C.number = O.card_number AND C.expiry_date >= CURRENT_DATE)
    ORDER BY O.from_date DESC
    LIMIT 1;
    INSERT INTO Registers VALUES(cardNumber, courseId, launchDate, sessionNumber, CURRENT_DATE);
    RAISE NOTICE 'The session successfully bought by customer %', custId;
END IF;
--end check payment method
END;
$$ LANGUAGE plpgsql;
-- call register_session(1, 7, '2021-03-30', 1, 0); select * from registers;


--18 search through registers and redeems
CREATE OR REPLACE FUNCTION get_my_registrations(custId INT)
RETURNS TABLE(course_title TEXT, fees NUMERIC, session_date DATE, start_time NUMERIC, duration NUMERIC, instructor_name TEXT)
AS $$
DECLARE
  currentDate DATE;
  currentHour NUMERIC;
  currentMinute NUMERIC;
  currentSecond NUMERIC;
  toHour NUMERIC;
BEGIN
IF NOT EXISTS (SELECT 1 FROM Customers WHERE Customers.cust_id = custId) THEN
RAISE EXCEPTION 'Customer ID % is not valid', custId;
END IF;
currentDate := CURRENT_DATE;
currentHour := extract(HOUR FROM CURRENT_TIMESTAMP);
currentMinute := extract(MINUTE FROM CURRENT_TIMESTAMP);
currentSecond := extract(SECOND FROM CURRENT_TIMESTAMP);
toHour := currentHour + currentMinute/60 + currentSecond/3600;

RETURN QUERY WITH count1 AS (
  SELECT COUNT(*) AS c1, course_id, launch_date, sid
  FROM Redeems R
  WHERE EXISTS (SELECT 1 FROM Owns O WHERE O.card_number = R.card_number AND O.cust_id = custId)
  GROUP BY course_id, launch_date, sid
), count2 AS (
  SELECT COUNT(*) AS c2, course_id, launch_date, sid
  FROM Registers R
  WHERE EXISTS (SELECT 1 FROM Owns O WHERE O.card_number = R.card_number AND O.cust_id = custId)
  GROUP BY course_id, launch_date, sid
), count3 AS (
  SELECT COUNT(*) AS c3, course_id, launch_date, sid
  FROM Cancels
  WHERE cust_id = custId
  GROUP BY course_id, launch_date, sid
), course_sessions AS (
  SELECT C.title, C.course_id, O.launch_date, O.fees, S.sid, S.date AS session_date, S.start_time, C.duration, E.name AS instructor_name
  FROM Courses C, Offerings O, Sessions S, Employees E
  WHERE C.course_id = O.course_id AND O.course_id = S.course_id AND O.launch_date = S.launch_date AND S.date >= currentDate
  AND S.eid = E.eid
)
--check date
SELECT course_sessions.title, course_sessions.fees, course_sessions.session_date, course_sessions.start_time, course_sessions.duration, course_sessions.instructor_name
FROM course_sessions NATURAL LEFT OUTER JOIN count1 NATURAL LEFT OUTER JOIN count2 NATURAL LEFT OUTER JOIN count3
WHERE (course_sessions.session_date > currentDate OR (course_sessions.start_time + course_sessions.duration)>toHour)
AND (COALESCE (count1.c1, 0)+COALESCE (count2.c2, 0)-COALESCE (count3.c3, 0)) = 1
ORDER BY course_sessions.session_date, course_sessions.start_time;

END;
$$ LANGUAGE plpgsql;
--TEST select * from get_my_registrations(1)


-- 19
-- this function uses cust_id to find card_number of cards that owned by this customer
CREATE OR REPLACE FUNCTION find_cards(cust INTEGER)
 RETURNS TABLE(cards TEXT) AS $$
  SELECT card_number
  FROM Owns
  WHERE cust_id = cust;
$$ LANGUAGE sql;


-- this function returns a boolean
-- TRUE if the customer directly register; FALSE if the customer redeem
CREATE OR REPLACE FUNCTION in_registers(cust INTEGER, course INTEGER, launch DATE)
  RETURNS BOOLEAN AS $$
  SELECT EXISTS (
	  SELECT * FROM Registers r
	  WHERE r.course_id = course AND r.launch_date = launch
	  AND (r.card_number IN (SELECT * FROM find_cards(cust)))
  );
$$ LANGUAGE sql;

/*
-- this function returns a boolean
-- TRUE if the customer redeem the course; FALSE if the customer redeem
CREATE OR REPLACE FUNCTION in_redeems(cust INTEGER, course INTEGER, launch DATE)
  RETURNS BOOLEAN AS $$
  SELECT EXISTS (
	  SELECT * FROM Redeems r
	  WHERE r.course_id = course AND r.launch_date = launch
	  AND (r.card_number IN (SELECT * FROM find_cards(cust)))
  );
$$ LANGUAGE sql;
*/

-- output: the number of student currently in the session.
CREATE OR REPLACE FUNCTION student_in_session(course INTEGER, launch DATE, session INTEGER)
  RETURNS INTEGER AS $$
  DECLARE
    count_redeems INT;
    count_registers INT;
    count_cancels INT;
    count_registration INTEGER;
  BEGIN
    SELECT count(*) INTO count_redeems
    FROM (
        SELECT *
        FROM Redeems R
        WHERE R.course_id = course AND R.launch_date = launch AND R.sid = session
    ) A;
    SELECT count(*) INTO count_registers
    FROM (
        SELECT *
        FROM Registers R
        WHERE R.course_id = course AND R.launch_date = launch AND R.sid = session
    ) B;
    SELECT count(*) INTO count_cancels
    FROM (
        SELECT *
        FROM Cancels C
        WHERE C.course_id = course AND C.launch_date = launch AND C.sid = session
    ) C;
    count_registration := count_redeems + count_registers - count_cancels;
    RETURN count_registration;
  END;
$$ LANGUAGE plpgsql;

-- check if a custommer register of redeem a session and the session is not canceled
CREATE OR REPLACE FUNCTION check_cancel(course INTEGER, launch DATE, cust INTEGER)
  RETURNS INTEGER AS $$
  DECLARE
    count_redeems INT;
    count_registers INT;
    count_cancels INT;
    count_registration INTEGER;
  BEGIN
    SELECT count(*) INTO count_redeems
    FROM (
        SELECT *
        FROM Redeems R
        WHERE R.course_id = course AND R.launch_date = launch AND R.card_number IN (SELECT cards FROM find_cards(cust))
    ) A;
    SELECT count(*) INTO count_registers
    FROM (
        SELECT *
        FROM Registers R
        WHERE R.course_id = course AND R.launch_date = launch AND R.card_number IN (SELECT cards FROM find_cards(cust))
    ) B;
    SELECT count(*) INTO count_cancels
    FROM (
        SELECT *
        FROM Cancels C
        WHERE C.course_id = course AND C.launch_date = launch AND C.cust_id = cust
    ) C;
    count_registration := count_redeems + count_registers - count_cancels;
    RETURN count_registration;
  END;
$$ LANGUAGE plpgsql;


-- 19. update_course_session: a customer requests to change a registered course session to another session.
CREATE OR REPLACE PROCEDURE update_course_session (cust INTEGER, course INTEGER, launch DATE, new_sid INTEGER) AS $$
  DECLARE
    seat INTEGER;
    students INTEGER;
    new_rid INTEGER;
    new_date DATE;

  BEGIN
    -- check if new session exists
    IF NOT EXISTS (SELECT * FROM Sessions WHERE course_id = course AND launch_date = launch AND sid = new_sid) THEN
      RAISE EXCEPTION 'session is not avaliable';

    ELSE
      SELECT rid, date INTO new_rid, new_date FROM Sessions WHERE course_id = course AND launch_date = launch AND sid = new_sid;
      students := student_in_session(course, launch, new_sid); -- students in the new session before the customer update
      SELECT seating_capacity INTO seat FROM Rooms WHERE rid = new_rid; -- the seat capacity of the new session

      IF NOT EXISTS(SELECT * FROM Customers WHERE cust_id = cust) THEN
        RAISE EXCEPTION 'this customer is not exist';
      ELSIF new_date <= CURRENT_DATE THEN
        RAISE EXCEPTION 'session started';

      -- make sure the custommer register or redeem one session and that session is not canceled
      ELSIF check_cancel(course, launch, cust) = 0 THEN
        RAISE EXCEPTION 'the custommer does not have a registerd session for this course';

      -- check there are seat in the new session: if the number of student in the new session after the customer updated into new session exceeds the room capacity
      ELSIF (students + 1 > seat) THEN
        RAISE EXCEPTION 'no seat in new session';

      -- if customer register directly, the record of that customer in register
      -- since a customer can register for at most one of its sessions before its registration deadline
      -- it is guaranteed that there is only one record for one customer in registers/redeems
      ELSIF in_registers(cust, course, launch) THEN
        -- update in Registers
        UPDATE Registers SET sid = new_sid
          WHERE card_number IN (SELECT * FROM find_cards(cust))
            AND course_id = course
            AND launch_date = launch
            AND date = (SELECT max(date)
              FROM Registers
              WHERE course_id = course AND launch_date = launch
              AND card_number IN (SELECT * FROM find_cards(cust)));
      -- update in Redeems
      ELSE
        UPDATE Redeems SET sid = new_sid
          WHERE card_number IN (SELECT * FROM find_cards(cust))
            AND course_id = course
            AND launch_date = launch
            AND date = (SELECT max(date)
              FROM Redeems
              WHERE course_id = course AND launch_date = launch
              AND card_number IN (SELECT * FROM find_cards(cust)));
      END IF;
    END IF;
  END;
$$ LANGUAGE plpgsql;


-- 20. cancel_registration: when a customer requests to cancel a registered course session.
CREATE OR REPLACE PROCEDURE cancel_registration (cust INTEGER, course INTEGER, launch DATE) AS $$
  DECLARE
    session INTEGER;
    refund_amt NUMERIC(10,2);
    fee NUMERIC(10,2);
    registered_session_start DATE;
    latest_redeem DATE;
    latest_register DATE;
    if_register INTEGER; -- 1 if is register, 0 if is not register

  BEGIN
    -- if customer does not have a registered session now, cannot cancel
    IF check_cancel(course, launch, cust) = 0 THEN
      RAISE EXCEPTION 'the customer not register or redeem any session or canceled, no session can be cancel for this customer';
    -- the customer registered/redeem in a session
    ELSE
      SELECT MAX(date)
        INTO latest_redeem
        FROM Redeems
        WHERE course_id = course AND launch_date = launch AND card_number IN (SELECT cards FROM find_cards(cust));
      SELECT MAX(date)
        INTO latest_register
        FROM Registers
        WHERE course_id = course AND launch_date = launch AND card_number IN (SELECT cards FROM find_cards(cust));

      -- check the if customer register of redeem
      IF (latest_redeem IS NOT NULL AND latest_register IS NOT NULL) THEN
        IF (latest_redeem > latest_register) THEN
          if_register := 0;
        ELSE
          if_register := 1;
        END IF;
      ELSE
        IF (latest_redeem IS NULL) THEN
          if_register := 1;
        ELSE
          if_register := 0;
        END IF;
      END IF;

      -- if regester directly
      IF if_register = 1 THEN
        SELECT sid INTO session FROM Registers WHERE course_id = course AND launch_date = launch AND card_number IN (SELECT cards FROM find_cards(cust)) AND date = latest_register;
        SELECT fees INTO fee FROM Offerings WHERE course_id = course AND launch_date = launch;
        SELECT date INTO registered_session_start FROM Sessions WHERE course_id = course AND launch_date = launch AND sid = session;
        -- check if the session is alr passed.
        IF registered_session_start <= CURRENT_DATE THEN
          RAISE EXCEPTION 'Session started';
        END IF;
        -- check can be refund
        IF registered_session_start-7 >= CURRENT_DATE THEN
          refund_amt := fee * 0.9;
        ELSE
          refund_amt := 0; -- not refundable
          RAISE NOTICE 'Cancellation will be proceed, but will be no refund as cancellation is made at less than 7 days before the day of the registered session';
        END IF;
        INSERT INTO Cancels VALUES (cust, course, launch, session, CURRENT_DATE, refund_amt, 0);
      -- redeem
      ELSE
        SELECT sid INTO session FROM Redeems WHERE course_id = course AND launch_date = launch AND card_number IN (SELECT cards FROM find_cards(cust)) AND date = latest_redeem;
        SELECT date INTO registered_session_start FROM Sessions WHERE course_id = course AND launch_date = launch AND sid = session;
        -- check if the session is alr passed.
        IF registered_session_start <= CURRENT_DATE THEN
          RAISE EXCEPTION 'Session started';
        END IF;
        INSERT INTO Cancels VALUES (cust, course, launch, session, CURRENT_DATE, 0, 1);
        IF registered_session_start-7 < CURRENT_DATE THEN
          RAISE NOTICE 'Cancellation will be proceed, but the number of remaining redemptions in your package cannot be added back';
        END IF;
      END IF;
    END IF;
  END;
$$ LANGUAGE plpgsql;

-- 21
CREATE OR REPLACE PROCEDURE update_instructor (course INTEGER, launch DATE, session_id INTEGER, new_eid INTEGER)
AS $$
  DECLARE
    session_date DATE;
    start_time INTEGER;
  BEGIN
  IF NOT EXISTS (SELECT 1 FROM Sessions WHERE course_id = course AND launch_date = launch AND sid = session_id) THEN
    RAISE EXCEPTION 'Session information not valid.';
  END IF;
  SELECT S.date, S.start_time INTO session_date, start_time FROM Sessions S WHERE course_id = course AND launch_date = launch AND sid = session_id;
  IF (new_eid NOT IN (SELECT eid FROM find_instructors (course, session_date, start_time))) THEN
    RAISE EXCEPTION 'new_eid is not valid';
  ELSIF session_date <= CURRENT_DATE THEN
    RAISE EXCEPTION 'session started';
  ELSE
    UPDATE Sessions
      SET eid = new_eid
      WHERE course_id = course AND session_id = sid AND launch_date = launch;
  END IF;
  END;
$$ LANGUAGE plpgsql;

-- 22
CREATE OR REPLACE PROCEDURE update_room (course INTEGER, launch DATE, session_id INTEGER, new_rid INTEGER)
AS $$
  DECLARE
    seat INTEGER;
    old_room INTEGER;
    seat_old INTEGER;
    students INTEGER;
    session_date DATE;
    session_start INTEGER;
    session_end INTEGER;
    offering_capacity INTEGER;
  BEGIN
  	SELECT date, start_time, end_time, rid INTO session_date, session_start, session_end, old_room FROM Sessions WHERE course_id = course AND sid = session_id AND launch_date = launch;
    -- the seat capacity offering before the update
    SELECT seating_capacity INTO offering_capacity FROM Offerings WHERE course_id = course AND launch_date = launch;

    IF (new_rid NOT IN (SELECT rid FROM find_rooms(session_date, session_start, session_start - session_end))) THEN
      RAISE EXCEPTION 'the room is not available';

    ELSIF session_date <= CURRENT_DATE THEN
      RAISE EXCEPTION 'session started';

    ELSE
      students := student_in_session(course, launch, session_id);
      SELECT seating_capacity INTO seat FROM Rooms WHERE rid = new_rid; -- the seat capacity of the new room
      SELECT seating_capacity INTO seat_old FROM Rooms WHERE rid = old_room ; -- the seat capacity of the old room

      -- check if the number of student in the session exceeds the room capacity
      IF (students > seat) THEN
        RAISE EXCEPTION 'new room cannot hold the number of registered customers';
      ELSE
        UPDATE Sessions
          SET rid = new_rid
          WHERE course_id = course AND session_id = sid AND launch_date = launch;
        -- update offering capacity
        UPDATE Offerings
          SET seating_capacity = (offering_capacity - seat_old + seat)
          WHERE course_id = course AND launch_date = launch;
      END IF;
	END IF;
  END;
$$ LANGUAGE plpgsql;

-- 23. remove_session: This routine is used to remove a course session.
CREATE OR REPLACE PROCEDURE remove_session (course INTEGER, launch DATE, session_id INTEGER)
AS $$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM Sessions WHERE course_id = course AND launch_date = launch AND sid = session_id) THEN
      RAISE EXCEPTION 'Session not exists';
    END IF;
    DELETE FROM Sessions WHERE course_id = course AND launch_date = launch AND sid = session_id;
  END;
$$ LANGUAGE plpgsql;

-- 24. add_session: This routine is used to add a new session to a course offering. The
-- update offering trigger
-- syntax correct
CREATE OR REPLACE PROCEDURE add_session (course INTEGER, launch DATE, new_sid INTEGER, new_start_date DATE, start NUMERIC(4,2), instructor INTEGER, room INTEGER)
AS $$
  DECLARE
    session_duration NUMERIC(4,2);
    deadline DATE;
    seat INTEGER;
    new_capacity INTEGER;
    target_number INTEGER;

  BEGIN
    SELECT target_number_registrations, registration_deadline
      INTO target_number, deadline
      FROM Offerings
      WHERE course_id = course AND launch_date = launch;
    SELECT seating_capacity INTO seat FROM Rooms WHERE rid = room; --the capacity of new room

    -- find the seat capacity if inserted new session
    SELECT SUM(seating_capacity) + seat -- the sum of seat capacity of rooms in offering + the seat capacity of the room of the new session
      INTO new_capacity
      FROM (Sessions S INNER JOIN Rooms R ON (S.rid = R.rid)) O
      WHERE course_id = course AND launch_date = launch;

    IF NOT EXISTS(SELECT * FROM Offerings WHERE course_id = course AND launch_date = launch) THEN
      RAISE EXCEPTION 'course offering does not exist, unable to add session';

    ELSIF CURRENT_DATE > deadline THEN
      RAISE EXCEPTION 'the course offering’s registration deadline has passed, unable to add session';

    ELSIF new_capacity < target_number THEN -- if the new seat capacity < target_number_registrations
      RAISE EXCEPTION 'seating capacity less than target number registrations, unable to add session';

    -- insert to session
    ELSE
      SELECT duration INTO session_duration FROM Courses WHERE course_id = course;

      INSERT INTO Sessions
        VALUES (course, launch, new_sid, new_start_date, start, (start+session_duration), instructor, room);
      -- update offering since start date or send date may change after new swssion being inserted
      UPDATE Offerings
      -- check coalesce date
        SET start_date = LEAST(start_date, new_start_date), end_date = GREATEST(end_date, new_start_date)
        WHERE course_id = course AND launch_date = launch;
      -- update the seating_capacity
      UPDATE Offerings
        SET seating_capacity = new_capacity
        WHERE course_id = course AND launch_date = launch;

    END IF;
  END;
$$ LANGUAGE  plpgsql;
-- test 24:
-- 1 offering time changed
-- CALL add_session (course INTEGER, launch DATE, new_sid INTEGER, start_date DATE, start NUMERIC(4,2), instructor INTEGER, room INTEGER);
-- 2 room not valiable
--
-- 3 instructor not valiable
--
-- 4 offering not exist
--


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
            AND CR2.reg_date BETWEEN (CURRENT_DATE - INTERVAL '6 month')::DATE
                AND CURRENT_DATE
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

-- 27
-- only check sale_start date? not buys date?
CREATE OR REPLACE FUNCTION top_packages(n INT)
RETURNS TABLE (package_id INT, num_free_registrations INT, price NUMERIC, sale_start_date DATE, sale_end_date DATE, num_sold INT) AS $$
DECLARE
    curs CURSOR FOR (
		SELECT C.package_id, C.num_free_registrations, C.price, C.sale_start_date, C.sale_end_date, count(B.date) AS num_sold
		FROM Course_packages C LEFT OUTER JOIN Buys B ON C.package_id = B.package_id
		WHERE EXTRACT(YEAR FROM C.sale_start_date) = EXTRACT(YEAR FROM CURRENT_DATE)
		GROUP BY C.package_id
		ORDER BY num_sold DESC, price DESC
    );
    r RECORD;
    curr_idx INT := 1;
    prev_num_sold INT := -1;
BEGIN
    OPEN curs;
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND OR (curr_idx > n AND prev_num_sold <> r.num_sold);
        package_id := r.package_id;
        num_free_registrations := r.num_free_registrations;
        price := r.price;
        sale_start_date := r.sale_start_date;
        sale_end_date := r.sale_end_date;
        num_sold := r.num_sold;
        RETURN NEXT;
        curr_idx := curr_idx + 1;
        prev_num_sold := r.num_sold;
    END LOOP;
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;

-- 28
-- number of registration: redeems + registers - cancels
CREATE OR REPLACE FUNCTION popular_courses()
RETURNS TABLE (course_id INT, course_title TEXT, course_area TEXT, num_offerings INT, num_latest_registrations INT) AS $$
DECLARE
    curs CURSOR FOR (
        WITH W AS (
            SELECT C.course_id, C.title, C.course_area, O.launch_date
            FROM Courses C LEFT OUTER JOIN Offerings O on C.course_id = O.course_id
            WHERE EXTRACT(YEAR FROM O.start_date) = EXTRACT(YEAR FROM CURRENT_DATE)
            AND (
				SELECT count(O1.launch_date) > 2
				FROM Offerings O1
				WHERE C.course_id = O1.course_id
			)
        ),
        X AS (
            SELECT R.course_id, R.launch_date, count(*) AS registers_count
            FROM Registers R
            GROUP BY R.course_id, R.launch_date
        ),
        Y AS (
            SELECT R1.course_id, R1.launch_date, count(*) AS redeems_count
            FROM Redeems R1
            GROUP BY R1.course_id, R1.launch_date
        ),
        Z AS (
            SELECT C1.course_id, C1.launch_date, count(*) AS cancels_count
            FROM Cancels C1
            GROUP BY C1.course_id, C1.launch_date
        )
        SELECT W.course_id, W.title, W.course_area, W.launch_date, COALESCE(X.registers_count, 0) + COALESCE(Y.redeems_count, 0) - COALESCE(Z.cancels_count, 0) AS num_registerations
        FROM W LEFT OUTER JOIN X ON (W.course_id = X.course_id AND W.launch_date = X.launch_date)
                LEFT OUTER JOIN Y ON (W.course_id = Y.course_id AND W.launch_date = Y.launch_date)
                LEFT OUTER JOIN Z ON (W.course_id = Z.course_id AND W.launch_date = Z.launch_date)
        ORDER BY W.course_id, W.launch_date
    );
    curr_r RECORD;
    prev_r RECORD;
    num INT := 1;
    is_popular INT := 1;
BEGIN
    OPEN curs;
    -- fetch the first record
    FETCH curs INTO prev_r;
    LOOP
        -- starts with the second record
        FETCH curs INTO curr_r;
        EXIT WHEN NOT FOUND;
        IF prev_r.course_id = curr_r.course_id AND prev_r.num_registerations >= curr_r.num_registerations
        THEN
            is_popular := 0;
        ELSIF prev_r.course_id <> curr_r.course_id AND is_popular = 1
        THEN
            course_id := prev_r.course_id;
            course_title := prev_r.title;
            course_area := prev_r.course_area;
            num_offerings := num;
            num_latest_registrations := prev_r.num_registerations;
            RETURN NEXT;
            num := 1;
        ELSIF prev_r.course_id <> curr_r.course_id AND is_popular = 0
        THEN
            is_popular := 1;
            num := 1;
        ELSE
            num := num + 1;
        END IF;
        prev_r := curr_r;
    END LOOP;
	IF is_popular = 1
	THEN
		course_id := prev_r.course_id;
        course_title := prev_r.title;
        course_area := prev_r.course_area;
        num_offerings := num;
        num_latest_registrations := prev_r.num_registerations;
        RETURN NEXT;
	END IF;
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;


--29 view_summary_report of n months
--look through Pay_slips, Buys, Registers, Redeems, Cancels
CREATE OR REPLACE FUNCTION view_summary_report(n INT)
RETURNS TABLE (month INT, year INT, total_salaries NUMERIC, total_sold_packages BIGINT, total_paid_fees NUMERIC, total_refunded_fees NUMERIC, total_redemptions BIGINT)
AS $$
DECLARE
  currentDate DATE;
  counterMonth TIMESTAMP;
  startMonth TIMESTAMP;
  mm INT;
  yy INT;
BEGIN
IF n < 1 THEN
RAISE EXCEPTION 'Input number of months % is not a positive integer', n;
END IF;
currentDate := CURRENT_DATE;
counterMonth := DATE_TRUNC('MONTH', currentDate);
counterMonth := counterMonth + interval'1 MONTH';

CREATE TABLE ViewedMonths (month INT, year INT);
FOR counter IN 0..n-1 LOOP
  counterMonth := counterMonth - interval'1 MONTH';
  mm := EXTRACT('MONTH' FROM counterMonth);
  yy := EXTRACT('YEAR' FROM counterMonth);
  INSERT INTO ViewedMonths VALUES(mm, yy);
END LOOP;

RETURN QUERY WITH salaries AS (
  SELECT extract(month from payment_date) AS month, extract(year from payment_date) AS year, SUM(amount) AS salary_sum
  FROM Pay_slips
  WHERE payment_date <= currentDate AND payment_date >= DATE(counterMonth)
  GROUP BY year, month
), sold_packages AS (
  SELECT extract(month from date) AS month, extract(year from date) AS year, COUNT(*) AS packages_count
  FROM Buys
  WHERE date <= currentDate AND date >= DATE(counterMonth)
  GROUP BY year, month
), paid_fees AS (
  SELECT extract(month from date) AS month, extract(year from date)AS year, SUM(fees) AS fees_sum
  FROM Registers R, Offerings O
  WHERE date <= currentDate AND date >= DATE(counterMonth) AND R.course_id = O.course_id AND R.launch_date = O.launch_date
  GROUP BY year, month
), refunded_fees AS (
  SELECT extract(month from date) AS month, extract(year from date) AS year, SUM(refund_amt) AS refund_sum
  FROM Cancels
  WHERE date <= currentDate AND date >= DATE(counterMonth) AND package_credit = 0
  GROUP BY year, month
), redemptions AS (
  SELECT extract(month from date) AS month, extract(year from date) AS year, COUNT(*) AS redeems_count
  FROM Redeems
  WHERE date <= currentDate AND date >= DATE(counterMonth)
  GROUP BY year, month
), cancels AS (
  SELECT extract(month from date) AS month, extract(year from date) AS year, COUNT(*) AS cancels_count
  FROM Cancels
  WHERE date <= currentDate AND date >= DATE(counterMonth) AND package_credit = 1
  GROUP BY year, month
)
SELECT V.month, V.year, COALESCE(salary_sum, 0), COALESCE(packages_count, 0), COALESCE(fees_sum, 0), COALESCE(refund_sum, 0), COALESCE(redeems_count, 0) - COALESCE(cancels_count, 0)
FROM ViewedMonths V NATURAL LEFT OUTER JOIN salaries NATURAL LEFT OUTER JOIN sold_packages NATURAL LEFT OUTER JOIN paid_fees NATURAL LEFT OUTER JOIN refunded_fees
NATURAL LEFT OUTER JOIN redemptions NATURAL LEFT OUTER JOIN cancels
ORDER BY V.year DESC;
DROP TABLE ViewedMonths;
END;
$$ LANGUAGE plpgsql;
--TEST SELECT * FROM view_summary_report(10)



-- 30. view_manager_report:
-- This routine is used to view a report on the sales generated by each manager.
-- returns a table
-- 1. manager name
-- 2. total number of course areas that are managed by the manager
-- 3. total number of course offerings that ended this year (i.e., the course offering’s end date is within this year) that are managed by the manager
-- 4. *total net registration fees* for #all the course offerings# that ended this year that are managed by the manager
-- 5. the course offering title (i.e., course title) that has the *highest total net registration fees* #among all the course offerings that ended this year that are managed by the manager

-- Each manager manages zero or more course areas, and each course area is managed by exactly one manager. Each course offering is managed by the manager of that course area.

CREATE OR REPLACE FUNCTION fee_one_offering(course INTEGER, launch DATE, fees NUMERIC(10,2))
  RETURNS NUMERIC AS $$
DECLARE
  fees_register NUMERIC;
  count_registers INTEGER;
  fees_redeem NUMERIC;
  fees_offering NUMERIC;

BEGIN
  --(excluding any refunded fees due to cancellations)
  -- customers register directly
  -- number of customer registered directly
  SELECT COUNT(*)
    INTO count_registers
    FROM (SELECT course_id, launch_date FROM Registers WHERE course_id = course AND launch_date = launch) A
  WHERE (course_id, launch_date) NOT IN (SELECT course_id, launch_date FROM Cancels WHERE course_id = course AND launch_date = launch);
  fees_register := count_registers * fees;

  SELECT package_id
    INTO package
    FROM (SELECT package_id, course_id, launch_date FROM Redeems WHERE course_id = course AND launch_date = launch) C
  WHERE (course_id, launch_date) NOT IN (SELECT course_id, launch_date FROM Cancels WHERE course_id = 5 AND launch_date = launch);

  -- customers redeem
  SELECT COALESCE(ROUND(SUM(C.price/C.num_free_registrations)),0)
    INTO fees_redeem
    FROM (SELECT package_id, num_free_registrations, price FROM Course_packages) C
  WHERE package_id = package;
  -- total fees for one offering
  fees_offering := fees_register + fees_redeem;
  RETURN COALESCE(fees_offering, 0);
END;
$$ LANGUAGE plpgsql;

-- ???????
CREATE OR REPLACE FUNCTION total_fee(M_eid INTEGER)
  RETURNS NUMERIC AS $$
  DECLARE
    fees_offering NUMERIC;
    total_fee NUMERIC;
    -- for each couse offering by the manager with id M_eid
    curs_o CURSOR FOR
      (SELECT * FROM Offerings
        WHERE course_id IN (SELECT course_id FROM Courses WHERE course_area IN (SELECT name FROM Course_areas WHERE eid = M_eid))
          AND EXTRACT(YEAR FROM end_date) = EXTRACT(YEAR FROM CURRENT_DATE));
    r_o RECORD;
  BEGIN
    total_fee := 0;
    OPEN curs_o;
    -- ????
    LOOP
      FETCH curs_o INTO r_o;
      EXIT WHEN NOT FOUND;
      fees_offering := fee_one_offering(r_o.course_id, r_o.launch_date, r_o.fees);
      total_fee := total_fee + fees_offering;
    END LOOP;
    CLOSE curs_o;

    RETURN COALESCE(total_fee, 0);
  END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION highest_total_fees(year INTEGER, M_eid INTEGER)
RETURNS TABLE(title TEXT) AS $$
SELECT R.title
FROM
  ((SELECT course_id FROM Offerings WHERE course_id IN (SELECT course_id FROM Courses WHERE course_area IN (SELECT name FROM Course_areas WHERE eid = M_eid))
    AND EXTRACT(YEAR FROM end_date) = year AND fee_one_offering(course_id, launch_date, fees) = (SELECT max(fee_one_offering(course_id, launch_date, fees))
  FROM Offerings
  WHERE course_id IN (SELECT course_id FROM Courses WHERE course_area IN (SELECT name FROM Course_areas WHERE eid = M_eid))
    AND EXTRACT(YEAR FROM end_date) = year)) A -- select offering(s) that have highest total net registration fees
  INNER JOIN
  (SELECT course_id, title FROM Courses) B
ON (A.course_id = B.course_id)) R
$$ LANGUAGE SQL;


CREATE OR REPLACE FUNCTION view_manager_report()
RETURNS TABLE (M_name TEXT, num_course_areas INTEGER, num_course_offering INTEGER, total_registration_fee NUMERIC, course_title TEXT) AS $$
  DECLARE
    current_year INTEGER;
    max_offering_fee NUMERIC;
    max_cid INTEGER;
    curs_m CURSOR FOR (SELECT * FROM Managers);
    r_m RECORD;
    curs_tie refcursor;
    r_tie RECORD;
    title_array TEXT[];
  BEGIN
    current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    OPEN curs_m;
    LOOP
      FETCH curs_m INTO r_m;
      EXIT WHEN NOT FOUND;

      -- name of manager
      SELECT name INTO M_name FROM Employees WHERE eid = r_m.eid;

      -- number of course area
      SELECT COUNT(*) INTO num_course_areas FROM Course_areas WHERE eid = r_m.eid;

      -- number of course offering
      SELECT COUNT(*)
        INTO num_course_offering
        FROM Offerings
        -- the offering managed by this manager that ended this year
        WHERE course_id
            IN (SELECT course_id FROM Courses WHERE course_area IN (SELECT name FROM Course_areas WHERE eid = r_m.eid))
          AND EXTRACT(YEAR FROM end_date) = current_year; -- ended this year

      -- find total registratino fee
      total_registration_fee := total_fee(r_m.eid);

      title_array := '{}';
      -- title of course offering with the highest registration fee.
      OPEN curs_tie FOR (SELECT * FROM highest_total_fees(current_year, r_m.eid));
      LOOP
        FETCH curs_tie INTO r_tie;
        EXIT WHEN NOT FOUND;
        title_array := title_array || r_tie.title;
      END LOOP;
      CLOSE curs_tie;
      course_title := title_array;
      RETURN NEXT;
    END LOOP;
    CLOSE curs_m;
  END;
$$ LANGUAGE plpgsql;

-- test 30:
-- 1
-- 18.13
-- SELECT fee_one_offering(4, DATE '2020-09-01', 10.90)
-- SELECT total_fee(6);  -- ?always return null
-- SELECT * FROM view_manager_report()


/* TRIGGERS */

DROP TRIGGER IF EXISTS emp_covering_con_trigger ON Employees;
DROP TRIGGER IF EXISTS full_time_emp_covering_con_trigger ON Full_time_Emp;
DROP TRIGGER IF EXISTS part_time_emp_covering_con_trigger ON Part_time_Emp;
DROP TRIGGER IF EXISTS instructor_covering_con_trigger ON Instructors;

DROP TRIGGER IF EXISTS customer_owns_total_part_con_trigger ON Customers;
DROP TRIGGER IF EXISTS credit_card_owns_total_part_con_trigger ON Credit_cards;
DROP TRIGGER IF EXISTS credit_card_own_before_expiry_date_trigger ON Owns;

DROP TRIGGER IF EXISTS instructor_specializes_total_part_con_trigger ON Instructors;
DROP TRIGGER IF EXISTS offering_consists_total_part_con_trigger ON Offerings;
DROP TRIGGER IF EXISTS course_area_manager_trigger ON Course_areas;

DROP TRIGGER IF EXISTS buy_package_trigger ON Buys;
DROP TRIGGER IF EXISTS redeem_if_valid_trigger ON Redeems;
DROP TRIGGER IF EXISTS update_buy_redeem_trigger ON Redeems;
DROP TRIGGER IF EXISTS register_if_valid_trigger ON Registers;
DROP TRIGGER IF EXISTS update_buy_cancel_trigger ON Cancels;
DROP TRIGGER IF EXISTS insert_session_trigger ON Sessions;
DROP TRIGGER IF EXISTS delete_sessions_trigger ON Sessions;
DROP TRIGGER IF EXISTS delete_sessions_update_trigger ON Sessions;


/* Employee Triggers */

-- Employee can be either part time or full time, but not both
-- Use simultaneous insertion with transaction when inserting/updating Employees
CREATE OR REPLACE FUNCTION emp_covering_con_func() RETURNS TRIGGER
AS $$
BEGIN
    IF NEW.eid NOT IN (SELECT FE.eid FROM Full_time_Emp FE)
    AND NEW.eid NOT IN (SELECT PE.eid FROM Part_time_Emp PE) THEN
        RAISE EXCEPTION 'Employee % must be either full-time or part-time.', NEW.eid;
    END IF;
    IF NEW.eid IN (SELECT FE.eid FROM Full_time_Emp FE)
    AND NEW.eid IN (SELECT PE.eid FROM Part_time_Emp PE) THEN
        RAISE EXCEPTION 'Employee % cannot be both full-time and part-time.', NEW.eid;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER emp_covering_con_trigger
AFTER INSERT OR UPDATE ON Employees
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION emp_covering_con_func();

-- Full time employee can only be ONE of the following: administrator, manager or full-time instructor
CREATE OR REPLACE FUNCTION full_time_emp_covering_con_func() RETURNS TRIGGER
AS $$
BEGIN
    IF NEW.eid NOT IN (SELECT A.eid FROM Administrators A)
    AND NEW.eid NOT IN (SELECT M.eid FROM Managers M)
    AND NEW.eid NOT IN (SELECT FI.eid FROM Full_time_instructors FI) THEN
        RAISE EXCEPTION 'Full-time employee % must be either administrator, manager, or full-time instructor.', NEW.eid;
    END IF;
    IF (NEW.eid IN (SELECT A.eid FROM Administrators A) AND NEW.eid IN (SELECT M.eid FROM Managers M))
        OR
        (NEW.eid IN (SELECT A.eid FROM Administrators A) AND NEW.eid IN (SELECT FI.eid FROM Full_time_instructors FI))
        OR
        (NEW.eid IN (SELECT M.eid FROM Managers M) AND NEW.eid IN (SELECT FI.eid FROM Full_time_instructors FI))
    THEN
        RAISE EXCEPTION 'Full-time employee % cannot take more than one role from the following: administrator, manager, full-time instructor.', NEW.eid;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER full_time_emp_covering_con_trigger
AFTER INSERT OR UPDATE ON Full_time_Emp
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION full_time_emp_covering_con_func();

-- Part time employee can only be instructor
CREATE OR REPLACE FUNCTION part_time_emp_covering_con_func() RETURNS TRIGGER
AS $$
BEGIN
    IF NEW.eid NOT IN (SELECT PI.eid FROM Part_time_instructors PI) THEN
        RAISE EXCEPTION 'Part-time employee % must be instructor.', NEW.eid;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER part_time_emp_covering_con_trigger
AFTER INSERT OR UPDATE ON Part_time_Emp
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION part_time_emp_covering_con_func();

-- Instructors can be either full-time instructor or part-time instructor, but not both
CREATE OR REPLACE FUNCTION instructor_covering_con_func() RETURNS TRIGGER
AS $$
BEGIN
    IF NEW.eid NOT IN (SELECT FI.eid FROM Full_time_instructors FI)
    AND NEW.eid NOT IN (SELECT PI.eid FROM Part_time_instructors PI) THEN
        RAISE EXCEPTION 'Instructor % must be either full-time or part-time instructor.', NEW.eid;
    END IF;
    IF NEW.eid IN (SELECT FI.eid FROM Full_time_instructors FI)
    AND NEW.eid IN (SELECT PI.eid FROM Part_time_instructors PI) THEN
        RAISE EXCEPTION 'Instructor % cannot be both full-time and part-time.', NEW.eid;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER instructor_covering_con_trigger
AFTER INSERT OR UPDATE ON Instructors
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION instructor_covering_con_func();

/* Customers & credit cards trigger */

-- TPC for Customers：every customer owns >= 1 credit card
CREATE OR REPLACE FUNCTION customer_owns_total_part_con_func() RETURNS TRIGGER
AS $$
BEGIN
    IF NEW.cust_id NOT IN (SELECT O.cust_id FROM Owns O) THEN
        RAISE EXCEPTION 'Customer % must own at least one credit card.', NEW.cust_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER customer_owns_total_part_con_trigger
AFTER INSERT OR UPDATE ON Customers
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION customer_owns_total_part_con_func();

-- TPC for Credit cards：every credit card must be owned by at least one customer
CREATE OR REPLACE FUNCTION credit_card_owns_total_part_con_func() RETURNS TRIGGER
AS $$
BEGIN
    IF NEW.number NOT IN (SELECT O.card_number FROM Owns O) THEN
        RAISE EXCEPTION 'Credit card % must be owned by a customer.', NEW.number;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER credit_card_owns_total_part_con_trigger
AFTER INSERT OR UPDATE ON Credit_cards
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION credit_card_owns_total_part_con_func();

-- Owns from_date < credit card's expiry_date
CREATE OR REPLACE FUNCTION credit_card_own_before_expiry_date_func() RETURNS TRIGGER
AS $$
BEGIN
    IF (SELECT expiry_date FROM Credit_cards C WHERE C.number = NEW.card_number) <= NEW.from_date THEN
        RAISE EXCEPTION 'Credit card % has already expired.', NEW.card_number;
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER credit_card_own_before_expiry_date_trigger
BEFORE INSERT OR UPDATE ON Owns
FOR EACH ROW EXECUTE FUNCTION credit_card_own_before_expiry_date_func();

/* Specializes trigger */

-- TPC for instructors: every instructor must specialize in at least one area
CREATE OR REPLACE FUNCTION instructor_specializes_total_part_con_func() RETURNS TRIGGER
AS $$
BEGIN
    IF NEW.eid NOT IN (SELECT S.eid FROM Specializes S) THEN
        RAISE EXCEPTION 'Instructor % must specialize in at least a course area.', NEW.eid;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER instructor_specializes_total_part_con_trigger
AFTER INSERT OR UPDATE ON Instructors
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION instructor_specializes_total_part_con_func();

/* Consists trigger */

-- TPC for Offerings: every offering must consist of at least one session
CREATE OR REPLACE FUNCTION offering_consists_total_part_con_func() RETURNS TRIGGER
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM Sessions S WHERE S.course_id = NEW.course_id and S.launch_date = NEW.launch_date
    ) THEN
        RAISE EXCEPTION 'Offering must consist of at least one session.';
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER offering_consists_total_part_con_trigger
AFTER INSERT OR UPDATE ON Offerings
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION offering_consists_total_part_con_func();

/* Course area's manager must be active employee (till current date) */
CREATE OR REPLACE FUNCTION course_area_manager_func() RETURNS TRIGGER
AS $$
BEGIN
    IF (SELECT depart_date FROM Employees E WHERE E.eid = NEW.eid) <= CURRENT_DATE THEN
        RAISE EXCEPTION 'The manager has already left the company.';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER course_area_manager_trigger
BEFORE INSERT OR UPDATE ON Course_areas
FOR EACH ROW EXECUTE FUNCTION course_area_manager_func();

/* Buys trigger */
CREATE OR REPLACE FUNCTION buy_package_func() RETURNS TRIGGER
AS $$
DECLARE
custId INT;
buyDate Date;
packageId INT;
cardNumber TEXT;
remainingRedem INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Owns O WHERE O.card_number = NEW.card_number AND O.from_date <= NEW.date) THEN
        RAISE EXCEPTION 'Card number % is invalid', NEW.card_number;
    END IF;

    SELECT cust_id INTO custId FROM Owns O WHERE O.card_number = NEW.card_number;
    --check if customer has an active or partially active package
    IF EXISTS (SELECT 1 FROM Buys NATURAL JOIN Owns WHERE cust_id = custId) THEN
        SELECT date, package_id, card_number, num_remaining_redemptions INTO buyDate, packageId, cardNumber, remainingRedem
        FROM Buys NATURAL JOIN Owns WHERE cust_id = custId
        ORDER BY date DESC LIMIT 1;
        IF remainingRedem = 0 THEN
            IF EXISTS(
            SELECT 1 FROM Redeems R
            WHERE R.package_id = packageId AND R.card_number = cardNumber AND R.buy_date = buyDate
            AND EXISTS (SELECT 1 FROM Sessions S WHERE S.course_id = R.course_id AND S.launch_date = R.launch_date AND S.sid = R.sid AND NEW.date <= S.date - 7)
            ) THEN RAISE EXCEPTION 'Customer % has a partially active package %, another package cannot be bought', custId, packageId;
            END IF;
        ELSE RAISE EXCEPTION 'Customer % has an active package %, another package cannot be bought', custId, packageId;
        END IF;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Course_packages WHERE Course_packages.package_id = NEW.package_id) THEN
        RAISE EXCEPTION 'Package ID % is invalid', NEW.package_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Credit_cards C WHERE C.number = NEW.card_number AND C.expiry_date >= NEW.date) THEN
        RAISE EXCEPTION 'Card number % has expired', NEW.card_number;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Course_packages P WHERE P.package_id = NEW.package_id
        AND P.sale_start_date <= NEW.date AND P.sale_end_date >= NEW.date) THEN
        RAISE EXCEPTION 'Package % is not open to sale on %', NEW.package_id, NEW.date;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER buy_package_trigger
BEFORE INSERT ON Buys
FOR EACH ROW EXECUTE FUNCTION buy_package_func();

/* Redeems trigger */
CREATE OR REPLACE FUNCTION redeem_if_valid_func() RETURNS TRIGGER
AS $$
DECLARE
custId INT;
ifRegistered INT;
count_redeems INT;
count_registers INT;
count_cancels INT;
count_registration INT;
capacity INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Course_packages WHERE Course_packages.package_id = NEW.package_id) THEN
    RAISE EXCEPTION 'Package ID % is invalid', NEW.package_id;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM Buys B
        WHERE B.card_number = NEW.card_number AND B.date = NEW.buy_date AND B.package_id = NEW.package_id AND B.card_number = NEW.card_number
        AND B.num_remaining_redemptions >= 1
    ) THEN RAISE EXCEPTION 'There is no active package % bought on % by card %', NEW.package_id, NEW.buy_date, NEW.card_number;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM Sessions S
        WHERE S.course_id = NEW.course_id AND S.launch_date = NEW.launch_date AND S.sid = NEW.sid
    ) THEN RAISE EXCEPTION 'The session % of course offering of % launched on % is invalid', NEW.sid, NEW.course_id, NEW.launch_date;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Offerings WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date
        AND registration_deadline >= NEW.date) THEN
    RAISE EXCEPTION 'Registration deadline for course offering of % launched on % is passed', NEW.course_id, NEW.launch_date;
    END IF;

    --check if course is Registered by the customer
    --As stated in project description, a customer can register for at most one session for a course, thus registered session can only be 0 or 1
    SELECT cust_id INTO custId FROM Owns O WHERE O.card_number = NEW.card_number;
    SELECT count(*) INTO ifRegistered FROM Redeems R
    WHERE R.course_id = NEW.course_id
    AND EXISTS (SELECT 1 FROM Owns O WHERE O.card_number = R.card_number AND O.cust_id = custId);
    SELECT ifRegistered + count(*) INTO ifRegistered FROM Registers R
    WHERE R.course_id = NEW.course_id
    AND EXISTS (SELECT 1 FROM Owns O WHERE O.card_number = R.card_number AND O.cust_id = custId);
    SELECT  ifRegistered - count(*) INTO ifRegistered FROM Cancels C
    WHERE C.course_id = NEW.course_id AND cust_id = custId;

    RAISE NOTICE 'Course % IF REGISTERED %', NEW.course_id, ifRegistered;
    IF ifRegistered = 1 THEN
    RAISE EXCEPTION 'Course % has been registered by customer %, another registration is not allowed', NEW.course_id, custId;
    END IF;

    --check if session is fully booked
    SELECT count(*) INTO count_redeems FROM Redeems R
    WHERE R.course_id = NEW.course_id AND R.launch_date = NEW.launch_date AND R.sid = NEW.sid;
    SELECT count(*) INTO count_registers FROM Registers R
    WHERE R.course_id = NEW.course_id AND R.launch_date = NEW.launch_date AND R.sid = NEW.sid;
    SELECT count(*) INTO count_cancels FROM Cancels C
    WHERE C.course_id = NEW.course_id AND C.launch_date = NEW.launch_date AND C.sid = NEW.sid;

    count_registration := count_redeems + count_registers - count_cancels;
    SELECT seating_capacity INTO capacity
    FROM Rooms
    WHERE Rooms.rid = (SELECT rid FROM Sessions S WHERE S.course_id = NEW.course_id AND S.launch_date = NEW.launch_date AND S.sid = NEW.sid);

    IF capacity <= count_registration THEN
    RAISE EXCEPTION 'The session % of course offering of % launched % is fully booked', NEW.sid, NEW.course_id, NEW.launch_date;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER redeem_if_valid_trigger
BEFORE INSERT ON Redeems
FOR EACH ROW EXECUTE FUNCTION redeem_if_valid_func();

/* Update Buys after Redeems */
-- num_remaining_redemptions --
CREATE OR REPLACE FUNCTION update_buy_redeem_func() RETURNS TRIGGER
AS $$
BEGIN
    --num_remaining_redemptions has been ensured to be >= 1 before insert/update Redeems
    UPDATE Buys SET num_remaining_redemptions = num_remaining_redemptions - 1
    WHERE package_id = NEW.package_id AND card_number = NEW.card_number AND date = NEW.buy_date;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER update_buy_redeem_trigger
AFTER INSERT ON Redeems
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION update_buy_redeem_func();

/* Registers trigger */
CREATE OR REPLACE FUNCTION register_if_valid_func() RETURNS TRIGGER
AS $$
DECLARE
custId INT;
ifRegistered INT;
count_redeems INT;
count_registers INT;
count_cancels INT;
count_registration INT;
capacity INT;
BEGIN
    IF NOT EXISTS (
       SELECT 1 FROM Owns O WHERE O.card_number = NEW.card_number AND O.from_date <= NEW.date
    ) THEN RAISE EXCEPTION 'The card number % is invalid', NEW.card_number;
    END IF;
    IF NOT EXISTS (
       SELECT 1 FROM Credit_cards C WHERE C.number = NEW.card_number AND C.expiry_date >= NEW.date
    ) THEN RAISE EXCEPTION 'The credit card % is expired', NEW.card_number;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM Sessions S
        WHERE S.course_id = NEW.course_id AND S.launch_date = NEW.launch_date AND S.sid = NEW.sid
    ) THEN RAISE EXCEPTION 'The session % of course offering of % launched on % is invalid', NEW.sid, NEW.course_id, NEW.launch_date;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Offerings WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date
        AND registration_deadline >= NEW.date) THEN
    RAISE EXCEPTION 'Registration deadline for course offering of % launched on % is passed', NEW.course_id, NEW.launch_date;
    END IF;

    --check if course is Registered by the customer
    --As stated in project description, a customer can register for at most one session for a course, thus registered session can only be 0 or 1
    SELECT cust_id INTO custId FROM Owns O WHERE O.card_number = NEW.card_number;
    SELECT count(*) INTO ifRegistered FROM Redeems R
    WHERE R.course_id = NEW.course_id
    AND EXISTS (SELECT 1 FROM Owns O WHERE O.card_number = R.card_number AND O.cust_id = custId);
    SELECT ifRegistered + count(*) INTO ifRegistered FROM Registers R
    WHERE R.course_id = NEW.course_id
    AND EXISTS (SELECT 1 FROM Owns O WHERE O.card_number = R.card_number AND O.cust_id = custId);
    SELECT  ifRegistered - count(*) INTO ifRegistered FROM Cancels C
    WHERE C.course_id = NEW.course_id AND cust_id = custId;

    RAISE NOTICE 'Course % IF REGISTERED %', NEW.course_id, ifRegistered;
    IF ifRegistered = 1 THEN
    RAISE EXCEPTION 'Course % has been registered by customer %, another registration is not allowed', NEW.course_id, custId;
    END IF;

    --check if session is fully booked
    SELECT count(*) INTO count_redeems FROM Redeems R
    WHERE R.course_id = NEW.course_id AND R.launch_date = NEW.launch_date AND R.sid = NEW.sid;
    SELECT count(*) INTO count_registers FROM Registers R
    WHERE R.course_id = NEW.course_id AND R.launch_date = NEW.launch_date AND R.sid = NEW.sid;
    SELECT count(*) INTO count_cancels FROM Cancels C
    WHERE C.course_id = NEW.course_id AND C.launch_date = NEW.launch_date AND C.sid = NEW.sid;

    count_registration := count_redeems + count_registers - count_cancels;
    SELECT seating_capacity INTO capacity
    FROM Rooms
    WHERE Rooms.rid = (SELECT rid FROM Sessions S WHERE S.course_id = NEW.course_id AND S.launch_date = NEW.launch_date AND S.sid = NEW.sid);

    IF capacity <= count_registration THEN
    RAISE EXCEPTION 'The session % of course offering of % launched % is fully booked', NEW.sid, NEW.course_id, NEW.launch_date;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER register_if_valid_trigger
BEFORE INSERT ON Registers
FOR EACH ROW EXECUTE FUNCTION register_if_valid_func();



-- after a cancelltion, if session is redeemed update the num_remaining_redemptions in Buy if is refundable
CREATE OR REPLACE FUNCTION update_buy_cancel_func() RETURNS TRIGGER AS $$
  DECLARE
    pid INT;
    cardNumber TEXT;
    buyDate DATE;
  BEGIN
    -- if the customer redeemed
    IF NEW.package_credit = 1 THEN

      IF EXISTS (
        SELECT 1 FROM Sessions S
        WHERE NEW.date <= S.date - 7
        AND S.course_id = NEW.course_id AND S.launch_date = NEW.launch_date AND S.sid = NEW.sid
      ) THEN
        SELECT B.package_id, B.card_number, B.date INTO pid, cardNumber, buyDate FROM Buys B
        WHERE EXISTS (SELECT 1 FROM Owns O WHERE NEW.cust_id = O.cust_id AND B.card_number = O.card_number)
        ORDER BY B.date DESC LIMIT 1;

        UPDATE Buys SET num_remaining_redemptions = num_remaining_redemptions + 1
        WHERE package_id = pid AND card_number = cardNumber AND date = buyDate;
        RETURN NULL;
      END IF;
    END IF;
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_buy_cancel_trigger
AFTER INSERT ON Cancels
FOR EACH ROW EXECUTE FUNCTION update_buy_cancel_func();



-- this function returns a boolean
-- TRUE if there is overlap in the session; FALSE if there is no overlap
CREATE OR REPLACE FUNCTION check_overlap(session_rid INTEGER, session_date DATE, new_start_time NUMERIC(4,2), new_end_time NUMERIC(4,2))
  RETURNS BOOLEAN AS $$
  SELECT EXISTS (
                SELECT * FROM Sessions S
                WHERE S.date = session_date
                AND S.rid = session_rid
                AND (
                    (S.start_time >= new_start_time AND S.start_time < new_end_time) OR
                    (S.end_time > new_start_time AND S.end_time <= new_end_time) OR
                    (new_start_time >= S.start_time AND new_start_time < S.end_time) OR
                    (new_end_time > S.start_time AND new_end_time <= S.end_time)
                )
            );
$$ LANGUAGE sql;


-- sessions triggers
CREATE OR REPLACE FUNCTION insert_session_func() RETURNS TRIGGER
AS $$
  DECLARE
    session_duration NUMERIC(4,2);

  BEGIN
    SELECT duration INTO session_duration FROM Courses WHERE course_id = NEW.course_id;
    -- check that the no session can overlap

    IF check_overlap(NEW.rid, NEW.date, NEW.start_time, NEW.end_time) THEN
      RAISE EXCEPTION 'The new session from % to % on % at room % overlaps with other session', NEW.start_time, NEW.end_time, NEW.date, NEW.rid;

    -- check if the room is valiable for the session
    -- IF NOT EXISTS(SELECT * FROM find_rooms(NEW.date, NEW.start_time, session_duration) WHERE rid = NEW.rid) THEN
	  ELSIF (NEW.rid NOT IN (SELECT rid FROM find_rooms(NEW.date, NEW.start_time, session_duration))) THEN
      RAISE EXCEPTION 'The room % is not available, unable to INSERT or UPDATE', NEW.rid;

    -- check if the instructor can teach this session
    ELSIF (NEW.eid NOT IN (SELECT eid FROM find_instructors (NEW.course_id, NEW.date, NEW.start_time))) THEN
      RAISE EXCEPTION 'Instructor % not avaliable, unable to INSERT or UPDATE, room %, date %, start %, end %', NEW.eid, NEW.rid, NEW.date, NEW.start_time, NEW.end_time;
    ELSE
      RETURN NEW;
    END IF;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER insert_session_trigger
BEFORE INSERT ON Sessions
FOR EACH ROW EXECUTE FUNCTION insert_session_func();

CREATE OR REPLACE FUNCTION delete_sessions_func() RETURNS TRIGGER
AS $$
  DECLARE
    students INTEGER;
    room_id INTEGER;
    room_deleted_session INTEGER;
  BEGIN
    students := student_in_session(OLD.course_id, OLD.launch_date, OLD.sid); 
    -- check if there are someone in the session
    -- registers_course_id_launch_date_sid_fkey & redeems_course_id_launch_date_sid_fkey already checked ???
    IF (students > 0) THEN
      RAISE EXCEPTION 'There are students in the session, cannot delete session';
    END IF;
    IF OLD.date < CURRENT_DATE THEN
      RAISE EXCEPTION 'The course session has started';
    END IF;
    SELECT rid INTO room_id FROM Sessions WHERE course_id = OLD.course_id AND launch_date = OLD.launch_date AND sid = OLD.sid;
    SELECT seating_capacity INTO room_deleted_session FROM Rooms WHERE rid = room_id;
    UPDATE Offerings
      SET seating_capacity =  seating_capacity - room_deleted_session
      WHERE course_id = OLD.course_id AND launch_date = OLD.launch_date;
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_sessions_trigger
BEFORE DELETE ON Sessions
FOR EACH ROW EXECUTE FUNCTION delete_sessions_func();

CREATE OR REPLACE FUNCTION delete_sessions_update_func() RETURNS TRIGGER
AS $$
  DECLARE
    offering_start DATE;
    offering_end DATE;

  BEGIN
    -- check if there are someone in the session
    -- registers_course_id_launch_date_sid_fkey & redeems_course_id_launch_date_sid_fkey already checked ???
    SELECT MIN(date) INTO offering_start FROM Sessions WHERE course_id = OLD.course_id AND launch_date = OLD.launch_date;
    SELECT MAX(date) INTO offering_end FROM Sessions WHERE course_id = OLD.course_id AND launch_date = OLD.launch_date;
    UPDATE Offerings
      SET start_date = offering_start, end_date = offering_end
      WHERE course_id = OLD.course_id AND launch_date = OLD.launch_date;
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_sessions_update_trigger
AFTER DELETE ON Sessions
FOR EACH ROW EXECUTE FUNCTION delete_sessions_update_func();