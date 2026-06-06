-- ============================================================
-- VOLUNTEER AND DONATION MANAGEMENT SYSTEM FOR NGOs
-- PL/SQL Blocks
-- ============================================================
 
-- ============================================================
-- FUNCTIONS & PROCEDURES (6)
-- ============================================================
 
-- FUNCTION 1: Get total donations for a project
CREATE OR REPLACE FUNCTION get_project_donations(p_project_id IN NUMBER)
RETURN NUMBER IS
    v_total NUMBER := 0;
BEGIN
    SELECT NVL(SUM(amount), 0)
    INTO v_total
    FROM DONATION
    WHERE project_id = p_project_id;
    RETURN v_total;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 0;
END get_project_donations;
/

-- Test
SELECT get_project_donations(1) AS total_donations FROM dual;

-- FUNCTION 2: Get volunteer total hours
CREATE OR REPLACE FUNCTION get_volunteer_hours(p_volunteer_id IN NUMBER)
RETURN NUMBER IS
    v_hours NUMBER := 0;
BEGIN
    SELECT NVL(SUM(hours_volunteered), 0)
    INTO v_hours
    FROM EVENT_VOLUNTEERS
    WHERE volunteer_id = p_volunteer_id;
    RETURN v_hours;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 0;
END get_volunteer_hours;
/

-- Test
SELECT get_volunteer_hours(1) AS total_hours FROM dual;

-- FUNCTION 3: Calculate project budget utilization percentage
CREATE OR REPLACE FUNCTION get_budget_utilization(p_project_id IN NUMBER)
RETURN NUMBER IS
    v_budget    NUMBER;
    v_expenses  NUMBER;
BEGIN
    SELECT budget INTO v_budget
    FROM PROJECTS WHERE project_id = p_project_id;

    SELECT NVL(SUM(amount), 0) INTO v_expenses
    FROM EXPENSES WHERE project_id = p_project_id;

    IF v_budget = 0 OR v_budget IS NULL THEN
        RETURN 0;
    END IF;
    RETURN ROUND(v_expenses / v_budget * 100, 2);
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 0;
END get_budget_utilization;
/

-- Test
SELECT get_budget_utilization(1) AS utilization_pct FROM dual;

-- PROCEDURE 4: Print full financial report for a project
CREATE OR REPLACE PROCEDURE project_financial_report(p_project_id IN NUMBER) IS
    v_name      PROJECTS.name%TYPE;
    v_budget    NUMBER;
    v_donated   NUMBER;
    v_expenses  NUMBER;
    v_balance   NUMBER;
BEGIN
    SELECT name, budget INTO v_name, v_budget
    FROM PROJECTS WHERE project_id = p_project_id;

    SELECT NVL(SUM(amount), 0) INTO v_donated
    FROM DONATION WHERE project_id = p_project_id;

    SELECT NVL(SUM(amount), 0) INTO v_expenses
    FROM EXPENSES WHERE project_id = p_project_id;

    v_balance := v_donated - v_expenses;

    DBMS_OUTPUT.PUT_LINE('=== FINANCIAL REPORT: ' || v_name || ' ===');
    DBMS_OUTPUT.PUT_LINE('Budget:          ' || v_budget);
    DBMS_OUTPUT.PUT_LINE('Total Donated:   ' || v_donated);
    DBMS_OUTPUT.PUT_LINE('Total Expenses:  ' || v_expenses);
    DBMS_OUTPUT.PUT_LINE('Net Balance:     ' || v_balance);
    DBMS_OUTPUT.PUT_LINE('Status: ' ||
        CASE WHEN v_balance > 0 THEN 'PROFITABLE'
             WHEN v_balance < 0 THEN 'DEFICIT'
             ELSE 'BREAK-EVEN' END);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Project ' || p_project_id || ' not found.');
END project_financial_report;
/

-- Test
BEGIN project_financial_report(1); END;
/

