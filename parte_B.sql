USE bia_raw;

-- Subquery que consigue las variaciones de mas del 50% absoluto en kwh con
-- respecto al dia anterior

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
  
-- Subquery para contar los contratos con mas de dos dias anomalos por periodo


CREATE OR REPLACE VIEW periods_variations AS
SELECT contract_id, month_read, year_read,
COUNT(contract_id) AS days_with_anomalies
FROM bia_raw.daily_variations 
GROUP BY contract_id, month_read, year_read
HAVING days_with_anomalies >= 2;

-- --------------------------------------------------------------------------

-- subquery para contar por periodo los contratos que tengan una factura con "contribution"
-- si la anterior factura no lo tenia

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
COUNT(*) AS contracts
FROM prev_contribution_count
WHERE prev_number_contributions IS NOT NULL AND
number_contributions <> 0 AND prev_number_contributions = 0
GROUP BY period
ORDER BY period;


-- --------------------------------------------------------------------------

-- query para conseguir los porcentajes pagados y lo debido a la empresa junto con los contratos anomalos y
-- contratos con contribution en un mismo periodo

WITH kpi_without_contracts AS (
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
	ORDER BY period)
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

-- ----------------------------------------------------------------------------
-- numeral 2

-- Cada fila debe ser única y no nula en su clave primaria.
-- Toda clave foránea debe apuntar a un valor existente en la tabla referida.
-- Los valores deben estar dentro de rangos o formatos esperados.
-- Evitar duplicados en campos clave y manejar correctamente los valores nulos.
-- Asegurar que campos críticos no estén vacíos.


-- ----------------------------------------------------------------------------
-- numeral 3

-- Si tuviera que considerar una partición de la información seria sobre la tabla consumptions que es de por si
-- la tabla con más datos ya que se agrega una nueva fila por cada hora de cada contrato para cada fecha. La partición 
-- podría ser por fecha (tipo anual) porque así es posible mantener la información a largo plazo sin que afecte
-- tanto la velocidad de consultas de años futuros, además de que si los valores de las facturas y lo recolectado son kpi 
-- para la empresa la agregación por fechas seria relativamente constante.

-- Por otra parte, si esta tabla es de donde se obtiene la data para mostrar a cada cliente su consumo la partición 
-- se podría hacer por contract_id ya que así es más rápido para cada cliente su consulta de consumo energético o ver anomalías
-- por cliente específicamente.

-- Por esto mismo los índices que consideraría seria sobre esas mismas columnas ya que son frecuentemente usadas para los queries
-- además de que se encuentran en varias tablas por lo que también aceleraría el proceso de los joins con bills que es usado para
-- los kpi del negocio.

-- Por último, para materializar solo sería sobre las vistas creadas para verificar los contratos con anomalías o el número de contratos
-- con contribución que no lo tenían en la factura anterior, ya que en vez de tener que realizar el subquery la información ya se encontraría
-- previamente computada en la base de datos, sin embargo, esto solo tiene sentido si la consulta de los kpi del negocio se realiza seguido y se 
-- puede definir una hora de corte cada día en la cual se actualice la información de las vistas materializadas.
