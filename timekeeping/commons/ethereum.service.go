package commons

import (
	"context"
	"errors"
	"math/big"
	"strings"
	"timekeeping/commons/models"
	"timekeeping/config"
	"timekeeping/utils"

	goEthereum "github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
)

type IEthereumService interface {
	Connect(connectStr string, contractABI string) error
	ChangeNode(ctx context.Context, fromAddress *models.FromAddress, input *models.Attendance, method string) (*types.Transaction, error)
	Deploy(ctx context.Context, fromAddress *models.FromAddress) (*common.Address, *types.Transaction, error)
	CreateTransactOpts(ctx context.Context, fromAddress *models.FromAddress) (*bind.TransactOpts, error)
	GetAttendance(ctx context.Context, fromAddress *models.FromAddress, input *FilterAttendance) ([]models.Attendance, error)
}

type ethereumService struct {
	Client *ethclient.Client
	ABI    abi.ABI
}

type FilterAttendance struct {
	EmployeeId *big.Int `json:"employeeId"`
	StartDate  *big.Int `json:"startDate"`
	EndDate    *big.Int `json:"endDate"`
}

func NewEthereumService() IEthereumService {
	return &ethereumService{}
}

// Hàm này được sử dụng để kết nối với một node Ethereum và đọc thông tin của smartcontract.
func (e *ethereumService) Connect(connectStr string, contractABI string) error {
	// Tạo kết nối với node Ethereum
	client, err := ethclient.Dial(connectStr)
	if err != nil {
		return err
	}
	// Phân tích cú pháp ABI
	parsedABI, err := abi.JSON(strings.NewReader(contractABI))
	if err != nil {
		return err
	}
	e.Client = client
	e.ABI = parsedABI
	return nil
}

// Hàm này được sử dụng để lấy checkin theo EmployeeId hoặc time range.
func (e *ethereumService) GetAttendance(ctx context.Context, fromAddress *models.FromAddress, input *FilterAttendance) ([]models.Attendance, error) {
	var data []byte
	var err error
	// ABI.Pack để gọi truyền các params mà hàm trong contract cần
	if input.EmployeeId != nil {
		data, err = e.ABI.Pack("getAttendanceByEmployee", input.EmployeeId)
	} else if input.StartDate != nil && input.EndDate != nil {
		data, err = e.ABI.Pack("getAttendanceByDateRange", input.StartDate, input.EndDate)
	}

	if err != nil {
		return nil, err
	}
	return e.getAttendance(ctx, fromAddress, data)
}

func (e *ethereumService) getAttendance(ctx context.Context, fromAddress *models.FromAddress, data []byte) ([]models.Attendance, error) {
	// value cần truyền cho CallMsg
	value := big.NewInt(0)

	// truyền address của địa chỉ gửi
	from := fromAddress.Address

	// smart contract được deploy
	contract := common.HexToAddress(config.Env.CONTRACT_CREATION)
	msg := goEthereum.CallMsg{From: from, To: &contract, Value: value, Data: data}

	// gọi smart contract
	resultContract, err := e.Client.CallContract(ctx, msg, nil)
	if err != nil {
		return nil, err
	}

	var resultAttendance []models.Attendance

	// mapping các data trả về từ smartcontract
	err = e.ABI.UnpackIntoInterface(&resultAttendance, "getAttendanceByEmployee", resultContract)
	if err != nil {
		return nil, err
	}

	return resultAttendance, nil
}

func (e *ethereumService) ChangeNode(ctx context.Context, fromAddress *models.FromAddress, input *models.Attendance, method string) (*types.Transaction, error) {
	auth, err := e.CreateTransactOpts(ctx, fromAddress)

	if err != nil {
		return nil, err
	}

	// truyền các params cho các hàm của contract
	data, err := e.ABI.Pack(method, input.EmployeeId)
	if err != nil {
		return nil, err
	}
	nonce := auth.Nonce

	// gửi transaction cho contract từ address
	tx := types.NewTransaction(nonce.Uint64(), common.HexToAddress(config.Env.CONTRACT_CREATION), auth.Value, auth.GasLimit, auth.GasPrice, data)
	if tx == nil {
		return nil, errors.New("cannot newTransaction")
	}

	// xác nhận sign để thực hiện giao dịch
	txSign, err := auth.Signer(fromAddress.Address, tx)
	if err != nil {
		return nil, err
	}

	// gửi transaction
	err = e.Client.SendTransaction(ctx, txSign)
	if err != nil {
		return nil, err
	}
	return txSign, nil
}

// hàm tạo transaction, một transaction cần nonce, gas limit, và sign của address gửi
func (e *ethereumService) CreateTransactOpts(ctx context.Context, fromAddress *models.FromAddress) (*bind.TransactOpts, error) {
	nonce, err := e.Client.PendingNonceAt(ctx, fromAddress.Address)
	if err != nil {
		return nil, err
	}

	// check gas price
	gasPrice, err := e.Client.SuggestGasPrice(ctx)
	if err != nil {
		return nil, err
	}

	chainID, err := e.Client.ChainID(ctx)
	if err != nil {
		return nil, err
	}

	// sign cho address từ privatekey của ví
	auth, err := bind.NewKeyedTransactorWithChainID(fromAddress.PrivateKey, chainID)
	if err != nil {
		return nil, err
	}
	auth.Nonce = big.NewInt(int64(nonce))
	auth.Value = big.NewInt(0)
	auth.GasLimit = uint64(5000000) // Giới hạn gas tùy chỉnh
	auth.GasPrice = gasPrice

	return auth, nil
}

func (e *ethereumService) Deploy(ctx context.Context, fromAddress *models.FromAddress) (*common.Address, *types.Transaction, error) {
	auth, err := e.CreateTransactOpts(ctx, fromAddress)
	if err != nil {
		return nil, nil, err
	}
	byteCodeStr, err := utils.ConvertSolToByteCode(config.Env.SOL_BUILD_FILE)
	if err != nil {
		return nil, nil, err
	}
	// Triển khai smart contract
	bytecode := common.FromHex(*byteCodeStr)

	// deploy smartcontract lên network
	contractAddress, tx, _, err := bind.DeployContract(auth, e.ABI, bytecode, e.Client)
	if err != nil {
		return nil, nil, err
	}
	return &contractAddress, tx, err
}
