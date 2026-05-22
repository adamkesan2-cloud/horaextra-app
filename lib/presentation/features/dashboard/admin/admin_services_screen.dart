import 'package:flutter/material.dart';
import 'package:horaextra_app/data/models/category/category_model.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/data/models/service/service_model.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/widgets/service_dialog.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/widgets/service_card.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  List<ServiceModel> _filteredServices = [];
  String _searchQuery = '';
  String? _selectedCategoryId;
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.ensureServicesLoaded(forceRefresh: true);
      _applyFilters();
    });
  }

  void _applyFilters() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    List<ServiceModel> filtered = List.from(provider.services);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((service) {
        return service.name
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            service.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
      filtered = filtered
          .where((service) => service.categoryId == _selectedCategoryId)
          .toList();
    }

    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'price':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'category':
        filtered.sort((a, b) => a.categoryName.compareTo(b.categoryName));
        break;
      case 'date':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    if (mounted) {
      setState(() {
        _filteredServices = filtered;
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

    final categories = provider.categories.where((c) => c.isActive).toList();
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isTablet = size.width > 600 && size.width <= 900;

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: Column(
        children: [
          _buildHeader(context, provider.services.length, isDesktop, isTablet),
          _buildFilters(context, categories, isDesktop, isTablet,
              provider.services.length),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredServices.isEmpty
                    ? _buildEmptyState(context, isDesktop)
                    : _buildServicesList(
                        context, provider, isDesktop, isTablet),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_services',
        onPressed: () => _showServiceDialog(context),
        icon: const Icon(Icons.add, color: AppColors.white),
        label: const Text(
          'Novo Serviço',
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
          bottom:
              BorderSide(color: AppColors.creamDark.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Serviços',
                style: TextStyle(
                  fontSize: isDesktop ? 32 : (isTablet ? 28 : 24),
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gerencie os serviços oferecidos',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : (isTablet ? 14 : 13),
                  color: AppColors.blueMedium,
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 16 : 12, vertical: isDesktop ? 8 : 6),
            decoration: BoxDecoration(
              color: AppColors.creamMedium,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.creamDark),
            ),
            child: Row(
              children: [
                Icon(Icons.home_repair_service_rounded,
                    color: AppColors.primaryBlue, size: isDesktop ? 20 : 18),
                const SizedBox(width: 8),
                Text(
                  '$total serviços',
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

  Widget _buildFilters(
    BuildContext context,
    List<CategoryModel> categories,
    bool isDesktop,
    bool isTablet,
    int totalServices,
  ) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 24 : 16)),
      child: Column(
        children: [
          Container(
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
                  color: AppColors.primaryBlue, fontSize: isDesktop ? 16 : 14),
              decoration: InputDecoration(
                hintText: 'Buscar serviços...',
                hintStyle: TextStyle(
                    color: AppColors.blueLight, fontSize: isDesktop ? 16 : 14),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
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
                      value: _selectedCategoryId,
                      hint: Text('Todas categorias',
                          style: TextStyle(
                              color: AppColors.blueLight,
                              fontSize: isDesktop ? 16 : 14)),
                      isExpanded: true,
                      style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: isDesktop ? 16 : 14),
                      dropdownColor: AppColors.white,
                      icon: Icon(Icons.arrow_drop_down_rounded,
                          color: AppColors.primaryBlue,
                          size: isDesktop ? 28 : 24),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Todas categorias',
                              style: TextStyle(color: AppColors.primaryBlue)),
                        ),
                        ...categories.map((category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                          _applyFilters();
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 120,
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
                    isExpanded: true,
                    style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: isDesktop ? 16 : 14),
                    dropdownColor: AppColors.white,
                    icon: Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.primaryBlue,
                        size: isDesktop ? 28 : 24),
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('Nome')),
                      DropdownMenuItem(value: 'price', child: Text('Preço')),
                      DropdownMenuItem(
                          value: 'category', child: Text('Categoria')),
                      DropdownMenuItem(value: 'date', child: Text('Data')),
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
        ],
      ),
    );
  }

  Widget _buildServicesList(
    BuildContext context,
    AppProvider provider,
    bool isDesktop,
    bool isTablet,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        await provider.ensureServicesLoaded(forceRefresh: true);
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
              itemCount: _filteredServices.length,
              itemBuilder: (context, index) {
                return ServiceCard(
                  service: _filteredServices[index],
                  onEdit: () => _showServiceDialog(context,
                      service: _filteredServices[index]),
                  onDelete: () => _deleteService(
                      context, provider, _filteredServices[index]),
                  onToggleAvailable: () => _toggleServiceStatus(
                      context, provider, _filteredServices[index]),
                );
              },
            )
          : ListView.builder(
              padding: EdgeInsets.all(isTablet ? 24 : 16),
              itemCount: _filteredServices.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ServiceCard(
                    service: _filteredServices[index],
                    onEdit: () => _showServiceDialog(context,
                        service: _filteredServices[index]),
                    onDelete: () => _deleteService(
                        context, provider, _filteredServices[index]),
                    onToggleAvailable: () => _toggleServiceStatus(
                        context, provider, _filteredServices[index]),
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
            Icon(Icons.home_repair_service_outlined,
                size: isDesktop ? 120 : 80,
                color: AppColors.blueLight.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isEmpty && _selectedCategoryId == null
                  ? 'Nenhum serviço cadastrado'
                  : 'Nenhum serviço encontrado',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty && _selectedCategoryId == null
                  ? 'Clique no botão + para criar seu primeiro serviço'
                  : 'Tente ajustar os filtros',
              style: TextStyle(
                  fontSize: isDesktop ? 16 : 14, color: AppColors.blueMedium),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showServiceDialog(BuildContext context,
      {ServiceModel? service}) async {
    final result = await showDialog<ServiceModel>(
      context: context,
      builder: (context) => ServiceDialog(service: service),
    );

    if (result != null && mounted) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (!authProvider.isAdmin) {
        _showErrorMessage('Apenas administradores podem gerenciar serviços');
        return;
      }

      bool success;
      if (service == null) {
        success = await provider.createService(result);
      } else {
        success = await provider.updateService(service.id, result);
      }

      if (success) {
        // ← Força reload do servidor após criar/editar
        await provider.ensureServicesLoaded(forceRefresh: true);
        _applyFilters();
        _showSuccessMessage(service == null
            ? 'Serviço criado com sucesso!'
            : 'Serviço atualizado com sucesso!');
      } else {
        _showErrorMessage(provider.error ?? 'Erro ao salvar serviço');
      }
    }
  }

  Future<void> _deleteService(
      BuildContext context, AppProvider provider, ServiceModel service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Serviço',
            style: TextStyle(color: AppColors.primaryBlue)),
        content: Text(
          'Tem certeza que deseja excluir o serviço "${service.name}"?\n\nEsta ação não poderá ser desfeita.',
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
      final success = await provider.deleteService(service.id);
      if (success) {
        await provider.ensureServicesLoaded(forceRefresh: true);
        _applyFilters();
        _showSuccessMessage('Serviço excluído com sucesso!');
      } else {
        _showErrorMessage(provider.error ?? 'Erro ao excluir serviço');
      }
    }
  }

  void _toggleServiceStatus(
      BuildContext context, AppProvider provider, ServiceModel service) async {
    final success = await provider.toggleServiceStatus(service.id);
    if (success) {
      await provider.ensureServicesLoaded(forceRefresh: true);
      _applyFilters();
      _showSuccessMessage(service.isAvailable
          ? 'Serviço desativado com sucesso!'
          : 'Serviço ativado com sucesso!');
    } else {
      _showErrorMessage(provider.error ?? 'Erro ao alterar status');
    }
  }
}