-- PROCEDURE 5: Register volunteer to an event
CREATE OR REPLACE PROCEDURE register_volunteer(
    p_event_id     IN NUMBER,
    p_volunteer_id IN NUMBER,
    p_hours        IN NUMBER DEFAULT 0
) IS
    v_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_exists
    FROM EVENT_VOLUNTEERS
    WHERE event_id = p_event_id AND volunteer_id = p_volunteer_id;

    IF v_exists > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Volunteer already registered for this event.');
        RETURN;
    END IF;

    INSERT INTO EVENT_VOLUNTEERS (ev_id, event_id, volunteer_id, participation_status, hours_volunteered)
    VALUES (
        (SELECT NVL(MAX(ev_id), 0) + 1 FROM EVENT_VOLUNTEERS),
        p_event_id, p_volunteer_id, 'ASSIGNED', p_hours
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Volunteer ' || p_volunteer_id || ' registered for event ' || p_event_id);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END register_volunteer;
/

-- Test
BEGIN register_volunteer(1, 1, 5); END;
/

-- PROCEDURE 6: Update all task statuses for completed events
CREATE OR REPLACE PROCEDURE close_event_tasks(p_event_id IN NUMBER) IS
    v_count NUMBER;
BEGIN
    UPDATE TASKS
    SET status = 'COMPLETED'
    WHERE event_id = p_event_id
      AND status != 'COMPLETED';

    v_count := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE(v_count || ' tasks marked as COMPLETED for event ' || p_event_id);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END close_event_tasks;
/

-- Test
BEGIN close_event_tasks(1); END;
/

-- ============================================================
-- CURSORS & RECORDS (5)
-- ============================================================

-- CURSOR 1: List all volunteers for a specific event
DECLARE
    CURSOR c_event_volunteers(p_event_id NUMBER) IS
        SELECT v.volunteer_id,
               v.first_name || ' ' || v.last_name AS full_name,
               v.skills,
               ev.participation_status,
               ev.hours_volunteered
        FROM VOLUNTEER v
        JOIN EVENT_VOLUNTEERS ev ON ev.volunteer_id = v.volunteer_id
        WHERE ev.event_id = p_event_id
        ORDER BY ev.hours_volunteered DESC;

    v_rec c_event_volunteers%ROWTYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== VOLUNTEERS FOR EVENT 1 ===');
    OPEN c_event_volunteers(1);
    LOOP
        FETCH c_event_volunteers INTO v_rec;
        EXIT WHEN c_event_volunteers%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(
            v_rec.full_name || ' | ' || v_rec.skills ||
            ' | ' || v_rec.participation_status ||
            ' | Hours: ' || v_rec.hours_volunteered
        );
    END LOOP;
    CLOSE c_event_volunteers;
END;
/

-- CURSOR 2: Projects with budget deficit using explicit cursor
DECLARE
    CURSOR c_deficit_projects IS
        SELECT p.project_id, p.name, p.budget,
               NVL(SUM(e.amount), 0) AS total_expenses,
               NVL(SUM(e.amount), 0) - p.budget AS deficit
        FROM PROJECTS p
        LEFT JOIN EXPENSES e ON e.project_id = p.project_id
        GROUP BY p.project_id, p.name, p.budget
        HAVING NVL(SUM(e.amount), 0) > p.budget
        ORDER BY deficit DESC;

    TYPE t_project_rec IS RECORD (
        project_id  NUMBER,
        name        VARCHAR2(200),
        budget      NUMBER,
        expenses    NUMBER,
        deficit     NUMBER
    );
    v_proj  t_project_rec;
    v_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== PROJECTS OVER BUDGET ===');
    OPEN c_deficit_projects;
    LOOP
        FETCH c_deficit_projects INTO v_proj.project_id, v_proj.name,
              v_proj.budget, v_proj.expenses, v_proj.deficit;
        EXIT WHEN c_deficit_projects%NOTFOUND;
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            v_proj.name || ' | Budget: ' || v_proj.budget ||
            ' | Expenses: ' || v_proj.expenses ||
            ' | Deficit: ' || v_proj.deficit
        );
    END LOOP;
    CLOSE c_deficit_projects;
    DBMS_OUTPUT.PUT_LINE('Total over-budget projects: ' || v_count);
END;
/

