SELECT CONCAT(ot.label,'-',ot.rate_id)              AS `tax`
    ,ot.rate_percent/100                            AS `rate`
    ,SUM(ot.tax_amount + ot.shipping_tax_amount)    AS `total_tax`
    ,SUM(ot.tax_amount)                             AS `tax_amount`
    ,SUM(ot.shipping_tax_amount)                    AS `shipping_tax`
    ,COUNT(so.id) - SUM(so.refund)                  AS `orders`
FROM shop_order so
INNER JOIN order_taxes ot ON 1 = 1
    AND ot.order_id = so.id

WHERE YEAR(so.order_date) = {{year}} AND MONTH(so.order_date) = {{month}}

GROUP BY ot.rate_id
