package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"sync"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/reflection"
	"google.golang.org/protobuf/types/known/emptypb"

	filestoragepb "github.com/gripmock/grpctestify/examples/file-storage/server/filestoragepb"
)

// FileStorageServer implements the FileStorageService
type FileStorageServer struct {
	filestoragepb.UnimplementedFileStorageServiceServer
	files map[string]*FileInfo
	mutex sync.RWMutex
}

type FileInfo struct {
	ID           string
	Filename     string
	Size         int64
	Chunks       map[int32][]byte
	TotalChunks  int32
	ReceivedSize int64
	Checksum     string
	Metadata     map[string]string
	CreatedAt    time.Time
}

func NewFileStorageServer() *FileStorageServer {
	return &FileStorageServer{
		files: make(map[string]*FileInfo),
	}
}

// UploadFiles handles client streaming file uploads
func (s *FileStorageServer) UploadFiles(stream filestoragepb.FileStorageService_UploadFilesServer) error {
	var currentFile *FileInfo

	for {
		chunk, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}

		s.mutex.Lock()

		// Initialize file if first chunk
		if currentFile == nil || currentFile.ID != chunk.FileId {
			currentFile = &FileInfo{
				ID:          chunk.FileId,
				Filename:    chunk.Filename,
				TotalChunks: chunk.TotalChunks,
				Chunks:      make(map[int32][]byte),
				Metadata:    chunk.Metadata,
				CreatedAt:   time.Now(),
			}
			s.files[chunk.FileId] = currentFile
		}

		// Store chunk
		currentFile.Chunks[chunk.ChunkIndex] = chunk.Data
		currentFile.ReceivedSize += int64(len(chunk.Data))
		currentFile.Checksum = chunk.Checksum

		// Check if file is complete
		isComplete := len(currentFile.Chunks) == int(currentFile.TotalChunks)
		var response *filestoragepb.UploadResponse

		if isComplete {
			// File is complete
			response = &filestoragepb.UploadResponse{
				FileId:           chunk.FileId,
				Status:           "FILE_COMPLETE",
				Message:          fmt.Sprintf("File upload completed"),
				BytesReceived:    currentFile.ReceivedSize,
				TotalSize:        currentFile.ReceivedSize,
				Url:              fmt.Sprintf("https://storage.example.com/files/%s", chunk.FileId),
				ChecksumVerified: true,
			}
		} else {
			// Chunk received
			response = &filestoragepb.UploadResponse{
				FileId:        chunk.FileId,
				Status:        "CHUNK_RECEIVED",
				Message:       fmt.Sprintf("Chunk %d/%d received", chunk.ChunkIndex, chunk.TotalChunks),
				BytesReceived: currentFile.ReceivedSize,
			}
		}

		s.mutex.Unlock()

		// Send response
		if err := stream.Send(response); err != nil {
			return err
		}
	}

	return nil
}

// UploadSecureFile handles secure file uploads with streaming response
func (s *FileStorageServer) UploadSecureFile(req *filestoragepb.SecureFile, stream filestoragepb.FileStorageService_UploadSecureFileServer) error {
	fileID := fmt.Sprintf("secure_%d", time.Now().UnixNano())

	// Stage 1: Security Check
	securityResponse := &filestoragepb.SecureUploadResponse{
		Status:             "SECURITY_CHECK",
		Message:            "Performing security validation",
		EncryptionVerified: req.Encryption == "AES256",
		VirusScanStatus:    "clean",
	}
	if err := stream.Send(securityResponse); err != nil {
		return err
	}

	time.Sleep(500 * time.Millisecond) // Simulate processing

	// Stage 2: Encrypted Storage
	storageResponse := &filestoragepb.SecureUploadResponse{
		Status:          "ENCRYPTED_STORAGE",
		Message:         "Storing with encryption",
		StorageLocation: fmt.Sprintf("encrypted://secure-storage/%s", fileID),
		BackupCreated:   true,
	}
	if err := stream.Send(storageResponse); err != nil {
		return err
	}

	time.Sleep(500 * time.Millisecond) // Simulate processing

	// Stage 3: Upload Complete
	completeResponse := &filestoragepb.SecureUploadResponse{
		Status:      "UPLOAD_COMPLETE",
		Message:     "Secure upload completed",
		FileId:      fileID,
		AccessUrl:   fmt.Sprintf("https://secure.example.com/files/%s?token=secure_token_123", fileID),
		AuditLogged: true,
	}
	if err := stream.Send(completeResponse); err != nil {
		return err
	}

	// Store file info
	s.mutex.Lock()
	s.files[fileID] = &FileInfo{
		ID:        fileID,
		Filename:  req.Filename,
		Size:      req.Size,
		Checksum:  req.Checksum,
		Metadata:  req.Metadata,
		CreatedAt: time.Now(),
	}
	s.mutex.Unlock()

	return nil
}

