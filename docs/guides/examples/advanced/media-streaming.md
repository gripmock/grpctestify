# Media Streaming Examples

File upload, processing, and streaming scenarios for media applications.

## 📁 Example Location

```
examples/advanced-examples/media-streaming/
├── server/           # Go gRPC server implementation
├── tests/           # .gctf test files
└── README.md        # Setup instructions
```

## 🎯 Test Scenarios

### File Upload
Basic file upload with validation:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
media.MediaService/UploadFile

--- REQUEST ---
{
    "filename": "document.pdf",
    "file_size": 1024000,
    "content_type": "application/pdf",
    "metadata": {
        "author": "John Doe",
        "version": "1.0"
    }
}

--- RESPONSE ---
{
    "file": {
        "id": "file_001",
        "filename": "document.pdf",
        "size": 1024000,
        "content_type": "application/pdf",
        "upload_status": "completed",
        "url": "https://storage.example.com/files/file_001"
    },
    "success": true
}

--- ASSERTS ---
.file.id | type == "string"
.file.upload_status == "completed"
.file.size == 1024000
.success == true
```

### Client Streaming - Bulk Upload
Efficient bulk file upload:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
media.MediaService/BulkUploadFiles

--- REQUEST ---
{
    "filename": "image1.jpg",
    "chunk_data": "SGVsbG8gV29ybGQh",
    "chunk_number": 1,
    "total_chunks": 3
}

--- REQUEST ---
{
    "filename": "image1.jpg",
    "chunk_data": "U2Vjb25kIGNodW5r",
    "chunk_number": 2,
    "total_chunks": 3
}

--- REQUEST ---
{
    "filename": "image1.jpg",
    "chunk_data": "RmluYWwgY2h1bms=",
    "chunk_number": 3,
    "total_chunks": 3
}

--- RESPONSE ---
{
    "upload_result": {
        "filename": "image1.jpg",
        "total_chunks": 3,
        "uploaded_chunks": 3,
        "file_id": "file_002",
        "status": "completed"
    },
    "success": true
}

--- ASSERTS ---
.upload_result.total_chunks == 3
.upload_result.uploaded_chunks == 3
.upload_result.status == "completed"
.success == true
```

### Server Streaming - File Processing
Real-time file processing status:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
media.MediaService/ProcessFile

--- REQUEST ---
{
    "file_id": "file_001",
    "processing_type": "video_compression"
}

--- ASSERTS ---
.status == "PROCESSING"
.file_id == "file_001"
.progress_percentage >= 0
.progress_percentage <= 100

--- ASSERTS ---
.status == "COMPRESSING"
.file_id == "file_001"
.progress_percentage >= 50

--- ASSERTS ---
.status == "COMPLETED"
.file_id == "file_001"
.progress_percentage == 100
.output_url | type == "string"
```

### Bidirectional Streaming - Advanced Processing
Complex file processing with feedback:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
media.MediaService/AdvancedFileProcessing

--- REQUEST ---
{
    "command": "START_PROCESSING",
    "file_id": "file_001",
    "options": {
        "quality": "high",
        "format": "mp4"
    }
}

--- ASSERTS ---
.command == "START_PROCESSING"
.status == "PROCESSING_STARTED"
.file_id == "file_001"

--- REQUEST ---
{
    "command": "GET_PROGRESS",
    "file_id": "file_001"
}

--- ASSERTS ---
.command == "GET_PROGRESS"
.file_id == "file_001"
.progress_percentage | type == "number"
.estimated_time_remaining | type == "number"

--- REQUEST ---
{
    "command": "STOP_PROCESSING",
    "file_id": "file_001"
}

--- ASSERTS ---
.command == "STOP_PROCESSING"
.status == "PROCESSING_STOPPED"
.file_id == "file_001"
```

### High Quality Streaming
Server streaming for high-quality video:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
media.MediaService/StreamHighQualityVideo

--- REQUEST ---
{
    "video_id": "video_001",
    "quality": "4k",
    "bitrate": "high"
}

--- ASSERTS ---
.video_id == "video_001"
.quality == "4k"
.chunk_data | type == "string"
.chunk_number | type == "number"

--- ASSERTS ---
.video_id == "video_001"
.quality == "4k"
.chunk_data | type == "string"
.chunk_number | type == "number"
```

### File Metadata Retrieval
Get file information:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
media.MediaService/GetFileMetadata

--- REQUEST ---
{
    "file_id": "file_001"
}

--- RESPONSE ---
{
    "metadata": {
        "file_id": "file_001",
        "filename": "document.pdf",
        "size": 1024000,
        "content_type": "application/pdf",
        "created_at": "2024-01-01T12:00:00Z",
        "last_modified": "2024-01-01T12:05:00Z",
        "checksum": "sha256:abc123...",
        "tags": ["document", "pdf"]
    },
    "success": true
}

--- ASSERTS ---
.metadata.file_id == "file_001"
.metadata.size == 1024000
.metadata.checksum | test("sha256:")
.metadata.tags | length == 2
.success == true
```

## 🔧 Running the Examples

```bash
# Navigate to the example
cd examples/advanced-examples/media-streaming

# Start the server
make start

# Run all tests
../../grpctestify.sh tests/*.gctf

# Run specific test
../../grpctestify.sh tests/upload_file_unary.gctf

# Stop the server
make stop
```

## 📊 Test Coverage

This example demonstrates:

- ✅ **File Upload** - Single and bulk file uploads
- ✅ **Client Streaming** - Chunked file uploads
- ✅ **Server Streaming** - Real-time processing status
- ✅ **Bidirectional Streaming** - Interactive file processing
- ✅ **High Quality Streaming** - Video streaming patterns
- ✅ **File Metadata** - File information management
- ✅ **Processing Workflows** - Complex file processing
- ✅ **Error Handling** - Upload and processing errors

## 🎓 Learning Points

1. **File Operations** - Upload, download, and processing patterns
2. **Streaming** - Efficient large file handling
3. **Media Processing** - Video and audio processing workflows
4. **Progress Tracking** - Real-time status updates
5. **Metadata Management** - File information and organization

## 🔗 Related Examples

- **[IoT Monitoring](../basic/iot-monitoring.md)** - Data streaming patterns
- **[ShopFlow E-commerce](shopflow-ecommerce.md)** - Media integration
- **[AI Chat](ai-chat.md)** - Content processing
