-- ============================================================
-- VOLUNTEER AND DONATION MANAGEMENT SYSTEM FOR NGOs
-- Advanced SQL Queries (20)
-- ============================================================
 
-- QUERY 1: Top 5 NGOs by total donations received
-- Shows which NGOs attract the most funding
SELECT n.name AS ngo_name,
       COUNT(d.donation_id) AS total_donations,
       SUM(d.amount) AS total_amount,
       ROUND(AVG(d.amount), 2) AS avg_donation
FROM NGO n
JOIN PROJECTS p ON p.ngo_id = n.ngo_id
JOIN DONATION d ON d.project_id = p.project_id
GROUP BY n.ngo_id, n.name
ORDER BY total_amount DESC
FETCH FIRST 5 ROWS ONLY;

-- QUERY 2: Volunteer activity ranking using window functions
-- Ranks volunteers by hours contributed within each skill category
SELECT volunteer_id,
       first_name || ' ' || last_name AS full_name,
       skills,
       total_hours,
       RANK() OVER (PARTITION BY skills ORDER BY total_hours DESC) AS rank_in_skill,
       ROUND(total_hours / SUM(total_hours) OVER (PARTITION BY skills) * 100, 2) AS pct_of_skill_total
FROM (
    SELECT v.volunteer_id, v.first_name, v.last_name, v.skills,
           NVL(SUM(ev.hours_volunteered), 0) AS total_hours
    FROM VOLUNTEER v
    LEFT JOIN EVENT_VOLUNTEERS ev ON ev.volunteer_id = v.volunteer_id
    GROUP BY v.volunteer_id, v.first_name, v.last_name, v.skills
)
ORDER BY skills, rank_in_skill;

