package middlewares

import (
	"github.com/gin-gonic/gin"
)

type IMiddlewareManager interface {
	ErrorMiddleware() gin.HandlerFunc
}

type middlewareManager struct {
}

func NewMiddlewareManager() IMiddlewareManager {
	return &middlewareManager{}
}
