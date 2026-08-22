import 'package:flutter/material.dart';
import 'register_rider_screen.dart';
import 'register_merchant_screen.dart';

enum _Role { rider, merchant }

/// Step 1/3 — "Which one describes you the best?" — matches the flow
/// spec exactly: rider splits into Gig Worker / Staff from Auto Maid,
/// merchant splits into Outlet Partner / Auto Maid Outlet. The chosen
/// type is passed straight into the role-specific registration screen
/// rather than carried as separate app state.
class RegisterRoleScreen extends StatefulWidget {
  const RegisterRoleScreen({super.key});

  @override
  State<RegisterRoleScreen> createState() => _RegisterRoleScreenState();
}

class _RegisterRoleScreenState extends State<RegisterRoleScreen> {
  _Role _role = _Role.rider;
  String? _riderType; // 'gig' | 'staff'
  String? _merchantType; // 'outlet_partner' | 'automaid_outlet'

  bool get _canContinue => _role == _Role.rider ? _riderType != null : _merchantType != null;

  void _continue() {
    if (!_canContinue) return;
    if (_role == _Role.rider) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RegisterRiderScreen(typeRider: _riderType!)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RegisterMerchantScreen(typeMerchant: _merchantType!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 1/3')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Register to Get Started', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Join our team and unlock new opportunities.'),
            const SizedBox(height: 24),
            const Text('Which one describes you the best?', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RoleCard(
                    icon: Icons.delivery_dining,
                    label: "I'm a rider",
                    selected: _role == _Role.rider,
                    onTap: () => setState(() => _role = _Role.rider),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RoleCard(
                    icon: Icons.storefront,
                    label: "I'm a merchant/partner",
                    selected: _role == _Role.merchant,
                    onTap: () => setState(() => _role = _Role.merchant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_role == _Role.rider) ...[
              const Text('Type of Rider', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _OptionTile(
                label: 'Gig Worker',
                selected: _riderType == 'gig',
                onTap: () => setState(() => _riderType = 'gig'),
              ),
              _OptionTile(
                label: 'Staff from Auto Maid',
                selected: _riderType == 'staff',
                onTap: () => setState(() => _riderType = 'staff'),
              ),
            ] else ...[
              const Text('Type of Merchant', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _OptionTile(
                label: 'Outlet Partner',
                selected: _merchantType == 'outlet_partner',
                onTap: () => setState(() => _merchantType = 'outlet_partner'),
              ),
              _OptionTile(
                label: 'Auto Maid Outlet',
                selected: _merchantType == 'automaid_outlet',
                onTap: () => setState(() => _merchantType = 'automaid_outlet'),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canContinue ? _continue : null,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(icon, size: 36),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: RadioListTile<bool>(
        value: true,
        groupValue: selected ? true : null,
        onChanged: (_) => onTap(),
        title: Text(label),
      ),
    );
  }
}
