// lib/presentation/features/requests/request_details_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';

class RequestDetailsScreen extends StatefulWidget {
  final String requestId;

  const RequestDetailsScreen({super.key, required this.requestId});

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  // TODO: ajustar esta rota conforme o backend real (controller/route de requests)
  String _detailsEndpoint(String baseUrl) =>
      '$baseUrl/api/requests/${widget.requestId}';

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _details;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      final res = await http
          .get(Uri.parse(_detailsEndpoint(ap.baseUrl)))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _details = data is Map ? Map<String, dynamic>.from(data) : {};
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Não foi possível carregar os detalhes (${res.statusCode}).';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Erro ao carregar detalhes. Verifica a ligação.';
        });
      }
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final d = DateTime.tryParse(iso);
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Detalhes do Pedido',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue)),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.refresh_rounded, color: AppColors.primaryBlue),
            onPressed: _loadDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : _error != null
              ? _buildError()
              : _buildDetails(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails() {
    final d = _details ?? {};
    final serviceName = d['serviceName']?.toString() ??
        d['service_name']?.toString() ??
        'Serviço';
    final status = d['status']?.toString() ?? 'pending';
    final clientName =
        d['clientName']?.toString() ?? d['client_name']?.toString() ?? '-';
    final providerName =
        d['providerName']?.toString() ?? d['provider_name']?.toString();
    final address = d['address']?.toString() ??
        (d['location'] is Map
            ? (d['location']['address']?.toString() ?? '-')
            : '-');
    final budget = (d['budget'] as num?)?.toDouble() ??
        (d['totalBudget'] as num?)?.toDouble();
    final quantity = d['quantity'] as int? ?? 1;
    final scheduledDate =
        d['scheduledDate']?.toString() ?? d['scheduled_date']?.toString();
    final createdAt = d['createdAt']?.toString() ?? d['created_at']?.toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(serviceName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue)),
                  ),
                  _statusChip(status),
                ],
              ),
              if (quantity > 1) ...[
                const SizedBox(height: 4),
                Text('Quantidade: $quantity',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard('Pessoas', [
          _infoRow(Icons.person_rounded, 'Cliente', clientName),
          if (providerName != null && providerName.isNotEmpty)
            _infoRow(Icons.engineering_rounded, 'Prestador', providerName),
        ]),
        const SizedBox(height: 12),
        _sectionCard('Local e Data', [
          _infoRow(Icons.location_on_rounded, 'Endereço', address),
          if (scheduledDate != null && scheduledDate.isNotEmpty)
            _infoRow(
                Icons.event_rounded, 'Agendado para', _fmtDate(scheduledDate)),
          if (createdAt != null && createdAt.isNotEmpty)
            _infoRow(
                Icons.access_time_rounded, 'Criado em', _fmtDate(createdAt)),
        ]),
        if (budget != null) ...[
          const SizedBox(height: 12),
          _sectionCard('Valor', [
            _infoRow(Icons.payments_rounded, 'Total',
                'MT ${budget.toStringAsFixed(0)}'),
          ]),
        ],
      ],
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'accepted':
        color = AppColors.success;
        label = 'Aceite';
        break;
      case 'in_progress':
        color = AppColors.primaryBlue;
        label = 'Em andamento';
        break;
      case 'completed':
        color = AppColors.success;
        label = 'Concluído';
        break;
      case 'cancelled':
        color = AppColors.error;
        label = 'Cancelado';
        break;
      default:
        color = AppColors.warning;
        label = 'Pendente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
