# Q1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
SELECT DISTINCT market 
FROM dim_customer
WHERE customer='Atliq Exclusive' AND region='APAC';
----------------------------------------------------------------------------------------------------------------------------------
# Q2. What is the percentage of unique product increase in 2021 vs. 2020? 
# The final output contains these fields (unique_products_2020, unique_products_2021, percentage_chg)
SELECT unique_products_2020, unique_products_2021,
CONCAT(ROUND((unique_products_2021 - unique_products_2020)/unique_products_2020*100.0, 2), '%') AS percentage_change
FROM
	(
	SELECT 
		(SELECT COUNT(DISTINCT product_code) FROM fact_sales_monthly WHERE fiscal_year=2020) unique_products_2020,
		(SELECT COUNT(DISTINCT product_code) FROM fact_sales_monthly WHERE fiscal_year=2021) unique_products_2021
	) a;
-----------------------------------------------------------------------------------------------------------------------------------
# Q3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
# The final output contains 2 fields: segment, product_count
SELECT segment, 
       COUNT(DISTINCT product_code) unique_prod_count_per_segment
FROM dim_product
GROUP BY 1
ORDER BY 2 DESC;
-----------------------------------------------------------------------------------------------------------------------------------
# Q4. Which segment had the most increase in unique products in 2021 vs 2020? 
# The final output contains these fields: segment, product_count_2020, product_count_2021, difference
WITH temp_table AS
	(
	SELECT s.product_code, segment, fiscal_year
	FROM fact_sales_monthly s 
	JOIN dim_product p 
	ON s.product_code = p.product_code 
	)

SELECT segment, 
       COUNT(DISTINCT products_2020) product_count_2020, 
       COUNT(DISTINCT products_2021) product_count_2021,
	  (COUNT(DISTINCT products_2021) - COUNT(DISTINCT products_2020)) AS difference
FROM
	(
		SELECT product_code, segment, fiscal_year,
			   CASE WHEN fiscal_year=2020 THEN product_code ELSE NULL END products_2020,
			   CASE WHEN fiscal_year=2021 THEN product_code ELSE NULL END products_2021
		FROM temp_table
	) a
GROUP BY 1
ORDER BY 4 DESC
LIMIT 1;
----------------------------------------------------------------------------------------------------------------------------------
# Q5. Get the products that have the highest and lowest manufacturing costs.
# The final output should contain these fields: product_code, product, manufacturing_cost 
SELECT m.product_code, product, manufacturing_cost
FROM fact_manufacturing_cost m
JOIN dim_product p
ON m.product_code = p.product_code
WHERE manufacturing_cost = (SELECT MIN(manufacturing_cost) 
                            FROM fact_manufacturing_cost)
OR manufacturing_cost = (SELECT MAX(manufacturing_cost) 
                         FROM fact_manufacturing_cost);
----------------------------------------------------------------------------------------------------------------------------------
# Q6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the 
# fiscal year 2021 and in the Indian market. 
# The final output contains these fields: customer_code, customer, average_discount_percentage
SELECT customer_code, customer, 
	   CONCAT(avg_pre_invoice_discount, '%') avg_pre_invoice_discount_pct
FROM (
		SELECT TRIM(customer) customer, i.customer_code,
			   ROUND(AVG(i.pre_invoice_discount_pct)*100.0, 2) avg_pre_invoice_discount
		FROM fact_pre_invoice_deductions i
		JOIN dim_customer c
		ON i.customer_code = c.customer_code
		WHERE market = 'India' AND fiscal_year = 2021
		GROUP BY 1
		ORDER BY 3 DESC
	) a
LIMIT 5;
----------------------------------------------------------------------------------------------------------------------------------
# Q7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. 
# This analysis helps to get an idea of low and high-performing months and take strategic decisions.
# The final report contains these columns: Month, Year, Gross sales Amount
SELECT Month, Year, Gross_Sales_Amount_mln
FROM
(
	SELECT YEAR(s.date) Year, MONTH(s.date) Month_number, MONTHNAME(s.date) Month, 
	       ROUND(SUM(gross_price*sold_quantity)/1000000, 2) Gross_Sales_Amount_mln
	FROM fact_sales_monthly s
	JOIN dim_customer c
	ON s.customer_code = c.customer_code
	JOIN fact_gross_price g
	ON s.product_code = g.product_code
	WHERE customer = 'Atliq Exclusive'
	GROUP BY 1, 2
	ORDER BY 1, 2
) a;
----------------------------------------------------------------------------------------------------------------------------------
# Q8. In which quarter of 2020, got the maximum total_sold_quantity? 
# The final output contains these fields sorted by the total_sold_quantity: Quarter, total_sold_quantity
SELECT CASE WHEN Month_2020 IN (9, 10, 11) THEN 'Q1'
            WHEN Month_2020 IN (12, 1, 2) THEN 'Q2'
            WHEN Month_2020 IN (3, 4, 5) THEN 'Q3' 
            WHEN Month_2020 IN (6, 7, 8) THEN 'Q4' END AS Quarter_2020, 
       SUM(total_sold_quantity_month) tot_sold_qty_quarter
FROM
(
	SELECT MONTH(date) Month_2020, SUM(sold_quantity) total_sold_quantity_month
	FROM fact_sales_monthly
	WHERE fiscal_year = 2020
	GROUP BY 1
) a
GROUP BY 1
ORDER BY 2 DESC;
---------------------------------------------------------------------------------------------------------------------------------
# Q9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
# The final output contains these fields: channel, gross_sales_mln, percentage
WITH gross_price_2021 AS
(
	SELECT * FROM fact_gross_price WHERE fiscal_year = 2021
),
sales_2021 AS
(
	SELECT * FROM fact_sales_monthly WHERE fiscal_year = 2021
),
gross_sales_2021 AS
(
	SELECT channel, gross_price, sold_quantity, (gross_price*sold_quantity) AS gross_sales_mln
	FROM sales_2021 s
	JOIN gross_price_2021 g
	ON s.product_code = g.product_code
	JOIN dim_customer c
	ON s.customer_code = c.customer_code
)
SELECT *, 
CONCAT(ROUND(gross_sales_channel_mln/(SELECT SUM(gross_sales_mln/1000000) FROM gross_sales_2021)*100.0, 2), '%') pct_contribution
FROM
(
	SELECT channel, ROUND(SUM(gross_sales_mln/1000000), 2) gross_sales_channel_mln
	FROM gross_sales_2021
	GROUP BY 1
) a
GROUP BY 1 
ORDER BY 2 DESC 
LIMIT 1;
---------------------------------------------------------------------------------------------------------------------------------
# Q10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
# The final output contains these fields: division, product_code, product, total_sold_quantity, rank_order
SELECT b.division, b.product_code, product, total_sold_quantity, rank_order
FROM
(
	SELECT *, DENSE_RANK() OVER(PARTITION BY division ORDER BY total_sold_quantity DESC) rank_order
	FROM
	(
		SELECT division, s.product_code, SUM(sold_quantity) total_sold_quantity
		FROM fact_sales_monthly s
		JOIN dim_product p
		ON s.product_code = p.product_code
		WHERE fiscal_year = 2021
		GROUP BY 1, 2
	) a
) b
JOIN dim_product p
ON b.product_code = p.product_code
WHERE rank_order = 1 OR rank_order = 2 OR rank_order = 3
ORDER BY 4 DESC;