pragma solidity >=0.5.0;

import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IERC20.sol";

import "./Utils.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";

library PancakeLibrary {
    using SafeMath for uint256;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "PancakeLibrary: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "PancakeLibrary: ZERO_ADDRESS");
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint256(
                keccak256(
                    abi.encodePacked(
                        hex"ff",
                        factory,
                        keccak256(abi.encodePacked(token0, token1)),
                        //hex"d0d4c4cd0848c93cb4fd1f498d7013ee6bfb25783ea21593d5834f5d250ece66" // init code hash MAINNET FACTORYv1
                        //hex"00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5" // init code hash MAINNET FACTORYv2
                        hex"ecba335299a6693cb2ebc4782e74669b84290b6378ea3a3873c7231a8d7d1074" // TESTNET
                    )
                )
            )
        );
    }

    // fetches and sorts the reserves for a pair
    function getReserves(
        address factory,
        address tokenA, //dai
        address tokenB //wbnb
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) =
            IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, "PancakeLibrary: INSUFFICIENT_AMOUNT");
        require(
            reserveA > 0 && reserveB > 0,
            "PancakeLibrary: INSUFFICIENT_LIQUIDITY"
        );
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "PancakeLibrary: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "PancakeLibrary: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn.mul(998);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "PancakeLibrary: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "PancakeLibrary: INSUFFICIENT_LIQUIDITY"
        );
        uint256 numerator = reserveOut.mul(amountOut).mul(1000);
        uint256 denominator = reserveIn.sub(amountOut).mul(998);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        require(path.length >= 2, "PancakeLibrary: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) =
                getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(
        address factory,
        uint256 amountOut,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        require(path.length >= 2, "PancakeLibrary: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) =
                getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}

/*
    function calculateSlippageFee(
        Utils.AmountsAndAdd memory structura,
        uint256 sentAmt,
        address pairAddress
    ) internal returns (uint256 value) {
        address token0 = structura.token0;
        address token1 = structura.token1;
        uint256 amount0Out = structura.amount0;
        uint256 amount1Out = structura.amount1;
        uint256 _reserve0 = structura.reserve0;
        uint256 _reserve1 = structura.reserve1;
        // scope for _token{0,1}, avoids stack too deep errors
        uint256 balance0 = IERC20(token0).balanceOf(pairAddress);
        uint256 balance1 = IERC20(token1).balanceOf(pairAddress);
        balance0 = balance0 + sentAmt;

        uint256 amount0In =
            balance0 > _reserve0 - amount0Out
                ? balance0 - (_reserve0 - amount0Out)
                : 0;
        uint256 amount1In =
            balance1 > _reserve1 - amount1Out
                ? balance1 - (_reserve1 - amount1Out)
                : 0;
        // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        uint256 balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(2));
        uint256 balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(2));

        //amtIn = balance1 - _reserve1
        /*
        require(
            1 == 0,
            string(
                abi.encodePacked(
                    "",
                    Utils.uint2str(amount0In),
                    ":",
                    Utils.uint2str(amount1In),
                    ":",
                    Utils.uint2str(balance0),
                    ":",
                    Utils.uint2str(balance1),
                    ":",
                    Utils.uint2str(_reserve0),
                    ":",
                    Utils.uint2str(_reserve1)
                )
            )
        );*/

/*
        uint256 slipageFee =
            balance0Adjusted.mul(balance1Adjusted) -
                (_reserve0.mul(_reserve1).mul(1000**2));*/

/*
            require(
                balance0Adjusted.mul(balance1Adjusted) >=
                    uint256(_reserve0).mul(_reserve1).mul(1000**2),
                "Pancake: K"
            );*/
/*
function swap(
    uint256 amount0Out,  0
    uint256 amount1Out, 100000000000
    uint112 _reserve0,
    uint112 _reserve1
) external lock {
    (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
    require(
        amount0Out < _reserve0 && amount1Out < _reserve1,
        "Pancake: INSUFFICIENT_LIQUIDITY"
    );

    uint256 balance0;
    uint256 balance1;
    {
        // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, "Pancake: INVALID_TO");
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0)
            IPancakeCallee(to).pancakeCall(
                msg.sender,
                amount0Out,
                amount1Out,
                data
            );
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
    }
    uint256 amount0In =
        balance0 > _reserve0 - amount0Out
            ? balance0 - (_reserve0 - amount0Out)
            : 0;
    uint256 amount1In =
        balance1 > _reserve1 - amount1Out
            ? balance1 - (_reserve1 - amount1Out)
            : 0;
    require(
        amount0In > 0 || amount1In > 0,
        "Pancake: INSUFFICIENT_INPUT_AMOUNT"
    );
    // scope for reserve{0,1}Adjusted, avoids stack too deep errors
    uint256 balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(2));
    uint256 balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(2));
    require(
        balance0Adjusted.mul(balance1Adjusted) >=
            uint256(_reserve0).mul(_reserve1).mul(1000**2),
        "Pancake: K"
    );

    _update(balance0, balance1, _reserve0, _reserve1);
    emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
}
*/
