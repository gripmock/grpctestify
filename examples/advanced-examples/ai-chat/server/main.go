package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net"
	"strings"
	"sync"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"

	aichatpb "github.com/gripmock/grpctestify/examples/ai-chat/server/aichatpb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// AIChatServer implements the AIChatService
type AIChatServer struct {
	aichatpb.UnimplementedAIChatServiceServer
	sessions      map[string]*aichatpb.ChatSession
	messages      map[string][]*aichatpb.ChatMessage
	mutex         sync.RWMutex
	conversations map[string]chan *aichatpb.AIResponse
	streaming     map[string]chan *aichatpb.ChatMessage
}

// NewAIChatServer creates a new AI chat server
func NewAIChatServer() *AIChatServer {
	s := &AIChatServer{
		sessions:      make(map[string]*aichatpb.ChatSession),
		messages:      make(map[string][]*aichatpb.ChatMessage),
		conversations: make(map[string]chan *aichatpb.AIResponse),
		streaming:     make(map[string]chan *aichatpb.ChatMessage),
	}

	// Add sample sessions
	s.addSampleSessions()

	return s
}

// Add sample sessions for testing
func (s *AIChatServer) addSampleSessions() {
	sampleSessions := []*aichatpb.ChatSession{
		{
			Id:     "session_001",
			UserId: "user_001",
			Name:   "General Chat",
			Settings: &aichatpb.ChatSettings{
				Model:                   "gpt-4",
				Temperature:             0.7,
				MaxTokens:               1000,
				TopP:                    0.9,
				FrequencyPenalty:        0.0,
				PresencePenalty:         0.0,
				Language:                "en",
				EnableStreaming:         true,
				EnableSentimentAnalysis: true,
				SystemPrompts:           []string{"You are a helpful AI assistant."},
				CustomSettings:          map[string]string{},
			},
			Status:       aichatpb.SessionStatus_SESSION_STATUS_ACTIVE,
			CreatedAt:    timestamppb.New(time.Now().Add(-24 * time.Hour)),
			UpdatedAt:    timestamppb.New(time.Now()),
			LastActivity: timestamppb.New(time.Now()),
			Metadata:     map[string]string{"category": "general"},
			MessageCount: 15,
		},
		{
			Id:     "session_002",
			UserId: "user_002",
			Name:   "Technical Support",
			Settings: &aichatpb.ChatSettings{
				Model:                   "claude-3",
				Temperature:             0.3,
				MaxTokens:               2000,
				TopP:                    0.8,
				FrequencyPenalty:        0.1,
				PresencePenalty:         0.1,
				Language:                "en",
				EnableStreaming:         true,
				EnableSentimentAnalysis: true,
				SystemPrompts:           []string{"You are a technical support specialist."},
				CustomSettings:          map[string]string{},
			},
			Status:       aichatpb.SessionStatus_SESSION_STATUS_ACTIVE,
			CreatedAt:    timestamppb.New(time.Now().Add(-48 * time.Hour)),
			UpdatedAt:    timestamppb.New(time.Now()),
			LastActivity: timestamppb.New(time.Now()),
			Metadata:     map[string]string{"category": "support"},
			MessageCount: 8,
		},
		{
			Id:     "session_003",
			UserId: "user_003",
			Name:   "Creative Writing",
			Settings: &aichatpb.ChatSettings{
				Model:                   "llama-2",
				Temperature:             0.9,
				MaxTokens:               1500,
				TopP:                    0.95,
				FrequencyPenalty:        0.2,
				PresencePenalty:         0.2,
				Language:                "en",
				EnableStreaming:         true,
				EnableSentimentAnalysis: true,
				SystemPrompts:           []string{"You are a creative writing assistant."},
				CustomSettings:          map[string]string{},
			},
			Status:       aichatpb.SessionStatus_SESSION_STATUS_PAUSED,
			CreatedAt:    timestamppb.New(time.Now().Add(-72 * time.Hour)),
			UpdatedAt:    timestamppb.New(time.Now()),
			LastActivity: timestamppb.New(time.Now().Add(-2 * time.Hour)),
			Metadata:     map[string]string{"category": "creative"},
			MessageCount: 25,
		},
	}

	for _, session := range sampleSessions {
		s.sessions[session.Id] = session
		s.messages[session.Id] = []*aichatpb.ChatMessage{}
	}
}

