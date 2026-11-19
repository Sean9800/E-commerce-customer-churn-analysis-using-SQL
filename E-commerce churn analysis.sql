/* =====================================================================
   E-COMMERCE CUSTOMER CHURN ANALYSIS (SQL)
   ---------------------------------------------------------------------
   Table: ecommerce_churn  (one row per customer)
   Columns: CustomerID, Churn (1 = churned, 0 = active), Tenure (months),
     PreferredLoginDevice, CityTier, WarehouseToHome, PreferredPaymentMode,
     Gender, HourSpendOnApp, NumberOfDeviceRegistered, PreferedOrderCat,
     SatisfactionScore (1-5), MaritalStatus, NumberOfAddress, Complain (0/1),
     OrderAmountHikeFromlastYear, CouponUsed, OrderCount,
     DaySinceLastOrder, CashbackAmount
   Written in portable SQL (tested on SQLite; runs on Postgres/MySQL 8+
   with minor tweaks noted inline).
   ===================================================================== */


/* ---------------------------------------------------------------------
   0. DATA QUALITY CHECKS
   --------------------------------------------------------------------- */

-- 0.1 Row count and duplicate customers
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT CustomerID) AS distinct_customers
FROM ecommerce_churn;

-- 0.2 Missing values in the columns we analyse
SELECT
    SUM(CASE WHEN Tenure              IS NULL THEN 1 ELSE 0 END) AS null_tenure,
    SUM(CASE WHEN OrderCount          IS NULL THEN 1 ELSE 0 END) AS null_order_count,
    SUM(CASE WHEN DaySinceLastOrder   IS NULL THEN 1 ELSE 0 END) AS null_days_since_order,
    SUM(CASE WHEN CouponUsed          IS NULL THEN 1 ELSE 0 END) AS null_coupon,
    SUM(CASE WHEN HourSpendOnApp      IS NULL THEN 1 ELSE 0 END) AS null_hours_on_app
FROM ecommerce_churn;

-- 0.3 Clean view: standardises payment-mode labels and builds reusable
--     buckets so every later query stays short and consistent.
DROP VIEW IF EXISTS churn_clean;
CREATE VIEW churn_clean AS
SELECT
    CustomerID,
    Churn,
    Tenure,
    CityTier,
    Gender,
    MaritalStatus,
    PreferredLoginDevice,
    PreferedOrderCat                              AS order_category,
    SatisfactionScore,
    Complain,
    CouponUsed,
    OrderCount,
    DaySinceLastOrder,
    CashbackAmount,
    HourSpendOnApp,
    NumberOfDeviceRegistered,
    NumberOfAddress,
    CASE
        WHEN PreferredPaymentMode IN ('CC')  THEN 'Credit Card'
        WHEN PreferredPaymentMode IN ('COD') THEN 'Cash on Delivery'
        ELSE PreferredPaymentMode
    END AS payment_mode,
    CASE
        WHEN Tenure IS NULL THEN 'Unknown'
        WHEN Tenure <= 3    THEN '1. 0-3 months'
        WHEN Tenure <= 12   THEN '2. 4-12 months'
        WHEN Tenure <= 24   THEN '3. 13-24 months'
        ELSE                     '4. 25+ months'
    END AS tenure_band,
    CASE
        WHEN DaySinceLastOrder IS NULL THEN 'Unknown'
        WHEN DaySinceLastOrder <= 3    THEN '1. 0-3 days'
        WHEN DaySinceLastOrder <= 7    THEN '2. 4-7 days'
        WHEN DaySinceLastOrder <= 14   THEN '3. 8-14 days'
        ELSE                                '4. 15+ days'
    END AS recency_band,
    CASE
        WHEN OrderCount IS NULL THEN 'Unknown'
        WHEN OrderCount <= 1    THEN '1. 1 order'
        WHEN OrderCount <= 3    THEN '2. 2-3 orders'
        WHEN OrderCount <= 8    THEN '3. 4-8 orders'
        ELSE                         '4. 9+ orders'
    END AS frequency_band
FROM ecommerce_churn;


/* ---------------------------------------------------------------------
   1. THE BIG PICTURE
   --------------------------------------------------------------------- */

-- 1.1 Overall churn rate
SELECT
    COUNT(*)                                   AS customers,
    SUM(Churn)                                 AS churned,
    ROUND(100.0 * SUM(Churn) / COUNT(*), 2)    AS churn_rate_pct
