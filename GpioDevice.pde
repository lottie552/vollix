/**
  GpioDevice
  Purpose:
    GPIO equivalent of your CanAnimate interface.

    A GpioDevice is a runtime-managed thing that may need per-frame updates
    (e.g., buttons for debouncing/edge detection) and must be able to clean up
    its OS-level resources on shutdown.

  Owned by:
    - GpioRuntime (keeps a list of devices and calls update/shutdown)

  Notes:
    - Outputs (LEDs) usually do nothing in update(), but still implement
      GpioDevice so they can reliably release gpioset ownership on shutdown.
    - Inputs (Buttons) do their debouncing + edge tracking inside update().
*/
interface GpioDevice {
  /** Called once per frame by GpioRuntime. */
  void update();

  /** Called when the sketch exits or hardware is being reset. Must free resources. */
  void shutdown();
}






