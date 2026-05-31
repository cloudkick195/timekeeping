// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import "./constant.sol";

// Employee Role
struct EmployeeRole {
    address Account;
    string Nickname;
    uint LastUpdate;
    ROLE[] PositionIds;
}

// Employee

enum EMPLOYEE_STATUS {
    ON_BOARDING,
    RESIGN,
    DELETE
}
struct Employee {
    address Wallet;

    string FullName;

    string Location;
    uint DepartmentId;
    uint PositionId;
    string Branch;

    uint OnboardDateTime;
}

enum GENDER_TYPE {
    MALE,
    FEMALE
}
struct EmployeeDetail {
    address Wallet;

    GENDER_TYPE Gender;
    uint64 DateOfBirth;
    uint64 PhoneNumber;
    string Email;
    
    uint StatusOfWork;
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

struct WorkPlaceAttendance{
    uint WorkPlaceId;
    string LatLon;
}

// Attendance

struct Attendance {
    uint256 AttendanceId;
    address Employee;
    ATTENDANCE_TYPE Type;
    uint Time; // In seconds
    uint YYYYMMDD; // Format: YYYYMMDD
    WorkPlaceAttendance WorkPlaceAttendance;
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
    uint TotalOvertimeInSecond; // Using cronjob
}

struct TotalTimeKeepingYM {
    address Employee;
    uint DepartmentId;
    uint TimeKeepingSummaryPerMonth;
}

// Request

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

// ========== REQUEST ========== //

struct Request {
    uint256 RequestId;
    uint IdDetail;
    REQUEST_TYPE Type;
    address Requester;
    address UpdatedBy;
    uint LastUpdate;
    REQUEST_STATUS Status;
}

struct LeaveRequest {
    uint Id;
    uint StartDateTime;
    uint EndDateTime;
    REASON_LEAVE_TYPE ReasonType;
    string Other;
}

struct LateRequest {
    uint Id;
    uint DateTime;
    REASON_LATE_TYPE ReasonType;
    string Other;
}

struct ComeBackSoonRequest {
    uint Id;
    uint DateTime;
    REASON_COME_BACK_SOON ReasonType;
    string Other;
}

struct OfferSalaryRequest {
    uint Id;
    uint CurrentSalary;
    uint OfferSalary;
    uint DateTime;
    REASON_COME_OFFER_SALARY ReasonType;
    string Other;
}

struct FullOfferSalaryRequest {
    OfferSalaryRequest[] offerSalaryRequests;
    Request[] requests;
}

struct SubsidizeRequest {
    uint Id;
    uint Allowance;
    uint DateTime;
    REASON_COME_SUBSIDIZE ReasonType;
    string Other;
}

struct FullSubsidizeRequest {
    SubsidizeRequest[] subsidizeRequests;
    Request[] requests;
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

struct FullSalaryDeducationRequest {
    SalaryDeducationRequest[] salaryDeducationRequests;
    Request[] requests;
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

struct OTSalary {
    address employee;
    uint amount;
    uint totalTime;
    uint datetime;
}

struct Subsidize {
    uint id;
    address employee;
    uint amount;
    uint datetime;
    REASON_COME_SUBSIDIZE reason;
}

struct ViewID {
    bytes32 ID;
    address Employee;
    VIEW_ID_TYPE Type;
    uint ExpiredTime;
    uint LastUpdate;
}

// Setting Time

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

struct FullEmployeesData {
    Employee[] EmployeeData;
    EmployeeDetail[] EmployeeDetailData;
}

struct SettingAddressForEmployee {
    SettingAddress SettingAddressData;
    ATTENDANCE_LIMIT_TYPE AttendanceLimitType;
}
