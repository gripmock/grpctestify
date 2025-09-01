package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net"
	"sync"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"

	monitoringpb "github.com/gripmock/grpctestify/examples/basic-examples/iot-monitoring/server/monitoringpb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// IoTMonitoringServer implements the IoTMonitoringService
type IoTMonitoringServer struct {
	monitoringpb.UnimplementedIoTMonitoringServiceServer
	devices    map[string]*monitoringpb.Device
	telemetry  map[string][]*monitoringpb.MetricDataPoint
	mutex      sync.RWMutex
	monitoring map[string]chan *monitoringpb.DeviceTelemetry
}

// NewIoTMonitoringServer creates a new IoT monitoring server
func NewIoTMonitoringServer() *IoTMonitoringServer {
	s := &IoTMonitoringServer{
		devices:    make(map[string]*monitoringpb.Device),
		telemetry:  make(map[string][]*monitoringpb.MetricDataPoint),
		monitoring: make(map[string]chan *monitoringpb.DeviceTelemetry),
	}

	// Add sample devices
	s.addSampleDevices()

	return s
}

// Add sample devices for testing
func (s *IoTMonitoringServer) addSampleDevices() {
	sampleDevices := []*monitoringpb.Device{
		{
			Id:              "device_001",
			Name:            "Temperature Sensor - Living Room",
			Type:            "temperature_sensor",
			Location:        "Living Room",
			Status:          monitoringpb.DeviceStatus_DEVICE_STATUS_ONLINE,
			FirmwareVersion: "1.2.3",
			LastSeen:        timestamppb.New(time.Now()),
			CreatedAt:       timestamppb.New(time.Now().Add(-24 * time.Hour)),
			UpdatedAt:       timestamppb.New(time.Now()),
			Metadata: map[string]string{
				"manufacturer": "SensorTech",
				"model":        "ST-100",
				"room":         "living_room",
			},
			Configuration: map[string]string{
				"update_interval": "30s",
				"alert_threshold": "25.0",
			},
		},
		{
			Id:              "device_002",
			Name:            "Humidity Sensor - Kitchen",
			Type:            "humidity_sensor",
			Location:        "Kitchen",
			Status:          monitoringpb.DeviceStatus_DEVICE_STATUS_ONLINE,
			FirmwareVersion: "1.1.5",
			LastSeen:        timestamppb.New(time.Now()),
			CreatedAt:       timestamppb.New(time.Now().Add(-48 * time.Hour)),
			UpdatedAt:       timestamppb.New(time.Now()),
			Metadata: map[string]string{
				"manufacturer": "HumidityCorp",
				"model":        "HC-200",
				"room":         "kitchen",
			},
			Configuration: map[string]string{
				"update_interval": "60s",
				"alert_threshold": "70.0",
			},
		},
		{
			Id:              "device_003",
			Name:            "Smart Thermostat - Bedroom",
			Type:            "thermostat",
			Location:        "Bedroom",
			Status:          monitoringpb.DeviceStatus_DEVICE_STATUS_MAINTENANCE,
			FirmwareVersion: "2.0.1",
			LastSeen:        timestamppb.New(time.Now().Add(-5 * time.Minute)),
			CreatedAt:       timestamppb.New(time.Now().Add(-72 * time.Hour)),
			UpdatedAt:       timestamppb.New(time.Now()),
			Metadata: map[string]string{
				"manufacturer": "ThermoSmart",
				"model":        "TS-300",
				"room":         "bedroom",
			},
			Configuration: map[string]string{
				"target_temperature": "22.0",
				"update_interval":    "15s",
			},
		},
	}

	for _, device := range sampleDevices {
		s.devices[device.Id] = device
	}
}

// RegisterDevice registers a new IoT device
func (s *IoTMonitoringServer) RegisterDevice(ctx context.Context, req *monitoringpb.RegisterDeviceRequest) (*monitoringpb.RegisterDeviceResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	deviceID := req.DeviceId
	if deviceID == "" {
		deviceID = fmt.Sprintf("device_%03d", len(s.devices)+1)
	}

	now := timestamppb.New(time.Now())

	device := &monitoringpb.Device{
		Id:              deviceID,
		Name:            req.DeviceName,
		Type:            req.DeviceType,
		Location:        req.Location,
		Status:          monitoringpb.DeviceStatus_DEVICE_STATUS_ONLINE,
		FirmwareVersion: req.FirmwareVersion,
		LastSeen:        now,
		CreatedAt:       now,
		UpdatedAt:       now,
		Metadata:        req.Metadata,
		Configuration:   make(map[string]string),
	}

	s.devices[deviceID] = device

	return &monitoringpb.RegisterDeviceResponse{
		Success: true,
		Message: fmt.Sprintf("Device %s registered successfully", deviceID),
		Device:  device,
	}, nil
}

