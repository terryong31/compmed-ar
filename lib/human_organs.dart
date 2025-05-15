import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class OrganModelsPage extends StatefulWidget {
  const OrganModelsPage({super.key});

  @override
  State<OrganModelsPage> createState() => _OrganModelsPageState();
}

class _OrganModelsPageState extends State<OrganModelsPage> {
  final List<Map<String, dynamic>> _models = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchModelsFromFirestore();
  }

  Future<void> fetchModelsFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('3dmodels').get();

      final List<Map<String, dynamic>> fetchedModels = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['name']?.toString() ?? 'Unknown',
          'fileURL': data['fileURL'] ?? '',
          'previewImage': data['previewImage'] ?? '',
          'description': data['description'] ?? 'No description available.',
          'webarURL': data.containsKey('webarURL') && data['webarURL'] != null
              ? data['webarURL'].toString()
              : '', // ✅ Ensure `webarURL` is not null
        };
      }).toList();

      setState(() {
        _models.addAll(fetchedModels);
        _isLoading = false;
      });
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching models: $error');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Human Organs', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _models.isEmpty
          ? const Center(child: Text('No models available.'))
          : ListView.builder(
        itemCount: _models.length,
        itemBuilder: (context, index) {
          final model = _models[index];
          return Card(
            margin: const EdgeInsets.all(10),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (model['previewImage']!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        model['previewImage']!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 50, color: Colors.grey),
                      ),
                    )
                  else
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model['name']!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ModelViewerPage(
                                modelName: model['name']!,
                                modelPath: model['fileURL']!,
                                description: model['description']!,
                                webarURL: model['webarURL']!,
                              ),
                            ),
                          ),
                          child: const Text('View Model'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ModelViewerPage extends StatelessWidget {
  final String modelName;
  final String modelPath;
  final String description;
  final String webarURL;

  const ModelViewerPage({
    super.key,
    required this.modelName,
    required this.modelPath,
    required this.description,
    required this.webarURL,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(modelName, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ModelViewer(
                  src: modelPath,
                  alt: 'A 3D model of $modelName',
                  ar: true,
                  arModes: ['scene-viewer', 'webxr', 'quick-look'],
                  arScale: ArScale.fixed,
                  arPlacement: ArPlacement.floor,
                  autoRotate: false,
                  cameraControls: true,
                  backgroundColor: Colors.white,
                ),
                // MyWebAR button inside ModelViewer
                if (webarURL.isNotEmpty)
                  Positioned(
                    bottom: 68,  // Align bottom same as WebXR button
                    right: 12,   // Adjust position beside WebXR button
                    child: GestureDetector(
                      onTap: () => launchUrl(Uri.parse(webarURL)),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 13),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white, // Circle background
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.view_in_ar_outlined,  // WebAR icon
                              size: 23,
                              color: Colors.green,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Description Box
          SizedBox(
            height: 180,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}