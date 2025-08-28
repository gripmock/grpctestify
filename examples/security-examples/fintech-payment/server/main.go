package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"log"
	"net"
	"sync"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/reflection"

	paymentpb "github.com/gripmock/grpctestify/examples/fintech-payment/server/paymentpb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// PaymentServer implements the PaymentService
type PaymentServer struct {
	paymentpb.UnimplementedPaymentServiceServer
	accounts     map[string]*paymentpb.Account
	transactions map[string]*paymentpb.Transaction
	refunds      map[string]*paymentpb.ProcessRefundResponse
	mutex        sync.RWMutex
	monitoring   map[string]chan *paymentpb.TransactionUpdate
	fraudAlerts  map[string]chan *paymentpb.FraudAnalysis
}

// NewPaymentServer creates a new payment server
func NewPaymentServer() *PaymentServer {
	s := &PaymentServer{
		accounts:     make(map[string]*paymentpb.Account),
		transactions: make(map[string]*paymentpb.Transaction),
		refunds:      make(map[string]*paymentpb.ProcessRefundResponse),
		monitoring:   make(map[string]chan *paymentpb.TransactionUpdate),
		fraudAlerts:  make(map[string]chan *paymentpb.FraudAnalysis),
	}

	// Add sample accounts
	s.addSampleAccounts()

	return s
}

// Add sample accounts for testing
func (s *PaymentServer) addSampleAccounts() {
	sampleAccounts := []*paymentpb.Account{
		{
			Id:              "acc_001",
			CustomerId:      "cust_001",
			AccountType:     "checking",
			Currency:        "USD",
			Balance:         5000.00,
			Status:          paymentpb.AccountStatus_ACCOUNT_STATUS_ACTIVE,
			ComplianceLevel: "enhanced",
			CreatedAt:       timestamppb.New(time.Now().Add(-30 * 24 * time.Hour)),
			UpdatedAt:       timestamppb.New(time.Now()),
			Metadata: map[string]string{
				"kyc_status": "verified",
				"risk_level": "low",
				"country":    "US",
			},
			LinkedCards: []*paymentpb.PaymentCard{
				{
					CardNumber:     "4111111111111111",
					CardholderName: "John Doe",
					ExpiryMonth:    "12",
					ExpiryYear:     "2025",
					Cvv:            "123",
					CardType:       "visa",
					Issuer:         "Chase Bank",
					IsPrimary:      true,
					CreatedAt:      timestamppb.New(time.Now().Add(-6 * 30 * 24 * time.Hour)),
				},
			},
		},
		{
			Id:              "acc_002",
			CustomerId:      "cust_002",
			AccountType:     "business",
			Currency:        "USD",
			Balance:         25000.00,
			Status:          paymentpb.AccountStatus_ACCOUNT_STATUS_ACTIVE,
			ComplianceLevel: "premium",
			CreatedAt:       timestamppb.New(time.Now().Add(-60 * 24 * time.Hour)),
			UpdatedAt:       timestamppb.New(time.Now()),
			Metadata: map[string]string{
				"kyc_status":    "verified",
				"risk_level":    "medium",
				"country":       "US",
				"business_type": "technology",
			},
			LinkedCards: []*paymentpb.PaymentCard{
				{
					CardNumber:     "5555555555554444",
					CardholderName: "Jane Smith",
					ExpiryMonth:    "08",
					ExpiryYear:     "2026",
					Cvv:            "456",
					CardType:       "mastercard",
					Issuer:         "Bank of America",
					IsPrimary:      true,
					CreatedAt:      timestamppb.New(time.Now().Add(-3 * 30 * 24 * time.Hour)),
				},
			},
		},
		{
			Id:              "acc_003",
			CustomerId:      "cust_003",
			AccountType:     "savings",
			Currency:        "EUR",
			Balance:         15000.00,
			Status:          paymentpb.AccountStatus_ACCOUNT_STATUS_PENDING_VERIFICATION,
			ComplianceLevel: "basic",
			CreatedAt:       timestamppb.New(time.Now().Add(-7 * 24 * time.Hour)),
			UpdatedAt:       timestamppb.New(time.Now()),
			Metadata: map[string]string{
				"kyc_status": "pending",
				"risk_level": "high",
				"country":    "DE",
			},
		},
	}

	for _, account := range sampleAccounts {
		s.accounts[account.Id] = account
	}
}

