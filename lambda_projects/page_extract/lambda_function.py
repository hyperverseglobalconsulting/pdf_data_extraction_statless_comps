import os
import boto3
import json
import fitz
import ExtractTables as extract_tables
import base64
import cv2
import numpy as np
import pytesseract
import copy

s3_client = boto3.client('s3')
sqs_client = boto3.client('sqs')

TEXT_BLOCK_TYPE = 0
IMG_BLOCK_TYPE = 1

#def extract_images(block_l):
#    images_xy = []
#    for block in block_l:
#        x0, y0, x1, y1, lines, block_no, block_type = block
#        if block_type == IMG_BLOCK_TYPE:
#            images_xy.append((x0, y0, x1, y1))
#    return images_xy

def extract_paragraphs(block_l):
    paragraph_bbox_l = []
    for block in block_l:
        x0, y0, x1, y1, lines, block_no, block_type = block
        print(f'extract paragraph = {block}')
        if block_type == TEXT_BLOCK_TYPE:
            rect = fitz.Rect(x0, y0, x1, y1)
            textpage = page.get_textpage_ocr(flags=7, language='eng', rect = rect, dpi=600, full=True)
            lines = textpage.extractText()
            paragraph_bbox_l.append((x0, y0, x1, y1, lines))
#            paragraph_l.append(text)
    return paragraph_bbox_l

def prepare_image_data(image_bbox_l, image):
    base64_jpg_l = []
    for image_bbox in image_bbox_l:
        jpg = extract_tables.jpg_in_bounding_box(image_bbox_l, image)
        base64_jpg = base64.b64encode(jpg)
        base64_jpg_l.append(base64_jpg)
    return base64_jpg_l

def prepare_paragraph_data(paragraph_bbox_l, image):
    paragraph_l = []
    for paragraph_bbox in paragraph_bbox_l:
        paragraph_l.append(paragraph_bbox[4])
    return paragraph_l

def prepare_table_data(table_dim_l, image):
    # copy image vector to protect it against modification
    image_content = copy.deepcopy(image)
    print(f'table_dim_l = {table_dim_l}')
    table_obj_l = []
    for table_dim in table_dim_l:
        table_obj = []
        for row in table_dim:
            row_arr = []
            for cell in row:
                x0, y0 = cell[0]
                x1, y1 = cell[1]

                # Extract the cell from the image
                cell_image = image_content[y0:y1, x0:x1]

                # Convert the cell image to grayscale
                gray = cv2.cvtColor(cell_image, cv2.COLOR_BGR2GRAY)

                # Apply thresholding to the cell image
                thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]

                # Apply dilation to the thresholded image
                kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2,2))
                dilate = cv2.dilate(thresh, kernel, iterations=2)

                # Extract text from the cell using PyTesseract
                text = pytesseract.image_to_string(dilate, config='--psm 6')
                print(f"table data: row = {row}, cell = {cell}, text = {text}")

                row_arr.append(text)
            table_obj.append(row_arr)
        table_obj_l.append(table_obj)
    return table_obj_l

#def extract_text_from_image(image, bbox):
#    _, encoded_img = cv2.imencode('.jpg', image)
#
#    # Convert the binary data to a bytes object
#    image_data = encoded_img.tobytes()
#
#    # Create fitz PDF document from masked image
#    with fitz.open(stream=image_data, filetype="jpg") as img_file:
#
#        x0, y0, x1, y1 = bbox
#
#        # Get pixmap for page insert
#        page = list(img_file.pages())[0]
#        pix = page.get_pixmap()
#
#        # Create a new document with a single page
#        doc = fitz.open()
#        page = doc.new_page()
#
#        # Draw the image onto the page
#        page.insert_image(fitz.Rect(x0, y0, x1, y1), pixmap=pix)
#
#        textpage = page.get_textpage_ocr(flags=7, language='eng', dpi=600, full=True)
#
#        # Extract the text from the OCR result
#        text = textpage.extractText()
#
#        return text

#RES_RATIO = 600/72

