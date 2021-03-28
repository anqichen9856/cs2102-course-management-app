-- 19. update_course_session: This routine is used when a customer requests to
-- change a registered course session to another session.
-- The inputs to the routine include the following:
-- customer identifier,
-- course offering identifier, and
-- new session number.
-- If the update request is valid and there is an available seat in the new session,
-- the routine will process the request with the necessary updates.


-- delete old regestration
-- find_rooms
-- get_available_course_sessions
-- a customer can register for at most one of its sessions before its registration deadline.

CREATE OR REPLACE FUNCTION Sessions_func() RETURNS TRIGGER
AS $$
BEGIN
-- check if the update us valid
-- 1. if the instructor exist
-- 2. an instructor who is assigned to teach a course session must be specialized in that course area.
-- 3. instructor can teach at most one course session at any hour.
-- 4. Each instructor must not be assigned to teach two consecutive course sessions;
-- (i.e., there must be at least one hour of break between any two course sessions that the instructor is teaching.)
-- 5. Each part-time instructor must not teach more than 30 hours for each month.

  -- update Registers
  UPDATE Registers
    SET sid = NEW.sid WHERE sid = ;
    -- update Redeems
  UPDATE INTO
    VALUES ();

  IF THEN

  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER Sessions_trigger
AFTER UPDATE OR INSERT ON Sessions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION Sessions_func();


CREATE OR REPLACE FUNCTION delete_session_func() RETURNS TRIGGER
AS $$
BEGIN
  DELETE FROM Redeems WHERE ;
  DELETE FROM Registers WHERE ;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER TRIGGER delete_session_trigger
AFTER DELETE ON Sessions
FOR EACH ROW EXECUTE FUNCTION delete_session_func();


CREATE OR REPLACE PROCEDURE update_course_session (cust_id INTEGER, course_id INTEGER, new_sid INTEGER)
RETURNS RECORD AS $$
BEGIN
  -- check if the new session is available
  IF new_sid IN (get_available_course_sessions(course_id)) THEN
    -- delete the old session
    DELETE FROM Sessions WHERE
    -- insert the new session
    INSERT INTO Sessions VALUES ();
  END IF;
END;
$$ LANGUAGE sql;




-- 20. cancel_registration: This routine is used when a customer requests to cancel
-- a registered course session.
-- The inputs to the routine include the following:
-- customer identifier, and course offering identifier.
-- If the cancellation request is valid, the routine will process the request with
-- the necessary updates.

CREATE OR REPLACE FUNCTION cancel_registration (IN cust_id, IN course_id)
RETURNS RECORD AS $$

DECLARE


BEGIN


-- If the cancellation request is valid(at least 7 days before the day of the registered session)
-- Registers/ Cancels

END;

$$ LANGUAGE sql;




-- 21. update_instructor: This routine is used to change the instructor for a course
-- session. The inputs to the routine include the following: course offering identifier,
-- session number, and identifier of the new instructor.
-- If the course session has not yet started and the update request is valid,
-- the routine will process the request with the necessary updates.

CREATE OR REPLACE PROCEDURE update_instructor (course_id INTEGER, sid INTEGER, new_eid INTEGER)
RETURNS RECORD AS $$

DECLARE

BEGIN


END;
$$ LANGUAGE sql;







-- 22. update_room: This routine is used to change the room for a course session. The
-- inputs to the routine include the following: course offering identifier, session
-- number, and identifier of the new room. If the course session has not yet started
-- and the update request is valid, the routine will process the request with the
-- necessary updates. Note that update request should not be performed if the number
-- of registrations for the session exceeds the seating capacity of the new room.


CREATE OR REPLACE PROCEDURE update_room (OUT output)
RETURNS RECORD AS $$

DECLARE


BEGIN


END;

$$ LANGUAGE sql;




----------------------------------------------------------------------------------------------
-- 23. remove_session: This routine is used to remove a course session. The inputs to
-- the routine include the following: course offering identifier and session number.
-- If the course session has not yet started and the request is valid, the routine
-- will process the request with the necessary updates. The request must not be
-- performed if there is at least one registration for the session. Note that the
-- resultant seating capacity of the course offering could fall below the course
-- offering’s target number of registrations, which is allowed.


CREATE OR REPLACE PROCEDURE remove_session (OUT output)
RETURNS RECORD AS $$

DECLARE


BEGIN


END;

$$ LANGUAGE sql;



-- 24. add_session: This routine is used to add a new session to a course offering. The
-- inputs to the routine include the following: course offering identifier, new
-- session number, new session day, new session start hour, instructor identifier
-- for new session, and room identifier for new session. If the course offering’s
-- registration deadline has not passed and the the addition request is valid, the
-- routine will process the request with the necessary updates.

CREATE OR REPLACE PROCEDURE add_session (OUT output)
RETURNS RECORD AS $$

DECLARE


BEGIN


END;

$$ LANGUAGE sql;
