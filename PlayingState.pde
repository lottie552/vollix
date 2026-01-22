
/**
  PlayingState - Tennis Volley Footwork Trainer
  Purpose:
    Tennis reaction training using calibrated foot positions.
    
  Visual Rules:
    - Center: white circle = ready/neutral stance position
    - LEFT target → RIGHT foot on LEFT side of screen
    - RIGHT target → LEFT foot on RIGHT side of screen
    - NO timer rings, NO target circles
*/
class PlayingState implements IGameState {
  final App app;
  
  // Game timing
  final int BASE_HIT_WINDOW_MS = 2000;
  final int BASE_SHOW_DURATION_MS = 800;
  final int BETWEEN_TARGET_MIN_MS = 500;
  final int BETWEEN_TARGET_MAX_MS = 3500;

  // Dynamic timing variables (mutable per level)
  int hitWindow;
  int showDuration;
  
  // Game phases
  static final int PHASE_WAIT = 0;
  static final int PHASE_SHOW = 1;
  static final int PHASE_RESULT = 2;
  static final int PHASE_GAME_OVER = 3;
  
  int phase = PHASE_WAIT;
  int phaseStartMs = 0;
  int phaseEndMs = 0;
  
  // Game state
  int lives = 3;
  int currentTargetIndex = -1;
  Target currentTarget = null;
  boolean hitSuccess = false;

  // -----------------------------------------------------------------
  // Leveling system fields
  //
  // level: current difficulty level (starts at 1)
  // correctInLevel: number of successful hits in this level
  // attemptsInLevel: number of targets shown this level (success or miss)
  // livesAtStartOfLevel: lives at the start of the current level
  // maxAttemptsInLevel: maximum targets this level = 6 + (livesAtStartOfLevel - 1)
  // randomWaitsUsed: counts how many random pre‑cue waits occurred this level
  // decreaseHitWindowNext: toggles which timing to shrink when leveling up
  // consecutivePerfectLevels: tracks consecutive perfect levels to restore a life
  int level;
  int correctInLevel;
  int attemptsInLevel;
  int livesAtStartOfLevel;
  int maxAttemptsInLevel;
  int randomWaitsUsed;
  boolean decreaseHitWindowNext;
  int consecutivePerfectLevels;
  
  // Start button handling (double-click to exit)
  int startClickCount = 0;
  int lastStartClickMs = 0;
  final int DOUBLE_CLICK_TIME_MS = 500;
  
  PlayingState(App app) {
    this.app = app;
  }
  
  @Override
  public void enterGameState() {
    println("=== PlayingState.enterGameState() ===");
    
    // Reset game state
    lives = 3;
    phase = PHASE_WAIT;
    currentTargetIndex = -1;
    currentTarget = null;
    hitSuccess = false;
    startClickCount = 0;
    lastStartClickMs = 0;

    // Initialise level system variables
    level = 1;
    correctInLevel = 0;
    attemptsInLevel = 0;
    randomWaitsUsed = 0;
    decreaseHitWindowNext = true; // First level‑up shrinks hit window
    consecutivePerfectLevels = 0;
    livesAtStartOfLevel = lives;
    maxAttemptsInLevel = 6 + (livesAtStartOfLevel - 1);
    // Set dynamic timing to base values
    hitWindow = BASE_HIT_WINDOW_MS;
    showDuration = BASE_SHOW_DURATION_MS;
    
    // Set initial LED state
    app.hardware.allLedsOff();
    app.hardware.showLives(lives);
    
    // Start with random wait before first target
    scheduleNextPhase(BETWEEN_TARGET_MIN_MS, BETWEEN_TARGET_MAX_MS);
    
    println("  Lives: " + lives);
    println("  Targets available: " + app.hardware.targets.size());
  }
  
  @Override
  public void update(int nowMs) {
    // 🟢 FIXED: Check for double-click panic exit EVERY frame
    checkPanicExit(nowMs);
    // Game over now handled synchronously in handlePhaseTimeout; do not skip update
    // Check if phase timeout
    if (phase != PHASE_WAIT && nowMs >= phaseEndMs) {
      handlePhaseTimeout(nowMs);
      return;
    }
    
    // Process current phase
    switch (phase) {
      case PHASE_WAIT:
        if (nowMs >= phaseEndMs) {
          startNewTarget();
        }
        break;
        
      case PHASE_SHOW:
        checkForTargetPress();
        break;
        
      case PHASE_RESULT:
        // Showing result, will auto-advance after timeout
        break;
    }
  }
  
