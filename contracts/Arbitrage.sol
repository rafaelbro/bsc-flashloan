pragma solidity ^0.6.6;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IACryptoRouter.sol";

import "./library/TransferHelper.sol";
import "./library/UniswapV2Library.sol";
import "./library/Utils.sol";


contract Arbitrage {
    address public pancakeFactory;
    address private owner;
    address myAddress = address(this); // contract address
    mapping(uint256 => address) private routerMap; //mapping ints to routers
    mapping(address => int256) public ACryptosStableMap;
    mapping(address => int256) public EllipsisStableMap;

    uint256[] private setRouterPath; //var to declare router path
    address[] private setTokenPath; //var to declare token addresses path

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor(address _pancakeFactory, address[] memory routers) public {
        pancakeFactory = _pancakeFactory;
        owner == msg.sender;
        require(routers.length > 0, "No routers declared");
        for (uint256 i = 0; i < routers.length; i++) {
            routerMap[i] = routers[i];
        }
        startStableMaps();
    }

    function setPath(uint256[] memory routingPath, address[] memory tokenPath)
        internal
    {
        delete setRouterPath;
        delete setTokenPath;
        require(
            routingPath.length == tokenPath.length - 1,
            "Token path needs to be ( routing path + 1) "
        );

        for (uint256 i; i < routingPath.length; i++) {
            setRouterPath.push(routingPath[i]);
            setTokenPath.push(tokenPath[i]);
        }

        setTokenPath.push(tokenPath[routingPath.length]);
    }

    function startArbitrage(
        uint256 amountBorrowed, //amount of tokens of token[0]
        uint256[] calldata routerPath,
        address[] calldata tokenPath
    ) external {
        //require(tokenPath.length > 1, "Wrong token path size");
        address pairAddress =
            IUniswapV2Factory(pancakeFactory).getPair(
                tokenPath[0],
                tokenPath[SafeMath.sub(tokenPath.length, 1)]
            );
        require(pairAddress != address(0), "This pool does not exist");

        (uint256 token0, uint256 token1) =
            defineTokenOrderBasedOnPair(
                tokenPath[0],
                tokenPath[tokenPath.length - 1],
                amountBorrowed
            );

        setPath(routerPath, tokenPath);
        //Flashloan borrows asset with non 0 amount
        IUniswapV2Pair(pairAddress).swap(
            token0,
            token1,
            address(this),
            bytes("not empty")
        );
    }

    function pancakeCall(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        uint256 initialTokenAmount = _amount0 == 0 ? _amount1 : _amount0; //gets borrowed token

        require(
            (IERC20(endPathToken[0]).balanceOf(myAddress)) != 0,
            "borrowed wrong asset"
        );

        require(_amount0 == 0 || _amount1 == 0, "Zeroed amounts");


        /*
        address token0 = IUniswapV2Pair(msg.sender).token0(); //WBNB
        address token1 = IUniswapV2Pair(msg.sender).token1(); //DAI*/

        /*
        address calc = UniswapV2Library.pairFor(pancakeFactory, token0, token1); wrong calculations
        require(
            msg.sender == calc,
            append("Unauthorized par: ", msg.sender, calc)
        );*/

        address pairAdress = msg.sender;

        //IERC20 token = IERC20(_amount0 == 0 ? token1 : token0);

        uint256 lastTokenPathIndex = setTokenPath.length - 1;

        address[] memory endPathToken = new address[](2);
        endPathToken[0] = setTokenPath[0];
        endPathToken[1] = setTokenPath[lastTokenPathIndex];

        //calculates amount required to payback loan that will need to be generated
        uint256 endAmountRequired =
            UniswapV2Library.getAmountsIn(
                pancakeFactory,
                IERC20(setTokenPath[0]).balanceOf(myAddress),
                endPathToken, //path from 1st to last token
                pairAdress
            )[0];

        for (uint256 i; i < setTokenPath.length - 1; i++) {
            address[] memory intermediaryPathToken = new address[](2);
            intermediaryPathToken[0] = setTokenPath[i];
            intermediaryPathToken[1] = setTokenPath[i + 1];
            IERC20 token = IERC20(intermediaryPathToken[0]);
            
            uint256 balance = token.balanceOf(myAddress);  //gets current balance  
            token.approve(routerPath[i], balance);    //approves for spending   

            int128 swapCategory = classifySwap(routerPath[i]);

            if(swapCategory == 0){
                standardSwap(balance, routerPath[i], intermediaryPathToken, myAddress);
            } else if (swapCategory == 1){
                executeStableACrypto(balance, routerPath[i], intermediaryPathToken, myAddress);
            } else {
                executeStableEllipse
            }

            
        }
        IERC20 finalToken = IERC20(setTokenPath[lastTokenPathIndex]);
        uint256 finalBalance = finalToken.balanceOf(myAddress);

        require(
            finalBalance > endAmountRequired,
            string(
                abi.encodePacked(
                    "Trade preju! req:",
                    Utils.uint2str(endAmountRequired),
                    " final: ",
                    Utils.uint2str(finalBalance)
                )
            )
        );

        TransferHelper.safeTransfer(
            setTokenPath[lastTokenPathIndex],
            msg.sender,
            endAmountRequired
        );
        TransferHelper.safeTransfer(
            setTokenPath[lastTokenPathIndex],
            tx.origin,
            SafeMath.sub(finalBalance, endAmountRequired)
        );
    }

    function standardSwap(uint256 amount, address routerAddress, address[] path, address destination) internal {
        IUniswapV2Router02 currentRouter = IUniswapV2Router02(routerAddress);
        currentRouter.swapExactTokensForTokens(
                amount,
                0,
                path,
                destination,
                now + 1000
            );
    }

    function classifySwap(uint256 routerIndex) internal returns (uint256 swapCategory){
        if(routerIndex>= 0 || routerIndex<=4)return 0;
        if(routerIndex == 5)return 1;
        if(routerIndex == 6) return 2;        
        require(1==0, "Invalid router index");
    }

    function executeStableACrypto(uint256 amount, address routerAddress, address[] path, address destination){
        IACryptoRouter aCryptoRouter = IACryptoRouter(routerAddress);
        aCryptoRouter.exchange_underlying(
            ACryptosStableMap[path[0]], ACryptosStableMap[path[1]], amount, 0);
    }

    executeStableEllipse(uint256 amount, address routerAddress, address[] path, address destination){
        return;
    }

    function defineTokenOrderBasedOnPair(
        address token0,
        address token1,
        uint256 amount
    ) internal pure returns (uint256 a, uint256 b) {
        if (token0 > token1) return (0, amount);
        return (amount, 0);
    }

    function addRouter(uint256 index, address routerAddress)
        external
        onlyOwner
    {
        routerMap[index] = routerAddress;
    }

    function startStableMaps() internal {
        address addVAI = 0x4bd17003473389a42daf6a0a729f6fdb328bbbd7;
        address addDAI = 0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3;
        address addBUSD = 0xe9e7cea3dedca5984780bafc599bd69add087d56;
        address addUSDT = 0x55d398326f99059ff775485246999027b3197955;
        address addUSDC = 0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d;

        ACryptosStableMap[VAI] = 0;
        ACryptosStableMap[BUSD] = 1;
        ACryptosStableMap[USDT] = 2;
        ACryptosStableMap[DAI] = 3;
        ACryptosStableMap[USDC] = 4;

        //EllipsisStableMap[]
    }
}
/*
0= VAI
  0= BUSD
  1= USDT
  2= DAI
  3= USDC

ELLIPSIS FINANCE => 0x160CAed03795365F3A589f10C379FfA7d75d4E76 
(BUSD-USDC-USDT) => exchange(int128 i, int128 j, uint256 dx, uint256 min_dy)
0=DAI
1=BUSD
2=USDC
3=USDT
*/