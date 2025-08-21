USE bia_raw;

-- query para total y promedio diario de kwh por contrato 
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

-- --------------------------------------------------------------

-- query para kwh consumidos diarios y comparacion percentual con consumo del dia anterior
-- solo filtra para los dias anomalos  (+-50% de variacion con dia anterior), quitar clausula
-- WHERE para mostrar todos los dias (no quitar la parte del IS NOT NULL)

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

-- --------------------------------------------------------------------------------------------

-- query para obtener el valor total facturado por periodo, el total pagado hasta el momento y el porcentaje del total que se le  debe
-- a la empresa pagado hasta la fecha de 30 dias despues del corte

SELECT period,  SUM(total) AS period_invoice_total,
	SUM(IF(payments.status = 'paid', total, 0)) AS period_paid_total,
    ROUND((SUM(IF(payments.status = 'paid' AND datediff(paid_at, cuttoff_date) <= 30, total, 0))/ SUM(total)) * 100, 2) AS percentage_paid_before_30_days
    FROM bills
    LEFT JOIN payments ON bills.bill_id = payments.bill_id
    GROUP BY period
	ORDER BY period;
