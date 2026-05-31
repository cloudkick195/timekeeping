package attendance

import (
	"net/http"

	"timekeeping/commons"
	"timekeeping/commons/middlewares"

	"github.com/gin-gonic/gin"
)

type IHandler interface {
	Create() gin.HandlerFunc
	Update() gin.HandlerFunc
	Deploy() gin.HandlerFunc
	Get() gin.HandlerFunc
}

type handler struct {
	Usecase IUsecase
	mw      middlewares.IMiddlewareManager
}

func NewHandler(Usecase IUsecase, mw middlewares.IMiddlewareManager) IHandler {
	return &handler{
		Usecase: Usecase,
		mw:      mw,
	}
}

// @Summary Get attendance records
// @Description Get attendance records based on filter criteria
// @Tags Attendance
// @Accept json
// @Produce json
// @Param employeeId query string false "Employee ID"
// @Param startDate query string false "Start date (Unix timestamp)"
// @Param endDate query string false "End date (Unix timestamp)"
// @Success 200 {object} interface{} "Success response"
// @Router /attendance [get]
func (h *handler) Get() gin.HandlerFunc {
	return func(c *gin.Context) {
		var input *FilterInput
		if err := c.ShouldBindQuery(&input); err != nil {
			panic(commons.ErrInvalidRequest(err))
		}

		output, err := h.Usecase.Get(c, input)
		if err != nil {
			panic(err)
		}

		c.JSON(http.StatusOK, commons.SimpleSuccessResponse(output))
	}
}

// @Summary Create attendance record
// @Description Create a new attendance record
// @Tags Attendance
// @Accept json
// @Produce json
// @Param attendance body CreateInput true "Create attendance input"
// @Success 200 {object} interface{} "Success response"
// @Router /attendance [post]
func (h *handler) Create() gin.HandlerFunc {
	return func(c *gin.Context) {
		var input *CreateInput
		if err := c.ShouldBindJSON(&input); err != nil {
			panic(err)
		}

		output, err := h.Usecase.Create(c, input)
		if err != nil {
			panic(err)
		}

		c.JSON(http.StatusOK, commons.SimpleSuccessResponse(output))
	}
}

// @Summary Update attendance record
// @Description Update an existing attendance record
// @Tags Attendance
// @Accept json
// @Produce json
// @Param input body CreateInput true "Update attendance input"
// @Success 200 {object} interface{} "Success response"
// @Router /attendance [put]
func (h *handler) Update() gin.HandlerFunc {
	return func(c *gin.Context) {
		var input *CreateInput
		if err := c.ShouldBindJSON(&input); err != nil {
			panic(err)
		}

		output, err := h.Usecase.Update(c, input)
		if err != nil {
			panic(err)
		}

		c.JSON(http.StatusOK, commons.SimpleSuccessResponse(output))
	}
}

// @Summary Deploy attendance contract
// @Description Deploy the attendance contract
// @Tags Attendance
// @Accept json
// @Produce json
// @Success 200 {object} DeployOutput "Deploy output"
// @Router /attendance/deploy [post]
func (h *handler) Deploy() gin.HandlerFunc {
	return func(c *gin.Context) {
		output, err := h.Usecase.Deploy(c)
		if err != nil {
			panic(err)
		}

		c.JSON(http.StatusOK, commons.SimpleSuccessResponse(output))
	}
}
