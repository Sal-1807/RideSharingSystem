-- ============================================================
-- CHAPTER 4: NORMALIZATION - RideShare System
-- 21CSC205P DBMS Mini Project
-- ============================================================

USE RideSharingSystem;

-- ============================================================
-- 4.1 ANALYSE THE PITFALLS (Unnormalized Flat Table)
-- ============================================================

DROP TABLE IF EXISTS RideBooking_UNF;
CREATE TABLE RideBooking_UNF (
    BookingID         INT PRIMARY KEY,
    CustomerID        INT,
    CustomerName      VARCHAR(100),
    CustomerPhone     VARCHAR(15),
    CustomerEmail     VARCHAR(100),
    DriverID          INT,
    DriverName        VARCHAR(100),
    DriverPhone       VARCHAR(15),
    LicenseNo         VARCHAR(50),
    DriverSkills      VARCHAR(255),   -- NON-ATOMIC: stores multiple skills
    VehicleModel      VARCHAR(100),
    VehicleType       VARCHAR(50),
    PickupLocation    VARCHAR(255),
    DropLocation      VARCHAR(255),
    BookingDate       DATE,
    PaymentAmount     DECIMAL(8,2),
    PaymentStatus     VARCHAR(20),
    DriverRating      INT,
    ReviewComment     VARCHAR(255)
);

INSERT INTO RideBooking_UNF VALUES
(1, 1, 'Aarav Sharma',  '9876543210', 'aarav@gmail.com',  1, 'Suresh Kumar', '9000011111', 'DL12345', 'City Driving, Highway', 'Swift Dzire', 'Sedan', 'Anna Nagar',   'T Nagar',    '2026-04-01', 127.50, 'Completed', 5, 'Excellent service'),
(2, 2, 'Diya Reddy',   '9123456780', 'diya@gmail.com',   2, 'Manoj Singh',  '9000022222', 'DL67890', 'City Driving',         'Honda City',  'Sedan', 'Adyar',        'Airport',    '2026-04-02', 330.00, 'Completed', 4, 'Good trip'),
(3, 1, 'Aarav Sharma',  '9876543210', 'aarav@gmail.com',  1, 'Suresh Kumar', '9000011111', 'DL12345', 'City Driving, Highway', 'Swift Dzire', 'Sedan', 'Velachery',   'Central',    '2026-04-03', 180.00, 'Completed', 5, 'Very polite');

SELECT * FROM RideBooking_UNF;

-- PITFALLS:
-- INSERTION ANOMALY:  Cannot add a new driver until they have a booking.
--                     DriverID 3 with no trips cannot be stored.
-- DELETION ANOMALY:   Deleting Diya's booking (row 2) erases all info about Manoj Singh.
-- UPDATE ANOMALY:     Suresh Kumar appears in rows 1 and 3.
--                     Changing his phone requires updating both rows.
-- DATA REDUNDANCY:    Aarav's phone/email repeated in rows 1 and 3.
-- NON-ATOMIC VALUE:   DriverSkills column stores 'City Driving, Highway' in one cell.


-- ============================================================
-- 4.2 FIRST NORMAL FORM (1NF)
-- ============================================================
-- Rule: All attributes atomic, no repeating groups, each row unique.

-- ============================================================
-- 4.2.1 IDENTIFY DEPENDENCY
-- ============================================================
-- VIOLATION 1: Non-atomic attribute in Driver
--   The DriverSkills column stores multiple skills as a comma-separated string
--   e.g. 'City Driving, Highway'. This violates 1NF because a single cell
--   holds more than one independent fact.

-- VIOLATION 2: Repeating groups in RideBooking
--   A single BookingID is associated with a driver's multiple skills
--   causing repeating groups. Each skill must occupy its own row.

-- ============================================================
-- 4.2.2 APPLY NORMALIZATION TO 1NF
-- ============================================================

-- TABLE 1: Driver
-- Before normalization
DROP TABLE IF EXISTS Driver_Before1NF;
CREATE TABLE Driver_Before1NF (
    DriverID     INT PRIMARY KEY,
    DriverName   VARCHAR(100) NOT NULL,
    Phone        VARCHAR(15),
    Email        VARCHAR(50),
    LicenseNo    VARCHAR(50),
    Skills       VARCHAR(255)   -- NON-ATOMIC: multiple skills in one column
);
INSERT INTO Driver_Before1NF VALUES
(1, 'Suresh Kumar', '9000011111', 'suresh@gmail.com', 'DL12345', 'City Driving, Highway'),
(2, 'Manoj Singh',  '9000022222', 'manoj@gmail.com',  'DL67890', 'City Driving');
SELECT * FROM Driver_Before1NF;

