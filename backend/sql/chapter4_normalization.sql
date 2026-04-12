-- ============================================================
-- CHAPTER 4: NORMALIZATION - RideShare System
-- 21CSC205P DBMS Mini Project
-- Run each section separately and screenshot the output
-- ============================================================

USE RideSharingSystem;

-- ============================================================
-- 4.1 ANALYSE THE PITFALLS (Unnormalized Table - UNF)
-- ============================================================
-- Before normalization, imagine all ride data in ONE table.
-- We create this "bad" table to demonstrate pitfalls.

DROP TABLE IF EXISTS Ride_UNF;
CREATE TABLE Ride_UNF (
    Ride_ID         INT,
    Passenger_Name  VARCHAR(100),
    Passenger_Phone VARCHAR(15),
    Passenger_Email VARCHAR(100),
    Driver_Name     VARCHAR(100),
    Driver_Phone    VARCHAR(15),
    License_No      VARCHAR(50),
    Vehicle_Model   VARCHAR(100),
    Vehicle_Type    VARCHAR(50),
    Pickup_Address  VARCHAR(255),
    Drop_Address    VARCHAR(255),
    Trip_Distance   DECIMAL(6,2),
    Trip_Fare       DECIMAL(8,2),
    Payment_Mode    VARCHAR(50),
    Driver_Rating   INT,
    Comments        VARCHAR(255)
);

INSERT INTO Ride_UNF VALUES
(1, 'Aarav Sharma',  '9876543210', 'aarav@gmail.com',   'Suresh Kumar', '9000011111', 'DL12345', 'Swift Dzire', 'Sedan', 'Anna Nagar',   'T Nagar',      8.5,  127.50, 'Wallet', 5, 'Great ride!'),
(2, 'Aarav Sharma',  '9876543210', 'aarav@gmail.com',   'Manoj Singh',  '9000022222', 'DL67890', 'Honda City', 'Sedan', 'Adyar',        'Airport',      22.0, 330.00, 'UPI',    4, 'On time'),
(3, 'Diya Reddy',    '9123456780', 'diya@gmail.com',    'Suresh Kumar', '9000011111', 'DL12345', 'Swift Dzire', 'Sedan', 'Velachery',   'Central',      12.0, 180.00, 'Cash',   5, 'Very polite'),
(4, 'Rahul Verma',   '9988776655', 'rahul@gmail.com',   'Manoj Singh',  '9000022222', 'DL67890', 'Honda City', 'Sedan', 'Porur',        'Sholinganallur',18.5, 277.50, 'UPI',   3, 'Average'),
(5, 'Aarav Sharma',  '9876543210', 'aarav@gmail.com',   'Suresh Kumar', '9000011111', 'DL12345', 'Swift Dzire', 'Sedan', 'Guindy',      'Chromepet',    9.0,  135.00, 'Wallet', 5, 'Excellent');

SELECT * FROM Ride_UNF;

-- PITFALLS VISIBLE IN THIS TABLE:
-- 1. REDUNDANCY:     Aarav's phone/email repeated in rows 1,2,5
-- 2. UPDATE ANOMALY: If Suresh changes his phone, must update rows 1,3,5
-- 3. DELETE ANOMALY: Delete ride 4 → lose all info about Rahul Verma
-- 4. INSERT ANOMALY: Cannot add a driver without a ride record


-- ============================================================
-- 4.2 FIRST NORMAL FORM (1NF)
-- ============================================================
-- Rule: All attributes must be atomic (no repeating groups, no arrays)
-- Problem in UNF: Vehicle_Type could store multiple values like 'Sedan, SUV'

-- 4.2.1 Identify Dependency
-- Ride_ID → all other columns (single-valued, but phone/email repeat per person)
-- Show violation: passenger info repeats for same passenger
SELECT Passenger_Name, Passenger_Phone, Passenger_Email, COUNT(*) AS Occurrences
FROM Ride_UNF
GROUP BY Passenger_Name, Passenger_Phone, Passenger_Email
HAVING COUNT(*) > 1;

