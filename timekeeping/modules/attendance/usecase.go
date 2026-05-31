package attendance

import (
	"context"
	"math/big"
	"timekeeping/commons"
	"timekeeping/commons/models"
	"timekeeping/config"
	"timekeeping/utils"
)

type IUsecase interface {
	Create(ctx context.Context, input *CreateInput) (*DeployOutput, error)
	Update(ctx context.Context, input *CreateInput) (*DeployOutput, error)
	Deploy(ctx context.Context) (*DeployOutput, error)
	Get(ctx context.Context, input *FilterInput) (interface{}, error)
}

type Usecase struct {
	ethereumService commons.IEthereumService
}

func NewUsecase(ethereumService commons.IEthereumService) IUsecase {
	return &Usecase{
		ethereumService: ethereumService,
	}
}

func (a *Usecase) Get(ctx context.Context, input *FilterInput) (interface{}, error) {
	fromAddress, err := utils.ConvertPrivateKeyToAddress(config.Env.PRIVATE_KEY)
	if err != nil {
		return nil, commons.ErrInternal(err)
	}

	return a.ethereumService.GetAttendance(ctx, fromAddress, &commons.FilterAttendance{
		EmployeeId: big.NewInt(*input.EmployeeId),
		StartDate:  big.NewInt(*input.StartDate),
		EndDate:    big.NewInt(*input.EndDate),
	})
}

func (a *Usecase) Create(ctx context.Context, input *CreateInput) (*DeployOutput, error) {
	fromAddress, err := utils.ConvertPrivateKeyToAddress(config.Env.PRIVATE_KEY)
	if err != nil {
		return nil, commons.ErrInternal(err)
	}

	result, err := a.ethereumService.ChangeNode(ctx, fromAddress, &models.Attendance{
		EmployeeId: big.NewInt(*input.EmployeeId),
	}, "checkin")

	if err != nil {
		return nil, commons.ErrInternal(err)
	}

	return &DeployOutput{
		ContractAddress: "",
		TransactionHash: result.Hash().Hex(),
	}, nil
}

func (a *Usecase) Update(ctx context.Context, input *CreateInput) (*DeployOutput, error) {
	fromAddress, err := utils.ConvertPrivateKeyToAddress(config.Env.PRIVATE_KEY)
	if err != nil {
		return nil, commons.ErrInternal(err)
	}

	result, err := a.ethereumService.ChangeNode(ctx, fromAddress, &models.Attendance{
		EmployeeId: big.NewInt(*input.EmployeeId),
	}, "checkout")

	if err != nil {
		return nil, commons.ErrInternal(err)
	}

	return &DeployOutput{
		ContractAddress: "",
		TransactionHash: result.Hash().Hex(),
	}, nil
}

func (a *Usecase) Deploy(ctx context.Context) (*DeployOutput, error) {
	fromAddress, err := utils.ConvertPrivateKeyToAddress(config.Env.PRIVATE_KEY)
	if err != nil {
		return nil, commons.ErrInternal(err)
	}

	// Nonce là số thứ tự của giao dịch, bạn có thể lấy từ blockchain hoặc tự tạo
	contractAddress, tx, err := a.ethereumService.Deploy(ctx, fromAddress)
	if err != nil {
		return nil, commons.ErrInternal(err)
	}

	return &DeployOutput{
		ContractAddress: contractAddress.Hex(),
		TransactionHash: tx.Hash().Hex(),
	}, nil
}
