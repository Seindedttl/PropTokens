PropTokens
==========

* * * * *

Table of Contents
-----------------

-   Introduction
-   Features
-   Error Codes
-   Contract Details
    -   Constants
    -   Data Maps and Variables
    -   Private Functions
    -   Public Functions
    -   Read-Only Functions
-   How to Use
-   Contributing
-   License

* * * * *

Introduction
------------

PropTokens is a cutting-edge Clarity smart contract that establishes a **tokenized real estate marketplace**. This contract facilitates **fractional ownership** of real-world assets (specifically real estate) by tokenizing them into fungible tokens. It provides secure mechanisms for asset creation, verification, trading through listings, and robust governance.

I designed this contract to bring transparency, liquidity, and accessibility to the real estate market by leveraging blockchain technology.

Features
--------

-   **Asset Tokenization:** Create unique digital tokens representing real estate properties.
-   **Fractional Ownership:** Enable multiple individuals to own a share of a single property.
-   **Decentralized Marketplace:** Securely list and trade tokenized property shares.
-   **Role-Based Access Control:** Differentiate between contract owners and authorized verifiers for specific functionalities.
-   **Asset Verification:** Implement a verification process to ensure the authenticity of listed properties.
-   **Portfolio Analytics:** Provide detailed insights into a holder's real estate token portfolio.
-   **Secure Transactions:** Utilize Clarity's safety features for reliable STX transfers and token balance updates.

* * * * *

## Error Codes
I've implemented a comprehensive set of error codes to clearly indicate the reason for transaction failures:

| Error Code | Value | Description                          |
| :--------- | :---- | :----------------------------------- |
| `ERR-NOT-AUTHORIZED`     | `u100`  | The transaction sender is not authorized to perform this action. |
| `ERR-ASSET-NOT-FOUND`    | `u101`  | The specified asset ID does not exist.   |
| `ERR-INSUFFICIENT-BALANCE` | `u102`  | The sender has an insufficient token balance for the operation. |
| `ERR-INVALID-AMOUNT`     | `u103`  | The specified amount is invalid (e.g., zero or too low). |
| `ERR-ASSET-NOT-VERIFIED` | `u104`  | The asset has not yet been verified by an authorized verifier. |
| `ERR-ASSET-ALREADY-EXISTS` | `u105`  | An asset with this ID already exists (though not explicitly used in current public functions). |
| `ERR-INVALID-PRICE`      | `u106`  | The specified price is invalid (e.g., zero or negative). |
| `ERR-LISTING-NOT-FOUND`  | `u107`  | The specified listing ID does not exist or is inactive. |
| `ERR-CANNOT-BUY-OWN-LISTING` | `u108`  | A user attempted to buy tokens from their own listing. |

* * * * *

Contract Details
----------------

### Constants

-   `ERR-NOT-AUTHORIZED` (`u100`): Error code for unauthorized actions.
-   `ERR-ASSET-NOT-FOUND` (`u101`): Error code for non-existent assets.
-   `ERR-INSUFFICIENT-BALANCE` (`u102`): Error code for insufficient token balance.
-   `ERR-INVALID-AMOUNT` (`u103`): Error code for invalid amounts.
-   `ERR-ASSET-NOT-VERIFIED` (`u104`): Error code for unverified assets.
-   `ERR-ASSET-ALREADY-EXISTS` (`u105`): Error code for asset already existing.
-   `ERR-INVALID-PRICE` (`u106`): Error code for invalid price.
-   `ERR-LISTING-NOT-FOUND` (`u107`): Error code for non-existent or inactive listings.
-   `ERR-CANNOT-BUY-OWN-LISTING` (`u108`): Error code for attempting to buy from one's own listing.
-   `CONTRACT-OWNER` (`tx-sender`): The address of the contract deployer, who has administrative privileges.
-   `MIN-LISTING-AMOUNT` (`u1`): The minimum allowed amount for a marketplace listing, preventing spam.

### Data Maps and Variables

-   `assets`: A map storing detailed metadata for each tokenized real estate asset.
    -   Keys: `{ asset-id: uint }`
    -   Values: `{ owner: principal, total-supply: uint, verified: bool, property-address: (string-ascii 256), property-type: (string-ascii 64), valuation: uint, created-at: uint }`
-   `token-balances`: Tracks the fractional ownership (token balance) of each asset for specific holders.
    -   Keys: `{ asset-id: uint, holder: principal }`
    -   Values: `{ balance: uint }`
-   `listings`: Stores information about active marketplace listings for asset tokens.
    -   Keys: `{ listing-id: uint }`
    -   Values: `{ seller: principal, asset-id: uint, amount: uint, price-per-token: uint, active: bool, created-at: uint }`
-   `authorized-verifiers`: A map to designate principals who can verify real-world assets.
    -   Keys: `{ verifier: principal }`
    -   Values: `{ authorized: bool }`
-   `next-asset-id`: A data variable (uint) that holds the next available unique ID for new assets, initialized to `u1`.
-   `next-listing-id`: A data variable (uint) that holds the next available unique ID for new listings, initialized to `u1`.
-   `current-portfolio-holder`: A data variable (principal) used internally by portfolio calculation helper functions to temporarily store the holder for whom the portfolio is being calculated.

