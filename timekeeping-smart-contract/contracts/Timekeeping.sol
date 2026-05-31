// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import "@openzeppelin/contracts@v4.9.0/access/AccessControl.sol";
import "@openzeppelin/contracts@v4.9.0/utils/Strings.sol";
import "./constant.sol";
import "./model.sol";
import "./interfaces/INoti.sol";
import "./interfaces/ITimekeeping.sol";

import "./lib/ConvertTime.sol";
import "./lib/UtilsLibrary.sol";

import "hardhat/console.sol";

contract Timekeeping is AccessControl {
    using DateTimeLibrary for uint;
    uint FIXED_NUMBER = 1000 * 1000;
    bytes32 public constant ROLE_HASH_DEPLOYER =
        keccak256("ROLE_HASH_DEPLOYER");
    bytes32 public constant ROLE_HASH_ROOT = keccak256("ROLE_HASH_ROOT");
    bytes32 public constant ROLE_HASH_HR_MANAGER =
        keccak256("ROLE_HASH_HR_MANAGER");
    bytes32 public constant ROLE_HASH_HR = keccak256("ROLE_HASH_HR");
    bytes32 public constant ROLE_HASH_ACCOUNTANT =
        keccak256("ROLE_HASH_ACCOUNTANT");
    bytes32 public constant ROLE_HASH_EMPLOYEE =
        keccak256("ROLE_HASH_EMPLOYEE");

    /** Attendance Management */

    //ShiftManagement public DEFAULT_SHIFT_MANAGERMENT;

    mapping(uint => AvgInOutForYM) public mAvgInOutForYM;
    mapping(uint => mapping(address => TimeKeepingSummaryPerMonth))
        public mTotalTimeKeepingForYM; // yyyymm => address => total time keeping
    Attendance[] public attendances;
    mapping(address => mapping(uint => uint256[]))
        public mAddressYYYYMMDDToAttendance;
    mapping(uint => uint256[]) public mYYYYMMDDToAttendance;
    uint[] public inOutOnBehalfAttendances; // mapping yyyymmdd => idx of attendances

    ShiftManagement[] public shiftManagements; // ShiftManagement

    mapping(uint => mapping(address => mapping(uint => uint256))) // Mapping yyyymmdd => employee => shift
        public mShiftManagement;

    mapping(uint => mapping(address => uint[])) public mAttendanceOvertime; // Mapping yyyymm => address => Attendance
    mapping(uint => mapping(uint => bool)) mFinalShift;

    /**
        Employee Management

        For employee management each employee will break to 2 struct.
            1. Employee: Overview information
            2. EmployeeDetail: Detail information
    */

    // The unique employee address has been imported/added to Timekeeping
    address[] public employees;

    mapping(address => Employee) public mEmployees;
    mapping(address => EmployeeDetail) private mEmployeeDetails;

    /**
        Active
            If the employee login successfully using the REF CODE, the active status is set TRUE; 
            otherwise, it is set to FALSE.
        
            For employees with the roles of ROOT, HR Manager, HR, Accountant, the default active stauts is TRUE
    */
    mapping(address => bool) public mActiveEmployee;
    
    // ========================= END Employee Management =========================


    /**
        ID Management

        The ID used by employees to share with third parties for obtaining data about their salary or attendance.
     */
    uint seedViewID;
    mapping(bytes32 => ViewID) mBytes32ToViewId;
    mapping(address => bytes32[]) mAddressToViewIDs;

    // ========================= END ID Management =========================

    // Define Notification
    string constant REPO = "TIMEKEEPING";
    INoti public notiSMC;
    event eNotificationSMC(string message);
    event eSendNotificationToAddress(
        address _toAddress,
        Notification _notification,
        bool result
    );
    event eSendNotificationToMultipleAddress(
        address[] _toAddresses,
        Notification _notification,
        bool result
    );

    address public ROOT_ADDRESS;

    //refcode
    bytes32 public constant DEFAULT_REF_CODE = 0x00;

    mapping(address => bytes32) public mRefCode;

    //RequestManagement
    Request[] public requests;
    uint256[] public requestIdxForHRs;

    mapping(uint => uint) public mRequestIdToDetailId;
    mapping(address => mapping(REQUEST_TYPE => uint256[]))
        public mAddressRequestTypeToIndex;
    mapping(REQUEST_TYPE => uint256[]) public mRequestTypeToIndex;
    LeaveRequest[] public leaveRequests;
    LateRequest[] public lateRequests;
    ComeBackSoonRequest[] public comeBackSoonRequests;
    OfferSalaryRequest[] public offerSalaryRequests;
    mapping(address => uint[]) public mOfferSalaryRequest; // address => requestId[];
    SubsidizeRequest[] public subsidizeRequests;
    mapping(address => uint[]) public mSubsidizeRequest; // mapping address => requestId[]
    ResignRequest[] public resignRequests;
    SalaryDeducationRequest[] public salaryDeducationRequests;
    mapping(address => mapping(uint => uint[]))
        public mSalaryDeducationRequestByYM;
    InOutOnBeHalfRequest[] public inOutOnBeHalfRequests;
    RuleRequest[] public ruleRequests;
    mapping(uint => HANDLE_CASE_STATUS) mHandleCaseStatus;

    //Salary
    Salary[] public salaries;
    mapping(address => SalaryRequest) public mSalaryRequest;
    mapping(address => mapping(uint => uint[][])) public mSalary; // address => YYYYMM => [key => day - 1][shiftid - 1]salaryId
    mapping(address => mapping(uint => uint)) public mTotalSalaryEmployee;
    mapping(address => Subsidize[]) public mSubsidize;
    mapping(address => mapping(uint => SalaryDeducation[]))
        public mSalaryDeducation; // address => YYYYMM=>SalaryDeducation

    mapping(address => mapping(uint => OTSalary[])) public mOTSalary; //address => YYYYMM => [key => day - 1]

    //SettingManagement

    SettingRule[] public settingRules;
    Shift public SHIFT_EMPTY;
    DayOff public DAYOFF_EMPTY;
    SettingTime public settingTime;
    SettingAddress public settingAddress;
    mapping(address => ATTENDANCE_LIMIT_TYPE) public mSettingAttendanceLimit;

    constructor() payable {
        _initRole(msg.sender);
    }

    /** AttendanceManagement */

    function _createAttendance(
        Attendance memory _attendance
    ) internal returns (Attendance memory) {
        _attendance.AttendanceId = attendances.length + 1;
        _attendance.LastUpdate = block.timestamp;

        attendances.push(_attendance);
        mAddressYYYYMMDDToAttendance[_attendance.Employee][_attendance.YYYYMMDD]
            .push(attendances.length);
        mYYYYMMDDToAttendance[_attendance.YYYYMMDD].push(attendances.length);

        if (
            _attendance.Type == ATTENDANCE_TYPE.CHECK_IN_ON_BEHALF ||
            _attendance.Type == ATTENDANCE_TYPE.CHECK_OUT_ON_BEHALF
        ) {
            inOutOnBehalfAttendances.push(_attendance.AttendanceId);
        }

        return attendances[attendances.length - 1];
    }

    function _getAttendanceForEmployee(
        address _employee,
        uint _yyyymmdd
    ) internal view returns (Attendance[] memory) {
        uint256[] memory recordIdxs = mAddressYYYYMMDDToAttendance[_employee][
            _yyyymmdd
        ];
        Attendance[] memory records = new Attendance[](recordIdxs.length);

        for (uint i = 0; i < recordIdxs.length; i++) {
            records[i] = attendances[recordIdxs[i] - 1];
        }

        return records;
    }

    function _getAttendanceById(
        uint _attendanceId
    ) internal view returns (Attendance memory) {
        return attendances[_attendanceId - 1];
    }

    function _initShiftManagement(
        uint _yyyymmdd,
        address _employee,
        uint _shiftId
    ) internal returns (ShiftManagement memory) {
        shiftManagements.push(
            ShiftManagement({
                ShiftManagementId: shiftManagements.length + 1,
                YYYYMMDD: _yyyymmdd,
                Employee: _employee,
                ShiftId: _shiftId,
                CheckInTime: 0,
                CheckOutTime: 0,
                ShiftStatus: SHIFT_STATUS.LEAVE,
                LatePermissionApproval: 0,
                LatePermissionStatus: PERMISSION_STATUS.NO_PERMISSION,
                ComeBackSoonApproval: 24 * 3600 - 1,
                ComeBackSoonPermissionStatus: PERMISSION_STATUS.NO_PERMISSION,
                LeavePermissionStatus: PERMISSION_STATUS.NO_PERMISSION
            })
        );

        mShiftManagement[_yyyymmdd][_employee][_shiftId] = shiftManagements
            .length;

        return shiftManagements[shiftManagements.length - 1];
    }

    function _getShiftManagementById(
        uint shiftManagementId
    ) internal view returns (ShiftManagement memory) {
        return shiftManagements[shiftManagementId - 1];
    }

    function _getShiftManagement(
        uint _yyyymmdd,
        address _employee,
        uint _shiftId
    ) internal returns (ShiftManagement memory) {
        uint idx = mShiftManagement[_yyyymmdd][_employee][_shiftId];

        if (idx == 0) {
            return _initShiftManagement(_yyyymmdd, _employee, _shiftId);
        }
        return shiftManagements[idx - 1];
    }

    function _updateShiftManagementAfterCheckin(
        uint _yyyymmdd,
        address _employee,
        Shift memory _shift,
        uint _checkInTime
    ) internal {
        ShiftManagement memory current = _getShiftManagement(
            _yyyymmdd,
            _employee,
            _shift.ShiftId
        );

        shiftManagements[current.ShiftManagementId - 1]
            .CheckInTime = _checkInTime;

        if (_checkInTime <= _shift.CheckIn) {
            shiftManagements[current.ShiftManagementId - 1]
                .ShiftStatus = SHIFT_STATUS.ON_SCHEDULE;
            shiftManagements[current.ShiftManagementId - 1]
                .LatePermissionApproval = 0;
            shiftManagements[current.ShiftManagementId - 1]
                .LeavePermissionStatus = PERMISSION_STATUS.NONE;
            shiftManagements[current.ShiftManagementId - 1]
                .LatePermissionStatus = PERMISSION_STATUS.NONE;
        } else {
            mTotalTimeKeepingForYM[_yyyymmdd / 100][_employee]
                .TotalLateInSecond += _checkInTime - _shift.CheckIn;
            mTotalTimeKeepingForYM[_yyyymmdd / 100][_employee].CountLate += 1;

            shiftManagements[current.ShiftManagementId - 1]
                .ShiftStatus = SHIFT_STATUS.LATE;
            if (
                shiftManagements[current.ShiftManagementId - 1]
                    .LatePermissionApproval >=
                shiftManagements[current.ShiftManagementId - 1].CheckInTime &&
                shiftManagements[current.ShiftManagementId - 1]
                    .LatePermissionStatus !=
                PERMISSION_STATUS.PERMISSION
            ) {
                shiftManagements[current.ShiftManagementId - 1]
                    .LatePermissionStatus = PERMISSION_STATUS.PERMISSION;
                mTotalTimeKeepingForYM[_yyyymmdd / 100][_employee]
                    .CountLatePermission += 1;
            }
        }
        uint _yyyymm = _yyyymmdd / 100;
        mAvgInOutForYM[_yyyymm].TotalCheckIn += _checkInTime;
        mAvgInOutForYM[_yyyymm].CountCheckIn += 1;
    }

    function _updateShiftManagementAfterCheckout(
        uint _yyyymmdd,
        address _employee,
        Shift memory _shift,
        uint _checkOutTime
    ) internal {
        ShiftManagement memory current = _getShiftManagement(
            _yyyymmdd,
            _employee,
            _shift.ShiftId
        );
        shiftManagements[current.ShiftManagementId - 1]
            .CheckOutTime = _checkOutTime;

        uint _yyyymm = _yyyymmdd / 100;
        mAvgInOutForYM[_yyyymm].TotalCheckOut += _checkOutTime;
        mAvgInOutForYM[_yyyymm].CountCheckOut += 1;
        mTotalTimeKeepingForYM[_yyyymm][_employee].TotalTimekeepingInSecond +=
            _checkOutTime -
            shiftManagements[current.ShiftManagementId - 1].CheckInTime;
        mTotalTimeKeepingForYM[_yyyymm][_employee].CountTimekeeping += 1;

        // Go home soon
        if (_checkOutTime < _shift.CheckOut) {
            mTotalTimeKeepingForYM[_yyyymm][_employee].CountComeBackSoon += 1;
            mTotalTimeKeepingForYM[_yyyymm][_employee]
                .TotalComeBackSoonInSecond += _shift.CheckOut - _checkOutTime;

            if (
                shiftManagements[current.ShiftManagementId - 1]
                    .ComeBackSoonApproval <=
                _checkOutTime &&
                shiftManagements[current.ShiftManagementId - 1]
                    .ComeBackSoonPermissionStatus !=
                PERMISSION_STATUS.PERMISSION
            ) {
                shiftManagements[current.ShiftManagementId - 1]
                    .ComeBackSoonPermissionStatus = PERMISSION_STATUS
                    .PERMISSION;
                mTotalTimeKeepingForYM[_yyyymmdd / 100][_employee]
                    .CountComeBackSoonPermission += 1;
            }
        }
    }

    function _updateAfterOvertime(
        Attendance memory _attendance,
        Shift memory _lastShift
    ) internal {
        mTotalTimeKeepingForYM[_attendance.YYYYMMDD / 100][_attendance.Employee]
            .TotalOvertimeInSecond += _attendance.Time - _lastShift.CheckOut;
        mAttendanceOvertime[_attendance.YYYYMMDD / 100][_attendance.Employee]
            .push(_attendance.AttendanceId);
    }

    function _getAttendanceOverviewPerMonth(
        uint _yyyymm,
        address _employee
    ) internal view returns (Attendance[] memory) {
        uint[] memory attendanceIdxs = mAttendanceOvertime[_yyyymm][_employee];
        Attendance[] memory attendanceOvertime = new Attendance[](
            attendanceIdxs.length
        );

        for (uint idx = 0; idx < attendanceIdxs.length; idx++) {
            attendanceOvertime[idx] = attendances[attendanceIdxs[idx] - 1];
        }

        return attendanceOvertime;
    }

    function _updateShiftManagementAfterApprovalLeaveRequest(
        uint _yyyymmdd,
        address _employee,
        uint _shiftId
    ) internal {
        ShiftManagement memory curr = _getShiftManagement(
            _yyyymmdd,
            _employee,
            _shiftId
        );

        shiftManagements[curr.ShiftManagementId - 1]
            .LeavePermissionStatus = PERMISSION_STATUS.PERMISSION;
        mTotalTimeKeepingForYM[_yyyymmdd / 100][_employee]
            .CountLeavePermission += 1;
        mTotalTimeKeepingForYM[_yyyymmdd / 100][_employee].CountLeave += 1;
    }

    function _updateShiftManagementAfterApprovalLateRequest(
        uint _yyyymmdd,
        address _employee,
        uint _shiftId,
        uint _latePermissionApproval
    ) internal {
        ShiftManagement memory curr = _getShiftManagement(
            _yyyymmdd,
            _employee,
            _shiftId
        );

        shiftManagements[curr.ShiftManagementId - 1]
            .LatePermissionApproval = _latePermissionApproval;
        if (
            shiftManagements[curr.ShiftManagementId - 1].CheckInTime <=
            _latePermissionApproval &&
            shiftManagements[curr.ShiftManagementId - 1].LatePermissionStatus !=
            PERMISSION_STATUS.PERMISSION
        ) {
            shiftManagements[curr.ShiftManagementId - 1]
                .LatePermissionStatus = PERMISSION_STATUS.PERMISSION;
            mTotalTimeKeepingForYM[_yyyymmdd / 100][_employee]
                .CountLatePermission += 1;
        }
    }

    function _updateShiftManagementAfterApprovalComeBackSoonRequest(
        uint _yyyymmdd,
        address _employee,
        uint _shiftId,
        uint _comeBackSoonApproval
    ) internal {
        ShiftManagement memory curr = _getShiftManagement(
            _yyyymmdd,
            _employee,
            _shiftId
        );

        shiftManagements[curr.ShiftManagementId - 1]
            .ComeBackSoonApproval = _comeBackSoonApproval;
        if (
            shiftManagements[curr.ShiftManagementId - 1].CheckOutTime >=
            _comeBackSoonApproval &&
            shiftManagements[curr.ShiftManagementId - 1]
                .ComeBackSoonPermissionStatus !=
            PERMISSION_STATUS.PERMISSION
        ) {
            shiftManagements[curr.ShiftManagementId - 1]
                .ComeBackSoonPermissionStatus = PERMISSION_STATUS.PERMISSION;
            mTotalTimeKeepingForYM[_yyyymmdd / 100][_employee]
                .CountComeBackSoonPermission += 1;
        }
    }
    function _updateInOutOnBehalf(
        uint _attendanceId,
        ON_BEHALF_STATUS _status
    ) internal returns (Attendance memory) {
        attendances[_attendanceId - 1].OnBehalfStatus = _status;
        return attendances[_attendanceId - 1];
    }

    function _getInOutOnBehalfForHR()
        internal
        returns (
            Attendance[] memory currAttendances,
            ShiftManagement[] memory currShiftManagements
        )
    {
        currAttendances = new Attendance[](inOutOnBehalfAttendances.length);
        currShiftManagements = new ShiftManagement[](
            inOutOnBehalfAttendances.length
        );

        for (uint idx = inOutOnBehalfAttendances.length; idx > 0; idx--) {
            uint attendanceIdx = inOutOnBehalfAttendances[idx - 1] - 1;

            currAttendances[
                inOutOnBehalfAttendances.length - idx
            ] = attendances[attendanceIdx];
            currShiftManagements[
                inOutOnBehalfAttendances.length - idx
            ] = _getShiftManagement(
                attendances[attendanceIdx].YYYYMMDD,
                attendances[attendanceIdx].Employee,
                attendances[attendanceIdx].ShiftId
            );
        }

        return (currAttendances, currShiftManagements);
    }

    function _getAvgInOutForMonth(
        uint _year
    ) internal view returns (AvgInOutForYM[] memory) {
        AvgInOutForYM[] memory avg = new AvgInOutForYM[](12);
        for (uint month = 1; month <= 12; month++) {
            avg[month - 1] = mAvgInOutForYM[_year * 100 + month];
        }

        return avg;
    }

    function _getTotalTimekeepingYM(
        uint _year,
        uint _month,
        Employee[] memory _employees
    ) internal view returns (TotalTimeKeepingYM[] memory) {
        uint _yyyymm = _year * 100 + _month;
        TotalTimeKeepingYM[]
            memory totalTimeKeepingYMs = new TotalTimeKeepingYM[](
                _employees.length
            );
        for (uint idx = 0; idx < _employees.length; idx++) {
            uint totalTimeKeepingInSecond = mTotalTimeKeepingForYM[_yyyymm][
                _employees[idx].Wallet
            ].TotalTimekeepingInSecond;
            totalTimeKeepingYMs[idx] = TotalTimeKeepingYM({
                Employee: _employees[idx].Wallet,
                DepartmentId: _employees[idx].DepartmentId,
                TimeKeepingSummaryPerMonth: totalTimeKeepingInSecond
            });
        }

        return totalTimeKeepingYMs;
    }

    function _getSumaryTimeKeeping(
        address _employee,
        uint _year,
        uint _month
    ) internal view returns (TimeKeepingSummaryPerMonth memory) {
        uint _yyyymm = _year * 100 + _month;
        return mTotalTimeKeepingForYM[_yyyymm][_employee];
    }


    /** Employee */

    function _addEmployee(Employee memory newEmployee) internal {
        employees.push(newEmployee.Wallet);
        mEmployees[newEmployee.Wallet] = newEmployee;
    }

    function _addEmployeeDetail(
        EmployeeDetail memory newEmployeeDetail
    ) internal {
        newEmployeeDetail.PositionSalary = newEmployeeDetail.PositionSalary * FIXED_NUMBER;
        newEmployeeDetail.TaxableSalary = newEmployeeDetail.TaxableSalary * FIXED_NUMBER;
        newEmployeeDetail.PersonalIncomeTax = newEmployeeDetail.PersonalIncomeTax * FIXED_NUMBER;
        mEmployeeDetails[newEmployeeDetail.Wallet] = newEmployeeDetail;
    }

    function _isExistEmployee(address _employee) internal view returns (bool) {
        int index = findEmployeeIndex(_employee);
        if (index < 0) {
            return false;
        }

        return true;
    }

    // ============================= EMPLOYEE MANAGEMENT ============================= //
    
    /**
        @dev Import Employee by ROOT, HR, HR Manager
        This function will update an existing employee or create a new one based on the WALLET address.
        After processing, the EMPLOYEE role will be granted to the wallet.
     */
    /**
        @dev Import Employee by ROOT, HR, HR Manager
        This function will update an existing employee or create a new one based on the WALLET address.
        After processing, the EMPLOYEE role will be granted to the wallet.
     */
    function importOneEmployee(
        Employee memory _newEmployee,
        EmployeeDetail memory _newEmployeeDetail
    )
        public
        onlyEmployeeHasRole(
            '{"from": "Timekeeping.sol","code": 10026,"msg": "authorization - employee role - importOneEmployee"}'
        )
        returns (bool)
    {
        _importEmployee(_newEmployee);
        _importEmployeeDetail(_newEmployeeDetail);
        _assignNewRefCode(_newEmployee.Wallet);
        _setEmployeeRole(_newEmployee.Wallet);
        return true;
    }
    function importEmployees(Employee[] memory _employees, EmployeeDetail[] memory _employeeDetails) 
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10016,"msg": "authorization - hr - importEmployees"}'
        )  
        returns (bool) 
    {
        for (uint idx = 0; idx < _employees.length; idx++) {
            _createOrUpdateEmployee(_employees[idx], _employeeDetails[idx]);
            _grantRole(ROLE_HASH_EMPLOYEE, _employees[idx].Wallet);
        }
        return true;
    }

    function createEmployee(Employee memory _employee, EmployeeDetail memory _employeeDetail) 
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10016,"msg": "authorization - hr - importEmployees"}'
        )  
        returns (bool) 
    {
        _createOrUpdateEmployee(_employee, _employeeDetail);
        _grantRole(ROLE_HASH_EMPLOYEE, _employee.Wallet);
        return true;
    }

    function exportEmployees() 
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10016,"msg": "authorization - hr - exportEmployees"}'
        ) 
        view 
        returns (Employee[] memory _employees, EmployeeDetail[] memory _employeeDetails) 
    {
        _employees = new Employee[](employees.length);
        _employeeDetails = new EmployeeDetail[](employees.length);

        for (uint idx = 0; idx < employees.length; idx++) {
            _employees[idx] = mEmployees[employees[idx]];
            _employeeDetails[idx] = mEmployeeDetails[employees[idx]];
        } 

        return (_employees, _employeeDetails);
    }

    function verifyEmployee(
        bytes32 refCode
    ) public returns (ROLE[] memory roles) {
        roles = _getAllRoleOfEmployee(msg.sender);

        require(
            roles.length > 0,
            '{"from": "Timekeeping.sol","code": 10042,"msg": "employee not found by address - verifyEmployee"}'
        );

        if (_isActiveEmployee(msg.sender)) {
            return roles;
        }

        require(
            refCode != DEFAULT_REF_CODE &&
                refCode == mRefCode[msg.sender],
            '{"from": "Timekeeping.sol","code": 11001,"msg": "ref-code invalid"}'
        );

        _activeEmployee(msg.sender);
        return roles;
    }

    function getAllEmployee() public view returns (Employee[] memory) {
        return _getAllEmployee();
    }

    function getAllEmployeeAndEmployeeDetail()
        public
        view
        returns (FullEmployeesData memory)
    {
        return
            FullEmployeesData({
                EmployeeData: _getAllEmployee(),
                EmployeeDetailData: _getAllEmployeeDetail()
            });
    }



    function getInformationForEmployee()
        public
        view
        returns (FullEmployeeData memory)
    {
        Employee memory employee = _getEmployeeByAddress(msg.sender);
        EmployeeDetail memory employeeDetail = _getEmployeeDetailByAddress(
            msg.sender
        );

        FullEmployeeData memory full;
        full.EmployeeData = employee;
        full.EmployeeDetailData = employeeDetail;
        return full;
    }

    function updateInformationForEmployee(
        Employee memory _newEmployee,
        EmployeeDetail memory _newEmployeeDetail
    )
        public
        onlyEmployee(
            '{"from": "Timekeeping.sol","code": 10029,"msg": "authorization - employee - updateInformationForEmployee"}'
        )
        returns (bool)
    {
        _updateEmployeeDetailByAddress(
            msg.sender,
            _newEmployee,
            _newEmployeeDetail
        );

        return true;
    }

    function deleteEmployee(
        address _employee
    )
        public
        onlyRoot(
            '{"from": "Timekeeping.sol","code": 10014,"msg": "authorization - root - deleteEmployee"}'
        )
        returns (bool)
    {
        _deleteEmployeeRole(_employee);
        _deleteEmployeeManagement(_employee);
        return true;
    }

    function _createOrUpdateEmployee(Employee memory newEmployee, EmployeeDetail memory newEmployeeDetail) internal {
        if (mEmployees[newEmployee.Wallet].Wallet == address(0)) {
            employees.push(newEmployee.Wallet);
            _assignNewRefCode(newEmployee.Wallet);
        }
        mEmployees[newEmployee.Wallet] = newEmployee;
        _addEmployeeDetail(newEmployeeDetail);
    }

    // ============================= END EMPLOYEE MANAGEMENT ============================= //

    function _initEmployeeAfterAddEmployeeRole(
        address _employee
    ) internal {
        // If employee role not found in timekeeing => INIT Employee 
        if (mEmployees[_employee].Wallet == address(0)) {
            Employee memory newEmployee;
            newEmployee.Wallet = _employee;
            EmployeeDetail memory newEmployeeDetail;
            newEmployeeDetail.Wallet = _employee;

            employees.push(newEmployee.Wallet);
            mEmployees[newEmployee.Wallet] = newEmployee;
            mEmployeeDetails[newEmployeeDetail.Wallet] = newEmployeeDetail;
        }

        _activeEmployee(_employee);
    }
    
    function _clearAllEmployee() internal {
        for (uint i = 0; i < employees.length; i++) {
            delete mEmployees[employees[i]];
        }
        delete employees;
    }

    function _clearAllEmployeeDetail() internal {
        for (uint i = 0; i < employees.length; i++) {
            delete mEmployeeDetails[employees[i]];
        }
    }

    function _importEmployee(Employee memory _newEmployee) internal {
        if (mEmployees[_newEmployee.Wallet].Wallet == address(0)) {
            _addEmployee(_newEmployee);
            return;
        }

        employees.push(_newEmployee.Wallet);
    }

    function _importEmployeeDetail(
        EmployeeDetail memory _newEmployeeDetail
    ) internal {
        _addEmployeeDetail(_newEmployeeDetail);
    }

    function _getEmployeeByAddress(
        address _employee
    ) internal view returns (Employee memory) {
        Employee memory m = mEmployees[_employee];
        if (m.Wallet == address(0)) {
            revert(
                '{"from": "Timekeeping.sol","code": 10046,"msg": "employee not found by address - _getEmployeeByAddress"}'
            );
        }
        return mEmployees[_employee];
    }

    function _getEmployeeDetailByAddress(
        address _employee
    ) internal view returns (EmployeeDetail memory) {
        EmployeeDetail memory m = mEmployeeDetails[_employee];
        if (m.Wallet == address(0)) {
            revert(
                '{"from": "Timekeeping.sol","code": 10047,"msg": "employee not found by address - _getEmployeeDetailByAddress"}'
            );
        }
        return mEmployeeDetails[_employee];
    }

    function _updateEmployeeDetailByAddress(
        address _employee,
        Employee memory _newEmployee,
        EmployeeDetail memory _newEmployeeDetail
    ) internal {
        if (mEmployees[_employee].Wallet == address(0)) {
            revert(
                '{"from": "Timekeeping.sol","code": 10044,"msg": "employee not found by address - _updateEmployeeDetailByAddress"}'
            );
        }

        if (mEmployeeDetails[_employee].Wallet == address(0)) {
            revert(
                '{"from": "Timekeeping.sol","code": 10045,"msg": "employee detail not found by address - _updateEmployeeDetailByAddress"}'
            );
        }

        //---------- Update Employee ---------- //
        mEmployees[_employee].FullName = _newEmployee.FullName;
        mEmployees[_employee].DepartmentId = _newEmployee.DepartmentId;
        mEmployees[_employee].PositionId = _newEmployee.PositionId;
        mEmployees[_employee].Location = _newEmployee.Location;
        mEmployees[_employee].OnboardDateTime = _newEmployee.OnboardDateTime;

        // // ---------- Update Employee Detail ---------- //
        mEmployeeDetails[_employee].DateOfBirth = _newEmployeeDetail.DateOfBirth;
        mEmployeeDetails[_employee].Gender = _newEmployeeDetail.Gender;
        mEmployeeDetails[_employee].Email = _newEmployeeDetail.Email;
        mEmployeeDetails[_employee].PhoneNumber = _newEmployeeDetail.PhoneNumber;

        mEmployeeDetails[_employee].TaxId = _newEmployeeDetail.TaxId;
        mEmployeeDetails[_employee].HealthInsuranceId = _newEmployeeDetail
            .HealthInsuranceId;
        mEmployeeDetails[_employee].SocialInsuranceId = _newEmployeeDetail
            .SocialInsuranceId;
        mEmployeeDetails[_employee].NumberOfDependents = _newEmployeeDetail
            .NumberOfDependents;
        mEmployeeDetails[_employee].PermanentAddress = _newEmployeeDetail
            .PermanentAddress;
    }

    function _getAllEmployee()
        internal
        view
        returns (Employee[] memory employeeArr)
    {
        employeeArr = new Employee[](employees.length);
        for (uint i = 0; i < employees.length; i++) {
            employeeArr[i] = mEmployees[employees[i]];
        }
        return employeeArr;
    }

    function _getAllEmployeeDetail()
        internal
        view
        returns (EmployeeDetail[] memory employeeDetailArr)
    {
        employeeDetailArr = new EmployeeDetail[](employees.length);
        for (uint i = 0; i < employees.length; i++) {
            employeeDetailArr[i] = mEmployeeDetails[employees[i]];
        }
        return employeeDetailArr;
    }

    function _isActiveEmployee(address account) internal view returns (bool) {
        return mActiveEmployee[account];
    }

    function _activeEmployee(address employee) internal {
        mActiveEmployee[employee] = true;
    }
    function _deactivateEmployee(address employee) internal {
        mActiveEmployee[employee] = false;
    }

    function findEmployeeIndex(
        address employeeAddress
    ) public view returns (int) {
        for (uint i = 0; i < employees.length; i++) {
            if (employees[i] == employeeAddress) {
                return int(i);
            }
        }
        return -1; // Trả về -1 nếu không tìm thấy
    }

    function _deleteEmployeeManagement(address _employee) internal {
        int index = findEmployeeIndex(_employee);
        if (index < 0) {
            return;
        }
        _deactivateEmployee(_employee);

        delete mEmployees[_employee];
        delete mEmployeeDetails[_employee];


        employees[uint(index)] = employees[employees.length - 1];
        employees.pop();
        _revokeRole(ROLE_HASH_EMPLOYEE, _employee);
    }

    /**Notification */

    function _setNotificationSMC(address _notiSMC) internal {
        notiSMC = INoti(_notiSMC);
    }

    function _getNotificationTypeName(
        NOTIFICATION_TYPE _type
    ) internal pure returns (string memory) {
        if (_type == NOTIFICATION_TYPE.REQUEST) {
            return "Request";
        }
        if (_type == NOTIFICATION_TYPE.WARNING) {
            return "Warning";
        }
        if (_type == NOTIFICATION_TYPE.REVIEW) {
            return "Review";
        }
        if (_type == NOTIFICATION_TYPE.HOLIDAY) {
            return "Holiday";
        }

        return "Type";
    }

    function _sendNotificationToAddress(
        address _toAddress,
        Notification memory _notification
    ) internal {
        if (address(notiSMC) == address(0)) {
            return;
        }
        NotiParams memory notiParams;
        notiParams.repo = REPO;
        notiParams.title = _notification.Title;
        notiParams.body = _notification.Body;
        notiParams.data = abi.encode(_notification);
        bool result = notiSMC.AddNoti(notiParams, _toAddress);
        emit eSendNotificationToAddress(_toAddress, _notification, result);
    }

    function _sendNotificationToMultipleAddress(
        address[] memory _toAddresses,
        Notification memory _notification
    ) internal {
        if (address(notiSMC) == address(0)) {
            return;
        }
        NotiParams memory notiParams;
        notiParams.repo = REPO;
        notiParams.title = _notification.Title;
        notiParams.body = _notification.Body;
        notiParams.data = abi.encode(_notification);
        bool result = notiSMC.AddMultipleNoti(notiParams, _toAddresses);
        emit eSendNotificationToMultipleAddress(
            _toAddresses,
            _notification,
            result
        );
    }

    /** Role management */

    function _initRole(address account) internal {
        _setRoleAdmin(ROLE_HASH_ROOT, ROLE_HASH_DEPLOYER);
        _setRoleAdmin(ROLE_HASH_HR_MANAGER, ROLE_HASH_ROOT);
        _setRoleAdmin(ROLE_HASH_HR, ROLE_HASH_ROOT);
        _setRoleAdmin(ROLE_HASH_ACCOUNTANT, ROLE_HASH_ROOT);
        _setRoleAdmin(ROLE_HASH_EMPLOYEE, ROLE_HASH_ROOT);

        _grantRole(ROLE_HASH_DEPLOYER, account);
    }

    modifier onlyDeployer(string memory mess) {
        require(hasRole(ROLE_HASH_DEPLOYER, msg.sender), mess);
        _;
    }

    modifier onlyRoot(string memory mess) {
        require(hasRole(ROLE_HASH_ROOT, msg.sender), mess);
        _;
    }

    modifier onlyHRManager() {
        require(
            hasRole(ROLE_HASH_ROOT, msg.sender) ||
                hasRole(ROLE_HASH_HR_MANAGER, msg.sender),
            '{"from": "Timekeeping.sol","code": 10003,"msg": "authorization - hr manager"}'
        );
        _;
    }

    modifier onlyHR(string memory mess) {
        require(
            hasRole(ROLE_HASH_ROOT, msg.sender) ||
                hasRole(ROLE_HASH_HR_MANAGER, msg.sender) ||
                hasRole(ROLE_HASH_HR, msg.sender),
            mess
        );
        _;
    }

    modifier onlyEmployeeHasRole(string memory mess) {
        require(
            hasRole(ROLE_HASH_ROOT, msg.sender) ||
                hasRole(ROLE_HASH_HR_MANAGER, msg.sender) ||
                hasRole(ROLE_HASH_HR, msg.sender) ||
                hasRole(ROLE_HASH_ACCOUNTANT, msg.sender),
            mess
        );
        _;
    }

    modifier onlyEmployee(string memory mess) {
        require(
            hasRole(ROLE_HASH_ROOT, msg.sender) ||
                hasRole(ROLE_HASH_HR_MANAGER, msg.sender) ||
                hasRole(ROLE_HASH_HR, msg.sender) ||
                hasRole(ROLE_HASH_ACCOUNTANT, msg.sender) ||
                hasRole(ROLE_HASH_EMPLOYEE, msg.sender),
            mess
        );
        _;
    }

    modifier onlyAccountant() {
        require(
            hasRole(ROLE_HASH_ROOT, msg.sender) ||
                hasRole(ROLE_HASH_ACCOUNTANT, msg.sender),
            '{"from": "Timekeeping.sol","code": 10005,"msg": "authorization - accountant"}'
        );
        _;
    }

    modifier permissionGetSalary() {
        require(
            hasRole(ROLE_HASH_ROOT, msg.sender) ||
                hasRole(ROLE_HASH_HR_MANAGER, msg.sender) ||
                hasRole(ROLE_HASH_ACCOUNTANT, msg.sender),
            '{"from": "Timekeeping.sol","code": 16001,"msg": "authorization - get salary"}'
        );
        _;
    }

    function _setRoot(address _account, string memory _nickname) internal {
        revokeRole(ROLE_HASH_ROOT, ROOT_ADDRESS);
        _deleteEmployeeRole(ROOT_ADDRESS);
        ROLE[] memory roles = new ROLE[](1);
        roles[0] = ROLE.ROOT;
        _createEmployeeRole(_account, _nickname, roles);

        ROOT_ADDRESS = _account;
    }

    function _setEmployeeRole(address account) internal {
        _grantRole(ROLE_HASH_EMPLOYEE, account);
    }

    function _getRoleHash(ROLE positionId) internal pure returns (bytes32) {
        if (positionId == ROLE.ROOT) {
            return ROLE_HASH_ROOT;
        }
        if (positionId == ROLE.HR_MANAGER) {
            return ROLE_HASH_HR_MANAGER;
        }
        if (positionId == ROLE.HR) {
            return ROLE_HASH_HR;
        }
        if (positionId == ROLE.ACCOUNTANT) {
            return ROLE_HASH_ACCOUNTANT;
        }
        if (positionId == ROLE.EMPLOYEE) {
            return ROLE_HASH_EMPLOYEE;
        }
        revert(
            '{"from": "Timekeeping.sol","code": 10006,"msg": "position id invalid"}'
        );
    }

    function _getRoleHashs(
        ROLE[] memory positionIds
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory roleHashs = new bytes32[](positionIds.length);
        for (uint i = 0; i < positionIds.length; i++) {
            roleHashs[i] = _getRoleHash(positionIds[i]);
        }

        return roleHashs;
    }

    mapping(address => uint256) mEmployeeRole;
    EmployeeRole[] private employeeRoles;

    function _createEmployeeRole(
        address account,
        string memory nickname,
        ROLE[] memory positionIds
    ) internal {
        EmployeeRole memory newEmployeeRole = EmployeeRole({
            Account: account,
            Nickname: nickname,
            LastUpdate: block.timestamp,
            PositionIds: positionIds
        });
        employeeRoles.push(newEmployeeRole);
        mEmployeeRole[account] = employeeRoles.length;

        bytes32[] memory roles = _getRoleHashs(positionIds);

        for (uint idx = 0; idx < roles.length; idx++) {
            grantRole(roles[idx], account);
        }
    }

    function _clearEmployeeRole(address account) internal {
        _revokeRole(ROLE_HASH_HR_MANAGER, account);
        _revokeRole(ROLE_HASH_ACCOUNTANT, account);
        _revokeRole(ROLE_HASH_HR, account);
    }

    function _getAllEmployeeRole()
        internal
        view
        returns (EmployeeRole[] memory)
    {
        return employeeRoles;
    }

    function _isExistEmployeeRole(
        address account
    ) internal view returns (bool) {
        if (mEmployeeRole[account] != 0) {
            return true;
        }
        return false;
    }

    function _updateEmployeeRole(
        address account,
        ROLE[] memory positionIds
    ) internal {
        uint256 idxEmployeeRole = mEmployeeRole[account];

        EmployeeRole memory currentEmployeeRole = employeeRoles[
            idxEmployeeRole - 1
        ];

        currentEmployeeRole.PositionIds = positionIds;
        employeeRoles[idxEmployeeRole - 1] = currentEmployeeRole;

        _clearEmployeeRole(account);

        bytes32[] memory roles = _getRoleHashs(positionIds);

        for (uint idx = 0; idx < roles.length; idx++) {
            grantRole(roles[idx], account);
        }
    }

    function _deleteEmployeeRole(address account) internal {
        uint256 idxEmployeeRole = mEmployeeRole[account];
        if (idxEmployeeRole == 0) {
            return;
        }
        for (uint256 i = idxEmployeeRole; i < employeeRoles.length; i++) {
            employeeRoles[i - 1] = employeeRoles[i];
            mEmployeeRole[employeeRoles[i - 1].Account] = i;
        }
        employeeRoles.pop();
        delete mEmployeeRole[account];
        _clearEmployeeRole(account);
    }

    function _getAllRoleOfEmployee(
        address account
    ) internal view returns (ROLE[] memory) {
        uint256 count = 0;

        if (hasRole(ROLE_HASH_ROOT, account)) count++;
        if (hasRole(ROLE_HASH_HR_MANAGER, account)) count++;
        if (hasRole(ROLE_HASH_HR, account)) count++;
        if (hasRole(ROLE_HASH_ACCOUNTANT, account)) count++;
        if (hasRole(ROLE_HASH_EMPLOYEE, account)) count++;

        ROLE[] memory roles = new ROLE[](count);
        uint256 index = 0;

        // Add roles to the array
        if (hasRole(ROLE_HASH_ROOT, account)) {
            roles[index] = ROLE.ROOT;
            index++;
        }
        if (hasRole(ROLE_HASH_HR_MANAGER, account)) {
            roles[index] = ROLE.HR_MANAGER;
            index++;
        }
        if (hasRole(ROLE_HASH_HR, account)) {
            roles[index] = ROLE.HR;
            index++;
        }
        if (hasRole(ROLE_HASH_ACCOUNTANT, account)) {
            roles[index] = ROLE.ACCOUNTANT;
            index++;
        }
        if (hasRole(ROLE_HASH_EMPLOYEE, account)) {
            roles[index] = ROLE.EMPLOYEE;
            index++;
        }

        return roles;
    }
    function _verifyEmployeeHasPermission(
        EmployeeRole memory _employeeRole,
        ROLE[] memory _roles
    ) internal pure returns (bool) {
        for (uint idx = 0; idx < _employeeRole.PositionIds.length; idx++) {
            for (uint idxRole = 0; idxRole < _roles.length; idxRole++) {
                if (_employeeRole.PositionIds[idx] == _roles[idxRole]) {
                    return true;
                }
            }
        }
        return false;
    }

    /**Refcode */

    function _generateRefcode(
        address _employee
    ) internal view returns (bytes32) {
        return
            keccak256(abi.encodePacked(block.timestamp, msg.sender, _employee));
    }

    function _assignNewRefCode(address _employee) internal returns (bytes32) {
        if (mRefCode[_employee] == DEFAULT_REF_CODE) {
            bytes32 newRefCode = _generateRefcode(_employee);
            mRefCode[_employee] = newRefCode;

            return newRefCode;
        }

        return mRefCode[_employee];
    }

    /*Request */

    function _createRequest(
        REQUEST_TYPE _type,
        uint _idDetail
    ) internal returns (Request memory) {
        requests.push(
            Request({
                RequestId: requests.length + 1,
                IdDetail: _idDetail,
                Type: _type,
                Requester: msg.sender,
                UpdatedBy: address(0),
                LastUpdate: block.timestamp,
                Status: REQUEST_STATUS.UN_READ
            })
        );

        mAddressRequestTypeToIndex[msg.sender][_type].push(requests.length);
        mRequestTypeToIndex[_type].push(requests.length);
        if (_verifyRequestTypeForHR(_type)) {
            requestIdxForHRs.push(requests.length);
        }

        return requests[requests.length - 1];
    }

    function _getRequestByAddressAndType(
        address _employee,
        REQUEST_TYPE _requestType
    ) internal view returns (Request[] memory) {
        uint256[] memory requestIdxs = mAddressRequestTypeToIndex[_employee][
            _requestType
        ];

        Request[] memory data = new Request[](requestIdxs.length);

        for (uint idx = requestIdxs.length; idx > 0; idx--) {
            data[requestIdxs.length - idx] = requests[requestIdxs[idx - 1] - 1];
        }

        return data;
    }

    function _verifyRequestTypeForHR(
        REQUEST_TYPE requestType
    ) internal pure returns (bool) {
        if (
            requestType == REQUEST_TYPE.LEAVE_PERMISSION ||
            requestType == REQUEST_TYPE.LATE_ARRIVAL ||
            requestType == REQUEST_TYPE.COME_BACK_SOON
        ) {
            return true;
        }

        return false;
    }

    function _getRequestById(
        uint _requestId
    ) internal view returns (Request memory) {
        return requests[_requestId - 1];
    }

    function _updateRequestStatus(
        uint256 requestId,
        REQUEST_STATUS requestStatus
    ) internal returns (bool) {
        require(
            requestId > 0 && requestId - 1 < requests.length,
            '{"from": "Timekeeping.sol","code": 12003,"msg": "the request id invalid"}'
        );
        require(
            requests[requestId - 1].Status == REQUEST_STATUS.UN_READ,
            '{"from": "Timekeeping.sol","code": 12004,"msg": "the request has been updated"}'
        );

        requests[requestId - 1].Status = requestStatus;
        requests[requestId - 1].UpdatedBy = msg.sender;
        requests[requestId - 1].LastUpdate = block.timestamp;
        return true;
    }

    function _getAllRequest() internal view returns (Request[] memory) {
        return requests;
    }

    function _getAllRequestForHRManager()
        internal
        view
        returns (Request[] memory requestForHRManagers)
    {
        requestForHRManagers = new Request[](requests.length);
        for (uint256 idx = requestForHRManagers.length; idx > 0; idx--) {
            requestForHRManagers[requestForHRManagers.length - idx] = requests[
                idx - 1
            ];
        }
        return requestForHRManagers;
    }

    function _getAllRequestsForHR() internal view returns (Request[] memory) {
        Request[] memory requestForHRs = new Request[](requestIdxForHRs.length);

        for (uint256 idx = requestIdxForHRs.length; idx > 0; idx--) {
            requestForHRs[requestIdxForHRs.length - idx] = requests[
                requestIdxForHRs[idx - 1] - 1
            ];
        }

        return requestForHRs;
    }

    // ==================================== Leave Request ====================================

    function _checkShiftBelongLeaveRequest(
        uint _dateInSeconds,
        Shift memory _shift,
        LeaveRequest memory _leaveRequest
    ) internal pure returns (bool) {
        if (
            _leaveRequest.StartDateTime <= _dateInSeconds + _shift.CheckIn &&
            _dateInSeconds + _shift.CheckOut <= _leaveRequest.EndDateTime
        ) {
            return true;
        }

        return false;
    }

    function _createLeaveRequest(
        uint _startDateTime,
        uint _endDateTime,
        REASON_LEAVE_TYPE _reasonType,
        string memory _other
    ) internal returns (Request memory request) {
        LeaveRequest memory leaveRequest = LeaveRequest({
            Id: leaveRequests.length + 1,
            StartDateTime: _startDateTime,
            EndDateTime: _endDateTime,
            ReasonType: _reasonType,
            Other: _other
        });
        leaveRequests.push(leaveRequest);

        request = _createRequest(
            REQUEST_TYPE.LEAVE_PERMISSION,
            leaveRequest.Id
        );

        return request;
    }

    function _getLeaveRequestDetail(
        uint _requestId
    ) internal view returns (LeaveRequest memory leaveRequest) {
        Request memory request = requests[_requestId - 1];
        leaveRequest = leaveRequests[request.IdDetail - 1];

        return leaveRequest;
    }

    // ==================================== Late Request ====================================

    function _createLateRequest(
        uint _dateTime,
        REASON_LATE_TYPE _reasonType,
        string memory _other
    ) public returns (Request memory request) {
        LateRequest memory lateRequest = LateRequest({
            Id: lateRequests.length + 1,
            DateTime: _dateTime,
            ReasonType: _reasonType,
            Other: _other
        });
        lateRequests.push(lateRequest);

        request = _createRequest(REQUEST_TYPE.LATE_ARRIVAL, lateRequest.Id);

        return request;
    }

    function _getLateRequestDetail(
        uint _requestId
    ) internal view returns (LateRequest memory lateRequest) {
        Request memory request = requests[_requestId - 1];
        lateRequest = lateRequests[request.IdDetail - 1];

        return lateRequest;
    }

    // ==================================== Come Back Soon Request ====================================

    function _createComeBackSoonRequest(
        uint _dateTime,
        REASON_COME_BACK_SOON _reasonType,
        string memory _other
    ) internal returns (Request memory request) {
        ComeBackSoonRequest memory comeBackSoonRequest = ComeBackSoonRequest({
            Id: comeBackSoonRequests.length + 1,
            DateTime: _dateTime,
            ReasonType: _reasonType,
            Other: _other
        });
        comeBackSoonRequests.push(comeBackSoonRequest);
        request = _createRequest(
            REQUEST_TYPE.COME_BACK_SOON,
            comeBackSoonRequest.Id
        );

        return request;
    }

    function _getComeBackSoonRequestDetail(
        uint _requestId
    ) internal view returns (ComeBackSoonRequest memory) {
        Request memory request = requests[_requestId - 1];
        return comeBackSoonRequests[request.IdDetail - 1];
    }

    // ==================================== Offer Salary Request ====================================

    function _createOfferSalaryRequest(
        uint _currentSalary,
        uint _offserSalary,
        uint _dateTime,
        REASON_COME_OFFER_SALARY _reasonType,
        string memory _other
    ) internal returns (Request memory request) {
        OfferSalaryRequest memory offerSalaryRequest = OfferSalaryRequest({
            Id: offerSalaryRequests.length + 1,
            CurrentSalary: _currentSalary,
            OfferSalary: _offserSalary,
            DateTime: _dateTime,
            ReasonType: _reasonType,
            Other: _other
        });
        offerSalaryRequests.push(offerSalaryRequest);
        request = _createRequest(
            REQUEST_TYPE.OFFER_SALARY,
            offerSalaryRequest.Id
        );
        mOfferSalaryRequest[msg.sender].push(request.RequestId);
        return request;
    }

    function _getOfferSalaryRequestDetail(
        uint _requestId
    ) internal view returns (OfferSalaryRequest memory) {
        Request memory request = requests[_requestId - 1];
        return offerSalaryRequests[request.IdDetail - 1];
    }

    function _getOfferSalaryRequestOfEmployee(
        address _empployee
    )
        internal
        view
        returns (
            Request[] memory resultRequests,
            OfferSalaryRequest[] memory resultOfferSalaryRequests
        )
    {
        uint[] memory recordIds = mOfferSalaryRequest[_empployee];

        resultRequests = new Request[](recordIds.length);
        resultOfferSalaryRequests = new OfferSalaryRequest[](recordIds.length);

        for (uint idx = 0; idx < recordIds.length; idx++) {
            resultRequests[idx] = requests[recordIds[idx] - 1];
            resultOfferSalaryRequests[idx] = offerSalaryRequests[
                resultRequests[idx].IdDetail - 1
            ];
        }

        return (resultRequests, resultOfferSalaryRequests);
    }

    function _getOfferSalaryRequestOfEmployees(
        address[] memory _empployee
    )
        internal
        view
        returns (
            Request[] memory resultRequests,
            OfferSalaryRequest[] memory resultOfferSalaryRequests
        )
    {
        uint[][] memory requestIdArr = new uint[][](_empployee.length);

        uint total = 0;
        for (uint i = 0; i < _empployee.length; i++) {
            requestIdArr[i] = mOfferSalaryRequest[_empployee[i]];
            total += requestIdArr[i].length;
        }

        resultRequests = new Request[](total);
        resultOfferSalaryRequests = new OfferSalaryRequest[](total);

        uint index = 0;
        for (uint i = 0; i < requestIdArr.length; i++) {
            for (uint j = 0; j < requestIdArr[i].length; j++) {
                resultRequests[index] = requests[requestIdArr[i][j] - 1];
                resultOfferSalaryRequests[index] = offerSalaryRequests[
                    resultRequests[index].IdDetail - 1
                ];
                index++;
            }
        }

        return (resultRequests, resultOfferSalaryRequests);
    }

    // ==================================== Subsidize Request ====================================

    function _createSubsidizeRequest(
        uint _allowance,
        uint _dateTime,
        REASON_COME_SUBSIDIZE _reasonType,
        string memory _other
    ) internal returns (Request memory request) {
        SubsidizeRequest memory subsidizeRequest = SubsidizeRequest({
            Id: subsidizeRequests.length + 1,
            Allowance: _allowance,
            DateTime: _dateTime,
            ReasonType: _reasonType,
            Other: _other
        });
        subsidizeRequests.push(subsidizeRequest);
        request = _createRequest(REQUEST_TYPE.SUBSIDIZE, subsidizeRequest.Id);

        mSubsidizeRequest[msg.sender].push(request.RequestId);
        return request;
    }

    function _getSubsidizeRequestOfEmployees(
        address[] memory _empployee
    )
        internal
        view
        returns (
            Request[] memory resultRequests,
            SubsidizeRequest[] memory resultSubsidizeRequests
        )
    {
        uint[][] memory requestIdArr = new uint[][](_empployee.length);

        uint total = 0;
        for (uint i = 0; i < _empployee.length; i++) {
            requestIdArr[i] = mSubsidizeRequest[_empployee[i]];
            total += requestIdArr[i].length;
        }

        resultRequests = new Request[](total);
        resultSubsidizeRequests = new SubsidizeRequest[](total);

        uint index = 0;
        for (uint i = 0; i < requestIdArr.length; i++) {
            for (uint j = 0; j < requestIdArr[i].length; j++) {
                resultRequests[index] = requests[requestIdArr[i][j] - 1];
                resultSubsidizeRequests[index] = subsidizeRequests[
                    resultRequests[index].IdDetail - 1
                ];
                index++;
            }
        }

        return (resultRequests, resultSubsidizeRequests);
    }

    function _getSubsidizeRequestDetail(
        uint _requestId
    ) internal view returns (SubsidizeRequest memory) {
        Request memory request = requests[_requestId - 1];
        return subsidizeRequests[request.IdDetail - 1];
    }

    // ==================================== Resign Request ====================================

    function _createResignRequest(
        uint _dateTime,
        REASON_RESIGN _reasonType,
        string memory _other
    ) internal returns (Request memory request) {
        ResignRequest memory resignRequest = ResignRequest({
            Id: resignRequests.length + 1,
            DateTime: _dateTime,
            ReasonType: _reasonType,
            Other: _other
        });
        resignRequests.push(resignRequest);
        request = _createRequest(REQUEST_TYPE.RESIGN, resignRequest.Id);

        return request;
    }

    function _getResignRequestDetail(
        uint _requestId
    ) internal view returns (ResignRequest memory) {
        Request memory request = requests[_requestId - 1];

        return resignRequests[request.IdDetail - 1];
    }

    // ==================================== Salary Deducation Request ====================================

    function _createSalaryDeducationRequest(
        address _employee,
        VIOLATION_TYPE _violationType,
        uint _yyyymmdd,
        string memory _other,
        SALARY_DEDUCATION_TYPE _salaryDeducationType,
        uint _shiftManagementId,
        uint _amountType,
        uint _amount
    ) internal returns (Request memory request) {
        SalaryDeducationRequest
            memory salaryDeducationRequest = SalaryDeducationRequest({
                Id: salaryDeducationRequests.length + 1,
                Employee: _employee,
                ViolationType: _violationType,
                Date: _yyyymmdd,
                SalaryDeducationType: _salaryDeducationType,
                Other: _other,
                ShiftManagementId: _shiftManagementId,
                AmountType: _amountType,
                Amount: _amount,
                RequestId: 0
            });

        request = _createRequest(
            REQUEST_TYPE.SALARY_DEDUCATION,
            salaryDeducationRequest.Id
        );
        salaryDeducationRequest.RequestId = request.RequestId;
        salaryDeducationRequests.push(salaryDeducationRequest);

        mSalaryDeducationRequestByYM[_employee][_yyyymmdd / 100].push(
            salaryDeducationRequests.length
        );

        return request;
    }

    function _updateSalaryDeducationRequests(Request memory request) internal {
        salaryDeducationRequests[request.IdDetail - 1].RequestId = request
            .RequestId;
    }

    function _getSalaryDeducationRequestDetail(
        uint _requestId
    ) internal view returns (SalaryDeducationRequest memory) {
        Request memory request = requests[_requestId - 1];
        return salaryDeducationRequests[request.IdDetail - 1];
    }

    function _getSalaryDeducationRequestOfEmployeeByYYYYMM(
        address _empployee,
        uint _yyyymm
    )
        internal
        view
        returns (
            Request[] memory resultRequests,
            SalaryDeducationRequest[] memory resultSalaryDeducationRequests
        )
    {
        uint[] memory recordIds = mSalaryDeducationRequestByYM[_empployee][
            _yyyymm
        ];

        resultRequests = new Request[](recordIds.length);
        resultSalaryDeducationRequests = new SalaryDeducationRequest[](
            recordIds.length
        );

        for (uint idx = 0; idx < recordIds.length; idx++) {
            resultSalaryDeducationRequests[idx] = salaryDeducationRequests[
                recordIds[idx] - 1
            ];
            resultRequests[idx] = requests[
                salaryDeducationRequests[idx].RequestId - 1
            ];
        }

        return (resultRequests, resultSalaryDeducationRequests);
    }

    function _getSalaryDeducationRequestOfEmployeesByYYYYMMs(
        address[] memory _employees,
        uint[] memory _yyyymms
    )
        public
        view
        returns (
            Request[] memory resultRequests,
            SalaryDeducationRequest[] memory resultSalaryDeducationRequests
        )
    {
        uint len = _employees.length * _yyyymms.length;
        SalaryDeducationRequest[][]
            memory salaryDeducationRequestArr = new SalaryDeducationRequest[][](
                len
            );
        Request[][] memory requestArr = new Request[][](len);

        uint totalRecords = 0;
        uint index = 0;
        for (uint i = 0; i < _employees.length; i++) {
            for (uint j = 0; j < _yyyymms.length; j++) {
                (
                    requestArr[index],
                    salaryDeducationRequestArr[index]
                ) = _getSalaryDeducationRequestOfEmployeeByYYYYMM(
                    _employees[i],
                    _yyyymms[j]
                );
                totalRecords += requestArr[index].length;
                index++;
            }
        }

        resultRequests = new Request[](totalRecords);
        resultSalaryDeducationRequests = new SalaryDeducationRequest[](
            totalRecords
        );
        uint indexS = 0;
        for (uint i = 0; i < salaryDeducationRequestArr.length; i++) {
            for (uint j = 0; j < salaryDeducationRequestArr[i].length; j++) {
                resultRequests[indexS] = requestArr[i][j];
                resultSalaryDeducationRequests[
                    indexS
                ] = salaryDeducationRequestArr[i][j];
                indexS++;
            }
        }

        return (resultRequests, resultSalaryDeducationRequests);
    }

    // ==================================== In/Out OnBehalf Request ====================================

    function _createInOutOnBeHalfRequest(
        address _employee,
        uint _dateTime,
        string memory _reason,
        uint _attendanceId
    ) internal returns (Request memory request) {
        InOutOnBeHalfRequest
            memory inOutOnBeHalfRequest = InOutOnBeHalfRequest({
                Id: inOutOnBeHalfRequests.length + 1,
                Employee: _employee,
                DateTime: _dateTime,
                Reason: _reason,
                AttendanceId: _attendanceId
            });
        inOutOnBeHalfRequests.push(inOutOnBeHalfRequest);
        request = _createRequest(
            REQUEST_TYPE.IN_OUT_ON_BEHALF,
            inOutOnBeHalfRequest.Id
        );

        return request;
    }

    function _getInOutOnBehalfRequestDetail(
        uint _requestId
    ) internal view returns (InOutOnBeHalfRequest memory) {
        Request memory request = requests[_requestId - 1];

        return inOutOnBeHalfRequests[request.IdDetail - 1];
    }
    // ==================================== Rule Request ====================================

    function _createRuleRequest(
        VIOLATION_TYPE _violationType,
        uint _time,
        uint _quantity,
        CONDITION_TYPE _conditionType,
        PUNISH_TYPE _punishType,
        SALARY_DEDUCATION_TYPE _salaryDeducation
    ) internal returns (Request memory request) {
        RuleRequest memory ruleRequest = RuleRequest({
            Id: ruleRequests.length + 1,
            ViolationType: _violationType,
            Time: _time,
            Quantity: _quantity,
            ConditionType: _conditionType,
            PunishType: _punishType,
            SalaryDeducationType: _salaryDeducation
        });
        ruleRequests.push(ruleRequest);
        request = _createRequest(REQUEST_TYPE.RULE, ruleRequest.Id);

        return request;
    }

    function _getRuleRequestDetail(
        uint _requestId
    ) internal view returns (RuleRequest memory) {
        Request memory request = requests[_requestId - 1];

        return ruleRequests[request.IdDetail - 1];
    }

    /**
        The HR only receive the request with type:
            - LEAVE_PERMISSION
            - LATE_ARRIVAL
            - COME_BACK_SOON

        HR Manager & ROOT will receive all notification.
     */
    function _getHRRolesToNotification(
        uint _requestId
    ) internal view returns (ROLE[] memory roles) {
        if (
            requests[_requestId - 1].Type == REQUEST_TYPE.LEAVE_PERMISSION ||
            requests[_requestId - 1].Type == REQUEST_TYPE.LATE_ARRIVAL ||
            requests[_requestId - 1].Type == REQUEST_TYPE.COME_BACK_SOON
        ) {
            roles = new ROLE[](3);
            roles[0] = ROLE.ROOT;
            roles[1] = ROLE.HR_MANAGER;
            roles[2] = ROLE.HR;
            return roles;
        }

        roles = new ROLE[](2);
        roles[0] = ROLE.ROOT;
        roles[1] = ROLE.HR_MANAGER;
        return roles;
    }

    function _getNotificationBody(
        Request memory _request
    ) internal view returns (string memory) {
        if (_request.Type == REQUEST_TYPE.LEAVE_PERMISSION) {
            return
                UtilsLibrary.getReasonRequestName(
                    _getLeaveRequestDetail(_request.RequestId).ReasonType
                );
        } else if (_request.Type == REQUEST_TYPE.LATE_ARRIVAL) {
            return
                UtilsLibrary.getReasonRequestName(
                    _getLateRequestDetail(_request.RequestId).ReasonType
                );
        } else if (_request.Type == REQUEST_TYPE.COME_BACK_SOON) {
            return
                UtilsLibrary.getReasonRequestName(
                    _getComeBackSoonRequestDetail(_request.RequestId).ReasonType
                );
        } else if (_request.Type == REQUEST_TYPE.OFFER_SALARY) {
            return
                UtilsLibrary.getReasonRequestName(
                    _getOfferSalaryRequestDetail(_request.RequestId).ReasonType
                );
        } else if (_request.Type == REQUEST_TYPE.SUBSIDIZE) {
            return
                UtilsLibrary.getReasonRequestName(
                    _getSubsidizeRequestDetail(_request.RequestId).ReasonType
                );
        } else if (_request.Type == REQUEST_TYPE.RESIGN) {
            return
                UtilsLibrary.getReasonRequestName(
                    _getResignRequestDetail(_request.RequestId).ReasonType
                );
        } else if (_request.Type == REQUEST_TYPE.RULE) {
            return "Review: New rule request by HR";
        } else if (_request.Type == REQUEST_TYPE.IN_OUT_ON_BEHALF) {
            return "Review IN/OUT On Behalf";
        } else if (_request.Type == REQUEST_TYPE.SALARY_DEDUCATION) {
            return "Review Salary Deducation";
        }
        return "";
    }

    /** Salary */

    function _addSalaryEmployee(SalaryRequest memory _salaryRequest) internal {
        mSalaryRequest[_salaryRequest.Employee] = _salaryRequest;
    }

    function _createSalary(
        uint shiftLength,
        Salary memory salary,
        uint _yyyymmdd,
        Shift memory shift
    ) internal returns (Salary memory) {
        uint id = salaries.length + 1;
        salaries.push(salary);

        uint yyyymm = _yyyymmdd / 100;
        uint day = _yyyymmdd % 100;
        mTotalSalaryEmployee[salary.employee][yyyymm] += salary.amount;

        if (mSalary[salary.employee][yyyymm].length == 0) {
            mSalary[salary.employee][yyyymm] = new uint[][](31);
        }

        if (mSalary[salary.employee][yyyymm][day - 1].length == 0) {
            mSalary[salary.employee][yyyymm][day - 1] = new uint[](shiftLength); //at most 10 shifts
        }

        mSalary[salary.employee][yyyymm][day - 1][shift.ShiftId - 1] = id;

        return salaries[id - 1];
    }

    function _createOTSalary(
        OTSalary memory _OTSalary,
        uint _yyyymmdd
    ) internal returns (OTSalary memory) {
        uint yyyymm = _yyyymmdd / 100;
        mOTSalary[_OTSalary.employee][yyyymm].push(_OTSalary);

        return _OTSalary;
    }

    function _createSalaryDeducation(
        SalaryDeducation memory salaryDeducation
    ) internal {
        uint yyyymm = salaryDeducation.Date / 100;
        mSalaryDeducation[salaryDeducation.Employee][yyyymm].push(
            salaryDeducation
        );
    }

    function _getSalaryDeducationOfEmployeeByYYYYMM(
        address _employee,
        uint _yyyymm
    ) internal view returns (SalaryDeducation[] memory) {
        return mSalaryDeducation[_employee][_yyyymm];
    }

    function _getSalaryDeducationOfEmployeesByYYYYMMs(
        address[] memory _employees,
        uint[] memory _yyyymms
    ) public view returns (SalaryDeducation[] memory result) {
        uint len = _employees.length * _yyyymms.length;
        SalaryDeducation[][]
            memory salaryDeducationArr = new SalaryDeducation[][](len);

        uint totalRecords = 0;
        uint index = 0;
        for (uint i = 0; i < _employees.length; i++) {
            for (uint j = 0; j < _yyyymms.length; j++) {
                (
                    salaryDeducationArr[index]
                ) = _getSalaryDeducationOfEmployeeByYYYYMM(
                    _employees[i],
                    _yyyymms[j]
                );
                totalRecords += salaryDeducationArr[index].length;
                index++;
            }
        }

        result = new SalaryDeducation[](totalRecords);
        uint indexS = 0;
        for (uint i = 0; i < salaryDeducationArr.length; i++) {
            for (uint j = 0; j < salaryDeducationArr[i].length; j++) {
                result[indexS] = salaryDeducationArr[i][j];
                indexS++;
            }
        }

        return result;
    }

    function _getSalaryOfEmployeesByYYYYMMs(
        address[] memory _employees,
        uint[] memory _yyyymms
    ) public view returns (Salary[] memory result) {
        uint len = _employees.length * _yyyymms.length;
        Salary[][] memory salaryArr = new Salary[][](len);
       
        uint totalRecords = 0;
        uint index = 0;

        for (uint i = 0; i < _employees.length; i++) {
            for (uint j = 0; j < _yyyymms.length; j++) {
                
                (salaryArr[index]) = _getSalaryOfEmployeeByYYYYMM(
                    _employees[i],
                    _yyyymms[j]
                );
                  
                
                totalRecords += salaryArr[index].length;
                index++;
            }
        }

        result = new Salary[](totalRecords);
        uint indexS = 0;
        for (uint i = 0; i < salaryArr.length; i++) {
            for (uint j = 0; j < salaryArr[i].length; j++) {
                result[indexS] = salaryArr[i][j];
                indexS++;
            }
        }

        return result;
    }

    function _getSalaryRequestByAddress(
        address employee
    ) internal view returns (SalaryRequest memory) {
        return mSalaryRequest[employee];
    }

    function _getSalaryOfEmployeeByYYYYMM(
        address _employee,
        uint _yyyymm
    ) public view returns (Salary[] memory) {
        uint[][] memory recordIds = mSalary[_employee][_yyyymm];

        uint validCount = 0;
        for (uint i = 0; i < recordIds.length; i++) {
            for (uint j = 0; j < recordIds[i].length; j++) {
                if (recordIds[i][j] > 0) {
                    validCount++;
                }
            }
        }


        Salary[] memory resultSalary = new Salary[](validCount);


        uint index = 0;
        for (uint i = 0; i < recordIds.length; i++) {
            for (uint j = 0; j < recordIds[i].length; j++) {
                if (recordIds[i][j] > 0) {
                    resultSalary[index] = salaries[recordIds[i][j] - 1];
                    index++;
                }
            }
        }

        return resultSalary;
    }

    function _getSalaryOfEmployeeByYYYYMMs(
        address _employee,
        uint[] memory _yyyymms
    ) public view returns (Salary[][] memory result) {
        result = new Salary[][](_yyyymms.length);

        for (uint i = 0; i < _yyyymms.length; i++) {
            result[i] = _getSalaryOfEmployeeByYYYYMM(
                _employee,
                _yyyymms[i]
            );
        }

        return result;
    }

    function _getOTSalaryOfEmployeeByYYYYMM(
        address _employee,
        uint _yyyymm
    ) public view returns (OTSalary[] memory resultOTSalary) {
        return mOTSalary[_employee][_yyyymm];
    }

    function _getOTSalaryOfEmployeeByYYYYMMs(
        address _employee,
        uint[] memory _yyyymms
    ) public view returns (OTSalary[][] memory result) {
        result = new OTSalary[][](_yyyymms.length);

        for (uint i = 0; i < _yyyymms.length; i++) {
            result[i] = _getOTSalaryOfEmployeeByYYYYMM(_employee, _yyyymms[i]);
        }

        return result;
    }

    function _getOTSalaryOfEmployeesByYYYYMMs(
        address[] memory _employees,
        uint[] memory _yyyymms
    ) public view returns (OTSalary[] memory result) {
        uint len = _employees.length * _yyyymms.length;
        OTSalary[][] memory OTSalaryArr = new OTSalary[][](len);

        uint totalRecords = 0;
        uint index = 0;
        for (uint i = 0; i < _employees.length; i++) {
            for (uint j = 0; j < _yyyymms.length; j++) {
                (OTSalaryArr[index]) = _getOTSalaryOfEmployeeByYYYYMM(
                    _employees[i],
                    _yyyymms[j]
                );
                totalRecords += OTSalaryArr[index].length;
                index++;
            }
        }

        result = new OTSalary[](totalRecords);
        uint indexS = 0;
        for (uint i = 0; i < OTSalaryArr.length; i++) {
            for (uint j = 0; j < OTSalaryArr[i].length; j++) {
                result[indexS] = OTSalaryArr[i][j];
                indexS++;
            }
        }

        return result;
    }

    function _getTotalSalaryEmployeeByYYYYMM(
        address _employee,
        uint _yyyymm
    ) public view returns (uint) {
        return mTotalSalaryEmployee[_employee][_yyyymm];
    }

    function _getTotalSalaryEmployeesByYYYYMMs(
        address[] memory _employees,
        uint[] memory _yyyymms
    ) public view returns (uint[][] memory result) {
        result = new uint[][](_employees.length);

        for (uint i = 0; i < _employees.length; i++) {
            result[i] = new uint[](_yyyymms.length);
            for (uint j = 0; j < _yyyymms.length; j++) {
                result[i][j] = _getTotalSalaryEmployeeByYYYYMM(
                    _employees[i],
                    _yyyymms[j]
                );
            }
        }

        return result;
    }

    function _createSubsidize(
        Subsidize memory _subsidize
    ) internal returns (Subsidize memory) {
        Subsidize[] memory records = _getSubsidizesByAddress(
            _subsidize.employee
        );
        _subsidize.id = records.length + 1;
        mSubsidize[_subsidize.employee].push(_subsidize);
        return mSubsidize[_subsidize.employee][_subsidize.id - 1];
    }

    function _getSubsidizesByAddress(
        address employee
    ) internal view returns (Subsidize[] memory) {
        return mSubsidize[employee];
    }

    function _getSubsidizeByAddress(
        address employee,
        uint id
    ) internal view returns (Subsidize memory) {
        return mSubsidize[employee][id];
    }

    /**Setting */

    function _createSettingRule(SettingRule memory rule) internal {
        rule.RuleId = settingRules.length + 1;
        rule.LastUpdate = block.timestamp;

        settingRules.push(rule);
    }

    function _getSettingRuleByRuleId(
        uint256 ruleId
    ) internal view returns (SettingRule memory) {
        require(
            0 < ruleId && ruleId - 1 < settingRules.length,
            '{"from": "Timekeeping.sol","code": 13002,"msg": "the rule id invalid"}'
        );
        return settingRules[ruleId - 1];
    }

    function _getSettingRule() internal view returns (SettingRule[] memory) {
        return settingRules;
    }

    function _updateSettingRule(
        uint256 ruleId,
        SettingRule memory rule
    ) internal {
        rule.LastUpdate = block.timestamp;
        settingRules[ruleId - 1] = rule;
    }

    function _checkShiftIsViolationCompanyRule(
        ShiftManagement memory _shiftManagements,
        Shift memory _shift
    ) internal view returns (uint) {
        for (uint ruleIdx = 0; ruleIdx < settingRules.length; ruleIdx++) {
            if (
                _shiftManagements.ShiftStatus == SHIFT_STATUS.LATE &&
                settingRules[ruleIdx].ViolationType == VIOLATION_TYPE.LATE
            ) {
                if (
                    _shift.CheckIn <= settingRules[ruleIdx].Time &&
                    settingRules[ruleIdx].Time <= _shift.CheckOut &&
                    _shiftManagements.CheckInTime >= settingRules[ruleIdx].Time
                ) {
                    return settingRules[ruleIdx].RuleId;
                }
            }
        }

        return 0;
    }

    function _addNewRuleAfterApprovalRequest(
        Request memory _request,
        RuleRequest memory _ruleRequestDetail
    ) internal {
        SettingRule memory settingRule = SettingRule({
            RuleId: settingRules.length + 1,
            ViolationType: _ruleRequestDetail.ViolationType,
            Time: _ruleRequestDetail.Time,
            Quantity: _ruleRequestDetail.Quantity,
            ConditionType: _ruleRequestDetail.ConditionType,
            PunishType: _ruleRequestDetail.PunishType,
            SalaryDeducationType: _ruleRequestDetail.SalaryDeducationType,
            LastUpdate: _request.LastUpdate
        });

        settingRules.push(settingRule);
    }

    // ============================= TIME ============================= //

    function _getSettingTime() internal view returns (SettingTime memory) {
        return settingTime;
    }

    function _getShiftById(uint id) internal view returns (Shift memory) {
        return settingTime.Shifts[id - 1];
    }

    function _getShifts() internal view returns (Shift[] memory) {
        return settingTime.Shifts;
    }

    function _getMinuteWork(Shift memory val) internal pure returns (uint) {
        return
            (val.CheckOut - val.CheckIn) -
            (val.BreakTimeTo - val.BreakTimeFrom);
    }

    function _getMinuteAndShiftWorkById(
        uint id
    ) internal view returns (uint, Shift memory) {
        Shift memory val = _getShiftById(id);
        return (_getMinuteWork(val), val);
    }

    function _updateSettingTime(SettingTime memory _settingTime) internal {
        settingTime.LastUpdate = block.timestamp;
        settingTime.FormOFWork = _settingTime.FormOFWork;

        settingTime.Overtime = _settingTime.Overtime;
        settingTime.Permission = _settingTime.Permission;
        settingTime.SalaryClosingDate = _settingTime.SalaryClosingDate;
        settingTime.NumberOfShift = _settingTime.NumberOfShift;
        delete settingTime.Shifts;
        for (uint256 i = 0; i < _settingTime.NumberOfShift; i++) {
            if (settingTime.FormOFWork == FORM_OF_WORK.BY_DATE) {
                require(
                    _settingTime.Shifts[i].BreakTimeFrom <
                        _settingTime.Shifts[i].BreakTimeTo,
                    "BreakTimeFrom and BreakTimeTo invalid"
                );
                require(
                    _settingTime.Shifts[i].CheckIn <
                        _settingTime.Shifts[i].BreakTimeFrom,
                    "BreakTimeFrom and BreakTimeTo invalid"
                );
                require(
                    _settingTime.Shifts[i].BreakTimeTo <
                        _settingTime.Shifts[i].CheckOut,
                    "BreakTimeFrom and BreakTimeTo invalid"
                );
            }
            _settingTime.Shifts[i].ShiftId = i + 1;
            settingTime.Shifts.push(_settingTime.Shifts[i]);
        }

        delete settingTime.DayOffs;
        for (uint256 i = 0; i < _settingTime.DayOffs.length; i++) {
            _settingTime.DayOffs[i].shiftId = i + 1;
            settingTime.DayOffs.push(_settingTime.DayOffs[i]);
        }
    }

    function _getShiftBasedOnCheckInTime(
        uint _time
    ) internal view returns (Shift memory) {
        Shift[] memory shifts = settingTime.Shifts;

        for (uint i = 0; i < shifts.length; i++) {
            if (_time <= shifts[i].CheckOut) {
                return shifts[i];
            }
        }
        return SHIFT_EMPTY;
    }

    function _getShiftBasedOnCheckOutTime(
        uint _time
    ) internal view returns (Shift memory) {
        Shift[] memory shifts = settingTime.Shifts;

        for (uint i = shifts.length - 1; i >= 0; i--) {
            if (shifts[i].CheckIn <= _time) {
                return shifts[i];
            }
        }
        return SHIFT_EMPTY;
    }

    function _getLastShiftForOvertime() internal view returns (Shift memory) {
        return settingTime.Shifts[settingTime.Shifts.length - 1];
    }

    function _getShiftBasedOnLateRequestTime(
        uint _time
    ) internal view returns (Shift memory) {
        for (uint i = 0; i < settingTime.NumberOfShift; i++) {
            if (
                settingTime.Shifts[i].CheckIn < _time &&
                _time < settingTime.Shifts[i].CheckOut
            ) {
                return settingTime.Shifts[i];
            }
        }
        return SHIFT_EMPTY;
    }

    // ============================= Attendance Address ============================= //

    function _getSettingAddress()
        internal
        view
        returns (SettingAddress memory)
    {
        return settingAddress;
    }
    function _updateSettingAddress(
        SettingAddress memory _settingAddress
    ) internal {
        settingAddress.SemiClosed = _settingAddress.SemiClosed;
        settingAddress.LastUpdate = block.timestamp;

        delete settingAddress.WorkPlaces;
        for (uint256 i = 0; i < _settingAddress.WorkPlaces.length; i++) {
            _settingAddress.WorkPlaces[i].WorkPlaceId = i + 1;
            settingAddress.WorkPlaces.push(_settingAddress.WorkPlaces[i]);
        }
    }

    function _getSettingAttendanceLimit(
        Employee[] memory _employees
    ) internal view returns (EmployeeSettingAttendanceLimit[] memory) {
        EmployeeSettingAttendanceLimit[]
            memory attendanceLimit = new EmployeeSettingAttendanceLimit[](
                _employees.length
            );

        for (uint256 i = 0; i < _employees.length; i++) {
            attendanceLimit[i].Employee = _employees[i].Wallet;
            attendanceLimit[i].AttendanceLimitType = mSettingAttendanceLimit[
                _employees[i].Wallet
            ];
        }

        return attendanceLimit;
    }

    function _isWorkPlaceExists(
        uint256 _workPlaceId
    ) public view returns (bool) {
        for (uint256 i = 0; i < settingAddress.WorkPlaces.length; i++) {
            if (settingAddress.WorkPlaces[i].WorkPlaceId == _workPlaceId) {
                return true;
            }
        }
        return false;
    }

    function _getSettingAttendanceLimitForEmployee(
        address _employee
    ) internal view returns (ATTENDANCE_LIMIT_TYPE) {
        return mSettingAttendanceLimit[_employee];
    }

    function _updateSettingAttendaceLimit(
        address[] memory employeeAddress,
        ATTENDANCE_LIMIT_TYPE[] memory typeOfLimit
    ) internal {
        for (uint256 i = 0; i < employeeAddress.length; i++) {
            mSettingAttendanceLimit[employeeAddress[i]] = typeOfLimit[i];
        }
    }

    function _getTotalTimeOfShift(
        Shift memory shift
    ) internal view returns (uint) {
        uint total = shift.CheckOut - shift.CheckIn;

        if (settingTime.FormOFWork == FORM_OF_WORK.BY_DATE) {
            total = total - (shift.BreakTimeTo - shift.BreakTimeFrom);
        }

        return total;
    }

    function _getTotalWorkMinutesPerYM(
        uint _year,
        uint _month
    ) internal view returns (uint minuteWork, uint totalMinuteWork) {
        uint timestampStartMonth = DateTimeLibrary.timestampFromDate(
            _year,
            _month,
            1
        );

        uint countSecondOff = 0;
        for (uint idx = 0; idx < settingTime.DayOffs.length; idx++) {
            countSecondOff += (settingTime.DayOffs[idx].to -
                settingTime.DayOffs[idx].from);
        }

        uint countSecondWork = 0;
        uint daysInMonth = DateTimeLibrary.getDaysInMonth(timestampStartMonth);
        for (uint idx = 0; idx < settingTime.Shifts.length; idx++) {
            countSecondWork += _getTotalTimeOfShift(settingTime.Shifts[idx]);
        }
        uint countMinuteOff = countSecondOff / 60;
        uint countMinuteWork = countSecondWork / 60;

        return (
            countMinuteWork,
            (countMinuteWork * daysInMonth) - countMinuteOff
        );
    }

    function setNotificationSMC(
        address _notiSMCAddress
    )
        public
        onlyDeployer(
            '{"from": "Timekeeping.sol","code": 10010,"msg": "authorization - deployeer - setNotificationSMC"}'
        )
        returns (bool)
    {
        _setNotificationSMC(_notiSMCAddress);
        return true;
    }

    // ==================== Employee Role ====================
    function setRoot(
        address _account,
        string memory _nickname
    )
        public
        onlyDeployer(
            '{"from": "Timekeeping.sol","code": 10011,"msg": "authorization - deployeer - setRoot"}'
        )
        returns (bool)
    {
        _deleteEmployeeManagement(ROOT_ADDRESS);

        _setRoot(_account, _nickname);
        _initEmployeeAfterAddEmployeeRole(_account);

        return true;
    }

    function createEmployeeRoleByRoot(
        address _account,
        string memory _nickname,
        ROLE[] memory _positionIds
    )
        public
        onlyRoot(
            '{"from": "Timekeeping.sol","code": 10012,"msg": "authorization - root - createEmployeeRoleByRoot"}'
        )
        returns (bool)
    {
        require(
            _isExistEmployeeRole(_account) == false,
            '{"from": "Timekeeping.sol","code": 10007,"msg": "employee has been created"}'
        );
        for (
            uint idxPositionId = 0;
            idxPositionId < _positionIds.length;
            idxPositionId++
        ) {
            require(
                _positionIds[idxPositionId] != ROLE.ROOT &&
                    _positionIds[idxPositionId] != ROLE.EMPLOYEE,
                '{"from": "Timekeeping.sol","code": 10009,"msg": "position ids invalid"}'
            );
        }
        _createEmployeeRole(_account, _nickname, _positionIds);
        _initEmployeeAfterAddEmployeeRole(_account);
        return true;
    }

    function getAllEmployeeRole() public view returns (EmployeeRole[] memory) {
        return _getAllEmployeeRole();
    }

    function deleteEmployeeRole(
        address _account
    )
        public
        onlyRoot(
            '{"from": "Timekeeping.sol","code": 10012,"msg": "authorization - root - deleteEmployeeRole"}'
        )
        returns (bool)
    {
        _deleteEmployeeRole(_account);
        return true;
    }

    function updateEmployeeRole(
        address _account,
        ROLE[] memory _positionIds
    )
        public
        onlyRoot(
            '{"from": "Timekeeping.sol","code": 10013,"msg": "authorization - root - updateEmployeeRole"}'
        )
        returns (bool)
    {
        require(
            _isExistEmployeeRole(_account) == true,
            '{"from": "Timekeeping.sol","code": 10008,"msg": "employee not found by address - updateEmployeeRole"}'
        );
        for (
            uint idxPositionId = 0;
            idxPositionId < _positionIds.length;
            idxPositionId++
        ) {
            require(
                _positionIds[idxPositionId] != ROLE.ROOT &&
                    _positionIds[idxPositionId] != ROLE.EMPLOYEE,
                '{"from": "Timekeeping.sol","code": 10009,"msg": "position ids invalid"}'
            );
        }
        _updateEmployeeRole(_account, _positionIds);
        return true;
    }

    // ==================== RefCode ====================
    function getCurrentRefCode(address _employee)
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10016,"msg": "authorization - hr - getCurrentRefCode"}'
        )
        view returns (bytes32) 
    {
        return mRefCode[_employee];
    }

    function assignNewRefCodeToEmployee(
        address employee
    )
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10016,"msg": "authorization - hr - assignNewRefCodeToEmployee"}'
        )
        returns (bytes32)
    {
        return _assignNewRefCode(employee);
    }
    // ============================= REQUEST ============================= //

    function createLeavePermissionRequest(
        uint _startDateTime,
        uint _endDateTime,
        REASON_LEAVE_TYPE _reasonType,
        string memory _other
    )
        public
        onlyEmployee(
            '{"from": "Timekeeping.sol","code": 10030,"msg": "authorization - employee - createLeavePermissionRequest"}'
        )
        returns (Request memory)
    {
        return
            _createLeaveRequest(
                _startDateTime,
                _endDateTime,
                _reasonType,
                _other
            );
    }

    function createLateArrivalRequest(
        uint _dateTime,
        REASON_LATE_TYPE _reasonType,
        string memory _other
    )
        public
        onlyEmployee(
            '{"from": "Timekeeping.sol","code": 10031,"msg": "authorization - employee - createLateArrivalRequest"}'
        )
        returns (Request memory)
    {
        return _createLateRequest(_dateTime, _reasonType, _other);
    }

    function createComeBackSoonRequest(
        uint _dateTime,
        REASON_COME_BACK_SOON _reasonType,
        string memory _other
    )
        public
        onlyEmployee(
            '{"from": "Timekeeping.sol","code": 10032,"msg": "authorization - employee - createComeBackSoonRequest"}'
        )
        returns (Request memory)
    {
        return _createComeBackSoonRequest(_dateTime, _reasonType, _other);
    }

    function createOfferSalaryRequest(
        uint _currentSalary,
        uint _offserSalary,
        uint _dateTime,
        REASON_COME_OFFER_SALARY _reasonType,
        string memory _other
    )
        public
        onlyEmployee(
            '{"from": "Timekeeping.sol","code": 10033,"msg": "authorization - employee - createOfferSalaryRequest"}'
        )
        returns (Request memory)
    {
        return
            _createOfferSalaryRequest(
                _currentSalary,
                _offserSalary,
                _dateTime,
                _reasonType,
                _other
            );
    }

    function getOfferSalaryRequest()
        public
        view
        returns (FullOfferSalaryRequest memory)
    {
        Employee[] memory employeeArr = _getAllEmployee();
        address[] memory addressEmployees = new address[](employeeArr.length);
        for (uint i = 0; i < employeeArr.length; i++) {
            addressEmployees[i] = employeeArr[i].Wallet;
        }
        (
            Request[] memory requestArr,
            OfferSalaryRequest[] memory result
        ) = _getOfferSalaryRequestOfEmployees(addressEmployees);
        return
            FullOfferSalaryRequest({
                offerSalaryRequests: result,
                requests: requestArr
            });
    }

    function getOfferSalaryRequestOfEmployees(
        address[] memory _employees
    ) public view returns (FullOfferSalaryRequest memory) {
        (
            Request[] memory requestArr,
            OfferSalaryRequest[] memory result
        ) = _getOfferSalaryRequestOfEmployees(_employees);
        return
            FullOfferSalaryRequest({
                offerSalaryRequests: result,
                requests: requestArr
            });
    }

    function getOffetSalaryRequestOfMe()
        public
        view
        returns (FullOfferSalaryRequest memory)
    {
        address[] memory addressEmployees = new address[](1);
        addressEmployees[0] = msg.sender;
        (
            Request[] memory requestArr,
            OfferSalaryRequest[] memory result
        ) = _getOfferSalaryRequestOfEmployees(addressEmployees);
        return
            FullOfferSalaryRequest({
                offerSalaryRequests: result,
                requests: requestArr
            });
    }

    function createSubsidizeRequest(
        uint _allowance,
        uint _dateTime,
        REASON_COME_SUBSIDIZE _reasonType,
        string memory _other
    )
        public
        onlyEmployee(
            '{"from": "Timekeeping.sol","code": 10034,"msg": "authorization - employee - createSubsidizeRequest"}'
        )
        returns (Request memory)
    {
        return
            _createSubsidizeRequest(_allowance, _dateTime, _reasonType, _other);
    }

    function getSubsidizeRequest()
        public
        view
        returns (FullSubsidizeRequest memory)
    {
        Employee[] memory employeeArr = _getAllEmployee();
        address[] memory addressEmployees = new address[](employeeArr.length);
        for (uint i = 0; i < employeeArr.length; i++) {
            addressEmployees[i] = employeeArr[i].Wallet;
        }
        (
            Request[] memory requestArr,
            SubsidizeRequest[] memory result
        ) = _getSubsidizeRequestOfEmployees(addressEmployees);
        return
            FullSubsidizeRequest({
                subsidizeRequests: result,
                requests: requestArr
            });
    }

    function getSubsidizeRequestOfEmployees(
        address[] memory _employees
    ) public view returns (FullSubsidizeRequest memory) {
        (
            Request[] memory requestArr,
            SubsidizeRequest[] memory result
        ) = _getSubsidizeRequestOfEmployees(_employees);
        return
            FullSubsidizeRequest({
                subsidizeRequests: result,
                requests: requestArr
            });
    }

    function getSubsidizeRequestOfMe()
        public
        view
        returns (FullSubsidizeRequest memory)
    {
        address[] memory addressEmployees = new address[](1);
        addressEmployees[0] = msg.sender;
        (
            Request[] memory requestArr,
            SubsidizeRequest[] memory result
        ) = _getSubsidizeRequestOfEmployees(addressEmployees);
        return
            FullSubsidizeRequest({
                subsidizeRequests: result,
                requests: requestArr
            });
    }

    function createResignRequest(
        uint _dateTime,
        REASON_RESIGN _reasonType,
        string memory _other
    )
        public
        onlyEmployee(
            '{"from": "Timekeeping.sol","code": 10035,"msg": "authorization - employee - createResignRequest"}'
        )
        returns (Request memory)
    {
        return _createResignRequest(_dateTime, _reasonType, _other);
    }

    function getReviewRequestForHR() public view returns (Request[] memory) {
        return _getAllRequestsForHR();
    }

    function getReviewRequestForHRManager()
        public
        view
        returns (Request[] memory)
    {
        return _getAllRequestForHRManager();
    }

    function getRequestForEmployeeWithRequestType(
        REQUEST_TYPE requestType
    ) public view returns (Request[] memory) {
        return _getRequestByAddressAndType(msg.sender, requestType);
    }

    function updateRequestStatus(
        uint256 _requestId,
        REQUEST_STATUS _requestStatus
    )
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10017,"msg": "authorization - hr - updateRequestStatus"}'
        )
        returns (bool)
    {
        Request memory request = _getRequestById(_requestId);

        if (
            !hasRole(ROLE_HASH_HR_MANAGER, msg.sender) &&
            !hasRole(ROLE_HASH_ROOT, msg.sender)
        ) {
            require(
                _verifyRequestTypeForHR(request.Type),
                '{"from": "Timekeeping.sol","code": 12001,"msg": "HR does not permission to update the request"}'
            );
        }

        _updateRequestStatus(_requestId, _requestStatus);
        _handleAfterUpdateRequestStatus(_requestId, _requestStatus);
        _handleSendNotificationAfterUpdateRequest(request);

        return true;
    }

    function _handleAfterUpdateRequestStatus(
        uint256 _requestId,
        REQUEST_STATUS _requestStatus
    ) internal {
        Request memory request = _getRequestById(_requestId);
        if (request.Type == REQUEST_TYPE.LEAVE_PERMISSION) {
            if (_requestStatus != REQUEST_STATUS.APPROVAL) {
                return;
            }

            LeaveRequest memory leaveRequest = _getLeaveRequestDetail(
                _requestId
            );

            uint startYMD = DateTimeLibrary._getStartOfDateFromTimestamp(
                leaveRequest.StartDateTime
            );
            uint endYMD = DateTimeLibrary._getStartOfDateFromTimestamp(
                leaveRequest.EndDateTime
            );

            Shift[] memory shifts = _getShifts();
            for (
                uint ymd = startYMD;
                ymd <= endYMD;
                ymd = DateTimeLibrary._addDay(ymd, 1)
            ) {
                for (uint shiftIdx = 0; shiftIdx < shifts.length; shiftIdx++) {
                    if (
                        leaveRequest.StartDateTime <=
                        ymd + shifts[shiftIdx].CheckIn &&
                        ymd + shifts[shiftIdx].CheckOut <=
                        leaveRequest.EndDateTime
                    ) {
                        uint _yyyymmdd = DateTimeLibrary._getYYYYMMDD(ymd);
                        _updateShiftManagementAfterApprovalLeaveRequest(
                            _yyyymmdd,
                            request.Requester,
                            shifts[shiftIdx].ShiftId
                        );

                        ShiftManagement memory curr = _getShiftManagement(
                            _yyyymmdd,
                            request.Requester,
                            shifts[shiftIdx].ShiftId
                        );
                        curr.CheckInTime = shifts[shiftIdx].CheckIn;
                        curr.CheckOutTime = shifts[shiftIdx].CheckOut;

                        _handleSalaryAfterCheckout(
                            _yyyymmdd,
                            _getEmployeeDetailByAddress(request.Requester),
                            curr
                        );
                    }
                }
            }
            return;
        }

        if (request.Type == REQUEST_TYPE.LATE_ARRIVAL) {
            if (_requestStatus != REQUEST_STATUS.APPROVAL) {
                return;
            }

            LateRequest memory lateRequest = _getLateRequestDetail(_requestId);
            uint startYMD = DateTimeLibrary._getStartOfDateFromTimestamp(
                lateRequest.DateTime
            );
            Shift[] memory shifts = _getShifts();

            for (uint shiftIdx = 0; shiftIdx < shifts.length; shiftIdx++) {
                if (
                    startYMD + shifts[shiftIdx].CheckIn <
                    lateRequest.DateTime &&
                    lateRequest.DateTime < startYMD + shifts[shiftIdx].CheckOut
                ) {
                    uint _yyyymmdd = DateTimeLibrary._getYYYYMMDD(startYMD);
                    _updateShiftManagementAfterApprovalLateRequest(
                        _yyyymmdd,
                        request.Requester,
                        shifts[shiftIdx].ShiftId,
                        DateTimeLibrary._getTime(lateRequest.DateTime)
                    );
                    break;
                }
            }
            return;
        }

        if (request.Type == REQUEST_TYPE.COME_BACK_SOON) {
            if (_requestStatus != REQUEST_STATUS.APPROVAL) {
                return;
            }
            ComeBackSoonRequest
                memory comeBackSoonRequest = _getComeBackSoonRequestDetail(
                    _requestId
                );
            uint startYMD = DateTimeLibrary._getStartOfDateFromTimestamp(
                comeBackSoonRequest.DateTime
            );

            Shift[] memory shifts = _getShifts();

            for (uint shiftIdx = 0; shiftIdx < shifts.length; shiftIdx++) {
                if (
                    startYMD + shifts[shiftIdx].CheckIn <
                    comeBackSoonRequest.DateTime &&
                    comeBackSoonRequest.DateTime <
                    startYMD + shifts[shiftIdx].CheckOut
                ) {
                    uint _yyyymmdd = DateTimeLibrary._getYYYYMMDD(startYMD);
                    _updateShiftManagementAfterApprovalComeBackSoonRequest(
                        _yyyymmdd,
                        request.Requester,
                        shifts[shiftIdx].ShiftId,
                        DateTimeLibrary._getTime(comeBackSoonRequest.DateTime)
                    );
                    break;
                }
            }
            return;
        }

        if (request.Type == REQUEST_TYPE.OFFER_SALARY) {
            if (_requestStatus != REQUEST_STATUS.APPROVAL) {
                return;
            }
            OfferSalaryRequest
                memory reqOffSalary = _getOfferSalaryRequestDetail(_requestId);
            SalaryRequest memory salaryRequest;
            salaryRequest.Employee = request.Requester;
            salaryRequest.Amount = reqOffSalary.OfferSalary;
            salaryRequest.ActiveTime = reqOffSalary.DateTime;

            _addSalaryEmployee(salaryRequest);
            return;
        }

        if (request.Type == REQUEST_TYPE.SUBSIDIZE) {
            SubsidizeRequest memory reqSubsidize = _getSubsidizeRequestDetail(
                _requestId
            );
            Subsidize memory subsidize;
            subsidize.employee = request.Requester;
            subsidize.datetime = reqSubsidize.DateTime;
            subsidize.amount = reqSubsidize.Allowance;
            subsidize.reason = reqSubsidize.ReasonType;

            _createSubsidize(subsidize);

            return;
        }

        if (request.Type == REQUEST_TYPE.RESIGN) {
            _handleResignRequestAfterUpdate(request);

            return;
        }

        if (request.Type == REQUEST_TYPE.RULE) {
            _handleRuleRequestAfterUpdate(request);
            return;
        }

        if (request.Type == REQUEST_TYPE.IN_OUT_ON_BEHALF) {
            InOutOnBeHalfRequest
                memory inOutOnBeHalfRequest = _getInOutOnBehalfRequestDetail(
                    _requestId
                );
            uint attendanceId = inOutOnBeHalfRequest.AttendanceId;

            ON_BEHALF_STATUS status;
            if (_requestStatus == REQUEST_STATUS.APPROVAL) {
                status = ON_BEHALF_STATUS.HR_MANAGER_APPROVAL;
            } else {
                status = ON_BEHALF_STATUS.HR_MANAGER_REJECT;
            }
            _updateInOutOnBehalf(attendanceId, status);
            return;
        }

        if (request.Type == REQUEST_TYPE.SALARY_DEDUCATION) {
            SalaryDeducationRequest
                memory salaryDeducationRequest = _getSalaryDeducationRequestDetail(
                    request.RequestId
                );

            _createSalaryDeducation(
                SalaryDeducation({
                    Employee: salaryDeducationRequest.Employee,
                    Reason: salaryDeducationRequest.Other,
                    Amount: salaryDeducationRequest.Amount,
                    SalaryDeducationRequestId: salaryDeducationRequest.Id,
                    Date: salaryDeducationRequest.Date
                })
            );

            return;
        }
    }

    function _handleResignRequestAfterUpdate(Request memory _request) internal {
        if (_request.Status != REQUEST_STATUS.APPROVAL) {
            return ;
        }

        ResignRequest memory resignRequest = _getResignRequestDetail(
            _request.RequestId
        );

        // TODO: Handle update resign data to employee list
    }

    function _handleRuleRequestAfterUpdate(Request memory _request) internal {
        if (_request.Status == REQUEST_STATUS.APPROVAL) {
            RuleRequest memory ruleRequestDetail = _getRuleRequestDetail(
                _request.RequestId
            );
            _addNewRuleAfterApprovalRequest(_request, ruleRequestDetail);
        }
    }

    function _checkPermissionForRequest(
        uint _requestId,
        address _employee
    ) internal view returns (bool) {
        if (
            hasRole(ROLE_HASH_ROOT, _employee) ||
            hasRole(ROLE_HASH_HR_MANAGER, _employee)
        ) {
            return true;
        }

        Request memory request = _getRequestById(_requestId);

        if (
            hasRole(ROLE_HASH_HR, _employee) &&
            _verifyRequestTypeForHR(request.Type)
        ) {
            return true;
        }

        return request.Requester == _employee;
    }

    function getLeaveRequestDetail(
        uint _requestId
    ) public view returns (LeaveRequest memory) {
        require(
            _checkPermissionForRequest(_requestId, msg.sender),
            '{"from": "Timekeeping.sol","code": 12006,"msg": "permission - getLeaveRequestDetail"}'
        );
        return _getLeaveRequestDetail(_requestId);
    }

    function getLateRequestDetail(
        uint _requestId
    ) public view returns (LateRequest memory) {
        require(
            _checkPermissionForRequest(_requestId, msg.sender),
            '{"from": "Timekeeping.sol","code": 12007,"msg": "permission - getLateRequestDetail"}'
        );
        return _getLateRequestDetail(_requestId);
    }

    function getComeBackSoonRequestDetail(
        uint _requestId
    ) public view returns (ComeBackSoonRequest memory) {
        require(
            _checkPermissionForRequest(_requestId, msg.sender),
            '{"from": "Timekeeping.sol","code": 12008,"msg": "permission - getComeBackSoonRequestDetail"}'
        );
        return _getComeBackSoonRequestDetail(_requestId);
    }

    function getOfferSalaryRequestDetail(
        uint _requestId
    ) public view returns (OfferSalaryRequest memory) {
        require(
            _checkPermissionForRequest(_requestId, msg.sender),
            '{"from": "Timekeeping.sol","code": 12009,"msg": "permission - getOfferSalaryRequestDetail"}'
        );
        return _getOfferSalaryRequestDetail(_requestId);
    }

    function getSubsidizeRequestDetail(
        uint _requestId
    ) public view returns (SubsidizeRequest memory) {
        require(
            _checkPermissionForRequest(_requestId, msg.sender),
            '{"from": "Timekeeping.sol","code": 12010,"msg": "permission - getSubsidizeRequestDetail"}'
        );
        return _getSubsidizeRequestDetail(_requestId);
    }

    function getResignRequestDetail(
        uint _requestId
    ) public view returns (ResignRequest memory) {
        require(
            _checkPermissionForRequest(_requestId, msg.sender),
            '{"from": "Timekeeping.sol","code": 12011,"msg": "permission - getResignRequestDetail"}'
        );
        return _getResignRequestDetail(_requestId);
    }

    function getSalaryDeducationRequestDetail(
        uint _requestId
    ) public view returns (SalaryDeducationRequest memory) {
        require(
            _checkPermissionForRequest(_requestId, msg.sender),
            '{"from": "Timekeeping.sol","code": 12012,"msg": "permission - getResignRequestDetail"}'
        );
        return _getSalaryDeducationRequestDetail(_requestId);
    }

    function getInOutOnBehalfRequestDetail(
        uint _requestId
    ) public view returns (InOutOnBeHalfRequest memory) {
        require(
            _checkPermissionForRequest(_requestId, msg.sender),
            '{"from": "Timekeeping.sol","code": 12013,"msg": "permission - getInOutOnBehalfRequestDetail"}'
        );
        return _getInOutOnBehalfRequestDetail(_requestId);
    }

    function getRuleRequesttDetail(
        uint _requestId
    ) public view returns (RuleRequest memory) {
        require(
            _checkPermissionForRequest(_requestId, msg.sender),
            '{"from": "Timekeeping.sol","code": 12014,"msg": "permission - getRuleRequesttDetail"}'
        );
        return _getRuleRequestDetail(_requestId);
    }
    // ============================= SETTING ============================= //

    // Setting - SettingRule
    function getSettingRules() public view returns (SettingRule[] memory) {
        return _getSettingRule();
    }

    function getSettingRulesByRuleId(
        uint256 ruleId
    ) public view returns (SettingRule memory) {
        return _getSettingRuleByRuleId(ruleId);
    }

    function createSettingRule(
        VIOLATION_TYPE _violationType,
        uint _time,
        uint _quantity,
        CONDITION_TYPE _conditionType,
        PUNISH_TYPE _punishType,
        SALARY_DEDUCATION_TYPE _salaryDeducation
    )
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10018,"msg": "authorization - hr - createSettingRule"}'
        )
        returns (bool)
    {
        if (
            hasRole(ROLE_HASH_HR_MANAGER, msg.sender) ||
            hasRole(ROLE_HASH_ROOT, msg.sender)
        ) {
            SettingRule memory rule;
            rule.ViolationType = _violationType;
            rule.Time = _time;
            rule.Quantity = _quantity;
            rule.ConditionType = _conditionType;
            rule.PunishType = _punishType;
            rule.SalaryDeducationType = _salaryDeducation;
            _createSettingRule(rule);
        } else {
            Request memory request = _createRuleRequest(
                _violationType,
                _time,
                _quantity,
                _conditionType,
                _punishType,
                _salaryDeducation
            );
            _handleSendNotificationAfterCreateRequest(request);
        }

        return true;
    }

    function updateSettingRule(
        uint256 _ruleId,
        VIOLATION_TYPE _violationType,
        uint _time,
        uint _quantity,
        CONDITION_TYPE _conditionType,
        SALARY_DEDUCATION_TYPE _salaryDeducationType
    )
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10019,"msg": "authorization - hr - updateSettingRule"}'
        )
        returns (bool)
    {
        SettingRule memory rule = _getSettingRuleByRuleId(_ruleId);
        rule.ViolationType = _violationType;
        rule.Time = _time;
        rule.Quantity = _quantity;
        rule.ConditionType = _conditionType;
        rule.SalaryDeducationType = _salaryDeducationType;

        _updateSettingRule(_ruleId, rule);
        return true;
    }

    // Setting - Time
    function getSettingTime() public view returns (SettingTime memory) {
        return _getSettingTime();
    }

    function updateSettingTime(
        FORM_OF_WORK formOFWork,
        Shift[] memory shifts,
        DayOffRequest[] memory dayOff,
        OVERTIME overtime,
        uint permission,
        SALARY_CLOSING_DATE salaryClosingDate
    )
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10020,"msg": "authorization - hr - updateSettingTime"}'
        )
        returns (bool)
    {
        SettingTime memory settingTime;

        settingTime.FormOFWork = formOFWork;
        settingTime.Overtime = overtime;
        settingTime.Permission = permission;
        settingTime.SalaryClosingDate = salaryClosingDate;
        settingTime.NumberOfShift = shifts.length;
        settingTime.Shifts = new Shift[](shifts.length);
        for (uint256 i = 0; i < shifts.length; i++) {
            settingTime.Shifts[i] = shifts[i];
        }
        DayOff[] memory dayOffs = new DayOff[](dayOff.length);

        for (uint256 i = 0; i < dayOff.length; i++) {
            Shift memory shift = shifts[dayOff[i].shiftId - 1];

            if (formOFWork == FORM_OF_WORK.BY_DATE) {
                if (dayOff[i].shiftNum == 1) {
                    require(
                        shift.CheckIn < shift.BreakTimeFrom,
                        '{"from": "Timekeeping.sol","code": 13003,"msg": "CheckIn must be less than BreakTimeFrom"}'
                    );
                    dayOffs[i] = DayOff({
                        shiftId: shift.ShiftId,
                        from: shift.CheckIn,
                        to: shift.BreakTimeFrom,
                        time: dayOff[i].time
                    });
                } else if (dayOff[i].shiftNum == 2) {
                    require(
                        shift.BreakTimeTo < shift.CheckOut,
                        '{"from": "Timekeeping.sol","code": 13004,"msg": "BreakTimeTo must be less than CheckOut"}'
                    );
                    dayOffs[i] = DayOff({
                        shiftId: shift.ShiftId,
                        from: shift.BreakTimeTo,
                        to: shift.CheckOut,
                        time: dayOff[i].time
                    });
                }

                continue;
            }

            dayOffs[i] = DayOff({
                shiftId: shift.ShiftId,
                from: shift.CheckIn,
                to: shift.CheckOut,
                time: dayOff[i].time
            });
        }

        settingTime.DayOffs = dayOffs;
        _updateSettingTime(settingTime);
        return true;
    }

    // Setting - Address
    function getSettingAddress() public view returns (SettingAddress memory) {
        return _getSettingAddress();
    }

    function updateSettingAddress(
        uint _semiClosed,
        WorkPlace[] memory _workPlaces
    )
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10021,"msg": "authorization - hr - updateSettingAddress"}'
        )
        returns (bool)
    {
        SettingAddress memory settingAddress;
        settingAddress.SemiClosed = _semiClosed;

        settingAddress.WorkPlaces = new WorkPlace[](_workPlaces.length);
        for (uint256 i = 0; i < _workPlaces.length; i++) {
            settingAddress.WorkPlaces[i] = _workPlaces[i];
        }

        _updateSettingAddress(settingAddress);
        return true;
    }

    function getSettingAttendanceLimit()
        public
        view
        returns (EmployeeSettingAttendanceLimit[] memory)
    {
        Employee[] memory employees = _getAllEmployee();
        return _getSettingAttendanceLimit(employees);
    }

    function updateSettingAttendaceLimit(
        address[] memory employeeAddress,
        ATTENDANCE_LIMIT_TYPE[] memory typeOfLimits
    )
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10022,"msg": "authorization - hr - updateSettingAttendaceLimit"}'
        )
        returns (bool)
    {
        require(
            employeeAddress.length == typeOfLimits.length,
            '{"from": "Timekeeping.sol","code": 12002,"msg": "the length of employees and attendent limit invalid"}'
        );
        _updateSettingAttendaceLimit(employeeAddress, typeOfLimits);
        return true;
    }

    function getSettingAddressForEmployee()
        public
        view
        returns (SettingAddressForEmployee memory settingAddressForEmployee)
    {
        settingAddressForEmployee.SettingAddressData = _getSettingAddress();
        settingAddressForEmployee
            .AttendanceLimitType = _getSettingAttendanceLimitForEmployee(
            msg.sender
        );

        return settingAddressForEmployee;
    }

    // ============================= START VIEW ID ============================= //
    function _generateViewId() internal returns (bytes32) {
        seedViewID = seedViewID + 1;
        return keccak256(abi.encodePacked(block.timestamp, msg.sender, seedViewID));
    }

    function createViewId(
        VIEW_ID_TYPE _type,
        uint _expiredTime
    )
        public
        onlyEmployee(
            '{"from": "Timekeeping.sol","code": 10036,"msg": "authorization - employee - createViewId"}'
        )
        returns (bool)
    {
        bytes32 id = _generateViewId();
        
        ViewID memory viewID;
        viewID.ID = id;
        viewID.Employee = msg.sender;
        viewID.Type = _type;
        viewID.ExpiredTime = _expiredTime;
        viewID.LastUpdate = block.timestamp;

        mBytes32ToViewId[id] = viewID;
        mAddressToViewIDs[msg.sender].push(id);

        return true;
    }

    function updateViewIdById(
        bytes32 id,
        VIEW_ID_TYPE _type,
        uint _expiredTime
    )
        public
        onlyEmployee(
            '{"from": "Timekeeping.sol","code": 10037,"msg": "authorization - employee - updateViewIdByIdx"}'
        )
        returns (bool)
    {
        require(mBytes32ToViewId[id].ID != 0x00,
            '{"from": "Timekeeping.sol","code": 15001,"msg": "viewid - the id not found - updateViewIdById"}'
        );

        require(mBytes32ToViewId[id].Employee == msg.sender,
            '{"from": "Timekeeping.sol","code": 15002,"msg": "viewid - authorization employee does not permission to update id - updateViewIdById"}'
        );

        mBytes32ToViewId[id].Type = _type;
        mBytes32ToViewId[id].ExpiredTime = _expiredTime;
        mBytes32ToViewId[id].LastUpdate = block.timestamp;

        return true;
    }

    function getViewID(bytes32 _id) public view returns (ViewID memory) {
        require(mBytes32ToViewId[_id].ID != 0x00,
            '{"from": "Timekeeping.sol","code": 15001,"msg": "viewid - the id not found - updateViewIdById"}'
        );

        require(mBytes32ToViewId[_id].Employee == msg.sender,
            '{"from": "Timekeeping.sol","code": 15002,"msg": "viewid - authorization employee does not permission to update id - updateViewIdById"}'
        );

        return mBytes32ToViewId[_id];
    }

    function getViewIDs() public view returns (ViewID[] memory) {
        uint len = mAddressToViewIDs[msg.sender].length;
        ViewID[] memory viewIDs = new ViewID[](len);
        for (uint idx = 0; idx < len; idx++) {
            viewIDs[idx] = mBytes32ToViewId[mAddressToViewIDs[msg.sender][idx]];
        }

        return viewIDs;
    }

    // ============================= END VIEW ID ============================= //


    function workPlaceExistsRequire(
        uint256 _workPlaceId,
        string memory message
    ) public view {
        require(_isWorkPlaceExists(_workPlaceId), message);
    }

    // ============================= ATTENDANCE ============================= //
    function checkInAttendance(
        WorkPlaceAttendance memory _workPlace
    ) public returns (bool) {
        workPlaceExistsRequire(
            _workPlace.WorkPlaceId,
            '{"from": "Timekeeping.sol","code": 17001,"msg": "workplace not found - checkInAttendance"}'
        );

        (uint _yyyymmdd, uint _time) = DateTimeLibrary._getYYYYMMDDAndTime(
            block.timestamp
        );

        Shift memory shift = _getShiftBasedOnCheckInTime(_time);
        require(
            shift.ShiftId != 0,
            '{"from": "Timekeeping.sol","code": 14001,"msg": "time shift not found - checkInAttendance"}'
        );

        Attendance memory attendance;
        attendance.Type = ATTENDANCE_TYPE.CHECK_IN;
        attendance.Employee = msg.sender;
        attendance.YYYYMMDD = _yyyymmdd;
        attendance.Time = _time;
        attendance.WorkPlaceAttendance = _workPlace;
        attendance.Note = "";
        attendance.ShiftId = shift.ShiftId;
        _createAttendance(attendance);
        _updateShiftManagementAfterCheckin(_yyyymmdd, msg.sender, shift, _time);
        handleAutoRule(_yyyymmdd, attendance, _time);

        return true;
    }

    function handleAutoRule(
        uint _yyyymmdd,
        Attendance memory attendance,
        uint _time
    ) internal {
        ShiftManagement memory current = _getShiftManagement(
            _yyyymmdd,
            attendance.Employee,
            attendance.ShiftId
        );

        if (current.ShiftStatus == SHIFT_STATUS.LATE) {
            SettingRule[] memory rules = _getSettingRule();

            for (uint idx = 0; idx < rules.length; idx++) {
                SettingRule memory rule = rules[idx];

                if (rule.Time > _time) continue;

                Notification memory noti;
                noti.ShiftManagementData = current;

                if (rule.PunishType == PUNISH_TYPE.WARNING) {
                    noti.Type = NOTIFICATION_TYPE.WARNING;
                    noti.Title = "Warning";
                    noti.Body = "Handler: Auto Rule handle";
                    _sendNotificationToAddress(attendance.Employee, noti);
                    return;
                }
                if (rule.PunishType == PUNISH_TYPE.FINE_OR_TICKET) {
                    noti.Type = NOTIFICATION_TYPE.FINE_TICKET;
                    noti.Title = "Ticker/Fine";
                    noti.Body = "Handler: Auto Rule handle";
                    _sendNotificationToAddress(attendance.Employee, noti);
                    return;
                }

                if (
                    current.LatePermissionStatus ==
                    PERMISSION_STATUS.PERMISSION &&
                    rule.ConditionType == CONDITION_TYPE.NO_PERMISSION
                ) continue;
                uint countLate = mTotalTimeKeepingForYM[_yyyymmdd / 100][
                    attendance.Employee
                ].CountLate;

                if (countLate < 1 || countLate % (rule.Quantity) != 0) continue;
                
                uint amount = _handleSalaryDeducationRequest(
                    rule.SalaryDeducationType,
                    _yyyymmdd,
                    current,
                    0
                );

                _createSalaryDeducation(
                    SalaryDeducation({
                        Employee: attendance.Employee,
                        Reason: "Auto rule",
                        Amount: amount,
                        SalaryDeducationRequestId: 0,
                        Date: _yyyymmdd
                    })
                );

                if (rule.PunishType == PUNISH_TYPE.SALARY_DEDUCATION_TYPE) {
                    noti.Type = NOTIFICATION_TYPE.SALARY_DEDUCATION_TYPE;
                    noti.Title = "Salary Deducation";
                    noti.Body = "Handler: Auto Rule handle";
                    _sendNotificationToAddress(attendance.Employee, noti);
                    return;
                }
            }
        }
    }

    function checkOutAttendance(
        WorkPlaceAttendance memory _workPlace
    ) public returns (bool) {
        workPlaceExistsRequire(
            _workPlace.WorkPlaceId,
            '{"from": "Timekeeping.sol","code": 17002,"msg": "workplace not found - checkOutAttendance"}'
        );
                
        (uint _yyyymmdd, uint _time) = DateTimeLibrary._getYYYYMMDDAndTime(
            block.timestamp
        );

        Shift memory shift = _getShiftBasedOnCheckOutTime(_time);

        require(
            shift.ShiftId != 0,
            '{"from": "Timekeeping.sol","code": 14002,"msg": "time shift not found - checkOutAttendance"}'
        );

        Attendance memory attendance;
        attendance.Type = ATTENDANCE_TYPE.CHECK_OUT;
        attendance.Employee = msg.sender;
        attendance.YYYYMMDD = _yyyymmdd;
        attendance.Time = _time;
        attendance.WorkPlaceAttendance = _workPlace;
        attendance.Note = "";
        _createAttendance(attendance);
        _updateShiftManagementAfterCheckout(
            _yyyymmdd,
            msg.sender,
            shift,
            _time
        );
        ShiftManagement memory current = _getShiftManagement(
            attendance.YYYYMMDD,
            attendance.Employee,
            shift.ShiftId
        );

        EmployeeDetail memory resultEmployee = _getEmployeeDetailByAddress(
            attendance.Employee
        );

        _handleSalaryAfterCheckout(
            attendance.YYYYMMDD,
            resultEmployee,
            current
        );
        return true;
    }

    // ============ START OVERTIME ============ //

    function overtimeAttendance(
        WorkPlaceAttendance memory _workPlace,
        string memory _reason
    )
        public
        onlyEmployee(
            '{"from": "Timekeeping.sol","code": 10038,"msg": "authorization - employee - overtimeAttendance"}'
        )
        returns (bool)
    {
        workPlaceExistsRequire(
            _workPlace.WorkPlaceId,
            '{"from": "Timekeeping.sol","code": 17003,"msg": "workplace not found - overtimeAttendance"}'
        );
        uint blockTime = block.timestamp;
        (uint _yyyymmdd, uint _time) = DateTimeLibrary._getYYYYMMDDAndTime(
            blockTime
        );
        Attendance memory attendance;
        attendance.Type = ATTENDANCE_TYPE.OVER_TIME;
        attendance.Employee = msg.sender;
        attendance.YYYYMMDD = _yyyymmdd;
        attendance.Time = _time;
        attendance.WorkPlaceAttendance = _workPlace;
        attendance.Reason = _reason;
        Attendance memory newAttendanceOvertime = _createAttendance(attendance);

        Shift memory shift = _getLastShiftForOvertime();

        _updateAfterOvertime(newAttendanceOvertime, shift);

        SettingTime memory settingTimeG = _getSettingTime();
        if (settingTimeG.Overtime == OVERTIME.SALARY) {
            EmployeeDetail memory resultEmployee = _getEmployeeDetailByAddress(
                attendance.Employee
            );
            (uint salaryPerMinute, ) = getSalaryOfEmployeeInMonth(
                blockTime,
                resultEmployee
            );
            uint totalTimeSeconds = _time - shift.CheckOut;
           _createOTSalary(
                OTSalary({
                    employee:  attendance.Employee,
                    totalTime: totalTimeSeconds,
                    amount: salaryPerMinute * (totalTimeSeconds / 60),
                    datetime: blockTime
                }),
                _yyyymmdd
            );
        }

        return true;
    }

    function getAttendanceOvertimePerMonth(
        uint _yyyymm
    ) public view returns (Attendance[] memory) {
        return _getAttendanceOverviewPerMonth(_yyyymm, msg.sender);
    }

    // ============ END OVERTIME ============ //

    function checkInOnBehalfAttendance(
        WorkPlaceAttendance memory _workPlace,
        string memory _reason
    )
        public
        onlyEmployee(
            '{"from": "Timekeeping.sol","code": 10039,"msg": "authorization - employee - checkInOnBehalfAttendance"}'
        )
        returns (bool)
    {
        workPlaceExistsRequire(
            _workPlace.WorkPlaceId,
            '{"from": "Timekeeping.sol","code": 17004,"msg": "workplace not found - checkInOnBehalfAttendance"}'
        );
        (uint _yyyymmdd, uint _time) = DateTimeLibrary._getYYYYMMDDAndTime(
            block.timestamp
        );
        Shift memory shift = _getShiftBasedOnCheckInTime(_time);
        require(
            shift.ShiftId != 0,
            '{"from": "Timekeeping.sol","code": 14003,"msg": "time shift not found - checkInOnBehalfAttendance"}'
        );

        Attendance memory attendance;
        attendance.Type = ATTENDANCE_TYPE.CHECK_IN_ON_BEHALF;
        attendance.Employee = msg.sender;
        attendance.YYYYMMDD = _yyyymmdd;
        attendance.Time = _time;
        attendance.WorkPlaceAttendance = _workPlace;
        attendance.Reason = _reason;
        attendance.ShiftId = shift.ShiftId;
        _createAttendance(attendance);

        return true;
    }

    function checkOutOnBehalfAttendance(
        WorkPlaceAttendance memory _workPlace,
        string memory _reason
    )
        public
        onlyEmployee(
            '{"from": "Timekeeping.sol","code": 10040,"msg": "authorization - employee - checkOutOnBehalfAttendance"}'
        )
        returns (bool)
    {
        workPlaceExistsRequire(
            _workPlace.WorkPlaceId,
            '{"from": "Timekeeping.sol","code": 17005,"msg": "workplace not found - checkOutOnBehalfAttendance"}'
        );
        (uint _yyyymmdd, uint _time) = DateTimeLibrary._getYYYYMMDDAndTime(
            block.timestamp
        );
        Shift memory shift = _getShiftBasedOnCheckOutTime(_time);
        require(
            shift.ShiftId != 0,
            '{"from": "Timekeeping.sol","code": 14004,"msg": "time shift not found - checkOutOnBehalfAttendance"}'
        );

        Attendance memory attendance;
        attendance.Type = ATTENDANCE_TYPE.CHECK_OUT_ON_BEHALF;
        attendance.Employee = msg.sender;
        attendance.YYYYMMDD = _yyyymmdd;
        attendance.Time = _time;
        attendance.WorkPlaceAttendance = _workPlace;
        attendance.Reason = _reason;
        attendance.ShiftId = shift.ShiftId;
        _createAttendance(attendance);

        return true;
    }

    function getAttendanceForEmployee(
        uint _yyyymmdd
    ) public view returns (Attendance[] memory) {
        return _getAttendanceForEmployee(msg.sender, _yyyymmdd);
    }

    function getShiftManagementForEmployee(
        uint _yyyymmdd
    )
        public
        onlyEmployee(
            '{"from": "Timekeeping.sol","code": 10041,"msg": "authorization - employee - getShiftManagementForEmployee"}'
        )
        returns (ShiftManagement[] memory shiftManagements)
    {
        Shift[] memory shifts = _getShifts();
        shiftManagements = new ShiftManagement[](shifts.length);

        for (uint idx = 0; idx < shifts.length; idx++) {
            shiftManagements[idx] = _getShiftManagement(
                _yyyymmdd,
                msg.sender,
                shifts[idx].ShiftId
            );
        }
        return shiftManagements;
    }

    function getAttendanceById(
        uint _attendanceId
    ) public view returns (Attendance memory) {
        return _getAttendanceById(_attendanceId);
    }

    function getEmployeeManagement(
        uint _yyyymmdd
    )
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10023,"msg": "authorization - hr - getEmployeeManagement"}'
        )
        returns (ShiftManagement[] memory)
    {
        Employee[] memory employees = _getAllEmployee();
        SettingTime memory settingTime = _getSettingTime();

        ShiftManagement[] memory shiftManagements = new ShiftManagement[](
            employees.length * settingTime.NumberOfShift
        );

        for (
            uint idxEmployee = 0;
            idxEmployee < employees.length;
            idxEmployee++
        ) {
            address employeeAddress = employees[idxEmployee].Wallet;
            for (
                uint idxShift = 0;
                idxShift < settingTime.NumberOfShift;
                idxShift++
            ) {
                uint shiftId = settingTime.Shifts[idxShift].ShiftId;
                uint idx = idxEmployee * settingTime.NumberOfShift + idxShift;

                shiftManagements[idx] = _getShiftManagement(
                    _yyyymmdd,
                    employeeAddress,
                    shiftId
                );
            }
        }
        return shiftManagements;
    }

    function getInOutOnBehalfForHR()
        public
        returns (Attendance[] memory, ShiftManagement[] memory)
    {
        return _getInOutOnBehalfForHR();
    }
    function confirmOnBehalfByHR(
        uint _attendanceId
    )
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10024,"msg": "authorization - hr - confirmOnBehalfByHR"}'
        )
        returns (bool)
    {
        Attendance memory attendance = _getAttendanceById(_attendanceId);
        _updateInOutOnBehalf(_attendanceId, ON_BEHALF_STATUS.HR_CONFIRM);
        Request memory request = _createInOutOnBeHalfRequest(
            attendance.Employee,
            attendance.YYYYMMDD,
            attendance.Reason,
            attendance.AttendanceId
        );

        _handleSendNotificationAfterCreateRequest(request);

        Shift memory shift = _getSettingTime().Shifts[attendance.ShiftId - 1];

        if (attendance.Type == ATTENDANCE_TYPE.CHECK_IN_ON_BEHALF) {
            _updateShiftManagementAfterCheckin(
                attendance.YYYYMMDD,
                attendance.Employee,
                shift,
                attendance.Time
            );
        } else {
            _updateShiftManagementAfterCheckout(
                attendance.YYYYMMDD,
                attendance.Employee,
                shift,
                attendance.Time
            );
            ShiftManagement memory current = _getShiftManagement(
                attendance.YYYYMMDD,
                attendance.Employee,
                shift.ShiftId
            );

            EmployeeDetail memory resultEmployee = _getEmployeeDetailByAddress(
                attendance.Employee
            );
            _handleSalaryAfterCheckout(
                attendance.YYYYMMDD,
                resultEmployee,
                current
            );
        }

        return true;
    }

    function getEmployeeTurnover()
        public
        view
        returns (EmployeeTurnover[] memory)
    {
        Employee[] memory employees = _getAllEmployee();
        Request[] memory requests = _getAllRequest();

        EmployeeTurnover[] memory tmpEmployeeTurnover = new EmployeeTurnover[](
            employees.length + requests.length
        );
        uint count = 0;
        for (
            uint idxEmployee = 0;
            idxEmployee < employees.length;
            idxEmployee++
        ) {
            tmpEmployeeTurnover[count] = EmployeeTurnover({
                DateTime: employees[idxEmployee].OnboardDateTime,
                Employee: employees[idxEmployee].Wallet,
                Type: EMPLOYEE_TURNOVER_TYPE.ON_BOARD,
                RequestId: 0,
                ResignStatus: REQUEST_STATUS.UN_READ
            });
            count++;
            Request[] memory requestResigns = _getRequestByAddressAndType(
                employees[idxEmployee].Wallet,
                REQUEST_TYPE.RESIGN
            );
            for (
                uint idxRequest = 0;
                idxRequest < requestResigns.length;
                idxRequest++
            ) {
                ResignRequest memory requestResign = _getResignRequestDetail(
                    requestResigns[idxRequest].RequestId
                );
                tmpEmployeeTurnover[count] = EmployeeTurnover({
                    DateTime: requestResign.DateTime,
                    Employee: requestResigns[idxRequest].Requester,
                    Type: EMPLOYEE_TURNOVER_TYPE.RESIGN,
                    RequestId: requestResigns[idxRequest].RequestId,
                    ResignStatus: requestResigns[idxRequest].Status
                });
                count++;
            }
        }

        EmployeeTurnover[] memory employeeTurnover = new EmployeeTurnover[](
            count
        );
        for (uint i = 0; i < count; i++) {
            employeeTurnover[i] = tmpEmployeeTurnover[i];
        }

        return employeeTurnover;
    }

    function getHandleCase(
        uint _yyyymmdd
    ) public returns (ShiftManagement[] memory, HANDLE_CASE_STATUS[] memory) {
        Employee[] memory employees = _getAllEmployee();
        SettingTime memory settingTime = _getSettingTime();

        ShiftManagement[] memory tmpShiftManagements = new ShiftManagement[](
            employees.length * settingTime.NumberOfShift
        );
        HANDLE_CASE_STATUS[]
            memory tmpHandleCaseStatus = new HANDLE_CASE_STATUS[](
                employees.length * settingTime.NumberOfShift
            );
        uint count = 0;

        for (
            uint idxEmployee = 0;
            idxEmployee < employees.length;
            idxEmployee++
        ) {
            address employeeAddress = employees[idxEmployee].Wallet;
            for (
                uint idxShift = 0;
                idxShift < settingTime.NumberOfShift;
                idxShift++
            ) {
                uint shiftId = settingTime.Shifts[idxShift].ShiftId;

                ShiftManagement memory shiftManagement = _getShiftManagement(
                    _yyyymmdd,
                    employeeAddress,
                    shiftId
                );

                if (shiftManagement.ShiftStatus != SHIFT_STATUS.ON_SCHEDULE) {
                    if (
                        _checkShiftIsViolationCompanyRule(
                            shiftManagement,
                            settingTime.Shifts[idxShift]
                        ) == 0
                    ) {
                        tmpShiftManagements[count] = shiftManagement;
                        tmpHandleCaseStatus[count] = mHandleCaseStatus[
                            shiftManagement.ShiftManagementId
                        ];
                        count++;
                    }
                }
            }
        }

        ShiftManagement[] memory shiftManagements = new ShiftManagement[](
            count
        );
        HANDLE_CASE_STATUS[] memory handleCaseStatus = new HANDLE_CASE_STATUS[](
            count
        );
        for (uint i = 0; i < count; i++) {
            shiftManagements[i] = tmpShiftManagements[i];
            handleCaseStatus[i] = tmpHandleCaseStatus[i];
        }

        return (shiftManagements, handleCaseStatus);
    }

    function updateHandleCase(
        UpdateHandleCase memory reqHandlecase
    ) public returns (Request memory request) {
        mHandleCaseStatus[reqHandlecase.shiftManagementId] = HANDLE_CASE_STATUS
            .SOLVED;
        ShiftManagement memory shiftManagement = _getShiftManagementById(
            reqHandlecase.shiftManagementId
        );

        Notification memory noti;
        noti.ShiftManagementData = shiftManagement;

        if (reqHandlecase.punish == PUNISH_TYPE.WARNING) {
            noti.Type = NOTIFICATION_TYPE.WARNING;
            noti.Title = "Warning";
            noti.Body = "Handler: HR handle";
            _sendNotificationToAddress(shiftManagement.Employee, noti);
        }
        if (reqHandlecase.punish == PUNISH_TYPE.FINE_OR_TICKET) {
            noti.Type = NOTIFICATION_TYPE.FINE_TICKET;
            noti.Title = "Ticker/Fine";
            noti.Body = "Handler: HR handle";
            _sendNotificationToAddress(shiftManagement.Employee, noti);
        }
        if (reqHandlecase.punish == PUNISH_TYPE.SALARY_DEDUCATION_TYPE) {
            uint amount = _handleSalaryDeducationRequest(
                reqHandlecase.salaryDeducationType,
                reqHandlecase.date,
                shiftManagement,
                reqHandlecase.amountType
            );

            request = _createSalaryDeducationRequest(
                shiftManagement.Employee,
                reqHandlecase.violationType,
                reqHandlecase.date,
                reqHandlecase.other,
                reqHandlecase.salaryDeducationType,
                reqHandlecase.shiftManagementId,
                reqHandlecase.amountType,
                amount
            );

            noti.Type = NOTIFICATION_TYPE.REVIEW;
            noti.Title = UtilsLibrary.getRequestTypeName(request.Type);
            noti.Body = "Handler: HR handle";

            ROLE[] memory roles = _getHRRolesToNotification(request.RequestId);
            _setNotificationToEmployeeRole(noti, roles);
        }

        return request;
    }

    function _handleSalaryDeducationRequest(
        SALARY_DEDUCATION_TYPE _type,
        uint _date,
        ShiftManagement memory _shiftManagement,
        uint _amountType
    ) internal view returns (uint) {
        EmployeeDetail memory employeeDetail = _getEmployeeDetailByAddress(
            _shiftManagement.Employee
        );
        Shift memory shift = _getShiftById(_shiftManagement.ShiftId);
        uint timestamp = DateTimeLibrary._getTimestampFromYYYYMMDDTime(
            _date,
            shift.CheckIn
        );
        (
            uint salaryPerMinute,
            uint workMinutesOfDay
        ) = getSalaryOfEmployeeInMonth(timestamp, employeeDetail);
  
        return
            _handleAmountSalaryDeducationRequest(
                _type,
                salaryPerMinute * 60,
                _shiftManagement,
                workMinutesOfDay / 60,
                _amountType
            );
    }

    function handleSalaryPerMinute(
        uint _salary,
        uint minutesWork
    ) internal pure returns (uint) {
        uint salaryHour = _salary / minutesWork;

        return salaryHour;
    }

    function handleSalaryPerHour(
        uint _salary,
        uint minutesWork
    ) internal pure returns (uint) {
        uint salaryHour = _salary / (minutesWork / 60);
        return salaryHour;
    }

    function getSalaryOfEmployeeInMonth(
        uint _timestamp,
        EmployeeDetail memory _employee
    ) public view returns (uint, uint) {
        (uint year, uint month, ) = DateTimeLibrary.timestampToDate(_timestamp);

        (
            uint workMinutesOfDay,
            uint totalWorkMinutes
        ) = _getTotalWorkMinutesPerYM(year, month);
        uint salary = _employee.PositionSalary;
        SalaryRequest memory salaryRequest = _getSalaryRequestByAddress(
            _employee.Wallet
        );

        if (
            salaryRequest.ActiveTime > 0 &&
            salaryRequest.ActiveTime <= _timestamp
        ) {
            salary = salaryRequest.Amount;
        }

        uint salaryPerMinute = handleSalaryPerMinute(salary, totalWorkMinutes);

        return (salaryPerMinute, workMinutesOfDay);
    }

    // ============================= REPORTS ============================= //

    function getSummaryAttendance(
        uint _yyyymmdd,
        uint _shiftId
    )
        public
        onlyRoot(
            '{"from": "Timekeeping.sol","code": 10015,"msg": "authorization - root - getSummaryAttendance"}'
        )
        returns (SummaryAttendance memory summary)
    {
        Employee[] memory employees = _getAllEmployee();
        summary.TotalEmployees = employees.length;
        uint totalLate = 0;
        uint totalLeave = 0;
        for (uint idx = 0; idx < employees.length; idx++) {
            ShiftManagement memory shiftManagement = _getShiftManagement(
                _yyyymmdd,
                employees[idx].Wallet,
                _shiftId
            );
            if (shiftManagement.ShiftStatus == SHIFT_STATUS.LATE) {
                totalLate++;
                if (
                    shiftManagement.LatePermissionStatus ==
                    PERMISSION_STATUS.PERMISSION
                ) {
                    summary.TotalLatePermission++;
                }
            }
            if (shiftManagement.ShiftStatus == SHIFT_STATUS.LEAVE) {
                totalLeave++;
                if (
                    shiftManagement.LeavePermissionStatus ==
                    PERMISSION_STATUS.PERMISSION
                ) {
                    summary.TotalLeavePermission++;
                }
            }
        }

        summary.TotalLateNoPermission = totalLate - summary.TotalLatePermission;
        summary.TotalLeaveNoPermission =
            totalLeave -
            summary.TotalLeavePermission;

        return summary;
    }
    function getAvgInOutForMonth(
        uint _year
    ) public view returns (AvgInOutForYM[] memory) {
        return _getAvgInOutForMonth(_year);
    }

    function getTotalTimeKeeping(
        uint _year,
        uint _month
    ) public view returns (TotalTimeKeepingYM[] memory) {
        Employee[] memory _employees = _getAllEmployee();
        return _getTotalTimekeepingYM(_year, _month, _employees);
    }

    function getSummaryTimekeepingForEmployee(
        uint _year,
        uint _month
    ) public view returns (TimeKeepingSummaryPerMonth memory) {
        return _getSumaryTimeKeeping(msg.sender, _year, _month);
    }

    // ============ START NOTIFICATION ============ //

    /**
        After create new request, will create a new notification to Reviewer:
            - ROOT: ALl Notification
            - HR Manager: ALL Notification
            - HR: Leave, Late, & Come back soon
     */
    function _handleSendNotificationAfterCreateRequest(
        Request memory _request
    ) internal {
        ROLE[] memory roles = _getHRRolesToNotification(_request.RequestId);
        Employee memory employee = _getEmployeeByAddress(_request.Requester);

        Notification memory noti;
        noti.Type = NOTIFICATION_TYPE.REVIEW;
        noti.Title = UtilsLibrary.getRequestTypeName(_request.Type);
        noti.Body = string.concat("Requester ", employee.FullName);
        noti.RequestData = _request;
        _setNotificationToEmployeeRole(noti, roles);
    }

    function _handleSendNotificationAfterUpdateRequest(
        Request memory _request
    ) internal {
        Notification memory noti;
        noti.Title = UtilsLibrary.getRequestTypeName(_request.Type);
        noti.Body = UtilsLibrary.getRequestStatusName(_request.Status);
        noti.RequestData = _request;
        _sendNotificationToAddress(_request.Requester, noti);
    }

    function _setNotificationToEmployeeRole(
        Notification memory _noti,
        ROLE[] memory _roles
    ) internal {
        EmployeeRole[] memory employeeRoles = _getAllEmployeeRole();
        address[] memory tmpAddress = new address[](employeeRoles.length);
        uint count = 0;
        for (uint idx = 0; idx < employeeRoles.length; idx++) {
            if (!_verifyEmployeeHasPermission(employeeRoles[idx], _roles)) {
                continue;
            }

            tmpAddress[count] = employeeRoles[idx].Account;
            count++;
        }

        address[] memory addresses = new address[](count);
        for (uint idx = 0; idx < count; idx++) {
            addresses[idx] = tmpAddress[idx];
        }
        _sendNotificationToMultipleAddress(addresses, _noti);
    }

    function createAndSendNotificationToAllEmployee(
        NOTIFICATION_TYPE _type,
        uint _dateTimeFrom,
        uint _dateTimeTo
    )
        public
        onlyHR(
            '{"from": "Timekeeping.sol","code": 10025,"msg": "authorization - hr - createAndSendNotificationToAllEmployee"}'
        )
        returns (bool)
    {
        Employee[] memory employees = _getAllEmployee();
        address[] memory toAddresses = new address[](employees.length);
        for (uint idx = 0; idx < employees.length; idx++) {
            toAddresses[idx] = employees[idx].Wallet;
        }

        Notification memory notification;
        notification.Type = _type;
        notification.DateTimeFrom = _dateTimeFrom;
        notification.DateTimeTo = _dateTimeTo;

        notification.Title = DateTimeLibrary._getDateTimeInString(
            _dateTimeFrom
        );
        notification.Body = _getNotificationTypeName(_type);

        _sendNotificationToMultipleAddress(toAddresses, notification);
        return true;
    }
    // ============ END NOTIFICATION ============ //

    function _handleAmountSalaryDeducationRequest(
        SALARY_DEDUCATION_TYPE _salaryDeducationType,
        uint _salaryHour,
        ShiftManagement memory _shiftManagement,
        uint _workHour,
        uint _type
    ) public view returns (uint) {
        (, Shift memory shift) = _getMinuteAndShiftWorkById(
            _shiftManagement.ShiftId
        );

        uint minutesLate = (_shiftManagement.CheckInTime - shift.CheckIn) / 60;

        require(
            minutesLate > 0,
            '{"from": "Timekeeping.sol","code": 12005,"msg": "time to choose not to be late"}'
        );

        if (_salaryDeducationType == SALARY_DEDUCATION_TYPE.DAY) {
            return _salaryHour * _workHour;
        }

        if (_salaryDeducationType == SALARY_DEDUCATION_TYPE.HALF_DAY) {
            return _salaryHour * (_workHour / 2);
        }
        if (_salaryDeducationType == SALARY_DEDUCATION_TYPE.HOUR) {
            if (minutesLate < 60) {
                return _salaryHour / 1;
            }

            return _salaryHour / (minutesLate / 60);
        }
        if (_salaryDeducationType == SALARY_DEDUCATION_TYPE.MINUTE) {
            return (_salaryHour / 60) * minutesLate;
        }

        return _type;
    }

    function _handleSalaryAfterCheckout(
        uint _yyyymmdd,
        EmployeeDetail memory _employee,
        ShiftManagement memory _shiftManagement
    ) internal {
        uint timestamp = DateTimeLibrary._getTimestampFromYYYYMMDDTime(
            _yyyymmdd,
            _shiftManagement.CheckOutTime
        );
        (uint salaryPerMinute, ) = getSalaryOfEmployeeInMonth(
            timestamp,
            _employee
        );
      
        Shift memory shift = _getShiftById(_shiftManagement.ShiftId);
        uint timeWork = _getTotalTimeOfShift(shift);
        timeWork = _handleComeBackSoon(
            timeWork,
            _shiftManagement.CheckOutTime,
            shift.CheckOut
        );
 
        Salary memory modelSalary;
        modelSalary.employee = _employee.Wallet;
        modelSalary.amount = salaryPerMinute * (timeWork / 60);
        modelSalary.ShiftManagementId = _shiftManagement.ShiftManagementId;
        modelSalary.datetime = timestamp;
        SettingTime memory settingTime = _getSettingTime();
        _createSalary(settingTime.Shifts.length, modelSalary, _yyyymmdd, shift);
    }

    function _handleComeBackSoon(
        uint _timeWork,
        uint _checkoutTime,
        uint _shiftCheckout
    ) internal returns (uint) {
        if (_checkoutTime < _shiftCheckout) {
            return _timeWork - (_shiftCheckout - _checkoutTime);
        }
        return _timeWork;
    }

    // Salary Deducation Request
    function getSalaryDeducationRequestOfEmployeesByYYYYMMs(
        address[] memory _employees,
        uint[] memory _yyyymms
    ) public view returns (FullSalaryDeducationRequest memory) {
        (
            Request[] memory requestArr,
            SalaryDeducationRequest[] memory result
        ) = _getSalaryDeducationRequestOfEmployeesByYYYYMMs(
                _employees,
                _yyyymms
            );
        return
            FullSalaryDeducationRequest({
                salaryDeducationRequests: result,
                requests: requestArr
            });
    }

    function getSalaryDeducationRequestByYYYYMMs(
        uint[] memory _yyyymms
    ) public view returns (FullSalaryDeducationRequest memory) {
        Employee[] memory employeeArr = _getAllEmployee();
        address[] memory addressEmployees = new address[](employeeArr.length);
        for (uint i = 0; i < employeeArr.length; i++) {
            addressEmployees[i] = employeeArr[i].Wallet;
        }
        (
            Request[] memory requestArr,
            SalaryDeducationRequest[] memory result
        ) = _getSalaryDeducationRequestOfEmployeesByYYYYMMs(
                addressEmployees,
                _yyyymms
            );
        return
            FullSalaryDeducationRequest({
                salaryDeducationRequests: result,
                requests: requestArr
            });
    }

    function getSalaryDeducationRequestOfMeByYYYYMMs(
        uint[] memory _yyyymms
    ) public view returns (FullSalaryDeducationRequest memory) {
        address[] memory addressEmployees = new address[](1);
        addressEmployees[0] = msg.sender;
        (
            Request[] memory requestArr,
            SalaryDeducationRequest[] memory result
        ) = _getSalaryDeducationRequestOfEmployeesByYYYYMMs(
                addressEmployees,
                _yyyymms
            );
        return
            FullSalaryDeducationRequest({
                salaryDeducationRequests: result,
                requests: requestArr
            });
    }

    // Salary Deducation
    function getSalaryDeducationOfEmployeesByYYYYMMs(
        address[] memory _employees,
        uint[] memory _yyyymms
    ) public view returns (SalaryDeducation[] memory) {
        return _getSalaryDeducationOfEmployeesByYYYYMMs(_employees, _yyyymms);
    }

    function getSalaryDeducationByYYYYMMs(
        uint[] memory _yyyymms
    ) public view returns (SalaryDeducation[] memory) {
        Employee[] memory employeeArr = _getAllEmployee();
        address[] memory addressEmployees = new address[](employeeArr.length);
        for (uint i = 0; i < employeeArr.length; i++) {
            addressEmployees[i] = employeeArr[i].Wallet;
        }
        return
            _getSalaryDeducationOfEmployeesByYYYYMMs(
                addressEmployees,
                _yyyymms
            );
    }

    function getSalaryDeducationOfMeByYYYYMMs(
        uint[] memory _yyyymms
    ) public view returns (SalaryDeducation[] memory) {
        address[] memory addressEmployees = new address[](1);
        addressEmployees[0] = msg.sender;

        return
            _getSalaryDeducationOfEmployeesByYYYYMMs(
                addressEmployees,
                _yyyymms
            );
    }

    // Salary

    function getSalaryOfEmployeesByYYYYMMs(
        address[] memory _employees,
        uint[] memory _yyyymms
    ) public view returns (Salary[] memory) {
        return
            _getSalaryOfEmployeesByYYYYMMs(
                _employees,
                _yyyymms
            );
    }

    function getSalaryByYYYYMMs(
        uint[] memory _yyyymms
    ) public view returns (Salary[] memory) {
        Employee[] memory employeeArr = _getAllEmployee();
        address[] memory addressEmployees = new address[](employeeArr.length);
        for (uint i = 0; i < employeeArr.length; i++) {
            addressEmployees[i] = employeeArr[i].Wallet;
        }
       
        return
            _getSalaryOfEmployeesByYYYYMMs(
                addressEmployees,
                _yyyymms
            );
    }

    function getSalaryOfMeByYYYYMMs(
        uint[] memory _yyyymms
    ) public view returns (Salary[] memory) {
        address[] memory addressEmployees = new address[](1);
        addressEmployees[0] = msg.sender;

        return
            _getSalaryOfEmployeesByYYYYMMs(
                addressEmployees,
                _yyyymms
            );
    }

    function getOTSalaryOfEmployeesByYYYYMMs(
        address[] memory _employees,
        uint[] memory _yyyymms
    ) public view returns (OTSalary[] memory) {
        return _getOTSalaryOfEmployeesByYYYYMMs(_employees, _yyyymms);
    }

    function getOTSalaryByYYYYMMs(
        uint[] memory _yyyymms
    ) public view returns (OTSalary[] memory) {
        Employee[] memory employeeArr = _getAllEmployee();
        address[] memory addressEmployees = new address[](employeeArr.length);
        for (uint i = 0; i < employeeArr.length; i++) {
            addressEmployees[i] = employeeArr[i].Wallet;
        }
        return _getOTSalaryOfEmployeesByYYYYMMs(addressEmployees, _yyyymms);
    }

    function getOTSalaryOfMeByYYYYMMs(
        uint[] memory _yyyymms
    ) public view returns (OTSalary[] memory) {
        address[] memory addressEmployees = new address[](1);
        addressEmployees[0] = msg.sender;
        return _getOTSalaryOfEmployeesByYYYYMMs(addressEmployees, _yyyymms);
    }

    function getTotalSalaryEmployeeByYYYYMM(
        address _employee,
        uint _yyyymm
    ) public view returns (uint) {
        return _getTotalSalaryEmployeeByYYYYMM(_employee, _yyyymm);
    }

    function getTotalSalaryOfMeByYYYYMMs(
        uint[] memory _yyyymms
    ) public view returns (uint[] memory result) {
        address[] memory addressEmployees = new address[](1);
        addressEmployees[0] = msg.sender;
        return _getTotalSalaryEmployeesByYYYYMMs(addressEmployees, _yyyymms)[0];
    }

    function getTotalSalaryByYYYYMMs(
        uint[] memory _yyyymms
    ) public view returns (uint[][] memory result) {
        Employee[] memory employeeArr = _getAllEmployee();
        address[] memory addressEmployees = new address[](employeeArr.length);
        for (uint i = 0; i < employeeArr.length; i++) {
            addressEmployees[i] = employeeArr[i].Wallet;
        }

        return _getTotalSalaryEmployeesByYYYYMMs(addressEmployees, _yyyymms);
    }

    function getTotalSalaryOfEmployeesByYYYYMMs(
        address[] memory _employees,
        uint[] memory _yyyymms
    ) public view returns (uint[][] memory result) {
        return _getTotalSalaryEmployeesByYYYYMMs(_employees, _yyyymms);
    }

    function getSubsidizesByAddressOfMe()
        public
        view
        returns (Subsidize[] memory)
    {
        return _getSubsidizesByAddress(msg.sender);
    }

    function getSubsidizesByAddress(
        address _employee
    ) public view returns (Subsidize[] memory) {
        return _getSubsidizesByAddress(_employee);
    }

    // ============================= START CRONJOB ============================= //
    function handleFinnalShift(
        uint _yyyymmdd,
        uint _shiftId
    ) public returns (bool) {
        if (mFinalShift[_yyyymmdd][_shiftId]) {
            return true;
        }

        Employee[] memory employees = _getAllEmployee();
        for (uint idx = 0; idx < employees.length; idx++) {
            ShiftManagement memory shiftManagement = _getShiftManagement(
                _yyyymmdd,
                employees[idx].Wallet,
                _shiftId
            );
            if (
                shiftManagement.ShiftStatus == SHIFT_STATUS.LEAVE &&
                shiftManagement.LeavePermissionStatus ==
                PERMISSION_STATUS.NO_PERMISSION
            ) {
                mTotalTimeKeepingForYM[_yyyymmdd / 100][employees[idx].Wallet]
                    .CountLeave++;
            }
        }

        mFinalShift[_yyyymmdd][_shiftId] = true;
        return true;
    }
    // ============================= END CRONJOB ============================= //
}
