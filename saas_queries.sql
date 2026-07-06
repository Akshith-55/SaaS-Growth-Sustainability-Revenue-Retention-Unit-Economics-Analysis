-- I) Revenue Analytics 

-- 1) What is the total MRR and ARR for each month across all active subscriptions?
SELECT 
    DATE_FORMAT('month', start_date) AS month,
    SUM(mrr_amount) AS total_mrr
FROM
    subscriptions
WHERE
    churn_flag = FALSE AND is_trial = FALSE
GROUP BY month
ORDER BY total_mrr;

-- 2) What is the ARPU (Average Revenue Per User) broken down by plan tier?
SELECT 
    DATE_FORMAT(start_date, '%Y-%m-%1') AS month,
    SUM(mrr) AS total_mrr
FROM
    subscriptions
WHERE
    churn_falg = FALSE AND is_trial = FALSE
GROUP BY month
ORDER BY total_mr;

-- 3) What is the MRR breakdown by industry vertical?
SELECT 
    a.industry,
    COUNT(DISTINCT s.account_id) AS total_subscriptions,
    SUM(s.mrr_amount) AS total_mrr,
    ROUND(AVG(s.mrr_amount), 2) AS avg_mrr_per_subscription,
    ROUND(SUM(s.mrr_amount) / SUM(SUM(s.mrr_amount)) * 100,
            2) AS mrr_percentage
FROM
    subscriptions s
        JOIN
    accounts a ON s.account_id = a.account_id
GROUP BY 1
ORDER BY total_mrr;
-- 4) How much revenue comes from monthly billing vs annual billing customers?
SELECT 
    billing_frequency, SUM(mrr_amount) AS revenue
FROM
    subscriptions
WHERE
    churn_flag = FALSE AND is_trial = FALSE
GROUP BY billing_frequency
ORDER BY revenue DESC;
-- 5) What is the MRR growth rate month over month?
WITH monthly_mrr AS
(
	SELECT   date_format(start_date, '%Y-%m-01') AS month,
	sum(mrr_month) AS total_mrr
	FROM     subscriptions
	WHERE    churn_flag = FALSE
	AND      is_trial = flase
    GROUP BY date_format(start_date, '%Y-%m-01') )
SELECT month,total_mrr
FROM   monthly_mrr;


WITH monthly_mrr AS
(
	SELECT date_format(start_date, '%Y-%m-01') AS month,
	sum(mrr_amount) AS total_mrr
	FROM subscriptions
	WHERE churn_flag = FALSE
	AND is_trial = FALSE
	GROUP BY date_format(start_date, '%Y-%m-01') 
),
mrr_with_lag AS
(
	SELECT   month, total_mrr,
    lag (total_mrr) over ( ORDER BY month) AS prev_month_mrr
	FROM  monthly_mrr )
SELECT   month, 
total_mrr,
prev_month,
round((total_mrr - prev_month_mrr) / nullif(prev_month_mrr) * 100, 2) AS mrr_growth_rate
FROM mrr_with_lag
ORDER BY month;
-- 6) What percentage of total MRR comes from Enterprise vs Pro vs Basic plans?
SELECT   a.plan_tier, sum(s.mrr_amount) AS total_mrr,
round(sum(s.mrr_amount) /(SELECT sum(mrr_amount)
FROM subscriptions
WHERE churn_flag = FALSE
AND is_trial = FALSE) * 100, 2) AS mrr_percentage
FROM subscriptions s
JOIN accounts a
ON s.account_id = a.account_id
WHERE s.churn_flag = FALSE
AND s.is_trial = FALSE
GROUP BY plan_tier
ORDER BY mrr_percentage;
 -- 5) What is the ARR growth rate YOY?
WITH arr_year AS
(
	SELECT date_format(start_date, '%Y-01-01') AS year,
	sum(arr_amount) AS total_arr
	FROM subscriptions
	WHERE churn_flag=FALSE
	AND is_trial = FALSE
	GROUP BY date_format(start_date, '%Y-01-01')
),
lag_arr AS
(
	SELECT total_arr, year,
	lag(total_arr) over(ORDER BY year) AS prev_year_arr
	FROM  arr_year )
SELECT year, total_arr, prev_year_arr,
 round((total_arr) - prev_year_arr / (prev_year_arr) *100, 2) AS yearly_growth_rate
FROM lag_arr
ORDER BY year;

