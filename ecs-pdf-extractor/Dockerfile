FROM python:3.9-slim

# Install dependencies
RUN pip install boto3 pdf2docx

# Copy the Python script
COPY pdf_to_docx.py /app/pdf_to_docx.py

# Set the working directory
WORKDIR /app

# Run the Python script
CMD ["python", "pdf_to_docx.py"]
