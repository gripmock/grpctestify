# AI Chat Examples

AI-powered conversation and sentiment analysis testing patterns.

## 📁 Example Location

```
examples/advanced-examples/ai-chat/
├── server/           # Go gRPC server implementation
├── tests/           # .gctf test files
└── README.md        # Setup instructions
```

## 🎯 Test Scenarios

### Chat Session Creation
Create AI chat sessions:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
ai.AIChatService/CreateChatSession

--- REQUEST ---
{
    "user_id": "user_123",
    "session_type": "conversation",
    "model": "gpt-4",
    "context": {
        "language": "en",
        "topic": "general"
    }
}

--- RESPONSE ---
{
    "session": {
        "id": "session_001",
        "user_id": "user_123",
        "session_type": "conversation",
        "model": "gpt-4",
        "status": "active",
        "created_at": "2024-01-01T12:00:00Z"
    },
    "success": true
}

--- ASSERTS ---
.session.id | type == "string"
.session.status == "active"
.session.model == "gpt-4"
.success == true
```

### Send Message
Basic message sending to AI:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
ai.AIChatService/SendMessage

--- REQUEST ---
{
    "session_id": "session_001",
    "message": "Hello, how are you?",
    "message_type": "user"
}

--- RESPONSE ---
{
    "message": {
        "id": "msg_001",
        "session_id": "session_001",
        "content": "Hello! I'm doing well, thank you for asking. How can I help you today?",
        "message_type": "assistant",
        "timestamp": "2024-01-01T12:01:00Z"
    },
    "success": true
}

--- ASSERTS ---
.message.id | type == "string"
.message.content | length > 0
.message.message_type == "assistant"
.success == true
```

### Sentiment Analysis
Analyze message sentiment:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
ai.AIChatService/AnalyzeSentiment

--- REQUEST ---
{
    "text": "I'm really happy with the service!",
    "language": "en"
}

--- RESPONSE ---
{
    "sentiment": {
        "text": "I'm really happy with the service!",
        "sentiment_score": 0.85,
        "sentiment_label": "positive",
        "confidence": 0.92,
        "emotions": {
            "joy": 0.8,
            "satisfaction": 0.7
        }
    },
    "success": true
}

--- ASSERTS ---
.sentiment.sentiment_score > 0.5
.sentiment.sentiment_label == "positive"
.sentiment.confidence > 0.8
.sentiment.emotions.joy > 0.5
.success == true
```

### Bidirectional Streaming - Conversation
Real-time AI conversation:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
ai.AIChatService/ChatConversation

--- REQUEST ---
{
    "session_id": "session_001",
    "message": "Tell me about machine learning"
}

--- ASSERTS ---
.session_id == "session_001"
.message | contains("machine learning")
.response_type == "streaming"

--- REQUEST ---
{
    "session_id": "session_001",
    "message": "What are the main types?"
}

--- ASSERTS ---
.session_id == "session_001"
.message | contains("types")
.response_type == "streaming"
```

### Context-Aware Conversation
Advanced context management:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
ai.AIChatService/ContextAwareConversation

--- REQUEST ---
{
    "session_id": "session_001",
    "message": "My name is Alice",
    "context": {
        "remember_user_info": true
    }
}

--- ASSERTS ---
.session_id == "session_001"
.response | contains("Alice")
.context_updated == true

--- REQUEST ---
{
    "session_id": "session_001",
    "message": "What's my name?",
    "context": {
        "use_memory": true
    }
}

--- ASSERTS ---
.session_id == "session_001"
.response | contains("Alice")
.memory_used == true
```

### Multilingual Chat
Multi-language conversation support:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
ai.AIChatService/MultilingualChat

--- REQUEST ---
{
    "session_id": "session_001",
    "message": "Bonjour, comment allez-vous?",
    "language": "fr"
}

--- ASSERTS ---
.session_id == "session_001"
.response | contains("Bonjour")
.language_detected == "fr"
.translation_quality > 0.8

--- REQUEST ---
{
    "session_id": "session_001",
    "message": "Hola, ¿cómo estás?",
    "language": "es"
}

--- ASSERTS ---
.session_id == "session_001"
.response | contains("Hola")
.language_detected == "es"
```

### Streaming Response
Chunked AI responses:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
ai.AIChatService/StreamingResponse

--- REQUEST ---
{
    "session_id": "session_001",
    "message": "Write a short story about a robot"
}

--- ASSERTS ---
.session_id == "session_001"
.chunk_number | type == "number"
.content | type == "string"
.is_final == false

--- ASSERTS ---
.session_id == "session_001"
.chunk_number | type == "number"
.content | type == "string"
.is_final == true
.total_chunks > 1
```

### Advanced NLP Processing
Natural language processing features:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
ai.AIChatService/AdvancedNLPConversation

--- REQUEST ---
{
    "session_id": "session_001",
    "message": "What is the weather like today?",
    "nlp_features": {
        "intent_detection": true,
        "entity_extraction": true,
        "sentiment_analysis": true
    }
}

--- ASSERTS ---
.session_id == "session_001"
.intent == "weather_inquiry"
.entities | length > 0
.sentiment | type == "object"
.confidence > 0.7
```

## 🔧 Running the Examples

```bash
# Navigate to the example
cd examples/advanced-examples/ai-chat

# Start the server
make start

# Run all tests
../../grpctestify.sh tests/*.gctf

# Run specific test
../../grpctestify.sh tests/send_message_unary.gctf

# Stop the server
make stop
```

## 📊 Test Coverage

This example demonstrates:

- ✅ **Chat Sessions** - Session management and creation
- ✅ **Message Handling** - Send and receive messages
- ✅ **Sentiment Analysis** - Text sentiment processing
- ✅ **Bidirectional Streaming** - Real-time conversations
- ✅ **Context Management** - Memory and context awareness
- ✅ **Multilingual Support** - Multi-language conversations
- ✅ **Streaming Responses** - Chunked AI responses
- ✅ **NLP Features** - Advanced language processing
- ✅ **AI Integration** - AI model interaction patterns

## 🎓 Learning Points

1. **AI Integration** - Working with AI models and services
2. **Conversation Patterns** - Multi-turn dialogue management
3. **Context Awareness** - Maintaining conversation context
4. **Multilingual Support** - Language detection and translation
5. **Streaming** - Real-time AI response handling

## 🔗 Related Examples

- **[Real-time Chat](../basic/real-time-chat.md)** - Basic messaging patterns
- **[Media Streaming](media-streaming.md)** - Content processing
- **[ShopFlow E-commerce](shopflow-ecommerce.md)** - Customer support integration