-- II) Chrun Analysis
-- 7)What is the overall churn rate across all accounts?
WITH churn_summary AS
(
	SELECT count(DISTINCT account_id) AS total_customers,
	sum(
		CASE WHEN churn_flag = TRUE THEN 1 ELSE 0 end) AS churned_customers
		FROM   subscriptions 
)
SELECT total_customers, churned_customers,
		(total_customers - churned_customers) AS active_accounts,
		round((churned_customers) / (total_customers) *100, 2) AS churn_rate
  FROM   churn_summary;
-- Churn summary and retentiom percentage
  WITH churn_summary AS
(
	SELECT count(DISTINCT account_id) AS total_accounts,
	sum(
		CASE WHEN churn_flag = 'TRUE' THEN 1 ELSE 0 end) AS churned_accounts
FROM   subscriptions 
)
SELECT total_accounts, churned_accounts,
	(total_accounts - churned_accounts) AS active_accounts,
	round((churned_accounts / nullif(total_accounts, 0)) * 100, 2) AS churn_rate_percentage,
	round(((total_accounts - churned_accounts) / nullif(total_accounts, 0)) * 100, 2) AS retention_rate_percentage
FROM   churn_summary;
-- 8 ) churn by plan tier
  WITH churn_by_tier AS
(
	SELECT   plan_tier,
	count(DISTINCT account_id) AS total_customers,
	sum(CASE WHEN churn_flag = 'TRUE' THEN 1 ELSE 0 end) AS churned_customers
	FROM accounts
	GROUP BY plan_tier 
    )
SELECT   plan_tier, total_customers, churned_customers, 
round((churned_customers) / (total_customers) *100, 2) AS churn_rate
FROM churn_by_tier
ORDER BY churn_rate;
-- 	9) churn by industry vertical
WITH industry_churn AS
(
	SELECT industry,
	count(DISTINCT account_id) AS total_customers,
	sum( CASE WHEN churn_flag = 'TRUE' THEN 1 ELSE 0 end) AS churned_customers
	FROM  accounts
	GROUP BY industry 
)
  SELECT  industry, total_customers, churned_customers,
	round((churned_customers) / (total_customers) *100, 2) AS churn_rate
  FROM  industry_churn
  ORDER BY churn_rate ;
-- 10) What are the top 3 churn reason codes and what percentage of churns does each represent?
WITH churn_reason AS
(
	SELECT c.reason_code,
	count(DISTINCT a.account_id) AS total_customers,
	sum(CASE WHEN a.churn_flag = 'TRUE' THEN 1 ELSE 0 end) AS churn_count
	FROM accounts a
	JOIN churn_events c
	ON  a.account_id = c.account_id
	GROUP BY c.reason_code
)
  SELECT reason_code, total_customers, churn_count,
  round((churn_count) / (total_customers)*100, 2) AS churn_percentage
  FROM churn_reason
  ORDER BY churn_percentage DESC
  LIMIT 3;
-- 11) What is the average subscription lifetime (in days) before churn for each plan tier?
 WITH churn_plan_tier AS
(
SELECT a.plan_tier, s.account_id, s.start_date, s.end_date,
CASE WHEN s.end_date IS NOT NULL THEN datediff(s.end_date, s.start_date) ELSE datediff(curdate(), s.start_date) end AS lifetime_days
FROM  subscriptions s
JOIN accounts a
ON s.account_id = a.account_id
WHERE  s.churn_flag = 'TRUE' )
SELECT plan_tier,
count(DISTINCT account_id)  AS churned_customers,
round(avg(lifetime_days),2) AS avg_lifetime_days,
min(lifetime_days) AS minimum_lifetime,
max(lifetime_days) AS maximum_lifetime
FROM churn_plan_tier
GROUP BY plan_tier;
-- 13) What is the churn rate by referral source (organic vs ads vs partner)?
-- 14) What percentage of churned accounts were reactivations (churned more than once)?
WITH churn_reactivations AS
(
 SELECT count(DISTINCT account_id) AS churned_accounts,
sum( CASE WHEN is_reactivation = 'TRUE' THEN 1 ELSE 0 end) AS reactived_accounts
FROM churn_events 
)
SELECT churned_accounts, reactived_accounts, 
(churned_accounts - reactived_accounts) AS firsttime_churn,
round((reactived_accounts) / (churned_accounts) *100, 2) AS reactive_percentage
FROM   churn_reactivations;
-- 15) What is the average refund amount for each churn reason code?
  SELECT   reason_code,
                 round(avg(refund_amount_usd), 2) AS average_refund_amount
        FROM     churn_events
        GROUP BY reason_code;
        
