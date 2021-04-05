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
-- syntax correct
CREATE OR REPLACE FUNCTION inRegister(cust INTEGER, course INTEGER, launch DATE)
  RETURNS BOOLEAN AS $$
  SELECT EXISTS (
	  SELECT * FROM Registers r
	  WHERE r.course_id = course AND r.launch_date = launch
	  AND (r.card_number IN (SELECT * FROM find_cards(cust)))
  );
$$ LANGUAGE sql;

-- output: the number of student currently in the session.
-- syntax correct
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
        WHERE R.course_id = course AND R.launch_date = launch AND R.sid = ssession
    ) A;
    SELECT count(*) INTO count_registers
    FROM (
        SELECT *
        FROM Registers R
        WHERE R.course_id = course AND R.launch_date = launch AND R.sid = ssession
    ) B;
    SELECT count(*) INTO count_cancels
    FROM (
        SELECT *
        FROM Cancels C
        WHERE C.course_id = course AND C.launch_date = launch AND C.sid = ssession
    ) C;
    count_registration := count_redeems + count_registers - count_cancels;
    RETURN count_registration;
  END;
$$ LANGUAGE plpgsql;


-- 19. update_course_session: a customer requests to change a registered course session to another session.
-- syntax correct
CREATE OR REPLACE PROCEDURE update_course_session (cust INTEGER, course INTEGER, launch DATE, new_sid INTEGER) AS $$

  BEGIN
    -- check if the new session is available
    IF new_sid NOT IN (get_available_course_sessions(course_id, launch_date)) THEN
      RAISE EXCEPTION 'session is not avaliable';

    ELSIF inRegister(cust, course, launch) THEN
      -- since a customer can register for at most one of its sessions before its registration deadline
      -- it is guaranteed that there is only one record for one customer in registers/redeems
      -- update in Registers
      UPDATE Registers SET sid = new_sid WHERE card_number IN (SELECT * FROM find_cards(cust)) AND course_id = course AND launch_date = launch;
    ELSE
      -- update in Redeems
      UPDATE Redeems SET sid = new_sid WHERE card_number IN (SELECT * FROM find_cards(cust)) AND course_id = course AND launch_date = launch;
    END IF;
  END;
$$ LANGUAGE plpgsql;




-- 20

-- check if cancelltion can be made
-- syntax correct
CREATE OR REPLACE FUNCTION insert_cancel_func() RETURNS TRIGGER
  AS $$
  DECLARE
    registered_session_start DATE;

  BEGIN
    SELECT date INTO registered_session_start FROM Sessions WHERE cust_id = NEW.cust_id AND launch_date = NEW.launch_date AND sid = NEW.sid;
    -- check cancelltion is valid
    IF registered_session_start-7 < CURRENT_DATE THEN
      RAISE EXCEPTION 'Cancel will be proceed only if cancellation is made at least 7 days before the day of the registered session';
    END IF;
    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS insert_cancel_trigger ON Cancels;

CREATE CONSTRAINT TRIGGER insert_cancel_trigger
AFTER INSERT ON Cancels
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION insert_cancel_func();


-- if session is redeemed update Buy after cancelltion
-- syntax correct
CREATE OR REPLACE FUNCTION update_buy_func() RETURNS TRIGGER AS $$
  DECLARE
    pid INTEGER; -- new
    num_remaining_before INTEGER;
    buy INTEGER;
  BEGIN
    -- if the customer must use package to redeem
    IF NEW.package_credit = 1 THEN
      -- find the package_id and the buy_date for the canceled session
      SELECT package_id, buy_date
        INTO pid, buy FROM Redeems
        WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date AND card_number IN (SELECT cards FROM find_cards(NEW.cust_id));

      SELECT num_remaining_redemptions
        INTO num_remaining_before FROM Buys
        WHERE package_id = pid AND card_number IN (SELECT cards FROM find_cards(NEW.cust_id)) AND date = buy;

      -- update the package that customer used to redeem the canceled session
      UPDATE Buys
        SET num_remaining_redemptions = num_remaining_before + 1
        WHERE package_id = pid AND card_number IN (SELECT cards FROM find_cards(NEW.cust_id)) AND date = buy;
    END IF;
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_buy_trigger ON Cancels;

CREATE TRIGGER update_buy_trigger
AFTER INSERT ON Cancels
FOR EACH ROW EXECUTE FUNCTION update_buy_func();



