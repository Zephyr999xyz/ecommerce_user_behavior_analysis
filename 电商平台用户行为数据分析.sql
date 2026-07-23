-- 项目：电商平台用户行为分析
-- 数据来源：阿里云天池数据集（10万用户）
-- 工具：MySQL 8.0 + Navicat
-- 说明：分析用户从首页到支付确认的转化路径





-- 漏斗分析
SELECT
    COUNT(DISTINCT h.user_id) AS home_uv,
    COUNT(DISTINCT l.user_id) AS listing_uv,
    COUNT(DISTINCT p.user_id) AS product_uv,
    COUNT(DISTINCT pay.user_id) AS payment_uv,
    COUNT(DISTINCT c.user_id) AS confirm_uv,
    ROUND(COUNT(DISTINCT l.user_id) * 100.0 / COUNT(DISTINCT h.user_id), 2) AS home_to_listing_pct,
    ROUND(COUNT(DISTINCT p.user_id) * 100.0 / COUNT(DISTINCT l.user_id), 2) AS listing_to_product_pct,
    ROUND(COUNT(DISTINCT pay.user_id) * 100.0 / COUNT(DISTINCT p.user_id), 2) AS product_to_payment_pct,
    ROUND(COUNT(DISTINCT c.user_id) * 100.0 / COUNT(DISTINCT pay.user_id), 2) AS payment_to_confirm_pct
FROM home_page h
LEFT JOIN listing_page l ON h.user_id = l.user_id
LEFT JOIN product_page p ON h.user_id = p.user_id
LEFT JOIN payment_page pay ON h.user_id = pay.user_id
LEFT JOIN confirmation_page c ON h.user_id = c.user_id;








-- 各来源渠道的效果对比
SELECT
    u.source,
    COUNT(DISTINCT u.user_id) AS total_users,
    COUNT(DISTINCT p.user_id) AS reached_product,
    COUNT(DISTINCT c.user_id) AS converted,
    ROUND(COUNT(DISTINCT c.user_id) * 100.0 / COUNT(DISTINCT u.user_id), 2) AS conversion_rate,
    ROUND(COUNT(DISTINCT c.user_id) * 100.0 / NULLIF(COUNT(DISTINCT p.user_id), 0), 2) AS product_to_confirm_pct
FROM user_info u
LEFT JOIN product_page p ON u.user_id = p.user_id
LEFT JOIN confirmation_page c ON u.user_id = c.user_id
GROUP BY u.source
ORDER BY conversion_rate DESC;








-- 性别 + 设备类型的交叉转化分析
SELECT
    u.sex,
    u.device,
    COUNT(DISTINCT u.user_id) AS user_count,
    COUNT(DISTINCT c.user_id) AS converted_count,
    ROUND(COUNT(DISTINCT c.user_id) * 100.0 / COUNT(DISTINCT u.user_id), 2) AS conv_rate,
    ROUND(AVG(u.age), 1) AS avg_age
FROM user_info u
LEFT JOIN confirmation_page c ON u.user_id = c.user_id
GROUP BY u.sex, u.device
HAVING COUNT(DISTINCT u.user_id) >= 500
ORDER BY conv_rate DESC;








-- 用户分层（四组各取前五）
WITH UserLevels AS (
    SELECT 
        u.user_id,
        u.sex AS 性别,
        u.source AS 来源渠道,
        (SELECT COUNT(*) FROM product_page p WHERE p.user_id = u.user_id) AS 详情页访问次数,
        CASE 
            WHEN co.user_id IS NOT NULL THEN '1-已转化'
            WHEN pa.user_id IS NOT NULL THEN '2-卡在支付页'
            WHEN pr_dist.user_id IS NOT NULL THEN '3-看过商品未下单'
            ELSE '4-边缘流失用户'
        END AS 用户分层
    FROM user_info u
    LEFT JOIN (SELECT DISTINCT user_id FROM confirmation_page) co ON u.user_id = co.user_id
    LEFT JOIN (SELECT DISTINCT user_id FROM payment_page) pa ON u.user_id = pa.user_id
    LEFT JOIN (SELECT DISTINCT user_id FROM product_page) pr_dist ON u.user_id = pr_dist.user_id
)
SELECT 
    user_id,
    性别,
    来源渠道,
    详情页访问次数,
    用户分层,
    分层内排名
FROM (
    SELECT 
        user_id,
        性别,
        来源渠道,
        详情页访问次数,
        用户分层,
        ROW_NUMBER() OVER (PARTITION BY 用户分层 ORDER BY 详情页访问次数 DESC) AS 分层内排名
    FROM UserLevels
) AS RankedUsers
WHERE 分层内排名 <= 5
ORDER BY 用户分层 ASC, 分层内排名 ASC;