-- III) Cohort Analysis

-- 16) For each monthly signup cohort, what percentage of accounts are still active after 1, 3, 6, and 12 months?
WITH cohort_month AS
             (
                    SELECT account_id,
                           date_format(signup_date, '%Y-%m-01') AS month,
                           signup_date
                    FROM   accounts ),
             cohort_activity AS
             (
                    SELECT cm.account_id,
                           cm.month,
                           cm.signup_date,
                           s.churn_flag,
                           CASE
                                  WHEN churn_flag = 'FALSE' THEN 1 
                                  WHEN  churn_flag = 'TRUE' AND datediff(s.end_date, cm.signup_date) > 30 THEN 1
                                  ELSE 0
                           end AS active_at_1_month,
                           CASE
                                  WHEN churn_flag = 'FALSE' THEN 1 
                                  WHEN churn_flag = 'TRUE' 
                                  and datediff(s.end_date, cm.signup_date) > 90 THEN 1
                                  ELSE 0
                           end AS active_at_3_months,
                           CASE
                                  WHEN churn_flag = 'FALSE' THEN 1 
                                  WHEN churn_flag = 'TRUE' and	datediff(s.end_date, cm.signup_date) > 180 THEN 1
                                  ELSE 0
                           end AS active_at_6_months,
                           CASE
                                  WHEN churn_flag = 'FALSE' THEN 1
                                  WHEN churn_flag = 'TRUE' and datediff(s.end_date, cm.signup_date) > 365 THEN 1
                                  ELSE 0
                           end AS active_at_12_months
                    FROM   cohort_month cm
                    JOIN   subscriptions s
                    ON     cm.account_id = s.account_id ),
             cohort_summary AS
             (
                      SELECT   count(DISTINCT account_id) AS cohort_size,
                               month,
                               sum(active_at_1_month)   AS act_active_after_1_month,
                               sum(active_at_3_months)  AS act_active_after_3_months,
                               sum(active_at_6_months)  AS act_active_after_6_months,
                               sum(active_at_12_months) AS act_active_after_12_months
                      FROM     cohort_activity
                      GROUP BY month )
    SELECT   month,
             cohort_size,
             act_active_after_1_month,
             act_active_after_3_months,
             act_active_after_6_months,
             act_active_after_12_months,
             round((act_active_after_1_month)   / (cohort_size), 2) AS active_1month_percentage,
             round((act_active_after_3_months)  / (cohort_size), 2) AS active_3month_percentage,
             round((act_active_after_6_months)  / (cohort_size), 2) AS active_6month_percentage,
             round((act_active_after_12_months) / (cohort_size), 2) AS active_12month_percentage
    FROM     cohort_summary
    GROUP BY month;
    
    
-- correct version
WITH cohort_month AS (
    SELECT account_id,
           date_format(signup_date, '%Y-%m-01') AS month,
           signup_date
    FROM accounts
),
latest_subscription AS (
    SELECT account_id,
           churn_flag,
           end_date,
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY end_date DESC) AS rn
    FROM subscriptions
),
cohort_activity AS (
    SELECT cm.account_id,
           cm.month,
           cm.signup_date,
           ls.churn_flag,
           CASE
               WHEN ls.churn_flag = 'FALSE' THEN 1 
               WHEN ls.churn_flag = 'TRUE' AND datediff(ls.end_date, cm.signup_date) > 30 THEN 1
               ELSE 0
           END AS active_at_1_month,
           CASE
               WHEN ls.churn_flag = 'FALSE' THEN 1 
               WHEN ls.churn_flag = 'TRUE' AND datediff(ls.end_date, cm.signup_date) > 90 THEN 1
               ELSE 0
           END AS active_at_3_months,
           CASE
               WHEN ls.churn_flag = 'FALSE' THEN 1 
               WHEN ls.churn_flag = 'TRUE' AND datediff(ls.end_date, cm.signup_date) > 180 THEN 1
               ELSE 0
           END AS active_at_6_months,
           CASE
               WHEN ls.churn_flag = 'FALSE' THEN 1
               WHEN ls.churn_flag = 'TRUE' AND datediff(ls.end_date, cm.signup_date) > 365 THEN 1
               ELSE 0
           END AS active_at_12_months
    FROM cohort_month cm
    JOIN latest_subscription ls ON cm.account_id = ls.account_id AND ls.rn = 1
),
cohort_summary AS (
    SELECT COUNT(DISTINCT account_id) AS cohort_size,
           month,
           SUM(active_at_1_month) AS act_active_after_1_month,
           SUM(active_at_3_months) AS act_active_after_3_months,
           SUM(active_at_6_months) AS act_active_after_6_months,
           SUM(active_at_12_months) AS act_active_after_12_months
    FROM cohort_activity
    GROUP BY month
)
SELECT month,
       cohort_size,
       act_active_after_1_month,
       act_active_after_3_months,
       act_active_after_6_months,
       act_active_after_12_months,
       ROUND((act_active_after_1_month) / (cohort_size), 2) AS active_1month_percentage,
       ROUND((act_active_after_3_months) / (cohort_size), 2) AS active_3month_percentage,
       ROUND((act_active_after_6_months) / (cohort_size), 2) AS active_6month_percentage,
       ROUND((act_active_after_12_months) / (cohort_size), 2) AS active_12month_percentage
