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
	"google.golang.org/grpc/codes"

	pb "github.com/gripmock/grpctestify/examples/basic-examples/real-time-chat/server/chatpb"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
)

// ChatServer implements the gRPC chat service
type ChatServer struct {
	pb.UnimplementedChatServiceServer

	// In-memory storage for demo purposes
	rooms    map[string]*pb.ChatRoom
	users    map[string]*pb.User
	messages map[string][]*pb.ChatMessage
	streams  map[string][]pb.ChatService_ChatServer
	mu       sync.RWMutex
}

// NewChatServer creates a new chat server instance
func NewChatServer() *ChatServer {
	server := &ChatServer{
		rooms:    make(map[string]*pb.ChatRoom),
		users:    make(map[string]*pb.User),
		messages: make(map[string][]*pb.ChatMessage),
		streams:  make(map[string][]pb.ChatService_ChatServer),
	}

	// Initialize with sample data
	server.initializeSampleData()
	return server
}

// initializeSampleData creates sample rooms and users for testing
func (s *ChatServer) initializeSampleData() {
	// Sample rooms
	s.rooms["room1"] = &pb.ChatRoom{
		Id:          "room1",
		Name:        "General Discussion",
		Description: "General chat room for all users",
		CreatedBy:   "user1",
		CreatedAt:   time.Now().Format(time.RFC3339),
		Members:     []string{"user1", "user2", "user3"},
		IsPrivate:   false,
		MaxMembers:  100,
	}

	s.rooms["room2"] = &ChatRoom{
		Id:          "room2",
		Name:        "Tech Support",
		Description: "Technical support and help",
		CreatedBy:   "user1",
		CreatedAt:   time.Now().Format(time.RFC3339),
		Members:     []string{"user1", "user2"},
		IsPrivate:   false,
		MaxMembers:  50,
	}

	// Sample users
	s.users["user1"] = &User{
		Id:          "user1",
		Username:    "alice",
		DisplayName: "Alice Johnson",
		AvatarUrl:   "https://example.com/avatars/alice.jpg",
		Online:      true,
		LastSeen:    time.Now().Format(time.RFC3339),
	}

	s.users["user2"] = &User{
		Id:          "user2",
		Username:    "bob",
		DisplayName: "Bob Smith",
		AvatarUrl:   "https://example.com/avatars/bob.jpg",
		Online:      false,
		LastSeen:    time.Now().Add(-1 * time.Hour).Format(time.RFC3339),
	}

	s.users["user3"] = &User{
		Id:          "user3",
		Username:    "charlie",
		DisplayName: "Charlie Brown",
		AvatarUrl:   "https://example.com/avatars/charlie.jpg",
		Online:      true,
		LastSeen:    time.Now().Format(time.RFC3339),
	}

	// Sample messages
	s.messages["room1"] = []*pb.ChatMessage{
		{
			Id:          "msg1",
			UserId:      "user1",
			RoomId:      "room1",
			Content:     "Hello everyone! Welcome to the general discussion room.",
			MessageType: "text",
			Timestamp:   time.Now().Add(-2 * time.Hour).Format(time.RFC3339),
		},
		{
			Id:          "msg2",
			UserId:      "user2",
			RoomId:      "room1",
			Content:     "Hi Alice! Great to be here.",
			MessageType: "text",
			Timestamp:   time.Now().Add(-1 * time.Hour).Format(time.RFC3339),
		},
	}

	s.messages["room2"] = []*pb.ChatMessage{
		{
			Id:          "msg3",
			UserId:      "user1",
			RoomId:      "room2",
			Content:     "How can I help you today?",
			MessageType: "text",
			Timestamp:   time.Now().Add(-30 * time.Minute).Format(time.RFC3339),
		},
	}
}