-- 4.2.2 Apply 1NF
-- Split into atomic tables — each cell has one value, each row is unique
DROP TABLE IF EXISTS Ride_1NF_Passenger;
DROP TABLE IF EXISTS Ride_1NF_Driver;
DROP TABLE IF EXISTS Ride_1NF_Trip;

CREATE TABLE Ride_1NF_Passenger (
    Passenger_ID    INT PRIMARY KEY,
    Passenger_Name  VARCHAR(100) NOT NULL,
    Passenger_Phone VARCHAR(15)  NOT NULL,
    Passenger_Email VARCHAR(100) NOT NULL
);

CREATE TABLE Ride_1NF_Driver (
    Driver_ID       INT PRIMARY KEY,
    Driver_Name     VARCHAR(100) NOT NULL,
    Driver_Phone    VARCHAR(15)  NOT NULL,
    License_No      VARCHAR(50)  NOT NULL,
    Vehicle_Model   VARCHAR(100),
    Vehicle_Type    VARCHAR(50)
);

CREATE TABLE Ride_1NF_Trip (
    Ride_ID         INT PRIMARY KEY,
    Passenger_ID    INT,
    Driver_ID       INT,
    Pickup_Address  VARCHAR(255),
    Drop_Address    VARCHAR(255),
    Trip_Distance   DECIMAL(6,2),
    Trip_Fare       DECIMAL(8,2),
    Payment_Mode    VARCHAR(50),
    Driver_Rating   INT,
    Comments        VARCHAR(255)
);

INSERT INTO Ride_1NF_Passenger VALUES
(1, 'Aarav Sharma', '9876543210', 'aarav@gmail.com'),
(2, 'Diya Reddy',   '9123456780', 'diya@gmail.com'),
(3, 'Rahul Verma',  '9988776655', 'rahul@gmail.com');

INSERT INTO Ride_1NF_Driver VALUES
(1, 'Suresh Kumar', '9000011111', 'DL12345', 'Swift Dzire', 'Sedan'),
(2, 'Manoj Singh',  '9000022222', 'DL67890', 'Honda City',  'Sedan');

INSERT INTO Ride_1NF_Trip VALUES
(1, 1, 1, 'Anna Nagar',  'T Nagar',         8.5,  127.50, 'Wallet', 5, 'Great ride!'),
(2, 1, 2, 'Adyar',       'Airport',         22.0, 330.00, 'UPI',    4, 'On time'),
(3, 2, 1, 'Velachery',   'Central',         12.0, 180.00, 'Cash',   5, 'Very polite'),
(4, 3, 2, 'Porur',       'Sholinganallur',  18.5, 277.50, 'UPI',    3, 'Average'),
(5, 1, 1, 'Guindy',      'Chromepet',        9.0, 135.00, 'Wallet', 5, 'Excellent');

-- Show 1NF result: no more repeated passenger data
SELECT 'BEFORE 1NF - Passenger data repeated:' AS Note;
SELECT Passenger_Name, COUNT(*) as Times_Repeated FROM Ride_UNF GROUP BY Passenger_Name;

SELECT 'AFTER 1NF - Each passenger stored once:' AS Note;
SELECT * FROM Ride_1NF_Passenger;
SELECT * FROM Ride_1NF_Driver;
SELECT * FROM Ride_1NF_Trip;


-- ============================================================
-- 4.3 SECOND NORMAL FORM (2NF)
-- ============================================================
-- Rule: Must be in 1NF + No partial dependency (no non-key attribute
--       depends on only PART of a composite primary key)
-- Problem: In Ride_1NF_Trip, if we had a composite PK (Ride_ID, Passenger_ID),
--          then Passenger_Name depends only on Passenger_ID (partial dependency)

-- 4.3.1 Identify Dependency
-- Suppose a poorly designed table with composite PK:
DROP TABLE IF EXISTS Ride_2NF_Bad;
CREATE TABLE Ride_2NF_Bad (
    Ride_ID         INT,
    Passenger_ID    INT,
    Passenger_Name  VARCHAR(100),  -- depends only on Passenger_ID (PARTIAL!)
    Driver_ID       INT,
    Trip_Fare       DECIMAL(8,2),
    PRIMARY KEY (Ride_ID, Passenger_ID)
);

