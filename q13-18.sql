--13
CREATE OR REPLACE PROCEDURE buy_course_package (cust_id INT,package_id INT)
AS $$
DECLARE
n INTEGER;
BEGIN            
IF EXISTS (SELECT 1 FROM Owns O WHERE O.cust_id == cust_id 
      AND EXISTS (SELECT 1 FROM Credit_cards C WHERE 
        C.number = O.card_number AND 
        C.expiry_date >= CURRENT_DATE)
      AND EXISTS (SELECT 1 FROM Course_packages P WHERE 
        P.package_id = package_id AND P.sale_start_date <= CURRENT_DATE
        P.sale_end_date >= CURRENT_DATE)) THEN 
INSERT (SELECT num_free_registrations FROM Course_packages P WHERE P.package_id = package_id) INTO n;              
INSERT INTO Buys VALUES (package_id, card_number, CURRENT_DATE, n);
ELSE
RAISE NOTICE 'The purchase for package % by customer % is not valid', package_id, cust_id;
END IF;
END;                
$$ LANGUAGE plpgsql;

--14 create json file 
CREATE OR REPLACE FUNCTION get_my_course_package (cust_id INT)
RETURNS json AS $$
SELECT row_to_json(row)
FROM (
  
) row；
 retailerid,retailername into jrow from myview;
return row_to_json(jrow);
              
$$ LANGUAGE plpgsql;    
                 
--15 retrieve all the available course offerings that could be ----registered.                  
CREATE OR REPLACE FUNCTION get_available_course_offerings()
RETURNS TABLE(title TEXT, course_area TEXT, start_date DATE, end_date DATE, registration_deadline DATE, fees NUMERIC, num_remaining_seats INT) 
AS $$
SELECT title, course_area, start_date, end_date, registration_deadline, fees, 
(seating_capacity - count_registers-count_redeems) AS num_remaining_seats               
FROM (
  SELECT title, course_area, start_date, end_date, registration_deadline, fees, seating_capacity
  , COALESCE (count1, 0) AS count_registers
  , COALESCE (count2, 0) AS count_redeems
  FROM Courses
  NATURAL JOIN Offerings
  NATURAL LEFT OUTER JOIN(SELECT course_id, launch_date, count(*) AS count1 FROM Registers GROUP BY course_id, launch_date)
  NATURAL LEFT OUTER JOIN(SELECT course_id, launch_date, count(*) AS count2 FROM Redeems GROUP BY course_id, launch_date)
  )
WHERE registration_deadline >= CURRENT_DATE AND (count_registers+ count_redeems)< seating_capacity  
ORDER BY registration_deadline, title;                 
                          
$$ LANGUAGE plpgsql;                 
                 
--16                
CREATE OR REPLACE FUNCTION get_available_course_sessions(courseId INT, launchDate DATE)
RETURNS TABLE(session_date DATE, start_time TIME, instructor_name TEXT, num_remaining_seats INTEGER) 
AS $$      
SELECT session_date, start_time, instructor_name, (seating_capacity - count_registers - count_redeems) AS num_remaining_seats
FROM ( 
  SELECT session_date DATE, start_time TIME, instructor_name TEXT, seating_capacity INTEGER
  , COALESCE (count1, 0) AS count_registers
  , COALESCE (count2, 0) AS count_redeems
  FROM Sessions
  NATURAL JOIN Rooms                 
  NATURAL LEFT OUTER JOIN (
    SELECT course_id, launch_date, sid, count(*) AS count1 
    FROM Registers 
    GROUP BY course_id, launch_date, sid
    )
  NATURAL LEFT OUTER JOIN (
    SELECT course_id, launch_date, sid, count(*) AS count2 
    FROM Redeems 
    GROUP BY course_id, launch_date, sid
    )
  WHERE course_id = courseId AND launch_date = launchDate
)                                                                   
WHERE count_registers+count_redeems < seating_capacity
ORDER BY session_date, start_time;  
$$ LANGUAGE plpgsql; 
                                
                 
--17either update Registers or Redeems--check if available session--check if payment is correct         
--(0 for credit card or 1 for redemption from active package)       
CREATE OR REPLACE FUNCTION register_session(custId INT, courseId INT, launchDate DATE sessionNumber INT, paymentMethod INT)
AS $$
DECLARE
count_redeems INT;
count_registers INT;
count_cancels INT;
count_registration INT;
capacity INT;
redeemRemaining INT;
packageId INT;
cardNumber TEXT;
buyDate DATE;
BEGIN

IF NOT EXISTS (SELECT 1 FROM Customers WHERE Customers.cust_id = custId) THEN
RAISE EXCEPTION 'Customer ID % is not valid', custId;
END IF;

IF NOT EXISTS (SELECT 1 FROM Offerings WHERE course_id = courseId AND launch_date = launchDate) THEN
RAISE EXCEPTION 'Course Offering of % launched on % is not valid', courseId, launchDate;
END IF;

IF NOT EXISTS (SELECT 1 FROM Offerings WHERE course_id = courseId AND launch_date = launchDate AND registration_deadline >= CURRENT_DATE) THEN
RAISE EXCEPTION 'Registration deadline is passed'
END IF;

IF payment_method != 0 AND payment_method != 1 THEN
RAISE EXCEPTION 'Payment method must be either INTEGER 0 or 1, which represent using credit card or redemption from active package respectively.';
END IF;  

