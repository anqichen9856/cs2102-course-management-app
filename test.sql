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

-- 25
delete from pay_slips where EXTRACT(MONTH FROM payment_date) = 4;
SELECT * FROM pay_salary() order by status;

select * from pay_slips
-- dio brando not full: 6/30*470=94
select * from employees where eid = 2
select * from employees where eid = 21
-- 28 hours for eid 15
select sum(end_time - start_time) from sessions where eid=15 and EXTRACT(MONTH FROM date) = 4

-- 26
SELECT * FROM promote_courses();
select cust_id from customers except SELECT cust_id FROM promote_courses() order by cust_id
-- active customers
-- 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 21
WITH Reg AS (
    (select cust_id, date from Customers NATURAL JOIN Owns NATURAL JOIN Registers)
    UNION
    (select cust_id, date from Customers NATURAL JOIN Owns NATURAL JOIN Redeems)
)
select distinct cust_id from Reg where date >= '2020-10-01' order by cust_id 

-- open offerings
select * from offerings where registration_deadline >= CURRENT_DATE

-- 15 Cho Chang has some interest area: register before 6 months 
-- 6 months: 2020-10 to 2021-04
select cust_id, course_area, date from Customers NATURAL JOIN Owns NATURAL JOIN Registers NATURAL JOIN Courses where cust_id = 15


-- 29 
SELECT * FROM view_summary_report(20);




