import os
import boto3
import logging
from pdf2docx import Converter
from botocore.exceptions import NoCredentialsError, PartialCredentialsError

# Initialize logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize S3 client
s3_client = boto3.client('s3')

# Get environment variables
bucket_name = os.environ.get('S3_BUCKET')
object_key = os.environ.get('OBJECT_KEY')

def validate_environment_variables():
    """
    Validate that required environment variables are set.
    """
    if not bucket_name or not object_key:
        raise ValueError("S3_BUCKET and OBJECT_KEY environment variables must be set.")

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

def main():
    try:
        # Validate environment variables
        validate_environment_variables()

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
        # Propagate the exception to let SQS handle retries and DLQ routing
        raise

if __name__ == "__main__":
    main()
