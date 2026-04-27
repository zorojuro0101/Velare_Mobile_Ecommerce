import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import 'add_edit_address_screen.dart';

class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() => _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    try {
      // Ensure AuthService is initialized
      await _authService.initialize();
      
      var buyerId = _authService.currentBuyerId;
      
      // If buyer_id is still null, try to fetch it from the database
      if (buyerId == null) {
        final userId = _authService.currentUserId;
        if (userId != null) {
          final buyerData = await _supabase
              .from('buyers')
              .select('buyer_id')
              .eq('user_id', userId)
              .maybeSingle();
          
          if (buyerData != null) {
            buyerId = buyerData['buyer_id'].toString();
          }
        }
      }
      
      if (buyerId == null) {
        setState(() {
          _addresses = [];
          _isLoading = false;
        });
        return;
      }
      
      final response = await _supabase
          .from('addresses')
          .select()
          .eq('user_type', 'buyer')
          .eq('user_ref_id', buyerId)
          .order('is_default', ascending: false);
      
      setState(() {
        _addresses = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        SnackBarHelper.showError(context, 'Error loading addresses: $e');
      }
    }
  }

  Future<void> _addAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEditAddressScreen(),
      ),
    );

    if (result == true) {
      _loadAddresses();
    }
  }

  Future<void> _editAddress(Map<String, dynamic> address) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditAddressScreen(address: address),
      ),
    );

    if (result == true) {
      _loadAddresses();
    }
  }

  Future<void> _setDefaultAddress(int addressId) async {
    try {
      await _authService.initialize();
      var buyerId = _authService.currentBuyerId;
      
      if (buyerId == null) {
        final userId = _authService.currentUserId;
        if (userId != null) {
          final buyerData = await _supabase
              .from('buyers')
              .select('buyer_id')
              .eq('user_id', userId)
              .maybeSingle();
          
          if (buyerData != null) {
            buyerId = buyerData['buyer_id'].toString();
          }
        }
      }
      
      if (buyerId == null) return;

      // Remove default from all addresses
      await _supabase
          .from('addresses')
          .update({'is_default': false})
          .eq('user_type', 'buyer')
          .eq('user_ref_id', buyerId);

      // Set new default
      await _supabase
          .from('addresses')
          .update({'is_default': true})
          .eq('address_id', addressId);

      _loadAddresses();
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Default address updated');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _deleteAddress(int addressId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Address', style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete this address?', style: GoogleFonts.goudyBookletter1911()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.goudyBookletter1911(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.goudyBookletter1911(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('addresses').delete().eq('address_id', addressId);
        _loadAddresses();
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Address deleted');
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, 'Error: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('My Addresses', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _addresses.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    return _buildAddressCard(_addresses[index]);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAddress,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add Address', style: GoogleFonts.goudyBookletter1911()),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No addresses saved',
            style: GoogleFonts.goudyBookletter1911(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add an address for faster checkout',
            style: GoogleFonts.goudyBookletter1911(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> address) {
    final isDefault = address['is_default'] == true;
    final recipientName = address['recipient_name'] ?? '';
    final phoneNumber = address['phone_number'] ?? '';
    final fullAddress = address['full_address'] ?? '';
    final barangay = address['barangay'] ?? '';
    final city = address['city'] ?? '';
    final province = address['province'] ?? '';
    final postalCode = address['postal_code'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDefault ? Border.all(color: Colors.black, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _editAddress(address),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 20,
                            color: isDefault ? Colors.black : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          if (isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'DEFAULT',
                                style: GoogleFonts.goudyBookletter1911(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'default') {
                          _setDefaultAddress(address['address_id']);
                        } else if (value == 'edit') {
                          _editAddress(address);
                        } else if (value == 'delete') {
                          _deleteAddress(address['address_id']);
                        }
                      },
                      itemBuilder: (context) => [
                        if (!isDefault)
                          PopupMenuItem(
                            value: 'default',
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 18),
                                const SizedBox(width: 8),
                                Text('Set as Default', style: GoogleFonts.goudyBookletter1911()),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text('Edit', style: GoogleFonts.goudyBookletter1911()),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              const SizedBox(width: 8),
                              Text('Delete', style: GoogleFonts.goudyBookletter1911(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  recipientName,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (phoneNumber.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    phoneNumber,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  fullAddress,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$barangay, $city, $province',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    if (postalCode.isNotEmpty)
                      Text(
                        postalCode,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
