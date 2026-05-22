import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/data/models/service/service_model.dart';
import 'package:horaextra_app/data/models/category/category_model.dart';

class ServiceDialog extends StatefulWidget {
  final ServiceModel? service;

  const ServiceDialog({super.key, this.service});

  @override
  State<ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<ServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _estimatedTimeController;

  String? _selectedCategoryId;
  bool _isAvailable = true;
  bool _isLoading = false;

  List<CategoryModel> _categories = [];

  @override
  void initState() {
    super.initState();

    final service = widget.service;

    _nameController = TextEditingController(text: service?.name ?? '');
    _descriptionController =
        TextEditingController(text: service?.description ?? '');
    _priceController = TextEditingController(
      text: service?.price.toString() ?? '',
    );

    // CORRIGIDO: estimatedTime agora é parte do modelo
    _estimatedTimeController = TextEditingController(
      text: service?.estimatedTime.toString() ?? '60',
    );

    _selectedCategoryId = service?.categoryId;
    _isAvailable = service?.isAvailable ?? true;

    // Carregar categorias
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    setState(() {
      _categories = provider.categories.where((c) => c.isActive).toList();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _estimatedTimeController.dispose();
    super.dispose();
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategoryId == null) {
        _showErrorMessage('Selecione uma categoria');
        return;
      }

      setState(() => _isLoading = true);

      // Encontrar a categoria selecionada
      final selectedCategory = _categories.firstWhere(
        (c) => c.id == _selectedCategoryId,
      );

      debugPrint(
          '📦 Categoria selecionada: ${selectedCategory.name} (ID: ${selectedCategory.id})');

      final service = ServiceModel(
        id: widget.service?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        description: _descriptionController.text,
        price: double.tryParse(_priceController.text) ?? 0.0,
        categoryId: selectedCategory.id, // USAR O ID CORRETO (UUID)
        categoryName: selectedCategory.name,
        estimatedTime: int.tryParse(_estimatedTimeController.text) ?? 60,
        isAvailable: _isAvailable,
        rating: widget.service?.rating ?? 0.0,
        reviewCount: widget.service?.reviewCount ?? 0,
        createdAt: widget.service?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      debugPrint('📦 Serviço a ser criado: ${service.name}');
      debugPrint('   Categoria ID: ${service.categoryId}');
      debugPrint('   Categoria Nome: ${service.categoryName}');

      setState(() => _isLoading = false);
      Navigator.pop(context, service);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.service != null;
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
                    isEditing ? 'Editar Serviço' : 'Novo Serviço',
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

              // Form Fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Nome
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do Serviço',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons
                              .build), // CORRIGIDO: Icons.service não existe
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

                      // Categoria
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        hint: const Text('Selecione uma categoria'),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Selecione uma categoria';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Preço
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Preço (MT)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Campo obrigatório';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Valor inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Tempo estimado
                      TextFormField(
                        controller: _estimatedTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Tempo Estimado (minutos)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timer),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Campo obrigatório';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Valor inválido';
                          }
                          if (int.tryParse(value)! <= 0) {
                            return 'Tempo deve ser maior que zero';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isAvailable ? Icons.check_circle : Icons.cancel,
                              color: _isAvailable
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Serviço Disponível',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            Switch(
                              value: _isAvailable,
                              onChanged: (value) {
                                setState(() {
                                  _isAvailable = value;
                                });
                              },
                              activeThumbColor: AppColors.success,
                            ),
                          ],
                        ),
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
                      onPressed: () => Navigator.pop(context),
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
}
