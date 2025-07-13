import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' hide Printer;
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _flutterThermalPrinterPlugin = FlutterThermalPrinter.instance;
  List<Printer> printers = [];
  StreamSubscription<List<Printer>>? _devicesStreamSubscription;
  Printer? _connectedPrinter;
  List<Map<String, dynamic>> items = [];
  bool _connected = false;
  String? _connectedDeviceName;
  String? _connectedDeviceAddress;

  final TextEditingController numberController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startScan();
    });
  }

  void startScan() async {
    _devicesStreamSubscription?.cancel();
    await _flutterThermalPrinterPlugin.getPrinters(connectionTypes: [
      ConnectionType.USB,
      ConnectionType.BLE,
    ]);
    _devicesStreamSubscription = _flutterThermalPrinterPlugin.devicesStream
        .listen((List<Printer> event) {
      setState(() {
        printers = event;
        printers.removeWhere(
            (element) => element.name == null || element.name == '');
      });
    });
  }

  void stopScan() {
    _flutterThermalPrinterPlugin.stopScan();
  }

  Future<void> connectToPrinter(Printer printer) async {
    try {
      await _flutterThermalPrinterPlugin.connect(printer);
      setState(() {
        _connectedPrinter = printer;
        _connected = true;
        _connectedDeviceName = printer.name;
        _connectedDeviceAddress = printer.address;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${printer.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
  }

  Future<void> disconnectPrinter() async {
    if (_connectedPrinter == null) return;
    try {
      await _flutterThermalPrinterPlugin.disconnect(_connectedPrinter!);
      setState(() {
        _connectedPrinter = null;
        _connected = false;
        _connectedDeviceName = null;
        _connectedDeviceAddress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Printer disconnected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error disconnecting: $e')),
      );
    }
  }

  Future<void> printTicket() async {
    if (!_connected || _connectedPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please connect to a printer first')),
      );
      return;
    }
    try {
      print('[DEBUG] printTicket called');
      // Only print very short text receipts (max 2 items)
      if (items.length > 2) {
        print('[DEBUG] Too many items for Bluetooth print: ${items.length}');
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Bluetooth Printing Limitation'),
              content: const Text(
                  'Bluetooth printing with this printer only supports very short receipts (1-2 items). For longer receipts, please print in batches or use USB/WiFi.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }
      String receiptText = '===== Item List =====\n';
      receiptText += items
          .map((item) =>
              'No: ${item['number']} | Name: ${item['name']} | Price: ${item['price']} | Qty: ${item['quantity']} | Amt: ${item['amount']}')
          .join('\n');
      final bytes = utf8.encode(receiptText);
      print('[DEBUG] Receipt text length: ${receiptText.length}');
      print('[DEBUG] Receipt bytes length: ${bytes.length}');
      if (bytes.length > 200) {
        print(
            '[ERROR] Receipt too long for Bluetooth print: ${bytes.length} bytes');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Receipt too long for Bluetooth print. Please print fewer items.')),
        );
        return;
      }
      print(
          '[DEBUG] Sending printWidget to printer: ${_connectedPrinter?.name}');
      try {
        await _flutterThermalPrinterPlugin.printWidget(
          context,
          printer: _connectedPrinter!,
          printOnBle: true,
          widget: _buildReceiptWidget(receiptText),
        );
        print('[DEBUG] Printing completed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Printing completed')),
        );
      } catch (e) {
        print('[ERROR] PrintWidget error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing: $e')),
        );
      }
    } catch (e) {
      print('[ERROR] printTicket outer error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error printing: $e')),
      );
    }
  }

  Widget _buildReceiptWidget(String receiptText) {
    // Use a single Text widget for minimal Bluetooth data
    return Text(
      receiptText,
      style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
    );
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

    //final file = await pdf.save();
    //await Printing.sharePdf(bytes: file, filename: 'item_list.pdf');
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.yellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Bluetooth printing only supports very short receipts (1-2 items). For longer receipts, print in batches or use USB/WiFi.',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
              TextField(
                controller: numberController,
                decoration: const InputDecoration(labelText: 'Number'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                keyboardType: TextInputType.text,
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: addItem,
                      child: const Text('Add Item'),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton(
                        onPressed: saveAndSharePdf,
                        child: const Text('Save PDF'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton(
                        onPressed: _connected ? printTicket : null,
                        child: const Text('Print Ticket'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _connected
                  ? Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.green.withOpacity(0.1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Connected to $_connectedDeviceName',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Paired Devices',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: startScan,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        printers.isEmpty
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
                                    const Icon(
                                      Icons.bluetooth_disabled,
                                      size: 32,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 8),
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
                                  itemCount: printers.length,
                                  itemBuilder: (context, index) {
                                    final printer = printers[index];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      child: ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.print,
                                              color: Colors.blue),
                                        ),
                                        title: Text(printer.name ?? ''),
                                        subtitle: Text(
                                            'Type: ${printer.connectionTypeString}'),
                                        trailing: ElevatedButton(
                                          onPressed: () =>
                                              connectToPrinter(printer),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text(
                                              printer.isConnected == true
                                                  ? 'Disconnect'
                                                  : 'Connect'),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ],
                    ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
            ],
          ),
        ),
      ),
    );
  }
}
