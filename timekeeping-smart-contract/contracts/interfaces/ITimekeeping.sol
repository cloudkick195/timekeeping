// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

interface ITimekeeping {
    enum ROLE {
        ROOT,
        HR_MANAGER,
        HR,
        ACCOUNTANT,
        EMPLOYEE
    }

    struct EmployeeRole {
        address Account;
        string Nickname;
        uint LastUpdate;
        ROLE[] PositionIds;
    }

    // Employee
    struct Employee {
        address Wallet;
        string FullName;
        string Location;
        uint DepartmentId;
        uint PositionId;
        string Branch;
        uint Sex;
        uint64 DateOfBirth;
        uint64 PhoneNumber;
        string Email;
        uint OnboardDateTime;
    }

    struct EmployeeDetail {
        address Wallet;
        uint Status;
        uint TypeOfWork;
        uint TypeOfContract;
        uint PositionSalary;
        uint TaxableSalary;
        uint PersonalIncomeTax;
        string PermanentAddress;
        uint NumberOfDependents;
        uint AcademicLevel;
        string ID;
        string TaxId;
        string HealthInsuranceId;
        string SocialInsuranceId;
        bool HasResume;
        bool HasBirthCertificate;
        bool HasCitizenIdentification;
        bool HasHouseRegistrationBook;
        bool HasHealthCertification;
        bool HasGraduationDegree;
    }

    // Setting
    // Setting - Address
    struct SettingAddress {
        WorkPlace[] WorkPlaces;
        uint SemiClosed;
        uint LastUpdate;
    }

    enum ATTENDANCE_LIMIT_TYPE {
        FREE_ATTENDANCE,
        ONLY_ALLOW_AT_WORK
    }

    struct EmployeeSettingAttendanceLimit {
        address Employee;
        ATTENDANCE_LIMIT_TYPE AttendanceLimitType;
    }

    // Setting - Rule
    struct SettingRule {
        uint256 RuleId;
        VIOLATION_TYPE ViolationType;
        uint Time;
        uint Quantity;
        CONDITION_TYPE ConditionType;
        PUNISH_TYPE PunishType;
        SALARY_DEDUCATION_TYPE SalaryDeducationType;
        uint LastUpdate;
    }

    // Attendance

    enum ATTENDANCE_TYPE {
        CHECK_IN,
        CHECK_OUT,
        OVER_TIME,
        CHECK_IN_ON_BEHALF,
        CHECK_OUT_ON_BEHALF
    }

    enum ON_BEHALF_STATUS {
        INIT,
        HR_CONFIRM,
        HR_MANAGER_APPROVAL,
        HR_MANAGER_REJECT
    }
    struct Attendance {
        uint256 AttendanceId;
        address Employee;
        ATTENDANCE_TYPE Type;
        uint Time; // In seconds
        uint YYYYMMDD; // Format: YYYYMMDD
        WorkPlace WorkPlace;
        string Reason;
        string Note;
        uint LastUpdate;
        uint ShiftId;
        ON_BEHALF_STATUS OnBehalfStatus;
    }

    struct SummaryAttendance {
        uint TotalEmployees;
        uint TotalLeavePermission;
        uint TotalLeaveNoPermission;
        uint TotalLatePermission;
        uint TotalLateNoPermission;
    }

    struct Shift {
        uint ShiftId;
        uint CheckIn;
        uint CheckOut;
        uint BreakTimeFrom;
        uint BreakTimeTo;
    }

    struct DayOffRequest {
        uint shiftId;
        uint shiftNum;
        uint time;
    }

    struct DayOff {
        uint shiftId;
        uint from;
        uint to;
        uint time;
    }

    struct WorkPlace {
        uint WorkPlaceId;
        string LocationName;
        string LocationAddress;
        string LatLon;
    }

    enum EMPLOYEE_MANAGEMENT_STATUS {
        NONE,
        PERMISSION,
        NO_PERMISSION,
        WAIT_REQUEST
    }

    struct AvgInOutForYM {
        uint TotalCheckIn;
        uint CountCheckIn;
        uint TotalCheckOut;
        uint CountCheckOut;
    }

    struct TimeKeepingSummaryPerMonth {
        uint CountTimekeeping;
        uint TotalTimekeepingInSecond;

        uint CountLeave;
        uint CountLeavePermission;
        
        uint CountLate;
        uint CountLatePermission;
        uint TotalLateInSecond;

        uint CountComeBackSoon;
        uint CountComeBackSoonPermission;
        uint TotalComeBackSoonInSecond;

