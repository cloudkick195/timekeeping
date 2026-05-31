package attendance

type CreateInput struct {
	EmployeeId *int64 `json:"employeeId"`
}
type GetAttendanceRecordsInput struct {
	EmployeeId *int64 `form:"employeeId"`
	StartDate  *int64 `form:"startDate"`
	EndDate    *int64 `form:"endDate"`
}

type DeployOutput struct {
	ContractAddress string
	TransactionHash string
}

type FilterInput struct {
	EmployeeId *int64 `form:"employeeId"`
	StartDate  *int64 `form:"startDate"`
	EndDate    *int64 `form:"endDate"`
}
