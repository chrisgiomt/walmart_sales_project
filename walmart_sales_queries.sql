-- 
-- Had to alter the columns to be able to query without ""
-- ALTER TABLE walmart_sales_cleaned RENAME COLUMN "Weekly_Sales" TO weekly_sales;
-- ALTER TABLE walmart_sales_cleaned RENAME COLUMN "Store" TO store;
-- ALTER TABLE walmart_sales_cleaned RENAME COLUMN "Date" TO date;
-- ALTER TABLE walmart_sales_cleaned RENAME COLUMN "Holiday_Flag" TO holiday_flag;
-- ALTER TABLE walmart_sales_cleaned RENAME COLUMN "Temperature" TO temperature;
-- ALTER TABLE walmart_sales_cleaned RENAME COLUMN "Fuel_Price" TO fuel_price;
-- ALTER TABLE walmart_sales_cleaned RENAME COLUMN "CPI" to cpi;
-- ALTER TABLE walmart_sales_cleaned RENAME COLUMN "Unemployment" TO unemployment;

-- Had to alter columns even further for efficient data storage.
-- ALTER TABLE walmart_sales_cleaned ALTER COLUMN store TYPE INT;
-- ALTER TABLE walmart_sales_cleaned ALTER COLUMN holiday_flag TYPE INT;
-- ALTER TABLE walmart_sales_cleaned ALTER COLUMN date TYPE DATE USING date::date;

SELECT store, COUNT(store) as unique_store_data_count
from walmart_sales_cleaned
WHERE store = 1
GROUP BY store;

-- counting the amount of data we have for flaged and unflaged holidays
SELECT holiday_flag, COUNT(date)  
FROM walmart_sales_cleaned
GROUP BY holiday_flag;

-- Separate it by year
SELECT holiday_flag, COUNT(date)
FROM walmart_sales_cleaned
WHERE EXTRACT(YEAR FROM date) = 2010
GROUP BY holiday_flag;

-- There are three years in the dataset: 2010, 2011, 2012
SELECT DISTINCT EXTRACT(YEAR FROM date)
FROM walmart_sales_cleaned
ORDER BY EXTRACT(YEAR FROM date) ASC;

-- Let's figure out what dates are flagged as holiday
SELECT store, date, holiday_flag 
FROM walmart_sales_cleaned
WHERE holiday_flag = 1
GROUP BY store, date, holiday_flag;
-- Some note worthy things to mention is that the holildays presented in this dataset
-- are 2/12, 9/10, 11/26, 12/31, which are the Fridays before the holiday present, which
-- I believe are Valentines, Sepetember 9/11, Thanksgiving, and New Years

-- See which holidays have affected weekly sales the most
-- Based on the query, we can see that Thanksgiving has the most weekly sales compared
-- to the other holidays. 

SELECT store, date, SUM(weekly_sales)
FROM walmart_sales_cleaned
WHERE holiday_flag = 1
GROUP BY date, store
ORDER BY store ASC, date ASC, SUM(weekly_sales) ASC;

-- Lets see which stores has the lowest and hights unemployment rate, using the AVG
SELECT store, ROUND(CAST(AVG(unemployment) AS NUMERIC), 3) AS avg_unemployment
FROM walmart_sales_cleaned
GROUP BY store
ORDER BY avg_unemployment DESC;
-- Store 28, 12, and 38 has the highest average unemployment rate while Store 40 and 
-- 23 has the lowest

-- Now we want to investigate what factors lead to a high or low unemployment rate.
-- Lets first try seeing how the temperates are like in each store.

WITH avg_store_temp AS (
SELECT store, AVG(temperature) AS avg_temp
FROM walmart_sales_cleaned
GROUP BY store
),
avg_unemployment_rate AS (
SELECT store, AVG(unemployment) AS avg_unemploy
FROM walmart_sales_cleaned
GROUP BY store
)
SELECT t.store, t.avg_temp, u.avg_unemploy
FROM avg_store_temp t
LEFT JOIN avg_unemployment_rate u
ON t.store = u.store
GROUP BY t.store, t.avg_temp, u.avg_unemploy
ORDER BY t.avg_temp DESC, u.avg_unemploy DESC;

-- The correlation between temperature and unemployment rate is low. Lets view other 
-- factors.

