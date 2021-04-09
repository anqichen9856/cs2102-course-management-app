-- 19
-- this function uses cust_id to find card_number of cards that owned by this customer
-- syntax correct
CREATE OR REPLACE FUNCTION find_cards(cust INTEGER)
 RETURNS TABLE(cards TEXT) AS $$
  SELECT card_number
  FROM Owns
  WHERE cust_id = cust;
$$ LANGUAGE sql;


-- this function returns a boolean
-- TRUE if the customer directly register; FALSE if the customer redeem

--(cust_id, course_id, launch_date, sid, date)
CREATE OR REPLACE FUNCTION inRegister(cust INTEGER, course INTEGER, launch DATE)
  RETURNS BOOLEAN AS $$
  DECLARE
    in_register INTEGER;
    in_cancel INTEGER;
  BEGIN
  SELECT EXISTS (
	  SELECT * FROM Registers r
	  WHERE r.course_id = course AND r.launch_date = launch
	  AND (r.card_number IN (SELECT * FROM find_cards(cust)))
  );

  END;
$$ LANGUAGE plpgsql;

/*
-- this function returns a boolean
-- TRUE if the customer redeem the course; FALSE if the customer redeem
CREATE OR REPLACE FUNCTION inRedeem(cust INTEGER, course INTEGER, launch DATE)
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
-- syntax correct
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
      ELSIF new_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'session started';

      -- make sure the custommer register or redeem one session and that session is not canceled
      ELSIF check_cancel(course, launch, cust) = 0 THEN
        RAISE EXCEPTION 'the custommer not register or redeem or canceled';

      -- check there are seat in the new session: if the number of student in the new session after the customer updated into new session exceeds the room capacity
      ELSIF (students + 1 > seat) THEN
        RAISE EXCEPTION 'no seat in new session';

      -- if customer register directly, the record of that customer in register
      -- since a customer can register for at most one of its sessions before its registration deadline
      -- it is guaranteed that there is only one record for one customer in registers/redeems
      ELSIF inRegister(cust, course, launch) THEN
        -- update in Registers
        UPDATE Registers SET sid = new_sid
          WHERE card_number IN (SELECT * FROM find_cards(cust))
            AND course_id = course
            AND launch_date = launch
            AND date = (SELECT date
              FROM Registers
              WHERE course_id = course AND launch_date = launch
              GROUP BY course_id, launch_date
              HAVING max(date));
      --ELSIF inRedeem(cust, course, launch) THEN
      -- update in Redeems
      ELSE
        UPDATE Redeems SET sid = new_sid
          WHERE card_number IN (SELECT * FROM find_cards(cust))
            AND course_id = course
            AND launch_date = launch
            AND date = (SELECT date
              FROM Redeems
              WHERE course_id = course AND launch_date = launch
              GROUP BY course_id, launch_date
              HAVING max(date));

      --ELSE
        --RAISE EXCEPTION 'customer did not register directly or redeem a session';
      END IF;
    END IF;
  END;
$$ LANGUAGE plpgsql;
-- test 19:
-- 1 new session started
-- CALL update_course_session (2, 2, DATE '2020-10-05', 2);
-- 2 customer redeem
-- CALL update_course_session (2, 5, DATE '2021-03-10', 2);
-- 3 customer register directly
--
-- 4 session is not avaliable
-- CALL update_course_session (8, 5, DATE '2021-03-30', 2);




-- 20




-- 20. cancel_registration: when a customer requests to cancel a registered course session.
CREATE OR REPLACE PROCEDURE cancel_registration (cust INTEGER, course INTEGER, launch DATE) AS $$
  DECLARE
    session INTEGER;
    refund_amt NUMERIC(10,2);
    package_credit INTEGER;
    fee NUMERIC(10,2);
    registered_session_start DATE;
    latest_redeem DATE;
    latest_register DATE;
    if_register INTEGER; -- 1 if is register, 0 if is not register

  BEGIN
    -- check if cancellation valid: a customer cannot cancel a session multiple times
    IF check_cancel(course, launch, cust) = 0 THEN
      RAISE EXCEPTION 'the customer not register or redeem any session or canceled, no session can be cancel for this customer';
    -- the customer registered/redeem in a session
    ELSE
      SELECT COALESCE(MAX(date))
        INTO latest_redeem
        FROM Redeems
        WHERE course_id = course AND launch_date = launch AND card_number IN (SELECT cards FROM find_cards(cust));
      SELECT COALESCE(MAX(date))
        INTO latest_register
        FROM Registers
        WHERE course_id = course AND launch_date = launch AND card_number IN (SELECT cards FROM find_cards(cust));

      -- check the if customer register of redeem
      IF (latest_redeem <> NULL AND latest_register <> NULL) THEN
        IF (latest_redeem > latest_register) THEN
          if_register = 0;
        ELSE
          if_register = 1;
        END IF;
      ELSE
        IF (latest_redeem = NULL) THEN
          if_register = 1;
        ELSE
          if_register = 0;
        END IF;
      END IF;

      -- if regester directly
      IF if_register = 1 THEN
        SELECT sid INTO session FROM Registers WHERE course_id = course AND launch_date = launch AND card_number IN (SELECT cards FROM find_cards(cust));
        SELECT fees INTO fee FROM Offerings WHERE course_id = course AND launch_date = launch;
        SELECT date INTO registered_session_start FROM Sessions WHERE course_id = course AND launch_date = launch AND sid = session;
        -- check can be refund
        IF registered_session_start-7 >= CURRENT_DATE THEN
          refund_amt := fee * 0.9;
          package_credit := 0;
          INSERT INTO Cancels VALUES (cust, course, launch, session, CURRENT_DATE, refund_amt, package_credit);
        ELSE
          refund_amt := 0; -- not refundable
          package_credit := 0;
          INSERT INTO Cancels VALUES (cust, course, launch, session, CURRENT_DATE, refund_amt, package_credit);
          RAISE NOTICE 'Cancellation will be proceed, but will be no refund as cancellation is made at least 7 days before the day of the registered session';
        END IF;
      -- redeem
      ELSE
        SELECT sid INTO session FROM Redeems WHERE course_id = course AND launch_date = launch AND card_number IN (SELECT cards FROM find_cards(cust));
        SELECT date INTO registered_session_start FROM Sessions WHERE course_id = course AND launch_date = launch AND sid = session;
        -- check can be refund
        IF registered_session_start-7 >= CURRENT_DATE THEN
          refund_amt := 0;
          package_credit := 1;
          INSERT INTO Cancels VALUES (cust, course, launch, session, CURRENT_DATE, refund_amt, package_credit);
        ELSE
          refund_amt := 0;
          package_credit := 0; -- not refundable
          INSERT INTO Cancels VALUES (cust, course, launch, session, CURRENT_DATE, refund_amt, package_credit);
          RAISE NOTICE 'Cancellation will be proceed, but will be no refund as cancellation is made at least 7 days before the day of the registered session';
        END IF;
      END IF;
    END IF;
  END;
$$ LANGUAGE plpgsql;

-- test 20:
-- 1 pass the date
-- CALL cancel_registration (2, 2, DATE '2020-10-05');
-- 2 customer register directly
-- CALL cancel_registration (8, 5, DATE '2021-03-30');
-- 3 customer redeem
--
-- null value in column "sid" violates not-null constraint
-- CALL cancel_registration (2, 5, DATE '2021-03-30');








-- 21
-- syntax correct
-- 21. update_instructor: This routine is used to change the instructor for a course session.
CREATE OR REPLACE PROCEDURE update_instructor (course INTEGER, launch DATE, session_id INTEGER, new_eid INTEGER)
AS $$
  DECLARE
    session_date DATE;
    start_time INTEGER;
  BEGIN
  SELECT date, start_time INTO session_date, start_time FROM Sessions WHERE course_id = course AND sid = session_id;
  IF (new_eid NOT IN (SELECT eid FROM find_instructors (course, session_date, start_time))) THEN
    RAISE EXCEPTION 'instructor not avaliable';
  ELSIF session_date > CURRENT_DATE THEN
    RAISE EXCEPTION 'session started';
  ELSE
    UPDATE Sessions
      SET eid = new_eid
      WHERE course_id = course AND session_id = sid AND launch_date = launch;
  END IF;
  END;
$$ LANGUAGE plpgsql;
-- test 21:
-- 1 instructor is not available -- ?
-- CALL update_instructor (7, DATE '2021-03-30', 1, 15);
-- 2 instructor is available
--



-- 22
-- syntax correct
-- 22. update_room: This routine is used to change the room for a course session.
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
    target INTEGER;

  BEGIN
  	SELECT date, start_time, end_time, rid INTO session_date, session_start, session_end, old_room FROM Sessions WHERE course_id = course AND sid = session_id AND launch_date = launch;
    -- the seat capacity offering before the update
    SELECT seating_capacity, target_number_registrations INTO offering_capacity, target FROM Offerings WHERE course_id = course AND launch_date = launch;


    IF (new_rid NOT IN (SELECT rid FROM find_rooms(session_date, session_start, session_start - session_end))) THEN
      RAISE EXCEPTION 'the room is not available';

    ELSIF session_date > CURRENT_DATE THEN
      RAISE EXCEPTION 'session started';

    ELSE
      students := student_in_session(course, launch, session);
      SELECT seating_capacity INTO seat FROM Rooms WHERE rid = new_rid; -- the seat capacity of the new room
      SELECT seating_capacity INTO seat_old FROM Rooms WHERE rid = old_room ; -- the seat capacity of the old room

      -- check if the number of student in the session exceeds the room capacity
      IF (students <= seat) THEN

      -- if the new room will make the seating capacity of the offering exceeds
      ELSIF (offering_capacity - seat_old + seat) > target THEN
        RAISE EXCEPTION 'target_number_registrations exceeds';

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

-- test 22:
-- 1 room is available
-- CALL update_room (7, DATE '2021-03-30', 4, 4);
-- 2 room is not available
--




-- 23.

-- 23. remove_session: This routine is used to remove a course session.
CREATE OR REPLACE PROCEDURE remove_session (course INTEGER, launch DATE, session_id INTEGER)
AS $$

  BEGIN
    DELETE FROM Sessions WHERE course_id = course AND launch_date = launch AND sid = session_id;

  END;
$$ LANGUAGE plpgsql;
-- test 23:
-- 1 offering time changed
--
-- 2 there are student in the session
--
-- 3 session started
-- CALL remove_session (4, DATE '2020-09-01', 2);
-- 4 update or delete on table "sessions" violates foreign key constraint "registers_course_id_launch_date_sid_fkey" on table "registers"
-- CALL remove_session (5, DATE '2021-03-30', 1);
-- 5 update or delete on table "sessions" violates foreign key constraint "redeems_course_id_launch_date_sid_fkey" on table "redeems"
-- CALL remove_session (5, DATE '2021-03-10', 2);



-- 24. add_session: This routine is used to add a new session to a course offering. The
-- update offering trigger
-- syntax correct
CREATE OR REPLACE PROCEDURE add_session (course INTEGER, launch DATE, new_sid INTEGER, start_date DATE, start NUMERIC(4,2), instructor INTEGER, room INTEGER)
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

    ELSIF new_capacity > target_number THEN -- if the new seat capacity < target_number_registrations
      RAISE EXCEPTION 'seating capacity exceeds target number registrations, unable to add session';

    -- insert to session
    ELSE
      SELECT duration INTO session_duration FROM Courses WHERE course_id = course;

      INSERT INTO Sessions
        VALUES (course, launch, new_sid, start_date, start, (start+session_duration), instructor, room);
      -- update offering since start date or send date may change after new swssion being inserted
      UPDATE Offerings
        SET start_date = COALESCE(LEAST(start_date, NEW.date)), end_date = COALESCE(GREATEST(end_date, NEW.date))
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




-- 30. view_manager_report:
-- This routine is used to view a report on the sales generated by each manager.
-- returns a table
-- 1. manager name
-- 2. total number of course areas that are managed by the manager
-- 3. total number of course offerings that ended this year (i.e., the course offering’s end date is within this year) that are managed by the manager
-- 4. *total net registration fees* for #all the course offerings# that ended this year that are managed by the manager
-- 5. the course offering title (i.e., course title) that has the *highest total net registration fees* #among all the course offerings that ended this year that are managed by the manager

-- Each manager manages zero or more course areas, and each course area is managed by exactly one manager. Each course offering is managed by the manager of that course area.

-- syntax correct
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
  SELECT COUNT(*) INTO count_registers
    FROM (
      (SELECT course_id, launch_date FROM Registers WHERE course_id = course AND launch_date = launch)
		EXCEPT
      (SELECT course_id, launch_date FROM Cancels WHERE course_id = course AND launch_date = launch)
    ) A;
  fees_register := count_registers * fees;

  -- customers redeem
  SELECT ROUND(SUM(C.price/C.num_free_registrations))
  INTO fees_redeem
  FROM (
    (SELECT C.package_id, C.num_free_registrations, C.price FROM Course_packages C) C
    INNER JOIN
    -- packages that used to redeem the couse offering
    (SELECT package_id
      FROM (SELECT *
        FROM (
          ((SELECT course_id, launch_date FROM Redeems WHERE course_id = course AND launch_date = launch)
  		  EXCEPT
          (SELECT course_id, launch_date FROM Cancels WHERE course_id = course AND launch_date = launch)) A
        INNER JOIN
          (SELECT package_id, course_id, launch_date FROM Redeems WHERE course_id = course AND launch_date = launch) B
        ON (A.course_id = B.course_id AND A.launch_date = B.launch_date)
        ) R
    ) P

  ) I
    ON (C.package_id = I.package_id)
  );
  -- total fees for one offering
  fees_offering := fees_register + fees_redeem;
  RETURN fees_offering;
END;
$$ LANGUAGE plpgsql;

-- syntax correct
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
    LOOP
      FETCH curs_o INTO r_o;
      EXIT WHEN NOT FOUND;
      fees_offering := fee_one_offering(r_o.course_id, r_o.launch_date, r_o.fees);
      total_fee := total_fee + fees_offering;
    END LOOP;
    CLOSE curs_o;
    RETURN total_fee;
  END;
$$ LANGUAGE plpgsql;


-- syntax correct
CREATE OR REPLACE FUNCTION highest_total_fees(year INTEGER, M_eid INTEGER)
RETURNS TABLE(title TEXT) AS $$
  -- highest total net registration fees among all the course offerings
  (SELECT B.title
  FROM (
    (SELECT course_id, MAX(f)
    FROM (
      SELECT course_id, fee_one_offering(course_id, launch_date, fees) AS f
      FROM Offerings
      -- the offering managed by this manager that ended this year
      WHERE course_id
          IN (SELECT course_id FROM Courses WHERE course_area IN (SELECT name FROM Course_areas WHERE eid = M_eid))
        AND EXTRACT(YEAR FROM end_date) = year
      ) C
	 GROUP BY course_id
    ) A
    INNER JOIN
    (SELECT course_id, title FROM Courses) B
    ON (A.course_id = B.course_id)
 ));
$$ LANGUAGE SQL;


-- syntax correct
CREATE OR REPLACE FUNCTION view_manager_report()
RETURNS TABLE (M_name TEXT, num_course_areas INTEGER, num_course_offering INTEGER, total_registratino_fee NUMERIC, course_title TEXT) AS $$
  DECLARE
    current_year INTEGER;
    max_offering_fee NUMERIC;
    max_cid INTEGER;
    curs_m CURSOR FOR (SELECT * FROM Managers);
    r_m RECORD;
    curs_tie refcursor;
    r_tie RECORD;
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
      total_registratino_fee := total_fee(r_m.eid);

      -- title of course offering with the highest registration fee.
      OPEN curs_tie FOR (SELECT * FROM highest_total_fees(current_year, r_m.eid));
      LOOP
        FETCH curs_tie INTO r_tie;
        EXIT WHEN NOT FOUND;
        course_title := r_tie.title;
        RETURN NEXT;
      END LOOP;
      CLOSE curs_tie;
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
