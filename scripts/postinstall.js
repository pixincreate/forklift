#!/usr/bin/env node
// Copies the /forklift OpenCode command into the user's OpenCode commands dir
// if OpenCode is installed. Best-effort: never fails the install.
const fs = require("fs");
const os = require("os");
const path = require("path");

const cmdDir = path.join(os.homedir(), ".config", "opencode", "commands");
const src = path.join(__dirname, "commands", "forklift.md");
const dest = path.join(cmdDir, "forklift.md");

try {
  if (!fs.existsSync(src)) {
    console.log("[forklift] command template not found, skipping /forklift command install.");
    process.exit(0);
  }
  if (!fs.existsSync(cmdDir)) {
    console.log("[forklift] OpenCode commands dir not found at " + cmdDir +
      " — skipping /forklift command. Copy commands/forklift.md manually or run 'forklift init'.");
    process.exit(0);
  }
  fs.copyFileSync(src, dest);
  console.log("[forklift] installed /forklift OpenCode command to " + dest);
} catch (e) {
  console.log("[forklift] could not install /forklift command: " + e.message);
}
