pragma solidity ^0.8.0;

import "../Interface/IERCXReceiver.sol";
contract ERCXHolder is IERCXReceiver {
    function onERCXReceived(address, address, uint256, uint256, bytes memory) public virtual override returns(bytes4) {
        return this.onERCXReceived.selector;
    }
}