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

	shopflowpb "github.com/gripmock/grpctestify/examples/advanced-examples/shopflow-ecommerce/server/shopflowpb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// ShopFlowServer implements the ShopFlowService
type ShopFlowServer struct {
	shopflowpb.UnimplementedShopFlowServiceServer
	products    map[string]*shopflowpb.Product
	orders      map[string]*shopflowpb.Order
	payments    map[string]*shopflowpb.ProcessPaymentResponse
	refunds     map[string]*shopflowpb.RefundPaymentResponse
	chatClients map[string]chan *shopflowpb.ChatMessage
	mutex       sync.RWMutex
}

// NewShopFlowServer creates a new ShopFlow server
func NewShopFlowServer() *ShopFlowServer {
	s := &ShopFlowServer{
		products:    make(map[string]*shopflowpb.Product),
		orders:      make(map[string]*shopflowpb.Order),
		payments:    make(map[string]*shopflowpb.ProcessPaymentResponse),
		refunds:     make(map[string]*shopflowpb.RefundPaymentResponse),
		chatClients: make(map[string]chan *shopflowpb.ChatMessage),
	}

	// Add sample products
	s.addSampleProducts()

	return s
}

func (s *ShopFlowServer) addSampleProducts() {
	sampleProducts := []*shopflowpb.Product{
		{
			Id:            "prod_001",
			Name:          "Wireless Bluetooth Headphones",
			Description:   "High-quality wireless headphones with noise cancellation",
			Price:         199.99,
			Currency:      "USD",
			StockQuantity: 50,
			Categories:    []string{"Electronics", "Audio"},
			Attributes: map[string]string{
				"brand":        "TechSound",
				"color":        "Black",
				"battery":      "30 hours",
				"connectivity": "Bluetooth 5.0",
			},
			CreatedAt:   timestamppb.New(time.Now().Add(-24 * time.Hour)),
			UpdatedAt:   timestamppb.New(time.Now()),
			Active:      true,
			Sku:         "TS-WH-001",
			ImageUrls:   []string{"https://example.com/headphones1.jpg", "https://example.com/headphones2.jpg"},
			Rating:      4.5,
			ReviewCount: 128,
		},
		{
			Id:            "prod_002",
			Name:          "Smart Fitness Watch",
			Description:   "Advanced fitness tracking with heart rate monitor",
			Price:         299.99,
			Currency:      "USD",
			StockQuantity: 25,
			Categories:    []string{"Electronics", "Fitness", "Wearables"},
			Attributes: map[string]string{
				"brand":      "FitTech",
				"color":      "Silver",
				"waterproof": "5ATM",
				"display":    "1.4 inch AMOLED",
			},
			CreatedAt:   timestamppb.New(time.Now().Add(-48 * time.Hour)),
			UpdatedAt:   timestamppb.New(time.Now()),
			Active:      true,
			Sku:         "FT-SW-002",
			ImageUrls:   []string{"https://example.com/watch1.jpg"},
			Rating:      4.8,
			ReviewCount: 89,
		},
		{
			Id:            "prod_003",
			Name:          "Organic Coffee Beans",
			Description:   "Premium organic coffee beans from Colombia",
			Price:         24.99,
			Currency:      "USD",
			StockQuantity: 100,
			Categories:    []string{"Food", "Beverages", "Organic"},
			Attributes: map[string]string{
				"origin":        "Colombia",
				"roast":         "Medium",
				"weight":        "1 lb",
				"certification": "USDA Organic",
			},
			CreatedAt:   timestamppb.New(time.Now().Add(-72 * time.Hour)),
			UpdatedAt:   timestamppb.New(time.Now()),
			Active:      true,
			Sku:         "OC-CB-003",
			ImageUrls:   []string{"https://example.com/coffee1.jpg"},
			Rating:      4.3,
			ReviewCount: 256,
		},
	}

	for _, product := range sampleProducts {
		s.products[product.Id] = product
	}
}

