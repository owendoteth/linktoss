pragma solidity 0.6.6;
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

interface Router {
  function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
  external
  payable
  returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IPegSwap {
    function swap(uint256 amount, address source, address target) external;
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
}

/*author => owen.eth*/
contract Coinflip is VRFConsumerBase{

    event GameCreated(address player, uint256 amount);
    event GameJoined(uint256 index, address player);
    event GameResult(uint256 index, address winner, uint256 amount);

    /*Chainlink setup*/
    bytes32 internal keyHash;
    uint256 internal fee;

    /*Game information and variables*/
    struct Game {
        uint256 index;
        address player1;
        address player2;
        uint256 amount;
        address winner;
        uint256 blockstamp;
    }

    /*Info indexing and Chainlink randomness indexing*/
    uint256 index;
    mapping(uint256 => Game) gameIndex;
    mapping(bytes32 => Game) requestIndex;

    /*Routers used*/
    Router QuickSwap = Router(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    IPegSwap PegSwap = IPegSwap(0xAA1DC356dc4B18f30C347798FD5379F3D77ABC5b);
    receive() external payable {
        if (msg.sender != address(QuickSwap) && msg.sender != address(PegSwap)) {
            /* Donations welcomed :) */
            payable(owner).transfer(msg.value);
        }
    }

    address owner;
    constructor() VRFConsumerBase(
            0x3d2341ADb2D31f1c5530cDC622016af293177AE0, // VRF Coordinator
            0xb0897686c545045aFc77CF20eC7A532E3120E0F1  // LINK Token
        ) public {
        keyHash = 0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da;
        fee = 0.0001 * 10 ** 18; // 0.0001 LINK
        index = 0;
        owner = msg.sender;
    }

    /* Callback for VRF Oracle, decides winner and distributes winnings*/
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        Game memory game = requestIndex[requestId];
        if (randomness % 2 == 0) {
            game.winner = game.player1;
        }
        else {
            game.winner = game.player2;
        }
        gameIndex[game.index] = game;
        payable(game.winner).transfer(game.amount);
        emit GameResult(game.index, game.winner, game.amount);
    }

    /*Create a new game*/
    function create_game() public payable {
        Game memory newGame = Game(index, msg.sender, address(this), msg.value, address(this), block.timestamp);
        gameIndex[index] = newGame;
        index += 1;
        emit GameCreated(msg.sender, msg.value);
    }

    /*Join a game given a valid index*/
    function join_game(uint256 _index) external payable {
        Game memory game = gameIndex[_index];
        address[] memory path = get_path();

        require(msg.value == game.amount, "Invalid bet!");
        require(game.player2 == address(this), "Game already joined");
        require(game.winner == address(this), "Game already played");

        /*Convert bets. MATIC => WETH => LINK (ERC-20) => LINK (ERC-621) */
        uint256 amountIn = QuickSwap.getAmountsIn(fee, path)[0];
        QuickSwap.swapETHForExactTokens{value: amountIn}(fee, path, address(this), block.timestamp + 15);
        IERC20(0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39).approve(address(PegSwap), fee);
        PegSwap.swap(fee, 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39, address(LINK));

        /*update game values*/
        game.player2 = msg.sender;
        game.amount += msg.value - amountIn;
        gameIndex[_index] = game;

        /*submit randomness request*/
        bytes32 requestId = requestRandomness(keyHash, fee, block.timestamp);
        requestIndex[requestId] = game;

        emit GameJoined(_index, msg.sender);
    }

    /*Routing path for computing price of 0.0001 LINK at time of bet*/
    function get_path() internal returns (address[] memory _path) {
        address[] memory path = new address[](3);
        path[0] = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; //WMatic
        path[1] = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619; //WETH
        path[2] = 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39; //LINK
        return path;
    }

    /*returns total amount of games*/
    function get_game_count() external view returns(uint256) {
        return index;
    }

    /*return info about a game given valid index*/
    function get_game_info(uint256 _index) external view returns(uint256 _i, address _player1, address _player2, uint256 _amount, address _winner, uint256 _timestamp) {
        Game memory game = gameIndex[_index];
        return (_index, game.player1, game.player2, game.amount, game.winner, game.blockstamp);
    }


}
