// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SimpleDEX.sol";

contract DEXFactory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair) {
        require(tokenA != tokenB, "DEXFactory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "DEXFactory: ZERO_ADDRESS");
        require(
            getPair[token0][token1] == address(0),
            "DEXFactory: PAIR_EXISTS"
        );

        // Generate names for the LP token
        string memory name = string(
            abi.encodePacked(
                "LiteDEX Pair-",
                _toHexString(token0),
                "-",
                _toHexString(token1)
            )
        );
        string memory symbol = "LDX-LP";

        SimpleDEX newPair = new SimpleDEX(token0, token1, name, symbol);
        pair = address(newPair);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping for both directions
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function _toHexString(address addr) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(
                uint8(uint256(uint160(addr)) / (2 ** (8 * (19 - i))))
            );
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = _char(hi);
            s[2 * i + 1] = _char(lo);
        }
        return string(abi.encodePacked("0x", s));
    }

    function _char(bytes1 b) internal pure returns (bytes1) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}
