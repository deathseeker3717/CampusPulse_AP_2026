-- ============================================================
-- CampusPulse
-- Application SQL query reference
-- ============================================================


-- Every SQL statement is marked -- READ or -- WRITE.
-- Transaction control statements are marked -- WRITE (TRANSACTION).


-- ============================================================
-- 1. HEALTH CHECK
-- ============================================================

-- READ
SELECT NOW() AS database_time;


-- ============================================================
-- 2. STUDENTS
-- ============================================================

-- ------------------------------------------------------------
-- 2.1 Count students for pagination
-- ------------------------------------------------------------

-- READ
SELECT COUNT(*) AS total
FROM students s
JOIN departments d ON d.id = s.department_id
WHERE
    ($1::TEXT IS NULL
        OR s.name ILIKE $1
        OR s.email ILIKE $1
        OR s.roll_no ILIKE $1)
    AND ($2::TEXT IS NULL OR d.code = $2)
    AND ($3::SMALLINT IS NULL OR s.year = $3);


-- ------------------------------------------------------------
-- 2.2 List students with department code and pagination
-- ------------------------------------------------------------

-- READ
SELECT
    s.id,
    s.name,
    s.email,
    s.roll_no,
    d.code AS department,
    s.year,
    s.phone
FROM students s
JOIN departments d ON d.id = s.department_id
WHERE
    ($1::TEXT IS NULL
        OR s.name ILIKE $1
        OR s.email ILIKE $1
        OR s.roll_no ILIKE $1)
    AND ($2::TEXT IS NULL OR d.code = $2)
    AND ($3::SMALLINT IS NULL OR s.year = $3)
ORDER BY s.id
LIMIT $4
OFFSET $5;


-- ------------------------------------------------------------
-- 2.3 Create student
-- ------------------------------------------------------------

-- WRITE
INSERT INTO students (
    name,
    email,
    roll_no,
    department_id,
    year,
    phone
)
SELECT
    $1,
    $2,
    $3,
    d.id,
    $5,
    $6
FROM departments d
WHERE d.code = $4
RETURNING id, name, email, roll_no, year, phone;


-- ------------------------------------------------------------
-- 2.4 Find department ID for student update
-- ------------------------------------------------------------

-- READ
SELECT id
FROM departments
WHERE code = $1;


-- ------------------------------------------------------------
-- 2.5 Update student
-- ------------------------------------------------------------

-- WRITE
UPDATE students
SET
    name = $2,
    email = $3,
    roll_no = $4,
    department_id = $5,
    year = $6,
    phone = $7
WHERE id = $1
RETURNING id, name, email, roll_no, year, phone;


-- ------------------------------------------------------------
-- 2.6 Delete student and dependent records
-- ------------------------------------------------------------

-- WRITE (TRANSACTION)
BEGIN;

-- READ
SELECT id
FROM students
WHERE id = $1
FOR UPDATE;

-- WRITE
DELETE FROM attendance a
USING registrations r
WHERE a.registration_id = r.id
  AND r.student_id = $1;

-- WRITE
DELETE FROM registrations
WHERE student_id = $1;

-- WRITE
DELETE FROM students
WHERE id = $1
RETURNING id;

-- WRITE (TRANSACTION)
COMMIT;


-- ============================================================
-- 3. EVENTS
-- ============================================================

-- ------------------------------------------------------------
-- 3.1 Count events for pagination
-- ------------------------------------------------------------

-- READ
SELECT COUNT(*) AS total
FROM events e
WHERE
    ($1::TEXT IS NULL
        OR e.title ILIKE $1
        OR e.venue ILIKE $1)
    AND ($2::VARCHAR IS NULL OR e.category = $2);


-- ------------------------------------------------------------
-- 3.2 List events with registration count
-- ------------------------------------------------------------

-- READ
SELECT
    e.id,
    e.title,
    e.description,
    e.category,
    e.venue,
    e.event_date,
    e.capacity,
    COUNT(r.id) AS registered
