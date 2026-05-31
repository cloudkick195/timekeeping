package attendance

import (
	"errors"
	"timekeeping/commons"
)

var (
	ErrNotFound = commons.NewCustomError(
		errors.New("ErrNotFound"),
		"ErrNotFound",
		"ErrNotFound",
	)
	ErrIdOrPasswordInvalid = commons.NewCustomError(
		errors.New("id or password invalid"),
		"id or password invalid",
		"ErrIdOrPasswordInvalid",
	)
	ErrEmailExisted = commons.NewCustomError(
		errors.New("email existed"),
		"Email Existed",
		"ErrEmailExisted",
	)
	ErrIdExisted = commons.NewCustomError(
		errors.New("id existed"),
		"Id Existed",
		"ErrIdExisted",
	)
	ErrAmount = commons.NewCustomError(
		errors.New("ErrAmount"),
		"ErrAmount",
		"ErrAmount",
	)
	ErrReferralCode = commons.NewCustomError(
		errors.New("ErrReferralCode"),
		"ErrReferralCode",
		"ErrReferralCode",
	)
	ErrattendanceBlocked = commons.NewCustomError(
		errors.New("ErrattendanceBlocked"),
		"ErrattendanceBlocked",
		"ErrattendanceBlocked",
	)
)
