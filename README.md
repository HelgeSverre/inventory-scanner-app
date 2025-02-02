## Inventory Scanner

Universal inventory scanner used to scan barcodes and keep track of scan counts.
Supports various barcode formats and provides multiple options for data synchronization.

## Installation

```shell
fvm flutter pub get

fvm flutter pub run build_runner build --delete-conflicting-outputs

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
