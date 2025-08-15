USE bia_raw;

SELECT
    contract_id,
    SUM(kwh)        AS kwh_total_mes,
    SUM(kwh) / COUNT(DISTINCT DAY(date))   AS kwh_promedio_diario
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
    GROUP BY
        contract_id,
        DATE(`date`)
)
SELECT
    contract_id,
    reading_date,
    daily_kwh,
    LAG(daily_kwh) OVER (PARTITION BY contract_id ORDER BY reading_date) AS prev_day_kwh,
    ROUND(
        ((daily_kwh - LAG(daily_kwh) OVER (PARTITION BY contract_id ORDER BY reading_date))
         / LAG(daily_kwh) OVER (PARTITION BY contract_id ORDER BY reading_date)) * 100,
        2
    ) AS pct_variation
FROM daily_totals
ORDER BY contract_id, reading_date;
