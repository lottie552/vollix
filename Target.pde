/**
  Target
  Purpose:
    A single playable game target consisting of:
      - Unique identifier (e.g., "t1", "t2")
      - Group ("LEFT" or "RIGHT") for foot-visual mapping
      - LED indicator (required)
      - Physical button (optional; some targets may be LED-only)

  Used by:
    - Hardware class (creates targets from pin table)
    - Game state logic (reacting to presses, controlling LEDs)

  Note:
    - "LEFT" group uses right foot visual (right foot steps on left target).
    - "RIGHT" group uses left foot visual (left foot steps on right target).
*/
class Target {
  final String id;
  final String group;       // "LEFT" or "RIGHT" exactly
  final IndicatorLed led;
  final PhysicalButton button; // may be null for LED-only targets

  /*
    Create a target with LED and optional button.
    - id: logical identifier like "t1"
    - group: "LEFT" or "RIGHT" (must match these strings exactly)
    - led: the target's indicator LED (required)
    - button: the target's button; null if target is LED-only
  */
  Target(String id, String group, IndicatorLed led, PhysicalButton button) {
    this.id = id;
    this.group = group;
    this.led = led;
    this.button = button;
  }

  // Turn the target LED on or off.
  void setLed(boolean on) {
    led.set(on);
  }

  // Convenience: turn LED on. 
  void on() {
    led.on();
  }

  // Convenience: turn LED off. 
  void off() {
    led.off();
  }

  //Returns true if this target has a physical button. 
  boolean hasButton() {
    return button != null;
  }

  //Returns true if the button is currently pressed (or false if no button). 
  boolean isPressed() {
    return hasButton() ? button.isDown() : false;
  }

  //Returns true if the button was just pressed this frame (false if no button). 
  boolean justPressed() {
    return hasButton() ? button.justPressed() : false;
  }

  //Returns true if the button was just released this frame (false if no button). 
  boolean justReleased() {
    return hasButton() ? button.justReleased() : false;
  }

  /*Returns true if this target should use the right-foot visual.
    Logic: "LEFT" target ⇒ right foot visual (true)
    "RIGHT" target ⇒ left foot visual (false)
  */
  boolean usesRightFootVisual() {
    return group.equals("LEFT");
  }

  //Helpful debug string. 
  String toString() {
    return String.format(
      "Target[id=%s, group=%s, hasButton=%b]",
      id, group, hasButton()
    );
  }
}



