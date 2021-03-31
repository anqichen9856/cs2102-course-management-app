-- 19
-- this function uses cust_id to find card_number of cards that owned by this customer
CREATE OR REPLACE FUNCTION find_cards(cust INTEGER)
RETURNS TABLE(cards TEXT) AS $$
SELECT card_number INTO cards
FROM Owns
WHERE cust_id = cust;
$$ LANGUAGE sql;


-- this function returns a boolean
-- TRUE if the customer directly register; FALSE if the customer redeem
CREATE FUNCTION inRegister(cust INTEGER, course INTEGER, launch DATE)
  RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS(
    SELECT *
    FROM Registers
    WHERE course_id = course AND launch_date = launch AND card_number IN find_cards(cust);
  );
END
$$ LANGUAGE plpgsql;


-- 19. update_course_session: a customer requests to change a registered course session to another session.
CREATE OR REPLACE PROCEDURE update_course_session (cust INTEGER, course INTEGER, launch DATE, new_sid INTEGER) AS $$

BEGIN
  -- check if the new session is available
  IF new_sid NOT IN (get_available_course_sessions(course_id, launch_date)) THEN
    RAISE EXCEPTION 'session is not avaliable'
  END IF;

  IF inRegister(cust, course, launch) THEN
    -- since a customer can register for at most one of its sessions before its registration deadline
    -- it is guaranteed that there is only one record for one customer in registers/redeems
    -- update in Registers
    UPDATE Registers SET sid = new_sid WHERE card_number IN find_cards(cust) AND, course_id = course AND launch_date = launch;
  ELSE
    -- update in Redeems
    UPDATE Redeems SET sid = new_sid WHERE card_number IN find_cards(cust) AND, course_id = course AND launch_date = launch;
  END IF;

END;
$$ LANGUAGE sql;




-- 20

-- check if cancelltion can be made
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

CREATE CONSTRAINT TRIGGER insert_cancel_trigger
AFTER INSERT ON Cancels
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION insert_cancel_func();


-- if session is redeemed update Buy after cancelltion
CREATE OR REPLACE FUNCTION update_buy_func() RETURN TRIGGER AS $$
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
      WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date AND card_number IN find_cards(NEW.cust_id);

    SELECT num_remaining_redemptions
      INTO num_remaining_before FROM Buys
      WHERE package_id = pid AND card_number IN find_cards(NEW.cust_id) AND date = buy;

    -- update the package that customer used to redeem the canceled session
    UPDATE Buys
      SET num_remaining_redemptions = num_remaining_before + 1
      WHERE package_id = pid AND card_number IN find_cards(NEW.cust_id) AND date = buy;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_buy_trigger
AFTER INSERT ON Cancels
FOR EACH ROW EXECUTE FUNCTION update_buy_func();


-- 20. cancel_registration: when a customer requests to cancel a registered course session.
CREATE OR REPLACE PROCEDURE cancel_registration (cust INTEGER, course INTEGER, launch DATE) AS $$

DECLARE
  sid INTEGER;
  refund_amt NUMERIC(10,2);
  package_credit INTEGER;
  fee NUMERIC(10,2);

BEGIN
  -- if regester directly:
  IF inRegister(cust INTEGER, course INTEGER, launch DATE) THEN
    SELECT fees INTO fee FROM Offering WHERE course_id = course AND launch_date = launch;
    refund_amt := fee * 0.9
    package_credit := 0

  -- if not regester by directly, must used credit card
  ELSE
    refund_amt := 0
    package_credit := 1
  END IF;

  INSERT INTO Cancels VALUES (cust, course, launch, sid, CURRENT_DATE, refund_amt, package_credit);
END;
$$ LANGUAGE sql;




-- sessions triggers
CREATE OR REPLACE FUNCTION sessions_func() RETURNS TRIGGER
AS $$
DECLARE
  deadline INTEGER;
  register_num INTEGER;
  course_specialize TEXT;
  working_month INTEGER;
  offering_start_date date;
  offering_end_date date;

