// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

library AddressUtils {
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
}

contract OriginBridge {
    using AddressUtils for address;

    bytes32 private constant ADMIN_SLOT = 0x6620b6cd897d53b014f0ae4ca06b7adbc8c5540e40fbee69168637a2dc741ff9;
    bytes32 private constant IMPLEMENTATION_SLOT = 0x349fbcf7810d15da41a8c6047db925faabd93075e1bf9f337efedf130f791a4d;

    constructor (address _i) {
        assert(ADMIN_SLOT == keccak256("astropia.origin.admin"));
        assert(IMPLEMENTATION_SLOT == keccak256("astropia.origin.implementation"));

        require(_i.isContract());

        _setImplementation(_i);
        _setAdmin(msg.sender);
    }

    event AdminChanged (address admin);
    event Upgraded (address implementation);

    modifier onlyAdmin () {
        require(msg.sender == _admin());
        _;
    }

    function proxyChangeAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0));
        _setAdmin(_newAdmin);
        emit AdminChanged(_newAdmin);
    }

    function proxyUpgradeTo(address _newImplementation) public onlyAdmin {
        require(_newImplementation.isContract());
        _setImplementation(_newImplementation);
        emit Upgraded(_newImplementation);
    }

    function proxyUpgradeToAndCall(
        address _newImplementation,
        bytes calldata _data
    ) external payable onlyAdmin returns (bytes memory) {
        proxyUpgradeTo(_newImplementation);
        (bool success, bytes memory data) = address(this).call{value:msg.value}(_data);
        require(success);
        return data;
    }

    function _admin () internal view returns (address a) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            a := sload(slot)
        }
    }

    function _implementation () internal view returns (address i) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            i := sload(slot)
        }
    }

    function admin() external view onlyAdmin returns (address) {
        return _admin();
    }

    function implementation() external view onlyAdmin returns (address) {
        return _implementation();
    }

    function _setAdmin (address newAdmin) internal {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }

    function _setImplementation (address newImplementation) internal {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }
    
    function _work() internal {
        address i = _implementation();
        assembly {
            calldatacopy(0, 0, calldatasize())

            let result := delegatecall(gas(), i, 0, calldatasize(), 0, 0)

            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    fallback () external payable {
        _work();
    }
    
    receive () external payable {
        _work();
    }
}
