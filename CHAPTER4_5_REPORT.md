# Chapter 4 & 5 — RideShare DBMS Mini Project
### How to use this file
- Copy the SQL blocks into your MySQL CLI one section at a time
- Screenshot each output for your report
- The SQL files are at:
  - `backend/sql/chapter4_normalization.sql`
  - `backend/sql/chapter5_transactions.sql`

---

# CHAPTER 4 — NORMALIZATION

## 4.1 Analyse the Pitfalls in Relations

Before normalization, imagine all ride data stored in **one giant table** (`Ride_UNF`):

| Ride_ID | Passenger_Name | Passenger_Phone | Driver_Name | License_No | Vehicle_Model | Pickup | Drop | Fare | Payment_Mode | Rating |
|---------|---------------|-----------------|-------------|------------|---------------|--------|------|------|--------------|--------|
| 1 | Aarav Sharma | 9876543210 | Suresh Kumar | DL12345 | Swift Dzire | Anna Nagar | T Nagar | 127.50 | Wallet | 5 |
| 2 | Aarav Sharma | 9876543210 | Manoj Singh | DL67890 | Honda City | Adyar | Airport | 330.00 | UPI | 4 |
| 3 | Diya Reddy | 9123456780 | Suresh Kumar | DL12345 | Swift Dzire | Velachery | Central | 180.00 | Cash | 5 |

**Pitfalls identified:**
- **Redundancy:** Aarav's phone repeated in rows 1, 2. Suresh's vehicle repeated in rows 1, 3.
- **Update Anomaly:** If Suresh changes his phone, must update multiple rows — risk of inconsistency.
- **Delete Anomaly:** Deleting Diya's trip (row 3) loses all information about Diya.
- **Insert Anomaly:** Cannot add a new driver until they have a trip — no trip = no record.

---

## 4.2 First Normal Form (1NF)

### 4.2.1 Identify Dependency
- `Ride_ID → Passenger_Phone` (but Passenger_Phone appears multiple times for same passenger)
- Non-atomic issue: one table stores passenger, driver, vehicle, and trip data together

### 4.2.2 Apply Normalization to 1NF

**Rule:** Every column must contain atomic values. No repeating groups.

**Before 1NF (violation):**
```sql
SELECT Passenger_Name, COUNT(*) AS Occurrences
FROM Ride_UNF
GROUP BY Passenger_Name
HAVING COUNT(*) > 1;
-- Aarav Sharma appears 3 times
```

**After 1NF — split into atomic tables:**

```sql
CREATE TABLE Ride_1NF_Passenger (
    Passenger_ID    INT PRIMARY KEY,
    Passenger_Name  VARCHAR(100),
    Passenger_Phone VARCHAR(15),
    Passenger_Email VARCHAR(100)
);

CREATE TABLE Ride_1NF_Driver (
    Driver_ID     INT PRIMARY KEY,
    Driver_Name   VARCHAR(100),
    Driver_Phone  VARCHAR(15),
    License_No    VARCHAR(50),
    Vehicle_Model VARCHAR(100),
    Vehicle_Type  VARCHAR(50)
);

CREATE TABLE Ride_1NF_Trip (
    Ride_ID       INT PRIMARY KEY,
    Passenger_ID  INT,
    Driver_ID     INT,
    Pickup_Address VARCHAR(255),
    Drop_Address  VARCHAR(255),
    Trip_Fare     DECIMAL(8,2),
    Payment_Mode  VARCHAR(50),
    Driver_Rating INT
);
```

Each passenger/driver now stored **once** — no repeating groups.

---

## 4.3 Second Normal Form (2NF)

### 4.3.1 Identify Dependency

In a table with composite primary key `(Ride_ID, Passenger_ID)`:
- `Passenger_ID → Passenger_Name` ← **Partial dependency** (depends on only part of PK)

**Before 2NF (violation):**
```sql
CREATE TABLE Ride_2NF_Bad (
    Ride_ID        INT,
    Passenger_ID   INT,
    Passenger_Name VARCHAR(100),  -- only depends on Passenger_ID!
    Trip_Fare      DECIMAL(8,2),
    PRIMARY KEY (Ride_ID, Passenger_ID)
);
-- Aarav Sharma appears in rows 1 and 2 — partial dependency!
```

### 4.3.2 Apply Normalization to 2NF

**Rule:** Remove partial dependencies — every non-key attribute must depend on the **whole** primary key.

**After 2NF:**
- `Passenger` table: `Passenger_ID → Name, Phone, Email` ✓
- `Trip` table: `Trip_ID → Driver_ID, Fare, Distance` ✓ (no composite key, no partial dep)

