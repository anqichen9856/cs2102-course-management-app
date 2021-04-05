/* Employee Triggers */

-- Employee can be either part time or full time
-- Use simultaneous insertion with transaction when inserting/updating Employees
CREATE OR REPLACE FUNCTION emp_covering_con_func() RETURNS TRIGGER 
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM Full_time_Emp FE WHERE FE.eid = NEW.eid
    ) AND NOT EXISTS (
        SELECT 1 FROM Part_time_Emp FE WHERE FE.eid = NEW.eid
    ) THEN
        RAISE EXCEPTION 'Employee % must be either full-time or part-time.', NEW.eid;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER emp_covering_con_trigger
AFTER INSERT OR UPDATE ON Employees
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION emp_covering_con_func();

-- Part time employee can only be instructor
CREATE OR REPLACE FUNCTION part_time_emp_covering_con_func() RETURNS TRIGGER 
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM Part_time_instructors PI WHERE PI.eid = NEW.eid
    ) THEN
        RAISE EXCEPTION 'Part-time employee % must be instructor.', NEW.eid;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER part_time_emp_covering_con_trigger
AFTER INSERT OR UPDATE ON Part_time_Emp
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION part_time_emp_covering_con_func();

-- Full time employee can be either administrator, manager or full-time instructor
CREATE OR REPLACE FUNCTION full_time_emp_covering_con_func() RETURNS TRIGGER 
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM Administrators A WHERE A.eid = NEW.eid
    ) AND NOT EXISTS (
        SELECT 1 FROM Managers M WHERE M.eid = NEW.eid
    ) AND NOT EXISTS (
        SELECT 1 FROM Full_time_instructors FI WHERE FI.eid = NEW.eid
    ) THEN
        RAISE EXCEPTION 'Full-time employee % must be either administrator or manager or instructor.', NEW.eid;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER full_time_emp_covering_con_trigger
AFTER INSERT OR UPDATE ON Full_time_Emp
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION full_time_emp_covering_con_func();

-- Instructors can be either full-time instructor or part-time instructor
CREATE OR REPLACE FUNCTION instructor_covering_con_func() RETURNS TRIGGER 
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM Full_time_instructors FI WHERE FI.eid = NEW.eid
    ) AND NOT EXISTS (
        SELECT 1 FROM Part_time_instructors PI WHERE PI.eid = NEW.eid
    ) THEN
        RAISE EXCEPTION 'Instructor % must be either full-time or part-time instructor.', NEW.eid;
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
    IF NOT EXISTS (
        SELECT 1 FROM Owns O WHERE O.cust_id = NEW.cust_id
    ) THEN
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
    IF NOT EXISTS (
        SELECT 1 FROM Owns O WHERE O.card_number = NEW.number
    ) THEN
        RAISE EXCEPTION 'Credit card % must be owned by a customer.', NEW.number;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER credit_card_owns_total_part_con_trigger
AFTER INSERT OR UPDATE ON Credit_cards
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION credit_card_owns_total_part_con_func();

/* Specializes trigger */

-- TPC for instructors: every instructor must specialize in at least one area
CREATE OR REPLACE FUNCTION instructor_specializes_total_part_con_func() RETURNS TRIGGER 
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM Specializes S WHERE S.eid = NEW.eid
    ) THEN
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


CREATE OR REPLACE FUNCTION buy_package_func() RETURNS TRIGGER
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Buys B WHERE B.package_id = NEW.package_id AND B.card_number = NEW.card_number AND B.date = NEW.date) THEN
        RAISE EXCEPTION 'Mutiple purchases of the same package % by card % on the same day % is not allowed', NEW.package_id , NEW.card_number, NEW.date;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Owns O WHERE O.card_number = NEW.card_number) THEN
        RAISE EXCEPTION 'Card number % is invalid', NEW.card_number;
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
BEFORE INSERT OR UPDATE ON Buys
FOR EACH ROW EXECUTE FUNCTION buy_package_func();
