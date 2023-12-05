CREATE TEMP TABLE
  STORE_ZIP_VOLUME AS
WITH
  STORE_SALES AS (
  SELECT
    org_unit_id,
    SUM(units_sold) AS store_sales
  FROM
    #GCP_PROJECT_ID.#CC_DATASET.transactions_#HORIZON
  WHERE
    vendor_id NOT IN (50)
  GROUP BY
    org_unit_id)
SELECT
    POS.client_id,
    POS.org_unit_id,
    POS.zip_code,
    ROUND(SUM(POS.units_sold) / MAX(SS.store_sales), 3) AS units_sold_pct
FROM (
         SELECT
             TXN.client_id,
             TXN.org_unit_id,
             COALESCE(SUBSTR(MZC.zip_code, 0, 5), TXN.customer_zipcode) AS zip_code,
             TXN.units_sold
         FROM
             #GCP_PROJECT_ID.#CC_DATASET.transactions_#HORIZON TXN
                 INNER JOIN
             #GCP_PROJECT_ID.#APP_DATASET.org_unit OU
             ON
                     OU.org_unit_id = TXN.org_unit_id
                 LEFT JOIN
             #GCP_PROJECT_ID.#APP_DATASET.market_zip_codes MZC
             ON
                         MZC.client_id = TXN.client_id
                     AND MZC.org_unit_id = TXN.org_unit_id
                     AND SUBSTR(MZC.zip_code, 0, 5) = TXN.customer_zipcode
         WHERE
                 OU.active = true
           AND TXN.vendor_id NOT IN (50) ) POS
         LEFT JOIN
     STORE_SALES SS
     ON
             SS.org_unit_id = POS.org_unit_id
GROUP BY
    POS.client_id,
    POS.org_unit_id,
    POS.zip_code;

CREATE OR REPLACE TABLE
    #GCP_PROJECT_ID.#CC_DATASET.market_sales_#HORIZON AS
SELECT
    SZV.client_id,
    SZV.org_unit_id,
    MSD.size_code,
    MSD.tier,
    MSD.tire_type,
    SUM(MSD.atd_units * COALESCE(SZV.units_sold_pct, 1)) AS group_atd_units,
    SUM(MSD.exp_tires * COALESCE(SZV.units_sold_pct, 1)) AS group_exp_tires
FROM
    STORE_ZIP_VOLUME SZV
        INNER JOIN
    #GCP_PROJECT_ID.polk_data.market_sales_data MSD
    ON
            MSD.zip_code = SZV.zip_code
WHERE
    CASE
        WHEN #HORIZON != 12 THEN MSD.date BETWEEN #FIRST_OF_NEXT_MONTH AND DATE_SUB(DATE_ADD(#FIRST_OF_NEXT_MONTH, INTERVAL #HORIZON MONTH), INTERVAL 1 DAY)
        ELSE 1 = 1
        END
GROUP BY
    SZV.client_id,
    SZV.org_unit_id,
    MSD.size_code,
    MSD.tier,
    MSD.tire_type;


DROP TABLE STORE_ZIP_VOLUME;
Brandon
Brandon Braner
pos nation avg price

CREATE TEMP TABLE national_avg_price (
  month_period INT64,
  zip_code STRING,
  zip3 INT64,
  mfg_name STRING,
  ipm_id STRING,
  distance INT64,
  size_code STRING,
  count_unique_stores INT64,
  total_units_sold FLOAT64,
  unit_retail_normalized FLOAT64,
  margin_dollar_normalized FLOAT64
);

