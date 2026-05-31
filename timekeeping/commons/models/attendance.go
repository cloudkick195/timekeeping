package models

import (
	"crypto/ecdsa"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
)

type Attendance struct {
	EmployeeId          *big.Int
	RequiredCheckInTime *big.Int
	CheckInTime         *big.Int
	CheckOutTime        *big.Int
}

type FromAddress struct {
	PrivateKey *ecdsa.PrivateKey
	Address    common.Address
}
