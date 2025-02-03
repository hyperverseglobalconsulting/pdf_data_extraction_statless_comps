document.getElementById('uploadBtn').addEventListener('click', async function () {
  const fileInput = document.getElementById('fileInput');
  const statusDiv = document.getElementById('status');

  if (fileInput.files.length === 0) {
    alert("Please select a PDF file.");
    return;
  }

  const file = fileInput.files[0];

  const presignedUrlEndpoint = ${API_ENDPOINT};

  // Step 1: Request presigned URL from your API
  try {
    statusDiv.innerText = "Requesting presigned URL...";
    const presignResponse = await fetch(
	    presignedUrlEndpoint,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-amz-acl': 'public-read'
        },
        body: JSON.stringify({ filename: file.name })
      }
    );

    if (!presignResponse.ok) {
      throw new Error("Failed to get presigned URL");
    }

    const { uploadUrl, objectKey } = await presignResponse.json();
    statusDiv.innerText = "Presigned URL received. Uploading file...";

    // Step 2: Upload the file using the presigned URL via PUT
    const uploadResponse = await fetch(uploadUrl, {
      method: 'PUT',
      headers: {
        'Content-Type': file.type // for a PDF, should be "application/pdf"
      },
      body: file
    });

    if (!uploadResponse.ok) {
      throw new Error("File upload failed");
    }

    statusDiv.innerText = "File uploaded successfully!";
    // You can display the objectKey or use it to construct a download URL later
    console.log("Uploaded object key:", objectKey);
  } catch (error) {
    console.error("Error:", error);
    statusDiv.innerText = "Error: " + error.message;
  }
});

