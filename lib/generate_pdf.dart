import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // Import the printing package

Future<void> generatePdf(
  String printerSize,
  List<Map<String, dynamic>> items,
) async {
  final pdf = pw.Document();

  // Load the Myanmar font
  final myanmarFont = await rootBundle.load(
    "assets/Pyidaungsu-2.5.3_Regular.ttf",
  );
  final ttf = pw.Font.ttf(myanmarFont);

  // Change page size based on selected printer type
  PdfPageFormat format;

  switch (printerSize) {
    case '58mm':
      format = PdfPageFormat(58 * PdfPageFormat.mm, double.infinity);
      break;
    case '80mm':
      format = PdfPageFormat(80 * PdfPageFormat.mm, double.infinity);
      break;
    case '110mm':
      format = PdfPageFormat(110 * PdfPageFormat.mm, double.infinity);
      break;
    default:
      format = PdfPageFormat.a4;
  }

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
  await Printing.sharePdf(bytes: file, filename: 'invoice.pdf');
}