SELECT count(*) INTO count_redeems
FROM (
    SELECT * 
    FROM Redeems R 
    WHERE R.course_id = courseId AND R.launch_date = launchDate AND R.sid = sessionNumber
);
SELECT count(*) INTO count_registers
FROM (
    SELECT *
    FROM Registers R 
    WHERE R.course_id = courseId AND R.launch_date = launchDate AND R.sid = sessionNumber
);
SELECT count(*) INTO count_cancels
FROM (
    SELECT *
    FROM Cancels C
    WHERE C.course_id = courseId AND C.launch_date = launchDate AND C.sid = sessionNumber
);
count_registration := count_redeems + count_registers - count_cancels;

SELECT seating_capacity INTO capacity
FROM Rooms 
WHERE Rooms.rid = (SELECT rid FROM Sessions S WHERE S.course_id = courseId AND S.launch_date = launchDate AND S.sid = sessionNumber);

IF capacity <= count_registration THEN
RAISE EXCEPTION 'The session % of course offering of % launched % is fully booked', sessionNumber, courseId, launchDate;
END IF;

--start check payment method
IF payment_method = 1 THEN 

--start inner if
IF NOT EXISTS (
  SELECT 1
  FROM Buys B
  WHERE B.cust_id = custId AND EXISTS (SELECT 1 FROM Owns O WHERE O.cust_id = custId AND O.card_number = B.card_number )  
  AND B.num_remaining_redemptions > 0;
) THEN
RAISE EXCEPTION 'There is no active package, so the session cannot be redeemed';
ELSE 
  SELECT max(B.num_remaining_redemptions) AS remaining, B.package_id, B.card_number, B.date INTO (redeemRemaining, packageId, cardNumber, buyDate)
  FROM Buys B
  WHERE B.cust_id = custId AND EXISTS (SELECT 1 FROM Owns O WHERE O.cust_id = custId AND O.card_number = B.card_number)
  AND B.num_remaining_redemptions > 0;
  redeemRemaining := redeemRemaining - 1;
  UPDATE Buys SET num_remaining_redemptions = num_remaining_redemptions - 1 WHERE package_id = packageId AND card_number = cardNumber AND date = buyDate;
  INSERT INTO Redeems VALUES(packageId, cardNumber, buyDate, courseId, launchDate, sessionNumber, CURRENT_DATE);
  RAISE NOTICE 'The session successfully redeemed with package %', packageId;
END IF;
--end inner if

ELSE 

--start inner if
IF NOT EXISTS (
  SELECT 1 
  FROM Owns O
  WHERE O.cust_id = custId AND EXISTS (SELECT 1 FROM Credit_cards C WHERE C.number = O.card_number AND C.expiry_date > CURRENT_DATE)
) THEN 
RAISE EXCEPTION 'The credit card is expired';
ELSE 
SELECT O.card_number INTO cardNumber 
FROM Owns O
WHERE O.cust_id = custId AND EXISTS (SELECT 1 FROM Credit_cards C WHERE C.number = O.card_number AND C.expiry_date > CURRENT_DATE);
INSERT INTO Registers VALUES(cardNumber, courseId, launchDate, sessionNumber, CURRENT_DATE);
RAISE NOTICE 'The session successfully bought by customer %', custId;
END IF;
--end inner if

END IF;
--end check payment method

END;
$$ LANGUAGE plpgsql;

--18 search through registers and redeems 
CREATE OR REPLACE FUNCTION get_my_registrations(custId INT)
RETURNS TABLE(course_title TEXT, fees NUMERIC, session_date DATE, start_time NUMERIC, duration NUMERIC, instructor_name TEXT) 
AS $$
DECLARE 
currentDate DATE;
currentHour NUMERIC;
currentMinute NUMERIC;
sessionDate DATE;
toHour NUMERIC;
BEGIN
currentDate := CURRENT_DATE;
currentHour := extract(HOUR FROM CURRENT_TIMESTAMP);
currentMinute := extract(MINUTE FROM CURRENT_TIMESTAMP);
currentSecond := extract(SECOND FROM CURRENT_TIMESTAMP);
toHour := currentHour + currentMinute/60 + currentSecond/3600;
--check ifCanceled 
WITH redeems_checked AS (
  SELECT *
  FROM Redeems R1
  WHERE R1.cust_id = custId 
  AND NOT EXISTS (
    SELECT 1
    FROM Cancels C1
    WHERE C1.cust_id = R1.cust_id AND C1.course_id = R1.course_id AND C1.launch_date = R1.launch_date AND C1.sid = R1.sid AND C1.date >= R1.date
  )
), registers_checked AS (
  SELECT *
  FROM Registers R2
  WHERE R2.cust_id = custId 
  AND NOT EXISTS (
    SELECT 1
    FROM Cancels C2
    WHERE C2.cust_id = R2.cust_id AND C2.course_id = R2.course_id AND C2.launch_date = R2.launch_date AND C2.sid = R2.sid AND C2.date >= R2.date
  )
), course_sessions AS (
  SELECT C.title AS course_title, O.fees, S.date AS session_date, S.start_time, C.duration, S.eid AS instructor_name, S.sid
  FROM Courses C, Offerings O, Sessions S
  WHERE C.course_id = O.course_id AND O.course_id = S.course_id AND O.launch_date = S.launch_date AND S.date >= currentDate
)
--check date 
SELECT S.course_title, S.fees, S.session_date, S.start_time, S.duration, S.instructor_name
FROM course_sessions S, redeems_checked R1, registers_checked R2
WHERE ((S.course_id = R1.course_id AND S.launch_date = R1.launch_date AND S1.sid = R1.sid)
OR (S.course_id = R2.course_id AND S.launch_date = R2.launch_date AND S.sid = R2.sid)) AND (S.date > currentDate OR ((S.start_time + S.duration)>toHour)
ORDER BY S.session_date, S.start_time;
END;
$$ LANGUAGE plpgsql;

