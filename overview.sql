/*generate sales report for a month: */
SELECT 
    title                                                       AS `product_title` 
    ,sku
    ,SUM(quantity * IF(refund, -1, 1))                          AS `quantity` 
    ,ROUND(SUM(line_total * IF(refund, -1, 1)), 2)              AS `net_sales` 
    ,ROUND(SUM((line_total + line_tax) * IF(refund, -1, 1)), 2) AS `gross_sales`
    ,ROUND(SUM(line_tax * IF(refund, -1, 1)), 2)                AS `total_vat` 
    ,tax_status
    ,ROUND(price_point, 2)                                      AS `price`
    ,ROUND(cost, 2)                                             AS `cost`
    ,category
    ,total_stock                                                AS `stock`
FROM sales

WHERE period = '{{year}}-{{month}}'

GROUP BY sku
    ,title
    ,tax_status
    ,cost
    ,price_point
    ,category
    ,period

ORDER BY sku DESC
