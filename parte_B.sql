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
SELECT * FROM bia_raw.periods_contracts_with_new_contributions;

WITH kpi_start AS (
SELECT period,  SUM(total) AS total_invoice,
	SUM(IF(payments.status = 'paid', total, 0)) AS total_paid,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 7, total, 0))/ SUM(total)) * 100, 2) AS total_paid_before_7_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 30, total, 0))/ SUM(total)) * 100, 2) AS total_paid_before_30_days,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 60, total, 0))/ SUM(total)) * 100, 2) AS total_paid_before_60_days,
    COUNT(IF(periods_variations.month_read = MONTH(period) AND periods_variations.year_read = YEAR(period), 1, NULL)) AS number_contracts
    FROM bills
    LEFT JOIN payments ON bills.bill_id = payments.bill_id
    LEFT JOIN periods_variations ON bills.contract_id = periods_variations.contract_id
    GROUP BY period
	ORDER BY period)
SELECT
	kpi_start.period,
	total_invoice,
    total_paid,
    total_paid_before_7_days,
    total_paid_before_30_days,
    total_paid_before_60_days,
    number_contracts,
    IFNULL(contracts, 0) AS with_new_contributions
FROM kpi_start
	LEFT JOIN periods_contracts_with_new_contributions AS p ON kpi_start.period = p.period;

CREATE OR REPLACE VIEW periods_contracts_with_new_contributions AS
WITH contribution_count AS (
SELECT contract_id, period,
COUNT(IF(line_type = 'contribution', 1, NULL)) AS number_contributions FROM bia_raw.bills
LEFT JOIN bill_details ON bills.bill_id = bill_details.bill_id
GROUP BY contract_id, period
ORDER BY contract_id, period),
prev_contribution_count AS (
	SELECT contract_id, period, number_contributions,
    LAG(number_contributions) OVER (PARTITION BY contract_id ORDER BY period) AS prev_number_contributions
    FROM contribution_count
)
SELECT period,
COUNT(contract_id) AS contracts
FROM prev_contribution_count
WHERE prev_number_contributions IS NOT NULL AND
number_contributions <> 0 AND prev_number_contributions = 0
GROUP BY period
ORDER BY period;

-- prueba ejemplo  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

WITH daily_totals AS (
    SELECT
        contract_id,
        DATE(`date`) AS reading_date,
        SUM(kwh) AS daily_kwh
    FROM consumptions
    WHERE deleted_at IS NULL
    GROUP BY contract_id, DATE(`date`)
),
with_prev AS (
    SELECT
        contract_id,
        reading_date,
        daily_kwh,
        LAG(daily_kwh) OVER (PARTITION BY contract_id ORDER BY reading_date) AS prev_day_kwh
    FROM daily_totals
)
SELECT 
    contract_id,
    COUNT(*) AS days_with_lower_kwh
FROM with_prev
WHERE prev_day_kwh IS NOT NULL
  AND daily_kwh < prev_day_kwh
GROUP BY contract_id;