-- After normalization
DROP TABLE IF EXISTS Driver_1NF;
DROP TABLE IF EXISTS DriverSkill_1NF;
CREATE TABLE Driver_1NF (
    DriverID   INT PRIMARY KEY,
    DriverName VARCHAR(100) NOT NULL,
    Phone      VARCHAR(15),
    Email      VARCHAR(50),
    LicenseNo  VARCHAR(50)
    -- Skills column REMOVED → moved to DriverSkill_1NF
);
CREATE TABLE DriverSkill_1NF (
    DriverID  INT,
    SkillName VARCHAR(50),
    PRIMARY KEY (DriverID, SkillName)   -- each skill is one atomic row
);
INSERT INTO Driver_1NF VALUES
(1, 'Suresh Kumar', '9000011111', 'suresh@gmail.com', 'DL12345'),
(2, 'Manoj Singh',  '9000022222', 'manoj@gmail.com',  'DL67890');
INSERT INTO DriverSkill_1NF VALUES
(1, 'City Driving'),
(1, 'Highway'),
(2, 'City Driving');
SELECT * FROM Driver_1NF;
SELECT * FROM DriverSkill_1NF;


-- TABLE 2: RideBooking
-- Before normalization
DROP TABLE IF EXISTS RideBooking_Before1NF;
CREATE TABLE RideBooking_Before1NF (
    BookingID       INT PRIMARY KEY,
    CustomerID      INT,
    DriverID        INT,
    VehicleType     VARCHAR(50),     -- repeating vehicle info inline
    PickupLocation  VARCHAR(255),
    DropLocation    VARCHAR(255),
    BookingDate     DATE
);
INSERT INTO RideBooking_Before1NF VALUES
(1, 1, 1, 'Sedan', 'Anna Nagar', 'T Nagar',   '2026-04-01'),
(2, 2, 2, 'Sedan', 'Adyar',      'Airport',   '2026-04-02'),
(3, 1, 1, 'Sedan', 'Velachery',  'Central',   '2026-04-03');
SELECT * FROM RideBooking_Before1NF;

-- After normalization: VehicleType moves to a separate table, BookingID is atomic FK
DROP TABLE IF EXISTS RideBooking_1NF;
CREATE TABLE RideBooking_1NF (
    BookingID      INT PRIMARY KEY,
    CustomerID     INT,
    DriverID       INT,           -- atomic FK reference only
    PickupLocation VARCHAR(255),
    DropLocation   VARCHAR(255),
    BookingDate    DATE
);
INSERT INTO RideBooking_1NF VALUES
(1, 1, 1, 'Anna Nagar', 'T Nagar',   '2026-04-01'),
(2, 2, 2, 'Adyar',      'Airport',   '2026-04-02'),
(3, 1, 1, 'Velachery',  'Central',   '2026-04-03');
SELECT * FROM RideBooking_1NF;
SELECT * FROM Driver_1NF;


-- ============================================================
-- 4.3 SECOND NORMAL FORM (2NF)
-- ============================================================
-- Rule: 1NF + No partial dependency on a composite primary key.

-- ============================================================
-- 4.3.1 IDENTIFY DEPENDENCY
-- ============================================================
-- VIOLATION 1: Partial dependency in TripAssignment
--   PK = (TripID, DriverID) [composite]
--   TripID → PickupLocation, DropLocation, BookingDate  (partial — only TripID)
--   DriverID → DriverName, DriverPhone                  (partial — only DriverID)
--   (TripID, DriverID) → AssignedDate                   (full dependency — OK)

-- VIOLATION 2: Partial dependency in RideRequest
--   PK = (RequestID, LocationID) [composite as designed here]
--   LocationID → Address, City            (partial — only LocationID)
--   RequestID → RequestTime, Status       (partial — only RequestID)

-- ============================================================
-- 4.3.2 APPLY NORMALIZATION TO 2NF
-- ============================================================

