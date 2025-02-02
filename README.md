## Inventory Scanner

Universal inventory scanner used to scan barcodes and keep track of scan counts.
Supports various barcode formats and provides multiple options for data synchronization.

```shell
fvm flutter pub get

fvm flutter pub run build_runner build --delete-conflicting-outputs

fvm dart format lib
```

------------------

# # Data Formats

### HTTP JSON Format

The scanner can send data via HTTP POST/GET requests in JSON format. Here's the detailed schema:

#### Session Data Schema

- [JSON Schema Validator](https://www.jsonschemavalidator.net/)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": [
    "session_id",
    "session_name",
    "started_at",
    "events",
    "device_info"
  ],
  "properties": {
    "session_id": {
      "type": "string",
      "description": "Unique identifier for the scanning session"
    },
    "session_name": {
      "type": "string",
      "description": "User-provided name for the session"
    },
    "started_at": {
      "type": "string",
      "format": "date-time",
      "description": "ISO8601 timestamp when session started"
    },
    "finished_at": {
      "type": "string",
      "format": "date-time",
      "description": "ISO8601 timestamp when session ended (null if ongoing)"
    },
    "events": {
      "type": "array",
      "items": {
        "type": "object",
        "required": [
          "barcode",
          "barcode_type",
          "timestamp"
        ],
        "properties": {
          "barcode": {
            "type": "string",
            "description": "The scanned barcode value"
          },
          "barcode_type": {
            "type": "string",
            "description": "Format of the barcode (e.g., QR_CODE, EAN_13)",
            "enum": [
              "QR_CODE",
              "EAN_13",
              "EAN_8",
              "CODE_39",
              "CODE_128",
              "UPC_A",
              "UPC_E"
            ]
          },
          "timestamp": {
            "type": "string",
            "format": "date-time",
            "description": "ISO8601 timestamp of when the scan occurred"
          }
        }
      }
    },
    "device_info": {
      "type": "object",
      "required": [
        "device_name",
        "location",
        "timestamp"
      ],
      "properties": {
        "device_name": {
          "type": "string",
          "description": "Configured name of the scanning device"
        },
        "location": {
          "type": "string",
          "description": "Configured location of the scanning device"
        },
        "timestamp": {
          "type": "string",
          "format": "date-time",
          "description": "ISO8601 timestamp of when the data was sent"
        }
      }
    }
  }
}
```

#### Example HTTP Request Body

```json
{
  "session_id": "1707155823000",
  "session_name": "Warehouse A Stock Count",
  "started_at": "2025-02-05T14:30:00Z",
  "finished_at": "2025-02-05T15:45:00Z",
  "events": [
    {
      "barcode": "123456789012",
      "barcode_type": "EAN_13",
      "timestamp": "2025-02-05T14:31:23Z"
    }
  ],
  "device_info": {
    "device_name": "Scanner-01",
    "location": "Warehouse A",
    "timestamp": "2025-02-05T15:45:00Z"
  }
}
```

### CSV Export Formats

The scanner exports two separate CSV files for each session:

#### 1. Event Log (filename: session_{id}_events.csv)

Details every scan event in chronological order.

| Column Name | Description               | Example                |
|-------------|---------------------------|------------------------|
| Timestamp   | ISO8601 timestamp of scan | `2025-02-05T14:31:23Z` |
| Barcode     | Scanned barcode value     | `123456789012`         |
| Type        | Format of the barcode     | `EAN_13`               |
| Device      | Name of scanning device   | `Scanner-01`           |
| Location    | Device location           | `Warehouse A`          |

Example:

```csv
Timestamp,Barcode,Type,Device,Location
2025-02-05T14:31:23Z,123456789012,EAN_13,Scanner-01,Warehouse A
2025-02-05T14:32:45Z,987654321098,EAN_13,Scanner-01,Warehouse A
```

#### 2. Stock Summary (filename: session_{id}_summary.csv)

Aggregated counts for each unique barcode.

| Column Name | Description             | Example              |
|-------------|-------------------------|----------------------|
| Barcode     | Scanned barcode value   | 123456789012         |
| Count       | Total number of scans   | 5                    |
| First_Scan  | Timestamp of first scan | 2025-02-05T14:31:23Z |
| Last_Scan   | Timestamp of last scan  | 2025-02-05T15:42:12Z |
| Type        | Format of the barcode   | EAN_13               |

Example:

```csv
Barcode,Count,First_Scan,Last_Scan,Type
123456789012,5,2025-02-05T14:31:23Z,2025-02-05T15:42:12Z,EAN_13
987654321098,3,2025-02-05T14:32:45Z,2025-02-05T15:30:18Z,EAN_13
```

### FTP Export

When using FTP export, both CSV files are automatically uploaded to the configured FTP server in a
directory structure:

```
/scans/
  YYYY-MM-DD/
    session_{id}_events.csv
    session_{id}_summary.csv
```

### Integration Notes

1. HTTP Integration:
    - Supports both POST and GET methods
    - For GET requests, data is base64 encoded in query parameters
    - Basic authentication supported via headers
    - Content-Type: application/json
    - Expects 200 OK response for successful sync

2. FTP Integration:
    - Supports both FTP and SFTP
    - Creates date-based directories automatically
    - Files are written atomically (temp file then move)
    - Maintains consistent naming convention

3. Error Handling:
    - Failed syncs are retried automatically
    - Error details are stored with sessions
    - Manual sync option always available
    - Export files maintain data integrity with strict formatting

-------

# Scanner Instant Sync Protocol

## Overview

JSON-RPC inspired protocol for real-time scanner event synchronization. Each scan event is
immediately sent to the server, which responds with updated session data.

## Endpoints

### POST /api/v1/scanner/scan

Sync a single scan event in real-time.

Request:

```json
{
  "device_id": "scanner-123",
  "session_id": "session-456",
  "event": {
    "barcode": "123456789",
    "barcode_type": "EAN_13",
    "timestamp": "2025-02-02T15:30:00Z"
  },
  "session_data": {
    "name": "Warehouse Count",
    "location": "Warehouse A",
    "started_at": "2025-02-02T15:00:00Z"
  }
}
```

Response:

```json
{
  "success": true,
  "session": {
    "id": "session-456",
    "name": "Warehouse Count",
    "started_at": "2025-02-02T15:00:00Z",
    "events_count": 42,
    "unique_items": 12,
    "last_sync": "2025-02-02T15:30:00Z",
    "items": [
      {
        "barcode": "123456789",
        "count": 3,
        "last_seen": "2025-02-02T15:30:00Z",
        "product_name": "Widget X",  // Optional server-enriched data
        "stock_level": 150           // Optional server-enriched data
      }
    ]
  }
}
```

### POST /api/v1/scanner/sessions

Create or resume a scanning session.

Request:

```json
{
  "device_id": "scanner-123",
  "session": {
    "id": "session-456",
    "name": "Warehouse Count",
    "location": "Warehouse A",
    "started_at": "2025-02-02T15:00:00Z"
  }
}
```

Response:

```json
{
  "success": true,
  "session": {
    "id": "session-456",
    "name": "Warehouse Count",
    "events_count": 0,
    "unique_items": 0,
    "last_sync": "2025-02-02T15:00:00Z",
    "items": []
  }
}
```