# Debugging
def save_tempimages(image, bucket, filename, suffix):
    table_corners_key_prefix = os.environ["TEMP_KEY_PREFIX"]
    base_filename = os.path.splitext(filename)[0]
    key = f"{table_corners_key_prefix}/{base_filename}_{suffix}.jpg"
    print(f'temp: key={key}')
    _, buffer = cv2.imencode('.jpg', image)
    image_b = buffer.tobytes()
    s3_client.put_object(Bucket=bucket, Key=key, Body=image_b)

# Debugging
def save_masked_image(image, bucket, filename):
    success_f, encoded_img = cv2.imencode('.jpg', image)

    # Convert the binary data to a bytes object
    image_b = encoded_img.tobytes()

    table_masked_key_prefix = os.environ["MASKED_KEY_PREFIX"]
    base_filename = os.path.splitext(filename)[0]
    key = f"{table_masked_key_prefix}/{base_filename}_masked.jpg"
    print(f'mask: key={key}')
    s3_client.put_object(Bucket=bucket, Key=key, Body=image_b)

def prepare_document_data(page_num, image_l, paragraph_bbox_l, table_dim_l, image, bucket, filename):
    save_tempimages(image, bucket, filename, 'table')
    table_obj_l = prepare_table_data(table_dim_l, image)
    paragraph_l = prepare_paragraph_data(paragraph_bbox_l, image)

    docdata = {}
    docdata['page'] = page_num
    docdata['paragraphs'] = paragraph_l
    docdata['images'] = image_l
    docdata['tables'] = table_obj_l
    return docdata

def extract_message(message_body):
    # Extract the filename, filename_lres, bucket, key prefix, and timestamp from the message
    message = json.loads(message_body)
    filename = message['filename']
    filename_lres = message['filename_lres']
    page_num = message['page_num']
    bucket = message['bucket']
    key_prefix = message['key_prefix']
    return filename, filename_lres, page_num, bucket, key_prefix

def get_np_image(bucket, key):
    print(f'bucket={bucket}, key={key}')
    response = s3_client.get_object(Bucket=bucket, Key=key)
    content_b = response['Body'].read()

    # Decode the JPG data into a numpy array
    image = cv2.imdecode(np.frombuffer(content_b, np.uint8), cv2.IMREAD_COLOR)
    return image

#def process_pdf(pdf_content):
#    pdf_file = fitz.open(stream=pdf_content, filetype="pdf")
#    page = list(pdf_file.pages())[0]
#    textpage = page.get_textpage_ocr(flags=7, language='eng', dpi=300, full=True)
#
#    # Extract the text blocks from the OCR result
#    block_l = textpage.extractBLOCKS()
#
#    images = extract_images(block_l)
#    paragraphs = extract_paragraphs(block_l)
#    tables = extract_tables(block_l)
#    return images, paragraphs, tables
#
def process_img(image, image_lres):
    print(f'Entered process img')
    corners, table_corners, arr, horizontal_lines, vertical_lines = extract_tables.detect_table(image_lres)

    # Debugging: Check if mapping is correct
    output_map_lres = extract_tables.get_lowres_ouput(image_lres, arr, horizontal_lines, vertical_lines)
    output_map = extract_tables.get_ouput(image, arr, horizontal_lines, vertical_lines)

    table_dim_l = extract_tables.get_table_dim_list(arr)

    print('table_dim_l = ', table_dim_l)

    masked_tbl_img = extract_tables.remove_bbox_from_image(image, [table_corners])

    # convert image verctor to base64 string
    base64_jpg_l = []

    _, encoded_img = cv2.imencode('.jpg', image)

    # Convert the binary data to a bytes object
    image_data = encoded_img.tobytes()
    base64_jpg = base64.b64encode(image_data).decode('ascii')
    base64_jpg_l.append(base64_jpg)

    # Create fitz PDF document from masked image
    _, encoded_img = cv2.imencode('.jpg', masked_tbl_img)

    # Convert the binary data to a bytes object
    masked_tbl_img_b = encoded_img.tobytes()

    with fitz.open(stream=masked_tbl_img_b, filetype="jpg") as img_file:

        # Get pixmap for page insert
        page_image = list(img_file.pages())[0]
        pix = page_image.get_pixmap(dpi=600, alpha=False)

