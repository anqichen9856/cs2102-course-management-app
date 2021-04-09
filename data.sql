/* For populating Pay_slips */
DROP PROCEDURE IF EXISTS pay_salary_for_month (DATE);
CREATE OR REPLACE PROCEDURE pay_salary_for_month (date DATE)
AS $$
DECLARE
    curs CURSOR FOR (
        SELECT X.eid, X.name, X.monthly_salary, X.hourly_rate, X.join_date, X.depart_date
        FROM (Employees NATURAL LEFT JOIN Full_time_Emp NATURAL LEFT JOIN Part_time_Emp) X
        WHERE X.depart_date IS NULL OR X.depart_date >= DATE_TRUNC('month', date)::DATE /* don't consider employees departed before this month */
    );
    r RECORD;
    num_work_days INTEGER; 
    num_work_hours NUMERIC; 
    amount NUMERIC;
    first_day_of_month DATE;
    last_day_of_month DATE;
    first_work_day DATE;
    last_work_day DATE;
BEGIN
    OPEN curs;
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;

        first_day_of_month := DATE_TRUNC('month', date)::DATE;
        last_day_of_month := (DATE_TRUNC('month', date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

        IF r.hourly_rate IS NULL THEN /* Full-time */
            IF r.join_date BETWEEN first_day_of_month AND last_day_of_month THEN
                first_work_day := r.join_date;
            ELSE
                first_work_day := first_day_of_month;
            END IF;

            IF r.depart_date BETWEEN first_day_of_month AND last_day_of_month THEN
                last_work_day := r.depart_date;
            ELSE
                last_work_day := last_day_of_month;
            END IF;

            num_work_days := last_work_day - first_work_day + 1;
            amount := TRUNC(monthly_salary * num_work_days / (last_day_of_month - first_day_of_month + 1), 2);
            INSERT INTO Pay_slips VALUES (r.eid, date, amount, NULL, num_work_days);

        ELSE  /* Part-time */
            SELECT COALESCE(SUM(end_time - start_time), 0) INTO num_work_hours FROM Sessions S
                WHERE S.eid = r.eid AND S.date BETWEEN first_day_of_month AND last_day_of_month;
            amount := TRUNC(hourly_rate * num_work_hours, 2);
            INSERT INTO Pay_slips VALUES (r.eid, date, amount, num_work_hours, NULL);
        END IF;
    END LOOP;
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;

--Employees
INSERT INTO Employees VALUES (1, 'Jonathan Joestar', 'abc@gmail.com', '(+65) 12345678', 'abc street', '2018-01-04', NULL);
INSERT INTO Employees VALUES (2, 'Dio Brando', 'qqq@gmail.com', '(+65) 12345679', 'bcd street ', '2018-01-01', '2021-04-06');
INSERT INTO Employees VALUES (3, 'Joseph Joestar', 'eee@gmail.com', '(+65) 12345680', 'def street', '2017-08-29', NULL);
INSERT INTO Employees VALUES (4, 'Lisa Lisa', 'ooo@gmail.com', '(+65) 12345681', 'xxx street', '2016-01-03', NULL);
INSERT INTO Employees VALUES (5, 'Alice Tan', 'hhh@gmail.com', '(+65) 12345682', 'yyy street', '2008-01-04', '2021-03-07');
INSERT INTO Employees VALUES (6, 'Charles Chen', 'halo@gmail.com', '(+65) 12345683', 'zzz street', '2019-01-05', NULL);
INSERT INTO Employees VALUES (7, 'David Sun', 'hallo@gmail.com', '(+65) 12345684', 'woe street', '2009-01-06', '2021-03-05');
INSERT INTO Employees VALUES (8, 'Frank Goh', 'hello@gmail.com', '(+65) 12345685', 'wow street', '2018-01-07', NULL);
INSERT INTO Employees VALUES (9, 'George Lim', 'bye@gmail.com', '(+65) 12345686', 'woohoo street', '2018-01-08', NULL);
INSERT INTO Employees VALUES (10, 'William Kin', 'byee@gmail.com', '(+65) 12345687', 'aha street', '2014-01-09', NULL);
INSERT INTO Employees VALUES (11, 'Emily Wang', 'yyqx@163.com', '(+86) 123456789', 'tf building level 18', '2018-07-16', NULL);
INSERT INTO Employees VALUES (12, 'Olivia Law', 'wjk@163.com', '(+86) 123456700', 'tf building level 18', '2018-09-11', NULL);
INSERT INTO Employees VALUES (13, 'Jean Haw', 'wy@163.com', '(+86) 88888888', 'tf building level 18', '2018-04-05', NULL);
INSERT INTO Employees VALUES (14, 'Alex Guo', 'mjq@qq.com', '(+86) 13955581324', 'tf building level 18', '2018-03-28', NULL);
INSERT INTO Employees VALUES (15, 'James Smith', 'hcy@outlook.com', '(+86) 123789456', 'tianyuchuanmei', '2019-03-14', NULL);
INSERT INTO Employees VALUES (16, 'Joel Hong', 'joelhong@gmail.com', '(+65) 90175679', 'hwa chong institution', '2017-09-30', NULL);
INSERT INTO Employees VALUES (17, 'Eve Brown', 'eve@gmail.com', '(+65) 90175689', 'raffles institution', '2018-12-01', NULL);
INSERT INTO Employees VALUES (18, 'Adam Yuan', 'ay@gmail.com', '(+65) 10102237', 'rvrc', '2018-04-01', NULL);
INSERT INTO Employees VALUES (19, 'Xavior Chu', 'xc@gmail.com', '(+65) 10102234', 'pgp', '2018-04-07', NULL);
INSERT INTO Employees VALUES (20, 'Peter Pan', 'peter@gmail.com', '(+65) 10102233', 'tembusu', '2018-02-03', '2021-04-09');

--Full_time_Emp
INSERT INTO Full_time_Emp VALUES (1, 10000);
INSERT INTO Full_time_Emp VALUES (2, 9000);
INSERT INTO Full_time_Emp VALUES (3, 8888);
INSERT INTO Full_time_Emp VALUES (4, 4000);
INSERT INTO Full_time_Emp VALUES (5, 5000);
INSERT INTO Full_time_Emp VALUES (6, 600);
INSERT INTO Full_time_Emp VALUES (7, 123456);
INSERT INTO Full_time_Emp VALUES (8, 987);
INSERT INTO Full_time_Emp VALUES (9, 100);
INSERT INTO Full_time_Emp VALUES (10, 1987);
INSERT INTO Full_time_Emp VALUES (17, 800);
INSERT INTO Full_time_Emp VALUES (18, 1250);
INSERT INTO Full_time_Emp VALUES (19, 1790);

--Part_time_Emp
INSERT INTO Part_time_Emp VALUES (11, 2000);
INSERT INTO Part_time_Emp VALUES (12, 80);
INSERT INTO Part_time_Emp VALUES (13, 120);
INSERT INTO Part_time_Emp VALUES (14, 70);
INSERT INTO Part_time_Emp VALUES (15, 99);
INSERT INTO Part_time_Emp VALUES (16, 86);
INSERT INTO Part_time_Emp VALUES (20, 90);

--Instructors
INSERT INTO Instructors VALUES (1);
INSERT INTO Instructors VALUES (2);
INSERT INTO Instructors VALUES (3);
INSERT INTO Instructors VALUES (4);
INSERT INTO Instructors VALUES (5);
INSERT INTO Instructors VALUES (11);
INSERT INTO Instructors VALUES (12);
INSERT INTO Instructors VALUES (13);
INSERT INTO Instructors VALUES (14);
INSERT INTO Instructors VALUES (15);
INSERT INTO Instructors VALUES (16);
INSERT INTO Instructors VALUES (17);
INSERT INTO Instructors VALUES (20);

--Full_time_instructors
INSERT INTO Full_time_instructors VALUES (1);
INSERT INTO Full_time_instructors VALUES (2);
INSERT INTO Full_time_instructors VALUES (3);
INSERT INTO Full_time_instructors VALUES (4);
INSERT INTO Full_time_instructors VALUES (5);
INSERT INTO Full_time_instructors VALUES (17);

--Part_time_instructors
INSERT INTO Part_time_instructors VALUES (11);
INSERT INTO Part_time_instructors VALUES (12);
INSERT INTO Part_time_instructors VALUES (13);
INSERT INTO Part_time_instructors VALUES (14);
INSERT INTO Part_time_instructors VALUES (15);
INSERT INTO Part_time_instructors VALUES (16);
INSERT INTO Part_time_instructors VALUES (20);

--Administrators
INSERT INTO Administrators VALUES (9);
INSERT INTO Administrators VALUES (10);
INSERT INTO Administrators VALUES (18);

--Managers
INSERT INTO Managers VALUES (6);
INSERT INTO Managers VALUES (7);
INSERT INTO Managers VALUES (8);
INSERT INTO Managers VALUES (19);

--Pay_slips

--Rooms
INSERT INTO Rooms VALUES (1, '01-01', 80);
INSERT INTO Rooms VALUES (2, '01-02', 60);
INSERT INTO Rooms VALUES (3, '01-03', 50);
INSERT INTO Rooms VALUES (4, '01-04', 40);
INSERT INTO Rooms VALUES (5, '01-05', 70);
INSERT INTO Rooms VALUES (6, '01-06', 20);
INSERT INTO Rooms VALUES (7, '01-07', 25);
INSERT INTO Rooms VALUES (8, '01-08', 60);
INSERT INTO Rooms VALUES (9, '01-09', 60);
INSERT INTO Rooms VALUES (10, '01-10', 30);
INSERT INTO Rooms VALUES (11, '02-01', 20);
INSERT INTO Rooms VALUES (12, '02-02', 50);
INSERT INTO Rooms VALUES (13, '02-03', 70);
INSERT INTO Rooms VALUES (14, '02-04', 60);
INSERT INTO Rooms VALUES (15, '02-05', 90);
INSERT INTO Rooms VALUES (16, '02-06', 100);
INSERT INTO Rooms VALUES (17, '02-07', 40);
INSERT INTO Rooms VALUES (18, '02-08', 100);
INSERT INTO Rooms VALUES (19, '02-09', 80);
INSERT INTO Rooms VALUES (20, '02-10', 80);
INSERT INTO Rooms VALUES (21, '03-01', 1);

--Course_areas
INSERT INTO Course_areas VALUES ('Database Systems', 6);
INSERT INTO Course_areas VALUES ('Algorithms & Theory', 6);
INSERT INTO Course_areas VALUES ('Artificial Intelligence', 6);
INSERT INTO Course_areas VALUES ('Computer Graphics and Games', 6);
INSERT INTO Course_areas VALUES ('Computer Security', 8);
INSERT INTO Course_areas VALUES ('Multimedia Information Retrieval', 8);
INSERT INTO Course_areas VALUES ('Networking', 8);
INSERT INTO Course_areas VALUES ('Parallel Computing', 19);
INSERT INTO Course_areas VALUES ('Programming Languages', 19);
INSERT INTO Course_areas VALUES ('Software Engineering', 19);

--Specializes
INSERT INTO Specializes VALUES (1, 'Database Systems');
INSERT INTO Specializes VALUES (2, 'Algorithms & Theory');
INSERT INTO Specializes VALUES (3, 'Artificial Intelligence');
INSERT INTO Specializes VALUES (4, 'Computer Graphics and Games');
INSERT INTO Specializes VALUES (5, 'Computer Security');
INSERT INTO Specializes VALUES (11, 'Multimedia Information Retrieval');
INSERT INTO Specializes VALUES (12, 'Networking');
INSERT INTO Specializes VALUES (13, 'Parallel Computing');
INSERT INTO Specializes VALUES (14, 'Programming Languages');
INSERT INTO Specializes VALUES (15, 'Software Engineering');
INSERT INTO Specializes VALUES (16, 'Computer Security');
INSERT INTO Specializes VALUES (17, 'Software Engineering');
INSERT INTO Specializes VALUES (20, 'Database Systems');

--Courses
INSERT INTO Courses VALUES (1, 'Database Systems', 'The aim of this module is to introduce the fundamental concepts and techniques necessary for the understanding and practice of design and implementation of database applications and of the management of data with relational database management systems.', 'Database Systems', 2.0);
INSERT INTO Courses VALUES (2, 'Theory of Computation', 'The objective of this module is to provide students with a theoretical understanding of what can be computed, and an introduction to the theory of complexity.', 'Algorithms & Theory', 2.0);
INSERT INTO Courses VALUES (3, 'Machine Learning', 'This module introduces basic concepts and algorithms in machine learning and neural networks.', 'Artificial Intelligence', 3.0);
INSERT INTO Courses VALUES (4, 'Graphics Rendering Techniques', 'This module provides a general treatment of real-time and offline rendering techniques in 3D computer graphics.', 'Computer Graphics and Games', 2.0);
INSERT INTO Courses VALUES (5, 'Cryptography Theory and Practice', 'This module aims to introduce the foundation, principles and concepts behind cryptology and the design of secure communication systems.', 'Computer Security', 1.5);
INSERT INTO Courses VALUES (6, 'Sound and Music Computing', 'This module introduces the fundamental technologies employed in Sound and Music Computing focusing on three major categories: speech, music, and environmental sound.', 'Multimedia Information Retrieval', 1.0);
INSERT INTO Courses VALUES (7, 'Internet Architecture', 'This module aims to focus on advanced networking concepts pertaining to the modern Internet architecture and applications.', 'Networking', 2.0);
INSERT INTO Courses VALUES (8, 'Multi-core Architecture', 'The world of parallel computer architecture has gone through a significant transformation in the recent years from high-end supercomputers used only for scientific applications to the multi-cores (multiple processing cores on a single chip) that are ubiquitous in mainstream computing systems including desktops, servers, and embedded systems.', 'Parallel Computing', 1.0);
INSERT INTO Courses VALUES (9, 'Compiler Design', 'The objective of this module is to introduce the principal ideas behind program compilation, and discusses various techniques for program parsing, program analysis, program optimisation, and run-time organisation required for program execution.', 'Programming Languages', 1.5);
INSERT INTO Courses VALUES (10, 'Formal Methods for Software Engineering', 'This module will cover formal specification and verification techniques for accurately capturing and reasoning about requirements, model and code.', 'Software Engineering', 4.0);

--Offerings
INSERT INTO Offerings VALUES (1, '2020-09-01', '2020-10-01', '2020-10-05', '2020-09-20', 100, 160, 39.9, 9);
INSERT INTO Offerings VALUES (2, '2020-10-05', '2020-12-01', '2020-12-20', '2020-11-15', 20, 40, 29.9, 9);
INSERT INTO Offerings VALUES (2, '2021-01-01', '2021-02-01', '2021-02-02', '2021-01-15', 50, 120, 39.9, 9);
INSERT INTO Offerings VALUES (3, '2021-03-10', '2021-04-09', '2021-04-15', '2021-03-30', 80, 100, 59.9, 9);
INSERT INTO Offerings VALUES (4, '2020-09-01', '2020-10-01', '2020-10-05', '2020-09-20', 200, 200, 10.9, 9);
INSERT INTO Offerings VALUES (4, '2021-03-10', '2021-04-09', '2021-04-15', '2021-03-30', 200, 200, 30.9, 10);
INSERT INTO Offerings VALUES (5, '2020-05-01', '2020-06-01', '2020-06-10', '2020-05-20', 150, 160, 49.9, 10);
INSERT INTO Offerings VALUES (5, '2021-01-01', '2021-02-01', '2021-02-03', '2021-01-15', 150, 160, 49.9, 10);
INSERT INTO Offerings VALUES (5, '2021-03-10', '2021-04-09', '2021-04-15', '2021-03-30', 180, 180, 39.9, 10);
INSERT INTO Offerings VALUES (6, '2021-02-02', '2021-02-25', '2021-02-26', '2021-02-15', 60, 160, 35.9, 10);
INSERT INTO Offerings VALUES (7, '2021-03-30', '2021-05-17', '2021-05-31', '2021-05-07', 60, 75, 59.9, 10);
INSERT INTO Offerings VALUES (8, '2021-01-01', '2021-02-01', '2021-02-01', '2021-01-20', 10, 40, 79.9, 18);
INSERT INTO Offerings VALUES (8, '2021-02-01', '2021-03-01', '2021-03-01', '2021-02-18', 20, 40, 79.9, 18);
INSERT INTO Offerings VALUES (8, '2021-03-01', '2021-04-01', '2021-04-01', '2021-03-20', 30, 40, 79.9, 18);
INSERT INTO Offerings VALUES (5, '2021-03-30', '2021-05-10', '2021-05-10', '2021-04-30', 50, 90, 49.9, 18);
INSERT INTO Offerings VALUES (3, '2021-04-30', '2021-06-22', '2021-06-22', '2021-05-06', 15, 90, 125.8, 18);
INSERT INTO Offerings VALUES (10, '2021-03-01', '2021-04-05', '2021-04-30', '2021-03-15', 10, 10, 79.9, 18);
INSERT INTO Offerings VALUES (3, '2019-04-18', '2019-05-06', '2019-05-06', '2019-04-19', 15, 90, 125.8, 18);

--Sessions
INSERT INTO Sessions VALUES (1, '2020-09-01', 1, '2020-10-01', 9.0, 11.0, 1, 1);
INSERT INTO Sessions VALUES (1, '2020-09-01', 2, '2020-10-05', 9.0, 11.0, 1, 1);
INSERT INTO Sessions VALUES (2, '2020-10-05', 1, '2020-12-01', 14.0, 16.0, 2, 6);
INSERT INTO Sessions VALUES (2, '2020-10-05', 2, '2020-12-18', 14.0, 16.0, 2, 6);
INSERT INTO Sessions VALUES (2, '2021-01-01', 1, '2021-02-01', 14.0, 16.0, 2, 8);
INSERT INTO Sessions VALUES (2, '2021-01-01', 2, '2021-02-02', 14.0, 16.0, 2, 8);
INSERT INTO Sessions VALUES (3, '2021-03-10', 1, '2021-04-09', 14.0, 17.0, 3, 3);
INSERT INTO Sessions VALUES (3, '2021-03-10', 2, '2021-04-15', 14.0, 17.0, 3, 3);
INSERT INTO Sessions VALUES (4, '2020-09-01', 1, '2020-10-01', 15.0, 17.0, 4, 16);
INSERT INTO Sessions VALUES (4, '2020-09-01', 2, '2020-10-05', 9.0, 11.0, 4, 16);
INSERT INTO Sessions VALUES (4, '2021-03-10', 1, '2021-04-09', 15.0, 17.0, 4, 16);
INSERT INTO Sessions VALUES (4, '2021-03-10', 2, '2021-04-15', 16.0, 18.0, 4, 16);
INSERT INTO Sessions VALUES (5, '2020-05-01', 1, '2020-06-01', 9.0, 10.5, 16, 20);
INSERT INTO Sessions VALUES (5, '2020-05-01', 2, '2020-06-10', 10.0, 11.5, 16, 19);
INSERT INTO Sessions VALUES (5, '2021-01-01', 1, '2021-02-01', 15.0, 16.5, 5, 20);
INSERT INTO Sessions VALUES (5, '2021-01-01', 2, '2021-02-03', 15.0, 16.5, 5, 19);
INSERT INTO Sessions VALUES (5, '2021-03-10', 1, '2021-04-09', 14.0, 15.5, 16, 20);
INSERT INTO Sessions VALUES (5, '2021-03-10', 2, '2021-04-15', 15.5, 17.0, 16, 18);
INSERT INTO Sessions VALUES (6, '2021-02-02', 1, '2021-02-25', 9.0, 10.0, 11, 20);
INSERT INTO Sessions VALUES (6, '2021-02-02', 2, '2021-02-26', 17.0, 18.0, 11, 19);
INSERT INTO Sessions VALUES (7, '2021-03-30', 1, '2021-05-17', 14.0, 16.0, 12, 7);
INSERT INTO Sessions VALUES (7, '2021-03-30', 2, '2021-05-20', 10.0, 12.0, 12, 7);
INSERT INTO Sessions VALUES (7, '2021-03-30', 3, '2021-05-31', 16.0, 18.0, 12, 7);
INSERT INTO Sessions VALUES (8, '2021-01-01', 1, '2021-02-01', 14.0, 15.0, 13, 4);
INSERT INTO Sessions VALUES (8, '2021-02-01', 2, '2021-03-01', 14.0, 15.0, 13, 4);
INSERT INTO Sessions VALUES (8, '2021-03-01', 3, '2021-04-01', 14.0, 15.0, 13, 4);
INSERT INTO Sessions VALUES (5, '2021-03-30', 1, '2021-05-10', 9.0, 10.5, 16, 15);
INSERT INTO Sessions VALUES (3, '2021-04-30', 1, '2021-06-22', 14.0, 17.0, 3, 15);
INSERT INTO Sessions VALUES (10, '2021-03-01', 1, '2021-04-05', 14.0, 18.0, 15, 21);
INSERT INTO Sessions VALUES (10, '2021-03-01', 2, '2021-04-06', 14.0, 18.0, 15, 21);
INSERT INTO Sessions VALUES (10, '2021-03-01', 3, '2021-04-07', 14.0, 18.0, 15, 21);
INSERT INTO Sessions VALUES (10, '2021-03-01', 4, '2021-04-08', 14.0, 18.0, 15, 21);
INSERT INTO Sessions VALUES (10, '2021-03-01', 5, '2021-04-09', 14.0, 18.0, 15, 21);
INSERT INTO Sessions VALUES (10, '2021-03-01', 6, '2021-04-26', 14.0, 18.0, 15, 21);
INSERT INTO Sessions VALUES (10, '2021-03-01', 7, '2021-04-27', 14.0, 18.0, 15, 21);
INSERT INTO Sessions VALUES (10, '2021-03-01', 8, '2021-04-28', 14.0, 18.0, 17, 21);
INSERT INTO Sessions VALUES (10, '2021-03-01', 9, '2021-04-29', 14.0, 18.0, 17, 21);
INSERT INTO Sessions VALUES (10, '2021-03-01', 10, '2021-04-30', 14.0, 18.0, 17, 21);
INSERT INTO Sessions VALUES (3, '2019-04-18', 1, '2019-05-06', 14.0, 17.0, 3, 15);

--Customers
INSERT INTO Customers VALUES (1, 'Severus Snape', 'xm@gmail.com', '(+86) 11111111', 'Changyang Street');
INSERT INTO Customers VALUES (2, 'Luna Lovegood', 'xw@gmail.com', '(+86) 11111112', 'Sanxing Street');
INSERT INTO Customers VALUES (3, 'Albus Dumbledore', 'xz@gmail.com', '(+86) 11111113', 'Yangpu Street');
INSERT INTO Customers VALUES (4, 'Dobby', 'abc123@gmail.com', '(+86) 11111114', 'Shu Street');
INSERT INTO Customers VALUES (5, 'Gellert Grindelwald', 'aaa123@gmail.com', '(+86) 11111115', 'Shu Street');
INSERT INTO Customers VALUES (6, 'Remus Lupin', 'xyz999@gmail.com', '(+86) 11111116', 'Shu Street');
INSERT INTO Customers VALUES (7, 'Ron Weasley', 'qwq123@gmail.com', '(+86) 11111117', 'Wei Street');
INSERT INTO Customers VALUES (8, 'Fred Weasley', 'www123@gmail.com', '(+86) 11111118', 'Wu Street');
INSERT INTO Customers VALUES (9, 'Ginny Weasley', 'ld@gmail.com', '(+86) 11111119', 'Daguanyuan Street');
INSERT INTO Customers VALUES (10, 'Pansy Parkinson', 'abcd@gmail.com', '(+86) 11111120', 'Daguanyuan Street');
INSERT INTO Customers VALUES (11, 'Voldemort', 'abcd@gmail.com', '(+86) 11111121', 'Diagon Ally');
INSERT INTO Customers VALUES (12, 'Harry Potter', 'abcd@gmail.com', '(+86) 11111122', 'Hogwarts');
INSERT INTO Customers VALUES (13, 'Draco Malfoy', 'abcd@gmail.com', '(+86) 11111123', 'Diagon Ally');
INSERT INTO Customers VALUES (14, 'Cedric Diggory', 'abcd@gmail.com', '(+86) 11111124', 'Hogwarts');
INSERT INTO Customers VALUES (15, 'Cho Chang', 'abcd@gmail.com', '(+86) 11111125', 'Hogwarts');
INSERT INTO Customers VALUES (16, 'Sirius Black', 'abcd@gmail.com', '(+86) 11111126', NULL);
INSERT INTO Customers VALUES (17, 'James Potter', 'abcd@gmail.com', '(+86) 11111127', NULL);
INSERT INTO Customers VALUES (18, 'Lily Potter', 'abcd@gmail.com', '(+86) 11111128', NULL);
INSERT INTO Customers VALUES (19, 'Oliver Wood', 'abcd@gmail.com', '(+86) 11111129', 'Hogwarts');
INSERT INTO Customers VALUES (20, 'Hermione Granger', 'abcd@gmail.com', '(+86) 11111130', 'Hogwarts');
INSERT INTO Customers VALUES (21, 'Newt Scamander', 'abcd@gmail.com', '(+86) 11111131', 'Hogwarts');
INSERT INTO Customers VALUES (22, 'Dudley Dursley', 'abcd@gmail.com', '(+86) 11111132', 'Hogwarts');
INSERT INTO Customers VALUES (23, 'George Weasley', 'abcd@gmail.com', '(+86) 11111133', 'Hogwarts');
INSERT INTO Customers VALUES (24, 'Molly Weasley', 'abcd@gmail.com', '(+86) 11111134', NULL);
INSERT INTO Customers VALUES (25, 'Dean Thomas', 'abcd@gmail.com', '(+86) 11111135', NULL);

--Credit_cards
INSERT INTO Credit_cards VALUES ('A123456789012', '2024-07-03', 123);
INSERT INTO Credit_cards VALUES ('A123456789013', '2024-07-04', 456);
INSERT INTO Credit_cards VALUES ('A123456789014', '2024-07-05', 788);
INSERT INTO Credit_cards VALUES ('A123456789015', '2024-07-06', 233);
INSERT INTO Credit_cards VALUES ('A123456789016', '2024-07-07', 666);
INSERT INTO Credit_cards VALUES ('A123456789017', '2024-07-08', 777);
INSERT INTO Credit_cards VALUES ('A123456789018', '2024-07-09', 888);
INSERT INTO Credit_cards VALUES ('A123456789019', '2024-07-10', 999);
INSERT INTO Credit_cards VALUES ('A123456789020', '2024-07-11', 555);
INSERT INTO Credit_cards VALUES ('A123456789021', '2024-07-12', 100);
INSERT INTO Credit_cards VALUES ('A123456789022', '2099-05-07', 884);
INSERT INTO Credit_cards VALUES ('A123456789023', '2024-05-09', 125);
INSERT INTO Credit_cards VALUES ('A123456789024', '2024-05-10', 126);
INSERT INTO Credit_cards VALUES ('A123456789025', '2024-05-11', 127);
INSERT INTO Credit_cards VALUES ('A123456789026', '2024-05-12', 444);
INSERT INTO Credit_cards VALUES ('A123456789027', '2024-05-13', 444);
INSERT INTO Credit_cards VALUES ('A123456789028', '2024-05-14', 444);
INSERT INTO Credit_cards VALUES ('A123456789029', '2024-05-15', 444);
INSERT INTO Credit_cards VALUES ('A123456789030', '2024-05-16', 444);
INSERT INTO Credit_cards VALUES ('A123456789031', '2024-05-17', 444);
INSERT INTO Credit_cards VALUES ('A123456789032', '2024-05-18', 444);
INSERT INTO Credit_cards VALUES ('A123456789033', '2024-05-19', 444);
INSERT INTO Credit_cards VALUES ('A123456789034', '2024-05-20', 444);
INSERT INTO Credit_cards VALUES ('A123456789035', '2024-05-21', 444);
INSERT INTO Credit_cards VALUES ('A123456789036', '2024-05-22', 444);

--Owns
INSERT INTO Owns VALUES (1, 'A123456789012', '2015-07-03');
INSERT INTO Owns VALUES (2, 'A123456789013', '2015-07-04');
INSERT INTO Owns VALUES (3, 'A123456789014', '2015-07-05');
INSERT INTO Owns VALUES (4, 'A123456789015', '2015-07-06');
INSERT INTO Owns VALUES (5, 'A123456789016', '2015-07-07');
INSERT INTO Owns VALUES (6, 'A123456789017', '2015-07-08');
INSERT INTO Owns VALUES (7, 'A123456789018', '2015-07-09');
INSERT INTO Owns VALUES (8, 'A123456789019', '2015-07-10');
INSERT INTO Owns VALUES (9, 'A123456789020', '2015-07-11');
INSERT INTO Owns VALUES (10, 'A123456789021', '2015-07-12');
INSERT INTO Owns VALUES (11, 'A123456789022', '2015-01-02');
INSERT INTO Owns VALUES (12, 'A123456789023', '2015-01-04');
INSERT INTO Owns VALUES (13, 'A123456789024', '2015-01-05');
INSERT INTO Owns VALUES (14, 'A123456789025', '2015-01-06');
INSERT INTO Owns VALUES (15, 'A123456789026', '2015-01-07');
INSERT INTO Owns VALUES (16, 'A123456789027', '2015-01-08');
INSERT INTO Owns VALUES (17, 'A123456789028', '2015-01-09');
INSERT INTO Owns VALUES (18, 'A123456789029', '2015-01-10');
INSERT INTO Owns VALUES (19, 'A123456789030', '2015-01-11');
INSERT INTO Owns VALUES (20, 'A123456789031', '2015-01-12');
INSERT INTO Owns VALUES (21, 'A123456789032', '2015-01-13');
INSERT INTO Owns VALUES (22, 'A123456789033', '2015-01-14');
INSERT INTO Owns VALUES (23, 'A123456789034', '2015-01-15');
INSERT INTO Owns VALUES (24, 'A123456789035', '2015-01-16');
INSERT INTO Owns VALUES (25, 'A123456789036', '2015-01-17');

--Course_packages
INSERT INTO Course_packages VALUES (1, 6, '2016-06-06', '2016-12-26', 'Wu Di 666', 166);
INSERT INTO Course_packages VALUES (2, 8, '2018-08-08', '2028-08-08', 'How To Get Rich', 178);
INSERT INTO Course_packages VALUES (3, 20, '2019-01-01', '2029-12-31', 'Forever Young', 308);
INSERT INTO Course_packages VALUES (4, 22, '2021-01-01', '2022-02-02', 'Te Hui ', 399);
INSERT INTO Course_packages VALUES (5, 10, '2021-02-01', '2021-12-01', 'HAPPY NEW YEAR', 188);
INSERT INTO Course_packages VALUES (6, 10, '2021-03-01', '2021-12-02', 'HAPPY NEW MONTH', 198);
INSERT INTO Course_packages VALUES (7, 15, '2021-04-01', '2021-12-03', 'HAPPY APRIL FOOLS', 233);
INSERT INTO Course_packages VALUES (8, 1, '2021-02-02', '2021-10-01', 'ARE YOU HAPPY', 10);

--Buys
INSERT INTO Buys VALUES (1, 'A123456789012', '2016-06-07', 6);
INSERT INTO Buys VALUES (2, 'A123456789016', '2018-10-08', 8);
INSERT INTO Buys VALUES (3, 'A123456789015', '2021-01-01', 20);
INSERT INTO Buys VALUES (3, 'A123456789021', '2021-01-01', 20);
INSERT INTO Buys VALUES (3, 'A123456789013', '2021-01-01', 20);
INSERT INTO Buys VALUES (2, 'A123456789018', '2018-08-09', 8);
INSERT INTO Buys VALUES (5, 'A123456789014', '2021-04-02', 10);
INSERT INTO Buys VALUES (5, 'A123456789020', '2021-04-02', 10);
INSERT INTO Buys VALUES (6, 'A123456789017', '2021-04-02', 10);
INSERT INTO Buys VALUES (7, 'A123456789019', '2021-04-02', 15);
INSERT INTO Buys VALUES (8, 'A123456789022', '2021-02-03', 1);
INSERT INTO Buys VALUES (8, 'A123456789023', '2021-02-03', 1);

--Redeems
INSERT INTO Redeems VALUES (2, 'A123456789016', '2018-10-08', 6, '2021-02-02', 1, '2021-02-15');
INSERT INTO Redeems VALUES (2, 'A123456789016', '2018-10-08', 4, '2020-09-01', 1, '2020-09-10');
INSERT INTO Redeems VALUES (2, 'A123456789016', '2018-10-08', 5, '2021-01-01', 1, '2021-01-01');
INSERT INTO Redeems VALUES (3, 'A123456789013', '2021-01-01', 5, '2021-03-10', 1, '2021-03-30');
INSERT INTO Redeems VALUES (1, 'A123456789012', '2016-06-07', 5, '2021-03-10', 1, '2021-03-10');
INSERT INTO Redeems VALUES (2, 'A123456789016', '2018-10-08', 8, '2021-01-01', 1, '2021-01-18');
INSERT INTO Redeems VALUES (3, 'A123456789013', '2021-01-01', 8, '2021-02-01', 2, '2021-02-18');
INSERT INTO Redeems VALUES (1, 'A123456789012', '2016-06-07', 8, '2021-03-01', 3, '2021-03-18');
INSERT INTO Redeems VALUES (8, 'A123456789022', '2021-02-03', 10, '2021-03-01', 1, '2021-03-11');
INSERT INTO Redeems VALUES (8, 'A123456789023', '2021-02-03', 10, '2021-03-01', 10, '2021-03-11');

--Registers
INSERT INTO Registers VALUES ('A123456789012', 1, '2020-09-01', 2, '2020-09-20');
INSERT INTO Registers VALUES ('A123456789013', 2, '2020-10-05', 1, '2020-11-01');
INSERT INTO Registers VALUES ('A123456789021', 3, '2021-03-10', 1, '2021-03-18');
INSERT INTO Registers VALUES ('A123456789015', 5, '2021-03-10', 2, '2021-03-15');
INSERT INTO Registers VALUES ('A123456789020', 5, '2021-03-30', 1, '2021-04-10');
INSERT INTO Registers VALUES ('A123456789019', 5, '2021-03-30', 1, '2021-04-11');
INSERT INTO Registers VALUES ('A123456789020', 8, '2021-02-01', 2, '2021-02-02');
INSERT INTO Registers VALUES ('A123456789017', 8, '2021-03-01', 3, '2021-03-03');
INSERT INTO Registers VALUES ('A123456789014', 8, '2021-03-01', 3, '2021-03-03');
INSERT INTO Registers VALUES ('A123456789031', 3, '2019-04-18', 1, '2019-04-18');
INSERT INTO Registers VALUES ('A123456789032', 8, '2021-03-01', 3, '2021-03-03');

--Cancels
INSERT INTO Cancels VALUES (1, 1, '2020-09-01', 2, '2020-09-28', 35.91, 0);
INSERT INTO Cancels VALUES (5, 4, '2020-09-01', 1, '2020-09-12', 0.0, 1);
INSERT INTO Cancels VALUES (3, 8, '2021-03-01', 3, '2021-03-30', 0.0, 0);

--Pay_slips
CALL pay_salary_for_month ('2021-01-01');