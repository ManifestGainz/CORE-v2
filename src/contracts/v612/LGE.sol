// SPDX-License-Identifier: MIT
// COPYRIGHT cVault.finance TEAM
// NO COPY
// COPY = BAD
// This code is provided with no assurances or guarantees of any kind. Use at your own responsibility.
//
//  _     _             _     _ _ _           
// | |   (_)           (_)   | (_) |         
// | |    _  __ _ _   _ _  __| |_| |_ _   _  
// | |   | |/ _` | | | | |/ _` | | __| | | | 
// | |___| | (_| | |_| | | (_| | | |_| |_| | 
// \_____/_|\__, |\__,_|_|\__,_|_|\__|\__, |  
//             | |                     __/ |                                                                               
//             |_|                    |___/               
//  _____                           _   _               _____                _                                                                    
// |  __ \                         | | (_)             |  ___|              | |  
// | |  \/ ___ _ __   ___ _ __ __ _| |_ _  ___  _ __   | |____   _____ _ __ | |_ 
// | | __ / _ \ '_ \ / _ \ '__/ _` | __| |/ _ \| '_ \  |  __\ \ / / _ \ '_ \| __|
// | |_\ \  __/ | | |  __/ | | (_| | |_| | (_) | | | | | |___\ V /  __/ | | | |_ 
//  \____/\___|_| |_|\___|_|  \__,_|\__|_|\___/|_| |_| \____/ \_/ \___|_| |_|\__|
//
// \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\                      
//    \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\                        
//       \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\                        
//          \\\\\\\\\\\\\\\\\\\\\\\\\\\\\                          
//            \\\\\\\\\\\\\\\\\\\\\\\\\\                           
//               \\\\\\\\\\\\\\\\\\\\\                             
//                  \\\\\\\\\\\\\\\\\                              
//                    \\\\\\\\\\\\\\                               
//                    \\\\\\\\\\\\\                                
//                    \\\\\\\\\\\\                                 
//                   \\\\\\\\\\\\                                  
//                  \\\\\\\\\\\\                                   
//                 \\\\\\\\\\\\                                    
//                \\\\\\\\\\\\                                     
//               \\\\\\\\\\\\                                      
//               \\\\\\\\\\\\                                      
//          `     \\\\\\\\\\\\      `    `                         
//             *    \\\\\\\\\\\\  *   *                            
//      `    *    *   \\\\\\\\\\\\   *  *   `                      
//              *   *   \\\\\\\\\\  *                              
//           `    *   * \\\\\\\\\ *   *   `                        
//        `    `     *  \\\\\\\\   *   `_____                      
//              \ \ \ * \\\\\\\  * /  /\`````\                    
//            \ \ \ \  \\\\\\  / / / /  \`````\                    
//          \ \ \ \ \ \\\\\\ / / / / |[] | [] |
//                                  EqPtz5qN7HM
//
// This contract lets people kickstart pair liquidity on uniswap together
// By pooling tokens together for a period of time
// A bundle of sticks makes one mighty liquidity pool
//
pragma solidity 0.6.12;


import './ICOREGlobals.sol';

import '@uniswap/v2-periphery/contracts/interfaces/IWETH.sol';
// import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import './COREv1/ICoreVault.sol';
import "@nomiclabs/buidler/console.sol";

// import '@uniswap/v2-core/contracts/UniswapV2Pair.sol';

library COREIUniswapV2Library {
    
    using SafeMath for uint256;

    // Copied from https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/libraries/IUniswapV2Library.sol
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'IUniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'IUniswapV2Library: ZERO_ADDRESS');
    }

        // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal  returns (uint256 amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        console.log("Inside getAmountOut from uniswap got amountIn of", amountIn);
        uint amountInWithFee = amountIn.mul(997);
        console.log("multiplied by 997 its",amountInWithFee);
        console.log("Reserve out is",reserveOut);

        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        console.log("Reserve in ",reserveIn);
        console.log( "So numerator is", numerator, "and denominator is", denominator);

        amountOut = numerator / denominator;
        console.log("So amount out is ", amountOut);
    }

}


interface ICOREVault {
    function depositFor(address, uint256 , uint256 ) external;
}


interface IERC95 {
    function wrapAtomic(address) external;
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function skim(address to) external;
    function unpauseTransfers() external;

}

interface CERC95 {
    function wrapAtomic(address) external;
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function skim(address to) external;
    function name() external view returns (string memory);
}


interface ICORETransferHandler {
    function sync(address) external returns(bool,bool);
}

