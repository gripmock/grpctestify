package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"log"
	"net"
	"os"
	"sync"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/reflection"

	userpb "github.com/gripmock/grpctestify/examples/user-management/server/userpb"
)

// server implements the UserService
type server struct {
	userpb.UnimplementedUserServiceServer
	users    map[string]*userpb.User
	profiles map[string]*userpb.UserProfile
	tokens   map[string]*userpb.User
	mutex    sync.RWMutex
}

// NewServer creates a new user server
func NewServer() *server {
	s := &server{
		users:    make(map[string]*userpb.User),
		profiles: make(map[string]*userpb.UserProfile),
		tokens:   make(map[string]*userpb.User),
	}

	// Add test user for examples
	testUser := &userpb.User{
		Id:       "user_12345",
		Username: "john_doe",
		Email:    "john.doe@example.com",
		FullName: "John Doe",
		Age:      30,
		Active:   true,
		Roles:    []string{"user", "premium"},
		Metadata: map[string]string{
			"department": "engineering",
			"location":   "san_francisco",
		},
		CreatedAt: "2024-01-15T10:00:00Z",
		UpdatedAt: "2024-01-15T10:00:00Z",
	}
	s.users["user_12345"] = testUser

	return s
}

// User CRUD operations
func (s *server) CreateUser(ctx context.Context, req *userpb.CreateUserRequest) (*userpb.CreateUserResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	// Validate required fields
	if req.Username == "" || req.Email == "" {
		return &userpb.CreateUserResponse{
			User:    nil,
			Message: "Username and email are required",
			Success: false,
		}, nil
	}

	// Check if user already exists
	for _, user := range s.users {
		if user.Username == req.Username || user.Email == req.Email {
			return &userpb.CreateUserResponse{
				User:    nil,
				Message: "User with this username or email already exists",
				Success: false,
			}, nil
		}
	}

	userID := fmt.Sprintf("user_%d", time.Now().UnixNano())
	user := &userpb.User{
		Id:        userID,
		Username:  req.Username,
		Email:     req.Email,
		FullName:  req.FullName,
		Age:       req.Age,
		Active:    true,
		Roles:     req.Roles,
		Metadata:  req.Metadata,
		CreatedAt: time.Now().Format(time.RFC3339),
		UpdatedAt: time.Now().Format(time.RFC3339),
	}

	s.users[userID] = user

	return &userpb.CreateUserResponse{
		User:    user,
		Message: "User created successfully",
		Success: true,
	}, nil
}

func (s *server) GetUser(ctx context.Context, req *userpb.GetUserRequest) (*userpb.GetUserResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	user, exists := s.users[req.UserId]
	if !exists {
		return &userpb.GetUserResponse{
			User:    nil,
			Profile: nil,
			Found:   false,
		}, nil
	}

	var profile *userpb.UserProfile
	if req.IncludeProfile {
		profile = s.profiles[req.UserId]
	}

	return &userpb.GetUserResponse{
		User:    user,
		Profile: profile,
		Found:   true,
	}, nil
}

func (s *server) UpdateUser(ctx context.Context, req *userpb.UpdateUserRequest) (*userpb.UpdateUserResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	user, exists := s.users[req.UserId]
	if !exists {
		return &userpb.UpdateUserResponse{
			User:    nil,
			Success: false,
			Message: "User not found",
		}, nil
	}

	// Update fields
	if req.Username != "" {
		user.Username = req.Username
	}
	if req.Email != "" {
		user.Email = req.Email
	}
	if req.FullName != "" {
		user.FullName = req.FullName
	}
	if req.Age > 0 {
		user.Age = req.Age
	}
	user.Active = req.Active
	if len(req.Roles) > 0 {
		user.Roles = req.Roles
	}
	if req.Metadata != nil {
		user.Metadata = req.Metadata
	}
	user.UpdatedAt = time.Now().Format(time.RFC3339)

	return &userpb.UpdateUserResponse{
		User:    user,
		Success: true,
		Message: "User updated successfully",
	}, nil
}

