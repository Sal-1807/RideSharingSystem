# RideShare Setup Guide

## 1. Configure Your Database Connection

Open `backend/.env` and update with your MySQL credentials:

```
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=YOUR_MYSQL_PASSWORD_HERE
DB_NAME=RideSharingSystem
PORT=3000
SESSION_SECRET=rideshare_super_secret_key_2026
```

Change `DB_NAME` to whatever your database is named.

---

## 2. Set Up the Database Schema

### Option A — Fresh / Empty Database
Run the full schema file (creates all tables, views, triggers, stored procedures, sample data):

```bash
mysql -u root -p RideSharingSystem < backend/sql/schema.sql
```

### Option B — You Already Have Some Tables
The schema uses `CREATE TABLE IF NOT EXISTS` on every table, so it is **safe to re-run** — it will not overwrite existing data.

However, you may need to add columns that the project requires. Run these ALTER statements only if the columns don't already exist in your database:

```sql
-- Add auth columns to Passenger (if missing)
ALTER TABLE Passenger
    ADD COLUMN IF NOT EXISTS Email    VARCHAR(100) NOT NULL DEFAULT '' AFTER Phone,
    ADD COLUMN IF NOT EXISTS Password VARCHAR(255) NOT NULL DEFAULT ''  AFTER Email;

-- Add auth columns to Driver (if missing)
ALTER TABLE Driver
    ADD COLUMN IF NOT EXISTS Email       VARCHAR(100) NOT NULL DEFAULT '' AFTER Phone,
    ADD COLUMN IF NOT EXISTS Password    VARCHAR(255) NOT NULL DEFAULT '' AFTER Email,
    ADD COLUMN IF NOT EXISTS Is_Available TINYINT(1) DEFAULT 1 AFTER Password;

-- Add Status column to Trip (if missing)
ALTER TABLE Trip
    ADD COLUMN IF NOT EXISTS Status VARCHAR(20) NOT NULL DEFAULT 'Accepted' AFTER End_Time;

-- Add created_at to Support_Ticket (if missing)
ALTER TABLE Support_Ticket
    ADD COLUMN IF NOT EXISTS Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add Password to Admin (if missing)
ALTER TABLE Admin
    ADD COLUMN IF NOT EXISTS Password VARCHAR(255) NOT NULL DEFAULT 'admin123';
```

---

## 3. Install Node.js Dependencies

```bash
cd backend
npm install
```

---

## 4. Start the Server

```bash
cd backend
npm start
```

The server runs at **http://localhost:3000**

Open your browser to http://localhost:3000 — the frontend loads automatically.

---

## 5. Default Login Credentials

| Role      | Credentials                          |
|-----------|--------------------------------------|
| Admin     | Any admin email · password: `admin123` |
| Passenger | Register at /register.html           |
| Driver    | Register at /register.html           |

Admin accounts come from the `Admin` table seeded in schema.sql.
Default admin: `admin@rideshare.com` / `admin123`

---

## Project Structure

```
RideSharingSystem/
├── backend/
│   ├── config/db.js          MySQL connection pool
│   ├── routes/               All API route files
│   ├── sql/schema.sql        Full database schema
│   ├── server.js             Express app entry point
│   ├── .env                  DB credentials (edit this)
│   └── package.json
└── frontend/
    ├── css/style.css
    ├── js/api.js
    ├── index.html
    ├── login.html
    ├── register.html
    ├── passenger_dashboard.html
    ├── request_ride.html
    ├── trip_history.html
    ├── payment.html
    ├── rating.html
    ├── support_ticket.html
    ├── driver_dashboard.html
    └── admin_dashboard.html
```
