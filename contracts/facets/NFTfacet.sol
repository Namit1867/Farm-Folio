// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibNFT} from "../libraries/LibNFT.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {AppStorage, LibAppStorage} from "../libraries/LibAppStorage.sol";
import {Modifiers} from "../libraries/LibAppStorage.sol";
import {LibMeta} from "../libraries/LibMeta.sol";

contract NFTFacet is Modifiers {
    //remove me
    function nftStorage() internal pure returns (LibNFT.NFTStorage storage ns) {
        ns = LibNFT.nftStorage();
    }

    function setBaseUri(string memory _newBaseUri) external onlyOwner {
        LibNFT.setBaseUri(_newBaseUri);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view returns (uint256) {
        require(
            owner != address(0),
            "ERC721: address zero is not a valid owner"
        );
        LibNFT.NFTStorage storage ns = nftStorage();
        return ns._balances[owner];
    }

    function currId() public view returns (uint) {
        return LibNFT.currId();
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        LibNFT.NFTStorage storage ns = nftStorage();
        address owner = ns._owners[tokenId];
        require(
            owner != address(0),
            "ERC721: owner query for nonexistent token"
        );
        return owner;
    }

    function initialOwner(uint256 tokenId) public view returns (address) {
        LibNFT.NFTStorage storage ns = nftStorage();
        return ns.initialOwner[tokenId];
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() external view returns (string memory) {
        LibNFT.NFTStorage storage ns = nftStorage();
        return ns._name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() external view returns (string memory) {
        LibNFT.NFTStorage storage ns = nftStorage();
        return ns._symbol;
    }

    function _exists(uint256 tokenId) public view returns (bool) {
        LibNFT.NFTStorage storage ns = nftStorage();
        return ns._owners[tokenId] != address(0);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return LibNFT.tokenURI(tokenId);
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() public view virtual returns (string memory) {
        return LibNFT._baseURI();
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            LibMeta.msgSender() == owner ||
                isApprovedForAll(owner, LibMeta.msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        LibNFT._approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view returns (address) {
        require(
            _exists(tokenId),
            "ERC721: approved query for nonexistent token"
        );
        LibNFT.NFTStorage storage ns = nftStorage();
        return ns._tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) external {
        LibNFT._setApprovalForAll(LibMeta.msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) public view returns (bool) {
        LibNFT.NFTStorage storage ns = nftStorage();
        return ns._operatorApprovals[owner][operator];
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) public view returns (bool) {
        require(
            _exists(tokenId),
            "ERC721: operator query for nonexistent token"
        );
        address owner = ownerOf(tokenId);
        return (spender == owner ||
            isApprovedForAll(owner, spender) ||
            getApproved(tokenId) == spender);
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(LibMeta.msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        LibNFT._transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public {
        require(
            _isApprovedOrOwner(LibMeta.msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        LibNFT._safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) public view returns (uint256) {
        require(
            index < balanceOf(owner),
            "ERC721Enumerable: owner index out of bounds"
        );
        LibNFT.NFTStorage storage ns = nftStorage();
        return ns._ownedTokens[owner][index];
    }

    function tokensOfOwner(
        address owner
    ) public view returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](balanceOf(owner));
        LibNFT.NFTStorage storage ns = nftStorage();
        for (uint256 i = 0; i < balanceOf(owner); i++) {
            ids[i] = ns._ownedTokens[owner][i];
        }
        return ids;
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        LibNFT.NFTStorage storage ns = nftStorage();
        return ns._allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view returns (uint256) {
        LibNFT.NFTStorage storage ns = nftStorage();
        require(
            index < totalSupply(),
            "ERC721Enumerable: global index out of bounds"
        );
        return ns._allTokens[index];
    }

    // //ERC-2981 (Royalty Standard):-

    // function setRoyaltyforPortfolio(
    //     uint256 _tokenId,
    //     address _receiver,
    //     uint96 feeNumerator
    // ) external onlyInitialOwner(_tokenId) {
    //     LibNFT._setTokenRoyalty(_tokenId, _receiver, feeNumerator);
    // }

    // function resetPortfolioRoyalty(
    //     uint256 _tokenId
    // ) external onlyInitialOwner(_tokenId) {
    //     LibNFT._resetTokenRoyalty(_tokenId);
    // }

    // function setDefaultRoyalty(
    //     address receiver,
    //     uint96 feeNumerator
    // ) external onlyOwner {
    //     LibNFT._setDefaultRoyalty(receiver, feeNumerator);
    // }

    // function _deleteDefaultRoyalty() external onlyOwner {
    //     LibNFT.NFTStorage storage ns = nftStorage();
    //     delete ns._defaultRoyaltyInfo;
    // }

    // function royaltyInfo(
    //     uint256 _tokenId,
    //     uint256 _salePrice
    // ) external view returns (address, uint) {
    //     return LibNFT.royaltyInfo(_tokenId, _salePrice);
    // }

    // function _feeDenominator() public pure returns (uint96) {
    //     return LibNFT._feeDenominator();
    // }

    // function _feeNumerator

    // //ERC-4907 (Rental Standard):-

    // function setUser(
    //     uint256 tokenId,
    //     address user,
    //     uint64 expires
    // ) external isApprovedOrOwner_(LibMeta.msgSender(), tokenId) {
    //     LibNFT.setUser(tokenId, user, expires);
    // }

    // function userOf(uint256 tokenId) external view returns (address) {
    //     return LibNFT.userOf(tokenId);
    // }

    // function userExpires(uint256 tokenId) external view returns (uint256) {
    //     return LibNFT.userExpires(tokenId);
    // }

    // //Brokerage:-

    // function setBroker(
    //     uint256 tokenId,
    //     uint256 poolId,
    //     address broker,
    //     uint256 brokeragePercentage
    // ) external isApprovedOrOwner_(LibMeta.msgSender(), tokenId) {
    //     LibNFT.setBroker(tokenId, poolId, broker, brokeragePercentage);
    // }

    // function brokerOf(
    //     uint256 tokenId,
    //     uint256 poolId
    // ) external view returns (address) {
    //     return LibNFT.brokerOf(tokenId, poolId);
    // }

    // function brokerage(
    //     uint256 tokenId,
    //     uint256 poolId
    // ) external view returns (uint256) {
    //     return LibNFT.brokerage(tokenId, poolId);
    // }

    // function _resetTokenBrokerAge(
    //     uint256 _tokenId,
    //     uint poolId
    // ) external isApprovedOrOwner_(LibMeta.msgSender(), _tokenId) {
    //     LibNFT._resetTokenBrokerAge(_tokenId, poolId);
    // }
}
