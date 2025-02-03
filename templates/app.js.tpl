document.addEventListener('DOMContentLoaded', () => {
    const dropZone = document.getElementById('dropZone');
    const fileInput = document.getElementById('fileInput');
    const uploadForm = document.getElementById('uploadForm');
    const progressBar = document.getElementById('progressBar');
    const progressContainer = document.getElementById('progressContainer');
    const resultSection = document.getElementById('resultSection');
    const convertBtn = document.querySelector('.convert-btn');
    const API_ENDPOINT = '${api_gateway_url}';

    // Drag & Drop handlers
    dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropZone.classList.add('dragover');
    });

    dropZone.addEventListener('dragleave', () => {
        dropZone.classList.remove('dragover');
    });

    dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        dropZone.classList.remove('dragover');
        const files = e.dataTransfer.files;
        if (files.length > 0) {
            fileInput.files = files;
            showSelectedFile(files[0].name);
        }
    });

    // File input change handler
    fileInput.addEventListener('change', () => {
        if (fileInput.files.length > 0) {
            showSelectedFile(fileInput.files[0].name);
        }
    });

    // File upload handler
    uploadForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const file = fileInput.files[0];

        if (!file) {
            showError('Please select a PDF file first!');
            return;
        }

        try {
            convertBtn.disabled = true;
            progressContainer.style.display = 'block';
            progressBar.style.width = '0%';

            // Get presigned URL from backend
            const presignedUrl = await generatePresignedUrl(file.name);
            
            // Upload file to S3
            await uploadFileToS3(presignedUrl, file);
            
            // Handle successful upload
            showSuccess('File uploaded successfully! Conversion in progress...');
            resultSection.style.display = 'block';
            
            // Reset form after 2 seconds
            setTimeout(() => {
                uploadForm.reset();
                progressContainer.style.display = 'none';
                convertBtn.disabled = false;
                document.querySelector('.file-name').remove();
            }, 2000);

        } catch (error) {
            showError("Upload failed: $${error.message}");
            console.error(error);
            convertBtn.disabled = false;
            progressContainer.style.display = 'none';
        }
    });

    async function generatePresignedUrl(filename) {
        try {
            const response = await fetch(API_ENDPOINT, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ filename })
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: $${response.status}`);
            }

            const data = await response.json();
            return data.uploadUrl;

        } catch (error) {
            throw new Error('Failed to get upload URL: ' + error.message);
        }
    }

    function uploadFileToS3(url, file) {
        return new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();
            
            xhr.open('PUT', url);
            xhr.setRequestHeader('Content-Type', file.type);

            xhr.upload.onprogress = (e) => {
                if (e.lengthComputable) {
                    const percent = (e.loaded / e.total) * 100;
                    progressBar.style.width = percent + '%';
                }
            };

            xhr.onload = () => {
                if (xhr.status === 200) {
                    resolve(xhr.response);
                } else {
                    reject(new Error(`Upload failed: $${xhr.statusText}`));
                }
            };

            xhr.onerror = () => reject(new Error('Network error'));
            xhr.send(file);
        });
    }

    function showSelectedFile(filename) {
        const existing = document.querySelector('.file-name');
        if (existing) existing.remove();

        const fileNameDisplay = document.createElement('div');
        fileNameDisplay.className = 'file-name';
        fileNameDisplay.textContent = `Selected file: $${filename}`;
        dropZone.parentNode.insertBefore(fileNameDisplay, dropZone.nextSibling);
    }

    function showError(message) {
        const errorDiv = document.createElement('div');
        errorDiv.className = 'error-message';
        errorDiv.textContent = message;
        document.querySelector('.container').appendChild(errorDiv);
        setTimeout(() => errorDiv.remove(), 3000);
    }

    function showSuccess(message) {
        const successDiv = document.createElement('div');
        successDiv.className = 'success-message';
        successDiv.textContent = message;
        document.querySelector('.container').appendChild(successDiv);
        setTimeout(() => successDiv.remove(), 3000);
    }
});
