-- 1. What is the unique count and total amount for each transaction type?

SELECT COUNT(DISTINCT txn_type)
FROM data_bank.customer_transactions;

-- 2. What is the average total historical deposit counts and amounts for all customers?
SELECT 
    ROUND(AVG(deposit_count), 2) AS avg_deposit_count,
    ROUND(AVG(total_deposit), 2) AS avg_deposit_amount
FROM (
    SELECT 
        customer_id,
        COUNT(*) AS deposit_count,
        SUM(txn_amount) AS total_deposit
    FROM data_bank.customer_transactions
    WHERE txn_type = 'deposit'
    GROUP BY customer_id
) AS customer_deposits;

-- 3 For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?

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

-- 4 What is the closing balance for each customer at the end of the month?
WITH monthly_changes AS (
    SELECT 
        customer_id,
        LAST_DAY(txn_date) AS month_end,
        SUM(CASE 
            WHEN txn_type = 'deposit' THEN txn_amount 
            ELSE -txn_amount 
        END) AS net_change
    FROM data_bank.customer_transactions
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

-- 5 What is the percentage of customers who increase their closing balance by more than 5%?

SELECT 
    ROUND(
        100.0 * COUNT(DISTINCT customer_id) / 
        (SELECT COUNT(DISTINCT customer_id) FROM data_bank.customer_transactions), 
    2) AS pct_customers_increased
FROM (
    SELECT 
        customer_id,
        month_end,
        closing_balance,
        LAG(closing_balance) OVER (
            PARTITION BY customer_id 
            ORDER BY month_end
        ) AS prev_balance
    FROM (
        SELECT 
            customer_id,
            LAST_DAY(txn_date) AS month_end,
            SUM(SUM(CASE 
                WHEN txn_type = 'deposit' THEN txn_amount 
                ELSE -txn_amount 
            END)) OVER (
                PARTITION BY customer_id 
                ORDER BY LAST_DAY(txn_date)
            ) AS closing_balance
        FROM data_bank.customer_transactions
        GROUP BY customer_id, LAST_DAY(txn_date)
    ) AS running_balances
) AS lagged_balances
WHERE prev_balance > 0 
  AND ((closing_balance - prev_balance) / prev_balance) > 0.05;