-- QUERY 3: Monthly donation trends with moving average (CTE + Window)
-- Time series analysis for financial planning
WITH monthly AS (
    SELECT TO_CHAR(donation_date, 'YYYY') AS yr,
           TO_CHAR(donation_date, 'MM') AS mo,
           SUM(amount) AS monthly_total,
           COUNT(*) AS donation_count
    FROM DONATION
    GROUP BY TO_CHAR(donation_date, 'YYYY'), TO_CHAR(donation_date, 'MM')
),
enhanced AS (
    SELECT yr, mo, monthly_total, donation_count,
           SUM(monthly_total) OVER (PARTITION BY yr ORDER BY mo) AS cumulative_yearly,
           ROUND(AVG(monthly_total) OVER (ORDER BY yr, mo ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3mo,
           ROUND((monthly_total - LAG(monthly_total,1) OVER (ORDER BY yr, mo))
               / NULLIF(LAG(monthly_total,1) OVER (ORDER BY yr, mo), 0) * 100, 2) AS growth_rate_pct
    FROM monthly
)
SELECT * FROM enhanced ORDER BY yr, mo;

-- QUERY 4: Project financial health dashboard
-- Compares budget vs actual donations vs expenses per project
SELECT p.project_id,
       p.name AS project_name,
       p.budget,
       NVL(SUM(DISTINCT d.amount), 0) AS total_donated,
       NVL(SUM(DISTINCT e.amount), 0) AS total_expenses,
       NVL(SUM(DISTINCT d.amount), 0) - NVL(SUM(DISTINCT e.amount), 0) AS net_balance,
       ROUND(NVL(SUM(DISTINCT d.amount), 0) / NULLIF(p.budget, 0) * 100, 2) AS funding_pct,
       CASE
           WHEN NVL(SUM(DISTINCT d.amount), 0) - NVL(SUM(DISTINCT e.amount), 0) > 0 THEN 'PROFITABLE'
           WHEN NVL(SUM(DISTINCT d.amount), 0) - NVL(SUM(DISTINCT e.amount), 0) < 0 THEN 'DEFICIT'
           ELSE 'BREAK-EVEN'
       END AS financial_status
FROM PROJECTS p
LEFT JOIN DONATION d ON d.project_id = p.project_id
LEFT JOIN EXPENSES e ON e.project_id = p.project_id
GROUP BY p.project_id, p.name, p.budget
ORDER BY net_balance DESC;

-- QUERY 5: Donor retention analysis using subquery
-- Identifies repeat donors vs one-time donors
SELECT donor_category,
       COUNT(*) AS donor_count,
       SUM(total_donated) AS total_contributed,
       ROUND(AVG(total_donated), 2) AS avg_contribution
FROM (
    SELECT d.donor_id,
           d.name,
           COUNT(dn.donation_id) AS donation_count,
           SUM(dn.amount) AS total_donated,
           CASE
               WHEN COUNT(dn.donation_id) = 1 THEN 'ONE-TIME'
               WHEN COUNT(dn.donation_id) BETWEEN 2 AND 5 THEN 'REGULAR'
               ELSE 'LOYAL'
           END AS donor_category
    FROM DONOR d
    JOIN DONATION dn ON dn.donor_id = d.donor_id
    GROUP BY d.donor_id, d.name
)
GROUP BY donor_category
ORDER BY total_contributed DESC;

-- QUERY 6: Event volunteer coverage analysis
-- Shows which events are understaffed
SELECT e.event_id,
       e.name AS event_name,
       e.event_date,
       e.location,
       COUNT(ev.volunteer_id) AS volunteers_assigned,
       SUM(NVL(ev.hours_volunteered, 0)) AS total_hours,
       COUNT(CASE WHEN ev.participation_status = 'PRESENT' THEN 1 END) AS attended,
       COUNT(CASE WHEN ev.participation_status = 'ABSENT' THEN 1 END) AS absent,
       ROUND(COUNT(CASE WHEN ev.participation_status = 'PRESENT' THEN 1 END) /
           NULLIF(COUNT(ev.volunteer_id), 0) * 100, 2) AS attendance_rate_pct
FROM EVENTS e
LEFT JOIN EVENT_VOLUNTEERS ev ON ev.event_id = e.event_id
GROUP BY e.event_id, e.name, e.event_date, e.location
ORDER BY attendance_rate_pct ASC NULLS LAST;

-- QUERY 7: Staff performance - projects managed and funds overseen
SELECT s.staff_id,
       s.first_name || ' ' || s.last_name AS staff_name,
       s.role,
       n.name AS ngo_name,
       COUNT(p.project_id) AS projects_managed,
       NVL(SUM(p.budget), 0) AS total_budget_managed,
       NVL(SUM(d.amount), 0) AS total_donations_raised,
       DENSE_RANK() OVER (ORDER BY NVL(SUM(d.amount), 0) DESC) AS fundraising_rank
FROM STAFF s
JOIN NGO n ON n.ngo_id = s.ngo_id
LEFT JOIN PROJECTS p ON p.staff_id = s.staff_id
LEFT JOIN DONATION d ON d.project_id = p.project_id
GROUP BY s.staff_id, s.first_name, s.last_name, s.role, n.name
ORDER BY fundraising_rank;

-- QUERY 8: Expenses breakdown by category with percentages
WITH expense_totals AS (
    SELECT category,
           SUM(amount) AS cat_total,
           COUNT(*) AS expense_count
    FROM EXPENSES
    GROUP BY category
),
grand AS (
    SELECT SUM(cat_total) AS grand_total FROM expense_totals
)
SELECT et.category,
       et.expense_count,
       et.cat_total,
       ROUND(et.cat_total / g.grand_total * 100, 2) AS pct_of_total,
       ROUND(AVG(e.amount), 2) AS avg_expense_amount,
       MAX(e.amount) AS max_single_expense
FROM expense_totals et
JOIN EXPENSES e ON e.category = et.category
CROSS JOIN grand g
GROUP BY et.category, et.expense_count, et.cat_total, g.grand_total
ORDER BY cat_total DESC;

-- QUERY 9: Volunteer skill gap analysis per project
-- Which skills are most needed but least available
SELECT p.name AS project_name,
       v.skills,
       COUNT(DISTINCT ev.volunteer_id) AS volunteers_with_skill,
       SUM(ev.hours_volunteered) AS total_skill_hours,
       NTILE(4) OVER (PARTITION BY p.project_id ORDER BY SUM(ev.hours_volunteered) DESC) AS skill_quartile
FROM PROJECTS p
JOIN EVENTS e ON e.project_id = p.project_id
JOIN EVENT_VOLUNTEERS ev ON ev.event_id = e.event_id
JOIN VOLUNTEER v ON v.volunteer_id = ev.volunteer_id
GROUP BY p.project_id, p.name, v.skills
ORDER BY p.name, total_skill_hours DESC;

-- QUERY 10: NGO efficiency score - donations per staff member
SELECT n.ngo_id,
       n.name AS ngo_name,
       n.founded_date,
       EXTRACT(YEAR FROM SYSDATE) - EXTRACT(YEAR FROM n.founded_date) AS years_active,
       COUNT(DISTINCT s.staff_id) AS staff_count,
       COUNT(DISTINCT p.project_id) AS project_count,
       NVL(SUM(d.amount), 0) AS total_raised,
       ROUND(NVL(SUM(d.amount), 0) / NULLIF(COUNT(DISTINCT s.staff_id), 0), 2) AS donations_per_staff,
       ROUND(NVL(SUM(d.amount), 0) / NULLIF(COUNT(DISTINCT p.project_id), 0), 2) AS donations_per_project
FROM NGO n
LEFT JOIN STAFF s ON s.ngo_id = n.ngo_id
LEFT JOIN PROJECTS p ON p.ngo_id = n.ngo_id
LEFT JOIN DONATION d ON d.project_id = p.project_id
GROUP BY n.ngo_id, n.name, n.founded_date
ORDER BY donations_per_staff DESC NULLS LAST;

-- QUERY 11: Payment method preference by donor type
SELECT dn.donor_type,
       d.payment_method,
       COUNT(*) AS transaction_count,
       SUM(d.amount) AS total_amount,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY dn.donor_type), 2) AS pct_within_type
