pragma solidity ^0.6.6;

import "./UniswapV2Library.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IERC20.sol";

contract Arbitrage {
    address public pancakeFactory;
    uint256 deadline = now + 1 days;
    IUniswapV2Router02 public bakeryRouter;

    constructor(address _pancakeFactory, address _bakeryRouter) public {
        pancakeFactory = _pancakeFactory;
        bakeryRouter = IUniswapV2Router02(_bakeryRouter);
    }

    function startArbitrage(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) external {
        address pairAddress =
            IUniswapV2Factory(pancakeFactory).getPair(token0, token1);
        require(pairAddress != address(0), "This pool does not exist");
        //Flashloan borrows asset with non 0 amount
        IUniswapV2Pair(pairAddress).swap(
            amount0,
            amount1,
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
        address[] memory path = new address[](2);

        uint256 amountToken = _amount0 == 0 ? _amount1 : _amount0; //gets borrowed token

        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        //address calc = UniswapV2Library.pairFor(pancakeFactory, token0, token1); wrong calculations

        address pairAdress = msg.sender;
        /*
        require(
            msg.sender == calc,
            append("Unauthorized par: ", msg.sender, calc)
        );*/
        require(_amount0 == 0 || _amount1 == 0, "Zeroed amounts");

        path[0] = _amount0 == 0 ? token1 : token0;
        path[1] = _amount0 == 0 ? token0 : token1;

        IERC20 token = IERC20(_amount0 == 0 ? token1 : token0);

        token.approve(address(bakeryRouter), amountToken);

        //get amount required to trade
        uint256 amountRequired =
            UniswapV2Library.getAmountsIn(
                pancakeFactory,
                amountToken,
                path,
                pairAdress
            )[0];
        /*
        require(
            1 == 0,
            string(
                abi.encodePacked(
                    " params, amountToken: ", //borrowed
                    uint2str(amountToken),
                    " params, amountReq: ",
                    uint2str(amountRequired), //required from 2nd token to repay borrow
                    " path0: ",
                    addressToString(path[0]),
                    " path1: ",
                    addressToString(path[1])
                )
            )
        );*/
        IERC20 otherToken = IERC20(_amount0 == 0 ? token0 : token1);

        uint256[] memory amountReceived = new uint256[](2);
        amountReceived = bakeryRouter.swapExactTokensForTokens(
            amountToken,
            amountRequired,
            path,
            msg.sender,
            deadline
        );

        /*
        require(
            1 == 0,
            string(
                abi.encodePacked(
                    " amt1: ",
                    uint2str(amountReceived[0]),
                    " amt2: ",
                    uint2str(amountReceived[1]),
                    //" received: ",
                    //uint2str(amountReceived),
                    " req:",
                    uint2str(amountRequired)
                    //" mine: ",
                    //uint2str(SafeMath.sub(amountReceived, amountRequired))
                )
            )
        );*/

        //returns second part of pool back
        otherToken.transfer(msg.sender, amountRequired);
        otherToken.transfer(
            tx.origin,
            SafeMath.sub(amountReceived[1] - 1, amountRequired)
        );
    }

    // Utility Functions
    function addressToString(address x) internal view returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal view returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function append(
        string memory a,
        address b,
        address c
    ) internal view returns (string memory) {
        return
            string(
                abi.encodePacked(a, addressToString(b), " ", addressToString(c))
            );
    }
}
