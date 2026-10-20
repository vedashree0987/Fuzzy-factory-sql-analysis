# Fuzzy-factory-sql-analysis

# E-commerce Channel, Conversion & Profitability Analysis (MySQL)

SQL analysis of 3 years of data from an online toy retailer (Maven Fuzzy Factory) to
understand growth, marketing channel performance, device conversion, product
profitability, and refunds.

## Dataset
[Maven Analytics Toy Store E-Commerce Database](https://mavenanalytics.io/data-playground)
(public domain): 472,871 website sessions, 32,313 orders, 40,025 order items,
1,731 refunds, 4 products (Mar 2012 - Mar 2015). The pageviews table was not used.

## Tools and techniques
MySQL 8: joins, CTEs, window functions (LAG), subqueries, views, indexing, data validation

## Data validation
- No orphan records: every order links to a session, every item to an order, every refund to an item
- Order totals reconcile exactly with the sum of their line items (0 mismatches)
- Trend queries exclude the partial final month (Mar 2015); 2012 (Mar-Dec) and 2015 (Jan-Feb) are partial years

## Key findings
1. **Business size:** $1.94M revenue, 6.8% overall conversion, 62.7% gross margin; refunds were 4.4% of revenue.
2. **Growth:** conversion rose from 4.14% (2012) to 7.22% (2014); revenue per session from $2.07 to $4.61. Revenue grew ~2.7x from 2013 to 2014 while sessions roughly doubled.
3. **Channels:** paid nonbrand search drives ~72% of sessions and ~70% of revenue but converts below brand, organic and direct (6.65% vs 7.15-7.78%). Paid social converts at 3.21% and earns about half the revenue per session of other channels.
4. **Device gap:** desktop converts 2.5x-3.5x better than mobile in four channels (paid nonbrand: 8.01% vs 3.17%) and ~6x better in paid social.
5. **Products:** The Original Mr. Fuzzy earns 62.5% of revenue; the newer products have higher margins (~68% vs 61%).
6. **Refund spike:** Mr. Fuzzy's refund rate jumped to ~13.5% in Aug-Sep 2014 (vs ~4% in adjacent months), about 190 excess refunds (~$9.5K), then fell to 2.5% in October.

## Recommendations
1. Shift paid nonbrand bids toward desktop and audit the mobile experience.
2. Review paid social spend, which converts at about half the rate of other channels.
3. Promote higher-margin products through cross-sell.
4. Investigate the Aug-Sep 2014 refund spike (batch, supplier, shipping) and add a monthly refund-rate alert.

## Limitations
The dataset has no ad-spend data, so ROI and customer acquisition cost could not be calculated. Refunds are grouped by purchase date, not refund date. Findings show associations, not proven causes.

## Files
- `setup.sql`: creates the tables, loads the CSVs, adds indexes and the `session_channel` view
- `analysis.sql`: validation checks and analysis queries, each with a business question, finding, and recommendation

## How to run
1. Download the dataset from Maven Analytics
2. Run `setup.sql` (update the CSV file paths for your machine; requires MySQL 8 with `local_infile` enabled)
3. Run `analysis.sql`