-- TABLE 1: TripAssignment
-- Before normalization
DROP TABLE IF EXISTS TripAssignment_Before2NF;
CREATE TABLE TripAssignment_Before2NF (
    TripID        INT,
    DriverID      INT,
    PickupLocation VARCHAR(100),   -- depends only on TripID (partial)
    DropLocation  VARCHAR(100),    -- depends only on TripID (partial)
    DriverName    VARCHAR(100),    -- depends only on DriverID (partial)
    DriverPhone   VARCHAR(15),     -- depends only on DriverID (partial)
    AssignedDate  DATE,            -- depends on full (TripID, DriverID) — OK
    PRIMARY KEY (TripID, DriverID)
);
INSERT INTO TripAssignment_Before2NF VALUES
(1, 1, 'Anna Nagar', 'T Nagar',  'Suresh Kumar', '9000011111', '2026-04-01'),
(2, 2, 'Adyar',      'Airport',  'Manoj Singh',  '9000022222', '2026-04-02'),
(3, 1, 'Velachery',  'Central',  'Suresh Kumar', '9000011111', '2026-04-03');
SELECT * FROM TripAssignment_Before2NF;

-- After normalization: split out the partially dependent attributes
DROP TABLE IF EXISTS Trip_2NF;
DROP TABLE IF EXISTS Driver_2NF;
DROP TABLE IF EXISTS TripAssignment_2NF;
CREATE TABLE Trip_2NF (
    TripID         INT PRIMARY KEY,
    PickupLocation VARCHAR(100),
    DropLocation   VARCHAR(100),
    BookingDate    DATE
);
CREATE TABLE Driver_2NF (
    DriverID    INT PRIMARY KEY,
    DriverName  VARCHAR(100) NOT NULL,
    DriverPhone VARCHAR(15)
);
CREATE TABLE TripAssignment_2NF (
    TripID       INT,
    DriverID     INT,
    AssignedDate DATE,
    PRIMARY KEY (TripID, DriverID)
);
INSERT INTO Trip_2NF VALUES
(1,'Anna Nagar','T Nagar','2026-04-01'),
(2,'Adyar','Airport','2026-04-02'),
(3,'Velachery','Central','2026-04-03');
INSERT INTO Driver_2NF VALUES
(1,'Suresh Kumar','9000011111'),
(2,'Manoj Singh','9000022222');
INSERT INTO TripAssignment_2NF VALUES (1,1,'2026-04-01'),(2,2,'2026-04-02'),(3,1,'2026-04-03');
SELECT * FROM Trip_2NF;
SELECT * FROM Driver_2NF;
SELECT * FROM TripAssignment_2NF;


-- TABLE 2: RideRequest
-- Before normalization
DROP TABLE IF EXISTS RideRequest_Before2NF;
CREATE TABLE RideRequest_Before2NF (
    RequestID      INT,
    LocationID     INT,
    Address        VARCHAR(255),    -- depends only on LocationID (partial)
    City           VARCHAR(100),    -- depends only on LocationID (partial)
    CustomerID     INT,             -- depends only on RequestID (partial)
    RequestDate    DATE,            -- depends only on RequestID (partial)
    RequestStatus  VARCHAR(20),     -- depends only on RequestID (partial)
    PRIMARY KEY (RequestID, LocationID)
);
INSERT INTO RideRequest_Before2NF VALUES
(1,1,'Anna Nagar','Chennai',  1,'2026-04-01','Confirmed'),
(2,2,'Adyar',     'Chennai',  2,'2026-04-02','Confirmed');
SELECT * FROM RideRequest_Before2NF;

-- After normalization: separate tables for each partial dependency
DROP TABLE IF EXISTS Location_2NF;
DROP TABLE IF EXISTS RideRequest_2NF;
CREATE TABLE Location_2NF (
    LocationID INT PRIMARY KEY,
    Address    VARCHAR(255),
    City       VARCHAR(100)
);
CREATE TABLE RideRequest_2NF (
    RequestID     INT PRIMARY KEY,
    LocationID    INT,
    CustomerID    INT,
    RequestDate   DATE,
    RequestStatus VARCHAR(20),
    FOREIGN KEY (LocationID) REFERENCES Location_2NF(LocationID)
);
INSERT INTO Location_2NF VALUES (1,'Anna Nagar','Chennai'),(2,'Adyar','Chennai');
INSERT INTO RideRequest_2NF VALUES (1,1,1,'2026-04-01','Confirmed'),(2,2,2,'2026-04-02','Confirmed');
SELECT * FROM Location_2NF;
SELECT * FROM RideRequest_2NF;


-- ============================================================
-- 4.4 THIRD NORMAL FORM (3NF)
-- ============================================================
-- Rule: 2NF + No transitive dependency (non-key → non-key → attribute).

