import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'generate_pdf.dart'; // Import the generatePdf function

class CreateScreen extends StatefulWidget {
  @override
  _CreateScreenState createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  List<Map<String, dynamic>> items = [];

  final TextEditingController numberController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

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

    // Load the Myanmar font
    final myanmarFont = await rootBundle.load(
      "assets/Pyidaungsu-2.5.3_Regular.ttf",
    );
    final ttf = pw.Font.ttf(myanmarFont);

    // Define page format
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

    // Save the PDF document
    final file = await pdf.save();

    // Share the PDF document
    await Printing.sharePdf(bytes: file, filename: 'item_list.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Item')),
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
            ElevatedButton(onPressed: addItem, child: Text('Add Item')),
            ElevatedButton(
              onPressed: saveAndSharePdf,
              child: Text('Save and Share PDF'),
            ), // New button
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
