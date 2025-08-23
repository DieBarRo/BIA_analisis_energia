
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
    
    SELECT period,  SUM(total) AS period_invoice_total,
	SUM(IF(payments.status = 'paid', total, 0)) AS period_paid_total,
    SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 7, total, 0)) AS period_paid_before_7_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 7, total, 0))/ SUM(total)) * 100, 2) AS percentage_paid_before_7_days,
    SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 30, total, 0)) AS period_paid_before_30_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 30, total, 0))/ SUM(total)) * 100, 2) AS percentage_paid_before_30_days,
    SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 60, total, 0)) AS period_paid_before_60_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 60, total, 0))/ SUM(total)) * 100, 2) AS percentage_paid_before_60_days,
    COUNT(IF(periods_variations.month_read = MONTH(period) AND periods_variations.year_read = YEAR(period), 1, NULL)) AS number_anomalous_contracts
    FROM bills
    LEFT JOIN payments ON bills.bill_id = payments.bill_id
    LEFT JOIN periods_variations ON bills.contract_id = periods_variations.contract_id
    GROUP BY period
	ORDER BY period