// Unary RPCs
func (s *ShopFlowServer) CreateProduct(ctx context.Context, req *shopflowpb.CreateProductRequest) (*shopflowpb.CreateProductResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	productID := fmt.Sprintf("prod_%03d", len(s.products)+1)
	now := timestamppb.New(time.Now())

	product := &shopflowpb.Product{
		Id:            productID,
		Name:          req.Name,
		Description:   req.Description,
		Price:         req.Price,
		Currency:      req.Currency,
		StockQuantity: req.StockQuantity,
		Categories:    req.Categories,
		Attributes:    req.Attributes,
		CreatedAt:     now,
		UpdatedAt:     now,
		Active:        true,
		Sku:           req.Sku,
		ImageUrls:     req.ImageUrls,
		Rating:        0.0,
		ReviewCount:   0,
	}

	s.products[productID] = product

	return &shopflowpb.CreateProductResponse{
		Product: product,
		Success: true,
		Message: "Product created successfully",
	}, nil
}

func (s *ShopFlowServer) GetProduct(ctx context.Context, req *shopflowpb.GetProductRequest) (*shopflowpb.GetProductResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	product, exists := s.products[req.ProductId]
	if !exists {
		return &shopflowpb.GetProductResponse{
			Product: nil,
			Found:   false,
		}, nil
	}

	return &shopflowpb.GetProductResponse{
		Product: product,
		Found:   true,
	}, nil
}

func (s *ShopFlowServer) UpdateProduct(ctx context.Context, req *shopflowpb.UpdateProductRequest) (*shopflowpb.UpdateProductResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	product, exists := s.products[req.ProductId]
	if !exists {
		return &shopflowpb.UpdateProductResponse{
			Product: nil,
			Success: false,
			Message: "Product not found",
		}, nil
	}

	// Update fields
	if req.Product.Name != "" {
		product.Name = req.Product.Name
	}
	if req.Product.Description != "" {
		product.Description = req.Product.Description
	}
	if req.Product.Price > 0 {
		product.Price = req.Product.Price
	}
	if req.Product.StockQuantity >= 0 {
		product.StockQuantity = req.Product.StockQuantity
	}
	if len(req.Product.Categories) > 0 {
		product.Categories = req.Product.Categories
	}
	if req.Product.Attributes != nil {
		product.Attributes = req.Product.Attributes
	}

	product.UpdatedAt = timestamppb.New(time.Now())

	return &shopflowpb.UpdateProductResponse{
		Product: product,
		Success: true,
		Message: "Product updated successfully",
	}, nil
}

func (s *ShopFlowServer) DeleteProduct(ctx context.Context, req *shopflowpb.DeleteProductRequest) (*shopflowpb.DeleteProductResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	_, exists := s.products[req.ProductId]
	if !exists {
		return &shopflowpb.DeleteProductResponse{
			Success: false,
			Message: "Product not found",
		}, nil
	}

	delete(s.products, req.ProductId)

	return &shopflowpb.DeleteProductResponse{
		Success: true,
		Message: "Product deleted successfully",
	}, nil
}

func (s *ShopFlowServer) CreateOrder(ctx context.Context, req *shopflowpb.CreateOrderRequest) (*shopflowpb.CreateOrderResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	orderID := fmt.Sprintf("order_%03d", len(s.orders)+1)
	now := timestamppb.New(time.Now())

	// Calculate total
	var totalAmount float64
	for _, item := range req.Items {
		totalAmount += item.TotalPrice
	}

	order := &shopflowpb.Order{
		Id:              orderID,
		CustomerId:      req.CustomerId,
		Items:           req.Items,
		TotalAmount:     totalAmount,
		Currency:        "USD",
		Status:          shopflowpb.OrderStatus_ORDER_STATUS_PENDING,
		ShippingAddress: req.ShippingAddress,
		BillingAddress:  req.BillingAddress,
		CreatedAt:       now,
		UpdatedAt:       now,
		PaymentMethod:   req.PaymentMethod,
		ShippingCost:    9.99,
		TaxAmount:       totalAmount * 0.08, // 8% tax
	}

	s.orders[orderID] = order

	return &shopflowpb.CreateOrderResponse{
		Order:   order,
		Success: true,
		Message: "Order created successfully",
	}, nil
}

