-- Test cases for routines

/* ad hoc test */
DO language plpgsql $$
BEGIN
  RAISE NOTICE 'hello, world!';
END
$$;

/* transient table */
(VALUES (row), (row))

-- 1
-- Full-time, admin, course area = 0
CALL add_employee ('Jasmine Ang', '12 Kent Ridge Drive', '(+65) 90176780', 'jasmine@gmail.com', 'monthly', '1200', '2021-03-31', 'administrator', '{}');
-- Full-time instructor, course area >= 1
CALL add_employee ('Richard Xiong', '12 Kent Ridge Drive', '(+65) 90176780', 'rx@gmail.com', 'monthly', '3000', '2021-03-31', 'instructor', '{"Computer Science"}');
-- Part-time instructor, course area >= 1
CALL add_employee ('Joyce Chua', '12 Kent Ridge Drive', '(+65) 90176780', 'joyce@gmail.com', 'hourly', '50.90', '2021-03-20', 'instructor', '{"Social Sciences", "Law"}');
-- Full-time manager, course area >= 0
CALL add_employee ('Wang Qian', '12 Kent Ridge Drive', '(+65) 90176780', 'qiannnnw@gmail.com', 'monthly', '2400', '2021-03-20', 'manager', '{"Law"}');
-- Full-time manager, course area >= 0
CALL add_employee ('Bryan Wang', '12 Kent Ridge Drive', '(+65) 90176780', 'bryanwang@gmail.com', 'monthly', '2400', '2021-03-20', 'manager', '{}');

-- 2
CALL remove_employee (3, '2021-02-29');
CALL remove_employee (21, CURRENT_DATE);

-- 3
CALL add_customer ('Chen Anqi', '3 Jurong East Street 32', '(+65) 90174780', 'anqichen@gmail.com', 'A0188533W1234', '2023-02-20', 886);

-- 4
CALL update_credit_card (11, 'A0188533119W0117', '2026-09-27', 901);

-- 5
CALL add_course ('Wireless Networking', 'This module aims to provide solid foundation for students in the area of wireless networks and introduces students to the emerging area of cyber-physical-system/Internet-of-Things.',
'Networking', 2.5);

-- 6
-- Database Systems: course=1, instructor=1,20
-- Artificial Intelligence: course=2,3,11, instructor=3,21
-- Software Engineering: course=10, instructor=15,17
SELECT * FROM find_instructors (1, '2021-03-31', 9);
SELECT * FROM find_instructors (2, '2021-03-31', 10);
SELECT * FROM find_instructors (3, '2021-03-31', 14);
SELECT * FROM find_instructors (10, '2021-03-31', 15);
SELECT * FROM find_instructors (11, '2021-03-31', 16);

-- 7
-- 2 instructors both free whole day
SELECT * FROM get_available_instructors(10, '2021-05-01', '2021-05-09');
-- 1 part time instructor exceeding 30h of teaching & the other have lessons
SELECT * FROM get_available_instructors(10, '2021-04-25', '2021-04-28');
-- not available before and after 1h
SELECT * FROM get_available_instructors(5, '2021-02-03', '2021-02-03');
-- instructor departed
SELECT * FROM get_available_instructors(5, '2021-04-06', '2021-04-06');

-- 8
SELECT * FROM Sessions;
-- no lesson on that day, all rooms free
SELECT * FROM find_rooms('2021-04-14', 9, 2);
-- several lessons on that day
SELECT * FROM find_rooms('2021-04-09', 14, 3);
SELECT * FROM Sessions WHERE DATE = '2021-04-09';
-- date not valid
SELECT * FROM find_rooms('2021-04-10', 14, 3);
-- time not valid
SELECT * FROM find_rooms('2021-04-9', 17, 2);

-- 9
-- 04-08 all available, 04-09 3,16,20,21 not avaialble 
SELECT * FROM get_available_rooms('2021-04-08', '2021-04-09');
-- skip weekends
SELECT * FROM get_available_rooms('2021-04-09', '2021-04-10');

-- 10
-- successul insertion
CALL add_course_offering(10, 10, DATE '2021-06-01', '2021-06-20', 2, 10, '{{"2021-07-01", "14", "21"}, {"2021-07-02", "14", "21"}}');
SELECT * FROM Offerings;
SELECT * FROM Sessions WHERE cid = 10 AND launch_date = '2021-06-01';
-- check by schema: registration ddl
CALL add_course_offering(10, 10, DATE '2021-06-02', '2021-07-01', 2, 10, '{{"2021-07-05", "14", "21"}, {"2021-07-06", "14", "21"}}');
-- sessions over weekends
CALL add_course_offering(10, 10, DATE '2021-06-02', '2021-07-01', 2, 10, '{{"2021-07-04", "14", "21"}, {"2021-07-06", "14", "21"}}');
-- check by routine: seating capacity 
CALL add_course_offering(10, 10, DATE '2021-06-02', '2021-06-20', 3, 10, '{{"2021-07-05", "14", "21"}, {"2021-07-06", "14", "21"}}');
-- check by trigger: room, instructor availablility, overlap of sessions
-- to be demoed by add_session

-- 11
CALL add_course_package('Cheapest package', 1, '2021-05-01', '2021-05-03', 10);
SELECT * FROM Course_packages;
-- unique entry
CALL add_course_package('Cheapest package', 1, '2021-05-01', '2021-05-03', 10);
-- start date > curr date
CALL add_course_package('Another Cheapest package', 1, '2021-01-04', '2021-05-03', 10);

--12
-- performed after 11. the newly added package is not available yet.
SELECT * FROM Course_packages;
SELECT * FROM get_available_course_packages();

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
-- successful:
CALL update_course_session (12, 10, '2021-03-01', 9);
CALL update_course_session (12, 10, '2021-03-01', 8);

-- test 20

CALL cancel_registration (12, 10, '2021-03-01');

-- test 21
-- successful:
-- need some instructor teaches same area
-- CALL update_instructor (10, '2021-03-01', 8, new_eid INTEGER);

-- test 22
-- successful:
CALL update_room (10, '2021-03-01', 8, 16);
CALL update_room (10, '2021-03-01', 10, 20);
CALL update_room (10, '2021-03-01', 10, 19);


-- test 23
-- successful:
CALL remove_session (10, '2021-03-01', 9);
CALL remove_session (10, '2021-03-01', 7);
CALL remove_session (10, '2021-03-01', 6);


-- test 24
-- successful:
CALL add_session (11, '2021-05-01', 2, '2021-09-06', 9.0, 3, 1);
CALL add_session (11, '2021-05-01', 3, '2021-09-07', 9.0, 3, 1);
CALL add_session (11, '2021-05-01', 4, '2021-09-08', 9.0, 3, 1);
CALL add_session (11, '2021-05-01', 5, '2021-09-09', 9.0, 3, 1);

-- 25
-- DELETE FROM Pay_slips;
SELECT * FROM pay_salary();

-- 26
SELECT * FROM promote_courses();

-- 27
SELECT * FROM Course_packages;
SELECT * FROM top_packages(1);
SELECT * FROM top_packages(2);
SELECT * FROM top_packages(3);
SELECT * FROM top_packages(4);
SELECT * FROM top_packages(5);


-- 28
SELECT * FROM popular_courses();

-- 29
SELECT * FROM view_summary_report(20);

-- 30
SELECT * FROM view_manager_report();