// CreateChatSession creates a new chat session
func (s *AIChatServer) CreateChatSession(ctx context.Context, req *aichatpb.CreateChatSessionRequest) (*aichatpb.CreateChatSessionResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	sessionID := fmt.Sprintf("session_%03d", len(s.sessions)+1)
	now := timestamppb.New(time.Now())

	// Set default settings if not provided
	settings := req.Settings
	if settings == nil {
		settings = &aichatpb.ChatSettings{
			Model:                   "gpt-4",
			Temperature:             0.7,
			MaxTokens:               1000,
			TopP:                    0.9,
			FrequencyPenalty:        0.0,
			PresencePenalty:         0.0,
			Language:                "en",
			EnableStreaming:         true,
			EnableSentimentAnalysis: true,
			SystemPrompts:           []string{"You are a helpful AI assistant."},
			CustomSettings:          map[string]string{},
		}
	}

	session := &aichatpb.ChatSession{
		Id:           sessionID,
		UserId:       req.UserId,
		Name:         req.SessionName,
		Settings:     settings,
		Status:       aichatpb.SessionStatus_SESSION_STATUS_ACTIVE,
		CreatedAt:    now,
		UpdatedAt:    now,
		LastActivity: now,
		Metadata:     req.Metadata,
		MessageCount: 0,
	}

	s.sessions[sessionID] = session
	s.messages[sessionID] = []*aichatpb.ChatMessage{}

	return &aichatpb.CreateChatSessionResponse{
		Success:   true,
		SessionId: sessionID,
		Message:   fmt.Sprintf("Chat session %s created successfully", sessionID),
		Session:   session,
	}, nil
}

// UpdateChatSettings updates chat session settings
func (s *AIChatServer) UpdateChatSettings(ctx context.Context, req *aichatpb.UpdateChatSettingsRequest) (*aichatpb.UpdateChatSettingsResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	session, exists := s.sessions[req.SessionId]
	if !exists {
		return &aichatpb.UpdateChatSettingsResponse{
			Success: false,
			Message: "Session not found",
		}, nil
	}

	session.Settings = req.Settings
	session.UpdatedAt = timestamppb.New(time.Now())

	return &aichatpb.UpdateChatSettingsResponse{
		Success: true,
		Message: fmt.Sprintf("Settings updated for session %s", req.SessionId),
		Session: session,
	}, nil
}

// SendMessage sends a message and gets AI response
func (s *AIChatServer) SendMessage(ctx context.Context, req *aichatpb.SendMessageRequest) (*aichatpb.SendMessageResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	// Validate session
	session, exists := s.sessions[req.SessionId]
	if !exists {
		return &aichatpb.SendMessageResponse{
			Success: false,
		}, nil
	}

	messageID := fmt.Sprintf("msg_%d", time.Now().Unix())
	now := timestamppb.New(time.Now())

	// Generate AI response
	aiResponse := s.generateAIResponse(req.Message, session.Settings)

	// Perform sentiment analysis
	sentiment := s.analyzeSentiment(req.Message)

	// Calculate processing metrics
	metrics := &aichatpb.ProcessingMetrics{
		ResponseTimeMs:  float64(time.Now().UnixNano()/1000000) - float64(now.AsTime().UnixNano()/1000000),
		TokensUsed:      int32(len(strings.Split(req.Message, " "))),
		TokensGenerated: int32(len(strings.Split(aiResponse, " "))),
		CostUsd:         0.001,
		ModelUsed:       session.Settings.Model,
		CustomMetrics:   map[string]float64{},
	}

	// Create message record
	message := &aichatpb.ChatMessage{
		MessageId:   messageID,
		SessionId:   req.SessionId,
		UserId:      req.UserId,
		Content:     req.Message,
		MessageType: req.MessageType,
		Role:        aichatpb.MessageRole_MESSAGE_ROLE_USER,
		Sentiment:   sentiment,
		Metrics:     metrics,
		Timestamp:   now,
		Metadata:    req.Context,
	}

	s.messages[req.SessionId] = append(s.messages[req.SessionId], message)
	session.MessageCount++
	session.LastActivity = now

	return &aichatpb.SendMessageResponse{
		Success:     true,
		MessageId:   messageID,
		AiResponse:  aiResponse,
		Sentiment:   sentiment,
		Metrics:     metrics,
		ProcessedAt: now,
	}, nil
}

