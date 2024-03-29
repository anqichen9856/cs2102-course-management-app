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
select * from employees
select * from administrators
select * from managers
select * from full_time_instructors
select * from part_time_instructors
select * from specializes
select * from course_areas
-- Full-time, admin, course area = 0
CALL add_employee ('Jasmine Ang', '12 Kent Ridge Drive', '(+65) 90176780', 'jasmine@gmail.com', 'monthly', '1200', '2021-03-31', 'administrator', '{}');
-- Full-time instructor, course area >= 1
CALL add_employee ('Richard Xiong', '12 Kent Ridge Drive', '(+65) 90176780', 'rx@gmail.com', 'monthly', '3000', '2021-03-31', 'instructor', '{"Parallel Computing"}');
-- Part-time instructor, course area >= 1
CALL add_employee ('Joyce Chua', '12 Kent Ridge Drive', '(+65) 90176780', 'joyce@gmail.com', 'hourly', '50.90', '2021-03-20', 'instructor', '{"Computer Security", "Algorithms & Theory"}');
-- Full-time manager, course area >= 0
CALL add_employee ('Wang Qian', '12 Kent Ridge Drive', '(+65) 90176780', 'qiannnnw@gmail.com', 'monthly', '2400', '2021-03-20', 'manager', '{"Artificial Intelligence"}');
-- Full-time manager, course area >= 0
CALL add_employee ('Bryan Wang', '12 Kent Ridge Drive', '(+65) 90176780', 'bryanwang@gmail.com', 'monthly', '2400', '2021-03-20', 'manager', '{}');

-- 2
select * from sessions where eid = 3
select * from employees
select * from instructors
CALL remove_employee (3, '2021-02-28');
CALL remove_employee (21, CURRENT_DATE);

-- 3
select * from customers
select * from credit_cards
select * from owns
CALL add_customer ('Chen Anqi', '3 Jurong East Street 32', '(+65) 90174780', 'anqichen@gmail.com', 'A0188533W1234', '2023-02-20', 886);

-- 4
select * from owns where cust_id=11
select * from credit_cards
CALL update_credit_card (11, 'A0188533119W0117', '2026-09-27', 901);

-- 5
select * from courses
CALL add_course ('Wireless Networking', 'This module aims to provide solid foundation for students in the area of wireless networks and introduces students to the emerging area of cyber-physical-system/Internet-of-Things.',
'Networking', 2.5);

-- 6
-- Database Systems: course=1, instructor=1,20
-- Artificial Intelligence: course=3,11, instructor=3,21
-- Software Engineering: course=10, instructor=15,17

select * from courses where course_area = 'Database Systems'
select * from specializes where area = 'Database Systems'
SELECT * FROM find_instructors (1, '2021-03-31', 9);

select * from courses where course_area = 'Artificial Intelligence'
select * from specializes where area = 'Artificial Intelligence'
select * from sessions where eid = 3
-- instructor 3 has another session
SELECT * FROM find_instructors (3, '2021-04-09', 14);
SELECT * FROM find_instructors (11, '2021-04-09', 9);

select * from courses where course_id = 10
-- 15+4=19 over time
SELECT * FROM find_instructors (10, '2021-03-31', 15);

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
CALL buy_course_package(12, 2);
-- Case 3: package 1 is not open to sale
CALL buy_course_package(11, 1);
-- Case 4: customer 12 successfully buys package 2
CALL buy_course_package(11, 2);
SELECT * FROM Buys;
-- CALL buy_course_package(1,1);
-- SELECT * FROM Buys


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
-- the customer not register or redeem any session or canceled
-- CALL cancel_registration (2, 10, '2021-03-01');
-- Cancellation will be proceed, but the number of remaining redemptions in your package cannot be added back
-- CALL cancel_registration (5, 10, '2021-03-01');

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
CALL update_course_session (12, 10, '2021-03-01', 9);
CALL update_course_session (12, 10, '2021-03-01', 8);
-- session is not avaliable:
-- CALL update_course_session (12, 10, '2021-03-01', 100);
-- this customer is not exist
-- CALL update_course_session (120, 10, '2021-03-01', 8);
-- the custommer does not have a registerd session for this course
-- CALL update_course_session (1, 10, '2021-03-01', 8);
-- no seat in new session
-- CALL update_course_session (12, 10, '2021-03-01', 5);



