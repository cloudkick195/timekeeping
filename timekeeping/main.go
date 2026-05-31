package main

import (
	"log"
	"timekeeping/config"
	_ "timekeeping/docs"
	"timekeeping/server"
)

// @title timekeeping
// @version 1.0
// @description timekeeping
// @BasePath /api/v1
func main() {
	config.InitConfig()
	server.NewServer()
	s := server.NewServer()
	if err := s.Run(); err != nil {
		log.Fatal(err)
	}
}
