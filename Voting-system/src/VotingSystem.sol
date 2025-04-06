// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VotingSystem {
    IERC20 public governanceToken;
    uint256 public proposalThreshold;
    uint256 public quorumThreshold;

    // Structure pour regrouper les informations de vote
    struct VoteInfo {
        uint256 voterStake;
        bool voteSupport;
        uint256 forVotes;
        uint256 againstVotes;
        string quorumStatus;
        bool passed;
    }

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 closingTime;
        bool executed;
        bool tokensReturned;
        bool quorumReached;      // Indique si le quorum est atteint
        bool acceptedWithoutQuorum; // Indique si accepté sans quorum
        string quorumStatus;     // Variable string pour le statut du quorum et du vote
        bool passed;             // Nouvelle variable pour indiquer si la proposition a passé
        address[] voters;
        mapping(address => uint256) voterStake;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteSupport;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description, uint256 closingTime);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event VoteChanged(uint256 indexed proposalId, address indexed voter, bool newSupport);
    event ProposalExecuted(uint256 indexed proposalId, string status);
    event TokensReturned(uint256 indexed proposalId);
    event Debug(string message, uint256 value, address user);
    event QuorumStatus(uint256 indexed proposalId, bool quorumReached, bool passed, string status);

    constructor(address _governanceToken, uint256 _proposalThreshold, uint256 _quorumThreshold) {
        governanceToken = IERC20(_governanceToken);
        proposalThreshold = _proposalThreshold;
        quorumThreshold = _quorumThreshold;
    }

    function createProposal(string memory description, uint256 votingPeriod) external returns (uint256) {
        require(governanceToken.balanceOf(msg.sender) >= proposalThreshold, "Insufficient tokens to create proposal");

        proposalCount++;
        Proposal storage proposal = proposals[proposalCount];
        proposal.id = proposalCount;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.closingTime = block.timestamp + votingPeriod;
        proposal.tokensReturned = false;
        proposal.quorumReached = false;
        proposal.acceptedWithoutQuorum = false;
        proposal.quorumStatus = "Pending"; // Statut initial
        proposal.passed = false;

        emit ProposalCreated(proposalCount, msg.sender, description, proposal.closingTime);

        return proposalCount;
    }

    function castVote(uint256 proposalId, bool support) external {
        require(proposalId > 0 && proposalId <= proposalCount, "Proposal does not exist");

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.closingTime, "Voting period has ended");

        if (proposal.hasVoted[msg.sender]) {
            // User is changing their vote
            changeVote(proposalId, support);
        } else {
            // First time voting
            uint256 userBalance = governanceToken.balanceOf(msg.sender);
            uint256 userAllowance = governanceToken.allowance(msg.sender, address(this));

            // Émettre des événements de débogage
            emit Debug("User balance", userBalance, msg.sender);
            emit Debug("Token allowance", userAllowance, msg.sender);

            require(userBalance > 0, "No voting power");

            // Utiliser le minimum entre le solde et l'allowance
            uint256 voteWeight = userBalance;
            if (userAllowance < userBalance) {
                voteWeight = userAllowance;
            }

            emit Debug("Vote weight to use", voteWeight, msg.sender);

            // Transfer tokens from voter to contract
            bool transferSuccess = governanceToken.transferFrom(msg.sender, address(this), voteWeight);
            require(transferSuccess, "Token transfer failed");

            // Record the voter's stake and mark as voted
            proposal.voterStake[msg.sender] = voteWeight;
            proposal.hasVoted[msg.sender] = true;
            proposal.voteSupport[msg.sender] = support;
            proposal.voters.push(msg.sender);

            if (support) {
                proposal.forVotes += voteWeight;
            } else {
                proposal.againstVotes += voteWeight;
            }

            emit VoteCast(proposalId, msg.sender, support, voteWeight);
        }
    }

    function changeVote(uint256 proposalId, bool newSupport) public {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp < proposal.closingTime, "Voting period has ended");
        require(proposal.hasVoted[msg.sender], "Haven't voted yet");

        bool oldSupport = proposal.voteSupport[msg.sender];
        if (oldSupport == newSupport) {
            return; // No change needed
        }

        uint256 voteWeight = proposal.voterStake[msg.sender];

        // Update vote counts
        if (oldSupport) {
            // Was "for", now "against"
            proposal.forVotes -= voteWeight;
            proposal.againstVotes += voteWeight;
        } else {
            // Was "against", now "for"
            proposal.againstVotes -= voteWeight;
            proposal.forVotes += voteWeight;
        }

        // Update vote preference
        proposal.voteSupport[msg.sender] = newSupport;

        emit VoteChanged(proposalId, msg.sender, newSupport);
    }

    // Fonction pour vérifier et mettre à jour le statut du quorum et du vote
    function checkProposalStatus(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.closingTime, "Voting period not ended");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 totalSupply = governanceToken.totalSupply();

        // Vérifier si le quorum est atteint
        bool hasQuorum = totalVotes * 10000 / totalSupply >= quorumThreshold;
        proposal.quorumReached = hasQuorum;

        // Vérifier si la proposition a plus de votes pour que contre
        bool hasPassed = proposal.forVotes > proposal.againstVotes;


        // Mettre à jour le statut complet en fonction du quorum et des votes
        if (hasQuorum) {
            if (hasPassed) {
                proposal.quorumStatus = "Approved with quorum";
                proposal.acceptedWithoutQuorum = false;
                proposal.passed = hasPassed;
            } else {
                proposal.quorumStatus = "Rejected: More against votes than for votes";
                proposal.acceptedWithoutQuorum = false;
            }
        } else {
            // Quorum non atteint
            if (hasPassed) {
                proposal.quorumStatus = "Approved without quorum";
                proposal.acceptedWithoutQuorum = true;
            } else {
                proposal.quorumStatus = "Rejected: More against votes than for votes and no quorum";
                proposal.acceptedWithoutQuorum = false;
            }
        }

        emit QuorumStatus(proposalId, proposal.quorumReached, proposal.passed, proposal.quorumStatus);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.closingTime, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");

        // Vérifier et mettre à jour le statut si ce n'est pas déjà fait
        if (keccak256(bytes(proposal.quorumStatus)) == keccak256(bytes("Pending"))) {
            checkProposalStatus(proposalId);
        }

        // Nous n'utilisons plus de require pour bloquer l'exécution
        // La proposition peut être exécutée même si elle n'a pas passé ou si le quorum n'est pas atteint
        // Le statut est enregistré dans la variable quorumStatus

        proposal.executed = true;

        // Return tokens to all voters
        returnTokensToVoters(proposalId);

        emit ProposalExecuted(proposalId, proposal.quorumStatus);
    }

    function returnTokensToVoters(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.closingTime, "Voting period not ended");
        require(!proposal.tokensReturned, "Tokens already returned");

        proposal.tokensReturned = true;

        for (uint i = 0; i < proposal.voters.length; i++) {
            address voter = proposal.voters[i];
            uint256 stakedAmount = proposal.voterStake[voter];

            if (stakedAmount > 0) {
                // Transfer tokens back to the voter
                require(governanceToken.transfer(voter, stakedAmount), "Token transfer failed");
            }
        }

        emit TokensReturned(proposalId);
    }

    function triggerTokenReturn(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.closingTime, "Voting period not ended");
        require(!proposal.tokensReturned, "Tokens already returned");

        returnTokensToVoters(proposalId);
    }

    function getProposalDetails(uint256 proposalId) external view returns (
        address proposer,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 closingTime,
        bool executed,
        bool tokensReturned,
        bool quorumReached,
        bool acceptedWithoutQuorum,
        string memory quorumStatus,
        bool passed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.closingTime,
            proposal.executed,
            proposal.tokensReturned,
            proposal.quorumReached,
            proposal.acceptedWithoutQuorum,
            proposal.quorumStatus,
            proposal.passed
        );
    }

    function getProposalStatus(uint256 proposalId) external view returns (
        bool passed,
        bool quorumReached,
        string memory quorumStatus
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.passed,
            proposal.quorumReached,
            proposal.quorumStatus
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoterStake(uint256 proposalId, address voter) external view returns (uint256) {
        return proposals[proposalId].voterStake[voter];
    }

    function getVoteSupport(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].voteSupport[voter];
    }

    // Fonction pour obtenir le solde et l'allowance d'un utilisateur
    function getUserTokenInfo(address user) external view returns (uint256 balance, uint256 allowance) {
        return (
            governanceToken.balanceOf(user),
            governanceToken.allowance(user, address(this))
        );
    }

    // Fonction pour obtenir les informations de vote d'un utilisateur
    function getUserVoteInfo(uint256 proposalId, address voter) external view returns (
        bool hasVoted,
        uint256 voterStake,
        bool voteSupport
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.hasVoted[voter],
            proposal.voterStake[voter],
            proposal.voteSupport[voter]
        );
    }

    // Fonction pour obtenir les informations générales de la proposition
    function getProposalVoteInfo(uint256 proposalId) external view returns (
        uint256 forVotes,
        uint256 againstVotes,
        string memory quorumStatus,
        bool passed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.forVotes,
            proposal.againstVotes,
            proposal.quorumStatus,
            proposal.passed
        );
    }

    // Remplacer la fonction checkVotingStatus par plusieurs fonctions plus petites
    function checkVotingStatus(uint256 proposalId, address voter) external view returns (
        uint256 userBalance,
        uint256 userAllowance,
        bool userHasVoted
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            governanceToken.balanceOf(voter),
            governanceToken.allowance(voter, address(this)),
            proposal.hasVoted[voter]
        );
    }
}