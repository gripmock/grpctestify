# IoT Monitoring Examples

Device management and monitoring scenarios for IoT applications.

## 📁 Example Location

```
examples/basic-examples/iot-monitoring/
├── server/           # Go gRPC server implementation
├── tests/           # .gctf test files
└── README.md        # Setup instructions
```

## 🎯 Test Scenarios

### Device Registration
Register new IoT devices:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
iot.IoTService/RegisterDevice

--- REQUEST ---
{
    "device_id": "sensor_001",
    "device_type": "temperature",
    "location": "room_101",
    "capabilities": ["temperature", "humidity"]
}

--- RESPONSE ---
{
    "device": {
        "id": "sensor_001",
        "type": "temperature",
        "location": "room_101",
        "capabilities": ["temperature", "humidity"],
        "status": "active",
        "registered_at": "2024-01-01T12:00:00Z"
    },
    "success": true
}

--- ASSERTS ---
.device.id == "sensor_001"
.device.status == "active"
.device.capabilities | length == 2
.success == true
```

### Get Device Metrics
Retrieve device sensor data:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
iot.IoTService/GetDeviceMetrics

--- REQUEST ---
{
    "device_id": "sensor_001",
    "metric_type": "temperature",
    "start_time": "2024-01-01T00:00:00Z",
    "end_time": "2024-01-01T23:59:59Z"
}

--- RESPONSE ---
{
    "device_id": "sensor_001",
    "metric_type": "temperature",
    "readings": [
        {
            "timestamp": "2024-01-01T12:00:00Z",
            "value": 22.5,
            "unit": "celsius"
        },
        {
            "timestamp": "2024-01-01T12:01:00Z",
            "value": 22.7,
            "unit": "celsius"
        }
    ],
    "total_readings": 2
}

--- ASSERTS ---
.device_id == "sensor_001"
.metric_type == "temperature"
.readings | length == 2
.readings[0].value | type == "number"
.total_readings == 2
```

### Server Streaming - Monitor Devices
Real-time device monitoring with streaming:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
iot.IoTService/StreamDeviceStatus

--- REQUEST ---
{
    "device_ids": ["sensor_001", "sensor_002"],
    "monitoring_duration": 30
}

--- ASSERTS ---
.status == "CONNECTING"
.device_id | test("sensor_00[12]")
.timestamp | type == "string"

--- ASSERTS ---
.status == "ONLINE"
.device_id | test("sensor_00[12]")
.metrics.temperature | type == "number"
.metrics.humidity | type == "number"

--- ASSERTS ---
.status == "DATA"
.device_id | test("sensor_00[12]")
.metrics.temperature >= 15
.metrics.temperature <= 35
```

### Client Streaming - Bulk Update
Update multiple devices with streaming:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
iot.IoTService/BulkUpdateDevices

--- REQUEST ---
{
    "device_id": "sensor_001",
    "update_type": "configuration",
    "settings": {
        "sampling_rate": 60,
        "alert_threshold": 25.0
    }
}

--- REQUEST ---
{
    "device_id": "sensor_002",
    "update_type": "configuration",
    "settings": {
        "sampling_rate": 30,
        "alert_threshold": 30.0
    }
}

--- RESPONSE ---
{
    "updated_devices": 2,
    "success_count": 2,
    "failed_count": 0,
    "results": [
        {
            "device_id": "sensor_001",
            "status": "updated"
        },
        {
            "device_id": "sensor_002",
            "status": "updated"
        }
    ]
}

--- ASSERTS ---
.updated_devices == 2
.success_count == 2
.failed_count == 0
.results | length == 2
```

### Bidirectional Streaming - Advanced Monitoring
Complex bidirectional communication:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
iot.IoTService/AdvancedDeviceManagement

--- REQUEST ---
{
    "command": "START_MONITORING",
    "device_ids": ["sensor_001", "sensor_002"],
    "parameters": {
        "interval": 5,
        "metrics": ["temperature", "humidity"]
    }
}

--- ASSERTS ---
.command == "START_MONITORING"
.status == "MONITORING_STARTED"
.device_count == 2

--- REQUEST ---
{
    "command": "GET_STATUS",
    "device_id": "sensor_001"
}

--- ASSERTS ---
.command == "GET_STATUS"
.device_id == "sensor_001"
.status == "ONLINE"
.metrics.temperature | type == "number"

--- REQUEST ---
{
    "command": "STOP_MONITORING",
    "device_ids": ["sensor_001", "sensor_002"]
}

--- ASSERTS ---
.command == "STOP_MONITORING"
.status == "MONITORING_STOPPED"
.device_count == 2
```

## 🔧 Running the Examples

```bash
# Navigate to the example
cd examples/basic-examples/iot-monitoring

# Start the server
make start

# Run all tests
../../grpctestify.sh tests/*.gctf

# Run specific test
../../grpctestify.sh tests/register_device_unary.gctf

# Stop the server
make stop
```

## 📊 Test Coverage

This example demonstrates:

- ✅ **Device Management** - Registration and configuration
- ✅ **Data Collection** - Sensor metrics and readings
- ✅ **Server Streaming** - Real-time monitoring
- ✅ **Client Streaming** - Bulk operations
- ✅ **Bidirectional Streaming** - Complex device control
- ✅ **Time Series Data** - Historical data analysis
- ✅ **Device Status** - Health monitoring and alerts

## 🎓 Learning Points

1. **IoT Patterns** - Device registration and management
2. **Streaming** - Real-time data collection and monitoring
3. **Bulk Operations** - Efficient multi-device updates
4. **Time Series** - Historical data and metrics
5. **Device Control** - Configuration and status management

## 🔗 Related Examples

- **[User Management](user-management.md)** - Device user management
- **[Real-time Chat](real-time-chat.md)** - Real-time communication
- **[Media Streaming](../advanced/media-streaming.md)** - Data streaming patterns
