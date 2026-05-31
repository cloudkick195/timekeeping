package server

import (
	"net/http"
	"timekeeping/commons/middlewares"

	"timekeeping/modules/attendance"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

type IPublicApi interface {
	PublicRoutes(router *gin.RouterGroup, mw middlewares.IMiddlewareManager)
}

func (s *Server) InitRouter() {
	routerDefault := s.router

	routerDefault.NoRoute(func(c *gin.Context) {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "API endpoint not found",
		})
	})
	router := routerDefault.Group("/api/v1")
	router.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "Welcome to my API!",
		})
	})

	//Usecase

	middlewareManager := middlewares.NewMiddlewareManager()

	attendanceUsecase := attendance.NewUsecase(s.ethereumService)

	attendanceHandler := attendance.NewHandler(attendanceUsecase, middlewareManager)

	router.Use(middlewareManager.ErrorMiddleware())
	//admin group

	authApis := []IPublicApi{
		&attendance.API{Handler: attendanceHandler},
	}
	for _, a := range authApis {
		a.PublicRoutes(router, middlewareManager)
	}
}