FROM events e
LEFT JOIN registrations r
    ON r.event_id = e.id
   AND r.status = 'registered'
WHERE
    ($1::TEXT IS NULL
        OR e.title ILIKE $1
        OR e.venue ILIKE $1)
    AND ($2::VARCHAR IS NULL OR e.category = $2)
GROUP BY e.id
ORDER BY e.event_date, e.id
LIMIT $3
OFFSET $4;


-- ------------------------------------------------------------
-- 3.3 Get one event and its active registration count
-- ------------------------------------------------------------

-- READ
SELECT
    e.id,
    e.title,
    e.description,
    e.category,
    e.venue,
    e.event_date,
    e.registration_deadline,
    e.capacity,
    e.status,
    e.created_at,
    e.updated_at,
    COUNT(r.id) AS registered
FROM events e
LEFT JOIN registrations r
    ON r.event_id = e.id
   AND r.status = 'registered'
WHERE e.id = $1
GROUP BY e.id;


-- ------------------------------------------------------------
-- 3.4 Get registered students for an event
-- ------------------------------------------------------------

-- READ
SELECT
    r.id,
    r.student_id,
    r.event_id,
    r.registered_at,
    s.name AS student_name,
    s.roll_no,
    d.code AS department,
    e.title AS event_title,
    e.event_date,
    a.status AS attendance_status
FROM registrations r
JOIN students s ON s.id = r.student_id
JOIN departments d ON d.id = s.department_id
JOIN events e ON e.id = r.event_id
LEFT JOIN attendance a ON a.registration_id = r.id
WHERE r.event_id = $1
  AND r.status = 'registered'
ORDER BY r.id;


-- ------------------------------------------------------------
-- 3.5 Create event
-- ------------------------------------------------------------

-- WRITE
INSERT INTO events (
    title,
    description,
    category,
    venue,
    event_date,
    capacity
)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING
    id, title, description, category, venue, event_date, capacity, status;


-- ------------------------------------------------------------
-- 3.6 Lock event before changing capacity
-- ------------------------------------------------------------

-- READ
SELECT id, capacity, status
FROM events
WHERE id = $1
FOR UPDATE;


-- ------------------------------------------------------------
-- 3.7 Count active registrations before reducing capacity
-- ------------------------------------------------------------

-- READ
SELECT COUNT(*) AS registered
FROM registrations
WHERE event_id = $1
  AND status = 'registered';


-- ------------------------------------------------------------
-- 3.8 Update event
-- ------------------------------------------------------------

-- WRITE
UPDATE events
SET
    title = $2,
    description = $3,
    category = $4,
    venue = $5,
    event_date = $6,
    capacity = $7
WHERE id = $1
RETURNING id, title, description, category, venue, event_date, capacity, status;


-- ------------------------------------------------------------
-- 3.9 Delete event and dependent records
-- ------------------------------------------------------------

-- WRITE (TRANSACTION)
BEGIN;

-- READ
SELECT id
FROM events
WHERE id = $1
FOR UPDATE;

-- WRITE
DELETE FROM attendance a
USING registrations r
WHERE a.registration_id = r.id
  AND r.event_id = $1;

-- WRITE
DELETE FROM registrations
WHERE event_id = $1;

-- WRITE
DELETE FROM events
WHERE id = $1
RETURNING id;

-- WRITE (TRANSACTION)
COMMIT;


-- ============================================================
-- 4. REGISTRATIONS
-- ============================================================

-- ------------------------------------------------------------
-- 4.1 Count registrations for pagination
-- ------------------------------------------------------------

-- READ
SELECT COUNT(*) AS total
FROM registrations r
JOIN students s ON s.id = r.student_id
JOIN events e ON e.id = r.event_id
WHERE r.status = 'registered'
  AND (
        $1::TEXT IS NULL
        OR s.name ILIKE $1
        OR s.roll_no ILIKE $1
        OR e.title ILIKE $1
      )
  AND ($2::BIGINT IS NULL OR r.event_id = $2);


