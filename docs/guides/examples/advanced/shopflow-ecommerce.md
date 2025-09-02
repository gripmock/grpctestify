# E-commerce ShopFlow Examples

Complete e-commerce platform testing with complex business workflows.

## 📁 Example Location

```
examples/advanced-examples/shopflow-ecommerce/
├── server/           # Go gRPC server implementation
├── tests/           # .gctf test files
└── README.md        # Setup instructions
```

## 🎯 Test Scenarios

### Product Management
Create and manage products:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
shopflow.ShopFlowService/CreateProduct

--- REQUEST ---
{
    "name": "Wireless Bluetooth Headphones",
    "description": "High-quality wireless headphones",
    "price": 199.99,
    "currency": "USD",
    "stock_quantity": 50,
    "categories": ["Electronics", "Audio"],
    "sku": "WH-001"
}

--- RESPONSE ---
{
    "product": {
        "id": "prod_001",
        "name": "Wireless Bluetooth Headphones",
        "description": "High-quality wireless headphones",
        "price": 199.99,
        "currency": "USD",
        "stock_quantity": 50,
        "categories": ["Electronics", "Audio"],
        "sku": "WH-001",
        "created_at": "2024-01-01T12:00:00Z"
    },
    "success": true
}

--- ASSERTS ---
.product.id | type == "string"
.product.price == 199.99
.product.stock_quantity == 50
.success == true
```

### Order Processing
Complete order workflow:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
shopflow.ShopFlowService/CreateOrder

--- REQUEST ---
{
    "customer_id": "cust_123",
    "items": [
        {
            "product_id": "prod_001",
            "quantity": 2,
            "unit_price": 199.99
        }
    ],
    "shipping_address": {
        "street": "123 Main St",
        "city": "New York",
        "state": "NY",
        "zip": "10001"
    }
}

--- RESPONSE ---
{
    "order": {
        "id": "order_001",
        "customer_id": "cust_123",
        "status": "pending",
        "total_amount": 399.98,
        "currency": "USD",
        "items": [
            {
                "product_id": "prod_001",
                "quantity": 2,
                "unit_price": 199.99,
                "total_price": 399.98
            }
        ],
        "created_at": "2024-01-01T12:00:00Z"
    },
    "success": true
}

--- ASSERTS ---
.order.id | type == "string"
.order.status == "pending"
.order.total_amount == 399.98
.order.items | length == 1
.success == true
```

### Payment Processing
Secure payment handling:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
shopflow.ShopFlowService/ProcessPayment

--- REQUEST ---
{
    "order_id": "order_001",
    "payment_method": "credit_card",
    "card_token": "tok_1234567890",
    "amount": 399.98,
    "currency": "USD"
}

--- RESPONSE ---
{
    "payment": {
        "id": "pay_001",
        "order_id": "order_001",
        "status": "completed",
        "amount": 399.98,
        "currency": "USD",
        "transaction_id": "txn_1234567890",
        "processed_at": "2024-01-01T12:05:00Z"
    },
    "success": true
}

--- ASSERTS ---
.payment.status == "completed"
.payment.amount == 399.98
.payment.transaction_id | type == "string"
.success == true
```

### Inventory Management
Real-time inventory updates:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
shopflow.ShopFlowService/UpdateInventory

--- REQUEST ---
{
    "product_id": "prod_001",
    "operation": "decrease",
    "quantity": 2,
    "reason": "order_fulfillment"
}

--- RESPONSE ---
{
    "inventory": {
        "product_id": "prod_001",
        "previous_quantity": 50,
        "new_quantity": 48,
        "operation": "decrease",
        "updated_at": "2024-01-01T12:10:00Z"
    },
    "success": true
}

--- ASSERTS ---
.inventory.product_id == "prod_001"
.inventory.previous_quantity == 50
.inventory.new_quantity == 48
.inventory.operation == "decrease"
.success == true
```

### Client Streaming - Bulk Operations
Efficient bulk product creation:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
shopflow.ShopFlowService/BulkCreateProducts

--- REQUEST ---
{
    "name": "Product 1",
    "description": "First product",
    "price": 10.99,
    "stock_quantity": 100
}

--- REQUEST ---
{
    "name": "Product 2", 
    "description": "Second product",
    "price": 20.99,
    "stock_quantity": 50
}

--- REQUEST ---
{
    "name": "Product 3",
    "description": "Third product", 
    "price": 30.99,
    "stock_quantity": 75
}

--- RESPONSE ---
{
    "created_products": 3,
    "success_count": 3,
    "failed_count": 0,
    "products": [
        {
            "id": "prod_001",
            "name": "Product 1",
            "status": "created"
        },
        {
            "id": "prod_002", 
            "name": "Product 2",
            "status": "created"
        },
        {
            "id": "prod_003",
            "name": "Product 3", 
            "status": "created"
        }
    ]
}

--- ASSERTS ---
.created_products == 3
.success_count == 3
.failed_count == 0
.products | length == 3
```

### Server Streaming - Order Status
Real-time order tracking:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
shopflow.ShopFlowService/OrderStatusStreaming

--- REQUEST ---
{
    "order_id": "order_001"
}

--- ASSERTS ---
.status == "PROCESSING"
.order_id == "order_001"
.message | contains("Processing")

--- ASSERTS ---
.status == "PAYMENT_VERIFIED"
.order_id == "order_001"
.message | contains("Payment verified")

--- ASSERTS ---
.status == "SHIPPED"
.order_id == "order_001"
.tracking_number | type == "string"
```

### Bidirectional Streaming - Live Chat
Customer support chat:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
shopflow.ShopFlowService/RealtimeChat

--- REQUEST ---
{
    "customer_id": "cust_123",
    "message": "I have a question about my order"
}

--- ASSERTS ---
.agent_id | type == "string"
.message | contains("How can I help you")

--- REQUEST ---
{
    "customer_id": "cust_123",
    "message": "When will my order ship?"
}

--- ASSERTS ---
.agent_id | type == "string"
.message | contains("Your order will ship")
```

## 🔧 Running the Examples

```bash
# Navigate to the example
cd examples/advanced-examples/shopflow-ecommerce

# Start the server
make start

# Run all tests
../../grpctestify.sh tests/*.gctf

# Run specific test
../../grpctestify.sh tests/product_management_unary.gctf

# Stop the server
make stop
```

## 📊 Test Coverage

This example demonstrates:

- ✅ **Product Management** - CRUD operations for products
- ✅ **Order Processing** - Complete order lifecycle
- ✅ **Payment Processing** - Secure payment handling
- ✅ **Inventory Management** - Real-time stock updates
- ✅ **Client Streaming** - Bulk operations
- ✅ **Server Streaming** - Real-time status updates
- ✅ **Bidirectional Streaming** - Customer support chat
- ✅ **Business Logic** - Complex e-commerce workflows

## 🎓 Learning Points

1. **E-commerce Patterns** - Product, order, and payment management
2. **Streaming** - Real-time updates and bulk operations
3. **Business Workflows** - Complex multi-step processes
4. **Data Validation** - Business rule enforcement
5. **Customer Experience** - Real-time communication

## 🔗 Related Examples

- **[User Management](../basic/user-management.md)** - Customer management
- **[Media Streaming](media-streaming.md)** - Product media handling
- **[Fintech Payment](../security/fintech-payment.md)** - Advanced payment processing
