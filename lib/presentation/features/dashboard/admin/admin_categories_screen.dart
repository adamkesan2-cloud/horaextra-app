import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/data/models/category/category_model.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/widgets/category_dialog.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/widgets/category_card.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  List<CategoryModel> _filteredCategories = [];
  String _searchQuery = '';
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.ensureCategoriesLoaded(forceRefresh: true);
      _applyFilters();
    });
  }

  void _applyFilters() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    List<CategoryModel> filtered = List.from(provider.categories);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((category) {
        return category.name
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            category.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
      }).toList();
    }

    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'date':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    if (mounted) {
      setState(() {
        _filteredCategories = filtered;
      });
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Sempre sincroniza filtros quando provider atualiza
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyFilters());

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isTablet = size.width > 600 && size.width <= 900;

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: Column(
        children: [
          _buildHeader(
              context, provider.categories.length, isDesktop, isTablet),
          _buildSearchAndFilters(context, isDesktop, isTablet),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCategories.isEmpty
                    ? _buildEmptyState(context, isDesktop)
                    : _buildCategoriesList(
                        context, provider, isDesktop, isTablet),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_categories',
        onPressed: () => _showCategoryDialog(context),
        icon: const Icon(Icons.add, color: AppColors.white),
        label: const Text(
          'Nova Categoria',
          style: TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.primaryBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, int total, bool isDesktop, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 24 : 16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.creamDark.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categorias',
                style: TextStyle(
                  fontSize: isDesktop ? 32 : (isTablet ? 28 : 24),
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gerencie as categorias de serviços',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : (isTablet ? 14 : 13),
                  color: AppColors.blueMedium,
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 16 : 12,
              vertical: isDesktop ? 8 : 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.creamMedium,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.creamDark),
            ),
            child: Row(
              children: [
                Icon(Icons.category_rounded,
                    color: AppColors.primaryBlue, size: isDesktop ? 20 : 18),
                const SizedBox(width: 8),
                Text(
                  '$total categorias',
                  style: TextStyle(
                    fontSize: isDesktop ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(
      BuildContext context, bool isDesktop, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 24 : 16)),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: isDesktop ? 56 : 48,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.creamDark),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _applyFilters();
                  });
                },
                style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: isDesktop ? 16 : 14),
                decoration: InputDecoration(
                  hintText: 'Buscar categorias...',
                  hintStyle: TextStyle(
                      color: AppColors.blueLight,
                      fontSize: isDesktop ? 16 : 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppColors.blueMedium, size: isDesktop ? 24 : 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              color: AppColors.blueMedium,
                              size: isDesktop ? 24 : 20),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _applyFilters();
                            });
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: isDesktop ? 56 : 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.creamDark),
              boxShadow: [
                BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: isDesktop ? 16 : 14),
                dropdownColor: AppColors.white,
                icon: Icon(Icons.arrow_drop_down_rounded,
                    color: AppColors.primaryBlue, size: isDesktop ? 28 : 24),
                items: const [
                  DropdownMenuItem(value: 'name', child: Text('Nome A-Z')),
                  DropdownMenuItem(value: 'date', child: Text('Mais recente')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _sortBy = value;
                      _applyFilters();
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList(
    BuildContext context,
    AppProvider provider,
    bool isDesktop,
    bool isTablet,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        await provider.ensureCategoriesLoaded(forceRefresh: true);
        _applyFilters();
      },
      color: AppColors.primaryBlue,
      backgroundColor: AppColors.creamLight,
      child: isDesktop
          ? GridView.builder(
              padding: const EdgeInsets.all(32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 0.9,
              ),
              itemCount: _filteredCategories.length,
              itemBuilder: (context, index) {
                return CategoryCard(
                  category: _filteredCategories[index],
                  onEdit: () => _showCategoryDialog(context,
                      category: _filteredCategories[index]),
                  onDelete: () => _deleteCategory(
                      context, provider, _filteredCategories[index]),
                  onToggleActive: () => _toggleCategoryStatus(
                      context, provider, _filteredCategories[index]),
                );
              },
            )
          : ListView.builder(
              padding: EdgeInsets.all(isTablet ? 24 : 16),
              itemCount: _filteredCategories.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: isTablet ? 220 : 200,
                    child: CategoryCard(
                      category: _filteredCategories[index],
                      onEdit: () => _showCategoryDialog(context,
                          category: _filteredCategories[index]),
                      onDelete: () => _deleteCategory(
                          context, provider, _filteredCategories[index]),
                      onToggleActive: () => _toggleCategoryStatus(
                          context, provider, _filteredCategories[index]),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDesktop) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined,
                size: isDesktop ? 120 : 80,
                color: AppColors.blueLight.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isEmpty
                  ? 'Nenhuma categoria cadastrada'
                  : 'Nenhuma categoria encontrada',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty
                  ? 'Clique no botão + para criar sua primeira categoria'
                  : 'Tente buscar com outros termos',
              style: TextStyle(
                  fontSize: isDesktop ? 16 : 14, color: AppColors.blueMedium),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategoryDialog(BuildContext context,
      {CategoryModel? category}) async {
    final result = await showDialog<CategoryModel>(
      context: context,
      builder: (context) => CategoryDialog(category: category),
    );

    if (result != null && mounted) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (!authProvider.isAuthenticated) {
        _showErrorMessage('Faça login novamente para criar categorias');
        return;
      }

      bool success;
      if (category == null) {
        success = await provider.createCategory(result);
      } else {
        success = await provider.updateCategory(category.id, result);
      }

      if (success) {
        // ← Força reload do servidor após criar/editar
        await provider.ensureCategoriesLoaded(forceRefresh: true);
        _applyFilters();
        _showSuccessMessage(category == null
            ? 'Categoria criada com sucesso!'
            : 'Categoria atualizada com sucesso!');
      } else {
        _showErrorMessage(provider.error ?? 'Erro ao salvar categoria');
      }
    }
  }

  Future<void> _deleteCategory(BuildContext context, AppProvider provider,
      CategoryModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Categoria',
            style: TextStyle(color: AppColors.primaryBlue)),
        content: Text(
          'Tem certeza que deseja excluir a categoria "${category.name}"?\n\nEsta ação não poderá ser desfeita.',
          style: const TextStyle(color: AppColors.blueMedium),
        ),
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.blueMedium),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await provider.deleteCategory(category.id);
      if (success) {
        await provider.ensureCategoriesLoaded(forceRefresh: true);
        _applyFilters();
        _showSuccessMessage('Categoria excluída com sucesso!');
      } else {
        _showErrorMessage(provider.error ?? 'Erro ao excluir categoria');
      }
    }
  }

  void _toggleCategoryStatus(BuildContext context, AppProvider provider,
      CategoryModel category) async {
    final success = await provider.toggleCategoryStatus(category.id);
    if (success) {
      await provider.ensureCategoriesLoaded(forceRefresh: true);
      _applyFilters();
      _showSuccessMessage(category.isActive
          ? 'Categoria desativada com sucesso!'
          : 'Categoria ativada com sucesso!');
    } else {
      _showErrorMessage(provider.error ?? 'Erro ao alterar status');
    }
  }
}