```sql
-- Verify: Passenger_Name is now only in the Passenger table
SELECT Passenger_ID, Name, Phone, Email FROM Passenger;
SELECT Trip_ID, Passenger_ID_via_Request, Fare FROM Trip; -- no Passenger_Name here
```

---

## 4.4 Third Normal Form (3NF)

### 4.4.1 Identify Dependency

In a poorly designed Trip table:
- `Trip_ID → Driver_ID → Vehicle_Model` ← **Transitive dependency**
- `Vehicle_Model` depends on `Driver_ID`, not directly on `Trip_ID`

**Before 3NF (violation):**
```sql
CREATE TABLE Ride_3NF_Bad (
    Trip_ID       INT PRIMARY KEY,
    Driver_ID     INT,
    Driver_Name   VARCHAR(100),  -- transitively depends on Driver_ID
    Vehicle_Model VARCHAR(100),  -- transitively depends on Driver_ID
    Trip_Fare     DECIMAL(8,2)
);
-- Suresh Kumar + Swift Dzire appears in rows 1 and 3 — transitive dep!
```

### 4.4.2 Apply Normalization to 3NF

**Rule:** No transitive dependencies — non-key attributes must depend only on the primary key.

**After 3NF:**
```sql
-- Driver_Name and Vehicle_Model moved to Driver table
SELECT Driver_ID, Name, License_No FROM Driver;        -- Driver info here
SELECT Vehicle_ID, Driver_ID, Model FROM Vehicle;      -- Vehicle info here
SELECT Trip_ID, Driver_ID, Fare, Distance FROM Trip;   -- Trip only has Driver_ID (FK)
```

---

## 4.5 BCNF (Boyce-Codd Normal Form)

### 4.5.1 Identify Dependency

For every functional dependency `X → Y`, X must be a **superkey**.

In the `Driver` table:
- `Driver_ID → Name, Phone, License_No` (Driver_ID is PK = superkey ✓)
- `License_No → Driver_ID, Name, Phone` (License_No is a candidate key = superkey ✓)

### 4.5.2 Apply Normalization to BCNF

```sql
-- Verify: both Driver_ID and License_No are candidate keys
SELECT Driver_ID, License_No, Name, Phone FROM Driver;
SHOW INDEX FROM Driver;
-- License_No has UNIQUE index → it is a candidate key → BCNF satisfied
```

**All tables in RideShare satisfy BCNF** — every determinant is a candidate key.

---

## 4.6 Fourth Normal Form (4NF)

### 4.6.1 Identify Dependency

**Multi-valued dependency (MVD):** `A →→ B` means A independently determines multiple values of B.

**Violation scenario:** If one table stores driver's vehicle types AND service areas:

```sql
CREATE TABLE Driver_4NF_Bad (
    Driver_ID    INT,
    Vehicle_Type VARCHAR(50),   -- Driver →→ Vehicle_Type
    Service_Area VARCHAR(100),  -- Driver →→ Service_Area
    PRIMARY KEY (Driver_ID, Vehicle_Type, Service_Area)
);
-- Driver 1 drives Sedan & SUV in Anna Nagar & Adyar
-- Must store all 4 combinations (2×2) = redundancy!
```

| Driver_ID | Vehicle_Type | Service_Area |
|-----------|-------------|-------------|
| 1 | Sedan | Anna Nagar |
| 1 | Sedan | Adyar |
| 1 | SUV | Anna Nagar |
| 1 | SUV | Adyar |

### 4.6.2 Apply Normalization to 4NF

**Rule:** No multi-valued dependencies — split into two independent tables.

```sql
-- After 4NF: two separate tables
CREATE TABLE Driver_VehicleType (Driver_ID INT, Vehicle_Type VARCHAR(50));
CREATE TABLE Driver_ServiceArea (Driver_ID INT, Service_Area VARCHAR(100));

-- Vehicle table in RideShare already handles this correctly:
SELECT v.Driver_ID, v.Model, vt.Type_Name FROM Vehicle v
JOIN Vehicle_Type vt ON v.Vehicle_Type_ID = vt.Vehicle_Type_ID;
```

---

## 4.7 Fifth Normal Form (5NF)

### 4.7.1 Identify Dependency

**Join dependency:** A table is in 5NF if it cannot be decomposed into smaller tables without losing information (no lossy decomposition).

### 4.7.2 Apply Normalization to 5NF

