#!/usr/bin/env python3
"""
Sample Data Generator for AWS Data Lake Demo
Generates sales data and uploads to S3 raw bucket with partitioning
"""

import boto3
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json
import os
import sys
from pathlib import Path

def generate_sales_data(num_records=1000):
    """Generate sample sales data"""
    print(f"Generating {num_records} sales records...")
    
    # Generate date range for the last 30 days
    end_date = datetime.now()
    start_date = end_date - timedelta(days=30)
    date_range = pd.date_range(start=start_date, end=end_date, freq='D')
    
    # Sample data
    products = ['Laptop', 'Phone', 'Tablet', 'Headphones', 'Monitor', 'Keyboard', 'Mouse', 'Speaker']
    regions = ['US-East', 'US-West', 'EU-West', 'Asia-Pacific', 'South-America']
    payment_methods = ['Credit Card', 'Debit Card', 'PayPal', 'Bank Transfer', 'Cash']
    
    data = []
    for i in range(num_records):
        # Random date within range
        sale_date = np.random.choice(date_range)
        
        # Convert numpy.datetime64 to Python datetime for strftime
        py_date = pd.Timestamp(sale_date).to_pydatetime()
        
        # Generate record
        record = {
            'sale_id': f"SALE-{i+1:06d}",
            'customer_id': f"CUST-{np.random.randint(1000, 9999):04d}",
            'product_name': np.random.choice(products),
            'quantity': np.random.randint(1, 10),
            'unit_price': round(np.random.uniform(50, 2000), 2),
            'total_amount': 0,  # Will be calculated
            'region': np.random.choice(regions),
            'payment_method': np.random.choice(payment_methods),
            'sale_date': py_date.strftime('%Y-%m-%d'),
            'sale_timestamp': py_date.isoformat(),
            'year': py_date.year,
            'month': py_date.month,
            'day': py_date.day
        }
        
        # Calculate total amount
        record['total_amount'] = round(record['quantity'] * record['unit_price'], 2)
        
        data.append(record)
    
    return pd.DataFrame(data)

def upload_to_s3(df, bucket_name, s3_client):
    """Upload data to S3 with partitioning"""
    print(f"Uploading data to S3 bucket: {bucket_name}")
    
    # Group by date for partitioning
    for (year, month, day), group in df.groupby(['year', 'month', 'day']):
        # Create partitioned path
        partition_path = f"year={year}/month={month:02d}/day={day:02d}"
        
        # Convert to JSON and CSV formats
        json_data = group.to_json(orient='records', lines=True)
        csv_data = group.to_csv(index=False)
        
        # Upload JSON file
        json_key = f"raw/{partition_path}/sales_data.json"
        s3_client.put_object(
            Bucket=bucket_name,
            Key=json_key,
            Body=json_data,
            ContentType='application/json'
        )
        print(f"Uploaded: {json_key}")
        
        # Upload CSV file
        csv_key = f"raw/{partition_path}/sales_data.csv"
        s3_client.put_object(
            Bucket=bucket_name,
            Key=csv_key,
            Body=csv_data,
            ContentType='text/csv'
        )
        print(f"Uploaded: {csv_key}")
    
    print(f"Successfully uploaded {len(df)} records to S3")

def create_scripts_folder(bucket_name, s3_client):
    """Create scripts folder in S3 and upload ETL script"""
    print("Creating scripts folder in S3...")
    
    # Read the ETL script
    script_path = Path(__file__).parent / "glue_etl_job.py"
    if script_path.exists():
        with open(script_path, 'r') as f:
            script_content = f.read()
        
        # Upload ETL script
        script_key = "scripts/glue_etl_job.py"
        s3_client.put_object(
            Bucket=bucket_name,
            Key=script_key,
            Body=script_content,
            ContentType='text/plain'
        )
        print(f"Uploaded ETL script: {script_key}")
    else:
        print("Warning: ETL script not found")

def main():
    """Main function"""
    # Get bucket name from environment or command line
    bucket_name = os.getenv('RAW_BUCKET_NAME')
    if not bucket_name:
        if len(sys.argv) > 1:
            bucket_name = sys.argv[1]
        else:
            print("Usage: python generate_data.py <raw_bucket_name>")
            print("Or set RAW_BUCKET_NAME environment variable")
            sys.exit(1)
    
    try:
        # Initialize S3 client
        s3_client = boto3.client('s3')
        
        # Check if bucket exists
        try:
            s3_client.head_bucket(Bucket=bucket_name)
        except Exception as e:
            print(f"Error: Bucket {bucket_name} not found or not accessible")
            print(f"Error details: {e}")
            sys.exit(1)
        
        # Generate sample data
        df = generate_sales_data(1000)
        
        # Upload to S3
        upload_to_s3(df, bucket_name, s3_client)
        
        # Create scripts folder and upload ETL script
        create_scripts_folder(bucket_name, s3_client)
        
        print("\n=== Data Generation Complete ===")
        print(f"Generated {len(df)} sales records")
        print(f"Uploaded to: s3://{bucket_name}/raw/")
        print("Data is partitioned by year/month/day")
        print("Formats: JSON and CSV")
        
        # Print sample data statistics
        print("\n=== Sample Data Statistics ===")
        print(f"Date range: {df['sale_date'].min()} to {df['sale_date'].max()}")
        print(f"Total sales amount: ${df['total_amount'].sum():,.2f}")
        print(f"Average order value: ${df['total_amount'].mean():.2f}")
        print(f"Products sold: {df['product_name'].nunique()}")
        print(f"Regions: {df['region'].nunique()}")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