-- ------------------------------------------------------------
-- 4.2 List registrations with joined student/event details
-- ------------------------------------------------------------

-- READ
SELECT
    r.id,
    r.student_id,
    r.event_id,
    r.registered_at,
    s.name AS student_name,
    s.roll_no,
    d.code AS department,
    e.title AS event_title,
    e.event_date,
    a.status AS attendance_status
FROM registrations r
JOIN students s ON s.id = r.student_id
JOIN departments d ON d.id = s.department_id
JOIN events e ON e.id = r.event_id
LEFT JOIN attendance a ON a.registration_id = r.id
WHERE r.status = 'registered'
  AND (
        $1::TEXT IS NULL
        OR s.name ILIKE $1
        OR s.roll_no ILIKE $1
        OR e.title ILIKE $1
      )
  AND ($2::BIGINT IS NULL OR r.event_id = $2)
ORDER BY r.registered_at DESC, r.id DESC
LIMIT $3
OFFSET $4;


-- ------------------------------------------------------------
-- 4.3 Lock the event before creating a registration
-- ------------------------------------------------------------

-- READ
SELECT id, capacity, status, registration_deadline
FROM events
WHERE id = $1
FOR UPDATE;


-- ------------------------------------------------------------
-- 4.4 Check student exists and is active
-- ------------------------------------------------------------

-- READ
SELECT id
FROM students
WHERE id = $1
  AND status = 'active';


-- ------------------------------------------------------------
-- 4.5 Count current active registrations for capacity check
-- ------------------------------------------------------------

-- READ
SELECT COUNT(*) AS registered
FROM registrations
WHERE event_id = $1
  AND status = 'registered';


-- ------------------------------------------------------------
-- 4.6 Create registration
-- ------------------------------------------------------------

-- WRITE
INSERT INTO registrations (student_id, event_id)
VALUES ($1, $2)
RETURNING id, student_id, event_id, registered_at, status;


-- ------------------------------------------------------------
-- 4.7 Return a registration with joined details
-- ------------------------------------------------------------

-- READ
SELECT
    r.id,
    r.student_id,
    r.event_id,
    r.registered_at,
    s.name AS student_name,
    s.roll_no,
    d.code AS department,
    e.title AS event_title,
    e.event_date,
    a.status AS attendance_status
FROM registrations r
JOIN students s ON s.id = r.student_id
JOIN departments d ON d.id = s.department_id
JOIN events e ON e.id = r.event_id
LEFT JOIN attendance a ON a.registration_id = r.id
WHERE r.id = $1;


-- ------------------------------------------------------------
-- 4.8 Delete registration and its attendance
-- ------------------------------------------------------------

-- WRITE (TRANSACTION)
BEGIN;

-- READ
SELECT id
FROM registrations
WHERE id = $1
FOR UPDATE;

-- WRITE
DELETE FROM attendance
WHERE registration_id = $1;

-- WRITE
DELETE FROM registrations
WHERE id = $1
RETURNING id;

-- WRITE (TRANSACTION)
COMMIT;


-- ============================================================
-- 5. ATTENDANCE
-- ============================================================

-- ------------------------------------------------------------
-- 5.1 Attendance sheet for one event
-- ------------------------------------------------------------

-- READ
SELECT
    r.id,
    r.student_id,
    r.event_id,
    r.registered_at,
    s.name AS student_name,
    s.roll_no,
    d.code AS department,
    e.title AS event_title,
    e.event_date,
    a.status AS attendance_status
FROM registrations r
JOIN students s ON s.id = r.student_id
JOIN departments d ON d.id = s.department_id
JOIN events e ON e.id = r.event_id
LEFT JOIN attendance a ON a.registration_id = r.id
WHERE r.event_id = $1
  AND r.status = 'registered'
ORDER BY s.name, r.id;


-- ------------------------------------------------------------
-- 5.2 Mark or update attendance for one registration
-- ------------------------------------------------------------

