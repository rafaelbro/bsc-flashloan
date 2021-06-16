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
import "./library/SwapHelper.sol";

contract Arbitrage {
    address public pancakeFactory;
    address owner;
    address myAddress = address(this); // contract address
    mapping(uint256 => address) private routerMap; //mapping ints to routers

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
                "Unauthorized pair: ",
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

        SwapHelper.SwapStruct memory swapStruct;

        for (uint256 i = 0; i < setTokenPath.length - 1; i++) {
            address[] memory intermediaryPathToken = new address[](2);
            intermediaryPathToken[0] = setTokenPath[i];
            intermediaryPathToken[1] = setTokenPath[i + 1];
            IERC20 token = IERC20(intermediaryPathToken[0]);

            uint256 currentRouterIndex = setRouterPath[i];
            address currentRouterAddress = routerMap[currentRouterIndex];

            uint256 balance = token.balanceOf(myAddress); //gets current balance
            token.approve(currentRouterAddress, balance); //approves for spending

            swapStruct.amount = balance;
            swapStruct.path = intermediaryPathToken;
            swapStruct.currentRouterAddress = currentRouterAddress;
            swapStruct.swapCategory = SwapHelper.classifySwap(
                currentRouterIndex
            );

            SwapHelper.executeSwap(swapStruct);
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
            calculatedPairAddress,
            endAmountRequired
        );
        TransferHelper.safeTransfer(
            setTokenPath[lastTokenPathIndex],
            tx.origin,
            SafeMath.sub(finalBalance, endAmountRequired)
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