FOR lookback IN (
  SELECT lookback_period
  FROM UNNEST ([1, 3, 6, 12]) AS lookback_period
) DO
INSERT INTO national_avg_price WITH TXN_ZIP AS (
    SELECT TXN.customer_zipcode,
      TXN.org_unit_id,
      IPM.mfg_name,
      IPM.size_code,
      TXN.ipm_id,
      TT.market_insights_tire_type,
      SUM(units_sold) AS total_units_sold,
      SUM(ext_retail) AS total_retail,
      SUM(ext_retail) / SUM(units_sold) AS volume_weighted_unit_retail,
      (SUM(ext_retail) - SUM(ext_cost)) / SUM(units_sold) AS volume_weighted_margin,
      SUM(ext_cost) AS total_unit_cost,
      COUNT(TXN.date) AS count_observations
    FROM #GCP_PROJECT_ID.#CC_DATASET.transactions_12 TXN
      LEFT JOIN #GCP_PROJECT_ID.ipm.industry_product_master IPM ON IPM.ipm_id = TXN.ipm_id
      LEFT JOIN #GCP_PROJECT_ID.reporting_datasets.tire_types TT ON TT.tire_type = IPM.tire_type
    WHERE TXN.date > DATE_SUB(
        CURRENT_DATE(),
        INTERVAL lookback.lookback_period MONTH
      )
      AND vendor_id != 9999
    GROUP BY TXN.customer_zipcode,
      IPM.mfg_name,
      IPM.size_code,
      TXN.ipm_id,
      TXN.org_unit_id,
      TT.market_insights_tire_type
  ),
  ZIP_TABLE AS (
    SELECT ZIP_TABLE.zip_code,
      CAST(SUBSTR(ZIP_TABLE.zip_code, 0, 3) AS INT) AS zip3,
      store_count,
      zip_count,
      candidate_zip,
      pass_5store_check,
      pass_10store_check,
      distance
    FROM #GCP_PROJECT_ID.reporting_datasets.zip_radius ZIP_TABLE
      CROSS JOIN UNNEST (zip_array) AS candidate_zip
    WHERE snapshot_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH)
      AND snapshot_date = (
        SELECT MAX(snapshot_date)
        FROM #GCP_PROJECT_ID.reporting_datasets.zip_radius
        WHERE snapshot_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH)
      )
  ),
  FINAL_POS_TABLE AS (
    SELECT ZIP_TABLE.zip_code,
      ZIP_TABLE.zip3,
      ZIP_TABLE.zip_count,
      ZIP_TABLE.distance,
      ZIP_TABLE.store_count,
      TXN_ZIP.org_unit_id,
      pass_5store_check,
      pass_10store_check,
      TXN_ZIP.mfg_name,
      TXN_ZIP.ipm_id,
      TXN_ZIP.size_code,
      TXN_ZIP.market_insights_tire_type,
      TXN_ZIP.count_observations,
      total_units_sold,
      total_retail,
      total_unit_cost,
      volume_weighted_unit_retail,
      volume_weighted_margin
    FROM ZIP_TABLE
      LEFT JOIN TXN_ZIP ON TXN_ZIP.customer_zipcode = ZIP_TABLE.candidate_zip
    WHERE org_unit_id is not null
  ),
  WEIGHT_TABLE AS (
    SELECT zip_code,
      zip3,
      mfg_name,
      ipm_id,
      distance,
      size_code,
      org_unit_id,
      total_units_sold,
      total_retail,
      SUM(total_units_sold) OVER(
        PARTITION BY zip_code,
        zip3,
        mfg_name,
        ipm_id,
        distance,
        size_code
      ) AS total_units_per_group,
      total_units_sold / SUM(total_units_sold) OVER(
        PARTITION BY zip_code,
        zip3,
        mfg_name,
        ipm_id,
        distance,
        size_code
      ) AS weight,
      volume_weighted_unit_retail,
      volume_weighted_margin,
      COUNT(*) OVER (
        PARTITION BY zip_code,
        zip3,
        mfg_name,
        ipm_id,
        distance,
        size_code
      ) AS group_size,
      FROM FINAL_POS_TABLE
  ),
  NEW_WEIGHT_TABLE AS (
    SELECT *,
      CASE
        WHEN (weight >= 0.2) AND (group_size >= 5) THEN 0.2
        WHEN MAX(weight) OVER(
          PARTITION BY zip_code,
          zip3,
          mfg_name,
          ipm_id,
          distance,
          size_code
        ) >= 0.2
        AND (group_size >= 5) THEN (1 / group_size)
        ELSE weight
      END AS new_weight
    FROM WEIGHT_TABLE
  ),
  FINAL_NORMALIZED_TABLE AS (
    SELECT *,
      new_weight / (
        SUM(new_weight) OVER (
          PARTITION BY zip_code,
          zip3,
          mfg_name,
          ipm_id,
          distance,
          size_code
        )
      ) AS new_weight_normalized,
      (
        new_weight / (
          SUM(new_weight) OVER (
            PARTITION BY zip_code,
            zip3,
            mfg_name,
            ipm_id,
            distance,
            size_code
          )
        )
      ) * volume_weighted_unit_retail AS unit_retail_norm,
      (
        new_weight / (
          SUM(new_weight) OVER (
            PARTITION BY zip_code,
            zip3,
            mfg_name,
            ipm_id,
            distance,
            size_code
          )
        )
      ) * volume_weighted_margin AS margin_dollar_norm
    FROM NEW_WEIGHT_TABLE
  )
SELECT lookback.lookback_period AS month_period,
       zip_code,
       zip3,
       mfg_name,
       ipm_id,
       distance,
       size_code,
       COUNT(DISTINCT(org_unit_id)) AS count_unique_stores,
       SUM(total_units_sold) AS total_units_sold,
       SUM(unit_retail_norm) AS unit_retail_normalized,
       SUM(margin_dollar_norm) AS margin_dollar_normalized
FROM FINAL_NORMALIZED_TABLE
GROUP BY zip_code,
         zip3,
         mfg_name,
         ipm_id,
         distance,
         size_code
HAVING count_unique_stores >= 5;
END FOR;

CREATE OR REPLACE TABLE #GCP_PROJECT_ID.#CC_DATASET.pos_national_avg_price AS
SELECT *
FROM national_avg_price;

DROP TABLE national_avg_price;
