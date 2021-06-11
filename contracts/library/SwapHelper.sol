pragma solidity ^0.6.6;

import "./../interfaces/ICorePool.sol";
import "./../interfaces/IMetaPool.sol";
import "./../interfaces/IUniswapV2Router02.sol";
import "./Utils.sol";

library SwapHelper {
    address constant addressVAI = 0x4BD17003473389A42DAF6a0a729f6Fdb328BbBd7;
    address constant addressDAI = 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3;
    address constant addressBUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant addressUSDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant addressUSDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    enum SwapCategory {
        UNISWAP,
        ACRYPTOSCORE,
        ACRYPTOSMETA,
        ELLIPSISCORE,
        ELLIPSISMETA
    }

    struct SwapStruct {
        uint256 amount;
        address currentRouterAddress;
        address[] path;
        SwapCategory swapCategory;
    }

    function executeSwap(SwapStruct memory swapInfo) internal {
        if (swapInfo.swapCategory == SwapCategory.UNISWAP) {
            standardSwap(
                swapInfo.amount,
                swapInfo.currentRouterAddress,
                swapInfo.path
            );
        } else if (swapInfo.swapCategory == SwapCategory.ACRYPTOSCORE) {
            executeCoreACrypto(
                swapInfo.amount,
                swapInfo.currentRouterAddress,
                swapInfo.path
            );
        } else if (swapInfo.swapCategory == SwapCategory.ACRYPTOSMETA) {
            executeMetaACrypto(
                swapInfo.amount,
                swapInfo.currentRouterAddress,
                swapInfo.path
            );
        } else if (swapInfo.swapCategory == SwapCategory.ELLIPSISCORE) {
            executeCoreEllipsis(
                swapInfo.amount,
                swapInfo.currentRouterAddress,
                swapInfo.path
            );
        } else {
            executeMetaEllipsis(
                swapInfo.amount,
                swapInfo.currentRouterAddress,
                swapInfo.path
            );
        }
    }

    function standardSwap(
        uint256 amount,
        address routerAddress,
        address[] memory path
    ) internal {
        IUniswapV2Router02 currentRouter = IUniswapV2Router02(routerAddress);
        try
            currentRouter.swapExactTokensForTokens(
                amount,
                0,
                path,
                address(this),
                now
            )
        {} catch {
            require(false, "Error Uniswap");
        }
    }

    function executeCoreACrypto(
        uint256 amount,
        address routerAddress,
        address[] memory path
    ) internal {
        ICorePool aCryptoCoreRouter = ICorePool(routerAddress);
        (int128 index0, int128 index1) = mapACryptos(path[0], path[1], 0);
        try aCryptoCoreRouter.exchange(index0, index1, amount, 0) {} catch {
            require(
                false,
                stableMessage("CPTcore", index0, index1, routerAddress, amount)
            );
        }
    }

    function executeMetaACrypto(
        uint256 amount,
        address routerAddress,
        address[] memory path
    ) internal {
        IMetaPool aCryptoMetaRouter = IMetaPool(routerAddress);
        (int128 index0, int128 index1) = mapACryptos(path[0], path[1], 1);
        try
            aCryptoMetaRouter.exchange_underlying(index0, index1, amount, 0)
        {} catch {
            require(
                false,
                stableMessage("CPTMeta", index0, index1, routerAddress, amount)
            );
        }
    }

    function executeCoreEllipsis(
        uint256 amount,
        address routerAddress,
        address[] memory path
    ) internal {
        ICorePool ellipsisCoreRouter = ICorePool(routerAddress);
        (int128 index0, int128 index1) = mapEllipsis(path[0], path[1], 0);
        try ellipsisCoreRouter.exchange(index0, index1, amount, 0) {} catch {
            require(
                false,
                stableMessage("ELPCore", index0, index1, routerAddress, amount)
            );
        }
    }

    function executeMetaEllipsis(
        uint256 amount,
        address routerAddress,
        address[] memory path
    ) internal {
        IMetaPool ellipsisMetaRouter = IMetaPool(routerAddress);
        (int128 index0, int128 index1) = mapEllipsis(path[0], path[1], 1);
        try
            ellipsisMetaRouter.exchange_underlying(index0, index1, amount, 0)
        {} catch {
            require(
                false,
                stableMessage("ELPMeta", index0, index1, routerAddress, amount)
            );
        }
    }

    function mapEllipsis(
        address tokenAddress0,
        address tokenAddress1,
        uint256 category
    ) internal returns (int128 index0, int128 index1) {
        int128 index00 = ellipsisManualMap(tokenAddress0);
        int128 index01 = ellipsisManualMap(tokenAddress1);

        return
            category == 0 ? ((index00 - 1), (index01 - 1)) : (index00, index01);
    }

    function ellipsisManualMap(address address1)
        internal
        returns (int128 index)
    {
        if (address1 == addressDAI) return 0;
        else if (address1 == addressBUSD) return 1;
        else if (address1 == addressUSDC) return 2;
        else if (address1 == addressUSDT) return 3;
        else require(1 == 0, "Invalid ellipsis token");
    }

    function mapACryptos(
        address tokenAddress0,
        address tokenAddress1,
        uint256 category //category 0 == core || category 1 == meta
    ) internal returns (int128 index0, int128 index1) {
        int128 index00 = aCryptosManualMap(tokenAddress0);
        int128 index01 = aCryptosManualMap(tokenAddress1);

        return
            category == 0 ? ((index00 - 1), (index01 - 1)) : (index00, index01);
    }

    function aCryptosManualMap(address address1)
        internal
        returns (int128 index)
    {
        if (address1 == addressVAI) return 0;
        else if (address1 == addressBUSD) return 1;
        else if (address1 == addressUSDT) return 2;
        else if (address1 == addressDAI) return 3;
        else if (address1 == addressUSDC) return 4;
        else require(1 == 0, "Invalid ACryptos token");
    }

    function classifySwap(uint256 routerIndex)
        internal
        returns (SwapCategory swapCategory)
    {
        if (routerIndex <= 5) return SwapCategory.UNISWAP;
        if (routerIndex == 6) return SwapCategory.ACRYPTOSCORE;
        if (routerIndex == 7) return SwapCategory.ACRYPTOSMETA;
        if (routerIndex == 8) return SwapCategory.ELLIPSISCORE;
        if (routerIndex == 9) return SwapCategory.ELLIPSISMETA;
        require(1 == 0, "Invalid router index");
    }

    function stableMessage(
        string memory message,
        int128 index0,
        int128 index1,
        address routerAddress,
        uint256 amt
    ) internal returns (string memory messageOut) {
        return (
            string(
                abi.encodePacked(
                    message,
                    ":",
                    Utils.uint2str(uint256(index0)),
                    ":",
                    Utils.uint2str(uint256(index1)),
                    ":",
                    Utils.addressToString(routerAddress),
                    ":",
                    Utils.uint2str(amt)
                )
            )
        );
    }
}
