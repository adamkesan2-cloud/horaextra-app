// lib/presentation/features/dashboard/client/category_services_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/constants/app_sizes.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/data/models/category/category_model.dart';
import 'package:horaextra_app/data/models/service/service_model.dart';
import 'package:horaextra_app/presentation/features/dashboard/client/widgets/service_card.dart';

class CategoryServicesScreen extends StatefulWidget {
  final CategoryModel category;

  const CategoryServicesScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryServicesScreen> createState() => _CategoryServicesScreenState();
}

class _CategoryServicesScreenState extends State<CategoryServicesScreen> {
  late Future<void> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _servicesFuture = _loadServices();
  }

  Future<void> _loadServices() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    // forceRefresh omitido → usa o valor padrão false
    await provider.ensureServicesLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isTablet = size.width > 600 && size.width <= 1024;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category.name,
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w700,
            fontSize: isDesktop ? AppSizes.fontL : AppSizes.fontM,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.creamDark, height: 1),
        ),
      ),
      body: FutureBuilder<void>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            );
          }

          return Consumer<AppProvider>(
            builder: (context, provider, child) {
              final services =
                  provider.getServicesByCategory(widget.category.id);

              debugPrint(
                  '📋 CategoryServicesScreen — ${widget.category.name} (${widget.category.id}): ${services.length} serviço(s)');

              if (services.isEmpty) return _buildEmptyState(isDesktop);

              return Padding(
                padding: EdgeInsets.all(
                  isDesktop ? AppSizes.paddingXL : AppSizes.paddingL,
                ),
                child: _buildServicesList(isDesktop, isTablet, services),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildServicesList(
    bool isDesktop,
    bool isTablet,
    List<ServiceModel> services,
  ) {
    if (isDesktop) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: AppSizes.paddingL,
          mainAxisSpacing: AppSizes.paddingL,
          childAspectRatio: 1.2,
        ),
        itemCount: services.length,
        itemBuilder: (context, index) =>
            ServiceCard(service: services[index], isDesktop: isDesktop),
      );
    }

    if (isTablet) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSizes.paddingM,
          mainAxisSpacing: AppSizes.paddingM,
          childAspectRatio: 1.3,
        ),
        itemCount: services.length,
        itemBuilder: (context, index) =>
            ServiceCard(service: services[index], isDesktop: false),
      );
    }

    return ListView.builder(
      itemCount: services.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.paddingM),
        child: ServiceCard(service: services[index], isDesktop: false),
      ),
    );
  }

  Widget _buildEmptyState(bool isDesktop) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: isDesktop ? 120 : 80,
              color: AppColors.blueLight.withOpacity(0.5),
            ),
            const SizedBox(height: AppSizes.paddingL),
            Text(
              'Nenhum serviço disponível',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: AppSizes.paddingS),
            Text(
              'Ainda não há serviços cadastrados nesta categoria',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: AppColors.blueMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
