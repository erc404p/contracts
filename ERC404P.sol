//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DoubleEndedQueue} from "./lib/DoubleEndedQueue.sol";
import {Strings} from "./lib/Strings.sol";

interface IP404 {
    /**
        transform ERC20 to ERC721 or ERC721 to ERC20
        @param _tokenOrAmount ERC20 token address or ERC721 token id
     */
    function transform(uint256 _tokenOrAmount) external;
}   

contract Ownable {
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    error Unauthorized();
    error InvalidOwner();

    address public owner;

    modifier onlyOwner() virtual {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address _owner) public virtual onlyOwner {
        if (_owner == address(0)) revert InvalidOwner();
        owner = _owner;
        emit OwnershipTransferred(msg.sender, _owner);
    }

}

abstract contract ERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721Receiver.onERC721Received.selector;
    }
}

interface Render {
    function render(uint256 tokenId) external view returns (string memory);
}

 contract ERC404 is Ownable,  ERC721Receiver{
    using Strings for uint256;
    using DoubleEndedQueue for DoubleEndedQueue.Uint256Deque;
    DoubleEndedQueue.Uint256Deque private _storedERC721Ids;

    uint256 public constant MAX_NFTS = 10000;
    uint256 public constant MAX_TOKENS = 100000000 * 10 ** 18;
    // Events
    event ERC20Transfer(
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event ERC721Approval(
        address indexed owner,
        address indexed spender,
        uint256 indexed id
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    // -------- for p404 --------
    mapping(address => bool) public swap;
    uint256 public constant SELL_TAX = 100; // 1%
    uint256 public constant MAX_ERC20_TOKENS = 100000000 * 10 ** 18;
    uint256 public constant TRANSFORM_PRICE = 10000 * 10 ** 18;
    uint256 public constant TRANSFORM_LOSE_RATE = 200; // 2%
    uint256 public constant MAX_NFT_MINT = 1500; // 2%
    uint256 public nftMinted;
    uint256 public mintPrice = 0.03 ether;
    address public feeTo;
    event FromTokenToNFT(address from,  uint256 amount);
    event FromNFTToToken(address from,  uint256 tokenId);
    event PayToMint(address from, uint256 price, uint256 tokenId);
    // -------- end of 404 --------

    // Errors
    error NotFound();
    error AlreadyExists();
    error InvalidSender();
    error UnsafeRecipient();

    // Metadata
    /// @dev Token name
    string public name;

    /// @dev Token symbol
    string public symbol;

    /// @dev Decimals for fractional representation
    uint8 public immutable decimals;

    /// @dev Total supply in fractionalized representation
    uint256 public totalSupply;

    /// @dev Current mint counter, monotonically increasing to ensure accurate ownership
    uint256 public minted;

    // Mappings
    /// @dev Balance of user in fractional representation
    mapping(address => uint256) public balanceOf;

    /// @dev Allowance of user in fractional representation
    mapping(address => mapping(address => uint256)) public allowance;

    /// @dev Approval in native representaion
    mapping(uint256 => address) public getApproved;

    /// @dev Approval for all in native representation
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// @dev Owner of id in native representation
    mapping(uint256 => address) internal _ownerOf;

    /// @dev Array of owned ids in native representation
    mapping(address => uint256[]) internal _owned;

    /// @dev Tracks indices for the _owned mapping
    mapping(uint256 => uint256) internal _ownedIndex;

    mapping(uint256 => bytes32) public mintHash;

    /// @dev Base URI f or tokenURI
    string public baseURI;

    // tokenURI render
    address public render;

    // Constructor
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        // totalSupply = 85000000 * (10 ** decimals);
        baseURI = "https://meta.metadragon.ai/?id=";
        _mintERC20(msg.sender, 85000000 * 10 ** 18);
        feeTo = msg.sender;
    }

    // setswap
    function setSwap(address _swap, bool _enable) public onlyOwner {
        swap[_swap] = _enable;
    }

    // setfeeto
    function setFeeTo(address _feeTo) public onlyOwner {
        feeTo = _feeTo;
    }

    // setbaseuri
    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    /// @notice Function to find owner of a given native token
    function ownerOf(uint256 id) public view virtual returns (address owner) {
        owner = _ownerOf[id];
    }

    /// @notice tokenURI must be implemented by child contract
    function tokenURI(uint256 id_) public view virtual returns (string memory) {
        if (render != address(0)) {
            return Render(render).render(id_);
        }
        return bytes(baseURI).length > 0 ? string.concat(baseURI, id_.toString()) : "";
    }

    /// @notice Function for token approvals
    /// @dev This function assumes id / native if amount less than or equal to current max id
    function approve(
        address spender,
        uint256 amountOrId
    ) public virtual returns (bool) {
        if (amountOrId <= minted && amountOrId > 0) {
            address owner = _ownerOf[amountOrId];

            if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) {
                revert Unauthorized();
            }

            getApproved[amountOrId] = spender;

            emit Approval(owner, spender, amountOrId);
        } else {
            allowance[msg.sender][spender] = amountOrId;

            emit Approval(msg.sender, spender, amountOrId);
        }

        return true;
    }

    /// @notice Function native approvals
    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Function for mixed transfers
    /// @dev This function assumes id / native if amount less than or equal to current max id
    function transferFrom(
        address from,
        address to,
        uint256 amountOrId
    ) public virtual {
        if (to == address(this)) {
            transform(amountOrId);
            return;
        }

        if (_isValidTokenId(amountOrId)) {
            if (from != _ownerOf[amountOrId]) {
                revert InvalidSender();
            }

            if (
                msg.sender != from &&
                !isApprovedForAll[from][msg.sender] &&
                msg.sender != getApproved[amountOrId]
            ) {
                revert Unauthorized();
            }

            _ownerOf[amountOrId] = to;
            delete getApproved[amountOrId];

            // update _owned for sender
            uint256 updatedId = _owned[from][_owned[from].length - 1];
            _owned[from][_ownedIndex[amountOrId]] = updatedId;
            // pop
            _owned[from].pop();
            // update index for the moved id
            _ownedIndex[updatedId] = _ownedIndex[amountOrId];
            // push token to to owned
            _owned[to].push(amountOrId);
            // update index for to owned
            _ownedIndex[amountOrId] = _owned[to].length - 1;

            emit Transfer(from, to, amountOrId);
        } else {
            uint256 allowed = allowance[from][msg.sender];

            if (allowed != type(uint256).max)
                allowance[from][msg.sender] = allowed - amountOrId;

            _transfer(from, to, amountOrId);
        }
    }

    /// @notice Function for fractional transfers
    function transfer(
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        if (to == address(this)) {
            transform(amount);
            return true;
        }
        return _transfer(msg.sender, to, amount);
    }

    /// @notice Function for native transfers with contract support
    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
            ERC721Receiver(to).onERC721Received(msg.sender, from, id, "") !=
            ERC721Receiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient();
        }
    }

    /// @notice Function for native transfers with contract support and callback data
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
            ERC721Receiver(to).onERC721Received(msg.sender, from, id, data) !=
            ERC721Receiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient();
        }
    }

    /// @notice Internal function for fractional transfers
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        // uint256 unit = _getUnit();
        // uint256 balanceBeforeSender = balanceOf[from];
        // uint256 balanceBeforeReceiver = balanceOf[to];
        balanceOf[from] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit ERC20Transfer(from, to, amount);
        return true;
    }

    // Internal utility logic
    function _getUnit() internal view returns (uint256) {
        return 10000 * 10 ** decimals;
    }


    function _withdrawAndStoreERC721(address from_, uint256 id) internal virtual {
        transferFrom(from_, address(0), id);
        _storedERC721Ids.pushFront(id);
    }

    function _retrieveOrMintERC721(address to_) internal virtual {
        
        uint256 id;
        if (!_storedERC721Ids.empty()) {
                id = _storedERC721Ids.popBack();
            } else {
                ++minted;
            if (minted == MAX_NFTS + 1) {
                revert();
            }
            id =  minted;
            // 如果没有mintHash，记录一下
            if (mintHash[id] == 0) {
                // 上一个区块的hash
                bytes32 lastHash = blockhash(block.number - 1);
                mintHash[id] = lastHash;
            }
        }
        address erc721Owner = ownerOf(id);
        if (erc721Owner != address(0)) {
            revert AlreadyExists();
        }

        _ownerOf[id] = to_;
        _owned[to_].push(id);
        _ownedIndex[id] = _owned[to_].length - 1;

        emit Transfer(address(0), to_, id);
    }

    function _isValidTokenId(uint256 id_) internal view returns (bool) {
        return id_ <= minted;
    }

    function transform(uint256 _tokenOrAmount) public  {
    if (_isValidTokenId(_tokenOrAmount)) {
      _erc721ToErc20(_tokenOrAmount);
    } else {
      _erc20ToErc721(_tokenOrAmount);
    }
  }

  function _erc20ToErc721(uint256 _amount) internal {
        // 销毁erc20，_totalSuppoly减少，增加nft
        require(balanceOf[msg.sender] >= _amount, "P404: insufficient balance");
        require(_amount >= TRANSFORM_PRICE, "P404: insufficient amount");

        uint256 nfts = _amount / TRANSFORM_PRICE;
        uint256 _realcost = nfts * TRANSFORM_PRICE;

        // 销毁_realcost
        _burnERC20(msg.sender, _realcost);
        for (uint256 i = 0; i < nfts; i++) {
            _retrieveOrMintERC721(msg.sender);
        }

        emit FromTokenToNFT(msg.sender, _amount);
    }

    function _erc721ToErc20(uint256 _tokenId) internal {
        require(ownerOf(_tokenId) == msg.sender, "P404: not owner");
        _withdrawAndStoreERC721(ownerOf(_tokenId), _tokenId);

        uint256 _amount = TRANSFORM_PRICE * (10000 - TRANSFORM_LOSE_RATE) / 10000;
        _mintERC20(msg.sender, _amount);

        uint256 _burnAmount = TRANSFORM_PRICE * TRANSFORM_LOSE_RATE / 10000;
        _mintERC20(address(0), _burnAmount);

        emit FromNFTToToken(msg.sender, _tokenId);
    }


    function _mintERC20(address to_, uint256 amount_) internal {
        require(totalSupply + amount_ <= MAX_TOKENS, "P404: total supply exceeds max supply");
        balanceOf[to_] += amount_;
        totalSupply += amount_;
        emit ERC20Transfer(address(0), to_, amount_);
    }

    function _burnERC20(address from_, uint256 amount_) internal {
        require(balanceOf[from_] >= amount_, "P404: insufficient balance");
        balanceOf[from_] -= amount_;
        totalSupply -= amount_;
        emit ERC20Transfer(from_, address(0), amount_);
    }

    receive () external payable {
        // 接收姨太并发放NFT，最多发放1500个NFT
        require(msg.value >= mintPrice, "P404: invalid price");
        require(msg.sender == tx.origin, "P404: invalid sender");
        require(!_isContract(msg.sender), "P404: invalid sender - contract");

        uint256 nfts = msg.value / mintPrice;
        uint256 _realcost = nfts * mintPrice;
        uint256 _charge = msg.value - _realcost;
        require(nftMinted + nfts <= MAX_NFT_MINT, "P404: exceed max mint");
        nftMinted += nfts;
        for (uint256 i = 0; i < nfts; i++) {
            _retrieveOrMintERC721(msg.sender);
        }

        payable(feeTo).transfer(_realcost);
        if (_charge > 0) {
            payable(msg.sender).transfer(_charge);
        }

        emit PayToMint(msg.sender, _realcost, nfts);
    }

  function _isContract(address account) internal view returns (bool) {
    uint256 size;
    assembly {
        size := extcodesize(account)
    }
    return size > 0;
  }

  function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256) {
    return _owned[owner][index];
  }

    function owned(
    address owner_
  ) public view virtual returns (uint256[] memory) {
    return _owned[owner_];
  }

  function erc721BalanceOf(
    address owner_
  ) public view virtual returns (uint256) {
    return _owned[owner_].length;
  }
}