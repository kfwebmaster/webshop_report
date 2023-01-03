/*pivoted and simplified table structures: */
WITH
postmeta AS (
    SELECT post_id
        ,MAX(CASE WHEN meta_key = '_sku'            THEN meta_value ELSE '' END) AS sku
        ,MAX(CASE WHEN meta_key = '_tax_status'     THEN meta_value ELSE '' END) AS tax_status
        ,MAX(CASE WHEN meta_key = '_wc_cog_cost'    THEN meta_value ELSE '' END) AS cost
        ,MAX(CASE WHEN meta_key = '_price'          THEN meta_value ELSE '' END) AS price
        ,MAX(CASE WHEN meta_key = '_stock'          THEN meta_value ELSE '' END) AS stock
    FROM {{prefix}}postmeta
    WHERE meta_key IN ('_sku', '_tax_status', '_wc_cog_cost', '_price', '_stock')
    GROUP BY post_id
)
,order_items AS (
    SELECT oi.order_id
        ,oi.order_item_id
        ,MAX(CASE WHEN oim.meta_key = '_qty'        THEN ABS(oim.meta_value) ELSE 0 END)    AS quantity
        ,MAX(CASE WHEN oim.meta_key = '_line_total' THEN ABS(oim.meta_value) ELSE 0 END)    AS line_total
        ,MAX(CASE WHEN oim.meta_key = '_line_tax'   THEN ABS(oim.meta_value) ELSE 0 END)    AS line_tax
        ,MAX(CASE WHEN oim.meta_key = '_product_id' THEN oim.meta_value ELSE '' END)        AS product_id
    FROM {{prefix}}woocommerce_order_items oi
    INNER JOIN {{prefix}}woocommerce_order_itemmeta oim ON oi.order_item_id = oim.order_item_id
    WHERE 1 = 1
        AND meta_key IN ('_qty', '_line_total', '_line_tax', '_product_id')
        AND oi.order_item_type = 'line_item'
    GROUP BY order_item_id
)
,order_lines AS (
    SELECT order_id
        ,order_item_id
        ,quantity
        ,line_total
        ,ROUND(line_total / quantity, 0)                AS `net_price`
        ,ROUND((line_total + line_tax) / quantity, 0)   AS `gross_price`
        ,line_tax
        ,product_id
    FROM order_items
)
,shop_order AS (
    SELECT id
        ,post_date AS order_date
        ,CASE WHEN post_type = 'shop_order_refund' THEN 1 ELSE 0 END AS refund
    FROM {{prefix}}posts
    WHERE 1 = 1
        AND post_type       IN ('shop_order', 'shop_order_refund')
        AND post_status     IN ('wc-completed', 'wc-processing', 'wc-refunded')
)
,postterms AS (
    SELECT object_id
        ,term_tax.taxonomy
        ,terms.`name`
    FROM {{prefix}}term_relationships term_rel
    JOIN {{prefix}}term_taxonomy term_tax  ON term_tax.term_taxonomy_id    = term_rel.term_taxonomy_id
    JOIN {{prefix}}terms terms             ON terms.term_id                = term_tax.term_id
)
,product AS (
    SELECT p.id
        ,p.post_title AS title
        ,postmeta.sku
        ,postmeta.tax_status
        ,postmeta.cost
        ,postmeta.price
        ,postterms.`name` AS category
        ,SUM(IFNULL(vm.stock, postmeta.stock)) AS total_stock
    FROM {{prefix}}posts p
    LEFT JOIN postmeta      ON postmeta.post_id     = p.id
    LEFT JOIN postterms     ON postterms.object_id  = p.id AND postterms.taxonomy   = 'product_cat'
    LEFT JOIN {{prefix}}posts v  ON v.post_parent        = p.id AND v.post_type          = 'product_variation'
    LEFT JOIN postmeta vm   ON vm.post_id           = v.id
    WHERE p.post_type = 'product'
    GROUP BY p.id
)
,sales AS (
    SELECT product.id
        ,product.title
        ,product.sku
        ,product.tax_status
        ,product.cost
        ,order_lines.net_price
        ,order_lines.gross_price
        ,SUM(order_lines.net_price)     AS net_total
        ,SUM(order_lines.gross_price)   AS gross_total
        ,SUM(order_lines.quantity)      AS quantity
        ,SUM(order_lines.line_total)    AS line_total
        ,SUM(order_lines.line_tax)      AS line_tax
        ,shop_order.refund
        ,product.category
        ,YEAR(shop_order.order_date)    AS `year`
        ,MONTH(shop_order.order_date)   AS `month`
        ,product.total_stock
    FROM shop_order
    INNER JOIN order_lines  ON order_lines.order_id = shop_order.id
    INNER JOIN product      ON product.id           = order_lines.product_id
    GROUP BY product.id
        ,order_lines.net_price
        ,order_lines.gross_price
        ,product.tax_status
        ,product.sku
        ,shop_order.refund
        ,CONCAT(YEAR(shop_order.order_date),'-',MONTH(shop_order.order_date))
)