-- syntax correct
-- 20. cancel_registration: when a customer requests to cancel a registered course session.
CREATE OR REPLACE PROCEDURE cancel_registration (cust INTEGER, course INTEGER, launch DATE) AS $$
  DECLARE
    sid INTEGER;
    refund_amt NUMERIC(10,2);
    package_credit INTEGER;
    fee NUMERIC(10,2);

  BEGIN
    -- if regester directly:
    IF inRegister(cust, course, launch) THEN
      SELECT fees INTO fee FROM Offering WHERE course_id = course AND launch_date = launch;
      refund_amt := fee * 0.9;
      package_credit := 0;

    -- if not regester by directly, must used credit card
    ELSE
      refund_amt := 0;
      package_credit := 1;
    END IF;

    INSERT INTO Cancels VALUES (cust, course, launch, sid, CURRENT_DATE, refund_amt, package_credit);
  END;
$$ LANGUAGE plpgsql;




-- sessions triggers
-- syntax correct
CREATE OR REPLACE FUNCTION sessions_func() RETURNS TRIGGER
AS $$
  DECLARE
    deadline DATE;
    session_duration NUMERIC(4,2);

  BEGIN
    IF NOT EXISTS(SELECT * FROM Offerings WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date) THEN
      RAISE EXCEPTION 'couese offering does not exist, unable to add session';
    ELSE
      SELECT registration_deadline INTO deadline FROM Offerings WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date;
      SELECT duration INTO session_duration FROM Courses WHERE course_id = NEW.course_id;

      IF deadline < CURRENT_DATE THEN
        RAISE EXCEPTION 'the course offering’s registration deadline has passed, unable to add session';

      ELSIF NEW.date < CURRENT_DATE THEN
        RAISE EXCEPTION 'the course session has started, unable to INSERT or UPDATE';

      -- check if the room is valiable for the session
      ELSIF NEW.rid NOT IN (SELECT * FROM find_rooms(NEW.date, NEW.start_time, session_duration)) THEN
        RAISE EXCEPTION 'the room is not available, unable to INSERT or UPDATE';

      -- check if the instructor can teach this session
      ELSIF NEW.eid NOT IN (SELECT eid FROM find_instructors (NEW.course_id, NEW.date, NEW.start_time)) THEN
        RAISE EXCEPTION 'instructor not avaliable, unable to INSERT or UPDATE';

      ELSE
        -- update Offering
        UPDATE Offerings
          SET start_date = MIN(start_date, NEW.date), end_date = MAX(end_date, NEW.date)
          WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date;

        -- update/insert new value to Sessions
        RETURN NEW;
      END IF;
    END IF;

  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sessions_trigger ON Sessions;

CREATE CONSTRAINT TRIGGER sessions_trigger
AFTER INSERT OR UPDATE ON Sessions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION sessions_func();



-- syntax correct
CREATE OR REPLACE FUNCTION sessions_delete_func() RETURNS TRIGGER
AS $$
  DECLARE
    students INTEGER;
  BEGIN
    students := student_in_session(OLD.course_id, OLD.launch_date, OLD.sid);
    -- check if there are someone in the session
    IF (students > 0) THEN
      RAISE EXCEPTION 'there are student in the session, cannot delete session';
    ELSIf OLD.date < CURRENT_DATE THEN
      RAISE EXCEPTION 'the course session has started';
    ELSE
      RETURN NULL;
    END IF;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sessions_delete_trigger ON Sessions;

CREATE CONSTRAINT TRIGGER sessions_delete_trigger
AFTER DELETE ON Sessions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION sessions_delete_func();




-- 21
-- syntax correct
-- 21. update_instructor: This routine is used to change the instructor for a course session.
CREATE OR REPLACE PROCEDURE update_instructor (course INTEGER, launch DATE, session_id INTEGER, new_eid INTEGER)
AS $$
  BEGIN
    UPDATE Sessions
      SET eid = new_eid
      WHERE course_id = course AND session_id = sid AND launch_date = launch;
  END;
$$ LANGUAGE plpgsql;


-- 22
-- syntax correct
-- 22. update_room: This routine is used to change the room for a course session.
CREATE OR REPLACE PROCEDURE update_room (course INTEGER, launch DATE, session_id INTEGER, new_rid INTEGER)
AS $$
  DECLARE
    seat INTEGER;
    students INTEGER;

  BEGIN
    students := student_in_session(course, launch, session);
    SELECT seating_capacity INTO seat FROM Rooms WHERE rid = new_rid;
    -- check if the number of student in the session exceeds the room capacity
    IF (students <= seat) THEN
      UPDATE Sessions
        SET rid = new_rid
        WHERE course_id = course AND session_id = sid AND launch_date = launch;
    END IF;
  END;
$$ LANGUAGE plpgsql;



-- 23.

-- syntax correct
-- 23. remove_session: This routine is used to remove a course session.
CREATE OR REPLACE PROCEDURE remove_session (course INTEGER, launch DATE, session_id INTEGER)
AS $$
  DECLARE
    offering_start DATE;
    offering_end DATE;
  BEGIN
    DELETE FROM Sessions WHERE course_id = course AND launch_date = launch AND sid = session_id;
    SELECT COALESCE(MIN(date)) INTO offering_start FROM Sessions WHERE course_id = course AND launch_date = launch;
    SELECT COALESCE(MAX(date)) INTO offering_end FROM Sessions WHERE course_id = course AND launch_date = launch;
    UPDATE Offerings
      SET start_date = offering_start, end_date = offering_end
      WHERE course_id = OLD.course_id AND launch_date = OLD.launch_date;
  END;
