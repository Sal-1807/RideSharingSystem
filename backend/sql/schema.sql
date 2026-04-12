-- ============================================================
-- RIDE SHARING SYSTEM - COMPLETE DATABASE SCHEMA
-- 21CSC205P Database Management Systems Mini Project
-- ============================================================

CREATE DATABASE IF NOT EXISTS RideSharingSystem;
USE RideSharingSystem;

-- ============================================================
-- TABLE CREATION (DDL)
-- ============================================================

-- Admin table (no foreign dependencies, create first)
CREATE TABLE IF NOT EXISTS Admin (
    Admin_ID   INT          PRIMARY KEY AUTO_INCREMENT,
    Name       VARCHAR(100) NOT NULL,
    Role       VARCHAR(50)  NOT NULL,
    Contact    VARCHAR(100),
    Password   VARCHAR(255) NOT NULL DEFAULT 'admin123'
);

-- Passenger table
CREATE TABLE IF NOT EXISTS Passenger (
    Passenger_ID INT          PRIMARY KEY AUTO_INCREMENT,
    Name         VARCHAR(100) NOT NULL,
    Phone        VARCHAR(15)  NOT NULL,
    Email        VARCHAR(100) NOT NULL UNIQUE,
    Password     VARCHAR(255) NOT NULL
);

-- Driver table
CREATE TABLE IF NOT EXISTS Driver (
    Driver_ID    INT          PRIMARY KEY AUTO_INCREMENT,
    Name         VARCHAR(100) NOT NULL,
    License_No   VARCHAR(50)  NOT NULL UNIQUE,
    Phone        VARCHAR(15)  NOT NULL,
    Email        VARCHAR(100) NOT NULL UNIQUE,
    Password     VARCHAR(255) NOT NULL,
    Is_Available TINYINT(1)   DEFAULT 1
);

-- Location table (referenced by Ride_Request)
CREATE TABLE IF NOT EXISTS Location (
    Location_ID INT          PRIMARY KEY AUTO_INCREMENT,
    Address     VARCHAR(255) NOT NULL,
    City        VARCHAR(100) NOT NULL,
    Pincode     VARCHAR(10)  NOT NULL
);

-- Vehicle_Type table
CREATE TABLE IF NOT EXISTS Vehicle_Type (
    Vehicle_Type_ID INT          PRIMARY KEY AUTO_INCREMENT,
    Type_Name       VARCHAR(100) NOT NULL
);

-- Vehicle table (depends on Driver, Vehicle_Type)
CREATE TABLE IF NOT EXISTS Vehicle (
    Vehicle_ID      INT          PRIMARY KEY AUTO_INCREMENT,
    Driver_ID       INT          NOT NULL,
    Vehicle_Type_ID INT,
    Model           VARCHAR(100) NOT NULL,
    Registration_No VARCHAR(50)  NOT NULL UNIQUE,
    FOREIGN KEY (Driver_ID)       REFERENCES Driver(Driver_ID),
    FOREIGN KEY (Vehicle_Type_ID) REFERENCES Vehicle_Type(Vehicle_Type_ID)
);

-- Wallet table (depends on Passenger)
CREATE TABLE IF NOT EXISTS Wallet (
    Wallet_ID    INT           PRIMARY KEY AUTO_INCREMENT,
    Passenger_ID INT           NOT NULL,
    Balance      DECIMAL(10,2) DEFAULT 0.00,
    FOREIGN KEY (Passenger_ID) REFERENCES Passenger(Passenger_ID)
);

-- Ride_Request table (depends on Passenger, Location)
CREATE TABLE IF NOT EXISTS Ride_Request (
    Request_ID          INT         PRIMARY KEY AUTO_INCREMENT,
    Passenger_ID        INT         NOT NULL,
    Pickup_Location_ID  INT         NOT NULL,
    Drop_Location_ID    INT         NOT NULL,
    Request_Time        DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Status              VARCHAR(50) NOT NULL DEFAULT 'Pending',
    FOREIGN KEY (Passenger_ID)       REFERENCES Passenger(Passenger_ID),
    FOREIGN KEY (Pickup_Location_ID) REFERENCES Location(Location_ID),
    FOREIGN KEY (Drop_Location_ID)   REFERENCES Location(Location_ID)
);

