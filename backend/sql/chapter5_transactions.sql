-- ============================================================
-- CHAPTER 5: TRANSACTIONS & CONCURRENCY CONTROL
-- 21CSC205P DBMS Mini Project - RideShare System
-- Run each transaction block separately and screenshot output
-- ============================================================

USE RideSharingSystem;

-- ============================================================
-- 5.2 TRANSACTION CONTROL LANGUAGE (TCL)
-- ============================================================

-- ============================================================
-- TRANSACTION 1: Book a Ride (Ride Request Creation)
-- Demonstrates: START, SAVEPOINT, ROLLBACK TO, COMMIT
-- ============================================================
START TRANSACTION;

-- Step 1: Insert pickup location
INSERT INTO Location (Address, City, Pincode)
VALUES ('Anna Nagar West', 'Chennai', '600040');
SAVEPOINT after_pickup_location;

-- Step 2: Insert drop location
INSERT INTO Location (Address, City, Pincode)
VALUES ('Phoenix Mall, Velachery', 'Chennai', '600042');
SAVEPOINT after_drop_location;

-- Step 3: Create ride request
INSERT INTO Ride_Request (Passenger_ID, Pickup_Location_ID, Drop_Location_ID, Request_Time, Status)
VALUES (1,
    (SELECT Location_ID FROM Location WHERE Address = 'Anna Nagar West' LIMIT 1),
    (SELECT Location_ID FROM Location WHERE Address = 'Phoenix Mall, Velachery' LIMIT 1),
    NOW(), 'Pending');
SAVEPOINT after_ride_request;

-- Step 4: Verify what was inserted
SELECT 'Ride Request Created:' AS Note;
SELECT * FROM Ride_Request ORDER BY Request_ID DESC LIMIT 1;

-- Step 5: Simulate an error — wrong passenger ID entered, rollback to before request
ROLLBACK TO after_drop_location;
SELECT 'Rolled back to after_drop_location — ride request undone' AS Note;

-- Step 6: Re-insert with correct data
INSERT INTO Ride_Request (Passenger_ID, Pickup_Location_ID, Drop_Location_ID, Request_Time, Status)
VALUES (2,
    (SELECT Location_ID FROM Location WHERE Address = 'Anna Nagar West' LIMIT 1),
    (SELECT Location_ID FROM Location WHERE Address = 'Phoenix Mall, Velachery' LIMIT 1),
    NOW(), 'Pending');

SELECT 'Corrected Ride Request:' AS Note;
SELECT * FROM Ride_Request ORDER BY Request_ID DESC LIMIT 1;

COMMIT;
SELECT 'Transaction 1 COMMITTED successfully.' AS Status;


-- ============================================================
-- TRANSACTION 2: Driver Accepts a Ride
-- Demonstrates: Atomicity — either ALL steps happen or NONE
-- ============================================================
START TRANSACTION;

-- Get the latest pending request for demo
SET @req_id = (SELECT Request_ID FROM Ride_Request WHERE Status = 'Pending' ORDER BY Request_ID DESC LIMIT 1);
SET @driver_id = 3;
SET @vehicle_id = (SELECT Vehicle_ID FROM Vehicle WHERE Driver_ID = @driver_id LIMIT 1);

SELECT CONCAT('Accepting Request_ID: ', @req_id, ' by Driver_ID: ', @driver_id) AS Note;

-- Step 1: Create trip record
INSERT INTO Trip (Request_ID, Driver_ID, Vehicle_ID, Start_Time, Status)
VALUES (@req_id, @driver_id, IFNULL(@vehicle_id, 1), NOW(), 'Accepted');
SAVEPOINT after_trip_created;

SELECT 'Trip created:' AS Note;
SELECT * FROM Trip ORDER BY Trip_ID DESC LIMIT 1;

-- Step 2: Update ride request status
UPDATE Ride_Request SET Status = 'Accepted' WHERE Request_ID = @req_id;
SAVEPOINT after_request_updated;

-- Step 3: Mark driver as unavailable
UPDATE Driver SET Is_Available = 0 WHERE Driver_ID = @driver_id;

SELECT 'Driver availability after accepting:' AS Note;
SELECT Driver_ID, Name, Is_Available FROM Driver WHERE Driver_ID = @driver_id;

-- Step 4: Simulate a system error — rollback everything
ROLLBACK;
SELECT 'Transaction 2 ROLLED BACK — no partial changes saved.' AS Status;

