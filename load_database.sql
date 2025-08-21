CREATE DATABASE IF NOT EXISTS bia_raw;

USE bia_raw;

-- para toda la  importación de data se subieron los archivos a la carpeta de uploads de MySQL para
-- poder operar en modo seguro

CREATE TABLE IF NOT EXISTS companies(
company_id VARCHAR(10) PRIMARY KEY ,
name VARCHAR(60),
tax_payer ENUM('yes', 'no'),
sic_agpe VARCHAR(10),
solar_starts_at DATE
);


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/prueba_tecnica_BIA/companies.csv'
INTO TABLE companies
FIELDS TERMINATED BY ','
IGNORE 1 LINES;

-- -------------------------------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS contracts(
contract_id VARCHAR(10) PRIMARY KEY,
company_id VARCHAR(10) NOT NULL,
start_date DATE,
end_date DATE NULL,
market_type VARCHAR(40),
FOREIGN KEY (company_id) 
REFERENCES companies(company_id)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/prueba_tecnica_BIA/contracts.csv'
INTO TABLE contracts
FIELDS TERMINATED BY ','
IGNORE 1 LINES
(contract_id, company_id, start_date, @end_date_temp, market_type)
SET end_date = NULLIF(@end_date_temp, '');

-- -------------------------------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS consumptions(
consumption_id CHAR(36) PRIMARY KEY,
contract_id VARCHAR(10) NOT NULL,
meter_id VARCHAR(10),
date DATE,
hour INT,
kwh DECIMAL(8,4),
deleted_at DATE NULL,
FOREIGN KEY (contract_id)
REFERENCES contracts(contract_id)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/prueba_tecnica_BIA/consumptions.csv'
INTO TABLE consumptions
FIELDS TERMINATED BY ','
IGNORE 1 LINES
(consumption_id,contract_id,meter_id,date,hour,kwh,@deleted_at_temp)
SET deleted_at = NULLIF(@deleted_at_temp, '');

-- -------------------------------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS bills (
    bill_id CHAR(36) PRIMARY KEY,
    contract_id VARCHAR(10) NOT NULL,
    period DATE,
    cuttoff_date DATE,
    total DECIMAL(10,4),
    status ENUM('paid', 'issued', 'overdue'),
    FOREIGN KEY (contract_id) 
    REFERENCES contracts(contract_id)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/prueba_tecnica_BIA/bills.csv'
INTO TABLE bills
FIELDS TERMINATED BY ','
IGNORE 1 LINES
(bill_id,contract_id,@period_temp,cuttoff_date,total,status)
SET period = STR_TO_DATE(CONCAT(@period_temp, '-01'), '%c-%Y-%d');


-- -------------------------------------------------------------------------------------------------------

CREATE TABLE bill_details (
    bill_details_id CHAR(36) PRIMARY KEY,
    bill_id CHAR(36) NOT NULL,
    line_type ENUM('contribution', 'tax', 'energy'),
    amount DECIMAL(10, 4),
	FOREIGN KEY (bill_id) 
    REFERENCES bills(bill_id)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/prueba_tecnica_BIA/bill_details.csv'
INTO TABLE bill_details
FIELDS TERMINATED BY ','
IGNORE 1 LINES;

-- -------------------------------------------------------------------------------------------------------

CREATE TABLE payments (
    payment_id CHAR(36) PRIMARY KEY,
    bill_id CHAR(36) NOT NULL,
    paid_at DATE,
    method ENUM('bank_transfer', 'credit_card', 'cash'),
    token VARCHAR(10) NULL,
    status ENUM('paid', 'late'),
    FOREIGN KEY (bill_id)
    REFERENCES bills(bill_id)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/prueba_tecnica_BIA/payments.csv'
INTO TABLE payments
FIELDS TERMINATED BY ','
IGNORE 1 LINES;