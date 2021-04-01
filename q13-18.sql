--13
CREATE OR REPLACE PROCEDURE buy_course_package (cust_id INT,package_id INT)
AS $$
DECLARE
n INTEGER;
BEGIN            
IF EXISTS (SELECT 1 FROM Owns O WHERE O.cust_id == cust_id 
     AND EXISTS (SELECT 1 FROM Credit_cards C WHERE 
        C.number = O.card_number AND 
        C.expiry_date >= CURRENT_DATE)) THEN 
INSERT (SELECT num_free_registrations FROM Course_packages P WHERE P.package_id = package_id) INTO n;              
INSERT INTO Buys VALUES (package_id, card_number, CURRENT_DATE, n);
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
(seating_capacity-count_registers-count_redeems) AS num_remaining_seats               
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
SELECT session_date, start_time, instructor_name, (seating_capacity-count_registers-count_redeems) AS num_remaining_seats
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
                                
                 
--17either update Registers or Redeems                 
CREATE OR REPLACE FUNCTION register_session(cust_id INT, course_id, session_number, and payment method (credit card or redemption from active package))
AS $$               
$$ LANGUAGE plpgsql;

--18 search through registers and redeems 
CREATE OR REPLACE FUNCTION get_my_registrations(cust_id INT)
RETURNS TABLE(title TEXT, fees, session_date DATE, start_time TIME, duration TIME, instructor_name TEXT) 
AS $$
--check date 
WITH date_checked AS (
  SELECT title, fees, session_date, start_time, duration , instructor_name 
  FROM 
  WHERE
)
--check ifCanceled 
SELECT title, fees, session_date, start_time, duration , instructor_name 
FROM 
WHERE  
ORDER BY session_date, start_time                                                                                                      
$$ LANGUAGE plpgsql;
