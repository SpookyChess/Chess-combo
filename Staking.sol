// StakingContract chessToken
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./IERC1155.sol";

contract StakingContract {
    // Define state variables
    IERC20 public chessToken; // ERC20 token contract
    IERC1155 public erc1155Contract; // ERC1155 token contract
    address public erc20ContractAddress; // Address of the ERC20 token contract
    bool public isInitialized; // Flag to track initialization status
    mapping(address => mapping(uint256 => uint256)) public stakedBalances; // Tracks staked token balances for each user and token ID
    mapping(address => uint256) public totalStaked; // Tracks total staked balance for each user
    mapping(address => uint256) public lastClaimedTime; // Tracks the timestamp of the last reward claim for each user
    uint256 public totalUnclaimedRewards; // Tracks the total unclaimed rewards
    uint256 public constant MAX_SUPPLY = 16_000_000 * (10 ** 18); // 16 million tokens
    uint256 public totalSupply; // Current total supply of tokens
    uint256 public constant SECONDS_IN_DAY = 86400; // Number of seconds in a day
    uint256[] public rewardRates = [1, 2, 3, 4, 5]; // Daily reward rates per token

    // Define events
    event Staked(address indexed user, uint256 tokenId, uint256 amount);
    event Unstaked(address indexed user, uint256 tokenId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    // Constructor to initialize the contract
    constructor(address _erc20ContractAddress) {
        require(_erc20ContractAddress != address(0), "Invalid ERC20 contract address");
        require(!isInitialized, "Contract is already initialized");
        erc20ContractAddress = _erc20ContractAddress;
        chessToken = IERC20(_erc20ContractAddress);
        chessToken.setStakingContract(address(this));
        isInitialized = true;
    }

    // Modifier to restrict function access to only the ERC20 contract
    modifier onlyStakingContract() {
        require(msg.sender == address(chessToken), "Only the StakingContract can call this function");
        _;
    }

    // Function to set the ERC20 contract address (can only be called once)
    function setERC20Contract(address _erc20ContractAddress) external {
        require(erc20ContractAddress == address(0), "ERC20 contract address has already been set");
        erc20ContractAddress = _erc20ContractAddress;
        chessToken = IERC20(_erc20ContractAddress);
        chessToken.setStakingContract(address(this));
    }

    // Function for users to stake tokens
    function stake(uint256[] memory _tokenIds, uint256[] memory _amounts) external {
        require(_tokenIds.length == _amounts.length, "Arrays length mismatch");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            uint256 amount = _amounts[i];
            require(amount > 0, "Amount must be greater than 0");

            // Transfer tokens from user to contract
            erc1155Contract.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");

            // Update staked balances and total staked
            stakedBalances[msg.sender][tokenId] += amount;
            totalStaked[msg.sender] += amount;

            // Emit event
            emit Staked(msg.sender, tokenId, amount);
        }

        // Update total unclaimed rewards
        updateTotalUnclaimedRewards();
    }

    // Function for users to unstake tokens
    function unstake(uint256[] memory _tokenIds, uint256[] memory _amounts) external {
        require(_tokenIds.length == _amounts.length, "Arrays length mismatch");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            uint256 amount = _amounts[i];
            require(amount > 0, "Amount must be greater than 0");
            require(stakedBalances[msg.sender][tokenId] >= amount, "Insufficient staked balance");

            // Transfer tokens from contract to user
            erc1155Contract.safeTransferFrom(address(this), msg.sender, tokenId, amount, "");

            // Update staked balances and total staked
            stakedBalances[msg.sender][tokenId] -= amount;
            totalStaked[msg.sender] -= amount;

            // Emit event
            emit Unstaked(msg.sender, tokenId, amount);
        }

        // Update total unclaimed rewards
        updateTotalUnclaimedRewards();

        // Calculate and mint rewards if applicable
        uint256 reward = calculateReward(msg.sender);
        if (reward > 0) {
            chessToken.mint(msg.sender, reward);
            emit RewardClaimed(msg.sender, reward);
            totalUnclaimedRewards -= reward;
            totalSupply += reward; // Update total supply
        }
    }

    // Function for users to claim rewards
    function claimRewards() external {
        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "No rewards to claim");

        // Update last claimed time
        lastClaimedTime[msg.sender] = block.timestamp;

        // Transfer rewards to user
        chessToken.transfer(msg.sender, reward);

        // Emit event
        emit RewardClaimed(msg.sender, reward);

        // Update total unclaimed rewards and total supply
        totalUnclaimedRewards -= reward;
        totalSupply += reward;
    }

    // Function to calculate rewards for a user
    function calculateReward(address _user) internal view returns (uint256) {
        uint256 reward = 0;
        for (uint256 tokenId = 8; tokenId <= 37; tokenId += 7) {
            uint256 stakedAmount = stakedBalances[_user][tokenId];
            reward += stakedAmount * rewardRates[(tokenId - 8) / 7];
        }
        uint256 elapsedTime = block.timestamp - lastClaimedTime[_user];
        uint256 rewardPerDay = reward * elapsedTime / SECONDS_IN_DAY;
        return rewardPerDay;
    }

    // Function to update total unclaimed rewards
    function updateTotalUnclaimedRewards() internal {
        // Logic to update totalUnclaimedRewards based on current total supply and max supply
        // Ensure totalUnclaimedRewards does not exceed the difference between max supply and current total supply of tokens
        uint256 maxUnclaimedRewards = MAX_SUPPLY - totalSupply;
        totalUnclaimedRewards = totalUnclaimedRewards > maxUnclaimedRewards ? maxUnclaimedRewards : totalUnclaimedRewards;
    }

    // Function to get unclaimed rewards for a user
    function getUnclaimedRewards(address _user) external view returns (uint256) {
        return calculateReward(_user);
    }

    // Function to get total unclaimed rewards
    function getTotalUnclaimedRewards() external view returns (uint256) {
        return totalUnclaimedRewards;
    }
}
