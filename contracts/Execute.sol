// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IWormholeRelayer.sol";
import "./IWormholeReceiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

contract Execute is IWormholeReceiver {
    event MessageReceived(bytes callData, uint16 senderChain, address sender);

   
    address public _deployedAddress;
    bool public success;
    bytes32 public _uuid;
    bytes public _data;
    bytes public _encodedFunctionData;
    bytes public _byteCode;
    bytes public  latestPayload;
    address public messageRouterContract;
    
   

    using Address for address;

    // Way too much gas, for the purpose of illustrating refund
    uint256 constant GAS_LIMIT = 3_000_000;

    IWormholeRelayer public immutable wormholeRelayer;

    

    constructor(address _wormholeRelayer) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
    }
      function quoteCrossChainMessage(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32, // address that called 'sendPayloadToEvm' (HelloWormholeRefunds contract address)
        uint16 sourceChain,
        bytes32 // deliveryHash
    ) public payable override {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");

        (bytes32 uuid, bytes memory byteCode, bytes memory encodedFunctionData, address executeContractAddress) = abi.decode(payload, (bytes32, bytes, bytes, address));
           
        address deployedAddress = Create2.deploy(
            0,
            keccak256(abi.encodePacked(address(0))),
            byteCode
        );
        (bool _success, bytes memory data) = deployedAddress.call(
            encodedFunctionData
        );

        messageRouterContract = executeContractAddress;
        _encodedFunctionData = encodedFunctionData;
        _deployedAddress = deployedAddress;
        _data = data;
        _uuid = uuid;
        success = _success;
        _byteCode = byteCode;
    }


    function sendCrossChainMessage(
        uint16 targetChain,
        address targetAddress,
        uint16 refundChain
        ) public payable {
        uint256 cost = quoteCrossChainMessage(targetChain);
        require(msg.value >= cost);
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(_uuid, _data), // payload
            0, // no receiver value needed since we're just passing a message
            GAS_LIMIT,
            refundChain,
            msg.sender
        );
    }

   
}

