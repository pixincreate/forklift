#!/usr/bin/env node
// Installs the /forklift command into one or more harness command dirs.
// Opt out with FORKLIFT_INSTALL_COMMAND=0. Target dirs come from
// FORKLIFT_COMMAND_PATHS (space/comma list); defaults to opencode's dir.
// Best-effort: never fails the install.
const fs = require("fs");
const os = require("os");
const path = require("path");

if (process.env.FORKLIFT_INSTALL_COMMAND === "0") {
  console.log("[forklift] skipping command install (FORKLIFT_INSTALL_COMMAND=0)");
  process.exit(0);
}

const pkgDir = path.join(__dirname, "..");
const src = path.join(pkgDir, "commands", "forklift.md");
if (!fs.existsSync(src)) {
  console.log("[forklift] command template not found, skipping /forklift command.");
  process.exit(0);
}

const defaultDir = path.join(os.homedir(), ".config", "opencode", "commands");
const raw = process.env.FORKLIFT_COMMAND_PATHS || defaultDir;
const dirs = raw.split(/[ ,]+/).map(s => s.trim()).filter(Boolean);

let installed = 0;
for (const d of dirs) {
  try {
    fs.mkdirSync(d, { recursive: true });
    fs.copyFileSync(src, path.join(d, "forklift.md"));
    console.log("[forklift] installed command to " + d);
    installed++;
  } catch (e) {
    console.log("[forklift] could not install command to " + d + ": " + e.message);
  }
}
if (installed === 0) {
  console.log("[forklift] no command paths configured; set FORKLIFT_COMMAND_PATHS to install the /forklift command.");
}
