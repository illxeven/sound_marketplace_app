import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/marketplace_provider.dart';

class CreateMerchandiseScreen extends StatefulWidget {
  const CreateMerchandiseScreen({super.key});

  @override
  State<CreateMerchandiseScreen> createState() => _CreateMerchandiseScreenState();
}

class _CreateMerchandiseScreenState extends State<CreateMerchandiseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '29.99');
  final _stockController = TextEditingController(text: '10');
  final _optionsController = TextEditingController(text: 'S, M, L, XL');

  int? _selectedCategoryId;

  final List<Uint8List> _imageBytesList = [];
  final List<String> _imageNamesList = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mkt = context.read<MarketplaceProvider>();
      if (mkt.groupTypes.isEmpty || mkt.categories.isEmpty) {
        mkt.loadCategories();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (final file in result.files) {
            if (_imageBytesList.length < 5 && file.bytes != null) {
              _imageBytesList.add(file.bytes!);
              _imageNamesList.add(file.name);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting images: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;

    // Strict Client-Side Role Guard: ONLY users with the "Artist" role can upload
    if (user == null || !user.canUploadMerchandise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only users with the "Artist" role are permitted to upload merchandise items.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a specific category from the hierarchical categories list.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final mkt = context.read<MarketplaceProvider>();
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

      final stockQuantity = int.tryParse(_stockController.text.trim()) ?? 10;

      final item = await mkt.createMerchandise(
        sellerId: user.id,
        categoryId: _selectedCategoryId!,
        title: _titleController.text.trim(),
        price: price,
        stockQuantity: stockQuantity,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        options: _optionsController.text.trim().isNotEmpty
            ? _optionsController.text.trim()
            : null,
        filePath: _imageNamesList.isNotEmpty ? _imageNamesList.first : null,
        imageBlob: _imageBytesList.isNotEmpty ? _imageBytesList[0] : null,
        imageBlob2: _imageBytesList.length > 1 ? _imageBytesList[1] : null,
        imageBlob3: _imageBytesList.length > 2 ? _imageBytesList[2] : null,
        imageBlob4: _imageBytesList.length > 3 ? _imageBytesList[3] : null,
        imageBlob5: _imageBytesList.length > 4 ? _imageBytesList[4] : null,
      );

      if (!mounted) return;

      if (item != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merchandise "${item.title}" uploaded successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mkt.errorMessage ?? 'Failed to upload merchandise item'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final isArtist = user != null && user.canUploadMerchandise;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Merchandise Item'),
      ),
      body: !isArtist
          ? _buildUnauthorizedView()
          : Consumer<MarketplaceProvider>(
              builder: (context, mkt, child) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Artist Badge Indicator
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.secondaryCyan.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: AppTheme.secondaryCyan, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Verified Artist Authorization',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      'Publishing as ${user.effectiveName} (${user.email})',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section 1: Category Selection
                        const Text(
                          'Category Selection',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Select the merchandise category for your item. The parent group is automatically categorized.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 16),

                        // Specific Merchandise Category Dropdown Only
                        DropdownButtonFormField<int>(
                          value: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Specific Category *',
                            prefixIcon: Icon(Icons.category_rounded, color: AppTheme.primaryPurple),
                            hintText: 'Select category (e.g., Short Sleeve T-Shirt, Keychains...)',
                          ),
                          dropdownColor: AppTheme.cardColor,
                          items: mkt.categories.map((cat) {
                            return DropdownMenuItem<int>(
                              value: cat.id,
                              child: Text(
                                '${cat.name}${cat.groupTypeName != null ? " (${cat.groupTypeName})" : ""}',
                              ),
                            );
                          }).toList(),
                          validator: (val) => val == null ? 'Please select a specific category' : null,
                          onChanged: (val) {
                            setState(() {
                              _selectedCategoryId = val;
                            });
                          },
                        ),
                        const SizedBox(height: 24),

                        // Section 2: Merchandise Item Details
                        const Text(
                          'Item Details',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Item Title *',
                            hintText: 'e.g., Limited Tour Edition Hoodie',
                            prefixIcon: Icon(Icons.shopping_bag_outlined),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Item title is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Price (USD) *',
                                  hintText: '29.99',
                                  prefixIcon: Icon(Icons.attach_money, color: AppTheme.successGreen),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Price is required';
                                  }
                                  final num = double.tryParse(val.trim());
                                  if (num == null || num < 0) {
                                    return 'Enter a valid price';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Initial Stock *',
                                  hintText: '10',
                                  prefixIcon: Icon(Icons.inventory_2_outlined, color: AppTheme.secondaryCyan),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Stock is required';
                                  }
                                  final num = int.tryParse(val.trim());
                                  if (num == null || num < 0) {
                                    return 'Enter positive number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _optionsController,
                          decoration: const InputDecoration(
                            labelText: 'Available Options (Sizes / Variants)',
                            hintText: 'e.g., S, M, L, XL or Red, Black',
                            prefixIcon: Icon(Icons.tune_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Describe materials, dimensions, or release details...',
                            prefixIcon: Icon(Icons.description_outlined),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section 3: Merchandise Images (Up to 5)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Product Images (Up to 5)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              '${_imageBytesList.length} / 5 Selected',
                              style: const TextStyle(color: AppTheme.secondaryCyan, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_imageBytesList.isNotEmpty) ...[
                          SizedBox(
                            height: 100,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _imageBytesList.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (ctx, index) {
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        _imageBytesList[index],
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _imageBytesList.removeAt(index);
                                            _imageNamesList.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Colors.black87,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (_imageBytesList.length < 5)
                          InkWell(
                            onTap: _pickImages,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: _imageBytesList.isEmpty ? 140 : 60,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.secondaryCyan.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 28,
                                    color: AppTheme.secondaryCyan,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _imageBytesList.isEmpty ? 'Select Merchandise Images (Up to 5)' : 'Add More Photos',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.cloud_upload_rounded),
                            label: Text(
                              _isSubmitting ? 'Uploading...' : 'Publish Merchandise to Marketplace',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _isSubmitting ? null : _submit,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildUnauthorizedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gpp_bad_rounded, size: 64, color: AppTheme.errorRed),
            ),
            const SizedBox(height: 20),
            const Text(
              'Artist Authorization Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Only users with the "Artist" role are permitted to upload and list merchandise items in the Sound Marketplace.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Return to Profile'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