-- Trip table (depends on Ride_Request, Driver, Vehicle)
CREATE TABLE IF NOT EXISTS Trip (
    Trip_ID    INT           PRIMARY KEY AUTO_INCREMENT,
    Request_ID INT           NOT NULL,
    Driver_ID  INT           NOT NULL,
    Vehicle_ID INT           NOT NULL,
    Start_Time DATETIME,
    End_Time   DATETIME,
    Distance   DECIMAL(6,2),
    Fare       DECIMAL(8,2),
    Status     VARCHAR(50)   DEFAULT 'Ongoing',
    FOREIGN KEY (Request_ID) REFERENCES Ride_Request(Request_ID),
    FOREIGN KEY (Driver_ID)  REFERENCES Driver(Driver_ID),
    FOREIGN KEY (Vehicle_ID) REFERENCES Vehicle(Vehicle_ID)
);

-- Payment table (depends on Trip, Wallet)
CREATE TABLE IF NOT EXISTS Payment (
    Payment_ID     INT           PRIMARY KEY AUTO_INCREMENT,
    Trip_ID        INT           NOT NULL,
    Wallet_ID      INT,
    Amount         DECIMAL(8,2)  NOT NULL,
    Payment_Mode   VARCHAR(50)   NOT NULL,
    Payment_Status VARCHAR(50)   NOT NULL DEFAULT 'Pending',
    FOREIGN KEY (Trip_ID)   REFERENCES Trip(Trip_ID),
    FOREIGN KEY (Wallet_ID) REFERENCES Wallet(Wallet_ID)
);

-- Rating_Review table (depends on Trip, Passenger, Driver)
CREATE TABLE IF NOT EXISTS Rating_Review (
    Rating_ID        INT          PRIMARY KEY AUTO_INCREMENT,
    Trip_ID          INT          NOT NULL,
    Passenger_ID     INT          NOT NULL,
    Driver_ID        INT          NOT NULL,
    Passenger_Rating INT,
    Driver_Rating    INT,
    Comments         VARCHAR(255),
    CONSTRAINT chk_passenger_rating CHECK (Passenger_Rating BETWEEN 1 AND 5),
    CONSTRAINT chk_driver_rating    CHECK (Driver_Rating    BETWEEN 1 AND 5),
    FOREIGN KEY (Trip_ID)      REFERENCES Trip(Trip_ID),
    FOREIGN KEY (Passenger_ID) REFERENCES Passenger(Passenger_ID),
    FOREIGN KEY (Driver_ID)    REFERENCES Driver(Driver_ID)
);

-- Cancellation_Details table (depends on Trip)
CREATE TABLE IF NOT EXISTS Cancellation_Details (
    Cancellation_ID  INT           PRIMARY KEY AUTO_INCREMENT,
    Trip_ID          INT           NOT NULL,
    Cancelled_By     VARCHAR(50)   NOT NULL,
    Cancellation_Time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Cancellation_Fee DECIMAL(6,2),
    FOREIGN KEY (Trip_ID) REFERENCES Trip(Trip_ID)
);

-- Promo_Details table (no foreign dependencies)
CREATE TABLE IF NOT EXISTS Promo_Details (
    Promo_ID            INT          PRIMARY KEY AUTO_INCREMENT,
    Code                VARCHAR(50)  NOT NULL UNIQUE,
    Discount_Percentage DECIMAL(5,2),
    Expiry_Date         DATE
);

