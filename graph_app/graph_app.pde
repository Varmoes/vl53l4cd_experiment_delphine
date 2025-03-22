// Full Processing sketch with proper layout margins and non-overlapping axis ticks/labels
// Includes: serial port selector, dynamic graph layout, zoom/pan, tooltip, stats, axis ticks,
// labels with margins, auto-scaling, and real-time logging

import processing.serial.*;
Serial myPort;

ArrayList<Float> distances = new ArrayList<Float>();
ArrayList<String> timestamps = new ArrayList<String>();

PrintWriter output;

float xZoom = 1.0;
float scrollOffset = 0;
int maxVisiblePoints = 800;
boolean autoScroll = true;
boolean isRunning = true;

boolean isDragging = false;
float dragStartX;
float dragStartScroll;

float globalMin = Float.MAX_VALUE;
float globalMax = Float.MIN_VALUE;
float sumDistances = 0;
int totalCount = 0;

float btnStartStopX, btnStartStopY, btnStartStopW, btnStartStopH;
float btnResetViewX,  btnResetViewY,  btnResetViewW,  btnResetViewH;

boolean serialConnected = false;
boolean showPortSelectorButton = false;
String[] serialPorts;
int selectedPortIndex = -1;

int marginTop = 20;
int marginRight = 20;
int marginBottom = 60;
int marginLeft = 60;

void setup() {
  size(900, 500);
  textSize(14);
  serialPorts = Serial.list();
  btnStartStopW = 100;
  btnStartStopH = 30;
  btnStartStopX = 10;
  btnStartStopY = 10;
  btnResetViewW = 100;
  btnResetViewH = 30;
  btnResetViewX = 120;
  btnResetViewY = 10;
}

void draw() {
  background(255);

  if (!serialConnected) {
    drawPortSelector();
    return;
  }

  drawGraph();
  drawButtons();
  drawStats();
  if (distances.size() < 2) drawOverlay();
}

void drawPortSelector() {
  fill(0);
  textSize(18);
  textAlign(CENTER, CENTER);
  text("Select Serial Port to Connect", width/2, 50);
  textAlign(LEFT, BASELINE);
  textSize(14);

  for (int i = 0; i < serialPorts.length; i++) {
    float boxX = width/2 - 150;
    float boxY = 100 + i * 40;
    float boxW = 300;
    float boxH = 30;
    fill(230);
    stroke(0);
    rect(boxX, boxY, boxW, boxH);
    fill(0);
    text(serialPorts[i], boxX + 10, boxY + 20);
  }
}

void drawOverlay() {
  fill(255, 240);
  rect(0, 0, width, height);
  fill(0);
  textAlign(CENTER, CENTER);
  textSize(24);
  text("Waiting for data...", width / 2, height / 2);
  textAlign(LEFT, BASELINE);
  textSize(14);
}

void drawGraph() {
  if (distances.size() < 2) return;

  float visibleCount = distances.size() < maxVisiblePoints ? distances.size() : maxVisiblePoints / xZoom;
  if (autoScroll) scrollOffset = max(0, distances.size() - visibleCount);
  scrollOffset = constrain(scrollOffset, 0, max(0, distances.size() - 1));

  int startIndex = floor(scrollOffset);
  int endIndex = min(floor(scrollOffset + visibleCount), distances.size() - 1);

  float visibleMin = Float.MAX_VALUE;
  float visibleMax = Float.MIN_VALUE;
  for (int i = startIndex; i <= endIndex; i++) {
    float val = distances.get(i);
    visibleMin = min(visibleMin, val);
    visibleMax = max(visibleMax, val);
  }
  if (visibleMax == visibleMin || visibleMin == Float.MAX_VALUE || visibleMax == Float.MIN_VALUE) return;

  float padding = (visibleMax - visibleMin) * 0.1;
  visibleMin -= padding;
  visibleMax += padding;
  if (visibleMin < 0) visibleMin = -padding * 1.5;

  stroke(0);
  noFill();
  beginShape();
  for (int i = startIndex; i <= endIndex; i++) {
    float x = map(i, scrollOffset, scrollOffset + visibleCount, marginLeft, width - marginRight);
    float y = map(distances.get(i), visibleMin, visibleMax, height - marginBottom, marginTop);
    vertex(x, y);
  }
  endShape();

  drawTooltip(startIndex, endIndex, visibleMin, visibleMax, visibleCount);
  drawAxes(visibleMin, visibleMax, scrollOffset, visibleCount);
}