$$ LANGUAGE plpgsql;



-- 24. add_session: This routine is used to add a new session to a course offering. The
-- update offering trigger
-- syntax correct
CREATE OR REPLACE PROCEDURE add_session (course INTEGER, launch DATE, new_sid INTEGER, start_date DATE, start NUMERIC(4,2), instructor INTEGER, room INTEGER)
AS $$
  DECLARE
    session_duration NUMERIC(4,2);
  BEGIN
    SELECT duration INTO session_duration FROM Courses WHERE course_id = course;
    INSERT INTO Sessions
      VALUES (course, launch, new_sid, start_date, start, (start+session_duration), instructor, room);
  END;
$$ LANGUAGE  plpgsql;





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
  -- costommers register directly
  -- number of costommer registered directly
  SELECT COUNT(*) INTO count_registers
    FROM (
      (SELECT course_id, launch_date FROM Registers WHERE course_id = course AND launch_date = launch)
		EXCEPT
      (SELECT course_id, launch_date FROM Cancels WHERE course_id = course AND launch_date = launch)
    ) A;
  fees_register := count_registers * fees;

-- syntax correct
  -- costommers redeem
  SELECT SUM(C.price/C.num_free_registrations)
  INTO fees_redeem
  FROM (
    (SELECT C.package_id, C.num_free_registrations, C.price FROM Course_packages C) C
    INNER JOIN
    -- packages that used to redeem the couse offering
    (SELECT P.package_id
      FROM (
        (SELECT course_id, launch_date FROM Redeems WHERE course_id = course AND launch_date = launch)
		  EXCEPT
        (SELECT course_id, launch_date FROM Cancels WHERE course_id = course AND launch_date = launch)
      ) P
    ) I
    ON (C.package_id = P.package_id)
  );
  -- total fees for one offering
  fees_offering := fees_register + fees_redeem;
  RETURN fees_offering;
END;
$$ LANGUAGE plpgsql;

-- syntax correct
CREATE FUNCTION total_fee(M_eid INTEGER)
  RETURNS NUMERIC AS $$
  DECLARE
    fees_offering NUMERIC;
    total_fee NUMERIC;
    -- for each couse offering by the manager with id M_eid
    curs CURSOR FOR
      (SELECT * FROM Offering
        WHERE course_id IN (SELECT course_id FROM Courses WHERE course_area IN (SELECT * FROM Course_areas WHERE eid = M_eid))
          AND EXTRACT(YEAR FROM end_date) = current_year);
    r RECORD;
  BEGIN
    OPEN curs;
    LOOP
      FETCH curs INTO r;
      EXIT WHEN NOT FOUND;
      fees_offering := fee_one_offering(r.course_id, r.launch_date, r.fees);
      total_fee := total_fee + fees_offering;
    END LOOP;
    CLOSE curs;
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
          IN (SELECT course_id FROM Courses WHERE course_area IN (SELECT course_area FROM Course_areas WHERE eid = M_eid))
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
    curs CURSOR FOR (SELECT * FROM Managers);
    r RECORD;
    curs_tie refcursor;
    r_tie RECORD;
  BEGIN
    current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    OPEN curs;
    LOOP
      FETCH curs INTO r;
      EXIT WHEN NOT FOUND;

      -- name of manager
      SELECT name INTO M_name FROM Employees WHERE eid = r.eid;

      -- number of course area
      SELECT COUNT(*) INTO num_course_areas FROM Course_areas WHERE eid = r.eid;

      -- number of course offering
      SELECT COUNT(*)
        INTO num_course_offering
        FROM Offerings
        -- the offering managed by this manager that ended this year
        WHERE course_id
            IN (SELECT course_id FROM Courses WHERE course_area IN (SELECT * FROM Course_areas WHERE eid = r.eid))
          AND EXTRACT(YEAR FROM end_date) = current_year; -- ended this year

      -- find total registratino fee
      total_registratino_fee := total_fee(r.eid);

      -- title of course offering with the highest registration fee.
      OPEN curs_tie FOR (SELECT * FROM highest_total_fees(current_year, r.eid));
      LOOP
        FETCH curs_tie INTO r_tie;
        EXIT WHEN NOT FOUND;
        course_title := r_tie.title;
        RETURN NEXT;
      END LOOP;
      CLOSE curs_tie;
    END LOOP;
    CLOSE curs;
  END;
$$ LANGUAGE plpgsql;
