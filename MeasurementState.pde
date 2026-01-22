/**
  MeasurementState - Reaction Speed Diagnostic

  This state implements a simplified playing sequence used to
  measure reaction times for tennis footwork training.  It reuses the
  calibrated target positions from VisualLayout but does not enforce
  lives, levels or timeouts.  A measurement run consists of three
  metadata input steps followed by exactly 10 cues.  Each cue shows
  one of the target foot positions; the reaction time is recorded
  when the correct physical button is pressed.  After 10 trials the
  run ends and the results are stored in App.measurementLog.

  Keyboard input during metadata entry:
    - Step 1 (life LED 3 ON): subject ID input via number keys 0-9.
      Enter confirms if at least one digit has been entered; Delete
      clears the entire input.
    - Step 2 (life LED 2 ON): measurement moment.  'B' sets
      the measurement_moment to "before" and 'A' sets it to "after".
      Enter confirms once a choice has been made.
    - Step 3 (life LED 1 ON): test condition.  'G' sets
      the test_condition to "game" (prototype) and 'R' sets it to "real".
      Enter confirms once a choice has been made.

  Aborting: A double-click of the start button at any time exits
  MeasurementState immediately.  If metadata has been confirmed and
  a row has been added to the measurement log, it is removed on
  abort.  Afterwards the state returns to IdleState.

  At the end of a measurement run, all LEDs blink twice and the
  state returns to IdleState.
*/
class MeasurementState implements IGameState {
  final App app;

  // Phases for measurement state
  static final int PHASE_INPUT = 0;   // collecting metadata
  static final int PHASE_RETURN = 1;  // showing only center marker between cues
  static final int PHASE_CUE = 2;     // cue is active awaiting correct press
  static final int PHASE_FINISH = 3;  // blinking end and returning to idle
  int phase = PHASE_INPUT;

  // Metadata entry step (1=subject,2=moment,3=condition,4=finished)
  int metadataStep = 1;
  String subjectBuffer = "";
  int subjectId = 0;
  boolean testDone = false; // false = before, true = after
  boolean usedGame = false; // false = real, true = game/prototype
  boolean metadataLocked = false;

  // Measurement run variables
  int trialIndex = 0;               // number of completed trials (0-10)
  Target currentTarget = null;
  int cueStartMs = 0;
  int returnEndMs = 0;
  int returnDurationMs = 500;       // time between cues (ms)
  float[] reactionTimes = new float[10];
  TableRow measurementRow = null;

  // Keyboard just-pressed tracking (to detect edges)
  boolean[] prevKeyStates = new boolean[256];
  boolean[] prevKeyCodeStates = new boolean[256];

  // Start button double-click detection for abort
  int startClickCount = 0;
  int lastStartClickMs = 0;
  final int DOUBLE_CLICK_MS = 500;

  MeasurementState(App app) {
    this.app = app;
  }

  @Override
  public void enterGameState() {
    println("=== MeasurementState.enterGameState() ===");
    phase = PHASE_INPUT;
    metadataStep = 1;
    subjectBuffer = "";
    subjectId = 0;
    testDone = false;
    usedGame = false;
    metadataLocked = false;
    trialIndex = 0;
    currentTarget = null;
    // ensure measurement log exists
    app.initMeasurementLog();
    // Create a new row immediately so it can be removed even if metadata is not confirmed yet
    measurementRow = app.measurementLog.addRow();
    // turn off all LEDs and show nothing
    app.hardware.allLedsOff();
    // Set life LED indicator to subject entry (life LED 3)
    updateLifeLedIndicator();
    println("  Ready for subject input (digits 0-9). Enter to confirm, Delete to clear");
  }

  @Override
  public void update(int nowMs) {
    // Check for panic (double-click) abort
    checkPanicExit(nowMs);

    switch (phase) {
      case PHASE_INPUT:
        handleMetadataInput();
        break;
      case PHASE_RETURN:
        // Wait until return time is over then start next cue or finish
        if (nowMs >= returnEndMs) {
          if (trialIndex >= 10) {
            // Completed all trials; finish measurement
            finishMeasurement();
          } else {
            startNextCue();
          }
        }
        break;
      case PHASE_CUE:
        // Check for correct button press; ignore wrong-target presses
        if (currentTarget != null && currentTarget.hasButton() && currentTarget.justPressed()) {
          recordReaction();
        }
        break;
      case PHASE_FINISH:
        // nothing to do; we immediately transition to idle in finishMeasurement()
        break;
    }
    // Update previous key states after processing
    updatePrevKeyStates();
  }

