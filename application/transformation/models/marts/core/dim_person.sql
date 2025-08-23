{{
    config(
        materialized='table',
        indexes=[
          {'columns': ['person_id'], 'unique': True},
          {'columns': ['email']},
          {'columns': ['cluster_id']}
        ]
    )
}}

-- Core dimension: Person master data
WITH staged AS (
    SELECT * FROM {{ ref('stg_person_records') }}
),

ranked AS (
    SELECT
        unique_id as person_id,
        first_name,
        surname,
        CONCAT(first_name, ' ', surname) as full_name,
        dob,
        DATE_PART('year', AGE(CURRENT_DATE, dob)) as age,
        city,
        email,
        cluster as cluster_id,
        loaded_at,
        CURRENT_TIMESTAMP as created_at,
        CURRENT_TIMESTAMP as updated_at,
        ROW_NUMBER() OVER (
            PARTITION BY cluster, email 
            ORDER BY loaded_at DESC
        ) as rn
    FROM staged
),

deduplicated AS (
    SELECT 
        person_id,
        first_name,
        surname,
        full_name,
        dob,
        age,
        city,
        email,
        cluster_id,
        loaded_at,
        created_at,
        updated_at
    FROM ranked
    WHERE rn = 1
)

SELECT * FROM deduplicated