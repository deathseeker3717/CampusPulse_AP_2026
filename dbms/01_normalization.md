# Database Normalization

## 1. Project Overview

CampusPulse is a campus event management and analytics platform designed to manage students, events, registrations, event sessions, and attendance.

The database design aims to minimize data redundancy, prevent insertion, update, and deletion anomalies, and maintain data consistency through relational constraints.

The proposed logical database design contains five main entities:

1. **Students** – stores student information.
2. **Events** – stores information about campus events.
3. **Event_Sessions** – stores individual sessions belonging to an event.
4. **Registrations** – records students registering for events.
5. **Attendance** – records a registered student's attendance at individual event sessions.

The design supports both single-session and multi-session events. An event with only one session does not require a different database structure from an event with multiple sessions.

## 2. Initial Unnormalized Structure (UNF)

Consider an initial event registration record containing student details, event details, session information, registration information, and attendance information.

| Student ID | Student Name | Email | Event ID | Event Name | Registration Date | Sessions Attended |
|---|---|---|---|---|---|---|
| S101 | Aarav | aarav@example.com | E101 | Tech Fest | 2026-11-10 | Opening Ceremony, Workshop |
| S102 | Riya | riya@example.com | E101 | Tech Fest | 2026-11-10 | Opening Ceremony |
| S101 | Aarav | aarav@example.com | E102 | Coding Workshop | 2026-11-11 | Main Session |

The `Sessions Attended` attribute contains multiple values in a single field. Student and event information is also repeated across records.

This structure introduces redundancy and can lead to insertion, update, and deletion anomalies.

## 3. First Normal Form (1NF)

A relation is in First Normal Form when:

- Every attribute contains a single atomic value.
- There are no repeating groups or multivalued attributes.
- Each record can be uniquely identified.

To achieve 1NF, each session attendance value is represented as an individual row.

The initial relation can be represented as:

`Event_Attendance(Student_ID, Student_Name, Email, Event_ID, Event_Name, Registration_Date, Session_ID, Session_Name, Attendance_Status)`

Each row represents one student's attendance record for one session of an event.

For this example, assume:
- A student can register for a particular event only once.
- A student can have at most one attendance record for a particular session.

The candidate key for the attendance-level relation is `(Student_ID, Event_ID, Session_ID)`.

Although the values are now atomic, student, event, and session information still repeats across multiple records.

## 4. Second Normal Form (2NF)

A relation is in Second Normal Form when:

- It is already in 1NF.
- Every non-key attribute depends on the whole candidate key.
- There are no partial dependencies on part of a composite candidate key.

For the initial attendance-level relation, the candidate key is:

`(Student_ID, Event_ID, Session_ID)`

The relevant functional dependencies are:

- `Student_ID → Student_Name, Email`
- `Event_ID → Event_Name`
- `Session_ID → Event_ID, Session_Name`
- `(Student_ID, Event_ID) → Registration_Date`
- `(Student_ID, Event_ID, Session_ID) → Attendance_Status`

Student information depends only on `Student_ID`, while event information depends only on `Event_ID`. Session information depends only on `Session_ID`.

These are partial dependencies because the corresponding attributes do not depend on the entire composite candidate key.

To remove these partial dependencies, the relation is decomposed into separate relations:

### Students

| Student_ID (PK) | Student_Name | Email |
|---|---|---|
| S101 | Aarav | aarav@example.com |
| S102 | Riya | riya@example.com |

### Events

| Event_ID (PK) | Event_Name |
|---|---|
| E101 | Tech Fest |
| E102 | Coding Workshop |

### Event_Sessions

| Session_ID (PK) | Event_ID (FK) | Session_Name |
|---|---|---|
| ES101 | E101 | Opening Ceremony |
| ES102 | E101 | Workshop |
| ES201 | E102 | Main Session |

### Registrations

| Student_ID (PK, FK) | Event_ID (PK, FK) | Registration_Date |
|---|---|---|
| S101 | E101 | 2026-11-10 |
| S102 | E101 | 2026-11-10 |
| S101 | E102 | 2026-11-11 |

### Attendance

| Student_ID | Event_ID | Session_ID | Attendance_Status |
|---|---|---|---|
| S101 | E101 | ES101 | Present |
| S101 | E101 | ES102 | Present |
| S102 | E101 | ES101 | Present |
| S101 | E102 | ES201 | Present |

The student, event, and session details are now maintained separately. This removes the partial dependencies from the original attendance-level relation.

## 5. Third Normal Form (3NF)

A relation is in Third Normal Form when:

- It is already in 2NF.
- It contains no transitive dependencies of non-key attributes on candidate keys.

The final design uses independent identifiers for registrations and attendance records. This provides stable identifiers for application-level operations while preserving the natural uniqueness rules.

### 5.1 Students

| Attribute | Constraint |
|---|---|
| student_id | Primary Key |
| student_name | NOT NULL |
| email | NOT NULL, UNIQUE |

Functional dependency:

`student_id → student_name, email`

Each student is identified by a unique student ID. Student information is stored independently of registrations and events.

### 5.2 Events

| Attribute | Constraint |
|---|---|
| event_id | Primary Key |
| event_name | NOT NULL |
| description | Optional |
| capacity | NOT NULL |

