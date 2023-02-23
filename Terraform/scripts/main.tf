terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~>3.27"
        }
    }
    backend "s3" {
        bucket = "datavid-pdfconverter"
        key    = "terraform/stateless_comps/terraform.tfstate"
        region = "us-east-2"
    }
}
