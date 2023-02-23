variable "bucket_name" {
    type    = string
    default = "datavid-pdfconverter"
}

variable "bucket_arn" {
    type    = string
    default = "arn:aws:s3:::datavid-pdfconverter"

variable "sqs_name" {
    type    = string
    default = "PDFPageInfo"
}

variable "repo_name_pdf_splitter" {
    type    = string
    default = "pdf_splitter"
}

variable "repo_name_page_extractor" {
    type    = string
    default = "page_extractor"
}

variable "lambda_name_pdf_splitter" {
    type    = string
    default = "pdf_splitter"
}

variable "lambda_name_page_extractor" {
    type    = string
    default = "page_extractor"
}

variable "sqs_queue_url" {
    type    = string
    default = "https://sqs.us-east-2.amazonaws.com/093487613626/PDFPageInfo"
}

variable "sqs_queue_arn" {
    type    = string
    default = "arn:aws:sqs:us-east-2:093487613626:PDFPageInfo"
}

variable "img_pages_key_prefix" {
    type    = string
    default = "project/data/imgpages/"
}

variable "source_pdf_key_prefix" {
    type    = string
    default = "project/data/document/"
}

variable "table_corners_img_key_prefix" {
    type    = string
    default = "project/data/table_corners/"
}

variable "masked_images_pdf_key_prefix" {
    type    = string
    default = "project/data/masked_images/"
}

variable "temp_images_pdf_key_prefix" {
    type    = string
    default = "project/data/temp_images/"
}

variable "opensearch_data_pdf_key_prefix" {
    type    = string
    default = "project/data/opensearch_data/"
}