// GetDevice retrieves device information
func (s *IoTMonitoringServer) GetDevice(ctx context.Context, req *monitoringpb.GetDeviceRequest) (*monitoringpb.GetDeviceResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	device, exists := s.devices[req.DeviceId]
	if !exists {
		return &monitoringpb.GetDeviceResponse{
			Found: false,
		}, nil
	}

	return &monitoringpb.GetDeviceResponse{
		Found:  true,
		Device: device,
	}, nil
}

// UpdateDeviceStatus updates device status
func (s *IoTMonitoringServer) UpdateDeviceStatus(ctx context.Context, req *monitoringpb.UpdateDeviceStatusRequest) (*monitoringpb.UpdateDeviceStatusResponse, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	device, exists := s.devices[req.DeviceId]
	if !exists {
		return &monitoringpb.UpdateDeviceStatusResponse{
			Success: false,
			Message: "Device not found",
		}, nil
	}

	device.Status = req.Status
	device.UpdatedAt = timestamppb.New(time.Now())
	if req.Reason != "" {
		device.Metadata["status_reason"] = req.Reason
	}

	return &monitoringpb.UpdateDeviceStatusResponse{
		Success: true,
		Message: fmt.Sprintf("Device %s status updated to %s", req.DeviceId, req.Status),
		Device:  device,
	}, nil
}

// GetDeviceMetrics retrieves device metrics
func (s *IoTMonitoringServer) GetDeviceMetrics(ctx context.Context, req *monitoringpb.GetDeviceMetricsRequest) (*monitoringpb.GetDeviceMetricsResponse, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	// Generate sample metrics for the requested device
	var dataPoints []*monitoringpb.MetricDataPoint
	now := time.Now()

	switch req.MetricType {
	case "temperature", "all":
		for i := 0; i < 10; i++ {
			timestamp := now.Add(time.Duration(-i*30) * time.Second)
			dataPoints = append(dataPoints, &monitoringpb.MetricDataPoint{
				Timestamp:  timestamppb.New(timestamp),
				MetricName: "temperature",
				Value:      22.5 + float64(i%5),
				Unit:       "celsius",
				Tags: map[string]string{
					"device_id": req.DeviceId,
					"location":  "indoor",
				},
			})
		}
	}

	if req.MetricType == "humidity" || req.MetricType == "all" {
		for i := 0; i < 10; i++ {
			timestamp := now.Add(time.Duration(-i*30) * time.Second)
			dataPoints = append(dataPoints, &monitoringpb.MetricDataPoint{
				Timestamp:  timestamppb.New(timestamp),
				MetricName: "humidity",
				Value:      45.0 + float64(i%10),
				Unit:       "percent",
				Tags: map[string]string{
					"device_id": req.DeviceId,
					"location":  "indoor",
				},
			})
		}
	}

	return &monitoringpb.GetDeviceMetricsResponse{
		DeviceId:    req.DeviceId,
		MetricType:  req.MetricType,
		DataPoints:  dataPoints,
		TotalPoints: int32(len(dataPoints)),
	}, nil
}

// HealthCheck provides service health information
func (s *IoTMonitoringServer) HealthCheck(ctx context.Context, req *monitoringpb.HealthCheckRequest) (*monitoringpb.HealthCheckResponse, error) {
	return &monitoringpb.HealthCheckResponse{
		Status:    "healthy",
		Version:   "1.0.0",
		Timestamp: timestamppb.New(time.Now()),
		Metadata: map[string]string{
			"total_devices": fmt.Sprintf("%d", len(s.devices)),
			"service":       "iot-monitoring",
		},
	}, nil
}

// StreamDeviceStatus streams real-time device status updates
func (s *IoTMonitoringServer) StreamDeviceStatus(req *monitoringpb.StreamDeviceStatusRequest, stream monitoringpb.IoTMonitoringService_StreamDeviceStatusServer) error {
	deviceIDs := req.DeviceIds
	if len(deviceIDs) == 0 {
		// Stream all devices if none specified
		s.mutex.RLock()
		for deviceID := range s.devices {
			deviceIDs = append(deviceIDs, deviceID)
		}
		s.mutex.RUnlock()
	}

	interval := time.Duration(req.UpdateIntervalSeconds) * time.Second
	if interval == 0 {
		interval = 5 * time.Second
	}

	for {
		for _, deviceID := range deviceIDs {
			s.mutex.RLock()
			device, exists := s.devices[deviceID]
			s.mutex.RUnlock()

			if !exists {
				continue
			}

			update := &monitoringpb.DeviceStatusUpdate{
				DeviceId:  deviceID,
				Status:    device.Status,
				Timestamp: timestamppb.New(time.Now()),
				Message:   fmt.Sprintf("Device %s is %s", deviceID, device.Status),
				Metadata: map[string]string{
					"location": device.Location,
					"type":     device.Type,
				},
			}

			if err := stream.Send(update); err != nil {
				return err
			}
		}

		time.Sleep(interval)
	}
}

