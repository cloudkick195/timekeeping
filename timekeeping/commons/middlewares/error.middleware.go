package middlewares

import (
	"bytes"
	"io"
	"timekeeping/commons"

	"github.com/gin-gonic/gin"
)

func (m *middlewareManager) ErrorMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		reqStream, _ := c.GetRawData()
		c.Request.Body = io.NopCloser(bytes.NewBuffer(reqStream))

		defer func() {
			if err := recover(); err != nil {
				var appErr *commons.AppError
				if errConvert, ok := err.(*commons.AppError); ok {
					appErr = errConvert
				} else {
					appErr = commons.ErrInternal(err.(error))
				}

				c.AbortWithStatusJSON(appErr.StatusCode, map[string]interface{}{
					"StatusCode": appErr.StatusCode,
					"Message":    appErr.Message,
					"Key":        appErr.Key,
				})
				return
			}
		}()
		c.Next()
	}
}