// CreateAccount creates a new payment account
func (s *PaymentServer) CreateAccount(ctx context.Context, req *paymentpb.CreateAccountRequest) (*paymentpb.CreateAccountResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	accountID := fmt.Sprintf("acc_%03d", len(s.accounts)+1)
	now := timestamppb.New(time.Now())

	account := &paymentpb.Account{
		Id:              accountID,
		CustomerId:      req.CustomerId,
		AccountType:     req.AccountType,
		Currency:        req.Currency,
		Balance:         0.0,
		Status:          paymentpb.AccountStatus_ACCOUNT_STATUS_PENDING_VERIFICATION,
		ComplianceLevel: req.ComplianceLevel,
		CreatedAt:       now,
		UpdatedAt:       now,
		Metadata:        req.Metadata,
		LinkedCards:     []*paymentpb.PaymentCard{},
	}

	s.accounts[accountID] = account

	complianceStatus := "pending"
	if req.ComplianceLevel == "basic" {
		complianceStatus = "approved"
		account.Status = paymentpb.AccountStatus_ACCOUNT_STATUS_ACTIVE
	}

	return &paymentpb.CreateAccountResponse{
		Success:          true,
		Message:          fmt.Sprintf("Account %s created successfully", accountID),
		Account:          account,
		ComplianceStatus: complianceStatus,
	}, nil
}

// GetAccount retrieves account information
func (s *PaymentServer) GetAccount(ctx context.Context, req *paymentpb.GetAccountRequest) (*paymentpb.GetAccountResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	account, exists := s.accounts[req.AccountId]
	if !exists {
		return &paymentpb.GetAccountResponse{
			Found: false,
		}, nil
	}

	return &paymentpb.GetAccountResponse{
		Found:   true,
		Account: account,
		Status:  account.Status,
	}, nil
}

// ProcessPayment processes a payment transaction
func (s *PaymentServer) ProcessPayment(ctx context.Context, req *paymentpb.ProcessPaymentRequest) (*paymentpb.ProcessPaymentResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	// Validate account
	account, exists := s.accounts[req.AccountId]
	if !exists {
		return &paymentpb.ProcessPaymentResponse{
			Success: false,
			Message: "Account not found",
		}, nil
	}

	if account.Status != paymentpb.AccountStatus_ACCOUNT_STATUS_ACTIVE {
		return &paymentpb.ProcessPaymentResponse{
			Success: false,
			Message: "Account is not active",
		}, nil
	}

	// Check balance
	if account.Balance < req.Amount {
		return &paymentpb.ProcessPaymentResponse{
			Success: false,
			Message: "Insufficient funds",
		}, nil
	}

	// Generate transaction ID
	transactionID := fmt.Sprintf("txn_%d", time.Now().Unix())
	now := timestamppb.New(time.Now())

	// Perform risk assessment
	riskAssessment := s.performRiskAssessment(req, account)

	// Perform compliance check
	complianceCheck := s.performComplianceCheck(req, account)

	// Determine transaction status
	status := "approved"
	message := "Payment processed successfully"

	if riskAssessment.RiskLevel == "high" {
		status = "fraud_detected"
		message = "Transaction flagged for fraud"
	} else if complianceCheck.ComplianceStatus == "violation" {
		status = "declined"
		message = "Transaction declined due to compliance violation"
	}

	// Update account balance if approved
	if status == "approved" {
		account.Balance -= req.Amount
		account.UpdatedAt = now
	}

	// Create transaction record
	transaction := &paymentpb.Transaction{
		Id:              transactionID,
		AccountId:       req.AccountId,
		MerchantId:      req.MerchantId,
		TransactionType: "payment",
		Amount:          req.Amount,
		Currency:        req.Currency,
		Status:          status,
		CreatedAt:       now,
		ProcessedAt:     now,
		RiskAssessment:  riskAssessment,
		ComplianceCheck: complianceCheck,
		Metadata:        req.Metadata,
	}

	s.transactions[transactionID] = transaction

	return &paymentpb.ProcessPaymentResponse{
		Success:         status == "approved",
		TransactionId:   transactionID,
		Status:          status,
		Message:         message,
		AmountCharged:   req.Amount,
		Currency:        req.Currency,
		ProcessedAt:     now,
		RiskAssessment:  riskAssessment,
		ComplianceCheck: complianceCheck,
	}, nil
}

