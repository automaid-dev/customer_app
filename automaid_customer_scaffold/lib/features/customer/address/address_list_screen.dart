import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/address_model.dart';
import '../providers/customer_providers.dart';
import 'address_form_screen.dart';

class AddressListScreen extends ConsumerWidget {
  const AddressListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My addresses')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AddressFormScreen())),
      ),
      body: addressesAsync.when(
        data: (addresses) => addresses.isEmpty
            ? const Center(child: Text('No addresses yet. Tap + to add one.'))
            : ListView.builder(
                itemCount: addresses.length,
                itemBuilder: (context, i) => _AddressTile(address: addresses[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load addresses: $e')),
      ),
    );
  }
}

class _AddressTile extends ConsumerWidget {
  const _AddressTile({required this.address});
  final Address address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(address.displayLabel),
        subtitle: Text('${address.addressLine1}, ${address.city} ${address.postcode}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddressFormScreen(existing: address)),
              );
            } else if (value == 'delete') {
              await ref.read(addressListProvider.notifier).remove(address.id);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
