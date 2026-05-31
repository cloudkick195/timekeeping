package commons

import (
	"errors"
	"fmt"
	"net/http"
	"strings"
)

type AppError struct {
	StatusCode int    `json:"status_code"`
	RootErr    error  `json:"-"`
	Message    string `json:"message"`
	Log        string `json:"log"`
	Key        string `json:"key"`
}

func NewErrorResponse(root error, msg, log, key string) *AppError {
	return &AppError{
		StatusCode: http.StatusBadRequest,
		RootErr:    root,
		Message:    msg,
		Log:        log,
		Key:        key,
	}
}

func NewFullErrorResponse(statusCode int, root error, msg, log, key string) *AppError {
	return &AppError{
		StatusCode: statusCode,
		RootErr:    root,
		Message:    msg,
		Log:        log,
		Key:        key,
	}
}

func NewErrIpPermission(root error, msg, log, key string) *AppError {
	return &AppError{
		StatusCode: http.StatusUnauthorized,
		RootErr:    root,
		Message:    msg,
		Log:        log,
		Key:        key,
	}
}

func NewUnAuthorized(msg string) *AppError {
	msgErr := errors.New(strings.ToLower(msg))
	return &AppError{
		StatusCode: http.StatusUnauthorized,
		RootErr:    msgErr,
		Message:    msg,
		Log:        msgErr.Error(),
		Key:        "UnAuthorized",
	}
}

func ErrorUnAuthorized() *AppError {
	errCreated := errors.New("UnAuthorized")
	return &AppError{
		StatusCode: http.StatusUnauthorized,
		RootErr:    errCreated,
		Message:    errCreated.Error(),
		Log:        errCreated.Error(),
		Key:        "UnAuthorized",
	}
}

func NewCustomError(root error, msg, key string) *AppError {
	if root != nil {
		return NewErrorResponse(root, msg, root.Error(), key)
	}

	return NewErrorResponse(errors.New(msg), msg, msg, key)
}

func NewMissingFieldError(field string) *AppError {
	textErrr := fmt.Sprintf("Missing %s", field)
	return NewCustomError(nil, textErrr, fmt.Sprintf("Missing%s", field))
}

func (e *AppError) RootError() error {
	if err, ok := e.RootErr.(*AppError); ok {
		return err.RootError()
	}

	return e.RootErr
}

func (e *AppError) Error() string {
	return e.RootError().Error()
}

func ErrDB(err error) *AppError {
	return NewFullErrorResponse(http.StatusInternalServerError, err, "something went wrong with the database", err.Error(), "DB_ERROR")
}

func ErrInvalidRequest(err error) *AppError {
	return NewErrorResponse(err, "invalid request", err.Error(), "ErrInvalidRequest")
}

func ErrInternal(err error) *AppError {
	return NewFullErrorResponse(http.StatusInternalServerError, err, err.Error(), err.Error(), "ErrInternal")
}

func ErrCannotListEntry(entity string, err error) *AppError {
	return NewCustomError(err, fmt.Sprintf("Cannot list %s", strings.ToLower(entity)), fmt.Sprintf("ErrCannotListEntry%s", entity))
}
