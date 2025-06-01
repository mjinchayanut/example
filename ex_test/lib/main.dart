import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'dart:html' as html;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ProductScannerPage(),
    );
  }
}

class Product {
  final String? id;
  final String barcode;
  final String serial;
  final String name;
  final String brand;
  final String category;
  final double price;
  final String description;
  final int stock;

  Product({
    this.id,
    required this.barcode,
    required this.serial,
    required this.name,
    required this.brand,
    required this.category,
    required this.price,
    required this.description,
    required this.stock,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    String? parseId(dynamic id) {
      if (id == null) return null;
      if (id is String) return id;
      if (id is Map<String, dynamic>) {
        if (id.containsKey('\$oid')) {
          return id['\$oid'].toString();
        }
        return id.toString();
      }
      return id.toString();
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    String parseString(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    return Product(
      id: parseId(json['_id']),
      barcode: parseString(json['barcode']),
      serial: parseString(json['serial']),
      name: parseString(json['name']),
      brand: parseString(json['brand']),
      category: parseString(json['category']),
      price: parseDouble(json['price']),
      description: parseString(json['description']),
      stock: parseInt(json['stock']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'serial': serial,
      'name': name,
      'brand': brand,
      'category': category,
      'price': price,
      'description': description,
      'stock': stock,
    };
  }
}

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';

  static Future<Product?> getProductByIdentifier(String identifier) async {
    try {
      log('Fetching product with identifier: $identifier');

      final response = await http.get(
        Uri.parse('$baseUrl/product/$identifier'),
        headers: {'Content-Type': 'application/json'},
      );

      log('Response status: ${response.statusCode}');
      log('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Product.fromJson(data['data']);
        }
      } else if (response.statusCode == 404) {
        log('Product not found');
        return null;
      }
      return null;
    } catch (e) {
      log('Error fetching product: $e');
      return null;
    }
  }

  static Future<bool> addProduct(Product product) async {
    try {
      log('Adding product: ${product.toJson()}');

      final response = await http.post(
        Uri.parse('$baseUrl/product'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(product.toJson()),
      );

      log('Add product response status: ${response.statusCode}');
      log('Add product response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      log('Error adding product: $e');
      return false;
    }
  }

  static Future<List<Product>> getAllProducts({
    int page = 1,
    int limit = 10,
    String search = '',
  }) async {
    try {
      log('Fetching all products...');

      final response = await http.get(
        Uri.parse('$baseUrl/products?page=$page&limit=$limit&search=$search'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          List<dynamic> productsJson = data['data'];
          List<Product> products = [];

          for (var productJson in productsJson) {
            try {
              products.add(Product.fromJson(productJson));
            } catch (e) {
              log('Error parsing product: $e');
            }
          }

          return products;
        }
      }
      return [];
    } catch (e) {
      log('Error fetching products: $e');
      return [];
    }
  }

  static Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      log('Health check error: $e');
      return false;
    }
  }
}

class ManualBarcodeDialog extends StatefulWidget {
  const ManualBarcodeDialog({super.key});

  @override
  _ManualBarcodeDialogState createState() => _ManualBarcodeDialogState();
}

class _ManualBarcodeDialogState extends State<ManualBarcodeDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.qr_code, color: Colors.blue),
          SizedBox(width: 8),
          Text('กรอกบาร์โค้ดด้วยตนเอง'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('กรุณากรอกบาร์โค้ดหรือสแกนด้วยเครื่องสแกนภายนอก'),
          SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'บาร์โค้ด',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code_scanner),
              hintText: 'เช่น 1234567890123',
            ),
            autofocus: true,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.of(context).pop(value.trim());
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: Text('ตกลง'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class CameraHelper {
  static Future<bool> checkCameraPermission() async {
    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': true,
      });

      if (stream != null) {
        stream.getTracks().forEach((track) => track.stop());
        return true;
      }
      return false;
    } catch (e) {
      log('Camera permission error: $e');
      return false;
    }
  }
}

class ProductScannerPage extends StatefulWidget {
  @override
  _ProductScannerPageState createState() => _ProductScannerPageState();
}

class _ProductScannerPageState extends State<ProductScannerPage> {
  final _identifierController = TextEditingController();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _serialController = TextEditingController();

