package main

import (
	"fmt"
	"log"
	"net"
	"strings"

	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"

	"github.com/gripmock/grpctestify/client-server/examplepb"
)

type server struct {
	examplepb.UnimplementedExampleServiceServer
}

func (s *server) ClientStream(stream examplepb.ExampleService_ClientStreamServer) error {
	result := make([]string, 0)
	for {
		msg, err := stream.Recv()
		if err != nil {
			break
		}
		result = append(result, msg.Text)
	}

	return stream.SendAndClose(&examplepb.Response{Result: strings.Join(result, " ")})
}

func (s *server) ServerStream(req *examplepb.Message, stream examplepb.ExampleService_ServerStreamServer) error {
	words := strings.Split(req.Text, " ")
	for _, word := range words {
		if err := stream.Send(&examplepb.Response{Result: word}); err != nil {
			return err
		}
	}

	return nil
}

func (s *server) BidiStream(stream examplepb.ExampleService_BidiStreamServer) error {
	for {
		req, err := stream.Recv()
		if err != nil {
			break
		}
		words := strings.Split(req.Text, " ")
		for _, word := range words {
			if err := stream.Send(&examplepb.Response{Result: word}); err != nil {
				return err
			}
		}
	}

	return nil
}

func main() {
	lis, err := net.Listen("tcp", ":50051")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	s := grpc.NewServer()

	examplepb.RegisterExampleServiceServer(s, &server{})

	reflection.Register(s)

	fmt.Println("Server is running on port 50051...")

	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
