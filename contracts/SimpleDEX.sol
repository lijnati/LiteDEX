// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract SimpleDEX is ReentrancyGuard {
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public totalLPSupply;
    mapping(address => uint256) public lpBalances;

    uint256 public constant FEE_NUMERATOR = 3;
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    event LiquidityAdded(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 lpMinted
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 lpBurned
    );

    event Swap(
        address indexed trader,
        address indexed tokenIn,
        uint256 amountIn,
        address indexed tokenOut,
        uint256 amountOut
    );

    event Sync(uint256 reserveA, uint256 reserveB);

    error ZeroAmount();
    error ZeroAddress();
    error InsufficientLiquidity();
    error InsufficientLPBalance();
    error InsufficientOutputAmount();
    error InvalidToken();
    error TransferFailed();
    error InsufficientInitialLiquidity();
    error InvalidK();

    constructor(address _tokenA, address _tokenB) {
        if (_tokenA == address(0) || _tokenB == address(0))
            revert ZeroAddress();
        if (_tokenA == _tokenB) revert InvalidToken();

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant returns (uint256 lpMinted) {
        if (amountA == 0 || amountB == 0) revert ZeroAmount();

        _safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        _safeTransferFrom(tokenB, msg.sender, address(this), amountB);

        if (totalLPSupply == 0) {
            lpMinted = _sqrt(amountA * amountB);

            if (lpMinted <= MINIMUM_LIQUIDITY)
                revert InsufficientInitialLiquidity();
            lpMinted -= MINIMUM_LIQUIDITY;

            totalLPSupply = MINIMUM_LIQUIDITY;
        } else {
            uint256 lpFromA = (amountA * totalLPSupply) / reserveA;
            uint256 lpFromB = (amountB * totalLPSupply) / reserveB;
            lpMinted = lpFromA < lpFromB ? lpFromA : lpFromB;
        }

        if (lpMinted == 0) revert InsufficientLiquidity();

        lpBalances[msg.sender] += lpMinted;
        totalLPSupply += lpMinted;

        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB, lpMinted);
        emit Sync(reserveA, reserveB);
    }

    function removeLiquidity(
        uint256 lpAmount
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        if (lpAmount == 0) revert ZeroAmount();
        if (lpBalances[msg.sender] < lpAmount) revert InsufficientLPBalance();

        amountA = (lpAmount * reserveA) / totalLPSupply;
        amountB = (lpAmount * reserveB) / totalLPSupply;

        if (amountA == 0 || amountB == 0) revert InsufficientLiquidity();

        lpBalances[msg.sender] -= lpAmount;
        totalLPSupply -= lpAmount;

        reserveA -= amountA;
        reserveB -= amountB;

        _safeTransfer(tokenA, msg.sender, amountA);
        _safeTransfer(tokenB, msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);
        emit Sync(reserveA, reserveB);
    }

    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn != address(tokenA) && tokenIn != address(tokenB))
            revert InvalidToken();

        bool isTokenA = tokenIn == address(tokenA);

        (
            IERC20 inputToken,
            IERC20 outputToken,
            uint256 reserveIn,
            uint256 reserveOut
        ) = isTokenA
                ? (tokenA, tokenB, reserveA, reserveB)
                : (tokenB, tokenA, reserveB, reserveA);

        _safeTransferFrom(inputToken, msg.sender, address(this), amountIn);

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR);
        amountOut =
            (amountInWithFee * reserveOut) /
            (reserveIn * FEE_DENOMINATOR + amountInWithFee);

        if (amountOut == 0) revert InsufficientOutputAmount();
        if (amountOut < minAmountOut) revert InsufficientOutputAmount();
        if (amountOut >= reserveOut) revert InsufficientLiquidity();

        if (isTokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        uint256 newK = reserveA * reserveB;
        uint256 oldK = (isTokenA ? reserveA - amountIn : reserveA + amountOut) *
            (isTokenA ? reserveB + amountOut : reserveB - amountIn);
        if (newK < oldK) revert InvalidK();

        _safeTransfer(outputToken, msg.sender, amountOut);

        emit Swap(
            msg.sender,
            tokenIn,
            amountIn,
            address(outputToken),
            amountOut
        );
        emit Sync(reserveA, reserveB);
    }

    function getAmountOut(
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        if (amountIn == 0) return 0;
        if (tokenIn != address(tokenA) && tokenIn != address(tokenB)) return 0;

        bool isTokenA = tokenIn == address(tokenA);
        uint256 reserveIn = isTokenA ? reserveA : reserveB;
        uint256 reserveOut = isTokenA ? reserveB : reserveA;

        if (reserveIn == 0 || reserveOut == 0) return 0;

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR);
        amountOut =
            (amountInWithFee * reserveOut) /
            (reserveIn * FEE_DENOMINATOR + amountInWithFee);
    }

    function getReserves()
        external
        view
        returns (uint256 _reserveA, uint256 _reserveB)
    {
        return (reserveA, reserveB);
    }

    function getLPBalance(address account) external view returns (uint256) {
        return lpBalances[account];
    }

    function getPriceAinB() external view returns (uint256 price) {
        if (reserveA == 0) return 0;
        return (reserveB * 1e18) / reserveA;
    }

    function getPriceBinA() external view returns (uint256 price) {
        if (reserveB == 0) return 0;
        return (reserveA * 1e18) / reserveB;
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
