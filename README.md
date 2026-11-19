# E-commerce-customer-churn-analysis-using-SQL
# 🛒 E-Commerce Customer Churn Analysis Using SQL

## 📌 Project Overview
Customer retention is one of the most critical drivers of profitability in online retail. Unlike subscription businesses with explicit cancellation events, e-commerce platforms must infer churn through purchasing behavior and inactivity windows. 

This project uses **SQL** to clean raw transactional and customer data, define and calculate churn rates, uncover key operational drivers behind customer attrition, and build a proactive **RFM (Recency, Frequency, Monetary)** segmentation model to flag at-risk high-value shoppers.

---

## 🎯 Business Objectives
1. **Ensure Data Integrity:** Audit customer and order tables for duplicates, missing timestamps, and null transaction amounts.
2. **Quantify Churn:** Establish a 90-day inactivity threshold to calculate baseline customer churn rates.
3. **Identify Root Causes:** Segment churned vs. retained customers across complaints, satisfaction scores, payment methods, tenure, and app engagement.
4. **Proactive Retention:** Score active customers using SQL window functions (`NTILE`) to isolate "At-Risk High Value" accounts before they churn.

---

## 🗂️ Dataset Schema
The queries in this repository are designed to work across standard relational e-commerce tables (`customers`, `orders`, and `ecommerce_churn`):

| Column | Type | Description |
| :--- | :--- | :--- |
| `customer_id` | VARCHAR / INT | Unique identifier for each customer |
| `order_id` | VARCHAR / INT | Unique identifier for each transaction |
| `order_date` | DATE | Date the order was placed |
| `total_amount` | DECIMAL | Total monetary value of the order |
| `tenure` | INT | Number of months the customer has been with the platform |
| `preferred_payment_mode` | VARCHAR | Primary checkout method (e.g., Credit Card, UPI, COD) |
| `hour_spend_on_app` | FLOAT | Average hours spent on the mobile app/website |
| `warehouse_to_home` | INT | Distance between fulfillment center and customer address |
| `satisfaction_score` | INT | Customer survey rating (1–5) |
| `complain` | INT | Binary flag indicating if a complaint was logged (`1` = Yes, `0` = No) |
| `churn` | INT | Target churn flag (`1` = Churned, `0` = Retained) |

---

## 🔍 SQL Methodology & Key Queries

### 1. Data Cleaning & Validation
* **Duplicate Detection:** Uses `GROUP BY` and `HAVING COUNT(*) > 1` to ensure unique customer records.
* **Null Auditing:** Uses conditional aggregation (`SUM(CASE WHEN ... IS NULL)`) to verify completeness across order dates and revenue fields.

### 2. Churn Definition & Rate Calculation
* Uses Common Table Expressions (**CTEs**) and `DATEDIFF` to calculate days elapsed since each customer's final purchase relative to the dataset's maximum date.
* Flags users with `> 90 days` of inactivity (or zero orders) as churned and computes the overall churn percentage.

### 3. Churn Driver Segmentation
* **Complaints & Satisfaction:** Measures how unresolved friction impacts attrition rates.
* **Checkout & Logistics:** Evaluates churn across `preferred_payment_mode` and average `warehouse_to_home` delivery distances.
* **Engagement:** Contrasts average `tenure` and `hour_spend_on_app` between retained and lost cohorts.

### 4. RFM Customer Risk Scoring
* Calculates raw **Recency** (days since last order), **Frequency** (distinct order count), and **Monetary** (total spend) metrics.
* Applies `NTILE(4)` window functions to bucket customers into quartiles and classify actionable segments:
  * **Loyal Champions:** High recency, high frequency, high spend.
  * **At-Risk High Value:** Historically high spend and frequency, but slipping recency (prime targets for win-back campaigns).
  * **Needs Attention:** Moderate engagement requiring targeted nurturing.
  * **Churned / Lost:** Low recency and low historical frequency.

---

## 🛠️ Tools & SQL Features Used
* **SQL Dialect:** Compatible with PostgreSQL, T-SQL (SQL Server), and Snowflake *(minor syntax adjustments may be needed for `DATEDIFF` in MySQL/SQLite)*.
* **Key Techniques:** Common Table Expressions (CTEs), Window Functions (`NTILE`), Conditional Aggregation (`CASE WHEN`), `LEFT JOIN`, and Date Arithmetic.

---

## 🚀 How to Use
1. Clone this repository:
   ```bash
   git clone https://github.com
   ```
2. Load your e-commerce dataset into your preferred SQL database environment.
3. Run the scripts in sequential order:
   * `01_data_cleaning.sql`
   * `02_churn_rate_calculation.sql`
   * `03_churn_drivers.sql`
   * `04_rfm_segmentation.sql`

---

## 📈 Next Steps & Recommendations
* **BI Dashboarding:** Connect the output views from `03_churn_drivers.sql` and `04_rfm_segmentation.sql` to **Power BI** or **Tableau** to monitor weekly churn cohorts.
* **Automated Win-Back Triggers:** Integrate the `At-Risk High Value` RFM segment with CRM email/SMS workflows to deploy targeted discount codes at the 60-day inactivity mark.