// GetChatHistory retrieves chat history
func (s *AIChatServer) GetChatHistory(ctx context.Context, req *aichatpb.GetChatHistoryRequest) (*aichatpb.GetChatHistoryResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	messages, exists := s.messages[req.SessionId]
	if !exists {
		return &aichatpb.GetChatHistoryResponse{
			Messages:   []*aichatpb.ChatMessage{},
			TotalCount: 0,
			HasMore:    false,
		}, nil
	}

	// Apply limit and offset
	start := int(req.Offset)
	end := start + int(req.Limit)
	if end > len(messages) {
		end = len(messages)
	}
	if start > len(messages) {
		start = len(messages)
	}

	return &aichatpb.GetChatHistoryResponse{
		Messages:   messages[start:end],
		TotalCount: int32(len(messages)),
		HasMore:    end < len(messages),
	}, nil
}

// AnalyzeSentiment analyzes text sentiment
func (s *AIChatServer) AnalyzeSentiment(ctx context.Context, req *aichatpb.AnalyzeSentimentRequest) (*aichatpb.AnalyzeSentimentResponse, error) {
	sentiment := s.analyzeSentiment(req.Text)

	confidence := &aichatpb.ConfidenceScores{
		OverallConfidence:  0.85,
		PositiveConfidence: sentiment.PositiveScore,
		NegativeConfidence: sentiment.NegativeScore,
		NeutralConfidence:  sentiment.NeutralScore,
	}

	entities := []*aichatpb.SentimentEntity{
		{
			Text:        "great",
			Sentiment:   "positive",
			Score:       0.8,
			EntityType:  "adjective",
			StartOffset: 0,
			EndOffset:   5,
		},
	}

	return &aichatpb.AnalyzeSentimentResponse{
		Sentiment:  sentiment,
		Confidence: confidence,
		Entities:   entities,
		AnalyzedAt: timestamppb.New(time.Now()),
	}, nil
}

// HealthCheck provides service health information
func (s *AIChatServer) HealthCheck(ctx context.Context, req *aichatpb.HealthCheckRequest) (*aichatpb.HealthCheckResponse, error) {
	activeSessions := 0
	totalMessages := 0
	for _, session := range s.sessions {
		if session.Status == aichatpb.SessionStatus_SESSION_STATUS_ACTIVE {
			activeSessions++
		}
		totalMessages += int(session.MessageCount)
	}

	return &aichatpb.HealthCheckResponse{
		Status:    "healthy",
		Version:   "1.0.0",
		Timestamp: timestamppb.New(time.Now()),
		Metadata: map[string]string{
			"total_sessions": fmt.Sprintf("%d", len(s.sessions)),
			"service":        "ai-chat",
		},
		Metrics: &aichatpb.ServiceMetrics{
			ActiveSessions:         int32(activeSessions),
			TotalMessagesProcessed: int32(totalMessages),
			AverageResponseTime:    150.0,
			UptimePercentage:       99.9,
			ModelUsage: map[string]int32{
				"gpt-4":    10,
				"claude-3": 5,
				"llama-2":  3,
			},
		},
	}, nil
}

// StreamChat streams real-time AI responses
func (s *AIChatServer) StreamChat(req *aichatpb.StreamChatRequest, stream aichatpb.AIChatService_StreamChatServer) error {
	session, exists := s.sessions[req.SessionId]
	if !exists {
		return fmt.Errorf("session not found")
	}

	// Generate streaming response
	response := s.generateAIResponse(req.InitialMessage, session.Settings)
	words := strings.Split(response, " ")

	for i, word := range words {
		message := &aichatpb.ChatMessage{
			MessageId:   fmt.Sprintf("stream_%d", time.Now().Unix()),
			SessionId:   req.SessionId,
			UserId:      req.UserId,
			Content:     word,
			MessageType: aichatpb.MessageType_MESSAGE_TYPE_TEXT,
			Role:        aichatpb.MessageRole_MESSAGE_ROLE_ASSISTANT,
			Sentiment:   s.analyzeSentiment(word),
			Timestamp:   timestamppb.New(time.Now()),
			IsStreaming: true,
			StreamChunk: int32(i + 1),
			TotalChunks: int32(len(words)),
		}

		if err := stream.Send(message); err != nil {
			return err
		}

		time.Sleep(100 * time.Millisecond) // Simulate streaming delay
	}

	return nil
}