-- ============================================================
-- 4.4.1 IDENTIFY DEPENDENCY
-- ============================================================
-- VIOLATION 1: Transitive dependency in Vehicle
--   Vehicle_ID → Vehicle_Type_ID  (direct — OK)
--   Vehicle_Type_ID → Type_Name   (transitive — non-key to non-key)
--   Chain: Vehicle_ID → Vehicle_Type_ID → Type_Name
--   Storing Type_Name directly in Vehicle causes update anomaly.

-- VIOLATION 2: Transitive dependency in Payment
--   Payment_ID → Trip_ID           (direct — OK)
--   Trip_ID → Passenger_ID         (transitive — non-key to non-key)
--   Chain: Payment_ID → Trip_ID → Passenger_ID
--   Storing Passenger_ID in Payment is redundant since it can be
--   derived through Trip → Ride_Request → Passenger.

-- ============================================================
-- 4.4.2 APPLY NORMALIZATION TO 3NF
-- ============================================================

-- TABLE 1: Vehicle
-- Before normalization
DROP TABLE IF EXISTS Vehicle_Before3NF;
CREATE TABLE Vehicle_Before3NF (
    VehicleID     INT PRIMARY KEY,
    DriverID      INT,
    Model         VARCHAR(100),
    VehicleTypeID INT,
    TypeName      VARCHAR(50)    -- TRANSITIVE: depends on VehicleTypeID, not VehicleID
);
INSERT INTO Vehicle_Before3NF VALUES
(1,1,'Swift Dzire',1,'Sedan'),
(2,2,'Honda City', 1,'Sedan'),   -- 'Sedan' repeated
(3,3,'Innova',     2,'SUV');
SELECT * FROM Vehicle_Before3NF;

-- After normalization: extract TypeName into its own table
DROP TABLE IF EXISTS VehicleType_3NF;
DROP TABLE IF EXISTS Vehicle_3NF;
CREATE TABLE VehicleType_3NF (
    VehicleTypeID INT PRIMARY KEY,
    TypeName      VARCHAR(50) NOT NULL
);
CREATE TABLE Vehicle_3NF (
    VehicleID     INT PRIMARY KEY,
    DriverID      INT,
    Model         VARCHAR(100),
    VehicleTypeID INT,
    FOREIGN KEY (VehicleTypeID) REFERENCES VehicleType_3NF(VehicleTypeID)
    -- TypeName is GONE from here — no transitive dependency
);
INSERT INTO VehicleType_3NF VALUES (1,'Sedan'),(2,'SUV');
INSERT INTO Vehicle_3NF VALUES (1,1,'Swift Dzire',1),(2,2,'Honda City',1),(3,3,'Innova',2);
SELECT * FROM VehicleType_3NF;
SELECT * FROM Vehicle_3NF;

-- Reconstruct full view with no data loss
SELECT v.VehicleID, v.DriverID, v.Model, vt.TypeName
FROM Vehicle_3NF v JOIN VehicleType_3NF vt ON v.VehicleTypeID = vt.VehicleTypeID;


-- TABLE 2: Payment
-- Before normalization
DROP TABLE IF EXISTS Payment_Before3NF;
CREATE TABLE Payment_Before3NF (
    PaymentID     INT PRIMARY KEY,
    TripID        INT,
    PassengerID   INT,            -- TRANSITIVE: PaymentID→TripID→PassengerID
    Amount        DECIMAL(10,2),
    PaymentDate   DATE,
    PaymentStatus VARCHAR(20)
);
INSERT INTO Payment_Before3NF VALUES
(1,1,1,127.50,'2026-04-01','Completed'),
(2,2,2,330.00,'2026-04-02','Completed');
SELECT * FROM Payment_Before3NF;

-- After normalization: remove PassengerID from Payment (it belongs in Trip/RideRequest)
DROP TABLE IF EXISTS Booking_3NF;
DROP TABLE IF EXISTS Payment_3NF;
CREATE TABLE Booking_3NF (
    TripID      INT PRIMARY KEY,
    PassengerID INT,             -- PassengerID lives here, not in Payment
    DriverID    INT,
    BookingDate DATE
);
CREATE TABLE Payment_3NF (
    PaymentID     INT PRIMARY KEY,
    TripID        INT,
    Amount        DECIMAL(10,2) NOT NULL,
    PaymentDate   DATE NOT NULL,
    PaymentStatus VARCHAR(20),
    FOREIGN KEY (TripID) REFERENCES Booking_3NF(TripID)
    -- PassengerID REMOVED — no transitive dependency remains
);
INSERT INTO Booking_3NF VALUES (1,1,1,'2026-04-01'),(2,2,2,'2026-04-02');
INSERT INTO Payment_3NF VALUES (1,1,127.50,'2026-04-01','Completed'),(2,2,330.00,'2026-04-02','Completed');
SELECT * FROM Booking_3NF;
SELECT * FROM Payment_3NF;

