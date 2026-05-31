// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {Timekeeping} from "../contracts/Timekeeping.sol";

import {SeedDataTimekeeping} from "./SeedDataTimekeeping.sol";
import "../contracts/lib/ConvertTime.sol";

import {SmcEventMock} from "../contracts/mock/SmcEventMock.sol";
import "../contracts/model.sol";

contract TimekeepingTest is SeedDataTimekeeping,Test{
    using DateTimeLibrary for uint;

    Timekeeping public timekeeping;
    SmcEventMock public notiSMCMock;

    address public DeployerAddress = address(this);
    address public RootAddress = address(1);
    address public HRManagerAddress = address(2);
    address public HRAddress = address(3);
    address public AccountantAddress = address(4);
    address public EmployeeAddress = address(5);

    uint public NumberOfEmployeeSeed = 10;
    uint public NumberOfRuleSeed = 1;

    function setUp() public {
        timekeeping = new Timekeeping();
        notiSMCMock = new SmcEventMock();

        timekeeping.setNotificationSMC(address(notiSMCMock));
        timekeeping.setRoot(RootAddress, "ROOT");

        vm.startPrank(RootAddress);
        ROLE[] memory positionIdHrManager = new ROLE[](1);
        positionIdHrManager[0] = ROLE.HR_MANAGER;
        timekeeping.createEmployeeRoleByRoot(
            HRManagerAddress,
            "HR Manager",
            positionIdHrManager
        );

        ROLE[] memory positionIdHr = new ROLE[](1);
        positionIdHr[0] = ROLE.HR;
        timekeeping.createEmployeeRoleByRoot(HRAddress, "HR", positionIdHr);

        ROLE[] memory positionIdAccountant = new ROLE[](1);
        positionIdAccountant[0] = ROLE.ACCOUNTANT;
        timekeeping.createEmployeeRoleByRoot(
            AccountantAddress,
            "Accountant",
            positionIdAccountant
        );
        vm.stopPrank();

        generateEmployee();
        generateRequest();
        generateSettingRule(NumberOfRuleSeed);
        generateSettingTime();
        generateSettingAddress();
    }

    function generateEmployee() public {
        Employee[] memory employees = new Employee[](NumberOfEmployeeSeed);
        EmployeeDetail[] memory employeeDetails = new EmployeeDetail[](NumberOfEmployeeSeed);

        for (uint add = 0; add < NumberOfEmployeeSeed; add++) {
            (employees[add], employeeDetails[add]) = seedEmployee(
                address(uint160(add + 1)),
                add
            );
        }
        vm.prank(HRAddress);
        timekeeping.importEmployees(employees, employeeDetails);
    }

    uint public NumberOfRequest = 5;
    uint public TotalRequestGenerate = 0;
    function generateRequest() public {
        for (uint seed = 0; seed < NumberOfRequest; seed++) {
            vm.startPrank(address(uint160(seed + 1)));
            timekeeping.createLeavePermissionRequest(
                1719826083,
                1720171683,
                REASON_LEAVE_TYPE.HAVE_PERSONAL_OR_FAMILY_MATTERS,
                "OTHER createLeavePermissionRequest"
            );
            TotalRequestGenerate++;

            timekeeping.createLateArrivalRequest(
                1719826083,
                REASON_LATE_TYPE.FEELING_TIRED_INSIDE,
                "OTHER createLateArrivalRequest"
            );
            TotalRequestGenerate++;

            timekeeping.createComeBackSoonRequest(
                1719826083,
                REASON_COME_BACK_SOON.MEDICAL_APPOINTMENT_SCHEDULE,
                "OTHER createComeBackSoonRequest"
            );
            TotalRequestGenerate++;

            timekeeping.createOfferSalaryRequest(
                100000,
                200000000000,
                1719826083,
                REASON_COME_OFFER_SALARY.INCREASE_PRODUCTIVITY,
                "OTHER createOfferSalaryRequest"
            );
            TotalRequestGenerate++;

            timekeeping.createSubsidizeRequest(
                1720259365,
                1720259366,
                REASON_COME_SUBSIDIZE.LUNCH,
                "OTHER createSubsidizeRequest"
            );
            TotalRequestGenerate++;

            timekeeping.createResignRequest(
                1719826083,
                REASON_RESIGN.THE_ENVIRONMENT_IS_NOT_SUITABLE,
                "OTHER createResignRequest"
            );
            TotalRequestGenerate++;

            vm.stopPrank();
        }
    }

    function generateSettingRule(uint cnt) public {
        SettingRule memory rule;
        for (uint seed = 0; seed < cnt; seed++) {
            rule = seedSeetingRule(seed);
            vm.prank(RootAddress);
            timekeeping.createSettingRule(
                rule.ViolationType,
                rule.Time,
                rule.Quantity,
                rule.ConditionType,
                rule.PunishType,
                rule.SalaryDeducationType
            );
        }

        rule = seedSeetingRule(99);
        vm.prank(HRAddress);
        timekeeping.createSettingRule(
            rule.ViolationType,
            rule.Time,
            rule.Quantity,
            rule.ConditionType,
            rule.PunishType,
            rule.SalaryDeducationType
        );
        TotalRequestGenerate++;

    }

    function generateSettingTime() public {
       (DayOffRequest[] memory dayOffRequest,SettingTime memory settingTime) = seedSeetingTime(block.timestamp);
        vm.prank(RootAddress);
     
        timekeeping.updateSettingTime(
            settingTime.FormOFWork,
            settingTime.Shifts,
            dayOffRequest,
            settingTime.Overtime,
            settingTime.Permission,
            settingTime.SalaryClosingDate
        );
    }

    function generateSettingAddress() public {
        SettingAddress memory settingAddress = seedSeetingAddress(
            block.timestamp
        );
        vm.prank(RootAddress);
        timekeeping.updateSettingAddress(
            settingAddress.SemiClosed,
            settingAddress.WorkPlaces
        );
    }

    // ========================== START UNIT TEST ========================== //

    // ============================= DateTime Lib  ============================= //
    function test_DateTime() public pure {
        // https://www.epochconverter.com
        // Monday, July 1, 2024 7:34:32 PM
        uint timestamp = 1719862472;
        (uint year, uint month, uint day, uint hour, uint minute, uint second) = DateTimeLibrary.timestampToDateTime(timestamp);
        vm.assertEq(year, 2024);
        vm.assertEq(month, 7);
        vm.assertEq(day, 1);
        vm.assertEq(hour, 19);
        vm.assertEq(minute, 34);
        vm.assertEq(second, 32);

        uint startOfDate = DateTimeLibrary._getStartOfDateFromTimestamp(timestamp);
        vm.assertEq(startOfDate, 1719862472 - 19 * 60 * 60 - 34 * 60 - 32);
    }
    // ============================= Employee  ============================= //
    function test_Employee_Import_Export_Excel() public {
        uint startAt = 100;
        uint newEmployee = 100;

        Employee[] memory employees = new Employee[](newEmployee);
        EmployeeDetail[] memory employeeDetails = new EmployeeDetail[](newEmployee);

        for (uint add = startAt; add < startAt + newEmployee; add++) {
            (employees[add - startAt], employeeDetails[add - startAt]) = seedEmployee(
                address(uint160(add + 1)),
                add
            );
        }
        vm.prank(HRAddress);
        timekeeping.importEmployees(employees, employeeDetails);
        
        vm.prank(HRAddress);
        (employees, employeeDetails) = timekeeping.exportEmployees();

        vm.assertEq(employees.length, NumberOfEmployeeSeed + newEmployee, "compare number of employee");
        vm.assertEq(employeeDetails.length, NumberOfEmployeeSeed + newEmployee, "compare number of employeeDetail");
    }

    function test_EmployeeRole_UpdateRoot() public {
        address newRootAddress = address(20); 
        timekeeping.setRoot(newRootAddress, "New Root Address");

        vm.prank(RootAddress);
        //vm.expectRevert();
        timekeeping.getAllEmployeeRole();

        address currentRootAddress = timekeeping.ROOT_ADDRESS();
       vm.assertEq(newRootAddress, currentRootAddress);
    }

    function test_Employee_UpdateInformation() public {
        Employee memory newEmployee;
        newEmployee.FullName = "NEW FULL NAME";
        newEmployee.DepartmentId = 1;
        newEmployee.PositionId = 2;
        newEmployee.Location = "NEW LOCATION";
        newEmployee.OnboardDateTime = 99999999;

        EmployeeDetail memory newEmployeeDetail;
        newEmployeeDetail.TaxId = "4444";
        newEmployeeDetail.HealthInsuranceId = "5555";
        newEmployeeDetail.SocialInsuranceId = "6666";
        newEmployeeDetail.NumberOfDependents = 5;
        newEmployeeDetail.PermanentAddress = "NEW PERMANENT ADDRESS";
        newEmployeeDetail.DateOfBirth = 100000;
        newEmployeeDetail.Gender = GENDER_TYPE.MALE;
        newEmployeeDetail.Email = "new-email@be-earning.com";
        newEmployeeDetail.PhoneNumber = 123456789;

        vm.startPrank(EmployeeAddress);
        bool result = timekeeping.updateInformationForEmployee(
            newEmployee,
            newEmployeeDetail
        );
        vm.assertTrue(result); 

        timekeeping.getInformationForEmployee();
        vm.stopPrank();
    }

    function test_Employee_Delete() public {
        vm.startPrank(RootAddress);

        timekeeping.deleteEmployee(address(2));

        timekeeping.deleteEmployee(address(5));

        timekeeping.deleteEmployee(address(7));

        timekeeping.deleteEmployee(address(9));

        vm.stopPrank();

        timekeeping.setRoot(address(100), "NEW ROOT EMPLOYEE");
        vm.prank(address(100));
        EmployeeRole[] memory employeeRoles = timekeeping.getAllEmployeeRole();
        vm.assertEq(employeeRoles.length, 3);

        vm.prank(HRAddress);
        ShiftManagement[] memory shiftManagements = timekeeping.getEmployeeManagement(20240702);

        vm.prank(address(100));
        SettingTime memory settingTime = timekeeping.getSettingTime();
        vm.assertEq(shiftManagements.length, (NumberOfEmployeeSeed - 4) * settingTime.NumberOfShift);

        vm.stopPrank();
    }

    // ========================== RefCode ========================== //
    function test_RefCode_GetRefCodeByRoot() public {
        vm.prank(RootAddress);
        bytes32 newRefCode = timekeeping.assignNewRefCodeToEmployee(
            EmployeeAddress
        );

        bytes32 result;
        vm.prank(RootAddress);
        result = timekeeping.getCurrentRefCode(EmployeeAddress);
        assertEq(result, newRefCode);

        vm.prank(HRManagerAddress);
        result = timekeeping.getCurrentRefCode(EmployeeAddress);
        assertEq(result, newRefCode);

        vm.prank(HRAddress);
        result = timekeeping.getCurrentRefCode(EmployeeAddress);
        assertEq(result, newRefCode);

        vm.prank(AccountantAddress);
        vm.expectRevert();
        result = timekeeping.getCurrentRefCode(EmployeeAddress);
    }


    function test_RefCode_VerifiRefCodeHas() public {
        vm.prank(RootAddress);
        timekeeping.verifyEmployee(0x00);

        vm.prank(HRManagerAddress);
        timekeeping.verifyEmployee(0x00);

        vm.prank(HRAddress);
        timekeeping.verifyEmployee(0x00);

        vm.prank(AccountantAddress);
        timekeeping.verifyEmployee(0x00);
    }

    function test_RefCode_VerifiRefCodeForEmployee() public {
        vm.prank(RootAddress);
        bytes32 refCodeOtherMember = timekeeping.getCurrentRefCode(address(9));
        vm.prank(RootAddress);
        bytes32 refCode = timekeeping.getCurrentRefCode(EmployeeAddress);
        vm.prank(EmployeeAddress);
        vm.expectRevert();
        timekeeping.verifyEmployee(0x00);


        vm.prank(EmployeeAddress);
        vm.expectRevert();
        timekeeping.verifyEmployee(refCodeOtherMember);

        vm.prank(EmployeeAddress);
        ROLE[] memory roles = timekeeping.verifyEmployee(refCode);
        vm.assertEq(uint(roles[0]), uint(ROLE.EMPLOYEE), "only has one role is ROLE.EMPLOYEE");
    }

    // ============================= REQUEST  ============================= //

    function test_Request_CreateAllRequest() public {
        uint startDateTime = 1719397076;
        uint endDateTime = 1719397076;
        string memory other = "OTHER";
        uint dateTime = 1719397076;
        uint currentSalary = 1000;
        uint offerSalary = 2000;
        uint allowance = 4000;

        vm.prank(EmployeeAddress);
        timekeeping.createLeavePermissionRequest(
            startDateTime,
            endDateTime,
            REASON_LEAVE_TYPE.HAVE_PERSONAL_OR_FAMILY_MATTERS,
            "OTHER"
        );

        vm.prank(EmployeeAddress);
        timekeeping.createLateArrivalRequest(
            dateTime,
            REASON_LATE_TYPE.TRAFFIC_JAM,
            "OTHER"
        );

        vm.prank(EmployeeAddress);
        timekeeping.createComeBackSoonRequest(
            dateTime,
            REASON_COME_BACK_SOON.OTHER,
            other
        );

        vm.prank(EmployeeAddress);
        timekeeping.createOfferSalaryRequest(
            currentSalary,
            offerSalary,
            startDateTime,
            REASON_COME_OFFER_SALARY.INCREASE_PRODUCTIVITY,
            other
        );

        vm.prank(EmployeeAddress);
        timekeeping.createSubsidizeRequest(
            allowance,
            startDateTime,
            REASON_COME_SUBSIDIZE.LUNCH,
            other
        );

        vm.prank(EmployeeAddress);
        timekeeping.createResignRequest(
            startDateTime,
            REASON_RESIGN.THE_ENVIRONMENT_IS_NOT_SUITABLE,
            other
        );
        vm.prank(EmployeeAddress);

        address[] memory addressEmployees = new address[](1);
        addressEmployees[0] = EmployeeAddress;
        timekeeping.getOffetSalaryRequestOfMe();
    }

    function test_Request_FilterByAddressAndType() public {
        Request[] memory requestUsers;

        vm.prank(EmployeeAddress);
        requestUsers = timekeeping.getRequestForEmployeeWithRequestType(
            REQUEST_TYPE.LEAVE_PERMISSION
        );
        vm.assertEq(1, requestUsers.length);

        vm.prank(EmployeeAddress);
        requestUsers = timekeeping.getRequestForEmployeeWithRequestType(
            REQUEST_TYPE.LATE_ARRIVAL
        );
        vm.assertEq(1, requestUsers.length);

        vm.prank(EmployeeAddress);
        requestUsers = timekeeping.getRequestForEmployeeWithRequestType(
            REQUEST_TYPE.COME_BACK_SOON
        );
        vm.assertEq(1, requestUsers.length);

        vm.prank(EmployeeAddress);
        requestUsers = timekeeping.getRequestForEmployeeWithRequestType(
            REQUEST_TYPE.OFFER_SALARY
        );
        vm.assertEq(1, requestUsers.length);

        vm.prank(EmployeeAddress);
        requestUsers = timekeeping.getRequestForEmployeeWithRequestType(
            REQUEST_TYPE.SUBSIDIZE
        );
        vm.assertEq(1, requestUsers.length);

        vm.prank(EmployeeAddress);
        requestUsers = timekeeping.getRequestForEmployeeWithRequestType(
            REQUEST_TYPE.RESIGN
        );
        vm.assertEq(1, requestUsers.length);
    }

    function test_Request_UpdateStatusForHRManager() public {
        vm.prank(HRManagerAddress);
        bool result = timekeeping.updateRequestStatus(
            1,
            REQUEST_STATUS.APPROVAL
        );
        vm.assertEq(result, true);
    }

    function test_Request_UpdateStatusForHR() public {
        bool result;
        vm.prank(HRAddress);
        result = timekeeping.updateRequestStatus(1, REQUEST_STATUS.APPROVAL);
        vm.assertEq(result, true);

        vm.prank(HRAddress);
        result = timekeeping.updateRequestStatus(2, REQUEST_STATUS.APPROVAL);
        vm.assertEq(result, true);

        vm.prank(HRAddress);
        result = timekeeping.updateRequestStatus(3, REQUEST_STATUS.APPROVAL);
        vm.assertEq(result, true);

        vm.prank(HRAddress);
        vm.expectRevert();
        result = timekeeping.updateRequestStatus(4, REQUEST_STATUS.APPROVAL);

        vm.prank(HRAddress);
        vm.expectRevert();
        result = timekeeping.updateRequestStatus(5, REQUEST_STATUS.APPROVAL);

        vm.prank(HRAddress);
        vm.expectRevert();
        result = timekeeping.updateRequestStatus(6, REQUEST_STATUS.APPROVAL);

        vm.prank(AccountantAddress);
        vm.expectRevert();
        result = timekeeping.updateRequestStatus(1, REQUEST_STATUS.APPROVAL);
    }

    function test_Request_GetAllRequestForHR() public {
        vm.prank(HRAddress);
        Request[] memory requests = timekeeping.getReviewRequestForHR();

        for (uint256 idx = 0; idx < requests.length; idx++) {
            assertTrue(
                uint(requests[idx].Type) == uint(REQUEST_TYPE.LEAVE_PERMISSION) || 
                uint(requests[idx].Type) == uint(REQUEST_TYPE.LATE_ARRIVAL) ||
                uint(requests[idx].Type) == uint(REQUEST_TYPE.COME_BACK_SOON),
                "HR Only get request of Leave, Late, Come back soon"
            );
        }
    }

    // ============================= SETTING  ============================= //

    // SettingRule
    function test_Setting_Rule_CreateRule() public {
        bool result;
        uint cnt = 2;
        for (uint seed = 0; seed < cnt; seed++) {
            SettingRule memory rule = seedSeetingRule(seed);

            vm.prank(RootAddress);
            result = timekeeping.createSettingRule(
                rule.ViolationType,
                rule.Time,
                rule.Quantity,
                rule.ConditionType,
                rule.PunishType,
                rule.SalaryDeducationType
            );
            vm.assertEq(result, true);
        }

        vm.prank(RootAddress);
        
        SettingRule[] memory settingRules;
        settingRules = timekeeping.getSettingRules();
        vm.assertEq(settingRules.length, NumberOfRuleSeed + cnt);

        vm.startPrank(HRManagerAddress);

        // Get all rule request by HR
        Request[] memory requests = timekeeping.getReviewRequestForHRManager();
        uint ruleRequestApproval = 0;
        for (uint i = 0; i <  requests.length; i++) {
            if (requests[i].Type == REQUEST_TYPE.RULE && requests[i].Status == REQUEST_STATUS.UN_READ) {
                // Aproval new rule request
                timekeeping.updateRequestStatus(requests[i].RequestId, REQUEST_STATUS.APPROVAL);
                // After approval => create will create
                ruleRequestApproval++;
            }
        }

        settingRules = timekeeping.getSettingRules();
        vm.assertEq(settingRules.length, NumberOfRuleSeed + cnt + ruleRequestApproval);

    }

    function test_Setting_Rule_UpdateRule() public {
        vm.startPrank(RootAddress);
        uint256 ruleId = 1;
        VIOLATION_TYPE newViolation = VIOLATION_TYPE.OTHER;
        uint newTime = 8 * 60 * 60 + 25 * 60 + 0;
        uint newQuatity = 1000;
        CONDITION_TYPE newCondition = CONDITION_TYPE.NO_PERMISSION;
        SALARY_DEDUCATION_TYPE newSalaryDeducation = SALARY_DEDUCATION_TYPE
            .TYPE;

        bool result = timekeeping.updateSettingRule(
            ruleId,
            newViolation,
            newTime,
            newQuatity,
            newCondition,
            newSalaryDeducation
        );
        vm.assertEq(result, true);
        SettingRule memory rule = timekeeping.getSettingRulesByRuleId(ruleId);

        vm.assertEq(uint(rule.ViolationType), uint(newViolation));
        vm.assertEq(rule.Time, newTime);
        vm.assertEq(rule.Quantity, newQuatity);
        vm.assertEq(uint(rule.ConditionType), uint(newCondition));
        vm.assertEq(uint(rule.SalaryDeducationType), uint(newSalaryDeducation));
    }

    // Time
    function test_Setting_Time_UpdateTime() public {
        (DayOffRequest[] memory dayOffRequest,SettingTime memory settingTime) = seedSeetingTime(100);
        vm.prank(RootAddress);
        
        bool result = timekeeping.updateSettingTime(
            settingTime.FormOFWork,
            settingTime.Shifts,
            dayOffRequest,
            settingTime.Overtime,
            settingTime.Permission,
            settingTime.SalaryClosingDate
        );

        vm.assertTrue(result);

        vm.prank(RootAddress);
        timekeeping.getSettingTime();
    }

    // Address
    function test_Setting_Address_UpdateAddress() public {
        vm.prank(RootAddress);
        timekeeping.getSettingAddress();

        SettingAddress memory settingAddress = seedSeetingAddress(99);
        vm.prank(RootAddress);
        bool result = timekeeping.updateSettingAddress(
            settingAddress.SemiClosed,
            settingAddress.WorkPlaces
        );
        vm.assertTrue(result);

        vm.prank(RootAddress);
        timekeeping.getSettingAddress();

        vm.prank(EmployeeAddress);
        //vm.expectRevert();
        timekeeping.getSettingAddress();
    }

    function test_Setting_Address_GetAttendanceLimit() public {
        vm.prank(RootAddress);
        EmployeeSettingAttendanceLimit[] memory attendanceLimitForRoot = timekeeping
            .getSettingAttendanceLimit();
        vm.assertEq(attendanceLimitForRoot.length, NumberOfEmployeeSeed);
        for (uint256 i = 0; i < attendanceLimitForRoot.length; i++) {
            vm.assertEq(uint(attendanceLimitForRoot[i].AttendanceLimitType), uint(ATTENDANCE_LIMIT_TYPE.FREE_ATTENDANCE));
        }
    }

    function test_Setting_Address_UpdateAttendanceLimit() public {
        uint256 cnt = 5;
        uint256 start = 2;
        address[] memory employeeAddress = new address[](cnt);
        ATTENDANCE_LIMIT_TYPE[] memory typeOfLimits = new ATTENDANCE_LIMIT_TYPE[](cnt);
        for (uint256 i = start; i < start + cnt; i++) {
            employeeAddress[i - start] = address(uint160(i));
            typeOfLimits[i - start] = ATTENDANCE_LIMIT_TYPE.ONLY_ALLOW_AT_WORK;
        }

        vm.prank(RootAddress);
        bool result = timekeeping.updateSettingAttendaceLimit(
            employeeAddress,
            typeOfLimits
        );
        vm.assertTrue(result);

        vm.prank(RootAddress);
        EmployeeSettingAttendanceLimit[] memory attendanceLimitUpdated = timekeeping
            .getSettingAttendanceLimit();
        vm.assertEq(attendanceLimitUpdated.length, NumberOfEmployeeSeed);
        for (uint256 i = 0; i < attendanceLimitUpdated.length; i++) {
            if (start - 1 <= i && i < start + cnt - 1) {
                vm.assertEq(uint(attendanceLimitUpdated[i].AttendanceLimitType), uint(ATTENDANCE_LIMIT_TYPE.ONLY_ALLOW_AT_WORK));
            } else {
                vm.assertEq(uint(attendanceLimitUpdated[i].AttendanceLimitType), uint(ATTENDANCE_LIMIT_TYPE.FREE_ATTENDANCE));
            }
        }
    }

    function test_Attendance_CheckIn() public {
        uint date = 20240628;

        WorkPlaceAttendance memory workPlace;
        workPlace.WorkPlaceId = 1;
        workPlace.LatLon = "1111111111,000000000000";

        bool result;
        
 
        vm.prank(EmployeeAddress);
        uint timestamp = DateTimeLibrary._getTimestampFromYYYYMMDDTime(date, 8 * 3600 + 30 * 60);
        vm.warp(timestamp);
        result = timekeeping.checkInAttendance(
            workPlace
        );
        vm.assertTrue(result);
        vm.prank(HRAddress);
        Attendance memory attendanceCheckIn = timekeeping.getAttendanceById(1);
        vm.assertEq(attendanceCheckIn.YYYYMMDD, date);
        vm.assertEq(attendanceCheckIn.Time, DateTimeLibrary._getTime(timestamp));
        vm.assertEq(attendanceCheckIn.WorkPlaceAttendance.WorkPlaceId, 1);
        vm.assertEq(
            uint(attendanceCheckIn.Type),
            uint(ATTENDANCE_TYPE.CHECK_IN)
        );
    }

    function test_Attendance_AvgInOutForMonth() public {
        uint _year = 2024;
        vm.prank(RootAddress);
        SettingAddress memory settingAddress = timekeeping.getSettingAddress(); 

        WorkPlaceAttendance[] memory workPlaceAttendanceArr = new WorkPlaceAttendance[](settingAddress.WorkPlaces.length);
        for (uint i = 0; i < settingAddress.WorkPlaces.length; i++) {
            WorkPlace memory item = settingAddress.WorkPlaces[i];
            workPlaceAttendanceArr[i] = WorkPlaceAttendance({
                WorkPlaceId: item.WorkPlaceId,
                LatLon: item.LatLon
            });
        }
        
        for (uint month = 1; month <= 12; month++) {
            uint totalCheckIn = 0;
            uint countCheckIn = 0;
            uint totalCheckOut = 0;
            uint countCheckOut = 0;
            for (uint i = 1; i < NumberOfEmployeeSeed; i++) {
                vm.startPrank(address(uint160(i + 1)));
                uint _checkInTime = 7 * 3600 + 30 * 60 + month * 15 + i;
               DateTimeLibrary._getTimestampFromYYYYMMDDTime(_year * 10000 + month * 100 + (i % 20), _checkInTime);
                vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(_year * 10000 + month * 100 + (i % 20), _checkInTime));
                //timekeeping.checkInAttendance(_year * 10000 + month * 100 + (i % 20), _checkInTime, workPlaceAttendanceArr[0]);
                timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);

                uint _checkOutTime = 18 * 3600 + 0 + month * 15 + i;
                //timekeeping.checkOutAttendance(_year * 10000 + month * 100 + (i % 20), _checkOutTime, workPlaceAttendanceArr[0]);
                uint firstP = _year * 10000 + month * 100 + (i % 20);
                vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(firstP, _checkOutTime));
                timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);
                vm.stopPrank();

                totalCheckIn += _checkInTime;
                countCheckIn += 1;

                totalCheckOut += _checkOutTime;
                countCheckOut += 1;
            }

            vm.prank(HRAddress);
            AvgInOutForYM memory avgCurrMonth = timekeeping.getAvgInOutForMonth(_year)[month - 1];
            vm.assertEq(avgCurrMonth.TotalCheckIn, totalCheckIn, "Total CheckIn");
            vm.assertEq(avgCurrMonth.CountCheckIn, countCheckIn, "Count CheckIn");
            vm.assertEq(avgCurrMonth.TotalCheckOut, totalCheckOut, "Total CheckOut");
            vm.assertEq(avgCurrMonth.CountCheckOut, countCheckOut, "Count CheckOut");
        }
    }

    function test_Attendance_TotalTimeKeeping() public {
        uint _year = 2024;
        vm.prank(RootAddress);
        SettingAddress memory settingAddress = timekeeping.getSettingAddress(); 
        WorkPlaceAttendance[] memory workPlaceAttendanceArr = new WorkPlaceAttendance[](settingAddress.WorkPlaces.length);
        for (uint i = 0; i < settingAddress.WorkPlaces.length; i++) {
            WorkPlace memory item = settingAddress.WorkPlaces[i];
            workPlaceAttendanceArr[i] = WorkPlaceAttendance({
                WorkPlaceId: item.WorkPlaceId,
                LatLon: item.LatLon
            });
        }
        for (uint month = 1; month <= 12; month++) {
            uint[] memory data = new uint[](NumberOfEmployeeSeed);

            for (uint i = 1; i < NumberOfEmployeeSeed; i++) {

                vm.startPrank(address(uint160(i + 1)));
                uint _checkInTime = 7 * 3600 + 30 * 60 + NumberOfEmployeeSeed - i;
                vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(_year * 10000 + month * 100 + (i % 20), _checkInTime));
                timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);

                uint _checkOutTime = 18 * 3600 + 0 + (month % 5) * 20 + NumberOfEmployeeSeed + i;
                vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(_year * 10000 + month * 100 + (i % 20), _checkOutTime));
                timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);
                vm.stopPrank();

                data[i] = _checkOutTime - _checkInTime;
            }

            vm.startPrank(HRAddress);
            TotalTimeKeepingYM[] memory totalCurrMonth = timekeeping.getTotalTimeKeeping(_year, month);
            vm.stopPrank();

            for (uint idx = 0; idx < totalCurrMonth.length; idx++) {
                vm.assertEq(totalCurrMonth[idx].TimeKeepingSummaryPerMonth, data[idx], "EQ - Total Time Keeping");
            }
        }
    }

    function test_Attendance_SummaryPerMonthForEmployee() public {
        vm.prank(RootAddress);
        SettingAddress memory settingAddress = timekeeping.getSettingAddress();
        WorkPlaceAttendance[] memory workPlaceAttendanceArr = new WorkPlaceAttendance[](settingAddress.WorkPlaces.length);
        for (uint i = 0; i < settingAddress.WorkPlaces.length; i++) {
            WorkPlace memory item = settingAddress.WorkPlaces[i];
            workPlaceAttendanceArr[i] = WorkPlaceAttendance({
                WorkPlaceId: item.WorkPlaceId,
                LatLon: item.LatLon
            });
        }
        uint _yyyymmdd = 20240701;
        uint _timeCheckIn = 7 *3600 + 30*60 + 0;
        uint _timeCheckOut = 18 *3600 + 0*60 + 0;

        for (uint i = 0; i < 15; i++) {
            vm.prank(EmployeeAddress);
            //timekeeping.checkInAttendance(_yyyymmdd + i, _timeCheckIn, workPlaceAttendanceArr[0]);
            vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd + i, _timeCheckIn)); 
            timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
            
            vm.prank(EmployeeAddress);
            //timekeeping.checkOutAttendance(_yyyymmdd + i, _timeCheckOut, workPlaceAttendanceArr[0]);
            vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd + i, _timeCheckOut)); 
            vm.prank(EmployeeAddress);
            timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);
        }

        // uint _timeCheckInLate = 8*3600 + 15*60 + 0;

        // vm.prank(EmployeeAddress);
        // vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(20240716, _timeCheckInLate)); 
        // //timekeeping.checkInAttendance(20240716, _timeCheckInLate, workPlaceAttendanceArr[0]);
        // timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
        // vm.prank(EmployeeAddress);
        // //timekeeping.checkOutAttendance(20240716, _timeCheckOut, workPlaceAttendanceArr[0]);
        // vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(20240716, _timeCheckOut)); 
        // timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

        // vm.prank(EmployeeAddress);
        // uint _dateTimeLate = DateTimeLibrary._getTimestampFromDateTime(2024, 7, 17, 8, 15, 0);
        // Request memory requestLate = timekeeping.createLateArrivalRequest(_dateTimeLate, REASON_LATE_TYPE.HAVE_PERSONAL_OR_FAMILY_MATTERS, "");

        // vm.prank(HRAddress);
        // timekeeping.updateRequestStatus(requestLate.RequestId, REQUEST_STATUS.APPROVAL);

        // _timeCheckInLate = 8*3600 + 10*60 + 0;
        // vm.prank(EmployeeAddress);
        // //timekeeping.checkInAttendance(20240717, _timeCheckInLate, workPlaceAttendanceArr[0]);
        // vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(20240717, _timeCheckInLate));
        // timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
        // vm.prank(EmployeeAddress);
        // //timekeeping.checkOutAttendance(20240717, _timeCheckOut, workPlaceAttendanceArr[0]);
        // vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(20240717, _timeCheckOut));
        // timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

        // uint _timeCheckOutSoon = 17*3600 + 15*60 + 0;
        // vm.prank(EmployeeAddress);
        // //timekeeping.checkInAttendance(20240718, _timeCheckIn, workPlaceAttendanceArr[0]);
        // vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(20240718, _timeCheckIn));
        // timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
        // vm.prank(EmployeeAddress);
        // //timekeeping.checkOutAttendance(20240718, _timeCheckOutSoon, workPlaceAttendanceArr[0]);
        // vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(20240718, _timeCheckOutSoon));
        // timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

        // vm.prank(EmployeeAddress);
        // uint _dateTimeComeBackSoonRequest = DateTimeLibrary._getTimestampFromDateTime(2024, 7, 19, 17, 20, 0);
        // Request memory requestComeBackSoon = timekeeping.createComeBackSoonRequest(_dateTimeComeBackSoonRequest, REASON_COME_BACK_SOON.MEDICAL_APPOINTMENT_SCHEDULE,"");

        // vm.prank(HRAddress);
        // timekeeping.updateRequestStatus(requestComeBackSoon.RequestId, REQUEST_STATUS.APPROVAL);

        // _timeCheckOutSoon = 17*3600 + 25*60 + 0;
        // vm.prank(EmployeeAddress);
        // //timekeeping.checkInAttendance(20240719, _timeCheckIn, workPlaceAttendanceArr[0]);
        // vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(20240719, _timeCheckIn));
        // timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
        // vm.prank(EmployeeAddress);
        // //timekeeping.checkOutAttendance(20240719, _timeCheckOutSoon, workPlaceAttendanceArr[0]);
        // vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(20240719, _timeCheckOutSoon));
        // timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);


        // uint _startDateTime = DateTimeLibrary._getTimestampFromDateTime(2024, 7, 21, 8, 0, 0);
        // uint _endDateTime = DateTimeLibrary._getTimestampFromDateTime(2024, 7, 21, 19, 0, 0);
        // vm.prank(EmployeeAddress);
        // Request memory request = timekeeping.createLeavePermissionRequest(_startDateTime, _endDateTime, REASON_LEAVE_TYPE.ANNUAL_LEAVE, "");

        // vm.prank(HRAddress);
        // timekeeping.updateRequestStatus(request.RequestId, REQUEST_STATUS.APPROVAL);

        // vm.prank(EmployeeAddress);
        // WorkPlaceAttendance memory workPlace;
        // workPlace.WorkPlaceId = 1;
        // workPlace.LatLon = "1111111111,000000000000";
        // vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(20240722, 22 * 3600));
        // timekeeping.overtimeAttendance(workPlace, "REASON");
        
        // vm.prank(EmployeeAddress);
        // TimeKeepingSummaryPerMonth memory summary = timekeeping.getSummaryTimekeepingForEmployee(2024, 7);

        // vm.assertEq(summary.CountTimekeeping, 21 - 2, "CountTimekeeping"); // 2 is leave (no permission + permission)
        // vm.assertEq(summary.CountLeavePermission, 1, "CountLeavePermission");

        // vm.assertEq(summary.CountLate, 2, "CountLate");
        // vm.assertEq(summary.CountLatePermission, 1, "CountLatePermission");

        // vm.assertEq(summary.CountComeBackSoon, 2, "CountComeBackSoon");
        // vm.assertEq(summary.CountComeBackSoonPermission, 1, "CountComeBackSoonPermission");

        // vm.prank(EmployeeAddress);
        // Attendance[] memory attendanceOvertime = timekeeping.getAttendanceOvertimePerMonth(202407);
        // vm.assertEq(attendanceOvertime.length, 1);
        // vm.assertEq(attendanceOvertime[0].Time, 22 * 3600);

        // SummaryAttendance memory summaryAttendance;
        // vm.prank(RootAddress);
        // summaryAttendance = timekeeping.getSummaryAttendance(20240717, 1);

        //timekeeping.getSummaryTimekeepingForEmployee(_year, _month);
        
    }
    function test_HR_GetEmployeeManagement() public {
        uint yyyymmdd = 20240628;

        WorkPlaceAttendance memory workPlace;
        workPlace.WorkPlaceId = 1;
        workPlace.LatLon = "1111111111,000000000000";
        bool result;

        uint checkInTime = 8 * 60 * 60 + 30 * 60; // 8:30:00

        for (uint160 add = 0; add < NumberOfEmployeeSeed; add++) {
            vm.startPrank(address(add + 1));
            vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(yyyymmdd, checkInTime));
            result = timekeeping.checkInAttendance(
                workPlace
            );

            // CheckOut
            uint checkOutTime = 17 * 60 * 60 + 30 * 60 + 10;
            vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(yyyymmdd, checkOutTime));
            result = timekeeping.checkOutAttendance(
                workPlace
            );

            uint checkInTimeShift2 = 13 * 60 * 60 + 30 * 60 + 0; // 8:30:00
            vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(yyyymmdd, checkInTimeShift2));
            result = timekeeping.checkInAttendance(
                workPlace
            );

            vm.stopPrank();
        }
        // CheckIn

        vm.prank(EmployeeAddress);
        Request memory request = timekeeping.createLateArrivalRequest(
            yyyymmdd,
            REASON_LATE_TYPE.HAVE_PERSONAL_OR_FAMILY_MATTERS,
            "LATE REQUEST OTHER"
        );

        vm.prank(HRAddress);
        timekeeping.updateRequestStatus(
            request.RequestId,
            REQUEST_STATUS.APPROVAL
        );

        ShiftManagement[] memory shiftManagements;

        vm.startPrank(HRAddress);
        shiftManagements = timekeeping
            .getEmployeeManagement(yyyymmdd);
    }

    function test_HR_InOutOnBehalf() public {
        uint yyyymmdd = 20240628;
        uint checkInTime = 8 * 60 * 60 + 30 * 60; // 8:30:00
        bool result;

        WorkPlaceAttendance memory workPlace;
        workPlace.WorkPlaceId = 1;
        workPlace.LatLon = "1111111111,000000000000";
        string memory note = "NOT";

        for (uint160 add = 0; add < NumberOfEmployeeSeed - 1; add++) {
            vm.startPrank(address(add + 1));
            vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(yyyymmdd, checkInTime));
            result = timekeeping.checkInOnBehalfAttendance(
                workPlace,
                note
            );

            vm.stopPrank();
        }

        vm.startPrank(address(uint160(NumberOfEmployeeSeed)));
        vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(yyyymmdd, checkInTime));
        timekeeping.checkInAttendance(workPlace);
        uint checkOutTime = 17 * 60 * 60 + 30 * 60; // 8:30:00
        vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(yyyymmdd, checkOutTime));
        timekeeping.checkOutOnBehalfAttendance(
            workPlace,
            "REASON"
        );
        vm.stopPrank();
        vm.startPrank(HRAddress);
        (Attendance[] memory currAttendances, ) = timekeeping
            .getInOutOnBehalfForHR();
        for (uint i = 0; i < currAttendances.length; i++) {
            timekeeping.confirmOnBehalfByHR(currAttendances[i].AttendanceId);
        }

        (Attendance[] memory updateAttendances, ) = timekeeping
            .getInOutOnBehalfForHR();

        for (uint i = 0; i < updateAttendances.length; i++) {
            vm.assertEq(
                uint(updateAttendances[i].OnBehalfStatus),
                uint(ON_BEHALF_STATUS.HR_CONFIRM)
            );
        }
        vm.stopPrank();

        vm.startPrank(HRManagerAddress);
        Request[] memory requests = timekeeping.getReviewRequestForHRManager();
        for (uint i = 0; i < requests.length; i++) {
            if (requests[i].Type == REQUEST_TYPE.IN_OUT_ON_BEHALF) {
                timekeeping.updateRequestStatus(
                    requests[i].RequestId,
                    REQUEST_STATUS((i % 2) + 1)
                );
            }
        }

        vm.startPrank(HRManagerAddress);
        requests = timekeeping.getReviewRequestForHRManager();
        for (uint i = 0; i < requests.length; i++) {
            if (requests[i].Type == REQUEST_TYPE.IN_OUT_ON_BEHALF) {
                InOutOnBeHalfRequest memory inOutOnBeHalfRequest = timekeeping
                    .getInOutOnBehalfRequestDetail(requests[i].RequestId);
                Attendance memory attendance = timekeeping.getAttendanceById(
                    inOutOnBeHalfRequest.AttendanceId
                );
                if (requests[i].Status == REQUEST_STATUS.APPROVAL) {
                    vm.assertEq(
                        uint(attendance.OnBehalfStatus),
                        uint(ON_BEHALF_STATUS.HR_MANAGER_APPROVAL)
                    );
                } else {
                    vm.assertEq(
                        uint(attendance.OnBehalfStatus),
                        uint(ON_BEHALF_STATUS.HR_MANAGER_REJECT)
                    );
                }
            }
        }
        vm.stopPrank();
    }

    function test_HR_EmployeeTurnover() public {
        vm.startPrank(HRManagerAddress);
        timekeeping.updateRequestStatus(24, REQUEST_STATUS.REJECT);
        timekeeping.updateRequestStatus(30, REQUEST_STATUS.APPROVAL);
        vm.stopPrank();
        vm.startPrank(HRAddress);
        EmployeeTurnover[] memory employeeTurnovers = timekeeping
            .getEmployeeTurnover();

        for (uint i = 0; i < employeeTurnovers.length; i++) {
            if (employeeTurnovers[i].RequestId == 24) {
                vm.assertEq(
                    uint(employeeTurnovers[i].ResignStatus),
                    uint(REQUEST_STATUS.REJECT)
                );
            }
            if (employeeTurnovers[i].RequestId == 30) {
                vm.assertEq(
                    uint(employeeTurnovers[i].ResignStatus),
                    uint(REQUEST_STATUS.APPROVAL)
                );
            }
        }
        vm.stopPrank();
    }

    function test_HR_HandleCase() public {
        uint _yyyymmdd = 20240704;
        uint checkInTime = 8 * 60 * 60 + 0 * 60;
        WorkPlaceAttendance memory workPlace;
        workPlace.WorkPlaceId = 1;
        workPlace.LatLon = "1111111111,000000000000";

        for (uint160 add = 2; add < NumberOfEmployeeSeed; add++) {
            vm.startPrank(address(add + 1));
            vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd, checkInTime));
            timekeeping.checkInAttendance(
                workPlace
            );
            vm.stopPrank();
        }
        vm.startPrank(address(1));
        vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd, checkInTime + 15 * 60));
        timekeeping.checkInAttendance(
            workPlace
        );
        vm.stopPrank();

        vm.startPrank(address(2));
        vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd, checkInTime + 30 * 60));
        timekeeping.checkInAttendance(
            workPlace
        );
        vm.stopPrank();
        vm.startPrank(HRAddress);
        ShiftManagement[] memory shiftManagements;
        HANDLE_CASE_STATUS[] memory handleCaseStatus;
        (shiftManagements, handleCaseStatus) = timekeeping.getHandleCase(
            _yyyymmdd
        );


        vm.stopPrank();

        vm.startPrank(HRManagerAddress);
        PUNISH_TYPE _punish = PUNISH_TYPE.SALARY_DEDUCATION_TYPE;
        VIOLATION_TYPE _violation_type = VIOLATION_TYPE.LATE;
        string memory _other = "OTHER FOR SALARY DEDUCATION";
        SALARY_DEDUCATION_TYPE _salaryDeducationType = SALARY_DEDUCATION_TYPE
            .HOUR;

        timekeeping.updateHandleCase(UpdateHandleCase({
            shiftManagementId: shiftManagements[0].ShiftManagementId,
            shiftId: 1,
            punish: _punish,
            violationType: _violation_type,
            date: _yyyymmdd,
            other: _other,
            salaryDeducationType: _salaryDeducationType,
            amountType: 100
        }));
    
        Request memory request = timekeeping.getReviewRequestForHRManager()[0]; // Latest
        vm.assertEq(uint(request.Type), uint(REQUEST_TYPE.SALARY_DEDUCATION));
    }

    function test_Attendance_LateRequest_Case1() public {
        address _employee = address(5);
        uint _yyyymmdd = 20240702;
        uint _checkInTime = 8*60*60 + 15*60 + 10;

        WorkPlaceAttendance memory workPlace;
        workPlace.WorkPlaceId = 1;
        workPlace.LatLon = "1111111111,000000000000";
        vm.startPrank(_employee);

        uint latePermissionApproval = DateTimeLibrary.timestampFromDateTime(2024, 7, 2, 8, 20, 0);

        timekeeping.createLateArrivalRequest(latePermissionApproval, REASON_LATE_TYPE.HAVE_PERSONAL_OR_FAMILY_MATTERS, "OTHER");
        vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd, _checkInTime));
        timekeeping.checkInAttendance(
            workPlace
        );

        ShiftManagement[] memory shiftManagements = timekeeping.getShiftManagementForEmployee(_yyyymmdd);
        ShiftManagement memory currShiftManagement = shiftManagements[0];

        vm.stopPrank();

        vm.startPrank(HRAddress);
        timekeeping.updateRequestStatus(TotalRequestGenerate + 1, REQUEST_STATUS.APPROVAL);
        vm.stopPrank();

        vm.startPrank(_employee);
        shiftManagements = timekeeping.getShiftManagementForEmployee(_yyyymmdd);
        currShiftManagement = shiftManagements[0];
        vm.stopPrank();

        vm.assertEq(_checkInTime, currShiftManagement.CheckInTime);
        vm.assertEq(_checkInTime, currShiftManagement.CheckInTime);
        vm.assertEq(_yyyymmdd, currShiftManagement.YYYYMMDD);
        vm.assertEq(1, currShiftManagement.ShiftId);
        vm.assertEq(uint(SHIFT_STATUS.LATE), uint(currShiftManagement.ShiftStatus));
        vm.assertEq(DateTimeLibrary._getTime(latePermissionApproval), currShiftManagement.LatePermissionApproval);
        vm.assertEq(uint(PERMISSION_STATUS.PERMISSION), uint(currShiftManagement.LatePermissionStatus));
    }

    function test_Attendance_LateRequest_Case2() public {
        address _employee = address(5);
        uint _yyyymmdd = 20240702;
        uint _checkInTime = 8*60*60 + 15*60 + 10;
        WorkPlaceAttendance memory workPlace;
        workPlace.WorkPlaceId = 1;
        workPlace.LatLon = "1111111111,000000000000";
        vm.startPrank(_employee);

        uint latePermissionApproval = DateTimeLibrary.timestampFromDateTime(2024, 7, 2, 8, 20, 0);

        timekeeping.createLateArrivalRequest(latePermissionApproval, REASON_LATE_TYPE.HAVE_PERSONAL_OR_FAMILY_MATTERS, "OTHER");
        vm.stopPrank();

        vm.startPrank(HRAddress);
        timekeeping.updateRequestStatus(TotalRequestGenerate + 1, REQUEST_STATUS.APPROVAL);
        vm.stopPrank();
        
        vm.startPrank(_employee);

        vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd, _checkInTime));
        timekeeping.checkInAttendance(
            workPlace
        );

        ShiftManagement[] memory shiftManagements = timekeeping.getShiftManagementForEmployee(_yyyymmdd);
        ShiftManagement memory currShiftManagement = shiftManagements[0];

        vm.stopPrank();



        vm.startPrank(_employee);
        shiftManagements = timekeeping.getShiftManagementForEmployee(_yyyymmdd);
        currShiftManagement = shiftManagements[0];
        vm.stopPrank();

        vm.assertEq(_checkInTime, currShiftManagement.CheckInTime);
        vm.assertEq(_checkInTime, currShiftManagement.CheckInTime);
        vm.assertEq(_yyyymmdd, currShiftManagement.YYYYMMDD);
        vm.assertEq(1, currShiftManagement.ShiftId);
        vm.assertEq(uint(SHIFT_STATUS.LATE), uint(currShiftManagement.ShiftStatus));
        vm.assertEq(DateTimeLibrary._getTime(latePermissionApproval), currShiftManagement.LatePermissionApproval);
        vm.assertEq(uint(PERMISSION_STATUS.PERMISSION), uint(currShiftManagement.LatePermissionStatus));
    }

    function test_Attendance_LateRequest_AutoRule() public {
        address _employee = address(5);
        uint _yyyymmdd = 20240702;
        uint _checkInTime = 8*60*60 + 30*60 + 10;
        WorkPlaceAttendance memory workPlace;
        workPlace.WorkPlaceId = 1;
        workPlace.LatLon = "1111111111,000000000000";
        vm.startPrank(_employee);

        uint latePermissionApproval = DateTimeLibrary.timestampFromDateTime(2024, 7, 2, 8, 20, 0);

        timekeeping.createLateArrivalRequest(latePermissionApproval, REASON_LATE_TYPE.HAVE_PERSONAL_OR_FAMILY_MATTERS, "OTHER");
        vm.stopPrank();

        vm.startPrank(HRAddress);
        timekeeping.updateRequestStatus(TotalRequestGenerate + 1, REQUEST_STATUS.APPROVAL);
        vm.stopPrank();
        
        vm.startPrank(_employee);

        vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd, _checkInTime));
        timekeeping.checkInAttendance(
            workPlace
        );

        ShiftManagement[] memory shiftManagements = timekeeping.getShiftManagementForEmployee(_yyyymmdd);
        ShiftManagement memory currShiftManagement = shiftManagements[0];

        vm.stopPrank();



        vm.startPrank(_employee);
        shiftManagements = timekeeping.getShiftManagementForEmployee(_yyyymmdd);
        currShiftManagement = shiftManagements[0];
        vm.stopPrank();

        vm.assertEq(_checkInTime, currShiftManagement.CheckInTime);
        vm.assertEq(_checkInTime, currShiftManagement.CheckInTime);
        vm.assertEq(_yyyymmdd, currShiftManagement.YYYYMMDD);
        vm.assertEq(1, currShiftManagement.ShiftId);
        vm.assertEq(uint(SHIFT_STATUS.LATE), uint(currShiftManagement.ShiftStatus));
        vm.assertEq(DateTimeLibrary._getTime(latePermissionApproval), currShiftManagement.LatePermissionApproval);
        vm.assertEq(uint(PERMISSION_STATUS.PERMISSION), uint(currShiftManagement.LatePermissionStatus));


    }

    function test_Attendance_LeaveRequest() public {
        address _employee = address(5);
        ShiftManagement[] memory shiftManagements;
        uint _yyyymmdd = 20240702;

        vm.prank(HRAddress);
        SettingTime memory settingTime = timekeeping.getSettingTime();


        vm.startPrank(_employee);
        uint _startDateTime = DateTimeLibrary.timestampFromDateTime(2024, 7, 2, 8, 0, 0);
        uint _endDateTime = DateTimeLibrary.timestampFromDateTime(2024, 9, 2, 8, 0, 0);
        timekeeping.createLeavePermissionRequest(_startDateTime, _endDateTime, REASON_LEAVE_TYPE.MATERNITY_LEAVE, "OTHER");
        vm.stopPrank();

        vm.startPrank(_employee);

        shiftManagements = timekeeping.getShiftManagementForEmployee(_yyyymmdd);
        for (uint idx = 0; idx < settingTime.NumberOfShift; idx++) {
            vm.assertEq(_yyyymmdd, shiftManagements[idx].YYYYMMDD);
            vm.assertEq(_employee, shiftManagements[idx].Employee);
            vm.assertEq(settingTime.Shifts[idx].ShiftId, shiftManagements[idx].ShiftId);
            vm.assertEq(0, shiftManagements[idx].CheckInTime);
            vm.assertEq(0, shiftManagements[idx].CheckOutTime);
            vm.assertEq(uint(SHIFT_STATUS.LEAVE), uint(shiftManagements[idx].ShiftStatus));
            vm.assertEq(uint(PERMISSION_STATUS.NO_PERMISSION), uint(shiftManagements[idx].LeavePermissionStatus));
        }
        vm.stopPrank();

        vm.startPrank(HRAddress);
        timekeeping.updateRequestStatus(TotalRequestGenerate + 1, REQUEST_STATUS.APPROVAL);
        vm.stopPrank();
        
        vm.startPrank(_employee);
        shiftManagements = timekeeping.getShiftManagementForEmployee(_yyyymmdd);
        for (uint idx = 0; idx < settingTime.NumberOfShift; idx++) {
            vm.assertEq(_yyyymmdd, shiftManagements[idx].YYYYMMDD);
            vm.assertEq(_employee, shiftManagements[idx].Employee);
            vm.assertEq(settingTime.Shifts[idx].ShiftId, shiftManagements[idx].ShiftId);
            vm.assertEq(0, shiftManagements[idx].CheckInTime);
            vm.assertEq(0, shiftManagements[idx].CheckOutTime);
            vm.assertEq(uint(SHIFT_STATUS.LEAVE), uint(shiftManagements[idx].ShiftStatus));
            vm.assertEq(uint(PERMISSION_STATUS.PERMISSION), uint(shiftManagements[idx].LeavePermissionStatus));
        }
        vm.stopPrank();
    }

    function test_Notification_Create() public {
        vm.prank(HRAddress);
        bool result = timekeeping.createAndSendNotificationToAllEmployee(NOTIFICATION_TYPE.HOLIDAY, 1720258058, 1720344457);
        vm.assertTrue(result);
    }

    function test_accountant_salary_Deducation() public {
        uint _yyyymmdd = 20240704;
        uint checkInTime = 8 * 60 * 60 + 0 * 60;
        WorkPlaceAttendance memory workPlace;
        workPlace.WorkPlaceId = 1;
        workPlace.LatLon = "1111111111,000000000000";

        uint[] memory yyyymmddArr = new uint[](1);
        yyyymmddArr[0] = _yyyymmdd / 100;
        vm.startPrank(EmployeeAddress);
        
        vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd, checkInTime + 1 * 70 * 60));// => Violation Company Rule For Late
        timekeeping.checkInAttendance(
            workPlace
        );
        vm.stopPrank();

        vm.startPrank(EmployeeAddress);
        vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(20240708, checkInTime + 1 * 80 * 60)); // => Violation Company Rule For Late
        timekeeping.checkInAttendance(
            workPlace
        );
        vm.stopPrank();

        vm.startPrank(EmployeeAddress);
        vm.warp(DateTimeLibrary._getTimestampFromYYYYMMDDTime(20240809, checkInTime + 1 * 90 * 60)); // => Violation Company Rule For Late
        timekeeping.checkInAttendance(
            workPlace
        );
        vm.stopPrank();

        vm.startPrank(HRAddress);
        PUNISH_TYPE _punish = PUNISH_TYPE.SALARY_DEDUCATION_TYPE;
        VIOLATION_TYPE _violation_type = VIOLATION_TYPE.LATE;
        string memory _other = "OTHER FOR SALARY DEDUCATION";
        SALARY_DEDUCATION_TYPE _salaryDeducationType = SALARY_DEDUCATION_TYPE.MINUTE;

        Request memory resultRequest = timekeeping.updateHandleCase(UpdateHandleCase({
            shiftManagementId: 1,
            shiftId: 1,
            punish: _punish,
            violationType: _violation_type,
            date: _yyyymmdd,
            other: _other,
            salaryDeducationType: _salaryDeducationType,
            amountType: 100
        }));

        Request memory resultRequest2 = timekeeping.updateHandleCase(UpdateHandleCase({
            shiftManagementId: 2,
            shiftId: 1,
            punish: _punish,
            violationType: _violation_type,
            date: 20240708,
            other: _other,
            salaryDeducationType: _salaryDeducationType,
            amountType: 100
        }));
         Request memory resultRequest3 = timekeeping.updateHandleCase(UpdateHandleCase({
            shiftManagementId: 3,
            shiftId: 1,
            punish: _punish,
            violationType: _violation_type,
            date: 20240609,
            other: _other,
            salaryDeducationType: _salaryDeducationType,
            amountType: 100
        }));
        vm.stopPrank();
        vm.startPrank(HRManagerAddress);
        timekeeping.updateRequestStatus(resultRequest.RequestId, REQUEST_STATUS.APPROVAL);
        timekeeping.updateRequestStatus(resultRequest2.RequestId, REQUEST_STATUS.APPROVAL);
        timekeeping.updateRequestStatus(resultRequest3.RequestId, REQUEST_STATUS.APPROVAL);
       
    
        uint[] memory yearMonths = new uint[](2);
        yearMonths[0] = _yyyymmdd / 100;  
        yearMonths[1] = 202406;  
        address[] memory addressEmployee = new address[](1);
        addressEmployee[0] = EmployeeAddress;
        SalaryDeducation[] memory salaryDeducations  = timekeeping.getSalaryDeducationOfEmployeesByYYYYMMs(addressEmployee, yearMonths);
        FullSalaryDeducationRequest memory result  = timekeeping.getSalaryDeducationRequestOfEmployeesByYYYYMMs(addressEmployee, yearMonths);
        // for (uint i = 0; i < salaryDeducationsRequest.length; i++) {
        //     console.log(223, i,
        //         salaryDeducationsRequest[i].Amount,
        //         salaryDeducationsRequest[i].Date
        //     );
        // }
  
        vm.assertEq(salaryDeducations[0].Amount, 1532487853050);
        vm.assertEq(salaryDeducations[1].Amount, 1751414689200);
        vm.assertEq(salaryDeducations[2].Amount, 2039476315770);
        vm.assertEq(salaryDeducations.length, 3);
        vm.assertEq(result.salaryDeducationRequests.length, 3);
      
        Request memory request = timekeeping.getReviewRequestForHRManager()[0]; // Latest
        vm.stopPrank();
        vm.assertEq(uint(request.Type), uint(REQUEST_TYPE.SALARY_DEDUCATION));
 
    }

    function test_subsidizeRequest()public {
        vm.startPrank(EmployeeAddress);
        Request memory request = timekeeping.createSubsidizeRequest(250000, 1719826083, REASON_COME_SUBSIDIZE.LUNCH, "note other");
        Request memory request2 = timekeeping.createSubsidizeRequest(150000, 1719826083, REASON_COME_SUBSIDIZE.PARKING_FEE, "note other");
        vm.stopPrank();
        
        vm.startPrank(HRManagerAddress);
        timekeeping.updateRequestStatus(request.RequestId, REQUEST_STATUS.APPROVAL);
        timekeeping.updateRequestStatus(request2.RequestId, REQUEST_STATUS.APPROVAL);
        vm.stopPrank();

        vm.startPrank(HRManagerAddress);
        Subsidize[] memory resultSubsidize = timekeeping.getSubsidizesByAddress(EmployeeAddress);
        // for (uint i = 0; i < resultSubsidize.length; i++) {
        //     console.log(44, resultSubsidize[i].amount);
        // }
       
     
        vm.stopPrank();
        vm.assertEq(resultSubsidize[0].amount, 250000);
        vm.assertEq(resultSubsidize[1].amount, 150000);
    }
    
    // ID Management
    function test_ViewID() public {
        uint timestamp = DateTimeLibrary.timestampFromDateTime(2024, 7, 17, 17, 6, 0);
        uint expiredTime = DateTimeLibrary.timestampFromDateTime(2024, 7, 20, 17, 6, 0);

        vm.warp(timestamp);
        vm.startPrank(EmployeeAddress);
        timekeeping.createViewId(VIEW_ID_TYPE.VIEW_ATTENDANCE, expiredTime + 0);
        timekeeping.createViewId(VIEW_ID_TYPE.VIEW_SALARY, expiredTime + 1);
        timekeeping.createViewId(VIEW_ID_TYPE.VIEW_ALL, expiredTime + 2);

        ViewID[] memory viewIDs = timekeeping.getViewIDs();

        vm.assertEq(viewIDs.length, 3, "Number of viewId");
        
        vm.assertEq(uint(viewIDs[0].Type), uint(VIEW_ID_TYPE.VIEW_ATTENDANCE), "type is ATTENDANCE");
        vm.assertEq(viewIDs[0].ExpiredTime, expiredTime, "expiredTime");

        timekeeping.updateViewIdById(viewIDs[0].ID, VIEW_ID_TYPE.VIEW_ALL, expiredTime + 100);
        ViewID memory newViewID = timekeeping.getViewID(viewIDs[0].ID);
        vm.assertEq(uint(newViewID.Type), uint(VIEW_ID_TYPE.VIEW_ALL), "type is VIEW ALL");
        vm.assertEq(newViewID.ExpiredTime, expiredTime + 100, "expiredTime");

    }


}
