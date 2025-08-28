import 'dart:io';
import 'dart:typed_data';

import 'package:downloads_path_provider_28/downloads_path_provider_28.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const InvoiceApp());

class InvoiceApp extends StatelessWidget {
  const InvoiceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SB Invoice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F45E4)),
        useMaterial3: true,
      ),
      home: const InvoiceFormPage(),
    );
  }
}

class InvoiceFormPage extends StatefulWidget {
  const InvoiceFormPage({super.key});
  @override
  State<InvoiceFormPage> createState() => _InvoiceFormPageState();
}

class _InvoiceFormPageState extends State<InvoiceFormPage> {
  final _formKey = GlobalKey<FormState>();

  // --- Locked Theme Defaults (Your Business) ---
  final _ourName = TextEditingController(text: "SHRI BALAJI TRADERS");
  final _ourAddr = TextEditingController(text: "NTPC ke saamne, 400m from Patan Bypass Chowk, Jabalpur, MP - 482002");
  final _ourGstin = TextEditingController(text: "23CUFPK3217C2Z7");
  final _stateLine = "State Name : Madhya Pradesh, Code : 23";

  // Bank details
  final _bankHolder = TextEditingController(text: "SHRI BALAJI TRADERS");
  final _bankName = TextEditingController(text: "UNION BANK OF INDIA");
  final _bankAcc = TextEditingController(text: "586801010050541");
  final _bankIfsc = TextEditingController(text: "UBIN0558681");

  // --- Invoice fields ---
  final _invoiceNo = TextEditingController();
  final _invoiceDate = TextEditingController(text: DateFormat("dd/MM/yyyy").format(DateTime.now()));

  // Customer
  final _custName = TextEditingController(text: "SPN Interior Projects LLP");
  final _custAddr = TextEditingController(text: "Jabalpur");
  final _custGstin = TextEditingController(text: "27AELFS4774C1ZQ");

  // Item
  final _itemDesc = TextEditingController(text: "Cement Bag");
  final _qtyCtrl = TextEditingController(text: "50");
  final _baseCtrl = TextEditingController(text: "282.81");
  final _gstPercentCtrl = TextEditingController(text: "28");

  // Calcs
  double qty = 0;
  double base = 0;
  double subTotal = 0;
  double gstPercent = 28;
  double gst = 0, cgst = 0, sgst = 0, roundOff = 0, grandTotal = 0;

  @override
  void initState() {
    super.initState();
    _generateNextInvoiceNumber();
    _recalc();
    _qtyCtrl.addListener(_recalc);
    _baseCtrl.addListener(_recalc);
    _gstPercentCtrl.addListener(_recalc);
  }