-- Reconstruct PassengerID through join when needed (no data lost)
SELECT p.PaymentID, b.PassengerID, p.Amount, p.PaymentStatus
FROM Payment_3NF p JOIN Booking_3NF b ON p.TripID = b.TripID;


-- ============================================================
-- 4.5 BCNF (Boyce-Codd Normal Form)
-- ============================================================
-- Rule: For every non-trivial FD X → Y, X must be a superkey.
-- BCNF is stricter than 3NF. It eliminates anomalies that 3NF
-- still allows when there are overlapping candidate keys.

-- ============================================================
-- 4.5.1 IDENTIFY DEPENDENCY
-- ============================================================
-- BCNF ANALYSIS: Driver table
--   Driver_ID → Name, Phone, Email, LicenseNo (Driver_ID is PK = superkey ✓)
--   Email → Driver_ID, Name, Phone (Email is UNIQUE = candidate key = superkey ✓)
--   LicenseNo → Driver_ID, Name, Phone (UNIQUE = candidate key = superkey ✓)
--   Both Driver_ID, Email, LicenseNo are superkeys → BCNF satisfied.

-- BCNF ANALYSIS: Passenger table
--   Passenger_ID → Name, Phone, Email (PK = superkey ✓)
--   Email → Passenger_ID, Name, Phone (UNIQUE = candidate key = superkey ✓)
--   Both determinants are superkeys → BCNF satisfied.

-- CONCLUSION: After 3NF, all key tables in RideShare satisfy BCNF
-- because every determinant in each table is a superkey.

-- ============================================================
-- 4.5.2 APPLY NORMALIZATION TO BCNF
-- ============================================================

-- TABLE 1: Driver — Already in BCNF
DROP TABLE IF EXISTS Driver_BCNF;
CREATE TABLE Driver_BCNF (
    DriverID   INT PRIMARY KEY,
    DriverName VARCHAR(100) NOT NULL,
    Phone      VARCHAR(15) UNIQUE,   -- candidate key: Phone → all others
    Email      VARCHAR(50) UNIQUE,   -- candidate key: Email → all others
    LicenseNo  VARCHAR(50) UNIQUE,   -- candidate key: LicenseNo → all others
    -- Both DriverID, Phone, Email, LicenseNo are superkeys
    -- Every determinant is a superkey → BCNF satisfied
    Status     VARCHAR(20)
);
INSERT INTO Driver_BCNF VALUES
(1,'Suresh Kumar','9000011111','suresh@gmail.com','DL12345','Active'),
(2,'Manoj Singh', '9000022222','manoj@gmail.com', 'DL67890','Active');
SELECT * FROM Driver_BCNF;

-- TABLE 2: VehicleType — Already in BCNF
DROP TABLE IF EXISTS VehicleType_BCNF;
CREATE TABLE VehicleType_BCNF (
    VehicleTypeID INT PRIMARY KEY,
    TypeName      VARCHAR(40) UNIQUE  -- candidate key: TypeName → VehicleTypeID
    -- Both VehicleTypeID and TypeName are candidate keys (superkeys)
    -- Every determinant is a superkey → BCNF satisfied
);
INSERT INTO VehicleType_BCNF VALUES (1,'Sedan'),(2,'SUV');
SELECT * FROM VehicleType_BCNF;


-- ============================================================
-- 4.6 FOURTH NORMAL FORM (4NF)
-- ============================================================
-- Rule: BCNF + No non-trivial multi-valued dependencies (MVDs).
-- MVD: A →→ B means for each value of A, B takes a set of values
--      independent of all other attributes.

-- ============================================================
-- 4.6.1 IDENTIFY DEPENDENCY
-- ============================================================
-- VIOLATION 1: DriverProfile (Skills + Service Areas)
--   A driver can have multiple vehicle types AND multiple service areas.
--   These two sets are independent of each other:
--   DriverID →→ VehicleType   (independent set)
--   DriverID →→ ServiceArea   (independent set)
--   Storing both in one table forces every (DriverID, VehicleType) to
--   be paired with every (DriverID, ServiceArea):
--   2 vehicle types × 2 areas = 4 rows instead of 4 total facts.

