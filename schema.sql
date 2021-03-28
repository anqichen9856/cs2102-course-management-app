CREATE TABLE Customers (
  	cust_id INTEGER PRIMARY KEY,
  	name TEXT,
  	email TEXT,
  	phone TEXT,
  	address TEXT
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

CREATE TABLE Cancels (
  	cust_id INTEGER REFERENCES Customers,
  	course_id INTEGER,
  	launch_date DATE,
  	sid INTEGER,  	
  	date DATE,
  	refund_amt NUMERIC,
  	package_credit INTEGER CHECK (package_credit IN (0, 1)),
  	PRIMARY KEY (cust_id, course_id, launch_date, sid, date),
  	FOREIGN KEY (course_id, launch_date, sid) REFERENCES Sessions
);


CREATE TABLE Course_packages (
	package_id INTEGER PRIMARY KEY,
  	num_free_registrations INTEGER NOT NULL,
	sale_start_date DATE NOT NULL,
  	sale_end_date DATE NOT NULL,
  	name TEXT NOT NULL,
    price NUMERIC NOT NULL
); 

CREATE TABLE Buys (
  	package_id INTEGER REFERENCES Course_packages,    	
    card_number TEXT REFERENCES Owns,
  	date DATE,
  	num_remaining_redemptions INTEGER NOT NULL,  	
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
  	FOREIGN KEY (course_id, launch_date, sid) REFERENCES Sessions
);

CREATE TABLE Registers(
  	card_number TEXT REFERENCES Owns,
  	course_id INTEGER,
  	launch_date DATE,
    sid INTEGER,
    date DATE,
    PRIMARY KEY (card_number, course_id, launch_date, sid, date),
  	FOREIGN KEY (course_id, launch_date, sid) REFERENCES Sessions 	
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
  	duration INTEGER NOT NULL
);

-- include Handles relationship by eid
CREATE TABLE Offerings (
	course_id INTEGER REFERENCES Courses ON DELETE CASCADE,
  	launch_date DATE,
  	start_date DATE NOT NULL,
  	end_date DATE NOT NULL,
  	registration_deadline DATE NOT NULL,
  	target_number_registrations INTEGER NOT NULL,
    seating_capacity INTEGER NOT NULL,
  	fees NUMERIC NOT NULL,
  	eid INTEGER REFERENCES Administrators NOT NULL,
  	PRIMARY KEY (course_id, launch_date)
);

-- include Conducts relationship by eid & rid
CREATE TABLE Sessions (
	course_id INTEGER,
  	launch_date DATE,
  	sid INTEGER,
  	date DATE NOT NULL, /* weekday */
  	start_time INTEGER NOT NULL, /* check constraints */
  	end_time INTEGER NOT NULL, /* check constraints */
	/* need to clarify: each session duration is one hour? */
  	eid INTEGER REFERENCES Instructors,
  	rid INTEGER REFERENCES Rooms,
  	PRIMARY KEY (course_id, launch_date, sid),
  	FOREIGN KEY (course_id, launch_date) REFERENCES Offerings ON DELETE CASCADE
);

CREATE TABLE Rooms (
	rid INTEGER PRIMARY KEY,
  	location TEXT NOT NULL,
  	seating_capacity INTEGER NOT NULL
);

-- course-employee relationships need to use trigger 
CREATE TABLE Specializes (
	eid INTEGER REFERENCES Instructors,
  	area TEXT REFERENCES Course_areas
  	PRIMARY KEY (eid, area)
);

CREATE TABLE Employees (
  	eid INTEGER PRIMARY KEY,
  	name TEXT NOT NULL,
  	email TEXT NOT NULL,
  	phone TEXT NOT NULL,
  	address TEXT,
  	join_date DATE NOT NULL,
	depart_date DATE
);

-- Trigger to enforce Either Or
CREATE TABLE Part_time_Emp (
	eid INTEGER PRIMARY KEY REFERENCES Employees ON DELETE CASCADE,
  	hourly_rate NUMERIC NOT NULL
);

CREATE TABLE Full_time_Emp (
	eid INTEGER PRIMARY KEY REFERENCES Employees ON DELETE CASCADE,
  	monthly_salary NUMERIC NOT NULL
);

CREATE TABLE Instructors (
  	eid INTEGER PRIMARY KEY REFERENCES Employees ON DELETE CASCADE
);

CREATE TABLE Part_time_instructors (
  	eid INTEGER PRIMARY KEY REFERENCES Part_time_Emp REFERENCES Instructors ON DELETE CASCADE	
);

CREATE TABLE Full_time_instructors (
  	eid INTEGER PRIMARY KEY REFERENCES Full_time_Emp REFERENCES Instructors ON DELETE CASCADE
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
  	amount NUMERIC NOT NULL,
  	num_work_hours INTEGER,
  	num_work_days INTEGER,
  	PRIMARY KEY (eid, payment_date)
);
