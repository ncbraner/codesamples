CREATE
TEMP TABLE
    MKT_AGG AS
SELECT MKT.client_id,
       MKT.org_unit_id,
       SUM(MKT.group_atd_units) AS total_atd_units,
       SUM(MKT.group_exp_tires) AS total_exp_tires
FROM #GCP_PROJECT_ID.#CC_DATASET.market_sales_#HORIZON AS MKT
GROUP BY MKT.client_id,
         MKT.org_unit_id;

CREATE
TEMP TABLE
    GRP_INV AS
SELECT INV.client_id,
       INV.org_unit_id,
       IPM.size_code,
       IPM.tier,
       IPM.tire_type,
       CASE
           WHEN MAX(INV.avg_qoh) > 0 THEN 1
           ELSE 0
           END AS group_stocked
FROM #GCP_PROJECT_ID.#CC_DATASET.inventory AS INV
         INNER JOIN
     #GCP_PROJECT_ID.ipm.industry_product_master AS IPM
     ON
         IPM.ipm_id = INV.ipm_id
GROUP BY INV.client_id,
         INV.org_unit_id,
         IPM.size_code,
         IPM.tier,
         IPM.tire_type;

CREATE
TEMP TABLE
    GRP AS
SELECT GRPD.client_id,
       GRPD.org_unit_id,
       CASE
           WHEN SUM(GRPD.group_market_demand) <= 0 THEN 0
           ELSE SUM(IF(GRP_INV.group_stocked = 1, GRPD.group_market_demand, 0)) / SUM(GRPD.group_market_demand)
           END AS market_coverage
FROM (SELECT MKT.client_id,
             MKT.org_unit_id,
             MKT.size_code,
             MKT.tier,
             MKT.tire_type,
             CASE
                 WHEN MKT_AGG.total_atd_units > 0 AND MKT_AGG.total_exp_tires > 0 THEN
                             (MKT.group_atd_units / MKT_AGG.total_atd_units) * 0.3 +
                             (MKT.group_exp_tires / MKT_AGG.total_exp_tires) * 0.7
                 WHEN MKT_AGG.total_atd_units > 0 THEN (MKT.group_atd_units / MKT_AGG.total_atd_units) * 0.3
                 WHEN MKT_AGG.total_exp_tires > 0 THEN (MKT.group_exp_tires / MKT_AGG.total_exp_tires) * 0.7
                 ELSE 0
                 END AS group_market_demand
      FROM #GCP_PROJECT_ID.#CC_DATASET.market_sales_#HORIZON AS MKT
               LEFT JOIN MKT_AGG
                         ON
                                     MKT_AGG.client_id = MKT.client_id
                                 AND
                                     MKT_AGG.org_unit_id = MKT.org_unit_id) AS GRPD
         LEFT JOIN
     GRP_INV
     ON
                 GRP_INV.client_id = GRPD.client_id
             AND GRP_INV.org_unit_id = GRPD.org_unit_id
             AND GRP_INV.size_code = GRPD.size_code
             AND GRP_INV.tier = GRPD.tier
             AND GRP_INV.tire_type = GRPD.tire_type
GROUP BY GRPD.client_id,
         GRPD.org_unit_id;

CREATE
TEMP TABLE
    CPM AS
SELECT OU.client_id,
       OU.org_unit_id,
       IPM.ipm_id,
       IPM.size_code,
       IPM.tier,
       IPM.tire_type,
       IPM.style,
       IPM.mfg_name
