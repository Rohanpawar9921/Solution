const express = require("express");
const router = express.Router();
const db = require("../db"); // pg pool or mysql pool

router.get("/api/companies/:companyId/alerts/low-stock", async (req, res) => {
  const { companyId } = req.params;
  const {
    page = 1,
    limit = 20,
    warehouse_id,
    product_type
  } = req.query;

  const offset = (page - 1) * limit;

  try {
    const query = `
      WITH recent_sales AS (
        SELECT
          s.product_id,
          s.warehouse_id,
          SUM(s.quantity) AS total_sold
        FROM sales s
        WHERE s.created_at >= NOW() - INTERVAL '30 days'
        GROUP BY s.product_id, s.warehouse_id
      )
      SELECT
        p.id AS product_id,
        p.name AS product_name,
        p.sku,
        p.product_type,
        w.id AS warehouse_id,
        w.name AS warehouse_name,
        i.quantity AS current_stock,
        rs.total_sold,
        sup.id AS supplier_id,
        sup.name AS supplier_name,
        sup.contact_email
      FROM recent_sales rs
      JOIN inventory i
        ON i.product_id = rs.product_id
       AND i.warehouse_id = rs.warehouse_id
      JOIN products p ON p.id = rs.product_id
      JOIN warehouses w ON w.id = rs.warehouse_id
      LEFT JOIN supplier_products sp ON sp.product_id = p.id
      LEFT JOIN suppliers sup ON sup.id = sp.supplier_id
      WHERE w.company_id = $1
        AND i.quantity <
          CASE
            WHEN p.product_type = 'FAST_MOVING' THEN 20
            WHEN p.product_type = 'SLOW_MOVING' THEN 5
            ELSE 10
          END
        ${warehouse_id ? "AND w.id = $2" : ""}
        ${product_type ? "AND p.product_type = $3" : ""}
      ORDER BY i.quantity ASC
      LIMIT $4 OFFSET $5
    `;

    const params = [
      companyId,
      warehouse_id,
      product_type,
      limit,
      offset
    ].filter(v => v !== undefined);

    const { rows } = await db.query(query, params);

    const alerts = rows.map(row => {
      const avgDailySales = row.total_sold / 30;

      return {
        product_id: row.product_id,
        product_name: row.product_name,
        sku: row.sku,
        warehouse_id: row.warehouse_id,
        warehouse_name: row.warehouse_name,
        current_stock: row.current_stock,
        threshold:
          LOW_STOCK_THRESHOLDS[row.product_type] ||
          LOW_STOCK_THRESHOLDS.DEFAULT,
        days_until_stockout:
          avgDailySales > 0
            ? Math.floor(row.current_stock / avgDailySales)
            : null,
        supplier: row.supplier_id
          ? {
              id: row.supplier_id,
              name: row.supplier_name,
              contact_email: row.contact_email
            }
          : null
      };
    });

    res.json({
      page: Number(page),
      limit: Number(limit),
      total_alerts: alerts.length,
      alerts
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Internal server error" });
  }
});

module.exports = router;
