
/**
  PinMap (Table builder)
  Purpose:
    Build and return the pin definition table for this sketch.

  Why this is a function:
    Processing does not allow method calls at top-level.
    So we build the Table inside a function and call it from setup().
*/
Table buildPinMap() {
  Table pinmap = new Table();

  pinmap.addColumn("id");    // string
  pinmap.addColumn("kind");  // "LED" or "BUTTON"
  pinmap.addColumn("role");  // "LIFE" "START" "TARGET"
  pinmap.addColumn("pin");   // int BCM pin
  pinmap.addColumn("group"); // "LEFT" "RIGHT" or ""

  // --- life leds ---
  TableRow row1 = pinmap.addRow();
  row1.setString("id", "life3");
  row1.setString("kind", "LED");
  row1.setString("role", "LIFE");
  row1.setInt("pin", 5);
  row1.setString("group", "");

  TableRow row2 = pinmap.addRow();
  row2.setString("id", "life2");
  row2.setString("kind", "LED");
  row2.setString("role", "LIFE");
  row2.setInt("pin", 6);
  row2.setString("group", "");

  TableRow row3 = pinmap.addRow();
  row3.setString("id", "life1");
  row3.setString("kind", "LED");
  row3.setString("role", "LIFE");
  row3.setInt("pin", 13);
  row3.setString("group", "");

  // --- start button ---
  TableRow row4 = pinmap.addRow();
  row4.setString("id", "start");
  row4.setString("kind", "BUTTON");
  row4.setString("role", "START");
  row4.setInt("pin", 12);
  row4.setString("group", "");

  // --- targets ---
  // IMPORTANT: for pairing LED+BUTTON into one Target,
  // the LED row and BUTTON row must share the same id (e.g. "t1").
  TableRow row5 = pinmap.addRow();
  row5.setString("id", "t1");
  row5.setString("kind", "LED");
  row5.setString("role", "TARGET");
  row5.setInt("pin", 26);
  row5.setString("group", "LEFT");

  TableRow row6 = pinmap.addRow();
  row6.setString("id", "t1");
  row6.setString("kind", "BUTTON");
  row6.setString("role", "TARGET");
  row6.setInt("pin", 16);
  row6.setString("group", "LEFT");

  TableRow row7 = pinmap.addRow();
  row7.setString("id", "t2");
  row7.setString("kind", "LED");
  row7.setString("role", "TARGET");
  row7.setInt("pin", 22);
  row7.setString("group", "RIGHT");

  TableRow row8 = pinmap.addRow();
  row8.setString("id", "t2");
  row8.setString("kind", "BUTTON");
  row8.setString("role", "TARGET");
  row8.setInt("pin", 23);
  row8.setString("group", "RIGHT");
  
  // TableRow row9 = pinmap.addRow();
  // row9.setString("id", "t3");
  // row9.setString("kind", "LED");
  // row9.setString("role", "TARGET");
  // row9.setInt("pin", 5);
  // row9.setString("group", "LEFT");   

  // TableRow row10 = pinmap.addRow();
  // row10.setString("id", "t4");
  // row10.setString("kind", "LED");
  // row10.setString("role", "TARGET");
  // row10.setInt("pin", 24);
  // row10.setString("group", "RIGHT");

  return pinmap;
}




