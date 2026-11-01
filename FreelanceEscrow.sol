// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * Freelance Escrow & Smart Payment Platform
 * Educational reference implementation.
 *
 * Features:
 * - Create an agreement
 * - Deposit exact ETH amount
 * - Submit work evidence (URL or content hash)
 * - Approve work and release payment
 * - Open and resolve disputes
 * - Claim refund after deadline if no work was submitted
 * - Read job data and emit transaction history events
 *
 * IMPORTANT:
 * - This is a learning project, not audited production code.
 * - Deploy to a test network first and run the test checklist.
 */
contract FreelanceEscrow {
    enum Status {
        Created,    // Agreement created; payment not deposited
        Funded,     // ETH locked in escrow
        Submitted,  // Freelancer submitted evidence
        Completed,  // Freelancer paid
        Disputed,   // Dispute opened; funds remain locked
        Refunded    // Client refunded
    }

    enum DisputeResolution {
        None,
        RefundClient,
        PayFreelancer
    }

    struct Job {
        uint256 id;
        address payable client;
        address payable freelancer;
        string projectName;
        string description;
        string workEvidence;
        string disputeReason;
        uint256 paymentAmount;
        uint256 deadline;
        uint256 createdAt;
        Status status;
        DisputeResolution resolution;
    }

    address public immutable admin;
    uint256 public nextJobId = 1;

    mapping(uint256 => Job) private jobs;

    // Tracks the ETH principal actually held for each job.
    mapping(uint256 => uint256) private escrowedAmount;

    // Prevents reentrant calls while sending ETH.
    uint256 private locked = 1;

    modifier nonReentrant() {
        require(locked == 1, "Reentrant call");
        locked = 2;
        _;
        locked = 1;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier jobExists(uint256 jobId) {
        require(jobId > 0 && jobId < nextJobId, "Job does not exist");
        _;
    }

    event JobCreated(
        uint256 indexed jobId,
        address indexed client,
        address indexed freelancer,
        string projectName,
        uint256 paymentAmount,
        uint256 deadline
    );

    event PaymentDeposited(
        uint256 indexed jobId,
        address indexed client,
        uint256 amount
    );

    event WorkSubmitted(
        uint256 indexed jobId,
        address indexed freelancer,
        string evidence
    );

    event PaymentReleased(
        uint256 indexed jobId,
        address indexed freelancer,
        uint256 amount
    );

    event DisputeOpened(
        uint256 indexed jobId,
        address indexed raisedBy,
        string reason
    );

    event DisputeResolved(
        uint256 indexed jobId,
        DisputeResolution resolution,
        address indexed resolver
    );

    event ClientRefunded(
        uint256 indexed jobId,
        address indexed client,
        uint256 amount
    );

    event ExpiredJobRefunded(
        uint256 indexed jobId,
        address indexed client,
        uint256 amount
    );

    constructor() {
        admin = msg.sender;
    }

    /// @notice Client creates a job agreement. paymentAmount is denominated in wei.
    function createJob(
        address payable freelancer,
        string calldata projectName,
        string calldata description,
        uint256 paymentAmount,
        uint256 deadline
    ) external returns (uint256 jobId) {
        require(freelancer != address(0), "Invalid freelancer address");
        require(freelancer != msg.sender, "Cannot hire yourself");
        require(bytes(projectName).length > 0, "Project name required");
        require(paymentAmount > 0, "Payment must be greater than zero");
        require(deadline > block.timestamp, "Deadline must be in the future");

        jobId = nextJobId++;

        jobs[jobId] = Job({
            id: jobId,
            client: payable(msg.sender),
            freelancer: freelancer,
            projectName: projectName,
            description: description,
            workEvidence: "",
            disputeReason: "",
            paymentAmount: paymentAmount,
            deadline: deadline,
            createdAt: block.timestamp,
            status: Status.Created,
            resolution: DisputeResolution.None
        });

        emit JobCreated(
            jobId,
            msg.sender,
            freelancer,
            projectName,
            paymentAmount,
            deadline
        );
    }

    /// @notice Client deposits exactly the agreed ETH amount.
    function depositPayment(uint256 jobId)
        external
        payable
        jobExists(jobId)
    {
        Job storage job = jobs[jobId];

        require(msg.sender == job.client, "Only client can deposit");
        require(job.status == Status.Created, "Job is not awaiting deposit");
        require(msg.value == job.paymentAmount, "Incorrect ETH amount");

        escrowedAmount[jobId] = msg.value;
        job.status = Status.Funded;

        emit PaymentDeposited(jobId, msg.sender, msg.value);
    }

    /// @notice Freelancer submits a URL or a content hash before the deadline.
    function submitWork(uint256 jobId, string calldata evidence)
        external
        jobExists(jobId)
    {
        Job storage job = jobs[jobId];

        require(msg.sender == job.freelancer, "Only freelancer can submit");
        require(job.status == Status.Funded, "Job is not funded");
        require(block.timestamp <= job.deadline, "Submission deadline passed");
        require(bytes(evidence).length > 0, "Evidence required");

        job.workEvidence = evidence;
        job.status = Status.Submitted;

        emit WorkSubmitted(jobId, msg.sender, evidence);
    }

    /// @notice Client approves the submitted work and releases escrowed ETH.
    function approveWork(uint256 jobId)
        external
        nonReentrant
        jobExists(jobId)
    {
        Job storage job = jobs[jobId];

        require(msg.sender == job.client, "Only client can approve");
        require(job.status == Status.Submitted, "Work has not been submitted");

        uint256 amount = escrowedAmount[jobId];
        require(amount == job.paymentAmount && amount > 0, "No escrowed funds");

        // Checks-effects-interactions: mark terminal state and clear escrow first.
        escrowedAmount[jobId] = 0;
        job.status = Status.Completed;

        (bool success, ) = job.freelancer.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit PaymentReleased(jobId, job.freelancer, amount);
    }

    /// @notice Client or freelancer can open a dispute while funds are locked.
    function openDispute(uint256 jobId, string calldata reason)
        external
        jobExists(jobId)
    {
        Job storage job = jobs[jobId];

        require(
            msg.sender == job.client || msg.sender == job.freelancer,
            "Not a party to this job"
        );
        require(
            job.status == Status.Funded || job.status == Status.Submitted,
            "Cannot dispute this job"
        );
        require(bytes(reason).length > 0, "Dispute reason required");
        require(escrowedAmount[jobId] > 0, "No escrowed funds");

        job.disputeReason = reason;
        job.status = Status.Disputed;

        emit DisputeOpened(jobId, msg.sender, reason);
    }

    /// @notice Admin decides whether the locked payment is refunded or released.
    function resolveDispute(uint256 jobId, DisputeResolution resolution)
        external
        onlyAdmin
        nonReentrant
        jobExists(jobId)
    {
        Job storage job = jobs[jobId];

        require(job.status == Status.Disputed, "Job is not disputed");
        require(
            resolution == DisputeResolution.RefundClient ||
            resolution == DisputeResolution.PayFreelancer,
            "Invalid resolution"
        );

        uint256 amount = escrowedAmount[jobId];
        require(amount == job.paymentAmount && amount > 0, "No escrowed funds");

        // Effects before external interaction.
        escrowedAmount[jobId] = 0;
        job.resolution = resolution;

        if (resolution == DisputeResolution.RefundClient) {
            job.status = Status.Refunded;

            (bool success, ) = job.client.call{value: amount}("");
            require(success, "Refund transfer failed");

            emit ClientRefunded(jobId, job.client, amount);
        } else {
            job.status = Status.Completed;

            (bool success, ) = job.freelancer.call{value: amount}("");
            require(success, "Freelancer payment failed");

            emit PaymentReleased(jobId, job.freelancer, amount);
        }

        emit DisputeResolved(jobId, resolution, msg.sender);
    }

    /// @notice Client may reclaim funds only if deadline passed and freelancer did not submit.
    /// @dev This is an added, explicit expiry rule; it is not stated verbatim in the assignment.
    function refundExpiredJob(uint256 jobId)
        external
        nonReentrant
        jobExists(jobId)
    {
        Job storage job = jobs[jobId];

        require(msg.sender == job.client, "Only client can request refund");
        require(job.status == Status.Funded, "Job must be funded with no submission");
        require(block.timestamp > job.deadline, "Deadline has not passed");
        require(bytes(job.workEvidence).length == 0, "Work was submitted");

        uint256 amount = escrowedAmount[jobId];
        require(amount == job.paymentAmount && amount > 0, "No escrowed funds");

        escrowedAmount[jobId] = 0;
        job.status = Status.Refunded;

        (bool success, ) = job.client.call{value: amount}("");
        require(success, "Refund transfer failed");

        emit ExpiredJobRefunded(jobId, job.client, amount);
    }

    /// @notice Returns all stored details for a job.
    function getJob(uint256 jobId)
        external
        view
        jobExists(jobId)
        returns (Job memory)
    {
        return jobs[jobId];
    }

    /// @notice Returns the amount of the original deposit still locked for this job.
    function getEscrowBalance(uint256 jobId)
        external
        view
        jobExists(jobId)
        returns (uint256)
    {
        return escrowedAmount[jobId];
    }

    /// @notice Convenience view for frontends to show the current job status.
    function getJobStatus(uint256 jobId)
        external
        view
        jobExists(jobId)
        returns (Status)
    {
        return jobs[jobId].status;
    }

    /// @notice Total ETH currently held by this contract.
    /// @dev May include unsolicited ETH; per-job accounting is available via getEscrowBalance.
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