        uint TotalOvertimeInSecond;
    }

    struct TotalTimeKeepingYM {
        address Employee;
        uint DepartmentId;
        uint TimeKeepingSummaryPerMonth;
    }

    // Request

    enum REQUEST_STATUS {
        UN_READ,
        APPROVAL,
        REJECT
    }

    enum SHIFT_STATUS {
        LEAVE,
        LATE,
        ON_SCHEDULE
    }

    enum PERMISSION_STATUS {
        NO_PERMISSION,
        PERMISSION,
        NONE
    }

    enum EMPLOYEE_TURNOVER_TYPE {
        ON_BOARD,
        RESIGN
    }
    struct EmployeeTurnover {
        uint DateTime;
        address Employee;
        EMPLOYEE_TURNOVER_TYPE Type;
        uint RequestId;
        REQUEST_STATUS ResignStatus;
    }

    struct ShiftManagement {
        uint ShiftManagementId;
        uint YYYYMMDD;
        address Employee;
        uint ShiftId;
        uint CheckInTime;
        uint CheckOutTime;
        SHIFT_STATUS ShiftStatus;
        uint LatePermissionApproval;
        PERMISSION_STATUS LatePermissionStatus;
        uint ComeBackSoonApproval;
        PERMISSION_STATUS ComeBackSoonPermissionStatus;
        PERMISSION_STATUS LeavePermissionStatus;
    }

    enum VIOLATION_TYPE {
        LATE,
        LEAVE,
        OTHER
    }

    enum CONDITION_TYPE {
        PERMISSION,
        NO_PERMISSION
    }

    enum PUNISH_TYPE {
        WARNING,
        FINE_OR_TICKET,
        SALARY_DEDUCATION_TYPE
    }

    enum SALARY_DEDUCATION_TYPE {
        MINUTE,
        HOUR,
        DAY,
        HALF_DAY,
        SHIFT_MINUTE,
        SHIFT_HOUR,
        SHIFT,
        HALF_SHIFT,
        TYPE
    }

    enum HANDLE_CASE_STATUS {
        UNSOLEVED,
        SOLVED
    }

    enum REQUEST_TYPE {
        LEAVE_PERMISSION,
        LATE_ARRIVAL,
        COME_BACK_SOON,
        OFFER_SALARY,
        SUBSIDIZE,
        RESIGN,
        RULE,
        IN_OUT_ON_BEHALF,
        SALARY_DEDUCATION
    }

    struct Request {
        uint256 RequestId;
        uint IdDetail;
        REQUEST_TYPE Type;
        address Requester;
        address UpdatedBy;
        uint LastUpdate;
        REQUEST_STATUS Status;
    }

    enum REASON_LEAVE_TYPE {
        SICK_LEAVE,
        MATERNITY_LEAVE,
        HAVE_PERSONAL_OR_FAMILY_MATTERS,
        ANNUAL_LEAVE,
        OTHER
    }
    struct LeaveRequest {
        uint Id;
        uint StartDateTime;
        uint EndDateTime;
        REASON_LEAVE_TYPE ReasonType;
        string Other;
    }

    enum REASON_LATE_TYPE {
        TRAFFIC_JAM,
        FEELING_TIRED_INSIDE,
        HAVE_PERSONAL_OR_FAMILY_MATTERS,
        OTHER
    }

    struct LateRequest {
        uint Id;
        uint DateTime;
        REASON_LATE_TYPE ReasonType;
        string Other;
    }

    enum REASON_COME_BACK_SOON {
        MEDICAL_APPOINTMENT_SCHEDULE,
        THERE_IS_AN_EMERGENCY,
        HAVE_PERSONAL_OR_FAMILY_MATTERS,
        OTHER
    }

    struct ComeBackSoonRequest {
        uint Id;
        uint DateTime;
        REASON_COME_BACK_SOON ReasonType;
        string Other;
    }

    enum REASON_COME_OFFER_SALARY {
        INCREASE_PRODUCTIVITY,
        INCREASE_LIVING_COSTS,
        INCREASED_RESPONSIBILITIES_AND_ROLES,
        OTHER
    }

    struct OfferSalaryRequest {
        uint Id;
        uint CurrentSalary;
        uint OfferSalary;
        uint DateTime;
        REASON_COME_OFFER_SALARY ReasonType;
        string Other;
    }

    enum REASON_COME_SUBSIDIZE {
        LUNCH,
        PARKING_FEE,
        GASOLINE,
        OTHER
    }

