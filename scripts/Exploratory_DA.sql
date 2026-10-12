/*
===============================================================================
Exploratory Data Analysis (EDA) - MySQL 8.0
===============================================================================
Script Purpose:
    Profiles the gold layer of the data warehouse to understand its structure,
    contents, and shape before deeper analysis. It answers "what do we have,
    and what does it look like?" for the customers, products and sales data.

Database:
    DataWareHouseAnalytics (snapshot of DataWareHouse gold views as tables):
    gold_dim_customers, gold_dim_products, gold_fact_sales

Contents:
	Creates the analytics database and copies the gold views into tables
    Lists tables and columns (information_schema)
    Explores distinct values in dimension columns (country, category, subcategory, product)
    Finds first/last order dates, time span covered, and customer age range
    Computes key totals and averages (sales, quantity, price, orders) in one report
    Compares measures across dimensions (e.g. sales by country, revenue by category)
    Ranks best and worst performers (top/bottom products and customers)

Notes:
    - Run the files in numeric order
=============================================================
0. Create Database
=============================================================
Purpose:
    This script creates a new database named 'DataWarehouseAnalytics' after checking if it already exists. 
    If the database exists, it is dropped and recreated. Additionally, this script creates a table called gold
*/

CREATE DATABASE IF NOT EXISTS DataWareHouseAnalytics;

CREATE TABLE DataWareHouseAnalytics.gold_fact_sales AS
SELECT * FROM DataWareHouse.gold_fact_sales;   -- schema.view
use DataWareHouseAnalytics;

/*
===============================================================================
1. Database Exploration
===============================================================================
Purpose:
    - To explore the structure of the database, including the list of tables and their schemas.
    - To inspect the columns and metadata for specific tables.
*/

SHOW COLUMNS FROM DataWareHouseAnalytics.gold_dim_customers;
SHOW COLUMNS FROM DataWareHouseAnalytics.gold_dim_products;
SHOW COLUMNS FROM DataWareHouseAnalytics.gold_fact_sales;

/*
===============================================================================
2. Dimensions Exploration
===============================================================================
Purpose:
    - To explore the structure of dimension tables.
*/

select distinct country from gold_dim_customers;
select distinct category, subcategory, product_name from gold_dim_products
order by 1,2,3;

/*
===============================================================================
3. Date Range Exploration 
===============================================================================
Purpose:
    - To determine the temporal boundaries of key data points.
    - To understand the range of historical data.
*/
-- Date of first and last order
-- How many years of sales are available?
select min(order_date) as first_order,
	   max(order_date) as last_order,
       TIMESTAMPDIFF(year, min(order_date), max(order_date)) as order_range_yrs
       from gold_fact_sales;
       
-- Youngest and Oldest Customer
select min(birthdate) as oldest_birthdate,
       TIMESTAMPDIFF(year, min(birthdate), curdate()) as oldest_customer,
	   max(birthdate) as youngest_birthdate,
       TIMESTAMPDIFF(year, max(birthdate), curdate()) as youngest_customer
from gold_dim_customers;

/*
===============================================================================
4. Measures Exploration (Key Metrics)
===============================================================================
Purpose:
    - To calculate aggregated metrics (e.g., totals, averages) for quick insights.
    - To identify overall trends or spot anomalies.
*/
-- Find the Total Sales
select sum(sales_amount) as total_sales from gold_fact_sales;

-- Find how many items are sold
select sum(quantity) as total_items_sold from gold_fact_sales;

-- Find the average selling price
select avg(price) as avg_price from gold_fact_sales;

-- Find the Total number of Orders
select count(order_number) as total_orders from gold_fact_sales;
select count(distinct order_number) as total_orders from gold_fact_sales; -- eliminates duplicates

-- Find the total number of products
select count(product_key) as total_products from gold_dim_products;
select count(distinct product_key) as total_products from gold_dim_products;

-- Find the total number of customers
select count(distinct customer_key) as total_customers from gold_dim_customers;

-- Find the total number of customers that has placed an order
select count(distinct customer_key) as total_customers from gold_fact_sales;


