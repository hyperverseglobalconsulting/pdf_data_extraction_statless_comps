import os
import boto3
import logging
from pdf2docx import Converter
from botocore.exceptions import NoCredentialsError, PartialCredentialsError
import json

# Initialize logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize S3 client
s3_client = boto3.client('s3')

# Get environment variables
bucket_name = os.environ['S3_BUCKET']
object_key = os.environ['OBJECT_KEY']
sqs_queue_url = os.environ['SQS_QUEUE_URL']
dlq_queue_url = os.environ['DLQ_QUEUE_URL']

# Initialize SQS client
sqs_client = boto3.client('sqs')

def download_pdf_from_s3(bucket, key, local_path):
    """
    Download a PDF file from S3.
    """
    try:
        s3_client.download_file(bucket, key, local_path)
        logger.info(f"Downloaded PDF from S3: s3://{bucket}/{key}")
    except (NoCredentialsError, PartialCredentialsError) as e:
        logger.error(f"Error downloading PDF from S3: {e}")
        raise

def convert_pdf_to_docx(pdf_path, docx_path):
    """
    Convert a PDF file to a DOCX file.
    """
    try:
        cv = Converter(pdf_path)
        cv.convert(docx_path, start=0, end=None)
        cv.close()
        logger.info(f"Converted PDF to DOCX: {docx_path}")
    except Exception as e:
        logger.error(f"Error converting PDF to DOCX: {e}")
        raise

def upload_docx_to_s3(bucket, key, local_path):
    """
    Upload a DOCX file to S3.
    """
    try:
        s3_client.upload_file(local_path, bucket, key)
        logger.info(f"Uploaded DOCX to S3: s3://{bucket}/{key}")
    except (NoCredentialsError, PartialCredentialsError) as e:
        logger.error(f"Error uploading DOCX to S3: {e}")
        raise

def send_to_dlq(message):
    """
    Send a failed message to the DLQ.
    """
    try:
        sqs_client.send_message(
            QueueUrl=dlq_queue_url,
            MessageBody=message
        )
        logger.info(f"Sent message to DLQ: {dlq_queue_url}")
    except Exception as e:
        logger.error(f"Error sending message to DLQ: {e}")
        raise

def main():
    try:
        # Define local file paths
        pdf_file = "/tmp/input.pdf"
        docx_file = "/tmp/output.docx"

        # Download the PDF file from S3
        download_pdf_from_s3(bucket_name, object_key, pdf_file)

        # Convert the PDF file to DOCX
        convert_pdf_to_docx(pdf_file, docx_file)

        # Define the S3 key for the processed DOCX file
        processed_key = f"processed/{os.path.splitext(os.path.basename(object_key))[0]}.docx"

        # Upload the DOCX file to the processed folder in S3
        upload_docx_to_s3(bucket_name, processed_key, docx_file)

        logger.info("PDF to DOCX conversion completed successfully.")

    except Exception as e:
        logger.error(f"Error processing PDF: {e}")
        # Send the failed message to the DLQ
        send_to_dlq(json.dumps({
            "bucket": bucket_name,
            "object_key": object_key,
            "error": str(e)
        }))

if __name__ == "__main__":
    main()