  @Override
  public void render() {
    // Dark floor background
    background(5, 10, 20);
    // Draw center marker always
    drawCenterMarker();
    // If cue is active, draw foot guide
    if (phase == PHASE_CUE && currentTarget != null) {
      drawFootGuide();
    }
  }

  @Override
  public void exitGameState() {
    println("=== MeasurementState.exitGameState() ===");
    // Turn off LEDs when exiting
    app.hardware.allLedsOff();
  }

  // -------------------------------------------------------------------
  // Metadata input handling
  // -------------------------------------------------------------------
  void handleMetadataInput() {
    // Step 1: subject ID (life LED3)
    if (metadataStep == 1) {
      // Digit keys 0-9: append to buffer
      for (char c = '0'; c <= '9'; c++) {
        if (keyJustPressed(c)) {
          subjectBuffer += c;
          println("  Subject ID buffer: " + subjectBuffer);
        }
      }
      // Delete key clears buffer (use BACKSPACE or DELETE keycode)
      if (keyCodeJustPressed(DELETE) || keyCodeJustPressed(BACKSPACE)) {
        subjectBuffer = "";
        println("  Subject ID cleared");
      }
      // Enter confirms if at least one digit typed
      if (enterJustPressed()) {
        if (subjectBuffer.length() > 0) {
          try {
            subjectId = Integer.parseInt(subjectBuffer);
            metadataStep = 2;
            println("  Subject ID confirmed: " + subjectId);
            updateLifeLedIndicator();
          } catch (Exception e) {
            println("  Invalid subject ID: " + subjectBuffer);
            subjectBuffer = "";
          }
        } else {
          println("  Subject ID empty; please enter digits");
        }
      }
    }
    // Step 2: test condition (life LED2)
    else if (metadataStep == 2) {
      // G or g sets usedGame flag
      if (keyJustPressed('G') || keyJustPressed('g')) {
        usedGame = true;
        println("  Test condition set to PROTOTYPE/GAME");
      }
      if (keyJustPressed('R') || keyJustPressed('r')) {
        usedGame = false;
        println("  Test condition set to REAL");
      }
      // Enter confirms test condition
      if (enterJustPressed()) {
        metadataStep = 3;
        println("  Test condition confirmed: " + (usedGame ? "PROTOTYPE/GAME" : "REAL"));
        updateLifeLedIndicator();
      }
    }
    // Step 3: measurement moment (life LED1)
    else if (metadataStep == 3) {
      // B or A set testDone flag
      if (keyJustPressed('B') || keyJustPressed('b')) {
        testDone = false;
        println("  Measurement moment set to BEFORE");
      }
      if (keyJustPressed('A') || keyJustPressed('a')) {
        testDone = true;
        println("  Measurement moment set to AFTER");
      }
      // Enter confirms measurement moment and finalizes metadata
      if (enterJustPressed()) {
        metadataStep = 4;
        finalizeMetadata();
      }
    }
  }

  // Lock metadata into measurement log and prepare for first cue
  void finalizeMetadata() {
    if (metadataLocked) return;
    metadataLocked = true;
    println("  Metadata confirmed: subject=" + subjectId + ", measurement_moment=" + (testDone ? "after" : "before") + ", test_condition=" + (usedGame ? "game" : "real"));
    // Use existing row created on state entry
    TableRow row = measurementRow;
    if (row == null) {
      // Fallback: create a new row if somehow missing
      row = app.measurementLog.addRow();
      measurementRow = row;
    }
    // datetime: real timestamp
    String ts = nf(year(), 4) + "-" + nf(month(), 2) + "-" + nf(day(), 2) + " " + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
    row.setString("datetime", ts);
    row.setInt("subject_id", subjectId);
    // Store measurement moment and test condition as strings rather than booleans
    row.setString("measurement_moment", testDone ? "after" : "before");
    row.setString("test_condition", usedGame ? "game" : "real");
    // Initialize rt columns to empty string; they will be set after each cue
    for (int i = 1; i <= 10; i++) {
      row.setString("rt" + i, "");
    }
    // Blink all LEDs twice to signal metadata lock (blocking)
    blinkAllLedsBlocking(2);
    // After blink, turn off all LEDs to prepare for the first cue
    app.hardware.allLedsOff();
    // Schedule first return (gives the player time to prepare)
    phase = PHASE_RETURN;
    trialIndex = 0;
    returnEndMs = millis() + returnDurationMs;
    println("  Starting measurement trials");
  }

