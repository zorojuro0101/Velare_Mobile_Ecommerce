import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddressSelectorModal extends StatefulWidget {
  const AddressSelectorModal({super.key});

  @override
  State<AddressSelectorModal> createState() => _AddressSelectorModalState();
}

class _AddressSelectorModalState extends State<AddressSelectorModal> {
  static const String psgcApi = 'https://psgc.gitlab.io/api';
  
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];
  
  String? _selectedRegion;
  String? _selectedProvince;
  String? _selectedCity;
  String? _selectedBarangay;
  
  String? _selectedRegionName;
  String? _selectedProvinceName;
  String? _selectedCityName;
  String? _selectedBarangayName;
  
  bool _isLoadingRegions = true;
  bool _isLoadingProvinces = false;
  bool _isLoadingCities = false;
  bool _isLoadingBarangays = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    setState(() => _isLoadingRegions = true);
    try {
      final response = await http.get(Uri.parse('$psgcApi/regions'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _regions = data.map((item) => {
            'code': item['code'],
            'name': item['name'],
          }).toList();
          _isLoadingRegions = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingRegions = false);
    }
  }

  Future<void> _loadProvinces(String regionCode) async {
    setState(() {
      _isLoadingProvinces = true;
      _provinces = [];
      _cities = [];
      _barangays = [];
      _selectedProvince = null;
      _selectedCity = null;
      _selectedBarangay = null;
    });
    
    try {
      final response = await http.get(Uri.parse('$psgcApi/regions/$regionCode/provinces'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _provinces = data.map((item) => {
            'code': item['code'],
            'name': item['name'],
          }).toList();
          _isLoadingProvinces = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingProvinces = false);
    }
  }

  Future<void> _loadCities(String provinceCode) async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
      _barangays = [];
      _selectedCity = null;
      _selectedBarangay = null;
    });
    
    try {
      final response = await http.get(Uri.parse('$psgcApi/provinces/$provinceCode/cities-municipalities'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _cities = data.map((item) => {
            'code': item['code'],
            'name': item['name'],
          }).toList();
          _isLoadingCities = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingCities = false);
    }
  }

  Future<void> _loadBarangays(String cityCode) async {
    setState(() {
      _isLoadingBarangays = true;
      _barangays = [];
      _selectedBarangay = null;
    });
    
    try {
      final response = await http.get(Uri.parse('$psgcApi/cities-municipalities/$cityCode/barangays'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _barangays = data.map((item) => {
            'code': item['code'],
            'name': item['name'],
          }).toList();
          _isLoadingBarangays = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingBarangays = false);
    }
  }

  void _onRegionSelected(String? code, String? name) {
    setState(() {
      _selectedRegion = code;
      _selectedRegionName = name;
    });
    if (code != null) {
      _loadProvinces(code);
    }
  }

  void _onProvinceSelected(String? code, String? name) {
    setState(() {
      _selectedProvince = code;
      _selectedProvinceName = name;
    });
    if (code != null) {
      _loadCities(code);
    }
  }

  void _onCitySelected(String? code, String? name) {
    setState(() {
      _selectedCity = code;
      _selectedCityName = name;
    });
    if (code != null) {
      _loadBarangays(code);
    }
  }

  void _onBarangaySelected(String? code, String? name) {
    setState(() {
      _selectedBarangay = code;
      _selectedBarangayName = name;
    });
  }

  void _confirmSelection() {
    if (_selectedRegion != null &&
        _selectedProvince != null &&
        _selectedCity != null &&
        _selectedBarangay != null) {
      Navigator.pop(context, {
        'region': _selectedRegionName!,
        'province': _selectedProvinceName!,
        'city': _selectedCityName!,
        'barangay': _selectedBarangayName!,
        'region_code': _selectedRegion!,
        'province_code': _selectedProvince!,
        'city_code': _selectedCity!,
        'barangay_code': _selectedBarangay!,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDropdown(
                    label: 'Region',
                    value: _selectedRegion,
                    items: _regions,
                    onChanged: (code) {
                      final region = _regions.firstWhere((r) => r['code'] == code);
                      _onRegionSelected(code, region['name']);
                    },
                    isLoading: _isLoadingRegions,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'Province',
                    value: _selectedProvince,
                    items: _provinces,
                    onChanged: (code) {
                      final province = _provinces.firstWhere((p) => p['code'] == code);
                      _onProvinceSelected(code, province['name']);
                    },
                    isLoading: _isLoadingProvinces,
                    enabled: _selectedRegion != null,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'City/Municipality',
                    value: _selectedCity,
                    items: _cities,
                    onChanged: (code) {
                      final city = _cities.firstWhere((c) => c['code'] == code);
                      _onCitySelected(code, city['name']);
                    },
                    isLoading: _isLoadingCities,
                    enabled: _selectedProvince != null,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'Barangay',
                    value: _selectedBarangay,
                    items: _barangays,
                    onChanged: (code) {
                      final barangay = _barangays.firstWhere((b) => b['code'] == code);
                      _onBarangaySelected(code, barangay['name']);
                    },
                    isLoading: _isLoadingBarangays,
                    enabled: _selectedCity != null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _selectedBarangay != null ? _confirmSelection : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Confirm Address',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Select Address',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> items,
    required Function(String?) onChanged,
    required bool isLoading,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: enabled ? Colors.black : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: enabled ? Colors.grey[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    hint: Text(
                      'Select $label',
                      style: GoogleFonts.goudyBookletter1911(color: Colors.grey[600]),
                    ),
                    items: items.map((item) {
                      return DropdownMenuItem<String>(
                        value: item['code'],
                        child: Text(
                          item['name'],
                          style: GoogleFonts.goudyBookletter1911(),
                        ),
                      );
                    }).toList(),
                    onChanged: enabled ? onChanged : null,
                  ),
                ),
        ),
      ],
    );
  }
}