-- Maybe fuel price could be a discerning factor for unemployment rate. High fuel cost
-- can impact consumer spending, which could lead to unemployment rate.
WITH max_fuel_price AS (
SELECT store, MAX(fuel_price) AS max_fuel_price
FROM walmart_sales_cleaned
GROUP BY store
),
max_unemployment_rate AS (
SELECT store, MAX(unemployment) as max_unemploy_rate
FROM walmart_sales_cleaned
GROUP BY store
)
SELECT fp.store, fp.max_fuel_price, ur.max_unemploy_rate
FROM max_fuel_price fp
LEFT JOIN max_unemployment_rate ur
ON fp.store = ur.store
ORDER BY max_fuel_price DESC;
-- We can see a correlation with fuel price being a factor in unemployment rate.
-- Although there is a correlation, i wouldnt say it is the sole factor to unemployment.

-- Similar query but now using MIN
WITH min_fuel_price AS (
SELECT store, MIN(fuel_price) AS min_fuel_price
FROM walmart_sales_cleaned
GROUP BY store
),
min_unemployment_rate AS (
SELECT store, MIN(unemployment) AS min_unemploy_rate
FROM walmart_sales_cleaned
GROUP BY store
)
SELECT fp.store, fp.min_fuel_price, ur.min_unemploy_rate
FROM min_fuel_price fp
LEFT JOIN min_unemployment_rate ur
ON fp.store = ur.store
ORDER BY min_fuel_price DESC;


-- There might also be a correlation between the time of year and unemployment rate.
-- Lets see when the unemployment rate is at its lowest and highest

SELECT store, date, unemployment,
		ROW_NUMBER() OVER(PARTITION BY store ORDER BY date ASC) as rank
FROM walmart_sales_cleaned; 

-- Consumer Price Index (CPI), the higher the cpi, the lower the purchasing power of consumer
-- and higher cost of living, which could correlate to unemployment.
SELECT store, date, cpi, unemployment
FROM walmart_sales_cleaned
ORDER BY store ASC, date ASC;


-- Lets see the average cpi and average unemployment rate per year
SELECT store, EXTRACT(YEAR FROM date) AS year, 
AVG(cpi) AS avg_cpi,
AVG(unemployment) AS avg_unemploy
FROM walmart_sales_cleaned
GROUP BY store, year
ORDER BY store, year;

-- Is there a correlation between CPI and weekly sales?
-- Lets check using covariance. Python would be good here but lets strictly just use SQL
-- Covariance will help check to see if there is a positive or negative correlation. 
-- The number we get wont be much importance, but instead the sign will (-, +)
SELECT store, cpi, weekly_sales
FROM walmart_sales_cleaned;

-- This output shows that the covariance is negative. So as CPI goes down, weekly sales goes
-- down too. This makes sense since CPI measures the purchasing power of consumers.
-- A high CPI means that consumers spend more, which would mean more weekly sales. 
SELECT COVAR_POP(cpi, weekly_sales)
FROM walmart_sales_cleaned;


-- Lets now check the correlation coefficient
SELECT COVAR_POP(cpi, weekly_sales) / 
    (STDDEV_POP(cpi) * STDDEV_POP(weekly_sales)) AS correlation_coefficient
FROM walmart_sales_cleaned;

-- I now realized that there already is a built-in correlation function
SELECT CORR(cpi, weekly_sales)
FROM walmart_sales_cleaned;

-- The correlation is -0.07263407421665953, which indications a negative correlation. 
-- However, its near zero so its a very weak correlation.

-- Lets see if the correlation differs when the holiday flag is 0 or 1
WITH holiday_false AS (
SELECT *
FROM walmart_sales_cleaned
WHERE holiday_flag = 0
),

holiday_true AS (
SELECT *
FROM walmart_sales_cleaned
WHERE holiday_flag = 1
)

SELECT CORR(cpi, weekly_sales)
FROM holiday_false;
-- The negative correlation increases when its a holiday compared to when its not


-- Does temperature impact weekly sales?
SELECT CORR(temperature, weekly_sales)
FROM walmart_sales_cleaned;
-- Weak negative correlation with weekly sales


-- Does fuel price impact weekly sales? BY MONTH
SELECT 
	store,
	EXTRACT(YEAR FROM date) as year,
	EXTRACT(MONTH FROM date) as month,
	ROUND(CAST(AVG(fuel_price) AS NUMERIC), 3) AS avg_fuel_price,
	ROUND(CAST(SUM(weekly_sales) AS NUMERIC), 2) AS sum_weekly_sales
FROM walmart_sales_cleaned
GROUP BY store, year, month
ORDER BY store ASC, year ASC, month ASC;

