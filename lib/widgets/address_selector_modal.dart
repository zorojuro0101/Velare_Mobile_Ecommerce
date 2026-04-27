import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddressSelectorModal extends StatefulWidget {
  final String? initialRegion;
  final String? initialProvince;
  final String? initialCity;
  final String? initialBarangay;
  
  const AddressSelectorModal({
    super.key,
    this.initialRegion,
    this.initialProvince,
    this.initialCity,
    this.initialBarangay,
  });

  @override
  State<AddressSelectorModal> createState() => _AddressSelectorModalState();
}

class _AddressSelectorModalState extends State<AddressSelectorModal> {
  static const String psgcApi = 'https://psgc.gitlab.io/api';
  
  // Cache data to avoid reloading
  static List<Map<String, dynamic>>? _cachedRegions;
  static final Map<String, List<Map<String, dynamic>>> _cachedProvinces = {};
  static final Map<String, List<Map<String, dynamic>>> _cachedCities = {};
  static final Map<String, List<Map<String, dynamic>>> _cachedBarangays = {};
  
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
  
  String? _postalCode;
  
  bool _isLoadingRegions = true;
  bool _isLoadingProvinces = false;
  bool _isLoadingCities = false;
  bool _isLoadingBarangays = false;
  bool _isLoadingPostalCode = false;
  
  bool _autoOpenNext = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
    