// ProcessRefund processes a refund
func (s *PaymentServer) ProcessRefund(ctx context.Context, req *paymentpb.ProcessRefundRequest) (*paymentpb.ProcessRefundResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	// Find original transaction
	originalTransaction, exists := s.transactions[req.TransactionId]
	if !exists {
		return &paymentpb.ProcessRefundResponse{
			Success: false,
			Message: "Original transaction not found",
		}, nil
	}

	// Validate refund amount
	if req.RefundAmount > originalTransaction.Amount {
		return &paymentpb.ProcessRefundResponse{
			Success: false,
			Message: "Refund amount exceeds original transaction amount",
		}, nil
	}

	// Generate refund ID
	refundID := fmt.Sprintf("refund_%d", time.Now().Unix())
	now := timestamppb.New(time.Now())

	// Update account balance
	account, exists := s.accounts[originalTransaction.AccountId]
	if exists {
		account.Balance += req.RefundAmount
		account.UpdatedAt = now
	}

	response := &paymentpb.ProcessRefundResponse{
		Success:        true,
		RefundId:       refundID,
		Status:         "processed",
		Message:        fmt.Sprintf("Refund processed for transaction %s", req.TransactionId),
		AmountRefunded: req.RefundAmount,
		ProcessedAt:    now,
	}

	s.refunds[refundID] = response

	return response, nil
}

// GetTransactionHistory retrieves transaction history
func (s *PaymentServer) GetTransactionHistory(ctx context.Context, req *paymentpb.GetTransactionHistoryRequest) (*paymentpb.GetTransactionHistoryResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	var transactions []*paymentpb.Transaction
	var count int32

	for _, transaction := range s.transactions {
		if transaction.AccountId == req.AccountId {
			transactions = append(transactions, transaction)
			count++
		}
	}

	// Apply limit and offset
	start := int(req.Offset)
	end := start + int(req.Limit)
	if end > len(transactions) {
		end = len(transactions)
	}
	if start > len(transactions) {
		start = len(transactions)
	}

	return &paymentpb.GetTransactionHistoryResponse{
		Transactions: transactions[start:end],
		TotalCount:   count,
		HasMore:      end < len(transactions),
	}, nil
}

// ValidateCard validates a payment card
func (s *PaymentServer) ValidateCard(ctx context.Context, req *paymentpb.ValidateCardRequest) (*paymentpb.ValidateCardResponse, error) {
	card := req.Card

	// Basic card validation
	var validationErrors []string
	var cardType, issuer string
	var riskScore string

	// Validate card number length
	if len(card.CardNumber) < 13 || len(card.CardNumber) > 19 {
		validationErrors = append(validationErrors, "Invalid card number length")
	}

	// Determine card type and issuer
	if len(card.CardNumber) >= 4 {
		prefix := card.CardNumber[:4]
		switch {
		case prefix == "4111":
			cardType = "visa"
			issuer = "Visa"
		case prefix == "5555":
			cardType = "mastercard"
			issuer = "Mastercard"
		case prefix == "3782":
			cardType = "amex"
			issuer = "American Express"
		default:
			cardType = "unknown"
			issuer = "Unknown"
		}
	}

	// Validate expiry
	if len(card.ExpiryMonth) != 2 || len(card.ExpiryYear) != 4 {
		validationErrors = append(validationErrors, "Invalid expiry date format")
	}

	// Validate CVV
	if len(card.Cvv) < 3 || len(card.Cvv) > 4 {
		validationErrors = append(validationErrors, "Invalid CVV")
	}

	// Determine risk score
	if len(validationErrors) > 0 {
		riskScore = "high"
	} else {
		riskScore = "low"
	}

	return &paymentpb.ValidateCardResponse{
		Valid:            len(validationErrors) == 0,
		CardType:         cardType,
		Issuer:           issuer,
		RiskScore:        riskScore,
		ValidationErrors: validationErrors,
	}, nil
}