FROM churn_clean;

-- 1.2 Churned vs retained: how do their average behaviours differ?
SELECT
    CASE WHEN Churn = 1 THEN 'Churned' ELSE 'Retained' END AS status,
    COUNT(*)                          AS customers,
    ROUND(AVG(Tenure), 1)             AS avg_tenure_months,
    ROUND(AVG(OrderCount), 1)         AS avg_orders,
    ROUND(AVG(DaySinceLastOrder), 1)  AS avg_days_since_last_order,
    ROUND(AVG(SatisfactionScore), 2)  AS avg_satisfaction,
    ROUND(AVG(CouponUsed), 2)         AS avg_coupons_used,
    ROUND(AVG(CashbackAmount), 1)     AS avg_cashback,
    ROUND(100.0 * AVG(Complain), 1)   AS pct_complained
FROM churn_clean
GROUP BY Churn;


/* ---------------------------------------------------------------------
   2. CHURN DRIVERS, ONE FACTOR AT A TIME
   Pattern: group, count, churn rate, and "lift" vs. the overall rate.
   Lift > 1 means the segment churns MORE than average.
   --------------------------------------------------------------------- */

-- 2.1 Complaints
SELECT
    CASE WHEN Complain = 1 THEN 'Complained' ELSE 'No complaint' END AS segment,
    COUNT(*)                                                         AS customers,
    SUM(Churn)                                                       AS churned,
    ROUND(100.0 * SUM(Churn) / COUNT(*), 2)                          AS churn_rate_pct,
    ROUND( (1.0 * SUM(Churn) / COUNT(*))
         / (SELECT 1.0 * SUM(Churn) / COUNT(*) FROM churn_clean), 2) AS lift
FROM churn_clean
GROUP BY Complain
ORDER BY churn_rate_pct DESC;

-- 2.2 Satisfaction score
SELECT
    SatisfactionScore,
    COUNT(*)                                AS customers,
    SUM(Churn)                              AS churned,
    ROUND(100.0 * SUM(Churn) / COUNT(*), 2) AS churn_rate_pct
FROM churn_clean
GROUP BY SatisfactionScore
ORDER BY SatisfactionScore;

-- 2.3 Tenure (are new customers the problem?)
SELECT
    tenure_band,
    COUNT(*)                                AS customers,
    SUM(Churn)                              AS churned,
    ROUND(100.0 * SUM(Churn) / COUNT(*), 2) AS churn_rate_pct
FROM churn_clean
GROUP BY tenure_band
ORDER BY tenure_band;

-- 2.4 Days since last order (recency)
SELECT
    recency_band,
    COUNT(*)                                AS customers,
    SUM(Churn)                              AS churned,
    ROUND(100.0 * SUM(Churn) / COUNT(*), 2) AS churn_rate_pct
FROM churn_clean
GROUP BY recency_band
ORDER BY recency_band;

-- 2.5 Order frequency
SELECT
    frequency_band,
    COUNT(*)                                AS customers,
    SUM(Churn)                              AS churned,
    ROUND(100.0 * SUM(Churn) / COUNT(*), 2) AS churn_rate_pct
FROM churn_clean
GROUP BY frequency_band
ORDER BY frequency_band;

-- 2.6 Payment method
SELECT
    payment_mode,
    COUNT(*)                                AS customers,
    SUM(Churn)                              AS churned,
    ROUND(100.0 * SUM(Churn) / COUNT(*), 2) AS churn_rate_pct
FROM churn_clean
GROUP BY payment_mode
ORDER BY churn_rate_pct DESC;

-- 2.7 Coupon usage
SELECT
    CASE
        WHEN CouponUsed IS NULL THEN 'Unknown'
        WHEN CouponUsed = 0     THEN '0 coupons'
        WHEN CouponUsed <= 2    THEN '1-2 coupons'
        WHEN CouponUsed <= 5    THEN '3-5 coupons'
        ELSE                         '6+ coupons'
    END AS coupon_band,
    COUNT(*)                                AS customers,
    SUM(Churn)                              AS churned,
    ROUND(100.0 * SUM(Churn) / COUNT(*), 2) AS churn_rate_pct
FROM churn_clean
GROUP BY 1
ORDER BY churn_rate_pct DESC;