-- Generate a Report that shows all key metrics of the business
select 'Total Sales' as measure_name, sum(sales_amount) as measure_value from gold_fact_sales
UNION ALL
select 'Total Quantity', sum(quantity) from gold_fact_sales
UNION ALL
select 'Average Price', avg(price) from gold_fact_sales
UNION ALL
select 'Total Orders', count(distinct order_number) from gold_fact_sales
UNION ALL
select 'Total Products', count(product_key) from gold_dim_products
UNION ALL
select 'Total Customers', count(distinct customer_key) from gold_dim_customers;

/*
===============================================================================
5. Magnitude Analysis
===============================================================================
Purpose:
    - To quantify data and group results by specific dimensions.
    - For understanding data distribution across categories.
*/
-- Find total customers by countries
select
country,
count(distinct customer_key) as total_customers
from gold_dim_customers
group by country
order by total_customers desc;

-- Find total customers by gender
select
gender,
count(distinct customer_key) as total_customers
from gold_dim_customers
group by gender
order by total_customers desc;

-- Find total products by category
select
category,
count(distinct product_key) as total_products
from gold_dim_products
group by category
order by total_products desc;

-- What is the average costs in each category?
select
category,
avg(cost) as avg_cost
from gold_dim_products
group by category
order by avg_cost desc;

-- What is the total revenue generated for each category?
select
p.category,
sum(f.sales_amount) as total_revenue
from gold_fact_sales f
left join gold_dim_products p
on f.product_key = p.product_key
group by category
order by total_revenue desc;

-- What is the total revenue generated by each customer?
select
c.customer_key,
c.first_name,
c.last_name,
sum(f.sales_amount) as total_revenue
from gold_fact_sales f
left join gold_dim_customers c
on f.customer_key = c.customer_key
group by c.customer_key, c.first_name, c.last_name
order by total_revenue desc;

-- What is the distribution of sold items across countries?
-- total quantity by country
select
c.country,
sum(f.quantity) as total_items_sold
from gold_fact_sales f
left join gold_dim_customers c
on f.customer_key = c.customer_key
group by c.country
order by total_items_sold desc;

/*
===============================================================================
6. Ranking Analysis
===============================================================================
Purpose:
    - To rank items (e.g., products, customers) based on performance or other metrics.
    - To identify top performers or laggards.
*/
-- Which 5 products Generating the Highest Revenue?
select * from(
	select
	p.product_name,
	sum(f.sales_amount) total_revenue,
	row_number() over (order by sum(f.sales_amount) desc) as product_rank
	from gold_fact_sales f
	left join gold_dim_products p
	on f.product_key = p.product_key
	group by p.product_name)t
where product_rank <=5;

-- What are the 5 worst-performing products in terms of sales?
select * from(
	select
	p.product_name,
	sum(f.sales_amount) total_revenue,
	row_number() over (order by sum(f.sales_amount) asc) as product_rank_worst
	from gold_fact_sales f
	left join gold_dim_products p
	on f.product_key = p.product_key
	group by p.product_name) t
where product_rank_worst <=5;

-- Find the top 10 customers who have generated the highest revenue
select * from (
	select
	c.customer_key,
    c.first_name,
    c.last_name,
	sum(f.sales_amount) total_revenue,
	row_number() over (order by sum(f.sales_amount) desc) as highest_revenue
	from gold_fact_sales f
	left join gold_dim_customers c
	on f.customer_key = c.customer_key
	group by c.first_name, c.last_name, c.customer_key)t
where highest_revenue <=10;

-- The 3 customers with the fewest orders placed
select * from (
	select
	c.customer_key,
    c.first_name,
    c.last_name,
    count(distinct f.order_number) as total_orders,
	row_number() over (order by count(distinct f.order_number) asc) as fewest_orders
	from gold_fact_sales f
	left join gold_dim_customers c
	on f.customer_key = c.customer_key
	group by c.first_name, c.last_name, c.customer_key)t
where fewest_orders <=3;