  // Start a new cue: choose random target and turn its LED on
  void startNextCue() {
    // Select random target from available list
    ArrayList<Target> allTargets = app.hardware.targets;
    if (allTargets.size() == 0) {
      println("ERROR: No targets available for MeasurementState");
      finishMeasurement();
      return;
    }
    int idx = (int)random(allTargets.size());
    currentTarget = allTargets.get(idx);
    // Turn off all LEDs and show lives indicator off (we only use life leds for metadata)
    app.hardware.allLedsOff();
    // Turn on current target's LED
    currentTarget.on();
    // Record cue start time
    cueStartMs = millis();
    phase = PHASE_CUE;
    println("  Cue " + (trialIndex+1) + ": target " + currentTarget.id);
  }

  // Record reaction time and transition to return phase
  void recordReaction() {
    // Compute reaction time in milliseconds
    int rt = millis() - cueStartMs;
    if (trialIndex < 10) {
      reactionTimes[trialIndex] = rt;
      if (measurementRow != null) {
        measurementRow.setInt("rt" + (trialIndex + 1), rt);
      }
      println("  Reaction time for cue " + (trialIndex+1) + ": " + rt + "ms");
    }
    // Turn off current target LED
    currentTarget.off();
    // Increment trial counter
    trialIndex++;
    // Set return phase
    returnEndMs = millis() + returnDurationMs;
    phase = PHASE_RETURN;
  }

  // Finish measurement: blink LEDs and return to IdleState
  void finishMeasurement() {
    println("  Measurement complete. Saving results.");
    // Blink all LEDs twice (blocking)
    blinkAllLedsBlocking(2);
    // After blink, transition to IdleState.  Because the blink is blocking,
    // the LEDs will remain off when the idle state takes over.  IdleState's
    // enterGameState() will turn the life LEDs back on.
    phase = PHASE_FINISH;
    app.gsm.setState(new IdleState(app));
  }

  // Update life LED indicator based on current metadata step
  void updateLifeLedIndicator() {
    // Turn off all life LEDs
    for (int i = 0; i < app.hardware.lifeLeds.size(); i++) {
      app.hardware.lifeLeds.get(i).off();
    }
    // Step 1 -> life3 (index 0), Step 2 -> life2 (index 1), Step 3 -> life1 (index 2)
    if (metadataStep == 1 && app.hardware.lifeLeds.size() >= 3) {
      app.hardware.lifeLeds.get(0).on();
    } else if (metadataStep == 2 && app.hardware.lifeLeds.size() >= 3) {
      app.hardware.lifeLeds.get(1).on();
    } else if (metadataStep == 3 && app.hardware.lifeLeds.size() >= 3) {
      app.hardware.lifeLeds.get(2).on();
    }
  }

  // Blink all target and life LEDs a given number of times
  /**
   * Blink all target and life LEDs a given number of times synchronously.
   * This implementation blocks the current thread while blinking so that
   * subsequent state changes happen after the blink completes.  Using
   * delay() here ensures that the blink timing is consistent with
   * Processing's frame loop and avoids a background thread that might
   * interfere with other states.
   */
  void blinkAllLedsBlocking(int blinks) {
    for (int i = 0; i < blinks; i++) {
      // Turn all LEDs on (eye closed)
      for (Target t : app.hardware.targets) {
        if (t != null) t.on();
      }
      for (IndicatorLed led : app.hardware.lifeLeds) {
        if (led != null) led.on();
      }
      delay(200);
      // Turn all LEDs off (eye open)
      for (Target t : app.hardware.targets) {
        if (t != null) t.off();
      }
      for (IndicatorLed led : app.hardware.lifeLeds) {
        if (led != null) led.off();
      }
      delay(200);
    }
  }