func (s *server) DeleteUser(ctx context.Context, req *userpb.DeleteUserRequest) (*userpb.DeleteUserResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	user, exists := s.users[req.UserId]
	if !exists {
		return &userpb.DeleteUserResponse{
			Success: false,
			Message: "User not found",
		}, nil
	}

	if req.SoftDelete {
		user.Active = false
		user.UpdatedAt = time.Now().Format(time.RFC3339)
	} else {
		delete(s.users, req.UserId)
		delete(s.profiles, req.UserId)
	}

	return &userpb.DeleteUserResponse{
		Success: true,
		Message: "User deleted successfully",
	}, nil
}

// Authentication
func (s *server) AuthenticateUser(ctx context.Context, req *userpb.AuthenticateUserRequest) (*userpb.AuthenticateUserResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	// Simple authentication logic - in real app, hash passwords
	if req.Username == "invalid_user" || req.Password == "wrong_password" {
		return &userpb.AuthenticateUserResponse{
			Success:      false,
			Token:        "",
			User:         nil,
			ExpiresAt:    "",
			Permissions:  []string{},
			ErrorMessage: "Invalid username or password",
		}, nil
	}

	// Find user by username
	var user *userpb.User
	for _, u := range s.users {
		if u.Username == req.Username {
			user = u
			break
		}
	}

	if user == nil {
		return &userpb.AuthenticateUserResponse{
			Success:      false,
			Token:        "",
			User:         nil,
			ExpiresAt:    "",
			Permissions:  []string{},
			ErrorMessage: "User not found",
		}, nil
	}

	// Generate token
	token := fmt.Sprintf("token_%d", time.Now().UnixNano())
	s.tokens[token] = user

	// Determine permissions based on roles
	var permissions []string
	for _, role := range user.Roles {
		switch role {
		case "admin":
			permissions = append(permissions, "read", "write", "delete", "admin")
		case "user":
			permissions = append(permissions, "read", "write")
		case "guest":
			permissions = append(permissions, "read")
		}
	}

	return &userpb.AuthenticateUserResponse{
		Success:     true,
		Token:       token,
		User:        user,
		ExpiresAt:   time.Now().Add(24 * time.Hour).Format(time.RFC3339),
		Permissions: permissions,
	}, nil
}

func (s *server) ValidateToken(ctx context.Context, req *userpb.ValidateTokenRequest) (*userpb.ValidateTokenResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	user, exists := s.tokens[req.Token]
	if !exists {
		return &userpb.ValidateTokenResponse{
			Valid:        false,
			UserId:       "",
			Permissions:  []string{},
			ExpiresAt:    "",
			ErrorMessage: "Invalid token",
		}, nil
	}

	// Determine permissions
	var permissions []string
	for _, role := range user.Roles {
		switch role {
		case "admin":
			permissions = append(permissions, "read", "write", "delete", "admin")
		case "user":
			permissions = append(permissions, "read", "write")
		case "guest":
			permissions = append(permissions, "read")
		}
	}

	return &userpb.ValidateTokenResponse{
		Valid:       true,
		UserId:      user.Id,
		Permissions: permissions,
		ExpiresAt:   time.Now().Add(24 * time.Hour).Format(time.RFC3339),
	}, nil
}

// Profile management
func (s *server) GetUserProfile(ctx context.Context, req *userpb.GetUserProfileRequest) (*userpb.GetUserProfileResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	profile, exists := s.profiles[req.UserId]
	if !exists {
		// Create default profile
		profile = &userpb.UserProfile{
			UserId: req.UserId,
			Bio:    "No bio available",
			Address: &userpb.Address{
				Street:     "123 Main Street",
				City:       "San Francisco",
				State:      "CA",
				Country:    "USA",
				PostalCode: "94105",
			},
			Interests: []string{"technology", "programming"},
			Preferences: map[string]string{
				"theme":    "dark",
				"language": "en",
			},
		}
		s.profiles[req.UserId] = profile
	}

	return &userpb.GetUserProfileResponse{
		Profile: profile,
		Found:   true,
	}, nil
}

func (s *server) UpdateUserProfile(ctx context.Context, req *userpb.UpdateUserProfileRequest) (*userpb.UpdateUserProfileResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	profile := &userpb.UserProfile{
		UserId:      req.UserId,
		Bio:         req.Bio,
		AvatarUrl:   req.AvatarUrl,
		Address:     req.Address,
		Interests:   req.Interests,
		Preferences: req.Preferences,
	}

	s.profiles[req.UserId] = profile

	return &userpb.UpdateUserProfileResponse{
		Profile: profile,
		Success: true,
	}, nil
}