// SendMessage handles sending a single message (Unary RPC)
func (s *ChatServer) SendMessage(ctx context.Context, req *pb.SendMessageRequest) (*pb.SendMessageResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Validate request
	if req.Message == nil {
		return nil, status.Error(codes.InvalidArgument, "message cannot be nil")
	}

	if req.Message.UserId == "" || req.Message.RoomId == "" || req.Message.Content == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id, room_id, and content are required")
	}

	// Check if room exists
	room, exists := s.rooms[req.Message.RoomId]
	if !exists {
		return nil, status.Error(codes.NotFound, "room not found")
	}

	// Check if user is member of the room
	userIsMember := false
	for _, memberID := range room.Members {
		if memberID == req.Message.UserId {
			userIsMember = true
			break
		}
	}
	if !userIsMember {
		return nil, status.Error(codes.PermissionDenied, "user is not a member of this room")
	}

	// Generate message ID and timestamp
	message := &pb.ChatMessage{
		Id:          fmt.Sprintf("msg_%d", time.Now().UnixNano()),
		UserId:      req.Message.UserId,
		RoomId:      req.Message.RoomId,
		Content:     req.Message.Content,
		MessageType: req.Message.MessageType,
		Timestamp:   time.Now().Format(time.RFC3339),
		Metadata:    req.Message.Metadata,
		Mentions:    req.Message.Mentions,
		ReplyTo:     req.Message.ReplyTo,
	}

	if message.MessageType == "" {
		message.MessageType = "text"
	}

	// Store message
	s.messages[req.Message.RoomId] = append(s.messages[req.Message.RoomId], message)

	// Broadcast to all connected streams for this room
	s.broadcastToRoom(req.Message.RoomId, message)

	return &pb.SendMessageResponse{
		Message: message,
		Success: true,
	}, nil
}

// GetMessages retrieves messages from a room (Unary RPC)
func (s *ChatServer) GetMessages(ctx context.Context, req *pb.GetMessagesRequest) (*pb.GetMessagesResponse, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if req.RoomId == "" {
		return nil, status.Error(codes.InvalidArgument, "room_id is required")
	}

	// Check if room exists
	if _, exists := s.rooms[req.RoomId]; !exists {
		return nil, status.Error(codes.NotFound, "room not found")
	}

	messages := s.messages[req.RoomId]

	// Apply pagination if specified
	if req.Limit > 0 {
		start := int(req.Offset)
		end := start + int(req.Limit)

		if start >= len(messages) {
			messages = []*pb.ChatMessage{}
		} else {
			if end > len(messages) {
				end = len(messages)
			}
			messages = messages[start:end]
		}
	}

	return &pb.GetMessagesResponse{
		Messages: messages,
		Total:    int32(len(s.messages[req.RoomId])),
	}, nil
}

// ChatStream handles bidirectional streaming chat (Bidirectional Streaming RPC)
func (s *ChatServer) ChatStream(stream pb.ChatService_ChatServer) error {
	// Handle incoming stream
	go func() {
		for {
			action, err := stream.Recv()
			if err == io.EOF {
				return
			}
			if err != nil {
				log.Printf("Error receiving from stream: %v", err)
				return
			}

			// Process chat action
			s.processChatAction(stream, action)
		}
	}()

	// Keep the stream alive
	select {
	case <-stream.Context().Done():
		return stream.Context().Err()
	}
}

// processChatAction handles incoming chat actions
func (s *ChatServer) processChatAction(stream pb.ChatService_ChatServer, action *pb.ChatAction) {
	s.mu.Lock()
	defer s.mu.Unlock()

	switch action.ActionType {
	case "join":
		// Add stream to room
		if s.streams[action.RoomId] == nil {
			s.streams[action.RoomId] = make([]pb.ChatService_ChatServer, 0)
		}
		s.streams[action.RoomId] = append(s.streams[action.RoomId], stream)

		// Send join confirmation
		stream.Send(&pb.ChatAction{
			UserId:     action.UserId,
			RoomId:     action.RoomId,
			ActionType: "joined",
			Metadata:   map[string]string{"status": "success"},
		})

	case "send":
		if action.Message != nil {
			// Generate message ID and timestamp
			message := &pb.ChatMessage{
				Id:          fmt.Sprintf("msg_%d", time.Now().UnixNano()),
				UserId:      action.UserId,
				RoomId:      action.RoomId,
				Content:     action.Message.Content,
				MessageType: action.Message.MessageType,
				Timestamp:   time.Now().Format(time.RFC3339),
				Metadata:    action.Message.Metadata,
				Mentions:    action.Message.Mentions,
				ReplyTo:     action.Message.ReplyTo,
			}

			if message.MessageType == "" {
				message.MessageType = "text"
			}

			// Store message
			s.messages[action.RoomId] = append(s.messages[action.RoomId], message)

			// Broadcast to all streams in the room
			s.broadcastToRoom(action.RoomId, message)
		}

	case "typing":
		// Broadcast typing indicator
		typingAction := &pb.ChatAction{
			UserId:     action.UserId,
			RoomId:     action.RoomId,
			ActionType: "user_typing",
			Metadata:   action.Metadata,
		}
		s.broadcastActionToRoom(action.RoomId, typingAction, stream)

	case "stop_typing":
		// Broadcast stop typing indicator
		stopTypingAction := &pb.ChatAction{
			UserId:     action.UserId,
			RoomId:     action.RoomId,
			ActionType: "user_stop_typing",
			Metadata:   action.Metadata,
		}
		s.broadcastActionToRoom(action.RoomId, stopTypingAction, stream)
	}
}

