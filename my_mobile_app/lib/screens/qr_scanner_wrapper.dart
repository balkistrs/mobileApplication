import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

class QRScannerWrapper {
  static Future<Map<String, String>?> scanQRCode(BuildContext context) async {
    if (kIsWeb) {
      // Sur le web, utiliser un dialogue avec option caméra
      return await _showWebQRScannerDialog(context);
    } else {
      // Sur mobile, utiliser le scanner natif
      return await _navigateToMobileQRScanner(context);
    }
  }

  static Future<Map<String, String>?> _showWebQRScannerDialog(BuildContext context) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const WebQRScannerDialog(),
    );
    return result;
  }

  static Future<Map<String, String>?> _navigateToMobileQRScanner(BuildContext context) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (context) => const MobileQRScannerScreen()),
    );
    return result;
  }
}

class WebQRScannerDialog extends StatefulWidget {
  const WebQRScannerDialog({super.key});

  @override
  State<WebQRScannerDialog> createState() => _WebQRScannerDialogState();
}

class _WebQRScannerDialogState extends State<WebQRScannerDialog> {
  final TextEditingController _manualInputController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _cameraActive = false;
  MobileScannerController? _cameraController;

  @override
  void initState() {
    super.initState();
    // Initialiser le contrôleur de caméra
    _cameraController = MobileScannerController();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _submitManualInput() {
    if (_manualInputController.text.isNotEmpty) {
      final data = _parseQRData(_manualInputController.text);
      Navigator.pop(context, data);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir des données'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        // Simuler la détection de QR code depuis l'image
        await Future.delayed(const Duration(seconds: 1));
        final data = _parseQRData('email:test@example.com;password:test123');
        if (mounted) {
          Navigator.pop(context, data);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleCamera() {
    setState(() {
      _cameraActive = !_cameraActive;
    });
  }

  void _handleDetectedQRCode(BarcodeCapture barcodes) {
    final barcode = barcodes.barcodes.first;
    if (barcode.rawValue != null && mounted) {
      final data = _parseQRData(barcode.rawValue!);
      Navigator.pop(context, data);
    }
  }

  Map<String, String> _parseQRData(String data) {
    final result = <String, String>{};
    final pairs = data.split(';');
    
    for (final pair in pairs) {
      final keyValue = pair.split(':');
      if (keyValue.length == 2) {
        result[keyValue[0]] = keyValue[1];
      }
    }
    
    // Support pour les données en JSON
    if (result.isEmpty && data.trim().startsWith('{')) {
      try {
        // Simulation d'analyse JSON (en réalité, vous utiliseriez jsonDecode)
        if (data.contains('email') && data.contains('password')) {
          final emailMatch = RegExp(r'"email"\s*:\s*"([^"]+)"').firstMatch(data);
          final passwordMatch = RegExp(r'"password"\s*:\s*"([^"]+)"').firstMatch(data);
          
          if (emailMatch != null) result['email'] = emailMatch.group(1)!;
          if (passwordMatch != null) result['password'] = passwordMatch.group(1)!;
        }
      } catch (e) {
        debugPrint('Error parsing JSON QR data: $e');
      }
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scanner QR Code'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Option 1: Utiliser la caméra
            Card(
              child: ListTile(
                leading: Icon(_cameraActive ? Icons.camera_alt : Icons.camera, 
                            color: Colors.blue),
                title: Text(_cameraActive ? 'Désactiver la caméra' : 'Activer la caméra'),
                subtitle: const Text('Scannez un QR Code avec votre caméra'),
                onTap: _toggleCamera,
              ),
            ),
            
            if (_cameraActive) ...[
              const SizedBox(height: 10),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: MobileScanner(
                    controller: _cameraController,
                    onDetect: _handleDetectedQRCode,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Pointez la caméra vers un QR Code',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Option 2: Import image
            Card(
              child: ListTile(
                leading: const Icon(Icons.image, color: Colors.green),
                title: const Text('Importer une image'),
                subtitle: const Text('Sélectionnez une image contenant un QR Code'),
                onTap: _pickImage,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Option 3: Manual input
            const Text(
              'Saisie manuelle',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Format: email:votre@email.com;password:votremotdepasse',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _manualInputController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Données du QR Code',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _submitManualInput,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}

class MobileQRScannerScreen extends StatefulWidget {
  const MobileQRScannerScreen({super.key});

  @override
  State<MobileQRScannerScreen> createState() => _MobileQRScannerScreenState();
}

class _MobileQRScannerScreenState extends State<MobileQRScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _isLoading = false;
  bool _torchEnabled = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  @override
  void initState() {
    super.initState();
    // Démarrer la caméra automatiquement sur mobile
    cameraController.start();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _handleDetectedQRCode(BarcodeCapture barcodes) {
    final barcode = barcodes.barcodes.first;
    if (barcode.rawValue != null && mounted) {
      final data = _parseQRData(barcode.rawValue!);
      Navigator.pop(context, data);
    }
  }

  Map<String, String> _parseQRData(String data) {
    final result = <String, String>{};
    final pairs = data.split(';');
    
    for (final pair in pairs) {
      final keyValue = pair.split(':');
      if (keyValue.length == 2) {
        result[keyValue[0]] = keyValue[1];
      }
    }
    
    return result;
  }

  void _toggleTorch() {
    setState(() {
      _torchEnabled = !_torchEnabled;
    });
    cameraController.toggleTorch();
  }

  void _switchCamera() {
    setState(() {
      _cameraFacing = _cameraFacing == CameraFacing.back 
          ? CameraFacing.front 
          : CameraFacing.back;
    });
    cameraController.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner QR Code'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: _torchEnabled ? Colors.yellow : Colors.grey,
            ),
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: Icon(
              _cameraFacing == CameraFacing.back 
                  ? Icons.camera_rear 
                  : Icons.camera_front,
            ),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _handleDetectedQRCode,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}