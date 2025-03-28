# Priority Soft - iOS Developer Code Test

## Overview

This iOS app was developed as part of the **Priority Soft iOS Developer Code Test**. The app demonstrates the implementation of a camera feature, handling image uploads, background uploads, and managing offline queues. The primary goal is to ensure that users can take pictures, upload them when internet access is available, and handle retries or failures during the upload process.

## Features

- **Permissions Handling**: 
  - Requests and checks for the required permissions (camera and internet access).
  - If permissions are not granted, the app will prompt the user to enable them in the device settings.

- **Camera Integration**: 
  - The app provides a real-time camera view using the device’s back camera.
  - A button allows users to take a picture.

- **Image Upload**:
  - Images are automatically uploaded to a remote API if internet access is available.
  - If the user is offline, images are saved to a queue for future upload attempts.
  - Failed uploads are retried 5 times, and if still unsuccessful, the image is kept in the queue for future upload attempts.

- **Offline Support**:
  - If the internet connection is restored while the app is in the background or after being terminated, the app uploads all queued images automatically.

- **Geotagging**:
  - All images taken by the app are geotagged with location data before uploading.

- **API Integration**:
  - The app integrates with the provided upload API using `POST` requests with `multipart/form-data` content type.
  - Each image is uploaded individually, ensuring that the 5MB file size limit is respected.


## User Journey

1. **App Initialization**:
   - On app launch, the app checks for camera and internet permissions. If not granted, the user is asked to enable permissions in settings.

2. **Home Page**:
   - The camera view is displayed with a button to take a photo.
   - The header shows upload progress, including whether the app is uploading and how many images are in the queue.

3. **Image Upload**:
   - If the internet is available, the image is uploaded immediately.
   - If the user is offline, the image is queued for later upload.

4. **Offline Image Upload Handling**:
   - Images queued when the user is offline are uploaded once the internet connection is restored.

5. **Upload Failure Handling**:
   - Uploads are retried up to 5 times. If unsuccessful, the image remains in the queue for future upload attempts.

6. **Bonus Task**: 
   - If the app is backgrounded and the internet is regained, queued images are uploaded automatically.

## Installation

1. **Clone the repository**:

   ```bash
   git clone https://github.com/your-username/priority-soft-ios.git
