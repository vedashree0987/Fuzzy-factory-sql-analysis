-- =====================================================================
-- Maven Fuzzy Factory: E-commerce Channel, Conversion & Profitability Analysis
-- Database: fuzzy_factory (MySQL 8)
-- Run setup.sql first (tables, data, indexes, session_channel view).
-- Data range: 2012-03-19 to 2015-03-19. Trend queries exclude the partial
-- final month (Mar 2015). 2012 (Mar-Dec) and 2015 (Jan-Feb) are partial years.
-- =====================================================================

USE fuzzy_factory;

-- =====================================================================
-- PART 1: DATA VALIDATION
-- =====================================================================

-- V1: What period does the data cover?
SELECT MIN(created_at) AS first_session, MAX(created_at) AS last_session
FROM website_sessions;
-- FINDING: 2012-03-19 to 2015-03-19 (3 years). The last month is partial.

-- V2: Orders with no matching website session
SELECT COUNT(*) AS orders_without_session
FROM orders o
LEFT JOIN website_sessions s ON s.website_session_id = o.website_session_id
WHERE s.website_session_id IS NULL;
-- FINDING: 0

-- V3: Order items with no matching order
SELECT COUNT(*) AS items_without_order
FROM order_items i
LEFT JOIN orders o ON o.order_id = i.order_id
WHERE o.order_id IS NULL;
-- FINDING: 0

-- V4: Refunds with no matching order item
SELECT COUNT(*) AS refunds_without_item
FROM order_item_refunds r
LEFT JOIN order_items i ON i.order_item_id = r.order_item_id
WHERE i.order_item_id IS NULL;
-- FINDING: 0

-- V5: Does each order's price equal the sum of its line items?
SELECT COUNT(*) AS price_mismatches
FROM orders o
JOIN (SELECT order_id, SUM(price_usd) AS p FROM order_items GROUP BY order_id) i
  ON i.order_id = o.order_id
WHERE ROUND(o.price_usd, 2) <> ROUND(i.p, 2);
-- FINDING: 0 mismatches. All five tables reconcile with no orphan records.

-- =====================================================================
-- PART 2: ANALYSIS
-- =====================================================================

-- Q0: How big is the business overall?
SELECT
 (SELECT COUNT(*) FROM website_sessions) AS sessions,
 (SELECT COUNT(*) FROM orders) AS orders,
 (SELECT ROUND(SUM(price_usd)) FROM orders) AS revenue,
 (SELECT ROUND(SUM(price_usd - cogs_usd)) FROM orders) AS gross_margin,
 (SELECT ROUND(SUM(refund_amount_usd)) FROM order_item_refunds) AS refunded;
-- FINDING: 472,871 sessions produced 32,313 orders (6.8% conversion), $1.94M revenue
--   and a 62.7% gross margin ($1.22M). Refunds were $85K (4.4% of revenue).

-- Q1: How have traffic, conversion and revenue trended month over month?
WITH m AS (
  SELECT DATE_FORMAT(s.created_at, '%Y-%m-01') AS month,
         COUNT(*) AS sessions,
         COUNT(o.order_id) AS orders,
         SUM(o.price_usd) AS revenue
  FROM website_sessions s
  LEFT JOIN orders o ON o.website_session_id = s.website_session_id
  WHERE s.created_at < '2015-03-01'
  GROUP BY 1
)
SELECT month, sessions, orders,
       ROUND(100 * orders / sessions, 2) AS conv_rate_pct,
       ROUND(revenue) AS revenue,
       ROUND(revenue / sessions, 2) AS revenue_per_session,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1) AS mom_revenue_growth_pct
FROM m
ORDER BY month;
-- FINDING: Conversion climbed from 3.19% (Mar 2012) to 6.15% (Mar 2013) and revenue per
--   session nearly doubled ($1.60 to $3.18) in the first year. See Q1b for the yearly view.

-- Q1b: Yearly rollup of the same metrics
SELECT YEAR(s.created_at) AS yr,
       COUNT(*) AS sessions,
       COUNT(o.order_id) AS orders,
       ROUND(100 * COUNT(o.order_id) / COUNT(*), 2) AS conv_rate_pct,
       ROUND(SUM(o.price_usd)) AS revenue,
       ROUND(SUM(o.price_usd) / COUNT(*), 2) AS revenue_per_session
FROM website_sessions s
LEFT JOIN orders o ON o.website_session_id = s.website_session_id
WHERE s.created_at < '2015-03-01'
GROUP BY yr
ORDER BY yr;
-- FINDING: Conversion rose from 4.14% (2012) to 6.60% (2013), 7.22% (2014) and 8.48%
--   (Jan-Feb 2015); revenue per session grew from $2.07 to $3.49, $4.61 and $5.32.
--   Revenue rose ~2.7x from 2013 to 2014 ($393K to $1.08M) while sessions roughly
--   doubled, so growth came from both more traffic and better monetization.
-- NOTE: 2012 covers Mar-Dec and 2015 covers Jan-Feb only.

-- Q2: Which traffic channels convert and earn the most?
SELECT c.channel,
       COUNT(*) AS sessions,
       COUNT(o.order_id) AS orders,
       ROUND(100 * COUNT(o.order_id) / COUNT(*), 2) AS conv_rate_pct,
       ROUND(SUM(o.price_usd)) AS revenue,
       ROUND(SUM(o.price_usd) / COUNT(*), 2) AS revenue_per_session