func (s *ShopFlowServer) GetOrder(ctx context.Context, req *shopflowpb.GetOrderRequest) (*shopflowpb.GetOrderResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	order, exists := s.orders[req.OrderId]
	if !exists {
		return &shopflowpb.GetOrderResponse{
			Order: nil,
			Found: false,
		}, nil
	}

	return &shopflowpb.GetOrderResponse{
		Order: order,
		Found: true,
	}, nil
}

func (s *ShopFlowServer) UpdateOrderStatus(ctx context.Context, req *shopflowpb.UpdateOrderStatusRequest) (*shopflowpb.UpdateOrderStatusResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	order, exists := s.orders[req.OrderId]
	if !exists {
		return &shopflowpb.UpdateOrderStatusResponse{
			Order:   nil,
			Success: false,
			Message: "Order not found",
		}, nil
	}

	order.Status = req.Status
	order.UpdatedAt = timestamppb.New(time.Now())
	if req.TrackingNumber != "" {
		order.TrackingNumber = req.TrackingNumber
	}

	return &shopflowpb.UpdateOrderStatusResponse{
		Order:   order,
		Success: true,
		Message: "Order status updated successfully",
	}, nil
}

func (s *ShopFlowServer) ProcessPayment(ctx context.Context, req *shopflowpb.ProcessPaymentRequest) (*shopflowpb.ProcessPaymentResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	// Simulate payment processing
	transactionID := fmt.Sprintf("txn_%d", time.Now().Unix())

	response := &shopflowpb.ProcessPaymentResponse{
		TransactionId: transactionID,
		Success:       true,
		Message:       "Payment processed successfully",
		AmountCharged: req.Amount,
		Currency:      req.Currency,
		ProcessedAt:   timestamppb.New(time.Now()),
	}

	s.payments[transactionID] = response

	return response, nil
}

func (s *ShopFlowServer) RefundPayment(ctx context.Context, req *shopflowpb.RefundPaymentRequest) (*shopflowpb.RefundPaymentResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	// Check if original payment exists
	_, exists := s.payments[req.TransactionId]
	if !exists {
		return &shopflowpb.RefundPaymentResponse{
			RefundId:       "",
			Success:        false,
			Message:        "Original transaction not found",
			AmountRefunded: 0,
			ProcessedAt:    timestamppb.New(time.Now()),
		}, nil
	}

	refundID := fmt.Sprintf("refund_%d", time.Now().Unix())

	response := &shopflowpb.RefundPaymentResponse{
		RefundId:       refundID,
		Success:        true,
		Message:        "Refund processed successfully",
		AmountRefunded: req.Amount,
		ProcessedAt:    timestamppb.New(time.Now()),
	}

	s.refunds[refundID] = response

	return response, nil
}

// Server Streaming RPCs
func (s *ShopFlowServer) StreamProductUpdates(req *shopflowpb.StreamProductUpdatesRequest, stream shopflowpb.ShopFlowService_StreamProductUpdatesServer) error {
	// Simulate product updates
	updates := []*shopflowpb.ProductUpdate{
		{
			ProductId:  "prod_001",
			UpdateType: "price_change",
			Product:    s.products["prod_001"],
			UpdatedAt:  timestamppb.New(time.Now()),
		},
		{
			ProductId:  "prod_002",
			UpdateType: "stock_update",
			Product:    s.products["prod_002"],
			UpdatedAt:  timestamppb.New(time.Now().Add(5 * time.Second)),
		},
	}

	for _, update := range updates {
		if err := stream.Send(update); err != nil {
			return err
		}
		time.Sleep(2 * time.Second)
	}

	return nil
}

