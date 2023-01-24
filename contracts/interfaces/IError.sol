//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IError {
    error LengthsNotEqual();
    error DevelopmentGroundIsLocked();
    error CsIsBellowHundred();
    error NotYourToken();
    error InvalidLockTime();
    error InvalidTokenForThisJob();
    error CsToHigh();
    error CannotClaimNow();

    error BalanceIsInsufficient();
    error TokenNotInDevelopementGround();
    error WrongMultiple();
    error TransferFailed();
    error NeandersmolsIsLocked();
    error ZeroBalanceError();
}
