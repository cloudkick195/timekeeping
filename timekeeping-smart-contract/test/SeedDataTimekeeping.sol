// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Timekeeping} from "../contracts/Timekeeping.sol";
import "../contracts/model.sol";

abstract contract SeedDataTimekeeping is Timekeeping{
    function seedEmployee(
        address wallet,
        uint seed
    ) public pure returns (Employee memory, EmployeeDetail memory) {
        Employee memory newEmployee = Employee({
            Wallet: wallet,

            FullName: "FullName",
            
            Location: "Location",
            DepartmentId: (seed % 3),
            PositionId: (seed % 2),
            Branch: "Branch",
            
            OnboardDateTime: 1719883722 + seed
        });

        EmployeeDetail memory newEmployeeDetail = EmployeeDetail({
            Wallet: wallet,

            Gender: GENDER_TYPE.FEMALE,
            DateOfBirth: 0,
            PhoneNumber: 0,
            Email: "be_earning@be-earning.com",

            StatusOfWork: seed,
            TypeOfWork: seed,
            TypeOfContract: seed,
            PositionSalary: (3100000 + seed) * 100,
            TaxableSalary: 10000 + seed,
            PersonalIncomeTax: seed,

            PermanentAddress: "PermanentAddress",
            NumberOfDependents: seed,
            AcademicLevel: seed,

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

    function seedSeetingRule(uint seed) public pure returns (SettingRule memory) {
        SettingRule memory rule;

        rule.ViolationType = VIOLATION_TYPE.LATE;
        rule.Time = 8 * 60 * 60 + 80 * 60 + seed;
        rule.Quantity = 3;
        rule.ConditionType = CONDITION_TYPE.PERMISSION;
        rule.PunishType = PUNISH_TYPE.SALARY_DEDUCATION_TYPE;
        rule.SalaryDeducationType = SALARY_DEDUCATION_TYPE.HOUR;

        return rule;
    }

    function seedSeetingTime(uint seed) public pure returns (DayOffRequest[] memory, SettingTime memory) {
        SettingTime memory settingTime;
        settingTime.FormOFWork = FORM_OF_WORK.BY_DATE;
       DayOffRequest[] memory dayOff = new DayOffRequest[](3);
        if (settingTime.FormOFWork == FORM_OF_WORK.WORK_IN_SHIFTS) {
            settingTime.NumberOfShift = 2;
            settingTime.Shifts = new Shift[](2);
            settingTime.Shifts[0].CheckIn = 8*60*60 + 0*60 + 0;
            settingTime.Shifts[0].CheckOut = 12*60*60 + 0*60 + 0;

            settingTime.Shifts[1].CheckIn = 13*60*60 + 30*60 + 0;
            settingTime.Shifts[1].CheckOut = 17*60*60 + 30*60 + 0;

        } else {
            settingTime.Shifts = new Shift[](1);
            settingTime.NumberOfShift = 1;
            settingTime.Shifts[0].CheckIn = 8*60*60 + 0*60 + 0;
            settingTime.Shifts[0].CheckOut = 17*60*60 + 30*60 + 0;
            settingTime.Shifts[0].BreakTimeFrom = 12*60*60 + 0 + 0;
            settingTime.Shifts[0].BreakTimeTo = 13*60*60 + 30*60 + 0;
        }
        dayOff[0] = DayOffRequest({
            shiftId: 1,
            shiftNum:1,
            time: seed + 1
        });
        dayOff[1] = DayOffRequest({
            shiftId: 1,
            shiftNum:2,
            time: seed + 2
        });
        dayOff[2] = DayOffRequest({
            shiftId: 1,
            shiftNum:1,
            time: seed + 4
        });
        settingTime.Overtime = OVERTIME(seed % 3);
        settingTime.Permission = 5;
        settingTime.SalaryClosingDate = SALARY_CLOSING_DATE(seed % 1);

        return (dayOff, settingTime);
    }

    function seedSeetingAddress(uint seed) public pure returns (SettingAddress memory) {
        SettingAddress memory settingAddress;
        settingAddress.SemiClosed = seed;

        WorkPlace[] memory workPlaces = new WorkPlace[](2);
        workPlaces[0].LocationName = "LocationName 0";
        workPlaces[0].LocationAddress = "LocationAddress 0";
        workPlaces[0].LatLon = "LatLon 0";

        workPlaces[1].LocationName = "LocationName 1";
        workPlaces[1].LocationAddress = "LocationAddress 1";
        workPlaces[1].LatLon = "LatLon 1";

        settingAddress.WorkPlaces = workPlaces;
        return settingAddress;
    }

    function seedWorkPlaces() public pure returns(WorkPlace memory){
        WorkPlace memory workPlace;
        workPlace.WorkPlaceId = 1;
        workPlace.LocationName = "Building 001";
        workPlace.LocationAddress = "Q1, HCM, VN";
        workPlace.LatLon = "1111111111,000000000000";
        return workPlace;
    }

    function seedWorkPlaceAttendance() public pure returns(WorkPlaceAttendance memory){
        WorkPlaceAttendance memory workPlace;
        workPlace.WorkPlaceId = 1;
        workPlace.LatLon = "1111111111,000000000000";
        return workPlace;
    }

}
