# python3.9 lambda base image
FROM public.ecr.aws/lambda/python:3.9

# copy requirements.txt to container
#COPY requirements.txt ./

RUN pip3 install --upgrade pip

RUN yum install -y poppler-utils

RUN pip3 install --upgrade pip

# installing dependencies
# RUN pip3 install pdf2image
RUN pip3 install PyPDF2==2.9.0
RUN pip3 install PyMuPDF
RUN pip3 install Pillow

# Copy function code to container
COPY lambda_function.py ./

#ENV TARGET_IMG_KEY_PREFIX=project/imgpages/
#ENV TARGET_PDF_KEY_PREFIX=project/pages
#ENV IMG_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/093487613626/PDFImages
#ENV PDF_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/093487613626/PDFPages
#ENV PDF_TEXT_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/093487613626/PDFTextQueue
#ENV PDF_TABLE_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/093487613626/PDFTableQueue
#ENV PDF_IMG_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/093487613626/PDFImgQueue

# setting the CMD to your handler file_name.function_name
CMD [ "lambda_function.lambda_handler" ]