  @Override
  public void render() {
    // Dark background for floor projection
    background(5, 10, 20);
    
    // Draw center marker (white circle only, no icon - this is ready stance)
    drawCenterMarker();
    
    // Draw current foot guide only while the target LED is on (during SHOW phase)
    if (currentTarget != null && phase == PHASE_SHOW) {
      drawFootGuide();
    }
  }
  
  @Override
  public void exitGameState() {
    println("=== PlayingState.exitGameState() ===");
    app.hardware.allLedsOff();
  }
  
  // -----------------------------------------------------------------
  // Game Logic Methods
  // -----------------------------------------------------------------
  
  void startNewTarget() {
    // Choose a random target instead of cycling sequentially
    ArrayList<Target> allTargets = app.hardware.targets;
    if (allTargets.size() == 0) {
      println("ERROR: No targets found!");
      app.gsm.setState(new IdleState(app));
      return;
    }
    int idx = (int)random(allTargets.size());
    currentTarget = allTargets.get(idx);
    println("  New target: " + currentTarget.id + " (group: " + currentTarget.group + ")");
    // Turn off all LEDs and show current lives on life LEDs
    app.hardware.allLedsOff();
    app.hardware.showLives(lives);
    currentTarget.on();
    // Enter SHOW phase
    phase = PHASE_SHOW;
    phaseStartMs = millis();
    phaseEndMs = phaseStartMs + hitWindow;
    hitSuccess = false;
  }
  
  void checkForTargetPress() {
    if (currentTarget == null || !currentTarget.hasButton()) {
      return;
    }
    
    // Check for correct button press
    if (currentTarget.justPressed()) {
      handleCorrectPress();
      return;
    }
    
    // Check for wrong button press (any other target button)
    for (Target t : app.hardware.targets) {
      if (t != null && t != currentTarget && t.hasButton() && t.justPressed()) {
        handleWrongPress();
        return;
      }
    }
  }
  
  void handleCorrectPress() {
    println("  HIT! Target " + currentTarget.id + " pressed correctly");
    
    hitSuccess = true;
    currentTarget.off();
    // Count success and attempt for level tracking
    correctInLevel++;
    attemptsInLevel++;
    phase = PHASE_RESULT;
    phaseStartMs = millis();
    phaseEndMs = phaseStartMs + showDuration;
  }
  
  void handleWrongPress() {
    println("  MISS! Wrong button pressed");
    
    hitSuccess = false;
    // Wrong press counts as an attempt and costs a life
    attemptsInLevel++;
    loseLife();
    currentTarget.off();
    phase = PHASE_RESULT;
    phaseStartMs = millis();
    phaseEndMs = phaseStartMs + showDuration;
  }
  
  void handlePhaseTimeout(int nowMs) {
    if (phase == PHASE_SHOW) {
      println("  TIMEOUT! No press for target " + currentTarget.id);
      hitSuccess = false;
      // Timeout counts as an attempt and costs a life
      attemptsInLevel++;
      loseLife();
      currentTarget.off();
      phase = PHASE_RESULT;
      phaseStartMs = nowMs;
      phaseEndMs = phaseStartMs + showDuration;
    } 
    else if (phase == PHASE_RESULT) {
      // Completed showing result; check game over or continue
      if (lives <= 0) {
        println("  GAME OVER! No lives left");
        // Blink all LEDs twice to signal game over (synchronously)
        blinkAllLedsSync(2);
        // Restore life LEDs (all three on) before leaving
        app.hardware.showLives(3);
        // Immediately return to IdleState
        app.gsm.setState(new IdleState(app));
        return;
      } else {
        // Check for level completion: 6 correct hits or reached max attempts
        if (correctInLevel >= 6 || attemptsInLevel >= maxAttemptsInLevel) {
          levelUp();
        }
        phase = PHASE_WAIT;
        scheduleNextPhase(BETWEEN_TARGET_MIN_MS, BETWEEN_TARGET_MAX_MS);
      }
    }
    else if (phase == PHASE_GAME_OVER) {
      // Should no longer reach here because game over handled above
      println("  Game Over - Returning to IdleState");
      app.gsm.setState(new IdleState(app));
    }
  }
  
  void loseLife() {
    lives = max(0, lives - 1);
    app.hardware.showLives(lives);
    println("  Lives remaining: " + lives);
  }
  