// broadcastToRoom sends a message to all connected streams in a room
func (s *ChatServer) broadcastToRoom(roomID string, message *pb.ChatMessage) {
	streams := s.streams[roomID]
	for i := len(streams) - 1; i >= 0; i-- {
		stream := streams[i]
		err := stream.Send(&pb.ChatAction{
			UserId:     message.UserId,
			RoomId:     message.RoomId,
			ActionType: "message",
			Message:    message,
		})
		if err != nil {
			// Remove disconnected stream
			streams = append(streams[:i], streams[i+1:]...)
		}
	}
	s.streams[roomID] = streams
}

// broadcastActionToRoom sends an action to all connected streams in a room except sender
func (s *ChatServer) broadcastActionToRoom(roomID string, action *pb.ChatAction, sender pb.ChatService_ChatServer) {
	streams := s.streams[roomID]
	for i := len(streams) - 1; i >= 0; i-- {
		stream := streams[i]
		if stream != sender {
			err := stream.Send(action)
			if err != nil {
				// Remove disconnected stream
				streams = append(streams[:i], streams[i+1:]...)
			}
		}
	}
	s.streams[roomID] = streams
}

// GetRooms retrieves available chat rooms (Unary RPC)
func (s *ChatServer) GetRooms(ctx context.Context, req *pb.GetRoomsRequest) (*pb.GetRoomsResponse, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	rooms := make([]*pb.ChatRoom, 0, len(s.rooms))
	for _, room := range s.rooms {
		// Filter private rooms if user is not a member
		if room.IsPrivate && req.UserId != "" {
			isMember := false
			for _, memberID := range room.Members {
				if memberID == req.UserId {
					isMember = true
					break
				}
			}
			if !isMember {
				continue
			}
		}
		rooms = append(rooms, room)
	}

	return &pb.GetRoomsResponse{
		Rooms: rooms,
	}, nil
}

// GetUsers retrieves users in a room (Unary RPC)
func (s *ChatServer) GetUsers(ctx context.Context, req *pb.GetUsersRequest) (*pb.GetUsersResponse, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if req.RoomId == "" {
		return nil, status.Error(codes.InvalidArgument, "room_id is required")
	}

	room, exists := s.rooms[req.RoomId]
	if !exists {
		return nil, status.Error(codes.NotFound, "room not found")
	}

	users := make([]*User, 0, len(room.Members))
	for _, memberID := range room.Members {
		if user, exists := s.users[memberID]; exists {
			users = append(users, user)
		}
	}

	return &GetUsersResponse{
		Users: users,
	}, nil
}

// JoinRoom adds a user to a room (Unary RPC)
func (s *ChatServer) JoinRoom(ctx context.Context, req *JoinRoomRequest) (*JoinRoomResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if req.UserId == "" || req.RoomId == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id and room_id are required")
	}

	room, exists := s.rooms[req.RoomId]
	if !exists {
		return nil, status.Error(codes.NotFound, "room not found")
	}

	// Check if user is already a member
	for _, memberID := range room.Members {
		if memberID == req.UserId {
			return &JoinRoomResponse{
				Success: true,
				Message: "User is already a member of this room",
			}, nil
		}
	}

	// Check room capacity
	if room.MaxMembers > 0 && len(room.Members) >= int(room.MaxMembers) {
		return nil, status.Error(codes.ResourceExhausted, "room is at maximum capacity")
	}

	// Add user to room
	room.Members = append(room.Members, req.UserId)

	return &JoinRoomResponse{
		Success: true,
		Message: "Successfully joined the room",
	}, nil
}

