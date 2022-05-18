// SPDX-License-Identifier: unlicense
pragma solidity ^0.8.0;

import "./ERCX721fier.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERCX2615 is Ownable, ERCX721fier {

    using Counters for Counters.Counter;
    Counters.Counter public tokenId;
    string baseUriExtended;

     uint256 immutable public _maxSupply = 10000;

    constructor() ERCX721fier("TEST", "TSTSS") {

    }

    function mint(address _account) external {
        require(tokenId.current() + 1 <= _maxSupply, "max supply reached");
        _mint(_account, tokenId.current());
        tokenId.increment();
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUriExtended;
    }

    function burn(uint256 _tokenId) external{
        _burn(_tokenId);
    }
    
    function setBaseUri(string memory _uri) external onlyOwner{
        baseUriExtended = _uri;
    }


}