-- VIOLATION 2: PassengerProfile (Contact Phones + Preferred Pickup Areas)
--   PassengerID →→ ContactPhone      (independent set)
--   PassengerID →→ PreferredPickup   (independent set)

-- ============================================================
-- 4.6.2 APPLY NORMALIZATION TO 4NF
-- ============================================================

-- TABLE 1: DriverProfile
-- Before normalization
DROP TABLE IF EXISTS DriverProfile_Before4NF;
CREATE TABLE DriverProfile_Before4NF (
    DriverID    INT,
    VehicleType VARCHAR(50),
    ServiceArea VARCHAR(100),
    PRIMARY KEY (DriverID, VehicleType, ServiceArea)
    -- REDUNDANCY: rows explode due to independent multi-valued facts
);
INSERT INTO DriverProfile_Before4NF VALUES
(1,'Sedan','Anna Nagar'),
(1,'Sedan','Adyar'),       -- same vehicle type, different area
(1,'SUV',  'Anna Nagar'),  -- same area, different vehicle type
(1,'SUV',  'Adyar'),
(2,'Sedan','Velachery'),
(2,'Sedan','Tambaram'),
(2,'SUV',  'Velachery'),
(2,'SUV',  'Tambaram');
SELECT * FROM DriverProfile_Before4NF;

-- After normalization: separate the two independent multi-valued facts
DROP TABLE IF EXISTS DriverVehicleType_4NF;
DROP TABLE IF EXISTS DriverServiceArea_4NF;
CREATE TABLE DriverVehicleType_4NF (
    DriverID    INT,
    VehicleType VARCHAR(50),
    PRIMARY KEY (DriverID, VehicleType)
);
CREATE TABLE DriverServiceArea_4NF (
    DriverID    INT,
    ServiceArea VARCHAR(100),
    PRIMARY KEY (DriverID, ServiceArea)
);
INSERT INTO DriverVehicleType_4NF VALUES (1,'Sedan'),(1,'SUV'),(2,'Sedan'),(2,'SUV');
INSERT INTO DriverServiceArea_4NF VALUES (1,'Anna Nagar'),(1,'Adyar'),(2,'Velachery'),(2,'Tambaram');
SELECT * FROM DriverVehicleType_4NF;
SELECT * FROM DriverServiceArea_4NF;


-- TABLE 2: PassengerProfile
-- Before normalization
DROP TABLE IF EXISTS PassengerProfile_Before4NF;
CREATE TABLE PassengerProfile_Before4NF (
    PassengerID    INT,
    ContactPhone   VARCHAR(15),
    PreferredPickup VARCHAR(100),
    PRIMARY KEY (PassengerID, ContactPhone, PreferredPickup)
);
INSERT INTO PassengerProfile_Before4NF VALUES
(1,'9876543210','Anna Nagar'),
(1,'9876543210','Adyar'),
(1,'9111111111','Anna Nagar'),
(1,'9111111111','Adyar'),
(2,'9123456780','Velachery'),
(2,'9123456780','Tambaram');
SELECT * FROM PassengerProfile_Before4NF;

-- After normalization
DROP TABLE IF EXISTS PassengerPhone_4NF;
DROP TABLE IF EXISTS PassengerPreference_4NF;
CREATE TABLE PassengerPhone_4NF (
    PassengerID  INT,
    ContactPhone VARCHAR(15),
    PRIMARY KEY (PassengerID, ContactPhone)
);
CREATE TABLE PassengerPreference_4NF (
    PassengerID     INT,
    PreferredPickup VARCHAR(100),
    PRIMARY KEY (PassengerID, PreferredPickup)
);
INSERT INTO PassengerPhone_4NF VALUES (1,'9876543210'),(1,'9111111111'),(2,'9123456780');
INSERT INTO PassengerPreference_4NF VALUES (1,'Anna Nagar'),(1,'Adyar'),(2,'Velachery'),(2,'Tambaram');
SELECT * FROM PassengerPhone_4NF;
SELECT * FROM PassengerPreference_4NF;


-- ============================================================
-- 4.7 FIFTH NORMAL FORM (5NF)
-- ============================================================
-- Rule: 4NF + No join dependency (every join dependency implied by candidate keys).
-- A table violates 5NF when a three-way (or more) fact cannot be
-- correctly represented by any combination of two-way tables.

