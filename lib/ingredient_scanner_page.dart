import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'utils/error_handler.dart';


class IngredientScannerPage extends StatefulWidget {
  const IngredientScannerPage({super.key});

  @override
  State<IngredientScannerPage> createState() => _IngredientScannerPageState();
}

class _IngredientScannerPageState extends State<IngredientScannerPage> {
  Map<String, dynamic>? _scannedProduct;
  List<String> _detectedAllergens = [];
  String? _errorMessage;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Barcode scanning variables
  bool _isScanningBarcode = false;
  MobileScannerController? _scannerController;
  String? _scannedBarcode;
  Map<String, dynamic>? _barcodeProductData;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  // API Methods for Food Data
  Future<Map<String, dynamic>?> _fetchProductFromOpenFoodFacts(String barcode) async {
    // Check internet connectivity first
    final hasInternet = await ErrorHandler.hasInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        ErrorHandler.showOfflineSnackbar(context);
      }
      return null;
    }

    try {
      print('DEBUG: Fetching product from OpenFoodFacts for barcode: $barcode');
      final response = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json'),
        headers: {'User-Agent': 'SmartDiet/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          print('DEBUG: Found product in OpenFoodFacts: ${data['product']['product_name']}');
          return data['product'];
        }
      }
      print('DEBUG: Product not found in OpenFoodFacts');
      return null;
    } on SocketException catch (_) {
      print('DEBUG: Network error fetching OpenFoodFacts data');
      if (mounted) {
        ErrorHandler.showOfflineSnackbar(context);
      }
      return null;
    } on TimeoutException catch (_) {
      print('DEBUG: Timeout fetching OpenFoodFacts data');
      if (mounted) {
        ErrorHandler.showErrorSnackbar(context, 'Request timeout. Please try again.');
      }
      return null;
    } on http.ClientException catch (e) {
      print('DEBUG: HTTP client error: $e');
      if (mounted) {
        ErrorHandler.showErrorSnackbar(context, 'Failed to connect to server.');
      }
      return null;
    } catch (e) {
      print('DEBUG: Error fetching product from OpenFoodFacts: $e');
      if (mounted) {
        ErrorHandler.showErrorSnackbar(context, 'Error fetching product data.');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchProductFromUSDA(String searchTerm) async {
    // Check internet connectivity first
    final hasInternet = await ErrorHandler.hasInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        ErrorHandler.showOfflineSnackbar(context);
      }
      return null;
    }

    try {
      print('DEBUG: Searching USDA database for: $searchTerm');
      
      // Get API key from environment variables
      final apiKey = dotenv.env['USDA_API_KEY'] ?? 'DEMO_KEY';
      print('DEBUG: Using USDA API key: ${apiKey.substring(0, 8)}...');
      
      final response = await http.get(
        Uri.parse('https://api.nal.usda.gov/fdc/v1/foods/search?query=${Uri.encodeComponent(searchTerm)}&api_key=$apiKey&pageSize=1'),
        headers: {'User-Agent': 'SmartDiet/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['foods'] != null && data['foods'].isNotEmpty) {
          print('DEBUG: Found product in USDA: ${data['foods'][0]['description']}');
          return data['foods'][0];
        }
      } else {
        print('DEBUG: USDA API error: ${response.statusCode} - ${response.body}');
      }
      print('DEBUG: Product not found in USDA');
      return null;
    } catch (e) {
      print('DEBUG: Error fetching from USDA: $e');
      return null;
    }
  }

  // Barcode scanning methods
  void _startBarcodeScanning() {
    setState(() {
      _isScanningBarcode = true;
      _scannerController = MobileScannerController();
    });
  }

  void _stopBarcodeScanning() {
    setState(() {
      _isScanningBarcode = false;
      _scannerController?.dispose();
      _scannerController = null;
    });
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null) {
        setState(() {
          _scannedBarcode = barcode.rawValue!;
        });
        
        await _processScannedBarcode(barcode.rawValue!);
        _stopBarcodeScanning();
      }
    }
  }

  Future<void> _processScannedBarcode(String barcode) async {
    setState(() {
      _errorMessage = null;
    });

    try {
      // Try OpenFoodFacts first
      Map<String, dynamic>? productData = await _fetchProductFromOpenFoodFacts(barcode);
      
      if (productData != null) {
        await _analyzeBarcodeProduct(productData);
      } else {
        // If not found in OpenFoodFacts, try USDA with generic search
        productData = await _fetchProductFromUSDA('barcode $barcode');
        if (productData != null) {
          await _analyzeUSDAData(productData);
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = 'Product not found in food databases. Please try manual entry.';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error processing barcode: $e';
        });
      }
    }
  }

  Future<void> _analyzeBarcodeProduct(Map<String, dynamic> product) async {
    final ingredientsText = product['ingredients_text'] ?? '';
    final ingredients = _parseIngredients(ingredientsText);
    
    // Check for allergens
    final detectedAllergens = _checkForAllergens(ingredients);
    final allergenDetails = _checkForAllergensWithDetails(ingredients);
    final ingredientAllergenMap = allergenDetails['ingredientMap'] as Map<String, List<String>>;
    
    if (mounted) {
      setState(() {
        _barcodeProductData = {
          'name': product['product_name'] ?? 'Unknown Product',
          'brand': product['brands'] ?? '',
          'barcode': _scannedBarcode,
          'ingredients': ingredients,
          'ingredients_text': ingredientsText,
          'nutrition': _extractNutritionFromOpenFoodFacts(product),
          'image': product['image_url'] ?? product['image_front_url'],
          'ingredientAllergenMap': ingredientAllergenMap,
          'source': 'OpenFoodFacts',
        };
        _detectedAllergens = detectedAllergens;
      });
    }
  }

  Future<void> _analyzeUSDAData(Map<String, dynamic> usdaData) async {
    if (mounted) {
      setState(() {
        _barcodeProductData = {
          'name': usdaData['description'] ?? 'Unknown Product',
          'brand': '',
          'barcode': _scannedBarcode,
          'ingredients': [],
          'ingredients_text': '',
          'nutrition': _extractNutritionFromUSDA(usdaData),
          'image': null,
          'ingredientAllergenMap': <String, List<String>>{},
          'source': 'USDA',
        };
        _detectedAllergens = [];
      });
    }
  }

  Map<String, dynamic> _extractNutritionFromOpenFoodFacts(Map<String, dynamic> product) {
    final nutriments = product['nutriments'] ?? {};
    return {
      'calories': _parseDouble(nutriments['energy-kcal_100g']) ?? 0.0,
      'protein': _parseDouble(nutriments['proteins_100g']) ?? 0.0,
      'carbs': _parseDouble(nutriments['carbohydrates_100g']) ?? 0.0,
      'fat': _parseDouble(nutriments['fat_100g']) ?? 0.0,
      'fiber': _parseDouble(nutriments['fiber_100g']) ?? 0.0,
      'sugar': _parseDouble(nutriments['sugars_100g']) ?? 0.0,
      'sodium': _parseDouble(nutriments['sodium_100g']) ?? 0.0,
    };
  }

  Map<String, dynamic> _extractNutritionFromUSDA(Map<String, dynamic> usdaData) {
    final nutrients = usdaData['foodNutrients'] ?? [];
    Map<String, double> nutrition = {};
    
    for (var nutrient in nutrients) {
      final nutrientId = nutrient['nutrient']?['id'];
      final amount = _parseDouble(nutrient['amount']) ?? 0.0;
      
      switch (nutrientId) {
        case 1008: // Energy (kcal)
          nutrition['calories'] = amount;
          break;
        case 1003: // Protein
          nutrition['protein'] = amount;
          break;
        case 1005: // Carbohydrates
          nutrition['carbs'] = amount;
          break;
        case 1004: // Fat
          nutrition['fat'] = amount;
          break;
        case 1079: // Fiber
          nutrition['fiber'] = amount;
          break;
        case 2000: // Sugar
          nutrition['sugar'] = amount;
          break;
        case 1093: // Sodium
          nutrition['sodium'] = amount;
          break;
      }
    }
    
    return {
      'calories': nutrition['calories'] ?? 0.0,
      'protein': nutrition['protein'] ?? 0.0,
      'carbs': nutrition['carbs'] ?? 0.0,
      'fat': nutrition['fat'] ?? 0.0,
      'fiber': nutrition['fiber'] ?? 0.0,
      'sugar': nutrition['sugar'] ?? 0.0,
      'sodium': nutrition['sodium'] ?? 0.0,
    };
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }









  Future<void> _analyzeIngredients(Map<String, dynamic> product) async {
    final ingredientsText = product['ingredients_text'] ?? '';
    final ingredients = _parseIngredients(ingredientsText);
    
    // Check for allergens
    
    final detectedAllergens = _checkForAllergens(ingredients);
    final allergenDetails = _checkForAllergensWithDetails(ingredients);
    final ingredientAllergenMap = allergenDetails['ingredientMap'] as Map<String, List<String>>;
    
    setState(() {
      _scannedProduct = {
        ...product,
        'ingredients': ingredients,
        'barcode': product['code'] ?? 'Unknown',
        'ingredientAllergenMap': ingredientAllergenMap,
      };
      _detectedAllergens = detectedAllergens;
    });
  }

  List<String> _parseIngredients(String ingredientsText) {
    if (ingredientsText.isEmpty) return [];
    
    // Split by common separators and clean up
    final ingredients = ingredientsText
        .split(RegExp(r'[,;]'))
        .map((ingredient) => ingredient.trim())
        .where((ingredient) => ingredient.isNotEmpty)
        .toList();
    
    print('Raw ingredients: $ingredients');
    return ingredients;
  }

  Map<String, dynamic> _checkForAllergensWithDetails(List<String> ingredients) {
    final detectedAllergens = <String>[];
    final ingredientAllergenMap = <String, List<String>>{};
    
    for (final ingredient in ingredients) {
      final lowerIngredient = ingredient.toLowerCase().trim();
      final ingredientAllergens = <String>[];
      
      // Check for common allergens
      final commonAllergens = _detectCommonAllergens(lowerIngredient);
      for (final allergen in commonAllergens) {
        ingredientAllergens.add(allergen);
        if (!detectedAllergens.contains(allergen)) {
          detectedAllergens.add(allergen);
        }
      }
      
      // Store which allergens were found in this specific ingredient
      if (ingredientAllergens.isNotEmpty) {
        ingredientAllergenMap[ingredient] = ingredientAllergens;
      }
    }
    
    return {
      'allergens': detectedAllergens,
      'ingredientMap': ingredientAllergenMap,
    };
  }

  List<String> _checkForAllergens(List<String> ingredients) {
    return _checkForAllergensWithDetails(ingredients)['allergens'] as List<String>;
  }


  List<String> _detectCommonAllergens(String ingredient) {
    final detectedAllergens = <String>[];
    
    // Common allergen patterns
    final allergenPatterns = {
      'milk': ['milk', 'dairy', 'lactose', 'casein', 'whey', 'cream', 'butter', 'cheese', 'yogurt'],
      'eggs': ['egg', 'albumin', 'lecithin', 'mayonnaise', 'custard'],
      'nuts': ['almond', 'walnut', 'pecan', 'cashew', 'pistachio', 'hazelnut', 'macadamia', 'pine nut'],
      'peanuts': ['peanut', 'groundnut', 'arachis'],
      'soy': ['soy', 'soybean', 'soya', 'tofu', 'tempeh', 'miso', 'edamame'],
      'wheat': ['wheat', 'gluten', 'flour', 'bread', 'pasta', 'semolina', 'bulgur'],
      'fish': ['fish', 'salmon', 'tuna', 'cod', 'anchovy', 'sardine', 'mackerel'],
      'shellfish': ['shrimp', 'crab', 'lobster', 'scallop', 'mussel', 'clam', 'oyster'],
      'sesame': ['sesame', 'tahini', 'halva'],
    };
    
    for (final allergen in allergenPatterns.keys) {
      for (final pattern in allergenPatterns[allergen]!) {
        if (ingredient.contains(pattern)) {
          detectedAllergens.add(allergen);
          break; // Only add each allergen once per ingredient
        }
      }
    }
    
    return detectedAllergens;
  }



  void _resetScan() {
    setState(() {
      _scannedProduct = null;
      _detectedAllergens = [];
      _errorMessage = null;
    });
  }


  Future<void> _captureIngredientPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        await _processIngredientPhoto(image.path);
      } else {
        setState(() {
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Camera not available. Please try again or use gallery instead.';
      });
    }
  }

  Future<void> _pickIngredientPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        await _processIngredientPhoto(image.path);
      } else {
        setState(() {
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gallery not available. Please try again or use camera instead.';
      });
    }
  }

  Future<void> _processIngredientPhoto(String imagePath) async {
    setState(() {
      _errorMessage = null;
    });

    try {
      // Try cropping first, but fallback to direct processing if cropping fails
      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: imagePath,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1.5),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Ingredient Section',
              toolbarColor: Colors.green,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Crop Ingredient Section',
            ),
          ],
        );

        if (croppedFile != null) {
          await _extractTextFromImage(croppedFile.path);
        } else {
          // User cancelled cropping, process original image
          await _extractTextFromImage(imagePath);
        }
      } catch (cropError) {
        // If cropping fails, process the original image
        print('Cropping failed, processing original image: $cropError');
        await _extractTextFromImage(imagePath);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing photo: ${e.toString()}';
      });
    }
  }

  Future<void> _extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();

      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      String extractedText = recognizedText.text;
      
      // Clean up the text
      extractedText = _cleanExtractedText(extractedText);
      
      if (extractedText.isNotEmpty) {
        // Process the extracted text as ingredients
        final product = {
          'product_name': 'Photo Scanned Product',
          'ingredients_text': extractedText,
          'brands': 'Unknown Brand',
          'categories': 'Unknown Category',
          'code': 'photo_scan',
          'is_photo_scan': true,
        };

        await _analyzeIngredients(product);
        setState(() {
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'No text found in the image. Please try again with a clearer photo of the ingredient section.';
        });
      }

      textRecognizer.close();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error extracting text: $e';
      });
    }
  }

  String _cleanExtractedText(String text) {
    // Clean up OCR text to extract ingredients
    List<String> lines = text.split('\n');
    List<String> cleanedLines = [];

    for (String line in lines) {
      line = line.trim();
      if (line.isNotEmpty) {
        // Skip common non-ingredient words
        if (!_isNonIngredientWord(line.toLowerCase())) {
          cleanedLines.add(line);
        }
      }
    }

    // Join lines and clean up
    String cleanedText = cleanedLines.join(', ');
    
    // Remove common OCR artifacts
    cleanedText = cleanedText
        .replaceAll(RegExp(r'[^\w\s,.-]'), '') // Remove special chars except basic punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .replaceAll(RegExp(r',\s*,+'), ',') // Remove multiple commas
        .trim();

    return cleanedText;
  }

  bool _isNonIngredientWord(String word) {
    final nonIngredientWords = [
      'ingredients',
      'ingredient',
      'contains',
      'may contain',
      'allergens',
      'allergen',
      'nutrition',
      'nutritional',
      'information',
      'serving',
      'size',
      'calories',
      'protein',
      'fat',
      'carbohydrate',
      'sodium',
      'sugar',
      'fiber',
      'vitamin',
      'mineral',
      'net weight',
      'weight',
      'volume',
      'manufactured',
      'distributed',
      'by',
      'company',
      'inc',
      'ltd',
      'corp',
      'llc',
    ];

    return nonIngredientWords.contains(word.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Ingredient Scanner',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: _isScanningBarcode 
          ? IconButton(
              icon: const Icon(Icons.close, size: 28),
              onPressed: _stopBarcodeScanning,
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FFF4), Color(0xFFE8F5E9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isScanningBarcode ? _buildBarcodeScanner() : _buildResultsSection(),
      ),
    );
  }

  Widget _buildBarcodeScanner() {
    if (_scannerController == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController!,
          onDetect: _onBarcodeDetected,
        ),
        // Overlay with scanning instructions
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Point your camera at the barcode on the product packaging',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Scanning frame overlay
        Positioned(
          top: 100,
          left: 50,
          right: 50,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                Icons.qr_code_scanner,
                color: Colors.green,
                size: 50,
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildResultsSection() {
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    
    if (_scannedProduct == null && _barcodeProductData == null) {
      return _buildEmptyState();
    }
    
    return _buildProductResults();
  }

  Widget _buildEmptyState() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Hero Icon
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.green[100]!, Colors.green[50]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 80,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Smart Ingredient Scanner',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Instantly detect allergens and analyze nutritional content',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Barcode Scanner Option
            _buildScanOption(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan Barcode',
              subtitle: 'Quick product lookup',
              gradient: LinearGradient(
                colors: [Colors.orange[700]!, Colors.orange[400]!],
              ),
              onTap: _isScanningBarcode ? null : _startBarcodeScanning,
            ),
            const SizedBox(height: 16),
            _buildScanOption(
              icon: Icons.camera_alt_rounded,
              title: 'Scan with Camera',
              subtitle: 'Take a photo of ingredient labels',
              gradient: const LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
              ),
              onTap: _captureIngredientPhoto,
            ),
            const SizedBox(height: 16),
            _buildScanOption(
              icon: Icons.photo_library_rounded,
              title: 'Choose from Gallery',
              subtitle: 'Select an existing photo',
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[400]!],
              ),
              onTap: _pickIngredientPhoto,
            ),

            const SizedBox(height: 40),
            // Info Cards
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.check_circle_outline,
                    text: 'Accurate\nDetection',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.flash_on,
                    text: 'Instant\nResults',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.security,
                    text: 'Safe &\nSecure',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 16,
              color: Colors.red[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _resetScan,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _captureIngredientPhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetailedAllergenWarnings(Map<String, dynamic> product) {
    final ingredientAllergenMap = product['ingredientAllergenMap'] as Map<String, List<String>>? ?? {};
    final widgets = <Widget>[];
    
    // Group allergens by type and show which ingredients contain them
    final allergenToIngredients = <String, List<String>>{};
    
    for (final entry in ingredientAllergenMap.entries) {
      final ingredient = entry.key;
      final allergens = entry.value;
      
      for (final allergen in allergens) {
        if (!allergenToIngredients.containsKey(allergen)) {
          allergenToIngredients[allergen] = [];
        }
        allergenToIngredients[allergen]!.add(ingredient);
      }
    }
    
    // Create warning widgets for each allergen
    for (final entry in allergenToIngredients.entries) {
      final allergen = entry.key;
      final ingredients = entry.value;
      
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red[100],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.red[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red[700],
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Allergen: $allergen',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Found in: ${ingredients.join(', ')}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[600],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return widgets;
  }

  Widget _buildProductResults() {
    final product = _scannedProduct ?? _barcodeProductData!;
    final hasAllergens = _detectedAllergens.isNotEmpty;
    
    print('DEBUG: Building product results for: ${product['name']}');
    print('DEBUG: Product ingredients type: ${product['ingredients'].runtimeType}');
    print('DEBUG: Product ingredients value: ${product['ingredients']}');
    
    // Safely cast ingredients to List<String>
    List<String> ingredients = [];
    if (product['ingredients'] != null) {
      if (product['ingredients'] is List<String>) {
        ingredients = product['ingredients'] as List<String>;
        print('DEBUG: Ingredients cast as List<String>');
      } else if (product['ingredients'] is List<dynamic>) {
        ingredients = (product['ingredients'] as List<dynamic>)
            .map((e) => e.toString())
            .toList();
        print('DEBUG: Ingredients cast from List<dynamic> to List<String>');
      }
    }
    
    // Safely cast ingredientAllergenMap
    Map<String, List<String>> ingredientAllergenMap = {};
    if (product['ingredientAllergenMap'] != null) {
      try {
        final rawMap = product['ingredientAllergenMap'] as Map<String, dynamic>;
        for (final entry in rawMap.entries) {
          if (entry.value is List<String>) {
            ingredientAllergenMap[entry.key] = entry.value as List<String>;
          } else if (entry.value is List<dynamic>) {
            ingredientAllergenMap[entry.key] = (entry.value as List<dynamic>)
                .map((e) => e.toString())
                .toList();
          }
        }
        print('DEBUG: Successfully parsed ingredientAllergenMap');
      } catch (e) {
        print('DEBUG: Error parsing ingredientAllergenMap: $e');
      }
    }
    
    print('DEBUG: Final ingredients count: ${ingredients.length}');
    print('DEBUG: Final allergen map keys: ${ingredientAllergenMap.keys.toList()}');
    
    // Calculate safety score
    final totalIngredients = ingredients.length;
    final allergenIngredients = ingredientAllergenMap.keys.length;
    final safetyScore = totalIngredients > 0 ? ((totalIngredients - allergenIngredients) / totalIngredients * 100).round() : 100;
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Modern Product Header with Safety Score
            _buildModernProductHeader(product, hasAllergens, safetyScore),
            
            const SizedBox(height: 16),
            
            // Safety Score Card
            _buildSafetyScoreCard(safetyScore, hasAllergens),
            
            const SizedBox(height: 16),
            
            // Allergen Alerts (if any)
            if (hasAllergens) ...[
              _buildAllergenAlertsCard(product),
              const SizedBox(height: 16),
            ],
            
            // Ingredients Analysis - Fixed height instead of Expanded
            SizedBox(
              height: 400, // Fixed height for ingredients section
              child: _buildIngredientsAnalysisCard(ingredients, ingredientAllergenMap, product),
            ),
            
            const SizedBox(height: 20),
            
            // Add to Meal Plan Button
            _buildAddToMealPlanButton(),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            _buildActionButtons(),
            
            const SizedBox(height: 20), // Extra space at bottom
          ],
        ),
      ),
    );
  }

  Widget _buildModernProductHeader(Map<String, dynamic> product, bool hasAllergens, int safetyScore) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasAllergens 
            ? [Colors.red[400]!, Colors.red[600]!, Colors.red[800]!]
            : [Colors.green[400]!, Colors.green[600]!, Colors.green[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (hasAllergens ? Colors.red : Colors.green).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  hasAllergens ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAllergens ? '⚠️ Allergen Detected!' : '✅ Safe to Consume',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product['name'] ?? product['product_name'] ?? 'Unknown Product',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              // Safety Score Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$safetyScore% Safe',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyScoreCard(int safetyScore, bool hasAllergens) {
    Color scoreColor;
    String scoreText;
    IconData scoreIcon;
    
    if (safetyScore >= 90) {
      scoreColor = Colors.green;
      scoreText = 'Excellent';
      scoreIcon = Icons.thumb_up_rounded;
    } else if (safetyScore >= 70) {
      scoreColor = Colors.orange;
      scoreText = 'Good';
      scoreIcon = Icons.check_circle_rounded;
    } else {
      scoreColor = Colors.red;
      scoreText = 'Caution';
      scoreIcon = Icons.warning_rounded;
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              scoreIcon,
              color: scoreColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety Score',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$safetyScore% - $scoreText',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasAllergens 
                    ? 'Contains allergens that may affect you'
                    : 'No allergens detected in your profile',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergenAlertsCard(Map<String, dynamic> product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[50]!, Colors.red[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red[700],
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Allergen Alert',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._buildDetailedAllergenWarnings(product),
        ],
      ),
    );
  }

  Widget _buildIngredientsAnalysisCard(List<String> ingredients, Map<String, List<String>> ingredientAllergenMap, Map<String, dynamic> product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: Colors.blue[600],
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Ingredient Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[600],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${ingredients.length} ingredients',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
          if (product['is_mock_ingredients'] == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sample data - actual ingredients not available',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ingredients.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No ingredients found',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Scroll indicator
                    if (ingredients.length > 5)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swipe_up_rounded,
                              color: Colors.blue[600],
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Scroll to see all ${ingredients.length} ingredients',
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Ingredients list
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: ingredients.length,
                        itemBuilder: (context, index) {
                          final ingredient = ingredients[index];
                          final ingredientAllergens = ingredientAllergenMap[ingredient] ?? [];
                          final isAllergen = ingredientAllergens.isNotEmpty;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isAllergen ? Colors.red[50] : Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAllergen ? Colors.red[200]! : Colors.green[200]!,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isAllergen ? Colors.red : Colors.green).withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isAllergen ? Colors.red[100] : Colors.green[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isAllergen ? Icons.warning_rounded : Icons.check_circle_rounded,
                                    color: isAllergen ? Colors.red[600] : Colors.green[600],
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ingredient,
                                        style: TextStyle(
                                          color: isAllergen ? Colors.red[700] : Colors.green[700],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (isAllergen) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: ingredientAllergens.map((allergen) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.red[200],
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '⚠️ $allergen',
                                                style: TextStyle(
                                                  color: Colors.red[700],
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.blue[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _pickIngredientPhoto,
              icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
              label: const Text(
                'Choose Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _captureIngredientPhoto,
              icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              label: const Text(
                'Take Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Meal Plan Integration
  Future<void> _addToMealPlan() async {
    final product = _scannedProduct ?? _barcodeProductData!;
    final user = FirebaseAuth.instance.currentUser;
    
    print('DEBUG: Adding to meal plan - Product: ${product['name']}');
    
    if (user == null) {
      ErrorHandler.showErrorSnackbar(
        context,
        'Please log in to add items to meal plan',
      );
      return;
    }

    // Check internet connectivity first
    final hasInternet = await ErrorHandler.hasInternetConnection();
    if (!hasInternet && mounted) {
      ErrorHandler.showOfflineSnackbar(context);
      return;
    }

    try {
      // Create a meal entry from the scanned product
      final mealData = {
        'title': product['name'] ?? 'Scanned Product',
        'brand': product['brand'] ?? '',
        'barcode': product['barcode'] ?? '',
        'ingredients': product['ingredients'] ?? [],
        'ingredients_text': product['ingredients_text'] ?? '',
        'nutrition': product['nutrition'] ?? {},
        'image': product['image'],
        'source': product['source'] ?? 'scanner',
        'hasAllergens': _detectedAllergens.isNotEmpty,
        'detectedAllergens': _detectedAllergens,
        'ingredientAllergenMap': product['ingredientAllergenMap'] ?? {},
        'addedAt': DateTime.now().toIso8601String(),
        'scanned': true,
        'mealTime': 'snack', // Default meal time
        'mealType': 'snack', // Default meal type
        'date': DateTime.now().toIso8601String().split('T')[0], // Today's date
      };

      print('DEBUG: Meal data created: $mealData');

      // Save to Firestore in the main meal_plans collection
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .add(mealData);

      print('DEBUG: Meal saved with ID: ${docRef.id}');

      if (mounted) {
        ErrorHandler.showSuccessSnackbar(
          context,
          '${product['name']} added to meal plan!',
        );
      }

      // Navigate back to meal planner
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on FirebaseException catch (e) {
      print('DEBUG: Firebase error adding to meal plan: ${e.code} - ${e.message}');
      final errorMessage = ErrorHandler.getFirestoreErrorMessage(e);
      if (mounted) {
        ErrorHandler.showErrorSnackbar(context, errorMessage);
      }
    } on SocketException catch (_) {
      print('DEBUG: Network error adding to meal plan');
      if (mounted) {
        ErrorHandler.showOfflineSnackbar(context);
      }
    } on TimeoutException catch (_) {
      print('DEBUG: Timeout adding to meal plan');
      if (mounted) {
        ErrorHandler.showErrorSnackbar(context, 'Request timeout. Please try again.');
      }
    } catch (e) {
      print('DEBUG: Error adding to meal plan: $e');
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          'Failed to add to meal plan. Please try again.',
        );
      }
    }
  }

  Widget _buildAddToMealPlanButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _addToMealPlan,
          icon: const Icon(Icons.add_circle_outline, size: 24),
          label: const Text(
            'Add to Meal Plan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: Colors.green.withOpacity(0.3),
          ),
        ),
      ),
    );
  }


}


