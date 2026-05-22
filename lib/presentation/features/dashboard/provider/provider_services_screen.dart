import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/data/models/category/category_model.dart';
import 'package:horaextra_app/data/models/service/service_model.dart';

class ProviderServicesScreen extends StatefulWidget {
  const ProviderServicesScreen({super.key});

  @override
  State<ProviderServicesScreen> createState() => _ProviderServicesScreenState();
}

class _ProviderServicesScreenState extends State<ProviderServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  CategoryModel? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppProvider>(context);
    final categories = provider.getActiveCategories();
    final services = provider.getActiveServices();

    // Filtrar categorias
    final filteredCategories = categories.where((category) {
      if (_searchQuery.isEmpty) return true;
      return category.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          category.description
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
    }).toList();

    // Filtrar serviços
    final filteredServices = services.where((service) {
      if (_selectedCategory != null &&
          service.categoryId != _selectedCategory!.id) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      return service.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          service.description
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serviços Disponíveis'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: const [
            Tab(text: 'Categorias', icon: Icon(Icons.category_rounded)),
            Tab(
                text: 'Serviços',
                icon: Icon(Icons.home_repair_service_rounded)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barra de pesquisa
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.cardColor,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Buscar categorias ou serviços...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: theme.disabledColor),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              color: theme.disabledColor),
                          onPressed: () => setState(() {
                            _searchQuery = '';
                            _selectedCategory = null;
                          }),
                        )
                      : null,
                ),
              ),
            ),
          ),

          // Conteúdo das tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab Categorias
                _buildCategoriesTab(context, filteredCategories, provider),

                // Tab Serviços
                _buildServicesTab(context, filteredServices, provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab(
    BuildContext context,
    List<CategoryModel> categories,
    AppProvider provider,
  ) {
    if (categories.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.category_outlined,
        message: 'Nenhuma categoria disponível',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return _buildCategoryCard(context, categories[index], provider);
      },
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    CategoryModel category,
    AppProvider provider,
  ) {
    final theme = Theme.of(context);
    final color = _getCategoryColor(category);
    final servicesCount = provider.getServicesByCategory(category.id).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = category;
            _tabController.animateTo(1);
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ícone
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconData(category.icon),
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Informações
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.disabledColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$servicesCount serviços',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Seta
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServicesTab(
    BuildContext context,
    List<ServiceModel> services,
    AppProvider provider,
  ) {
    if (services.isEmpty) {
      String message = 'Nenhum serviço disponível';
      if (_selectedCategory != null) {
        message = 'Nenhum serviço em ${_selectedCategory!.name}';
      }

      return _buildEmptyState(
        context,
        icon: Icons.home_repair_service_outlined,
        message: message,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      itemBuilder: (context, index) {
        return _buildServiceCard(context, services[index], provider);
      },
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    ServiceModel service,
    AppProvider provider,
  ) {
    final theme = Theme.of(context);
    final category = provider.getCategoryById(service.categoryId);
    final color =
        category != null ? _getCategoryColor(category) : AppColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showServiceDetails(context, service, provider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.home_repair_service_rounded,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            service.categoryName,
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Descrição
              Text(
                service.description,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.disabledColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Rating e preço
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: AppColors.warning, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        service.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        ' (${service.reviewCount})',
                        style:
                            TextStyle(color: theme.disabledColor, fontSize: 12),
                      ),
                    ],
                  ),
                  Text(
                    'MT ${service.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
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

  void _showServiceDetails(
    BuildContext context,
    ServiceModel service,
    AppProvider provider,
  ) {
    final category = provider.getCategoryById(service.categoryId);
    final color =
        category != null ? _getCategoryColor(category) : AppColors.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(Icons.home_repair_service_rounded, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service.categoryName,
                          style:
                              TextStyle(color: Theme.of(context).disabledColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Detalhes
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailItem('Descrição', service.description),
                  const SizedBox(height: 16),
                  _buildDetailItem(
                      'Preço', 'MT ${service.price.toStringAsFixed(2)}'),
                  const SizedBox(height: 16),
                  _buildDetailItem(
                    'Avaliação',
                    '${service.rating.toStringAsFixed(1)} (${service.reviewCount} avaliações)',
                  ),
                ],
              ),
            ),

            // Botão de interesse (para prestador)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Interesse registrado em ${service.name}'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Tenho Interesse'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(CategoryModel category) {
    if (category.color != null) {
      try {
        return Color(
          int.parse('FF${category.color!.replaceFirst('#', '')}', radix: 16),
        );
      } catch (e) {
        return AppColors.primary;
      }
    }
    return AppColors.primary;
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'cleaning_services':
        return Icons.cleaning_services_rounded;
      case 'electric_bolt':
        return Icons.electric_bolt_rounded;
      case 'plumbing':
        return Icons.plumbing_rounded;
      case 'format_paint':
        return Icons.format_paint_rounded;
      case 'eco':
        return Icons.eco_rounded;
      case 'construction':
        return Icons.construction_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
