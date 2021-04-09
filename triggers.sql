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
        RAISE EXCEPTION 'Credit card % has already expired.', NEW.number;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER credit_card_own_before_expiry_date_trigger
AFTER INSERT OR UPDATE ON Owns
DEFERRABLE INITIALLY DEFERRED
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
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER course_area_manager_trigger
AFTER INSERT OR UPDATE ON Course_areas
DEFERRABLE INITIALLY DEFERRED
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
    IF NOT EXISTS (SELECT 1 FROM Owns O WHERE O.card_number = NEW.card_number) THEN
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
       SELECT 1 FROM Credit_cards C WHERE C.number = NEW.card_number
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
    pid INTEGER; -- new
    num_remaining_before INTEGER;
    buy DATE;
  BEGIN
    -- if the customer use package to redeem and is refundable, package_credit = 1
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

DROP TRIGGER IF EXISTS update_buy_cancel_trigger ON Cancels;

CREATE TRIGGER update_buy_cancel_trigger
AFTER INSERT ON Cancels
FOR EACH ROW EXECUTE FUNCTION update_buy_cancel_func();







-- this function returns a boolean
-- TRUE if there is overlap in the session; FALSE if there is no overlap
CREATE OR REPLACE FUNCTION ifOverlap(session_rid INTEGER, session_date DATE, new_start_time NUMERIC(4,2), new_end_time NUMERIC(4,2))
  RETURNS BOOLEAN AS $$
  SELECT EXISTS (
                SELECT * FROM Sessions S
                WHERE S.date = session_date
                AND S.rid = session_rid
                AND (
                    (S.start_time >= new_start_time AND S.start_time < new_end_time) OR
                    (S.end_time > new_start_time AND S.end_time <= new_end_time) OR
                    (new_start_time >= S.start_time AND S.start_time < new_end_time) OR
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
    IF ifOverlap(NEW.rid, NEW.date, NEW.start_time, NEW.end_time) THEN
      RAISE EXCEPTION 'the new session is overlap with other session';

    -- check if the room is valiable for the session
    -- IF NOT EXISTS(SELECT * FROM find_rooms(NEW.date, NEW.start_time, session_duration) WHERE rid = NEW.rid) THEN
	  ELSIF (NEW.rid NOT IN (SELECT rid FROM find_rooms(NEW.date, NEW.start_time, session_duration))) THEN
      RAISE EXCEPTION 'the room is not available, unable to INSERT or UPDATE';

    -- check if the instructor can teach this session
    ELSIF (NEW.eid NOT IN (SELECT eid FROM find_instructors (NEW.course_id, NEW.date, NEW.start_time))) THEN
      RAISE EXCEPTION 'instructor not avaliable, unable to INSERT or UPDATE';
    ELSE
      RETURN NEW;
    END IF;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS insert_session_trigger ON Sessions;

CREATE CONSTRAINT TRIGGER insert_session_trigger
AFTER INSERT ON Sessions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION insert_session_func();




CREATE OR REPLACE FUNCTION delete_sessions_func() RETURNS TRIGGER
AS $$
  DECLARE
    students INTEGER;
    offering_start DATE;
    offering_end DATE;
    room_id INTEGER;
    room_deleted_session INTEGER;
  BEGIN
    students := student_in_session(OLD.course_id, OLD.launch_date, OLD.sid); --
    -- check if there are someone in the session
    -- registers_course_id_launch_date_sid_fkey & redeems_course_id_launch_date_sid_fkey already checked ???
    IF (students > 0) THEN
      RAISE EXCEPTION 'there are student in the session, cannot delete session';
    ELSIf OLD.date < CURRENT_DATE THEN
      RAISE EXCEPTION 'the course session has started';
    ELSE
      SELECT COALESCE(MIN(date)) INTO offering_start FROM Sessions WHERE course_id = OLD.course_id AND launch_date = OLD.launch_date;
      SELECT COALESCE(MAX(date)) INTO offering_end FROM Sessions WHERE course_id = OLD.course_id AND launch_date = OLD.launch_date;
      SELECT rid INTO room_id FROM Sessions WHERE course_id = OLD.course_id AND launch_date = OLD.launch_date AND sid = OLD.sid;
      SELECT seating_capacity INTO room_deleted_session FROM Rooms WHERE rid = room_id;
      UPDATE Offerings
        SET start_date = offering_start, end_date = offering_end
        WHERE course_id = OLD.course_id AND launch_date = OLD.launch_date;

      -- update seat capacity
      UPDATE Offerings
        SET seating_capacity =  seating_capacity - room_deleted_session
        WHERE course_id = OLD.course_id AND launch_date = OLD.launch_date;
      RETURN NULL;
    END IF;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS delete_sessions_trigger ON Sessions;

CREATE TRIGGER delete_sessions_trigger
BEFORE DELETE ON Sessions
FOR EACH ROW EXECUTE FUNCTION delete_sessions_func();