func (s *ShopFlowServer) StreamOrderStatus(req *shopflowpb.StreamOrderStatusRequest, stream shopflowpb.ShopFlowService_StreamOrderStatusServer) error {
	// Simulate order status updates
	statuses := []shopflowpb.OrderStatus{
		shopflowpb.OrderStatus_ORDER_STATUS_CONFIRMED,
		shopflowpb.OrderStatus_ORDER_STATUS_PROCESSING,
		shopflowpb.OrderStatus_ORDER_STATUS_SHIPPED,
		shopflowpb.OrderStatus_ORDER_STATUS_DELIVERED,
	}

	for i, status := range statuses {
		update := &shopflowpb.OrderStatusUpdate{
			OrderId:        req.OrderId,
			Status:         status,
			Message:        fmt.Sprintf("Order status updated to %s", status.String()),
			UpdatedAt:      timestamppb.New(time.Now().Add(time.Duration(i) * 10 * time.Second)),
			TrackingNumber: fmt.Sprintf("TRK%06d", 123456+i),
		}

		if err := stream.Send(update); err != nil {
			return err
		}
		time.Sleep(3 * time.Second)
	}

	return nil
}

func (s *ShopFlowServer) StreamInventoryAlerts(req *shopflowpb.StreamInventoryAlertsRequest, stream shopflowpb.ShopFlowService_StreamInventoryAlertsServer) error {
	// Simulate inventory alerts
	alerts := []*shopflowpb.InventoryAlert{
		{
			ProductId:    "prod_001",
			ProductName:  "Wireless Bluetooth Headphones",
			CurrentStock: 5,
			Threshold:    req.LowStockThreshold,
			AlertType:    "low_stock",
			AlertTime:    timestamppb.New(time.Now()),
		},
		{
			ProductId:    "prod_002",
			ProductName:  "Smart Fitness Watch",
			CurrentStock: 0,
			Threshold:    req.LowStockThreshold,
			AlertType:    "out_of_stock",
			AlertTime:    timestamppb.New(time.Now().Add(5 * time.Second)),
		},
	}

	for _, alert := range alerts {
		if err := stream.Send(alert); err != nil {
			return err
		}
		time.Sleep(2 * time.Second)
	}

	return nil
}

// Client Streaming RPCs
func (s *ShopFlowServer) BulkCreateProducts(stream shopflowpb.ShopFlowService_BulkCreateProductsServer) error {
	var totalProcessed, successful, failed int32
	var productIDs []string
	var errors []string

	for {
		_, err := stream.Recv()
		if err != nil {
			break
		}

		totalProcessed++

		// Simulate product creation
		productID := fmt.Sprintf("bulk_prod_%03d", totalProcessed)
		productIDs = append(productIDs, productID)
		successful++
	}

	response := &shopflowpb.BulkCreateProductsResponse{
		TotalProcessed: totalProcessed,
		Successful:     successful,
		Failed:         failed,
		ProductIds:     productIDs,
		Errors:         errors,
	}

	return stream.SendAndClose(response)
}

func (s *ShopFlowServer) BulkUpdateInventory(stream shopflowpb.ShopFlowService_BulkUpdateInventoryServer) error {
	var totalProcessed, successful, failed int32
	var errors []string

	for {
		_, err := stream.Recv()
		if err != nil {
			break
		}

		totalProcessed++

		// Simulate inventory update
		successful++
	}

	response := &shopflowpb.BulkUpdateInventoryResponse{
		TotalProcessed: totalProcessed,
		Successful:     successful,
		Failed:         failed,
		Errors:         errors,
	}

	return stream.SendAndClose(response)
}

// Bidirectional Streaming RPCs
func (s *ShopFlowServer) RealTimeChat(stream shopflowpb.ShopFlowService_RealTimeChatServer) error {
	for {
		msg, err := stream.Recv()
		if err != nil {
			return err
		}

		// Echo the message back with agent response
		response := &shopflowpb.ChatMessage{
			Id:          fmt.Sprintf("msg_%d", time.Now().Unix()),
			CustomerId:  msg.CustomerId,
			AgentId:     "agent_001",
			Message:     fmt.Sprintf("Thank you for your message: %s. How can I help you?", msg.Message),
			MessageType: "text",
			Timestamp:   timestamppb.New(time.Now()),
			IsCustomer:  false,
		}

		if err := stream.Send(response); err != nil {
			return err
		}
	}
}

