-- 7 DONE
-- we need to assume that the start_date and end_date are within the same month.
-- hour array indicates whether the instructor is available for the entire hour. eg. if the room has a session starting from 15:30, 15 will not be in available hours.
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
        IF r_instructor.area = area AND total_hours_that_month + d <= 30
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
                        IF (curr_hour <= 12 OR curr_hour >= 14)
                        AND NOT EXISTS (
                            SELECT 1
                            FROM Sessions S
                            WHERE S.date = day
                            AND S.eid = r_instructor.eid
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
    OPEN curs;
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;
        IF NOT EXISTS (
            SELECT 1 
            FROM Sessions S
            WHERE S.rid = r.rid
            AND S.date = session_date
            AND ((start_hour >= S.start_time AND start_hour < S.end_time) OR (end_hour > S.start_time AND end_hour <= S.end_time))
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
                IF (curr_hour <= 12 OR curr_hour >= 14)
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
CREATE OR REPLACE PROCEDURE add_course_offering(cid INT, fees NUMERIC, launch_date DATE, registration_deadline DATE, target_num_registeration INT, eid INT, session_info TEXT[][])
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
BEGIN
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
        -- choose a random instructor from the list? 
        --sid := sid + 1;
        --SELECT MIN(eid) INTO instructor_id FROM find_instructors(cid, date, start_hour);
        --add_session(cid, launch_date, sid, date, start_hour, instructor_id, rid);
        
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
    INSERT INTO Offerings VALUES (cid, launch_date, start_date, end_date, registration_deadline, target_number_registrations, seating_capacity, fees, eid);
END;
$$ LANGUAGE plpgsql;

-- 11 DONE
-- checked in schema: (1) unique entry; (2) start_date <= end date; (3) price >= 0.
-- checked in procedure: curr_date between start and end date
CREATE OR REPLACE PROCEDURE add_course_package(name TEXT, num_free_registrations INT, start_date DATE, end_date DATE, price NUMERIC)
AS $$
DECLARE
    new_pkg_id INT;
BEGIN
    SELECT COALESCE(MAX(package_id), 0) + 1 INTO new_pkg_id FROM Course_packages;
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

-- 27
-- MORE TEST CASES NEEDED
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
        -- new cid, reset all values
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
