# Lexis — Setup Guide

## Create the Xcode project

1. Open Xcode → File → New → Project
2. Choose **iOS → App**
3. Set these options:
   - Product Name: `Lexis`
   - Interface: `SwiftUI`
   - Language: `Swift`
4. Save the project anywhere on your Mac

## Add the files

1. Delete the default `ContentView.swift` Xcode created
2. Drag all `.swift` files from this folder into your Xcode project
3. When prompted, make sure **"Copy items if needed"** is checked

## Add your API key

1. When cloning this project, you will need to provide your API key.
2. Create a new file called `Secrets.swift` alongside the other source files:
   ```swift
   enum Secrets {
       static let claudeApiKey = "YOUR_ANTHROPIC_API_KEY"
   }
   ```
3. Replace `YOUR_ANTHROPIC_API_KEY` with your key from console.anthropic.com

## Run the app

1. Select any iPhone simulator from the device menu at the top
2. Press **Cmd + R** to build and run
3. The app will fetch today's word on first launch — this takes a few seconds

## File overview

| File | What it does |
|---|---|
| `LexisApp.swift` | App entry point and tab navigation |
| `Theme.swift` | All colors and fonts |
| `Models.swift` | WordEntry data model and WordStore |
| `Services.swift` | Claude API, text-to-speech, notifications |
| `TodayView.swift` | Today's word screen |
| `ArchiveView.swift` | Past words list |
| `QuizView.swift` | Daily quiz with time lock |
| `SettingsView.swift` | Notification schedule settings |

## Notes

- The API key is stored locally in `Secrets.swift` which is ignored by git. This prevents accidental leaks, but for a real App Store deployment you must move the API call to a secure backend.
- The quiz unlocks at whatever time you set in Settings (default: 7:00 PM).
  To test it immediately, go to Settings and set the quiz time to a minute
  from now.
- Words are cached locally, so the app only calls the Claude API once per day.