-- CURSOR 3: NGO staff report using %ROWTYPE record
DECLARE
    CURSOR c_staff(p_ngo_id NUMBER) IS
        SELECT * FROM STAFF WHERE ngo_id = p_ngo_id ORDER BY salary DESC;
    v_staff STAFF%ROWTYPE;
    v_total_salary NUMBER := 0;
    v_count        NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== STAFF REPORT FOR NGO 1 ===');
    OPEN c_staff(1);
    LOOP
        FETCH c_staff INTO v_staff;
        EXIT WHEN c_staff%NOTFOUND;
        v_total_salary := v_total_salary + NVL(v_staff.salary, 0);
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            v_staff.first_name || ' ' || v_staff.last_name ||
            ' | Role: ' || v_staff.role ||
            ' | Salary: ' || v_staff.salary
        );
    END LOOP;
    CLOSE c_staff;
    DBMS_OUTPUT.PUT_LINE('Total staff: ' || v_count);
    DBMS_OUTPUT.PUT_LINE('Total payroll: ' || v_total_salary);
    DBMS_OUTPUT.PUT_LINE('Avg salary: ' || ROUND(v_total_salary / NULLIF(v_count, 0), 2));
END;
/

-- CURSOR 4: Top donors report with cumulative total
DECLARE
    CURSOR c_top_donors IS
        SELECT dn.donor_id, dn.name, dn.donor_type,
               SUM(d.amount) AS total_donated
        FROM DONOR dn
        JOIN DONATION d ON d.donor_id = dn.donor_id
        GROUP BY dn.donor_id, dn.name, dn.donor_type
        ORDER BY total_donated DESC
        FETCH FIRST 10 ROWS ONLY;

    TYPE t_donor IS RECORD (
        donor_id     NUMBER,
        name         VARCHAR2(100),
        donor_type   VARCHAR2(30),
        total_donated NUMBER
    );
    v_donor       t_donor;
    v_cumulative  NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TOP 10 DONORS ===');
    OPEN c_top_donors;
    LOOP
        FETCH c_top_donors INTO v_donor;
        EXIT WHEN c_top_donors%NOTFOUND;
        v_cumulative := v_cumulative + v_donor.total_donated;
        DBMS_OUTPUT.PUT_LINE(
            v_donor.name || ' (' || v_donor.donor_type || ')' ||
            ' | Donated: ' || v_donor.total_donated ||
            ' | Cumulative: ' || v_cumulative
        );
    END LOOP;
    CLOSE c_top_donors;
END;
/

-- CURSOR 5: Monthly expense summary with implicit cursor
DECLARE
    v_month      VARCHAR2(7);
    v_total      NUMBER;
    v_prev_total NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== MONTHLY EXPENSE SUMMARY ===');
    FOR rec IN (
        SELECT TO_CHAR(expense_date, 'YYYY-MM') AS month,
               SUM(amount) AS monthly_total,
               COUNT(*) AS expense_count
        FROM EXPENSES
        GROUP BY TO_CHAR(expense_date, 'YYYY-MM')
        ORDER BY month
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            rec.month ||
            ' | Total: ' || rec.monthly_total ||
            ' | Count: ' || rec.expense_count ||
            ' | Change: ' || (rec.monthly_total - v_prev_total)
        );
        v_prev_total := rec.monthly_total;
    END LOOP;
END;
/

-- ============================================================
-- PACKAGES & EXCEPTIONS (3)
-- ============================================================

-- PACKAGE 1: NGO Analytics Package
CREATE OR REPLACE PACKAGE pkg_ngo_analytics IS
    ngo_not_found    EXCEPTION;
    project_inactive EXCEPTION;

    FUNCTION get_ngo_total_raised(p_ngo_id IN NUMBER) RETURN NUMBER;
    FUNCTION get_ngo_volunteer_count(p_ngo_id IN NUMBER) RETURN NUMBER;
    PROCEDURE print_ngo_summary(p_ngo_id IN NUMBER);
END pkg_ngo_analytics;
/

