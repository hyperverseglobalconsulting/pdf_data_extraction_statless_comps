# Use the official Python image as the base image
FROM public.ecr.aws/lambda/python:3.13

# Install dependencies
RUN pip install boto3

# Set the working directory to the Lambda task root
WORKDIR ${LAMBDA_TASK_ROOT}

# Copy the Lambda function code into the container
COPY lambda_function.py ${LAMBDA_TASK_ROOT}

#RUN ls ${LAMBDA_TASK_ROOT}
#RUN cat ${LAMBDA_TASK_ROOT}/lambda_function.py
#
#RUN chmod +x lambda_function.py

# Set the handler function in the correct format
CMD ["lambda_function.lambda_handler"]