FROM cohort_summary
GROUP BY month;
-- 17) For trial accounts, what percentage convert to paid plans and how does this vary by plan tier?

WITH base_cte AS
(
	SELECT   a.plan_tier,
    count(a.account_id) AS total_accounts,
    sum( CASE WHEN a.is_trial = 'TRUE' THEN 1 ELSE 0 end) AS trail_acc_count,
	sum( CASE WHEN a.is_trial = 'FALSE' THEN 1 ELSE 0 end) AS converted_accounts
	FROM accounts a 
	GROUP BY a.plan_tier 
)
SELECT total_accounts, plan_tier, trail_acc_count, converted_accounts,
round((converted_accounts) / (total_accounts), 2) AS conversion_percentage
FROM base_cte
ORDER BY conversion_percentage;

-- IV) Segmentation Analysis
-- Segment accounts into SMB (1-50 seats), Mid-Market (51-200 seats), and Enterprise (200+ seats) — what is the MRR contribution of each segment?
WITH segment_acc AS
(
SELECT a.account_id,
 s.mrr_amount,
 CASE WHEN s.seats BETWEEN 1 AND    25 THEN 'SMB'
      WHEN s.seats BETWEEN 26 AND    100 THEN 'MidMarket'
      ELSE 'Enterprise'
     end AS segmentation
FROM subscriptions s
JOIN accounts a
ON  a.account_id = s.account_id 
)
SELECT segmentation,
sum(mrr_amount) AS total_mrr
FROM segment_acc
GROUP BY segmentation;
-- Which segment has the highest churn rate?

WITH segment_churn AS
(
 SELECT churn_flag, account_id,
sum( CASE WHEN churn_flag = 'TRUE' THEN 1 ELSE 0 end) AS churned,
CASE
    WHEN seats BETWEEN 1 AND 25 THEN 'SMB'
    WHEN seats BETWEEN 26 AND 100 THEN 'MidMarket'
    ELSE 'Enterprise'
	end AS segmentation
	FROM subscriptions
	GROUP BY segmentation )
	SELECT segmentation,
	count(account_id) AS total_customers,
	round((churned) / (total_customers) * 100, 2) AS churn_rate
	FROM  segment_churn
	GROUP BY segmentation
	ORDER BY churn_rate;