  Product? _foundProduct;
  bool _isLoading = false;
  bool _isAddMode = false;
  List<Product> _allProducts = [];
  bool _serverConnected = false;
  String _lastScannedBarcode = '';
  bool _cameraPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkServerConnection();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final hasPermission = await CameraHelper.checkCameraPermission();
    setState(() {
      _cameraPermissionGranted = hasPermission;
    });

    if (!hasPermission) {
      log('Camera permission not granted');
    }
  }

  Future<void> _checkServerConnection() async {
    final isConnected = await ApiService.checkServerHealth();
    setState(() {
      _serverConnected = isConnected;
    });

    if (isConnected) {
      _loadAllProducts();
    } else {
      _showMessage(
        'ไม่สามารถเชื่อมต่อ Server ได้ กรุณาตรวจสอบ Backend',
        isError: true,
      );
    }
  }

  Future<void> _loadAllProducts() async {
    setState(() {
      _isLoading = true;
    });

    final products = await ApiService.getAllProducts(limit: 50);

    setState(() {
      _allProducts = products;
      _isLoading = false;
    });
  }

  Future<void> _searchProduct() async {
    if (_identifierController.text.trim().isEmpty) {
      _showMessage('กรุณากรอก Barcode หรือ Serial Number', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _foundProduct = null;
      _isAddMode = false;
    });

    final product = await ApiService.getProductByIdentifier(
      _identifierController.text.trim(),
    );

    setState(() {
      _isLoading = false;
      _foundProduct = product;
      if (product != null) {
        _populateForm(product);
        _isAddMode = false;
      } else {
        _isAddMode = true;
        _barcodeController.text = _identifierController.text.trim();
        _serialController.text = _identifierController.text.trim();
      }
    });

    if (product == null) {
      _showMessage('ไม่พบสินค้า กรุณาเพิ่มสินค้าใหม่', isError: true);
    } else {
      _showMessage('พบสินค้า: ${product.name}');
    }
  }

  void _populateForm(Product product) {
    _nameController.text = product.name;
    _brandController.text = product.brand;
    _categoryController.text = product.category;
    _priceController.text = product.price.toString();
    _descriptionController.text = product.description;
    _stockController.text = product.stock.toString();
    _barcodeController.text = product.barcode;
    _serialController.text = product.serial;
  }

  void _clearForm() {
    _identifierController.clear();
    _nameController.clear();
    _brandController.clear();
    _categoryController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _stockController.clear();
    _barcodeController.clear();
    _serialController.clear();
    setState(() {
      _foundProduct = null;
      _isAddMode = false;
    });
  }

  Future<void> _addProduct() async {
    if (_nameController.text.trim().isEmpty) {
      _showMessage('กรุณากรอกชื่อสินค้า', isError: true);
      return;
    }

    if (_priceController.text.trim().isEmpty) {
      _showMessage('กรุณากรอกราคา', isError: true);
      return;
    }

    if (_barcodeController.text.trim().isEmpty) {
      _showMessage('กรุณากรอก Barcode', isError: true);
      return;
    }

    if (_serialController.text.trim().isEmpty) {
      _showMessage('กรุณากรอก Serial Number', isError: true);
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      _showMessage('กรุณากรอกราคาที่ถูกต้อง', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final product = Product(
      barcode: _barcodeController.text.trim(),
      serial: _serialController.text.trim(),
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      category: _categoryController.text.trim(),
      price: price,
      description: _descriptionController.text.trim(),
      stock: int.tryParse(_stockController.text.trim()) ?? 0,
    );

    final success = await ApiService.addProduct(product);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _showMessage('เพิ่มสินค้าสำเร็จ');
      _clearForm();
      _loadAllProducts();
    } else {
      _showMessage(
        'เกิดข้อผิดพลาดในการเพิ่มสินค้า (อาจมี Barcode/Serial ซ้ำ)',
        isError: true,
      );
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    try {
      log('Starting barcode scan...');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('กำลังเปิดกล้อง...'),
                ],
              ),
            ),
      );

      String? result = await SimpleBarcodeScanner.scanBarcode(
        context,
        barcodeAppBar: const BarcodeAppBar(
          appBarTitle: 'สแกนบาร์โค้ดสินค้า',
          centerTitle: true,
          enableBackButton: true,
          backButtonIcon: Icon(Icons.arrow_back_ios),
        ),
        isShowFlashIcon: true,
        delayMillis: 500,
        cameraFace: CameraFace.back,
        scanFormat: ScanFormat.ONLY_BARCODE,
      );

      Navigator.of(context).pop();

      log('Scan result: $result');

      if (result != null && result != '-1' && result.isNotEmpty) {
        setState(() {
          _lastScannedBarcode = result;
          _identifierController.text = result;
        });

        _showMessage('สแกนบาร์โค้ดสำเร็จ: $result');

        await _searchProduct();
      } else {
        _showMessage('ยกเลิกการสแกนหรือไม่พบบาร์โค้ด', isError: true);

        _showManualBarcodeDialog();
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      log('Error scanning barcode: $e');
      _showMessage('เกิดข้อผิดพลาดในการสแกน: $e', isError: true);
      _showManualBarcodeDialog();
    }
  }

  Future<void> _showManualBarcodeDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => ManualBarcodeDialog(),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _lastScannedBarcode = result;
        _identifierController.text = result;
      });

      _showMessage('กรอกบาร์โค้ดสำเร็จ: $result');
      await _searchProduct();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Product Scanner & Manager'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_serverConnected ? Icons.cloud_done : Icons.cloud_off),
            onPressed: _checkServerConnection,
            tooltip:
                _serverConnected
                    ? 'เชื่อมต่อ Server แล้ว'
                    : 'ไม่ได้เชื่อมต่อ Server',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_serverConnected)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ไม่สามารถเชื่อมต่อ Backend Server ได้ กรุณาตรวจสอบว่า Server ทำงานอยู่ที่ localhost:3000',
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _checkServerConnection,
                        child: Text('ลองใหม่'),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 16),

            if (!_cameraPermissionGranted)
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.camera_alt_outlined, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ไม่สามารถเข้าถึงกล้องได้',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                            ),
                            Text(
                              'กรุณาอนุญาตให้เข้าถึงกล้องในเบราว์เซอร์ หรือใช้ฟีเจอร์กรอกด้วยตนเอง',
                              style: TextStyle(color: Colors.orange[700]),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _checkCameraPermission,
                        child: Text('ตรวจสอบอีกครั้ง'),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 16),

            if (_lastScannedBarcode.isNotEmpty)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'บาร์โค้ดล่าสุดที่สแกน:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                              ),
                            ),
                            Text(
                              _lastScannedBarcode,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.green),
                        onPressed: () {
                          setState(() {
                            _lastScannedBarcode = '';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 16),

            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ค้นหาสินค้า',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),

                    TextField(
                      controller: _identifierController,
                      decoration: InputDecoration(
                        labelText: 'Barcode หรือ Serial Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        hintText: 'ลองใช้: 1234567890123',
                        suffixIcon:
                            _identifierController.text.isNotEmpty
                                ? IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    _identifierController.clear();
                                    setState(() {});
                                  },
                                )
                                : null,
                      ),
                      onSubmitted: (_) => _searchProduct(),
                      onChanged: (value) => setState(() {}),
                    ),

                    SizedBox(height: 16),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _scanBarcode,
                          icon: Icon(Icons.qr_code_scanner),
                          label: Text('สแกนบาร์โค้ด'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed:
                              (_isLoading || !_serverConnected)
                                  ? null
                                  : _searchProduct,
                          icon:
                              _isLoading
                                  ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Icon(Icons.search),
                          label: Text('ค้นหา'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            if (_foundProduct != null || _isAddMode) ...[
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _foundProduct != null
                                ? 'ข้อมูลสินค้า'
                                : 'เพิ่มสินค้าใหม่',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(),
                          if (_foundProduct != null)
                            Chip(
                              label: Text('พบสินค้า'),
                              backgroundColor: Colors.green[100],
                              avatar: Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 18,
                              ),
                            ),
                          if (_isAddMode && _foundProduct == null)
                            Chip(
                              label: Text('สินค้าใหม่'),
                              backgroundColor: Colors.orange[100],
                              avatar: Icon(
                                Icons.add_circle,
                                color: Colors.orange,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _barcodeController,
                              decoration: InputDecoration(
                                labelText: 'Barcode *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.qr_code),
                              ),
                              enabled: _foundProduct == null,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _serialController,
                              decoration: InputDecoration(
                                labelText: 'Serial Number *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.confirmation_number),
                              ),
                              enabled: _foundProduct == null,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'ชื่อสินค้า *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory),
                        ),
                        enabled: _foundProduct == null,
                      ),

                      SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _brandController,
                              decoration: InputDecoration(
                                labelText: 'แบรนด์',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.business),
                              ),
                              enabled: _foundProduct == null,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _categoryController,
                              decoration: InputDecoration(
                                labelText: 'หมวดหมู่',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              enabled: _foundProduct == null,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _priceController,
                              decoration: InputDecoration(
                                labelText: 'ราคา *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money),
                                suffixText: '฿',
                              ),
                              keyboardType: TextInputType.number,
                              enabled: _foundProduct == null,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _stockController,
                              decoration: InputDecoration(
                                labelText: 'จำนวนสต็อก',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.storage),
                              ),
                              keyboardType: TextInputType.number,
                              enabled: _foundProduct == null,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'รายละเอียด',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                        enabled: _foundProduct == null,
                      ),

                      SizedBox(height: 16),

                      Row(
                        children: [
                          if (_foundProduct == null) ...[
                            ElevatedButton.icon(
                              onPressed:
                                  (_isLoading || !_serverConnected)
                                      ? null
                                      : _addProduct,
                              icon:
                                  _isLoading
                                      ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Icon(Icons.add),
                              label: Text('เพิ่มสินค้า'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                          ],
                          ElevatedButton.icon(
                            onPressed: _clearForm,
                            icon: Icon(Icons.clear),
                            label: Text('ล้างข้อมูล'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            SizedBox(height: 16),

            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list_alt, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'รายการสินค้าทั้งหมด (${_allProducts.length} รายการ)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        ElevatedButton.icon(
                          onPressed:
                              (_isLoading || !_serverConnected)
                                  ? null
                                  : _loadAllProducts,
                          icon:
                              _isLoading
                                  ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Icon(Icons.refresh),
                          label: Text('รีเฟรช'),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    if (_isLoading)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('กำลังโหลดข้อมูล...'),
                            ],
                          ),
                        ),
                      )
                    else if (_allProducts.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'ไม่มีสินค้าในระบบ',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'เริ่มต้นด้วยการสแกนบาร์โค้ดเพื่อเพิ่มสินค้าใหม่',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        child: Column(
                          children:
                              _allProducts.map((product) {
                                return Card(
                                  margin: EdgeInsets.only(bottom: 8),
                                  elevation: 2,
                                  child: InkWell(
                                    onTap: () {
                                      _identifierController.text =
                                          product.barcode;
                                      _searchProduct();
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  product.name,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 4,
                                                  horizontal: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      product.stock > 0
                                                          ? Colors.green[100]
                                                          : Colors.red[100],
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'สต็อก: ${product.stock}',
                                                  style: TextStyle(
                                                    color:
                                                        product.stock > 0
                                                            ? Colors.green[800]
                                                            : Colors.red[800],
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          SizedBox(height: 8),

                                          Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 6,
                                                    horizontal: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.blue[200]!,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Barcode',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color:
                                                              Colors.blue[600],
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      Text(
                                                        product.barcode,
                                                        style: TextStyle(
                                                          fontFamily:
                                                              'monospace',
                                                          color:
                                                              Colors.blue[800],
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 6,
                                                    horizontal: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.green[200]!,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Serial',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color:
                                                              Colors.green[600],
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      Text(
                                                        product.serial,
                                                        style: TextStyle(
                                                          fontFamily:
                                                              'monospace',
                                                          color:
                                                              Colors.green[800],
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          SizedBox(height: 8),

                                          Row(
                                            children: [
                                              if (product.brand.isNotEmpty) ...[
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 2,
                                                    horizontal: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.purple[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    product.brand,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.purple[700],
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 6),
                                              ],
                                              if (product
                                                  .category
                                                  .isNotEmpty) ...[
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 2,
                                                    horizontal: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    product.category,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.orange[700],
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 6),
                                              ],
                                              Spacer(),
                                              Text(
                                                '฿${product.price.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green[700],
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),

                                          if (product
                                              .description
                                              .isNotEmpty) ...[
                                            SizedBox(height: 6),
                                            Text(
                                              product.description,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    _serialController.dispose();
    super.dispose();
  }
}
