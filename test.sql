-- Test cases for routines

-- 13
-- Case 1: unable to buy package 2 because customer 1 has an active package
CALL buy_course_package(1,2);
-- Case 2: unable to buy package 2 because customer 11 has a partially acitve package
CALL buy_course_package(11, 2);
--Case 3: customer 12 successfully buys package 2
CALL buy_course_package(11, 2);
SELECT * FROM Buys;

--14
SELECT FROM 

