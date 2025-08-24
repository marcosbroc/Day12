// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


//  - Owners set at deploy (unique, nonzero)
//  - submitTransaction -> confirmTransaction -> executeTransaction
//  - Owners can revoke their confirmation before execution
contract Wallet {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event Submit(uint256 indexed txId, address indexed proposer, address indexed to, uint256 value, bytes data);
    event Confirm(uint256 indexed txId, address indexed owner, uint256 numConfirmations);
    event Revoke(uint256 indexed txId, address indexed owner, uint256 numConfirmations);
    event Execute(uint256 indexed txId, address indexed executor, bool success, bytes returnData);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public immutable THRESHOLD;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed; // txId => owner => confirmed?

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint256 txId) {
        require(txId < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint256 txId) {
        require(!isConfirmed[txId][msg.sender], "already confirmed");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "owners required");
        require(_threshold > 0 && _threshold <= _owners.length, "bad threshold");

        for (uint256 i = 0; i < _owners.length; ) {
            address owner = _owners[i];
            require(owner != address(0), "owner is zero");
            require(!isOwner[owner], "owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
            unchecked { ++i; }
        }
        THRESHOLD = _threshold;
    }

    /*//////////////////////////////////////////////////////////////
                               RECEIVE
    //////////////////////////////////////////////////////////////*/
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
    fallback() external payable {
        if (msg.value > 0) emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /*//////////////////////////////////////////////////////////////
                           MULTISIG ACTIONS
    //////////////////////////////////////////////////////////////*/
    function submitTransaction(address to, uint256 value, bytes calldata data)
        external
        onlyOwner
        returns (uint256 txId)
    {
        txId = transactions.length;
        transactions.push(Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            numConfirmations: 0
        }));
        emit Submit(txId, msg.sender, to, value, data);
        // (Optional) auto-confirm by proposer:
        _confirm(txId, msg.sender);
    }

    function confirmTransaction(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
        notConfirmed(txId)
    {
        _confirm(txId, msg.sender);
    }

    function revokeConfirmation(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
    {
        require(isConfirmed[txId][msg.sender], "not confirmed");
        isConfirmed[txId][msg.sender] = false;
        uint256 newCount = transactions[txId].numConfirmations - 1;
        transactions[txId].numConfirmations = newCount;
        emit Revoke(txId, msg.sender, newCount);
    }

    function executeTransaction(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
    {
        Transaction storage txn = transactions[txId];
        require(txn.numConfirmations >= THRESHOLD, "insufficient confirmations");

        txn.executed = true; // effects before interaction

        (bool ok, bytes memory ret) = txn.to.call{value: txn.value}(txn.data);
        emit Execute(txId, msg.sender, ok, ret);

        require(ok, _revertReason(ret));
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW HELPERS
    //////////////////////////////////////////////////////////////*/
    function getOwners() external view returns (address[] memory) { return owners; }
    function getTransactionCount() external view returns (uint256) { return transactions.length; }
    function getTransaction(uint256 txId)
        external view returns (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations)
    {
        Transaction storage t = transactions[txId];
        return (t.to, t.value, t.data, t.executed, t.numConfirmations);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL UTILITIES
    //////////////////////////////////////////////////////////////*/
    function _confirm(uint256 txId, address owner) internal {
        isConfirmed[txId][owner] = true;
        uint256 newCount = transactions[txId].numConfirmations + 1;
        transactions[txId].numConfirmations = newCount;
        emit Confirm(txId, owner, newCount);
    }

    function _revertReason(bytes memory ret) private pure returns (string memory) {
        // Bubble up revert reason if present
        if (ret.length >= 68) {
            assembly {
                ret := add(ret, 0x04)
            }
            return abi.decode(ret, (string));
        }
        return "multisig: call failed";
    }
}
