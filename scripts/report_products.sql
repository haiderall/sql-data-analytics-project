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
=============================================================================
0) Create Report: gold.report_products
=============================================================================*/
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