// HealthCheck provides health status
func (s *FileStorageServer) HealthCheck(ctx context.Context, req *emptypb.Empty) (*filestoragepb.HealthCheckResponse, error) {
	return &filestoragepb.HealthCheckResponse{
		Status:  "healthy",
		Message: "File storage service is running",
		Uptime:  time.Since(startTime).String(),
	}, nil
}

var startTime = time.Now()

func main() {
	// Check if TLS certificates exist (using user-management certificates)
	useTLS := false
	if _, err := os.Stat("../user-management/server/tls/server-cert.pem"); err == nil {
		if _, err := os.Stat("../user-management/server/tls/server-key.pem"); err == nil {
			useTLS = true
		}
	}

	var lis net.Listener
	var err error

	if useTLS {
		// Load TLS certificates
		cert, err := tls.LoadX509KeyPair("../user-management/server/tls/server-cert.pem", "../user-management/server/tls/server-key.pem")
		if err != nil {
			log.Fatalf("Failed to load TLS certificates: %v", err)
		}

		// Create TLS configuration
		tlsConfig := &tls.Config{
			Certificates: []tls.Certificate{cert},
			ClientAuth:   tls.NoClientCert,
		}

		// Create TLS listener
		lis, err = tls.Listen("tcp", ":50051", tlsConfig)
		if err != nil {
			log.Fatalf("Failed to listen with TLS: %v", err)
		}

		log.Println("🔒 File Storage Service is running with TLS on port 50051...")
	} else {
		// Create plain TCP listener
		lis, err = net.Listen("tcp", ":50051")
		if err != nil {
			log.Fatalf("Failed to listen: %v", err)
		}

		log.Println("⚠️  File Storage Service is running without TLS on port 50051...")
		log.Println("   Run 'make tls' in user-management/server to generate TLS certificates")
	}

	// Create gRPC server
	var s *grpc.Server
	if useTLS {
		// Load certificates again for gRPC server
		cert, err := tls.LoadX509KeyPair("../user-management/server/tls/server-cert.pem", "../user-management/server/tls/server-key.pem")
		if err != nil {
			log.Fatalf("Failed to load TLS certificates for gRPC: %v", err)
		}

		// Create server with TLS credentials
		creds := credentials.NewTLS(&tls.Config{
			Certificates: []tls.Certificate{cert},
		})
		s = grpc.NewServer(grpc.Creds(creds))
	} else {
		// Create server without TLS
		s = grpc.NewServer()
	}

	fileStorageServer := NewFileStorageServer()
	filestoragepb.RegisterFileStorageServiceServer(s, fileStorageServer)
	reflection.Register(s)

	log.Println("Available methods:")
	log.Println("  - UploadFiles (Client Streaming)")
	log.Println("  - UploadSecureFile (Server Streaming)")
	log.Println("  - HealthCheck (Unary)")
	log.Println("📁 Ready for file upload and secure storage")

	if err := s.Serve(lis); err != nil {
		log.Fatalf("Failed to serve gRPC server: %v", err)
	}
}