func (s *ShopFlowServer) LiveOrderTracking(stream shopflowpb.ShopFlowService_LiveOrderTrackingServer) error {
	for {
		req, err := stream.Recv()
		if err != nil {
			return err
		}

		// Simulate tracking update
		update := &shopflowpb.OrderTrackingUpdate{
			OrderId:   req.OrderId,
			Status:    shopflowpb.OrderStatus_ORDER_STATUS_SHIPPED,
			Location:  "Distribution Center - San Francisco",
			Message:   "Package is in transit",
			Timestamp: timestamppb.New(time.Now()),
			Latitude:  37.7749,
			Longitude: -122.4194,
		}

		if err := stream.Send(update); err != nil {
			return err
		}
	}
}

// Health and monitoring
func (s *ShopFlowServer) HealthCheck(ctx context.Context, req *shopflowpb.HealthCheckRequest) (*shopflowpb.HealthCheckResponse, error) {
	return &shopflowpb.HealthCheckResponse{
		Status:    "healthy",
		Message:   "ShopFlow E-commerce service is running",
		Timestamp: timestamppb.New(time.Now()),
	}, nil
}

func (s *ShopFlowServer) GetMetrics(ctx context.Context, req *shopflowpb.GetMetricsRequest) (*shopflowpb.GetMetricsResponse, error) {
	var value float64
	var unit string

	switch req.MetricType {
	case "orders":
		value = float64(len(s.orders))
		unit = "count"
	case "revenue":
		value = 125000.50
		unit = "USD"
	case "products":
		value = float64(len(s.products))
		unit = "count"
	case "customers":
		value = 1250.0
		unit = "count"
	default:
		value = 0
		unit = "unknown"
	}

	return &shopflowpb.GetMetricsResponse{
		MetricType: req.MetricType,
		Value:      value,
		Unit:       unit,
		Timestamp:  timestamppb.New(time.Now()),
		Metadata: map[string]string{
			"source":  "shopflow-database",
			"period":  "last_24_hours",
			"version": "1.0.0",
		},
	}, nil
}

func main() {
	// Check for TLS certificates
	useTLS := false
	if _, err := os.Stat("tls/server-cert.pem"); err == nil {
		if _, err := os.Stat("tls/server-key.pem"); err == nil {
			useTLS = true
		}
	}

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
		}

		lis, err = tls.Listen("tcp", ":50058", config)
		if err != nil {
			log.Fatalf("Failed to listen with TLS: %v", err)
		}

		fmt.Println("🔒 ShopFlow E-commerce Service is running with TLS on port 50058...")
	} else {
		lis, err = net.Listen("tcp", ":50058")
		if err != nil {
			log.Fatalf("Failed to listen: %v", err)
		}

		fmt.Println("⚠️  ShopFlow E-commerce Service is running without TLS on port 50058...")
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
		})
		s = grpc.NewServer(grpc.Creds(creds))
	} else {
		s = grpc.NewServer()
	}

	// Register services
	shopflowServer := NewShopFlowServer()
	shopflowpb.RegisterShopFlowServiceServer(s, shopflowServer)
	reflection.Register(s)

	fmt.Println("Available methods:")
	fmt.Println("  - CreateProduct, GetProduct, UpdateProduct, DeleteProduct")
	fmt.Println("  - CreateOrder, GetOrder, UpdateOrderStatus")
	fmt.Println("  - ProcessPayment, RefundPayment")
	fmt.Println("  - StreamProductUpdates, StreamOrderStatus, StreamInventoryAlerts")
	fmt.Println("  - BulkCreateProducts, BulkUpdateInventory")
	fmt.Println("  - RealTimeChat, LiveOrderTracking")
	fmt.Println("  - HealthCheck, GetMetrics")

	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