  Future<void> _generateNextInvoiceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final yy = DateFormat("yy").format(now);
    final mon = DateFormat("MMM").format(now).toUpperCase(); // AUG, SEP, etc.
    final key = "counter_$yy$mon";
    int counter = prefs.getInt(key) ?? 0;
    counter += 1;
    await prefs.setInt(key, counter);
    final number = counter.toString().padLeft(3, '0');
    _invoiceNo.text = "SB/$yy/$mon/$number";
    setState(() {});
  }

  void _recalc() {
    setState(() {
      qty = double.tryParse(_qtyCtrl.text) ?? 0;
      base = double.tryParse(_baseCtrl.text) ?? 0;
      gstPercent = double.tryParse(_gstPercentCtrl.text) ?? 0;

      subTotal = qty * base;
      gst = (subTotal * gstPercent / 100);
      cgst = gst / 2;
      sgst = gst / 2;

      final totalBeforeRound = subTotal + gst;
      grandTotal = totalBeforeRound.roundToDouble();
      roundOff = grandTotal - totalBeforeRound;
      // Keep two decimals clean
      subTotal = double.parse(subTotal.toStringAsFixed(2));
      gst = double.parse(gst.toStringAsFixed(2));
      cgst = double.parse(cgst.toStringAsFixed(2));
      sgst = double.parse(sgst.toStringAsFixed(2));
      grandTotal = double.parse(grandTotal.toStringAsFixed(2));
      roundOff = double.parse(roundOff.toStringAsFixed(2));
    });
  }

  Future<Uint8List> _buildPdf() async {
    final pdf = pw.Document();
    final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10);
    final normal = const pw.TextStyle(fontSize: 10);
    final small = const pw.TextStyle(fontSize: 9);

    pw.Widget titledBox(String title, List<pw.Widget> children) => pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: bold),
          pw.SizedBox(height: 4),
          ...children,
        ],
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(pw.Text("Tax Invoice", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 4),
              pw.Center(pw.Text(_ourName.text, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
              pw.Center(pw.Text(_ourAddr.text, style: small)),
              pw.Center(pw.Text("GSTIN/UIN: ${_ourGstin.text}", style: small)),
              pw.Center(pw.Text("State Name :  Madhya Pradesh, Code : 23", style: small)),
              pw.SizedBox(height: 8),

              // Consignee & Buyer (side by side)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: titledBox("Consignee (Ship to)", [
                      pw.Text("Name: ${_custName.text}", style: normal),
                      pw.Text("Address: ${_custAddr.text}", style: normal),
                      pw.Text("GSTIN/UIN : ${_custGstin.text}", style: normal),
                      pw.Text(_stateLine, style: normal),
                    ]),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: titledBox("Buyer (Bill to)", [
                      pw.Text("Name: ${_custName.text}", style: normal),
                      pw.Text("Address: ${_custAddr.text}", style: normal),
                      pw.Text("GSTIN/UIN : ${_custGstin.text}", style: normal),
                      pw.Text(_stateLine, style: normal),
                    ]),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              // Invoice info grid
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Invoice No.\n${_invoiceNo.text}", style: normal)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Dated\n${_invoiceDate.text}", style: normal)),
                  ]),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Delivery Note\n", style: normal)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Mode/Terms of Payment\n", style: normal)),
                  ]),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Reference No. & Date\n", style: normal)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Other References\n", style: normal)),
                  ]),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Buyer's Order No.\n", style: normal)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Delivery Note Date\n", style: normal)),
                  ]),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Dispatch Doc No.\n", style: normal)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Destination\n", style: normal)),
                  ]),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Dispatched through\n", style: normal)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Terms of Delivery\n", style: normal)),
                  ]),
                ],
              ),

              pw.SizedBox(height: 8),

              // Items Table (locked columns like your template)
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(40),
                  5: const pw.FixedColumnWidth(70),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Sl No.", style: bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Description of Goods", style: bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Quantity", style: bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Rate", style: bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Per", style: bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Amount", style: bold)),
                    ],
                  ),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("1", style: normal)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_itemDesc.text, style: normal)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_qtyCtrl.text, style: normal)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(double.tryParse(_baseCtrl.text)?.toStringAsFixed(2) ?? "0.00", style: normal, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("BAG", style: normal)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(subTotal.toStringAsFixed(2), style: normal, textAlign: pw.TextAlign.right)),
                  ]),
                ],
              ),

              pw.SizedBox(height: 8),

              // Totals like template
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FixedColumnWidth(120)},
                children: [
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Output CGST ${(gstPercent/2).toStringAsFixed(0)}%", style: normal)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(cgst.toStringAsFixed(2), style: normal, textAlign: pw.TextAlign.right)),
                  ]),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Output SGST ${(gstPercent/2).toStringAsFixed(0)}%", style: normal)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(sgst.toStringAsFixed(2), style: normal, textAlign: pw.TextAlign.right)),
                  ]),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Round OFF", style: normal)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(roundOff.toStringAsFixed(2), style: normal, textAlign: pw.TextAlign.right)),
                  ]),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Total", style: bold)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Rs. ${grandTotal.toStringAsFixed(2)}", style: bold, textAlign: pw.TextAlign.right)),
                  ]),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Text("Amount Chargeable (in words): INR ${_amountInWords(grandTotal)} Only", style: normal),
              ),

              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Text("Declaration:\nWe declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.", style: normal),
              ),

              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Company's Bank Details", style: bold),
                    pw.SizedBox(height: 4),
                    pw.Text("A/c Holder's Name : ${_bankHolder.text}", style: normal),
                    pw.Text("Bank Name : ${_bankName.text}", style: normal),
                    pw.Text("A/c No. : ${_bankAcc.text}", style: normal),
                    pw.Text("Branch & IFSC Code : ${_bankIfsc.text}", style: normal),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Customer's Seal and Signature", style: normal),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("For ${_ourName.text}", style: normal),
                      pw.SizedBox(height: 22),
                      pw.Text("Authorised Signatory", style: normal),
                    ],
                  )
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  String _amountInWords(double value) {
    // Simple integer-only words
    final intPart = value.round();
    final f = NumberFormat.currency(locale: "en_IN", symbol: "", decimalDigits: 0);
    // Represent with commas (not true words to keep simple)
    return f.format(intPart);
  }

  Future<File> _savePdfToDownloads(Uint8List bytes, String filename) async {
    // Try Downloads folder (Android 10+ compatibility)
    final downloadsDir = await DownloadsPathProvider.downloadsDirectory;
    Directory dir;
    if (downloadsDir != null) {
      dir = Directory(downloadsDir.path);
    } else {
      // fallback to external storage
      dir = (await getExternalStorageDirectory())!;
    }
    final file = File("${dir.path}/$filename");
    await file.writeAsBytes(bytes);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SB Invoice Generator"),
        actions: [
          IconButton(
            tooltip: "Next Invoice No",
            onPressed: () => _generateNextInvoiceNumber(),
            icon: const Icon(Icons.confirmation_number_outlined),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Our Details", style: Theme.of(context).textTheme.titleMedium),
              TextFormField(controller: _ourName, decoration: const InputDecoration(labelText: "Business Name")),
              TextFormField(controller: _ourAddr, decoration: const InputDecoration(labelText: "Business Address")),
              TextFormField(controller: _ourGstin, decoration: const InputDecoration(labelText: "Our GSTIN")),
              const SizedBox(height: 12),

              Text("Customer Details", style: Theme.of(context).textTheme.titleMedium),
              TextFormField(controller: _custName, decoration: const InputDecoration(labelText: "Customer Name")),
              TextFormField(controller: _custAddr, decoration: const InputDecoration(labelText: "Customer Address")),
              TextFormField(controller: _custGstin, decoration: const InputDecoration(labelText: "Customer GSTIN")),
              const SizedBox(height: 12),

              Text("Invoice Details", style: Theme.of(context).textTheme.titleMedium),
              TextFormField(controller: _invoiceNo, decoration: const InputDecoration(labelText: "Invoice Number")),
              TextFormField(controller: _invoiceDate, decoration: const InputDecoration(labelText: "Invoice Date (dd/MM/yyyy)")),
              const SizedBox(height: 12),

              Text("Item", style: Theme.of(context).textTheme.titleMedium),
              TextFormField(controller: _itemDesc, decoration: const InputDecoration(labelText: "Description")),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Quantity"))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _baseCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Base Price / Bag"))),
                ],
              ),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _gstPercentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "GST % (e.g., 28)"))),
                  const SizedBox(width: 12),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text("Subtotal: ₹${subTotal.toStringAsFixed(2)}"),
                  )),
                ],
              ),
              const SizedBox(height: 8),
              Text("CGST: ₹${cgst.toStringAsFixed(2)}   SGST: ₹${sgst.toStringAsFixed(2)}"),
              Text("Round Off: ₹${roundOff.toStringAsFixed(2)}   Grand Total: ₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),

              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 8, children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text("Preview / Print PDF"),
                  onPressed: () async {
                    final pdfBytes = await _buildPdf();
                    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text("Save to Downloads"),
                  onPressed: () async {
                    final pdfBytes = await _buildPdf();
                    final file = await _savePdfToDownloads(pdfBytes, "Invoice_${_invoiceNo.text.replaceAll('/', '_')}.pdf");
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved: ${file.path}")));
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text("Share PDF"),
                  onPressed: () async {
                    final pdfBytes = await _buildPdf();
                    final tempDir = await getTemporaryDirectory();
                    final tempFile = File("${tempDir.path}/invoice_share.pdf");
                    await tempFile.writeAsBytes(pdfBytes);
                    await Share.shareXFiles([XFile(tempFile.path)], text: "Invoice ${_invoiceNo.text}");
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.confirmation_number),
                  label: const Text("Next Invoice No"),
                  onPressed: _generateNextInvoiceNumber,
                ),
              ]),
              const SizedBox(height: 24),
              Text("Bank Details", style: Theme.of(context).textTheme.titleMedium),
              TextFormField(controller: _bankHolder, decoration: const InputDecoration(labelText: "Account Holder Name")),
              TextFormField(controller: _bankName, decoration: const InputDecoration(labelText: "Bank Name")),
              TextFormField(controller: _bankAcc, decoration: const InputDecoration(labelText: "Account Number")),
              TextFormField(controller: _bankIfsc, decoration: const InputDecoration(labelText: "IFSC Code")),
            ],
          ),
        ),
      ),
    );
  }
}