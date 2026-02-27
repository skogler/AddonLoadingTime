# AddonLoadingTime

A simple tool to see how much time each of your addons takes to load.

## How it works

The addon folder is named `!!AddonLoadingTime` so that the game loads it first. This allows it to track the loading time of every other addon that follows.

When you log in, the UI will automatically pop up with the results.

## Usage

- **Sort:** Click the column headers to sort by:
  - **Addon:** Alphabetical name.
  - **Load Time:** How long that specific addon took to load.
  - **Cumulative:** The total time elapsed from the start of the loading process until that addon finished. (e.g., if an addon shows 500ms, it finished half a second after you started loading).
- **Colors:** Red is > 50ms, yellow is > 10ms, and green is anything less.
- **Toggle UI:** Use `/alt` or `/addonloadingtime` to show or hide the window.

## Installation

1. Put the `!!AddonLoadingTime` folder into your `World of Warcraft/_retail_/Interface/AddOns/` directory.
2. Restart the game or reload your UI.