FROM DONATION d
JOIN DONOR dn ON dn.donor_id = d.donor_id
GROUP BY dn.donor_type, d.payment_method
ORDER BY dn.donor_type, total_amount DESC;

-- QUERY 12: Identify projects at financial risk (expenses > 80% of donations)
WITH project_finance AS (
    SELECT p.project_id, p.name,
           NVL(SUM(DISTINCT d.amount), 0) AS total_donations,
           NVL(SUM(DISTINCT e.amount), 0) AS total_expenses
    FROM PROJECTS p
    LEFT JOIN DONATION d ON d.project_id = p.project_id
    LEFT JOIN EXPENSES e ON e.project_id = p.project_id
    GROUP BY p.project_id, p.name
)
SELECT project_id, name, total_donations, total_expenses,
       ROUND(total_expenses / NULLIF(total_donations, 0) * 100, 2) AS expense_ratio_pct,
       CASE
           WHEN total_expenses / NULLIF(total_donations, 0) > 1   THEN 'CRITICAL'
           WHEN total_expenses / NULLIF(total_donations, 0) > 0.8 THEN 'AT RISK'
           WHEN total_expenses / NULLIF(total_donations, 0) > 0.6 THEN 'WATCH'
           ELSE 'HEALTHY'
       END AS risk_level
FROM project_finance
ORDER BY expense_ratio_pct DESC NULLS LAST;

-- QUERY 13: Volunteer engagement over time (cohort analysis)
SELECT TO_CHAR(registration_date, 'YYYY') AS cohort_year,
       COUNT(*) AS volunteers_registered,
       SUM(COUNT(*)) OVER (ORDER BY TO_CHAR(registration_date, 'YYYY')) AS cumulative_volunteers,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM VOLUNTEER
GROUP BY TO_CHAR(registration_date, 'YYYY')
ORDER BY cohort_year;

-- QUERY 14: Top donors with cumulative contribution rank
SELECT donor_id, name, donor_type,
       total_donated,
       SUM(total_donated) OVER (ORDER BY total_donated DESC) AS running_total,
       ROUND(SUM(total_donated) OVER (ORDER BY total_donated DESC) /
           SUM(total_donated) OVER () * 100, 2) AS cumulative_pct,
       CASE WHEN ROUND(SUM(total_donated) OVER (ORDER BY total_donated DESC) /
           SUM(total_donated) OVER () * 100, 2) <= 80
           THEN 'TOP 80%' ELSE 'LONG TAIL' END AS pareto_segment
FROM (
    SELECT dn.donor_id, dn.name, dn.donor_type,
           SUM(d.amount) AS total_donated
    FROM DONOR dn
    JOIN DONATION d ON d.donor_id = dn.donor_id
    GROUP BY dn.donor_id, dn.name, dn.donor_type
)
ORDER BY total_donated DESC;

-- QUERY 15: Task completion rate by event
SELECT e.name AS event_name,
       e.event_date,
       COUNT(t.task_id) AS total_tasks,
       COUNT(CASE WHEN t.status = 'COMPLETED' THEN 1 END) AS completed,
       COUNT(CASE WHEN t.status = 'IN PROGRESS' THEN 1 END) AS in_progress,
       COUNT(CASE WHEN t.status = 'PENDING' THEN 1 END) AS pending,
       ROUND(COUNT(CASE WHEN t.status = 'COMPLETED' THEN 1 END) /
           NULLIF(COUNT(t.task_id), 0) * 100, 2) AS completion_rate_pct
