package attendance

import (
	"timekeeping/commons/middlewares"

	"github.com/gin-gonic/gin"
)

type API struct{ Handler IHandler }

// Map auth routes
func (a *API) PublicRoutes(router *gin.RouterGroup, mw middlewares.IMiddlewareManager) {
	h := a.Handler
	router.Group("/attendance").
		GET("/", h.Get()).
		POST("/", h.Create()).
		PUT("/", h.Update()).
		GET("/deploy", h.Deploy())
}
