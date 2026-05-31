// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

struct NotiParams{
  string repo;
  bytes data;
  uint8 dataStruct;
  string title;
  string body;
}

interface INoti{
  function AddNoti(
      NotiParams memory params,
      address _to
    ) external returns (bool);

  function AddMultipleNoti(
        NotiParams memory params,
        address[] memory _to
    ) external returns (bool);
}
