#!/usr/bin/env python3
"""
Script to seed PostgreSQL with test data from Splink demo dataset
"""
import csv
import psycopg2
from psycopg2.extras import execute_batch
from datetime import datetime
import os
import sys

# Database connection parameters
DB_CONFIG = {
    'host': os.getenv('POSTGRES_HOST', 'localhost'),
    'port': os.getenv('POSTGRES_PORT', '5432'),
    'database': os.getenv('POSTGRES_DB', 'dataplatform'),
    'user': os.getenv('POSTGRES_USER', 'dataplatform'),
    'password': os.getenv('POSTGRES_PASSWORD', 'dataplatform')
}

def load_splink_data(conn, csv_path):
    """Load Splink demo data into PostgreSQL"""
    cur = conn.cursor()
    
    # Clear existing data
    cur.execute("TRUNCATE raw.person_records RESTART IDENTITY CASCADE;")
    
    # Read CSV and prepare data
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        records = []
        
        for row in reader:
            # Handle empty values and date formatting
            record = (
                int(row['unique_id']),
                row['first_name'].strip() if row['first_name'].strip() else None,
                row['surname'].strip() if row['surname'].strip() else None,
                row['dob'] if row['dob'] else None,
                row['city'].strip() if row['city'].strip() else None,
                row['email'].strip() if row['email'].strip() else None,
                int(row['cluster']) if row['cluster'] else None
            )
            records.append(record)
    
    # Insert data using batch execution for better performance
    insert_query = """
        INSERT INTO raw.person_records 
        (unique_id, first_name, surname, dob, city, email, cluster)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (unique_id) DO NOTHING;
    """
    
    execute_batch(cur, insert_query, records, page_size=100)
    conn.commit()
    
    # Get count of inserted records
    cur.execute("SELECT COUNT(*) FROM raw.person_records;")
    count = cur.fetchone()[0]
    
    print(f"✓ Successfully loaded {count} records into raw.person_records")
    
    # Show sample data
    cur.execute("SELECT * FROM raw.person_records LIMIT 5;")
    print("\nSample data:")
    for row in cur.fetchall():
        print(f"  {row}")
    
    cur.close()

def main():
    """Main function"""
    csv_path = 'fixtures/test-data/fake_1000_from_splink_demos.csv'
    
    if not os.path.exists(csv_path):
        print(f"Error: Test data file not found at {csv_path}")
        print("Please ensure the test data has been downloaded from Splink repository")
        sys.exit(1)
    
    try:
        # Connect to PostgreSQL
        print("Connecting to PostgreSQL...")
        conn = psycopg2.connect(**DB_CONFIG)
        print("✓ Connected successfully")
        
        # Load data
        print("\nLoading Splink test data...")
        load_splink_data(conn, csv_path)
        
        # Close connection
        conn.close()
        print("\n✓ Data seeding completed successfully!")
        
    except psycopg2.Error as e:
        print(f"Database error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()