-- Which segment has the highest average satisfaction score from support tickets?
WITH segmentation AS
(
   SELECT st.satisfaction_score,
   CASE WHEN s.seats BETWEEN 1 AND 25 THEN 'SMB'
		WHEN s.seats BETWEEN 26 AND 100 THEN 'MidMarket'
		ELSE 'Enterprise'
		end AS segmented
		FROM subscriptions s
		JOIN support_tickets st
		ON s.account_id = st.account_id
)
SELECT segmented,
avg(satisfaction_score) AS avg_satisfaction_score
FROM  segmentation
GROUP BY segmented
ORDER BY avg_satisfaction_score; 
-- What is the upgrade vs downgrade rate for each segment?
WITH segment AS
(
	SELECT a.account_id,
	s.upgrade_flag,
    s.downgrade_flag,
	CASE
		WHEN s.seats BETWEEN 1 AND    25 THEN 'SMB'
        WHEN s.seats BETWEEN 26 AND    100 THEN 'MidMarket'
		ELSE 'Enterprise'
		end AS segmented
		FROM subscriptions s
		JOIN accounts a
		ON s.account_id = a.account_id 
),
grade_segmentation AS
(
   SELECT segmented,
   count(DISTINCT account_id) AS total_customers,
	sum( CASE WHEN upgrade_flag = 'TRUE' THEN 1 ELSE 0 end) AS upgrade_flag_count,
	sum( CASE WHEN downgrade_flag = 'FALSE' THEN 1 ELSE 0 end) AS downgrade_flag_count
	FROM segment
	GROUP BY segmented )
	SELECT segmented,
	round((upgrade_flag_count) /(total_customers), 2) AS upgrade_flag_rate,
	round((downgrade_flag_count) /(total_customers), 2) AS downgrade_flag_rate
	FROM  grade_segmentation;
-- Which industry vertical has the highest concentration of Enterprise accounts?

-- V) Customer health scoring
-- Which features are used most by accounts that never churned vs accounts that did churn?

SELECT f.feature_name,
    ROUND(AVG(CASE WHEN a.churn_flag = 'FALSE' THEN f.usage_count ELSE NULL END), 2) AS avg_retained_usage,
    ROUND(AVG(CASE WHEN a.churn_flag = 'TRUE' THEN f.usage_count ELSE NULL END), 2) AS avg_churned_usage,
    ROUND(AVG(CASE WHEN a.churn_flag = 'FALSE' THEN f.usage_count ELSE NULL END) - 
          AVG(CASE WHEN a.churn_flag = 'TRUE' THEN f.usage_count ELSE NULL END), 2) AS usage_delta
FROM feature_usage f
JOIN subscriptions s on f.subscription_id  = s.subscription_id
join 
accounts a ON s.account_id = a.account_id
GROUP BY 1
ORDER BY usage_delta DESC;
-- What is the average support ticket satisfaction score for churned vs retained accounts?
SELECT 
    a.churn_flag,
    COUNT(DISTINCT a.account_id) AS total_accounts,
    ROUND(AVG(CAST(NULLIF(s.satisfaction_score, '') AS DECIMAL(10,2))), 2) AS avg_satisfaction_score
FROM accounts a
LEFT JOIN support_tickets s ON a.account_id = s.account_id
GROUP BY 1;
-- What is the average error count in feature usage for accounts that churned within 3 months?
SELECT 
    f.feature_name,
    ROUND(AVG(f.error_count), 2) AS avg_errors_per_feature,
    COUNT(DISTINCT a.account_id) AS early_churn_account_count
FROM feature_usage f
JOIN subscriptions s on f.subscription_id = s.subscription_id
JOIN accounts a ON s.account_id = a.account_id
JOIN churn_events c ON a.account_id = c.account_id
WHERE a.churn_flag = 'TRUE' 
  AND DATEDIFF(c.churn_date, a.signup_date) <= 90
GROUP BY 1
ORDER BY avg_errors_per_feature DESC;
-- Which accounts have low feature usage + high error count + low satisfaction score simultaneously? ( high-risk accounts)
WITH Usage_Aggregates AS (
    SELECT 
        s.account_id,
        AVG(f.usage_count) AS avg_usage,
        SUM(f.error_count) AS total_errors
    FROM subscriptions s
    JOIN feature_usage f ON s.subscription_id = f.subscription_id
    GROUP BY s.account_id
),
Support_Aggregates AS (
    SELECT 
        account_id,
        AVG(CAST(NULLIF(satisfaction_score, '') AS DECIMAL(10,2))) AS avg_csat
    FROM support_tickets
    GROUP BY account_id
),
Risk_Signals AS (
    SELECT 
        a.account_id,
        a.plan_tier,
        u.avg_usage,
        u.total_errors,
        s.avg_csat
    FROM accounts a
    LEFT JOIN Usage_Aggregates u ON a.account_id = u.account_id
    LEFT JOIN Support_Aggregates s ON a.account_id = s.account_id
    WHERE a.churn_flag = 'FALSE' 
)
SELECT *
FROM Risk_Signals
WHERE 
    avg_usage < (SELECT AVG(usage_count)  FROM feature_usage)
    AND total_errors > (SELECT AVG(error_count)  FROM feature_usage)
    AND avg_csat < 3.0