    struct SubsidizeRequest {
        uint Id;
        uint Allowance;
        uint DateTime;
        REASON_COME_SUBSIDIZE ReasonType;
        string Other;
    }

    enum REASON_RESIGN {
        THE_ENVIRONMENT_IS_NOT_SUITABLE,
        UNSUITABLE_WORK,
        THE_WORK_IS_TOO_DIFFICULT,
        OTHER
    }

    struct ResignEmployee {
        uint Id;
        uint RequestId;
        address UpdatedBy;
        uint ApprovalDate;
        address Employee;
        uint DateTime;
        REASON_RESIGN ReasonType;
        string Other;
    }
    struct ResignRequest {
        uint Id;
        uint DateTime;
        REASON_RESIGN ReasonType;
        string Other;
    }

    struct SalaryDeducationRequest {
        uint256 Id;
        address Employee;
        VIOLATION_TYPE ViolationType;
        uint Date;
        string Other;
        SALARY_DEDUCATION_TYPE SalaryDeducationType;
        uint Amount;
        uint RequestId;
        uint AmountType;
        // Related
        uint ShiftManagementId;
    }

    struct SalaryDeducation {
        address Employee;
        string Reason;
        uint Amount;
        uint SalaryDeducationRequestId;
        uint Date;
    }

    struct SalaryRequest {
        address Employee;
        uint Amount;
        uint ActiveTime;
    }

    struct UpdateHandleCase {
        uint shiftManagementId;
        uint shiftId;
        PUNISH_TYPE punish;
        VIOLATION_TYPE violationType;
        uint date;
        string other;
        SALARY_DEDUCATION_TYPE salaryDeducationType;
        uint amountType;
    }

    struct InOutOnBeHalfRequest {
        uint256 Id;
        address Employee;
        uint DateTime;
        string Reason;
        // Related
        uint AttendanceId;
    }

    struct RuleRequest {
        uint Id;
        VIOLATION_TYPE ViolationType;
        uint Time;
        uint Quantity;
        CONDITION_TYPE ConditionType;
        PUNISH_TYPE PunishType;
        SALARY_DEDUCATION_TYPE SalaryDeducationType;
    }

    // SUMMARY
    struct SummaryTimekeepingForEmployee {
        uint CountTimekeeping;
        uint RemainingTimekeeping;
        uint CountLeavePermission;
        uint RemainingLeavePermission;
        uint CountLate;
        uint TotalLateInMinute;
        uint CountComeBackSoon;
        uint TotalComeBackSoonInMinute;
        uint CountLeaveNoPermission;
        uint TotalOvertimeInMinute;
    }

    struct TotalSalary {
        uint salary;
        uint pit;
        uint insurance;
        uint yearMonth;
    }

    enum NOTIFICATION_TYPE {
        REQUEST, // Related Request
        FINE_TICKET,
        WARNING, // Related Violation Company Rule
        REVIEW, // For HR & HR Manager: All request of employee
        HOLIDAY,
        TYPE,
        SALARY_DEDUCATION_TYPE
    }

    struct Notification {
        NOTIFICATION_TYPE Type;
        string Title;
        string Body;
        uint DateTimeFrom;
        uint DateTimeTo;
        // For Request
        Request RequestData;
        // For Shift
        ShiftManagement ShiftManagementData;
        REQUEST_STATUS RequestStatus;
    }

    struct Salary {
        uint id;
        address employee;
        uint amount;
        uint datetime;
        uint ShiftManagementId;
    }

    struct Subsidize {
        uint id;
        address employee;
        uint amount;
        uint datetime;
        REASON_COME_SUBSIDIZE reason;
    }

    enum VIEW_ID_TYPE {
        VIEW_ALL,
        VIEW_ATTENDANCE,
        VIEW_SALARY
    }
    struct ViewId {
        uint Id;
        bytes32 ViewId;
        address Employee;
        VIEW_ID_TYPE Type;
        uint ExpiredTime;
        uint LastUpdate;
    }

    // Setting Time
    enum FORM_OF_WORK {
        BY_DATE,
        WORK_IN_SHIFTS
    }

    enum OVERTIME {
        SALARY,
        MAKE_UP_FOR_TIME,
        NONE
    }

    enum SALARY_CLOSING_DATE {
        LAST_DATE_OF_EACH_MONTH
    }

    struct SettingTime {
        FORM_OF_WORK FormOFWork;
        uint NumberOfShift;
        Shift[] Shifts;
        DayOff[] DayOffs;
        OVERTIME Overtime;
        uint Permission;
        SALARY_CLOSING_DATE SalaryClosingDate;
        uint256 LastUpdate;
    }

