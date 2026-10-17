import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';

class CreateTrackScreen extends StatefulWidget {
  const CreateTrackScreen({super.key});

  @override
  State<CreateTrackScreen> createState() => _CreateTrackScreenState();
}

class _CreateTrackScreenState extends State<CreateTrackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistNameController = TextEditingController();
  final _featuresController = TextEditingController();
  final _filePathController = TextEditingController();
  final _priceController = TextEditingController(text: '0.00');
  final _durationController = TextEditingController();
  final _genreController = TextEditingController(text: 'Hip Hop & Rap');

  bool _isPromoted = false;
  bool _isSubmitting = false;
  String _mediaType = 'AUDIO'; // 'AUDIO' or 'VIDEO'
  PlatformFile? _pickedFile;
  String? _selectedFileName;
  int? _selectedFileSize;
  PlatformFile? _pickedVideoFile;
  String? _selectedVideoName;
  int? _selectedVideoSize;
  PlatformFile? _pickedCoverFile;

  final List<String> _genres = [
    'Hip Hop & Rap',
    'Electronic (including House, Techno, Trance)',
    'Pop',
    'R&B & Soul',
    'Rock',
    'Alternative Rock',
    'Dance & EDM',
    'Indie',
    'Classical',
    'Country',
    'Reggae',
    'Jazz & Blues',
    'Folk & Singer-Songwriter',
    'Soundtrack',
    'Spoken Word',
    'World',
    'Afro Beats',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _artistNameController.text = user.displayName!;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistNameController.dispose();
    _featuresController.dispose();
    _filePathController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pickedFile = file;
          _selectedFileName = file.name;
          _selectedFileSize = file.size;
          _filePathController.text = file.path ?? file.name;

          // Prefill title if empty
          if (_titleController.text.trim().isEmpty) {
            String nameWithoutExt = file.name;
            final dotIndex = nameWithoutExt.lastIndexOf('.');
            if (dotIndex != -1) {
              nameWithoutExt = nameWithoutExt.substring(0, dotIndex);
            }
            nameWithoutExt =
                nameWithoutExt.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
            if (nameWithoutExt.isNotEmpty) {
              _titleController.text =
                  nameWithoutExt[0].toUpperCase() + nameWithoutExt.substring(1);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting file: $e')));
      }
    }
  }

  Future<void> _pickVideoFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'webm', 'mkv', 'avi'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pickedVideoFile = file;
          _selectedVideoName = file.name;
          _selectedVideoSize = file.size;
          _mediaType = 'VIDEO';

          // Prefill title if empty
          if (_titleController.text.trim().isEmpty) {
            String nameWithoutExt = file.name;
            final dotIndex = nameWithoutExt.lastIndexOf('.');
            if (dotIndex != -1) {
              nameWithoutExt = nameWithoutExt.substring(0, dotIndex);
            }
            nameWithoutExt =
                nameWithoutExt.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
            if (nameWithoutExt.isNotEmpty) {
              _titleController.text =
                  nameWithoutExt[0].toUpperCase() + nameWithoutExt.substring(1);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting video: $e')));
      }
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedCoverFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting cover image: $e')),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;

    if (user == null || !user.canUploadTracks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access Denied: Only Artists and Producers are authorized to upload tracks.',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final catalog = context.read<CatalogProvider>();
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final duration = int.tryParse(_durationController.text);
    final filePath =
        _pickedFile?.path ??
        (_filePathController.text.trim().isNotEmpty
            ? _filePathController.text.trim()
            : null);

    final track = await catalog.uploadTrack(
      artistId: user.id,
      title: _titleController.text.trim(),
      filePath: filePath,
      fileBytes: _pickedFile?.bytes,
      fileName: _pickedFile?.name,
      videoPath: _pickedVideoFile?.path,
      videoBytes: _pickedVideoFile?.bytes,
      videoName: _pickedVideoFile?.name,
      mediaType: _mediaType,
      coverArtPath: _pickedCoverFile?.path,
      coverArtBytes: _pickedCoverFile?.bytes,
      coverArtName: _pickedCoverFile?.name,
      genre: _genreController.text,
      price: price,
      artistName:
          _artistNameController.text.trim().isNotEmpty
              ? _artistNameController.text.trim()
              : null,
      features:
          _featuresController.text.trim().isNotEmpty
              ? _featuresController.text.trim()
              : null,
      durationSeconds: duration,
      isPromoted: _isPromoted,
      uploadSource: 'PROFILE_PAGE',
      uploaderUserId: user.id,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (track != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Published "${track.title}" successfully!\nBackend storage path: ${track.filePath}',
            ),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed: ${catalog.errorMessage ?? "Unknown error"}',
            ),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final canUpload = user != null && user.canUploadTracks;

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Track')),
      body:
          !canUpload
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(
                          Icons.lock_person_outlined,
                          size: 48,
                          color: AppTheme.warningOrange,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Artist Access Only',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Track uploading is exclusively permitted for registered Music Artists and Producers.\n\nYour account is currently set to Consumer role. To upload music, switch or register with an Artist or Producer role.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to Profile'),
                      ),
                    ],
                  ),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Publish Sound to Marketplace',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Upload your master audio, beat, or loop to stream and monetize globally.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Audio File Picker Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                _selectedFileName != null
                                    ? AppTheme.secondaryCyan.withValues(
                                      alpha: 0.5,
                                    )
                                    : Colors.white10,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.audio_file_rounded,
                                  color: AppTheme.secondaryCyan,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Audio File',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _pickAudioFile,
                                  icon: const Icon(
                                    Icons.folder_open_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Browse Audio'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.secondaryCyan,
                                    side: const BorderSide(
                                      color: AppTheme.secondaryCyan,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedFileName != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppTheme.successGreen,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedFileName!,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (_selectedFileSize != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatFileSize(_selectedFileSize!),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            // Manual or selected filepath field
                            TextFormField(
                              controller: _filePathController,
                              decoration: InputDecoration(
                                labelText:
                                    _pickedFile != null
                                        ? 'Selected File (Uploaded to backend storage)'
                                        : 'Audio Filepath or S3 URI',
                                prefixIcon: const Icon(
                                  Icons.link_rounded,
                                  color: Colors.white54,
                                ),
                                hintText:
                                    'e.g. /music/track.mp3 or browse file above',
                                helperText:
                                    'The backend will store this audio and save the server filepath.',
                              ),
                              validator: (val) {
                                if (_pickedFile != null) return null;
                                return (val == null || val.trim().isEmpty)
                                    ? 'Please select a file or enter an audio path'
                                    : null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Video File Picker Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                _selectedVideoName != null
                                    ? AppTheme.accentPink.withValues(
                                      alpha: 0.5,
                                    )
                                    : Colors.white10,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.video_collection_rounded,
                                  color: AppTheme.accentPink,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Music Video (Optional)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _pickVideoFile,
                                  icon: const Icon(
                                    Icons.video_file_rounded,
                                    size: 18,
                                  ),
                                  label: Text(_pickedVideoFile != null ? 'Change Video' : 'Browse Video'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.accentPink,
                                    side: const BorderSide(
                                      color: AppTheme.accentPink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedVideoName != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppTheme.successGreen,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedVideoName!,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (_selectedVideoSize != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatFileSize(_selectedVideoSize!),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Cover Artwork Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                _pickedCoverFile != null
                                    ? AppTheme.primaryPurple.withValues(
                                      alpha: 0.6,
                                    )
                                    : Colors.white10,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.image_rounded,
                                  color: AppTheme.primaryPurple,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cover Artwork',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Persisted directly to MySQL BLOB storage',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _pickCoverImage,
                                  icon: const Icon(
                                    Icons.add_photo_alternate_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _pickedCoverFile != null
                                        ? 'Change Art'
                                        : 'Select Artwork',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryPurple,
                                    side: const BorderSide(
                                      color: AppTheme.primaryPurple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_pickedCoverFile != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child:
                                          _pickedCoverFile!.bytes != null
                                              ? Image.memory(
                                                _pickedCoverFile!.bytes!,
                                                width: 64,
                                                height: 64,
                                                fit: BoxFit.cover,
                                              )
                                              : Container(
                                                width: 64,
                                                height: 64,
                                                color: AppTheme.primaryPurple
                                                    .withValues(alpha: 0.2),
                                                child: const Icon(
                                                  Icons.image,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _pickedCoverFile!.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatFileSize(
                                              _pickedCoverFile!.size,
                                            ),
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 14,
                                                color: AppTheme.successGreen,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Ready to persist into database',
                                                style: TextStyle(
                                                  color: AppTheme.successGreen,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white54,
                                      ),
                                      tooltip: 'Remove Artwork',
                                      onPressed:
                                          () => setState(
                                            () => _pickedCoverFile = null,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Track Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Track Title *',
                          prefixIcon: Icon(
                            Icons.music_note,
                            color: AppTheme.secondaryCyan,
                          ),
                          hintText: 'e.g. Cyber City Nights',
                        ),
                        validator:
                            (val) =>
                                (val == null || val.trim().isEmpty)
                                    ? 'Please enter a title'
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      // Artist / Stage Name
                      TextFormField(
                        controller: _artistNameController,
                        decoration: const InputDecoration(
                          labelText: 'Artist / Stage Name',
                          prefixIcon: Icon(
                            Icons.person_pin_rounded,
                            color: AppTheme.primaryPurple,
                          ),
                          hintText: 'e.g. DJ Cyber, Nova Wave',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Featured Artists / Credits
                      TextFormField(
                        controller: _featuresController,
                        decoration: const InputDecoration(
                          labelText: 'Featured Artists / Credits',
                          prefixIcon: Icon(
                            Icons.group_outlined,
                            color: AppTheme.secondaryCyan,
                          ),
                          hintText: 'e.g. feat. Luna Star, Metro',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Genre Dropdown & Duration
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return DropdownMenu<String>(
                                  width: constraints.maxWidth,
                                  controller: _genreController,
                                  enableFilter: true,
                                  requestFocusOnTap: true,
                                  label: const Text('Genre'),
                                  leadingIcon: const Icon(
                                    Icons.category,
                                    color: AppTheme.primaryPurple,
                                  ),
                                  dropdownMenuEntries:
                                      _genres.map((g) {
                                        return DropdownMenuEntry(
                                          value: g,
                                          label: g,
                                        );
                                      }).toList(),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration (sec)',
                                prefixIcon: Icon(
                                  Icons.timer_outlined,
                                  color: Colors.white54,
                                ),
                                hintText: '180',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Price
                      TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Price (USD) - 0.00 for Free',
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: AppTheme.successGreen,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Enter price';
                          if (double.tryParse(val) == null) {
                            return 'Must be a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Promoted Switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Promote this track'),
                        subtitle: const Text(
                          'Boost track visibility in marketplace recommendations',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        value: _isPromoted,
                        activeColor: AppTheme.secondaryCyan,
                        onChanged: (val) => setState(() => _isPromoted = val),
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child:
                              _isSubmitting
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text(
                                    'Publish Track to Marketplace',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
    );
  }
}