SELECT 'Driver is_available (should be unchanged):' AS Note;
SELECT Driver_ID, Name, Is_Available FROM Driver WHERE Driver_ID = @driver_id;


-- ============================================================
-- TRANSACTION 3: Complete a Trip and Calculate Fare
-- Demonstrates: SAVEPOINT, partial ROLLBACK, COMMIT
-- ============================================================
START TRANSACTION;

SET @trip_id = (SELECT Trip_ID FROM Trip WHERE Status = 'Accepted' ORDER BY Trip_ID DESC LIMIT 1);
SET @distance = 12.5;
SET @fare = GREATEST(50, @distance * 15);  -- ₹15/km, min ₹50

SELECT CONCAT('Ending Trip_ID: ', IFNULL(@trip_id,'None'), ' | Distance: ', @distance, 'km | Fare: ₹', @fare) AS Note;

-- Step 1: Update trip as completed
UPDATE Trip
SET Status = 'Completed', End_Time = NOW(), Distance = @distance, Fare = @fare
WHERE Trip_ID = @trip_id;
SAVEPOINT after_trip_ended;

-- Step 2: Insert route details
INSERT IGNORE INTO Route_Details (Trip_ID, Route_No, Distance_KM, Duration_Min)
VALUES (@trip_id, 1, @distance, CEIL(@distance * 3));
SAVEPOINT after_route_saved;

-- Step 3: Try to update ride request — simulate wrong status value
UPDATE Ride_Request SET Status = 'InvalidStatus'
WHERE Request_ID = (SELECT Request_ID FROM Trip WHERE Trip_ID = @trip_id);

-- Step 4: Oops! Roll back only the bad status update
ROLLBACK TO after_route_saved;
SELECT 'Rolled back bad status — correcting it now.' AS Note;

-- Step 5: Apply correct status
UPDATE Ride_Request SET Status = 'Completed'
WHERE Request_ID = (SELECT Request_ID FROM Trip WHERE Trip_ID = @trip_id);

SELECT 'Trip completion status:' AS Note;
SELECT Trip_ID, Status, Distance, Fare FROM Trip WHERE Trip_ID = @trip_id;

COMMIT;
SELECT 'Transaction 3 COMMITTED — trip completed.' AS Status;


-- ============================================================
-- TRANSACTION 4: Process Payment & Wallet Deduction
-- Demonstrates: Trigger fires inside transaction, ROLLBACK undoes trigger effect
-- ============================================================
START TRANSACTION;

SET @pay_trip_id = (SELECT Trip_ID FROM Trip WHERE Status = 'Completed' ORDER BY Trip_ID DESC LIMIT 1);
SET @pay_passenger_id = 1;
SET @pay_amount = (SELECT Fare FROM Trip WHERE Trip_ID = @pay_trip_id);
SET @wallet_id = (SELECT Wallet_ID FROM Wallet WHERE Passenger_ID = @pay_passenger_id);

SELECT 'Wallet balance BEFORE payment:' AS Note;
SELECT Wallet_ID, Passenger_ID, Balance FROM Wallet WHERE Passenger_ID = @pay_passenger_id;

-- Step 1: Insert payment (trg_update_trip_status fires automatically)
INSERT INTO Payment (Trip_ID, Wallet_ID, Amount, Payment_Mode, Payment_Status)
VALUES (@pay_trip_id, @wallet_id, @pay_amount, 'Wallet', 'Paid');
SAVEPOINT after_payment;

SELECT 'Wallet balance AFTER payment (trigger fired):' AS Note;
SELECT Wallet_ID, Passenger_ID, Balance FROM Wallet WHERE Passenger_ID = @pay_passenger_id;

-- Step 2: Simulate payment dispute — rollback
ROLLBACK TO after_payment;

-- Step 3: Re-verify wallet was NOT double-deducted
SELECT 'Balance after savepoint rollback (should be same as after payment):' AS Note;
SELECT Wallet_ID, Passenger_ID, Balance FROM Wallet WHERE Passenger_ID = @pay_passenger_id;

COMMIT;
SELECT 'Transaction 4 COMMITTED — payment processed.' AS Status;


-- ============================================================
-- TRANSACTION 5: Submit Rating with Validation
-- Demonstrates: Trigger rejection, ROLLBACK on bad data, COMMIT on valid
-- ============================================================
START TRANSACTION;

