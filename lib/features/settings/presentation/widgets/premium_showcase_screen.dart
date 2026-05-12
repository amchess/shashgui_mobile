import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

class PremiumShowcaseScreen extends StatelessWidget {
  const PremiumShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 220.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1e1e1e),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                loc.shashguiPremium,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.orange[900]!, Colors.deepPurple[900]!],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.workspace_premium,
                    size: 80,
                    color: Colors.white30,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    loc.ilPotereDeiServerCloud,
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loc.premiumIntroDesc,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 24),

                  _buildDetailedFeatureCard(
                    title: loc.featureBeautyTitle,
                    subtitle: loc.featureBeautySub,
                    desc: loc.featureBeautyDesc,
                    icon: Icons.auto_awesome,
                    color: Colors.pinkAccent,
                  ),
                  _buildDetailedFeatureCard(
                    title: loc.featureNuggetsTitle,
                    subtitle: loc.featureNuggetsSub,
                    desc: loc.featureNuggetsDesc,
                    icon: Icons.savings,
                    color: Colors.amber,
                  ),
                  _buildDetailedFeatureCard(
                    title: loc.featureXaiTitle,
                    subtitle: loc.featureXaiSub,
                    desc: loc.featureXaiDesc,
                    icon: Icons.psychology,
                    color: Colors.cyanAccent,
                  ),
                  _buildDetailedFeatureCard(
                    title: loc.featureAvatarTitle,
                    subtitle: loc.featureAvatarSub,
                    desc: loc.featureAvatarDesc,
                    icon: Icons.portrait,
                    color: Colors.deepPurpleAccent,
                  ),
                  _buildDetailedFeatureCard(
                    title: loc.featureIdeaTitle,
                    subtitle: loc.featureIdeaSub,
                    desc: loc.featureIdeaDesc,
                    icon: Icons.account_tree,
                    color: Colors.greenAccent,
                  ),
                  _buildDetailedFeatureCard(
                    title: loc.featureLearningTitle,
                    subtitle: loc.featureLearningSub,
                    desc: loc.featureLearningDesc,
                    icon: Icons.memory,
                    color: Colors.tealAccent,
                  ),
                  _buildDetailedFeatureCard(
                    title: loc.featureBatchTitle,
                    subtitle: loc.featureBatchSub,
                    desc: loc.featureBatchDesc,
                    icon: Icons.batch_prediction,
                    color: Colors.blueAccent,
                  ),
                  _buildDetailedFeatureCard(
                    title: loc.featureSqlTitle,
                    subtitle: loc.featureSqlSub,
                    desc: loc.featureSqlDesc,
                    icon: Icons.storage,
                    color: Colors.orange,
                  ),

                  const SizedBox(height: 32),

                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Integration in progress..."),
                        ),
                      );
                    },
                    icon: const Icon(Icons.cloud_sync, size: 28),
                    label: Text(
                      loc.sbloccaIlCloud999mese,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 8,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedFeatureCard({
    required String title,
    required String subtitle,
    required String desc,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              desc,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
