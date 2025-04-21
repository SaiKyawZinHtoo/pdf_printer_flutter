import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
      if (!_isBluetoothOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bluetooth is not enabled')),
        );
        return;
      }
      _devices = await PrintBluetoothThermal.pairedBluetooths;
      setState(() {});
    } catch (e) {
      print("Error getting bonded devices: $e");
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

      final myanmarFont = await rootBundle.load(
        "assets/Pyidaungsu-2.5.3_Regular.ttf",
      );
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

    final myanmarFont = await rootBundle.load(
      "assets/Pyidaungsu-2.5.3_Regular.ttf",
    );
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
                      Text('Paired Devices:'),
                      Container(
                        height: 100,
                        child: ListView.builder(
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: Icon(Icons.print),
                              title: Text(_devices[index].name ?? 'Unknown'),
                              subtitle: Text(_devices[index].macAdress),
                              onTap: () => connectToDevice(_devices[index]),
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
