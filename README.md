## Inventory Scanner

Universal inventory scanner used to scan barcodes and keep track of scan counts.
Supports various barcode formats and provides multiple options for data synchronization.

## What this is for

This app is designed for use in warehouses and similar environments where you need to track
inventory counts. When you scan a barcode, the app keeps track of how many times you have scanned
it, maintaining a running count for each unique barcode.

The app offers multiple ways to get this data into your existing systems. You can export scans to
CSV or JSON files, upload them directly to FTP servers, send them to HTTP endpoints, or integrate
with supply chain systems through EPCIS. This flexibility makes it suitable for integration with
virtually any inventory management system.

## Key Features

- Scan barcodes using the device camera with real-time count tracking
- Support for multiple barcode formats including EAN-13, Code 128, QR Code, and
  others ([see supported formats](https://pub.dev/documentation/mobile_scanner/latest/mobile_scanner/BarcodeFormat.html))
- Export options:
    - CSV files with detailed scan logs and inventory summaries
    - JSON export of complete scan sessions
    - Direct HTTP POST of scan data
    - FTP/FTPS file uploads
    - EPCIS 2.0 compliant event export
- Configurable settings for device name, location, scan interval, and sync options
- Remote configuration through JSON files (via URL or QR code scan)
- Offline-capable with batch synchronization support

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

## Remote Configuration

The app can be bootstrapped using a remote JSON configuration file. You can either enter the URL
directly in settings or scan a QR code containing the configuration URL. This makes it easy to
deploy and configure multiple devices with the same settings.

### Example Configuration File

This [configuration example](https://gist.githubusercontent.com/HelgeSverre/06f23f064a8c717dda87d1f0cd9cca9b/raw/765b58f84a7c3c3eea931c23c524edaca439613d/inventory-scanner-remote-config.json)
can be used as a starting point:

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
    "path": "/scans/[LOCATION]/[DEVICE]/[YEAR]/[MONTH]/[SESSION_NAME]_[TYPE]_[TIMESTAMP].csv",
    "use_ftps": false,
    "timeout": 30,
    "transfer_mode": "passive",
    "transfer_type": "auto"
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

## Data Export Features

### HTTP Integration

The app provides two methods for sending scan data via HTTP:

#### HTTP Instant Sync

When instant sync is enabled, each scan is immediately sent to your configured endpoint. This is
useful for real-time inventory tracking:

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

#### HTTP Batch Sync

When instant sync is disabled, complete scanning sessions are sent in batches. This includes
comprehensive session information, all scan events, and summary statistics:

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

HTTP sync supports basic authentication and custom endpoints, making it suitable for integration
with most web-based inventory systems.

### File-Based Export

The app generates two types of CSV files for detailed record-keeping:

#### Event Log CSV

The event log (session_[id]_events_[timestamp].csv) contains a detailed record of every scan,
including:

- Exact timestamp of each scan
- Barcode value and format
- Device and location information
- Session tracking data

Example event log:

| timestamp                  | barcode       | format | device     | location    | session_id    | session_name  |
|----------------------------|---------------|--------|------------|-------------|---------------|---------------|
| 2025-02-02T06:47:54.286864 | 9780201379525 | ean13  | Scanner-01 | Warehouse-A | 1738475273155 | Morning Count |
| 2025-02-02T06:48:12.123456 | 7310865004703 | ean13  | Scanner-01 | Warehouse-A | 1738475273155 | Morning Count |
| 2025-02-02T06:49:01.234567 | 4006381333931 | ean13  | Scanner-01 | Warehouse-A | 1738475273155 | Morning Count |
| 2025-02-02T06:49:45.345678 | 7310865004703 | ean13  | Scanner-01 | Warehouse-A | 1738475273155 | Morning Count |
| 2025-02-02T06:50:22.456789 | 8710847111605 | ean13  | Scanner-01 | Warehouse-A | 1738475273155 | Morning Count |
| 2025-02-02T06:51:15.567890 | 4006381333931 | ean13  | Scanner-01 | Warehouse-A | 1738475273155 | Morning Count |

#### Inventory Summary CSV

The summary file (session_[id]_inventory_[timestamp].csv) provides aggregated statistics for each
unique barcode:

- Total count per barcode
- First and last scan times
- Device and location context
- Session information

Example summary:

| device     | location    | barcode       | format | count | first_scan                 | last_scan                  | session_id    | session_name  |
|------------|-------------|---------------|--------|-------|----------------------------|----------------------------|---------------|---------------|
| Scanner-01 | Warehouse-A | 9780201379525 | ean13  | 1     | 2025-02-02T06:47:54.286864 | 2025-02-02T06:47:54.286864 | 1738475273155 | Morning Count |
| Scanner-01 | Warehouse-A | 7310865004703 | ean13  | 2     | 2025-02-02T06:48:12.123456 | 2025-02-02T06:49:45.345678 | 1738475273155 | Morning Count |
| Scanner-01 | Warehouse-A | 4006381333931 | ean13  | 2     | 2025-02-02T06:49:01.234567 | 2025-02-02T06:51:15.567890 | 1738475273155 | Morning Count |
| Scanner-01 | Warehouse-A | 8710847111605 | ean13  | 1     | 2025-02-02T06:50:22.456789 | 2025-02-02T06:50:22.456789 | 1738475273155 | Morning Count |

### FTP Integration

The app provides comprehensive FTP support with multiple configuration options to ensure
compatibility with various FTP server setups:

#### Security Options

- Plain FTP: Standard unencrypted FTP using port 21
- FTPS: FTP over SSL/TLS, typically using port 990, providing encrypted data transfer

#### Transfer Mode Options

- **Passive Mode** (Default): Ideal for most modern networks, especially when connecting through
  firewalls. In this mode, the client initiates all connections, making it more firewall-friendly.
- **Active Mode**: Traditional FTP mode where the server initiates the data connection. Useful in
  specific network configurations or with legacy FTP servers.

#### Transfer Type Options

- **Auto-detect** (Default): Automatically selects the appropriate transfer mode:
    - ASCII for CSV files (handles line ending conversions)
    - Binary for all other file types
- **ASCII Mode**: Specifically for text files, handles line ending conversions between different
  operating systems
- **Binary Mode**: Raw data transfer suitable for all file types, ensures exact byte-for-byte copies

### Flexible Path Configuration

The app supports flexible FTP path configuration using placeholders. You can customize both the
directory structure and filenames in a single path template.

#### Available Placeholders

- `[DATE]` = Current date (YYYY-MM-DD)
- `[YEAR]` = Current year
- `[MONTH]` = Current month (01-12)
- `[DAY]` = Current day (01-31)
- `[DEVICE]` = Device name from settings
- `[LOCATION]` = Device location from settings
- `[SESSION_ID]` = Unique session identifier
- `[SESSION_NAME]` = Name of the scan session
- `[TYPE]` = File type ("events" or "inventory")
- `[TIMESTAMP]` = Full ISO timestamp

#### Example Path Templates

1. Simple date-based organization (default):

```
/scans/[DATE]/session_[SESSION_ID]_[TYPE].csv
→ /scans/2025-02-02/session_1738475273155_events.csv
```

2. Location and device-based organization:

```
/inventory/[LOCATION]/[DEVICE]/[DATE]_[SESSION_NAME]_[TYPE].csv
→ /inventory/warehouse-a/scanner-01/2025-02-02_morning-count_events.csv
```

3. Year/month based archival structure:

```
/scans/[YEAR]/[MONTH]/[DEVICE]_[SESSION_NAME]_[TYPE]_[TIMESTAMP].csv
→ /scans/2025/02/scanner-01_morning-count_events_2025-02-02T06-47-53.csv
```

The app automatically creates any required directories in the specified path. You can configure the
path template through the settings screen or the remote configuration file.

### EPCIS Integration

The app supports EPCIS 2.0 (Electronic Product Code Information Services), a GS1 standard designed
for sharing supply chain event data between trading partners. EPCIS integration is particularly
valuable for organizations that need to:

- Track product movement through the supply chain
- Share inventory data with trading partners
- Maintain compliance with traceability requirements
- Integrate with larger supply chain management systems

#### Why EPCIS?

EPCIS provides a standardized way to answer four essential questions about inventory:

- What: The objects being tracked (identified by EPCs)
- When: The time each event occurred
- Where: The location of objects (both read point and business location)
- Why: The business context (business step and disposition)

The app supports two EPCIS event types, each suited for different use cases:

#### 1. Individual Scans (ObjectEvent)

Uses `epcList` mode to record each scan as a separate observation. This mode is ideal for:

- Tracking individual items through the supply chain
- Maintaining detailed scan history
- Compliance with item-level traceability requirements

Example ObjectEvent:

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

#### 2. Aggregated Counts (AggregationEvent)

Uses `quantityList` mode to record total counts for each unique barcode. This mode is better for:

- Bulk inventory counts
- Situations where individual scan timing isn't critical
- Reducing data volume in high-throughput environments

Example AggregationEvent:

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

For more details on EPCIS event types, fields, and best practices, refer to
the [GS1 EPCIS 2.0 Specification](https://ref.gs1.org/epcis/).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details.
