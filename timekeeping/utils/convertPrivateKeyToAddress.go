package utils

import (
	"crypto/ecdsa"
	"errors"
	"timekeeping/commons/models"

	"github.com/ethereum/go-ethereum/crypto"
)

func ConvertPrivateKeyToAddress(privateKeyStr string) (*models.FromAddress, error) {
	// Tạo một key private để ký giao dịch
	privateKey, err := crypto.HexToECDSA(privateKeyStr)
	if err != nil {
		return nil, err
	}

	// Lấy địa chỉ từ private key
	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		return nil, errors.New("Cannot derive public key")
	}
	address := crypto.PubkeyToAddress(*publicKeyECDSA)
	return &models.FromAddress{
		PrivateKey: privateKey,
		Address:    address,
	}, nil
}
