/**
 BootState
 Purpose:
 Screenless-ish hardware self-test + wiring validation.
 
 Owns:
 - Startup delay before test begins
 - LED sweep pattern (each LED blinks in sequence)
 - Button validation (each testable button must be pressed alone at least once)
 - Per-button confirmation blink pattern
 - Transition to IdleState when finished
 
 Reads:
 - Debounced button state + edges via PhysicalButton (updated in main gpioDevices loop)
 
 Controls:
 - All LEDs (life LEDs + target LEDs)
 - Boot visual: center dot + adjust icon
 
 Uses (but does not own):
 - App for access to Hardware / VisualLayout / adjustIcon + state switching
 
 Notes:
 - Presses during sweep/confirm are ignored by design.
 - Valid press = exactly one testable button down AND that button justPressed().
 - Targets without a physical button are skipped (LED-only targets are allowed).
 */
class BootState implements IGameState {

  final App app;

  // --- timings (slow enough to SEE) ---
  final int START_DELAY_MS = 2000;  // CHANGED: 2 seconds before starting test

  final int SWEEP_BLINKS_PER_LED = 2;
  final int SWEEP_ON_MS = 500;    // Longer to see
  final int SWEEP_OFF_MS = 300;   // Adjusted
  final int SWEEP_GAP_MS = 200;

  final int CONFIRM_BLINKS = 3;
  final int CONFIRM_ON_MS = 220;
  final int CONFIRM_OFF_MS = 220;

  final int DONE_BLINKS = 2;
  final int DONE_ON_MS = 260;
  final int DONE_OFF_MS = 260;

  // --- phases ---
  static final int PHASE_DELAY = 0;
  static final int PHASE_SWEEP = 1;
  static final int PHASE_WAIT_BUTTONS = 2;
  static final int PHASE_CONFIRM = 3;
  static final int PHASE_DONE = 4;

  int phase = PHASE_DELAY;
  int nextAtMs = 0;

  // --- sweep state ---
  final ArrayList<IndicatorLed> sweepLeds = new ArrayList<IndicatorLed>();
  int sweepLedIndex = 0;
  int sweepBlinkDone = 0;
  boolean sweepOn = false;

  // --- button test set (start + any target buttons) ---
  final ArrayList<PhysicalButton> testButtons = new ArrayList<PhysicalButton>();
  final ArrayList<String> testButtonIds = new ArrayList<String>(); // "start" or targetId ("t1","t2",...)

  final HashMap<String, Boolean> seenById = new HashMap<String, Boolean>();

  // --- confirm blink state ---
  String confirmId = null;
  int confirmBlinkDone = 0;
  boolean confirmOn = false;

  // --- done blink state ---
  int doneBlinkDone = 0;
  boolean doneOn = false;

  BootState(App app) {
    this.app = app;
  }

  @Override
    public void enterGameState() {  // Changed from enter()
    println("=== BootState.enterGameState() ===");

    phase = PHASE_DELAY;
    nextAtMs = millis() + START_DELAY_MS;
    println("  Phase: DELAY, will start hardware test at: " + nextAtMs + "ms");
    println("  Waiting " + (START_DELAY_MS/1000.0) + " seconds before starting test...");

    // Build sweep list: life LEDs then target LEDs (all via lists)
    sweepLeds.clear();
    println("  Life LEDs count: " + app.hardware.lifeLeds.size());
    for (int i = 0; i < app.hardware.lifeLeds.size(); i++) {
      IndicatorLed led = app.hardware.lifeLeds.get(i);
      sweepLeds.add(led);
      println("    Added life LED #" + i + ": " + led.debugName());
    }

    println("  Target LEDs count: " + app.hardware.targetLeds.size());
    for (int i = 0; i < app.hardware.targetLeds.size(); i++) {
      IndicatorLed led = app.hardware.targetLeds.get(i);
      sweepLeds.add(led);
      println("    Added target LED #" + i + ": " + led.debugName());
    }

    println("  Total sweep LEDs: " + sweepLeds.size());

    // DEBUG: Force test LED immediately (optional, for quick testing)
    // if (sweepLeds.size() > 0) {
    //   println("  TEST: Turning on first LED for 1 second...");
    //   sweepLeds.get(0).on();
    //   delay(1000);
    //   sweepLeds.get(0).off();
    // }

    sweepLedIndex = 0;
    sweepBlinkDone = 0;
    sweepOn = false;

    // Build test buttons (skip nulls, skip targets without a button)
    testButtons.clear();
    testButtonIds.clear();
    seenById.clear();

    if (app.hardware.startButton != null) {
      testButtons.add(app.hardware.startButton);
      testButtonIds.add("start");
      seenById.put("start", false);
      println("  Added test button: start");
    }

    for (int i = 0; i < app.hardware.targets.size(); i++) {
      Target t = app.hardware.targets.get(i);
      if (t != null && t.hasButton()) {
        testButtons.add(t.button);
        testButtonIds.add(t.id);
        seenById.put(t.id, false);
        println("  Added test button: " + t.id);
      }
    }

    confirmId = null;
    confirmBlinkDone = 0;
    confirmOn = false;

    doneBlinkDone = 0;
    doneOn = false;

    // Safe baseline
    app.hardware.allLedsOff();
    println("  All LEDs OFF");

    // Small "boot heartbeat" baseline: keep middle life LED on during delay
    if (app.hardware.lifeLeds.size() >= 2) {
      IndicatorLed middleLed = app.hardware.lifeLeds.get(1);
      middleLed.on();
      println("  Middle life LED ON during delay: " + middleLed.debugName());
    }

    println("=== BootState ready ===");
  }

