import boto3
import os
import json
import logging

# Initialize logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

ecs_client = boto3.client('ecs')
sqs_client = boto3.client('sqs')

def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    cluster = os.environ['ECS_CLUSTER']
    task_definition = os.environ['ECS_TASK_DEFINITION']
    sqs_queue_url = os.environ['SQS_QUEUE_URL']
    dlq_queue_url = os.environ['DLQ_QUEUE_URL']

    for record in event['Records']:
        try:
            # Parse the S3 event from the SQS message
            s3_event = json.loads(record['body'])
            logger.info("Parsed S3 event: %s", json.dumps(s3_event))

            for s3_record in s3_event['Records']:
                bucket = s3_record['s3']['bucket']['name']
                object_key = s3_record['s3']['object']['key']

                # Log the bucket and object key
                logger.info("Processing S3 object: s3://%s/%s", bucket, object_key)

                # Invoke the ECS Fargate task
                response = ecs_client.run_task(
                    cluster=cluster,
                    launchType='FARGATE',
                    taskDefinition=task_definition,
                    networkConfiguration={
                        'awsvpcConfiguration': {
                            'subnets': ['subnet-02c51756995a80812'],
                            'assignPublicIp': 'ENABLED'
                        }
                    },
                    overrides={
                        'containerOverrides': [
                            {
                                'name': 'pdf-to-doc',
                                'environment': [
                                    {'name': 'S3_BUCKET', 'value': bucket},
                                    {'name': 'OBJECT_KEY', 'value': object_key},
                                    {'name': 'SQS_QUEUE_URL', 'value': sqs_queue_url},
                                    {'name': 'DLQ_QUEUE_URL', 'value': dlq_queue_url}
                                ]
                            }
                        ]
                    }
                )

                # Check for failures
                if response['failures']:
                    print(f"Failed to run ECS task: {response['failures']}")
                    sqs_client.send_message(
                        QueueUrl=dlq_queue_url,
                        MessageBody=record['body']
                    )
                else:
                    print(f"Successfully started ECS task: {response['tasks']}")

        except Exception as e:
            print(f"Error processing message: {e}")
            sqs_client.send_message(
                QueueUrl=dlq_queue_url,
                MessageBody=record['body']
            )

    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete')
    }
