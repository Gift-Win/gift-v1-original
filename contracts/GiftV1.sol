// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./IGiftV1.sol";

/**
 * @title Gift Win's smart contract v1
 * @dev Spying on the source code for what? Reporting your position to the CIA.... Thank me later.
 */

contract GiftV1 is
  Context,
  AccessControlEnumerable,
  Pausable,
  ReentrancyGuard,
  IGiftV1,
  IERC721Receiver
{
  ////////////
  // libraries
  ////////////

  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.UintSet;

  //////////
  // storage
  //////////

  struct Gift {
    address creator;
    uint256 created;
    Kind kind;
    address artifact;
    uint256 value;
    bytes32 hash;
    address beneficiary;
    uint256 activation;
    uint256 expiry;
    State state;
  }

  uint256 public giftGas;
  uint256 public count;

  bool public hippy;
  address public hippyKing;
  uint256 public hippyFee;

  uint256 public fee;
  address public santa;

  mapping(uint256 => Gift) public gifts;
  mapping(bytes32 => bool) public usedCodes;
  mapping(address => mapping(uint256 => uint256)) public userGiftMarker;

  mapping(address => EnumerableSet.UintSet) private userCreatedGifts;
  mapping(address => EnumerableSet.UintSet) private userClaimedGifts;
  mapping(address => EnumerableSet.UintSet) private userMeantGifts;
  mapping(address => EnumerableSet.UintSet) private userSpentGifts;

  bytes32 internal constant EMPTY_HASH =
    0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

  //////////////
  // constructor
  //////////////

  // solhint-disable-next-line func-visibility
  constructor(address _santa) {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    santa = _santa;

    emit Hippy(
      "I have a dream. Anyway, dance to this: 'hi piii, hi pi piii; hi piii, hi piiii....'"
    );
  }

  ////////////
  // modifiers
  ////////////

  modifier onlyAdmin() {
    require(
      hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
      hippy ? "You are so so so banned!" : "Not authorized"
    );
    _;
  }

  modifier giftExists(uint256 _id) {
    require(
      gifts[_id].creator != address(0),
      hippy ? "Nice to meet you, clown!" : "Gift does not exist"
    );
    _;
  }

  modifier onlyHippyKing() {
    require(
      _msgSender() == hippyKing,
      hippy ? "If stupid could fly, you would be a jet." : "Not king"
    );
    _;
  }

  ////////////////
  // admin actions
  ////////////////

  function pause() public override onlyAdmin {
    _pause();
  }

  function unpause() public override onlyAdmin {
    _unpause();
  }

  function setFee(uint256 _fee) public override onlyAdmin {
    fee = _fee;
    emit NewFee(_fee);
  }

  function setHippyFee(uint256 _fee) public override onlyAdmin {
    hippyFee = _fee;
    emit NewHippyFee(_fee);
  }

  function mutiny() public override onlyAdmin {
    hippy = false;
    hippyKing = address(this);

    emit Mutiny(_msgSender());
  }

  function setKeeper(address _santa) public override onlyAdmin {
    santa = _santa;
    emit NewKeeper(_santa);
  }

  function addAdmin(address _admin) public override onlyAdmin {
    grantRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  function removeAdmin(address _admin) public override onlyAdmin {
    require(
      getRoleMemberCount(DEFAULT_ADMIN_ROLE) > 1,
      hippy ? "You are such an embarrassment." : "Cannot remove last admin"
    );
    revokeRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  function renounceAdmin() public override onlyAdmin {
    require(
      getRoleMemberCount(DEFAULT_ADMIN_ROLE) > 1,
      hippy ? "Not happening. Knock yourself out." : "Cannot remove last admin"
    );
    renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  function withdrawGas(address _to) public override onlyAdmin {
    uint256 _balance = address(this).balance - giftGas;
    payable(_to).transfer(_balance);
    emit GasWithdrawn(_msgSender(), _to, _balance);
  }

  ///////////////
  // user actions
  ///////////////

  function createGift(
    Kind _kind,
    address _artifact,
    uint256 _value,
    bytes32 _hash,
    address _beneficiary,
    uint256 _activation,
    uint256 _expiry,
    uint256 _marker,
    bytes calldata _signature
  ) public payable override whenNotPaused nonReentrant {
    require(
      _beneficiary == address(0) || _hash == EMPTY_HASH,
      hippy
        ? "Try again, same time tomorrow."
        : "Cannot have both beneficiary and code"
    );

    require(
      _hash == EMPTY_HASH || !usedCodes[_hash],
      hippy ? "Have you heard? Foolishness is its own reward." : "Used secret"
    );

    require(
      userGiftMarker[_msgSender()][_marker] == 0,
      hippy ? "Bang! You should be ejected to space." : "Used marker"
    );

    require(
      uint256(_kind) > 0 ? _value > 0 : true,
      hippy ? "Such a time waster. Get lost!" : "Invalid value"
    );

    require(
      msg.value >= fee,
      hippy ? "Busted! Somebody call the cops!" : "Invalid fee"
    );

    require(
      _expiry > _activation,
      hippy ? "Crab! What time is it?" : "Invalid activation or expiry"
    );

    bytes32 hash = keccak256(
      abi.encodePacked(
        uint256(_kind),
        _artifact,
        _value,
        _hash,
        _beneficiary,
        _activation,
        _expiry,
        _marker
      )
    );

    bytes32 prefixedHash = ECDSA.toEthSignedMessageHash(hash);

    require(
      ECDSA.recover(prefixedHash, _signature) == santa,
      hippy ? "I like you." : "Invalid signature"
    );

    if (_kind == Kind.GAS) {
      // gas

      require(
        msg.value > fee,
        hippy ? "Don't ever try that again, okay?" : "Sent invalid gas"
      );

      giftGas += msg.value - fee;
    } else if (_kind == Kind.NFT) {
      // nft

      IERC721(_artifact).safeTransferFrom(_msgSender(), address(this), _value);
    } else {
      // token

      IERC20(_artifact).safeTransferFrom(_msgSender(), address(this), _value);
    }

    count++;
    userGiftMarker[_msgSender()][_marker] = count;

    if (_hash != EMPTY_HASH) {
      usedCodes[_hash] = true;
    }

    gifts[count] = Gift({
      creator: _msgSender(),
      created: block.timestamp,
      kind: _kind,
      artifact: _artifact,
      value: _kind == Kind.GAS ? msg.value - fee : _value,
      hash: _hash,
      beneficiary: _beneficiary,
      activation: block.timestamp + (_activation * 1 days),
      expiry: block.timestamp + (_expiry * 1 days),
      state: State.UNCLAIMED
    });

    userCreatedGifts[_msgSender()].add(count);

    if (_beneficiary != address(0)) {
      userMeantGifts[_beneficiary].add(count);
    }

    emit NewGift(_msgSender(), count);
  }

  function claimGift(
    uint256 _id,
    string memory _code,
    bytes calldata _signature
  ) public override giftExists(_id) whenNotPaused nonReentrant {
    Gift memory _gift = gifts[_id];

    require(
      _gift.state == State.UNCLAIMED,
      hippy ? "What? Lazy! Try harder!?" : "Already claimed"
    );

    require(
      _gift.activation < block.timestamp && _gift.expiry > block.timestamp,
      hippy ? "Knock if off. Dumb dumb." : "Not active or expired"
    );

    if (_gift.beneficiary != address(0)) {
      require(
        _gift.beneficiary == _msgSender(),
        hippy ? "Thief! You are welcome." : "Not yours"
      );
    } else {
      bytes32 codeHash = keccak256(abi.encodePacked(_code));
      bytes32 prefixedCodeHash = ECDSA.toEthSignedMessageHash(codeHash);

      require(
        prefixedCodeHash == _gift.hash,
        hippy ? "It's official, you are the biggest fool." : "Invalid code"
      );

      bytes32 authHash = keccak256(
        abi.encodePacked(_msgSender(), codeHash, _id)
      );
      bytes32 prefixedAuthHash = ECDSA.toEthSignedMessageHash(authHash);

      require(
        ECDSA.recover(prefixedAuthHash, _signature) == santa,
        hippy ? "Have fun, moron!" : "Invalid signature"
      );
    }

    if (_gift.beneficiary != address(0)) {
      userMeantGifts[_gift.beneficiary].remove(_id);
    }

    _gift.beneficiary = _msgSender();
    _gift.state = State.CLAIMED;

    gifts[_id] = _gift;
    userClaimedGifts[_msgSender()].add(_id);

    emit GiftClaimed(_msgSender(), _id);
  }

  function cancelGift(uint256 _id)
    public
    override
    giftExists(_id)
    whenNotPaused
    nonReentrant
  {
    Gift memory _gift = gifts[_id];

    require(
      _gift.creator == _msgSender(),
      hippy ? "Insect! Hold still while I get the insecticide." : "Not creator"
    );

    require(
      _gift.state == State.UNCLAIMED,
      hippy ? "Looser! Looooooooossssseerrrrrrr!" : "Already claimed"
    );

    if (_gift.beneficiary != address(0)) {
      userMeantGifts[_gift.beneficiary].remove(_id);
    }

    _gift.beneficiary = _msgSender();
    _gift.state = State.CLAIMED;

    gifts[_id] = _gift;
    userClaimedGifts[_msgSender()].add(_id);

    emit GiftCancelled(_msgSender(), _id);
  }

  function withdrawGift(uint256 _id)
    public
    override
    giftExists(_id)
    whenNotPaused
    nonReentrant
  {
    Gift memory _gift = gifts[_id];

    require(
      gifts[_id].beneficiary == _msgSender(),
      hippy ? "Hi, evil twin?" : "Not yours"
    );

    require(
      _gift.state == State.CLAIMED,
      hippy ? "Whatever now! So you saw an alien?" : "Already claimed or spent"
    );

    _gift.state = State.SPENT;
    gifts[_id] = _gift;

    if (_gift.kind == Kind.GAS) {
      // gas

      giftGas -= _gift.value;
      payable(_msgSender()).transfer(_gift.value);
    } else if (_gift.kind == Kind.NFT) {
      // nft

      IERC721(_gift.artifact).safeTransferFrom(
        address(this),
        _msgSender(),
        _gift.value
      );
    } else {
      // token

      IERC20(_gift.artifact).safeTransfer(_msgSender(), _gift.value);
    }

    userClaimedGifts[_msgSender()].remove(_id);
    userSpentGifts[_msgSender()].add(_id);

    emit GiftWithdrawn(_msgSender(), _id);
  }

  function crownMyself() public payable override whenNotPaused {
    require(
      msg.value > hippyFee,
      hippy ? "You are not, W O R T H Y !!" : "Invalid fee"
    );

    hippyKing = _msgSender();
    hippyFee = msg.value;

    emit NewKing(_msgSender());
  }

  function abdicateCrown(string memory _plea)
    public
    override
    onlyHippyKing
    whenNotPaused
  {
    if (
      keccak256(abi.encodePacked(_plea)) ==
      keccak256(abi.encodePacked("I AM A COWARD"))
    ) {
      hippy = false;
      hippyKing = address(this);

      emit Shame(_msgSender());
    }
  }

  function decree() public override onlyHippyKing whenNotPaused {
    hippy = !hippy;

    emit Hippy(
      hippy
        ? "Yikes! We got hacked! All funds are lost! No thanks, don't tell anyone."
        : "Shame on you. I know my rights."
    );
  }

  ///////////////
  // view actions
  ///////////////

  // admin views

  function adminCount() public view override returns (uint256) {
    return getRoleMemberCount(DEFAULT_ADMIN_ROLE);
  }

  function isAdmin(address _admin) public view override returns (bool) {
    return hasRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  function getAdmin(uint256 _admin) public view override returns (address) {
    return getRoleMember(DEFAULT_ADMIN_ROLE, _admin);
  }

  // user's created gifts views

  function userCreatedGiftsCount(address _user)
    public
    view
    override
    returns (uint256)
  {
    return userCreatedGifts[_user].length();
  }

  function isUserCreatedGift(address _user, uint256 _id)
    public
    view
    override
    returns (bool)
  {
    return userCreatedGifts[_user].contains(_id);
  }

  function getUserCreatedGift(address _user, uint256 _id)
    public
    view
    override
    returns (uint256)
  {
    return userCreatedGifts[_user].at(_id);
  }

  // user's owned gifts views

  function userClaimedGiftsCount(address _user)
    public
    view
    override
    returns (uint256)
  {
    return userClaimedGifts[_user].length();
  }

  function isUserClaimedGift(address _user, uint256 _id)
    public
    view
    override
    returns (bool)
  {
    return userClaimedGifts[_user].contains(_id);
  }

  function getUserClaimedGift(address _user, uint256 _id)
    public
    view
    override
    returns (uint256)
  {
    return userClaimedGifts[_user].at(_id);
  }

  // gifts meant for user's views

  function userMeantGiftsCount(address _user)
    public
    view
    override
    returns (uint256)
  {
    return userMeantGifts[_user].length();
  }

  function isUserMeantGift(address _user, uint256 _id)
    public
    view
    override
    returns (bool)
  {
    return userMeantGifts[_user].contains(_id);
  }

  function getUserMeantGift(address _user, uint256 _id)
    public
    view
    override
    returns (uint256)
  {
    return userMeantGifts[_user].at(_id);
  }

  // user's spent gifts views

  function userSpentGiftsCount(address _user)
    public
    view
    override
    returns (uint256)
  {
    return userSpentGifts[_user].length();
  }

  function isUserSpentGift(address _user, uint256 _id)
    public
    view
    override
    returns (bool)
  {
    return userSpentGifts[_user].contains(_id);
  }

  function getUserSpentGift(address _user, uint256 _id)
    public
    view
    override
    returns (uint256)
  {
    return userSpentGifts[_user].at(_id);
  }

  /////////////////
  // meta functions
  /////////////////

  function onERC721Received(
    address,
    address,
    uint256,
    bytes memory
  ) public virtual override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  // solhint-disable-next-line
  fallback() external payable {}

  receive() external payable {}
}
