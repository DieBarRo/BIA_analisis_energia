USE bia_raw;

SELECT
    contract_id,
    SUM(kwh)        AS kwh_total_month,
    SUM(kwh) / COUNT(DISTINCT DAY(date))   AS average_daily_kwh
FROM consumptions
WHERE YEAR(date)   = 2024
  AND MONTH(date)  = 7
  AND deleted_at IS NULL
GROUP BY contract_id
ORDER BY contract_id
;

WITH daily_totals AS (
    SELECT
        contract_id,
        DATE(`date`) AS reading_date,
        SUM(kwh) AS daily_kwh
    FROM consumptions
    WHERE deleted_at IS NULL
    GROUP BY contract_id, DATE(`date`)
),
variations AS (
    SELECT
        contract_id,
        reading_date,
        daily_kwh,
        LAG(daily_kwh) OVER (PARTITION BY contract_id ORDER BY reading_date) AS prev_day_kwh
    FROM daily_totals
)
SELECT
    contract_id,
    reading_date,
    daily_kwh,
    prev_day_kwh,
    ROUND(((daily_kwh - prev_day_kwh) / prev_day_kwh) * 100, 2) AS pct_variation
FROM variations
WHERE prev_day_kwh IS NOT NULL AND ABS(((daily_kwh - prev_day_kwh) / prev_day_kwh) * 100) > 50
ORDER BY contract_id, reading_date;

SELECT *
    FROM bills
    INNER JOIN payments ON bills.bill_id = payments.bill_id
    WHERE contract_id = "CT00019"
AND period = "1-2024";

SELECT period, cuttoff_date, total, bills.status AS bill_status, paid_at, payments.status AS payment_status,
	datediff(paid_at, cuttoff_date) AS days_since_cuttoff
    FROM bills
    LEFT JOIN payments ON bills.bill_id = payments.bill_id;
    
SELECT period,  SUM(total) AS total2,
	SUM(IF(payments.status = 'paid', total, 0)) AS total_paid,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 30, total, 0))/ SUM(total)) * 100, 2) AS total_paid_before_30_days
    FROM bills
    LEFT JOIN payments ON bills.bill_id = payments.bill_id
    GROUP BY period
	ORDER BY period;
