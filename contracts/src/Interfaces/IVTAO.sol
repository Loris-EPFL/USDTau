// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IVTAO {
    function wrap(uint256 _taoAmount) external returns (uint256);
    function unwrap(uint256 _vTaoAmount) external returns (uint256);
    function getVTaoByTao(uint256 _taoAmount) external view returns (uint256);
    function getTaoByVTao(uint256 _vTaoAmount) external view returns (uint256);
    function taoPerToken() external view returns (uint256);
    function tokensPerTao() external view returns (uint256);
}