// HealthCheck provides service health information
func (s *PaymentServer) HealthCheck(ctx context.Context, req *paymentpb.HealthCheckRequest) (*paymentpb.HealthCheckResponse, error) {
	return &paymentpb.HealthCheckResponse{
		Status:    "healthy",
		Version:   "1.0.0",
		Timestamp: timestamppb.New(time.Now()),
		Metadata: map[string]string{
			"total_accounts":     fmt.Sprintf("%d", len(s.accounts)),
			"total_transactions": fmt.Sprintf("%d", len(s.transactions)),
			"service":            "payment-service",
		},
		ComplianceStatus: &paymentpb.ComplianceStatus{
			OverallStatus: "compliant",
			AuditScore:    "95",
			LastAudit:     timestamppb.New(time.Now().Add(-7 * 24 * time.Hour)),
		},
	}, nil
}

// StreamTransactions streams real-time transaction updates
func (s *PaymentServer) StreamTransactions(req *paymentpb.StreamTransactionsRequest, stream paymentpb.PaymentService_StreamTransactionsServer) error {
	accountIDs := req.AccountIds
	if len(accountIDs) == 0 {
		// Stream all accounts if none specified
		s.mutex.RLock()
		for accountID := range s.accounts {
			accountIDs = append(accountIDs, accountID)
		}
		s.mutex.RUnlock()
	}

	// Simulate transaction updates
	for {
		for _, accountID := range accountIDs {
			// Generate sample transaction update
			update := &paymentpb.TransactionUpdate{
				TransactionId:   fmt.Sprintf("txn_%d", time.Now().Unix()),
				AccountId:       accountID,
				TransactionType: "payment",
				Amount:          100.0 + float64(time.Now().Unix()%1000),
				Currency:        "USD",
				Status:          "approved",
				Timestamp:       timestamppb.New(time.Now()),
				RiskAssessment: &paymentpb.RiskAssessment{
					RiskLevel: "low",
					RiskScore: 0.1,
				},
				Metadata: map[string]string{
					"merchant": "Sample Merchant",
					"category": "retail",
				},
			}

			if err := stream.Send(update); err != nil {
				return err
			}
		}

		time.Sleep(5 * time.Second)
	}
}

// BulkProcessPayments processes bulk payment requests
func (s *PaymentServer) BulkProcessPayments(stream paymentpb.PaymentService_BulkProcessPaymentsServer) error {
	var totalProcessed, successful, failed, fraudDetected int32
	var errors []string
	var successfulTransactions []string

	for {
		req, err := stream.Recv()
		if err != nil {
			break
		}

		totalProcessed++

		// Simulate payment processing
		s.mutex.Lock()
		account, exists := s.accounts[req.AccountId]
		if exists && account.Status == paymentpb.AccountStatus_ACCOUNT_STATUS_ACTIVE {
			transactionID := fmt.Sprintf("txn_%d", time.Now().Unix())
			successful++
			successfulTransactions = append(successfulTransactions, transactionID)
		} else {
			failed++
			errors = append(errors, fmt.Sprintf("Account %s not found or inactive", req.AccountId))
		}
		s.mutex.Unlock()
	}

	response := &paymentpb.BulkPaymentResponse{
		BatchId:                fmt.Sprintf("batch_%d", time.Now().Unix()),
		TotalProcessed:         totalProcessed,
		Successful:             successful,
		Failed:                 failed,
		FraudDetected:          fraudDetected,
		Errors:                 errors,
		SuccessfulTransactions: successfulTransactions,
		ComplianceReport: &paymentpb.ComplianceReport{
			ReportId:            fmt.Sprintf("report_%d", time.Now().Unix()),
			GeneratedAt:         timestamppb.New(time.Now()),
			TotalTransactions:   int32(totalProcessed),
			FlaggedTransactions: fraudDetected,
			RiskAssessment:      "low",
		},
	}

	return stream.SendAndClose(response)
}

