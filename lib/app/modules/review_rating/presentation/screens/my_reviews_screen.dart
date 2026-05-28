import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../blocs/my_reviews/my_reviews_cubit.dart';
import '../../blocs/my_reviews/my_reviews_state.dart';

class MyReviewsScreen extends StatelessWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MyReviewsCubit>()..load(),
      child: const _MyReviewsView(),
    );
  }
}

class _MyReviewsView extends StatelessWidget {
  const _MyReviewsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<MyReviewsCubit, MyReviewsState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () => context.read<MyReviewsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  'Mis resenas',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Historial de opiniones publicadas.'),
                const SizedBox(height: 16),
                if (state.status == MyReviewsStatus.loading)
                  const Center(child: CircularProgressIndicator())
                else if (state.items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Todavia no has escrito resenas.'),
                    ),
                  )
                else
                  ...state.items.map((review) {
                    final date = review.createdAt == null
                        ? 'Sin fecha'
                        : DateFormat('dd/MM/yyyy HH:mm').format(review.createdAt!);
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.rate_review_outlined,
                          color: AppColors.goldDark,
                        ),
                        title: Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < review.rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: AppColors.goldDark,
                              size: 18,
                            ),
                          ),
                        ),
                        subtitle: Text('${review.comment ?? 'Sin comentario'}\n$date'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go(AppRoutes.store(review.businessId)),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