void drawTooltip(int startIndex, int endIndex, float visibleMin, float visibleMax, float visibleCount) {
  float hoverIndex = map(mouseX, marginLeft, width - marginRight, scrollOffset, scrollOffset + visibleCount);
  int iHover = floor(hoverIndex);
  if (iHover < startIndex || iHover > endIndex || iHover >= distances.size()) return;

  float x = map(iHover, scrollOffset, scrollOffset + visibleCount, marginLeft, width - marginRight);
  float y = map(distances.get(iHover), visibleMin, visibleMax, height - marginBottom, marginTop);

  fill(0, 150);
  noStroke();
  ellipse(x, y, 8, 8);

  stroke(0);
  fill(255);
  rect(x + 10, y - 30, 120, 40);

  fill(0);
  textSize(12);
  text("Time: " + timestamps.get(iHover), x + 14, y - 12);
  text("Dist: " + distances.get(iHover) + " mm", x + 14, y + 4);
}

void drawAxes(float visibleMin, float visibleMax, float scrollOffset, float visibleCount) {
  stroke(180);
  fill(0);
  textSize(12);
  textAlign(RIGHT, CENTER);

  int yTicks = 6;
  for (int i = 0; i <= yTicks; i++) {
    float val = map(i, 0, yTicks, visibleMax, visibleMin);
    float y = map(val, visibleMin, visibleMax, height - marginBottom, marginTop);

    // Draw horizontal grid lines
    stroke(220);
    line(marginLeft, y, width - marginRight, y);

    stroke(180);
    line(marginLeft - 5, y, marginLeft, y);
    fill(0);
    text(nf(val, 0, 1), marginLeft - 10, y);
  }

  pushMatrix();
  translate(marginLeft - 40, height / 2);
  rotate(-HALF_PI);
  textAlign(CENTER, CENTER);
  text("Distance (mm)", 0, -10);
  popMatrix();

  int xTicks = 10;
  textAlign(CENTER, TOP);
  for (int i = 0; i <= xTicks; i++) {
    float index = map(i, 0, xTicks, scrollOffset, scrollOffset + visibleCount);
    int iIndex = floor(index);
    if (iIndex >= 0 && iIndex < timestamps.size()) {
      float x = map(iIndex, scrollOffset, scrollOffset + visibleCount, marginLeft, width - marginRight);

      // Draw vertical grid lines
      stroke(220);
      line(x, marginTop, x, height - marginBottom);

      stroke(180);
      line(x, height - marginBottom, x, height - marginBottom + 5);
      fill(0);
      text(timestamps.get(iIndex), x, height - marginBottom + 8);
    }
  }

  textAlign(CENTER, TOP);
  text("Time", width / 2, height - marginBottom + 30);

  // Draw port selector return button
  fill(200);
  stroke(0);
  rect(width - 140, 10, 130, 30);
  fill(0);
  textAlign(CENTER, CENTER);
  text("Change Port", width - 75, 25);
}

void drawButtons() {
  fill(200);
  stroke(0);
  rect(btnStartStopX, btnStartStopY, btnStartStopW, btnStartStopH);
  fill(0);
  textAlign(CENTER, CENTER);
  text(isRunning ? "Stop" : "Start", btnStartStopX + btnStartStopW/2, btnStartStopY + btnStartStopH/2);

  fill(200);
  stroke(0);
  rect(btnResetViewX, btnResetViewY, btnResetViewW, btnResetViewH);
  fill(0);
  text("Reset View", btnResetViewX + btnResetViewW/2, btnResetViewY + btnResetViewH/2);

  textAlign(LEFT, BASELINE);
}

void drawStats() {
  fill(0);
  textSize(14);
  float globalAvg = (totalCount > 0) ? (sumDistances / totalCount) : 0;
  text("Min: " + nf(globalMin,1,2) + " mm   " +
       "Max: " + nf(globalMax,1,2) + " mm   " +
       "Avg: " + nf(globalAvg,1,2) + " mm   " +
       "[Points: " + distances.size() + "]",
       marginLeft, height - 10);
}

