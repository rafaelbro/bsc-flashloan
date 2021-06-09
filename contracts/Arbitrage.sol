pragma solidity ^0.6.6;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ICorePool.sol";
import "./interfaces/IMetaPool.sol";

import "./library/TransferHelper.sol";
import "./library/PancakeLibrary.sol";
import "./library/Utils.sol";

contract Arbitrage {
    address public pancakeFactory;
    address owner;
    address myAddress = address(this); // contract address
    mapping(uint256 => address) private routerMap; //mapping ints to routers
    mapping(address => int128) public ACryptosStableMap;
    mapping(address => int128) public EllipsisStableMap;

    enum SwapCategory {
        UNISWAP,
        ACRYPTOSCORE,
        ACRYPTOSMETA,
        ELLIPSISCORE,
        ELLIPSISMETA
    }

    uint256[] private setRouterPath; //var to declare router path
    address[] private setTokenPath; //var to declare token addresses path

    modifier onlyOwner {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    constructor(address _pancakeFactory, address[] memory routers) public {
        pancakeFactory = _pancakeFactory;
        owner = msg.sender;
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
    ) external onlyOwner {
        //require(tokenPath.length > 1, "Wrong token path size");
        address pairAddress =
            IUniswapV2Factory(pancakeFactory).getPair(
                tokenPath[0],
                tokenPath[tokenPath.length - 1]
            );
        require(pairAddress != address(0), "This pool does not exist");

        (uint256 amountToken0, uint256 amountToken1) =
            defineTokenOrderBasedOnPair(
                tokenPath[0],
                tokenPath[tokenPath.length - 1],
                amountBorrowed
            );

        setPath(routerPath, tokenPath);
        //Flashloan borrows asset with non 0 amount
        IUniswapV2Pair(pairAddress).swap(
            amountToken0,
            amountToken1,
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
        require(_amount0 == 0 || _amount1 == 0, "Zeroed amounts");
        uint256 lastTokenPathIndex = setTokenPath.length - 1;
        address pairAddress = msg.sender;
        address[] memory endPathToken = new address[](2);
        endPathToken[0] = setTokenPath[lastTokenPathIndex];
        endPathToken[1] = setTokenPath[0];

        address calculatedPairAddress =
            PancakeLibrary.pairFor(
                pancakeFactory,
                endPathToken[0],
                endPathToken[1]
            );
        require(
            msg.sender == calculatedPairAddress,
            Utils.append(
                "Unauthorized par: ",
                msg.sender,
                calculatedPairAddress
            )
        );

        uint256 amount0In = IERC20(setTokenPath[0]).balanceOf(myAddress);
        require(amount0In != 0, "borrowed wrong asset");

        //calculates amount required to payback loan that will need to be generated
        //Given an output amount calculates the input amount of the token 0
        uint256 endAmountRequired =
            PancakeLibrary.getAmountsIn(
                pancakeFactory,
                IERC20(setTokenPath[0]).balanceOf(myAddress), //given output amt
                endPathToken //path from input token to output token
            )[0];

        uint256 valorContract =
            IUniswapV2Router01(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3)
                .getAmountsIn(
                IERC20(setTokenPath[0]).balanceOf(myAddress),
                endPathToken
            )[0];

        require(
            endAmountRequired == valorContract,
            string(
                abi.encodePacked(
                    "calc: ",
                    Utils.uint2str(endAmountRequired),
                    " contract: ",
                    valorContract
                )
            )
        );

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
            } else if (resolvedSwapCategory == SwapCategory.ACRYPTOSCORE) {
                executeCoreACrypto(
                    balance,
                    currentRouterAddress,
                    intermediaryPathToken
                );
            } else if (resolvedSwapCategory == SwapCategory.ACRYPTOSMETA) {
                executeMetaACrypto(
                    balance,
                    currentRouterAddress,
                    intermediaryPathToken
                );
            } else if (resolvedSwapCategory == SwapCategory.ELLIPSISCORE) {
                executeCoreEllipsis(
                    balance,
                    currentRouterAddress,
                    intermediaryPathToken
                );
            } else {
                executeMetaEllipsis(
                    balance,
                    currentRouterAddress,
                    intermediaryPathToken
                );
            }
        }
        //gets final balance of last token
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
            pairAddress,
            endAmountRequired
        );
        TransferHelper.safeTransfer(
            setTokenPath[lastTokenPathIndex],
            tx.origin,
            SafeMath.sub(finalBalance, endAmountRequired)
        );
        require(1 == 0, "executou");
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
        if (routerIndex >= 0 || routerIndex <= 5) return SwapCategory.UNISWAP;
        if (routerIndex == 6) return SwapCategory.ACRYPTOSCORE;
        if (routerIndex == 7) return SwapCategory.ACRYPTOSMETA;
        if (routerIndex == 8) return SwapCategory.ELLIPSISCORE;
        if (routerIndex == 9) return SwapCategory.ELLIPSISMETA;
        require(1 == 0, "Invalid router index");
    }

    function executeCoreACrypto(
        uint256 amount,
        address routerAddress,
        address[] memory path
    ) internal {
        ICorePool aCryptoCoreRouter = ICorePool(routerAddress);
        aCryptoCoreRouter.exchange(
            ACryptosStableMap[path[0]] - 1, //adjusted asset index
            ACryptosStableMap[path[1]] - 1, //adjusted asset index
            amount,
            0
        );
    }

    function executeMetaACrypto(
        uint256 amount,
        address routerAddress,
        address[] memory path
    ) internal {
        IMetaPool aCryptoMetaRouter = IMetaPool(routerAddress);
        aCryptoMetaRouter.exchange_underlying(
            ACryptosStableMap[path[0]],
            ACryptosStableMap[path[1]],
            amount,
            0
        );
    }

    function executeCoreEllipsis(
        uint256 amount,
        address routerAddress,
        address[] memory path
    ) internal {
        IMetaPool ellipsisCoreRouter = IMetaPool(routerAddress);
        ellipsisCoreRouter.exchange_underlying(
            EllipsisStableMap[path[0]] - 1, //adjusted asset index
            EllipsisStableMap[path[1]] - 1, //adjusted asset index
            amount,
            0
        );
    }

    function executeMetaEllipsis(
        uint256 amount,
        address routerAddress,
        address[] memory path
    ) internal {
        IMetaPool ellipsisMetaRouter = IMetaPool(routerAddress);
        ellipsisMetaRouter.exchange_underlying(
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

    function defineTokenOrderAmountAndAddressBasedOnPair(
        address token0,
        address token1,
        uint256 amount
    )
        internal
        pure
        returns (
            uint256 a,
            uint256 b,
            address token00,
            address token01
        )
    {
        if (token0 > token1) return (0, amount, token1, token0);
        return (amount, 0, token0, token1);
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
        ACryptosStableMap[addressBUSD] = 1; // -1 for core
        ACryptosStableMap[addressUSDT] = 2; // -1 for core
        ACryptosStableMap[addressDAI] = 3; // -1 for core
        ACryptosStableMap[addressUSDC] = 4; //-1 for core

        EllipsisStableMap[addressDAI] = 0;
        EllipsisStableMap[addressBUSD] = 1; //-1 for core
        EllipsisStableMap[addressUSDC] = 2; //-1 for core
        EllipsisStableMap[addressUSDT] = 3; //-1 for core
    }

    function getRouterIn(uint256 index)
        public
        view
        returns (address routerAddress)
    {
        return routerMap[index];
    }

    function renounceOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
