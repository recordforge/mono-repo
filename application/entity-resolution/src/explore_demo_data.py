#!/usr/bin/env python3
"""
Explore and save Splink demo dataset for entity resolution testing.
"""

from splink import splink_datasets
import pandas as pd
import json
from pathlib import Path

def explore_demo_datasets():
    """Explore available demo datasets from Splink."""
    
    # Create data directory if it doesn't exist
    data_dir = Path("data")
    data_dir.mkdir(exist_ok=True)
    
    # Load the fake_1000 dataset - synthetic person records
    print("Loading fake_1000 dataset...")
    df_fake = splink_datasets.fake_1000
    
    print(f"\nDataset shape: {df_fake.shape}")
    print(f"Columns: {df_fake.columns.tolist()}")
    print(f"\nFirst 5 records:")
    print(df_fake.head())
    
    print(f"\nData types:")
    print(df_fake.dtypes)
    
    print(f"\nNull values:")
    print(df_fake.isnull().sum())
    
    # Check for duplicates
    print(f"\nNumber of unique IDs: {df_fake['unique_id'].nunique()}")
    print(f"Total records: {len(df_fake)}")
    
    # Save to CSV for inspection
    csv_path = data_dir / "fake_1000.csv"
    df_fake.to_csv(csv_path, index=False)
    print(f"\nDataset saved to: {csv_path}")
    
    # Save to Parquet for efficient loading
    parquet_path = data_dir / "fake_1000.parquet"
    df_fake.to_parquet(parquet_path, index=False)
    print(f"Dataset saved to: {parquet_path}")
    
    # Also explore historical_50k for a larger dataset
    print("\n" + "="*50)
    print("Loading historical_50k dataset...")
    df_historical = splink_datasets.historical_50k
    
    print(f"\nDataset shape: {df_historical.shape}")
    print(f"Columns: {df_historical.columns.tolist()}")
    print(f"\nFirst 5 records:")
    print(df_historical.head())
    
    # Save sample of historical dataset
    sample_path = data_dir / "historical_50k_sample.csv"
    df_historical.head(1000).to_csv(sample_path, index=False)
    print(f"\nSample (1000 records) saved to: {sample_path}")
    
    return df_fake, df_historical

if __name__ == "__main__":
    df_fake, df_historical = explore_demo_datasets()