--Street Maintence Budget Payments for 2015-2016 where Vendor is unknown
WITH A AS
(SELECT row_id, fiscal_year, division, budget_category, expense_category, payment_date, amount, fund, vendor,
SUM(amount) OVER(PARTITION BY expense_category ORDER BY expense_category, fiscal_year ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
AVG(amount) OVER(PARTITION BY expense_category ORDER BY expense_category, fiscal_year ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_avg 
FROM urbana_expenses
WHERE program LIKE 'STREET MAIN%' AND vendor LIKE 'VENDOR NAME%' AND EXTRACT(year FROM fiscal_year) >= '2015'
AND EXTRACT(year FROM fiscal_year) <= '2016'
ORDER BY expense_category ASC,fiscal_year ASC)

SELECT row_id, fiscal_year, division, budget_category, expense_category,payment_date, 
amount, running_total, ROUND((running_avg),2) AS running_avg, fund
FROM A
ORDER BY expense_category ASC, fiscal_year ASC;

--Money Spent each Fiscal Year on materials and supplies for street maintenance
WITH A AS
(SELECT *
FROM urbana_expenses
WHERE program LIKE 'STREET MAIN%' AND vendor != 'EMPLOYEE PAYROLL' AND expense_category != 'UNIFORM RENTAL' 
AND expense_category != 'GATE FEES'
ORDER BY fiscal_year ASC)

SELECT DISTINCT fiscal_year, expense_category, SUM(amount) OVER(PARTITION BY expense_category ORDER BY fiscal_year) AS spent_on_materials
FROM A
WHERE budget_category = 'MATERIALS & SUPPLIES' 
ORDER BY 1, 3 DESC;

--total cost of professional legal services for Urbana, with running total per vendor
WITH A AS
(SELECT DISTINCT row_id, fiscal_year, program, description, budget_category, expense_category, vendor, amount
FROM urbana_expenses
WHERE program = 'LEGAL' AND expense_category = 'PROF. LEGAL SERVICES')

SELECT row_id, fiscal_year,description, budget_category, expense_category, 
vendor, amount AS legal_serv_cost, 
SUM(amount) OVER(PARTITION BY vendor ORDER BY vendor ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
CONCAT('$',ROUND(((SELECT SUM(amount) FROM urbana_expenses WHERE program = 'LEGAL')*1.0/1000000),2), ' million') AS total_cost_of_legal
FROM A
ORDER BY vendor ASC;

--Uncleared payments to Fire and Police Department Pensions
WITH A AS
(SELECT *
FROM urbana_expenses
WHERE payment_status = 'Not Cleared' AND department IN ('POLICE', 'FIRE', 'FIRE AND RESCUE') AND expense_category LIKE '%PENSION%'
ORDER BY department ASC, fiscal_year ASC)

SELECT row_id, fiscal_year, department, budget_category, payment_number, payment_date,
invoice_id, invoice_line_number, description, amount, SUM(amount) OVER(PARTITION BY department ORDER BY fiscal_year ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
AS running_total, CONCAT('$', ROUND(MAX(amount) OVER(PARTITION BY department, fiscal_year ORDER BY fiscal_year ASC)*1.0/100000,2), ' hundred thousand') AS max_uncleared_year,
CONCAT('$',ROUND(((SELECT SUM(amount) FROM urbana_expenses WHERE department = 'FIRE' AND payment_status = 'Not Cleared')/1000000),2), ' million') AS total_fire_pension_uncleared,
CONCAT('$',ROUND(((SELECT SUM(amount) FROM urbana_expenses WHERE department = 'POLICE' AND payment_status = 'Not Cleared')/1000000),2), ' million') AS total_police_pension_uncleared
FROM A;
--Expenses made toward Social Services and Social Service Expenses with running total per vendor, max contribution per vendor, and total expense spent
WITH A AS
(SELECT fiscal_year,program, description,vendor,amount, 
SUM(amount) OVER(PARTITION BY vendor ORDER BY vendor, fiscal_year ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
(SELECT SUM(amount) FROM urbana_expenses WHERE program LIKE 'SOCIAL%') AS total_serv_spent
FROM urbana_expenses
WHERE program LIKE 'SOCIAL%'
ORDER BY vendor ASC, fiscal_year ASC)

SELECT A.fiscal_year, A.program, A.description, A.vendor, A.amount, A.running_total, SUM(A.amount) OVER(PARTITION BY vendor) AS max_contrib,
CONCAT('$', ROUND((A.total_serv_spent*1.0/1000000),2), ' million') AS total_serv_spent
FROM A
ORDER BY vendor ASC;

--Fund Type amount percentage against the summed total of amount
SELECT DISTINCT fund_type,
CASE WHEN fund_type = 'BOND FUND' THEN ROUND((SELECT SUM(amount) FROM urbana_expenses WHERE fund_type = 'BOND FUND')*100.0/(SELECT SUM(amount) FROM urbana_expenses),2) 
WHEN fund_type = 'CAPITAL IMPROVEMENT' THEN ROUND((SELECT SUM(amount) FROM urbana_expenses WHERE fund_type = 'CAPITAL IMPROVEMENT')*100.0/(SELECT SUM(amount) FROM urbana_expenses),2)
WHEN fund_type = 'ENTERPRISE' THEN ROUND((SELECT SUM(amount) FROM urbana_expenses WHERE fund_type = 'ENTERPRISE')*100.0/(SELECT SUM(amount) FROM urbana_expenses),2)
WHEN fund_type = 'GENERAL FUND' THEN ROUND((SELECT SUM(amount) FROM urbana_expenses WHERE fund_type = 'GENERAL FUND')*100.0/(SELECT SUM(amount) FROM urbana_expenses),2)
WHEN fund_type = 'GENERAL/SUPPORTIVE' THEN ROUND((SELECT SUM(amount) FROM urbana_expenses WHERE fund_type = 'GENERAL/SUPPORTIVE')*100.0/(SELECT SUM(amount) FROM urbana_expenses),2)
WHEN fund_type = 'INTERNAL SERVICE' THEN ROUND((SELECT SUM(amount) FROM urbana_expenses WHERE fund_type = 'INTERNAL SERVICE')*100.0/(SELECT SUM(amount) FROM urbana_expenses),2)
WHEN fund_type = 'RESERVE FUND' THEN ROUND((SELECT SUM(amount) FROM urbana_expenses WHERE fund_type = 'RESERVE FUND')*100.0/(SELECT SUM(amount) FROM urbana_expenses),2)
WHEN fund_type = 'SPECIAL REVENUE' THEN ROUND((SELECT SUM(amount) FROM urbana_expenses WHERE fund_type = 'SPECIAL REVENUE')*100.0/(SELECT SUM(amount) FROM urbana_expenses),2)
WHEN fund_type IS NULL THEN ROUND((SELECT SUM(amount) FROM urbana_expenses WHERE fund_type IS NULL)*100.0/(SELECT SUM(amount) FROM urbana_expenses),2) END AS fund_type_percentage
FROM urbana_expenses
GROUP BY 1

--Department Public Works 2013 expenses by expense category with percentage of each expense against the total departmental expense
WITH A AS
(SELECT DISTINCT fiscal_year, division, program, 
expense_category, ROUND((SUM(amount) OVER(PARTITION BY expense_category ORDER BY expense_category)),2) AS expense_amount
FROM urbana_expenses
WHERE department = 'PUBLIC WORKS' AND EXTRACT(year FROM fiscal_year) = '2013'
GROUP BY fiscal_year, division, program, expense_category, amount
ORDER BY fiscal_year ASC, division ASC, program ASC, expense_category ASC),
B AS
(SELECT DISTINCT fiscal_year, SUM(amount) AS amount
FROM urbana_expenses
WHERE department = 'PUBLIC WORKS' AND EXTRACT(year FROM fiscal_year) = '2013'
GROUP BY 1)
SELECT A.fiscal_year, division, program, expense_category, expense_amount, ROUND((A.expense_amount*100.0/B.amount),4) AS expense_perc
FROM A
LEFT JOIN B
ON A.fiscal_year = B.fiscal_year

--Payments that occurred after 6 months since invoiced
SELECT department,program, budget_category, expense_category, invoice_date, payment_date, AGE(payment_date, invoice_date) AS age_of_payment
FROM urbana_expenses
WHERE invoice_date IS NOT NULL
GROUP BY 1,2,3,4,5,6
HAVING AGE(payment_date, invoice_date) > '6 mon'
ORDER BY age_of_payment DESC

--Yearly Departmental expenditure 
SELECT DISTINCT fiscal_year, department, CONCAT('$', ROUND((SUM(amount) OVER(PARTITION BY fiscal_year ORDER BY fiscal_year ASC)*1.0/1000000),2), ' million') AS yearly_department_expend
FROM urbana_expenses
WHERE budget_category = 'SALARIES & BENEFITS'
ORDER BY department ASC, fiscal_year ASC

--2020-2023 COVID-19 Expense Report: Amounts used with the Percentage of the amount against the total expenditure for that year under COVID
SELECT fiscal_year, program, description, expense_category, amount,
CASE EXTRACT(year FROM fiscal_year) WHEN '2020' THEN
ROUND((SUM(amount) OVER(PARTITION BY amount ORDER BY fiscal_year ASC)*100.0/(SELECT SUM(amount) FROM urbana_expenses WHERE description LIKE 'COVID%' AND EXTRACT(year from fiscal_year) = '2020')),2)
WHEN '2021' THEN ROUND((SUM(amount) OVER(PARTITION BY amount ORDER BY fiscal_year ASC)*100.0/(SELECT SUM(amount) FROM urbana_expenses WHERE description LIKE 'COVID%' AND EXTRACT(year from fiscal_year) = '2021')),2)
WHEN '2022' THEN ROUND((SUM(amount) OVER(PARTITION BY amount ORDER BY fiscal_year ASC)*100.0/(SELECT SUM(amount) FROM urbana_expenses WHERE description LIKE 'COVID%' AND EXTRACT(year from fiscal_year) = '2022')),2)
WHEN '2023' THEN ROUND((SUM(amount) OVER(PARTITION BY amount ORDER BY fiscal_year ASC)*100.0/(SELECT SUM(amount) FROM urbana_expenses WHERE description LIKE 'COVID%' AND EXTRACT(year from fiscal_year) = '2020')),2) END
FROM urbana_expenses
WHERE description LIKE 'COVID%'
GROUP BY 1,2,3,4,5
ORDER BY fiscal_year;

--Summed total of amount fields in which amount is negative and a count of rows that contain negative amounts
WITH A AS
(SELECT SUM(amount) AS sum
FROM urbana_expenses
GROUP BY amount
HAVING SIGN(amount) = -1)
SELECT SUM(sum), COUNT(sum)
FROM A;