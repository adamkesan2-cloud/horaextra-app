// lib/presentation/features/admin/widgets/category_dialog.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:horaextra_app/data/models/service/image_picker_service.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/core/config/api_config.dart';
import 'package:horaextra_app/data/models/category/category_model.dart';
import 'package:horaextra_app/core/services/image_picker_service.dart';
import 'package:horaextra_app/core/services/upload_service.dart';

class CategoryDialog extends StatefulWidget {
  final CategoryModel? category;

  const CategoryDialog({super.key, this.category});

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _iconController;
  late TextEditingController _colorController;
  late TextEditingController _orderController;

  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageUrl;
  bool _isLoading = false;
  bool _isUploading = false;
  String? _uploadError;

  final List<String> _availableIcons = [
    'cleaning_services',
    'electric_bolt',
    'plumbing',
    'format_paint',
    'eco',
    'construction',
    'handyman',
    'pets',
    'local_shipping',
    'school',
    'medical_services',
    'celebration',
  ];

  final List<Color> _availableColors = [
    const Color(0xFF3B82F6), // Azul
    const Color(0xFF10B981), // Verde
    const Color(0xFFF59E0B), // Amarelo
    const Color(0xFFEF4444), // Vermelho
    const Color(0xFF8B5CF6), // Roxo
    const Color(0xFFEC4899), // Rosa
    const Color(0xFF06B6D4), // Ciano
    const Color(0xFFF97316), // Laranja
  ];

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _descriptionController =
        TextEditingController(text: category?.description ?? '');
    _iconController =
        TextEditingController(text: category?.icon ?? 'cleaning_services');
    _colorController =
        TextEditingController(text: category?.color ?? '#3B82F6');
    _orderController = TextEditingController(
      text: (category?.order ?? 0).toString(),
    );
    _imageBytes = category?.imageBytes;
    _imageName = category?.imageName;
    _imageUrl = category?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _iconController.dispose();
    _colorController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });
    
    try {
      final result = await ImagePickerService.pickImage();
      debugPrint('🖼️ ImagePickerService resultado: ${result?.runtimeType}');
      
      if (result != null) {
        debugPrint('   bytes: ${result.bytes?.length ?? 'NULL'}');
        debugPrint('   name: ${result.name}');
        setState(() {
          _imageBytes = result.bytes;
          _imageName = result.name;
          _imageUrl = null;
        });
      } else {
        debugPrint('⚠️ Nenhuma imagem selecionada (result é null)');
      }
    } catch (e) {
      debugPrint('❌ Erro ao selecionar imagem: $e');
      _showErrorMessage('Erro ao selecionar imagem: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  String _getFullImageUrl(String? path) {
    return ApiConfig.getFullImageUrl(path);
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _uploadError = null;
    });

    String? uploadedImageUrl = widget.category?.imageUrl;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📋 SUBMIT FORM');
    debugPrint('   Nome: ${_nameController.text}');
    debugPrint('   _imageBytes: ${_imageBytes?.length ?? 'NULL'} bytes');
    debugPrint('   _imageName: $_imageName');
    debugPrint('   _imageUrl existente: $_imageUrl');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // ✅ Upload da imagem se houver nova
    if (_imageBytes != null && _imageName != null) {
      debugPrint('📤 Iniciando upload da imagem: $_imageName');
      
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final uploadService = UploadService(authProvider);

        uploadedImageUrl = await uploadService.uploadCategoryImage(
          imageBytes: _imageBytes!,
          fileName: _imageName!,
          categoryName: _nameController.text,
        );

        debugPrint('📥 uploadCategoryImage retornou: $uploadedImageUrl');

        if (uploadedImageUrl == null || uploadedImageUrl.isEmpty) {
          debugPrint('❌ Upload retornou URL vazia ou nula!');
          setState(() {
            _uploadError = 'Upload falhou — URL não retornada pelo servidor';
            _isLoading = false;
          });
          _showErrorMessage('Erro: imagem não foi salva no servidor.');
          return;
        }

        debugPrint('✅ Upload com sucesso: $uploadedImageUrl');
        _showSuccessMessage('Imagem enviada com sucesso!');
      } catch (e) {
        debugPrint('❌ Exceção no upload: $e');
        setState(() {
          _uploadError = 'Erro no upload: $e';
          _isLoading = false;
        });
        _showErrorMessage('Erro no upload da imagem: $e');
        return;
      }
    } else {
      debugPrint('⚠️ Sem nova imagem para upload');
    }

    debugPrint('💾 Salvando categoria com imageUrl: $uploadedImageUrl');

    final category = CategoryModel(
      id: widget.category?.id ?? 
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      icon: _iconController.text,
      color: _colorController.text,
      imageUrl: uploadedImageUrl,
      imageBytes: null,
      imageName: null,
      order: int.tryParse(_orderController.text) ?? 0,
      isActive: widget.category?.isActive ?? true,
      createdAt: widget.category?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() => _isLoading = false);
    
    if (mounted) {
      Navigator.pop(context, category);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isDesktop ? 600 : double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit : Icons.add,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Editar Categoria' : 'Nova Categoria',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Image Picker
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: (_imageBytes != null || _imageUrl != null)
                            ? null
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(60),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: _imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: Image.memory(
                                _imageBytes!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            )
                          : _imageUrl != null && _imageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(60),
                                  child: Image.network(
                                    _getFullImageUrl(_imageUrl),
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: progress.expectedTotalBytes != null
                                              ? progress.cumulativeBytesLoaded /
                                                  progress.expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint('❌ Erro ao carregar imagem: $error');
                                      return Icon(
                                        Icons.broken_image,
                                        size: 40,
                                        color: Colors.grey[400],
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.image,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _isUploading ? null : _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: _isUploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Nome do arquivo ou erro de upload
              if (_imageName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _imageName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_uploadError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Center(
                    child: Text(
                      _uploadError!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Form Fields (Expanded para scroll)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Nome
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Categoria',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Descrição
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Ordem
                      TextFormField(
                        controller: _orderController,
                        decoration: const InputDecoration(
                          labelText: 'Ordem',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.sort),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Ícone
                      DropdownButtonFormField<String>(
                        value: _iconController.text,
                        decoration: const InputDecoration(
                          labelText: 'Ícone',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.brush),
                        ),
                        items: _availableIcons.map((icon) {
                          return DropdownMenuItem(
                            value: icon,
                            child: Row(
                              children: [
                                Icon(_getIconData(icon), size: 20),
                                const SizedBox(width: 8),
                                Text(icon),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _iconController.text = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Cor
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cor da Categoria',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableColors.map((color) {
                              final isSelected = _colorController.text == _colorToHex(color);
                              return InkWell(
                                onTap: () => setState(() {
                                  _colorController.text = _colorToHex(color);
                                }),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(color: Colors.black, width: 3)
                                        : null,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEditing ? 'Atualizar' : 'Criar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'electric_bolt':
        return Icons.electric_bolt;
      case 'plumbing':
        return Icons.plumbing;
      case 'format_paint':
        return Icons.format_paint;
      case 'eco':
        return Icons.eco;
      case 'construction':
        return Icons.construction;
      case 'handyman':
        return Icons.handyman;
      case 'pets':
        return Icons.pets;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'school':
        return Icons.school;
      case 'medical_services':
        return Icons.medical_services;
      case 'celebration':
        return Icons.celebration;
      default:
        return Icons.category;
    }
  }
}