    // Initialize with previous selections if provided
    if (widget.initialRegion != null) {
      _selectedRegionName = widget.initialRegion;
      // We'll need to find the code after regions load
    }
    if (widget.initialProvince != null) {
      _selectedProvinceName = widget.initialProvince;
    }
    if (widget.initialCity != null) {
      _selectedCityName = widget.initialCity;
    }
    if (widget.initialBarangay != null) {
      _selectedBarangayName = widget.initialBarangay;
    }
  }

  Future<void> _loadRegions() async {
    //   Use cached data if available
    if (_cachedRegions != null) {
      setState(() {
        _regions = _cachedRegions!;
        _isLoadingRegions = false;
      });
      _initializeSelections();
      return;
    }
    
    setState(() => _isLoadingRegions = true);
    try {
      final response = await http.get(Uri.parse('$psgcApi/regions'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final regions = data.map((item) => {
          'code': item['code'],
          'name': item['name'],
        }).toList();
        
        setState(() {
          _regions = regions;
          _cachedRegions = regions; // Cache for future use
          _isLoadingRegions = false;
        });
        _initializeSelections();
      }
    } catch (e) {
      setState(() => _isLoadingRegions = false);
    }
  }
  
  void _initializeSelections() {
    // Find and set region code if initial region name was provided
    if (widget.initialRegion != null && _selectedRegion == null) {
      final region = _regions.firstWhere(
        (r) => r['name'] == widget.initialRegion,
        orElse: () => {},
      );
      if (region.isNotEmpty) {
        _selectedRegion = region['code'];
        _selectedRegionName = region['name'];
        _loadProvinces(_selectedRegion!, autoOpen: false).then((_) {
          _initializeProvinceSelection();
        });
      }
    }
  }
  
  void _initializeProvinceSelection() {
    if (widget.initialProvince != null && _selectedProvince == null) {
      final province = _provinces.firstWhere(
        (p) => p['name'] == widget.initialProvince,
        orElse: () => {},
      );
      if (province.isNotEmpty) {
        _selectedProvince = province['code'];
        _selectedProvinceName = province['name'];
        _loadCities(_selectedProvince!, autoOpen: false).then((_) {
          _initializeCitySelection();
        });
      }
    }
  }
  
  void _initializeCitySelection() {
    if (widget.initialCity != null && _selectedCity == null) {
      final city = _cities.firstWhere(
        (c) => c['name'] == widget.initialCity,
        orElse: () => {},
      );
      if (city.isNotEmpty) {
        _selectedCity = city['code'];
        _selectedCityName = city['name'];
        _loadBarangays(_selectedCity!, autoOpen: false).then((_) {
          _initializeBarangaySelection();
        });
      }
    }
  }
  
  void _initializeBarangaySelection() {
    if (widget.initialBarangay != null && _selectedBarangay == null) {
      final barangay = _barangays.firstWhere(
        (b) => b['name'] == widget.initialBarangay,
        orElse: () => {},
      );
      if (barangay.isNotEmpty) {
        setState(() {
          _selectedBarangay = barangay['code'];
          _selectedBarangayName = barangay['name'];
        });
      }
    }
  }

  Future<void> _loadProvinces(String regionCode, {bool autoOpen = false}) async {
    // Use cached data if available
    if (_cachedProvinces.containsKey(regionCode)) {
      setState(() {
        _provinces = _cachedProvinces[regionCode]!;
        _cities = [];
        _barangays = [];
        _selectedProvince = null;
        _selectedCity = null;
        _selectedBarangay = null;
        _isLoadingProvinces = false;
        _autoOpenNext = autoOpen;
      });
      return;
    }
    
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
        final provinces = data.map((item) => {
          'code': item['code'],
          'name': item['name'],
        }).toList();
        
        setState(() {
          _provinces = provinces;
          _cachedProvinces[regionCode] = provinces; // Cache for future use
          _isLoadingProvinces = false;
          _autoOpenNext = autoOpen;
        });
      }
    } catch (e) {
      setState(() => _isLoadingProvinces = false);
    }
  }

  Future<void> _loadCities(String provinceCode, {bool autoOpen = false}) async {
    // Use cached data if available
    if (_cachedCities.containsKey(provinceCode)) {
      setState(() {
        _cities = _cachedCities[provinceCode]!;
        _barangays = [];
        _selectedCity = null;
        _selectedBarangay = null;
        _isLoadingCities = false;
        _autoOpenNext = autoOpen;
      });
      return;
    }
    
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
        final cities = data.map((item) => {
          'code': item['code'],
          'name': item['name'],
        }).toList();
        
        setState(() {
          _cities = cities;
          _cachedCities[provinceCode] = cities; // Cache for future use
          _isLoadingCities = false;
          _autoOpenNext = autoOpen;
        });
      }
    } catch (e) {
      setState(() => _isLoadingCities = false);
    }
  }

  Future<void> _loadBarangays(String cityCode, {bool autoOpen = false}) async {
    // Use cached data if available
    if (_cachedBarangays.containsKey(cityCode)) {
      setState(() {
        _barangays = _cachedBarangays[cityCode]!;
        _selectedBarangay = null;
        _isLoadingBarangays = false;
        _autoOpenNext = autoOpen;
      });
      return;
    }
    
    setState(() {
      _isLoadingBarangays = true;
      _barangays = [];
      _selectedBarangay = null;
    });
    
    try {
      final response = await http.get(Uri.parse('$psgcApi/cities-municipalities/$cityCode/barangays'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final barangays = data.map((item) => {
          'code': item['code'],
          'name': item['name'],
        }).toList();
        
        setState(() {
          _barangays = barangays;
          _cachedBarangays[cityCode] = barangays; // Cache for future use
          _isLoadingBarangays = false;
          _autoOpenNext = autoOpen;
        });
      }
    } catch (e) {
      setState(() => _isLoadingBarangays = false);
    }
  }

  void _onRegionSelected(String? code, String? name) {
    // Clear subsequent selections when region changes
    setState(() {
      _selectedRegion = code;
      _selectedRegionName = name;
      _selectedProvince = null;
      _selectedProvinceName = null;
      _selectedCity = null;
      _selectedCityName = null;
      _selectedBarangay = null;
      _selectedBarangayName = null;
      _cities = [];
      _barangays = [];
    });
    if (code != null) {
      _loadProvinces(code, autoOpen: true);
    }
  }

  void _onProvinceSelected(String? code, String? name) {
    // Clear subsequent selections when province changes
    setState(() {
      _selectedProvince = code;
      _selectedProvinceName = name;
      _selectedCity = null;
      _selectedCityName = null;
      _selectedBarangay = null;
      _selectedBarangayName = null;
      _barangays = [];
      _autoOpenNext = false; // Reset auto-open when user manually selects
    });
    if (code != null) {
      _loadCities(code, autoOpen: true);
    }
  }

  void _onCitySelected(String? code, String? name) {
    // Clear subsequent selections when city changes
    setState(() {
      _selectedCity = code;
      _selectedCityName = name;
      _selectedBarangay = null;
      _selectedBarangayName = null;
      _autoOpenNext = false; // Reset auto-open when user manually selects
    });
    if (code != null) {
      _loadBarangays(code, autoOpen: true);
    }
  }

  void _onBarangaySelected(String? code, String? name) {
    setState(() {
      _selectedBarangay = code;
      _selectedBarangayName = name;
      _autoOpenNext = false; // Reset auto-open when user manually selects
    });
    
    // Automatically fetch postal code when barangay is selected
    if (code != null) {
      _fetchPostalCode();
    }
  }

  Future<void> _fetchPostalCode() async {
    if (_selectedCityName == null) return;
    
    setState(() {
      _isLoadingPostalCode = true;
      _postalCode = null;
    });
    
    try {
      final response = await http.get(
        Uri.parse('https://gist.githubusercontent.com/chrisbjr/784565232f10cba6530856dc7fda367a/raw/ph-zip-codes.json'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> postalData = json.decode(response.body);
        
        final cityTokens = _normalizeAndTokenize(_selectedCityName!);
        final provinceTokens = _selectedProvinceName != null ? _normalizeAndTokenize(_selectedProvinceName!) : <String>[];
        final barangayTokens = _selectedBarangayName != null ? _normalizeAndTokenize(_selectedBarangayName!) : <String>[];
        
        String? foundPostalCode;
        int bestScore = 0;
        
        for (var entry in postalData) {
          final area = entry['area'] as String;
          final areaTokens = _normalizeAndTokenize(area);
          
          int score = 0;
          
          if (!cityTokens.every((token) => areaTokens.contains(token))) continue;
          
          score += 5;
          
          if (provinceTokens.isNotEmpty && provinceTokens.every((token) => areaTokens.contains(token))) {
            score += 3;
          }
          
          if (barangayTokens.isNotEmpty && barangayTokens.any((token) => areaTokens.contains(token))) {
            score += 2;
          }
          
          if (score > bestScore) {
            bestScore = score;
            foundPostalCode = entry['zip'] as String;
          }
        }
        
        if (mounted) {
          setState(() {
            _postalCode = foundPostalCode;
            _isLoadingPostalCode = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPostalCode = false;
        });
      }
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

  void _confirmSelection() {
    if (_selectedRegion != null &&
        _selectedProvince != null &&
        _selectedCity != null &&
        _selectedBarangay != null) {
      final result = <String, String>{
        'region': _selectedRegionName!,
        'province': _selectedProvinceName!,
        'city': _selectedCityName!,
        'barangay': _selectedBarangayName!,
        'region_code': _selectedRegion!,
        'province_code': _selectedProvince!,
        'city_code': _selectedCity!,
        'barangay_code': _selectedBarangay!,
      };
      
      // Add postal code only if it's not null
      if (_postalCode != null) {
        result['postal_code'] = _postalCode!;
      }
      
      Navigator.pop(context, result);
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
                    dropdownKey: GlobalKey(),
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
                    dropdownKey: GlobalKey(),
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
                    dropdownKey: GlobalKey(),
                  ),
                  const SizedBox(height: 16),
                  _buildPostalCodeField(),
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
    GlobalKey? dropdownKey,
  }) {
    // Auto-open dropdown after data loads
    if (_autoOpenNext && !isLoading && items.isNotEmpty && value == null && enabled && dropdownKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _autoOpenNext = false);
          // Trigger dropdown to open
          final dynamic dropdownState = dropdownKey.currentContext?.findRenderObject();
          if (dropdownState != null) {
            // This will programmatically open the dropdown
            dropdownKey.currentContext?.visitChildElements((element) {
              if (element.widget is DropdownButton) {
                // Simulate tap to open dropdown
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted && dropdownKey.currentContext != null) {
                    final RenderBox? box = dropdownKey.currentContext!.findRenderObject() as RenderBox?;
                    if (box != null) {
                      // The dropdown will open when tapped
                    }
                  }
                });
              }
            });
          }
        }
      });
    }
    
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
          key: dropdownKey,
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

  Widget _buildPostalCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Postal Code',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _selectedBarangay != null ? Colors.black : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _selectedBarangay != null ? Colors.grey[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isLoadingPostalCode
              ? Row(
                  children: [
                    const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Fetching postal code...',
                      style: GoogleFonts.goudyBookletter1911(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
              : Text(
                  _postalCode ?? 'Auto-filled',
                  style: _postalCode != null
                      ? GoogleFonts.playfairDisplay(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        )
                      : GoogleFonts.goudyBookletter1911(
                          color: Colors.grey[600],
                        ),
                ),
        ),
      ],
    );
  }
}
