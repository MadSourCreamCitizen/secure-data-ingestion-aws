import os
import json
import urllib.parse
import boto3
from datetime import datetime

print('Loading function')

s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Log the event for debugging
    print("Received event: " + json.dumps(event, indent=2))

    # Get bucket and key from the S3 event record
    source_bucket = event['Records'][0]['s3']['bucket']['name']
    source_key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')

    # Get destination bucket name from Lambda environment variables
    destination_bucket = os.environ.get('PROCESSED_BUCKET_NAME')
    if not destination_bucket:
        print("Error: PROCESSED_BUCKET_NAME environment variable not set.")
        raise ValueError("PROCESSED_BUCKET_NAME environment variable is required.")

    # Construct the destination key (e.g., processed/timestamp_originalfilename.csv)
    # We'll put processed files in a 'processed/' prefix in the destination bucket
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    destination_key = f"processed/{timestamp}_{source_key.split('/')[-1]}" # Get only filename from source_key

    try:
        # 1. Read the raw data from S3
        print(f"Reading file '{source_key}' from bucket '{source_bucket}'.")
        response = s3.get_object(Bucket=source_bucket, Key=source_key)
        raw_file_content = response['Body'].read().decode('utf-8')
        print(f"File '{source_key}' read successfully. Content length: {len(raw_file_content)}")

        # 2. Simulate processing the data
        # For a real project, this is where you'd add complex logic:
        # - Anonymization (e.g., hashing PII, removing sensitive fields)
        # - Data validation
        # - Transformation (e.g., converting CSV to Parquet, normalizing data)
        # - Enrichment (e.g., adding geographic data)

        processed_content = (
            f"--- Processed by Lambda on {datetime.now()} ---\n"
            f"Original Source: s3://{source_bucket}/{source_key}\n"
            f"Original Content:\n{raw_file_content}"
        )
        print(f"Data processed for {source_key}. Writing to {destination_bucket}/{destination_key}")

        # 3. Write the processed data to the destination S3 bucket
        # The S3 PutObject operation implicitly uses the default encryption settings of the destination bucket,
        # which we configured with KMS encryption.
        s3.put_object(
            Bucket=destination_bucket,
            Key=destination_key,
            Body=processed_content.encode('utf-8') # Ensure content is bytes
        )
        print(f"Processed data written successfully to s3://{destination_bucket}/{destination_key}")

        # 4. Optional: Delete the original file from the raw bucket
        # This is a common step in ingestion pipelines to prevent re-processing and manage storage.
        # Comment out if you want to keep raw files.
        # s3.delete_object(Bucket=source_bucket, Key=source_key)
        # print(f"Original file deleted from raw bucket: {source_bucket}/{source_key}")


        return {
            'statusCode': 200,
            'body': json.dumps(f'Successfully processed and moved {source_key} to {destination_bucket}/{destination_key}')
        }

    except Exception as e:
        print(f"Error processing object {source_key} from bucket {source_bucket}.")
        print(f"Error details: {e}")
        raise e