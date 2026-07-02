import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../business_directory/presentation/screens/business_detail_screen.dart';

class BusinessStorePreviewScreen extends StatefulWidget {
  const BusinessStorePreviewScreen({super.key});

  @override
  State<BusinessStorePreviewScreen> createState() =>
      _BusinessStorePreviewScreenState();
}

class _BusinessStorePreviewScreenState
    extends State<BusinessStorePreviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<ActiveBusinessCubit>().state;
      if (state.status == ActiveBusinessStatus.initial) {
        context.read<ActiveBusinessCubit>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveBusinessCubit, ActiveBusinessState>(
      builder: (context, state) {
        if (state.status == ActiveBusinessStatus.loading ||
            state.status == ActiveBusinessStatus.initial) {
          return const Center(child: CircularProgressIndicator());
        }

        final business = state.activeBusiness;
        if (business == null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_rounded, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Todavia no tienes un negocio activo.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.businessWizard),
                    icon: const Icon(Icons.add_business_rounded),
                    label: const Text('Crear negocio'),
                  ),
                ],
              ),
            ),
          );
        }

        return BusinessDetailScreen(businessId: business.id);
      },
    );
  }
}
