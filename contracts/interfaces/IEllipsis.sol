pragma solidity >=0.5.0;

interface IEllipsis {
    function add_liquidity(
        uint256[4] amounts,
        uint256 min_mint_amount
    ) external;

    function remove_liquidity_one_coin(
        uint256 token_amount,
        int128 i,  // 0 DAI 1=BUSD 2=USDC 3=USDT
        uint256 min_mint_amount
    ) external;
}
