# step 1st create schema
# Import csv file
-- -----------------------------------------------------
use sql_project;

-- -----------------------------------------------------
/* Describe Tables */
-- -----------------------------------------------------
DESCRIBE Customer;
DESCRIBE Employee_Details;
DESCRIBE employee_manages_shipment;
DESCRIBE Membership;
DESCRIBE Payment_Details;
DESCRIBE Shipment_Details;
DESCRIBE STATUS;

-- -----------------------------------------------------
/* Selecting the contents from the tables */
-- -----------------------------------------------------
SELECT * FROM Customer;
SELECT * FROM Employee_Details;
SELECT * FROM employee_manages_shipment;
SELECT * FROM Membership;
SELECT * FROM Payment_Details;
SELECT * FROM Shipment_Details;
SELECT * FROM STATUS;

-- -----------------------------------------------------
/* Look for erroneous dates */
-- -----------------------------------------------------
# 1) Find the incorrect dates in the 'STATUS' table from the 'DELIVERY DATE' column, where the month is greater than 12.
SELECT DELIVERY_DATE FROM STATUS
WHERE CAST(SUBSTRING_INDEX(DELIVERY_DATE, '/', 1) AS UNSIGNED) > 12;
    
    
# 2) Search for the records where the month is February but the date is incorrectly entered as 30 and 31.   
SELECT * FROM STATUS
WHERE CAST(SUBSTRING_INDEX(DELIVERY_DATE, '/', 1) AS UNSIGNED) = 2
AND 
CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(DELIVERY_DATE, '/', 2),'/',- 1) AS UNSIGNED) > 29;
SELECT * FROM STATUS
WHERE CAST(SUBSTRING_INDEX(SENT_DATE, '/', 1) AS UNSIGNED) = 2
AND
 CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(SENT_DATE, '/', 2), '/', - 1) AS UNSIGNED) > 29;
SELECT * FROM Payment_Details
WHERE CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(PAYMENT_DATE, '-', 2),'-', - 1) AS UNSIGNED) = 2
AND 
CAST(SUBSTRING_INDEX(PAYMENT_DATE, '-', - 1) AS UNSIGNED) > 29;

    
-- -----------------------------------------------------
/* Converting the string in to a date format */
-- -----------------------------------------------------
UPDATE Payment_Details 
SET Payment_Date = STR_TO_DATE(Payment_Date, '%Y-%m-%d');    
UPDATE STATUS 
SET Delivery_Date = STR_TO_DATE(Delivery_Date, '%m/%d/%Y'),
    Sent_Date = STR_TO_DATE(Sent_Date, '%m/%d/%Y');
UPDATE MEMBERSHIP 
SET Start_Date = STR_TO_DATE(Start_Date, '%Y-%m-%d'),
    End_Date = STR_TO_DATE(End_Date, '%Y-%m-%d');  
    
-- -----------------------------------------------------
/* Changing the datatype from TEXT to DATE */
-- -----------------------------------------------------
ALTER TABLE Payment_Details
MODIFY COLUMN Payment_Date Date;

ALTER TABLE STATUS
MODIFY COLUMN Delivery_Date Date, MODIFY COLUMN Sent_Date Date ;

ALTER TABLE MEMBERSHIP
MODIFY COLUMN Start_Date Date, MODIFY COLUMN End_Date Date ;    
    
-- -----------------------------------------------------
-- Creating a Single Source Of Truth (SSOT)
-- -----------------------------------------------------
CREATE TABLE sql_project AS
SELECT 
	emp.E_ID, ship.SH_ID, Cust.C_ID, pmt.PAYMENT_ID, memb.M_ID,
    emp.E_NAME, emp.E_ADDR, emp.E_BRANCH, emp.E_DESIGNATION, emp.E_CONT_NO,
    ship.SH_DOMAIN, ship.SH_CONTENT, ship.SR_ADDR, ship.DS_ADDR, ship.SH_WEIGHT, ship.SER_TYPE, ship.SH_CHARGES,
    cust.C_NAME, cust.C_TYPE, cust.C_ADDR, cust.C_CONT_NO, cust.C_EMAIL_ID,
    stat.SENT_DATE, stat.DELIVERY_DATE, stat.Current_Status, 
    pmt.AMOUNT, pmt.PAYMENT_STATUS, pmt.PAYMENT_DATE, pmt.PAYMENT_MODE,
    memb.Start_Date, memb.End_Date
    
FROM
    EMPLOYEE_Details AS emp
         INNER JOIN
	employee_manages_shipment AS ems ON emp.E_ID = ems.Employee_E_ID
         INNER JOIN
    SHIPMENT_Details AS ship ON ship.SH_ID = ems.Shipment_Sh_ID
		 INNER JOIN
	customer AS cust ON Cust.C_ID = ship.C_ID
		 INNER JOIN
	STATUS AS stat ON ship.SH_ID = stat.SH_ID
		 INNER JOIN
	payment_details AS pmt ON ship.SH_ID = pmt.SH_ID
		 INNER JOIN
	MEMBERSHIP AS memb ON memb.M_ID = cust.M_ID; 