void serialEvent(Serial p) {
  if (!isRunning) return;

  try {
    String inData = trim(p.readStringUntil('\n'));
    if (inData == null || inData.length() == 0 || !inData.contains(",")) return;
    String[] parts = split(inData, ',');
    if (parts.length != 2) return;

    String millisPart = parts[0].trim();
    String distancePart = parts[1].trim();
    if (millisPart.length() == 0 || distancePart.length() == 0) return;

    float distance = Float.parseFloat(distancePart);
    String timestamp = nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);

    distances.add(distance);
    timestamps.add(timestamp);
    output.println(timestamp + "," + distance);
    output.flush();

    if (distance < globalMin) globalMin = distance;
    if (distance > globalMax) globalMax = distance;
    sumDistances += distance;
    totalCount++;
  } catch (Exception e) {
    println("⚠️ Malformed serial data or parse error: " + e);
  }
}

void mousePressed() {
  if (!serialConnected) {
    for (int i = 0; i < serialPorts.length; i++) {
      float boxX = width / 2 - 150;
      float boxY = 100 + i * 40;
      float boxW = 300;
      float boxH = 30;
      if (mouseX > boxX && mouseX < boxX + boxW && mouseY > boxY && mouseY < boxY + boxH) {
        selectedPortIndex = i;
        try {
          myPort = new Serial(this, serialPorts[i], 115200);
          myPort.bufferUntil('\n');
          output = createWriter("distance_log_" + year() + "_" + nf(month(), 2) + "_" + nf(day(), 2) + "_" + nf(hour(), 2) + nf(minute(), 2) + ".csv");
          output.println("Timestamp,Distance(mm)");
          serialConnected = true;
          println("✅ Connected to " + serialPorts[i]);
        } catch (Exception e) {
          println("⚠️ Failed to connect to " + serialPorts[i] + ": " + e);
        }
        return;
      }
    }
  } else {
    // Handle return to port selector
    if (mouseX > width - 140 && mouseX < width - 10 && mouseY > 10 && mouseY < 40) {
      println("🔌 Returning to port selector...");
      serialConnected = false;
      if (myPort != null) myPort.stop();
      myPort = null;
      if (output != null) {
        output.flush();
        output.close();
      }
    }
  }

  if (mouseX > btnStartStopX && mouseX < btnStartStopX + btnStartStopW && mouseY > btnStartStopY && mouseY < btnStartStopY + btnStartStopH) {
    isRunning = !isRunning;
    return;
  }

  if (mouseX > btnResetViewX && mouseX < btnResetViewX + btnResetViewW && mouseY > btnResetViewY && mouseY < btnResetViewY + btnResetViewH) {
    autoScroll = true;
    xZoom = 1.0;
    scrollOffset = 0;
    return;
  }

  if (mouseButton == LEFT) {
    isDragging = true;
    dragStartX = mouseX;
    dragStartScroll = scrollOffset;
  }
}

void mouseDragged() {
  if (isDragging) {
    autoScroll = false;
    float dx = mouseX - dragStartX;
    float visibleCount = maxVisiblePoints / xZoom;
    float idxDiff = map(dx, 0, width - marginLeft - marginRight, 0, visibleCount);
    scrollOffset = dragStartScroll - idxDiff;
  }
}

void mouseReleased() {
  isDragging = false;
}

void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  float zoomFactor = 1.05;
  float visibleCount = maxVisiblePoints / xZoom;
  float oldDataIndex = map(mouseX, marginLeft, width - marginRight, scrollOffset, scrollOffset + visibleCount);

  if (e < 0) xZoom *= pow(zoomFactor, -e);
  else       xZoom /= pow(zoomFactor, e);

  xZoom = constrain(xZoom, 0.1, 50);
  autoScroll = false;

  visibleCount = maxVisiblePoints / xZoom;
  float newDataIndex = map(mouseX, marginLeft, width - marginRight, scrollOffset, scrollOffset + visibleCount);
  scrollOffset += oldDataIndex - newDataIndex;
}

void keyPressed() {
  if (key == 'q' || key == 'Q') {
    println("Exiting and saving log...");
    output.flush();
    output.close();
    exit();
  }
}