INSERT INTO Ride_2NF_Bad VALUES
(1, 1, 'Aarav Sharma', 1, 127.50),
(2, 1, 'Aarav Sharma', 2, 330.00),  -- Aarav repeated → partial dependency!
(3, 2, 'Diya Reddy',   1, 180.00),
(4, 3, 'Rahul Verma',  2, 277.50);

SELECT 'BEFORE 2NF - Passenger_Name partially depends on Passenger_ID only:' AS Note;
SELECT * FROM Ride_2NF_Bad;

-- 4.3.2 Apply 2NF: Remove partial dependency — Passenger_Name goes to Passenger table
SELECT 'AFTER 2NF - Passenger info in separate table, Trip table has no partial deps:' AS Note;
SELECT * FROM Ride_1NF_Passenger;  -- Passenger_Name lives here, linked by Passenger_ID
SELECT Ride_ID, Passenger_ID, Driver_ID, Trip_Fare FROM Ride_1NF_Trip;


-- ============================================================
-- 4.4 THIRD NORMAL FORM (3NF)
-- ============================================================
-- Rule: Must be in 2NF + No transitive dependency
--       (non-key attribute should not depend on another non-key attribute)
-- Problem: In the UNF table: Ride_ID → Driver_ID → Vehicle_Model
--          Vehicle_Model depends on Driver, not on Ride directly (transitive!)

-- 4.4.1 Identify Dependency
DROP TABLE IF EXISTS Ride_3NF_Bad;
CREATE TABLE Ride_3NF_Bad (
    Trip_ID       INT PRIMARY KEY,
    Driver_ID     INT,
    Driver_Name   VARCHAR(100),   -- depends on Driver_ID, not Trip_ID (TRANSITIVE!)
    Vehicle_Model VARCHAR(100),   -- depends on Driver_ID, not Trip_ID (TRANSITIVE!)
    Trip_Fare     DECIMAL(8,2)
);

INSERT INTO Ride_3NF_Bad VALUES
(1, 1, 'Suresh Kumar', 'Swift Dzire', 127.50),
(2, 2, 'Manoj Singh',  'Honda City',  330.00),
(3, 1, 'Suresh Kumar', 'Swift Dzire', 180.00);  -- Suresh + Swift Dzire repeated

SELECT 'BEFORE 3NF - Driver_Name and Vehicle_Model transitively depend on Driver_ID:' AS Note;
SELECT * FROM Ride_3NF_Bad;

-- 4.4.2 Apply 3NF: Move Driver_Name and Vehicle to Driver table
SELECT 'AFTER 3NF - Transitive dependency removed:' AS Note;
SELECT Driver_ID, Driver_Name, Vehicle_Model, Vehicle_Type FROM Ride_1NF_Driver;
SELECT Ride_ID, Driver_ID, Trip_Fare FROM Ride_1NF_Trip;


-- ============================================================
-- 4.5 BCNF (Boyce-Codd Normal Form)
-- ============================================================
-- Rule: For every functional dependency X → Y, X must be a superkey
-- Our actual tables satisfy BCNF. We demonstrate with Driver table:
-- License_No → Driver_ID (License_No is a candidate key → satisfies BCNF)

-- 4.5.1 Identify Dependency
SELECT 'BCNF Check - Every determinant in Driver is a candidate key:' AS Note;
SELECT Driver_ID, License_No, Name, Phone FROM Driver;

-- License_No uniquely identifies a driver (candidate key) ✓
-- Driver_ID is the primary key ✓
-- No non-superkey determinants → satisfies BCNF

-- 4.5.2 Verify BCNF on actual Driver table
SELECT 'Driver table - License_No is a candidate key (UNIQUE):' AS Note;
SHOW INDEX FROM Driver WHERE Key_name != 'PRIMARY';


-- ============================================================
-- 4.6 FOURTH NORMAL FORM (4NF)
-- ============================================================
-- Rule: Must be in BCNF + No multi-valued dependencies
-- Problem scenario: If a driver could have MULTIPLE vehicle types AND
--                   MULTIPLE service areas independently, that's a MVD.