-- test 20
CALL cancel_registration (12, 10, '2021-03-01');
case Session started:
CALL cancel_registration (11, 10, '2021-03-01');
-- the customer not register or redeem any session or canceled
-- CALL cancel_registration (2, 10, '2021-03-01');
-- Cancellation will be proceed, but the number of remaining redemptions in your package cannot be added back
-- CALL cancel_registration (5, 10, '2021-03-01');
-- Session started
-- CALL cancel_registration (1, 5, '2021-03-10');

-- test 21
CALL update_instructor (11, '2021-05-01', 1, 21);
CALL update_instructor (11, '2021-05-01', 2, 21);
-- Session information not valid.
-- CALL update_instructor (111, '2021-05-01', 1 , 21);
-- new_eid is not valid
-- CALL update_instructor (10, '2021-03-01', 8 , 211);


-- test 22
CALL update_room (10, '2021-03-01', 8, 16);
CALL update_room (10, '2021-03-01', 10, 20);
CALL update_room (10, '2021-03-01', 10, 19);
-- the room is not available
-- CALL update_room (10, '2021-03-01', 10, 190);
-- Session information not valid.
-- CALL update_room (100, '2021-03-01', 10, 20);
-- session started
-- CALL update_room (10, '2021-03-01', 1, 20);


-- test 23
CALL remove_session (10, '2021-03-01', 9);
CALL remove_session (10, '2021-03-01', 7);
CALL remove_session (10, '2021-03-01', 6);
-- Session not exists
-- CALL remove_session (10, '2021-03-01', 6);



-- test 24
CALL add_session (11, '2021-05-01', 2, '2021-09-06', 9.0, 3, 1);
CALL add_session (11, '2021-05-01', 3, '2021-09-07', 9.0, 3, 1);
CALL add_session (11, '2021-05-01', 4, '2021-09-08', 9.0, 3, 1);
CALL add_session (11, '2021-05-01', 5, '2021-09-09', 9.0, 3, 1);
-- session overlap:
-- CALL add_session (3, '2021-04-30', 2, '2021-06-22', 15, 21, 1);
-- course offering does not exist, unable to add session
-- CALL add_session (110, '2021-05-01', 5, '2021-09-09', 9.0, 3, 1);



-- 25
delete from pay_slips where EXTRACT(MONTH FROM payment_date) = 4;
SELECT * FROM pay_salary() order by status;

select * from pay_slips
-- dio brando not full: 6/30*470=94
select * from employees where eid = 2
select * from employees where eid = 21
-- eid 15 worked 28 hours
select sum(end_time - start_time) from sessions where eid=15 and EXTRACT(MONTH FROM date) = 4


-- 26
SELECT * FROM promote_courses();
select cust_id from customers except SELECT cust_id FROM promote_courses() order by cust_id
-- active customers: 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 21
WITH Reg AS (
    (select cust_id, date from Customers NATURAL JOIN Owns NATURAL JOIN Registers)
    UNION
    (select cust_id, date from Customers NATURAL JOIN Owns NATURAL JOIN Redeems)
)
select distinct cust_id from Reg where date >= '2020-10-01' order by cust_id

-- open offerings
select * from offerings where registration_deadline >= CURRENT_DATE

-- Cho Chang (15) has some interest area: register before 6 months
-- prev 6 months: 2020-10 to 2021-04
select cust_id, course_area, date from Customers NATURAL JOIN Owns NATURAL JOIN Registers NATURAL JOIN Courses where cust_id = 15


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
