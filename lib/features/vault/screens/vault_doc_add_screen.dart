import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sanchita/features/vault/data/vault_doc_repository.dart';
import 'package:sanchita/features/vault/models/vault_doc_folder_model.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';

class VaultDocAddScreen extends ConsumerStatefulWidget {
  const VaultDocAddScreen({this.initialFolderId, super.key});

  final String? initialFolderId;

  @override
  ConsumerState<VaultDocAddScreen> createState() => _VaultDocAddScreenState();
}

class _VaultDocAddScreenState extends ConsumerState<VaultDocAddScreen> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  int _stepIndex = 0;
  String _source = '';
  String _saveMode = 'original';
  bool _loadingFolders = true;
  List<VaultDocFolderModel> _folders = const <VaultDocFolderModel>[];
  String? _folderId;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _saving = false;
  String? _errorMessage;

  static const Map<String, int> _modeEstimatedBytes = <String, int>{
    'original': 2400 * 1024,
    'enhanced': 220 * 1024,
    'document': 75 * 1024,
  };

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _loadingFolders = true;
    });

    final result = await ref.read(vaultDocRepositoryProvider).getFolders();
    if (!mounted) {
      return;
    }

    result.when(
      success: (folders) {
        final preferred = widget.initialFolderId?.trim();
        final preferredExists = folders.any((folder) => folder.id == preferred);
        setState(() {
          _folders = folders;
          _folderId = preferredExists
              ? preferred
              : (folders.isNotEmpty ? folders.first.id : null);
          _loadingFolders = false;
        });
      },
      failure: (message) {
        setState(() {
          _folders = const <VaultDocFolderModel>[];
          _folderId = null;
          _errorMessage = message;
          _loadingFolders = false;
        });
      },
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  Future<void> _pickImage(String source) async {
    final normalized = source.trim().toLowerCase();

    try {
      late Uint8List bytes;
      String fileName = 'imported_image';

      if (normalized == 'files') {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );
        if (!mounted || picked == null || picked.files.isEmpty) {
          return;
        }
        final file = picked.files.first;
        Uint8List? pickedBytes = file.bytes;
        if ((pickedBytes == null || pickedBytes.isEmpty) && file.path != null) {
          pickedBytes = await File(file.path!).readAsBytes();
        }
        if (pickedBytes == null || pickedBytes.isEmpty) {
          setState(() {
            _errorMessage =
                'Could not read selected file. Please choose another file.';
          });
          return;
        }
        bytes = pickedBytes;
        fileName = file.name;
      } else {
        final pickerSource = normalized == 'camera'
            ? ImageSource.camera
            : ImageSource.gallery;
        final picked = await _imagePicker.pickImage(source: pickerSource);
        if (!mounted || picked == null) {
          return;
        }
        bytes = await picked.readAsBytes();
        fileName = picked.name;
      }

      if (!mounted) {
        return;
      }

      if (bytes.isEmpty) {
        setState(() {
          _errorMessage =
              'Selected image is empty. Please choose another file.';
        });
        return;
      }

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = fileName;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Failed to pick image: $error';
      });
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final label = _labelController.text.trim();
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    final notes = _notesController.text.trim();
    final folderId = (_folderId ?? '').trim();
    final imageBytes = _selectedImageBytes;

    if (label.isEmpty) {
      setState(() {
        _errorMessage = 'Label is required.';
      });
      return;
    }
    if (folderId.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a folder.';
      });
      return;
    }
    if (_source.isNotEmpty && (imageBytes == null || imageBytes.isEmpty)) {
      setState(() {
        _errorMessage = 'Select an image before saving this document.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(vaultDocRepositoryProvider)
        .createItem(
          folderId: folderId,
          label: label,
          saveMode: _saveMode,
          tags: tags,
          notes: notes,
          imageBytes: imageBytes,
        );
    if (!mounted) {
      return;
    }

    await result.when(
      success: (_) async {
        context.pop(true);
      },
      failure: (message) async {
        setState(() {
          _saving = false;
          _errorMessage = message;
        });
      },
    );
  }

  Widget _buildStepSource() {
    Widget option(String value, IconData icon, String label, String subtitle) {
      final selected = _source == value;
      return Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(subtitle),
          trailing: Icon(
            selected ? Icons.check_circle_outline : Icons.circle_outlined,
          ),
          onTap: () async {
            setState(() {
              _source = value;
            });
            await _pickImage(value);
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Step 1: Source', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        option(
          'camera',
          Icons.photo_camera_outlined,
          'Camera',
          'Capture a document photo',
        ),
        option(
          'gallery',
          Icons.photo_library_outlined,
          'Gallery',
          'Import from photos',
        ),
        option(
          'files',
          Icons.folder_open_outlined,
          'Files',
          'Import image file',
        ),
        if (_selectedImageName != null) ...<Widget>[
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(_selectedImageName!),
              subtitle: Text(
                'Selected image: ${_formatSize(_selectedImageBytes?.length ?? 0)}',
              ),
              trailing: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedImageBytes = null;
                    _selectedImageName = null;
                  });
                },
                child: const Text('Clear'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepMode() {
    Widget modeTile(String mode, String title, String desc, IconData icon) {
      final estimated = _modeEstimatedBytes[mode] ?? 0;
      final selected = _saveMode == mode;
      return Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text('$desc - Est: ${_formatSize(estimated)}'),
          trailing: Icon(
            selected
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onTap: () {
            setState(() {
              _saveMode = mode;
            });
          },
        ),
      );
    }

    final previewLabel = switch (_saveMode) {
      'original' => 'Preview: Source quality preserved',
      'enhanced' => 'Preview: Sharper and clearer output',
      _ => 'Preview: High-contrast document style',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Step 2: Quality Mode',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        modeTile(
          'original',
          'Original',
          'Preserve source quality',
          Icons.image_outlined,
        ),
        modeTile(
          'enhanced',
          'Enhanced',
          'Readable with moderate compression',
          Icons.auto_fix_high_outlined,
        ),
        modeTile(
          'document',
          'Document',
          'Text clarity with minimum size',
          Icons.description_outlined,
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(previewLabel),
        ),
      ],
    );
  }

  Widget _buildStepMetadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Step 3: Label & Save',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _labelController,
          decoration: const InputDecoration(
            labelText: 'Document label',
            hintText: 'e.g. Passport Copy, Utility Bill Feb 2026',
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _folderId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Folder'),
          items: _folders
              .map<DropdownMenuItem<String>>((folder) {
                return DropdownMenuItem<String>(
                  value: folder.id,
                  child: Text(folder.name),
                );
              })
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _folderId = value;
            });
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _tagsController,
          decoration: const InputDecoration(
            labelText: 'Tags (comma separated)',
            hintText: 'personal, legal, 2026',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notesController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'Optional notes',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoNext = switch (_stepIndex) {
      0 => _source.isNotEmpty && _selectedImageBytes != null,
      1 => _saveMode.isNotEmpty,
      _ => true,
    };
    final progress = (_stepIndex + 1) / 3;

    if (_loadingFolders) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: const AppNavigationBar(
        title: 'Add Document',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Step ${_stepIndex + 1} of 3',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                ],
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Stepper(
                currentStep: _stepIndex,
                onStepTapped: (index) {
                  setState(() {
                    _stepIndex = index;
                  });
                },
                controlsBuilder: (_, __) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: <Widget>[
                        if (_stepIndex > 0)
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _stepIndex -= 1;
                              });
                            },
                            child: const Text('Back'),
                          )
                        else
                          const SizedBox.shrink(),
                        const Spacer(),
                        if (_stepIndex < 2)
                          FilledButton(
                            onPressed: canGoNext
                                ? () {
                                    setState(() {
                                      _stepIndex += 1;
                                    });
                                  }
                                : null,
                            child: const Text('Continue'),
                          )
                        else
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(
                              _saving ? 'Saving...' : 'Save Document',
                            ),
                          ),
                      ],
                    ),
                  );
                },
                steps: <Step>[
                  Step(
                    title: const Text('Source'),
                    isActive: _stepIndex >= 0,
                    content: _buildStepSource(),
                  ),
                  Step(
                    title: const Text('Mode'),
                    isActive: _stepIndex >= 1,
                    content: _buildStepMode(),
                  ),
                  Step(
                    title: const Text('Metadata'),
                    isActive: _stepIndex >= 2,
                    content: _buildStepMetadata(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
