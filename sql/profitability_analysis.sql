/*=============================================================================
  PROJECT : E-commerce Profitability Analysis
  DATABASE: ecommerce_profitability_large
  ENGINE  : MySQL 8.0

  PURPOSE
  Analyze delivered-order revenue, COGS, gross profit, and gross margin;
  investigate product-level margin changes, discounts, and unit-cost movements.

  METRIC DEFINITIONS
  Net Revenue = quantity * (unit_price - discount_per_unit)
  COGS        = quantity * unit_cost
  Gross Profit= Net Revenue - COGS
  Gross Margin= Gross Profit / Net Revenue * 100

  NOTE: This project uses a synthetic practice dataset.
=============================================================================*/

-- Large synthetic E-commerce Profitability dataset, MySQL 8.0
-- CREATE DATABASE IF NOT EXISTS ecommerce_profitability_large;
USE ecommerce_profitability_large;
-- 01. DATASET SIZE CHECKS
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM returns;
SELECT COUNT(*) FROM marketing_spend;


-- 02. INITIAL DATA EXPLORATION
SELECT * FROM orders LIMIT 10;

SELECT * FROM order_items LIMIT 10;

SELECT * FROM products;

-- 03. VALIDATE TABLE JOINS
SELECT o.order_id,
       o.order_date,
       o.customer_id,
       p.product_id,
       p.category
FROM orders o
JOIN order_items oi
ON o.order_id = oi.order_id
JOIN products p
ON oi.product_id = p.product_id
LIMIT 10;

-- 04. MONTHLY PRODUCT PROFITABILITY
SELECT
    p.product_id,
    DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,

    SUM(
        oi.quantity * (oi.unit_price - oi.discount_per_unit)
    ) AS net_revenue,

    SUM(
        oi.quantity * oi.unit_cost
    ) AS cogs,

    SUM(
        oi.quantity * (oi.unit_price - oi.discount_per_unit)
        - oi.quantity * oi.unit_cost
    ) AS gross_profit,

    ROUND(
        100.0 * SUM(
            oi.quantity * (oi.unit_price - oi.discount_per_unit)
            - oi.quantity * oi.unit_cost
        )
        / NULLIF(
            SUM(
                oi.quantity * (oi.unit_price - oi.discount_per_unit)
            ),
            0
        ),
        2
    ) AS gross_margin_pct

FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id

WHERE o.status = 'delivered'

GROUP BY
    p.product_id,
    DATE_FORMAT(o.order_date, '%Y-%m')

ORDER BY
    p.product_id,
    order_month;
-- LIMIT 10;

    -- 05. MONTH-OVER-MONTH GROSS MARGIN CHANGE
WITH monthly_profit AS (
        SELECT
        p.product_id,
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        SUM(
            oi.quantity * (oi.unit_price - oi.discount_per_unit)
        ) AS net_revenue,
        SUM(
            oi.quantity * oi.unit_cost
        ) AS cogs,
        SUM(
            oi.quantity * (oi.unit_price - oi.discount_per_unit)
            - oi.quantity * oi.unit_cost
        ) AS gross_profit,
        ROUND(
            100.0 * SUM(
                oi.quantity * (oi.unit_price - oi.discount_per_unit)
                - oi.quantity * oi.unit_cost
            )
            / NULLIF(
                SUM(
                    oi.quantity * (oi.unit_price - oi.discount_per_unit)
                ),
                0
            ),
            2
        ) AS gross_margin_pct

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    WHERE o.status = 'delivered'
    GROUP BY
        p.product_id,
        DATE_FORMAT(o.order_date, '%Y-%m')
    ),
previous_month_margins AS (
    SELECT *,
           LAG(gross_margin_pct) OVER (
               PARTITION BY product_id
               ORDER BY order_month
            ) AS previous_month_margin
    FROM monthly_profit
    ORDER BY product_id, order_month
)

SELECT *,
      ROUND (
        gross_margin_pct - previous_month_margin,
        2
      ) AS margin_change_pp
FROM previous_month_margins;

-- 06. PRODUCT 201: PRICE, DISCOUNT, AND UNIT-COST TREND
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,

    SUM(oi.quantity) AS total_quantity,

    ROUND(
        SUM(oi.quantity * oi.unit_price) / SUM(oi.quantity),
        2
    ) AS asp_before_disc,

    ROUND(
        SUM(oi.quantity * oi.discount_per_unit) / SUM(oi.quantity),
        2
    ) AS weighted_avg_disc,

    ROUND(
        SUM(oi.quantity * (oi.unit_price - oi.discount_per_unit))
        / NULLIF(SUM(oi.quantity), 0),
        2
    ) AS realized_selling_ppu,

    ROUND(
        SUM(oi.quantity * oi.unit_cost) / NULLIF(SUM(oi.quantity), 0),
        2
    ) AS weighted_avg_unit_cost

FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE
    o.status = 'delivered'
    AND oi.product_id = 201

GROUP BY
    DATE_FORMAT(o.order_date, '%Y-%m')

ORDER BY
    order_month;

SELECT
    p.product_id,
    p.product_name,
    p.category,
    DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
    SUM(oi.quantity) AS total_quantity,
    ROUND(
        SUM(oi.quantity * oi.unit_price) / SUM(oi.quantity),
        2
    ) AS asp_before_disc,
    ROUND(
        SUM(oi.quantity * oi.discount_per_unit) / SUM(oi.quantity),
        2
    ) AS weighted_avg_disc,
    ROUND(
        SUM(oi.quantity * (oi.unit_price - oi.discount_per_unit))
        / NULLIF(SUM(oi.quantity), 0),
        2
    ) AS realized_selling_ppu,
    ROUND(
        SUM(oi.quantity * oi.unit_cost) / NULLIF(SUM(oi.quantity), 0),
        2
    ) AS weighted_avg_unit_cost,
      ROUND(
        SUM(
            oi.quantity * (
                oi.unit_price
                - oi.discount_per_unit
                - oi.unit_cost
            )
        ),
        2
    ) AS gross_profit,

    ROUND(
        100.0 * SUM(
            oi.quantity * (
                oi.unit_price
                - oi.discount_per_unit
                - oi.unit_cost
            )
        ) / NULLIF(
            SUM(oi.quantity * (oi.unit_price - oi.discount_per_unit)),
            0
        ),
        2
    ) AS gross_margin_pct
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id
WHERE
    o.status = 'delivered'
GROUP BY
    p.product_id,
    p.product_name,
    p.category,
    DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY
    order_month;


-- 08. MARCH-TO-APRIL PRODUCT MARGIN COMPARISON
-- COMPARISON ACROSS PRODUCTS
WITH monthly_product AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,

        SUM(
            oi.quantity *
            (oi.unit_price - oi.discount_per_unit)
        ) AS net_revenue,

        SUM(
            oi.quantity *
            (
                oi.unit_price
                - oi.discount_per_unit
                - oi.unit_cost
            )
        ) AS gross_profit

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id

    WHERE o.status = 'delivered'

    GROUP BY
        p.product_id,
        p.product_name,
        p.category,
        DATE_FORMAT(o.order_date, '%Y-%m')
),
margin_comparison AS (
    SELECT
        product_id,
        product_name,
        category,
        order_month,

        100.0 * gross_profit /
            NULLIF(net_revenue, 0) AS gross_margin_pct

    FROM monthly_product
)
SELECT
    product_id,
    product_name,
    category,

    ROUND(MAX(
        CASE WHEN order_month = '2026-03'
        THEN gross_margin_pct END
    ), 2) AS march_margin_pct,

    ROUND(MAX(
        CASE WHEN order_month = '2026-04'
        THEN gross_margin_pct END
    ), 2) AS april_margin_pct,

    ROUND(MAX(
        CASE WHEN order_month = '2026-05'
        THEN gross_margin_pct END
    ), 2) AS may_margin_pct,

    ROUND(
        MAX(CASE WHEN order_month = '2026-04'
            THEN gross_margin_pct END)
        -
        MAX(CASE WHEN order_month = '2026-03'
            THEN gross_margin_pct END),
        2
    ) AS march_to_april_change_pp

FROM margin_comparison

GROUP BY product_id, product_name, category
ORDER BY march_to_april_change_pp ASC;


SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,

    SUM(oi.quantity) AS total_quantity,

    ROUND(
        SUM(oi.quantity * oi.unit_price) / SUM(oi.quantity),
        2
    ) AS asp_before_disc,

    ROUND(
        SUM(oi.quantity * oi.discount_per_unit) / SUM(oi.quantity),
        2
    ) AS weighted_avg_disc,

    ROUND(
        SUM(oi.quantity * (oi.unit_price - oi.discount_per_unit))
        / NULLIF(SUM(oi.quantity), 0),
        2
    ) AS realized_selling_ppu,

    ROUND(
        SUM(oi.quantity * oi.unit_cost) / NULLIF(SUM(oi.quantity), 0),
        2
    ) AS weighted_avg_unit_cost

FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE
    o.status = 'delivered'
    AND oi.product_id = 207

GROUP BY
    DATE_FORMAT(o.order_date, '%Y-%m')

ORDER BY
    order_month;


-- 09. ELECTRONICS: MARCH-TO-MAY UNIT-COST CHANGE
WITH monthly_cost AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,

        SUM(oi.quantity * oi.unit_cost)
            / NULLIF(SUM(oi.quantity), 0) AS avg_unit_cost

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id

    WHERE o.status = 'delivered'
      AND DATE_FORMAT(o.order_date, '%Y-%m')
          IN ('2026-03', '2026-05')

    GROUP BY
        p.product_id,
        p.product_name,
        p.category,
        DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT
    product_id,
    product_name,
    category,

    ROUND(MAX(
        CASE WHEN order_month = '2026-03'
             THEN avg_unit_cost END
    ), 2) AS march_unit_cost,

    ROUND(MAX(
        CASE WHEN order_month = '2026-05'
             THEN avg_unit_cost END
    ), 2) AS may_unit_cost,

    ROUND(
        MAX(CASE WHEN order_month = '2026-05'
                 THEN avg_unit_cost END)
        -
        MAX(CASE WHEN order_month = '2026-03'
                 THEN avg_unit_cost END),
        2
    ) AS cost_change,

    ROUND(
        100.0 * (
            MAX(CASE WHEN order_month = '2026-05'
                     THEN avg_unit_cost END)
            -
            MAX(CASE WHEN order_month = '2026-03'
                     THEN avg_unit_cost END)
        )
        / NULLIF(
            MAX(CASE WHEN order_month = '2026-03'
                     THEN avg_unit_cost END),
            0
        ),
        2
    ) AS cost_change_pct

FROM monthly_cost
GROUP BY product_id, product_name, category
HAVING march_unit_cost IS NOT NULL
   AND may_unit_cost IS NOT NULL
   AND category = 'Electronics'
ORDER BY cost_change_pct DESC;


-- 10. ELECTRONICS: MARCH-TO-APRIL DISCOUNT CHANGE
WITH monthly_discount AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,

        SUM(oi.quantity * oi.discount_per_unit)
            / NULLIF(SUM(oi.quantity), 0) AS avg_discount

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id

    WHERE o.status = 'delivered'
      AND p.category = 'Electronics'
      AND DATE_FORMAT(o.order_date, '%Y-%m')
          IN ('2026-03', '2026-04')

    GROUP BY
        p.product_id,
        p.product_name,
        p.category,
        DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT
    product_id,
    product_name,
    ROUND(MAX(
        CASE WHEN order_month = '2026-03'
             THEN avg_discount END
    ), 2) AS march_discount,
    ROUND(MAX(
        CASE WHEN order_month = '2026-04'
             THEN avg_discount END
    ), 2) AS april_discount,
    ROUND(
        MAX(CASE WHEN order_month = '2026-04'
                 THEN avg_discount END)
        -
        MAX(CASE WHEN order_month = '2026-03'
                 THEN avg_discount END),
        2
    ) AS discount_increase,
    ROUND(
        100.0 * (
            MAX(CASE WHEN order_month = '2026-04'
                     THEN avg_discount END)
            -
            MAX(CASE WHEN order_month = '2026-03'
                     THEN avg_discount END)
        )
        / NULLIF(
            MAX(CASE WHEN order_month = '2026-03'
                     THEN avg_discount END),
            0
        ),
        2
    ) AS discount_change_pct
FROM monthly_discount
GROUP BY product_id, product_name
HAVING march_discount IS NOT NULL
   AND april_discount IS NOT NULL
ORDER BY discount_change_pct DESC;


SELECT * FROM order_items;
SELECT
    p.category,
    DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
    SUM(
        oi.quantity *
        (oi.unit_price - oi.discount_per_unit)
    ) AS net_revenue,

    SUM(
        oi.quantity * oi.unit_cost
    ) AS total_cogs,

    SUM(
        oi.quantity *
        (
            oi.unit_price
            - oi.discount_per_unit
            - oi.unit_cost
        )
    ) AS gross_profit,

    ROUND(
        100.0 * SUM(
            oi.quantity *
            (
                oi.unit_price
                - oi.discount_per_unit
                - oi.unit_cost
            )
        )
        / NULLIF(
            SUM(
                oi.quantity *
                (oi.unit_price - oi.discount_per_unit)
            ),
            0
        ),
        2
    ) AS gross_margin_pct
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id

    WHERE o.status = 'delivered'
      AND DATE_FORMAT(o.order_date, '%Y-%m')
          IN ('2026-03', '2026-04', '2026-05')
