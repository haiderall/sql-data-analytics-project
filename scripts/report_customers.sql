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

=============================================================================
0) Create Report: gold_report_products
=============================================================================*/
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
