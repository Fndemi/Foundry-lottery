// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @author Florence Ndemi
 * @notice This contract is for creating a simple raffle
 * @dev Implements Chainlink VRFv2.5
 *
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * Errors
     */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 playersLegth, uint256 raffleState);
    /*Type declarations*/

    enum RaffleState {
        OPEN, //0
        CALCULATING //1

    }

    /* State variable */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState; //start as open

    /**
     * Events
     */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    // what data structure should we use?How to keep track of the player?

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;

        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee,"Not enough ETH sent!");
        //  require(msg.value >= i_entranceFee,SendMoreToEnterRaffle());

        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }
    //when should the winner be picked?
    /**
     * @dev This is the function that the Chainlink nodes will call to see if the lottery is ready to have a winner picked
     * The following should be true inorder for upkeepNeeded to be true
     * 1.The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3.The contract has Eth
     * 4.implicitily your subscription has ETH
     * @param - ignored
     * @return upKeepNeeded -true if it is time to restart the lottery
     * @return - ignored
     */

    function checkUpKeep(bytes memory /*checkdata*/ )
        public
        view
        returns (bool upKeepNeeded, bytes memory /*performData*/ )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upKeepNeeded, "");
    }

    //1.Get a random number
    //2.Use random number to pick a player
    //3.Be automatically called

    function performUpkeep(bytes calldata /* performData */ ) external {
        //check to see if enough time has passed
        //1000-900>200
        (bool upKeepNeeded,) = checkUpKeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;
        //Get our Random number from Chainlink
        //1.Request RNG
        //2.Get RNG
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        //Is this Redundant?Yes

        emit RequestedRaffleWinner(requestId);
    }
    //CEI checks, Effects, Interactions Pattern

    function fulfillRandomWords(uint256, /*requestId,*/ uint256[] calldata randomWords) internal override {
        //Checks

        //Effect(Internal Contract State)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        //Interactions(External contract Interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