// BulkUpdateDevices processes bulk device configuration updates
func (s *IoTMonitoringServer) BulkUpdateDevices(stream monitoringpb.IoTMonitoringService_BulkUpdateDevicesServer) error {
	var totalProcessed, successful, failed int32
	var errors []string
	var successfulDevices []string

	for {
		req, err := stream.Recv()
		if err != nil {
			break
		}

		totalProcessed++

		// Simulate device update
		s.mutex.Lock()
		device, exists := s.devices[req.DeviceId]
		if exists {
			device.UpdatedAt = timestamppb.New(time.Now())
			successful++
			successfulDevices = append(successfulDevices, req.DeviceId)
		} else {
			failed++
			errors = append(errors, fmt.Sprintf("Device %s not found", req.DeviceId))
		}
		s.mutex.Unlock()
	}

	response := &monitoringpb.BulkUpdateDevicesResponse{
		TotalProcessed:    totalProcessed,
		Successful:        successful,
		Failed:            failed,
		Errors:            errors,
		SuccessfulDevices: successfulDevices,
	}

	return stream.SendAndClose(response)
}

// MonitorDevices provides bidirectional streaming for device monitoring and control
func (s *IoTMonitoringServer) MonitorDevices(stream monitoringpb.IoTMonitoringService_MonitorDevicesServer) error {
	monitoringID := fmt.Sprintf("monitor_%d", time.Now().Unix())
	telemetryChan := make(chan *monitoringpb.DeviceTelemetry, 100)
	s.mutex.Lock()
	s.monitoring[monitoringID] = telemetryChan
	s.mutex.Unlock()

	defer func() {
		s.mutex.Lock()
		delete(s.monitoring, monitoringID)
		s.mutex.Unlock()
		close(telemetryChan)
	}()

	// Start telemetry generation goroutine
	go func() {
		ticker := time.NewTicker(2 * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				// Generate telemetry for all devices
				s.mutex.RLock()
				for deviceID, device := range s.devices {
					telemetry := &monitoringpb.DeviceTelemetry{
						DeviceId:  deviceID,
						Timestamp: timestamppb.New(time.Now()),
						Status:    device.Status,
						Message:   fmt.Sprintf("Device %s telemetry update", deviceID),
						Telemetry: &monitoringpb.TelemetryData{
							Temperature:    22.5 + float64(time.Now().Unix()%10),
							Humidity:       45.0 + float64(time.Now().Unix()%15),
							Pressure:       1013.25 + float64(time.Now().Unix()%5),
							Voltage:        12.0 + float64(time.Now().Unix()%2),
							Current:        0.5 + float64(time.Now().Unix()%1)/10,
							SignalStrength: -50 + int32(time.Now().Unix()%20),
							BatteryLevel:   85 + int32(time.Now().Unix()%15),
							CustomMetrics: map[string]float64{
								"cpu_usage":    15.0 + float64(time.Now().Unix()%10),
								"memory_usage": 45.0 + float64(time.Now().Unix()%20),
							},
						},
					}

					select {
					case telemetryChan <- telemetry:
					default:
						// Channel full, skip this update
					}
				}
				s.mutex.RUnlock()
			}
		}
	}()

	// Handle incoming commands and send telemetry
	for {
		command, err := stream.Recv()
		if err != nil {
			if err == io.EOF {
				return nil
			}
			return err
		}

		// Process command
		response := &monitoringpb.DeviceTelemetry{
			DeviceId:  command.DeviceId,
			RequestId: command.RequestId,
			Timestamp: timestamppb.New(time.Now()),
			Message:   fmt.Sprintf("Command %s processed for device %s", command.CommandType, command.DeviceId),
			Status:    monitoringpb.DeviceStatus_DEVICE_STATUS_ONLINE,
			Telemetry: &monitoringpb.TelemetryData{
				Temperature:    22.5,
				Humidity:       45.0,
				Pressure:       1013.25,
				Voltage:        12.0,
				Current:        0.5,
				SignalStrength: -50,
				BatteryLevel:   85,
			},
		}

		if err := stream.Send(response); err != nil {
			return err
		}
	}
}

func main() {
	// Create listener
	lis, err := net.Listen("tcp", ":50052")
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	// Create gRPC server
	s := grpc.NewServer()

	// Register services
	monitoringServer := NewIoTMonitoringServer()
	monitoringpb.RegisterIoTMonitoringServiceServer(s, monitoringServer)
	reflection.Register(s)

	fmt.Println("🔌 IoT Monitoring Service is running on port 50052...")
	fmt.Println("Available methods:")
	fmt.Println("  - RegisterDevice, GetDevice, UpdateDeviceStatus, GetDeviceMetrics")
	fmt.Println("  - StreamDeviceStatus, BulkUpdateDevices, MonitorDevices")
	fmt.Println("  - HealthCheck")

	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
