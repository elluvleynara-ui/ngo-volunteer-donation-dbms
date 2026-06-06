-- 1. NGO
CREATE TABLE NGO (
    ngo_id       NUMBER PRIMARY KEY,
    name         VARCHAR2(200) NOT NULL,
    address      VARCHAR2(300),
    phone        VARCHAR2(30),
    email        VARCHAR2(100),
    mission      VARCHAR2(1000),
    founded_date DATE
);

-- 2. STAFF
CREATE TABLE STAFF (
    staff_id  NUMBER PRIMARY KEY,
    ngo_id    NUMBER NOT NULL,
    first_name VARCHAR2(50) NOT NULL,
    last_name  VARCHAR2(50) NOT NULL,
    role       VARCHAR2(50),
    email      VARCHAR2(100),
    phone      VARCHAR2(30),
    hire_date  DATE,
    salary     NUMBER(12,2),
    CONSTRAINT fk_staff_ngo FOREIGN KEY (ngo_id) REFERENCES NGO(ngo_id)
);

-- 3. VOLUNTEER
CREATE TABLE VOLUNTEER (
    volunteer_id      NUMBER PRIMARY KEY,
    first_name        VARCHAR2(50) NOT NULL,
    last_name         VARCHAR2(50) NOT NULL,
    phone             VARCHAR2(30),
    email             VARCHAR2(100),
    skills            VARCHAR2(100),
    availability      VARCHAR2(50),
    registration_date DATE
);

-- 4. DONOR
CREATE TABLE DONOR (
    donor_id   NUMBER PRIMARY KEY,
    name       VARCHAR2(100) NOT NULL,
    donor_type VARCHAR2(30),
    phone      VARCHAR2(30),
    email      VARCHAR2(100),
    address    VARCHAR2(300)
);

-- 5. PROJECTS
CREATE TABLE PROJECTS (
    project_id  NUMBER PRIMARY KEY,
    ngo_id      NUMBER NOT NULL,
    staff_id    NUMBER NOT NULL,
    name        VARCHAR2(200) NOT NULL,
    description VARCHAR2(1000),
    start_date  DATE,
    end_date    DATE,
    budget      NUMBER(15,2),
    CONSTRAINT fk_projects_ngo   FOREIGN KEY (ngo_id)   REFERENCES NGO(ngo_id),
    CONSTRAINT fk_projects_staff FOREIGN KEY (staff_id) REFERENCES STAFF(staff_id)
);

-- 6. DONATION
CREATE TABLE DONATION (
    donation_id      NUMBER PRIMARY KEY,
    donor_id         NUMBER NOT NULL,
    project_id       NUMBER NOT NULL,
    donation_date    DATE,
    amount           NUMBER(15,2),
    payment_method   VARCHAR2(30),
    status           VARCHAR2(20),
    donation_comment VARCHAR2(300),
    CONSTRAINT fk_donation_donor   FOREIGN KEY (donor_id)   REFERENCES DONOR(donor_id),
    CONSTRAINT fk_donation_project FOREIGN KEY (project_id) REFERENCES PROJECTS(project_id)
);

-- 7. EVENTS
CREATE TABLE EVENTS (
    event_id    NUMBER PRIMARY KEY,
    project_id  NUMBER NOT NULL,
    name        VARCHAR2(200) NOT NULL,
    event_date  DATE,
    location    VARCHAR2(200),
    description VARCHAR2(500),
    CONSTRAINT fk_events_project FOREIGN KEY (project_id) REFERENCES PROJECTS(project_id)
);

-- 8. TASKS
CREATE TABLE TASKS (
    task_id     NUMBER PRIMARY KEY,
    event_id    NUMBER NOT NULL,
    task_name   VARCHAR2(200) NOT NULL,
    description VARCHAR2(500),
    priority    VARCHAR2(20),
    status      VARCHAR2(30),
    CONSTRAINT fk_tasks_event FOREIGN KEY (event_id) REFERENCES EVENTS(event_id)
);

-- 9. EVENT_VOLUNTEERS
CREATE TABLE EVENT_VOLUNTEERS (
    ev_id                NUMBER PRIMARY KEY,
    event_id             NUMBER NOT NULL,
    volunteer_id         NUMBER NOT NULL,
    participation_status VARCHAR2(30),
    hours_volunteered    NUMBER(6,2),
    CONSTRAINT fk_ev_event     FOREIGN KEY (event_id)     REFERENCES EVENTS(event_id),
    CONSTRAINT fk_ev_volunteer FOREIGN KEY (volunteer_id) REFERENCES VOLUNTEER(volunteer_id)
);

-- 10. EXPENSES
CREATE TABLE EXPENSES (
    expense_id   NUMBER PRIMARY KEY,
    project_id   NUMBER NOT NULL,
    staff_id     NUMBER NOT NULL,
    amount       NUMBER(15,2),
    expense_date DATE,
    category     VARCHAR2(50),
    description  VARCHAR2(300),
    CONSTRAINT fk_expenses_project FOREIGN KEY (project_id) REFERENCES PROJECTS(project_id),
    CONSTRAINT fk_expenses_staff   FOREIGN KEY (staff_id)   REFERENCES STAFF(staff_id)
);