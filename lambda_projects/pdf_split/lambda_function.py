import boto3
import os
import fitz
from datetime import datetime
import json
from io import BytesIO
from PyPDF2 import PdfFileReader, PdfFileWriter


s3 = boto3.client('s3')
sqs = boto3.client('sqs')

def write_pdfpages(pdf_content, src_bucket, source_key):
    # Split PDF into individual pages and write to dest folder
    pdf_reader = PdfFileReader(BytesIO(pdf_content))

    dest_folder = os.getenv('TARGET_PDF_KEY_PREFIX')

    for page in range(pdf_reader.getNumPages()):
        pdf_writer = PdfFileWriter()
        pdf_writer.addPage(pdf_reader.getPage(page))
        output_file = f'/tmp/{os.path.splitext(os.path.basename(source_key))[0]}_page{page+1}.pdf'
        with open(output_file, 'wb') as output:
            pdf_writer.write(output)
        output_key = f'{dest_folder}/{os.path.splitext(os.path.basename(source_key))[0]}_page{page+1}.pdf'
        s3.upload_file(output_file, src_bucket, output_key)

        # Intimate consumer about the new file that arrived
        message = {
            'filename': os.path.basename(output_key),
            'bucket': src_bucket,
            'key_prefix': os.path.dirname(output_key),
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }

        # Send the message to the SQS queue
        PDF_QUEUE_URL = os.getenv('PDF_QUEUE_URL')
        print(f'PDF_QUEUE_URL={PDF_QUEUE_URL}')

        response = sqs.send_message(
            QueueUrl= PDF_QUEUE_URL,
            MessageBody= json.dumps(message)
        )

        # Send the message to the SQS TEXT queue
        PDF_TEXT_QUEUE_URL = os.getenv('PDF_TEXT_QUEUE_URL')
        print(f'PDF_TEXT_QUEUE_URL={PDF_TEXT_QUEUE_URL}')

        response = sqs.send_message(
            QueueUrl= PDF_TEXT_QUEUE_URL,
            MessageBody= json.dumps(message)
        )

        # Send the message to the SQS TABLE queue
        PDF_TABLE_QUEUE_URL = os.getenv('PDF_TABLE_QUEUE_URL')
        print(f'PDF_TABLE_QUEUE_URL={PDF_TABLE_QUEUE_URL}')

        response = sqs.send_message(
            QueueUrl= PDF_TABLE_QUEUE_URL,
            MessageBody= json.dumps(message)
        )

        # Send the message to the SQS IMG queue
        PDF_IMG_QUEUE_URL = os.getenv('PDF_IMG_QUEUE_URL')
        print(f'PDF_IMG_QUEUE_URL={PDF_IMG_QUEUE_URL}')

        response = sqs.send_message(
            QueueUrl= PDF_IMG_QUEUE_URL,
            MessageBody= json.dumps(message)
        )

def get_imglist(pdf_content):
    # Convert the PDF to images using fitz
    pdf_file = fitz.open(stream=pdf_content, filetype="pdf")
    images = []
    images_lres = []
    for i, page in enumerate(pdf_file):
        pix = page.get_pixmap(dpi=600, alpha=False)
        pix_lres = page.get_pixmap(dpi=72, alpha=False)
        image = fitz.Pixmap(pix, 0)
        image_lres = fitz.Pixmap(pix_lres, 0)
        images.append(image)
        images_lres.append(image_lres)

    # Close the PDF file
    pdf_file.close()

    return images, images_lres

def write_imgfiles(images, images_lres, source_bucket, dest_key_prefix):
    # Upload the images to the destination folder in the same bucket
    for i, image_t in enumerate(zip(images, images_lres)):
        image = image_t[0]
        image_lres = image_t[1]
        image_key = f'{dest_key_prefix}-page-{i+1}.jpg'
        image_key_lres = f'{dest_key_prefix}-page-{i+1}_lres.jpg'
        image_file_path = f'/tmp/' + os.path.basename(image_key)
        image_file_path_lres = f'/tmp/' + os.path.basename(image_key_lres)
        print(f'image_file_path={image_file_path}')
        image.pil_save(image_file_path, optimize=True, dpi=(600, 600))
        image_lres.pil_save(image_file_path_lres, optimize=True, dpi=(72, 72))
        s3.upload_file(image_file_path, source_bucket, image_key)
        s3.upload_file(image_file_path_lres, source_bucket, image_key_lres)

        # Intimate consumer about the new file that arrived
        message = {
            'filename': os.path.basename(image_key),
            'filename_lres': os.path.basename(image_key_lres),
            'page_num': i + 1,
            'bucket': source_bucket,
            'key_prefix': os.path.dirname(image_key),
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }

        # Send the message to the SQS queue
        IMG_QUEUE_URL = os.getenv('IMG_QUEUE_URL')
        print(f'IMG_QUEUE_URL={IMG_QUEUE_URL}')

        response = sqs.send_message(
            QueueUrl= IMG_QUEUE_URL,
            MessageBody= json.dumps(message)
        )

def lambda_handler(event, context):
    # Get the source bucket and key from the event
    source_bucket = event['Records'][0]['s3']['bucket']['name']
    source_key = event['Records'][0]['s3']['object']['key']
    print(f'source_bucket={source_bucket}, source_key={source_key}')

    # Define the destination folder and key for the converted images
    dest_folder = os.getenv('TARGET_IMG_KEY_PREFIX')
    dest_key_prefix = dest_folder + os.path.splitext(os.path.basename(source_key))[0]
    print(f'dest_key_prefix={dest_key_prefix}')

    # Read the content of the PDF file from S3
    response = s3.get_object(Bucket=source_bucket, Key=source_key)
    pdf_content = response['Body'].read()

    # Split PDF into individual pages and write to dest folder
#    write_pdfpages(pdf_content, source_bucket, source_key)

    # Convert the PDF to images using fitz
    images, images_lres = get_imglist(pdf_content)

    write_imgfiles(images, images_lres, source_bucket, dest_key_prefix)

    # Free the memory used by the images
    for image in images:
        image = None

    return {
        'statusCode': 200,
        'body': 'PDF content converted to images and uploaded to S3 successfully'
    }