#        # Set the image resolution
#        page = list(doc.pages())[0]
##        page.set_dpi(600, 600)
#
#        # Perform OCR on the first page of the image using Tesseract
#        page = doc[0]
#        textpage = page.textpage_ocr(engine="tesseract", dpi=600, full=True)

        # Create a new document with a single page
        doc = fitz.open()
        page = doc.new_page(width=page_image.rect.width, height=page_image.rect.height)

        # Draw the image onto the page
        page.insert_image(fitz.Rect(0, 0, page.rect.width, page.rect.height), pixmap=pix)

        print(f'page_size: width = {page.rect.width}, height = {page.rect.height}')

        textpage = page.get_textpage_ocr(flags=7, language='eng', dpi=150, full=True)

        # Extract the text blocks from the OCR result
        block_l = textpage.extractBLOCKS()

        paragraph_bbox_l = extract_paragraphs(block_l, textpage)

    return base64_jpg_l, paragraph_bbox_l, table_dim_l, output_map_lres, output_map, masked_tbl_img

def save_docdata(bucket, filename, docdata):
    # Save the docdata to S3
    target_key_prefix = os.environ["TARGET_KEY_PREFIX"]
    base_filename = os.path.splitext(filename)[0]
    json_key = f"{target_key_prefix}/{base_filename}.json"
    print(f'text_key={json_key}')
    jsonobj = json.dumps(docdata)
    s3_client.put_object(Bucket=bucket, Key=json_key, Body=jsonobj)

#def save_paragraph_dim(bucket, filename, paragraph_dict_l):
#    text_dim_key_prefix = os.environ["TEXT_DIM_KEY_PREFIX"]
#    base_filename = os.path.splitext(filename)[0]
#    jpg_key = f"{text_dim_key_prefix}/{base_filename}_text_dim.jpg"
#    print(f'text_dim_key={jpg_key}')
#    s3_client.put_object(Bucket=bucket, Key=jpg_key, Body=content)

def delete_message(record):
    queue_url = record['eventSourceARN'].split(':')[5]
    print(f"queue_url={queue_url}")

    response = sqs_client.delete_message(
        QueueUrl=queue_url,
        ReceiptHandle=record['receiptHandle']
    )

# Debugging
def save_table_corner_files(bucket, filename, filename_lres, output, output_lres):
    table_corners_key_prefix = os.environ["TABLE_CORNERS_KEY_PREFIX"]
    base_filename = os.path.splitext(filename)[0]
    key = f"{table_corners_key_prefix}/{base_filename}_corners.jpg"
    print(f'corner: key={key}')
    base_filename_lres = os.path.splitext(filename_lres)[0]
    key_lres = f"{table_corners_key_prefix}/{base_filename_lres}_corners.jpg"
    s3_client.put_object(Bucket=bucket, Key=key, Body=output)
    s3_client.put_object(Bucket=bucket, Key=key_lres, Body=output_lres)

def lambda_handler(event, context):
    # Extract the records from the SQS event
    records = event['Records']

    for record in records:
        # Extract the message body from the record
        message_body = record['body']

        filename, filename_lres, page_num, bucket, key_prefix = extract_message(message_body)

        print(f'filename={filename}, filename_lres={filename_lres}, page_num={page_num}, bucket={bucket}, key_prefix={key_prefix}')

        key = f'{key_prefix}/{filename}'
        key_lres = f'{key_prefix}/{filename_lres}'
        image = get_np_image(bucket, key)
        image_lres = get_np_image(bucket, key_lres)

        image_l, paragraph_bbox_l, table_dim_l, output_lres, output, masked_tbl_img = process_img(image, image_lres)

        save_table_corner_files(bucket, filename, filename_lres, output, output_lres)

        save_masked_image(masked_tbl_img, bucket, filename)

        print(f'paragraph_bbox_l = {paragraph_bbox_l}')

        docdata = prepare_document_data(page_num, image_l, paragraph_bbox_l, table_dim_l, image, bucket, filename)

        # Save the extracted text to S3
        save_docdata(bucket, filename, docdata)

        delete_message(record)

    return {
        'statusCode': 200,
        'body': 'Success'
    }