Functional dependency:

`event_id → event_name, description, capacity`

The Events relation stores information about the overall event.

The event's scheduled dates, times, and venues are maintained in Event_Sessions because one event may contain multiple sessions with different schedules or venues.

### 5.3 Event_Sessions

| Attribute | Constraint |
|---|---|
| session_id | Primary Key |
| event_id | Foreign Key → Events |
| session_name | NOT NULL |
| starts_at | NOT NULL |
| ends_at | NOT NULL |
| venue | NOT NULL |

Functional dependency:

`session_id → event_id, session_name, starts_at, ends_at, venue`

Each session belongs to exactly one event. An event can have one or more sessions.

This relation avoids storing multiple session dates, times, and venues in a single event record.

### 5.4 Registrations

| Attribute | Constraint |
|---|---|
| registration_id | Primary Key |
| student_id | Foreign Key → Students |
| event_id | Foreign Key → Events |
| registered_at | NOT NULL |
| registration_status | NOT NULL |

Functional dependency:

`registration_id → student_id, event_id, registered_at, registration_status`

A UNIQUE constraint on `(student_id, event_id)` ensures that a student cannot register for the same event more than once.

The registration ID provides a stable identifier, while the unique constraint preserves the business rule.

### 5.5 Attendance

| Attribute | Constraint |
|---|---|
| attendance_id | Primary Key |
| registration_id | Foreign Key → Registrations |
| session_id | Foreign Key → Event_Sessions |
| attendance_status | NOT NULL |
| check_in_time | Optional |

Functional dependency:

`attendance_id → registration_id, session_id, attendance_status, check_in_time`

A UNIQUE constraint on `(registration_id, session_id)` ensures that only one attendance record can exist for a particular registration and session.

Attendance is therefore tracked at the session level rather than only at the overall event level.

An additional integrity rule must ensure that the session belongs to the same event as the registration. This can be enforced through composite foreign keys or an appropriate database constraint/trigger.

Separating these relations removes unnecessary duplication and allows attendance to be managed independently for each session.

## 6. Final Normalized Schema

The proposed logical relational schema is:

```text
STUDENTS
--------
student_id (PK)
student_name
email (UNIQUE)

EVENTS
------
event_id (PK)
event_name
description
capacity

EVENT_SESSIONS
--------------
session_id (PK)
event_id (FK)
session_name
starts_at
ends_at
venue

REGISTRATIONS
-------------
registration_id (PK)
student_id (FK)
event_id (FK)
registered_at
registration_status
UNIQUE(student_id, event_id)

ATTENDANCE
----------
attendance_id (PK)
registration_id (FK)
session_id (FK)
attendance_status
check_in_time
UNIQUE(registration_id, session_id)
```

### Relationships

- One student can have multiple registrations.
- One event can have multiple registrations.
- One event can contain multiple sessions.
- Each session belongs to exactly one event.
- Each registration belongs to exactly one student and one event.
- One registration can have attendance records for multiple sessions.
- Each attendance record belongs to one registration and one session.
- A student must be registered for an event before attendance can be recorded for its sessions.

Registrations resolve the many-to-many relationship between Students and Events.

Event_Sessions separates the overall event from its individual scheduled sessions.

Attendance records participation at the session level.

## 7. Benefits of Normalization

The proposed normalized design provides the following benefits:

1. Reduces redundant storage of student and event information.
2. Prevents inconsistent updates to student, event, and session records.
3. Avoids storing multiple session values in a single attribute.
4. Maintains referential integrity through primary and foreign keys.
5. Supports events with either one session or multiple sessions.
6. Tracks attendance separately for each session.
7. Provides a structured foundation for registration, attendance, and participation analytics.

## 8. Design Assumptions

The following assumptions define the current proposed logical design:

1. Every student has a unique student ID and email address.
2. Every event has a unique event ID.
3. An event can contain one or more sessions.
4. Each session belongs to exactly one event.
5. A student can register for a particular event only once.
6. A registration belongs to exactly one student and one event.
7. Attendance is recorded at the session level.
8. A registration can have at most one attendance record per session.
9. Attendance can only be recorded for a session belonging to the event for which the student is registered.
10. A registration may exist without any attendance records.
11. Event capacity represents the maximum number of registrations accepted for an event; the exact registration-status and capacity-enforcement rules must be defined by the application requirements.
12. Session-specific capacity limits are not included in the current design and can be introduced if required.

## 9. Scope and Implementation Notes

This document describes the proposed logical database design for CampusPulse.

The five relations form the current design baseline. The actual PostgreSQL implementation must preserve the documented primary keys, foreign keys, unique constraints, and relationship rules.

The following details remain subject to confirmation during implementation:

- Allowed registration and attendance status values.
- Whether cancelled registrations count toward event capacity.
- Whether session-specific capacity limits are required.
- Whether organizers, departments, or additional event-management roles need separate entities.
- Whether attendance requires check-in timestamps, multiple checkpoints, or other tracking information.

Analytics should primarily be derived from registration and attendance data rather than duplicated as manually maintained transactional records.

Any future changes to these requirements should be reflected in the logical schema, ER diagram, and database implementation together.