-- Support_Ticket table
CREATE TABLE IF NOT EXISTS Support_Ticket (
    Ticket_ID         INT         PRIMARY KEY AUTO_INCREMENT,
    User_ID           INT         NOT NULL,
    User_Type         VARCHAR(50) NOT NULL,
    Issue_Description TEXT        NOT NULL,
    Status            VARCHAR(50) NOT NULL DEFAULT 'Open',
    Created_At        DATETIME    DEFAULT CURRENT_TIMESTAMP
);

-- Route_Details table (depends on Trip)
CREATE TABLE IF NOT EXISTS Route_Details (
    Trip_ID          INT           NOT NULL,
    Route_No         INT           NOT NULL,
    Pickup_Location  VARCHAR(100),
    Drop_Location    VARCHAR(100),
    Distance_KM      DECIMAL(5,2),
    Duration_Min     INT,
    PRIMARY KEY (Trip_ID, Route_No),
    FOREIGN KEY (Trip_ID) REFERENCES Trip(Trip_ID) ON DELETE CASCADE,
    CONSTRAINT chk_distance_positive CHECK (Distance_KM > 0)
);

-- ============================================================
-- SAMPLE DATA (DML)
-- ============================================================

INSERT IGNORE INTO Admin (Name, Role, Contact, Password) VALUES
('Admin Raj', 'System Admin', 'admin@rideshare.com', 'admin123');

INSERT IGNORE INTO Vehicle_Type (Type_Name) VALUES
('Sedan'), ('SUV'), ('Mini'), ('Auto');

INSERT IGNORE INTO Promo_Details (Code, Discount_Percentage, Expiry_Date) VALUES
('NEWUSER10', 10.00, '2026-12-31'),
('SAVE20',    20.00, '2026-06-30');

INSERT IGNORE INTO Location (Address, City, Pincode) VALUES
('MG Road',      'Hyderabad', '500001'),
('Banjara Hills','Hyderabad', '500034'),
('Hitech City',  'Hyderabad', '500081'),
('Gachibowli',   'Hyderabad', '500032'),
('Madhapur',     'Hyderabad', '500081');

-- ============================================================
-- VIEWS (Chapter 3.6)
-- ============================================================

CREATE OR REPLACE VIEW Trip_Details_View AS
SELECT
    t.Trip_ID,
    p.Name       AS Passenger_Name,
    d.Name       AS Driver_Name,
    t.Fare,
    t.Distance,
    t.Status,
    t.Start_Time,
    t.End_Time
FROM Trip t
JOIN Ride_Request rr ON t.Request_ID = rr.Request_ID
JOIN Passenger    p  ON rr.Passenger_ID = p.Passenger_ID
JOIN Driver       d  ON t.Driver_ID = d.Driver_ID;

CREATE OR REPLACE VIEW High_Payments AS
SELECT Trip_ID, Amount, Payment_Mode, Payment_Status
FROM Payment
WHERE Amount > 300;

CREATE OR REPLACE VIEW Trip_Ratings AS
SELECT
    t.Trip_ID,
    rr.Passenger_Rating,
    rr.Driver_Rating,
    rr.Comments
FROM Trip t
JOIN Rating_Review rr ON t.Trip_ID = rr.Trip_ID;

-- ============================================================
-- TRIGGERS (Chapter 3.7)
-- ============================================================

-- Trigger 1: Update trip status to Completed after payment inserted
DROP TRIGGER IF EXISTS trg_update_trip_status;
DELIMITER $$
CREATE TRIGGER trg_update_trip_status
AFTER INSERT ON Payment
FOR EACH ROW
BEGIN
    UPDATE Trip
    SET Status = 'Completed'
    WHERE Trip_ID = NEW.Trip_ID;
END$$
DELIMITER ;

