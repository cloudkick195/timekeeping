// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "@openzeppelin/contracts@v4.9.0/utils/Strings.sol";
import "../constant.sol";
import "../model.sol";

library UtilsLibrary {
    function getRequestTypeName(
        REQUEST_TYPE _reqquestType
    ) internal pure returns (string memory) {
        if (_reqquestType == REQUEST_TYPE.LEAVE_PERMISSION) {
            return "Leave permission";
        }
        if (_reqquestType == REQUEST_TYPE.LATE_ARRIVAL) {
            return "Late arrival";
        }
        if (_reqquestType == REQUEST_TYPE.COME_BACK_SOON) {
            return "Come back soon";
        }
        if (_reqquestType == REQUEST_TYPE.OFFER_SALARY) {
            return "Offer salary";
        }
        if (_reqquestType == REQUEST_TYPE.SUBSIDIZE) {
            return "Subsidize";
        }
        if (_reqquestType == REQUEST_TYPE.RESIGN) {
            return "Resign";
        }
        if (_reqquestType == REQUEST_TYPE.RULE) {
            return "Rule";
        }
        if (_reqquestType == REQUEST_TYPE.IN_OUT_ON_BEHALF) {
            return "In/Out on behalf";
        }
        if (_reqquestType == REQUEST_TYPE.SALARY_DEDUCATION) {
            return "Salary Deducation";
        }
        return "Other";
    }

    function getReasonRequestName(
        REASON_LEAVE_TYPE _reason
    ) internal pure returns (string memory) {
        if (_reason == REASON_LEAVE_TYPE.SICK_LEAVE) {
            return "Annual Leave";
        }
        if (_reason == REASON_LEAVE_TYPE.MATERNITY_LEAVE) {
            return "Maternity leave";
        }
        if (_reason == REASON_LEAVE_TYPE.HAVE_PERSONAL_OR_FAMILY_MATTERS) {
            return "Have personal or family matters";
        }
        if (_reason == REASON_LEAVE_TYPE.ANNUAL_LEAVE) {
            return "Annual leave";
        }
        return "Other";
    }

    function getReasonRequestName(
        REASON_LATE_TYPE _reason
    ) internal pure returns (string memory) {
        if (_reason == REASON_LATE_TYPE.TRAFFIC_JAM) {
            return "Traffic jam";
        }
        if (_reason == REASON_LATE_TYPE.FEELING_TIRED_INSIDE) {
            return "Feeling tired inside";
        }
        if (_reason == REASON_LATE_TYPE.HAVE_PERSONAL_OR_FAMILY_MATTERS) {
            return "Have personal or family matters";
        }
        return "Other";
    }

    function getReasonRequestName(
        REASON_COME_BACK_SOON _reason
    ) internal pure returns (string memory) {
        if (_reason == REASON_COME_BACK_SOON.MEDICAL_APPOINTMENT_SCHEDULE) {
            return "Medical appointment schedule";
        }
        if (_reason == REASON_COME_BACK_SOON.THERE_IS_AN_EMERGENCY) {
            return "There's an emergency";
        }
        if (_reason == REASON_COME_BACK_SOON.HAVE_PERSONAL_OR_FAMILY_MATTERS) {
            return "Have personal or family matters";
        }
        return "Other";
    }

    function getReasonRequestName(
        REASON_COME_OFFER_SALARY _reason
    ) internal pure returns (string memory) {
        if (_reason == REASON_COME_OFFER_SALARY.INCREASE_PRODUCTIVITY) {
            return "Increase productivity";
        }
        if (_reason == REASON_COME_OFFER_SALARY.INCREASE_LIVING_COSTS) {
            return "Increase living costs";
        }
        if (
            _reason ==
            REASON_COME_OFFER_SALARY.INCREASED_RESPONSIBILITIES_AND_ROLES
        ) {
            return "Increased responsibilities and roles";
        }
        return "Other";
    }

    function getReasonRequestName(
        REASON_COME_SUBSIDIZE _reason
    ) internal pure returns (string memory) {
        if (_reason == REASON_COME_SUBSIDIZE.LUNCH) {
            return "Lunch";
        }
        if (_reason == REASON_COME_SUBSIDIZE.PARKING_FEE) {
            return "Parking fee";
        }
        if (_reason == REASON_COME_SUBSIDIZE.GASOLINE) {
            return "Gasoline";
        }
        return "Other";
    }

    function getReasonRequestName(
        REASON_RESIGN _reason
    ) internal pure returns (string memory) {
        if (_reason == REASON_RESIGN.THE_ENVIRONMENT_IS_NOT_SUITABLE) {
            return "The environment is not suitable";
        }
        if (_reason == REASON_RESIGN.UNSUITABLE_WORK) {
            return "Unsuitable work";
        }
        if (_reason == REASON_RESIGN.THE_WORK_IS_TOO_DIFFICULT) {
            return "The work is too difficult";
        }
        return "Other";
    }

    function getRequestStatusName(
        REQUEST_STATUS _requestStatus
    ) internal pure returns (string memory) {
        if (_requestStatus == REQUEST_STATUS.APPROVAL) {
            return "Approval";
        }
        if (_requestStatus == REQUEST_STATUS.REJECT) {
            return "Reject";
        }
        return "Un read";
    }

    function getNotificationTypeName(
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
}
