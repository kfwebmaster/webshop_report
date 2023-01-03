/*generate sales report for a month: */
SELECT
    title                                                       AS `product_title`
    ,sales.sku
    ,SUM(quantity * IF(refund, -1, 1))                          AS `quantity`
    ,ROUND(SUM(net_price * quantity * IF(refund, -1, 1)), 2)    AS `net_sales`
    ,ROUND(SUM(gross_price * quantity * IF(refund, -1, 1)), 2)  AS `gross_sales`
    ,ROUND(SUM(line_tax * IF(refund, -1, 1)), 2)                AS `total_vat`
    ,tax_status
    ,ROUND(gross_price, 2)                                      AS `price`
    ,ROUND(cost, 2)                                             AS `cost`
    ,category
    ,total_stock                                                AS `stock`
FROM sales

WHERE `year` = {{year}} AND `month` = {{month}}

GROUP BY sales.sku
    ,title
    ,tax_status
    ,cost
    ,gross_price
    ,category
    ,CONCAT(`year`,'-',`month`)

ORDER BY sku DESC
