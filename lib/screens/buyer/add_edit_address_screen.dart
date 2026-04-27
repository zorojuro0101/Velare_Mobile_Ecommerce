import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/address_selector_modal.dart';

class AddEditAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? address;

  const AddEditAddressScreen({super.key, this.address});

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _postalCodeController = TextEditingController();
  
  String? _region;
  String? _province;
  String? _city;
  String? _barangay;
  String _addressDisplay = '';
  
  bool _isDefault = false;
  bool _isSaving = false;
  bool _showAddressError = false;

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      _recipientController.text = widget.address!['recipient_name'] ?? '';
      _phoneController.text = widget.address!['phone_number'] ?? '';
      _streetController.text = widget.address!['street_name'] ?? '';
      _houseNumberController.text = widget.address!['house_number'] ?? '';
      _postalCodeController.text = widget.address!['postal_code'] ?? '';
      _region = widget.address!['region'];
      _province = widget.address!['province'];
      _city = widget.address!['city'];
      _barangay = widget.address!['barangay'];
      _isDefault = widget.address!['is_default'] == true;
      _updateAddressDisplay();
    }
  }

  void _updateAddressDisplay() {
    if (_region != null && _city != null && _barangay != null) {
      _addressDisplay = _province != null
          ? '$_region, $_province, $_city, $_barangay'
          : '$_region, $_city, $_barangay';
    } else {
      _addressDisplay = '';
    }
  }

  Future<void> _selectAddress() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressSelectorModal(
        initialRegion: _region,
        initialProvince: _province,
        initialCity: _city,
        initialBarangay: _barangay,
      ),
    );

    if (result != null) {
      setState(() {
        _region = result['region'];
        _province = result['province'];
        _city = result['city'];
        _barangay = result['barangay'];
        _showAddressError = false; // Clear error when address is selected
        _updateAddressDisplay();
      });
      
      // Automatically lookup postal code
      await _lookupPostalCode();
    }
  }

  Future<void> _lookupPostalCode() async {
    if (_city == null) return;
    
    try {
      // Fetch postal code data from the same source as web
      final response = await http.get(
        Uri.parse('https://gist.githubusercontent.com/chrisbjr/784565232f10cba6530856dc7fda367a/raw/ph-zip-codes.json'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> postalData = json.decode(response.body);
        
        // Normalize and tokenize for matching
        final cityTokens = _normalizeAndTokenize(_city!);
        final provinceTokens = _province != null ? _normalizeAndTokenize(_province!) : <String>[];
        final barangayTokens = _barangay != null ? _normalizeAndTokenize(_barangay!) : <String>[];
        
        // Find best match
        String? foundPostalCode;
        int bestScore = 0;
        
        for (var entry in postalData) {
          final area = entry['area'] as String;
          final areaTokens = _normalizeAndTokenize(area);
          
          int score = 0;
          
          // City must match
          if (!cityTokens.every((token) => areaTokens.contains(token))) continue;
          
          score += 5; // Base score for city match
          
          // Bonus for province match
          if (provinceTokens.isNotEmpty && provinceTokens.every((token) => areaTokens.contains(token))) {
            score += 3;
          }
          
          // Bonus for barangay match
          if (barangayTokens.isNotEmpty && barangayTokens.any((token) => areaTokens.contains(token))) {
            score += 2;
          }
          
          if (score > bestScore) {
            bestScore = score;
            foundPostalCode = entry['zip'] as String;
          }
        }
        
        if (foundPostalCode != null && mounted) {
          setState(() {
            _postalCodeController.text = foundPostalCode!;
          });
        }
      }
    } catch (e) {
      print('Error looking up postal code: $e');
      // Silently fail - postal code is optional
    }
  }

  Set<String> _normalizeAndTokenize(String text) {
    final stopWords = {'OF', 'THE', 'CITY', 'MUNICIPALITY', 'PROVINCE', 'BARANGAY', 'DISTRICT'};
    
    return text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty && !stopWords.contains(token))
        .toSet();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    if (_region == null || _city == null || _barangay == null) {
      setState(() => _showAddressError = true);
      SnackBarHelper.showError(context, 'Please select address location');
      return;
    }

    setState(() => _isSaving = true);

    try {
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
        throw Exception('Buyer ID not found');
      }

      // Build full address string - include ALL address parts
      final fullAddressParts = <String>[];
      if (_houseNumberController.text.isNotEmpty) {
        fullAddressParts.add(_houseNumberController.text.trim());
      }
      if (_streetController.text.isNotEmpty) {
        fullAddressParts.add(_streetController.text.trim());
      }
      if (_barangay != null && _barangay!.isNotEmpty) {
        fullAddressParts.add(_barangay!);
      }
      if (_city != null && _city!.isNotEmpty) {
        fullAddressParts.add(_city!);
      }
      if (_province != null && _province!.isNotEmpty) {
        fullAddressParts.add(_province!);
      }
      if (_region != null && _region!.isNotEmpty) {
        fullAddressParts.add(_region!);
      }
      final fullAddress = fullAddressParts.join(', ');

      final addressData = {
        'user_type': 'buyer',
        'user_ref_id': buyerId,
        'recipient_name': _recipientController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'full_address': fullAddress,
        'region': _region,
        'province': _province,
        'city': _city,
        'barangay': _barangay,
        'street_name': _streetController.text.trim(),
        'house_number': _houseNumberController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'is_default': _isDefault,
      };

      if (widget.address == null) {
        // Adding new address
        // If this is set as default, remove default from others first
        if (_isDefault) {
          await _supabase
              .from('addresses')
              .update({'is_default': false})
              .eq('user_type', 'buyer')
              .eq('user_ref_id', buyerId);
        }
        
        await _supabase.from('addresses').insert(addressData);
      } else {
        // Editing existing address
        if (_isDefault) {
          await _supabase
              .from('addresses')
              .update({'is_default': false})
              .eq('user_type', 'buyer')
              .eq('user_ref_id', buyerId);
        }
        
        await _supabase
            .from('addresses')
            .update(addressData)
            .eq('address_id', widget.address!['address_id']);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        SnackBarHelper.showError(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.address == null ? 'Add Address' : 'Edit Address',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTextField(
              controller: _recipientController,
              label: 'Recipient Name',
              hint: 'Enter recipient name',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter recipient name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: 'Enter phone number',
              keyboardType: TextInputType.phone,
              maxLength: 11,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                if (value.length != 11) {
                  return 'Phone number must be 11 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _houseNumberController,
              label: 'House/Unit/Floor No.',
              hint: 'e.g., Unit 123, 5th Floor',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _streetController,
              label: 'Street Name',
              hint: 'Enter street name',
            ),
            const SizedBox(height: 16),
            _buildAddressSelector(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _postalCodeController,
              label: 'Postal Code',
              hint: 'Auto-filled based on address',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildDefaultCheckbox(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.address == null ? 'Add Address' : 'Save Changes',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          validator: validator,
          decoration: InputDecoration(
            counterText: maxLength != null ? '' : null,
            hintText: hint,
            hintStyle: GoogleFonts.goudyBookletter1911(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: keyboardType == TextInputType.phone || keyboardType == TextInputType.number
              ? GoogleFonts.playfairDisplay()
              : GoogleFonts.goudyBookletter1911(),
        ),
      ],
    );
  }

  Widget _buildAddressSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Region, Province, City, Barangay',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectAddress,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _showAddressError && _addressDisplay.isEmpty 
                    ? Colors.red.withValues(alpha: 0.3) 
                    : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _addressDisplay.isEmpty ? 'Select address location' : _addressDisplay,
                    style: GoogleFonts.goudyBookletter1911(
                      color: _addressDisplay.isEmpty ? Colors.grey[400] : Colors.black,
                    ),
                  ),
                ),
                Icon(
                  _addressDisplay.isEmpty ? Icons.add_circle_outline : Icons.edit_outlined,
                  size: 20,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        if (_showAddressError && _addressDisplay.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Please select address location',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultCheckbox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _isDefault,
            onChanged: (value) {
              setState(() {
                _isDefault = value ?? false;
              });
            },
            activeColor: Colors.black,
          ),
          Expanded(
            child: Text(
              'Set as default address',
              style: GoogleFonts.goudyBookletter1911(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _houseNumberController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }
}
