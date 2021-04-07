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
SELECT title, course_area, start_date, end_date, registration_deadline, fees, (seating_capacity - count_registers - count_redeems + count_cancels) AS num_remaining_seats               
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
--TEST select * from get_available_course_offerings() RESULT 1 row 

--16                
CREATE OR REPLACE FUNCTION get_available_course_sessions(courseId INT, launchDate DATE)
RETURNS TABLE(session_date DATE, start_time NUMERIC, instructor_name TEXT, num_remaining_seats INTEGER) 
AS $$
BEGIN
IF NOT EXISTS (SELECT 1 FROM Offerings WHERE course_id = courseId AND launch_date = launchDate) THEN
RAISE EXCEPTION 'Course Offering of % launched on % is invalid', courseId, launchDate;
END IF;
IF NOT EXISTS (SELECT 1 FROM Offerings WHERE course_id = courseId AND launch_date = launchDate AND registration_deadline >= CURRENT_DATE) THEN
RAISE EXCEPTION 'Registration deadline for course Offering of % launched on % is passed', courseId, launchDate; 
END IF;
SELECT session_date, start_time, instructor_name, (seating_capacity - count_registers - count_redeems + count_cancels) AS num_remaining_seats
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
WHERE count_registers + count_redeems - count_cancels < seating_capacity 
ORDER BY session_date, start_time;
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
--call register_session(1, 7, '2021-03-30', 1, 0); select * from registers; 


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
)
SELECT V.month, V.year, COALESCE(salary_sum, 0), COALESCE(packages_count, 0), COALESCE(fees_sum, 0), COALESCE(refund_sum, 0), COALESCE(redeems_count, 0)
FROM ViewedMonths V NATURAL LEFT OUTER JOIN salaries NATURAL LEFT OUTER JOIN sold_packages NATURAL LEFT OUTER JOIN paid_fees NATURAL LEFT OUTER JOIN refunded_fees NATURAL LEFT OUTER JOIN redemptions
ORDER BY V.year DESC;
DROP TABLE ViewedMonths;
END;
$$ LANGUAGE plpgsql;
--TEST SELECT * FROM view_summary_report(10)

