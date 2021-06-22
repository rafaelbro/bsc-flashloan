pragma solidity ^0.6.6;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ICorePool.sol";
import "./interfaces/IMetaPool.sol";

import "./library/TransferHelper.sol";
import "./library/RouterLibrary.sol";
import "./library/Utils.sol";
import "./library/SwapHelper.sol";

contract Arbitrage {
    address owner;
    address myAddress = address(this); // contract address
    address private pairAddress;
    mapping(uint256 => address) private routerMap; //mapping ints to routers

    uint256[] private setRouterPath; //var to declare router path
    address[] private setTokenPath; //var to declare token addresses path

    uint256 private constant pancakeFee = 25;
    uint256 private constant waultFee = 20;
    uint256 private constant mdexFee = 30;

    modifier onlyOwner {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    constructor(address[] memory routers) public {
        owner = msg.sender;
        require(routers.length > 0, "No routers declared");
        for (uint256 i = 0; i < routers.length; i++) {
            routerMap[i] = routers[i];
        }
    }

    function setPath(address[] memory tokenPath)
        internal
    {
        delete setTokenPath;
        for (uint256 i; i < tokenPath.length - 1; i++) {
            setTokenPath.push(abi.encodePacked("00000000000000003b6d0340", tokenPath[i]));
        }
    }

    function startArbitrage(
        address srcTokenAddr,
        uint256 amountBorrowed, //amount of tokens of token[0]
        uint256 minReturnValue, //Double check if it is the final token, origin token or dollar
        address[] calldata tokenPairPath
    ) external onlyOwner {
        pairAddress = inPairAddress;

        uint256 amountToken0 = 0; //Consider use of BUSD
        setPath(tokenPairPath);

        //Flashloan borrows asset with non 0 amount
        IUniswapV2Pair(pairAddress).swap(
            amountToken0,
            amountBorrowed,
            address(this),
            bytes("not empty")
        );
    }

    function pancakeCall(
        //pancakeswap and apeswap call this
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        require(_amount0 == 0 || _amount1 == 0, "Pancake Zeroed amounts");
        uint256 lastTokenPathIndex = setTokenPath.length - 1;
        address[] memory endPathToken = new address[](2);
        endPathToken[0] = setTokenPath[lastTokenPathIndex];
        endPathToken[1] = setTokenPath[0];

        require(
            msg.sender == pairAddress,
            Utils.append("Pancake Unauthorized pair: ", msg.sender, pairAddress)
        );

        uint256 amount0In = IERC20(setTokenPath[0]).balanceOf(myAddress);
        require(amount0In != 0, "Pancake borrowed wrong asset");

        //calculates amount required to payback loan that will need to be generated
        //Given an output amount calculates the input amount of the token 0
        uint256 endAmountRequired =
            RouterLibrary.getAmountsIn(
                pairAddress,
                IERC20(setTokenPath[0]).balanceOf(myAddress), //given output amt
                endPathToken, //path from input token to output token
                pancakeFee
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
                    "Pancake Trade preju! req:",
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
    }

    function waultSwapCall(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        require(_amount0 == 0 || _amount1 == 0, "Wault Zeroed amounts");
        uint256 lastTokenPathIndex = setTokenPath.length - 1;
        address[] memory endPathToken = new address[](2);
        endPathToken[0] = setTokenPath[lastTokenPathIndex];
        endPathToken[1] = setTokenPath[0];

        require(
            msg.sender == pairAddress,
            Utils.append("Wault unauthorized pair: ", msg.sender, pairAddress)
        );

        uint256 amount0In = IERC20(setTokenPath[0]).balanceOf(myAddress);
        require(amount0In != 0, "Wault borrowed wrong asset");

        //calculates amount required to payback loan that will need to be generated
        //Given an output amount calculates the input amount of the token 0
        uint256 endAmountRequired =
            RouterLibrary.getAmountsIn(
                pairAddress,
                IERC20(setTokenPath[0]).balanceOf(myAddress), //given output amt
                endPathToken, //path from input token to output token
                waultFee
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
                    "Wault Trade preju! req:",
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
    }

    function swapV2Call(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        require(_amount0 == 0 || _amount1 == 0, "Mdex Zeroed amounts");
        uint256 lastTokenPathIndex = setTokenPath.length - 1;
        address[] memory endPathToken = new address[](2);
        endPathToken[0] = setTokenPath[lastTokenPathIndex];
        endPathToken[1] = setTokenPath[0];

        require(
            msg.sender == pairAddress,
            Utils.append("Mdex unauthorized pair: ", msg.sender, pairAddress)
        );

        uint256 amount0In = IERC20(setTokenPath[0]).balanceOf(myAddress);
        require(amount0In != 0, "Mdex borrowed wrong asset");

        //calculates amount required to payback loan that will need to be generated
        //Given an output amount calculates the input amount of the token 0
        uint256 endAmountRequired =
            RouterLibrary.getAmountsIn(
                pairAddress,
                IERC20(setTokenPath[0]).balanceOf(myAddress), //given output amt
                endPathToken, //path from input token to output token
                mdexFee
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
                    "Mdex Trade preju! req:",
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