select * from sql_project;
    
# ----------------------------------------------------------- QUERY -----------------------------------------------------------    
    
# 1) Extract all the employees whose name starts with A and ends with A.  
select E_NAME from employee_details
where E_NAME  Like'A%A';
    
    
# 2) Find all the common names from Employee_Details names and Customer names.
SELECT DISTINCT(E_name) FROM Employee_Details WHERE E_name IN (SELECT C_name FROM Customer AS cus);


# 3) Create a view 'PaymentNotDone' of those customers who have not paid the amount.
CREATE VIEW PaymentNotDone AS
SELECT * FROM sql_project
WHERE PAYMENT_STATUS = 'NOT PAID';

-- Selecting all the observations of the newly created view 'PaymentNotDone'
SELECT * FROM PaymentNotDone;


# 4) Find the frequency (in percentage) of each of the class of the payment mode
SET @total_count = 0;
SELECT COUNT(*) INTO @total_count FROM Pyament_Deatils;
SELECT PAYMENT_MODE, ROUND((COUNT(PAYMENT_MODE) / @total_count) * 100,2)  AS Percentage_Contribution
FROM Payment_Details
GROUP BY PAYMENT_MODE;


# 5) What is the highest total payable amount ?
SELECT MAX(Amount) FROM sql_project;


# 6) Extract the customer id and the customer name  of the customers who were or will be the member of the branch for more than 10 years
SELECT C_ID, C_NAME, START_DATE, END_DATE, ROUND(DATEDIFF(END_DATE, START_DATE)/365,0) 
	AS Membership_Years FROM sql_project 
HAVING Membership_Years > 10;


# 7) Who got the product delivered on the next day the product was sent?
SELECT * FROM sql_project 
	HAVING DELIVERY_DATE-SENT_DATE = 1;
SELECT * FROM sql_project 
	HAVING DATEDIFF(DELIVERY_DATE, SENT_DATE)=1;


# 8) Which shipping content had the highest total amount (Top 5).
SELECT SH_CONTENT, SUM(AMOUNT) AS Content_Wise_Amount
FROM sql_project
GROUP BY (SH_CONTENT)
ORDER BY Content_Wise_Amount DESC
LIMIT 5;


# 9) Which product categories from shipment content are transferred more?  
SELECT SH_CONTENT, COUNT(SH_CONTENT) 
	AS Content_Wise_Count 
FROM sql_project 
GROUP BY(SH_CONTENT) 
ORDER BY Content_Wise_Count DESC 
LIMIT 5;


# 10) Create a new view 'TXLogistics' where employee branch is Texas.
CREATE VIEW TXLogistics AS
	SELECT * FROM sql_project 
		WHERE E_BRANCH = 'TX';

SELECT * FROM TXLogistics;


# 11) Texas(TX) branch is giving 5% discount on total payable amount. Create a new column 'New_Price' for payable price after applying discount.
ALTER VIEW TXLogistics
   AS SELECT *, AMOUNT - ((AMOUNT * 5)/100) AS New_Price 
   FROM logistics_Emp
   WHERE E_BRANCH = 'TX';
SELECT * FROM TXLogistics;
   
   
# 12) Drop the view TXLogistics
DROP VIEW TXLogistics;


# 13) The employee branch in New York (NY) is shutdown temporarily. Thus, the the branch needs to be replaced to New Jersy (NJ).
SELECT * FROM sql_project WHERE E_BRANCH = 'NY';

UPDATE sql_project
	SET E_BRANCH = 'NJ'
WHERE E_BRANCH = 'NY';

SELECT * FROM sql_project;


# 14) Finding the unique designations of the employees.
SELECT DISTINCT(E_DESIGNATION) FROM Employee_Details;


# 15) Rename the column SER_TYPE to SERVICE_TYPE.
ALTER TABLE sql_project
CHANGE SER_TYPE SERVICE_TYPE VARCHAR (15);


# 16) Which service type is preferred more?
SELECT SERVICE_TYPE, COUNT(SERVICE_TYPE) 
	AS Frequency 
FROM sql_project 
GROUP BY SERVICE_TYPE 
ORDER BY Frequency DESC;


# 17) Find the shipment id and shipment content where the weight is greater than the average weight.
SELECT SH_ID, SH_CONTENT, SH_WEIGHT FROM Shipment_Details
WHERE SH_WEIGHT > (SELECT AVG(SH_WEIGHT) FROM Shipment_Details);

-- -------------------------------------------Thank You-------------------------------------------------------- --