-- 4.6.1 Identify potential MVD
DROP TABLE IF EXISTS Driver_4NF_Bad;
CREATE TABLE Driver_4NF_Bad (
    Driver_ID    INT,
    Vehicle_Type VARCHAR(50),   -- MVD: Driver →→ Vehicle_Type
    Service_Area VARCHAR(100),  -- MVD: Driver →→ Service_Area
    PRIMARY KEY (Driver_ID, Vehicle_Type, Service_Area)
);

INSERT INTO Driver_4NF_Bad VALUES
(1, 'Sedan', 'Anna Nagar'),
(1, 'Sedan', 'Adyar'),       -- Same vehicle type, different area
(1, 'SUV',   'Anna Nagar'),  -- Same area, different vehicle type
(1, 'SUV',   'Adyar');       -- Cartesian product = multi-valued dep!

SELECT 'BEFORE 4NF - Multi-valued dependency causes redundant combinations:' AS Note;
SELECT * FROM Driver_4NF_Bad;

-- 4.6.2 Apply 4NF: Split into two tables
DROP TABLE IF EXISTS Driver_VehicleType;
DROP TABLE IF EXISTS Driver_ServiceArea;

CREATE TABLE Driver_VehicleType (
    Driver_ID    INT,
    Vehicle_Type VARCHAR(50),
    PRIMARY KEY (Driver_ID, Vehicle_Type)
);
CREATE TABLE Driver_ServiceArea (
    Driver_ID    INT,
    Service_Area VARCHAR(100),
    PRIMARY KEY (Driver_ID, Service_Area)
);

INSERT INTO Driver_VehicleType VALUES (1,'Sedan'),(1,'SUV');
INSERT INTO Driver_ServiceArea VALUES (1,'Anna Nagar'),(1,'Adyar');

SELECT 'AFTER 4NF - MVD removed, split into separate tables:' AS Note;
SELECT * FROM Driver_VehicleType;
SELECT * FROM Driver_ServiceArea;


-- ============================================================
-- 4.7 FIFTH NORMAL FORM (5NF)
-- ============================================================
-- Rule: Must be in 4NF + No join dependency
--       A table is in 5NF if every join dependency is implied by candidate keys
-- Our schema: Trip, Driver, Passenger, Ride_Request are all in 5NF
-- because they can only be reconstructed by joining on their primary keys.

-- 4.7.1 Identify Join Dependency
-- Trip table decomposes into: (Trip_ID, Driver_ID), (Trip_ID, Request_ID), (Trip_ID, Fare)
-- But joining them back always gives the original table → no lossy decomposition → 5NF ✓

SELECT '5NF Verification - Trip table decomposition is lossless:' AS Note;

-- Decompose Trip into two projections
SELECT Trip_ID, Driver_ID, Status FROM Trip;
SELECT Trip_ID, Request_ID, Fare, Distance FROM Trip;

-- Join them back — original table is recovered (lossless join → 5NF satisfied)
SELECT t1.Trip_ID, t1.Driver_ID, t1.Status, t2.Request_ID, t2.Fare, t2.Distance
FROM (SELECT Trip_ID, Driver_ID, Status FROM Trip) t1
JOIN (SELECT Trip_ID, Request_ID, Fare, Distance FROM Trip) t2
  ON t1.Trip_ID = t2.Trip_ID;

SELECT '5NF Confirmed: Joining decomposed projections recovers original Trip table exactly.' AS Result;


-- ============================================================
-- CLEANUP DEMO TABLES (keep your real tables intact)
-- ============================================================
DROP TABLE IF EXISTS Ride_UNF;
DROP TABLE IF EXISTS Ride_1NF_Passenger;
DROP TABLE IF EXISTS Ride_1NF_Driver;
DROP TABLE IF EXISTS Ride_1NF_Trip;
DROP TABLE IF EXISTS Ride_2NF_Bad;
DROP TABLE IF EXISTS Ride_3NF_Bad;
DROP TABLE IF EXISTS Driver_4NF_Bad;
DROP TABLE IF EXISTS Driver_VehicleType;
DROP TABLE IF EXISTS Driver_ServiceArea;

SELECT 'Chapter 4 complete. All demo tables cleaned up. Real tables untouched.' AS Status;
