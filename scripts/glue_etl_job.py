#!/usr/bin/env python3
"""
AWS Glue ETL Job for Data Lake Processing
Converts raw CSV/JSON data to optimized Parquet format with partitioning
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import *
from pyspark.sql.types import *
import boto3
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Glue context
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'raw_bucket',
    'processed_bucket',
    'archive_bucket'
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Get bucket names from arguments
raw_bucket = args['raw_bucket']
processed_bucket = args['processed_bucket']
archive_bucket = args['archive_bucket']

logger.info(f"Processing data from s3://{raw_bucket}/raw/")
logger.info(f"Output to s3://{processed_bucket}/processed/")

def process_sales_data():
    """Process sales data from raw to processed format"""
    
    # Read raw data from S3
    raw_path = f"s3://{raw_bucket}/raw/"
    logger.info(f"Reading raw data from: {raw_path}")
    
    # Create dynamic frame from raw data
    raw_dyf = glueContext.create_dynamic_frame.from_options(
        connection_type="s3",
        connection_options={
            "paths": [raw_path],
            "recurse": True
        },
        format="json"
    )
    
    logger.info(f"Found {raw_dyf.count()} records in raw data")
    
    # Convert to Spark DataFrame for easier processing
    df = raw_dyf.toDF()
    
    if df.count() == 0:
        logger.warning("No data found in raw bucket")
        return
    
    # Show schema
    logger.info("Raw data schema:")
    df.printSchema()
    
    # Data transformations
    logger.info("Applying data transformations...")
    
    # Add processing timestamp
    df = df.withColumn("processing_timestamp", current_timestamp())
    
    # Add data quality checks
    df = df.withColumn("is_valid", 
                       when(col("sale_id").isNotNull() & 
                            col("total_amount").isNotNull() & 
                            (col("total_amount") > 0), True).otherwise(False))
    
    # Add derived columns
    df = df.withColumn("profit_margin", 
                       when(col("total_amount") > 0, 
                            round((col("total_amount") * 0.15), 2)).otherwise(0))
    
    df = df.withColumn("customer_segment",
                       when(col("total_amount") >= 1000, "Premium")
                       .when(col("total_amount") >= 500, "Standard")
                       .otherwise("Basic"))
    
    # Add month name for easier querying
    df = df.withColumn("month_name", 
                       date_format(to_date(col("sale_date"), "yyyy-MM-dd"), "MMMM"))
    
    # Add quarter
    df = df.withColumn("quarter", 
                       quarter(to_date(col("sale_date"), "yyyy-MM-dd")))
    
    # Add day of week
    df = df.withColumn("day_of_week", 
                       date_format(to_date(col("sale_date"), "yyyy-MM-dd"), "EEEE"))
    
    # Filter out invalid records
    valid_df = df.filter(col("is_valid") == True)
    invalid_df = df.filter(col("is_valid") == False)
    
    logger.info(f"Valid records: {valid_df.count()}")
    logger.info(f"Invalid records: {invalid_df.count()}")
    
    # Write processed data with partitioning
    logger.info("Writing processed data to S3...")
    
    # Write valid records to processed bucket
    processed_path = f"s3://{processed_bucket}/processed/sales/"
    
    valid_df.write \
        .mode("overwrite") \
        .partitionBy("year", "month", "day") \
        .option("compression", "snappy") \
        .parquet(processed_path)
    
    logger.info(f"Processed data written to: {processed_path}")
    
    # Write invalid records to archive for review
    if invalid_df.count() > 0:
        archive_path = f"s3://{archive_bucket}/invalid_records/"
        invalid_df.write \
            .mode("append") \
            .partitionBy("year", "month", "day") \
            .parquet(archive_path)
        logger.info(f"Invalid records archived to: {archive_path}")
    
    # Create summary statistics
    create_summary_stats(valid_df, processed_bucket)
    
    return valid_df

def create_summary_stats(df, bucket_name):
    """Create summary statistics for the processed data"""
    logger.info("Creating summary statistics...")
    
    # Daily sales summary
    daily_summary = df.groupBy("year", "month", "day", "sale_date") \
        .agg(
            count("*").alias("total_orders"),
            sum("total_amount").alias("total_sales"),
            avg("total_amount").alias("avg_order_value"),
            countDistinct("customer_id").alias("unique_customers"),
            countDistinct("product_name").alias("products_sold")
        ) \
        .orderBy("sale_date")
    
    # Product summary
    product_summary = df.groupBy("product_name") \
        .agg(
            count("*").alias("units_sold"),
            sum("total_amount").alias("revenue"),
            avg("unit_price").alias("avg_unit_price")
        ) \
        .orderBy(desc("revenue"))
    
    # Region summary
    region_summary = df.groupBy("region") \
        .agg(
            count("*").alias("orders"),
            sum("total_amount").alias("revenue"),
            avg("total_amount").alias("avg_order_value")
        ) \
        .orderBy(desc("revenue"))
    
    # Write summaries to S3
    summaries_path = f"s3://{bucket_name}/summaries/"
    
    daily_summary.write \
        .mode("overwrite") \
        .partitionBy("year", "month") \
        .option("compression", "snappy") \
        .parquet(f"{summaries_path}daily_summary/")
    
    product_summary.write \
        .mode("overwrite") \
        .option("compression", "snappy") \
        .parquet(f"{summaries_path}product_summary/")
    
    region_summary.write \
        .mode("overwrite") \
        .option("compression", "snappy") \
        .parquet(f"{summaries_path}region_summary/")
    
    logger.info(f"Summary statistics written to: {summaries_path}")

def create_redshift_tables():
    """Create Redshift tables for analytics"""
    logger.info("Creating Redshift table definitions...")
    
    # This would typically be done via Redshift COPY commands
    # For demo purposes, we'll create the table structure
    
    redshift_table_sql = """
    CREATE TABLE IF NOT EXISTS sales_fact (
        sale_id VARCHAR(50),
        customer_id VARCHAR(50),
        product_name VARCHAR(100),
        quantity INTEGER,
        unit_price DECIMAL(10,2),
        total_amount DECIMAL(12,2),
        region VARCHAR(50),
        payment_method VARCHAR(50),
        sale_date DATE,
        sale_timestamp TIMESTAMP,
        processing_timestamp TIMESTAMP,
        profit_margin DECIMAL(10,2),
        customer_segment VARCHAR(20),
        month_name VARCHAR(20),
        quarter INTEGER,
        day_of_week VARCHAR(20),
        year INTEGER,
        month INTEGER,
        day INTEGER
    )
    DISTSTYLE KEY
    DISTKEY (sale_date)
    SORTKEY (sale_date, region);
    """
    
    logger.info("Redshift table definition created")
    return redshift_table_sql

def main():
    """Main ETL process"""
    try:
        logger.info("Starting ETL job...")
        
        # Process the data
        processed_df = process_sales_data()
        
        if processed_df is not None:
            # Create Redshift table definition
            redshift_sql = create_redshift_tables()
            
            # Log success
            logger.info("ETL job completed successfully!")
            logger.info(f"Processed data available at: s3://{processed_bucket}/processed/")
            logger.info(f"Summaries available at: s3://{processed_bucket}/summaries/")
            
            # Print some sample data
            logger.info("Sample processed data:")
            processed_df.select("sale_id", "product_name", "total_amount", "region", "sale_date").show(5)
            
        else:
            logger.warning("No data was processed")
            
    except Exception as e:
        logger.error(f"ETL job failed: {str(e)}")
        raise e
    
    finally:
        job.commit()

if __name__ == "__main__":
    main()