// FraudDetection provides bidirectional streaming for fraud detection
func (s *PaymentServer) FraudDetection(stream paymentpb.PaymentService_FraudDetectionServer) error {
	fraudID := fmt.Sprintf("fraud_%d", time.Now().Unix())
	fraudChan := make(chan *paymentpb.FraudAnalysis, 100)
	s.mutex.Lock()
	s.fraudAlerts[fraudID] = fraudChan
	s.mutex.Unlock()

	defer func() {
		s.mutex.Lock()
		delete(s.fraudAlerts, fraudID)
		s.mutex.Unlock()
		close(fraudChan)
	}()

	// Start fraud analysis goroutine
	go func() {
		ticker := time.NewTicker(3 * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				// Generate sample fraud analysis
				analysis := &paymentpb.FraudAnalysis{
					RequestId:  fmt.Sprintf("req_%d", time.Now().Unix()),
					AnalysisId: fmt.Sprintf("analysis_%d", time.Now().Unix()),
					RiskLevel:  "low",
					RiskScore:  0.15,
					RiskFactors: []string{
						"normal_transaction_pattern",
						"verified_customer",
					},
					Recommendation: "approve",
					FraudIndicators: &paymentpb.FraudIndicators{
						SuspiciousLocation: false,
						UnusualAmount:      false,
						VelocityAlert:      false,
						CardNotPresent:     false,
						HighRiskMerchant:   false,
						DeviceMismatch:     false,
						TimeAnomaly:        false,
					},
					ComplianceViolations: &paymentpb.ComplianceViolations{
						AmlViolation:        false,
						KycViolation:        false,
						SanctionsViolation:  false,
						RegulatoryViolation: false,
					},
					AnalyzedAt: timestamppb.New(time.Now()),
				}

				select {
				case fraudChan <- analysis:
				default:
					// Channel full, skip this analysis
				}
			}
		}
	}()

	// Handle incoming payment requests and send fraud analysis
	for {
		paymentReq, err := stream.Recv()
		if err != nil {
			if err == io.EOF {
				return nil
			}
			return err
		}

		// Process payment request and generate fraud analysis
		analysis := &paymentpb.FraudAnalysis{
			RequestId:  paymentReq.RequestId,
			AnalysisId: fmt.Sprintf("analysis_%d", time.Now().Unix()),
			RiskLevel:  "medium",
			RiskScore:  0.45,
			RiskFactors: []string{
				"amount_above_average",
				"new_merchant",
			},
			Recommendation: "review",
			FraudIndicators: &paymentpb.FraudIndicators{
				SuspiciousLocation: false,
				UnusualAmount:      true,
				VelocityAlert:      false,
				CardNotPresent:     false,
				HighRiskMerchant:   false,
				DeviceMismatch:     false,
				TimeAnomaly:        false,
			},
			ComplianceViolations: &paymentpb.ComplianceViolations{
				AmlViolation:        false,
				KycViolation:        false,
				SanctionsViolation:  false,
				RegulatoryViolation: false,
			},
			AnalyzedAt: timestamppb.New(time.Now()),
		}

		if err := stream.Send(analysis); err != nil {
			return err
		}
	}
}

