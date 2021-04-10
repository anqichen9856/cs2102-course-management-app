-- Test cases for routines

-- 13
-- Case 1: unable to buy package 2 because customer 1 has an active package
CALL buy_course_package(1, 2);
-- Case 2: unable to buy package 2 because customer 11 has a partially acitve package
CALL buy_course_package(11, 2);
-- Case 3: package 1 is not open to sale
CALL buy_course_package(11, 1);
-- Case 4: customer 12 successfully buys package 2
CALL buy_course_package(11, 2);
SELECT * FROM Buys;

-- 14
SELECT * FROM get_my_course_package(5);
-- to check correctness of json result
-- SELECT * FROM Buys;
-- SELECT * FROM Redeems;
-- SELECT * FROM Cancels;

-- 15
-- By default, three course offerings are returned.
SELECT * FROM get_available_course_offerings();

-- 16
-- Case 1: registration deadline is passed
SELECT * FROM get_available_course_sessions(1, '2020-09-01');
-- Case 2: by default, three sessions of course 7 are returned.
SELECT * FROM get_available_course_sessions(7, '2021-03-30');

-- 17
-- Case 1: register SUCCESS
CALL register_session(1, 7, '2021-03-30', 1, 0); 
SELECT * FROM Registers;
-- Case 2: redeem SUCCESS
CALL register_session(3, 7, '2021-03-30', 1, 1); 
SELECT * FROM Redeems;

-- 18
SELECT * FROM get_my_registrations(1);


-- test 19
-- CALL update_course_session (12, 10, '2021-03-01', 9);
-- CALL update_course_session (12, 10, '2021-03-01', 8);

-- test 20
-- CALL cancel_registration (12, 10, '2021-03-01');

-- test 21
-- need some instructor teaches same area
-- CALL update_instructor (10, '2021-03-01', 8, new_eid INTEGER);

-- test 22
-- CALL update_room (10, '2021-03-01', 8, 16);
-- CALL update_room (10, '2021-03-01', 10, 20);
-- CALL update_room (10, '2021-03-01', 10, 19);


-- test 23
-- CALL remove_session (10, '2021-03-01', 9);
-- CALL remove_session (10, '2021-03-01', 7);
-- CALL remove_session (10, '2021-03-01', 6);


-- test 24
-- CALL add_session (11, '2021-05-01', 2, '2021-09-06', 9.0, 3, 1);
-- CALL add_session (11, '2021-05-01', 3, '2021-09-07', 9.0, 3, 1);
-- CALL add_session (11, '2021-05-01', 4, '2021-09-08', 9.0, 3, 1);
-- CALL add_session (11, '2021-05-01', 5, '2021-09-09', 9.0, 3, 1);


-- 29 
SELECT * FROM view_summary_report(20);



