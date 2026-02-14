# BulkMessager

A macOS app for sending bulk messages via iMessage and SMS.

## Background

I built this app when I changed my phone number and needed to notify all my contacts. The native Messages app doesn't support bulk selection, so I created this tool.

## Features

- **Contact Management** - Select contacts from your Mac or import from CSV
- **Message Templates** - Create templates with variables like `{{name}}`, `{{company}}`
- **Bulk Sending** - Send personalized messages to multiple contacts
- **History Tracking** - Track sent messages with success/failure status

## Usage

1. Select contacts (from system Contacts or import a CSV file)
2. Write a message or select a template
3. Preview and send
4. Track results in the History tab

## CSV Format

```csv
Name,Phone,Company
John Doe,+1234567890,Acme Corp
Jane Smith,+1987654321,Tech Inc
```

Use `{{company}}` in your template and it gets replaced with the actual value.

## Requirements

- macOS 12.0+
- Xcode 14.0+ (for building)
- Messages app configured

## Installation

```bash
git clone [repo-url]
cd bulk-messager
open BulkMessager.xcodeproj
```

Build and run with ⌘+R.

## License

MIT
