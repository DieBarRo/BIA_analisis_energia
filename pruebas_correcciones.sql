
USE bia_raw;


SELECT period,  SUM(total) AS period_invoice_total,
	SUM(IF(payments.status = 'paid', total, 0)) AS period_paid_total,
    SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 7, total, 0)) AS period_paid_before_7_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 7, total, 0))/ SUM(total)) * 100, 2) AS percentage_paid_before_7_days,
    SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 30, total, 0)) AS period_paid_before_30_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 30, total, 0))/ SUM(total)) * 100, 2) AS percentage_paid_before_30_days,
    SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 60, total, 0)) AS period_paid_before_60_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 60, total, 0))/ SUM(total)) * 100, 2) AS percentage_paid_before_60_days
    FROM bills
    LEFT JOIN payments ON bills.bill_id = payments.bill_id
    GROUP BY period
	ORDER BY period;
    
    SELECT bills.period,  SUM(total) AS period_invoice_total,
	SUM(IF(payments.status = 'paid', total, 0)) AS period_paid_total,
    SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 7, total, 0)) AS period_paid_before_7_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 7, total, 0))/ SUM(total)) * 100, 2) AS percentage_paid_before_7_days,
    SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 30, total, 0)) AS period_paid_before_30_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 30, total, 0))/ SUM(total)) * 100, 2) AS percentage_paid_before_30_days,
    SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 60, total, 0)) AS period_paid_before_60_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 60, total, 0))/ SUM(total)) * 100, 2) AS percentage_paid_before_60_days,
    COUNT(IF(p2.month_read = MONTH(bills.period) AND p2.year_read = YEAR(bills.period), 1, NULL)) AS number_anomalous_contracts
    FROM bills
    LEFT JOIN payments ON bills.bill_id = payments.bill_id
    LEFT JOIN periods_variations_2 AS p2 ON bills.contract_id = p2.contract_id AND bills.period = p2.period
    GROUP BY bills.period
	ORDER BY bills.period;
    
SELECT *
    FROM bills
    LEFT JOIN payments ON bills.bill_id = payments.bill_id
    INNER JOIN periods_variations_2 ON bills.contract_id = periods_variations_2.contract_id AND bills.period = periods_variations_2.period
    ORDER BY bills.contract_id, bills.period;
    
SELECT *
    FROM bills
    LEFT JOIN payments ON bills.bill_id = payments.bill_id;
    
SELECT * FROM daily_variations;

CREATE OR REPLACE VIEW periods_variations_2 AS
SELECT contract_id, month_read, year_read, 
STR_TO_DATE(CONCAT(year_read, '-', month_read, '-', '01'), '%Y-%c-%d') AS period,
COUNT(contract_id) AS days_with_anomalies
FROM bia_raw.daily_variations 
GROUP BY contract_id, month_read, year_read
HAVING days_with_anomalies >= 2;

WITH kpi_without_contracts AS (
SELECT bills.period,  SUM(total) AS period_invoice_total,
	SUM(IF(payments.status = 'paid', total, 0)) AS period_paid_total,
    SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 7, total, 0)) AS period_paid_before_7_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 7, total, 0))/ SUM(total)) * 100, 2) AS percentage_paid_before_7_days,
    SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 30, total, 0)) AS period_paid_before_30_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 30, total, 0))/ SUM(total)) * 100, 2) AS percentage_paid_before_30_days,
    SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 60, total, 0)) AS period_paid_before_60_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 60, total, 0))/ SUM(total)) * 100, 2) AS percentage_paid_before_60_days,
    COUNT(IF(p2.month_read = MONTH(bills.period) AND p2.year_read = YEAR(bills.period), 1, NULL)) AS number_anomalous_contracts
    FROM bills
    LEFT JOIN payments ON bills.bill_id = payments.bill_id
    LEFT JOIN periods_variations_2 AS p2 ON bills.contract_id = p2.contract_id AND bills.period = p2.period
    GROUP BY bills.period
	ORDER BY bills.period)
SELECT
	kpi_without_contracts.period,
	period_invoice_total,
    period_paid_total,
    period_paid_before_7_days,
    percentage_paid_before_7_days,
    period_paid_before_30_days,
    percentage_paid_before_30_days,
    period_paid_before_60_days,
    percentage_paid_before_60_days,
    number_anomalous_contracts,
    IFNULL(contracts, 0) AS contracts_with_new_contributions
FROM kpi_without_contracts
	LEFT JOIN periods_contracts_with_new_contributions AS p ON kpi_without_contracts.period = p.period;