// BulkProcessMessages processes multiple messages
func (s *AIChatServer) BulkProcessMessages(stream aichatpb.AIChatService_BulkProcessMessagesServer) error {
	var totalProcessed, successful, failed int32
	var errors []string
	var successfulMessages []string

	for {
		req, err := stream.Recv()
		if err != nil {
			break
		}

		totalProcessed++

		// Simulate message processing
		s.mutex.Lock()
		session, exists := s.sessions[req.SessionId]
		if exists && session.Status == aichatpb.SessionStatus_SESSION_STATUS_ACTIVE {
			messageID := fmt.Sprintf("bulk_%d", time.Now().Unix())
			successful++
			successfulMessages = append(successfulMessages, messageID)
		} else {
			failed++
			errors = append(errors, fmt.Sprintf("Session %s not found or inactive", req.SessionId))
		}
		s.mutex.Unlock()
	}

	response := &aichatpb.BulkProcessResponse{
		BatchId:            fmt.Sprintf("batch_%d", time.Now().Unix()),
		TotalProcessed:     totalProcessed,
		Successful:         successful,
		Failed:             failed,
		Errors:             errors,
		SuccessfulMessages: successfulMessages,
		Summary: &aichatpb.ProcessingSummary{
			AverageResponseTime: 150.0,
			TotalTokensUsed:     int32(totalProcessed * 50),
			TotalCostUsd:        float64(totalProcessed) * 0.001,
			ModelUsage: map[string]int32{
				"gpt-4":    int32(successful),
				"claude-3": 0,
				"llama-2":  0,
			},
			SentimentDistribution: &aichatpb.SentimentDistribution{
				PositiveCount: int32(successful * 3 / 4),
				NegativeCount: 0,
				NeutralCount:  int32(successful / 4),
				MixedCount:    0,
			},
		},
	}

	return stream.SendAndClose(response)
}

// ChatConversation provides bidirectional streaming for real-time conversation
func (s *AIChatServer) ChatConversation(stream aichatpb.AIChatService_ChatConversationServer) error {
	conversationID := fmt.Sprintf("conv_%d", time.Now().Unix())
	responseChan := make(chan *aichatpb.AIResponse, 100)
	s.mutex.Lock()
	s.conversations[conversationID] = responseChan
	s.mutex.Unlock()

	defer func() {
		s.mutex.Lock()
		delete(s.conversations, conversationID)
		s.mutex.Unlock()
		close(responseChan)
	}()

	// Start AI response generation goroutine
	go func() {
		ticker := time.NewTicker(2 * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				// Generate sample AI response
				response := &aichatpb.AIResponse{
					SessionId:    "session_001",
					RequestId:    fmt.Sprintf("req_%d", time.Now().Unix()),
					Response:     "I'm here to help you with any questions!",
					ResponseType: aichatpb.ResponseType_RESPONSE_TYPE_TEXT,
					Sentiment:    s.analyzeSentiment("I'm here to help you with any questions!"),
					Metrics: &aichatpb.ProcessingMetrics{
						ResponseTimeMs:  150.0,
						TokensUsed:      10,
						TokensGenerated: 15,
						CostUsd:         0.001,
						ModelUsed:       "gpt-4",
					},
					Timestamp:   timestamppb.New(time.Now()),
					IsFinal:     true,
					ChunkNumber: 1,
					TotalChunks: 1,
				}

				select {
				case responseChan <- response:
				default:
					// Channel full, skip this response
				}
			}
		}
	}()

	// Handle incoming user messages and send AI responses
	for {
		userMsg, err := stream.Recv()
		if err != nil {
			if err == io.EOF {
				return nil
			}
			return err
		}

		// Process user message and generate AI response
		aiResponse := &aichatpb.AIResponse{
			SessionId:    userMsg.SessionId,
			RequestId:    userMsg.RequestId,
			Response:     s.generateAIResponse(userMsg.Message, nil),
			ResponseType: aichatpb.ResponseType_RESPONSE_TYPE_TEXT,
			Sentiment:    s.analyzeSentiment(userMsg.Message),
			Metrics: &aichatpb.ProcessingMetrics{
				ResponseTimeMs:  200.0,
				TokensUsed:      20,
				TokensGenerated: 25,
				CostUsd:         0.002,
				ModelUsed:       "gpt-4",
			},
			Timestamp:   timestamppb.New(time.Now()),
			IsFinal:     true,
			ChunkNumber: 1,
			TotalChunks: 1,
		}

		if err := stream.Send(aiResponse); err != nil {
			return err
		}
	}
}