    struct FullEmployeeData {
        Employee EmployeeData;
        EmployeeDetail EmployeeDetailData;
    }

    /**
        Notificatinon Smart Contract

        Usecase:
        - After create/approval/reject request
        - After handle company rule
        - After update handle case
     */
    function setNotificationSMC(address _notiSMCAddress) external;

    function setRoot(
        address _account,
        string memory _nickname
    ) external returns (bool);
    /**
        Employee Role

        Usecase:
        - Using for CRUD Employee Role by ROOT
     */

    function createEmployeeRoleByRoot(
        address _account,
        string memory _nickname,
        ROLE[] memory _positionIds
    ) external returns (bool);

    function getAllEmployeeRole() external view returns (EmployeeRole[] memory);
    function deleteEmployeeRole(
        address _account
    ) external;

    function updateEmployeeRole(
        address _account,
        ROLE[] memory _positionIds
    ) external returns (bool);

    /**
        REF Code

        Usecase:
        - Get current REF Code for employee
        - Assign new REF Code to employee
     */

    function getCurrentRefCode(address employee) external view returns (bytes32);
    function assignNewRefCodeToEmployee(
        address employee
    ) external returns (bytes32);

    /**
        Employee Management

        Usecase:
        - Verify Employee Login
        - Import/Export List Employee (Employee & EmployeeDetail) by HR

     */
    function verifyEmployee(
        bytes32 refCode
    ) external returns (ROLE[] memory roles);

    // Import One Employee
    function importOneEmployee(Employee calldata newEmployee, EmployeeDetail calldata newEmployeeDetail) external returns (bool);

    // Import Employee & Employee Detail for HR
    function importEmployee(Employee[] calldata newEmployees) external returns (bool);
    function importEmployeeDetail(
        EmployeeDetail[] calldata newEmployeeDetails
    ) external returns (bool);

    // Export Employee & Employee Detail for HR
    function exportEmployee() external view returns (Employee[] memory);
    function exportEmployeeDetail() external view returns (EmployeeDetail[] memory);

    // Get All Employee for HR
    function getAllEmployee() external view returns (Employee[] memory);

    // Get Full Data for Employee
    function getInformationForEmployee() external view returns (FullEmployeeData memory);
    function updateInformationForEmployee(Employee memory _newEmployee, EmployeeDetail memory _newEmployeeDetail) external  returns (bool);



    /**
        SETTING Time

        Usecase:
        - Setting time working for company
     */
    function getSettingTime() external view returns (SettingTime memory);
    
    function updateSettingTime(
        FORM_OF_WORK formOFWork,
        Shift[] memory shifts,
        DayOffRequest[] memory dayOff,
        OVERTIME overtime,
        uint permission,
        SALARY_CLOSING_DATE salaryClosingDate
    ) external returns (bool);


    /**
        SETTING Address

        Usecase:
        - Setting adress working for company
     */

    // Using for HR, HR Manager, Root
    function getSettingAddress() external view  returns (SettingAddress memory);
    function updateSettingAddress(
        uint _semiClosed,
        WorkPlace[] memory _workPlaces
    ) external returns (bool);

    // Using for employee
    struct SettingAddressForEmployee {
        SettingAddress SettingAddressData;
        ATTENDANCE_LIMIT_TYPE AttendanceLimitType;
    }
    function getSettingAddressForEmployee() external view returns (SettingAddressForEmployee memory settingAddressForEmployee);

    /**
        Timekeeping **MAIN FEATURE**

        Usecase:
        - Check in, Check out, In/Out On Behalf, Overtime
        - Get over timekeeping per month
        - Get attendace records
        - Get Shift Management
     */
    function checkInAttendance(
        uint _yyyymmdd,
        uint _time,
        WorkPlace memory _workPlace
    ) external returns (bool);

    function checkOutAttendance(
        uint _yyyymmdd,
        uint _time,
        WorkPlace memory _workPlace
    ) external returns (bool);

    function overtimeAttendance(
        uint _yyyymmdd,
        uint _time,
        WorkPlace memory _workPlace,
        string memory _reason
    ) external returns (bool);

    function getAttendanceForEmployee(
        uint _yyyymmdd
    ) external view returns (Attendance[] memory);

    function getShiftManagementForEmployee(
        uint _yyyymmdd
    ) external returns (ShiftManagement[] memory shiftManagements);

    function getSummaryTimekeepingForEmployee(uint _year, uint _month) external view returns (TimeKeepingSummaryPerMonth memory);
}
