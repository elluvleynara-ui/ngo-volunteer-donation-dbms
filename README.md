# Volunteer and Donation Management System for NGOs

> Built as a final project for Database Management Systems course at SDU University, 2025.

Non-profits do important work — but behind every event, every donation, every volunteer shift, there's a mountain of data that's usually tracked in Excel sheets or not tracked at all. This project is an attempt to fix that. A proper relational database that actually makes sense for how NGOs operate.

🔗 **Live Demo:** [volunteer-and-donation-management-system](https://oracleapex.com/ords/r/elya/volunteer-and-donation-management-system/home)

---

## What's inside

10 tables, fully connected with foreign keys and constraints. No orphaned data, no shortcuts.

| Table | What it stores | Rows |
|-------|---------------|------|
| NGO | The organizations themselves | 20 |
| STAFF | Employees, their roles and salaries | 400 |
| VOLUNTEER | People who show up and help | 3,000 |
| DONOR | Who's giving money and how much | 1,200 |
| PROJECTS | What the NGOs are actually working on | 300 |
| DONATION | Every transaction, every payment method | 5,000 |
| EVENTS | Events tied to projects | 4,000 |
| TASKS | What needs to happen at each event | 12,000 |
| EVENT_VOLUNTEERS | Who showed up, for how long | 60,000 |
| EXPENSES | Where the money actually went | 4,000 |

---

## The queries (20 total)

Not just basic SELECTs. The interesting stuff:

- Monthly donation trends with 3-month moving average and growth rate — built with CTEs and LAG window function
- Project financial risk scoring — flags projects where expenses eat more than 80% of donations (HEALTHY / WATCH / AT RISK / CRITICAL)
- Donor retention: who gives once and disappears vs who keeps coming back
- Volunteer engagement score — composite metric combining events attended, hours worked, and attendance rate
- Seasonal donation pivot — quarterly breakdown by year, useful for planning fundraising campaigns
- Pareto analysis on donors — who contributes the top 80% of all funding

Window functions used: RANK, DENSE_RANK, PERCENT_RANK, NTILE, LAG, SUM OVER, AVG OVER, PARTITION BY.

---

## PL/SQL objects

**3 Functions** — get total donations for a project, calculate budget utilization %, get volunteer hours

**3 Procedures** — full financial report for a project, register a volunteer to an event (with duplicate check), bulk-close event tasks

**3 Packages** with custom exceptions:
- `PKG_NGO_ANALYTICS` — fundraising stats and volunteer counts per NGO
- `PKG_PROJECT_FINANCE` — balance calculation and reporting
- `PKG_VOLUNTEER_MGMT` — volunteer history + status classification (BEGINNER → ACTIVE → EXPERIENCED → EXPERT)

**5 Cursors** — explicit cursors with custom record types, %ROWTYPE, implicit cursors with month-over-month comparison

**1 Collection** — nested table for bulk donor categorization into PLATINUM / GOLD / SILVER / BRONZE tiers

**5 Triggers:**
- No negative donation amounts
- Auto-set registration date for new volunteers
- Block expenses that exceed 150% of project budget
- No duplicate volunteer registrations per event
- Auto-assign donation status on insert

---

## APEX Interface

Built on Oracle APEX — 4 management pages, each with full CRUD (create, read, update, delete):

**Volunteer Management** — browse all 3,000 volunteers, filter by name, skills, or availability, add new volunteers via form, edit or delete existing records

**Donation Management** — full donation history with 5,000 transactions, filter by donor, project, payment method or status, add and manage donation records

**Expenses Management** — track all project expenses by category, filter and sort by project or date, add new expense entries with staff approval tracking

**Event Volunteers** — 60,000 participation records, see who attended which event, how many hours they worked, and their participation status

All pages include interactive filtering, sorting, and column search. Forms include validation — required fields, data type checks, and error messages.

---

## How to run it yourself

1. Free workspace at [apex.oracle.com](https://apex.oracle.com)
2. Run `sql/01_create_tables.sql` — tables in order, foreign keys matter
3. Load CSVs from `data/` via Utilities → Data Workshop
4. Run `sql/02_queries.sql` and `sql/03_plsql.sql` — one block at a time

---

## Repository structure

```
ngo-volunteer-donation-dbms/
├── sql/
│   ├── 01_create_tables.sql
│   ├── 02_queries.sql
│   └── 03_plsql.sql
├── data/
│   └── (10 CSV files)
├── docs/
│   ├── ERD.png
│   └── screenshots/
└── README.md
```

---

## Team

Ruslan Dilnaz · Iglik Elnara · Toregeldieva Aliya — SDU University, 2025
