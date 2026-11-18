// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC20
 * @notice Standard ERC-20 interface for QDay Aevum Testnet tUSD8 (6 decimals)
 *         Official tUSD8 Contract: 0x456569838f1d43009A91ebA4263147Afd7233483
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

/**
 * @title AevumAgentPay
 * @author Tung Nguyen (@tungdeptrai07)
 * @notice End-to-End Stablecoin Payment Hub for Humans & Autonomous AI Agents on QDay Aevum Testnet (Chain ID: 44005).
 *         Supports:
 *         1. Smart Invoices with Confirmation of Payee (CoP) cryptographic verification
 *         2. Per-Second Streaming Payroll & Token Vesting in tUSD8
 *         3. ERC-8004 Autonomous AI Agent Payment Mandates with Daily Spending Guardrails
 */
contract AevumAgentPay {
    IERC20 public immutable tUSD8;
    address public owner;

    // Official QDay Aevum Testnet tUSD8 address: 0x456569838f1d43009A91ebA4263147Afd7233483
    uint256 public constant TUSD8_DECIMALS = 6;

    enum InvoiceStatus { Pending, Paid, Cancelled, Refunded }

    struct Invoice {
        uint256 id;
        address issuer;
        address payer;
        uint256 amount;          // in tUSD8 (6 decimals)
        bytes32 payeeNameHash;   // Confirmation of Payee (CoP) keccak256 hash
        string metadataUri;      // Invoice description / IPFS ref
        uint256 dueDate;
        uint256 paidAt;
        InvoiceStatus status;
    }

    struct PayrollStream {
        uint256 id;
        address employer;
        address employee;
        uint256 totalAmount;     // Total tUSD8 locked
        uint256 claimedAmount;   // tUSD8 already withdrawn
        uint256 startTime;
        uint256 stopTime;
        bool active;
    }

    struct AgentMandate {
        address principal;       // Human/treasury owner
        address agentSigner;     // AI Agent execution wallet
        uint256 maxPerTx;        // Max tUSD8 per single transaction
        uint256 dailyLimit;      // Max tUSD8 per 24h window
        uint256 spentToday;
        uint256 lastResetDay;
        bool active;
    }

    uint256 public nextInvoiceId = 1001;
    uint256 public nextStreamId = 501;

    mapping(uint256 => Invoice) public invoices;
    mapping(uint256 => PayrollStream) public streams;
    mapping(address => mapping(address => AgentMandate)) public mandates; // principal => agent => Mandate
    mapping(address => bytes32) public registeredPayeeHash;              // Confirmation of Payee registry

    event PayeeRegistered(address indexed account, bytes32 indexed payeeNameHash);
    event InvoiceCreated(uint256 indexed invoiceId, address indexed issuer, address indexed payer, uint256 amount, bytes32 payeeNameHash);
    event InvoicePaid(uint256 indexed invoiceId, address indexed payer, address indexed issuer, uint256 amount, bool viaAgent);
    event StreamCreated(uint256 indexed streamId, address indexed employer, address indexed employee, uint256 totalAmount, uint256 duration);
    event StreamClaimed(uint256 indexed streamId, address indexed employee, uint256 amountClaimed);
    event MandateConfigured(address indexed principal, address indexed agent, uint256 maxPerTx, uint256 dailyLimit, bool active);
    event AgentPaymentExecuted(address indexed principal, address indexed agent, address indexed recipient, uint256 amount, uint256 invoiceId);

    constructor(address _tUSD8Address) {
        require(_tUSD8Address != address(0), "Invalid tUSD8 address");
        tUSD8 = IERC20(_tUSD8Address);
        owner = msg.sender;
    }

    // =========================================================================
    // 1. CONFIRMATION OF PAYEE (CoP) & SMART INVOICES
    // =========================================================================

    /**
     * @notice Registers a verified payee identity hash for Confirmation of Payee (CoP) checks.
     */
    function registerPayeeIdentity(string calldata legalOrBusinessName) external {
        bytes32 nameHash = keccak256(abi.encodePacked(legalOrBusinessName));
        registeredPayeeHash[msg.sender] = nameHash;
        emit PayeeRegistered(msg.sender, nameHash);
    }

    /**
     * @notice Creates a tUSD8 invoice on Aevum Testnet with Confirmation of Payee protection.
     */
    function createInvoice(
        address _payer,
        uint256 _amount,
        string calldata _issuerPayeeName,
        string calldata _metadataUri,
        uint256 _dueDate
    ) external returns (uint256 invoiceId) {
        require(_amount > 0, "Amount must be > 0");
        require(_dueDate > block.timestamp, "Invalid due date");

        bytes32 nameHash = keccak256(abi.encodePacked(_issuerPayeeName));
        if (registeredPayeeHash[msg.sender] == bytes32(0)) {
            registeredPayeeHash[msg.sender] = nameHash;
        }

        invoiceId = nextInvoiceId++;
        invoices[invoiceId] = Invoice({
            id: invoiceId,
            issuer: msg.sender,
            payer: _payer,
            amount: _amount,
            payeeNameHash: nameHash,
            metadataUri: _metadataUri,
            dueDate: _dueDate,
            paidAt: 0,
            status: InvoiceStatus.Pending
        });

        emit InvoiceCreated(invoiceId, msg.sender, _payer, _amount, nameHash);
    }

    /**
     * @notice Pays a pending invoice only if the Confirmation of Payee (CoP) name matches.
     */
    function payInvoiceWithCoP(uint256 _invoiceId, string calldata _expectedPayeeName) external {
        Invoice storage inv = invoices[_invoiceId];
        require(inv.status == InvoiceStatus.Pending, "Invoice not pending");
        require(inv.payer == address(0) || inv.payer == msg.sender, "Not authorized payer");

        bytes32 providedHash = keccak256(abi.encodePacked(_expectedPayeeName));
        require(providedHash == inv.payeeNameHash, "CoP Error: Payee name mismatch");

        inv.status = InvoiceStatus.Paid;
        inv.paidAt = block.timestamp;
        inv.payer = msg.sender;

        require(tUSD8.transferFrom(msg.sender, inv.issuer, inv.amount), "tUSD8 transfer failed");
        emit InvoicePaid(_invoiceId, msg.sender, inv.issuer, inv.amount, false);
    }

    // =========================================================================
    // 2. REAL-TIME STREAMING PAYROLL & VESTING
    // =========================================================================

    /**
     * @notice Locks tUSD8 into a continuous per-second salary/vesting stream.
     */
    function createPayrollStream(
        address _employee,
        uint256 _totalAmount,
        uint256 _durationSeconds
    ) external returns (uint256 streamId) {
        require(_employee != address(0) && _employee != msg.sender, "Invalid employee");
        require(_totalAmount > 0 && _durationSeconds > 0, "Invalid stream params");

        require(tUSD8.transferFrom(msg.sender, address(this), _totalAmount), "tUSD8 funding failed");

        streamId = nextStreamId++;
        streams[streamId] = PayrollStream({
            id: streamId,
            employer: msg.sender,
            employee: _employee,
            totalAmount: _totalAmount,
            claimedAmount: 0,
            startTime: block.timestamp,
            stopTime: block.timestamp + _durationSeconds,
            active: true
        });

        emit StreamCreated(streamId, msg.sender, _employee, _totalAmount, _durationSeconds);
    }

    /**
     * @notice Calculates vested tUSD8 available to claim right now.
     */
    function claimableStreamBalance(uint256 _streamId) public view returns (uint256) {
        PayrollStream memory s = streams[_streamId];
        if (!s.active || block.timestamp <= s.startTime) return 0;

        uint256 elapsed = block.timestamp >= s.stopTime
            ? (s.stopTime - s.startTime)
            : (block.timestamp - s.startTime);
        uint256 duration = s.stopTime - s.startTime;
        uint256 totalVested = (s.totalAmount * elapsed) / duration;

        if (totalVested <= s.claimedAmount) return 0;
        return totalVested - s.claimedAmount;
    }

    /**
     * @notice Withdraws accrued tUSD8 from an active stream to the employee wallet.
     */
    function claimPayrollStream(uint256 _streamId) external {
        PayrollStream storage s = streams[_streamId];
        require(s.active, "Stream inactive");
        require(msg.sender == s.employee, "Only employee can claim");

        uint256 claimable = claimableStreamBalance(_streamId);
        require(claimable > 0, "Nothing to claim yet");

        s.claimedAmount += claimable;
        if (s.claimedAmount >= s.totalAmount) {
            s.active = false;
        }

        require(tUSD8.transfer(s.employee, claimable), "Stream payout failed");
        emit StreamClaimed(_streamId, s.employee, claimable);
    }

    // =========================================================================
    // 3. ERC-8004 AUTONOMOUS AI AGENT PAYMENT MANDATES
    // =========================================================================

    /**
     * @notice Authorizes an AI Agent to autonomously settle invoices within strict risk guardrails.
     */
    function configureAgentMandate(
        address _agentSigner,
        uint256 _maxPerTx,
        uint256 _dailyLimit,
        bool _active
    ) external {
        require(_agentSigner != address(0), "Invalid agent address");
        require(_maxPerTx <= _dailyLimit, "maxPerTx cannot exceed dailyLimit");

        mandates[msg.sender][_agentSigner] = AgentMandate({
            principal: msg.sender,
            agentSigner: _agentSigner,
            maxPerTx: _maxPerTx,
            dailyLimit: _dailyLimit,
            spentToday: 0,
            lastResetDay: block.timestamp / 1 days,
            active: _active
        });

        emit MandateConfigured(msg.sender, _agentSigner, _maxPerTx, _dailyLimit, _active);
    }

    /**
     * @notice Executed by an authorized AI Agent to pay a verified tUSD8 invoice on behalf of the principal.
     */
    function executeAgentInvoicePayment(
        address _principal,
        uint256 _invoiceId,
        string calldata _expectedPayeeName
    ) external {
        AgentMandate storage m = mandates[_principal][msg.sender];
        require(m.active, "Agent mandate inactive");

        Invoice storage inv = invoices[_invoiceId];
        require(inv.status == InvoiceStatus.Pending, "Invoice not pending");

        // Verify Confirmation of Payee (CoP)
        bytes32 providedHash = keccak256(abi.encodePacked(_expectedPayeeName));
        require(providedHash == inv.payeeNameHash, "Agent CoP check failed");

        // Enforce programmatic guardrails
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay > m.lastResetDay) {
            m.spentToday = 0;
            m.lastResetDay = currentDay;
        }
        require(inv.amount <= m.maxPerTx, "Exceeds agent maxPerTx guardrail");
        require(m.spentToday + inv.amount <= m.dailyLimit, "Exceeds agent dailyLimit guardrail");

        m.spentToday += inv.amount;
        inv.status = InvoiceStatus.Paid;
        inv.paidAt = block.timestamp;
        inv.payer = _principal;

        require(tUSD8.transferFrom(_principal, inv.issuer, inv.amount), "Agent tUSD8 transferFrom failed");

        emit InvoicePaid(_invoiceId, _principal, inv.issuer, inv.amount, true);
        emit AgentPaymentExecuted(_principal, msg.sender, inv.issuer, inv.amount, _invoiceId);
    }
}