-- ============================================================
-- 4.7.1 IDENTIFY DEPENDENCY
-- ============================================================
-- VIOLATION: DriverServiceCity (three-way fact)
--   Business rule: "A driver offers a specific service in a specific city,
--   but only if that exact combination has been confirmed as valid."
--   This is a three-way fact: (DriverID, ServiceType, City)
--   If we split into two-way tables:
--     T1: (DriverID, ServiceType) — which driver offers which service
--     T2: (DriverID, City)        — which driver covers which city
--     T3: (ServiceType, City)     — which service is in which city
--   Joining T1, T2, T3 generates SPURIOUS TUPLES — false combinations.

-- Real facts (only 3 valid combinations):
-- Suresh Kumar offers City Driving in Chennai          (real)
-- Suresh Kumar offers Highway in Tambaram              (real)
-- Manoj Singh  offers City Driving in Tambaram         (real)
-- Pairwise join will incorrectly generate:
-- Suresh Kumar offers City Driving in Tambaram ← SPURIOUS (fake)

-- ============================================================
-- 4.7.2 APPLY NORMALIZATION TO 5NF
-- ============================================================

-- TABLE 1: DriverServiceCity
-- Before normalization: demonstrate pairwise tables generating spurious tuples
DROP TABLE IF EXISTS DS_Pair;
DROP TABLE IF EXISTS DC_Pair;
DROP TABLE IF EXISTS SC_Pair;

CREATE TABLE DS_Pair (   -- Driver + Service pairs
    DriverID    INT,
    ServiceType VARCHAR(50),
    PRIMARY KEY (DriverID, ServiceType)
);
CREATE TABLE DC_Pair (   -- Driver + City pairs
    DriverID INT,
    City     VARCHAR(50),
    PRIMARY KEY (DriverID, City)
);
CREATE TABLE SC_Pair (   -- Service + City pairs
    ServiceType VARCHAR(50),
    City        VARCHAR(50),
    PRIMARY KEY (ServiceType, City)
);
INSERT INTO DS_Pair VALUES (1,'City Driving'),(1,'Highway'),(2,'City Driving');
INSERT INTO DC_Pair VALUES (1,'Chennai'),(1,'Tambaram'),(2,'Tambaram');
INSERT INTO SC_Pair VALUES ('City Driving','Chennai'),('City Driving','Tambaram'),('Highway','Tambaram');

-- Pairwise join generates 4 rows but only 3 are real facts:
SELECT ds.DriverID, ds.ServiceType, dc.City AS SuspiciousCity
FROM DS_Pair ds
JOIN DC_Pair dc ON ds.DriverID = dc.DriverID
JOIN SC_Pair sc ON ds.ServiceType = sc.ServiceType AND dc.City = sc.City
ORDER BY ds.DriverID, ds.ServiceType;
-- Row (DriverID=1, ServiceType='City Driving', City='Tambaram') is SPURIOUS
-- Suresh Kumar does NOT offer City Driving in Tambaram!

-- After normalization: store the exact three-way fact directly
DROP TABLE IF EXISTS DriverServiceCity_5NF;
CREATE TABLE DriverServiceCity_5NF (
    DriverID    INT,
    ServiceType VARCHAR(50),
    City        VARCHAR(50),
    PRIMARY KEY (DriverID, ServiceType, City)
    -- Only real, confirmed combinations stored here.
    -- No spurious rows are possible.
);
INSERT INTO DriverServiceCity_5NF VALUES
(1,'City Driving','Chennai'),   -- Suresh Kumar: City Driving in Chennai  (REAL)
(1,'Highway',     'Tambaram'),  -- Suresh Kumar: Highway in Tambaram      (REAL)
(2,'City Driving','Tambaram');  -- Manoj Singh:  City Driving in Tambaram (REAL)
-- (1,'City Driving','Tambaram') is NOT inserted — it's spurious
SELECT * FROM DriverServiceCity_5NF;


-- TABLE 2: PassengerDriverRoute (three-way fact)
-- Business rule: "A passenger booked a specific driver on a specific route —
-- only exact confirmed combinations are valid."
-- Real facts:
--   Aarav (1) booked Suresh (1) for Anna Nagar → T Nagar  (real)
--   Aarav (1) booked Manoj  (2) for Adyar → Airport        (real)
--   Diya  (2) booked Suresh (1) for Velachery → Central     (real)
-- Pairwise join would generate a 4th fake combination.

