use `DataWareHouseAnalytics`;

-- 1. Change Over Time Analysis

-- Analyse sales performance over days
-- Quick Date Functions

select
order_date,
sum(sales_amount) as total_sales
from gold_fact_sales
where order_date is not null
group by order_date
order by order_date;

-- Analyse sales performance over years and months
select
DATE_FORMAT(order_date, '%Y-%m') as order_date,
count(distinct customer_key) as total_customers,
sum(sales_amount) as total_sales,
sum(quantity) as total_quantity
from gold_fact_sales
where (order_date) is not null
group by DATE_FORMAT(order_date, '%Y-%m')
order by DATE_FORMAT(order_date, '%Y-%m');

-- can also use format for custom date format dmy


-- 2. Cumulative Analysis

-- Calculate the total sales per month 
-- and the running total of sales over time and moving avg price
select 
order_date,
total_sales,
sum(total_sales) over (partition by order_date order by order_date) as running_total_sales,
avg(avg_price) over (order by order_date) as moving_avg_price
from
(
	select
	DATE_FORMAT(order_date, '%Y-%m-01') as order_date,
	sum(sales_amount) total_sales,
    avg(price) avg_price 
	from gold_fact_sales
	where order_date is not null  
	group by DATE_FORMAT(order_date, '%Y-%m-01') 
)t;

-- 3. Performance Analysis (Year-over-Year, Month-over-Month)
/*
Analyze the yearly performance of products by comparing their sales 
to both the average sales performance of the product and the previous year's sales */

with yearly_product_sales as (

select
year(f.order_date) as order_year,
p.product_name,
sum(f.sales_amount) current_sales
from gold_fact_sales f
left join gold_dim_products p
on f.product_key = p.product_key 
where f.order_date is not null
group by year(f.order_date), p.product_name
)
select
order_year,
product_name,
current_sales,
avg(current_sales) over (partition by product_name) avg_sales,
current_sales - avg(current_sales) over (partition by product_name) diff_avg,
case when current_sales - avg(current_sales) over (partition by product_name) > 0 then 'Above Avg'
	 when current_sales - avg(current_sales) over (partition by product_name) < 0 then 'Below Avg'
     else 'Avg'
end avg_change,
-- YOY Analysis
lag(current_sales) over (partition by product_name order by order_year) py_sales,
current_sales - lag(current_sales) over (partition by product_name order by order_year) diff_py,
case when current_sales - lag(current_sales) over (partition by product_name order by order_year) > 0 then 'Increased'
	 when current_sales - lag(current_sales) over (partition by product_name order by order_year) < 0 then 'Decreased'
     else 'No Change'
end py_change
from yearly_product_sales;


-- 4. Part-to-Whole Analysis
-- Which categories contribute the most to overall sales?

with category_sales as (
select
p.category,
sum(f.sales_amount) as total_sales
from gold_fact_sales f
left join gold_dim_products p
on f.product_key = p.product_key
group by category)

select
category,
total_sales,
sum(total_sales) over() overall_sales,
concat(round((total_sales/sum(total_sales) over()) * 100, 2), '%') as contrib_to_sales
from category_sales;


 -- 5. Data Segmentation Analysis (Case when)
/*Segment products into cost ranges and 
count how many products fall into each segment*/

with product_segments as (
select
product_key,
product_name,
cost,
case when cost < 100 then 'Below 100'
	 when cost between 100 and 500 then 'Between 100-500'
	 when cost between 500 and 1000 then 'Between 500-1000'
     else 'Above 1000'
end cost_range
from gold_dim_products)

select 
cost_range,
count(product_key) total_products
from product_segments
group by cost_range
order by total_products desc;

/*Group customers into three segments based on their spending behavior:
	- VIP: Customers with at least 12 months of history and spending more than €5,000.
	- Regular: Customers with at least 12 months of history but spending €5,000 or less.
	- New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group
*/

with customer_spending as (

select
c.customer_key,
sum(f.sales_amount) as total_spending,
min(order_date) as first_order,
max(order_date) as last_order,
TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
from gold_fact_sales f
left join gold_dim_customers c
on f.customer_key = c.customer_key
group by c.customer_key)

select
cust_segment,
count(customer_key) as total_cust
from (
	select
	customer_key,
	case when lifespan >= 12 and total_spending > 5000 then 'VIP'
		 when lifespan >= 12 and total_spending <= 5000 then 'Regular'
		 else 'New'
	end cust_segment
	from customer_spending) t
group by cust_segment
order by total_cust desc;


