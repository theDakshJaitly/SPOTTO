import 'package:flutter/material.dart';
import '../data/mock_data.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = mockUserProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Points',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${profile.points}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.stars,
                        size: 64,
                        color: Colors.amber,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Available Rewards',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildRewardCard(
                'Free Hour Parking',
                '500 points',
                Icons.local_parking,
                Colors.blue,
              ),
              _buildRewardCard(
                'Coffee Voucher',
                '300 points',
                Icons.local_cafe,
                Colors.brown,
              ),
              _buildRewardCard(
                'Premium Spot Access',
                '1000 points',
                Icons.workspace_premium,
                Colors.purple,
              ),
              _buildRewardCard(
                'Gas Gift Card',
                '800 points',
                Icons.local_gas_station,
                Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardCard(String title, String points, IconData icon, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(points),
        trailing: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: const Text('Redeem'),
        ),
      ),
    );
  }
}
