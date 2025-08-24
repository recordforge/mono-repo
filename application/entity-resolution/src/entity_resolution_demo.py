#!/usr/bin/env python3
"""
Entity resolution demo using Splink library with fake_1000 dataset.
This script demonstrates the full pipeline: data loading, model training, and clustering.
"""

import pandas as pd
from pathlib import Path
import splink.comparison_library as cl
from splink import DuckDBAPI, Linker, SettingsCreator, block_on, splink_datasets

def load_demo_data():
    """Load the fake_1000 demo dataset."""
    print("Loading demo dataset...")
    
    # Check if we have a local copy
    data_path = Path("data/fake_1000.parquet")
    if data_path.exists():
        print(f"Loading from local file: {data_path}")
        df = pd.read_parquet(data_path)
    else:
        print("Loading from splink_datasets...")
        df = splink_datasets.fake_1000
        
        # Save for future use
        data_path.parent.mkdir(exist_ok=True)
        df.to_parquet(data_path)
        print(f"Saved to: {data_path}")
    
    print(f"Loaded {len(df)} records with columns: {df.columns.tolist()}")
    return df

def create_splink_settings():
    """Create Splink settings configuration for entity resolution."""
    
    settings = SettingsCreator(
        link_type="dedupe_only",  # We're deduplicating a single dataset
        
        # Define comparison functions for each field
        comparisons=[
            # Name comparisons with fuzzy matching
            cl.NameComparison("first_name", 
                             jaro_winkler_thresholds=[0.9, 0.8]).configure(
                                 term_frequency_adjustments=True),
            
            cl.JaroAtThresholds("surname", 
                               score_threshold_or_thresholds=[0.9, 0.7]).configure(
                                   term_frequency_adjustments=True),
            
            # Date of birth - exact and nearby dates
            cl.DateOfBirthComparison("dob", 
                                    input_is_string=True,
                                    datetime_thresholds=[1, 1, 10],  # 1 month, 1 year, 10 years
                                    datetime_metrics=["month", "year", "year"]),
            
            # City with term frequency adjustments
            cl.ExactMatch("city").configure(
                term_frequency_adjustments=True
            ),
            
            # Email comparison
            cl.EmailComparison("email"),
        ],
        
        # Blocking rules to reduce comparisons
        blocking_rules_to_generate_predictions=[
            block_on("first_name", "surname"),  # Same first and last name
            block_on("surname", "dob"),  # Same surname and DOB
            block_on("email"),  # Same email
            block_on("first_name", "city"),  # Same first name and city
        ],
        
        retain_intermediate_calculation_columns=True,
    )
    
    return settings

def train_model(linker):
    """Train the Splink model using expectation maximization."""
    
    print("\n=== Training Model ===")
    
    # Step 1: Estimate probability two random records match
    print("Estimating baseline match probability...")
    linker.training.estimate_probability_two_random_records_match(
        [block_on("first_name", "surname")],
        recall=0.7,
    )
    
    # Step 2: Train using expectation maximization
    print("Training with expectation maximization...")
    
    # Train on different blocking rules
    training_blocking_rules = [
        block_on("first_name", "dob"),  # People with same first name and DOB
        block_on("email"),  # Same email is strong signal
    ]
    
    linker.training.estimate_parameters_using_expectation_maximisation(
        training_blocking_rules[0]
    )
    
    linker.training.estimate_parameters_using_expectation_maximisation(
        training_blocking_rules[1]
    )
    
    print("Model training complete!")

def run_predictions(linker):
    """Generate pairwise predictions and cluster results."""
    
    print("\n=== Generating Predictions ===")
    
    # Generate pairwise predictions
    print("Computing pairwise match probabilities...")
    pairwise_predictions = linker.inference.predict(
        threshold_match_weight=-10  # Lower threshold to see more potential matches
    )
    
    # Convert to pandas for inspection
    predictions_df = pairwise_predictions.as_pandas_dataframe()
    print(f"Generated {len(predictions_df)} pairwise comparisons")
    
    # Show sample of high-confidence matches
    high_confidence = predictions_df[predictions_df['match_probability'] > 0.9]
    print(f"Found {len(high_confidence)} high-confidence matches (>90% probability)")
    
    if len(high_confidence) > 0:
        print("\nSample high-confidence matches:")
        sample = high_confidence.head(3)[['unique_id_l', 'unique_id_r', 'match_probability']]
        print(sample)
    
    return pairwise_predictions

def create_clusters(linker, pairwise_predictions):
    """Create entity clusters from pairwise predictions."""
    
    print("\n=== Creating Clusters ===")
    
    # Cluster at different thresholds
    thresholds = [0.95, 0.90, 0.80]
    
    for threshold in thresholds:
        clusters = linker.clustering.cluster_pairwise_predictions_at_threshold(
            pairwise_predictions, 
            threshold_match_probability=threshold
        )
        
        clusters_df = clusters.as_pandas_dataframe()
        
        # Count clusters
        cluster_counts = clusters_df.groupby('cluster_id').size()
        multi_record_clusters = cluster_counts[cluster_counts > 1]
        
        print(f"\nThreshold {threshold}:")
        print(f"  Total clusters: {clusters_df['cluster_id'].nunique()}")
        print(f"  Clusters with >1 record: {len(multi_record_clusters)}")
        print(f"  Largest cluster size: {cluster_counts.max()}")
        
        # Save clusters for this threshold
        output_path = Path(f"data/clusters_threshold_{threshold}.csv")
        clusters_df.to_csv(output_path, index=False)
        print(f"  Saved to: {output_path}")
    
    return clusters_df

def generate_reports(linker):
    """Generate diagnostic reports and visualizations."""
    
    print("\n=== Generating Reports ===")
    
    # Create reports directory
    reports_dir = Path("reports")
    reports_dir.mkdir(exist_ok=True)
    
    # 1. Model parameters report
    print("Generating model parameters report...")
    params_chart = linker.visualisations.match_weights_chart()
    params_path = reports_dir / "match_weights.html"
    params_chart.save(str(params_path))
    print(f"  Saved to: {params_path}")
    
    # 2. Waterfall chart (shows how match weights accumulate)
    print("Generating waterfall chart...")
    # Get sample pairs for waterfall visualization
    waterfall_chart = linker.visualisations.waterfall_chart(
        linker.inference.predict(threshold_match_weight=0).as_record_dict(limit=1)
    )
    waterfall_path = reports_dir / "waterfall_chart.html"
    waterfall_chart.save(str(waterfall_path))
    print(f"  Saved to: {waterfall_path}")
    
    print("\nReports generated! Open HTML files in browser to view.")

def main():
    """Main pipeline for entity resolution."""
    
    print("="*60)
    print("Entity Resolution Demo with Splink")
    print("="*60)
    
    # Load data
    df = load_demo_data()
    
    # Create settings
    settings = create_splink_settings()
    
    # Initialize linker with DuckDB backend
    print("\nInitializing Splink linker with DuckDB backend...")
    linker = Linker(df, settings, DuckDBAPI())
    
    # Train model
    train_model(linker)
    
    # Generate predictions
    pairwise_predictions = run_predictions(linker)
    
    # Create clusters
    clusters_df = create_clusters(linker, pairwise_predictions)
    
    # Generate reports
    generate_reports(linker)
    
    print("\n" + "="*60)
    print("Entity resolution pipeline complete!")
    print("Check the 'data' directory for results and 'reports' for visualizations.")
    print("="*60)
    
    return linker, clusters_df

if __name__ == "__main__":
    linker, clusters = main()