  @Override
    public void update(int nowMs) {
    // Print phase every 1000ms for debugging
    if (nowMs % 1000 < 16) { // Roughly once per second
      println("BootState.update() - Phase: " + phase + ", Time: " + nowMs);
    }

    if (phase == PHASE_DELAY) {
      if (nowMs >= nextAtMs) {
        println("  DELAY COMPLETE, starting HARDWARE TEST SWEEP");
        app.hardware.allLedsOff();
        phase = PHASE_SWEEP;
        nextAtMs = nowMs;
        sweepLedIndex = 0;
        sweepBlinkDone = 0;
        sweepOn = false;
      }
      return;
    }

    if (phase == PHASE_SWEEP) {
      runSweep(nowMs);
      return;
    }

    if (phase == PHASE_CONFIRM) {
      runConfirmBlink(nowMs);
      return;
    }

    if (phase == PHASE_DONE) {
      runDoneBlink(nowMs);
      return;
    }

    if (phase == PHASE_WAIT_BUTTONS) {
      runButtonValidation(nowMs);
      return;
    }
  }

  void runSweep(int nowMs) {
    if (sweepLeds.size() == 0) {
      println("ERROR: No LEDs to sweep!");
      phase = PHASE_WAIT_BUTTONS;
      return;
    }

    if (nowMs < nextAtMs) {
      return; // Wait
    }

    IndicatorLed led = sweepLeds.get(sweepLedIndex);

    if (!sweepOn) {
      // TURN LED ON
      app.hardware.allLedsOff();
      led.on();
      sweepOn = true;
      nextAtMs = nowMs + SWEEP_ON_MS;

      println("SWEEP LED ON: #" + sweepLedIndex + " (" + led.debugName() +
        "), blink " + (sweepBlinkDone+1) + "/" + SWEEP_BLINKS_PER_LED);
    } else {
      // TURN LED OFF
      led.off();
      sweepOn = false;
      sweepBlinkDone++;
      nextAtMs = nowMs + SWEEP_OFF_MS;

      println("SWEEP LED OFF: #" + sweepLedIndex);

      if (sweepBlinkDone >= SWEEP_BLINKS_PER_LED) {
        // Done with this LED
        sweepBlinkDone = 0;
        sweepLedIndex++;
        nextAtMs = nowMs + SWEEP_GAP_MS;

        println("LED complete, moving to next. Index: " + sweepLedIndex + "/" + sweepLeds.size());

        if (sweepLedIndex >= sweepLeds.size()) {
          // ALL LEDs DONE
          app.hardware.allLedsOff();
          println("=== SWEEP COMPLETE ===");

          // Turn on middle life LED for button validation
          if (app.hardware.lifeLeds.size() >= 2) {
            app.hardware.lifeLeds.get(1).on();
          }

          phase = PHASE_WAIT_BUTTONS;
          println("Moving to BUTTON VALIDATION phase");
        }
      }
    }
  }

  void runButtonValidation(int nowMs) {
    // Baseline: life2 on
    app.hardware.targetsOff();
    if (app.hardware.lifeLeds.size() >= 2) app.hardware.lifeLeds.get(1).on();

    // Exclusive press rule
    int downCount = countTestButtonsDown();
    if (downCount != 1) {
      // No "multi press" allowed: remove "help" LEDs
      if (app.hardware.lifeLeds.size() >= 1) app.hardware.lifeLeds.get(app.hardware.lifeLeds.size() - 1).off();
      if (app.hardware.lifeLeds.size() >= 3) app.hardware.lifeLeds.get(0).off();
      return;
    }

    // Find which one is down
    int downIndex = findSingleDownIndex();
    if (downIndex < 0) return;

    String id = testButtonIds.get(downIndex);
    PhysicalButton b = testButtons.get(downIndex);

    // While-held feedback for "not yet seen" buttons only
    boolean alreadySeen = safeSeen(id);

    if (!alreadySeen) {
      showHeldFeedback(id);
    } else {
      clearHeldFeedback();
    }

    // Accept press: must be justPressed AND exclusive
    if (b.justPressed() && !alreadySeen) {
      println("Button VALIDATED: " + id);
      seenById.put(id, true);
      startConfirmBlink(id);
      return;
    }

    // All done?
    if (allSeen()) {
      println("=== ALL BUTTONS VALIDATED ===");
      phase = PHASE_DONE;
      doneBlinkDone = 0;
      doneOn = false;
      nextAtMs = nowMs;
      app.hardware.allLedsOff();
    }
  }