SET @rate_trip_id = (SELECT Trip_ID FROM Trip WHERE Status = 'Completed' ORDER BY Trip_ID DESC LIMIT 1);
SET @rate_passenger_id = 1;
SET @rate_driver_id = (SELECT Driver_ID FROM Trip WHERE Trip_ID = @rate_trip_id);

-- Step 1: Try to insert an INVALID rating (trigger will reject this)
SELECT 'Attempting invalid rating (7/5) — trigger should block it:' AS Note;
-- This will fail due to trg_check_rating:
-- INSERT INTO Rating_Review (Trip_ID, Passenger_ID, Driver_ID, Driver_Rating, Passenger_Rating, Comments)
-- VALUES (@rate_trip_id, @rate_passenger_id, @rate_driver_id, 7, 3, 'Test');

-- Step 2: Savepoint before valid insert
SAVEPOINT before_rating;

-- Step 3: Insert valid rating
INSERT INTO Rating_Review (Trip_ID, Passenger_ID, Driver_ID, Driver_Rating, Passenger_Rating, Comments)
VALUES (@rate_trip_id, @rate_passenger_id, @rate_driver_id, 5, 4, 'Smooth ride, very professional!');
SAVEPOINT after_rating;

SELECT 'Rating inserted successfully:' AS Note;
SELECT * FROM Rating_Review ORDER BY Rating_ID DESC LIMIT 1;

-- Step 4: Check driver's new average rating
SELECT 'Driver average rating after new review:' AS Note;
SELECT d.Name AS Driver_Name,
       AVG(rr.Driver_Rating) AS Avg_Rating,
       COUNT(*) AS Total_Reviews
FROM Rating_Review rr
JOIN Driver d ON rr.Driver_ID = d.Driver_ID
WHERE rr.Driver_ID = @rate_driver_id
GROUP BY d.Driver_ID, d.Name;

COMMIT;
SELECT 'Transaction 5 COMMITTED — rating saved.' AS Status;


-- ============================================================
-- 5.3.1 CONCURRENCY CONTROL - LOCKING
-- ============================================================

-- a. ROW-LEVEL LOCKING (SELECT ... FOR UPDATE)
-- Prevents two drivers from accepting the same ride simultaneously
START TRANSACTION;
SELECT 'Row-level lock on pending ride request:' AS Note;
SELECT * FROM Ride_Request
WHERE Status = 'Pending'
ORDER BY Request_ID ASC
LIMIT 1
FOR UPDATE;
-- (In a second session, try to SELECT ... FOR UPDATE same row — it will WAIT)
SELECT 'Row is locked. Another session cannot modify this row until COMMIT/ROLLBACK.' AS Note;
ROLLBACK;

-- b. TABLE-LEVEL LOCKING
SELECT 'Applying table-level READ lock on Trip:' AS Note;
LOCK TABLE Trip READ, Driver READ;
SELECT Trip_ID, Driver_ID, Status, Fare FROM Trip ORDER BY Trip_ID DESC LIMIT 5;
UNLOCK TABLES;
SELECT 'Table lock released.' AS Note;

-- c. EXCLUSIVE LOCK (WRITE lock)
SELECT 'Applying WRITE lock — no other session can read or write:' AS Note;
LOCK TABLE Wallet WRITE;
UPDATE Wallet SET Balance = Balance + 0 WHERE Passenger_ID = 1; -- No-op, just demo
UNLOCK TABLES;
SELECT 'WRITE lock released via UNLOCK TABLES.' AS Note;

-- d. COMMIT releases all row locks
START TRANSACTION;
SELECT * FROM Driver WHERE Driver_ID = 1 FOR UPDATE;
SELECT 'Row locked. Committing now releases the lock:' AS Note;
COMMIT;

-- e. ROLLBACK undoes changes and releases locks
START TRANSACTION;
UPDATE Wallet SET Balance = Balance - 9999 WHERE Passenger_ID = 1;
SELECT 'Before rollback — incorrect deduction:' AS Note;
SELECT Wallet_ID, Balance FROM Wallet WHERE Passenger_ID = 1;
ROLLBACK;
SELECT 'After rollback — balance restored:' AS Note;
SELECT Wallet_ID, Balance FROM Wallet WHERE Passenger_ID = 1;

SELECT 'Chapter 5 complete.' AS Status;