  void scheduleNextPhase(int minMs, int maxMs) {
    int waitTime;
    if (minMs == maxMs) {
      // Fixed delay (no random count increment)
      waitTime = minMs;
    } else {
      // Only allow random waits at most twice per level
      if (randomWaitsUsed < 2) {
        waitTime = (int)random(minMs, maxMs);
        randomWaitsUsed++;
      } else {
        waitTime = 0;
      }
    }
    phaseStartMs = millis();
    phaseEndMs = phaseStartMs + waitTime;
    println("  Next phase in: " + waitTime + "ms");
  }

  // -----------------------------------------------------------------
  // Level up logic
  //
  // Called when the current level finishes.  Increments the level counter,
  // blinks LEDs to signal the new level, reduces either hitWindow or
  // showDuration (alternating each level), resets counters, and handles
  // perfect-level life recovery.
  void levelUp() {
    level++;
    println("  LEVEL UP! Now at level " + level);
    // Blink LEDs: number of blinks equals level number
    blinkTargets(level);
    // Adjust timing: alternate shrinking hitWindow and showDuration
    if (decreaseHitWindowNext) {
      hitWindow = max(300, hitWindow - 200);
      println("    New hitWindow = " + hitWindow + "ms");
    } else {
      showDuration = max(200, showDuration - 100);
      println("    New showDuration = " + showDuration + "ms");
    }
    decreaseHitWindowNext = !decreaseHitWindowNext;
    // Perfect level check: no mistakes (correctInLevel == 6)
    if (correctInLevel == 6) {
      consecutivePerfectLevels++;
      println("    Consecutive perfect levels: " + consecutivePerfectLevels);
      if (consecutivePerfectLevels >= 3) {
        // Restore one life up to a maximum of 3
        if (lives < 3) {
          lives++;
          app.hardware.showLives(lives);
          println("    🎉 Perfect streak! Life restored to " + lives);
        }
        consecutivePerfectLevels = 0;
      }
    } else {
      // Reset perfect streak on any mistakes
      consecutivePerfectLevels = 0;
    }
    // Reset level counters and random waits
    correctInLevel = 0;
    attemptsInLevel = 0;
    randomWaitsUsed = 0;
    // Update lives baseline and max attempts for the new level
    livesAtStartOfLevel = lives;
    maxAttemptsInLevel = 6 + (livesAtStartOfLevel - 1);
    println("    Lives at start of new level: " + livesAtStartOfLevel + ", max attempts: " + maxAttemptsInLevel);
  }

  // Blink all target LEDs a specified number of times.  A blink consists
  // of turning all target LEDs on (eye closed) and then off (eye open).
  void blinkTargets(final int blinks) {
    new Thread(new Runnable() {
      public void run() {
        try {
          for (int i = 0; i < blinks; i++) {
            // Turn all target LEDs on
            for (Target t : app.hardware.targets) {
              if (t != null) t.on();
            }
            Thread.sleep(200);
            // Turn all target LEDs off
            for (Target t : app.hardware.targets) {
              if (t != null) t.off();
            }
            Thread.sleep(200);
          }
        } catch (InterruptedException e) {
          // Ignore interruption
        }
      }
    }).start();
  }

  // -----------------------------------------------------------------
  // Blink all target and life LEDs together.  Used for game-over signal.
  void blinkAllLeds(final int blinks) {
    new Thread(new Runnable() {
      public void run() {
        try {
          for (int i = 0; i < blinks; i++) {
            // Turn all target LEDs and life LEDs on
            for (Target t : app.hardware.targets) {
              if (t != null) t.on();
            }
            for (IndicatorLed led : app.hardware.lifeLeds) {
              if (led != null) led.on();
            }
            Thread.sleep(200);
            // Turn all target LEDs and life LEDs off
            for (Target t : app.hardware.targets) {
              if (t != null) t.off();
            }
            for (IndicatorLed led : app.hardware.lifeLeds) {
              if (led != null) led.off();
            }
            Thread.sleep(200);
          }
        } catch (InterruptedException e) {
          // Ignore
        }
      }
    }).start();
  }

  // -----------------------------------------------------------------
  // Synchronous blink of all target and life LEDs. This method blocks
  // the current thread while blinking to ensure LEDs end in a known
  // state before transitioning back to Idle. Each blink turns all LEDs
  // on for 200ms then off for 200ms.
  void blinkAllLedsSync(int blinks) {
    for (int i = 0; i < blinks; i++) {
      // On
      for (Target t : app.hardware.targets) {
        if (t != null) t.on();
      }
      for (IndicatorLed led : app.hardware.lifeLeds) {
        if (led != null) led.on();
      }
      try {
        Thread.sleep(200);
      } catch (InterruptedException e) {
        // ignore
      }
      // Off
      for (Target t : app.hardware.targets) {
        if (t != null) t.off();
      }
      for (IndicatorLed led : app.hardware.lifeLeds) {
        if (led != null) led.off();
      }
      try {
        Thread.sleep(200);
      } catch (InterruptedException e) {
        // ignore
      }
    }
  }
  