CREATE OR REPLACE PACKAGE BODY pkg_ngo_analytics IS

    FUNCTION get_ngo_total_raised(p_ngo_id IN NUMBER) RETURN NUMBER IS
        v_total  NUMBER;
        v_exists NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_exists FROM NGO WHERE ngo_id = p_ngo_id;
        IF v_exists = 0 THEN RAISE ngo_not_found; END IF;

        SELECT NVL(SUM(d.amount), 0) INTO v_total
        FROM DONATION d
        JOIN PROJECTS p ON p.project_id = d.project_id
        WHERE p.ngo_id = p_ngo_id;
        RETURN v_total;
    EXCEPTION
        WHEN ngo_not_found THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: NGO ' || p_ngo_id || ' not found.');
            RETURN NULL;
    END get_ngo_total_raised;

    FUNCTION get_ngo_volunteer_count(p_ngo_id IN NUMBER) RETURN NUMBER IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(DISTINCT ev.volunteer_id) INTO v_count
        FROM EVENT_VOLUNTEERS ev
        JOIN EVENTS e ON e.event_id = ev.event_id
        JOIN PROJECTS p ON p.project_id = e.project_id
        WHERE p.ngo_id = p_ngo_id;
        RETURN v_count;
    END get_ngo_volunteer_count;

    PROCEDURE print_ngo_summary(p_ngo_id IN NUMBER) IS
        v_name    NGO.name%TYPE;
        v_raised  NUMBER;
        v_vols    NUMBER;
        v_exists  NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_exists FROM NGO WHERE ngo_id = p_ngo_id;
        IF v_exists = 0 THEN RAISE ngo_not_found; END IF;

        SELECT name INTO v_name FROM NGO WHERE ngo_id = p_ngo_id;
        v_raised := get_ngo_total_raised(p_ngo_id);
        v_vols   := get_ngo_volunteer_count(p_ngo_id);

        DBMS_OUTPUT.PUT_LINE('=== NGO SUMMARY: ' || v_name || ' ===');
        DBMS_OUTPUT.PUT_LINE('Total Raised:     ' || v_raised);
        DBMS_OUTPUT.PUT_LINE('Unique Volunteers: ' || v_vols);
    EXCEPTION
        WHEN ngo_not_found THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: NGO ' || p_ngo_id || ' does not exist.');
    END print_ngo_summary;

END pkg_ngo_analytics;
/

-- Test
BEGIN pkg_ngo_analytics.print_ngo_summary(1); END;
/
SELECT pkg_ngo_analytics.get_ngo_total_raised(1) FROM dual;

-- PACKAGE 2: Project Finance Package
CREATE OR REPLACE PACKAGE pkg_project_finance IS
    project_not_found EXCEPTION;

    FUNCTION get_project_balance(p_project_id IN NUMBER) RETURN NUMBER;
    PROCEDURE show_financial_report(p_project_id IN NUMBER);
END pkg_project_finance;
/

CREATE OR REPLACE PACKAGE BODY pkg_project_finance IS

    FUNCTION get_project_balance(p_project_id IN NUMBER) RETURN NUMBER IS
        v_exists    NUMBER;
        v_donations NUMBER;
        v_expenses  NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_exists FROM PROJECTS WHERE project_id = p_project_id;
        IF v_exists = 0 THEN RAISE project_not_found; END IF;

        SELECT NVL(SUM(amount), 0) INTO v_donations
        FROM DONATION WHERE project_id = p_project_id;

        SELECT NVL(SUM(amount), 0) INTO v_expenses
        FROM EXPENSES WHERE project_id = p_project_id;

        RETURN v_donations - v_expenses;
    EXCEPTION
        WHEN project_not_found THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: Project does not exist.');
            RETURN NULL;
    END get_project_balance;

    PROCEDURE show_financial_report(p_project_id IN NUMBER) IS
        v_name    PROJECTS.name%TYPE;
        v_balance NUMBER;
        v_exists  NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_exists FROM PROJECTS WHERE project_id = p_project_id;
        IF v_exists = 0 THEN RAISE project_not_found; END IF;

        SELECT name INTO v_name FROM PROJECTS WHERE project_id = p_project_id;
        v_balance := get_project_balance(p_project_id);

        DBMS_OUTPUT.PUT_LINE('Project: ' || v_name);
        DBMS_OUTPUT.PUT_LINE('Balance: ' || v_balance);
        DBMS_OUTPUT.PUT_LINE('Status:  ' ||
            CASE WHEN v_balance > 0 THEN 'PROFITABLE'
                 WHEN v_balance < 0 THEN 'NEGATIVE BALANCE'
                 ELSE 'BREAK-EVEN' END);
    EXCEPTION
        WHEN project_not_found THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: Project ' || p_project_id || ' does not exist.');
    END show_financial_report;