DROP TABLE IF EXISTS PD_Pair;
DROP TABLE IF EXISTS PR_Pair;
DROP TABLE IF EXISTS DR_Pair;
CREATE TABLE PD_Pair (PassengerID INT, DriverID INT, PRIMARY KEY(PassengerID,DriverID));
CREATE TABLE PR_Pair (PassengerID INT, RouteID  INT, PRIMARY KEY(PassengerID,RouteID));
CREATE TABLE DR_Pair (DriverID    INT, RouteID  INT, PRIMARY KEY(DriverID,RouteID));
INSERT INTO PD_Pair VALUES (1,1),(1,2),(2,1);
INSERT INTO PR_Pair VALUES (1,1),(1,2),(2,1);
INSERT INTO DR_Pair VALUES (1,1),(2,2),(1,3);

-- Pairwise join generates spurious tuples
SELECT pd.PassengerID, pd.DriverID, pr.RouteID AS SpuriousRoute
FROM PD_Pair pd
JOIN PR_Pair pr ON pd.PassengerID = pr.PassengerID
JOIN DR_Pair dr ON pd.DriverID    = dr.DriverID AND pr.RouteID = dr.RouteID
ORDER BY pd.PassengerID;

-- After 5NF: store exact three-way fact
DROP TABLE IF EXISTS PassengerDriverRoute_5NF;
CREATE TABLE PassengerDriverRoute_5NF (
    PassengerID INT,
    DriverID    INT,
    RouteID     INT,
    PRIMARY KEY (PassengerID, DriverID, RouteID)
);
INSERT INTO PassengerDriverRoute_5NF VALUES
(1,1,1),   -- Aarav booked Suresh for Route 1  (REAL)
(1,2,2),   -- Aarav booked Manoj  for Route 2  (REAL)
(2,1,3);   -- Diya  booked Suresh for Route 3  (REAL)
SELECT * FROM PassengerDriverRoute_5NF;


-- ============================================================
-- VERIFY ALL NORMALIZED TABLES
-- ============================================================
SELECT * FROM Driver_1NF;
SELECT * FROM DriverSkill_1NF;
SELECT * FROM RideBooking_1NF;
SELECT * FROM Trip_2NF;
SELECT * FROM Driver_2NF;
SELECT * FROM TripAssignment_2NF;
SELECT * FROM Location_2NF;
SELECT * FROM RideRequest_2NF;
SELECT * FROM VehicleType_3NF;
SELECT * FROM Vehicle_3NF;
SELECT * FROM Booking_3NF;
SELECT * FROM Payment_3NF;
SELECT * FROM Driver_BCNF;
SELECT * FROM VehicleType_BCNF;
SELECT * FROM DriverVehicleType_4NF;
SELECT * FROM DriverServiceArea_4NF;
SELECT * FROM PassengerPhone_4NF;
SELECT * FROM PassengerPreference_4NF;
SELECT * FROM DriverServiceCity_5NF;
SELECT * FROM PassengerDriverRoute_5NF;


-- ============================================================
-- CLEANUP ALL DEMO TABLES (real tables untouched)
-- ============================================================
DROP TABLE IF EXISTS RideBooking_UNF;
DROP TABLE IF EXISTS Driver_Before1NF, Driver_1NF, DriverSkill_1NF;
DROP TABLE IF EXISTS RideBooking_Before1NF, RideBooking_1NF;
DROP TABLE IF EXISTS TripAssignment_Before2NF, Trip_2NF, Driver_2NF, TripAssignment_2NF;
DROP TABLE IF EXISTS RideRequest_Before2NF, Location_2NF, RideRequest_2NF;
DROP TABLE IF EXISTS Vehicle_Before3NF, VehicleType_3NF, Vehicle_3NF;
DROP TABLE IF EXISTS Payment_Before3NF, Booking_3NF, Payment_3NF;
DROP TABLE IF EXISTS Driver_BCNF, VehicleType_BCNF;
DROP TABLE IF EXISTS DriverProfile_Before4NF, DriverVehicleType_4NF, DriverServiceArea_4NF;
DROP TABLE IF EXISTS PassengerProfile_Before4NF, PassengerPhone_4NF, PassengerPreference_4NF;
DROP TABLE IF EXISTS DS_Pair, DC_Pair, SC_Pair, DriverServiceCity_5NF;
DROP TABLE IF EXISTS PD_Pair, PR_Pair, DR_Pair, PassengerDriverRoute_5NF;

SELECT 'Chapter 4 complete. All demo tables cleaned up. Real tables untouched.' AS Status;
