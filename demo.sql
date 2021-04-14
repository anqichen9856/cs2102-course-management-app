-- Test cases for routines

/* ad hoc test */
DO language plpgsql $$
BEGIN
  RAISE NOTICE 'hello, world!';
END
$$;

/* transient table */
(VALUES (row), (row))


-- 3
select * from customers
select * from credit_cards
select * from owns
CALL add_customer ('Chen Anqi', '3 Jurong East Street 32', '(+65) 90174780', 'anqichen@gmail.com', 'A0188533W1234', '2023-02-20', 886);

-- 4
select * from owns where cust_id=11
select * from credit_cards
CALL update_credit_card (11, 'A0188533119W0117', '2026-09-27', 901);


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