-- WRITE
INSERT INTO attendance (registration_id, status, check_in_method)
SELECT r.id, $2, 'manual'
FROM registrations r
WHERE r.id = $1
  AND r.status = 'registered'
ON CONFLICT (registration_id)
DO UPDATE SET
    status = EXCLUDED.status,
    check_in_method = EXCLUDED.check_in_method,
    marked_at = NOW()
RETURNING registration_id, status, check_in_method, marked_at;


-- ------------------------------------------------------------
-- 5.3 Mark all active registrations for an event
-- ------------------------------------------------------------

-- WRITE
INSERT INTO attendance (registration_id, status, check_in_method)
SELECT r.id, $2, 'bulk'
FROM registrations r
WHERE r.event_id = $1
  AND r.status = 'registered'
ON CONFLICT (registration_id)
DO UPDATE SET
    status = EXCLUDED.status,
    check_in_method = EXCLUDED.check_in_method,
    marked_at = NOW()
RETURNING registration_id, status, check_in_method, marked_at;


-- ============================================================
-- 6. ANALYTICS
-- ============================================================

-- ------------------------------------------------------------
-- 6.1 Dashboard summary
-- ------------------------------------------------------------

-- READ
SELECT
    (SELECT COUNT(*) FROM students) AS total_students,
    (SELECT COUNT(*) FROM events) AS total_events,
    (SELECT COUNT(*) FROM registrations WHERE status = 'registered') AS total_registrations,
    COALESCE(
        (
            SELECT ROUND(
                100.0 * COUNT(*) FILTER (WHERE status = 'present')
                / NULLIF(COUNT(*), 0)
            )::INTEGER
            FROM attendance
        ),
        0
    ) AS avg_attendance;


-- ------------------------------------------------------------
-- 6.2 Top five events by active registrations
-- ------------------------------------------------------------

-- READ
SELECT
    e.id AS event_id,
    e.title,
    COUNT(r.id) AS registrations
FROM events e
LEFT JOIN registrations r
    ON r.event_id = e.id
   AND r.status = 'registered'
GROUP BY e.id, e.title
ORDER BY registrations DESC, e.id
LIMIT 5;


-- ------------------------------------------------------------
-- 6.3 Department-wise participation
-- ------------------------------------------------------------

-- READ
SELECT
    d.code AS department,
    COUNT(r.id) AS participation
FROM departments d
JOIN students s ON s.department_id = d.id
JOIN registrations r
    ON r.student_id = s.id
   AND r.status = 'registered'
GROUP BY d.id, d.code
ORDER BY participation DESC, d.code;


-- ------------------------------------------------------------
-- 6.4 Attendance analytics by event
-- ------------------------------------------------------------

-- READ
SELECT
    event_id,
    title,
    total_registrations AS registered,
    present_count AS present,
    attendance_percentage AS percentage
FROM v_event_analytics
ORDER BY event_date, event_id;


-- ------------------------------------------------------------
-- 6.5 Monthly registrations
-- ------------------------------------------------------------

-- READ
SELECT
    TO_CHAR(month, 'YYYY-MM') AS month,
    registrations
FROM v_monthly_registrations
ORDER BY month;


-- ============================================================
-- 7. QUERY COVERAGE
-- ============================================================
--
-- API module       READ operations                   WRITE operations
-- -------------------------------------------------------------------
-- Health           database time                     none
-- Students         list/count, department lookup     create/update/delete
-- Events           list/count/detail, registrations  create/update/delete
-- Registrations    list/count, event/student/capacity create/delete
-- Attendance       event attendance sheet            mark one/mark bulk
-- Analytics        summary, top events, departments,
--                  event attendance, monthly trend    none
--
-- Implementation note:
-- 1. Event_Sessions appears in the normalization document but is not
--    part of the implemented schema in dbms/03_schema.sql; these queries
--    therefore use the current five-table implementation.
-- ============================================================
