DROP TRIGGER IF EXISTS trg_update_wallet;
DROP TRIGGER IF EXISTS trg_check_rating;

DELIMITER $$

CREATE TRIGGER trg_update_wallet
AFTER INSERT ON payment
FOR EACH ROW
BEGIN
    IF NEW.Payment_Mode = 'Wallet' THEN
        UPDATE wallet
        SET Balance = Balance - NEW.Amount
        WHERE Passenger_ID = (
            SELECT rr.Passenger_ID
            FROM trip t
            JOIN ride_request rr ON t.Request_ID = rr.Request_ID
            WHERE t.Trip_ID = NEW.Trip_ID
        );
    END IF;
END$$

CREATE TRIGGER trg_check_rating
BEFORE INSERT ON rating_review
FOR EACH ROW
BEGIN
    IF NEW.Driver_Rating < 1 OR NEW.Driver_Rating > 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Driver rating must be between 1 and 5';
    END IF;
    IF NEW.Passenger_Rating < 1 OR NEW.Passenger_Rating > 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Passenger rating must be between 1 and 5';
    END IF;
END$$

DELIMITER ;