ORDER BY 
    -- CASE WHEN plan_tier = 'Enterprise' THEN 1 ELSE 2 END,
    total_errors DESC;

-- VI) Revenue forecassting
-- What is the MRR trend over the last 12 months? is it growing, flat, or declining?
WITH Monthly_MRR AS (
    SELECT 
        DATE_FORMAT(start_date, '%Y-%m-01') AS month_label,
        SUM(mrr_amount) AS total_mrr
    FROM subscriptions
    WHERE start_date >= DATE_SUB(CURDATE(), INTERVAL 41 MONTH)
    GROUP BY 1
)
SELECT 
    month_label,
    total_mrr,
    LAG(total_mrr) OVER (ORDER BY month_label) AS prev_month_mrr,
    ROUND(total_mrr - LAG(total_mrr) OVER (ORDER BY month_label), 2) AS mrr_variance,
    CASE 
        WHEN total_mrr > LAG(total_mrr) OVER (ORDER BY month_label) THEN 'Growing'
        WHEN total_mrr < LAG(total_mrr) OVER (ORDER BY month_label) THEN 'Declining'
        ELSE 'Flat'
    END AS trend_status
FROM Monthly_MRR;

-- What is the net MRR change each month accounting for new subscriptions, expansions (upgrades), contractions (downgrades), and churn?
SELECT 
    DATE_FORMAT(s.start_date, '%Y-%m-01') AS report_month,
    SUM(CASE WHEN s.start_date = a.signup_date THEN s.mrr_amount ELSE 0 END) AS new_mrr,
    SUM(CASE WHEN s.upgrade_flag = 'TRUE' THEN s.mrr_amount ELSE 0 END) AS expansion_mrr,
    SUM(CASE WHEN s.downgrade_flag = 'TRUE' THEN s.mrr_amount ELSE 0 END) AS contraction_mrr,
    SUM(CASE WHEN a.churn_flag = 'TRUE' AND DATE_FORMAT(s.end_date, '%Y-%m-01') = DATE_FORMAT(s.start_date, '%Y-%m-01') 
             THEN s.mrr_amount ELSE 0 END) AS churn_mrr,
    ROUND(SUM(CASE WHEN s.start_date = a.signup_date THEN s.mrr_amount ELSE 0 END) + 
          SUM(CASE WHEN s.upgrade_flag = 'TRUE' THEN s.mrr_amount ELSE 0 END) - 
          SUM(CASE WHEN s.downgrade_flag = 'TRUE' THEN s.mrr_amount ELSE 0 END) - 
          SUM(CASE WHEN a.churn_flag = 'TRUE' AND DATE_FORMAT(s.end_date, '%Y-%m-01') = DATE_FORMAT(s.start_date, '%Y-%m-01') 
                   THEN s.mrr_amount ELSE 0 END), 2) AS net_mrr_change
FROM subscriptions s
JOIN accounts a ON s.account_id = a.account_id
GROUP BY 1
ORDER BY 1;

-- What is the expansion MRR (revenue gained from upgrades) vs contraction MRR (revenue lost from downgrades) each month?
select date_format(start_date, '%Y-%m-01') as month,
sum(case when upgrade_flag = 'TRUE' then 1 else 0 end) as revenue_gain_upgrades,
sum( case when downgrade_flag = 'TRUE' THEN 1 ELSE 0 end) as revenue_lost_downgrades
from subscriptions 
group by month;
-- VII) Unit Economics (CAC vs LTV)

