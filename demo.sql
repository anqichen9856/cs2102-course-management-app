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
-- NULL attributes
CALL add_customer (NULL, '3 Jurong East Street 32', '(+65) 90174780', 'anqichen@gmail.com', 'A0188533W1234', '2023-02-20', 886);
-- NULL address allowed
CALL add_customer ('Joshua Ong', NULL, '(+65) 71156789', 'joshua@gmail.com', 'A0188533W1236', '2026-07-20', 888);
-- Same credit card
-- TPC for Credit cards：every credit card must be owned by at least one customer
-- credit_card_owns_total_part_con_trigger
CALL add_customer ('Joshua Ong', NULL, '(+65) 71156789', 'joshuaong@gmail.com', 'A0188533W1234', '2026-07-20', 888);
-- TPC for Customers：every customer owns >= 1 credit card
-- customer_owns_total_part_con_trigger
CALL add_customer ('Joel Siow', NULL, '(+65) 98256170', 'joelsiow@gmail.com', 'A0123456789012', '2026-07-20', 888);

-- 4
select * from owns where cust_id=11
select * from credit_cards
CALL update_credit_card (11, 'A0188533119W0117', '2026-09-27', 901);


-- 8
-- first look at all rooms. in total 22 rooms
SELECT * FROM Rooms;
-- look at sessions
SELECT * FROM Sessions;
-- no lesson on 2021-04-14, all rooms free
SELECT * FROM find_rooms('2021-04-14', 9, 2);
-- several lessons on that day
SELECT * FROM Sessions WHERE DATE = '2021-04-09';
SELECT * FROM find_rooms('2021-04-09', 14, 1);
SELECT * FROM find_rooms('2021-04-09', 14, 2);
-- time not valid
SELECT * FROM find_rooms('2021-04-09', 18, 1);
SELECT * FROM find_rooms('2021-04-09', 11, 2);
-- date not valid
SELECT * FROM find_rooms('2021-04-10', 14, 3);
-- negative start time can handle
-- duration > 0 cannot handle 555


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

