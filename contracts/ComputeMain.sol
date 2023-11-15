// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IWormholeRelayer.sol";
import "./IWormholeReceiver.sol";

contract ComputeMain is IWormholeReceiver {
    event MessageReceived(string Message, uint16 senderChain, address sender);

    // Way too much gas, for purpose of illustrating refund
    uint256 constant GAS_LIMIT = 3_000_000;

    bytes32 public _uuid;
    bytes public _data;

    uint nonce;

    struct contractInfo {
        address sourceAddress;
        string sourceFunction;
    }

    event dispatchCallCreated(
        bytes32 uuid,
        address indexed Executer,
        bytes callData
    );

    event CallbackCreated(bytes32 uuid, string sourceFunction, bytes data);

    mapping(bytes32 => contractInfo) uuidToContractInfo;

    IWormholeRelayer public immutable wormholeRelayer;

    string public latestMessage;

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

    function quoteCrossChainMessageRefundPerUnitGasUnused(
        uint16 targetChain
    ) public view returns (uint256 refundPerUnitGasUnused) {
        (, refundPerUnitGasUnused) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );
    }

    function sendCrossChainCompute(
        uint16 targetChain,
        address targetAddress,
        uint16 refundChain,
       
        bytes memory _byteCode,
        bytes calldata _encodedFunctionData
    ) public payable {
        bytes32 uuid = keccak256(
            abi.encodePacked(block.number, msg.data, nonce++)
        );
        uuidToContractInfo[uuid];
         uint256 cost = quoteCrossChainMessage(targetChain);
        require(msg.value >= cost);
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(
            uuid,
            _byteCode,
            _encodedFunctionData,
            address(this)
        ), // payload
            0, // no receiver value needed since we're just passing a message
            GAS_LIMIT,
            refundChain,
            msg.sender
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

        (bytes32 uuid, bytes memory data) = abi.decode(payload,(bytes32, bytes));
         _uuid = uuid;
        _data = data;

    }
    
    function decodeData() public view returns (uint256 integerValue) {
        integerValue = abi.decode(_data, (uint256));
        return integerValue;
    }

    
}