END pkg_project_finance;
/

-- Test
BEGIN pkg_project_finance.show_financial_report(5); END;
/

-- PACKAGE 3: Volunteer Management Package
CREATE OR REPLACE PACKAGE pkg_volunteer_mgmt IS
    volunteer_not_found EXCEPTION;

    FUNCTION get_volunteer_status(p_volunteer_id IN NUMBER) RETURN VARCHAR2;
    PROCEDURE print_volunteer_history(p_volunteer_id IN NUMBER);
END pkg_volunteer_mgmt;
/

CREATE OR REPLACE PACKAGE BODY pkg_volunteer_mgmt IS

    FUNCTION get_volunteer_status(p_volunteer_id IN NUMBER) RETURN VARCHAR2 IS
        v_hours  NUMBER;
        v_exists NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_exists FROM VOLUNTEER WHERE volunteer_id = p_volunteer_id;
        IF v_exists = 0 THEN RAISE volunteer_not_found; END IF;

        SELECT NVL(SUM(hours_volunteered), 0) INTO v_hours
        FROM EVENT_VOLUNTEERS WHERE volunteer_id = p_volunteer_id;

        RETURN CASE
            WHEN v_hours >= 100 THEN 'EXPERT'
            WHEN v_hours >= 50  THEN 'EXPERIENCED'
            WHEN v_hours >= 10  THEN 'ACTIVE'
            ELSE 'BEGINNER'
        END;
    EXCEPTION
        WHEN volunteer_not_found THEN RETURN 'NOT FOUND';
    END get_volunteer_status;

    PROCEDURE print_volunteer_history(p_volunteer_id IN NUMBER) IS
        v_name   VARCHAR2(100);
        v_exists NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_exists FROM VOLUNTEER WHERE volunteer_id = p_volunteer_id;
        IF v_exists = 0 THEN RAISE volunteer_not_found; END IF;

        SELECT first_name || ' ' || last_name INTO v_name
        FROM VOLUNTEER WHERE volunteer_id = p_volunteer_id;

        DBMS_OUTPUT.PUT_LINE('=== HISTORY: ' || v_name || ' ===');
        FOR rec IN (
            SELECT e.name AS event_name,
                   TO_CHAR(e.event_date, 'YYYY-MM-DD') AS event_date,
                   ev.participation_status,
                   ev.hours_volunteered
            FROM EVENT_VOLUNTEERS ev
            JOIN EVENTS e ON e.event_id = ev.event_id
            WHERE ev.volunteer_id = p_volunteer_id
            ORDER BY e.event_date
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(
                rec.event_name || ' | ' || rec.event_date ||
                ' | ' || rec.participation_status ||
                ' | Hours: ' || rec.hours_volunteered
            );
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('Status: ' || get_volunteer_status(p_volunteer_id));
    EXCEPTION
        WHEN volunteer_not_found THEN
            DBMS_OUTPUT.PUT_LINE('Volunteer ' || p_volunteer_id || ' not found.');
    END print_volunteer_history;

END pkg_volunteer_mgmt;
/

-- Test
BEGIN pkg_volunteer_mgmt.print_volunteer_history(1); END;
/

-- ============================================================
-- COLLECTIONS (1)
-- ============================================================

-- COLLECTION: Bulk process top donors using nested table
DECLARE
    TYPE t_donor_rec IS RECORD (
        donor_id     NUMBER,
        name         VARCHAR2(100),
        total_amount NUMBER,
        category     VARCHAR2(20)
    );
    TYPE t_donor_table IS TABLE OF t_donor_rec;
    v_donors t_donor_table := t_donor_table();

    v_idx    NUMBER := 0;
BEGIN
    FOR rec IN (
        SELECT dn.donor_id, dn.name, SUM(d.amount) AS total_amount
        FROM DONOR dn
        JOIN DONATION d ON d.donor_id = dn.donor_id
        GROUP BY dn.donor_id, dn.name
        ORDER BY total_amount DESC
        FETCH FIRST 10 ROWS ONLY
    ) LOOP
        v_donors.EXTEND;
        v_idx := v_idx + 1;
        v_donors(v_idx).donor_id     := rec.donor_id;
        v_donors(v_idx).name         := rec.name;
        v_donors(v_idx).total_amount := rec.total_amount;
        v_donors(v_idx).category     :=
            CASE WHEN rec.total_amount >= 5000000 THEN 'PLATINUM'
                 WHEN rec.total_amount >= 1000000 THEN 'GOLD'
                 WHEN rec.total_amount >= 500000  THEN 'SILVER'
                 ELSE 'BRONZE' END;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('=== TOP DONOR CATEGORIES ===');
    FOR i IN 1 .. v_donors.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(
            i || '. ' || v_donors(i).name ||
            ' | ' || v_donors(i).total_amount ||
            ' | ' || v_donors(i).category
        );
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Total donors processed: ' || v_donors.COUNT);
END;
/

-- ============================================================
-- TRIGGERS (5)
-- ============================================================

-- TRIGGER 1: Prevent negative donation amount
CREATE OR REPLACE TRIGGER trg_donation_amount
BEFORE INSERT OR UPDATE ON DONATION
FOR EACH ROW
BEGIN
    IF :NEW.amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Donation amount must be positive.');
    END IF;
END;
/

-- TRIGGER 2: Auto-set registration date for new volunteers
CREATE OR REPLACE TRIGGER trg_volunteer_reg_date
BEFORE INSERT ON VOLUNTEER
FOR EACH ROW
BEGIN
    IF :NEW.registration_date IS NULL THEN
        :NEW.registration_date := SYSDATE;
    END IF;
END;
/

-- TRIGGER 3: Log expense approval — prevent expenses exceeding project budget
CREATE OR REPLACE TRIGGER trg_expense_budget_check
BEFORE INSERT ON EXPENSES
FOR EACH ROW
DECLARE
    v_budget       NUMBER;
    v_current_exp  NUMBER;
BEGIN
    SELECT budget INTO v_budget
    FROM PROJECTS WHERE project_id = :NEW.project_id;

    SELECT NVL(SUM(amount), 0) INTO v_current_exp
    FROM EXPENSES WHERE project_id = :NEW.project_id;

    IF (v_current_exp + :NEW.amount) > v_budget * 1.5 THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Expenses exceed 150% of project budget. Approval required.');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'Project not found.');
END;
/

-- TRIGGER 4: Prevent duplicate volunteer registration for same event
CREATE OR REPLACE TRIGGER trg_no_duplicate_volunteer
BEFORE INSERT ON EVENT_VOLUNTEERS
FOR EACH ROW
DECLARE
    v_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_exists
    FROM EVENT_VOLUNTEERS
    WHERE event_id = :NEW.event_id
      AND volunteer_id = :NEW.volunteer_id;

    IF v_exists > 0 THEN
        RAISE_APPLICATION_ERROR(-20004,
            'Volunteer is already registered for this event.');
    END IF;
END;
/

-- TRIGGER 5: Auto-update donation status based on amount
CREATE OR REPLACE TRIGGER trg_donation_status
BEFORE INSERT ON DONATION
FOR EACH ROW
BEGIN
    IF :NEW.status IS NULL THEN
        :NEW.status := CASE
            WHEN :NEW.amount >= 1000000 THEN 'MAJOR'
            WHEN :NEW.amount >= 100000  THEN 'RECEIVED'
            ELSE 'RECEIVED'
        END;
    END IF;
    IF :NEW.donation_date IS NULL THEN
        :NEW.donation_date := SYSDATE;
    END IF;
END;
/