GROUP BY
    p.category,
    DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY
    p.category,
    order_month;

SELECT * FROM products;
-- 12. ELECTRONICS: PRODUCT GROSS-PROFIT CHANGE (MARCH VS MAY)
SELECT p.product_name,
       SUM(
          CASE
             WHEN DATE_FORMAT(o.order_date, '%Y-%m') = '2026-03'
             THEN oi.quantity * (oi.unit_price - oi.discount_per_unit - oi.unit_cost)
             ELSE 0
             END
       ) AS march_gross_profit,
       SUM(
          CASE
             WHEN DATE_FORMAT(o.order_date, '%Y-%m') = '2026-05'
             THEN oi.quantity * (oi.unit_price - oi.discount_per_unit - oi.unit_cost)
             ELSE 0
             END
       ) AS may_gross_profit,
         SUM(
        CASE
            WHEN DATE_FORMAT(o.order_date, '%Y-%m') = '2026-05'
            THEN oi.quantity *
                 (oi.unit_price - oi.discount_per_unit - oi.unit_cost)
            ELSE 0
        END
    )
    -
    SUM(
        CASE
            WHEN DATE_FORMAT(o.order_date, '%Y-%m') = '2026-03'
            THEN oi.quantity *
                 (oi.unit_price - oi.discount_per_unit - oi.unit_cost)
            ELSE 0
        END
    ) AS profit_change
FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
WHERE o.status = 'delivered'
  AND p.category = 'Electronics'
  AND DATE_FORMAT(o.order_date, '%Y-%m')
      IN ('2026-03', '2026-05')
GROUP BY
    p.product_id,
    p.product_name

ORDER BY profit_change ASC;

SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,

    SUM(oi.quantity) AS total_quantity,

    ROUND(
        SUM(oi.quantity * oi.unit_price) / SUM(oi.quantity),
        2
    ) AS asp_before_disc,

    ROUND(
        SUM(oi.quantity * oi.discount_per_unit) / SUM(oi.quantity),
        2
    ) AS weighted_avg_disc,

    ROUND(
        SUM(oi.quantity * (oi.unit_price - oi.discount_per_unit))
        / NULLIF(SUM(oi.quantity), 0),
        2
    ) AS realized_selling_ppu,

    ROUND(
        SUM(oi.quantity * oi.unit_cost) / NULLIF(SUM(oi.quantity), 0),
        2
    ) AS weighted_avg_unit_cost

FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE
    o.status = 'delivered'
    AND oi.product_id = 214

GROUP BY
    DATE_FORMAT(o.order_date, '%Y-%m')

ORDER BY
    order_month;

-- 13. RECONCILIATION: DIRECT CATEGORY TOTALS VS PRODUCT ROLLUP
WITH base AS (
    SELECT
        p.category,
        p.product_id,
        p.product_name,
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        oi.quantity * (oi.unit_price - oi.discount_per_unit) AS net_revenue,
        oi.quantity * oi.unit_cost                           AS cogs
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders   o ON oi.order_id   = o.order_id
    WHERE o.status = 'delivered'          -- same filter, ek hi jagah
),
product_level AS (
    SELECT category, product_id, order_month,
           SUM(net_revenue) AS net_revenue,
           SUM(cogs)        AS cogs
    FROM base
    GROUP BY category, product_id, order_month
),
product_rollup AS (                        -- products ko wapas category tak sum karo
    SELECT category, order_month,
           SUM(net_revenue) AS rev_from_products,
           SUM(cogs)        AS cogs_from_products
    FROM product_level
    GROUP BY category, order_month
),
category_level AS (                        -- category ko direct calculate karo
    SELECT category, order_month,
           SUM(net_revenue) AS rev_category,
           SUM(cogs)        AS cogs_category
    FROM base
    GROUP BY category, order_month
)
SELECT
    c.category,
    c.order_month,
    c.rev_category,
    r.rev_from_products,
    c.rev_category  - r.rev_from_products  AS revenue_diff,
    c.cogs_category,
    r.cogs_from_products,
    c.cogs_category - r.cogs_from_products AS cogs_diff
FROM category_level c
JOIN product_rollup r
  ON c.category = r.category
 AND c.order_month = r.order_month
ORDER BY c.category, c.order_month;

-- 14. DATA QUALITY: ORDER ITEMS WITHOUT A MATCHING PRODUCT
SELECT COUNT(*) AS orphan_items
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;
