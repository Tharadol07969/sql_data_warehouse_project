/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT
	ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,
	ci.cst_id AS customer_id,
	ci.cst_key AS customer_number,
	ci.cst_firstname AS firstname,
	ci.cst_lastname AS lastname,
	cl.cntry AS country,
	ci.cst_marital_status AS marital_status,
	CASE WHEN ci.cst_gndr <> 'Unknown' THEN ci.cst_gndr
		 ELSE COALESCE(ca.gen, 'Unknown')
	END AS gender,
	ca.bdate AS birthdate,
	ci.cst_create_date AS create_date
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 AS cl
ON ci.cst_key = cl.cid;
GO

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT
	ROW_NUMBER() OVER (ORDER BY prd_start_dt, prd_key) AS product_key,
	pr.prd_id AS product_id,
	pr.prd_key AS product_number,
	pr.prd_nm AS product_name,
	pr.cat_id AS category_id,
	ca.cat AS category,
	ca.subcat AS subcategory,
	ca.maintenance AS maintenance,
	pr.prd_cost AS cost,
	pr.prd_line AS product_line,
	pr.prd_start_dt AS start_date
FROM silver.crm_prd_info AS pr
LEFT JOIN silver.erp_px_cat_g1v2 AS ca
ON pr.cat_id = ca.id
WHERE pr.prd_end_dt IS NULL; -- Filter out all outdated products
GO

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT
	fs.sls_ord_num AS order_number,
	dp.product_key,
	dc.customer_key,
	fs.sls_order_dt AS order_date,
	fs.sls_ship_dt AS ship_date,
	fs.sls_due_dt AS due_date,
	fs.sls_sales AS sales_amount,
	fs.sls_quantity AS quantity,
	fs.sls_price AS price
FROM silver.crm_sales_details AS fs
LEFT JOIN gold.dim_products AS dp
ON fs.sls_prd_key = dp.product_number
LEFT JOIN gold.dim_customers AS dc
ON fs.sls_cust_id = dc.customer_id;
