DROP TABLE IF EXISTS Customers CASCADE;
DROP TABLE IF EXISTS Credit_cards CASCADE;
DROP TABLE IF EXISTS Owns CASCADE;
DROP TABLE IF EXISTS Cancels CASCADE;
DROP TABLE IF EXISTS Course_packages CASCADE;
DROP TABLE IF EXISTS Buys CASCADE;
DROP TABLE IF EXISTS Redeems CASCADE;
DROP TABLE IF EXISTS Registers CASCADE;
DROP TABLE IF EXISTS Course_areas CASCADE;
DROP TABLE IF EXISTS Courses CASCADE;
DROP TABLE IF EXISTS Offerings CASCADE;
DROP TABLE IF EXISTS Sessions CASCADE;
DROP TABLE IF EXISTS Rooms CASCADE;
DROP TABLE IF EXISTS Specializes CASCADE;
DROP TABLE IF EXISTS Employees CASCADE;
DROP TABLE IF EXISTS Part_time_Emp CASCADE;
DROP TABLE IF EXISTS Full_time_Emp CASCADE;
DROP TABLE IF EXISTS Instructors CASCADE;
DROP TABLE IF EXISTS Part_time_instructors CASCADE;
DROP TABLE IF EXISTS Full_time_instructors CASCADE;
DROP TABLE IF EXISTS Administrators CASCADE;
DROP TABLE IF EXISTS Managers CASCADE;
DROP TABLE IF EXISTS Pay_slips CASCADE;

CREATE TABLE Employees (
  	eid INTEGER PRIMARY KEY,
  	name TEXT NOT NULL,
  	email TEXT NOT NULL,
  	phone TEXT NOT NULL,
  	address TEXT NOT NULL,
  	join_date DATE NOT NULL,
	depart_date DATE,
	CHECK (join_date <= depart_date),
	UNIQUE (name, email, phone, address, join_date, depart_date)
);

-- Trigger to enforce Either Or
CREATE TABLE Full_time_Emp (
	eid INTEGER PRIMARY KEY REFERENCES Employees ON DELETE CASCADE,
  	monthly_salary NUMERIC(10,2) NOT NULL CHECK (monthly_salary >= 0)
);

CREATE TABLE Part_time_Emp (
	eid INTEGER PRIMARY KEY REFERENCES Employees ON DELETE CASCADE,
  	hourly_rate NUMERIC(6,2) NOT NULL CHECK (hourly_rate >= 0)
);

CREATE TABLE Instructors (
  	eid INTEGER PRIMARY KEY REFERENCES Employees ON DELETE CASCADE
);

CREATE TABLE Full_time_instructors (
  	eid INTEGER PRIMARY KEY REFERENCES Full_time_Emp REFERENCES Instructors ON DELETE CASCADE
);

CREATE TABLE Part_time_instructors (
  	eid INTEGER PRIMARY KEY REFERENCES Part_time_Emp REFERENCES Instructors ON DELETE CASCADE	
);

CREATE TABLE Administrators (
  	eid INTEGER PRIMARY KEY REFERENCES Full_time_Emp ON DELETE CASCADE
);

CREATE TABLE Managers (
  	eid INTEGER PRIMARY KEY REFERENCES Full_time_Emp ON DELETE CASCADE
);

CREATE TABLE Pay_slips (
	eid INTEGER REFERENCES Employees ON DELETE CASCADE,
  	payment_date DATE,
  	amount NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
  	num_work_hours NUMERIC(5,2) CHECK (num_work_hours >= 0),
  	num_work_days INTEGER CHECK (num_work_days >= 0),
  	PRIMARY KEY (eid, payment_date)
);

CREATE TABLE Rooms (
	rid INTEGER PRIMARY KEY,
  	location TEXT NOT NULL,
  	seating_capacity INTEGER NOT NULL CHECK (seating_capacity > 0),
	UNIQUE (location)
);

-- include Manages relationship by eid
CREATE TABLE Course_areas (
  	name TEXT PRIMARY KEY,
  	eid INTEGER REFERENCES Managers NOT NULL
);

-- include In relationship by course_area_name
CREATE TABLE Courses (
	course_id INTEGER PRIMARY KEY,
	title TEXT NOT NULL,
	description TEXT,
  	course_area TEXT REFERENCES Course_areas NOT NULL,
  	duration NUMERIC(4,2) NOT NULL CHECK (duration > 0),
	UNIQUE (title, description, course_area, duration)
);

-- include Handles relationship by eid
CREATE TABLE Offerings (
	course_id INTEGER REFERENCES Courses ON DELETE CASCADE,
  	launch_date DATE,
  	start_date DATE NOT NULL,
  	end_date DATE NOT NULL,
  	registration_deadline DATE NOT NULL,
  	target_number_registrations INTEGER NOT NULL CHECK (target_number_registrations > 0),
    seating_capacity INTEGER NOT NULL CHECK (seating_capacity > 0),
  	fees NUMERIC(10,2) NOT NULL CHECK (fees >= 0),
  	eid INTEGER REFERENCES Administrators NOT NULL,
  	PRIMARY KEY (course_id, launch_date),
	CHECK (launch_date <= registration_deadline),
	CHECK (start_date <= end_date),
	CHECK (registration_deadline <= start_date - INTERVAL '10 days'),
	CHECK (seating_capacity >= target_number_registrations)
);