-- Which plan tier has the best LTV? and ltv summary
WITH lifetime AS
(
	SELECT account_id, plan_tier, mrr_amount,
	CASE WHEN end_date IS NOT NULL THEN datediff(end_date, start_date)
	ELSE datediff(curdate(), start_date)
	end AS lifetime_days
	FROM subscriptions 
),
ltv_cte AS
(
   SELECT   account_id, plan_tier,
	round(sum(mrr_amount*(lifetime_days)/30), 2) AS ltv
	FROM lifetime
	GROUP BY account_id,
    plan_tier 
)
SELECT plan_tier,
count(DISTINCT account_id) AS total_acccounts,
max(ltv) AS maximum_ltv,
round(avg(ltv), 2) AS avg_ltv,
round(sum(ltv), 2) AS total_ltv
FROM ltv_cte
GROUP BY plan_tier;
-- What is the LTV to CAC ratio by referral source (assume CAC: organic=$0, partner=$2000, ads=$5500, event=$7500)?
WITH account_lifetime AS
(
SELECT a.referral_source, a.account_id, s.mrr_amount,
CASE WHEN s.end_date IS NOT NULL THEN datediff(s.end_date, s.start_date) ELSE datediff(curdate(), s.start_date) end AS lifetime_days
FROM subscriptions s
JOIN accounts a
ON s.account_id = a.account_id ),
ltv_per_account AS
(
SELECT referral_source, account_id,
round(sum(mrr_amount*(lifetime_days)/30), 2) AS ltv,
CASE
	WHEN referral_source = 'organic'THEN 0
	WHEN referral_source = 'partner' THEN 2000
	WHEN referral_source = 'ads' THEN 5500
	WHEN referral_source = 'event' THEN 7500
	ELSE 1000
    end AS assumed_cac
	FROM account_lifetime
	GROUP BY referral_source,
    account_id 
),
ltv_cte AS
 (
    SELECT referral_source, assumed_cac,
	count(DISTINCT account_id) AS total_customers,
    round(sum(ltv), 2) AS total_ltv,
	round(avg(ltv), 2) AS avg_ltv
	FROM  ltv_per_account
	GROUP BY referral_source
)
SELECT referral_source, assumed_cac, avg_ltv, total_ltv, total_customers,
round((avg_ltv/assumed_cac), 2) AS ltv_cac_ratio,
CASE
WHEN (avg_ltv/assumed_cac) = 0 THEN 'Free_Channel'
WHEN (avg_ltv/assumed_cac) >=3 THEN 'HEALTHY'
WHEN (avg_ltv/assumed_cac) = 1 THEN 'Break_Even'
ELSE 'Loss'
end AS health_score
FROM ltv_cte
ORDER BY avg_ltv;



-- another
WITH account_lifetime AS (
    SELECT a.referral_source, 
           a.account_id, 
           s.mrr_amount,
           CASE WHEN s.end_date IS NOT NULL 
                THEN datediff(s.end_date, s.start_date) 
                ELSE datediff(curdate(), s.start_date) 
           END AS lifetime_days
    FROM subscriptions s
    JOIN accounts a ON s.account_id = a.account_id
),
ltv_per_account AS (
    SELECT referral_source, 
           account_id,
           round(sum(mrr_amount * (lifetime_days / 30)), 2) AS ltv
    FROM account_lifetime
    GROUP BY referral_source, account_id
),
ltv_summary AS (
    SELECT referral_source,
           count(DISTINCT account_id) AS total_customers,
           round(sum(ltv), 2) AS total_ltv,
           round(avg(ltv), 2) AS avg_ltv,
           round(max(ltv), 2) AS max_ltv,
           round(min(ltv), 2) AS min_ltv,
           CASE
           WHEN referral_source = 'organic' THEN 0
           WHEN referral_source = 'partner' THEN 16600
           WHEN referral_source = 'ads' THEN 41500
           WHEN referral_source = 'event' THEN 24900
           ELSE 11500
       END AS assumed_cac
    FROM ltv_per_account
    GROUP BY referral_source
)
SELECT referral_source,
	   assumed_cac,
       total_customers,
       avg_ltv,
       max_ltv,
       total_ltv,
       CASE
           WHEN assumed_cac = 0 THEN 'N/A'
           ELSE round((avg_ltv / assumed_cac), 2)
       END AS ltv_cac_ratio,
       CASE
           WHEN assumed_cac = 0 THEN 'Free_Channel'
           WHEN (avg_ltv / assumed_cac) >= 3 THEN 'HEALTHY'
           WHEN (avg_ltv / assumed_cac) = 1 THEN 'Break_Even'
           ELSE 'Loss'
       END AS health_score
FROM ltv_summary
ORDER BY avg_ltv DESC;
-- What is the average subscription lifetime in months for each referral source channel?
SELECT 
    referral_source,
    ROUND(AVG(TIMESTAMPDIFF(MONTH, signup_date, 
        COALESCE(
            (SELECT churn_date FROM churn_events ce WHERE ce.account_id = a.account_id), 
            CURDATE()
        )
    )), 1) AS avg_lifetime_months
FROM accounts a
GROUP BY 1
ORDER BY avg_lifetime_months DESC;