-- Trigger 2: Validate rating values before insert
DROP TRIGGER IF EXISTS trg_check_rating;
DELIMITER $$
CREATE TRIGGER trg_check_rating
BEFORE INSERT ON Rating_Review
FOR EACH ROW
BEGIN
    IF NEW.Passenger_Rating < 1 OR NEW.Passenger_Rating > 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid Passenger Rating: must be between 1 and 5';
    END IF;
    IF NEW.Driver_Rating < 1 OR NEW.Driver_Rating > 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid Driver Rating: must be between 1 and 5';
    END IF;
END$$
DELIMITER ;

-- Trigger 3: Deduct wallet balance after wallet payment
DROP TRIGGER IF EXISTS trg_update_wallet;
DELIMITER $$
CREATE TRIGGER trg_update_wallet
AFTER INSERT ON Payment
FOR EACH ROW
BEGIN
    IF NEW.Payment_Mode = 'Wallet' THEN
        UPDATE Wallet
        SET Balance = Balance - NEW.Amount
        WHERE Passenger_ID = (
            SELECT rr.Passenger_ID
            FROM Ride_Request rr
            JOIN Trip t ON t.Request_ID = rr.Request_ID
            WHERE t.Trip_ID = NEW.Trip_ID
        );
    END IF;
END$$
DELIMITER ;

-- ============================================================
-- STORED PROCEDURES / CURSORS (Chapter 3.8)
-- ============================================================

-- Procedure 1: Print all trip IDs and fares
DROP PROCEDURE IF EXISTS show_trip_fares;
DELIMITER $$
CREATE PROCEDURE show_trip_fares()
BEGIN
    DECLARE done      INT           DEFAULT 0;
    DECLARE vTripID   INT;
    DECLARE vFare     DECIMAL(10,2);
    DECLARE trip_cursor CURSOR FOR
        SELECT Trip_ID, Fare FROM Trip;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN trip_cursor;
    read_loop: LOOP
        FETCH trip_cursor INTO vTripID, vFare;
        IF done THEN LEAVE read_loop; END IF;
        SELECT CONCAT('Trip: ', vTripID, ', Fare: Rs.', vFare) AS Trip_Info;
    END LOOP;
    CLOSE trip_cursor;
END$$
DELIMITER ;

-- Procedure 2: Flag trips with distance > 15 km
DROP PROCEDURE IF EXISTS show_high_distance_trips;
DELIMITER $$
CREATE PROCEDURE show_high_distance_trips()
BEGIN
    DECLARE done      INT          DEFAULT 0;
    DECLARE vTripID   INT;
    DECLARE vDistance DECIMAL(5,2);
    DECLARE trip_cursor CURSOR FOR
        SELECT Trip_ID, Distance_KM
        FROM Route_Details
        WHERE Distance_KM > 15;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN trip_cursor;
    read_loop: LOOP
        FETCH trip_cursor INTO vTripID, vDistance;
        IF done THEN LEAVE read_loop; END IF;
        SELECT CONCAT('Trip ID: ', vTripID, ' | Distance: ', vDistance, ' KM') AS Trip_Info;
    END LOOP;
    CLOSE trip_cursor;
END$$
DELIMITER ;

-- Procedure 3: Print each driver's total trip count
DROP PROCEDURE IF EXISTS show_driver_trips;
DELIMITER $$
CREATE PROCEDURE show_driver_trips()
BEGIN
    DECLARE done        INT DEFAULT 0;
    DECLARE vDriverID   INT;
    DECLARE totalTrips  INT;
    DECLARE driver_cursor CURSOR FOR
        SELECT Driver_ID FROM Driver;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN driver_cursor;
    read_loop: LOOP
        FETCH driver_cursor INTO vDriverID;
        IF done THEN LEAVE read_loop; END IF;
        SELECT COUNT(*) INTO totalTrips FROM Trip WHERE Driver_ID = vDriverID;
        SELECT CONCAT('Driver ID: ', vDriverID, ' | Total Trips: ', totalTrips) AS Driver_Trips;
    END LOOP;
    CLOSE driver_cursor;
END$$
DELIMITER ;
