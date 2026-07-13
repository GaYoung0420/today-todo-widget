# FocusTodo

FocusTodo is a lightweight macOS menu-bar app for managing today's todos, running Pomodoro focus sessions, writing quick task memos, blocking distracting websites, and syncing todos with a Notion database.

The app is designed for personal daily focus rather than full project management. It stays close in the menu bar, opens compact floating panels, and keeps the next task, timer, memo, and sync controls within reach.

## Features

- Daily todo widget with previous, today, and next-day navigation
- Menu-bar popover for quick todo access
- Floating Pomodoro panel for the selected todo
- Per-todo target and completed Pomodoro counts
- Memo panel for task notes
- Website blocking during focus sessions
- Built-in focus music
- Settings for timer length, blocked sites, and sync options
- Two-way Notion database sync
- Automatic Notion polling with manual refresh from the widget
- Local state storage with the Notion token stored in macOS Keychain

## Requirements

- macOS 14 or later
- Xcode Command Line Tools
- Swift 5.9 or later

Install the Xcode Command Line Tools if needed:

```bash
xcode-select --install
```

## Run

From the project root:

```bash
bash script/build_and_run.sh
```

The script builds the Swift package, creates `dist/FocusTodo.app`, stops any existing FocusTodo process, and opens the app.

After launch, FocusTodo appears in the macOS menu bar. Click the timer icon to open the todo panel. Right-click it to open the app menu.

## Useful Commands

Build only:

```bash
swift build
```

Build, launch, and verify that the process started:

```bash
bash script/build_and_run.sh --verify
```

Launch with app logs:

```bash
bash script/build_and_run.sh --logs
```

Launch telemetry logs:

```bash
bash script/build_and_run.sh --telemetry
```

Debug the built binary:

```bash
bash script/build_and_run.sh --debug
```

## Notion Sync

FocusTodo can read rows from a Notion database and write app changes back to the matching Notion pages.

### Setup

1. Create a Notion integration.
2. Copy the integration token.
3. Make sure the integration has read, insert, and update content capabilities.
4. Open the target Notion database as a full page.
5. Share the database with the integration from the database connection menu.
6. In FocusTodo, open Settings, then the `노션` tab.
7. Turn on `노션 연동`.
8. Paste the integration token.
9. Paste the database URL or database ID.
10. Click `가져오기`.
11. Keep `자동 동기화` enabled if you want background polling.

For a database link like this:

```text
https://www.notion.so/workspace/0123456789abcdef0123456789abcdef?v=...
```

The database ID is:

```text
0123456789abcdef0123456789abcdef
```

You can paste either the full link or only the database ID into FocusTodo.

### Property Mapping

FocusTodo detects common Notion property names and types:

- Title: first Notion `title` property
- Notes: rich text properties such as `notes`, `note`, `memo`, `description`, `설명`, or `메모`
- Done state: checkbox or status properties such as `done`, `complete`, `completed`, `완료`, or `완료 여부`
- Date: date properties such as `date`, `due`, `deadline`, `schedule`, `날짜`, `일자`, `일정`, `기한`, or `마감`
- Target Pomodoros: number properties such as `pomodoro`, `target`, `estimate`, `뽀모도로`, or `예상`

Unsupported properties are left unchanged. FocusTodo only writes to property types it can detect safely: `title`, `rich_text`, `checkbox`, `status`, `date`, and `number`.

### Sync Behavior

- `가져오기` imports rows from the connected Notion database.
- Automatic sync polls Notion in the background. The default interval is 60 seconds.
- Opening the widget or changing the selected date refreshes stale data.
- Existing Notion-backed todos are matched by Notion page ID to avoid duplicates.
- Rows removed from Notion are removed from the Notion-backed local section on the next import.
- New local todos create new Notion pages when sync is enabled.
- Editing a title, memo, done state, date, or target Pomodoro count updates the matching Notion property when supported.
- Deleting a Notion-backed todo archives the matching Notion page.

## Local Data

FocusTodo stores app state here:

```text
~/Library/Application Support/FocusTodo/state.json
```

The Notion integration token is stored in macOS Keychain and is not written to `state.json`.

## Website Blocking Notes

Website blocking runs during Pomodoro focus sessions and checks the active browser URL against the blocked sites configured in Settings. macOS may ask for automation or accessibility-related permissions depending on your browser and system settings.

## Troubleshooting

If Notion returns a 404 error such as `Could not find database with ID`, the database ID was parsed but the integration cannot access that database.

Check that:

- The original Notion database is shared with the integration.
- You are using the source database URL, not only a linked database view.
- The integration belongs to the same Notion workspace as the database.
- The integration has read, insert, and update content capabilities.
- Related databases are also shared if your database depends on relation properties.

If the app does not appear after launch, check the macOS menu bar for the timer icon or run:

```bash
pgrep -x FocusTodo
```

## Project Structure

```text
Package.swift
Sources/FocusTodo/
  App/
  Models/
  Services/
  Stores/
  Support/
  Views/
  Resources/
script/build_and_run.sh
```

## License

No license has been specified yet.