FROM #GCP_PROJECT_ID.ipm.industry_product_master AS IPM
         CROSS JOIN (SELECT DISTINCT client_id,
                                     org_unit_id
                     FROM #GCP_PROJECT_ID.#APP_DATASET.org_unit OU
                              LEFT JOIN
                          #GCP_PROJECT_ID.#APP_DATASET.store ST
                          ON
                                      ST.torqata_client_id = OU.client_id
                                  AND ST.torqata_org_unit_id = OU.org_unit_id
                     WHERE parent_id IS NOT NULL
                       AND (ST.vendor_id != 50
                  OR OU.org_unit_id IN (
                   SELECT
                   demo_org_unit_id
                   FROM
               #GCP_PROJECT_ID.#CC_DATASET.demo_org_unit_map))
                       AND #CLIENT_FILTER) AS OU;

CREATE
TEMP TABLE
                   POS AS
SELECT CPM.client_id
     , CPM.org_unit_id
     , CPM.ipm_id
     , CPM.size_code
     , CPM.tier
     , CPM.tire_type
     , CPM.style
     , CPM.mfg_name
     , COALESCE(POS.store_units
    , 0) AS store_units
     , CASE
           WHEN EBR.reward_mode = "dollars" THEN COALESCE(POS.store_profit + POS.store_units * EBR.reward_value
               , 0)
           WHEN EBR.reward_mode = "percent" THEN COALESCE(POS.store_profit * (1 + EBR.reward_value / 100)
               , 0)
           ELSE COALESCE(POS.store_profit
               , 0)
    END  AS store_profit
     , COALESCE(POS.total_cost
    , 0) AS total_cost
     , COALESCE(POS.total_retail
    , 0) AS total_retail
     , COALESCE(POS.cost
    , 0) AS cost
     , COALESCE(POS.retail
    , 0) AS retail
FROM CPM
         LEFT JOIN
     #GCP_PROJECT_ID.#CC_DATASET.pos_sales_#HORIZON AS POS
     ON
                 POS.client_id = CPM.client_id
             AND POS.org_unit_id = CPM.org_unit_id
             AND POS.ipm_id = CPM.ipm_id
         LEFT JOIN
     #GCP_PROJECT_ID.#APP_DATASET.estimated_backend_reward AS EBR
     ON
                 EBR.client_id = POS.client_id
             AND EBR.mfg_name = CPM.mfg_name
;
CREATE
TEMP TABLE
                   SSD AS
SELECT ORG.client_id
     , ORG.org_unit_id
     , OU.name AS store_name
     , COALESCE(GRP.market_coverage
    , 0)       AS market_coverage
     , COALESCE(ORG.sales_inventory
    , 0)       AS sales_inventory
     , COALESCE(ORG.sales_total
    , 0)       AS sales_total
     , CASE
           WHEN ORG.sales_total
               > 0 THEN ORG.sales_inventory / ORG.sales_total
           ELSE 0
    END        AS sales_pct
     , COALESCE(ORG.profit_inventory
    , 0)       AS profit_inventory
     , COALESCE(ORG.profit_total
    , 0)       AS profit_total
     , CASE
           WHEN ORG.profit_total
               > 0 THEN ORG.profit_inventory / ORG.profit_total
           ELSE 0
    END        AS profit_pct
     , COALESCE(ORG.inventory_cost
    , 0)       AS inventory_cost
     , COALESCE(ORG.unit_count
    , 0)       AS unit_count
     , COALESCE(ORG.avg_unit_count
    , 0)       AS avg_unit_count
     , CASE
           WHEN ORG.inventory_cost
               > 0 THEN ORG.profit_inventory / ORG.inventory_cost
           ELSE 0
    END        AS gmroi_units
     , CASE
           WHEN ORG.unit_count
               > 0 THEN ORG.sales_inventory / ORG.unit_count
           ELSE 0
    END        AS turns_units
     , COALESCE(ORG.sku_count
    , 0)       AS sku_count
     , COALESCE(ORG.avg_sku_count
    , 0)       AS avg_sku_count
     , CASE
           WHEN ORG.set_cost
               > 0 THEN ORG.profit_inventory / ORG.set_cost
           ELSE 0
    END        AS gmroi_skus
     , CASE
           WHEN ORG.sku_count
               > 0 THEN ORG.sales_inventory / (ORG.sku_count * 4)
           ELSE 0
    END        AS turns_skus
     , CASE
           WHEN ORG.sales_inventory
               > 0 THEN ORG.profit_inventory / ORG.sales_inventory
           ELSE 0
    END        AS margin_inventory
     , CASE
           WHEN ORG.retail_inventory
               > 0 THEN ORG.profit_inventory / ORG.retail_inventory
           ELSE 0
    END        AS margin_inventory_pct
     , CASE
           WHEN ORG.cost_inventory
               > 0 THEN ORG.profit_inventory / ORG.cost_inventory
           ELSE 0
    END        AS markup_inventory_pct
     , CASE
           WHEN ORG.sales_total
               > 0 THEN ORG.profit_total / ORG.sales_total
           ELSE 0
    END        AS margin_total
     , CASE
           WHEN ORG.retail_total
               > 0 THEN ORG.profit_total / ORG.retail_total
           ELSE 0
    END        AS margin_total_pct
     , CASE
           WHEN ORG.cost_total
               > 0 THEN ORG.profit_total / ORG.cost_total
           ELSE 0
    END        AS markup_total_pct
FROM (SELECT INV.client_id
           , INV.org_unit_id
           , SUM(INV.sales_inventory)  AS sales_inventory
           , SUM(INV.sales_total)      AS sales_total
           , SUM(INV.profit_inventory) AS profit_inventory
           , SUM(INV.profit_total)     AS profit_total
           , SUM(INV.cost_inventory)   AS cost_inventory
           , SUM(INV.cost_total)       AS cost_total
           , SUM(INV.retail_inventory) AS retail_inventory
           , SUM(INV.retail_total)     AS retail_total
           , SUM(INV.inventory_cost)   AS inventory_cost
           , SUM(INV.set_cost)         AS set_cost
           , SUM(INV.unit_count)       AS unit_count
           , SUM(INV.avg_unit_count)   AS avg_unit_count
           , SUM(INV.sku_count)        AS sku_count
           , SUM(INV.avg_sku_count)    AS avg_sku_count
      FROM (SELECT
                /* Client info */
                POS.client_id
                 , POS.org_unit_id
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE POS.store_units
              END                                       AS sales_inventory
                 , POS.store_units                      AS sales_total
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE POS.store_units * (COALESCE(LSP.retail
                                                   , POS.retail
                                                   , LAPP.retail
                                                   , LASP.retail
                                                   , LABP.retail) -
                                               COALESCE(LSP.cost
                                                   , POS.cost
                                                   , LAPP.cost
                                                   , LASP.cost
                                                   , LABP.cost))
              END                                       AS profit_inventory
                 , POS.store_units * (COALESCE(LSP.retail
                                          , POS.retail
                                          , LAPP.retail
                                          , LASP.retail
                                          , LABP.retail) -
                                      COALESCE(LSP.cost
                                          , POS.cost
                                          , LAPP.cost
                                          , LASP.cost
                                          , LABP.cost)) AS profit_total
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE POS.store_units * COALESCE(LSP.cost
                           , POS.cost
                           , LAPP.cost
                           , LASP.cost
                           , LABP.cost)
              END                                       AS cost_inventory
                 , POS.store_units * COALESCE(LSP.cost
              , POS.cost
              , LAPP.cost
              , LASP.cost
              , LABP.cost)                              AS cost_total
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE POS.store_units * COALESCE(LSP.retail
                           , POS.retail
                           , LAPP.retail
                           , LASP.retail
                           , LABP.retail)
              END                                       AS retail_inventory
                 , POS.store_units * COALESCE(LSP.retail
              , POS.retail
              , LAPP.retail
              , LASP.retail
              , LABP.retail)                            AS retail_total
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE COALESCE(LSP.cost
                                , POS.cost
                                , LAPP.cost
                                , LASP.cost
                                , LABP.cost) * QOH.avg_qoh
              END                                       AS inventory_cost
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE COALESCE(LSP.cost
                                , POS.cost
                                , LAPP.cost
                                , LASP.cost
                                , LABP.cost) * 4
              END                                       AS set_cost
                 , CASE
                       WHEN QOH.qoh IS NULL THEN 0
                       WHEN QOH.qoh <= 0 THEN 0
                       ELSE QOH.qoh
              END                                       AS unit_count
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE QOH.avg_qoh
              END                                       AS avg_unit_count
                 , CASE
                       WHEN QOH.qoh IS NULL THEN 0
                       WHEN QOH.qoh <= 0 THEN 0
                       ELSE 1
              END                                       AS sku_count
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE 1
              END                                       AS avg_sku_count
            FROM POS
                     LEFT JOIN
                 #GCP_PROJECT_ID.#CC_DATASET.inventory AS QOH
                 ON
                             QOH.client_id = POS.client_id
                         AND QOH.org_unit_id = POS.org_unit_id
                         AND QOH.ipm_id = POS.ipm_id
                     LEFT JOIN
                 #GCP_PROJECT_ID.#CC_DATASET.latest_store_prices AS LSP
                 ON
                             LSP.client_id = POS.client_id
                         AND LSP.org_unit_id = POS.org_unit_id
                         AND LSP.ipm_id = POS.ipm_id
                     LEFT JOIN
                 #GCP_PROJECT_ID.#CC_DATASET.latest_avg_product_price AS LAPP
                 ON
                     LAPP.ipm_id = POS.ipm_id
                     LEFT JOIN
                 #GCP_PROJECT_ID.#CC_DATASET.latest_avg_style_price AS LASP
                 ON
                             LASP.style = POS.style
                         AND LASP.mfg_name = POS.mfg_name
                     LEFT JOIN
                 #GCP_PROJECT_ID.#CC_DATASET.latest_avg_brand_price AS LABP
                 ON
                     LABP.brand = POS.mfg_name) AS INV
      GROUP BY INV.client_id
             , INV.org_unit_id) AS ORG
         INNER JOIN
     #GCP_PROJECT_ID.#APP_DATASET.org_unit AS OU
     ON
                 OU.client_id = ORG.client_id
             AND OU.org_unit_id = ORG.org_unit_id
         LEFT JOIN
     GRP
     ON
                 GRP.client_id = ORG.client_id
             AND GRP.org_unit_id = ORG.org_unit_id
WHERE OU.active = true
;
DELETE
FROM #GCP_PROJECT_ID.#CC_DATASET.store_summary_data
WHERE snapshot_date = CURRENT_DATE()
  AND #CLIENT_FILTER
  AND horizon = #HORIZON;

INSERT INTO #GCP_PROJECT_ID.#CC_DATASET.store_summary_data
SELECT CURRENT_DATE() AS snapshot_date
     , *
     , #HORIZON       as horizon

FROM SSD
;
CREATE
TEMP TABLE
                   MKT_AGG AS
SELECT MKT.client_id
     , MKT.org_unit_id
     , SUM(MKT.group_atd_units) AS total_atd_units
     , SUM(MKT.group_exp_tires) AS total_exp_tires
FROM #GCP_PROJECT_ID.#CC_DATASET.market_sales_#HORIZON AS MKT
GROUP BY MKT.client_id
       , MKT.org_unit_id
;
CREATE
TEMP TABLE
                   GRP_INV AS
SELECT INV.client_id
     , INV.org_unit_id
     , IPM.size_code
     , IPM.tier
     , IPM.tire_type
     , CASE
           WHEN MAX(INV.avg_qoh)
               > 0 THEN 1
           ELSE 0
    END AS group_stocked
FROM #GCP_PROJECT_ID.#CC_DATASET.inventory AS INV
         INNER JOIN
     #GCP_PROJECT_ID.ipm.industry_product_master AS IPM
     ON
         IPM.ipm_id = INV.ipm_id
GROUP BY INV.client_id
       , INV.org_unit_id
       , IPM.size_code
       , IPM.tier
       , IPM.tire_type
;
CREATE
TEMP TABLE
                   GRP AS
SELECT GRPD.client_id
     , GRPD.org_unit_id
     , CASE
           WHEN SUM(GRPD.group_market_demand) <= 0 THEN 0
           ELSE SUM(IF(GRP_INV.group_stocked = 1
               , GRPD.group_market_demand
               , 0)) / SUM(GRPD.group_market_demand)
    END AS market_coverage
FROM (SELECT MKT.client_id
           , MKT.org_unit_id
           , MKT.size_code
           , MKT.tier
           , MKT.tire_type
           , CASE
                 WHEN MKT_AGG.total_atd_units
                          > 0
                     AND MKT_AGG.total_exp_tires
                          > 0 THEN
                             (MKT.group_atd_units / MKT_AGG.total_atd_units) * 0.3 +
                             (MKT.group_exp_tires / MKT_AGG.total_exp_tires) * 0.7
                 WHEN MKT_AGG.total_atd_units
                     > 0 THEN (MKT.group_atd_units / MKT_AGG.total_atd_units) * 0.3
                 WHEN MKT_AGG.total_exp_tires
                     > 0 THEN (MKT.group_exp_tires / MKT_AGG.total_exp_tires) * 0.7
                 ELSE 0
        END AS group_market_demand
      FROM #GCP_PROJECT_ID.#CC_DATASET.market_sales_#HORIZON AS MKT
               LEFT JOIN
           MKT_AGG
           ON
                       MKT_AGG.client_id = MKT.client_id
                   AND MKT_AGG.org_unit_id = MKT.org_unit_id) AS GRPD
         LEFT JOIN
     GRP_INV
     ON
                 GRP_INV.client_id = GRPD.client_id
             AND GRP_INV.org_unit_id = GRPD.org_unit_id
             AND GRP_INV.size_code = GRPD.size_code
             AND GRP_INV.tier = GRPD.tier
             AND GRP_INV.tire_type = GRPD.tire_type
GROUP BY GRPD.client_id
       , GRPD.org_unit_id
;
CREATE
TEMP TABLE
                   CPM AS
SELECT OU.client_id
     , OU.org_unit_id
     , IPM.ipm_id
     , IPM.size_code
     , IPM.tier
     , IPM.tire_type
     , IPM.style
     , IPM.mfg_name
FROM #GCP_PROJECT_ID.ipm.industry_product_master AS IPM
         CROSS JOIN (SELECT DISTINCT client_id
                                   , org_unit_id
                     FROM #GCP_PROJECT_ID.#APP_DATASET.org_unit OU
                              LEFT JOIN
                          #GCP_PROJECT_ID.#APP_DATASET.store ST
                          ON
                                      ST.torqata_client_id = OU.client_id
                                  AND ST.torqata_org_unit_id = OU.org_unit_id
                     WHERE parent_id IS NOT NULL
                       AND (ST.vendor_id != 50
                  OR OU.org_unit_id IN (
                   SELECT
                   demo_org_unit_id
                   FROM
               #GCP_PROJECT_ID.#CC_DATASET.demo_org_unit_map))
                       AND #CLIENT_FILTER) AS OU;

CREATE
TEMP TABLE
                   POS AS
SELECT CPM.client_id
     , CPM.org_unit_id
     , CPM.ipm_id
     , CPM.size_code
     , CPM.tier
     , CPM.tire_type
     , CPM.style
     , CPM.mfg_name
     , COALESCE(POS.store_units
    , 0) AS store_units
     , CASE
           WHEN EBR.reward_mode = "dollars" THEN COALESCE(POS.store_profit + POS.store_units * EBR.reward_value
               , 0)
           WHEN EBR.reward_mode = "percent" THEN COALESCE(POS.store_profit * (1 + EBR.reward_value / 100)
               , 0)
           ELSE COALESCE(POS.store_profit
               , 0)
    END  AS store_profit
     , COALESCE(POS.total_cost
    , 0) AS total_cost
     , COALESCE(POS.total_retail
    , 0) AS total_retail
     , COALESCE(POS.cost
    , 0) AS cost
     , COALESCE(POS.retail
    , 0) AS retail
FROM CPM
         LEFT JOIN
     #GCP_PROJECT_ID.#CC_DATASET.pos_sales_#HORIZON AS POS
     ON
                 POS.client_id = CPM.client_id
             AND POS.org_unit_id = CPM.org_unit_id
             AND POS.ipm_id = CPM.ipm_id
         LEFT JOIN
     #GCP_PROJECT_ID.#APP_DATASET.estimated_backend_reward AS EBR
     ON
                 EBR.client_id = POS.client_id
             AND EBR.mfg_name = CPM.mfg_name
;
CREATE
TEMP TABLE
                   SSD AS
SELECT ORG.client_id
     , ORG.org_unit_id
     , OU.name AS store_name
     , COALESCE(GRP.market_coverage
    , 0)       AS market_coverage
     , COALESCE(ORG.sales_inventory
    , 0)       AS sales_inventory
     , COALESCE(ORG.sales_total
    , 0)       AS sales_total
     , CASE
           WHEN ORG.sales_total
               > 0 THEN ORG.sales_inventory / ORG.sales_total
           ELSE 0
    END        AS sales_pct
     , COALESCE(ORG.profit_inventory
    , 0)       AS profit_inventory
     , COALESCE(ORG.profit_total
    , 0)       AS profit_total
     , CASE
           WHEN ORG.profit_total
               > 0 THEN ORG.profit_inventory / ORG.profit_total
           ELSE 0
    END        AS profit_pct
     , COALESCE(ORG.inventory_cost
    , 0)       AS inventory_cost
     , COALESCE(ORG.unit_count
    , 0)       AS unit_count
     , COALESCE(ORG.avg_unit_count
    , 0)       AS avg_unit_count
     , CASE
           WHEN ORG.inventory_cost
               > 0 THEN ORG.profit_inventory / ORG.inventory_cost
           ELSE 0
    END        AS gmroi_units
     , CASE
           WHEN ORG.unit_count
               > 0 THEN ORG.sales_inventory / ORG.unit_count
           ELSE 0
    END        AS turns_units
     , COALESCE(ORG.sku_count
    , 0)       AS sku_count
     , COALESCE(ORG.avg_sku_count
    , 0)       AS avg_sku_count
     , CASE
           WHEN ORG.set_cost
               > 0 THEN ORG.profit_inventory / ORG.set_cost
           ELSE 0
    END        AS gmroi_skus
     , CASE
           WHEN ORG.sku_count
               > 0 THEN ORG.sales_inventory / (ORG.sku_count * 4)
           ELSE 0
    END        AS turns_skus
     , CASE
           WHEN ORG.sales_inventory
               > 0 THEN ORG.profit_inventory / ORG.sales_inventory
           ELSE 0
    END        AS margin_inventory
     , CASE
           WHEN ORG.retail_inventory
               > 0 THEN ORG.profit_inventory / ORG.retail_inventory
           ELSE 0
    END        AS margin_inventory_pct
     , CASE
           WHEN ORG.cost_inventory
               > 0 THEN ORG.profit_inventory / ORG.cost_inventory
           ELSE 0
    END        AS markup_inventory_pct
     , CASE
           WHEN ORG.sales_total
               > 0 THEN ORG.profit_total / ORG.sales_total
           ELSE 0
    END        AS margin_total
     , CASE
           WHEN ORG.retail_total
               > 0 THEN ORG.profit_total / ORG.retail_total
           ELSE 0
    END        AS margin_total_pct
     , CASE
           WHEN ORG.cost_total
               > 0 THEN ORG.profit_total / ORG.cost_total
           ELSE 0
    END        AS markup_total_pct
FROM (SELECT INV.client_id
           , INV.org_unit_id
           , SUM(INV.sales_inventory)  AS sales_inventory
           , SUM(INV.sales_total)      AS sales_total
           , SUM(INV.profit_inventory) AS profit_inventory
           , SUM(INV.profit_total)     AS profit_total
           , SUM(INV.cost_inventory)   AS cost_inventory
           , SUM(INV.cost_total)       AS cost_total
           , SUM(INV.retail_inventory) AS retail_inventory
           , SUM(INV.retail_total)     AS retail_total
           , SUM(INV.inventory_cost)   AS inventory_cost
           , SUM(INV.set_cost)         AS set_cost
           , SUM(INV.unit_count)       AS unit_count
           , SUM(INV.avg_unit_count)   AS avg_unit_count
           , SUM(INV.sku_count)        AS sku_count
           , SUM(INV.avg_sku_count)    AS avg_sku_count
      FROM (SELECT
                /* Client info */
                POS.client_id
                 , POS.org_unit_id
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE POS.store_units
              END                                       AS sales_inventory
                 , POS.store_units                      AS sales_total
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE POS.store_units * (COALESCE(LSP.retail
                                                   , POS.retail
                                                   , LAPP.retail
                                                   , LASP.retail
                                                   , LABP.retail) -
                                               COALESCE(LSP.cost
                                                   , POS.cost
                                                   , LAPP.cost
                                                   , LASP.cost
                                                   , LABP.cost))
              END                                       AS profit_inventory
                 , POS.store_units * (COALESCE(LSP.retail
                                          , POS.retail
                                          , LAPP.retail
                                          , LASP.retail
                                          , LABP.retail) -
                                      COALESCE(LSP.cost
                                          , POS.cost
                                          , LAPP.cost
                                          , LASP.cost
                                          , LABP.cost)) AS profit_total
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE POS.store_units * COALESCE(LSP.cost
                           , POS.cost
                           , LAPP.cost
                           , LASP.cost
                           , LABP.cost)
              END                                       AS cost_inventory
                 , POS.store_units * COALESCE(LSP.cost
              , POS.cost
              , LAPP.cost
              , LASP.cost
              , LABP.cost)                              AS cost_total
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE POS.store_units * COALESCE(LSP.retail
                           , POS.retail
                           , LAPP.retail
                           , LASP.retail
                           , LABP.retail)
              END                                       AS retail_inventory
                 , POS.store_units * COALESCE(LSP.retail
              , POS.retail
              , LAPP.retail
              , LASP.retail
              , LABP.retail)                            AS retail_total
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE COALESCE(LSP.cost
                                , POS.cost
                                , LAPP.cost
                                , LASP.cost
                                , LABP.cost) * QOH.avg_qoh
              END                                       AS inventory_cost
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE COALESCE(LSP.cost
                                , POS.cost
                                , LAPP.cost
                                , LASP.cost
                                , LABP.cost) * 4
              END                                       AS set_cost
                 , CASE
                       WHEN QOH.qoh IS NULL THEN 0
                       WHEN QOH.qoh <= 0 THEN 0
                       ELSE QOH.qoh
              END                                       AS unit_count
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE QOH.avg_qoh
              END                                       AS avg_unit_count
                 , CASE
                       WHEN QOH.qoh IS NULL THEN 0
                       WHEN QOH.qoh <= 0 THEN 0
                       ELSE 1
              END                                       AS sku_count
                 , CASE
                       WHEN QOH.avg_qoh IS NULL THEN 0
                       WHEN QOH.avg_qoh <= 0 THEN 0
                       ELSE 1
              END                                       AS avg_sku_count
            FROM POS
                     LEFT JOIN
                 #GCP_PROJECT_ID.#CC_DATASET.inventory AS QOH
                 ON
                             QOH.client_id = POS.client_id
                         AND QOH.org_unit_id = POS.org_unit_id
                         AND QOH.ipm_id = POS.ipm_id
                     LEFT JOIN
                 #GCP_PROJECT_ID.#CC_DATASET.latest_store_prices AS LSP
                 ON
                             LSP.client_id = POS.client_id
                         AND LSP.org_unit_id = POS.org_unit_id
                         AND LSP.ipm_id = POS.ipm_id
                     LEFT JOIN
                 #GCP_PROJECT_ID.#CC_DATASET.latest_avg_product_price AS LAPP
                 ON
                     LAPP.ipm_id = POS.ipm_id
                     LEFT JOIN
                 #GCP_PROJECT_ID.#CC_DATASET.latest_avg_style_price AS LASP
                 ON
                             LASP.style = POS.style
                         AND LASP.mfg_name = POS.mfg_name
                     LEFT JOIN
                 #GCP_PROJECT_ID.#CC_DATASET.latest_avg_brand_price AS LABP
                 ON
                     LABP.brand = POS.mfg_name) AS INV
      GROUP BY INV.client_id
             , INV.org_unit_id) AS ORG
         INNER JOIN
     #GCP_PROJECT_ID.#APP_DATASET.org_unit AS OU
     ON
                 OU.client_id = ORG.client_id
             AND OU.org_unit_id = ORG.org_unit_id
         LEFT JOIN
     GRP
     ON
                 GRP.client_id = ORG.client_id
             AND GRP.org_unit_id = ORG.org_unit_id
WHERE OU.active = true
;
DELETE
FROM #GCP_PROJECT_ID.#CC_DATASET.store_summary_data
WHERE snapshot_date = CURRENT_DATE()
  AND #CLIENT_FILTER
  AND horizon = #HORIZON;

INSERT INTO #GCP_PROJECT_ID.#CC_DATASET.store_summary_data
SELECT CURRENT_DATE() AS snapshot_date
     , *
     , #HORIZON       as horizon

FROM SSD
;
DROP TABLE SSD
;
DROP TABLE MKT_AGG
;
DROP TABLE GRP_INV
;
DROP TABLE GRP
;
DROP TABLE POS
;
DROP TABLE SSD
;
DROP TABLE MKT_AGG
;
DROP TABLE GRP_INV
;
DROP TABLE GRP
;
DROP TABLE POS
;
