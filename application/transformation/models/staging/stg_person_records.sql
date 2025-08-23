{{
    config(
        materialized='view'
    )
}}

-- Staging layer: Clean and standardize raw person records
SELECT
    unique_id,
    LOWER(TRIM(first_name)) as first_name,
    LOWER(TRIM(surname)) as surname,
    dob,
    LOWER(TRIM(city)) as city,
    LOWER(TRIM(email)) as email,
    cluster,
    CURRENT_TIMESTAMP as loaded_at
FROM {{ source('raw', 'person_records') }}
WHERE unique_id IS NOT NULL