FROM EVENTS e
LEFT JOIN TASKS t ON t.event_id = e.event_id
GROUP BY e.event_id, e.name, e.event_date
HAVING COUNT(t.task_id) > 0
ORDER BY completion_rate_pct DESC;

-- QUERY 16: Hierarchical staff salary analysis within NGO
SELECT n.name AS ngo_name,
       s.role,
       s.first_name || ' ' || s.last_name AS staff_name,
       s.salary,
       ROUND(AVG(s.salary) OVER (PARTITION BY s.ngo_id), 2) AS avg_salary_in_ngo,
       s.salary - ROUND(AVG(s.salary) OVER (PARTITION BY s.ngo_id), 2) AS diff_from_avg,
       PERCENT_RANK() OVER (PARTITION BY s.ngo_id ORDER BY s.salary) AS salary_percentile
FROM STAFF s
JOIN NGO n ON n.ngo_id = s.ngo_id
ORDER BY n.name, s.salary DESC;

-- QUERY 17: Seasonal donation patterns (pivot-style)
SELECT TO_CHAR(donation_date, 'YYYY') AS year,
       SUM(CASE WHEN TO_CHAR(donation_date,'MM') IN ('01','02','03') THEN amount ELSE 0 END) AS Q1,
       SUM(CASE WHEN TO_CHAR(donation_date,'MM') IN ('04','05','06') THEN amount ELSE 0 END) AS Q2,
       SUM(CASE WHEN TO_CHAR(donation_date,'MM') IN ('07','08','09') THEN amount ELSE 0 END) AS Q3,
       SUM(CASE WHEN TO_CHAR(donation_date,'MM') IN ('10','11','12') THEN amount ELSE 0 END) AS Q4,
       SUM(amount) AS annual_total
FROM DONATION
GROUP BY TO_CHAR(donation_date, 'YYYY')
ORDER BY year;

-- QUERY 18: Most active volunteers (composite score)
SELECT v.volunteer_id,
       v.first_name || ' ' || v.last_name AS volunteer_name,
       v.skills,
       v.availability,
       COUNT(DISTINCT ev.event_id) AS events_participated,
       SUM(NVL(ev.hours_volunteered, 0)) AS total_hours,
       COUNT(CASE WHEN ev.participation_status = 'PRESENT' THEN 1 END) AS times_present,
       ROUND(
           (COUNT(DISTINCT ev.event_id) * 0.3 +
            SUM(NVL(ev.hours_volunteered, 0)) * 0.5 +
            COUNT(CASE WHEN ev.participation_status = 'PRESENT' THEN 1 END) * 0.2)
       , 2) AS engagement_score
FROM VOLUNTEER v
JOIN EVENT_VOLUNTEERS ev ON ev.volunteer_id = v.volunteer_id
GROUP BY v.volunteer_id, v.first_name, v.last_name, v.skills, v.availability
ORDER BY engagement_score DESC
FETCH FIRST 20 ROWS ONLY;

-- QUERY 19: Projects with no donations (orphaned projects)
SELECT p.project_id, p.name, p.start_date, p.end_date, p.budget,
       n.name AS ngo_name,
       s.first_name || ' ' || s.last_name AS manager
FROM PROJECTS p
JOIN NGO n ON n.ngo_id = p.ngo_id
JOIN STAFF s ON s.staff_id = p.staff_id
WHERE NOT EXISTS (
    SELECT 1 FROM DONATION d WHERE d.project_id = p.project_id
)
ORDER BY p.budget DESC;

-- QUERY 20: Comprehensive NGO impact report (full join analysis)
SELECT n.ngo_id,
       n.name AS ngo_name,
       COUNT(DISTINCT p.project_id) AS project_count,
       NVL(SUM(d.amount), 0) AS total_raised,
       RANK() OVER (ORDER BY NVL(SUM(d.amount), 0) DESC) AS fundraising_rank
FROM NGO n
LEFT JOIN PROJECTS p ON p.ngo_id = n.ngo_id
LEFT JOIN DONATION d ON d.project_id = p.project_id
GROUP BY n.ngo_id, n.name
ORDER BY fundraising_rank;