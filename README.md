# Relaxer

A macOS menu bar app that tracks how long you’ve been using your Mac without a break, then reminds you to rest.

The leaf icon in the menu bar fills up as you stay active. When you hit your reminder time, Relaxer sends a notification. The timer resets if you go idle, sleep the Mac, lock the screen, or close the lid.

## Install on this Mac

This is a `.app` bundle, not a single Unix binary. After a Release build you can copy it to `/Applications` and run it like any other Mac app.

**From Xcode**

1. Choose **My Mac** as the destination
2. **Product → Archive**
3. In the Organizer window, click **Distribute App**
4. Choose **Copy App** and save `relaxer.app` (Desktop or `/Applications`)
5. Double-click it, or drag it into `/Applications`

If macOS says the app can’t be opened, go to **System Settings → Privacy & Security** and allow it. That can happen on the first launch of a locally signed build.


## Version

Relaxer is at **1.0** (build **1**). The popover shows this at the bottom.

To bump it, open the **relaxer** target in Xcode → **General**:

- **Version** (`MARKETING_VERSION`) — user-facing, e.g. `1.1`
- **Build** (`CURRENT_PROJECT_VERSION`) — integer you raise for every archive, e.g. `2`

## Settings

- **Idle reset** — seconds with no input (mouse, keyboard, trackpad, scroll) before the timer resets (default 300)
- **Remind after** — minutes of activity before a notification (default 120)

Open settings from the menu bar popover.

## Data

Relaxer does not use a database or any files of its own.

Settings are stored in macOS **UserDefaults** (the standard app preferences plist):

- `idleResetSeconds`
- `reminderMinutes`

Active time is only kept in memory. Quitting the app or resetting the timer starts you over. No accounts, no network, no history.
