FROM 093487613626.dkr.ecr.us-east-1.amazonaws.com/tesseract_1_83_0_leptonica_5_3_0:latest

# Copy function code to container
COPY ExtractTables.py ./
COPY lambda_function.py ./
#COPY tessdata/eng.traineddata ./tessdata/eng.traineddata
COPY requirements.txt ./

# Install Python dependencies
RUN pip install --upgrade pip && \
    pip install -r requirements.txt && \
    pip install pytesseract

#ENV RES_HIGH=600
#ENV RES_LOW=72
#ENV BATCH_SIZE=10
#ENV TARGET_KEY_PREFIX=project/opensearch_data
#ENV TEMP_KEY_PREFIX=project/temp_images
#ENV MASKED_KEY_PREFIX=project/masked_images
#ENV TABLE_CORNERS_KEY_PREFIX=project/table_corners
#ENV SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/093487613626/PDFPages
#ENV TESSDATA_PREFIX=tessdata

# setting the CMD to your handler file_name.function_name
CMD [ "lambda_function.lambda_handler" ]