// LeaveRoom removes a user from a room (Unary RPC)
func (s *ChatServer) LeaveRoom(ctx context.Context, req *LeaveRoomRequest) (*LeaveRoomResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if req.UserId == "" || req.RoomId == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id and room_id are required")
	}

	room, exists := s.rooms[req.RoomId]
	if !exists {
		return nil, status.Error(codes.NotFound, "room not found")
	}

	// Remove user from room
	for i, memberID := range room.Members {
		if memberID == req.UserId {
			room.Members = append(room.Members[:i], room.Members[i+1:]...)
			return &LeaveRoomResponse{
				Success: true,
				Message: "Successfully left the room",
			}, nil
		}
	}

	return &LeaveRoomResponse{
		Success: false,
		Message: "User is not a member of this room",
	}, nil
}

// GetUserProfile retrieves user profile information (Unary RPC)
func (s *ChatServer) GetUserProfile(ctx context.Context, req *GetUserProfileRequest) (*GetUserProfileResponse, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if req.UserId == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id is required")
	}

	user, exists := s.users[req.UserId]
	if !exists {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	return &GetUserProfileResponse{
		User: user,
	}, nil
}

// UpdateUserStatus updates user online status (Unary RPC)
func (s *ChatServer) UpdateUserStatus(ctx context.Context, req *UpdateUserStatusRequest) (*UpdateUserStatusResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if req.UserId == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id is required")
	}

	user, exists := s.users[req.UserId]
	if !exists {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	// Update user status
	user.Online = req.Online
	if req.Online {
		user.LastSeen = time.Now().Format(time.RFC3339)
	}
	if req.Status != nil {
		user.Status = req.Status
	}

	return &UpdateUserStatusResponse{
		Success: true,
		User:    user,
	}, nil
}

// HealthCheck provides a simple health check endpoint
func (s *ChatServer) HealthCheck(ctx context.Context, req *emptypb.Empty) (*HealthCheckResponse, error) {
	return &HealthCheckResponse{
		Status:  "healthy",
		Message: "Chat service is running",
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

	var listener net.Listener
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
			ClientAuth:   tls.NoClientCert, // For now, no client cert required
		}

		// Create TLS listener
		listener, err = tls.Listen("tcp", ":50057", tlsConfig)
		if err != nil {
			log.Fatalf("Failed to listen with TLS: %v", err)
		}

		log.Println("🔒 Real-time Chat gRPC Server starting with TLS on :50057")
	} else {
		// Create plain TCP listener
		listener, err = net.Listen("tcp", ":50057")
		if err != nil {
			log.Fatalf("Failed to listen on port 50057: %v", err)
		}

		log.Println("⚠️  Real-time Chat gRPC Server starting without TLS on :50057")
		log.Println("   Run 'make tls' in user-management/server to generate TLS certificates")
	}

	// Create gRPC server
	var server *grpc.Server
	if useTLS {
		// Create server with TLS credentials
		creds := credentials.NewTLS(&tls.Config{
			Certificates: []tls.Certificate{cert},
		})
		server = grpc.NewServer(grpc.Creds(creds))
	} else {
		// Create server without TLS
		server = grpc.NewServer()
	}

	// Register chat service
	chatServer := NewChatServer()
	RegisterChatServiceServer(server, chatServer)

	log.Println("📝 Sample data initialized:")
	log.Println("   - Rooms: General Discussion, Tech Support")
	log.Println("   - Users: alice, bob, charlie")
	log.Println("   - Messages: Pre-loaded sample conversations")
	log.Println("💬 Ready for bidirectional streaming and unary calls")

	// Start server
	if err := server.Serve(listener); err != nil {
		log.Fatalf("Failed to serve gRPC server: %v", err)
	}
}
