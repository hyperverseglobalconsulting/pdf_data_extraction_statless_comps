<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PDF to DOCX Converter</title>
    <link rel="icon" type="image/x-icon" href="/favicon.ico">
    <link rel="stylesheet" href="static/style.css">
</head>
<body>
    <div class="container">
        <h1>Convert PDF to DOCX</h1>
        <div class="upload-section">
            <form id="uploadForm" enctype="multipart/form-data">
                <div class="drop-zone" id="dropZone">
                    <span class="drop-text">Drag & Drop PDF file here</span>
                    <input type="file" id="fileInput" accept=".pdf" hidden>
                    <button type="button" class="btn" onclick="document.getElementById('fileInput').click()">
                        Choose File
                    </button>
                </div>
                <div class="progress-container" id="progressContainer">
                    <div class="progress-bar" id="progressBar"></div>
                </div>
                <button type="submit" class="btn convert-btn">Convert to DOCX</button>
            </form>
        </div>
        <div class="result-section" id="resultSection" style="display: none;">
            <a href="#" class="download-btn" id="downloadLink">Download DOCX File</a>
        </div>
    </div>
    <script>
      const API_ENDPOINT = "${api_endpoint}";
    </script>
    <script src="static/app.js"></script>
</body>
</html>
