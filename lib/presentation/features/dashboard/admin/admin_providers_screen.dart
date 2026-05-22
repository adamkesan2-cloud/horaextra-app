// lib/presentation/features/dashboard/admin/admin_providers_screen.dart
import 'package:flutter/material.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/data/models/user/user_model.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminProvidersScreen extends StatefulWidget {
  const AdminProvidersScreen({super.key});

  @override
  State<AdminProvidersScreen> createState() => _AdminProvidersScreenState();
}

class _AdminProvidersScreenState extends State<AdminProvidersScreen> {
  List<UserModel> _pendingProviders = [];
  bool _isLoading = true;
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoading = true);
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final users = await appProvider.getAllUsers();

      setState(() {
        _pendingProviders = users.where((u) {
          if (u.role != 'provider') return false;
          final isApproved = u.providerProfile?['is_approved'] == true;
          if (_filter == 'pending') {
            return !isApproved;
          } else if (_filter == 'approved') {
            return isApproved;
          }
          return true;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Erro ao carregar prestadores: $e');
    }
  }

  Future<void> _approveProvider(UserModel provider) async {
    setState(() => _isLoading = true);
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.approveProvider(provider.id);
      _showSnackBar('Prestador aprovado com sucesso!', isError: false);
      await _loadProviders();
    } catch (e) {
      _showSnackBar('Erro ao aprovar: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectProvider(UserModel provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeitar Prestador'),
        content: Text('Tem certeza que deseja rejeitar ${provider.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        await appProvider.rejectProvider(provider.id);
        _showSnackBar('Prestador rejeitado', isError: false);
        await _loadProviders();
      } catch (e) {
        _showSnackBar('Erro ao rejeitar: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showProviderDetails(UserModel provider) {
    final profile = provider.providerProfile;
    final isApproved = profile?['is_approved'] == true;
    final specialties = profile?['specialties'] as List? ?? [];
    final experienceYears = profile?['experience_years'] ?? 0;
    final description = profile?['description'] ?? 'Não informado';
    final cvUrl = profile?['cv_url']?.toString();
    final idDocumentUrl = profile?['id_document_url']?.toString();
    final location =
        provider.location?['address'] ?? provider.address ?? 'Não informado';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.creamLight,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.primaryBlue, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          provider.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            provider.email,
                            style: const TextStyle(color: AppColors.blueMedium),
                          ),
                          Text(
                            provider.phone ?? 'Sem telefone',
                            style: const TextStyle(color: AppColors.blueMedium),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Informações Profissionais',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 12),
                _infoTile('Descrição', description),
                _infoTile('Experiência', '$experienceYears anos'),
                _infoTile(
                    'Especialidades',
                    specialties.isNotEmpty
                        ? specialties.take(3).join(', ')
                        : 'Nenhuma'),
                _infoTile('Localização', location),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Documentos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 12),
                if (cvUrl != null && cvUrl.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.description,
                        color: AppColors.primaryBlue),
                    title: const Text('Currículo'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _launchUrl(cvUrl),
                  ),
                if (idDocumentUrl != null && idDocumentUrl.isNotEmpty)
                  ListTile(
                    leading:
                        const Icon(Icons.badge, color: AppColors.primaryBlue),
                    title: const Text('Documento de Identificação'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _launchUrl(idDocumentUrl),
                  ),
                const SizedBox(height: 20),
                if (!isApproved)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _rejectProvider(provider);
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Rejeitar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _approveProvider(provider);
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Aprovar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.blueMedium,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Não foi possível abrir o link');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        title: const Text('Gerenciar Prestadores'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
              value: _filter,
              dropdownColor: AppColors.white,
              style: const TextStyle(color: AppColors.white),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pendentes')),
                DropdownMenuItem(value: 'approved', child: Text('Aprovados')),
                DropdownMenuItem(value: 'all', child: Text('Todos')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _filter = value);
                  _loadProviders();
                }
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingProviders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: AppColors.blueLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _filter == 'pending'
                            ? 'Nenhum prestador pendente'
                            : 'Nenhum prestador encontrado',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(isDesktop ? 24 : 16),
                  itemCount: _pendingProviders.length,
                  itemBuilder: (context, index) {
                    final provider = _pendingProviders[index];
                    final profile = provider.providerProfile;
                    final isPending = profile?['is_approved'] != true;
                    final specialties = profile?['specialties'] as List? ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              isPending ? AppColors.warning : AppColors.success,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.creamLight,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isPending
                                  ? AppColors.warning
                                  : AppColors.success,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              provider.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          provider.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(provider.email),
                            Text(provider.phone ?? 'Sem telefone'),
                            if (specialties.isNotEmpty)
                              Text(
                                'Especialidades: ${specialties.take(2).join(', ')}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility,
                                  color: AppColors.primaryBlue),
                              onPressed: () => _showProviderDetails(provider),
                            ),
                            if (isPending) ...[
                              IconButton(
                                icon: const Icon(Icons.check_circle,
                                    color: AppColors.success),
                                onPressed: () => _approveProvider(provider),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel,
                                    color: AppColors.error),
                                onPressed: () => _rejectProvider(provider),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
