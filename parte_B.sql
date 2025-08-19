CREATE OR REPLACE VIEW daily_variations AS
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
    ROUND(((daily_kwh - prev_day_kwh) / prev_day_kwh) * 100, 2) AS pct_variation,
    MONTH(reading_date) AS month_read,
    YEAR(reading_date) AS year_read
FROM variations
WHERE prev_day_kwh IS NOT NULL
  AND ABS(((daily_kwh - prev_day_kwh) / prev_day_kwh) * 100) > 50;
  
-- SELECT *, MONTH(reading_date) AS month_read FROM bia_raw.daily_variations;
SELECT * FROM bia_raw.daily_variations;

CREATE OR REPLACE VIEW periods_variations AS
SELECT contract_id, month_read, year_read,
COUNT(contract_id) AS days_with_anomalies
FROM bia_raw.daily_variations 
GROUP BY contract_id, month_read, year_read
HAVING days_with_anomalies >= 2;

SELECT * FROM bia_raw.periods_variations;

SELECT period,  SUM(total) AS total2,
	SUM(IF(payments.status = 'paid', total, 0)) AS total_paid,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 7, total, 0))/ SUM(total)) * 100, 2) AS total_paid_before_7_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 30, total, 0))/ SUM(total)) * 100, 2) AS total_paid_before_30_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 60, total, 0))/ SUM(total)) * 100, 2) AS total_paid_before_60_days,
    COUNT(IF(periods_variations.month_read = MONTH(period) AND periods_variations.year_read = YEAR(period), 1, NULL)) AS number_contracts
    FROM bills
    LEFT JOIN payments ON bills.bill_id = payments.bill_id
    LEFT JOIN periods_variations ON bills.contract_id = periods_variations.contract_id
    GROUP BY period
	ORDER BY period;