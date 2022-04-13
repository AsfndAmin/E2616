// SPDX-License-Identifier: unlicense
pragma solidity ^0.8.0;

import "./ERCX721fier.sol";

contract ERCX2615 is ERCX721fier {
    uint count = 1;
    constructor() ERCX721fier("Tests", "TSTSS") {
    }

    function mint() external {
        _mint(msg.sender, count);
        count++;
    }
}