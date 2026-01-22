/**
  GpioEdgeTracker
  Purpose:
    Candy-store capability: detect rising/falling edges from a stable boolean signal.

  Exposes:
    - justActivated: false -> true transition (one frame)
    - justDeactivated: true -> false transition (one frame)

  Notes:
    - Device-agnostic: does not know what a "button" is.
    - Call update(stableState) once per frame.
*/
class GpioEdgeTracker {
  boolean justActivated = false;
  boolean justDeactivated = false;

  boolean previous = false;
  boolean hasPrevious = false;

  void reset(boolean initialState) {
    previous = initialState;
    hasPrevious = true;
    justActivated = false;
    justDeactivated = false;
  }

  void update(boolean currentState) {
    justActivated = false;
    justDeactivated = false;

    if (!hasPrevious) {
      previous = currentState;
      hasPrevious = true;
      return;
    }

    if (!previous && currentState) justActivated = true;
    if (previous && !currentState) justDeactivated = true;

    previous = currentState;
  }
}




