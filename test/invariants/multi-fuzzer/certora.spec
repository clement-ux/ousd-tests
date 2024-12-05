methods {
    function rebasingCreditsPerTokenHighres() external returns uint256 envfree;
}

rule neverBellow27(method f) {    
    env e;
    
    require rebasingCreditsPerTokenHighres() <= 1000000000000000000000000000;
    require f.selector != sig:initialize(address, uint256);

    // issues:
    // We cannot mint 1eth to dead address at beginning
    // 

    calldataarg args;
    f(e, args);

    assert rebasingCreditsPerTokenHighres() <= 1000000000000000000000000000, "nnnaaaann";
}