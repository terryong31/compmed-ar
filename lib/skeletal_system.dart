import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class InteractiveSkeletalPage extends StatefulWidget {
  const InteractiveSkeletalPage({super.key});

  @override
  State<InteractiveSkeletalPage> createState() => _InteractiveSkeletalPageState();
}

class _InteractiveSkeletalPageState extends State<InteractiveSkeletalPage> {
  bool isMale = true; // Gender toggle
  String selectedLayer = 'Skeletal'; // Default layer
  String selectedPart = 'Full Skeleton'; // Default selected part

  List<Map<String, dynamic>> skeletalModels = []; // Store models retrieved from Firestore
  String? selectedModelUrl; // Model URL from Firestore
  String? selectedDescription; // Description of the selected model

  @override
  void initState() {
    super.initState();
    fetchSkeletalModels();
  }

  /// Fetch skeletal models from Firestore
  Future<void> fetchSkeletalModels() async {
    try {
      final QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('skeletal_models').orderBy('createdAt', descending: true).get();

      setState(() {
        skeletalModels = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'fileName': doc['fileName'],
            'description': doc['description'],
            'gender': doc['gender'],
            'system': doc['system'],
            'fileURL': doc['fileURL'],
            'previewImage': doc['previewImage'],
          };
        }).toList();
      });

      updateSelectedModel();
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching skeletal models: $e");
      }
    }
  }

  /// Update the selected model URL based on gender and system type
  void updateSelectedModel() {
    if (kDebugMode) {
      print("Updating model for: Gender=${isMale ? 'male' : 'female'}, System=$selectedPart");
    }

    final model = skeletalModels.firstWhere(
          (model) => model['gender'] == (isMale ? 'male' : 'female') && model['system'] == selectedPart,
      orElse: () {
        if (kDebugMode) {
          print("No model found for Gender=${isMale ? 'male' : 'female'}, System=$selectedPart");
        }
        // Fallback to a default (e.g., Full Skeleton for Skeletal layer)
        if (selectedLayer == 'Skeletal') {
          selectedPart = 'Full Skeleton'; // Reset to default
          return skeletalModels.firstWhere(
                (model) => model['gender'] == (isMale ? 'male' : 'female') && model['system'] == 'Full Skeleton',
            orElse: () => {},
          );
        }
        return {};
      },
    );

    setState(() {
      selectedModelUrl = model.isNotEmpty ? model['fileURL'] : null;
      selectedDescription = model.isNotEmpty ? model['description'] : "No description available.";
    });

    if (kDebugMode) {
      print("Selected Model URL: $selectedModelUrl");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive Skeletal Viewer', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildGenderSelection(),
          _buildLayerSelection(),
          _buildBonePartSelector(),
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(0.0),
                  child: selectedModelUrl != null
                      ? ModelViewer(
                    key: ValueKey(selectedModelUrl),
                    src: selectedModelUrl!,
                    alt: '3D Skeletal Model',
                    ar: true,
                    arModes: ['scene-viewer', 'webxr', 'quick-look'],
                    arScale: ArScale.fixed,
                    arPlacement: ArPlacement.floor,
                    autoRotate: false,
                    cameraControls: true,
                    backgroundColor: Colors.white38,
                  )
                      : const Center(
                    child: Text("No model available for the selected options."),
                  ),
                ),
                _buildDescriptionButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// UI: Gender selection
  Widget _buildGenderSelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Male'),
          selected: isMale,
          selectedColor: Colors.blueAccent,
          onSelected: (_) {
            setState(() {
              isMale = true;
              updateSelectedModel();
            });
          },
        ),
        const SizedBox(width: 10),
        ChoiceChip(
          label: const Text('Female'),
          selected: !isMale,
          selectedColor: Colors.pinkAccent,
          onSelected: (_) {
            setState(() {
              isMale = false;
              updateSelectedModel();
            });
          },
        ),
      ],
    );
  }

  /// UI: System layer selection
  Widget _buildLayerSelection() {
    const layers = ['Skeletal', 'Connective Tissue', 'Arterial', 'Muscle'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: layers.map((layer) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ChoiceChip(
              label: Text(layer),
              selected: selectedLayer == layer,
              selectedColor: Colors.blueAccent,
              onSelected: (_) {
                setState(() {
                  selectedLayer = layer;
                  // Reset selectedPart based on the layer
                  if (layer == 'Skeletal') {
                    selectedPart = 'Full Skeleton'; // Default for Skeletal
                  } else {
                    selectedPart = layer; // Use the layer name for non-skeletal
                  }
                  updateSelectedModel();
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  /// UI: Bone structure selector with fixed dropdown position & proper ordering
  Widget _buildBonePartSelector() {
    const double dropdownHeight = 56.0;

    if (selectedLayer != 'Skeletal') {
      return const SizedBox(height: dropdownHeight);
    }

    List<String> orderedParts = ['Full Skeleton', 'Skull', 'Spine', 'Ribcage', 'Arms', 'Legs'];

    // If selectedPart isn’t in orderedParts, default to 'Full Skeleton'
    if (!orderedParts.contains(selectedPart)) {
      selectedPart = 'Full Skeleton'; // Reset to default
    }

    return SizedBox(
      height: dropdownHeight,
      width: double.infinity,
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          value: selectedPart,
          items: orderedParts.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              selectedPart = newValue!;
              updateSelectedModel();
            });
          },
          dropdownStyleData: DropdownStyleData(
            maxHeight: 250,
            offset: const Offset(0, 40),
          ),
        ),
      ),
    );
  }

  /// UI: Description button
  Widget _buildDescriptionButton() {
    return Positioned(
      bottom: 16,
      left: 16,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.black.withOpacity(0.6),
        child: const Icon(Icons.info, color: Colors.white),
        onPressed: () {
          _showDescriptionDialog();
        },
      ),
    );
  }

  /// Dialog to show description
  void _showDescriptionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Model Description"),
          content: Text(selectedDescription ?? "No description available."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }
}