BEGIN

  IF NOT EXISTS(SELECT * FROM Offerings WHERE course_id = NEW.course_id AND  NEW.launch_date;) THEN
    RAISE EXCEPTION 'couese offering does not exist, unable to add session';
  ELSE
    SELECT registration_deadline INTO deadline FROM Offerings WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date;
    SELECT course_area INTO course_specialize FROM Courses WHERE course_id = NEW.course_id;

    IF NOT EXISTS(SELECT * FROM Rooms WHERE rid = NEW.rid) THEN
      RAISE EXCEPTION 'room does not exist, unable to INSERT or UPDATE';

    ELSIF deadline < CURRENT_DATE THEN
      RAISE EXCEPTION 'the course offering’s registration deadline has passed, unable to add session';

    ELSIF NEW.date < CURRENT_DATE THEN
      RAISE EXCEPTION 'the course session has started, unable to INSERT or UPDATE';

    ELSIF EXISTS(SELECT * FROM Sessions WHERE rid = new_eid AND date = NEW.date AND start_time = NEW.start_time) THEN
      RAISE EXCEPTION 'the room is in use, unable to INSERT or UPDATE';

    ELSIF NOT EXISTS(SELECT * FROM Instructors WHERE eid = NEW.eid) THEN
      RAISE EXCEPTION 'the instructor dose not exist, unable to INSERT or UPDATE';

    ELSIF course_area NOT IN (SELECT area INTO instructor_specialize FROM Specializes WHERE eid = NEW.eid;) THEN
      RAISE EXCEPTION 'an instructor who is assigned to teach a course session not specialized in that course area, unable to INSERT or UPDATE.';

    ELSIF EXISTS(SELECT * FROM Courses WHERE date = NEW.date AND start_time = NEW.start_time AND eid = NEW.eid;) THEN
      RAISE EXCEPTION 'an instructor can not teach more than one course session at any hour, unable to INSERT or UPDATE';

    ELSIF EXISTS (SELECT * FROM Sessions WHERE eid = NEW.eid AND date = NEW.date AND (end_time - NEW.start_time < 1 OR NEW.start_time - start_time < 1)) THEN
      RAISE EXCEPTION 'an instructor must not be assigned to teach two consecutive course sessions, unable to INSERT or UPDATE';

    ELSIF NEW.eid IN (SELECT eid FROM Part_time_instructors;) THEN
      -- NOT SURE HOW
      -- the working hour varys month to month?
      -- table constrint?
      SELECT num_work_hours INTO working_month FROM Pay_slips WHERE eid = NEW.eid AND EXTRACT(MONTH FROM payment_date) = EXTRACT(MONTH FROM  NEW.date);
      IF num_work_hours > 30 THEN
        RAISE EXCEPTION 'a part-time instructor must not teach more than 30 hours for each month, unable to INSERT or UPDATE';
      END IF;

    ELSE
      -- update Offering
      UPDATE Offerings
        SET start_date = MIN(start_date, OLD.date), end_date = MAX(end_date, OLD.date)
        WHERE course_id = OLD.course_id AND launch_date = OLD.launch_date;
      -- update/insert new value to Sessions
      RETURN NEW;

    END IF;
  END IF;

END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER sessions_trigger
AFTER INSERT OR UPDATE ON Sessions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION sessions_func();


CREATE OR REPLACE FUNCTION sessions_delete_func() RETURNS TRIGGER
AS $$
DECLARE
  regist_num_redeem INTEGER;
  regist_num_Registers INTEGER;
  offering_start_date date;
  offering_end_date date;
BEGIN
  SELECT count(*) INTO regist_num_redeem FROM Redeems WHERE course_id = course AND sid = session_id AND launch_date = launch;
  SELECT count(*) INTO regist_num_Registers FROM register WHERE course_id = course AND sid = session_id AND launch_date = launch;
  -- check if there are someone in the session
  IF (regist_num_redeem + regist_num_Registers > 0) THEN
    RAISE EXCEPTION 'there are student in the session';
  ELSIf OLD.date < CURRENT_DATE THEN
    RAISE EXCEPTION 'the course session has started';
  END IF;

  -- ????
  UPDATE Offerings
    SET start_date = MIN(start_date, OLD.date), end_date = MAX(end_date, OLD.date)
    WHERE course_id = OLD.course_id AND launch_date = OLD.launch_date;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER sessions_delete_trigger
AFTER DELETE ON Sessions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION sessions_delete_func();




-- 21
-- 21. update_instructor: This routine is used to change the instructor for a course session.
CREATE OR REPLACE PROCEDURE update_instructor (course INTEGER, launch DATE, session_id INTEGER, new_eid INTEGER)
RETURNS RECORD AS $$
BEGIN
  UPDATE Sessions
    SET eid = new_eid
    WHERE course_id = course AND session_id = sid AND launch_date = launch;
END;
$$ LANGUAGE sql;


-- 22
-- 22. update_room: This routine is used to change the room for a course session.
CREATE OR REPLACE PROCEDURE update_room (course INTEGER, launch DATE, session_id INTEGER, new_rid INTEGER)
RETURNS RECORD AS $$
DECLARE
  seat INTEGER;
  regist_num_redeem INTEGER;
  regist_num_Registers INTEGER;

BEGIN
  SELECT count(*) INTO regist_num_redeem FROM Redeems WHERE course_id = course AND sid = session_id AND launch_date = launch;
  SELECT count(*) INTO regist_num_Registers FROM register WHERE course_id = course AND sid = session_id AND launch_date = launch;
  SELECT seating_capacity INTO seat FROM Rooms WHERE rid = new_rid;
  -- check if the number of student in the session exceeds the room capacity
  IF (regist_num_redeem + regist_num_Registers <= seat) THEN
    UPDATE Sessions
      SET rid = new_rid
      WHERE course_id = course AND session_id = sid AND launch_date = launch;
  END IF;
END;

$$ LANGUAGE sql;



-- 23.


-- 23. remove_session: This routine is used to remove a course session.
CREATE OR REPLACE PROCEDURE remove_session (course INTEGER, launch DATE, session_id INTEGER)
RETURNS RECORD AS $$

BEGIN
  DELETE FROM Sessions WHERE course_id = course AND launch_date = launch AND sid = session_id;
END;

$$ LANGUAGE sql;



-- 24. add_session: This routine is used to add a new session to a course offering. The
-- update offering trigger


CREATE OR REPLACE PROCEDURE add_session (course INTEGER, launch DATE, new_sid INTEGER, start_date DATE, start NUMERIC(4,2), instructor INTEGER, room INTEGER)
RETURNS RECORD AS $$

DECLARE
  session_duration NUMERIC(4,2);
BEGIN
  SELECT duration INTO session_duration FROM Courses WHERE course_id = course;
  INSERT INTO Sessions
    VALUES (course, launch, new_sid, start_date, start, (start+session_duration), instructor, room);

END;

$$ LANGUAGE sql;
