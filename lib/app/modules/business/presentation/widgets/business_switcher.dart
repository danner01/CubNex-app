import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';

class BusinessSwitcher extends StatelessWidget {
  const BusinessSwitcher({
    super.key,
    this.onChanged,
  });

  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveBusinessCubit, ActiveBusinessState>(
      builder: (context, state) {
        if (state.status == ActiveBusinessStatus.loading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        if (state.businesses.isEmpty) {
          return const SizedBox.shrink();
        }

        if (!state.hasMultipleBusinesses) {
          final business = state.activeBusiness ?? state.businesses.first;
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Negocio activo: ${business.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          );
        }

        final active = state.activeBusiness;
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: DropdownButtonFormField<String>(
            value: active?.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Negocio activo',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            items: state.businesses
                .map(
                  (business) => DropdownMenuItem(
                    value: business.id,
                    child: Text(
                      business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (businessId) async {
              final selected = state.businesses
                  .where((business) => business.id == businessId)
                  .firstOrNull;
              if (selected == null) return;
              await context.read<ActiveBusinessCubit>().selectBusiness(selected);
              onChanged?.call();
            },
          ),
        );
      },
    );
  }
}