-- 2.8 Cashback received
SELECT
    CASE
        WHEN CashbackAmount < 150 THEN '1. < 150'
        WHEN CashbackAmount < 200 THEN '2. 150-199'
        WHEN CashbackAmount < 250 THEN '3. 200-249'
        ELSE                           '4. 250+'
    END AS cashback_band,
    COUNT(*)                                AS customers,
    ROUND(100.0 * SUM(Churn) / COUNT(*), 2) AS churn_rate_pct
FROM churn_clean
GROUP BY 1
ORDER BY 1;

-- 2.9 Device, city tier, order category, marital status
--     (one UNION ALL query keeps all the "profile" cuts in a single result)
SELECT 'Login device' AS dimension, PreferredLoginDevice AS segment,
       COUNT(*) AS customers, ROUND(100.0 * SUM(Churn) / COUNT(*), 2) AS churn_rate_pct
FROM churn_clean GROUP BY PreferredLoginDevice
UNION ALL
SELECT 'City tier', CAST(CityTier AS TEXT),
       COUNT(*), ROUND(100.0 * SUM(Churn) / COUNT(*), 2)
FROM churn_clean GROUP BY CityTier
UNION ALL
SELECT 'Order category', order_category,
       COUNT(*), ROUND(100.0 * SUM(Churn) / COUNT(*), 2)
FROM churn_clean GROUP BY order_category
UNION ALL
SELECT 'Marital status', MaritalStatus,
       COUNT(*), ROUND(100.0 * SUM(Churn) / COUNT(*), 2)
FROM churn_clean GROUP BY MaritalStatus
ORDER BY dimension, churn_rate_pct DESC;

-- 2.10 Ranking every driver: which single factor separates churners best?
--      (spread = highest segment churn rate minus lowest; larger = stronger driver)
WITH all_cuts AS (
    SELECT 'Complaint' AS driver,
           CAST(Complain AS TEXT) AS segment,
           100.0 * SUM(Churn) / COUNT(*) AS churn_rate
    FROM churn_clean GROUP BY Complain
    UNION ALL
    SELECT 'Satisfaction', CAST(SatisfactionScore AS TEXT), 100.0 * SUM(Churn) / COUNT(*)
    FROM churn_clean GROUP BY SatisfactionScore
    UNION ALL
    SELECT 'Tenure', tenure_band, 100.0 * SUM(Churn) / COUNT(*)
    FROM churn_clean GROUP BY tenure_band
    UNION ALL
    SELECT 'Recency', recency_band, 100.0 * SUM(Churn) / COUNT(*)
    FROM churn_clean GROUP BY recency_band
    UNION ALL
    SELECT 'Frequency', frequency_band, 100.0 * SUM(Churn) / COUNT(*)
    FROM churn_clean GROUP BY frequency_band
    UNION ALL
    SELECT 'Payment mode', payment_mode, 100.0 * SUM(Churn) / COUNT(*)
    FROM churn_clean GROUP BY payment_mode
)
SELECT driver,
       ROUND(MAX(churn_rate), 1) AS highest_segment_rate,
       ROUND(MIN(churn_rate), 1) AS lowest_segment_rate,
       ROUND(MAX(churn_rate) - MIN(churn_rate), 1) AS spread
FROM all_cuts
GROUP BY driver
ORDER BY spread DESC;


/* ---------------------------------------------------------------------
   3. COMBINED PATTERNS (where churn really concentrates)
   --------------------------------------------------------------------- */

-- 3.1 Complaint x satisfaction
SELECT
    CASE WHEN Complain = 1 THEN 'Complained' ELSE 'No complaint' END AS complaint,
    CASE WHEN SatisfactionScore <= 2 THEN 'Low (1-2)'
         WHEN SatisfactionScore = 3  THEN 'Medium (3)'
         ELSE                             'High (4-5)' END           AS satisfaction,
    COUNT(*)                                AS customers,
    ROUND(100.0 * SUM(Churn) / COUNT(*), 2) AS churn_rate_pct
FROM churn_clean
GROUP BY 1, 2
ORDER BY churn_rate_pct DESC;

-- 3.2 New customers with a complaint: an early-life warning
SELECT
    tenure_band,
    Complain,
    COUNT(*)                                AS customers,
    ROUND(100.0 * SUM(Churn) / COUNT(*), 2) AS churn_rate_pct
