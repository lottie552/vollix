/**
 VisualLayout with position and rotation storage for calibration.
 */
class VisualLayout {
  // Screen dimensions
  final int width;
  final int height;

  // Center position (needs calibration)
  PVector center;

  // Center marker geometry
  final float centerRadius;
  final float iconSize;

  // 🟢 ADD: Scaling factors for center and targets.  CalibrationState sets
  // these values and PlayingState uses them to scale the foot cues and
  // center marker sizes.  Default scale is 1.0f (no scaling).
  float centerScale = 1.0f;
  ArrayList<Float> targetScales;

  // Target positions and rotations for calibration
  final ArrayList<PVector> targetPositions;
  final ArrayList<Float> targetRotations;

  VisualLayout(int w, int h) {
    width = w;
    height = h;

    // Start with screen center (will be calibrated)
    center = new PVector(w * 0.5f, h * 0.5f);

    // Center marker sizing
    centerRadius = min(w, h) * 0.12f;
    iconSize = centerRadius * 1.3f;

    // Initialize empty arrays
    targetPositions = new ArrayList<PVector>();
    targetRotations = new ArrayList<Float>();

    // Initialize target scales list
    targetScales = new ArrayList<Float>();
  }

  /**
   Setup targets with DEFAULT positions:
   - LEFT group targets on LEFT side of screen (for RIGHT foot)
   - RIGHT group targets on RIGHT side of screen (for LEFT foot)
   This assumes Hardware is already built and we know target groups
   */
  void setupTargets(ArrayList<Target> targets) {  // 🟢 CHANGED: Pass targets for group info
    targetPositions.clear();
    targetRotations.clear();
    targetScales.clear();

    if (targets.size() == 0) {
      println("VisualLayout: No targets to arrange");
      return;
    }

    println("VisualLayout: Setting up " + targets.size() + " targets with group-aware positions");

    // Count targets per side
    int leftCount = 0;
    int rightCount = 0;
    for (Target t : targets) {
      if (t.group.equals("LEFT")) leftCount++;
      else if (t.group.equals("RIGHT")) rightCount++;
    }

    println("  LEFT side targets: " + leftCount);
    println("  RIGHT side targets: " + rightCount);

    // Arrange targets based on their groups
    for (int i = 0; i < targets.size(); i++) {
      Target t = targets.get(i);
      PVector pos;
      float rotation = 0.0f;

      if (t.group.equals("LEFT")) {
        // LEFT target → position on LEFT side of screen
        // Simple vertical arrangement for multiple LEFT targets
        float ySpacing = height / (leftCount + 1);
        float yPos = ySpacing * (getLeftTargetIndex(targets, i) + 1);
        pos = new PVector(width * 0.25f, yPos); // Left quarter of screen
        rotation = 0; // Default rotation
      } else if (t.group.equals("RIGHT")) {
        // RIGHT target → position on RIGHT side of screen
        float ySpacing = height / (rightCount + 1);
        float yPos = ySpacing * (getRightTargetIndex(targets, i) + 1);
        pos = new PVector(width * 0.75f, yPos); // Right quarter of screen
        rotation = 0; // Default rotation
      } else {
        // No group, put in center as fallback
        pos = new PVector(width * 0.5f, height * 0.5f);
        rotation = 0;
      }

      targetPositions.add(pos);
      targetRotations.add(rotation);
      // Initialise scale for this target to 1.0
      targetScales.add(1.0f);

      println("  Target " + i + " (" + t.id + ", " + t.group + "): " +
        "pos(" + pos.x + ", " + pos.y + "), rot=" + rotation);
    }
  }

  // Helper to get index within LEFT targets
  int getLeftTargetIndex(ArrayList<Target> targets, int currentIndex) {
    int leftIndex = 0;
    for (int i = 0; i <= currentIndex; i++) {
      if (targets.get(i).group.equals("LEFT")) {
        if (i == currentIndex) return leftIndex;
        leftIndex++;
      }
    }
    return 0;
  }

  // Helper to get index within RIGHT targets
  int getRightTargetIndex(ArrayList<Target> targets, int currentIndex) {
    int rightIndex = 0;
    for (int i = 0; i <= currentIndex; i++) {
      if (targets.get(i).group.equals("RIGHT")) {
        if (i == currentIndex) return rightIndex;
        rightIndex++;
      }
    }
    return 0;
  }

  // ... (rest of the methods remain the same) ...

  float centerRadius() {
    return centerRadius;
  }
  float iconSize() {
    return iconSize;
  }

  // 🟢 ADD: Getter and setter for center scale
  float getCenterScale() {
    return centerScale;
  }
  void setCenterScale(float s) {
    centerScale = s;
  }

  // 🟢 ADD: Getter and setter for target scale
  float getTargetScale(int index) {
    if (index >= 0 && index < targetScales.size()) {
      return targetScales.get(index);
    }
    return 1.0f;
  }
  void setTargetScale(int index, float s) {
    // Ensure list can hold the index
    while (index >= targetScales.size()) {
      targetScales.add(1.0f);
    }
    targetScales.set(index, s);
  }

  PVector getTargetPosition(int index) {
    if (index >= 0 && index < targetPositions.size()) {
      return targetPositions.get(index);
    }
    return center.copy();
  }

  float getTargetRotation(int index) {
    if (index >= 0 && index < targetRotations.size()) {
      return targetRotations.get(index);
    }
    return 0.0f;
  }

  void setTargetPosition(int index, PVector position) {
    if (index >= 0 && index < targetPositions.size()) {
      targetPositions.set(index, position.copy());
    }
  }

  void setTargetRotation(int index, float rotation) {
    if (index >= 0 && index < targetRotations.size()) {
      while (rotation < 0) rotation += TWO_PI;
      while (rotation >= TWO_PI) rotation -= TWO_PI;
      targetRotations.set(index, rotation);
    }
  }

  void setCenter(PVector newCenter) {
    center = newCenter.copy();
  }

  ArrayList<PVector> getAllTargetPositions() {
    return targetPositions;
  }

  int getTargetCount() {
    return targetPositions.size();
  }

  void drawCenterMarker(PShape icon) {
    noStroke();
    fill(255);
    circle(center.x, center.y, centerRadius * 2);
    if (icon != null) {
      shape(icon, center.x, center.y, iconSize, iconSize);
    }
  }

  void drawCenterMarkerOnly() {
    drawCenterMarker(null);
  }

  void drawCenterMarkerWithIcon(PShape icon) {
    if (icon == null) {
      drawCenterMarkerOnly();
      return;
    }
    drawCenterMarker(icon);
  }
}