```sql
-- Decompose Trip into two projections
SELECT Trip_ID, Driver_ID, Status FROM Trip;
SELECT Trip_ID, Request_ID, Fare, Distance FROM Trip;

-- Join them back — recovers the original table exactly (lossless join)
SELECT t1.Trip_ID, t1.Driver_ID, t1.Status, t2.Request_ID, t2.Fare, t2.Distance
FROM (SELECT Trip_ID, Driver_ID, Status FROM Trip) t1
JOIN (SELECT Trip_ID, Request_ID, Fare, Distance FROM Trip) t2
  ON t1.Trip_ID = t2.Trip_ID;

-- Result is identical to original Trip table → 5NF satisfied ✓
```

**All tables in the RideShare schema satisfy 5NF** — every join dependency is implied by the primary key.

---

# CHAPTER 5 — CONCURRENCY CONTROL & RECOVERY

## 5.1 Introduction to Transactions

A **transaction** is a sequence of database operations treated as a single unit.

### 5.1.1 Properties (ACID)
| Property | Description | Example in RideShare |
|----------|-------------|----------------------|
| **Atomicity** | All operations succeed or all are rolled back | Accepting a ride creates a trip AND marks driver unavailable — both or neither |
| **Consistency** | DB moves from one valid state to another | Wallet balance never goes negative |
| **Isolation** | Transactions don't interfere with each other | Two drivers can't accept the same ride simultaneously |
| **Durability** | Committed changes are permanent | Payment recorded even if server restarts |

### 5.1.2 States
```
Active → Partially Committed → Committed
                 ↓
              Failed → Aborted (Rolled Back)
```

---

## 5.2 Transaction Control Language (TCL)

### 5.2.1 SAVEPOINT
```sql
SAVEPOINT savepoint_name;        -- Mark a point to rollback to
ROLLBACK TO savepoint_name;      -- Undo only up to this point
RELEASE SAVEPOINT savepoint_name; -- Remove the savepoint
```

### 5.2.2 COMMIT
```sql
COMMIT; -- Make all changes permanent, release locks
```

### 5.2.3 ROLLBACK
```sql
ROLLBACK;                    -- Undo ALL changes since START TRANSACTION
ROLLBACK TO savepoint_name;  -- Undo only to the savepoint
```

---

## 5.3 Five Transactions for RideShare

### Transaction 1: Book a Ride (Ride Request Creation)

```sql
START TRANSACTION;

INSERT INTO Location (Address, City, Pincode)
VALUES ('Anna Nagar West', 'Chennai', '600040');
SAVEPOINT after_pickup_location;

INSERT INTO Location (Address, City, Pincode)
VALUES ('Phoenix Mall, Velachery', 'Chennai', '600042');
SAVEPOINT after_drop_location;

INSERT INTO Ride_Request (Passenger_ID, Pickup_Location_ID, Drop_Location_ID, Request_Time, Status)
VALUES (1,
    (SELECT Location_ID FROM Location WHERE Address = 'Anna Nagar West' LIMIT 1),
    (SELECT Location_ID FROM Location WHERE Address = 'Phoenix Mall, Velachery' LIMIT 1),
    NOW(), 'Pending');
SAVEPOINT after_ride_request;

-- Oops! Wrong passenger — rollback to before the request
ROLLBACK TO after_drop_location;

-- Re-insert with correct passenger
INSERT INTO Ride_Request (Passenger_ID, Pickup_Location_ID, Drop_Location_ID, Request_Time, Status)
VALUES (2,
    (SELECT Location_ID FROM Location WHERE Address = 'Anna Nagar West' LIMIT 1),
    (SELECT Location_ID FROM Location WHERE Address = 'Phoenix Mall, Velachery' LIMIT 1),
    NOW(), 'Pending');

COMMIT;
```

---

### Transaction 2: Driver Accepts a Ride

```sql
START TRANSACTION;

INSERT INTO Trip (Request_ID, Driver_ID, Vehicle_ID, Start_Time, Status)
VALUES (1, 3, 1, NOW(), 'Accepted');
SAVEPOINT after_trip_created;

UPDATE Ride_Request SET Status = 'Accepted' WHERE Request_ID = 1;
SAVEPOINT after_request_updated;

UPDATE Driver SET Is_Available = 0 WHERE Driver_ID = 3;

-- Simulate system crash — rollback everything (atomicity)
ROLLBACK;
-- All 3 steps undone: trip not created, request not updated, driver still available
```

---

### Transaction 3: Complete a Trip and Calculate Fare

