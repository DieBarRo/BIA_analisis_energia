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


-- ------------------------------------------------------------------------
-- numeral 4

-- Para el numeral 4 consulta con BUG no encontre un bug en el conjunto de datos, sin embargo prodria ser que
-- al usar la funcionalidad de contar los dias entre las fechas de paid_at y cuttoff_date se deban tomar en cuenta
-- solo los dias laborales y no todos los  dias por lo que si es requerido se podria cambiar usando la funcion DAYOFWEEK
-- de MySQL para contar solo los dias de lunes a viernes o crear una tabla con los dias no laborales y contar el rango de fechas
-- que  sean dias laborales para solucionar el problema.

-- ----------------------------------------------------------------------------
-- numeral 5

-- crear un indice en la tabla consumptions sobre la columna contract_id ya que se usa para agrupar y ordenar los
-- datos de las consultas 2 y 3, ademas de que sl tendria que ser actualizado cuando se genera un nuevo contrato lo
-- cual puede ser una ocurrencia ordenes de magnitud menor a la cantidad de veces que se leen los datos de consumo de 
-- los contratos. 