/*
===============================================================================
Customer Report
===============================================================================
Purpose:
    - This report consolidates key customer metrics and behaviors

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
	   - total orders
	   - total sales
	   - total quantity purchased
	   - total products
	   - lifespan (in months)
    4. Calculates valuable KPIs:
	    - recency (months since last order)
		- average order value
		- average monthly spend
=============================================================================== */
-- =============================================================================
-- Create Report: gold.report_products
-- =============================================================================
create view gold_report_customers as
with base_query as (
/*---------------------------------------------------------------------------
1) Base Query: Retrieves core columns from tables
---------------------------------------------------------------------------*/
select
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
concat(first_name, ' ', last_name) cust_name,
TIMESTAMPDIFF(year, c.birthdate, curdate()) age
from gold_fact_sales f
left join gold_dim_customers c
on c.customer_key = f.customer_key
where order_date is not null)

, cust_aggregation as (
/*---------------------------------------------------------------------------
2) Customer Aggregations: Summarizes key metrics at the customer level
---------------------------------------------------------------------------*/
select
	customer_key,
	customer_number,
	cust_name,
	age,
	count(distinct order_number) total_orders,
	sum(sales_amount) total_sales,
	sum(quantity) total_quantity_purchased,
	count(distinct product_key) total_products,
	max(order_date) last_order_date,
	TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) lifespan
from base_query
	group by 
	customer_key,
	customer_number,
	cust_name,
	age)
    
select 
customer_key,
customer_number,
cust_name,
age,
case when age < 20 then 'Under 20'
	 when age between 20 and 29 then '20-29'
     when age between 30 and 39 then '30-39'
     when age between 40 and 49 then '40-49'
	 else '50 and Above'
end age_group,
case when lifespan >= 12 and total_sales > 5000 then 'VIP'
	 when lifespan >= 12 and total_sales <= 5000 then 'Regular'
	 else 'New'
end cust_segment,
total_orders,
last_order_date,
TIMESTAMPDIFF(MONTH, last_order_date, curdate()) recency,
total_sales,
total_quantity_purchased,
total_products,
lifespan,
-- Compute average order value (AVO)
case when total_sales = 0 then 0
else round(total_sales/total_orders, 2)
end avg_order_value,
-- Compute average monthly spend
case when lifespan = 0 then total_sales
else round(total_sales/lifespan, 2)
end avg_monthly_spend
from cust_aggregation;


/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
       - total orders
       - total sales
       - total quantity sold
       - total customers (unique)
       - lifespan (in months)
    4. Calculates valuable KPIs:
       - recency (months since last sale)
       - average order revenue (AOR)
       - average monthly revenue
===============================================================================
*/
-- =============================================================================
-- Create Report: gold.report_products
-- =============================================================================
create view gold_report_products as
with base_query as (
/*---------------------------------------------------------------------------
1) Base Query: Retrieves core columns from fact_sales and dim_products
---------------------------------------------------------------------------*/
select
f.order_date,
f.order_number,
f.customer_key,
f.sales_amount,
f.quantity,
p.product_key,
p.product_name,
p.category,
p.subcategory,
p.cost
from gold_fact_sales f
left join gold_dim_products p
on p.product_key = f.product_key
where order_date is not null)

, prod_aggregation as (
/*---------------------------------------------------------------------------
2) Product Aggregations: Summarizes key metrics at the product level
---------------------------------------------------------------------------*/
select
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	count(distinct order_number) total_orders,
	sum(sales_amount) total_sales,
	sum(quantity) total_quantity_sold,
	count(distinct customer_key) total_customers,
	round(sum(sales_amount) / nullif(sum(quantity), 0), 1) as avg_selling_price,
	TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) lifespan,
    max(order_date) last_sale_date
from base_query
group by
		product_key,
		product_name,
		category,
		subcategory,
		cost)
/*---------------------------------------------------------------------------
  3) Final Query: Combines all product results into one output
---------------------------------------------------------------------------*/
select 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
    last_sale_date,
	TIMESTAMPDIFF(MONTH, last_sale_date, curdate()) recency,
case
	 when total_sales > 50000 then 'High-Performer'
	 when total_sales >= 10000 then 'Mid-Range'
	 else 'Low-Performer'
end prod_segment,
total_orders,
lifespan,
total_sales,
total_quantity_sold,
total_customers,
avg_selling_price,
	-- Average Order Revenue (AOR)
case when total_orders = 0 then 0
else round(total_sales/total_orders, 2)
end avg_order_revenue,  
	-- Average Monthly Revenue
case when lifespan = 0 then total_sales
else round(total_sales/lifespan, 2)
end avg_monthly_spend
from prod_aggregation;