FROM churn_clean
GROUP BY tenure_band, Complain
ORDER BY tenure_band, Complain;

-- 3.3 Where do most churners come from? (share of all churn, not rate)
SELECT
    tenure_band,
    SUM(Churn) AS churned,
    ROUND(100.0 * SUM(Churn) / SUM(SUM(Churn)) OVER (), 1) AS pct_of_all_churn
FROM churn_clean
GROUP BY tenure_band
ORDER BY pct_of_all_churn DESC;


/* ---------------------------------------------------------------------
   4. CUSTOMER SEGMENTATION (RFM-STYLE RISK SCORE)
   Each risk flag adds 1 point; score 0-6.
   Flags come from the patterns found above; adjust thresholds to match
   what your own data shows in section 2.
   --------------------------------------------------------------------- */

DROP VIEW IF EXISTS customer_risk;
CREATE VIEW customer_risk AS
SELECT
    CustomerID,
    Churn,
    Tenure, OrderCount, DaySinceLastOrder, SatisfactionScore, Complain, payment_mode,
      (CASE WHEN Complain = 1                    THEN 1 ELSE 0 END)
    + (CASE WHEN SatisfactionScore <= 2          THEN 1 ELSE 0 END)
    + (CASE WHEN Tenure <= 3                     THEN 1 ELSE 0 END)
    + (CASE WHEN DaySinceLastOrder >= 8          THEN 1 ELSE 0 END)
    + (CASE WHEN OrderCount <= 2                 THEN 1 ELSE 0 END)
    + (CASE WHEN CouponUsed = 0                  THEN 1 ELSE 0 END)   AS risk_score
FROM churn_clean;

-- 4.1 Does the score work? Churn rate should climb with the score.
SELECT
    risk_score,
    COUNT(*)                                AS customers,
    SUM(Churn)                              AS churned,
    ROUND(100.0 * SUM(Churn) / COUNT(*), 2) AS churn_rate_pct
FROM customer_risk
GROUP BY risk_score
ORDER BY risk_score;

-- 4.2 Named segments for the business
SELECT
    CASE
        WHEN risk_score >= 4 THEN 'High risk'
        WHEN risk_score >= 2 THEN 'Medium risk'
        ELSE                      'Low risk'
    END AS segment,
    COUNT(*)                                AS customers,
    ROUND(100.0 * SUM(Churn) / COUNT(*), 2) AS actual_churn_rate_pct
FROM customer_risk
GROUP BY 1
ORDER BY actual_churn_rate_pct DESC;

-- 4.3 ACTION LIST: still-active customers who look like past churners.
--     This is the output the retention team would actually use.
SELECT
    CustomerID, risk_score, Tenure, OrderCount, DaySinceLastOrder,
    SatisfactionScore, Complain
FROM customer_risk
WHERE Churn = 0
  AND risk_score >= 4
ORDER BY risk_score DESC, DaySinceLastOrder DESC
LIMIT 50;   -- SQL Server: use SELECT TOP 50 instead


/* ---------------------------------------------------------------------
   5. RETENTION SIZING
   --------------------------------------------------------------------- */

-- 5.1 If we resolved complaints well enough to bring complaint-customers'
--     churn down to the non-complaint rate, how many customers would we keep?
WITH rates AS (
    SELECT
        SUM(CASE WHEN Complain = 1 THEN 1 ELSE 0 END)                AS complaint_customers,
        1.0 * SUM(CASE WHEN Complain = 1 THEN Churn ELSE 0 END)
            / SUM(CASE WHEN Complain = 1 THEN 1 ELSE 0 END)          AS complaint_churn_rate,
        1.0 * SUM(CASE WHEN Complain = 0 THEN Churn ELSE 0 END)
            / SUM(CASE WHEN Complain = 0 THEN 1 ELSE 0 END)          AS baseline_churn_rate
    FROM churn_clean
)
SELECT
    complaint_customers,
    ROUND(100 * complaint_churn_rate, 1) AS complaint_churn_pct,
    ROUND(100 * baseline_churn_rate, 1)  AS baseline_churn_pct,
    ROUND(complaint_customers * (complaint_churn_rate - baseline_churn_rate), 0)
        AS customers_saved_if_gap_closed
FROM rates;
