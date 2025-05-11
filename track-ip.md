# Advanced IP Scanner Setup for ADB Connection via MAC Address

## Overview

This project outlines a systematic method for locating a mobile device on a local network using its **MAC address**. The purpose is to identify the device's dynamic IP address in order to enable ADB (Android Debug Bridge) access over TCP/IP for remote control—particularly useful when the screen is physically damaged but still responsive.

---

## Objective

- **Scan a specified IP range** within the local network.
- **Identify the device** with the known MAC address: `04:C8:07:19:19:80`
- **Establish ADB connection** over port `5555` using the identified IP.

---

## Tools Required

- [Advanced IP Scanner](https://www.advanced-ip-scanner.com/) (Windows)
- USB debugging and Wireless debugging must already be enabled on the phone.
- ADB installed on your system.

---

## Scan Instructions

1. **Launch** Advanced IP Scanner.

2. **Enter the IP range** to scan:
```

10.10.8.1 - 10.10.15.254

```

3. **Start Scan** by clicking the **Scan** button.

4. **Search for the MAC address**:
```

04:C8:07:19:19:80

````
Use the search box or manually locate it in the list.

5. **Note the corresponding IP address** once the MAC is found.

---

## Connect via ADB

Once the IP address of the phone is identified:

```bash
adb connect <device-ip>:5555
````

Example:

```bash
adb connect 10.10.9.12:5555
```

> ⚠️ Ensure `adb tcpip 5555` was executed previously while the phone was connected via USB and Wireless Debugging was enabled.

---

## Additional Notes

* Keep your device and PC on the same Wi-Fi network.
* If the device reboots, its IP may change. Repeat the scan to find the new address.
* Use `adb devices` to confirm connection.

---

## Disclaimer

This method is intended for personal use in recovery or accessibility scenarios. Ensure network scanning is permitted within your organization's or ISP's acceptable use policy.

---