```sql
START TRANSACTION;

UPDATE Trip
SET Status = 'Completed', End_Time = NOW(), Distance = 12.5, Fare = 187.50
WHERE Trip_ID = 1;
SAVEPOINT after_trip_ended;

INSERT IGNORE INTO Route_Details (Trip_ID, Route_No, Distance_KM, Duration_Min)
VALUES (1, 1, 12.5, 38);
SAVEPOINT after_route_saved;

-- Wrong status accidentally — rollback only this
UPDATE Ride_Request SET Status = 'InvalidStatus' WHERE Request_ID = 1;
ROLLBACK TO after_route_saved;

-- Correct update
UPDATE Ride_Request SET Status = 'Completed' WHERE Request_ID = 1;

COMMIT;
```

---

### Transaction 4: Process Payment with Wallet Deduction

```sql
START TRANSACTION;

-- Check wallet before
SELECT Wallet_ID, Balance FROM Wallet WHERE Passenger_ID = 1;

-- Insert payment (trg_update_trip_status + trg_update_wallet fire automatically)
INSERT INTO Payment (Trip_ID, Wallet_ID, Amount, Payment_Mode, Payment_Status)
VALUES (1, 1, 187.50, 'Wallet', 'Paid');
SAVEPOINT after_payment;

-- Verify trigger fired — wallet deducted
SELECT Wallet_ID, Balance FROM Wallet WHERE Passenger_ID = 1;

COMMIT;
-- Trip status auto-set to 'Completed' by trigger
-- Wallet deducted by trigger (Wallet mode only)
```

---

### Transaction 5: Submit Rating with Validation

```sql
START TRANSACTION;

SAVEPOINT before_rating;

-- Valid rating (1–5) — trigger trg_check_rating validates
INSERT INTO Rating_Review
    (Trip_ID, Passenger_ID, Driver_ID, Driver_Rating, Passenger_Rating, Comments)
VALUES (1, 1, 1, 5, 4, 'Smooth ride, very professional!');
SAVEPOINT after_rating;

-- Check updated average rating
SELECT d.Name, AVG(rr.Driver_Rating) AS Avg_Rating
FROM Rating_Review rr
JOIN Driver d ON rr.Driver_ID = d.Driver_ID
WHERE rr.Driver_ID = 1
GROUP BY d.Name;

COMMIT;
```

---

## 5.3.2 Concurrency Control

### 5.3.1 Algorithms & Locking Commands

#### a. Row-Level Locking — `SELECT ... FOR UPDATE`

Prevents two drivers from accepting the same ride simultaneously:

```sql
-- Session 1 (Driver A):
START TRANSACTION;
SELECT * FROM Ride_Request
WHERE Status = 'Pending' AND Request_ID = 1
FOR UPDATE;
-- Row is now locked. Driver B's session will WAIT here.

-- Session 2 (Driver B — in a second terminal):
START TRANSACTION;
SELECT * FROM Ride_Request
WHERE Status = 'Pending' AND Request_ID = 1
FOR UPDATE;  -- This WAITS until Session 1 commits or rolls back

-- Session 1 commits:
UPDATE Ride_Request SET Status = 'Accepted' WHERE Request_ID = 1;
COMMIT;
-- Now Session 2 gets the lock but sees Status = 'Accepted' — too late!
```

#### b. Table-Level Locking — `LOCK TABLE`

```sql
-- READ lock: others can read but not write
LOCK TABLE Trip READ;
SELECT Trip_ID, Status, Fare FROM Trip;
UNLOCK TABLES;

-- WRITE lock: no other session can read or write
LOCK TABLE Wallet WRITE;
UPDATE Wallet SET Balance = Balance - 100 WHERE Passenger_ID = 1;
UNLOCK TABLES;
```

#### Lock Modes Summary

| Lock Mode | Allows Others To Read | Allows Others To Write |
|-----------|----------------------|------------------------|
| ROW SHARE (FOR UPDATE) | Yes | No (on locked rows) |
| ROW EXCLUSIVE | Yes | No |
| SHARE (READ) | Yes | No |
| EXCLUSIVE (WRITE) | No | No |

#### c. COMMIT — Release All Locks
```sql
START TRANSACTION;
SELECT * FROM Driver WHERE Driver_ID = 1 FOR UPDATE;
-- ... make changes ...
COMMIT;  -- Releases all row locks acquired in this transaction
```

#### d. ROLLBACK — Undo Changes & Release Locks
```sql
START TRANSACTION;
UPDATE Wallet SET Balance = Balance - 9999 WHERE Passenger_ID = 1;
SELECT Balance FROM Wallet WHERE Passenger_ID = 1;  -- Shows deducted balance
ROLLBACK;
SELECT Balance FROM Wallet WHERE Passenger_ID = 1;  -- Balance restored
-- All locks released automatically on ROLLBACK
```