### Private Functions

I've included several private helper functions to ensure modularity and reusability:

-   `(validate-asset (asset-id uint))`: Checks if an asset exists and is verified. Returns `(ok asset-data)` or an error.
-   `(get-balance-or-default (asset-id uint) (holder principal))`: Retrieves a token balance, defaulting to `u0` if not found.
-   `(update-balance (asset-id uint) (holder principal) (new-balance uint))`: Safely updates a holder's token balance for a specific asset.
-   `(calculate-asset-value-for-holder (asset-id uint) (holder principal))`: Calculates the estimated value of a single asset holding for a given holder.
-   `(get-detailed-holding (asset-id uint) (holder principal))`: Provides a detailed record of a holder's ownership in a specific asset, including percentage and estimated value.
-   `(sum-values (values (list 50 uint)))`: A helper to sum a list of uints.
-   `(is-positive (val uint))`: A predicate function to check if a `uint` is greater than zero.
-   `(get-max (a uint) (b uint))`: Returns the maximum of two `uint` values.
-   `(get-min (a uint) (b uint))`: Returns the minimum of two `uint` values.
-   `(calculate-single-asset-value (asset-id uint))`: Helper for `map` function to calculate asset value using `current-portfolio-holder`.
-   `(get-single-detailed-holding (asset-id uint))`: Helper for `map` function to get detailed holding using `current-portfolio-holder`.

### Public Functions

I've made the following functions available for external interaction:

-   `(create-asset (total-supply uint) (property-address (string-ascii 256)) (property-type (string-ascii 64)) (valuation uint))`:
    -   Creates a new tokenized real estate asset.
    -   **Only `CONTRACT-OWNER` can call this.**
    -   Initializes all tokens to the creator.
    -   Returns the new `asset-id`.
-   `(verify-asset (asset-id uint))`:
    -   Marks an asset as verified.
    -   **Only `authorized-verifiers` can call this.**
    -   Requires the asset to exist.
-   `(add-verifier (verifier principal))`:
    -   Adds a principal to the list of authorized verifiers.
    -   **Only `CONTRACT-OWNER` can call this.**
-   `(create-listing (asset-id uint) (amount uint) (price-per-token uint))`:
    -   Creates a new marketplace listing for asset tokens.
    -   Requires the asset to be verified, the seller to have sufficient balance, and valid amounts/prices.
    -   Returns the new `listing-id`.
-   `(buy-tokens (listing-id uint) (amount uint))`:
    -   Purchases tokens from an active marketplace listing.
    -   Transfers STX from buyer to seller.
    -   Updates token balances for both parties.
    -   Closes the listing if fully purchased or reduces the listed amount.
    -   Prevents buyers from purchasing their own listings.
-   `(calculate-portfolio-value (holder principal) (asset-ids (list 50 uint)))`:
    -   Calculates detailed portfolio analytics for a given holder across a list of asset IDs.
    -   Returns a tuple containing total value, asset count, average value, individual holdings details, portfolio diversity, largest holding, and smallest holding.

### Read-Only Functions

I've also provided several read-only functions for querying contract state without requiring a transaction:

-   `(get-asset (asset-id uint))`: Retrieves the full metadata for a given asset ID.
-   `(get-token-balance (asset-id uint) (holder principal))`: Returns the token balance of a specific holder for an asset.
-   `(get-listing (listing-id uint))`: Retrieves the full details of a marketplace listing.

* * * * *

How to Use
----------

To interact with the PropTokens contract, you'll need a Stacks wallet and access to a Clarity development environment (like the Stacks.js SDK or a Clarity IDE).

1.  **Deployment:** Deploy the contract to the Stacks blockchain. The deployer will automatically be set as the `CONTRACT-OWNER`.
2.  **Asset Creation:** As the `CONTRACT-OWNER`, call `create-asset` to mint new real estate tokens, specifying `total-supply`, `property-address`, `property-type`, and `valuation`.
3.  **Verifier Authorization:** The `CONTRACT-OWNER` should then call `add-verifier` to authorize trusted principals who can verify assets.
4.  **Asset Verification:** An `authorized-verifier` can call `verify-asset` to mark an asset as legitimate, making it eligible for listing.
5.  **Listing Creation:** Holders of tokenized assets can call `create-listing` to put their tokens up for sale, specifying the `asset-id`, `amount` of tokens, and `price-per-token`.
6.  **Token Purchase:** Buyers can call `buy-tokens` with a `listing-id` and the `amount` of tokens they wish to purchase. The required STX will be transferred to the seller.
7.  **Portfolio Review:** Any principal can use `calculate-portfolio-value` to get a comprehensive overview of their real estate token holdings by providing their principal address and a list of asset IDs they hold. You can also use `get-asset`, `get-token-balance`, and `get-listing` to query specific information.

* * * * *

Contributing
------------

I welcome contributions to enhance PropTokens! If you have suggestions for improvements, bug fixes, or new features, please feel free to:

1.  Fork the repository.
2.  Create a new branch for your feature (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

* * * * *

License
-------

This project is licensed under the MIT License. See the `LICENSE` file for more details.
