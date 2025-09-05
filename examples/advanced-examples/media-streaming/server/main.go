package main

import (
	"context"
	"crypto/md5"
	"fmt"
	"io"
	"log"
	"net"
	"sync"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"

	mediapb "github.com/gripmock/grpctestify/examples/advanced-examples/media-streaming/server/mediapb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// MediaStreamingServer implements the MediaStreamingService
type MediaStreamingServer struct {
	mediapb.UnimplementedMediaStreamingServiceServer
	files              map[string]*mediapb.FileMetadata
	fileData           map[string][]byte
	processing         map[string]*mediapb.ProcessingStatus
	mutex              sync.RWMutex
	processingChannels map[string]chan *mediapb.ProcessingResponse
}

// NewMediaStreamingServer creates a new media streaming server
func NewMediaStreamingServer() *MediaStreamingServer {
	s := &MediaStreamingServer{
		files:              make(map[string]*mediapb.FileMetadata),
		fileData:           make(map[string][]byte),
		processing:         make(map[string]*mediapb.ProcessingStatus),
		processingChannels: make(map[string]chan *mediapb.ProcessingResponse),
	}

	// Add sample files
	s.addSampleFiles()

	return s
}

// Add sample files for testing
func (s *MediaStreamingServer) addSampleFiles() {
	sampleFiles := []*mediapb.FileMetadata{
		{
			Id:          "file_001",
			Filename:    "sample_image.jpg",
			ContentType: "image/jpeg",
			FileSize:    1024000,
			UserId:      "user_001",
			Category:    "images",
			IsPublic:    true,
			Status:      mediapb.FileStatus_FILE_STATUS_ACTIVE,
			ProcessingStatus: &mediapb.ProcessingStatus{
				Status:      "completed",
				Progress:    100.0,
				Message:     "File processed successfully",
				StartedAt:   timestamppb.New(time.Now().Add(-1 * time.Hour)),
				CompletedAt: timestamppb.New(time.Now().Add(-30 * time.Minute)),
			},
			CreatedAt:     timestamppb.New(time.Now().Add(-2 * time.Hour)),
			UpdatedAt:     timestamppb.New(time.Now().Add(-30 * time.Minute)),
			LastAccessed:  timestamppb.New(time.Now()),
			Metadata:      map[string]string{"width": "1920", "height": "1080", "format": "JPEG"},
			Tags:          []string{"sample", "image", "test"},
			Checksum:      "md5_hash_001",
			StoragePath:   "/files/user_001/sample_image.jpg",
			DownloadCount: 15,
			AverageRating: 4.5,
		},
		{
			Id:          "file_002",
			Filename:    "document.pdf",
			ContentType: "application/pdf",
			FileSize:    2048000,
			UserId:      "user_002",
			Category:    "documents",
			IsPublic:    false,
			Status:      mediapb.FileStatus_FILE_STATUS_ACTIVE,
			ProcessingStatus: &mediapb.ProcessingStatus{
				Status:      "completed",
				Progress:    100.0,
				Message:     "Document processed successfully",
				StartedAt:   timestamppb.New(time.Now().Add(-2 * time.Hour)),
				CompletedAt: timestamppb.New(time.Now().Add(-1 * time.Hour)),
			},
			CreatedAt:     timestamppb.New(time.Now().Add(-3 * time.Hour)),
			UpdatedAt:     timestamppb.New(time.Now().Add(-1 * time.Hour)),
			LastAccessed:  timestamppb.New(time.Now().Add(-30 * time.Minute)),
			Metadata:      map[string]string{"pages": "25", "author": "John Doe", "version": "1.0"},
			Tags:          []string{"document", "pdf", "business"},
			Checksum:      "md5_hash_002",
			StoragePath:   "/files/user_002/document.pdf",
			DownloadCount: 8,
			AverageRating: 4.2,
		},
		{
			Id:          "file_003",
			Filename:    "video.mp4",
			ContentType: "video/mp4",
			FileSize:    52428800,
			UserId:      "user_001",
			Category:    "videos",
			IsPublic:    true,
			Status:      mediapb.FileStatus_FILE_STATUS_PROCESSING,
			ProcessingStatus: &mediapb.ProcessingStatus{
				Status:    "processing",
				Progress:  65.0,
				Message:   "Video transcoding in progress",
				StartedAt: timestamppb.New(time.Now().Add(-10 * time.Minute)),
				Steps: []*mediapb.ProcessingStep{
					{
						Name:        "metadata_extraction",
						Status:      "completed",
						Progress:    100.0,
						Message:     "Metadata extracted successfully",
						StartedAt:   timestamppb.New(time.Now().Add(-10 * time.Minute)),
						CompletedAt: timestamppb.New(time.Now().Add(-8 * time.Minute)),
					},
					{
						Name:      "transcoding",
						Status:    "processing",
						Progress:  65.0,
						Message:   "Transcoding to H.264",
						StartedAt: timestamppb.New(time.Now().Add(-8 * time.Minute)),
					},
				},
			},
			CreatedAt:     timestamppb.New(time.Now().Add(-15 * time.Minute)),
			UpdatedAt:     timestamppb.New(time.Now()),
			LastAccessed:  timestamppb.New(time.Now()),
			Metadata:      map[string]string{"duration": "120", "resolution": "1080p", "codec": "H.264"},
			Tags:          []string{"video", "mp4", "streaming"},
			Checksum:      "md5_hash_003",
			StoragePath:   "/files/user_001/video.mp4",
			DownloadCount: 3,
			AverageRating: 0.0,
		},
	}

	for _, file := range sampleFiles {
		s.files[file.Id] = file
		// Generate sample file data
		s.fileData[file.Id] = make([]byte, file.FileSize)
		for i := range s.fileData[file.Id] {
			s.fileData[file.Id][i] = byte(i % 256)
		}
	}
}

// UploadFile uploads a file
func (s *MediaStreamingServer) UploadFile(ctx context.Context, req *mediapb.UploadFileRequest) (*mediapb.UploadFileResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	fileID := fmt.Sprintf("file_%03d", len(s.files)+1)
	now := timestamppb.New(time.Now())

	// Calculate checksum
	checksum := fmt.Sprintf("%x", md5.Sum(req.Data))

	// Create file metadata
	metadata := &mediapb.FileMetadata{
		Id:          fileID,
		Filename:    req.Filename,
		ContentType: req.ContentType,
		FileSize:    req.FileSize,
		UserId:      req.UserId,
		Category:    req.Category,
		IsPublic:    req.IsPublic,
		Status:      mediapb.FileStatus_FILE_STATUS_ACTIVE,
		ProcessingStatus: &mediapb.ProcessingStatus{
			Status:    "pending",
			Progress:  0.0,
			Message:   "File uploaded, processing pending",
			StartedAt: now,
		},
		CreatedAt:     now,
		UpdatedAt:     now,
		LastAccessed:  now,
		Metadata:      req.Metadata,
		Tags:          []string{"uploaded", req.Category},
		Checksum:      checksum,
		StoragePath:   fmt.Sprintf("/files/%s/%s", req.UserId, req.Filename),
		DownloadCount: 0,
		AverageRating: 0.0,
	}

	s.files[fileID] = metadata
	s.fileData[fileID] = req.Data

	return &mediapb.UploadFileResponse{
		Success:          true,
		FileId:           fileID,
		Message:          fmt.Sprintf("File %s uploaded successfully", req.Filename),
		Metadata:         metadata,
		ProcessingStatus: metadata.ProcessingStatus,
		UploadedAt:       now,
	}, nil
}

// DownloadFile downloads a file
func (s *MediaStreamingServer) DownloadFile(ctx context.Context, req *mediapb.DownloadFileRequest) (*mediapb.DownloadFileResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	file, exists := s.files[req.FileId]
	if !exists {
		return &mediapb.DownloadFileResponse{
			Success: false,
			Message: "File not found",
		}, nil
	}

	fileData, exists := s.fileData[req.FileId]
	if !exists {
		return &mediapb.DownloadFileResponse{
			Success: false,
			Message: "File data not found",
		}, nil
	}

	// Update download count and last accessed
	s.mutex.Lock()
	file.DownloadCount++
	file.LastAccessed = timestamppb.New(time.Now())
	s.mutex.Unlock()

	return &mediapb.DownloadFileResponse{
		Success:     true,
		FileId:      req.FileId,
		Data:        fileData,
		Metadata:    file,
		ContentType: file.ContentType,
		FileSize:    file.FileSize,
		Message:     fmt.Sprintf("File %s downloaded successfully", file.Filename),
	}, nil
}

// GetFileMetadata retrieves file metadata
func (s *MediaStreamingServer) GetFileMetadata(ctx context.Context, req *mediapb.GetFileMetadataRequest) (*mediapb.GetFileMetadataResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	file, exists := s.files[req.FileId]
	if !exists {
		return &mediapb.GetFileMetadataResponse{
			Found: false,
		}, nil
	}

	return &mediapb.GetFileMetadataResponse{
		Found:            true,
		Metadata:         file,
		ProcessingStatus: file.ProcessingStatus,
	}, nil
}

// UpdateFileMetadata updates file metadata
func (s *MediaStreamingServer) UpdateFileMetadata(ctx context.Context, req *mediapb.UpdateFileMetadataRequest) (*mediapb.UpdateFileMetadataResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	file, exists := s.files[req.FileId]
	if !exists {
		return &mediapb.UpdateFileMetadataResponse{
			Success: false,
			Message: "File not found",
		}, nil
	}

	// Update metadata
	for key, value := range req.Metadata {
		file.Metadata[key] = value
	}

	if req.Category != "" {
		file.Category = req.Category
	}

	file.IsPublic = req.IsPublic
	file.UpdatedAt = timestamppb.New(time.Now())

	return &mediapb.UpdateFileMetadataResponse{
		Success:  true,
		Message:  fmt.Sprintf("Metadata updated for file %s", req.FileId),
		Metadata: file,
	}, nil
}

// DeleteFile deletes a file
func (s *MediaStreamingServer) DeleteFile(ctx context.Context, req *mediapb.DeleteFileRequest) (*mediapb.DeleteFileResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	file, exists := s.files[req.FileId]
	if !exists {
		return &mediapb.DeleteFileResponse{
			Success: false,
			Message: "File not found",
		}, nil
	}

	if req.Permanent {
		// Permanent deletion
		delete(s.files, req.FileId)
		delete(s.fileData, req.FileId)
		delete(s.processing, req.FileId)
	} else {
		// Soft deletion
		file.Status = mediapb.FileStatus_FILE_STATUS_DELETED
		file.UpdatedAt = timestamppb.New(time.Now())
	}

	return &mediapb.DeleteFileResponse{
		Success: true,
		Message: fmt.Sprintf("File %s deleted successfully", req.FileId),
		FileId:  req.FileId,
	}, nil
}

// ListFiles lists files
func (s *MediaStreamingServer) ListFiles(ctx context.Context, req *mediapb.ListFilesRequest) (*mediapb.ListFilesResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	var files []*mediapb.FileMetadata
	var count int32

	for _, file := range s.files {
		// Filter by user
		if file.UserId != req.UserId && !req.IncludePublic {
			continue
		}

		// Filter by category
		if req.Category != "" && file.Category != req.Category {
			continue
		}

		// Skip deleted files
		if file.Status == mediapb.FileStatus_FILE_STATUS_DELETED {
			continue
		}

		files = append(files, file)
		count++
	}

	// Apply limit and offset
	start := int(req.Offset)
	end := start + int(req.Limit)
	if end > len(files) {
		end = len(files)
	}
	if start > len(files) {
		start = len(files)
	}

	return &mediapb.ListFilesResponse{
		Files:      files[start:end],
		TotalCount: count,
		HasMore:    end < len(files),
		Limit:      req.Limit,
		Offset:     req.Offset,
	}, nil
}

// HealthCheck provides service health information
func (s *MediaStreamingServer) HealthCheck(ctx context.Context, req *mediapb.HealthCheckRequest) (*mediapb.HealthCheckResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	totalStorage := int64(0)
	activeFiles := 0
	storageByCategory := make(map[string]int64)
	filesByCategory := make(map[string]int32)

	for _, file := range s.files {
		if file.Status == mediapb.FileStatus_FILE_STATUS_ACTIVE {
			activeFiles++
			totalStorage += file.FileSize
			storageByCategory[file.Category] += file.FileSize
			filesByCategory[file.Category]++
		}
	}

	return &mediapb.HealthCheckResponse{
		Status:    "healthy",
		Version:   "1.0.0",
		Timestamp: timestamppb.New(time.Now()),
		Metadata: map[string]string{
			"total_files": fmt.Sprintf("%d", len(s.files)),
			"service":     "media-streaming",
		},
		StorageMetrics: &mediapb.StorageMetrics{
			TotalStorageBytes:         totalStorage,
			UsedStorageBytes:          totalStorage,
			AvailableStorageBytes:     107374182400, // 100GB
			TotalFiles:                int32(len(s.files)),
			ActiveFiles:               int32(activeFiles),
			StorageUtilizationPercent: float64(totalStorage) / 107374182400 * 100,
			StorageByCategory:         storageByCategory,
			FilesByCategory:           filesByCategory,
		},
	}, nil
}

// StreamFile streams a file in chunks
func (s *MediaStreamingServer) StreamFile(req *mediapb.StreamFileRequest, stream mediapb.MediaStreamingService_StreamFileServer) error {
	s.mutex.RLock()
	file, exists := s.files[req.FileId]
	fileData, dataExists := s.fileData[req.FileId]
	s.mutex.RUnlock()

	if !exists || !dataExists {
		return fmt.Errorf("file not found")
	}

	chunkSize := int(req.ChunkSize)
	if chunkSize == 0 {
		chunkSize = 1024 * 1024 // 1MB default
	}

	startOffset := req.StartOffset
	endOffset := req.EndOffset
	if endOffset == 0 {
		endOffset = int64(len(fileData))
	}

	totalChunks := int32((endOffset - startOffset + int64(chunkSize) - 1) / int64(chunkSize))
	chunkNumber := int32(0)

	for offset := startOffset; offset < endOffset; offset += int64(chunkSize) {
		chunkNumber++
		chunkEnd := offset + int64(chunkSize)
		if chunkEnd > endOffset {
			chunkEnd = endOffset
		}

		chunk := &mediapb.FileChunk{
			FileId:      req.FileId,
			ChunkNumber: chunkNumber,
			TotalChunks: totalChunks,
			Data:        fileData[offset:chunkEnd],
			Offset:      offset,
			ChunkSize:   int32(chunkEnd - offset),
			IsLastChunk: chunkNumber == totalChunks,
			Timestamp:   timestamppb.New(time.Now()),
			ChunkMetadata: map[string]string{
				"checksum": fmt.Sprintf("%x", md5.Sum(fileData[offset:chunkEnd])),
			},
		}

		if req.IncludeMetadata && chunkNumber == 1 {
			chunk.Metadata = file
		}

		if err := stream.Send(chunk); err != nil {
			return err
		}

		time.Sleep(10 * time.Millisecond) // Simulate streaming delay
	}

	return nil
}

// UploadLargeFile uploads a large file in chunks
func (s *MediaStreamingServer) UploadLargeFile(stream mediapb.MediaStreamingService_UploadLargeFileServer) error {
	var fileID string
	var filename string
	var contentType string
	var userID string
	var metadata map[string]string
	var totalSize int64
	_ = totalSize // Remove unused variable - keeping for future use
	var chunks [][]byte
	var chunkNumber int32

	for {
		chunk, err := stream.Recv()
		if err != nil {
			break
		}

		if chunkNumber == 0 {
			// First chunk contains metadata
			fileID = chunk.FileId
			filename = chunk.Metadata.Filename
			contentType = chunk.Metadata.ContentType
			userID = chunk.Metadata.UserId
			metadata = chunk.Metadata.Metadata
			totalSize = chunk.Metadata.FileSize
		}

		chunks = append(chunks, chunk.Data)
		chunkNumber++
	}

	// Combine chunks
	var fileData []byte
	for _, chunk := range chunks {
		fileData = append(fileData, chunk...)
	}

	// Create file metadata
	now := timestamppb.New(time.Now())
	checksum := fmt.Sprintf("%x", md5.Sum(fileData))

	fileMetadata := &mediapb.FileMetadata{
		Id:          fileID,
		Filename:    filename,
		ContentType: contentType,
		FileSize:    int64(len(fileData)),
		UserId:      userID,
		Category:    "uploads",
		IsPublic:    false,
		Status:      mediapb.FileStatus_FILE_STATUS_ACTIVE,
		ProcessingStatus: &mediapb.ProcessingStatus{
			Status:      "completed",
			Progress:    100.0,
			Message:     "Large file uploaded successfully",
			StartedAt:   now,
			CompletedAt: now,
		},
		CreatedAt:     now,
		UpdatedAt:     now,
		LastAccessed:  now,
		Metadata:      metadata,
		Tags:          []string{"large_upload", "chunked"},
		Checksum:      checksum,
		StoragePath:   fmt.Sprintf("/files/%s/%s", userID, filename),
		DownloadCount: 0,
		AverageRating: 0.0,
	}

	s.mutex.Lock()
	s.files[fileID] = fileMetadata
	s.fileData[fileID] = fileData
	s.mutex.Unlock()

	response := &mediapb.UploadFileResponse{
		Success:          true,
		FileId:           fileID,
		Message:          fmt.Sprintf("Large file %s uploaded successfully in %d chunks", filename, chunkNumber),
		Metadata:         fileMetadata,
		ProcessingStatus: fileMetadata.ProcessingStatus,
		UploadedAt:       now,
	}

	return stream.SendAndClose(response)
}

// ProcessFile provides bidirectional streaming for file processing
func (s *MediaStreamingServer) ProcessFile(stream mediapb.MediaStreamingService_ProcessFileServer) error {
	processingID := fmt.Sprintf("proc_%d", time.Now().Unix())
	responseChan := make(chan *mediapb.ProcessingResponse, 100)
	s.mutex.Lock()
	s.processingChannels[processingID] = responseChan
	s.mutex.Unlock()

	defer func() {
		s.mutex.Lock()
		delete(s.processingChannels, processingID)
		s.mutex.Unlock()
		close(responseChan)
	}()

	// Start processing simulation goroutine
	go func() {
		ticker := time.NewTicker(2 * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				// Generate sample processing response
				response := &mediapb.ProcessingResponse{
					RequestId: fmt.Sprintf("req_%d", time.Now().Unix()),
					FileId:    "file_001",
					Operation: mediapb.ProcessingOperation_PROCESSING_OPERATION_THUMBNAIL,
					Status: &mediapb.ProcessingStatus{
						Status:    "processing",
						Progress:  75.0,
						Message:   "Generating thumbnail...",
						StartedAt: timestamppb.New(time.Now().Add(-30 * time.Second)),
					},
					Progress: 75.0,
					Message:  "Thumbnail generation in progress",
					Result: &mediapb.ProcessingResult{
						ResultType: "thumbnail",
						ResultData: "thumbnail_001.jpg",
						Metadata:   map[string]string{"width": "300", "height": "200"},
					},
					Timestamp: timestamppb.New(time.Now()),
				}

				select {
				case responseChan <- response:
				default:
					// Channel full, skip this response
				}
			}
		}
	}()

	// Handle incoming processing requests and send responses
	for {
		processingReq, err := stream.Recv()
		if err != nil {
			if err == io.EOF {
				return nil
			}
			return err
		}

		// Process request and generate response
		response := &mediapb.ProcessingResponse{
			RequestId: processingReq.RequestId,
			FileId:    processingReq.FileId,
			Operation: processingReq.Operation,
			Status: &mediapb.ProcessingStatus{
				Status:    "processing",
				Progress:  25.0,
				Message:   fmt.Sprintf("Processing %s operation", processingReq.Operation),
				StartedAt: timestamppb.New(time.Now()),
			},
			Progress: 25.0,
			Message:  fmt.Sprintf("Started %s operation", processingReq.Operation),
			Result: &mediapb.ProcessingResult{
				ResultType: "processing_started",
				ResultData: "Operation initiated",
				Metadata:   processingReq.Parameters,
			},
			Timestamp: timestamppb.New(time.Now()),
		}

		if err := stream.Send(response); err != nil {
			return err
		}
	}
}

func main() {
	// Create listener
	lis, err := net.Listen("tcp", ":50057")
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	// Create gRPC server
	s := grpc.NewServer()

	// Register services
	mediaServer := NewMediaStreamingServer()
	mediapb.RegisterMediaStreamingServiceServer(s, mediaServer)
	reflection.Register(s)

	fmt.Println("📺 Media Streaming Service is running on port 50057...")
	fmt.Println("Available methods:")
	fmt.Println("  - UploadFile, DownloadFile, GetFileMetadata, UpdateFileMetadata")
	fmt.Println("  - DeleteFile, ListFiles, HealthCheck")
	fmt.Println("  - StreamFile, UploadLargeFile, ProcessFile")

	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
