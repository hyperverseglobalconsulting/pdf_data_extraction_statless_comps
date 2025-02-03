import os
import fitz
import boto3
import logging
import json
from PIL import Image, __version__ as pillow_version

if pillow_version >= "9.1.0":
    Image.LINEAR = Image.Resampling.LINEAR
    Image.BILINEAR = Image.Resampling.BILINEAR
    Image.BICUBIC = Image.Resampling.BICUBIC
    Image.LANCZOS = Image.Resampling.LANCZOS

import layoutparser as lp
from layoutparser.models.detectron2 import Detectron2LayoutModel  # Correct import path
from paddleocr import PaddleOCR
import io
from botocore.exceptions import NoCredentialsError, PartialCredentialsError

# Initialize logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# Initialize S3 client
s3_client = boto3.client('s3')

# Get environment variables
bucket_name = os.environ.get('S3_BUCKET')
object_key = os.environ.get('OBJECT_KEY')

# Initialize models at startup
#LAYOUT_MODEL = lp.Detectron2LayoutModel(
LAYOUT_MODEL = Detectron2LayoutModel(
    config_path="/models/config.yml",
    model_path="/models/model_final.pth",
    extra_config=["MODEL.ROI_HEADS.SCORE_THRESH_TEST", 0.8],
    label_map={0: "Text", 1: "Title", 2: "List", 3: "Table", 4: "Figure"}
)

OCR_MODEL = PaddleOCR(
    use_angle_cls=False,
    lang='en',
    show_log=False,
    det_model_dir='/models/en_PP-OCRv3_det_infer',
    rec_model_dir='/models/en_PP-OCRv4_rec_infer',
    cls_model_dir='/models/ch_ppocr_mobile_v2.0_cls_infer'
)

def validate_environment_variables():
    """Validate required environment variables"""
    if not bucket_name or not object_key:
        raise ValueError("S3_BUCKET and OBJECT_KEY environment variables must be set")
    logger.info("Environment variables validated successfully")

def download_pdf_from_s3(bucket, key, local_path):
    """Download PDF from S3 bucket"""
    try:
        s3_client.download_file(bucket, key, local_path)
        logger.info(f"Successfully downloaded PDF from s3://{bucket}/{key}")
    except (NoCredentialsError, PartialCredentialsError) as e:
        logger.error(f"Credentials error: {e}")
        raise
    except Exception as e:
        logger.error(f"Error downloading PDF: {e}")
        raise

def extract_text_from_pdf(pdf_path):
    """Extract text from PDF and structure as JSON"""
    doc = fitz.open(pdf_path)

#    layout_model = lp.Detectron2LayoutModel(
#        config_path="lp://PubLayNet/faster_rcnn_R_50_FPN_3x/config",
#        model_path="/root/.torch/iopath_cache/s/dgy9c10wykk4lq4/model_final.pth",
#        extra_config=["MODEL.ROI_HEADS.SCORE_THRESH_TEST", 0.8]
#    )
#    #ocr_model = PaddleOCR(use_angle_cls=True, lang='en', show_log=False)
#    ocr_model = PaddleOCR(
#        use_angle_cls=False,
#        lang='en',
#        show_log=False,
#        rec_algorithm='SVTR_LCNet',
#        det_model_dir='/root/.paddleocr/whl/det/en/en_PP-OCRv3_det_infer',
#        rec_model_dir='/root/.paddleocr/whl/rec/en/en_PP-OCRv4_rec_infer',
#        cls_model_dir='/root/.paddleocr/whl/cls/ch_ppocr_mobile_v2.0_cls_infer'
#    )

    result = []

    for page_num in range(len(doc)):
        page_data = {
            "page_number": page_num + 1,
            "blocks": []
        }

        page = doc.load_page(page_num)
        pix = page.get_pixmap(dpi=150)
        # img = Image.open(io.BytesIO(pix.tobytes()))
        img = Image.open(io.BytesIO(pix.tobytes())).convert('L')  # Grayscale conversion

        # Layout detection
        layout = LAYOUT_MODEL.detect(img)
        blocks = lp.Layout([b for b in layout if b.type in ['Text', 'Title', 'List']])
        blocks.sort(key=lambda b: (b.coordinates[1], b.coordinates[0]))

#        if img.mode != 'RGB':
#            img = img.convert('RGB')

#        layout = layout_model.detect(img)
#        blocks = lp.Layout([b for b in layout if b.type in ['Text', 'Title', 'List']])
#        
#        # Corrected sorting implementation
#        blocks.sort(key=lambda b: (b.coordinates[1], b.coordinates[0]))

        for block_idx, block in enumerate(blocks):
            x1, y1, x2, y2 = map(int, block.coordinates)
            cropped_img = img.crop((x1, y1, x2, y2))

            ocr_result = OCR_MODEL.ocr(cropped_img)
            text = ' '.join([line[1][0] for line in ocr_result[0]]) if ocr_result[0] else ''

            page_data["blocks"].append({
                "block_id": block_idx + 1,
                "coordinates": [x1, y1, x2, y2],
                "text": text,
                "type": block.type
            })

        result.append(page_data)

    return json.dumps(result, indent=2)

def upload_to_s3(json_data, bucket, key):
    """Upload JSON result to S3 bucket"""
    try:
        with open("/tmp/output.json", "w") as f:
            f.write(json_data)

        s3_client.upload_file(
            "/tmp/output.json",
            bucket,
            key
        )
        logger.info(f"Successfully uploaded results to s3://{bucket}/{key}")
    except (NoCredentialsError, PartialCredentialsError) as e:
        logger.error(f"Credentials error: {e}")
        raise
    except Exception as e:
        logger.error(f"Error uploading to S3: {e}")
        raise

def generate_output_key():
    """Generate output path in processed/ directory with same base name as input"""
    original_filename = os.path.basename(object_key)
    base_name = os.path.splitext(original_filename)[0]
    return f"processed/{base_name}.json"

def main():
    try:
        validate_environment_variables()

        local_pdf_path = "/tmp/input.pdf"
        download_pdf_from_s3(bucket_name, object_key, local_pdf_path)

        json_output = extract_text_from_pdf(local_pdf_path)

        output_key = generate_output_key()
        logger.info(f"Generated output key: {output_key}")

        upload_to_s3(json_output, bucket_name, output_key)

    except Exception as e:
        logger.error(f"Processing failed: {e}")
        raise

if __name__ == "__main__":
    main()