-- include Conducts relationship by eid & rid
CREATE TABLE Sessions (
	course_id INTEGER,
  	launch_date DATE,
  	sid INTEGER,
  	date DATE NOT NULL, 
  	start_time NUMERIC(4,2) NOT NULL, 
  	end_time NUMERIC(4,2) NOT NULL, 
  	eid INTEGER REFERENCES Instructors NOT NULL,
  	rid INTEGER REFERENCES Rooms NOT NULL,
  	PRIMARY KEY (course_id, launch_date, sid),
  	FOREIGN KEY (course_id, launch_date) REFERENCES Offerings ON DELETE CASCADE
	  	DEFERRABLE INITIALLY DEFERRED,
	CHECK ((EXTRACT(DOW FROM date)) IN (1,2,3,4,5)),
	CHECK ((start_time >= 9 and end_time <= 12) or (start_time >= 14 and end_time <= 18)),
	CHECK (start_time < end_time),
	CHECK (launch_date <= date - INTERVAL '10 days')
);

-- course-employee relationships need to use trigger 
CREATE TABLE Specializes (
	eid INTEGER REFERENCES Instructors,
  	area TEXT REFERENCES Course_areas,
  	PRIMARY KEY (eid, area)
);

CREATE TABLE Customers (
  	cust_id INTEGER PRIMARY KEY,
  	name TEXT NOT NULL,
  	email TEXT NOT NULL,
  	phone TEXT NOT NULL,
  	address TEXT,
	UNIQUE (name, email, phone, address)
);

CREATE TABLE Credit_cards (
  	number TEXT PRIMARY KEY,  	
  	expiry_date DATE NOT NULL,
  	CVV INTEGER NOT NULL
);

CREATE TABLE Owns (
  	cust_id INTEGER REFERENCES Customers NOT NULL,
  	card_number TEXT REFERENCES Credit_cards,
  	from_date DATE NOT NULL,
  	PRIMARY KEY (card_number)
  	--TPC for Customers trigger: when inserting customer, check credit_card >= 1
  	--TPC for Credit_card trigger: when inserting credit card, check customers >= 1
);

CREATE TABLE Course_packages (
	package_id INTEGER PRIMARY KEY,
  	num_free_registrations INTEGER NOT NULL CHECK (num_free_registrations > 0),
	sale_start_date DATE NOT NULL,
  	sale_end_date DATE NOT NULL,
  	name TEXT NOT NULL,
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
	CHECK (sale_start_date <= sale_end_date),
	UNIQUE (num_free_registrations, sale_start_date, sale_end_date, name, price)
); 

CREATE TABLE Buys (
  	package_id INTEGER REFERENCES Course_packages, 
    card_number TEXT REFERENCES Owns,
  	date DATE,
  	num_remaining_redemptions INTEGER NOT NULL CHECK (num_remaining_redemptions >= 0),
    PRIMARY KEY (package_id, card_number, date)
);

CREATE TABLE Redeems(
  	package_id INTEGER,
    card_number TEXT,
  	buy_date DATE,
  	course_id INTEGER,
  	launch_date DATE,
  	sid INTEGER,  	
	date DATE,  	
    PRIMARY KEY (package_id, card_number, buy_date, course_id, launch_date, sid, date),
    FOREIGN KEY (package_id, card_number, buy_date) REFERENCES Buys,
  	FOREIGN KEY (course_id, launch_date, sid) REFERENCES Sessions,
	CHECK (buy_date <= date),
	CHECK (launch_date <= date)
);

CREATE TABLE Registers(
  	card_number TEXT REFERENCES Owns,
  	course_id INTEGER,
  	launch_date DATE,
    sid INTEGER,
    date DATE,
    PRIMARY KEY (card_number, course_id, launch_date, sid, date),
  	FOREIGN KEY (course_id, launch_date, sid) REFERENCES Sessions,
	CHECK (launch_date <= date)
);

CREATE TABLE Cancels (
  	cust_id INTEGER REFERENCES Customers,
  	course_id INTEGER,
  	launch_date DATE,
  	sid INTEGER,  	
  	date DATE,
  	refund_amt NUMERIC(10,2) DEFAULT 0 CHECK (refund_amt >= 0), /* bought: 90% of offering fees, redeemed: 0 */
  	package_credit INTEGER CHECK (package_credit IN (0, 1)), /* bought: 0, redeemed: 1 */
  	PRIMARY KEY (cust_id, course_id, launch_date, sid, date),
  	FOREIGN KEY (course_id, launch_date, sid) REFERENCES Sessions,
	CHECK (launch_date <= date)
);