// Helper functions
func (s *PaymentServer) performRiskAssessment(req *paymentpb.ProcessPaymentRequest, account *paymentpb.Account) *paymentpb.RiskAssessment {
	riskLevel := "low"
	riskScore := 0.1
	var riskFactors []string

	// Check amount
	if req.Amount > 1000 {
		riskLevel = "medium"
		riskScore = 0.4
		riskFactors = append(riskFactors, "high_amount")
	}

	// Check account history
	if account.Status == paymentpb.AccountStatus_ACCOUNT_STATUS_PENDING_VERIFICATION {
		riskLevel = "high"
		riskScore = 0.8
		riskFactors = append(riskFactors, "unverified_account")
	}

	return &paymentpb.RiskAssessment{
		RiskLevel:    riskLevel,
		RiskScore:    riskScore,
		RiskFactors:  riskFactors,
		AssessmentId: fmt.Sprintf("risk_%d", time.Now().Unix()),
		AssessedAt:   timestamppb.New(time.Now()),
	}
}

func (s *PaymentServer) performComplianceCheck(req *paymentpb.ProcessPaymentRequest, account *paymentpb.Account) *paymentpb.ComplianceCheck {
	complianceStatus := "compliant"
	var violations []string

	// Check KYC status
	if account.Metadata["kyc_status"] == "pending" {
		complianceStatus = "violation"
		violations = append(violations, "kyc_not_completed")
	}

	// Check sanctions
	if account.Metadata["country"] == "XX" {
		complianceStatus = "violation"
		violations = append(violations, "sanctions_violation")
	}

	return &paymentpb.ComplianceCheck{
		ComplianceStatus: complianceStatus,
		Violations:       violations,
		CheckId:          fmt.Sprintf("compliance_%d", time.Now().Unix()),
		CheckedAt:        timestamppb.New(time.Now()),
	}
}

func main() {
	// Check if TLS is enabled
	useTLS := true // Set to false for testing without TLS

	// Create listener
	var lis net.Listener
	var err error

	if useTLS {
		// Load TLS certificates
		cert, err := tls.LoadX509KeyPair("tls/server-cert.pem", "tls/server-key.pem")
		if err != nil {
			log.Fatalf("Failed to load TLS certificates: %v", err)
		}

		config := &tls.Config{
			Certificates: []tls.Certificate{cert},
			ClientAuth:   tls.RequireAndVerifyClientCert,
		}

		lis, err = tls.Listen("tcp", ":50053", config)
		if err != nil {
			log.Fatalf("Failed to listen with TLS: %v", err)
		}

		fmt.Println("🔒 FinTech Payment Service is running with mTLS on port 50053...")
	} else {
		lis, err = net.Listen("tcp", ":50053")
		if err != nil {
			log.Fatalf("Failed to listen: %v", err)
		}

		fmt.Println("⚠️  FinTech Payment Service is running without TLS on port 50053...")
		fmt.Println("   Run 'make tls' to generate TLS certificates")
	}

	// Create gRPC server
	var s *grpc.Server
	if useTLS {
		// Load TLS certificates for gRPC server
		cert, err := tls.LoadX509KeyPair("tls/server-cert.pem", "tls/server-key.pem")
		if err != nil {
			log.Fatalf("Failed to load TLS certificates for gRPC server: %v", err)
		}

		creds := credentials.NewTLS(&tls.Config{
			Certificates: []tls.Certificate{cert},
			ClientAuth:   tls.RequireAndVerifyClientCert,
		})
		s = grpc.NewServer(grpc.Creds(creds))
	} else {
		s = grpc.NewServer()
	}

	// Register services
	paymentServer := NewPaymentServer()
	paymentpb.RegisterPaymentServiceServer(s, paymentServer)
	reflection.Register(s)

	fmt.Println("Available methods:")
	fmt.Println("  - CreateAccount, GetAccount, ProcessPayment, ProcessRefund")
	fmt.Println("  - GetTransactionHistory, ValidateCard, HealthCheck")
	fmt.Println("  - StreamTransactions, BulkProcessPayments, FraudDetection")

	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
