/**
  GpioCommandException
  Purpose:
    Thrown when a GPIO shell command fails (gpioset/gpioget).
*/
class GpioCommandException extends RuntimeException {
  GpioCommandException(String message) {
    super(message);
  }

  GpioCommandException(String message, Throwable cause) {
    super(message, cause);
  }
}