FROM session_channel c
LEFT JOIN orders o ON o.website_session_id = c.website_session_id
WHERE c.created_at < '2015-03-01'
GROUP BY c.channel
ORDER BY revenue DESC;
-- FINDING: Paid nonbrand search drives ~72% of sessions and ~70% of revenue, but converts
--   below the other core channels (6.65% vs 7.15-7.78%). Paid social converts at 3.21% and
--   earns $2.08 per session, about half of every other channel.
-- RECOMMENDATION: Review paid social spend; protect brand and organic channels, which earn
--   the most per session. (The dataset has no ad-spend data, so ROI/CAC could not be
--   calculated.)

-- Q4: Do mobile and desktop visitors convert differently, and does it vary by channel?
SELECT c.channel, c.device_type,
       COUNT(*) AS sessions,
       ROUND(100 * COUNT(o.order_id) / COUNT(*), 2) AS conv_rate_pct,
       ROUND(SUM(o.price_usd) / COUNT(*), 2) AS revenue_per_session
FROM session_channel c
LEFT JOIN orders o ON o.website_session_id = c.website_session_id
WHERE c.created_at < '2015-03-01'
GROUP BY c.channel, c.device_type
ORDER BY c.channel, c.device_type;
-- FINDING: Desktop converts 2.5x-3.5x better than mobile in paid nonbrand, paid brand,
--   organic and direct traffic (paid nonbrand: 8.01% vs 3.17%; revenue per session $4.76 vs
--   $1.92), and about 6x better in paid social (4.99% vs 0.83%).
-- RECOMMENDATION: Shift nonbrand bids toward desktop and reduce mobile bids; audit the mobile
--   experience, since mobile is 28% of nonbrand traffic.

-- Q5: Which products make the most money, and at what margin?
SELECT p.product_name,
       COUNT(*) AS items_sold,
       ROUND(SUM(i.price_usd)) AS revenue,
       ROUND(SUM(i.price_usd - i.cogs_usd)) AS gross_margin,
       ROUND(100 * SUM(i.price_usd - i.cogs_usd) / SUM(i.price_usd), 1) AS margin_pct
FROM order_items i
JOIN products p ON p.product_id = i.product_id
GROUP BY p.product_name
ORDER BY revenue DESC;
-- FINDING: The Original Mr. Fuzzy generates 62.5% of revenue, but the newer Birthday Sugar
--   Panda and Hudson River Mini earn higher margins (~68% vs 61%).
-- RECOMMENDATION: Promote higher-margin products through cross-sell and homepage placement.
-- NOTE: Products launched at different dates (2012, 2013, Dec 2013, Feb 2014), so volumes
--   are not directly comparable.

-- Q6: Which products get returned most?
SELECT p.product_name,
       COUNT(i.order_item_id) AS items_sold,
       COUNT(r.order_item_refund_id) AS refunds,
       ROUND(100 * COUNT(r.order_item_refund_id) / COUNT(i.order_item_id), 2) AS refund_rate_pct,
       ROUND(SUM(r.refund_amount_usd)) AS refunded_usd
FROM order_items i
JOIN products p ON p.product_id = i.product_id
LEFT JOIN order_item_refunds r ON r.order_item_id = i.order_item_id
GROUP BY p.product_name
ORDER BY refund_rate_pct DESC;
-- FINDING: The Birthday Sugar Panda has the highest refund rate (6.04%) and the Hudson River
--   Mini the lowest (1.28%). Mr. Fuzzy accounts for ~72% of refunded dollars due to volume.
-- RECOMMENDATION: Investigate Panda quality and product-page expectations.

-- Q7: Did any product's refund rate change sharply over time? (root cause)
SELECT CONCAT(YEAR(i.created_at), '-Q', QUARTER(i.created_at)) AS yr_qtr,
       p.product_name,
       COUNT(i.order_item_id) AS items_sold,
       COUNT(r.order_item_refund_id) AS refunds,
       ROUND(100 * COUNT(r.order_item_refund_id) / COUNT(i.order_item_id), 1) AS refund_rate_pct
FROM order_items i
JOIN products p ON p.product_id = i.product_id
LEFT JOIN order_item_refunds r ON r.order_item_id = i.order_item_id
GROUP BY yr_qtr, p.product_name
ORDER BY p.product_name, yr_qtr;
-- FINDING: The Birthday Sugar Panda's refund rate was steady (5.6-7.2% per quarter), while
--   The Original Mr. Fuzzy spiked to 10.6% in 2014-Q3 (vs 3.3-4.0% in adjacent quarters).
--   See Q7b for the month-level breakdown.

-- Q7b: Which months drove the Mr. Fuzzy refund spike?
SELECT DATE_FORMAT(i.created_at, '%Y-%m') AS month,
       COUNT(i.order_item_id) AS items_sold,
       COUNT(r.order_item_refund_id) AS refunds,
       ROUND(100 * COUNT(r.order_item_refund_id) / COUNT(i.order_item_id), 1) AS refund_rate_pct
FROM order_items i
LEFT JOIN order_item_refunds r ON r.order_item_id = i.order_item_id
WHERE i.product_id = 1
  AND i.created_at >= '2014-06-01' AND i.created_at < '2014-11-01'
GROUP BY month
ORDER BY month;
-- FINDING: The Original Mr. Fuzzy's refund rate spiked to 13.8% in Aug 2014 and 13.3% in
--   Sep 2014 (272 refunds on 2,014 items), versus ~4% in Jun, Jul and Oct combined. That is
--   ~190 excess refunds (~$9.5K at the ~$50 average refund). The rate fell to 2.5% in Oct 2014.
-- RECOMMENDATION: Investigate what changed in Aug-Sep 2014 (product batch, supplier,
--   shipping) and add a monthly refund-rate alert.
-- NOTE: Refunds are grouped by purchase date, not refund date, and the dataset has no data
--   on the cause.