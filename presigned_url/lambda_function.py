import os
import json
import boto3
import logging
from botocore.exceptions import ClientError

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3', region_name='us-east-2')
#s3 = boto3.client(
#    's3',
#    region_name='us-east-2',
#    endpoint_url='https://s3.us-east-2.amazonaws.com'
#)

bucket_name = os.environ['S3_BUCKET']

def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")
    logger.debug(f"Full event details: {event}")
    
    # Handle OPTIONS request for CORS preflight
    if event['httpMethod'] == 'OPTIONS':
        logger.info("Handling OPTIONS preflight request")
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': 'https://pdf2docx.vizeet.me',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
                'Access-Control-Allow-Credentials': 'true',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0'
            },
            'body': json.dumps({'message': 'CORS preflight response'})
        }

    try:
        logger.info(f"Incoming request ID: {context.aws_request_id}")
        body = json.loads(event['body'])
        filename = body['filename']
        logger.info(f"Original filename received: {filename}")
        
        sanitized_name = sanitize_filename(filename)
        logger.info(f"Sanitized filename: {sanitized_name}")
        
        object_key = f"upload/{context.aws_request_id}-{sanitized_name}"
        logger.info(f"Generated object key: {object_key}")

        logger.info("Generating presigned URL with parameters:")
        logger.info(f"Bucket: {bucket_name}")
        logger.info(f"Key: {object_key}")
        logger.info(f"ContentType: application/pdf")
        logger.info(f"ACL: bucket-owner-full-control")
        logger.info(f"ExpiresIn: 300 seconds")

        presigned_url = s3.generate_presigned_url(
            ClientMethod='put_object',
            Params={
                'Bucket': bucket_name,
                'Key': object_key,
                'ContentType': 'application/pdf',
               # 'ACL': 'public-read'
            },
            ExpiresIn=900
        )

        logger.info(f"Successfully generated presigned URL: {presigned_url}")
        logger.debug(f"Full presigned URL details: {presigned_url}")

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': 'https://pdf2docx.vizeet.me',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
                'Access-Control-Allow-Credentials': 'true',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0'
            },
            'body': json.dumps({
                'uploadUrl': presigned_url,
                'objectKey': object_key
            })
        }

    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {str(e)}")
        logger.error(f"Request body: {event.get('body', 'No body')}")
        return error_response("Invalid JSON format in request body")
        
    except KeyError as e:
        logger.error(f"Missing key in request: {str(e)}")
        return error_response(f"Missing required field: {str(e)}")

    except ClientError as e:
        logger.error(f"S3 ClientError: {str(e)}")
        logger.error(f"Error code: {e.response['Error']['Code']}")
        logger.error(f"Error message: {e.response['Error']['Message']}")
        return error_response(f"S3 operation failed: {e.response['Error']['Message']}")

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return error_response("Internal server error")

def sanitize_filename(filename):
    logger.debug(f"Sanitizing filename: {filename}")
    keep = ("-", "_", ".")
    sanitized = "".join(c for c in filename if c.isalnum() or c in keep).rstrip()
    logger.debug(f"Sanitized result: {sanitized}")
    return sanitized

def error_response(message):
    return {
        'statusCode': 500,
        'headers': {
            'Access-Control-Allow-Origin': 'https://pdf2docx.vizeet.me',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0'
        },
        'body': json.dumps({'error': message})
    }
