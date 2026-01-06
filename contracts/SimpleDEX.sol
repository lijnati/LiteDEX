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

abstract contract ERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    error ERC20InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed
    );
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );
    error ERC20InvalidReceiver(address receiver);
    error ERC20InvalidSpender(address spender);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ERC20InvalidReceiver(address(0));

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount)
            revert ERC20InsufficientBalance(from, fromBalance, amount);

        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        if (account == address(0)) revert ERC20InvalidReceiver(address(0));

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }

        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        uint256 accountBalance = _balances[account];
        if (accountBalance < amount)
            revert ERC20InsufficientBalance(account, accountBalance, amount);

        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        if (spender == address(0)) revert ERC20InvalidSpender(address(0));

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount)
                revert ERC20InsufficientAllowance(
                    spender,
                    currentAllowance,
                    amount
                );
            unchecked {
                _allowances[owner][spender] = currentAllowance - amount;
            }
        }
    }
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

contract SimpleDEX is ERC20, ReentrancyGuard {
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public constant FEE_NUMERATOR = 3;
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint32 public blockTimestampLast;

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

    constructor(
        address _tokenA,
        address _tokenB,
        string memory _lpName,
        string memory _lpSymbol
    ) ERC20(_lpName, _lpSymbol) {
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

        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            lpMinted = _sqrt(amountA * amountB);

            if (lpMinted <= MINIMUM_LIQUIDITY)
                revert InsufficientInitialLiquidity();
            lpMinted -= MINIMUM_LIQUIDITY;

            _mint(address(0xdead), MINIMUM_LIQUIDITY);
        } else {
            uint256 lpFromA = (amountA * _totalSupply) / reserveA;
            uint256 lpFromB = (amountB * _totalSupply) / reserveB;
            lpMinted = lpFromA < lpFromB ? lpFromA : lpFromB;
        }

        if (lpMinted == 0) revert InsufficientLiquidity();

        _mint(msg.sender, lpMinted);

        reserveA += amountA;
        reserveB += amountB;

        _update(reserveA, reserveB);

        emit LiquidityAdded(msg.sender, amountA, amountB, lpMinted);
        emit Sync(reserveA, reserveB);
    }

    function removeLiquidity(
        uint256 lpAmount
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        if (lpAmount == 0) revert ZeroAmount();
        if (balanceOf(msg.sender) < lpAmount) revert InsufficientLPBalance();

        uint256 _totalSupply = totalSupply();

        amountA = (lpAmount * reserveA) / _totalSupply;
        amountB = (lpAmount * reserveB) / _totalSupply;

        if (amountA == 0 || amountB == 0) revert InsufficientLiquidity();

        _burn(msg.sender, lpAmount);

        reserveA -= amountA;
        reserveB -= amountB;

        _safeTransfer(tokenA, msg.sender, amountA);
        _safeTransfer(tokenB, msg.sender, amountB);

        _update(reserveA, reserveB);

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

        _update(reserveA, reserveB);

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

    function getPriceAinB() external view returns (uint256 price) {
        if (reserveA == 0) return 0;
        return (reserveB * 1e18) / reserveA;
    }

    function getPriceBinA() external view returns (uint256 price) {
        if (reserveB == 0) return 0;
        return (reserveA * 1e18) / reserveB;
    }

    function _update(uint256 _reserveA, uint256 _reserveB) internal {
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast;
        }

        if (timeElapsed > 0 && _reserveA != 0 && _reserveB != 0) {
            // Price of A in B: reserveB / reserveA
            // Price of B in A: reserveA / reserveB
            // We use 1e18 for precision
            price0CumulativeLast +=
                ((_reserveB * 1e18) / _reserveA) *
                timeElapsed;
            price1CumulativeLast +=
                ((_reserveA * 1e18) / _reserveB) *
                timeElapsed;
        }
        blockTimestampLast = blockTimestamp;
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
