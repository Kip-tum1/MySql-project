# DATA BANK CASE STUDY

## Background
Neo-Banks, or modern digital-only banks without physical branches, are a recent innovation in the financial sector.
Danny decided to start a new project because he believed that these modern banks, cryptocurrencies, and the data industry 
should all intersect in some way: **Data Bank**! Similar to other digital banks, Data Bank offers the most secure distributed
data storage platform in the world in addition to banking services. This case study examines how banking and node-allocation 
data can be used to address important business questions because customers are given cloud data storage limits that are 
directly correlated with the amount of money in their accounts. 

## Problem Statement
Danny founded Data Bank, a digital-only neo-bank where clients are given cloud data storage caps that are directly correlated with their bank account balances.

Danny has been dedicated to operating Data Bank with a data-driven mindset since its founding, with the goal of precisely predicting cloud data storage capacity and directing future platform scaling based on reliable data analysis rather than speculation.

Therefore, the task is to examine Data Bank's customer node and transaction data to provide answers to important business questions pertaining to:

* Distribution of customers among regional nodes and frequency of reallocation

* The way customers make purchases, withdrawals, and deposits
* End-of-month closing balances and monthly cash flow trends
* Over time, balance customer growth and retention
* Providing actionable insights that can guide Data Bank's cloud storage provisioning and product strategy

## SKILLS APPLIED
* Window Functions (`SUM() OVER`,)
* Derived Tables (Subqueries without `WITH` / CTEs)
* Conditional Aggregations (`CASE WHEN`)
* MySQL Date Functions (`LAST_DAY`, `MONTH`, `MONTHNAME`)
* Write scripts to generate basic reports that can be run every period

## Questions Explored (Customer Transactions)
1. What is the unique count and total amount for each transaction type?
2. What is the average total historical deposit counts and amounts for all customers?
3. For each month — how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
4. What is the closing balance for each customer at the end of the month?
5. What is the percentage of customers who increase their closing balance by more than 5%?

## Some interesting queries

**Q5. What is the percentage of customers who increase their closing balance by more than 5%?**
```sql
WITH monthly_changes AS (
    SELECT 
        customer_id,
        LAST_DAY(txn_date) AS month_end,
        SUM(CASE 
            WHEN txn_type = 'deposit' THEN txn_amount 
            ELSE -txn_amount 
        END) AS net_change
    FROM customer_transactions
    GROUP BY customer_id, month_end
),
running_balances AS (
    SELECT 
        customer_id,
        month_end,
        SUM(net_change) OVER (
            PARTITION BY customer_id 
            ORDER BY month_end
        ) AS closing_balance
    FROM monthly_changes
),
lagged_balances AS (
    SELECT 
        customer_id,
        month_end,
        closing_balance,
        LAG(closing_balance) OVER (
            PARTITION BY customer_id 
            ORDER BY month_end
        ) AS prev_balance
    FROM running_balances
)
SELECT 
    ROUND(
        100.0 * COUNT(DISTINCT customer_id) / 
        (SELECT COUNT(DISTINCT customer_id) FROM customer_transactions), 
    2) AS pct_customers_increased
FROM lagged_balances
WHERE prev_balance > 0 
  AND ((closing_balance - prev_balance) / prev_balance) > 0.05;
```

**Q4. What is the closing balance for each customer at the end of the month?**
```sql
WITH monthly_changes AS (
    SELECT 
        customer_id,
        LAST_DAY(txn_date) AS month_end,
        SUM(CASE 
            WHEN txn_type = 'deposit' THEN txn_amount 
            ELSE -txn_amount 
        END) AS net_change
    FROM customer_transactions
    GROUP BY customer_id, month_end
)
SELECT 
    customer_id,
    month_end,
    SUM(net_change) OVER (
        PARTITION BY customer_id 
        ORDER BY month_end
    ) AS closing_balance
FROM monthly_changes
ORDER BY customer_id, month_end;
```

**Q3. For each month — how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?**
```sql
SELECT 
    txn_month,
    month_name,
    COUNT(customer_id) AS customer_count
FROM (
    SELECT 
        MONTH(txn_date) AS txn_month,
        MONTHNAME(txn_date) AS month_name,
        customer_id,
        SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposit_cnt,
        SUM(CASE WHEN txn_type = 'purchase' THEN 1 ELSE 0 END) AS purchase_cnt,
        SUM(CASE WHEN txn_type = 'withdrawal' THEN 1 ELSE 0 END) AS withdrawal_cnt
    FROM data_bank.customer_transactions
    GROUP BY txn_month, month_name, customer_id
) AS monthly_activity
WHERE deposit_cnt > 1 
  AND (purchase_cnt >= 1 OR withdrawal_cnt >= 1)
GROUP BY txn_month, month_name
ORDER BY txn_month;
```

