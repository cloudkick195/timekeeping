// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AttendanceTracker {
    // Định nghĩa một cấu trúc dữ liệu Attendance gồm các trường:
    struct Attendance {
        uint256 employeeId; // ID của nhân viên
        uint256 requiredCheckInTime;  // Thời gian check-in yêu cầu, ví dụ 08:00
        uint256 checkInTime; // Thời gian check-in thực tế
        uint256 checkOutTime; // Thời gian check-out
    }

    // Tạo một mapping (bảng tra cứu) với key là ID của nhân viên, lưu trữ các bản ghi chấm công của nhân viên, khi thêm vào thì sẽ mất phí gas
    mapping(uint256 => Attendance[]) private attendanceRecords;

    // Tạo một biến lưu trữ địa chỉ của chủ sở hữu hợp đồng
    address private owner;
    // Và một mapping lưu trữ các địa chỉ được phép thực hiện các hành động trong hợp đồng
    mapping(address => bool) private authorizedEntities;

    constructor() {
        owner = msg.sender; // Gán địa chỉ của người tạo hợp đồng làm chủ sở hữu
        authorizedEntities[owner] = true;  // Thêm chủ sở hữu vào danh sách các đối tượng được phép
    }

    modifier onlyAuthorized() {
         // Định nghĩa một modifier (điều kiện) để kiểm tra quyền truy cập
        require(
            authorizedEntities[msg.sender],
            "Only authorized entities can perform this action."
        );
        _;
    }

    // Hàm cho phép nhân viên check-in
    function checkin(uint256 _employeeId) public onlyAuthorized {
        uint256 _checkInTime = block.timestamp; // Lấy thời gian hiện tại
        uint256 _requiredCheckInTime = 28800; // 08:00 tính bằng giây

        // Tạo một record cho checkin với key là id của nhân viên
        Attendance memory newAttendance = Attendance(
            _employeeId,
            _requiredCheckInTime,
            _checkInTime,
            0
        );
        attendanceRecords[_employeeId].push(newAttendance); // Thêm bản ghi chấm công vào mapping
    }

    // Hàm cho phép nhân viên check-out
    function checkout(uint256 _employeeId) public onlyAuthorized {

        //Kiểm tra id có tồn tại
        require(
            attendanceRecords[_employeeId].length > 0,
            "No attendance record found for the employee."
        );
        
        //lấy checkin cuối cùng để checkout
        Attendance storage lastAttendance = attendanceRecords[_employeeId][
            attendanceRecords[_employeeId].length - 1
        ];
        require(
            lastAttendance.checkOutTime == 0,
            "Employee has already checked out."
        );
        lastAttendance.checkOutTime = block.timestamp; // Cập nhật thời gian check-out
    }

     // Hàm lấy record checkin của một nhân viên
    function getAttendanceByEmployee(
        uint256 _employeeId
    ) public view onlyAuthorized returns (Attendance[] memory) {
       
        return attendanceRecords[_employeeId];
    }

    // Hàm lấy record checkin trong khoảng time
    function getAttendanceByDateRange(
        uint256 _startDate,
        uint256 _endDate
    ) public view onlyAuthorized returns (Attendance[] memory) {
        Attendance[] memory result = new Attendance[](0);
        for (uint256 employeeId = 0; ; employeeId++) {
            Attendance[] storage employeeAttendance = attendanceRecords[
                employeeId
            ];
            if (employeeAttendance.length == 0) {
                break;
            }
            for (uint256 i = 0; i < employeeAttendance.length; i++) {
                if (
                    employeeAttendance[i].checkInTime >= _startDate &&
                    employeeAttendance[i].checkInTime <= _endDate
                ) {
                    result[result.length] = employeeAttendance[i];
                }
            }
        }
        return result;
    }

    function addAuthorizedEntity(address _entity) public onlyAuthorized {
         // Hàm thêm một đối tượng được phép vào danh sách
        authorizedEntities[_entity] = true;
    }

    function removeAuthorizedEntity(address _entity) public onlyAuthorized {
        // Hàm xóa một đối tượng khỏi danh sách những đối tượng được phép
        delete authorizedEntities[_entity];
    }
}
