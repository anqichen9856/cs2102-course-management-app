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
            amount := TRUNC(r.monthly_salary * num_work_days / (last_day_of_month - first_day_of_month + 1), 2);
            INSERT INTO Pay_slips VALUES (r.eid, last_day_of_month, amount, NULL, num_work_days);

        ELSE  /* Part-time */
            SELECT COALESCE(SUM(end_time - start_time), 0) INTO num_work_hours FROM Sessions S
                WHERE S.eid = r.eid AND S.date BETWEEN first_day_of_month AND last_day_of_month;
            amount := TRUNC(r.hourly_rate * num_work_hours, 2);
            INSERT INTO Pay_slips VALUES (r.eid, last_day_of_month, amount, num_work_hours, NULL);

        END IF;
    END LOOP;
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;


 --Pay_slips
CALL pay_salary_for_month ('2020-01-01');
CALL pay_salary_for_month ('2020-02-01');
CALL pay_salary_for_month ('2020-03-01');
CALL pay_salary_for_month ('2020-04-01');
CALL pay_salary_for_month ('2020-05-01');
CALL pay_salary_for_month ('2020-06-01');
CALL pay_salary_for_month ('2020-07-01');
CALL pay_salary_for_month ('2020-08-01');
CALL pay_salary_for_month ('2020-09-01');
CALL pay_salary_for_month ('2020-10-01');
CALL pay_salary_for_month ('2020-11-01');
CALL pay_salary_for_month ('2020-12-01');
CALL pay_salary_for_month ('2021-01-01');
CALL pay_salary_for_month ('2021-02-01');
CALL pay_salary_for_month ('2021-03-01');