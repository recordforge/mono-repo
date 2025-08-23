#!/usr/bin/env python3
"""
Entity resolution using Splink with PostgreSQL backend.
This script demonstrates how to use Splink with a PostgreSQL database.
"""

import pandas as pd
from pathlib import Path
import psycopg2
from sqlalchemy import create_engine
import splink.comparison_library as cl
from splink import PostgresAPI, Linker, SettingsCreator, block_on
import os

# PostgreSQL connection details
DB_CONFIG = {
    'host': os.getenv('POSTGRES_HOST', 'localhost'),
    'port': os.getenv('POSTGRES_PORT', '5432'),
    'database': os.getenv('POSTGRES_DB', 'dataplatform'),
    'user': os.getenv('POSTGRES_USER', 'dataplatform'),
    'password': os.getenv('POSTGRES_PASSWORD', 'dataplatform')
}

def get_postgres_connection_string():
    """Create PostgreSQL connection string."""
    return f"postgresql://{DB_CONFIG['user']}:{DB_CONFIG['password']}@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"

def load_data_to_postgres():
    """Load demo data into PostgreSQL."""
    print("Loading data into PostgreSQL...")
    
    # Load local data
    data_path = Path("data/fake_1000.parquet")
    if not data_path.exists():
        print("Demo data not found. Running explore script first...")
        from explore_demo_data import explore_demo_datasets
        df, _ = explore_demo_datasets()
    else:
        df = pd.read_parquet(data_path)
    
    # Create SQLAlchemy engine
    engine = create_engine(get_postgres_connection_string())
    
    # Load data to PostgreSQL
    table_name = "fake_persons"
    df.to_sql(table_name, engine, if_exists='replace', index=False)
    print(f"Loaded {len(df)} records to table '{table_name}'")
    
    return table_name

def create_splink_settings_postgres():
    """Create Splink settings for PostgreSQL backend."""
    
    settings = SettingsCreator(
        link_type="dedupe_only",
        
        comparisons=[
            cl.NameComparison("first_name", 
                             jaro_winkler_thresholds=[0.9, 0.8]).configure(
                                 term_frequency_adjustments=True),
            
            cl.JaroAtThresholds("surname", 
                               score_threshold_or_thresholds=[0.9, 0.7]).configure(
                                   term_frequency_adjustments=True),
            
            cl.DateOfBirthComparison("dob", 
                                    input_is_string=True,
                                    datetime_thresholds=[1, 1, 10],
                                    datetime_metrics=["month", "year", "year"]),
            
            cl.ExactMatch("city").configure(
                term_frequency_adjustments=True
            ),
            
            cl.EmailComparison("email"),
        ],
        
        blocking_rules_to_generate_predictions=[
            block_on("first_name", "surname"),
            block_on("surname", "dob"),
            block_on("email"),
            block_on("first_name", "city"),
        ],
        
        retain_intermediate_calculation_columns=True,
    )
    
    return settings

def train_model_postgres(linker):
    """Train the Splink model using PostgreSQL backend."""
    
    print("\n=== Training Model (PostgreSQL) ===")
    
    # Estimate baseline probability
    print("Estimating baseline match probability...")
    linker.training.estimate_probability_two_random_records_match(
        [block_on("first_name", "surname")],
        recall=0.7,
    )
    
    # Train with EM algorithm
    print("Training with expectation maximization...")
    linker.training.estimate_parameters_using_expectation_maximisation(
        block_on("first_name", "dob")
    )
    
    linker.training.estimate_parameters_using_expectation_maximisation(
        block_on("email")
    )
    
    print("Model training complete!")

def run_predictions_postgres(linker):
    """Generate predictions using PostgreSQL backend."""
    
    print("\n=== Generating Predictions (PostgreSQL) ===")
    
    pairwise_predictions = linker.inference.predict(
        threshold_match_weight=-10
    )
    
    # Convert to pandas for analysis
    predictions_df = pairwise_predictions.as_pandas_dataframe()
    print(f"Generated {len(predictions_df)} pairwise comparisons")
    
    high_confidence = predictions_df[predictions_df['match_probability'] > 0.9]
    print(f"Found {len(high_confidence)} high-confidence matches (>90% probability)")
    
    return pairwise_predictions

def create_clusters_postgres(linker, pairwise_predictions):
    """Create clusters using PostgreSQL backend."""
    
    print("\n=== Creating Clusters (PostgreSQL) ===")
    
    clusters = linker.clustering.cluster_pairwise_predictions_at_threshold(
        pairwise_predictions, 
        threshold_match_probability=0.90
    )
    
    clusters_df = clusters.as_pandas_dataframe()
    
    # Analyze clusters
    cluster_counts = clusters_df.groupby('cluster_id').size()
    multi_record_clusters = cluster_counts[cluster_counts > 1]
    
    print(f"Total clusters: {clusters_df['cluster_id'].nunique()}")
    print(f"Clusters with >1 record: {len(multi_record_clusters)}")
    print(f"Largest cluster size: {cluster_counts.max()}")
    
    # Save results
    output_path = Path("data/clusters_postgres.csv")
    clusters_df.to_csv(output_path, index=False)
    print(f"Saved to: {output_path}")
    
    return clusters_df

def test_postgres_connection():
    """Test PostgreSQL connection."""
    try:
        conn = psycopg2.connect(
            host=DB_CONFIG['host'],
            port=DB_CONFIG['port'],
            database=DB_CONFIG['database'],
            user=DB_CONFIG['user'],
            password=DB_CONFIG['password']
        )
        conn.close()
        print("✓ PostgreSQL connection successful")
        return True
    except Exception as e:
        print(f"✗ PostgreSQL connection failed: {e}")
        print("\nMake sure PostgreSQL is running:")
        print("  cd /workspaces/mono-repo/infrastructure/docker")
        print("  docker-compose -f postgres-compose.yml up -d")
        return False

def main():
    """Main pipeline for PostgreSQL-based entity resolution."""
    
    print("="*60)
    print("Entity Resolution with PostgreSQL Backend")
    print("="*60)
    
    # Test connection
    if not test_postgres_connection():
        return
    
    # Load data to PostgreSQL
    table_name = load_data_to_postgres()
    
    # Create settings
    settings = create_splink_settings_postgres()
    
    # Initialize linker with PostgreSQL backend
    print("\nInitializing Splink linker with PostgreSQL backend...")
    
    # Create PostgreSQL API connection
    postgres_api = PostgresAPI(
        connection=get_postgres_connection_string()
    )
    
    # Create linker
    linker = Linker(
        table_name,
        settings,
        postgres_api
    )
    
    # Train model
    train_model_postgres(linker)
    
    # Generate predictions
    pairwise_predictions = run_predictions_postgres(linker)
    
    # Create clusters
    clusters_df = create_clusters_postgres(linker, pairwise_predictions)
    
    # Generate reports
    print("\n=== Generating Reports ===")
    reports_dir = Path("reports")
    reports_dir.mkdir(exist_ok=True)
    
    params_chart = linker.visualisations.match_weights_chart()
    params_path = reports_dir / "match_weights_postgres.html"
    params_chart.to_html(params_path)
    print(f"Report saved to: {params_path}")
    
    print("\n" + "="*60)
    print("PostgreSQL entity resolution pipeline complete!")
    print("="*60)
    
    return linker, clusters_df

if __name__ == "__main__":
    linker, clusters = main()