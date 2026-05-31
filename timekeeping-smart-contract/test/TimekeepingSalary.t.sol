// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {Timekeeping} from "../contracts/Timekeeping.sol";

import {SeedDataTimekeeping} from "./SeedDataTimekeeping.sol";
import "../contracts/lib/ConvertTime.sol";

import {SmcEventMock} from "../contracts/mock/SmcEventMock.sol";
import "../contracts/model.sol";

contract TimekeepingSalaryTest is SeedDataTimekeeping, Test {
    using DateTimeLibrary for uint;

    // Timekeeping public timekeeping;

    address public DeployerAddress = address(this);
    address public RootAddress = address(1);
    address public HRManagerAddress = address(2);
    address public HRAddress = address(3);
    address public AccountantAddress = address(4);
    address public EmployeeAddress = address(5);

    uint public NumberOfEmployeeSeed = 10;
    uint public NumberOfRuleSeed = 1;

    function initTest(Timekeeping _timekeeping) public {
        _timekeeping.setRoot(RootAddress, "ROOT");

        vm.startPrank(RootAddress);
        ROLE[] memory positionIdHrManager = new ROLE[](1);
        positionIdHrManager[0] = ROLE.HR_MANAGER;
        _timekeeping.createEmployeeRoleByRoot(
            HRManagerAddress,
            "HR Manager",
            positionIdHrManager
        );
        vm.stopPrank();
    }
    function AddEmployeeFull(
        string memory fullName,
        address wallet,
        uint salary
    ) public pure returns (Employee memory, EmployeeDetail memory) {
        Employee memory newEmployee = Employee({
            Wallet: wallet,

            FullName: "FullName",
            
            Location: "Location",
            DepartmentId: 1,
            PositionId: 1,
            Branch: "Branch",
            
            OnboardDateTime: 1719883722
        });

        EmployeeDetail memory newEmployeeDetail = EmployeeDetail({
            Wallet: wallet,

            Gender: GENDER_TYPE.FEMALE,
            DateOfBirth: 0,
            PhoneNumber: 0,
            Email: "be_earning@be-earning.com",

            StatusOfWork: 1,
            TypeOfWork: 1,
            TypeOfContract: 1,
            PositionSalary: salary,
            TaxableSalary: 10000000,
            PersonalIncomeTax: 100000,

            PermanentAddress: "PermanentAddress",
            NumberOfDependents: 1,
            AcademicLevel: 1,

            ID: "CCCD 01234",
            TaxId: "0123",
            HealthInsuranceId: "0123",
            SocialInsuranceId: "0123",

            HasResume: false,
            HasBirthCertificate: false,
            HasCitizenIdentification: false,
            HasHouseRegistrationBook: false,
            HasHealthCertification: false,
            HasGraduationDegree: false
        });
        return (newEmployee, newEmployeeDetail);
    }

    function generateSettingAddress(Timekeeping _timekeeping) public {
        SettingAddress memory settingAddress = seedSeetingAddress(
            block.timestamp
        );
        vm.prank(RootAddress);
        _timekeeping.updateSettingAddress(
            settingAddress.SemiClosed,
            settingAddress.WorkPlaces
        );
    }

    // function generateSettingTime(Timekeeping _timekeeping) public {
    //    (DayOffRequest[] memory dayOffRequest,SettingTime memory settingTime) = seedSeetingTime(block.timestamp);
    //     vm.prank(RootAddress);

    //     _timekeeping.updateSettingTime(
    //         settingTime.FormOFWork,
    //         settingTime.Shifts,
    //         dayOffRequest,
    //         settingTime.Overtime,
    //         settingTime.Permission,
    //         settingTime.SalaryClosingDate
    //     );
    // }

    function generateSettingRule(Timekeeping _timekeeping, uint cnt) public {
        SettingRule memory rule;
        for (uint seed = 0; seed < cnt; seed++) {
            rule = seedSeetingRule(seed);
            vm.prank(RootAddress);
            _timekeeping.createSettingRule(
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
        _timekeeping.createSettingRule(
            rule.ViolationType,
            rule.Time,
            rule.Quantity,
            rule.ConditionType,
            rule.PunishType,
            rule.SalaryDeducationType
        );
    }

    function test_salary_day() public {
        Timekeeping timekeeping = new Timekeeping();
        initTest(timekeeping);
        generateSettingAddress(timekeeping);

        (
            Employee memory newEmployee,
            EmployeeDetail memory newEmployeeDetail
        ) = AddEmployeeFull("fullname1", EmployeeAddress, 20000000);
        vm.prank(RootAddress);
        timekeeping.createEmployee(newEmployee, newEmployeeDetail);

        vm.prank(RootAddress);
        timekeeping.createSettingRule(
            VIOLATION_TYPE.LEAVE,
            13 * 60 * 60,
            1,
            CONDITION_TYPE.PERMISSION,
            PUNISH_TYPE.SALARY_DEDUCATION_TYPE,
            SALARY_DEDUCATION_TYPE.HALF_DAY
        );
        vm.prank(RootAddress);
        timekeeping.createSettingRule(
            VIOLATION_TYPE.LATE,
            8 * 60 * 60 + 30 * 60,
            1,
            CONDITION_TYPE.PERMISSION,
            PUNISH_TYPE.SALARY_DEDUCATION_TYPE,
            SALARY_DEDUCATION_TYPE.HOUR
        );

        SettingTime memory settingTime;
        DayOffRequest[] memory dayOff = new DayOffRequest[](10);
        settingTime.FormOFWork = FORM_OF_WORK.BY_DATE;
        settingTime.Shifts = new Shift[](1);
        settingTime.NumberOfShift = 1;
        settingTime.Shifts[0].CheckIn = 8 * 60 * 60 + 0 * 60 + 0;
        settingTime.Shifts[0].CheckOut = 17 * 60 * 60 + 30 * 60 + 0;
        settingTime.Shifts[0].BreakTimeFrom = 12 * 60 * 60 + 0 + 0;
        settingTime.Shifts[0].BreakTimeTo = 13 * 60 * 60 + 30 * 60 + 0;
        vm.prank(RootAddress);
        SettingAddress memory settingAddress = timekeeping.getSettingAddress();
        WorkPlaceAttendance[]
            memory workPlaceAttendanceArr = new WorkPlaceAttendance[](
                settingAddress.WorkPlaces.length
            );
        for (uint i = 0; i < settingAddress.WorkPlaces.length; i++) {
            WorkPlace memory item = settingAddress.WorkPlaces[i];
            workPlaceAttendanceArr[i] = WorkPlaceAttendance({
                WorkPlaceId: item.WorkPlaceId,
                LatLon: item.LatLon
            });
        }

        dayOff[0] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 1});
        dayOff[1] = DayOffRequest({shiftId: 1, shiftNum: 2, time: 2});
        dayOff[2] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 3});
        dayOff[3] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 4});
        dayOff[4] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 5});
        dayOff[5] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 6});
        dayOff[6] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 7});
        dayOff[7] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 8});
        dayOff[8] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 9});
        dayOff[9] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 10});
        vm.prank(RootAddress);
        timekeeping.updateSettingTime(
            settingTime.FormOFWork,
            settingTime.Shifts,
            dayOff,
            settingTime.Overtime,
            settingTime.Permission,
            settingTime.SalaryClosingDate
        );

        settingTime.Overtime = OVERTIME.SALARY;
        settingTime.Permission = 5;
        settingTime.SalaryClosingDate = SALARY_CLOSING_DATE
            .LAST_DATE_OF_EACH_MONTH;

        uint _yyyymmdd = 20240701;
        uint _timeCheckIn = 7 * 3600 + 30 * 60 + 0;
        uint _timeCheckOut = 17 * 3600 + 30 * 60 + 0;

        for (uint i = 0; i < 21; i++) {
            vm.prank(EmployeeAddress);
            vm.warp(
                DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                    _yyyymmdd + i,
                    _timeCheckIn
                )
            );
            timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);

            vm.prank(EmployeeAddress);
            vm.warp(
                DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                    _yyyymmdd + i,
                    _timeCheckOut
                )
            );
            vm.prank(EmployeeAddress);
            timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);
        }

        // Nghỉ có lương 2 ngày
        vm.prank(EmployeeAddress);
        timekeeping.createLeavePermissionRequest(
            1721721600,
            1721844000,
            REASON_LEAVE_TYPE.HAVE_PERSONAL_OR_FAMILY_MATTERS,
            "OTHER"
        );

        vm.prank(RootAddress);
        timekeeping.updateRequestStatus(1, REQUEST_STATUS.APPROVAL);

        //Checkout sớm 1h
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                _yyyymmdd + 21,
                8 * 3600
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                _yyyymmdd + 21,
                _timeCheckOut - 60 * 60
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

        //Đi trễ 1h
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                _yyyymmdd + 24,
                9 * 3600
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                _yyyymmdd + 24,
                _timeCheckOut
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

        //OT 2H
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                20240724,
                19 * 3600 + 30 * 60
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.overtimeAttendance(workPlaceAttendanceArr[0], "REASON");

        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                _yyyymmdd + 25,
                13 * 3600 + 30 * 60 + 0
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);

        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                _yyyymmdd + 25,
                _timeCheckOut
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

        address[] memory addressEmployee = new address[](1);
        addressEmployee[0] = EmployeeAddress;
        vm.startPrank(HRManagerAddress);
        uint[] memory yyyymmddArr = new uint[](1);
        yyyymmddArr[0] = _yyyymmdd / 100;
        Salary[] memory resultSalary = timekeeping
            .getSalaryOfEmployeesByYYYYMMs(addressEmployee, yyyymmddArr);
        uint resultTotalSalary = timekeeping.getTotalSalaryEmployeeByYYYYMM(
            EmployeeAddress,
            yyyymmddArr[0]
        );
        vm.stopPrank();
        vm.prank(EmployeeAddress);
        SalaryDeducation[] memory resultSalaryDeducation = timekeeping
            .getSalaryDeducationOfMeByYYYYMMs(yyyymmddArr);
        vm.prank(EmployeeAddress);
        OTSalary[] memory resultOTSalary = timekeeping.getOTSalaryOfMeByYYYYMMs(
            yyyymmddArr
        );

        uint totalcount = 0;
        for (uint i = 0; i < resultSalary.length; i++) {
            totalcount += resultSalary[i].amount;
            //console.log(334, resultSalary[i].amount);
        }

        vm.assertEq(192307692240, resultOTSalary[0].amount);
        vm.assertEq(96153846120, resultSalaryDeducation[0].Amount);
        vm.assertEq(384615384480, resultSalaryDeducation[1].Amount);
        vm.assertEq(19903846146840, totalcount);
        vm.assertEq(19903846146840, resultTotalSalary);
        // so sánh excel
        vm.assertEq(
            19615384608480,
            resultTotalSalary -
                resultSalaryDeducation[0].Amount -
                resultSalaryDeducation[1].Amount +
                resultOTSalary[0].amount
        );

        vm.stopPrank();
    }

    function test_salary_shifts() public {
        Timekeeping timekeeping = new Timekeeping();
        initTest(timekeeping);
        generateSettingAddress(timekeeping);

        (
            Employee memory newEmployee,
            EmployeeDetail memory newEmployeeDetail
        ) = AddEmployeeFull("fullname1", EmployeeAddress, 20000000);
        vm.prank(RootAddress);
        timekeeping.importOneEmployee(newEmployee, newEmployeeDetail);

        vm.prank(RootAddress);
        timekeeping.createSettingRule(
            VIOLATION_TYPE.LATE,
            18 * 60 * 60 + 30 * 60,
            1,
            CONDITION_TYPE.PERMISSION,
            PUNISH_TYPE.SALARY_DEDUCATION_TYPE,
            SALARY_DEDUCATION_TYPE.HOUR
        );
        vm.prank(RootAddress);
        timekeeping.createSettingRule(
            VIOLATION_TYPE.LATE,
            14 * 60 * 60,
            1,
            CONDITION_TYPE.PERMISSION,
            PUNISH_TYPE.SALARY_DEDUCATION_TYPE,
            SALARY_DEDUCATION_TYPE.HOUR
        );

        vm.prank(RootAddress);
        timekeeping.createSettingRule(
            VIOLATION_TYPE.LATE,
            8 * 60 * 60 + 30 * 60,
            1,
            CONDITION_TYPE.PERMISSION,
            PUNISH_TYPE.SALARY_DEDUCATION_TYPE,
            SALARY_DEDUCATION_TYPE.HOUR
        );

        SettingTime memory settingTime;

        settingTime.FormOFWork = FORM_OF_WORK.WORK_IN_SHIFTS;
        settingTime.Shifts = new Shift[](2);
        settingTime.NumberOfShift = 2;
        settingTime.Shifts[0].CheckIn = 8 * 60 * 60;
        settingTime.Shifts[0].CheckOut = 12 * 60 * 60;

        settingTime.Shifts[1].CheckIn = 13 * 60 * 60 + 30 * 60;
        settingTime.Shifts[1].CheckOut = 17 * 60 * 60 + 30 * 60;

        vm.prank(RootAddress);
        SettingAddress memory settingAddress = timekeeping.getSettingAddress();
        WorkPlaceAttendance[]
            memory workPlaceAttendanceArr = new WorkPlaceAttendance[](
                settingAddress.WorkPlaces.length
            );
        for (uint i = 0; i < settingAddress.WorkPlaces.length; i++) {
            WorkPlace memory item = settingAddress.WorkPlaces[i];
            workPlaceAttendanceArr[i] = WorkPlaceAttendance({
                WorkPlaceId: item.WorkPlaceId,
                LatLon: item.LatLon
            });
        }
        DayOffRequest[] memory dayOff = new DayOffRequest[](10);
        dayOff[0] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 1});
        dayOff[1] = DayOffRequest({shiftId: 2, shiftNum: 2, time: 2});
        dayOff[2] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 3});
        dayOff[3] = DayOffRequest({shiftId: 2, shiftNum: 1, time: 4});
        dayOff[4] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 5});
        dayOff[5] = DayOffRequest({shiftId: 2, shiftNum: 1, time: 6});
        dayOff[6] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 7});
        dayOff[7] = DayOffRequest({shiftId: 2, shiftNum: 1, time: 8});
        dayOff[8] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 9});
        dayOff[9] = DayOffRequest({shiftId: 2, shiftNum: 1, time: 10});
        settingTime.Overtime = OVERTIME.SALARY;
        settingTime.Permission = 5;
        settingTime.SalaryClosingDate = SALARY_CLOSING_DATE
            .LAST_DATE_OF_EACH_MONTH;
        vm.prank(RootAddress);
        timekeeping.updateSettingTime(
            settingTime.FormOFWork,
            settingTime.Shifts,
            dayOff,
            settingTime.Overtime,
            settingTime.Permission,
            settingTime.SalaryClosingDate
        );

        uint _yyyymmdd = 20240701;
        // uint _timeCheckIn = 7 *3600 + 30*60 + 0;
        // uint _timeCheckOut = 18 *3600 + 0*60 + 0;

        for (uint i = 3; i < 26; i++) {
            //ca1
            vm.prank(EmployeeAddress);
            vm.warp(
                DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                    _yyyymmdd + i,
                    7 * 3600 + 30 * 60 + 0
                )
            );
            vm.prank(EmployeeAddress);
            timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);

            vm.prank(EmployeeAddress);
            vm.warp(
                DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                    _yyyymmdd + i,
                    12 * 3600 + 30 * 60 + 0
                )
            );
            vm.prank(EmployeeAddress);
            timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

            //ca2
            vm.prank(EmployeeAddress);
            vm.warp(
                DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                    _yyyymmdd + i,
                    13 * 3600 + 30 * 60 + 0
                )
            );
            vm.prank(EmployeeAddress);
            timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);

            vm.prank(EmployeeAddress);
            vm.warp(
                DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                    _yyyymmdd + i,
                    17 * 3600 + 40 * 60 + 0
                )
            );
            vm.prank(EmployeeAddress);
            timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);
        }

        //Nghỉ có lương 2 ca đầu
        vm.prank(EmployeeAddress);
        timekeeping.createLeavePermissionRequest(
            1719820800,
            1719855000,
            REASON_LEAVE_TYPE.HAVE_PERSONAL_OR_FAMILY_MATTERS,
            "OTHER"
        );

        vm.prank(RootAddress);
        timekeeping.updateRequestStatus(1, REQUEST_STATUS.APPROVAL);

        //ngày 2 làm nửa ca đầu, ca 2 không làm
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                _yyyymmdd + 1,
                8 * 3600
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                _yyyymmdd + 1,
                10 * 3600
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

        //ngày 3 ca 2 đi trễ 1h
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                _yyyymmdd + 2,
                9 * 3600
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                _yyyymmdd + 2,
                12 * 3600
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

        //ngày 3 ca 2 về sớm 1h
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                _yyyymmdd + 2,
                13 * 3600 + 30 * 60
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                _yyyymmdd + 2,
                16 * 3600 + 30 * 60
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

        //OT 2H
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                20240724,
                19 * 3600 + 30 * 60
            )
        );
        vm.prank(EmployeeAddress);
        timekeeping.overtimeAttendance(workPlaceAttendanceArr[0], "REASON");

        address[] memory addressEmployee = new address[](1);
        addressEmployee[0] = EmployeeAddress;
        vm.startPrank(HRManagerAddress);
        uint[] memory yyyymmddArr = new uint[](1);
        yyyymmddArr[0] = _yyyymmdd / 100;
        Salary[] memory resultSalary = timekeeping
            .getSalaryOfEmployeesByYYYYMMs(addressEmployee, yyyymmddArr);

        uint resultTotalSalary = timekeeping.getTotalSalaryEmployeeByYYYYMM(
            EmployeeAddress,
            yyyymmddArr[0]
        );
        vm.stopPrank();
        vm.prank(EmployeeAddress);
        SalaryDeducation[] memory resultSalaryDeducation = timekeeping
            .getSalaryDeducationOfMeByYYYYMMs(yyyymmddArr);
        vm.prank(EmployeeAddress);
        OTSalary[] memory resultOTSalary = timekeeping.getOTSalaryOfMeByYYYYMMs(
            yyyymmddArr
        );

        uint totalcount = 0;
        for (uint i = 0; i < resultSalary.length; i++) {
            totalcount += resultSalary[i].amount;
            //console.log(441, i, resultSalary[i].amount);
        }
        // for (uint i = 0; i < resultSalaryDeducation.length; i++) {
        //     console.log(3313, resultSalaryDeducation[i].Amount);
        // }

        vm.assertEq(192307692240, resultOTSalary[0].amount);
        vm.assertEq(96153846120, resultSalaryDeducation[0].Amount);

        vm.assertEq(19326923070120, totalcount);
        vm.assertEq(19326923070120, resultTotalSalary);
        vm.assertEq(
            19423076916240,
            resultTotalSalary -
                resultSalaryDeducation[0].Amount +
                resultOTSalary[0].amount
        );
        vm.stopPrank();
    }

    function test_salary_shifts2() public {
        Timekeeping timekeeping = new Timekeeping();
        initTest(timekeeping);
        generateSettingAddress(timekeeping);

        (
            Employee memory newEmployee,
            EmployeeDetail memory newEmployeeDetail
        ) = AddEmployeeFull("fullname1", EmployeeAddress, 20000000);
        vm.prank(RootAddress);
        timekeeping.importOneEmployee(newEmployee, newEmployeeDetail);

        vm.prank(RootAddress);
        timekeeping.createSettingRule(
            VIOLATION_TYPE.LATE,
            18 * 60 * 60 + 30 * 60,
            1,
            CONDITION_TYPE.PERMISSION,
            PUNISH_TYPE.SALARY_DEDUCATION_TYPE,
            SALARY_DEDUCATION_TYPE.HOUR
        );
        vm.prank(RootAddress);
        timekeeping.createSettingRule(
            VIOLATION_TYPE.LATE,
            14 * 60 * 60,
            1,
            CONDITION_TYPE.PERMISSION,
            PUNISH_TYPE.SALARY_DEDUCATION_TYPE,
            SALARY_DEDUCATION_TYPE.HOUR
        );

        vm.prank(RootAddress);
        timekeeping.createSettingRule(
            VIOLATION_TYPE.LATE,
            8 * 60 * 60 + 30 * 60,
            1,
            CONDITION_TYPE.PERMISSION,
            PUNISH_TYPE.SALARY_DEDUCATION_TYPE,
            SALARY_DEDUCATION_TYPE.HOUR
        );

        SettingTime memory settingTime;

        settingTime.FormOFWork = FORM_OF_WORK.WORK_IN_SHIFTS;
        settingTime.Shifts = new Shift[](3);
        settingTime.NumberOfShift = 3;
        settingTime.Shifts[0].CheckIn = 8 * 60 * 60;
        settingTime.Shifts[0].CheckOut = 12 * 60 * 60;

        settingTime.Shifts[1].CheckIn = 13 * 60 * 60 + 30 * 60;
        settingTime.Shifts[1].CheckOut = 17 * 60 * 60 + 30 * 60;

        settingTime.Shifts[2].CheckIn = 17 * 60 * 60 + 55 * 60;
        settingTime.Shifts[2].CheckOut = 23 * 60 * 60 + 55 * 60;

        vm.prank(RootAddress);
        SettingAddress memory settingAddress = timekeeping.getSettingAddress();
        WorkPlaceAttendance[]
            memory workPlaceAttendanceArr = new WorkPlaceAttendance[](
                settingAddress.WorkPlaces.length
            );
        for (uint i = 0; i < settingAddress.WorkPlaces.length; i++) {
            WorkPlace memory item = settingAddress.WorkPlaces[i];
            workPlaceAttendanceArr[i] = WorkPlaceAttendance({
                WorkPlaceId: item.WorkPlaceId,
                LatLon: item.LatLon
            });
        }
        DayOffRequest[] memory dayOff = new DayOffRequest[](15);
        dayOff[0] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 1});
        dayOff[1] = DayOffRequest({shiftId: 2, shiftNum: 2, time: 2});
        dayOff[2] = DayOffRequest({shiftId: 3, shiftNum: 1, time: 3});
        dayOff[3] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 4});
        dayOff[4] = DayOffRequest({shiftId: 2, shiftNum: 1, time: 5});
        dayOff[5] = DayOffRequest({shiftId: 3, shiftNum: 1, time: 6});
        dayOff[6] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 7});
        dayOff[7] = DayOffRequest({shiftId: 2, shiftNum: 1, time: 8});
        dayOff[8] = DayOffRequest({shiftId: 3, shiftNum: 1, time: 9});
        dayOff[9] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 10});
        dayOff[10] = DayOffRequest({shiftId: 2, shiftNum: 1, time: 6});
        dayOff[11] = DayOffRequest({shiftId: 3, shiftNum: 1, time: 7});
        dayOff[12] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 8});
        dayOff[13] = DayOffRequest({shiftId: 2, shiftNum: 1, time: 9});
        dayOff[14] = DayOffRequest({shiftId: 3, shiftNum: 1, time: 10});
        vm.prank(RootAddress);
        timekeeping.updateSettingTime(
            settingTime.FormOFWork,
            settingTime.Shifts,
            dayOff,
            settingTime.Overtime,
            settingTime.Permission,
            settingTime.SalaryClosingDate
        );

        settingTime.Overtime = OVERTIME.SALARY;
        settingTime.Permission = 5;
        settingTime.SalaryClosingDate = SALARY_CLOSING_DATE
            .LAST_DATE_OF_EACH_MONTH;

        uint _yyyymmdd = 20240701;
        // uint _timeCheckIn = 7 *3600 + 30*60 + 0;
        // uint _timeCheckOut = 18 *3600 + 0*60 + 0;

        for (uint i = 2; i < 26; i++) {
            //ca1
            vm.prank(EmployeeAddress);
            vm.warp(
                DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                    _yyyymmdd + i,
                    7 * 3600 + 30 * 60 + 0
                )
            );
            vm.prank(EmployeeAddress);
            timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);

            vm.prank(EmployeeAddress);
            vm.warp(
                DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                    _yyyymmdd + i,
                    12 * 3600 + 30 * 60 + 0
                )
            );
            vm.prank(EmployeeAddress);
            timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

            //ca2
            vm.prank(EmployeeAddress);
            vm.warp(
                DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                    _yyyymmdd + i,
                    13 * 3600 + 30 * 60 + 0
                )
            );
            vm.prank(EmployeeAddress);
            timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);

            vm.prank(EmployeeAddress);
            vm.warp(
                DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                    _yyyymmdd + i,
                    17 * 3600 + 40 * 60 + 0
                )
            );
            vm.prank(EmployeeAddress);
            timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

            //ca3
            vm.prank(EmployeeAddress);
            vm.warp(
                DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                    _yyyymmdd + i,
                    17 * 3600 + 50 * 60 + 0
                )
            );
            vm.prank(EmployeeAddress);
            timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);

            vm.prank(EmployeeAddress);
            vm.warp(
                DateTimeLibrary._getTimestampFromYYYYMMDDTime(
                    _yyyymmdd + i,
                    23 * 3600 + 55 * 60
                )
            );
            vm.prank(EmployeeAddress);
            timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);
        }

        //ngày 1 làm 2 ca 4 tiếng
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd, 8 * 3600)
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd, 12 * 3600)
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

         vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd, 13 * 3600 + 30 * 60)
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd, 17 * 3600  + 30 * 60)
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

        //ngày 2 làm ca 1 4h và ca 3 6h
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd + 1, 8 * 3600)
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd + 1, 12 * 3600)
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd + 1, 17 * 3600 + 50 * 60)
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkInAttendance(workPlaceAttendanceArr[0]);
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd + 1, 23 * 3600  + 59 * 60)
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkOutAttendance(workPlaceAttendanceArr[0]);

        address[] memory addressEmployee = new address[](1);
        addressEmployee[0] = EmployeeAddress;
        vm.startPrank(HRManagerAddress);
        uint[] memory yyyymmddArr = new uint[](1);
        yyyymmddArr[0] = _yyyymmdd / 100;
        Salary[] memory resultSalary = timekeeping
            .getSalaryOfEmployeesByYYYYMMs(addressEmployee, yyyymmddArr);

        uint resultTotalSalary = timekeeping.getTotalSalaryEmployeeByYYYYMM(
            EmployeeAddress,
            yyyymmddArr[0]
        );
        vm.stopPrank();
        vm.prank(EmployeeAddress);
        SalaryDeducation[] memory resultSalaryDeducation = timekeeping
            .getSalaryDeducationOfMeByYYYYMMs(yyyymmddArr);
        vm.prank(EmployeeAddress);
        //OTSalary[] memory resultOTSalary = timekeeping.getOTSalaryOfMeByYYYYMMs(yyyymmddArr);

        uint totalcount = 0;
        for (uint i = 0; i < resultSalary.length; i++) {
            totalcount += resultSalary[i].amount;
            //console.log(335, i, resultSalary[i].amount);
        }

        //vm.assertEq(192240, resultOTSalary[0].amount);
        vm.assertEq(439560439200, resultSalary[0].amount + resultSalary[1].amount);
        vm.assertEq(549450549000, resultSalary[2].amount + resultSalary[3].amount);
        vm.assertEq(769230768600, resultSalary[4].amount + resultSalary[5].amount  + resultSalary[6].amount);

        vm.assertEq(19450549434600, totalcount);
        vm.assertEq(19450549434600, resultTotalSalary);

        vm.stopPrank();
    }

    function seedSetting(
        Timekeeping timekeeping
    ) internal returns (WorkPlaceAttendance[] memory) {
        initTest(timekeeping);
        generateSettingAddress(timekeeping);

        (
            Employee memory newEmployee,
            EmployeeDetail memory newEmployeeDetail
        ) = AddEmployeeFull("fullname1", EmployeeAddress, 20000000);
        vm.prank(RootAddress);
        timekeeping.importOneEmployee(newEmployee, newEmployeeDetail);



        SettingTime memory settingTime;
        DayOffRequest[] memory dayOff = new DayOffRequest[](10);
        settingTime.FormOFWork = FORM_OF_WORK.BY_DATE;
        settingTime.Shifts = new Shift[](1);
        settingTime.NumberOfShift = 1;
        settingTime.Shifts[0].CheckIn = 8 * 60 * 60 + 0 * 60 + 0;
        settingTime.Shifts[0].CheckOut = 17 * 60 * 60 + 30 * 60 + 0;
        settingTime.Shifts[0].BreakTimeFrom = 12 * 60 * 60 + 0 + 0;
        settingTime.Shifts[0].BreakTimeTo = 13 * 60 * 60 + 30 * 60 + 0;
        vm.prank(RootAddress);
        SettingAddress memory settingAddress = timekeeping.getSettingAddress();
        WorkPlaceAttendance[]
            memory workPlaceAttendanceArr = new WorkPlaceAttendance[](
                settingAddress.WorkPlaces.length
            );
        for (uint i = 0; i < settingAddress.WorkPlaces.length; i++) {
            WorkPlace memory item = settingAddress.WorkPlaces[i];
            workPlaceAttendanceArr[i] = WorkPlaceAttendance({
                WorkPlaceId: item.WorkPlaceId,
                LatLon: item.LatLon
            });
        }

        dayOff[0] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 1});
        dayOff[1] = DayOffRequest({shiftId: 1, shiftNum: 2, time: 2});
        dayOff[2] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 3});
        dayOff[3] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 4});
        dayOff[4] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 5});
        dayOff[5] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 6});
        dayOff[6] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 7});
        dayOff[7] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 8});
        dayOff[8] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 9});
        dayOff[9] = DayOffRequest({shiftId: 1, shiftNum: 1, time: 10});
        vm.prank(RootAddress);
        settingTime.Overtime = OVERTIME.SALARY;
        settingTime.Permission = 5;
        settingTime.SalaryClosingDate = SALARY_CLOSING_DATE
            .LAST_DATE_OF_EACH_MONTH;
        timekeeping.updateSettingTime(
            settingTime.FormOFWork,
            settingTime.Shifts,
            dayOff,
            settingTime.Overtime,
            settingTime.Permission,
            settingTime.SalaryClosingDate
        );

        return workPlaceAttendanceArr;
    }

    function seedCheckOutCheckIn(
        Timekeeping timekeeping,
        WorkPlaceAttendance memory place,
        uint _yyyymmdd,
        uint checkin,
        uint checkout
    ) internal {
        //Đi trễ 1h
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd, checkin)
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkInAttendance(place);
        vm.prank(EmployeeAddress);
        vm.warp(
            DateTimeLibrary._getTimestampFromYYYYMMDDTime(_yyyymmdd, checkout)
        );
        vm.prank(EmployeeAddress);
        timekeeping.checkOutAttendance(place);
    }

    function test_salary_deducation_minute() public {
        Timekeeping timekeeping = new Timekeeping();

        WorkPlaceAttendance[] memory workPlaceAttendanceArr = seedSetting(
            timekeeping
        );

        vm.prank(RootAddress);
        timekeeping.createSettingRule(
            VIOLATION_TYPE.LATE,
            8 * 60 * 60 + 1 * 60,
            1,
            CONDITION_TYPE.PERMISSION,
            PUNISH_TYPE.SALARY_DEDUCATION_TYPE,
            SALARY_DEDUCATION_TYPE.MINUTE
        );

        uint _yyyymmdd = 20240701;
        // uint _timeCheckIn = 7 *3600 + 30*60 + 0;
        uint _timeCheckOut = 18 * 3600 + 0 * 60 + 0;

        seedCheckOutCheckIn(
            timekeeping,
            workPlaceAttendanceArr[0],
            _yyyymmdd + 24,
            8 * 3600 + 1*60,
            _timeCheckOut
        );

        address[] memory addressEmployee = new address[](1);
        addressEmployee[0] = EmployeeAddress;
        uint[] memory yyyymmddArr = new uint[](1);
        yyyymmddArr[0] = _yyyymmdd / 100;

        vm.prank(EmployeeAddress);
        SalaryDeducation[] memory resultSalaryDeducation = timekeeping
            .getSalaryDeducationOfMeByYYYYMMs(yyyymmddArr);

        vm.assertEq(1602564102, resultSalaryDeducation[0].Amount);

        vm.stopPrank();
    }

    function test_salary_deducation_hour() public {
        Timekeeping timekeeping = new Timekeeping();

        WorkPlaceAttendance[] memory workPlaceAttendanceArr = seedSetting(
            timekeeping
        );

                vm.prank(RootAddress);
        timekeeping.createSettingRule(
            VIOLATION_TYPE.LATE,
            8 * 60 * 60 + 30 * 60,
            1,
            CONDITION_TYPE.PERMISSION,
            PUNISH_TYPE.SALARY_DEDUCATION_TYPE,
            SALARY_DEDUCATION_TYPE.MINUTE
        );

        uint _yyyymmdd = 20240701;
        // uint _timeCheckIn = 7 *3600 + 30*60 + 0;
        uint _timeCheckOut = 18 * 3600 + 0 * 60 + 0;

        seedCheckOutCheckIn(
            timekeeping,
            workPlaceAttendanceArr[0],
            _yyyymmdd + 24,
            9 * 3600,
            _timeCheckOut
        );

        address[] memory addressEmployee = new address[](1);
        addressEmployee[0] = EmployeeAddress;
        uint[] memory yyyymmddArr = new uint[](1);
        yyyymmddArr[0] = _yyyymmdd / 100;

        vm.prank(EmployeeAddress);
        SalaryDeducation[] memory resultSalaryDeducation = timekeeping
            .getSalaryDeducationOfMeByYYYYMMs(yyyymmddArr);

        vm.assertEq(96153846120, resultSalaryDeducation[0].Amount);

        vm.stopPrank();
    }

    function test_salary_deducation_day() public {
        Timekeeping timekeeping = new Timekeeping();

        WorkPlaceAttendance[] memory workPlaceAttendanceArr = seedSetting(
            timekeeping
        );

        vm.prank(RootAddress);
        timekeeping.createSettingRule(
            VIOLATION_TYPE.LATE,
            8 * 60 * 60 + 30 * 60,
            1,
            CONDITION_TYPE.PERMISSION,
            PUNISH_TYPE.SALARY_DEDUCATION_TYPE,
            SALARY_DEDUCATION_TYPE.DAY
        );

        uint _yyyymmdd = 20240701;
        // uint _timeCheckIn = 7 *3600 + 30*60 + 0;
        uint _timeCheckOut = 18 * 3600 + 0 * 60 + 0;

        seedCheckOutCheckIn(
            timekeeping,
            workPlaceAttendanceArr[0],
            _yyyymmdd + 24,
            9 * 3600,
            _timeCheckOut
        );

        address[] memory addressEmployee = new address[](1);
        addressEmployee[0] = EmployeeAddress;
        uint[] memory yyyymmddArr = new uint[](1);
        yyyymmddArr[0] = _yyyymmdd / 100;

        vm.prank(EmployeeAddress);
        SalaryDeducation[] memory resultSalaryDeducation = timekeeping
            .getSalaryDeducationOfMeByYYYYMMs(yyyymmddArr);

        vm.assertEq(769230768960, resultSalaryDeducation[0].Amount);

        vm.stopPrank();
    }
     function test_salary_deducation_halfday() public {
        Timekeeping timekeeping = new Timekeeping();

        WorkPlaceAttendance[] memory workPlaceAttendanceArr = seedSetting(
            timekeeping
        );

        vm.prank(RootAddress);
        timekeeping.createSettingRule(
            VIOLATION_TYPE.LATE,
            8 * 60 * 60 + 30 * 60,
            1,
            CONDITION_TYPE.PERMISSION,
            PUNISH_TYPE.SALARY_DEDUCATION_TYPE,
            SALARY_DEDUCATION_TYPE.HALF_DAY
        );

        uint _yyyymmdd = 20240701;
        // uint _timeCheckIn = 7 *3600 + 30*60 + 0;
        uint _timeCheckOut = 18 * 3600 + 0 * 60 + 0;

        seedCheckOutCheckIn(
            timekeeping,
            workPlaceAttendanceArr[0],
            _yyyymmdd + 24,
            9 * 3600,
            _timeCheckOut
        );

        address[] memory addressEmployee = new address[](1);
        addressEmployee[0] = EmployeeAddress;
        uint[] memory yyyymmddArr = new uint[](1);
        yyyymmddArr[0] = _yyyymmdd / 100;

        vm.prank(EmployeeAddress);
        SalaryDeducation[] memory resultSalaryDeducation = timekeeping
            .getSalaryDeducationOfMeByYYYYMMs(yyyymmddArr);

        vm.assertEq(384615384480, resultSalaryDeducation[0].Amount);

        vm.stopPrank();
    }
}