  // -----------------------------------------------------------------
  // 🟢 FIXED: Panic Exit Method (double-click back to IdleState)
  // -----------------------------------------------------------------
  
  void checkPanicExit(int nowMs) {
    if (app.hardware.startButton == null) {
      return;
    }
    
    if (app.hardware.startButton.justPressed()) {
      println("PlayingState: Start button pressed (double-click to exit)");
      
      // Check for double-click
      if (nowMs - lastStartClickMs < DOUBLE_CLICK_TIME_MS) {
        // Double-click detected!
        println("=== PANIC EXIT: Double-click detected, returning to IdleState ===");
        app.gsm.setState(new IdleState(app));
        return;
      }
      
      lastStartClickMs = nowMs;
      startClickCount = 1;
    }
    
    // Reset click count if too much time has passed
    if (startClickCount > 0 && (nowMs - lastStartClickMs) >= DOUBLE_CLICK_TIME_MS) {
      startClickCount = 0;
    }
  }
  
  // -----------------------------------------------------------------
  // Rendering Methods
  // -----------------------------------------------------------------
  
  void drawCenterMarker() {
    // Big white circle in center - this is READY STANCE position.
    // Apply calibration scale so the neutral stance size matches the calibration
    noStroke();
    fill(255);
    float r = app.layout.centerRadius() * 0.8 * app.layout.getCenterScale();
    circle(app.layout.center.x, app.layout.center.y, r * 2);
  }
  
  void drawFootGuide() {
    if (currentTarget == null) return;
    
    // Get calibrated position for this target
    int targetIndex = app.hardware.targets.indexOf(currentTarget);
    PVector pos = app.layout.getTargetPosition(targetIndex);
    if (pos == null) {
      pos = app.layout.center.copy(); // Fallback
    }
    
    // 🟢 FIXED: Choose foot AND position based on target group
    PShape footIcon = null;
    String footSide = "";
    
    if (currentTarget.group.equals("LEFT")) {
      // LEFT target → RIGHT foot on LEFT side
      footIcon = app.cupcakeIcon;  // Right foot (cupcake)
      footSide = "RIGHT foot on LEFT side";
    } else if (currentTarget.group.equals("RIGHT")) {
      // RIGHT target → LEFT foot on RIGHT side  
      footIcon = app.candyIcon; // Left foot (candy)
      footSide = "LEFT foot on RIGHT side";
    } else {
      // No group specified, fallback
      footIcon = app.candyIcon;
      footSide = "UNKNOWN";
    }
    
    // Draw the foot guide
    if (footIcon != null) {
      shapeMode(CENTER);
      
      // Apply rotation if available (will be used in CalibrationState)
      float rotation = app.layout.getTargetRotation(targetIndex);
      
      pushMatrix();
      translate(pos.x, pos.y);
      rotate(rotation);
      
      // Foot color based on phase
      if (phase == PHASE_SHOW) {
        tint(255, 230); // Normal during active phase
      } else if (phase == PHASE_RESULT) {
        if (hitSuccess) {
          tint(100, 255, 100, 230); // Green on success
        } else {
          tint(255, 100, 100, 230); // Red on miss
        }
      }
      
      // Use fixed width and preserve the original aspect ratio of the foot SVG.
      // Scale foot width based on calibration.  Retrieve the target-specific
      // scale factor from VisualLayout; default is 1.0.  Also preserve the
      // original SVG aspect ratio (1014/1800).  This means the foot
      // increases/decreases uniformly according to calibration.
      float baseFootWidth = 80;
      float scaleFactor = app.layout.getTargetScale(targetIndex);
      float footWidth = baseFootWidth * scaleFactor;
      float footHeight = footWidth * (1014.0f / 1800.0f);
      shape(footIcon, 0, 0, footWidth, footHeight);
      noTint();
      popMatrix();
      
      // Debug info (console only)
      if (phase == PHASE_SHOW) {
        println("  Showing: " + footSide + " at (" + pos.x + ", " + pos.y + ")");
      }
    }
  }
}