// Search and listing
func (s *server) SearchUsers(ctx context.Context, req *userpb.SearchUsersRequest) (*userpb.SearchUsersResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	var results []*userpb.User
	for _, user := range s.users {
		// Apply filters
		if req.ActiveOnly && !user.Active {
			continue
		}

		// Check role filter
		if len(req.Roles) > 0 {
			hasRole := false
			for _, filterRole := range req.Roles {
				for _, userRole := range user.Roles {
					if userRole == filterRole {
						hasRole = true
						break
					}
				}
				if hasRole {
					break
				}
			}
			if !hasRole {
				continue
			}
		}

		// Check query match
		if req.Query != "" {
			if user.Username != req.Query && user.Email != req.Query && user.FullName != req.Query {
				continue
			}
		}

		results = append(results, user)
	}

	// Apply pagination
	start := int((req.Page - 1) * req.PageSize)
	end := start + int(req.PageSize)
	if end > len(results) {
		end = len(results)
	}

	var paginatedResults []*userpb.User
	if start < len(results) {
		paginatedResults = results[start:end]
	}

	return &userpb.SearchUsersResponse{
		Users:      paginatedResults,
		TotalCount: int32(len(results)),
		Page:       req.Page,
		PageSize:   req.PageSize,
		HasMore:    end < len(results),
	}, nil
}

func (s *server) ListUsers(ctx context.Context, req *userpb.ListUsersRequest) (*userpb.ListUsersResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	var users []*userpb.User
	for _, user := range s.users {
		users = append(users, user)
	}

	// Apply pagination
	start := int((req.Page - 1) * req.PageSize)
	end := start + int(req.PageSize)
	if end > len(users) {
		end = len(users)
	}

	var paginatedUsers []*userpb.User
	if start < len(users) {
		paginatedUsers = users[start:end]
	}

	return &userpb.ListUsersResponse{
		Users:      paginatedUsers,
		TotalCount: int32(len(users)),
		Page:       req.Page,
		PageSize:   req.PageSize,
		HasMore:    end < len(users),
	}, nil
}

func main() {
	// Check if TLS certificates exist
	useTLS := false
	if _, err := os.Stat("tls/server-cert.pem"); err == nil {
		if _, err := os.Stat("tls/server-key.pem"); err == nil {
			useTLS = true
		}
	}

	var lis net.Listener
	var err error

	if useTLS {
		// Load TLS certificates
		cert, err := tls.LoadX509KeyPair("tls/server-cert.pem", "tls/server-key.pem")
		if err != nil {
			log.Fatalf("failed to load TLS certificates: %v", err)
		}

		// Create TLS configuration
		tlsConfig := &tls.Config{
			Certificates: []tls.Certificate{cert},
			ClientAuth:   tls.NoClientCert, // For now, no client cert required
		}

		// Create TLS listener
		lis, err = tls.Listen("tcp", ":50051", tlsConfig)
		if err != nil {
			log.Fatalf("failed to listen with TLS: %v", err)
		}

		fmt.Println("🔒 User Management Service is running with TLS on port 50051...")
	} else {
		// Create plain TCP listener
		lis, err = net.Listen("tcp", ":50051")
		if err != nil {
			log.Fatalf("failed to listen: %v", err)
		}

		fmt.Println("⚠️  User Management Service is running without TLS on port 50051...")
		fmt.Println("   Run 'make tls' to generate TLS certificates")
	}

	// Create gRPC server
	var s *grpc.Server
	if useTLS {
		// Load certificates again for gRPC server
		cert, err := tls.LoadX509KeyPair("tls/server-cert.pem", "tls/server-key.pem")
		if err != nil {
			log.Fatalf("failed to load TLS certificates for gRPC: %v", err)
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

	userServer := NewServer()
	userpb.RegisterUserServiceServer(s, userServer)
	reflection.Register(s)

	fmt.Println("Available methods:")
	fmt.Println("  - CreateUser, GetUser, UpdateUser, DeleteUser")
	fmt.Println("  - AuthenticateUser, ValidateToken")
	fmt.Println("  - GetUserProfile, UpdateUserProfile")
	fmt.Println("  - SearchUsers, ListUsers")

	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