contract cLGE is Initializable, OwnableUpgradeSafe, ReentrancyGuardUpgradeSafe {

    using SafeMath for uint256;


    /// CORE gets deposited straight never sold - refunded if balance is off at end
    // Others get sold if needed
    // ETH always gets sold into XXX from CORE/XXX
    
    IERC20 public tokenBeingWrapped;
    address public coreEthPair;
    address public wrappedToken;
    address public preWrapEthPair;
    address public COREToken;
    address public _WETH;
    address public wrappedTokenUniswapPair;
    address public uniswapFactory;

    ///////////////////////////////////////
    // Note this 3 are not supposed to be actual contributed because of the internal swaps
    // But contributed by people, before internal swaps
    uint256 public totalETHContributed;
    uint256 public totalCOREContributed;
    uint256 public totalWrapTokenContributed;
    ////////////////////////////////////////



    ////////////////////////////////////////
    // Internal balances user to calculate canges
    // Note we dont have WETH here because it all goes out
    uint256 private wrappedTokenBalance;
    uint256 private COREBalance;
    ////////////////////////////////////////

    ////////////////////////////////////////
    // Variables for calculating LP gotten per each user
    // Note all contributions get "flattened" to CORE 
    // This means we just calculate how much CORE it would buy with the running average
    // And use that as the counter
    uint256 public totalCOREToRefund; // This is in case there is too much CORE in the contract we refund people who contributed CORE proportionally
                                      // Potential scenario where someone swapped too much ETH/WBTC into CORE causing too much CORE to be in the contract
                                      // and subsequently being not refunded because he didn't contribute CORE but bought CORE for his ETH/WETB
                                      // Was noted and decided that the impact of this is not-significant
    uint256 public totalLPCreated;    
    uint256 private totalUnitsContributed;
    uint256 public LPPerUnitContributed; // stored as 1e18 more - this is done for change
    ////////////////////////////////////////


    event Contibution(uint256 COREvalue, address from);
    event COREBought(uint256 COREamt, address from);

    mapping (address => uint256) public COREContributed; // We take each persons core contributed to calculate units and 
                                                        // to calculate refund later from totalCoreRefund + CORE total contributed
    mapping (address => uint256) public unitsContributed; // unit to keep track how much each person should get of LP
    mapping (address => uint256) public unitsClaimed; 
    mapping (address => bool) public CORERefundClaimed; 
    mapping (address => address) public pairWithWETHAddressForToken; 

    mapping (address => uint256) public wrappedTokenContributed; // To calculate units
                                                                 // Note eth contributed will turn into this and get counted
    ICOREGlobals public coreGlobals;
    bool public LGEStarted;
    uint256 public contractStartTimestamp;
    uint256 public LGEDurationDays;
    bool public LGEFinished;

    function initialize(uint256 daysLong, address _wrappedToken, address _coreGlobals, address _preWrapEthPair) public initializer {
        require(msg.sender == address(0x5A16552f59ea34E44ec81E58b3817833E9fD5436));
        OwnableUpgradeSafe.__Ownable_init();
        ReentrancyGuardUpgradeSafe.__ReentrancyGuard_init();

        contractStartTimestamp = uint256(-1); // wet set it here to max so checks fail
        LGEDurationDays = daysLong.mul(1 days);
        coreGlobals = ICOREGlobals(_coreGlobals);
        coreEthPair = coreETHPairGetter();
        (COREToken, _WETH) = (IUniswapV2Pair(coreEthPair).token0(), IUniswapV2Pair(coreEthPair).token1()); // bb
        console.log("Address WETH= ", _WETH);
        address tokenBeingWrappedAddress = IUniswapV2Pair(_preWrapEthPair).token1(); // bb
        tokenBeingWrapped =  IERC20(tokenBeingWrappedAddress); 

        console.log("In constructor pair, prewrap eth pair pair is " , _preWrapEthPair, CERC95(_preWrapEthPair).name());
        console.log("tokenBeingWrapped (token0) is ", tokenBeingWrappedAddress, CERC95(tokenBeingWrappedAddress).name());

        pairWithWETHAddressForToken[address(tokenBeingWrapped)] = _preWrapEthPair;
        pairWithWETHAddressForToken[IUniswapV2Pair(coreEthPair).token0()] = coreEthPair;// bb 


        wrappedToken = _wrappedToken;
        preWrapEthPair = _preWrapEthPair;
        uniswapFactory = coreGlobals.UniswapFactory();
    }
    
    function setTokenBeingWrapped(address token, address tokenPairWithWETH) public onlyOwner {
        tokenBeingWrapped = IERC20(token);
        pairWithWETHAddressForToken[token] = tokenPairWithWETH;
    }
    
    /// Starts LGE by admin call
    function startLGE() public onlyOwner {
        require(LGEStarted == false, "Already started");
        console.log("Starting LGE on block", block.timestamp);
        contractStartTimestamp = block.timestamp;
        LGEStarted = true;

        updateRunningAverages();
    }
    
    function isLGEOver() public view returns (bool) {
        return block.timestamp > contractStartTimestamp.add(LGEDurationDays);
    }
    
    function claimLP() nonReentrant public {
        IUniswapV2Pair(wrappedTokenUniswapPair).transfer(msg.sender, _claimLP());
    }

    function claimAndStakeLP() nonReentrant public {
        address vault = coreGlobals.COREVaultAddress();

        IUniswapV2Pair(wrappedTokenUniswapPair).approve(vault, uint(-1));
    
        ICOREVault(vault).depositFor(msg.sender,1, _claimLP());
    }


    function _claimLP() internal returns (uint256 sentAmt){ 
        require(LGEFinished == true, "LGE : Liquidity generation not finished");
        require(unitsContributed[msg.sender].sub(unitsClaimed[msg.sender]) > 0, "LEG : Nothing to claim");
        sentAmt = unitsContributed[msg.sender].sub(getCORERefundForPerson(msg.sender)).mul(LPPerUnitContributed).div(1e18);
            // LPPerUnitContributed is stored at 1e18 multiplied


        unitsClaimed[msg.sender] = unitsContributed[msg.sender];
    }

    function buyToken(address tokenTarget, uint256 amtToken, address tokenSwapping, uint256 amtTokenSwappingInput, address pair) internal {
        console.log(" > LGE.sol::buyToken(address tokenTarget, uint256 amtToken, address tokenSwapping, uint256 amtTokenSwappingInput, address pair) internal");
        (address token0, address token1) = COREIUniswapV2Library.sortTokens(tokenSwapping, tokenTarget);


        console.log("Transfering token", CERC95(tokenSwapping).name(), "To Uniswap");
        console.log("For amount", amtTokenSwappingInput);
        console.log("And I have", IERC20(tokenSwapping).balanceOf(address(this)), CERC95(tokenSwapping).name());
        IERC20(tokenSwapping).transfer(pair, amtTokenSwappingInput);

        console.log("Performing Uniswap swap from", CERC95(tokenSwapping).name(), " to ", CERC95(tokenTarget).name());
        console.log("Buying ", amtToken, "of", CERC95(tokenSwapping).name()); 
        if(tokenTarget == token0) {
             IUniswapV2Pair(pair).swap(amtToken, 0, address(this), "");
        }
        else {
            IUniswapV2Pair(pair).swap(0, amtToken, address(this), "");
        }

        if(tokenTarget == COREToken){
            emit COREBought(amtToken, msg.sender);
        }
        
        updateRunningAverages();
    }

    function updateRunningAverages() internal{
         if(_averagePrices[address(tokenBeingWrapped)].lastBlockOfIncrement != block.number) {
            _averagePrices[address(tokenBeingWrapped)].lastBlockOfIncrement = block.number;
            updateRunningAveragePrice(address(tokenBeingWrapped), false);
          }
         if(_averagePrices[COREToken].lastBlockOfIncrement != block.number) {
            _averagePrices[COREToken].lastBlockOfIncrement = block.number;
            updateRunningAveragePrice(COREToken, false);
         }
    }


    function coreETHPairGetter() public view returns (address) {
        return coreGlobals.COREWETHUniPair();
    }


    function getPairReserves(address pair) internal view returns (uint256 wethReserves, uint256 tokenReserves) {
        console.log("calling pair pair is :", pair);
        address token0 = IUniswapV2Pair(pair).token0();
        (uint256 reserve0, uint reserve1,) = IUniswapV2Pair(pair).getReserves();
        (wethReserves, tokenReserves) = token0 == _WETH ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function finalizeTokenWrapAddress(address _wrappedToken) onlyOwner public {
        wrappedToken = _wrappedToken;
    }

    // If LGE doesn't trigger in 24h after its complete its possible to withdraw tokens
    // Because then we can assume something went wrong since LGE is a publically callable function
    // And otherwise everything is stuck.
    function safetyTokenWithdraw(address token) onlyOwner public {
        require(block.timestamp > contractStartTimestamp.add(LGEDurationDays).add(1 days));
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }
    function safetyETHWithdraw() onlyOwner public {
        require(block.timestamp > contractStartTimestamp.add(LGEDurationDays).add(1 days));
        msg.sender.call.value(address(this).balance)("");
    }

    // Added safety function to extend LGE in case multisig #2 isn't avaiable from emergency life events
    // TODO x3 add your key here
    function extendLGE(uint numHours) public {
        require(msg.sender == 0xd5b47B80668840e7164C1D1d81aF8a9d9727B421 || msg.sender == 0xC91FE1ee441402D854B8F22F94Ddf66618169636, "LGE: Requires admin");
        require(numHours <= 24);
        LGEDurationDays = LGEDurationDays.add(numHours.mul(1 hours));
    }

    function addLiquidityAtomic() public {
        console.log(" > LGE.sol::addLiquidityAtomic()");
        require(LGEStarted == true, "LGE Didn't start");
        require(LGEFinished == false, "LGE : Liquidity generation finished");
        require(isLGEOver() == false, "LGE is over.");

        // require(token == _WETH || token == COREToken || token == address(tokenBeingWrapped) || token == preWrapEthPair, "Unsupported deposit token");

        if(IUniswapV2Pair(preWrapEthPair).balanceOf(address(this)) > 0) {
            // Special carveout because unwrap calls this funciton
            // Since unwrap will add both WETH and tokenwrapped
            unwrapLiquidityTokens();
        } else{
            ( uint256 tokenBeingWrappedPer1ETH, uint256 coreTokenPer1ETH) = getHowMuch1WETHBuysOfTokens();


             // Check WETH if there is swap for CORRE or WBTC depending
             // Check WBTC and swap for core or not depending on peg
            uint256 balWETH = IERC20(_WETH).balanceOf(address(this));
            // No need to upate it because we dont retain WETH

            uint256 totalCredit; // In core units

 

            // Handling core wrap deposits
            // we check change from reserves
            uint256 tokenBeingWrappedBalNow = IERC20(tokenBeingWrapped).balanceOf(address(this));
            uint256 tokenBeingWrappedBalChange = tokenBeingWrappedBalNow.sub(wrappedTokenBalance);
            // If its bigger than 0 we handle
            if(tokenBeingWrappedBalChange > 0) {
                totalWrapTokenContributed = totalWrapTokenContributed.add(tokenBeingWrappedBalChange);
      
                // We add wrapped token contributionsto the person this is for stats only
                wrappedTokenContributed[msg.sender] = wrappedTokenContributed[msg.sender].add(tokenBeingWrappedBalChange);
                // We check how much credit he got that returns from this function
                totalCredit =   handleTokenBeingWrappedLiquidityAddition(tokenBeingWrappedBalChange,tokenBeingWrappedPer1ETH,coreTokenPer1ETH) ;
                // We update reserves
                wrappedTokenBalance = IERC20(tokenBeingWrapped).balanceOf(address(this));
                COREBalance = IERC20(COREToken).balanceOf(address(this)); /// CHANGE

           }           
           
             // Handling weth
            if(balWETH > 0){
                totalETHContributed = totalETHContributed.add(balWETH);
                totalCredit = totalCredit.add( handleWETHLiquidityAddition(balWETH,tokenBeingWrappedPer1ETH,coreTokenPer1ETH) );
                // No other number should be there since it just started a line above
                COREBalance = IERC20(COREToken).balanceOf(address(this)); /// CHANGE
            }

            // we check core balance against reserves
            // Note this is FoT token safe because we check balance of this 
            // And not accept user input
            uint256 COREBalNow = IERC20(COREToken).balanceOf(address(this));
            uint256 balCOREChange = COREBalNow.sub(COREBalance);
            if(balCOREChange > 0) {
                COREContributed[msg.sender] = COREContributed[msg.sender].add(balCOREChange);
                totalCOREContributed = totalCOREContributed.add(balCOREChange);
            }
            // Reset reserves
            COREBalance = COREBalNow;

            uint256 unitsChange = totalCredit.add(balCOREChange);
            // Gives people balances based on core units, if Core is contributed then we just append it to it without special logic
            unitsContributed[msg.sender] = unitsContributed[msg.sender].add(unitsChange);
            totalUnitsContributed = totalUnitsContributed.add(unitsChange);
            emit Contibution(totalCredit, msg.sender);
        
        }
    }

    function handleTokenBeingWrappedLiquidityAddition(uint256 amt,uint256 tokenBeingWrappedPer1ETH,uint256 coreTokenPer1ETH) internal  returns (uint256 coreUnitsCredit) {
        // VERY IMPRECISE TODO
        uint256 outWETH;
        (uint256 reserveWETHofWrappedTokenPair, uint256 reserveTokenofWrappedTokenPair) = getPairReserves(preWrapEthPair);

        if(COREBalance.div(coreTokenPer1ETH) <= wrappedTokenBalance.div(tokenBeingWrappedPer1ETH)) {
            // swap for eth
            outWETH = COREIUniswapV2Library.getAmountOut(amt, reserveTokenofWrappedTokenPair, reserveWETHofWrappedTokenPair);
            console.log("I got a wrapped token deposit, figuring out how much ETH i get for ",amt,"of it - its", outWETH);
            console.log("Pair reserves of wrapped token are : wrapped token - ",reserveTokenofWrappedTokenPair, "and weth -", reserveWETHofWrappedTokenPair);
            buyToken(_WETH, outWETH, address(tokenBeingWrapped) , amt, preWrapEthPair);
            // buy core
            (uint256 buyReserveWeth, uint256 reserveCore) = getPairReserves(coreEthPair);
            uint256 outCore = COREIUniswapV2Library.getAmountOut(outWETH, buyReserveWeth, reserveCore);
            buyToken(COREToken, outCore, _WETH ,outWETH,coreEthPair);
        } else {
            // Dont swap just calculate out and credit and leave as is
            outWETH = COREIUniswapV2Library.getAmountOut(amt, reserveTokenofWrappedTokenPair , reserveWETHofWrappedTokenPair);
        }

        // Out weth is in 2 branches
        // We give credit to user contributing
        coreUnitsCredit = outWETH.mul(coreTokenPer1ETH).div(1e18);
    }

    function handleWETHLiquidityAddition(uint256 amt,uint256 tokenBeingWrappedPer1ETH,uint256 coreTokenPer1ETH) internal returns (uint256 coreUnitsCredit) {
        // VERY IMPRECISE TODO

        // We check if corebalance in ETH is smaller than wrapped token balance in eth
        if(COREBalance.div(coreTokenPer1ETH) <= wrappedTokenBalance.div(tokenBeingWrappedPer1ETH)) {
            // If so we buy core
            (uint256 reserveWeth, uint256 reserveCore) = getPairReserves(coreEthPair);
            uint256 outCore = COREIUniswapV2Library.getAmountOut(amt, reserveWeth, reserveCore);
            //we buy core
            buyToken(COREToken, outCore,_WETH,amt, coreEthPair);

            // amt here is weth contributed
        } else {
            (uint256 reserveWeth, uint256 reserveToken) = getPairReserves(preWrapEthPair);
            uint256 outToken = COREIUniswapV2Library.getAmountOut(amt, reserveWeth, reserveToken);
            console.log("I'm trying to figure out hwo much of wrapped token to buy",outToken);
            // we buy wrappedtoken
            buyToken(address(tokenBeingWrapped), outToken,_WETH, amt,preWrapEthPair);
            wrappedTokenBalance = IERC20(tokenBeingWrapped).balanceOf(address(this));


           //We buy outToken of the wrapped token and add it here
            wrappedTokenContributed[msg.sender] = wrappedTokenContributed[msg.sender].add(outToken);
        }
        // we credit user for ETH/ multiplied per core per 1 eth and then divided by 1 weth meaning we get exactly how much core it would be
        // in the running average
        coreUnitsCredit = amt.mul(coreTokenPer1ETH).div(1e18);

    }



    function getHowMuch1WETHBuysOfTokens() public view returns (uint256 tokenBeingWrappedPer1ETH, uint256 coreTokenPer1ETH) {
        return (getAveragePriceLast20Blocks(address(tokenBeingWrapped)), getAveragePriceLast20Blocks(COREToken));
    }


    //TEST TASK : Check if liquidity is added via just ending ETH to contract
    fallback() external payable {
        console.log("hit fallback");
        if(msg.sender != _WETH) {
             addLiquidityETH();
        }
    }

    //TEST TASK : Check if liquidity is added via calling this function
    function addLiquidityETH() nonReentrant public payable {
        console.log(" > LGE.sol::addLiquidityETH() nonReentrant public payable");
        // wrap weth
        console.log("Depositing ETH of value", msg.value);
        console.log("WETH address in liq addition", _WETH);
        IWETH(_WETH).deposit{value: msg.value}();
        console.log("Depsosited WETH");
        addLiquidityAtomic();
    }

    // TEST TASK : check if this function deposits tokens
    function addLiquidityWithTokenWithAllowance(address token, uint256 amount) public nonReentrant {
        console.log(" > LGE.sol::addLiquidityWithTokenWithAllowance(address token, uint256 amount) public nonReentrant");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        addLiquidityAtomic();
    }   

    // We burn liquiidyt from WBTC/ETH pair
    // And then send it to this ontract
    // Wrap atomic will handle both deposits of WETH and wrappedtoken
    function unwrapLiquidityTokens() internal {
        console.log(" > LGE.sol::unwrapLiquidityTokens() internal");
        IUniswapV2Pair pair = IUniswapV2Pair(preWrapEthPair);
        pair.transfer(preWrapEthPair, pair.balanceOf(address(this)));
        pair.burn(address(this));
        addLiquidityAtomic();
    }



    // TODO

    mapping(address => PriceAverage) _averagePrices;
    struct PriceAverage{
       uint8 lastAddedHead;
       uint256[20] price;
       uint256 cumulativeLast20Blocks;
       bool arrayFull;
       uint lastBlockOfIncrement; // Just update once per block ( by buy token function )
    }

    // This is out tokens per 1WETH (1e18 units)
    function getAveragePriceLast20Blocks(address token) public view returns (uint256){
        console.log("Inside view average price last head is ", _averagePrices[token].lastAddedHead);
        console.log("Inside view average price token is ", token, CERC95(token).name());
        console.log("Inside view average cumulative is ", _averagePrices[token].cumulativeLast20Blocks);
        console.log("Inside view average last block is is ", _averagePrices[token].lastBlockOfIncrement);

       return _averagePrices[token].cumulativeLast20Blocks.div(_averagePrices[token].arrayFull ? 20 : _averagePrices[token].lastAddedHead);
       // We check if the "array is full" because 20 writes might not have happened yet
       // And therefor the average would be skewed by dividing it by 20
    }


    // NOTE outTokenFor1WETH < lastQuote.mul(150).div(100) check
    function updateRunningAveragePrice(address token, bool isRescue) public returns (uint256) {
        console.log("Incrementing average of address", CERC95(token).name());
        PriceAverage storage currentAveragePrices =  _averagePrices[token];
        address pairWithWETH = pairWithWETHAddressForToken[token];
        (uint256 wethReserves, uint256 tokenReserves) = getPairReserves(address(pairWithWETH));
        // Get amt you would get for 1eth
        uint256 outTokenFor1WETH = COREIUniswapV2Library.getAmountOut(1e18, wethReserves, tokenReserves);

        uint8 i = currentAveragePrices.lastAddedHead;
        
        ////////////////////
        /// flash loan safety
        //we check the last quote for comparing to this one
        uint256 lastQuote;
        if(i == 0) {
            lastQuote = currentAveragePrices.price[19];
        }
        else {
            lastQuote = currentAveragePrices.price[i - 1];
        }
        console.log("Last average is ", lastQuote);
        console.log("Current Price is ", outTokenFor1WETH);

        // Safety flash loan revert
        // If change is above 50%
        // This can be rescued by the bool "isRescue"
        if(lastQuote != 0 && isRescue == false){
            require(outTokenFor1WETH < lastQuote.mul(15000).div(10000), "Change too big from previous price");
        }
        ////////////////////
        
        currentAveragePrices.cumulativeLast20Blocks = currentAveragePrices.cumulativeLast20Blocks.sub(currentAveragePrices.price[i]);
        currentAveragePrices.price[i] = outTokenFor1WETH;
        currentAveragePrices.cumulativeLast20Blocks = currentAveragePrices.cumulativeLast20Blocks.add(outTokenFor1WETH);
        currentAveragePrices.lastAddedHead++;
        if(currentAveragePrices.lastAddedHead > 19) {
            currentAveragePrices.lastAddedHead = 0;
            currentAveragePrices.arrayFull = true;
        }
        return currentAveragePrices.cumulativeLast20Blocks;
    }

    // Because its possible that price of someting legitimately goes +50%
    // Then the updateRunningAveragePrice would be stuck until it goes down,
    // This allows the admin to "rescue" it by writing a new average
    // skiping the +50% check
    function rescueRatioLock(address token) public onlyOwner{
        updateRunningAveragePrice(token, true);
    }



    // Protect form people atomically calling for LGE generation [x]
    // Price manipulation protections
    // use TWAP [x] custom 20 blocks
    // Set max diviation from last trade - not needed [ ]
    // re-entrancy protection [x]
    // dev tax [x]
    function addLiquidityToPairPublic() nonReentrant public{
        addLiquidityToPair(true,0,0);
    }

    // 1000 finey in 1 eth
    function getUnitsContributedPerFenny(uint256 amt) internal pure returns (uint256 units){
        // Counted at 14ETH/CORE which is one of the best rates
        //109.64791 ETH is 109647 fenny and shoul dbe around 7.83CORE
        // times 1e18 is 1.09647e+23
        // divided by 14000 ( 1000 for finney times 14 for price)
        // gives us 7831928571428571000 which is 7.83 ... in CORE units
        units = amt.mul(1e18).div(14000);
    }

    bool public LPmismatchCredited;
    function matchCreditFromLPContributionBug() public {
        require(LPmismatchCredited == false , "Already refunded");
        // Values in ETH are half of the value of LP token at the moment of contribution
        // 30 transactions in total
        //1) https://etherscan.io/tx/0xc98284112b627a2187156faaaff860238ebd0934f560871849dd946fd8f52975
        // 15.21958 ETH
        addUnitsContributed(0x6996C784cdA7a2841C3a6F579C896477586A1D9A, 15_219);
        //2) https://etherscan.io/tx/0xb721c3f2b0766ee8b8e80c5fd383fb024309b32c1620401a41c46639682a6fed
        //7.280364ETH
        addUnitsContributed(0x38Bc5196d8b21782372a843E5A505d9F457e6ff8, 7_280);
        //3) https://etherscan.io/tx/0x54c7e90b302e92f14949958394b95b8550273b65917f2de72e62dc2ed5e9fe9c
        //0.249332ETH
        addUnitsContributed(0x91a90ACd8791ABB4c07c69aBBca82822c3451584, 249);
        //4) https://etherscan.io/tx/0x5ca6470a79aa015cf8dd877f51c757e71ae12bd4fd74a1d02e5ad7d6c426afe4
        //109.64791 ETH
        addUnitsContributed(0x4523b791292da89A9194B61bA4CD9d98f2af68E0, 109_647);
        //5) https://etherscan.io/tx/0x9de3e90e1f02c2f069859ba0616c57e0d4e07e074a4348455e3a26dfd91b39cc
        //0.1511757ETH
        addUnitsContributed(0xD2FA59811af055e0e94D570EA7F9800c0E5C0428, 151);
        //6) https://etherscan.io/tx/0xafd98d37c98a663faee7c850acc99d8cab9dd38125cba1faeb36a8b278ca9805
        //0.2204769ETH
        addUnitsContributed(0xeeBa4a8f5b27D7d7c91cF4D4A716FbA042850f9A, 220);
        //7) https://etherscan.io/tx/0xe41f8073be1026910df96dc734882aeca6cbc27170c6fee76249810096aed102
        //11.99914ETH
        addUnitsContributed(0x2eACd09e92273D5fb86Cf40504917F664EE15Da8, 11_999);
        //8) https://etherscan.io/tx/0xf9576b52ebf9344f2fdb03dcbe02efdd447ee5b2f7de246a5a48f48358f3875b
        //0.289062357ETH
        addUnitsContributed(0xbbAb2ca3dF54726D3F484aFFf85708C0075a4400, 289);
        //9) https://etherscan.io/tx/0x26a32da8579121351c4476ec5bc1a18dddca6867fa59a4ad4b91872f648a00c9
        //123.992301ETH
        addUnitsContributed(0xC8D76B1Ae76bdE393ef4CD495502D18326623ec5, 123_992);
        //10) https://etherscan.io/tx/0xaa4348ce279a3282cafd69ea2d42533d14fe5bd5c5bddab8f51487a77472c907
        //1.39978401ETH
        addUnitsContributed(0x882E11F884E9d221706DB9A36bA4856292b26d87, 1_399);
        //11) https://etherscan.io/tx/0x0c82f065e054a6c0914f37853bac76bb601a04a5d3d6215e218a96d1c90bc733
        //0.25052733ETH
        addUnitsContributed(0xb0e7C2319993C00B9430d18bDd9f98Fefb6B5857, 250);
        //12) https://etherscan.io/tx/0xcc62b3df51d3e29ede693706fc3bbac3d713f3332dda0782d3e425c48decc271
        //1.147797ETH
        addUnitsContributed(0x41AFc9c6414FE7C4AbBc9977B07E5C5e62F7938A ,1_147);
        //13) https://etherscan.io/tx/0x24235a4894ada1dabb3929a4e5deaf77dd599b76d36cb0f42a91257eeb19e6d3
        //5.129589455ETH
        addUnitsContributed(0x3E4D97C22571C5Ff22f0DAaBDa2d3835E67738EB, 5_129);
        //14) https://etherscan.io/tx/0xcd0d52f92257e360482799ed9a502c703d979d8ede7979bfb514a9304853c360
        //2.0568510ETH
        addUnitsContributed(0x5924544A57e26b52231597aaa5E0374748C0a127, 2_056);
        //15) https://etherscan.io/tx/0x0f8a9f142c4ffd8ad585a14b260c5040d2c6dc1d4bb47cf94720be420238d220
        //4.9843880ETH
        addUnitsContributed(0xa26f824aE181cD3893D77D0ACd2Fb7afc225e07e, 4_984);
        //16) https://etherscan.io/tx/0x570fe1ca7d5baf0c8a772ee28a6d7e4a65bf3391961f3ad650b22e83a543629b
        //9.645344991ETH
        addUnitsContributed(0x821fC6A963b94920c57966A31BA1cF9b7569Dd30, 9_645);
        //17) https://etherscan.io/tx/0x6933e20bdca0b8dfad169bdaa7d79194c8cc2f1eb783b79acfa5183ecd16efd7
        //0.299104ETH
        addUnitsContributed(0x09cC473b67696F31A8536D43C7CF4B32Ade588C8, 299);
        //18) https://etherscan.io/tx/0x49d37f9a25ff53a301927a0ddcded0e3ccc0c8c1eb7abf84cb99d2ddee5e0a6d
        //0.2683990359ETH
        addUnitsContributed(0x67593A4F0c1e290eaE66459eE160A82945a5886f, 268);
        //19) https://etherscan.io/tx/0x19c1861853e2cd9a5ad6fec6910215f63b39a1d824c1b862ffab5a6d12a82733
        //1.0975376ETH
        addUnitsContributed(0x2aCFd4D5EBbC9803Ee5B6BA190BA41B8b3e6A29d, 1_097);
        //20) https://etherscan.io/tx/0xe29887b6f27a9e98610f73544d750a4f9219378da25c7228b14f2f757efc0798
        //7.64413238ETH
        addUnitsContributed(0xEd037d27846A6a7943B7b33AeBA526cd95Bd95Ce, 7_644);
        //21) https://etherscan.io/tx/0xbbb03e0258f0d2df9123ae2587ab22ef4f62bc55d0ab1ca91ea5092480666fc6
        //0.86045ETH
        addUnitsContributed(0xe39Bc99b80a9EFD0F14F82AEA1406Eee93D456F2, 860);
        //22) https://etherscan.io/tx/0x53735a0f31f37d8e9927998ac4548546b365a285736d9665bc851479b9cc8f90
        //0.092910ETH
        addUnitsContributed(0xA467b35b756359F55BC26bA82BAfA83B9Fb720Ed, 92);
        //23) https://etherscan.io/tx/0xa622ff0e0a0dfc194bcc5fc3a590cafb5a891289c889e2e712b10b3717d23110
        //8.973076534
        addUnitsContributed(0x8261F215B09F6595A66C251625c24b6F52857195, 8_973);
        //24) https://etherscan.io/tx/0xc9f36aba09bbd3fedf3f5e3f861c8616aceda619e82fcaf7a74792872be15747
        // 27.95852ETH
        addUnitsContributed(0x3D3C3EEAc517B72670DB36cb7380cd18B929430b, 27_958);
        //25) https://etherscan.io/tx/0x0892c57752316d222430e1096ff17c68c4dcee49fcc4b27ffae82841295c88f6
        //0.036792ETH
        addUnitsContributed(0x27f5EB564BAEDb169C0c2d3a5ea1d25281D9a5e5, 36);
        //26) https://etherscan.io/tx/0x76cb986eaf3213ea6127950b791660795f2b4666e3d9d33b7dc38c1945992195
        //3.865313825ETH
        addUnitsContributed(0x473bbC06D7fdB7713D1ED334F8D8096CaD6eC3f3, 3_865);
        //27) https://etherscan.io/tx/0x7b41f44ad43f82c5707e05566113bb2614b274a0644aea7f6a3e095b819f9366
        //0.120902ETH
        addUnitsContributed(0x11ef72795691570b28277043d344D969f749A837, 120);
        //28) https://etherscan.io/tx/0x61fe2706a03fb152f4713466cefc0dbc60e7ccf695426c5916faf1b94522cabd
        //1.2530218ETH
        addUnitsContributed(0x2836cFCc14d89Ccf0B0a980e5605f24Fa0A4a735, 1_253);
        //29) https://etherscan.io/tx/0x3e94390de1bc53bee0f9dc8a0af5d66f567d82b21dd1355783a495022af16ca8/
        //0.499988ETH
        addUnitsContributed(0x83d371D26FE57a17849F87B14717fbAd7C6B82A5, 499);
        //30) https://etherscan.io/tx/0xbacad42784b3f16bf7da601db7d83a40b4756076b2daaa7588cae1afbafc55c9/
        //0.9410832ETH
        addUnitsContributed(0xf172ee7B2b94b70f975E98E25044F82E6C29f996, 941);

        LPmismatchCredited = true;
    }

    function addUnitsContributed(address guy, uint256 amtFenny) internal {
        unitsContributed[guy] = unitsContributed[guy].add(getUnitsContributedPerFenny(amtFenny));
        totalUnitsContributed = totalUnitsContributed.add(getUnitsContributedPerFenny(amtFenny));
    }

    // Safety function that can call public add liquidity before
    // This is in case someone manipulates the 20 liquidity addition blocks 
    // and screws up the ratio
    // Allows admins 2 hours to rescue the contract.
    function addLiquidityToPairAdmin(uint256 ratio1ETHWholeBuysXCOREUnits, uint256 ratio1ETHWholeBuysXWrappedTokenUnits)
         nonReentrant onlyOwner public{
        addLiquidityToPair(false,ratio1ETHWholeBuysXCOREUnits, ratio1ETHWholeBuysXWrappedTokenUnits);
    }
    
    function getCORERefundForPerson(address guy) public view returns (uint256) {
        return COREContributed[guy].mul(1e12).div(totalCOREContributed).
            mul(totalCOREToRefund).div(1e12);
    }
    
    function getCOREREfund() nonReentrant public {
        require(LGEFinished == true, "LGE not finished");
        require(totalCOREToRefund > 0 , "No refunds");
        require(COREContributed[msg.sender] > 0, "You didn't contribute anything");
        // refund happens just once
        require(CORERefundClaimed[msg.sender] == false , "You already claimed");
        
        // To get refund we get the core contributed of this user
        // divide it by total core to get the percentage of total this user contributed
        // And then multiply that by total core
        uint256 COREToRefundToThisPerson = getCORERefundForPerson(msg.sender);
        // Let 50% of total core is refunded, total core contributed is 5000
        // So refund amount it 2500
        // Lets say this user contributed 100, so he needs to get 50 back
        // 100*1e12 = 100000000000000
        // 100000000000000/5000 is 20000000000
        // 20000000000*2500 is 50000000000000
        // 50000000000000/1e21 = 50
        CORERefundClaimed[msg.sender] = true;
        IERC20(COREToken).transfer(msg.sender,COREToRefundToThisPerson);
    }

    function notMoreThan4PercentDeltaFromCurrentPrice(address pair, uint256 amtOutPer1ETH) internal  {
        (uint256 reserveWETHofWrappedTokenPair, uint256 reserveTokenofWrappedTokenPair) = getPairReserves(preWrapEthPair);
        uint256 outTokenFor1WETH = COREIUniswapV2Library.getAmountOut(1e18, reserveWETHofWrappedTokenPair, reserveTokenofWrappedTokenPair);
        require(amtOutPer1ETH.mul(104) > outTokenFor1WETH.mul(100) 
                && outTokenFor1WETH.mul(100) <  amtOutPer1ETH.mul(96), 
                  "LGE : Delta of balances is too big from actual (4% or more)");
    }

    function addLiquidityToPair(bool publicCall, uint256 ratio1ETHWholeBuysXCOREUnits, uint256 ratio1ETHWholeBuysXWrappedTokenUnits)
     internal {
        require(block.timestamp > contractStartTimestamp.add(LGEDurationDays).add(publicCall ? 2 hours : 0), "LGE : Liquidity generation ongoing");
        require(LGEFinished == false, "LGE : Liquidity generation finished");
        
        // !!!!!!!!!!!
        //unlock wrapping
        IERC95(wrappedToken).unpauseTransfers();
        //!!!!!!!!!


        // // wrap token
        tokenBeingWrapped.transfer(wrappedToken, tokenBeingWrapped.balanceOf(address(this)));
        IERC95(wrappedToken).wrapAtomic(address(this));
        IERC95(wrappedToken).skim(address(this)); // In case

        // Optimistically get pair
        wrappedTokenUniswapPair = IUniswapV2Factory(coreGlobals.UniswapFactory()).getPair(COREToken , wrappedToken);
        if(wrappedTokenUniswapPair == address(0)) { // Pair doesn't exist yet 
            // create pair returns address
            wrappedTokenUniswapPair = IUniswapV2Factory(coreGlobals.UniswapFactory()).createPair(
                COREToken,
                wrappedToken
            );
        }

        //send dev fee
        // 7.24% 
        uint256 DEV_FEE = 724; // TODO: DEV_FEE isn't public //ICoreVault(coreGlobals.COREVault).DEV_FEE();
        address devaddress = ICoreVault(coreGlobals.COREVaultAddress()).devaddr();
        IERC95(wrappedToken).transfer(devaddress, IERC95(wrappedToken).balanceOf(address(this)).mul(DEV_FEE).div(10000));
        IERC20(COREToken).transfer(devaddress, IERC20(COREToken).balanceOf(address(this)).mul(DEV_FEE).div(10000));

        //calculate core refund
        uint256 balanceCORENow = IERC20(COREToken).balanceOf(address(this));
        uint256 balanceCOREWrappedTokenNow = IERC95(wrappedToken).balanceOf(address(this));

        ( uint256 tokenBeingWrappedPer1ETH, uint256 coreTokenPer1ETH)  = getHowMuch1WETHBuysOfTokens();

 

        if(publicCall == false){ // admin added ratio
            
            notMoreThan4PercentDeltaFromCurrentPrice(preWrapEthPair, ratio1ETHWholeBuysXWrappedTokenUnits);
            notMoreThan4PercentDeltaFromCurrentPrice(coreEthPair, ratio1ETHWholeBuysXCOREUnits);

            uint256 totalValueOfWrapper = balanceCOREWrappedTokenNow.div(ratio1ETHWholeBuysXWrappedTokenUnits).mul(1e18);
            uint256 totalValueOfCORE =  balanceCORENow.div(ratio1ETHWholeBuysXCOREUnits).mul(1e18);

            totalCOREToRefund = totalValueOfWrapper >= totalValueOfCORE ? 0 :
                totalValueOfCORE.sub(totalValueOfWrapper).mul(coreTokenPer1ETH).div(1e18);

        }else{
            notMoreThan4PercentDeltaFromCurrentPrice(preWrapEthPair, tokenBeingWrappedPer1ETH);
            notMoreThan4PercentDeltaFromCurrentPrice(coreEthPair, coreTokenPer1ETH);

            uint256 totalValueOfWrapper = balanceCOREWrappedTokenNow.div(tokenBeingWrappedPer1ETH).mul(1e18);
            uint256 totalValueOfCORE =  balanceCORENow.div(coreTokenPer1ETH).mul(1e18);

            totalCOREToRefund = totalValueOfWrapper >= totalValueOfCORE ? 0 :
                totalValueOfCORE.sub(totalValueOfWrapper).mul(coreTokenPer1ETH).div(1e18);
        }
  


        // send tokenwrap
        IERC95(wrappedToken).transfer(wrappedTokenUniswapPair, IERC95(wrappedToken).balanceOf(address(this)));

        // send core without the refund
        IERC20(COREToken).transfer(wrappedTokenUniswapPair, balanceCORENow.sub(totalCOREToRefund));

        require(IUniswapV2Pair(wrappedTokenUniswapPair).totalSupply() == 0, "Somehow total supply is higher, sanity fail");
        // mint LP to this adddress
        IUniswapV2Pair(wrappedTokenUniswapPair).mint(address(this));

        // check how much was minted
        totalLPCreated = IUniswapV2Pair(wrappedTokenUniswapPair).balanceOf(address(this));

        // calculate minted per contribution
        LPPerUnitContributed = totalLPCreated.mul(1e18).div(totalUnitsContributed.sub(totalCOREToRefund)); // Stored as 1e18 more for round erorrs and change
                                                                               // Remove refunded from the total
        require(LPPerUnitContributed > 0, "LP Per Unit Contribute Must be above Zero");
        // set LGE to complete
        LGEFinished = true;

        //sync the tokens
        ICORETransferHandler(coreGlobals.TransferHandler()).sync(wrappedTokenUniswapPair);
        ICORETransferHandler(coreGlobals.TransferHandler()).sync(coreEthPair);

    }
    


    
}
