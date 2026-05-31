package server

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"time"
	"timekeeping/commons"
	"timekeeping/config"

	"github.com/gin-gonic/gin"
)

type Server struct {
	ethereumService commons.IEthereumService
	router          *gin.Engine
}

func NewServer() *Server {
	router := gin.Default()

	return &Server{
		router:          router,
		ethereumService: commons.NewEthereumService(),
	}
}

func (s *Server) Run() error {
	s.InitRouter()

	err := s.ethereumService.Connect(config.Env.NETWORK_URL, config.Env.CONTRACT_ABI)
	if err != nil {
		return err
	}
	server := &http.Server{
		Addr:    ":" + config.Env.PORT,
		Handler: s.router,
	}

	go func() {
		log.Printf("Server is running on %s\n", server.Addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %s\n", err.Error())
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt)
	<-quit

	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server shutdown error: %s\n", err.Error())
	}

	log.Println("Server gracefully stopped")

	return nil
}
