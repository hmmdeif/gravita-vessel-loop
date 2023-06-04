// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.10;

interface ICurveExchange {
    function exchange(address _pool, address _from, address _to, uint256 _amount, uint256 _expected, address _receiver) external payable returns (uint256);
    function get_best_rate(address _from, address _to, uint256 _amount) external view returns (address, uint256);
    function exchange_multiple(address[9] calldata _route, uint256[3][4] calldata _swapParams, uint256 _amount, uint256 _expected, address _receiver) external payable returns (uint256);
}