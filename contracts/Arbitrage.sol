pragma solidity ^0.6.6;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IACryptoRouter.sol";
import "./interfaces/IEllipsisRouter.sol";

import "./library/TransferHelper.sol";
import "./library/UniswapV2Library.sol";
import "./library/Utils.sol";

contract Arbitrage {
    address public pancakeFactory;
    address private owner;
    address myAddress = address(this); // contract address
    mapping(uint256 => address) private routerMap; //mapping ints to routers
    mapping(address => int128) public ACryptosStableMap;
    mapping(address => int128) public EllipsisStableMap;

    enum SwapCategory {UNISWAP, ACRYPTOS, ELLIPSIS}

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
                tokenPath[tokenPath.length - 1]
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

        address pairAddress = msg.sender;

        //IERC20 token = IERC20(_amount0 == 0 ? token1 : token0);

        uint256 lastTokenPathIndex = setTokenPath.length - 1;

        address[] memory endPathToken = new address[](2);
        endPathToken[0] = setTokenPath[0];
        endPathToken[1] = setTokenPath[lastTokenPathIndex];

        require(
            (IERC20(endPathToken[0]).balanceOf(myAddress)) != 0,
            "borrowed wrong asset"
        );

        //calculates amount required to payback loan that will need to be generated
        uint256 endAmountRequired =
            UniswapV2Library.getAmountsIn(
                pancakeFactory,
                IERC20(setTokenPath[0]).balanceOf(myAddress),
                endPathToken, //path from 1st to last token
                pairAddress
            )[0];

        for (uint256 i = 0; i < setTokenPath.length - 1; i++) {
            address[] memory intermediaryPathToken = new address[](2);
            intermediaryPathToken[0] = setTokenPath[i];
            intermediaryPathToken[1] = setTokenPath[i + 1];
            IERC20 token = IERC20(intermediaryPathToken[0]);

            uint256 currentRouterIndex = setRouterPath[i];
            address currentRouterAddress = routerMap[currentRouterIndex];

            uint256 balance = token.balanceOf(myAddress); //gets current balance
            token.approve(currentRouterAddress, balance); //approves for spending

            SwapCategory resolvedSwapCategory =
                classifySwap(currentRouterIndex);

            if (resolvedSwapCategory == SwapCategory.UNISWAP) {
                standardSwap(
                    balance,
                    currentRouterAddress,
                    intermediaryPathToken,
                    myAddress
                );
            } else if (resolvedSwapCategory == SwapCategory.ACRYPTOS) {
                executeStableACrypto(
                    balance,
                    currentRouterAddress,
                    intermediaryPathToken
                );
            } else {
                executeStableEllipse(
                    balance,
                    currentRouterAddress,
                    intermediaryPathToken
                );
            }
        }
        //gets final balance of last token
        IERC20 finalToken = IERC20(setTokenPath[lastTokenPathIndex]);
        uint256 finalBalance = finalToken.balanceOf(myAddress);

        uint256 borrowBalance = IERC20(setTokenPath[0]).balanceOf(myAddress);

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
        /*
        require(
            1 == 0,
            string(
                abi.encodePacked(
                    "add1:",
                    Utils.addressToString(setTokenPath[lastTokenPathIndex]),
                    " traded: ",
                    Utils.uint2str(finalBalance),
                    " req: ",
                    Utils.uint2str(endAmountRequired)
                )
            )
        );*/

        TransferHelper.safeTransfer(
            setTokenPath[lastTokenPathIndex],
            pairAddress,
            endAmountRequired
        );
        TransferHelper.safeTransfer(
            setTokenPath[lastTokenPathIndex],
            tx.origin,
            SafeMath.sub(finalBalance, endAmountRequired)
        );
    }

    function standardSwap(
        uint256 amount,
        address routerAddress,
        address[] memory path,
        address destination
    ) internal {
        IUniswapV2Router02 currentRouter = IUniswapV2Router02(routerAddress);
        currentRouter.swapExactTokensForTokens(
            amount,
            0,
            path,
            destination,
            now
        );
    }

    function classifySwap(uint256 routerIndex)
        internal
        returns (SwapCategory swapCategory)
    {
        if (routerIndex >= 0 || routerIndex <= 4) return SwapCategory.UNISWAP;
        if (routerIndex == 5) return SwapCategory.ACRYPTOS;
        if (routerIndex == 6) return SwapCategory.ELLIPSIS;
        require(1 == 0, "Invalid router index");
    }

    function executeStableACrypto(
        uint256 amount,
        address routerAddress,
        address[] memory path
    ) internal {
        IACryptoRouter aCryptoRouter = IACryptoRouter(routerAddress);
        aCryptoRouter.exchange_underlying(
            ACryptosStableMap[path[0]],
            ACryptosStableMap[path[1]],
            amount,
            0
        );
    }

    function executeStableEllipse(
        uint256 amount,
        address routerAddress,
        address[] memory path
    ) internal {
        IEllipsisRouter ellipsisRouter = IEllipsisRouter(routerAddress);
        ellipsisRouter.exchange_underlying(
            EllipsisStableMap[path[0]],
            EllipsisStableMap[path[1]],
            amount,
            0
        );
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
        address addressVAI = 0x4BD17003473389A42DAF6a0a729f6Fdb328BbBd7;
        address addressDAI = 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3;
        address addressBUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
        address addressUSDT = 0x55d398326f99059fF775485246999027B3197955;
        address addressUSDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

        ACryptosStableMap[addressVAI] = 0;
        ACryptosStableMap[addressBUSD] = 1;
        ACryptosStableMap[addressUSDT] = 2;
        ACryptosStableMap[addressDAI] = 3;
        ACryptosStableMap[addressUSDC] = 4;

        EllipsisStableMap[addressDAI] = 0;
        EllipsisStableMap[addressBUSD] = 1;
        EllipsisStableMap[addressUSDC] = 2;
        EllipsisStableMap[addressUSDT] = 3;
    }
}
