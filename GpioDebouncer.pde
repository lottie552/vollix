/**
  GpioDebouncer
  Purpose:
    Candy-store capability: debounce a raw boolean signal into a stable boolean.

  Used for:
    - Buttons (bouncy)
    - Reed switches
    - Any digital input that chatters

  How it works:
    - If raw signal changes, start a timer.
    - Only accept the new state if it stays unchanged for debounceMs.

  Notes:
    - Pass in nowMs so callers control time source (millis()).
    - This class is device-agnostic: it does not know what a "button" is.
*/
class GpioDebouncer {
  final int debounceMs;

  boolean stableState = false;
  boolean lastRaw = false;

  int lastRawChangeAtMs = 0;
  boolean hasAnySample = false;

  GpioDebouncer(int debounceMs) {
    this.debounceMs = max(0, debounceMs);
  }

  void reset(boolean initialStableState, int nowMs) {
    stableState = initialStableState;
    lastRaw = initialStableState;
    lastRawChangeAtMs = nowMs;
    hasAnySample = true;
  }

  /** Feed a raw sample. Returns the current stable (debounced) state. */
  boolean update(boolean rawState, int nowMs) {
    if (!hasAnySample) {
      reset(rawState, nowMs);
      return stableState;
    }

    if (rawState != lastRaw) {
      lastRaw = rawState;
      lastRawChangeAtMs = nowMs;
    }

    if (rawState != stableState) {
      if ((nowMs - lastRawChangeAtMs) >= debounceMs) {
        stableState = rawState;
      }
    }

    return stableState;
  }

  boolean stable() {
    return stableState;
  }
}