// Helper functions
func (s *AIChatServer) generateAIResponse(message string, settings *aichatpb.ChatSettings) string {
	// Simple AI response generation based on input
	lowerMessage := strings.ToLower(message)

	switch {
	case strings.Contains(lowerMessage, "hello") || strings.Contains(lowerMessage, "hi"):
		return "Hello! How can I help you today?"
	case strings.Contains(lowerMessage, "how are you"):
		return "I'm doing well, thank you for asking! How can I assist you?"
	case strings.Contains(lowerMessage, "weather"):
		return "I can't check the weather in real-time, but I'd be happy to help you with other questions!"
	case strings.Contains(lowerMessage, "help"):
		return "I'm here to help! What would you like to know?"
	case strings.Contains(lowerMessage, "thank"):
		return "You're welcome! Is there anything else I can help you with?"
	default:
		return "That's an interesting question. Let me think about that for a moment. I'd be happy to help you explore this topic further."
	}
}

func (s *AIChatServer) analyzeSentiment(text string) *aichatpb.SentimentAnalysis {
	lowerText := strings.ToLower(text)

	positiveWords := []string{"good", "great", "excellent", "amazing", "wonderful", "happy", "love", "like", "thank"}
	negativeWords := []string{"bad", "terrible", "awful", "hate", "dislike", "angry", "sad", "disappointed"}

	positiveScore := 0.0
	negativeScore := 0.0
	neutralScore := 0.0

	for _, word := range positiveWords {
		if strings.Contains(lowerText, word) {
			positiveScore += 0.3
		}
	}

	for _, word := range negativeWords {
		if strings.Contains(lowerText, word) {
			negativeScore += 0.3
		}
	}

	if positiveScore == 0 && negativeScore == 0 {
		neutralScore = 0.8
	}

	// Normalize scores
	total := positiveScore + negativeScore + neutralScore
	if total > 0 {
		positiveScore /= total
		negativeScore /= total
		neutralScore /= total
	}

	overallSentiment := "neutral"
	if positiveScore > 0.5 {
		overallSentiment = "positive"
	} else if negativeScore > 0.5 {
		overallSentiment = "negative"
	}

	return &aichatpb.SentimentAnalysis{
		OverallSentiment: overallSentiment,
		PositiveScore:    positiveScore,
		NegativeScore:    negativeScore,
		NeutralScore:     neutralScore,
		MixedScore:       0.0,
		Entities:         []*aichatpb.SentimentEntity{},
		Language:         "en",
		AnalyzedAt:       timestamppb.New(time.Now()),
	}
}

func main() {
	// Create listener
	lis, err := net.Listen("tcp", ":50054")
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	// Create gRPC server
	s := grpc.NewServer()

	// Register services
	chatServer := NewAIChatServer()
	aichatpb.RegisterAIChatServiceServer(s, chatServer)
	reflection.Register(s)

	fmt.Println("🤖 AI Chat Service is running on port 50054...")
	fmt.Println("Available methods:")
	fmt.Println("  - CreateChatSession, UpdateChatSettings, SendMessage")
	fmt.Println("  - GetChatHistory, AnalyzeSentiment, HealthCheck")
	fmt.Println("  - StreamChat, BulkProcessMessages, ChatConversation")

	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