  // Check for double-click abort: similar to PlayingState panic exit
  void checkPanicExit(int nowMs) {
    PhysicalButton startBtn = app.hardware.startButton;
    if (startBtn == null) return;
    if (startBtn.justPressed()) {
      // Double-click detected?
      if (nowMs - lastStartClickMs < DOUBLE_CLICK_MS) {
        println("=== MeasurementState PANIC EXIT: Double-click detected ===");
        // Abort measurement: remove the last row if a row was added.
        // The measurementRow is always the most recently added row because
        // we add a new row when entering MeasurementState and only start
        // a new run after finishing or aborting the current one.  The
        // Processing Table API only accepts an int row index for
        // removeRow(), so compute the last index as getRowCount() - 1
        // instead of passing the TableRow object directly.
        if (measurementRow != null) {
          int lastIndex = app.measurementLog.getRowCount() - 1;
          if (lastIndex >= 0) {
            app.measurementLog.removeRow(lastIndex);
            println("  Measurement aborted: removed measurement row");
          }
          measurementRow = null;
        }
        // Return to IdleState
        app.gsm.setState(new IdleState(app));
        return;
      }
      lastStartClickMs = nowMs;
      startClickCount = 1;
    }
    // Reset click count if time passes
    if (startClickCount > 0 && (nowMs - lastStartClickMs) >= DOUBLE_CLICK_MS) {
      startClickCount = 0;
    }
  }

  // Draw the center marker: same as PlayingState
  void drawCenterMarker() {
    noStroke();
    fill(255);
    float r = app.layout.centerRadius() * 0.8;
    circle(app.layout.center.x, app.layout.center.y, r * 2);
  }

  // Draw foot cue at currentTarget's calibrated position
  void drawFootGuide() {
    if (currentTarget == null) return;
    // Determine target index
    int idx = app.hardware.targets.indexOf(currentTarget);
    PVector pos = app.layout.getTargetPosition(idx);
    if (pos == null) pos = app.layout.center.copy();
    // Choose icon based on group: same mapping as PlayingState
    PShape footIcon;
    if (currentTarget.group.equals("LEFT")) {
      // LEFT target → RIGHT foot icon (cupcake)
      footIcon = app.cupcakeIcon;
    } else if (currentTarget.group.equals("RIGHT")) {
      // RIGHT target → LEFT foot icon (candy)
      footIcon = app.candyIcon;
    } else {
      footIcon = app.candyIcon;
    }
    // Get rotation
    float rotation = app.layout.getTargetRotation(idx);
    pushMatrix();
    translate(pos.x, pos.y);
    rotate(rotation);
    // Tint white semi-transparent during cue
    tint(255, 230);
    // Draw the foot cue with aspect ratio preserved.  The SVG files
    // Foot L.svg and Foot R.svg have dimensions 1800pt x 1014pt,
    // giving a height ratio of 1014/1800 ≈ 0.5633.  Use a fixed width
    // and compute height from that ratio to avoid distortion.
    // Scale foot guide based on calibration values.  Retrieve the target-specific
    // scale factor from VisualLayout so that measurement cues respect calibration.
    float baseFootWidth = 80;
    float scaleFactor = app.layout.getTargetScale(idx);
    float footWidth = baseFootWidth * scaleFactor;
    float footHeight = footWidth * (1014.0f / 1800.0f);
    shapeMode(CENTER);
    shape(footIcon, 0, 0, footWidth, footHeight);
    noTint();
    popMatrix();
  }

  // Helper: detect if a char key has just been pressed
  boolean keyJustPressed(char c) {
    // Use global keyStates array from main sketch
    boolean isDown = isKeyPressed(c);
    int code = (int)c;
    boolean wasDown = false;
    if (code >= 0 && code < prevKeyStates.length) {
      wasDown = prevKeyStates[code];
    }
    return isDown && !wasDown;
  }

  // Helper: detect if a keyCode has just been pressed
  boolean keyCodeJustPressed(int kc) {
    boolean isDown = isKeyCodePressed(kc);
    boolean wasDown = false;
    if (kc >= 0 && kc < prevKeyCodeStates.length) {
      wasDown = prevKeyCodeStates[kc];
    }
    return isDown && !wasDown;
  }

  boolean enterJustPressed() {
    return keyCodeJustPressed(ENTER) || keyCodeJustPressed(RETURN);
  }

  // Update previous key state arrays
  void updatePrevKeyStates() {
    // Copy current global key states into prev arrays
    for (int i = 0; i < prevKeyStates.length; i++) {
      prevKeyStates[i] = false;
    }
    for (int i = 0; i < prevKeyCodeStates.length; i++) {
      prevKeyCodeStates[i] = false;
    }
    // Mark keys currently down as down for next frame
    for (int i = 0; i < keyStates.length; i++) {
      if (keyStates[i]) prevKeyStates[i] = true;
    }
    for (int i = 0; i < keyCodeStates.length; i++) {
      if (keyCodeStates[i]) prevKeyCodeStates[i] = true;
    }
  }
}

