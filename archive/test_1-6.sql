DO language plpgsql $$
BEGIN
  RAISE NOTICE 'hello, world!';
END
$$;

(VALUES (row), (row))

CALL add_employee (
	'Jasmine', 
	'12 Kent Ridge Drive', 
	'(+65) 90176780',
	'jasmine@gmail.com',
	'monthly',
	'1200',
	'2021-03-31',
	'administrator',
	'{}'
);

CALL add_employee (
	'Richard Xiong', 
	'12 Kent Ridge Drive', 
	'(+65) 90176780',
	'rx@gmail.com',
	'monthly',
	'3000',
	'2021-03-31',
	'instructor',
	'{"Computer Science"}'
);

CALL add_employee (
	'Joyce', 
	'12 Kent Ridge Drive', 
	'(+65) 90176780',
	'joyce@gmail.com',
	'hourly',
	'50.90',
	'2021-03-20',
	'instructor',
	'{"Social Sciences", "Law"}'
);

CALL add_employee (
	'Wang Qian', 
	'12 Kent Ridge Drive', 
	'(+65) 90176780',
	'qiannnnw@gmail.com',
	'monthly',
	'2400',
	'2021-03-20',
	'manager',
	'{"Law"}'
);


CALL add_employee (
	'test', 
	NULL, 
	'(+65) 90176780',
	'qiannnnw@gmail.com',
	'monthly',
	'2400',
	'2021-03-20',
	'manager',
	'{}'
);

CALL remove_employee (
    21, CURRENT_DATE
);

CALL remove_employee (
    3, '2017-08-29'
);

CALL add_customer (
    'Chen Anqi',
    '3 Jurong East Street 32',
    '(+65) 90174780',
    'anqichen@gmail.com',
    '1100201111923455',
    '2023-02-20',
    '886' 
);

CALL update_credit_card (
    11, 'A0188533119W', '2026-09-27', 901
);

INSERT INTO Course_areas VALUES ('Philosophy', 8);
CALL add_course (
    'Philosophical Logic',
    'Resolving the paradox is extremely difficult, requiring revision to classical logic or the theory of truth. The course will cover this and other topics in philosophical logic such as vagueness and the sorites paradox, the paradoxes of material implication, essentialism and necessity, and probability and induction.',
    'Philosophy',
    3
);

SELECT * FROM find_instructors (
    11,
    '2021-03-31',
    15
);

SELECT * FROM find_instructors (
    1,
    '2021-03-31',
    15
);

SELECT * FROM find_instructors (
    2,
    '2021-03-31',
    15
);

SELECT * FROM find_instructors (
    4,
    '2021-03-31',
    15
);

DELETE FROM Pay_slips;
SELECT * FROM pay_salary();

SELECT * FROM promote_courses();

