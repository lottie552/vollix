/**
  GpioPinClaimException
  Purpose:
    Thrown when code attempts to claim a GPIO pin that is already claimed.

  Notes:
    - This prevents "two owners for one pin" bugs, which cause confusing behavior
      and resource-busy errors at the Linux GPIO level.
*/
class GpioPinClaimException extends RuntimeException {
  GpioPinClaimException(String message) {
    super(message);
  }
}



