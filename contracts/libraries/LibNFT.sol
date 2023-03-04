// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {LibFarmFacet} from "./LibFarmFacet.sol";
import {LibDiamond} from "./LibDiamond.sol";
import {Counters} from "./Counters.sol";
import {LibMeta} from "./LibMeta.sol";

library LibNFT {
    using Address for address;
    using Strings for uint256;

    bytes32 constant NFT_STORAGE_POSITION =
        keccak256("diamond.standard.nft.storage");

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    /// Logged when the user of a token assigns a new user or updates expires
    /// @notice Emitted when the `user` of an NFT or the `expires` of the `user` is changed
    /// The zero address for user indicates that there is no user address
    /// Rental Event
    event UpdateUser(
        uint256 indexed tokenId,
        address indexed user,
        uint64 expires
    );

    /// Brokerage Event
    event UpdateBroker(
        uint256 indexed tokenId,
        uint256 poolId,
        address indexed broker,
        uint256 brokerage
    );

    //Royalty
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    //Rental
    struct UserInfo {
        address user; // address of user role
        uint64 expires; // unix timestamp, user expires
    }

    // //Brokerage
    // struct BrokerInfo {
    //     address broker;
    //     uint256 brokerPercentage;
    // }

    struct NFTStorage {
        
        /*-------------------------------ERC721 NORMAL STORAGE------------------------------------*/

        // Token name
        string _name;
        // Token symbol
        string _symbol;
        // Base Uri
        string _baseUri;
        // Mapping from token ID to owner address
        mapping(uint256 => address) _owners;
        // Mapping owner address to token count
        mapping(address => uint256) _balances;
        // Mapping from token ID to approved address
        mapping(uint256 => address) _tokenApprovals;
        // Mapping from owner to operator approvals
        mapping(address => mapping(address => bool)) _operatorApprovals;
        
        /*----------------------------ERC721 ENUMERABLE STORAGE------------------------------------*/

        // Mapping from owner to list of owned token IDs
        mapping(address => mapping(uint256 => uint256)) _ownedTokens;
        // Mapping from token ID to index of the owner tokens list
        mapping(uint256 => uint256) _ownedTokensIndex;
        // Array with all token ids, used for enumeration
        uint256[] _allTokens;
        // Mapping from token id to position in the allTokens array
        mapping(uint256 => uint256) _allTokensIndex;

        // /*-------------------------------ERC2981 (ROYALTY) STORAGE--------------------------------*/

        // //minter of the NFT
        // mapping(uint256 => address) initialOwner;
        // //default royalty info for every new NFT
        // RoyaltyInfo _defaultRoyaltyInfo;
        // //current royalty info
        // mapping(uint256 => RoyaltyInfo) _tokenRoyaltyInfo;

        // /*-------------------------------EIP4907 (RENTING) STORAGE--------------------------------*/

        // //current renter info of given NFT
        // mapping(uint256 => UserInfo) _users;
        
        // /*-------------------------------(BROKERAGE) STORAGE--------------------------------*/
        
        // //Broker Info for NFTID -> POOL ID -> INFO
        // mapping(uint256 => mapping(uint => BrokerInfo)) brokerInfo;
    }

    function nftStorage() internal pure returns (NFTStorage storage ns) {
        bytes32 position = NFT_STORAGE_POSITION;
        assembly {
            ns.slot := position
        }
    }

    function initialize(string memory name_, string memory symbol_) internal {
        NFTStorage storage ns = nftStorage();
        ns._name = name_;
        ns._symbol = symbol_;
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        NFTStorage storage ns = nftStorage();
        return ns._owners[tokenId] != address(0);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) internal view returns (uint256) {
        require(
            owner != address(0),
            "ERC721: address zero is not a valid owner"
        );
        LibNFT.NFTStorage storage ns = nftStorage();
        return ns._balances[owner];
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) internal view returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view returns (string memory) {
        NFTStorage storage ns = nftStorage();
        return ns._baseUri;
    }

    function setBaseUri(string memory _newBaseUri) internal {
        NFTStorage storage ns = nftStorage();
        ns._baseUri = _newBaseUri;
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) internal view returns (address) {
        NFTStorage storage ns = nftStorage();
        address owner = ns._owners[tokenId];
        require(
            owner != address(0),
            "ERC721: owner query for nonexistent token"
        );
        return owner;
    }

    function currId() internal view returns (uint tokenId) {
        tokenId = Counters.current();
    }

    // function initialOwner(uint256 tokenId) internal view returns (address) {
    //     NFTStorage storage ns = nftStorage();
    //     return ns.initialOwner[tokenId];
    // }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) internal view returns (bool) {
        NFTStorage storage ns = nftStorage();
        return ns._operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) internal view returns (address) {
        require(
            _exists(tokenId),
            "ERC721: approved query for nonexistent token"
        );
        NFTStorage storage ns = nftStorage();
        return ns._tokenApprovals[tokenId];
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
    ) internal view returns (bool) {
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
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");
        NFTStorage storage ns = nftStorage();
        _beforeTokenTransfer(address(0), to, tokenId);
              
        ns._balances[to] += 1;
        ns._owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal {
        address owner = ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);
        NFTStorage storage ns = nftStorage();
        ns._balances[owner] -= 1;
        delete ns._owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        require(
            ownerOf(tokenId) == from,
            "ERC721: transfer from incorrect owner"
        );
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);
        NFTStorage storage ns = nftStorage();

        ns._balances[from] -= 1;
        ns._balances[to] += 1;
        ns._owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal {
        NFTStorage storage ns = nftStorage();
        ns._tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal {
        require(owner != operator, "ERC721: approve to caller");
        NFTStorage storage ns = nftStorage();
        ns._operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try
                IERC721Receiver(to).onERC721Received(
                    LibMeta.msgSender(),
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {}

    //withdraw criteria 0 for time and 1 for price
    function safeMint(address to) internal returns (uint tokenId) {
        tokenId = Counters.current();
        Counters.increment();
        _safeMint(to, tokenId);
        return tokenId;
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        LibNFT.NFTStorage storage ns = nftStorage();

        /**
         * DEPENDENCIES:-
         * ROYALTY --> (MINT AND BURN)
         * RENTING -->  
         * BROKERAGE
         */

        if (from == address(0)) {

            /*----------------------------------------MINTING-----------------------------------*/

            // //SET INITIAL OWNER
            // ns.initialOwner[tokenId] = to;

            //ADD TOKEN ID TO ALL TOKENS
            _addTokenToAllTokensEnumeration(tokenId);


        } 
        else if (from != to) {

            /*-----------------------------------BURNING OR TRANSFER------------------------------*/

            //REMOVE TOKEN ID FROM OWNER TOKENS
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }

        if (to == address(0)) {

            /*------------------------------------------BURNING-----------------------------------*/
            
            // //DELETE INITIAL OWNER
            // delete ns.initialOwner[tokenId];
            
            // //RESET TOKEN ROYALTY
            // _resetTokenRoyalty(tokenId);

            //REMOVE TOKEN ID FROM ALL TOKENS
            _removeTokenFromAllTokensEnumeration(tokenId);

        } 
        else if (to != from) {

            /*------------------------------------------MINTING OR TRANSFER-----------------------------------*/
            
            //ADD TOKEN ID TO OWNER TOKENS
            _addTokenToOwnerEnumeration(to, tokenId);

        }

        // //reset rental parameters
        // if (from != to && ns._users[tokenId].user != address(0)) {
        //     delete ns._users[tokenId];
        //     emit UpdateUser(tokenId, address(0), 0);
        // }
    }

    function tokensOfOwner(
        address owner
    ) internal view returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](balanceOf(owner));
        LibNFT.NFTStorage storage ns = nftStorage();
        for (uint256 i = 0; i < balanceOf(owner); i++) {
            ids[i] = ns._ownedTokens[owner][i];
        }
        return ids;
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = balanceOf(to);
        LibNFT.NFTStorage storage ns = nftStorage();
        ns._ownedTokens[to][length] = tokenId;
        ns._ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        LibNFT.NFTStorage storage ns = nftStorage();
        ns._allTokensIndex[tokenId] = ns._allTokens.length;
        ns._allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(
        address from,
        uint256 tokenId
    ) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).
        LibNFT.NFTStorage storage ns = nftStorage();
        uint256 lastTokenIndex = balanceOf(from) - 1;
        uint256 tokenIndex = ns._ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ns._ownedTokens[from][lastTokenIndex];

            ns._ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            ns._ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete ns._ownedTokensIndex[tokenId];
        delete ns._ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        LibNFT.NFTStorage storage ns = nftStorage();
        uint256 lastTokenIndex = ns._allTokens.length - 1;
        uint256 tokenIndex = ns._allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = ns._allTokens[lastTokenIndex];

        ns._allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        ns._allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete ns._allTokensIndex[tokenId];
        ns._allTokens.pop();
    }

    //ERC2981 (Royalty Standard)

    // function royaltyInfo(
    //     uint256 _tokenId,
    //     uint256 _salePrice
    // ) internal view returns (address, uint256) {
    //     LibNFT.NFTStorage storage ns = nftStorage();
    //     RoyaltyInfo memory royalty = ns._tokenRoyaltyInfo[_tokenId];

    //     if (royalty.receiver == address(0)) {
    //         royalty = ns._defaultRoyaltyInfo;
    //     }

    //     uint256 royaltyAmount = (_salePrice * royalty.royaltyFraction) /
    //         _feeDenominator();

    //     return (royalty.receiver, royaltyAmount);
    // }

    // /**
    //  * @dev The denominator with which to interpret the fee set in {_setTokenRoyalty} and {_setDefaultRoyalty} as a
    //  * fraction of the sale price. Defaults to 10000 so fees are expressed in basis points, but may be customized by an
    //  * override.
    //  */
    // function _feeDenominator() internal pure returns (uint96) {
    //     return 10000;
    // }

    // /**
    //  * @dev Sets the royalty information that all ids in this contract will default to.
    //  *
    //  * Requirements:
    //  *
    //  * - `receiver` cannot be the zero address.
    //  * - `feeNumerator` cannot be greater than the fee denominator.
    //  */
    // function _setDefaultRoyalty(
    //     address receiver,
    //     uint96 feeNumerator
    // ) internal {
    //     LibNFT.NFTStorage storage ns = nftStorage();
    //     require(
    //         feeNumerator <= _feeDenominator(),
    //         "ERC2981: royalty fee will exceed salePrice"
    //     );
    //     require(receiver != address(0), "ERC2981: invalid receiver");

    //     ns._defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    // }

    // /**
    //  * @dev Removes default royalty information.
    //  */
    // function _deleteDefaultRoyalty() internal {
    //     LibNFT.NFTStorage storage ns = nftStorage();
    //     delete ns._defaultRoyaltyInfo;
    // }

    // /**
    //  * @dev Sets the royalty information for a specific token id, overriding the global default.
    //  *
    //  * Requirements:
    //  *
    //  * - `receiver` cannot be the zero address.
    //  * - `feeNumerator` cannot be greater than the fee denominator.
    //  */
    // function _setTokenRoyalty(
    //     uint256 tokenId,
    //     address receiver,
    //     uint96 feeNumerator
    // ) internal {
    //     LibNFT.NFTStorage storage ns = nftStorage();
    //     require(
    //         feeNumerator <= _feeDenominator(),
    //         "ERC2981: royalty fee will exceed salePrice"
    //     );
    //     require(receiver != address(0), "ERC2981: Invalid parameters");

    //     ns._tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    // }

    // /**
    //  * @dev Resets royalty information for the token id back to the global default.
    //  */
    // function _resetTokenRoyalty(uint256 tokenId) internal {
    //     LibNFT.NFTStorage storage ns = nftStorage();
    //     delete ns._tokenRoyaltyInfo[tokenId];
    // }

    // //EIP-4907 (Renting Standard)

    // /// @notice set the user and expires of a NFT
    // /// @dev The zero address indicates there is no user
    // /// Throws if `tokenId` is not valid NFT
    // /// @param user  The new user of the NFT
    // /// @param expires  UNIX timestamp, The new user could use the NFT before expires
    // function setUser(uint256 tokenId, address user, uint64 expires) internal {
    //     LibNFT.NFTStorage storage ns = nftStorage();
    //     UserInfo storage info = ns._users[tokenId];
    //     info.user = user;
    //     info.expires = expires;
    //     emit UpdateUser(tokenId, user, expires);
    // }

    // /// @notice Get the user address of an NFT
    // /// @dev The zero address indicates that there is no user or the user is expired
    // /// @param tokenId The NFT to get the user address for
    // /// @return The user address for this NFT
    // function userOf(uint256 tokenId) internal view returns (address) {
    //     LibNFT.NFTStorage storage ns = nftStorage();
    //     if (uint256(ns._users[tokenId].expires) >= block.timestamp) {
    //         return ns._users[tokenId].user;
    //     } else {
    //         return address(0);
    //     }
    // }

    // /// @notice Get the user expires of an NFT
    // /// @dev The zero value indicates that there is no user
    // /// @param tokenId The NFT to get the user expires for
    // /// @return The user expires for this NFT
    // function userExpires(uint256 tokenId) internal view returns (uint256) {
    //     LibNFT.NFTStorage storage ns = nftStorage();
    //     return ns._users[tokenId].expires;
    // }

    // //Brokerage

    // /// @notice set the broker and brokerage percentage
    // /// @dev The zero address indicates there is no user
    // /// Throws if `tokenId` is not valid NFT
    // /// @param tokenId  NFT ID
    // /// @param poolId  POOL ID
    // /// @param broker  The new broker of the NFT
    // /// @param brokeragePercentage  brokerage pecentage offered to broker
    // function setBroker(
    //     uint256 tokenId,
    //     uint256 poolId,
    //     address broker,
    //     uint256 brokeragePercentage
    // ) internal {
    //     require(
    //         brokeragePercentage < 10000,
    //         "Brokerage should be less than 10000"
    //     );

    //     LibNFT.NFTStorage storage ns = nftStorage();
    //     BrokerInfo storage info = ns.brokerInfo[tokenId][poolId];
    //     info.broker = broker;
    //     info.brokerPercentage = brokeragePercentage;
    //     emit UpdateBroker(tokenId, poolId, broker, brokeragePercentage);
    // }

    // /// @notice Get the user address of an NFT
    // /// @dev The zero address indicates that there is no user or the user is expired
    // /// @param tokenId The NFT to get the user address for
    // /// @return The user address for this NFT
    // function brokerOf(
    //     uint256 tokenId,
    //     uint256 poolId
    // ) internal view returns (address) {
    //     LibNFT.NFTStorage storage ns = nftStorage();
    //     return ns.brokerInfo[tokenId][poolId].broker;
    // }

    // /// @notice Get the user expires of an NFT
    // /// @dev The zero value indicates that there is no user
    // /// @param tokenId The NFT to get the user expires for
    // /// @return The user expires for this NFT
    // function brokerage(
    //     uint256 tokenId,
    //     uint256 poolId
    // ) internal view returns (uint256) {
    //     LibNFT.NFTStorage storage ns = nftStorage();
    //     return ns.brokerInfo[tokenId][poolId].brokerPercentage;
    // }

    // function _resetTokenBrokerAge(uint256 tokenId, uint256 poolId) internal {
    //     LibNFT.NFTStorage storage ns = nftStorage();
    //     require(
    //         brokerOf(tokenId, poolId) != address(0),
    //         "No broker assigned yet"
    //     );
    //     delete ns.brokerInfo[tokenId][poolId];
    // }
}
