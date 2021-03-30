-- 7
CREATE OR REPLACE FUNCTION get_available_instructors(cid INT, start_date DATE, end_date DATE)
RETURNS TABLE (eid INT, name TEXT, hours INT, day DATE, available_hours INT[]) AS $$
DECLARE
    hours_array INT[];
    curr_hour INT;
    r_instructor RECORD;
    r_day RECORD;
    curs_instructor CURSOR FOR (SELECT eid, name, area FROM Instructors NATURAL JOIN Employees NATURAL JOIN Specializes ORDER BY eid);
    curs_day CURSOR FOR (SELECT d.as_of_date::DATE FROM GENERATE_SERIES(start_date, end_date, '1 day'::INTERVAL) d (as_of_date));
    total_hours_that_month INT;
    duration INT;
    area TEXT;
BEGIN
    SELECT course_area, duration INTO area, duration FROM Courses WHERE course_id = cid;
    OPEN curs_instructor;
    LOOP
        FETCH curs_instructor INTO r_instructor;
        EXIT WHEN NOT FOUND;
        -- get total hours that month
        SELECT SUM(end_time) - SUM(start_time) INTO total_hours_that_month 
            FROM Sessions WHERE eid = r.eid AND
            date BETWEEN 
                DATE_TRUNC('month', session_date)::DATE AND 
                (DATE_TRUNC('month', session_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        IF r_instructor.area = area AND total_hours_that_month + duration <= 30
        THEN
            eid := r_instructor.eid;
            name := r_instructor.name;
            hours := total_hours_that_month;
            -- get date and available hours
            LOOP 
                FETCH curs_day INTO r_day;
                EXIT WHEN NOT FOUND;
                day := r_day.as_of_date::DATE;
                hours_array := '{}';
                curr_hour := 0;
                LOOP
                    EXIT WHEN curr_hour > 24;
                    IF NOT EXISTS (
                        SELECT 1
                        FROM Sessions S
                        WHERE S.date = day
                        AND S.eid = eid
                        AND ((curr_hour = S.start_time) OR (curr_hour > S.start_time AND curr < S.end_time))
                    ) 
                    THEN hours_array := hours_array || curr_hour;
                    END IF;
                    curr_hour := curr_hour + 1;
                END LOOP;
                RETURN NEXT;
            END LOOP;
        END IF;
    END LOOP;
    CLOSE curs_r;
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

-- 9
CREATE OR REPLACE FUNCTION get_available_rooms(start_date DATE, end_date DATE)
RETURNS TABLE (rid INT, capacity INT, day DATE, available_hours INT[]) AS $$
DECLARE
    hours_array INT[];
    curr_hour INT;
    r_room RECORD;
    r_day RECORD;
    curs_room CURSOR FOR (SELECT * FROM Rooms ORDER BY rid);
    curs_day CURSOR FOR (SELECT d.as_of_date::DATE FROM GENERATE_SERIES(start_date, end_date, '1 day'::INTERVAL) d (as_of_date));
BEGIN
    OPEN curs_room;
    LOOP
        FETCH curs_room INTO r_room;
        EXIT WHEN NOT FOUND;
        rid := r_room.rid;
        capacity := r_room.seating_capacity;
        LOOP 
            FETCH curs_day INTO r_day;
            EXIT WHEN NOT FOUND;
            day := r_day.as_of_date::DATE;
            hours_array := '{}';
            curr_hour := 0;
            LOOP
                EXIT WHEN curr_hour > 24;
                IF NOT EXISTS (
                    SELECT 1
                    FROM Sessions S
                    WHERE S.date = day
                    AND S.rid = rid
                    AND ((curr_hour = S.start_time) OR (curr_hour > S.start_time AND curr < S.end_time))
                ) 
                THEN hours_array := hours_array || curr_hour;
                END IF;
                curr_hour := curr_hour + 1;
            END LOOP;
            RETURN NEXT;
        END LOOP;
    END LOOP;
    CLOSE curs_r;
END;
$$ LANGUAGE plpgsql;

-- 10
-- course offering id? - cid + launch date
-- do we need to insert into sessions too? 
-- targer_num_registration vs. capacity? 
-- data type of info stored in array. 
-- conditions checked: non-negative, launch_date <= registration ddl, ddl at least 10 days from start date. 
-- start and end dates, seating capacity, available instructors.
CREATE OR REPLACE PROCEDURE add_course_offering(cid INT, fees NUMERIC, launch_date DATE, registration_deadline DATE, eid INT, session_info TEXT[][])
AS $$
DECLARE
    date DATE;
    start_hour INT;
    rid INT;
    start_date DATE := session_info[1][1];
    end_date DATE := session_info[1][1];
    target_number_registrations INT := -1;
    curr_capacity INT;
BEGIN
    SELECT MAX(seating_capacity) INTO target_number_registrations FROM Rooms;
    BEGIN TRANSACTION;
         
        FOREACH m SLICE 1 IN ARRAY session_info
        LOOP
            date := m[1];
            start_hour := m[2];
            rid := m[3];
            IF NOT EXISTS (
                SELECT 1 FROM find_instructors(cid, date, start_hour);
            )
            THEN 
                RAISE EXCEPTION 'No available instructor for session on %, start hour %, rid %', date, start_hour, rid;
            END IF;
            
            IF date < start_date 
            THEN start_date := date;
            END IF;
            
            IF date > end_date
            THEN end_date := date;
            END IF;

            SELECT R.seating_capacity INTO curr_capacity FROM Rooms R WHERE R.rid = rid;
            IF curr_capacity < target_number_registrations
            THEN target_number_registrations := curr_capacity;
            END IF;

        END LOOP;
        INSERT INTO Offerings VALUES (cid, launch_date, start_date, end_date, registration_deadline, target_number_registrations, targer_num_registration, fees, eid);
    COMMIT;
END;
$$ LANGUAGE plpgsql;

-- 11 TODO: make attributes unique
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