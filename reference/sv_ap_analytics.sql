USE DATABASE COCO_WORKSHOP;
USE SCHEMA PIPELINE_LAB;

CREATE OR REPLACE SEMANTIC VIEW SV_AP_ANALYTICS
  TABLES (
    inv AS COCO_WORKSHOP.PIPELINE_LAB.SILVER_AP_INVOICES
      PRIMARY KEY (SOURCE_SYSTEM, INVOICE_ID)
      COMMENT = 'One row per AP invoice across SAP, Oracle, Baan and Workday'
  )
  FACTS (
    inv.invoice_amount_fact AS INVOICE_AMOUNT COMMENT = 'Invoice amount in original transaction currency (BR-002: not converted)'
  )
  DIMENSIONS (
    inv.source_system AS SOURCE_SYSTEM COMMENT = 'Originating ERP: SAP, ORACLE, BAAN, WORKDAY',
    inv.vendor_name AS VENDOR_NAME COMMENT = 'Vendor / supplier name',
    inv.vendor_id AS VENDOR_ID COMMENT = 'Source-system vendor identifier (not unified across systems)',
    inv.currency_code AS CURRENCY_CODE COMMENT = 'ISO currency of the invoice',
    inv.approval_status AS APPROVAL_STATUS COMMENT = 'APPROVED or PENDING',
    inv.cost_center AS COST_CENTER COMMENT = 'Source cost center, used as business unit',
    inv.invoice_date AS INVOICE_DATE COMMENT = 'Invoice date',
    inv.invoice_month AS DATE_TRUNC('MONTH', INVOICE_DATE) COMMENT = 'Invoice month',
    inv.due_date AS DUE_DATE COMMENT = 'Payment due date'
  )
  METRICS (
    inv.total_spend AS SUM(inv.invoice_amount_fact) COMMENT = 'Total AP spend (mixed currencies unless filtered by currency)',
    inv.invoice_count AS COUNT(inv.invoice_amount_fact) COMMENT = 'Number of invoices',
    inv.unpaid_amount AS SUM(IFF(inv.approval_status = 'PENDING', inv.invoice_amount_fact, 0)) COMMENT = 'Amount on PENDING invoices (proxy for unpaid; no paid flag exists)'
  )
  COMMENT = 'AP analytics over Silver AP invoices';

SELECT * FROM SEMANTIC_VIEW(COCO_WORKSHOP.PIPELINE_LAB.SV_AP_ANALYTICS
  DIMENSIONS inv.source_system METRICS inv.total_spend, inv.invoice_count)
ORDER BY 1;
