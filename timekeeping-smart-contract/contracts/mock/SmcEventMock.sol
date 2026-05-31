// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

contract SmcEventMock {
    constructor() payable {
    }

    struct NotiParams{
        string repo;
        bytes data;
        uint8 dataStruct;
        string title;
        string body;
    }

    event NotiEvent(
        NotiParams params,
        address to
    );


    function AddNoti(
      NotiParams memory params,
      address _to
    ) public returns (bool) {
        emit NotiEvent(params, _to);
        return true;
    }

    function AddMultipleNoti(
        NotiParams memory params,
        address[] memory _to
    ) external returns (bool) {
        for (uint256 i = 0; i < _to.length; i++) {
            AddNoti(params, _to[i]);
        }
        return true;
    }
}
