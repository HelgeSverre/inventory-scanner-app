## Inventory Scanner

Universal inventory scanner used to scan barcodes and keep track of scan counts.
Supports various barcode formats and provides multiple options for data synchronization.

## What this is for

This app is designed to be used in a warehouse or similar environment where you need to keep track
of inventory.

You scan a barcode, and the app will keep track of how many times you have scanned it. You can then
export the data to a CSV or JSON file, upload it to an FTP server, or send it to an HTTP endpoint to
use in your own systems.

This is meant to be "universal" in the sense that it can be configured to work with any system that
can accept CSV or JSON files, or HTTP requests.

## Key Features

- Scan barcodes using the device camera, each barcode is counted and displayed in a list.
- Supports multiple barcode
  formats [see supported formats](https://pub.dev/documentation/mobile_scanner/latest/mobile_scanner/BarcodeFormat.html).
- Can integrate with external systems using Sharing of CSV or JSON files, direct HTTP POST requests,
  or FTP uploads, also supports EPCIS events via HTTP Post.
- Configurable settings for device name, location, scan interval, and sync options.
- Bootstrap configuration using a remote JSON file (Fetch JSON config from a URL input or scan a QR
  code with the URL), for quick setup and configuration of new devices.
- Can work offline and sync data later when a connection is available.

## Installation

```shell
# Clone the repository
git clone git@github.com:HelgeSverre/inventory-scanner-app.git

# Change directory
cd inventory-scanner-app

# Install dependencies
fvm flutter pub get

# Generate files
fvm flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
fvm flutter run lib/main.dart -d 

# Format code
fvm dart format lib
```

## Remote JSON Config

The app can be configured using a remote JSON file. The file should be placed in a public location
and the URL should be provided in the app settings, or create a QR code with the URL and scan it in
the app.

### Example Config

This [gist](https://gist.githubusercontent.com/HelgeSverre/e2ce0369fd7492253f0b0ff8647e1c85/raw/d553b5b9951a46639b821ef5aa6a413b7e371da1/scanner.json)
can be used for testing.

```json
{
  "device": {
    "name": "Scanner-01",
    "location": "Warehouse-A"
  },
  "scanner": {
    "min_time_between_scans": 1000,
    "instant_sync": true
  },
  "http": {
    "enabled": true,
    "url": "https://api.example.com/scans",
    "auth": {
      "enabled": true,
      "username": "scanner1",
      "password": "secret123"
    }
  },
  "ftp": {
    "enabled": true,
    "server": "ftp.example.com",
    "port": "21",
    "username": "ftpuser",
    "password": "ftppass",
    "path": "/scans",
    "use_sftp": false
  },
  "epcis": {
    "namespace": "example",
    "device": "scanner-01",
    "location": "warehouse-a",
    "mode": "epcList",
    "url": "https://epcis.example.com/events"
  }
}
```

-----

## Data Formats

### Instant Sync (HTTP)

When instant sync is enabled, the app will send the scan data to the configured HTTP endpoint as
soon
as a scan is made. The data is sent as a JSON object with the following format:

```json
{
  "timestamp": "2025-02-02T07:34:38.515990",
  "barcode": "4009900484220",
  "format": "ean13",
  "session_id": "1738478072742",
  "session_name": "name of session",
  "device": "device-name-01",
  "location": "warehouse-name-here"
}
```

### HTTP Sync (Batch)

When instant sync is disabled, the app will send all session data in a single batch:

```json
{
  "session": {
    "id": "1738475273155",
    "name": "name of session",
    "startedAt": "2025-02-02T06:47:53.156847",
    "finishedAt": "2025-02-02T06:48:08.450879",
    "device": "Scanner-01",
    "location": "Warehouse-A"
  },
  "events": [
    {
      "timestamp": "2025-02-02T06:47:54.286864",
      "barcode": "9780201379525",
      "format": "ean13"
    }
  ],
  "summary": [
    {
      "barcode": "9780201379525",
      "count": 1
    }
  ]
}
```

### CSV Export

The app creates two CSV files for each export:

#### Event Log (session_[id]_events_[timestamp].csv)

Contains detailed records of each individual scan event:

| timestamp                  | barcode       | format | device     | location    | session_id    | session_name  |
|----------------------------|---------------|--------|------------|-------------|---------------|---------------|
| 2025-02-02T06:47:54.286864 | 9780201379525 | ean13  | Scanner-01 | Warehouse-A | 1738475273155 | Morning Count |
| 2025-02-02T06:48:12.123456 | 7310865004703 | ean13  | Scanner-01 | Warehouse-A | 1738475273155 | Morning Count |
| 2025-02-02T06:49:01.234567 | 4006381333931 | ean13  | Scanner-01 | Warehouse-A | 1738475273155 | Morning Count |
| 2025-02-02T06:49:45.345678 | 7310865004703 | ean13  | Scanner-01 | Warehouse-A | 1738475273155 | Morning Count |
| 2025-02-02T06:50:22.456789 | 8710847111605 | ean13  | Scanner-01 | Warehouse-A | 1738475273155 | Morning Count |
| 2025-02-02T06:51:15.567890 | 4006381333931 | ean13  | Scanner-01 | Warehouse-A | 1738475273155 | Morning Count |

#### Inventory Summary (session_[id]_inventory_[timestamp].csv)

Contains aggregated statistics for each unique barcode:

| device     | location    | barcode       | format | count | first_scan                 | last_scan                  | session_id    | session_name  |
|------------|-------------|---------------|--------|-------|----------------------------|----------------------------|---------------|---------------|
| Scanner-01 | Warehouse-A | 9780201379525 | ean13  | 1     | 2025-02-02T06:47:54.286864 | 2025-02-02T06:47:54.286864 | 1738475273155 | Morning Count |
| Scanner-01 | Warehouse-A | 7310865004703 | ean13  | 2     | 2025-02-02T06:48:12.123456 | 2025-02-02T06:49:45.345678 | 1738475273155 | Morning Count |
| Scanner-01 | Warehouse-A | 4006381333931 | ean13  | 2     | 2025-02-02T06:49:01.234567 | 2025-02-02T06:51:15.567890 | 1738475273155 | Morning Count |
| Scanner-01 | Warehouse-A | 8710847111605 | ean13  | 1     | 2025-02-02T06:50:22.456789 | 2025-02-02T06:50:22.456789 | 1738475273155 | Morning Count |

### EPCIS Integration

The app supports exporting data in EPCIS 2.0 format (Electronic Product Code Information Services),
which is a GS1 standard for sharing supply chain event data between trading partners. EPCIS provides
a standardized way to track and share information about the movement and status of products as they
travel through the supply chain.

#### Core EPCIS Concepts:

- **What**: The objects being tracked (identified by EPCs)
- **When**: The time the event occurred
- **Where**: The location of the objects (readPoint and bizLocation)
- **Why**: The business context (bizStep and disposition)

The app supports two different EPCIS event types:

#### 1. Individual Scans (ObjectEvent)

Uses `epcList` mode to record each scan as a separate observation. Best for tracking individual
items and maintaining detailed scan history.

```json
{
  "epcisVersion": "2.0",
  "schemaVersion": "2.0",
  "creationDate": "2025-02-02T07:34:38.515990",
  "epcisBody": {
    "eventList": [
      {
        "type": "ObjectEvent",
        "eventTime": "2025-02-02T07:34:38.515990",
        "eventTimeZoneOffset": "+00:00",
        "epcList": [
          "urn:example:item:9780201379525"
        ],
        "action": "OBSERVE",
        "bizStep": "urn:epcglobal:cbv:btt:inventory_check",
        "disposition": "urn:epcglobal:cbv:disp:in_progress",
        "readPoint": {
          "id": "urn:example:location:warehouse-a"
        },
        "bizLocation": {
          "id": "urn:example:device:scanner-01"
        }
      }
    ]
  }
}
```

Key fields:

- `type`: "ObjectEvent" indicates an observation of objects
- `epcList`: Array of scanned items in EPC URI format
- `action`: "OBSERVE" indicates items were seen but not changed
- `bizStep`: Indicates this was an inventory check operation
- `readPoint`: The specific location where the scan occurred
- `bizLocation`: The broader business context of the scan

#### 2. Aggregated Counts (AggregationEvent)

Uses `quantityList` mode to record total counts for each unique barcode. Better for bulk inventory
counts where individual scan timing isn't critical.

```json
{
  "epcisVersion": "2.0",
  "schemaVersion": "2.0",
  "creationDate": "2025-02-02T07:34:38.515990",
  "epcisBody": {
    "eventList": [
      {
        "type": "AggregationEvent",
        "eventTime": "2025-02-02T07:34:38.515990",
        "eventTimeZoneOffset": "+00:00",
        "parentID": "urn:example:location:warehouse-a",
        "childEPCs": [],
        "quantityList": [
          {
            "epcClass": "urn:example:item:9780201379525",
            "quantity": 3
          }
        ],
        "action": "ADD",
        "bizStep": "urn:epcglobal:cbv:btt:inventory_check",
        "readPoint": {
          "id": "urn:example:location:warehouse-a"
        },
        "bizLocation": {
          "id": "urn:example:device:scanner-01"
        }
      }
    ]
  }
}
```

Key fields:

- `type`: "AggregationEvent" indicates grouping of objects
- `parentID`: The location containing the items
- `quantityList`: Array of item counts by type
- `action`: "ADD" indicates items were added to the location
- `bizStep`: Same as ObjectEvent, indicates inventory check
- `readPoint`/`bizLocation`: Same as ObjectEvent

The app follows the EPCIS 2.0 specification for event structure and vocabulary. For more details on
EPCIS event types, fields, and best practices, refer to
the [GS1 EPCIS 2.0 Specification](https://ref.gs1.org/epcis/?show=classes).

### FTP Export

When using FTP export, the app creates a directory structure like this:

```
/scans/                           # Base directory (configurable)
  └── YYYY-MM-DD/                 # Date-based subdirectories
      ├── session_[id]_events_[timestamp].csv      # Event log
      └── session_[id]_inventory_[timestamp].csv    # Inventory summary
```

The CSV files follow the same format as described in the CSV Export section above.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details.
