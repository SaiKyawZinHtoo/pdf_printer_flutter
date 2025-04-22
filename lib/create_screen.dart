import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'generate_pdf.dart';

class CreateScreen extends StatefulWidget {
  @override
  _CreateScreenState createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  List<Map<String, dynamic>> items = [];
  bool _connected = false;
  List<BluetoothInfo> _devices = [];
  String? _connectedDeviceName;
  bool _isBluetoothOn = false;

  final TextEditingController numberController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkBluetoothStatus();
    getBondedDevices();
    _checkPrinterConnection();
  }

  Future<void> checkBluetoothStatus() async {
    try {
      final bool result = await PrintBluetoothThermal.bluetoothEnabled;
      setState(() {
        _isBluetoothOn = result;
      });
      if (!result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please turn on Bluetooth')),
        );
      }
    } catch (e) {
      print("Error checking Bluetooth status: $e");
    }
  }

  Future<void> _checkPrinterConnection() async {
    try {
      final bool connectionStatus =
          await PrintBluetoothThermal.connectionStatus;
      setState(() {
        _connected = connectionStatus;
      });
    } catch (e) {
      print("Error checking printer connection: $e");
    }
  }

  Future<void> disconnectPrinter() async {
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      setState(() {
        _connected = false;
        _connectedDeviceName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(result ? 'Printer disconnected' : 'Failed to disconnect')),
      );
    } catch (e) {
      print("Error disconnecting printer: $e");
    }
  }

  void addItem() {
    setState(() {
      items.add({
        'number': numberController.text,
        'name': nameController.text,
        'price': double.tryParse(priceController.text) ?? 0.0,
        'quantity': int.tryParse(quantityController.text) ?? 0,
        'amount': double.tryParse(amountController.text) ?? 0.0,
      });
      numberController.clear();
      nameController.clear();
      priceController.clear();
      quantityController.clear();
      amountController.clear();
    });
  }

  Future<void> getBondedDevices() async {
    try {
      // Request runtime permissions first
      if (!await _requestPermissions()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Please grant Bluetooth permissions in settings')),
        );
        return;
      }
      // First check Bluetooth status
      final bool isEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      print("Bluetooth Status: $isEnabled"); // Debug log

      if (!isEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bluetooth is not enabled')),
        );
        return;
      }

      // Get paired devices
      final List<BluetoothInfo> devices =
          await PrintBluetoothThermal.pairedBluetooths;
      print("Found ${devices.length} paired devices"); // Debug log

      // Print each device for debugging
      devices.forEach((device) {
        print("Device: ${device.name} - ${device.macAdress}");
      });

      setState(() {
        _devices = devices;
      });

      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No paired devices found. Please pair your printer in system settings')),
        );
      }
    } catch (e) {
      print("Error getting bonded devices: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finding paired devices: $e')),
      );
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      // Request Bluetooth permissions
      final List<String> permissions = [
        'android.permission.BLUETOOTH',
        'android.permission.BLUETOOTH_ADMIN',
        'android.permission.BLUETOOTH_CONNECT',
        'android.permission.BLUETOOTH_SCAN',
        'android.permission.ACCESS_FINE_LOCATION',
      ];

      // Use permission_handler package to request permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();

      // Check if all permissions are granted
      bool allGranted = true;
      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          allGranted = false;
        }
      });

      return allGranted;
    } catch (e) {
      print("Error requesting permissions: $e");
      return false;
    }
  }

  Future<void> connectToDevice(BluetoothInfo device) async {
    try {
      String mac = "66:02:BD:06:18:7B"; // Example MAC address
      final bool result =
          await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      setState(() {
        _connected = result;
        _connectedDeviceName = result ? device.name : null;
      });
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${device.name}')),
        );
      }
    } catch (e) {
      print("Error connecting to device: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
  }

  Future<void> printTicket() async {
    if (!_connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please connect to a printer first')),
      );
      return;
    }

    try {
      final pdf = pw.Document();
      final myanmarFont =
          await rootBundle.load("assets/Pyidaungsu-2.5.3_Regular.ttf");
      final ttf = pw.Font.ttf(myanmarFont);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                    child: pw.Text("===== Item List =====",
                        style: pw.TextStyle(font: ttf))),
                pw.SizedBox(height: 10),
                ...items
                    .map((item) => pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("Number: ${item['number']}",
                                style: pw.TextStyle(font: ttf)),
                            pw.Text("Name: ${item['name']}",
                                style: pw.TextStyle(font: ttf)),
                            pw.Text("Price: ${item['price']}",
                                style: pw.TextStyle(font: ttf)),
                            pw.Text("Quantity: ${item['quantity']}",
                                style: pw.TextStyle(font: ttf)),
                            pw.Text("Amount: ${item['amount']}",
                                style: pw.TextStyle(font: ttf)),
                            pw.Text("------------------------",
                                style: pw.TextStyle(font: ttf)),
                          ],
                        ))
                    .toList(),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final printer = await Printing.pickPrinter(context: context);

      if (printer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No printer selected')),
        );
        return;
      }

      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (_) => pdfBytes,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Printing completed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error printing: $e')),
      );
    }
  }

  Future<void> saveAndSharePdf() async {
    final pdf = pw.Document();
    final myanmarFont =
        await rootBundle.load("assets/Pyidaungsu-2.5.3_Regular.ttf");
    final ttf = pw.Font.ttf(myanmarFont);
    PdfPageFormat format = PdfPageFormat.a4;

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text("Item List", style: pw.TextStyle(font: ttf)),
              ...items.map(
                (item) => pw.Text(
                  'Number: ${item['number']}, Name: ${item['name']}, Price: ${item['price']}, Quantity: ${item['quantity']}, Amount: ${item['amount']}',
                  style: pw.TextStyle(font: ttf),
                ),
              ),
            ],
          );
        },
      ),
    );

    final file = await pdf.save();
    await Printing.sharePdf(bytes: file, filename: 'item_list.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Item'),
        actions: [
          if (_connected)
            IconButton(
              icon: Icon(Icons.print_disabled),
              onPressed: disconnectPrinter,
              tooltip: 'Disconnect Printer',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: numberController,
              decoration: InputDecoration(labelText: 'Number'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: priceController,
              decoration: InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: quantityController,
              decoration: InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: amountController,
              decoration: InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: addItem,
                  child: Text('Add Item'),
                ),
                ElevatedButton(
                  onPressed: saveAndSharePdf,
                  child: Text('Save PDF'),
                ),
                ElevatedButton(
                  onPressed: _connected ? printTicket : null,
                  child: Text('Print Ticket'),
                ),
              ],
            ),
            SizedBox(height: 20),
            _connected
                ? Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.green.withOpacity(0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Connected to $_connectedDeviceName',
                          style: TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Paired Devices',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: getBondedDevices,
                            icon: Icon(Icons.refresh),
                            label: Text('Refresh'),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      _devices.isEmpty
                          ? Container(
                              height: 100,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bluetooth_disabled,
                                    size: 32,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No paired devices found',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                itemCount: _devices.length,
                                itemBuilder: (context, index) {
                                  final device = _devices[index];
                                  return Card(
                                    margin: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    child: ListTile(
                                      leading: Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.print,
                                            color: Colors.blue),
                                      ),
                                      title: Text(
                                        device.name ?? 'Unknown Device',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(device.macAdress),
                                      trailing: ElevatedButton(
                                        onPressed: () =>
                                            connectToDevice(device),
                                        child: Text('Connect'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ],
                  ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(item['name']),
                    subtitle: Text(
                      'Number: ${item['number']}, Price: ${item['price']}, Quantity: ${item['quantity']}, Amount: ${item['amount']}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
