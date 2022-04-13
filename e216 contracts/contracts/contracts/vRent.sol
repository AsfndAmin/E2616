// SPDX-License-Identifier: MIT
pragma solidity =0.8.6; 

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "./IPayment.sol"; 
import "./IvRent.sol";  

contract vRent is IvRent, ERC721Holder, ERC1155Receiver, ERC1155Holder { 
    using SafeERC20 for ERC20; 

    IPayment private payment;
    address private owner;
    address payable private feeReceiver;
    uint256 private leasingId = 1;
    bool public paused = false;

    // in bps. so 100 => 1%
    uint256 public rentFee = 0;

    uint256 private constant SECONDS_IN_DAY = 86400;

    struct Leasing {
        address payable leaserAddress; 
        uint8 maxLeaseDuration;
        bytes4 dailyLeasePrice;
        bytes4 collateralAmount;
        uint8 leaseAmount;
        IPayment.PaymentToken paymentToken;
    }

    // single storage slot: 160 bits, 168, 200
    struct Renting {
        address payable renterAddress;
        uint8 rentDuration;
        uint32 rentedAt;
    }

    struct LeasingRenting {
        Leasing Leasing;
        Renting renting;
    }

    mapping(bytes32 => LeasingRenting) private leasingRenting;

    struct CallData {
        uint256 left;
        uint256 right;
        address[] nfts;
        uint256[] tokenIds;
        uint256[] leaseAmounts;
        uint8[] maxLeaseDurations;
        bytes4[] _dailyLeaseCost;
        bytes4[] collateralAmounts;
        uint256[] leasingIds;
        uint8[] rentPeriod;
        IPayment.PaymentToken[] paymentTokens;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "vRent::not owner");
        _;
    }

    modifier notPaused {
        require(!paused, "vRent::paused");
        _;
    }

    constructor(
        address _payment,
        address payable _feeReceiver,
        address _owner
    ) {
        _isNotZeroAddr(_payment);
        _isNotZeroAddr(_feeReceiver);
        _isNotZeroAddr(_owner);
        payment = IPayment(_payment);
        feeReceiver = _feeReceiver;
        owner = _owner;
    }

    function batchCall(function(CallData memory) _manager, CallData memory _cd)
        private
    {
        require(_cd.nfts.length > 0, "vRent::no nfts");
        while (_cd.right != _cd.nfts.length) {
            if (
                (_cd.nfts[_cd.left] == _cd.nfts[_cd.right]) &&
                (is1155(_cd.nfts[_cd.right]))
            ) {
                _cd.right++;
            } else {
                _manager(_cd);
                _cd.left = _cd.right;
                _cd.right++;
            }
        }
        _manager(_cd);
    }

    /**
     * @dev user Lease the nft for earning.
     * 
     * Emits an {Leased} event indicating the nft is Leaseed by Leaser.
     * 
     * Requirements:
     *
     * - the caller must have allowance for `_tokenIds`'s tokens of at least
     * `_tokenAmounts`.
     * - the caller must have a balance of at least `_tokenAmounts`.
     * - `_collateralAmounts` and `_dailyLeaseCost` should be between 9999.9999 and 0.0001
     */
    function lease(
        address[] memory _nftAddress,
        uint256[] memory _tokenIds,
        uint256[] memory _tokenAmounts,
        uint8[] memory _maxLeasePeriod,
        bytes4[] memory _dailyLeaseCost,
        bytes4[] memory _collateralAmounts,
        IPayment.PaymentToken[] memory _paymentTokens
    ) external override notPaused {
        batchCall(
            manageLease,
            _createLeaseCallData(
                _nftAddress,
                _tokenIds,
                _tokenAmounts,
                _maxLeasePeriod,
                _dailyLeaseCost,
                _collateralAmounts,
                _paymentTokens
            )
        );
    }

    /**
     * @dev See {IvRent-rent}.
     *
     * Emits an {Rented} event indicating the nft is rented by renter.
     *
     * Requirements:
     *
     * - caller must have a balance of at least daily rent + collateral amount.
     * - the caller must have allowance for PaymentToken's tokens of at least
     *   dailyLeasePrice + collateral amount.
     */
    function rentNFT(
        address[] memory _nftAddress,
        uint256[] memory _tokenIds,
        uint256[] memory _leasingIds,
        uint8[] memory _rentPeriod
    ) external override notPaused {
        batchCall(
            manageRent,
            _createRentCallData(_nftAddress, _tokenIds, _leasingIds, _rentPeriod)
        );
    }

    /**
     * @dev renter returns NFT to vRent contract
     * 
     * Emits an {Returned} event indicating the nft returned from renter to contract.
     *
     * Requirements:
     *
     * - caller cannot be the zero address.
     * - caller must have a balance of `_tokenIds`.
     */    
    function endRent(
        address[] memory _nftAddress,
        uint256[] memory _tokenIds,
        uint256[] memory _leasingIds
    ) external override {
        batchCall(
            manageReturn,
            _createActionCallData(_nftAddress, _tokenIds, _leasingIds)
        );
    }

    /**
     * @dev Leaser gets his nft back from vRent
     *
     * Emits an {LeasingStopped} event indicating nft Leasing stopped. 
     * 
     * Requirements:
     *
     * - caller cannot be the zero address.
     * - caller must be the one who Leaseed nft.
     */
    function cancelLeasing(
        address[] memory _nftAddress,
        uint256[] memory _tokenIds,
        uint256[] memory _leasingIds
    ) external override notPaused {
        batchCall(
            manageStopLeasing,
            _createActionCallData(_nftAddress, _tokenIds, _leasingIds)
        );
    }

    /**
     * @dev Leaser claims collateral in case of nft not returned by
     * renter within deadline.
     *
     * Emits an {CollateralClaimed} event indicating the the Leaser cllaimed the
     * collateral for his nft.
     *
     * Requirements:
     *
     * - caller cannot be the zero address.
     * - caller must be the one who Leaseed the nft.
     * - Leaser cannot claim collateral before the deadline 
     */
    function claimCollateral(
        address[] memory _nftAddress,
        uint256[] memory _tokenIds,
        uint256[] memory _leasingIds
    ) external override notPaused {
        batchCall(
            manageClaimCollateral,
            _createActionCallData(_nftAddress, _tokenIds, _leasingIds)
        );
    }

    // -------------------------------------------------------------------------
    
    /**
     * deduct the platform fee and transfer it to `feeReceiver` address
    */

    function takeFee(
        uint256 _rent, 
        IPayment.PaymentToken _paymentToken)
        private returns (uint256 fee) {
        fee = _rent * rentFee;
        fee /= 10000;
        uint8 paymentTokenIx = uint8(_paymentToken);
        tokenNotSentinel(paymentTokenIx);
        ERC20 paymentToken = ERC20(payment.getPaymentToken(paymentTokenIx));
        paymentToken.safeTransfer(feeReceiver, fee);
    }
    
    
    //   distribute payments
    function distributePayments(
        LeasingRenting storage _LeasingRenting,
        uint256 _secondsSinceRentStart
    ) private {
        uint8 paymentTokenIx = uint8(_LeasingRenting.Leasing.paymentToken);
        tokenNotSentinel(paymentTokenIx);
        address paymentToken = payment.getPaymentToken(paymentTokenIx);
        uint256 decimals = ERC20(paymentToken).decimals();

        uint256 scale = 10**decimals;
        uint256 collateralAmount =
            _LeasingRenting.Leasing.leaseAmount *
                _unwrapPrice(_LeasingRenting.Leasing.collateralAmount, scale);
        uint256 rentPrice =
            _unwrapPrice(_LeasingRenting.Leasing.dailyLeasePrice, scale);
        uint256 totalRenterPmtWoCollateral =
            rentPrice * _LeasingRenting.renting.rentDuration;
        uint256 sendLeaserAmt =
            (_secondsSinceRentStart * rentPrice) / SECONDS_IN_DAY;
        require(
            totalRenterPmtWoCollateral > 0,
            "vRent::total payment wo collateral is zero"
        );
        require(sendLeaserAmt > 0, "vRent::Leaser payment is zero");
        uint256 sendRenterAmt = totalRenterPmtWoCollateral - sendLeaserAmt;

        uint256 takenFee =
            takeFee(sendLeaserAmt, _LeasingRenting.Leasing.paymentToken);

        sendLeaserAmt -= takenFee;
        sendRenterAmt += collateralAmount;

        ERC20(paymentToken).safeTransfer(
            _LeasingRenting.Leasing.leaserAddress,
            sendLeaserAmt
        );
        ERC20(paymentToken).safeTransfer(
            _LeasingRenting.renting.renterAddress,
            sendRenterAmt
        );
    }

    // distributes the `collateralAmounts` amount 
    function distributeClaimPayment(LeasingRenting memory _LeasingRenting)
        private
    {
        uint8 paymentTokenIx = uint8(_LeasingRenting.Leasing.paymentToken);
        tokenNotSentinel(paymentTokenIx);
        ERC20 paymentToken = ERC20(payment.getPaymentToken(paymentTokenIx));

        uint256 decimals = ERC20(paymentToken).decimals();
        uint256 scale = 10**decimals;
        uint256 collateralAmount =
            _LeasingRenting.Leasing.leaseAmount *
                _unwrapPrice(_LeasingRenting.Leasing.collateralAmount, scale);
        uint256 rentPrice =
            _unwrapPrice(_LeasingRenting.Leasing.dailyLeasePrice, scale);
        uint256 maxRentPayment =
            rentPrice * _LeasingRenting.renting.rentDuration;
        uint256 takenFee =
            takeFee(maxRentPayment, IPayment.PaymentToken(paymentTokenIx));
        uint256 finalAmt = maxRentPayment + collateralAmount;

        require(finalAmt > 0, "vRent::collateral plus rent is zero");

        paymentToken.safeTransfer(
            _LeasingRenting.Leasing.leaserAddress,
            finalAmt - takenFee
        );
    }

    function _safeTransfer(
        CallData memory _cd,
        address _from,
        address _to,
        uint256[] memory _tokenIds,
        uint256[] memory _leaseAmounts
    ) private {
        if (is721(_cd.nfts[_cd.left])) {
            IERC721(_cd.nfts[_cd.left]).transferFrom(
                _from,
                _to,
                _cd.tokenIds[_cd.left]
            );
        } else if (is1155(_cd.nfts[_cd.left])) {
            IERC1155(_cd.nfts[_cd.left]).safeBatchTransferFrom(
                _from,
                _to,
                _tokenIds,
                _leaseAmounts,
                ""
            );
        } else {
            revert("vRent::unsupported token type");
        }
    }

    // -------------------------------------------------------------------------
    function manageLease(CallData memory _cd) private {
        for (uint256 i = _cd.left; i < _cd.right; i++) {
            _isLeaseable(_cd, i); 

            LeasingRenting storage item =
                leasingRenting[
                    keccak256(
                        abi.encodePacked(
                            _cd.nfts[_cd.left],
                            _cd.tokenIds[i],
                            leasingId
                        )
                    )
                ];

            _isNull(item.Leasing);
            _isNull(item.renting);

            bool nftIs721 = is721(_cd.nfts[i]);
            item.Leasing = Leasing({ 
                leaserAddress: payable(msg.sender),
                leaseAmount: nftIs721 ? 1 : uint8(_cd.leaseAmounts[i]),
                maxLeaseDuration: _cd.maxLeaseDurations[i],
                dailyLeasePrice: _cd._dailyLeaseCost[i],
                collateralAmount: _cd.collateralAmounts[i],
                paymentToken: _cd.paymentTokens[i]
            });

            emit Leased(
                _cd.nfts[_cd.left],
                _cd.tokenIds[i],
                nftIs721 ? 1 : uint8(_cd.leaseAmounts[i]),
                leasingId,
                msg.sender,
                _cd.maxLeaseDurations[i],
                _cd._dailyLeaseCost[i],
                _cd.collateralAmounts[i],
                nftIs721,
                _cd.paymentTokens[i]
            );

            leasingId++;
        }

        _safeTransfer(
            _cd,
            msg.sender,
            address(this),
            _splitArr(_cd.tokenIds, _cd.left, _cd.right, 0),
            _splitArr(_cd.leaseAmounts, _cd.left, _cd.right, 0)
        );
    }

    function manageRent(CallData memory _cd) private {
        uint256[] memory leaseAmounts = new uint256[](_cd.right - _cd.left);

        for (uint256 i = _cd.left; i < _cd.right; i++) {
            LeasingRenting storage item =
                leasingRenting[
                    keccak256(
                        abi.encodePacked(
                            _cd.nfts[_cd.left],
                            _cd.tokenIds[i],
                            _cd.leasingIds[i]
                        )
                    )
                ];

            _isNotNull(item.Leasing);
            _isNull(item.renting);
            _isRentable(item.Leasing, _cd, i, msg.sender);

            uint8 paymentTokenIx = uint8(item.Leasing.paymentToken);
            tokenNotSentinel(paymentTokenIx);
            address paymentToken = payment.getPaymentToken(paymentTokenIx); 
            uint256 decimals = ERC20(paymentToken).decimals();

            {
                uint256 scale = 10**decimals;
                uint256 rentPrice =
                    _cd.rentPeriod[i] *
                        _unwrapPrice(item.Leasing.dailyLeasePrice, scale);
                uint256 collateralAmount =
                    item.Leasing.leaseAmount *
                        _unwrapPrice(item.Leasing.collateralAmount, scale);

                require(rentPrice > 0, "vRent::rent price is zero");
                require(collateralAmount > 0, "vRent::nft price is zero");

                ERC20(paymentToken).safeTransferFrom(
                    msg.sender,
                    address(this),
                    rentPrice + collateralAmount
                );
            }

            leaseAmounts[i - _cd.left] = item.Leasing.leaseAmount;

            item.renting.renterAddress = payable(msg.sender);
            item.renting.rentDuration = _cd.rentPeriod[i];
            item.renting.rentedAt = uint32(block.timestamp);

            emit Rented(
                _cd.leasingIds[i],
                msg.sender,
                _cd.rentPeriod[i],
                item.renting.rentedAt
            );
        }

        _safeTransfer(
            _cd,
            address(this),
            msg.sender,
            _splitArr(_cd.tokenIds, _cd.left, _cd.right, 0),
            _splitArr(leaseAmounts, _cd.left, _cd.right, _cd.left)
        );
    }
    
    function manageReturn(CallData memory _cd) private {
        uint256[] memory leaseAmounts = new uint256[](_cd.right - _cd.left);

        for (uint256 i = _cd.left; i < _cd.right; i++) {
            LeasingRenting storage item =
                leasingRenting[
                    keccak256(
                        abi.encodePacked(
                            _cd.nfts[_cd.left],
                            _cd.tokenIds[i],
                            _cd.leasingIds[i]
                        )
                    )
                ];

            _isNotNull(item.Leasing);
            _isReturnable(item.renting, msg.sender, block.timestamp);

            uint256 secondsSinceRentStart =
                block.timestamp - item.renting.rentedAt;
            distributePayments(item, secondsSinceRentStart);

            leaseAmounts[i - _cd.left] = item.Leasing.leaseAmount;

            emit Returned(_cd.leasingIds[i], uint32(block.timestamp));

            delete item.renting;
        }

        _safeTransfer(
            _cd,
            msg.sender,
            address(this),
            _splitArr(_cd.tokenIds, _cd.left, _cd.right, 0),
            _splitArr(leaseAmounts, _cd.left, _cd.right, _cd.left)
        );
    }

    function manageStopLeasing(CallData memory _cd) private {
        uint256[] memory leaseAmounts = new uint256[](_cd.right - _cd.left);

        for (uint256 i = _cd.left; i < _cd.right; i++) { 
            LeasingRenting storage item =
                leasingRenting[
                    keccak256(
                        abi.encodePacked(
                            _cd.nfts[_cd.left],
                            _cd.tokenIds[i],
                            _cd.leasingIds[i]
                        )
                    )
                ];

            _isNotNull(item.Leasing);
            _isNull(item.renting);
            _isStoppable(item.Leasing, msg.sender);

            leaseAmounts[i - _cd.left] = item.Leasing.leaseAmount;

            emit LeasingStopped(_cd.leasingIds[i], uint32(block.timestamp)); 

            delete item.Leasing;
        }

        _safeTransfer(
            _cd,
            address(this),
            msg.sender,
            _splitArr(_cd.tokenIds, _cd.left, _cd.right, 0),
            _splitArr(leaseAmounts, _cd.left, _cd.right, _cd.left)
        );
    }

    function manageClaimCollateral(CallData memory _cd) private {
        for (uint256 i = _cd.left; i < _cd.right; i++) {
            LeasingRenting storage item =
                leasingRenting[
                    keccak256(
                        abi.encodePacked(
                            _cd.nfts[_cd.left],
                            _cd.tokenIds[i],
                            _cd.leasingIds[i]
                        )
                    )
                ];

            _isNotNull(item.Leasing);
            _isNotNull(item.renting);
            _isClaimable(item.renting, block.timestamp);

            distributeClaimPayment(item);

            emit CollateralClaimed(_cd.leasingIds[i], uint32(block.timestamp));

            delete item.Leasing;
            delete item.renting;
        }
    }

   // -------------------------------------------------------------------------
   // verifys the NFT standard

    function is721(address _nft) private view returns (bool) {
        return IERC165(_nft).supportsInterface(type(IERC721).interfaceId);
    }

    function is1155(address _nft) private view returns (bool) {
        return IERC165(_nft).supportsInterface(type(IERC1155).interfaceId);
    }

    // -------------------------------------------------------------------------

    function _createLeaseCallData(
        address[] memory _nftAddress,
        uint256[] memory _tokenIds,
        uint256[] memory _tokenAmounts,
        uint8[] memory _maxLeasePeriod,
        bytes4[] memory _dailyLeaseCost,
        bytes4[] memory _collateralAmounts,
        IPayment.PaymentToken[] memory _paymentTokens
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nfts: _nftAddress,
            tokenIds: _tokenIds,
            leaseAmounts: _tokenAmounts,
            leasingIds: new uint256[](0),
            rentPeriod: new uint8[](0),
            maxLeaseDurations: _maxLeasePeriod,
            _dailyLeaseCost: _dailyLeaseCost,
            collateralAmounts: _collateralAmounts,
            paymentTokens: _paymentTokens
        });
    }

    function _createRentCallData(
        address[] memory _nftAddress,
        uint256[] memory _tokenIds,
        uint256[] memory _leasingIds,
        uint8[] memory _rentPeriod
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nfts: _nftAddress,
            tokenIds: _tokenIds,
            leaseAmounts: new uint256[](0),
            leasingIds: _leasingIds,
            rentPeriod: _rentPeriod,
            maxLeaseDurations: new uint8[](0),
            _dailyLeaseCost: new bytes4[](0),
            collateralAmounts: new bytes4[](0),
            paymentTokens: new IPayment.PaymentToken[](0)
        });
    }

    function _createActionCallData(
        address[] memory _nftAddress,
        uint256[] memory _tokenIds,
        uint256[] memory _leasingIds
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nfts: _nftAddress,
            tokenIds: _tokenIds,
            leaseAmounts: new uint256[](0),
            leasingIds: _leasingIds,
            rentPeriod: new uint8[](0),
            maxLeaseDurations: new uint8[](0),
            _dailyLeaseCost: new bytes4[](0),
            collateralAmounts: new bytes4[](0),
            paymentTokens: new IPayment.PaymentToken[](0)
        });
    }
    
    /**
     * convert the `_dailyLeaseCost` and `collateralAmounts` from bytes4 into decimal
    */
    function _unwrapPrice(bytes4 _price, uint256 _scale)
        private
        pure
        returns (uint256)
    {
        _isUnwrapablePrice(_price, _scale);

        uint16 whole = uint16(bytes2(_price));
        uint16 decimal = uint16(bytes2(_price << 16));
        uint256 decimalScale = _scale / 10000;

        if (whole > 9999) {
            whole = 9999;
        }
        if (decimal > 9999) {
            decimal = 9999;
        }

        uint256 w = whole * _scale;
        uint256 d = decimal * decimalScale;
        uint256 price = w + d;

        return price;
    }

    function _splitArr(
        uint256[] memory _arr,
        uint256 _fromIx,
        uint256 _toIx,
        uint256 _arrOffset
    ) private pure returns (uint256[] memory r) {
        r = new uint256[](_toIx - _fromIx);
        for (uint256 i = _fromIx; i < _toIx; i++) {
            r[i - _fromIx] = _arr[i - _arrOffset];
        }
    }

    // -------------------------------------------------------------------------
    
    /**
     * verify whether caller is zero aaddress or not
    */
    function _isNotZeroAddr(address _addr) private pure {
        require(_addr != address(0), "vRent::zero address");
    }

    function _isZeroAddr(address _addr) private pure {
        require(_addr == address(0), "vRent::not a zero address");
    }

    function _isNull(Leasing memory _Leasing) private pure {
        _isZeroAddr(_Leasing.leaserAddress);
        require(_Leasing.maxLeaseDuration == 0, "vRent::duration not zero");
        require(_Leasing.dailyLeasePrice == 0, "vRent::rent price not zero");
        require(_Leasing.collateralAmount == 0, "vRent::nft price not zero");
    }

    function _isNotNull(Leasing memory _Leasing) private pure {
        _isNotZeroAddr(_Leasing.leaserAddress);
        require(_Leasing.maxLeaseDuration != 0, "vRent::duration zero");
        require(_Leasing.dailyLeasePrice != 0, "vRent::rent price is zero");
        require(_Leasing.collateralAmount != 0, "vRent::nft price is zero");
    }

    function _isNull(Renting memory _renting) private pure {
        _isZeroAddr(_renting.renterAddress);
        require(_renting.rentDuration == 0, "vRent::duration not zero");
        require(_renting.rentedAt == 0, "vRent::rented at not zero");
    }

    function _isNotNull(Renting memory _renting) private pure {
        _isNotZeroAddr(_renting.renterAddress);
        require(_renting.rentDuration != 0, "vRent::duration is zero");
        require(_renting.rentedAt != 0, "vRent::rented at is zero");
    }

    /**
     * verify whether the duration is between the range else user can't Lease nft
    */
    function _isLeaseable(CallData memory _cd, uint256 _i) private pure {
        require(_cd.leaseAmounts[_i] > 0, "vRent::Lease amount is zero");
        require(_cd.leaseAmounts[_i] <= type(uint8).max, "vRent::not uint8");
        require(_cd.maxLeaseDurations[_i] > 0, "vRent::duration is zero");
        require(
            _cd.maxLeaseDurations[_i] <= type(uint8).max,
            "vRent::not uint8"
        );
        require(
            uint32(_cd._dailyLeaseCost[_i]) > 0,
            "vRent::rent price is zero"
        );
        require(uint32(_cd.collateralAmounts[_i]) > 0, "vRent::nft price is zero");
    }

    /**
     * verifys the rent duration provided by user
    */
    function _isRentable(
        Leasing memory _Leasing,
        CallData memory _cd,
        uint256 _i,
        address _msgSender
    ) private pure {
        require(
            _msgSender != _Leasing.leaserAddress,
            "vRent::cant rent own nft"
        );
        require(_cd.rentPeriod[_i] <= type(uint8).max, "vRent::not uint8");
        require(_cd.rentPeriod[_i] > 0, "vRent::duration is zero");
        require(
            _cd.rentPeriod[_i] <= _Leasing.maxLeaseDuration,
            "vRent::rent duration exceeds allowed max"
        );
    }
    
    /**
     * @dev compare the timestamp with renting time and returns
     * whether the NFT is returnable or not
    */
    function _isReturnable(
        Renting memory _renting,
        address _msgSender,
        uint256 _blockTimestamp
    ) private pure {
        require(_renting.renterAddress == _msgSender, "vRent::not renter");
        require(
            !_isPastReturnDate(_renting, _blockTimestamp),
            "vRent::past return date"
        );
    }

    function _isStoppable(Leasing memory _Leasing, address _msgSender)
        private
        pure
    {
        require(_Leasing.leaserAddress == _msgSender, "vRent::not Leaser");
    }

    function _isClaimable(Renting memory _renting, uint256 _blockTimestamp)
        private
        pure
    {
        require(
            _isPastReturnDate(_renting, _blockTimestamp),
            "vRent::return date not passed"
        );
    }

    function _isUnwrapablePrice(bytes4 _price, uint256 _scale)
        private
        pure
    {
        require(uint32(_price) > 0, "vRent::invalid price");
        require(_scale >= 10000, "vRent::invalid scale");
    }

    function tokenNotSentinel(uint8 _paymentIx) private pure {
        require(_paymentIx > 0, "vRent::token is sentinel");
    }

    function _isPastReturnDate(Renting memory _renting, uint256 _now)
        private
        pure
        returns (bool)
    {
        require(_now > _renting.rentedAt, "vRent::now before rented");
        return
            _now - _renting.rentedAt > _renting.rentDuration * SECONDS_IN_DAY;
    }

    // -------------------------------------------------------------------------
    
    /**
     * @dev only owner can call this function
     * set the platform `rentFee`
     * `+_rentFee` should be less than 100%
    */
    function setRentFee(uint256 _rentFee) external onlyOwner {
        require(_rentFee < 10000, "vRent::fee exceeds 100pct");
        rentFee = _rentFee;
    }
    
    /**
     * @dev only owner can call this function
     * replaces the `feeReceiver` address to `+_newfeeReceiver`
    */
    function setfeeReceiver(address payable _newfeeReceiver)
        external
        onlyOwner
    {
        feeReceiver = _newfeeReceiver;
    }
    
    /**
     * owner can pause the Lease, rent, returnit or claimCollateral functions
    */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function getleasingId() external view returns (uint256) {
    return leasingId; 
    }
}