-- More Granular, this time by WEEK
SELECT 
	store,
	EXTRACT(YEAR FROM date) as year,
	EXTRACT(MONTH FROM date) as month,
	EXTRACT(WEEK FROM date) as week,
	ROUND(CAST(AVG(fuel_price) AS NUMERIC), 3) AS avg_fuel_price,
	ROUND(CAST(SUM(weekly_sales) AS NUMERIC), 2) AS sum_weekly_sales
FROM walmart_sales_cleaned
GROUP BY store, year, month, week
ORDER BY store ASC, year ASC, month ASC, week ASC;

-- Partition by year and month
SELECT 
    store, 
    EXTRACT(YEAR FROM date) as year, 
    EXTRACT(MONTH FROM date) as month, 
    EXTRACT(WEEK FROM date) as week, 
    ROUND(CAST(AVG(fuel_price) AS NUMERIC), 3) AS avg_fuel_price, 
    ROUND(CAST(SUM(weekly_sales) AS NUMERIC), 2) AS sum_weekly_sales,
    ROUND(CAST(AVG(fuel_price) OVER (PARTITION BY store, EXTRACT(YEAR FROM date) ORDER BY EXTRACT(WEEK FROM date)) AS NUMERIC), 3) AS yearly_avg_fuel_price,
    ROUND(CAST(SUM(weekly_sales) OVER (PARTITION BY store, EXTRACT(YEAR FROM date) ORDER BY EXTRACT(WEEK FROM date)) AS NUMERIC), 2) AS yearly_cumulative_sales,
    ROUND(CAST(AVG(fuel_price) OVER (PARTITION BY store ORDER BY date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS NUMERIC), 3) AS rolling_avg_fuel_price
FROM walmart_sales_cleaned
GROUP BY store, year, month, week, date, fuel_price, weekly_sales
ORDER BY store ASC, year ASC, month ASC, week ASC;

-- Overall 
SELECT *
FROM walmart_sales_cleaned;

-------- NEW TABLE 'walmart_sales_feature' has been created -----------------
-- ALTER TABLE walmart_sales_feature RENAME COLUMN "Weekly_Sales" TO weekly_sales;
-- ALTER TABLE walmart_sales_feature RENAME COLUMN "Store" TO store;
-- ALTER TABLE walmart_sales_feature RENAME COLUMN "Date" TO date;
-- ALTER TABLE walmart_sales_feature RENAME COLUMN "Holiday_Flag" TO holiday_flag;
-- ALTER TABLE walmart_sales_feature RENAME COLUMN "Temperature" TO temperature;
-- ALTER TABLE walmart_sales_feature RENAME COLUMN "Fuel_Price" TO fuel_price;
-- ALTER TABLE walmart_sales_feature RENAME COLUMN "CPI" to cpi;
-- ALTER TABLE walmart_sales_feature RENAME COLUMN "Unemployment" TO unemployment;

SELECT * 
FROM walmart_sales_feature;

-- Lets see the count for temp_category
SELECT store, temp_category, COUNT(*) as temp_cat_count
FROM walmart_sales_feature
GROUP BY store, temp_category
ORDER BY store ASC, temp_category;

-- What months have the most weekly sales across all stores for each year?
SELECT month, ROUND(CAST(SUM(weekly_sales) AS INT), 2) as sum_weekly_sales
FROM walmart_sales_feature
GROUP BY month
ORDER BY sum_weekly_sales DESC;
-- It shows to be July that has the most weekly sales while January has the least 
-- Does holiday have an influence to this?

SELECT month, ROUND(CAST(SUM(weekly_sales) AS INT), 2) as sum_weekly_sales
FROM walmart_sales_feature
WHERE holiday_flag = 1
GROUP BY month
ORDER BY sum_weekly_sales DESC;

SELECT date, holiday_flag
FROM walmart_sales_feature
WHERE holiday_flag = 1;

-- To see how many instances of each month per year are in this dataset. 2010-02 -> 2012-10
SELECT 
    EXTRACT(YEAR FROM date) AS year,
    month,
    COUNT(DISTINCT date) AS unique_days
FROM walmart_sales_feature
WHERE store = 1
GROUP BY EXTRACT(YEAR FROM date), month
ORDER BY year, CAST(month AS INTEGER);


-- Lets see which holidays have the most impact on sales between 2010-2011, since 2012 
-- is missing November and December
SELECT month, SUM(weekly_sales) as weekly_sales_sum
FROM walmart_sales_feature
WHERE holiday_flag = 1
AND EXTRACT(YEAR FROM date) IN (2010, 2011)
GROUP BY month
ORDER BY SUM(weekly_sales) DESC;
-- November tends to have the most influence on sales.

-- Which stores tend to have the highest and lowest unemployment rate
SELECT store, MAX(unemployment) as max_unemployment
FROM walmart_sales_feature
GROUP BY store
ORDER BY MAX(unemployment) DESC;

SELECT store, MIN(unemployment) as min_unemployment
FROM walmart_sales_feature
GROUP BY store
ORDER BY MIN(unemployment) ASC;

SELECT store, AVG(unemployment) as avg_unemployment
FROM walmart_sales_feature
GROUP BY store
ORDER BY AVG(unemployment) DESC;

-- To directly answer the question, store 28 has the highest unemployment rate(14.313)on record,
-- while store 4 has the lowest unemployment rate on record reaching as low as 3.879.
-- On average, 28 still tends to have the highest unemployment trend throughout the dataset
-- while store 40 has has on average the lowest unemployment rate.



-- What factors do you think are impacting the unemployment rate?
-- A few factors could impact unemployment rate, such as cpi, temperature, and fuel_price. 
-- Unemployment rating could also be affect by the weekly_sales.

-- Lets first start with Consumer Price Index (CPI)
-- Higher CPI means prices of goods/cost of living increase (Could indicate Inflation)
-- Lower CPI means prices of goods/cost of living are dropping (Indicating Defation)

-- Lets see the same MAX/MIN/AVG values for each of the stores.
SELECT store,
	MAX(cpi) AS max_cpi,
	MIN(cpi) AS min_cpi,
	AVG(cpi) AS avg_cpi,
	AVG(unemployment) AS avg_unemployment
FROM walmart_sales_feature
GROUP BY store
ORDER BY AVG(unemployment) DESC;
-- Lets see the correlation
-- There seems to be variations between high CPI and avg unemployment. CPI may have an
-- influence in unemployment, but probably isnt the only one.

SELECT
	CORR(cpi, unemployment)
FROM walmart_sales_feature;
-- Shows to be a moderate negative correlation. If CPI goes down, Unemployment should go 
-- down too.


-- Lets try now temperature
SELECT store,
	MAX(temperature) AS max_temperature,
	MIN(temperature) AS min_temperature,
	AVG(temperature) AS avg_tempearture,
	AVG(unemployment) AS avg_unemployment
FROM walmart_sales_feature
GROUP BY store
ORDER BY AVG(unemployment) DESC;

SELECT 
	CORR(temperature, unemployment)
FROM walmart_sales_feature;

-- There is a slight postive correlation between temperature and unemployment rate. We can 
-- also see from the query above that highest avg_unemployment rate tend to have a max temp
-- of 99, a low of 38, avg temp of 70. (This could mean that These stores are relatively 
-- close when it comes to region). The stores with the lowest avg unemployment tend to have 
-- around the max temp of 77, min temp of 10, and avg temp of 48.
-- Due to the weak postive correlation, tempearture might not the deciding factor of 
-- unemployment.


-- Lets see now fuel_price.
SELECT store,
	MAX(fuel_price) AS max_fuel_price,
	MIN(fuel_price) AS min_fuel_price,
	AVG(fuel_price) AS avg_fuel_price,
	AVG(unemployment) AS avg_unemployment
FROM walmart_sales_feature
GROUP BY store
ORDER BY AVG(unemployment) DESC;

SELECT 
	CORR(fuel_price, unemployment)
FROM walmart_sales_feature;

-- NOPE! Based on the queries above, which shows to be a very weak negative correlation
-- of -0.03, and very similar variant of max, min, and avg fuel price. Fuel price isnt
-- a big influence to unemployment.


-- Lets move on to weekly_sales itself.
SELECT store,
	MAX(weekly_sales) AS max_weekly_sales,
	MIN(weekly_sales) AS min_weekly_sales,
	AVG(weekly_sales) AS avg_weekly_sales,
	AVG(unemployment) AS avg_unemployment
FROM walmart_sales_feature
GROUP BY store
ORDER BY AVG(unemployment) DESC;

SELECT
	CORR(weekly_sales, unemployment)
FROM walmart_sales_feature;

-- There is a slight negative correlation of -0.1. There is wide variation of weekly_sales
-- which doesnt indicate that it is the biggest influence to unemployment.


-- From the information i gathered, it seems CPI has the most influential feature that 
-- plays a part in unemployment rating increasing.

SELECT 
	CORR(cpi, unemployment) as cpi_unemployment,
	CORR(weekly_sales, unemployment) as weekly_sales_unemployment,
	CORR(temperature, unemployment) as temperature_unemployment,
	CORR(fuel_price, unemployment) as fuel_price_unemployment
FROM walmart_sales_feature;

-- Lets see how temperature category goes with each store
SELECT store,
	temp_category,
	COUNT(*) as temp_count
FROM walmart_sales_feature
GROUP BY store, temp_category
ORDER BY store ASC;
-- USE TABLEAU GRAPH FOR THIS ^


-- Which quarters tend to have the most sales
-- I might need to exclude quarter 1 for year 2010, and quarter 4 for 2012
SELECT store,
	quarter,
	SUM(quarter) as sum_quarter
FROM walmart_sales_feature
GROUP BY store, quarter
ORDER BY store ASC, quarter ASC;
-- MAYBE EXCLUDE IT GRAPH WISE 


-- 
SELECT
	CORR(temperature, weekly_sales),
	CORR(fuel_price, weekly_sales),
	CORR(cpi, weekly_sales),
	CORR(unemployment, weekly_sales)
FROM walmart_sales_feature;

-- With November and December being missing from 2012, there is a decline in yearly-sales
WITH yearly_sales AS (
	SELECT 
		EXTRACT(YEAR FROM date) AS year,
		SUM(weekly_sales) AS total_sales
	FROM walmart_sales_feature
	GROUP BY EXTRACT(YEAR FROM date)
)
SELECT 
  current.year,
  current.total_sales,
  previous.total_sales AS previous_year_sales,
  ((current.total_sales - previous.total_sales) / previous.total_sales) * 100 AS year_growth_percentage
FROM yearly_sales current
LEFT JOIN yearly_sales previous ON current.year = previous.year + 1
ORDER BY current.year;

-- 
SELECT 
    CASE 
        WHEN holiday_flag = 1 THEN 'Holiday'
        ELSE 'Non-Holiday'
    END AS period,
    AVG(weekly_sales) AS avg_weekly_sales,
    MAX(weekly_sales) AS max_weekly_sales,
    MIN(weekly_sales) AS min_weekly_sales
FROM walmart_sales_feature
WHERE EXTRACT(YEAR FROM date) != 2012
GROUP BY holiday_flag

UNION ALL

SELECT 
    'November Holiday' AS period,
    AVG(weekly_sales) AS avg_weekly_sales,
    MAX(weekly_sales) AS max_weekly_sales,
    MIN(weekly_sales) AS min_weekly_sales
FROM walmart_sales_feature
WHERE EXTRACT(MONTH FROM date) = 11 
  AND holiday_flag = 1
  AND EXTRACT(YEAR FROM date) != 2012

UNION ALL

SELECT 
    'November Non-Holiday' AS period,
    AVG(weekly_sales) AS avg_weekly_sales,
    MAX(weekly_sales) AS max_weekly_sales,
    MIN(weekly_sales) AS min_weekly_sales
FROM walmart_sales_feature
WHERE EXTRACT(MONTH FROM date) = 11 
  AND holiday_flag = 0
  AND EXTRACT(YEAR FROM date) != 2012;

-- See the percentage increase of sales between holidays and non-holidays
SELECT 
    EXTRACT(MONTH FROM date) AS month,
    AVG(CASE WHEN holiday_flag = 1 THEN weekly_sales ELSE NULL END) AS avg_holiday_sales,
    AVG(CASE WHEN holiday_flag = 0 THEN weekly_sales ELSE NULL END) AS avg_non_holiday_sales,
    (AVG(CASE WHEN holiday_flag = 1 THEN weekly_sales ELSE NULL END) - 
     AVG(CASE WHEN holiday_flag = 0 THEN weekly_sales ELSE NULL END)) / 
     AVG(CASE WHEN holiday_flag = 0 THEN weekly_sales ELSE NULL END) * 100 AS percent_increase
FROM walmart_sales_feature
WHERE EXTRACT(MONTH FROM date) IN (2, 9, 11, 12)
  AND EXTRACT(YEAR FROM date) < 2012
GROUP BY EXTRACT(MONTH FROM date)
ORDER BY EXTRACT(MONTH FROM date);

SELECT DISTINCT date, holiday_flag 
FROM walmart_sales_feature 
WHERE EXTRACT(MONTH FROM date) = 12 
ORDER BY date;

SELECT 
  date, 
  EXTRACT(WEEK FROM date) AS week_number,
  holiday_flag,
  AVG(weekly_sales) AS avg_weekly_sales
FROM walmart_sales_feature
WHERE EXTRACT(MONTH FROM date) = 12
GROUP BY date, EXTRACT(WEEK FROM date), holiday_flag
ORDER BY date;
