# 📊 SQL Data Analytics Project

A comprehensive collection of SQL scripts for data exploration, analytics, and reporting. These scripts cover various analyses such as database exploration, measures and metrics, time-based trends, cumulative analytics, segmentation, and more. This repository contains SQL queries designed to help data analysts and BI professionals quickly explore, segment, and analyze data within a relational database. Each script focuses on a specific analytical theme and demonstrates best practices for SQL queries.

---

## 🏗️ Data Architecture

This project sits on top of the Gold layer of the [SQL Data Warehouse Project](github.com/haiderall/sql-data-warehouse-project) , which follows Medallion Architecture (Bronze → Silver → Gold):

1. **Source: Gold Layer (DataWareHouse):** Business-ready star schema (`gold_dim_customers`, `gold_dim_products`, `gold_fact_sales`) built from cleansed ERP and CRM data.
2. **Analytics Database (DataWareHouseAnalytics):** A snapshot of the gold views copied as tables into a separate MySQL database, so analysis never touches the warehouse itself.
3. **Insights Layer:** SQL queries and reusable report views that turn the star schema into answers about customers, products, and sales.

## 🚀 Project Requirements

### BI: Analytics & Reporting (Data Analysis)

#### Objective
Develop SQL-based analytics to deliver detailed insights into:
- **Customer Behavior**
- **Product Performance**
- **Sales Trends**

#### Specifications
- **Data Source:** Gold-layer star schema from the data warehouse project, copied into `DataWareHouseAnalytics`.
- **Tooling:** MySQL 8.0 (CTEs and window functions required).
- **Scope:** Latest dataset only; analysis is run on a static snapshot.
- **Output:** Documented, rerunnable SQL scripts and two report views for stakeholders.

## ☕ Stay Connected
Let's stay in touch!

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://linkedin.com/in/haiderralii)

## 🛡️ License
This project is licensed under the [MIT License](LICENSE)