  int countTestButtonsDown() {
    int c = 0;
    for (int i = 0; i < testButtons.size(); i++) {
      if (testButtons.get(i).isDown()) c++;
    }
    return c;
  }

  int findSingleDownIndex() {
    for (int i = 0; i < testButtons.size(); i++) {
      if (testButtons.get(i).isDown()) return i;
    }
    return -1;
  }

  void showHeldFeedback(String id) {
    // Start button feedback: light life1 + life3 (ends)
    if (id.equals("start")) {
      if (app.hardware.lifeLeds.size() >= 3) {
        app.hardware.lifeLeds.get(0).on();                       // life3
        app.hardware.lifeLeds.get(app.hardware.lifeLeds.size()-1).on(); // life1
      }
      return;
    }

    // Target feedback: light that target's LED
    IndicatorLed targetLed = findTargetLedByTargetId(id);
    if (targetLed != null) targetLed.on();
  }

  void clearHeldFeedback() {
    // Clear everything except baseline life2
    app.hardware.targetsOff();
    if (app.hardware.lifeLeds.size() >= 3) {
      app.hardware.lifeLeds.get(0).off();
      app.hardware.lifeLeds.get(app.hardware.lifeLeds.size()-1).off();
    }
  }

  IndicatorLed findTargetLedByTargetId(String targetId) {
    for (int i = 0; i < app.hardware.targets.size(); i++) {
      Target t = app.hardware.targets.get(i);
      if (t != null && t.id.equals(targetId)) return t.led;
    }
    return null;
  }

  void startConfirmBlink(String id) {
    confirmId = id;
    confirmBlinkDone = 0;
    confirmOn = false;
    phase = PHASE_CONFIRM;
    nextAtMs = millis();

    app.hardware.allLedsOff();
    if (app.hardware.lifeLeds.size() >= 2) app.hardware.lifeLeds.get(1).on();
  }

  void runConfirmBlink(int nowMs) {
    if (nowMs < nextAtMs) return;

    if (!confirmOn) {
      app.hardware.allLedsOff();
      if (app.hardware.lifeLeds.size() >= 2) app.hardware.lifeLeds.get(1).on();

      // Blink the "confirmed" thing
      showHeldFeedback(confirmId);

      confirmOn = true;
      nextAtMs = nowMs + CONFIRM_ON_MS;
    } else {
      clearHeldFeedback();

      confirmOn = false;
      confirmBlinkDone++;
      nextAtMs = nowMs + CONFIRM_OFF_MS;

      if (confirmBlinkDone >= CONFIRM_BLINKS) {
        println("Confirm blink done for: " + confirmId);
        phase = PHASE_WAIT_BUTTONS;
        app.hardware.allLedsOff();
        if (app.hardware.lifeLeds.size() >= 2) app.hardware.lifeLeds.get(1).on();
      }
    }
  }

  void runDoneBlink(int nowMs) {
    if (nowMs < nextAtMs) return;

    if (!doneOn) {
      // ON: all LEDs
      println("DONE BLINK ON");
      for (int i = 0; i < app.hardware.lifeLeds.size(); i++) app.hardware.lifeLeds.get(i).on();
      for (int i = 0; i < app.hardware.targetLeds.size(); i++) app.hardware.targetLeds.get(i).on();

      doneOn = true;
      nextAtMs = nowMs + DONE_ON_MS;
    } else {
      app.hardware.allLedsOff();
      println("DONE BLINK OFF");

      doneOn = false;
      doneBlinkDone++;
      nextAtMs = nowMs + DONE_OFF_MS;

      if (doneBlinkDone >= DONE_BLINKS) {
        println("=== TRANSITIONING TO IDLE STATE ===");
        app.hardware.allLedsOff();
        app.gsm.setState(new IdleState(app));
      }
    }
  }

  boolean safeSeen(String id) {
    Boolean v = seenById.get(id);
    if (v == null) return false;
    return v.booleanValue();
  }

  boolean allSeen() {
    for (String key : seenById.keySet()) {
      if (!safeSeen(key)) return false;
    }
    return true;
  }


  @Override
    public void render() {
    background(15, 20, 30);

    // Use layout helper to draw center marker with adjust icon
    app.layout.drawCenterMarkerWithIcon(app.hintIcon);

    // Optional: Show debug grid during development
    // app.layout.drawDebugGrid();

    // Or if you want more control, draw manually:
    // noStroke();
    // fill(255);
    // float r = app.layout.centerRadius();
    // circle(app.layout.center.x, app.layout.center.y, r * 2);
    // shape(app.adjustIcon, app.layout.center.x, app.layout.center.y,
    //       app.layout.iconSize(), app.layout.iconSize());
  }

  @Override
    public void exitGameState() {  // Changed from exit()
    println("=== BootState.exitGameState() ===");
    app.hardware.allLedsOff();
  }
}




