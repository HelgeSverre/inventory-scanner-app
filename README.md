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

## Features

- Scan barcodes using the device camera, each barcode is counted and displayed in a list.
- Supports multiple barcode
  formats [see supported formats](https://pub.dev/documentation/mobile_scanner/latest/mobile_scanner/BarcodeFormat.html).
- Can integrate with external systems using Sharing of CSV or JSON files, direct HTTP POST requests,
  or FTP uploads, also supports EPCIS events via HTTP Post.
-

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
