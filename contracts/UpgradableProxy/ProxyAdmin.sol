// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AdminUpgradeabilityProxy.sol";
import "../Base/Ownable.sol";

contract ProxyAdmin is Ownable {
    AdminUpgradeabilityProxy proxy;
    constructor(AdminUpgradeabilityProxy _proxy, address _ownerAdmin) Ownable(_ownerAdmin)
    {
        proxy = _proxy;
    }

    function proxyAddress() public view returns (address) {
        return address(proxy);
    }

    function admin() public returns (address) {
        return proxy.admin();
    }

    function changeAdmin(address newAdmin) public onlyOwner {
        proxy.changeAdmin(newAdmin);
    }

    function upgradeTo(address implementation) public onlyOwner {
        proxy.upgradeTo(implementation);
    }

    function upgradeToAndCall(address implementation, bytes memory data)
        public
        payable
        onlyOwner
    {
        proxy.upgradeToAndCall{value: msg.value}(implementation, data);
    }

}
